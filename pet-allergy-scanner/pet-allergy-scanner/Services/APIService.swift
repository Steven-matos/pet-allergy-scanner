//
//  APIService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Security

/// Empty response model for API calls that don't return data
struct EmptyResponse: Codable {}

/// Main API service for communicating with the backend using Swift Concurrency
@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = Configuration.apiBaseURL
    private let authTokenKey = "authToken"
    private var authToken: String? {
        get { KeychainHelper.read(forKey: authTokenKey) }
        set {
            if let token = newValue {
                KeychainHelper.save(token, forKey: authTokenKey)
            } else {
                KeychainHelper.delete(forKey: authTokenKey)
            }
        }
    }
    
    /// Check if user has authentication token
    var hasAuthToken: Bool {
        return authToken != nil
    }
    
    private init() {}
    
    /// Set authentication token for API requests
    func setAuthToken(_ token: String) {
        authToken = token
    }
    
    /// Clear authentication token
    func clearAuthToken() {
        authToken = nil
    }
    
    /// Get current authentication token
    /// - Returns: The current auth token or nil if not set
    func getAuthToken() -> String? {
        return authToken
    }
    
    /// Create JSON encoder with consistent date encoding strategy
    private func createJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    /// Create JSON decoder with flexible date decoding strategy
    private func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            print("🔍 DEBUG: Attempting to decode date string: \(dateString)")
            
            // Try ISO8601 format first (with time)
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                print("🔍 DEBUG: Successfully decoded date with ISO8601: \(date)")
                return date
            }
            
            // Try ISO8601 without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                print("🔍 DEBUG: Successfully decoded date with ISO8601 (no fractional): \(date)")
                return date
            }
            
            // Try simple date format (YYYY-MM-DD)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            if let date = dateFormatter.date(from: dateString) {
                print("🔍 DEBUG: Successfully decoded date with simple format: \(date)")
                return date
            }
            
            print("🔍 DEBUG: Failed to decode date string: \(dateString)")
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        return decoder
    }
    
    /// Create URL request with authentication headers and security features
    private func createRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("1.0.0", forHTTPHeaderField: "X-Client-Version")
        
        // Add security headers
        request.setValue("en-US", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        // Set timeout for security
        request.timeoutInterval = 30.0
        
        return request
    }
    
    /// Perform network request with error handling using async/await
    private func performRequest<T: Codable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    break // Success
                case 401:
                    // Try to decode error message from response
                    if let errorResponse = try? createJSONDecoder().decode(APIErrorResponse.self, from: data) {
                        // Clear invalid token only if this is a session/token error
                        if errorResponse.message.lowercased().contains("invalid authentication") {
                            clearAuthToken()
                        }
                        throw APIError.serverMessage(errorResponse.message)
                    }
                    // Fallback to generic authentication error
                    clearAuthToken()
                    throw APIError.authenticationError
                case 403:
                    // Check if this is an email verification error
                    if let errorResponse = try? createJSONDecoder().decode(APIErrorResponse.self, from: data) {
                        if errorResponse.message.contains("verify your email") {
                            throw APIError.emailNotVerified(errorResponse.message)
                        }
                    }
                    throw APIError.authenticationError
                case 429:
                    // Rate limit exceeded
                    throw APIError.rateLimitExceeded
                case 400...499:
                    // Try to decode error response
                    if let errorResponse = try? createJSONDecoder().decode(APIErrorResponse.self, from: data) {
                        throw APIError.serverMessage(errorResponse.message)
                    }
                    // Try to decode as generic error response (also check for 'detail' key)
                    if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorDict["error"] as? String) ?? (errorDict["detail"] as? String) {
                        throw APIError.serverMessage(errorMessage)
                    }
                    throw APIError.serverError(httpResponse.statusCode)
                case 500...599:
                    throw APIError.serverError(httpResponse.statusCode)
                default:
                    throw APIError.unknownError
                }
            }
            
            // Decode successful response
            let decoder = createJSONDecoder()
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                // Log the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 DEBUG: Failed to decode response. Raw response: \(responseString)")
                    print("🔍 DEBUG: Response data length: \(data.count) bytes")
                    print("🔍 DEBUG: Decoding error: \(decodingError)")
                    
                    // Log detailed decoding error information
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("🔍 DEBUG: Type mismatch - Expected: \(type), Context: \(context)")
                    case .valueNotFound(let type, let context):
                        print("🔍 DEBUG: Value not found - Type: \(type), Context: \(context)")
                    case .keyNotFound(let key, let context):
                        print("🔍 DEBUG: Key not found - Key: \(key), Context: \(context)")
                    case .dataCorrupted(let context):
                        print("🔍 DEBUG: Data corrupted - Context: \(context)")
                    @unknown default:
                        print("🔍 DEBUG: Unknown decoding error")
                    }
                    
                    // Try to provide more helpful error messages
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("🔍 DEBUG: Parsed JSON object: \(jsonObject)")
                        
                        // Check if this is an error response with a different format
                        if let errorMessage = jsonObject["error"] as? String {
                            print("🔍 DEBUG: Found error message in response: \(errorMessage)")
                        }
                    }
                }
                throw APIError.networkError("Failed to decode response: \(decodingError.localizedDescription)")
            } catch {
                // Log the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 DEBUG: Failed to decode response. Raw response: \(responseString)")
                }
                throw error
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            if let decodingError = error as? DecodingError {
                // Provide more detailed decoding error information
                let errorMessage = "Failed to decode response: \(decodingError.localizedDescription)"
                throw APIError.networkError(errorMessage)
            } else {
                throw APIError.networkError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Authentication Endpoints

extension APIService {
    /// Register a new user
    func register(user: UserCreate) async throws -> RegistrationResponse {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try createJSONEncoder().encode(user)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: RegistrationResponse.self)
    }
    
    /// Login user
    func login(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw APIError.invalidURL
        }
        
        print("🔍 DEBUG: Attempting login to URL: \(url)")
        
        var request = createRequest(url: url, method: "POST")
        
        let loginData = ["email_or_username": email, "password": password]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
            print("🔍 DEBUG: Login request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
        } catch {
            print("🔍 DEBUG: Failed to encode login data: \(error)")
            throw APIError.encodingError
        }
        
        print("🔍 DEBUG: Sending login request...")
        return try await performRequest(request, responseType: AuthResponse.self)
    }
    
    /// Reset password for user
    func resetPassword(email: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/reset-password") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        let resetData = ["email": email]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: resetData)
        } catch {
            throw APIError.encodingError
        }
        
        let _: EmptyResponse = try await performRequest(request, responseType: EmptyResponse.self)
    }
    
    /// Get current user information
    func getCurrentUser() async throws -> User {
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: User.self)
    }
    
    /// Update current user
    func updateUser(_ userUpdate: UserUpdate) async throws -> User {
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "PUT")
        
        do {
            request.httpBody = try createJSONEncoder().encode(userUpdate)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: User.self)
    }
}

