//
//  APIErrorTests.swift
//  pet-allergy-scannerTests
//
//  Created by Steven Matos on 9/26/25.
//

import Testing
import Foundation
@testable import pet_allergy_scanner

/// Unit tests for APIError enum and error handling
@Suite("API Error Tests")
struct APIErrorTests {
    
    /// Test APIError error descriptions
    @Test("Error descriptions")
    func testErrorDescriptions() {
        let invalidURL = APIError.invalidURL
        #expect(invalidURL.errorDescription == "Invalid URL")
        
        let networkError = APIError.networkError("Connection failed")
        #expect(networkError.errorDescription == "Network error: Connection failed")
        
        let decodingError = APIError.decodingError
        #expect(decodingError.errorDescription == "Failed to decode response")
        
        let encodingError = APIError.encodingError
        #expect(encodingError.errorDescription == "Failed to encode request")
        
        let authError = APIError.authenticationError
        #expect(authError.errorDescription == "Authentication failed")
        
        let serverError = APIError.serverError(500)
        #expect(serverError.errorDescription == "Server error: 500")
        
        let serverMessage = APIError.serverMessage("Invalid request")
        #expect(serverMessage.errorDescription == "Server error: Invalid request")
        
        let unknownError = APIError.unknownError
        #expect(unknownError.errorDescription == "Unknown error occurred")
    }
    
    /// Test APIErrorResponse model
    @Test("APIErrorResponse model")
    func testAPIErrorResponse() {
        let errorResponse = APIErrorResponse(
            message: "Validation failed",
            code: "VALIDATION_ERROR",
            details: ["field": "email", "reason": "invalid format"]
        )
        
        #expect(errorResponse.message == "Validation failed")
        #expect(errorResponse.code == "VALIDATION_ERROR")
        #expect(errorResponse.details?["field"] == "email")
        #expect(errorResponse.details?["reason"] == "invalid format")
    }
    
    /// Test APIErrorResponse with minimal data
    @Test("APIErrorResponse minimal data")
    func testAPIErrorResponseMinimal() {
        let errorResponse = APIErrorResponse(
            message: "Server error",
            code: nil,
            details: nil
        )
        
        #expect(errorResponse.message == "Server error")
        #expect(errorResponse.code == nil)
        #expect(errorResponse.details == nil)
    }
    
    /// Test APIErrorResponse JSON decoding
    @Test("APIErrorResponse JSON decoding")
    func testAPIErrorResponseJSONDecoding() throws {
        let json = """
        {
            "message": "User not found",
            "code": "USER_NOT_FOUND",
            "details": {
                "user_id": "123"
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let errorResponse = try decoder.decode(APIErrorResponse.self, from: json)
        
        #expect(errorResponse.message == "User not found")
        #expect(errorResponse.code == "USER_NOT_FOUND")
        #expect(errorResponse.details?["user_id"] == "123")
    }
    
    /// Test APIErrorResponse JSON encoding
    @Test("APIErrorResponse JSON encoding")
    func testAPIErrorResponseJSONEncoding() throws {
        let errorResponse = APIErrorResponse(
            message: "Database connection failed",
            code: "DB_ERROR",
            details: ["database": "main", "table": "users"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(errorResponse)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        #expect(json["message"] as? String == "Database connection failed")
        #expect(json["code"] as? String == "DB_ERROR")
        #expect((json["details"] as? [String: String])?["database"] == "main")
    }
}
