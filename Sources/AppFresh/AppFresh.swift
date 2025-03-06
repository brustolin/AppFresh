import UIKit
import Foundation

struct AppInfo: Decodable {
    let version: String?
    let trackName: String?
    let trackViewUrl: String?
    let minimumOsVersion: String?
}

struct ItunesLookupResponse: Decodable {
    let resultCount: Int
    let results: [AppInfo]
}

// Actor to ensure thread-safe access to app info
actor AppFreshStorage {
    var appInfo: AppInfo?
    func setAppInfo(_ appInfo: AppInfo?) {
        self.appInfo = appInfo
    }
}

@objc
public final class AppFresh: NSObject, Sendable {
    private static let storage = AppFreshStorage()
    
    public static func hasUpdate(_ bundleIdentifier: String? = nil) async -> Bool {
        guard
            let bundleId = bundleIdentifier ?? Bundle.main.bundleIdentifier,
            let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)")
        else {
            print("[AppFresh] No bundle identifier found. Provide one.")
            return false
        }
        
        guard let appInfo = await fetchAppInfo(from: url) else { return false }
        await storage.setAppInfo(appInfo)
        
        guard let latestVersion = appInfo.version
        else {
            print("[AppFresh] Could not extract latest app version from the app info.")
            return false
        }
        
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else {
            print("[AppFresh] No app version found in the main bundle")
            return false
        }
        
        // If there is no minimumOsVersion in the app info, assume it works on every version.
        if let minimumOsVersion = appInfo.minimumOsVersion, await !isOsVersionCompatible(minimumOsVersion) {
            return false
        }
        
        return isVersion(currentVersion, olderThan: latestVersion)
    }
    
    public static func openAppStore() {
        Task { @MainActor in
            guard let urlString = await storage.appInfo?.trackViewUrl,
                  let url = URL(string: urlString) else { return }
            
            await UIApplication.shared.open(url)
        }
    }
    
    private static func fetchAppInfo(from url: URL) async -> AppInfo? {
        guard var data: Data = await {
            do {
                let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
                return data
            } catch {
                print("[AppFresh] Could not fetch app info: \(error)")
                return nil
            }
        }() else { return nil }
        
        do {
            let lookup = try JSONDecoder().decode(ItunesLookupResponse.self, from: data)
            return lookup.results.first ?? AppInfo(version: nil, trackName: nil, trackViewUrl: nil, minimumOsVersion: nil)
        } catch {
            print("[AppFresh] Could not parse app info from JSON: \(error)")
            return nil
        }
    }
    
    private static func isVersion(_ current: String, olderThan latest: String) -> Bool {
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        
        for (current, latest) in zip(currentComponents, latestComponents) {
            if current < latest { return true }
            if current > latest { return false }
        }
        
        return currentComponents.count < latestComponents.count
    }
    
    @MainActor
    private static func isOsVersionCompatible(_ minVersion: String) -> Bool {
        let systemVersion = UIDevice.current.systemVersion
        return !isVersion(systemVersion, olderThan: minVersion)
    }
}
