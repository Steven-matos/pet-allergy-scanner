//
//  Configuration.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 10/1/25.
//

import Foundation

/// Configuration manager for environment variables and app settings
/// Provides secure access to configuration values with fallback defaults
struct Configuration {
    
    // MARK: - Supabase Configuration
    
    /// Supabase project URL
    static var supabaseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }
    
    /// Supabase anonymous key
    static var supabaseAnonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }
    
    /// Supabase pet images bucket name
    static var petBucketName: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PET_BUCKET") as? String ?? ""
    }

    /// Supabase user images bucket name
    static var userBucketName: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_USER_BUCKET") as? String ?? ""
    }
    
    // MARK: - API Configuration
    
    /// API base URL
    static var apiBaseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "http://localhost:8000/api/v1"
    }
    
    // MARK: - Security Configuration
    
    /// Maximum file size for uploads (in bytes)
    static var maxUploadSize: Int {
        Bundle.main.object(forInfoDictionaryKey: "MAX_UPLOAD_SIZE") as? Int ?? 5_242_880 // 5MB default
    }
    
    /// Allowed image MIME types
    static var allowedImageTypes: [String] {
        Bundle.main.object(forInfoDictionaryKey: "ALLOWED_IMAGE_TYPES") as? [String] ?? [
            "image/jpeg",
            "image/jpg", 
            "image/png",
            "image/webp"
        ]
    }
    
    // MARK: - Environment Detection
    
    /// Current environment (development, staging, production)
    static var environment: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    /// Check if running in debug mode
    static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

/// App environment types
enum AppEnvironment: String, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    
    var displayName: String {
        switch self {
        case .development:
            return "Development"
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        }
    }
}

// MARK: - Configuration Validation

extension Configuration {
    
    /// Validate that all required configuration values are present
    /// - Returns: True if configuration is valid, false otherwise
    static func validate() -> Bool {
        let requiredValues = [
            supabaseURL,
            supabaseAnonKey,
            apiBaseURL
        ]
        
        return requiredValues.allSatisfy { !$0.isEmpty }
    }
    
    /// Get configuration summary for debugging
    /// - Returns: Dictionary with configuration values (excluding sensitive data)
    static func getDebugInfo() -> [String: Any] {
        return [
            "environment": environment.rawValue,
            "isDebugMode": isDebugMode,
            "apiBaseURL": apiBaseURL,
            "supabaseURL": supabaseURL,
            "petBucketName": petBucketName,
            "userBucketName": userBucketName,
            "maxUploadSize": maxUploadSize,
            "allowedImageTypes": allowedImageTypes
        ]
    }
}
