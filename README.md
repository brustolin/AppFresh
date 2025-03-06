# AppFresh

AppFresh is a lightweight Swift library that checks for updates of an iOS app on the App Store using the iTunes Lookup API, no self hosting required. It also provides a convenient way to open the App Store for updating the app.

## Features
- Fetch the latest app version from the App Store.
- Compare the installed app version with the latest version.
- Ensure the device meets the minimum required iOS version.
- Open the App Store page for easy updating.

## Installation

### Swift Package Manager (SPM)
1. Open your Xcode project.
2. Go to `File > Add Packages`.
3. Enter the repository URL:
   ```
   https://github.com/brustolin/AppFresh.git
   ```
4. Add the package to your project.

## Usage

### Check for an Update and Show an Alert
```swift
import AppFresh
import UIKit

func checkForUpdate() async {
    guard await AppFresh.hasUpdate() else { return }
    
    let alert = UIAlertController(
        title: "Update Available",
        message: "A new version of the app is available. Would you like to update now?",
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "Update", style: .default) { _ in
        AppFresh.openAppStore()
    })
    
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
    // Assuming self is a view controller
    self.present(alert, animated: true, completion: nil)
}
```

## Requirements
- iOS 13.0+
- tvOS 13.0+
- macOS 10.15+
- visionOS 1.0+