// MARK: - Pet Endpoints

extension APIService {
    /// Create a new pet profile
    func createPet(_ pet: PetCreate) async throws -> Pet {
        guard let url = URL(string: "\(baseURL)/pets/") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try createJSONEncoder().encode(pet)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: Pet.self)
    }
    
    /// Get all pets for current user
    func getPets() async throws -> [Pet] {
        guard let url = URL(string: "\(baseURL)/pets/") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: [Pet].self)
    }
    
    /// Get specific pet
    func getPet(id: String) async throws -> Pet {
        guard let url = URL(string: "\(baseURL)/pets/\(id)") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: Pet.self)
    }
    
    /// Update pet profile
    func updatePet(id: String, petUpdate: PetUpdate) async throws -> Pet {
        guard let url = URL(string: "\(baseURL)/pets/\(id)") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "PUT")
        
        do {
            request.httpBody = try createJSONEncoder().encode(petUpdate)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: Pet.self)
    }
    
    /// Delete pet profile
    func deletePet(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/pets/\(id)") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url, method: "DELETE")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return // Success
                case 401:
                    throw APIError.authenticationError
                case 400...499:
                    throw APIError.serverError(httpResponse.statusCode)
                case 500...599:
                    throw APIError.serverError(httpResponse.statusCode)
                default:
                    throw APIError.unknownError
                }
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Scan Endpoints

