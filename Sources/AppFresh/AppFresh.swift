#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
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
    
    /**
     * Checks if a newer version of the app is available on the App Store. It compares the app’s current version with the
     * latest version available for the app’s bundle identifier. Optionally, the function allows specifying a country code
     * to retrieve the update information for a specific country.
     *
     * - Parameters:
     *      - bundleIdentifier: The bundle identifier of the app. If `nil`,
     *      the function uses the bundle identifier from the main app bundle. Default is `nil`.
     *     - countryCode: The country code for the App Store (e.g., "us" for the United States).
     *     Default is `"us"`. In case your app is not available in the US you need to provide a country code,
     *     otherwise the library cannot find your app info.
     *
     * - Returns: `true` if an update is available, `false` if the app is up-to-date or
     * there was an error fetching the update information.
     */
    @objc
    public static func hasUpdate(_ bundleIdentifier: String? = nil, countryCode: String = "us") async -> Bool {
        guard
            let bundleId = bundleIdentifier ?? Bundle.main.bundleIdentifier,
            let url = URL(string: "https://itunes.apple.com/\(countryCode)/lookup?bundleId=\(bundleId)")
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
    
    /**
     * Open the app store directly into the apps page where the user can update it.
     * In order for `openAppStore()` to work, `hasUpdate()` needs to be called at least once before.
     */
    @objc
    public static func openAppStore() {
        Task { @MainActor in
            guard let urlString = await storage.appInfo?.trackViewUrl,
                  let url = URL(string: urlString) else {
                print("[AppFresh] There is no app url to open. You need to call `AppFresh.hasUpdate()` first.")
                return
            }
            
#if canImport(UIKit)
            await UIApplication.shared.open(url)
#elseif canImport(AppKit)
            NSWorkspace.shared.open(url)
#endif
            
        }
    }
    
    private static func fetchAppInfo(from url: URL) async -> AppInfo? {
        guard let data: Data = await {
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
#if canImport(UIKit)
        let versionString = UIDevice.current.systemVersion
#elseif canImport(AppKit)
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(systemVersion.majorVersion).\(systemVersion.minorVersion).\(systemVersion.patchVersion)"
#endif
        
        return !isVersion(versionString, olderThan: minVersion)
    }
}
