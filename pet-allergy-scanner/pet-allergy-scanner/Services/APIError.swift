//
//  APIError.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// API error enumeration for handling network and API errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(String)
    case decodingError
    case encodingError
    case authenticationError
    case serverError(Int)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request"
        case .authenticationError:
            return "Authentication failed"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}