extension APIService {
    /// Create a new scan
    func createScan(_ scan: ScanCreate) async throws -> Scan {
        guard let url = URL(string: "\(baseURL)/scans/") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try createJSONEncoder().encode(scan)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: Scan.self)
    }
    
    /// Analyze scan text
    func analyzeScan(_ analysisRequest: ScanAnalysisRequest) async throws -> Scan {
        guard let url = URL(string: "\(baseURL)/scans/analyze") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try createJSONEncoder().encode(analysisRequest)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: Scan.self)
    }
    
    /// Get user's scans
    func getScans(petId: String? = nil) async throws -> [Scan] {
        var urlString = "\(baseURL)/scans/"
        if let petId = petId {
            urlString += "?pet_id=\(petId)"
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: [Scan].self)
    }
    
    /// Get specific scan
    func getScan(id: String) async throws -> Scan {
        guard let url = URL(string: "\(baseURL)/scans/\(id)") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: Scan.self)
    }
}

// MARK: - Ingredient Endpoints

extension APIService {
    /// Analyze ingredients for a pet
    func analyzeIngredients(
        ingredients: [String],
        petSpecies: PetSpecies,
        petAllergies: [String] = []
    ) async throws -> [IngredientAnalysis] {
        guard let url = URL(string: "\(baseURL)/ingredients/analyze") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        let analysisData: [String: Any] = [
            "ingredients": ingredients,
            "pet_species": petSpecies.rawValue,
            "pet_allergies": petAllergies
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: analysisData)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: [IngredientAnalysis].self)
    }
    
    /// Get common allergens
    func getCommonAllergens() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/ingredients/common-allergens") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: [String].self)
    }
    
    /// Get safe alternatives
    func getSafeAlternatives() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/ingredients/safe-alternatives") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: [String].self)
    }
}

// MARK: - MFA Endpoints

extension APIService {
    /// Setup MFA for current user
    func setupMFA() async throws -> MFASetupResponse {
        guard let url = URL(string: "\(baseURL)/mfa/setup") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url, method: "POST")
        return try await performRequest(request, responseType: MFASetupResponse.self)
    }
    
    /// Enable MFA with verification token
    func enableMFA(token: String) async throws {
        guard let url = URL(string: "\(baseURL)/mfa/enable") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        let mfaData = ["token": token]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: mfaData)
        } catch {
            throw APIError.encodingError
        }
        
        let _: [String: String] = try await performRequest(request, responseType: [String: String].self)
    }
    
    /// Verify MFA token
    func verifyMFA(token: String) async throws {
        guard let url = URL(string: "\(baseURL)/mfa/verify") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        let mfaData = ["token": token]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: mfaData)
        } catch {
            throw APIError.encodingError
        }
        
        let _: [String: String] = try await performRequest(request, responseType: [String: String].self)
    }
    
    /// Get MFA status
    func getMFAStatus() async throws -> MFAStatus {
        guard let url = URL(string: "\(baseURL)/mfa/status") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: MFAStatus.self)
    }
}

// MARK: - GDPR Endpoints

extension APIService {
    /// Export user data
    func exportUserData() async throws -> Data {
        guard let url = URL(string: "\(baseURL)/gdpr/export") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
    
    /// Delete user data
    func deleteUserData() async throws {
        guard let url = URL(string: "\(baseURL)/gdpr/delete") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url, method: "DELETE")
        let _: [String: String] = try await performRequest(request, responseType: [String: String].self)
    }
    
    /// Get data retention information
    func getDataRetentionInfo() async throws -> DataRetentionInfo {
        guard let url = URL(string: "\(baseURL)/gdpr/retention") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: DataRetentionInfo.self)
    }
    
    /// Get data subject rights information
    func getDataSubjectRights() async throws -> DataSubjectRights {
        guard let url = URL(string: "\(baseURL)/gdpr/rights") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: DataSubjectRights.self)
    }
}

// MARK: - Monitoring Endpoints

extension APIService {
    /// Get system health status
    func getHealthStatus() async throws -> HealthStatus {
        guard let url = URL(string: "\(baseURL)/monitoring/health") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: HealthStatus.self)
    }
    
    /// Get system metrics
    func getMetrics(hours: Int = 24) async throws -> SystemMetrics {
        guard let url = URL(string: "\(baseURL)/monitoring/metrics?hours=\(hours)") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: SystemMetrics.self)
    }
    
    /// Get system status
    func getSystemStatus() async throws -> SystemStatus {
        guard let url = URL(string: "\(baseURL)/monitoring/status") else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(url: url)
        return try await performRequest(request, responseType: SystemStatus.self)
    }
}

