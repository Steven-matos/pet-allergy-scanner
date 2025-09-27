//
//  APIService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Security

/// Main API service for communicating with the backend using Swift Concurrency
@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "http://localhost:8000/api/v1"
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
    
    /// Create URL request with authentication headers
    private func createRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
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
                    throw APIError.authenticationError
                case 400...499:
                    // Try to decode error response
                    if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        throw APIError.serverMessage(errorResponse.message)
                    }
                    throw APIError.serverError(httpResponse.statusCode)
                case 500...599:
                    throw APIError.serverError(httpResponse.statusCode)
                default:
                    throw APIError.unknownError
                }
            }
            
            // Decode successful response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
            
        } catch let error as APIError {
            throw error
        } catch {
            if error is DecodingError {
                throw APIError.decodingError
            } else {
                throw APIError.networkError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Authentication Endpoints

extension APIService {
    /// Register a new user
    func register(user: UserCreate) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try JSONEncoder().encode(user)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: AuthResponse.self)
    }
    
    /// Login user
    func login(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw APIError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        
        let loginData = ["email": email, "password": password]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: AuthResponse.self)
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
            request.httpBody = try JSONEncoder().encode(userUpdate)
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
            request.httpBody = try JSONEncoder().encode(pet)
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
            request.httpBody = try JSONEncoder().encode(petUpdate)
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
            request.httpBody = try JSONEncoder().encode(scan)
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
            request.httpBody = try JSONEncoder().encode(analysisRequest)
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
        
        let analysisData = [
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

