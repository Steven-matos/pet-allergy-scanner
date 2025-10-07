import Foundation

/// Extension to Bundle for accessing common app information
extension Bundle {
    /// Returns the app's version number from Info.plist (CFBundleShortVersionString)
    /// - Returns: The app version string, or "1.0" if not found
    var appVersion: String {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    
    /// Returns the app's build number from Info.plist (CFBundleVersion)
    /// - Returns: The build number string, or "1" if not found
    var buildNumber: String {
        return object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    
    /// Returns a combined version string (e.g., "1.0 (1)")
    /// - Returns: Combined version and build number string
    var fullVersion: String {
        return "\(appVersion) (\(buildNumber))"
    }
}

