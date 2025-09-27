//
//  LocalizationHelper.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Helper for localization and string management
struct LocalizationHelper {
    
    /// Get localized string for key
    /// - Parameter key: The localization key
    /// - Returns: Localized string or the key itself if not found
    static func localizedString(for key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }
    
    /// Get localized string with arguments
    /// - Parameters:
    ///   - key: The localization key
    ///   - arguments: Arguments to format into the string
    /// - Returns: Localized and formatted string
    static func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, arguments: arguments)
    }
}

/// Extension to String for easy localization
extension String {
    /// Get localized version of this string
    var localized: String {
        return LocalizationHelper.localizedString(for: self)
    }
    
    /// Get localized version with arguments
    func localized(_ arguments: CVarArg...) -> String {
        return LocalizationHelper.localizedString(for: self, arguments: arguments)
    }
}

/// Localization keys for type safety
struct LocalizationKeys {
    
    // MARK: - Common
    static let ok = "OK"
    static let cancel = "Cancel"
    static let save = "Save"
    static let delete = "Delete"
    static let edit = "Edit"
    static let add = "Add"
    static let remove = "Remove"
    static let done = "Done"
    static let retry = "Retry"
    static let tryAgain = "Try Again"
    static let settings = "Settings"
    static let error = "Error"
    static let success = "Success"
    static let loading = "Loading"
    static let processing = "Processing"
    
    // MARK: - Navigation
    static let profile = "Profile"
    static let scan = "Scan"
    static let pets = "Pets"
    static let history = "History"
    static let favorites = "Favorites"
    
    // MARK: - Profile View
    static let editProfile = "Edit Profile"
    static let subscription = "Subscription"
    static let helpSupport = "Help & Support"
    static let signOut = "Sign Out"
    static let signOutConfirmation = "Are you sure you want to sign out?"
    static let configurationError = "Configuration Error"
    static let servicesNotAvailable = "Required services are not available. Please restart the app."
    
    // MARK: - Scan View
    static let scanPetFood = "Scan Pet Food"
    static let pointCameraAtIngredients = "Point your camera at the ingredient list"
    static let tapToScan = "Tap to Scan"
    static let processingImage = "Processing image..."
    static let analyzingIngredients = "Analyzing ingredients..."
    static let extractedText = "Extracted Text:"
    static let analyzeIngredients = "Analyze Ingredients"
    static let recentScans = "Recent Scans"
    static let selectPet = "Select Pet"
    static let cameraPermission = "Camera Permission"
    static let cameraError = "Camera Error"
    static let cameraAccessRequired = "Camera access is required to scan ingredient labels. Please allow camera access in Settings."
    static let cameraAccessDenied = "Camera access is denied. Please enable camera access in Settings to scan ingredient labels."
    static let cameraAccessGranted = "Camera access is granted."
    static let unknownCameraPermission = "Unknown camera permission status."
    static let failedToCaptureImage = "Failed to capture image"
    
    // MARK: - Pet Management
    static let addPet = "Add Pet"
    static let addYourFirstPet = "Add Your First Pet"
    static let noPetsAdded = "No Pets Added"
    static let addPetDescription = "Add your pet's profile to start scanning ingredient labels for allergies and safety."
    static let basicInformation = "Basic Information"
    static let petName = "Pet Name"
    static let species = "Species"
    static let breedOptional = "Breed (Optional)"
    static let physicalInformation = "Physical Information"
    static let age = "Age"
    static let months = "Months"
    static let weight = "Weight"
    static let kg = "kg"
    static let knownAllergies = "Known Allergies"
    static let addAllergy = "Add allergy"
    static let veterinaryInformation = "Veterinary Information (Optional)"
    static let vetName = "Vet Name"
    static let vetPhone = "Vet Phone"
    
    // MARK: - Pet Species
    static let dog = "Dog"
    static let cat = "Cat"
    
    // MARK: - Scan Status
    static let pending = "Pending"
    static let completed = "Completed"
    static let failed = "Failed"
    
    // MARK: - Safety Levels
    static let safe = "Safe"
    static let caution = "Caution"
    static let unsafe = "Unsafe"
    static let unknown = "Unknown"
    
    // MARK: - Validation Messages
    static let petNameRequired = "Pet name is required"
    static let petNameMinLength = "Pet name must be at least 2 characters"
    static let petNameMaxLength = "Pet name must be less than 50 characters"
    static let ageCannotBeNegative = "Age cannot be negative"
    static let weightMustBePositive = "Weight must be positive"
    static let petIdRequired = "Pet ID is required"
    static let imageOrTextRequired = "Either image or text data is required"
    static let extractedTextRequired = "Extracted text is required"
    
    // MARK: - OCR Messages
    static let invalidImage = "Invalid image"
    static let ocrFailed = "OCR failed: %@"
    static let noTextFound = "No text found in image"
    static let ocrProcessingFailed = "OCR processing failed: %@"
    static let invalidImageData = "Invalid image data"
    
    // MARK: - Safety Messages
    static let containsUnsafeIngredient = "Contains %d potentially unsafe ingredient"
    static let containsUnsafeIngredients = "Contains %d potentially unsafe ingredients"
}
