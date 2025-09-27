//
//  APIService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/// Main API service for communicating with the backend
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = "http://localhost:8000/api/v1"
    private var authToken: String?
    
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
    
    /// Perform network request with error handling
    private func performRequest<T: Codable>(_ request: URLRequest, responseType: T.Type) -> AnyPublisher<T, APIError> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Authentication Endpoints

extension APIService {
    /// Register a new user
    func register(user: UserCreate) -> AnyPublisher<AuthResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try JSONEncoder().encode(user)
        } catch {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return performRequest(request, responseType: AuthResponse.self)
    }
    
    /// Login user
    func login(email: String, password: String) -> AnyPublisher<AuthResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = createRequest(url: url, method: "POST")
        
        let loginData = ["email": email, "password": password]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return performRequest(request, responseType: AuthResponse.self)
    }
    
    /// Get current user information
    func getCurrentUser() -> AnyPublisher<User, APIError> {
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = createRequest(url: url)
        return performRequest(request, responseType: User.self)
    }
    
    /// Update current user
    func updateUser(_ userUpdate: UserUpdate) -> AnyPublisher<User, APIError> {
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = createRequest(url: url, method: "PUT")
        
        do {
            request.httpBody = try JSONEncoder().encode(userUpdate)
        } catch {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return performRequest(request, responseType: User.self)
    }
}

// MARK: - Pet Endpoints

extension APIService {
    /// Create a new pet profile
    func createPet(_ pet: PetCreate) -> AnyPublisher<Pet, APIError> {
        guard let url = URL(string: "\(baseURL)/pets/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try JSONEncoder().encode(pet)
        } catch {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return performRequest(request, responseType: Pet.self)
    }
    
    /// Get all pets for current user
    func getPets() -> AnyPublisher<[Pet], APIError> {
        guard let url = URL(string: "\(baseURL)/pets/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = createRequest(url: url)
        return performRequest(request, responseType: [Pet].self)
    }
    
    /// Get specific pet
    func getPet(id: String) -> AnyPublisher<Pet, APIError> {
        guard let url = URL(string: "\(baseURL)/pets/\(id)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = createRequest(url: url)
        return performRequest(request, responseType: Pet.self)
    }
    
    /// Update pet profile
    func updatePet(id: String, petUpdate: PetUpdate) -> AnyPublisher<Pet, APIError> {
        guard let url = URL(string: "\(baseURL)/pets/\(id)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = createRequest(url: url, method: "PUT")
        
        do {
            request.httpBody = try JSONEncoder().encode(petUpdate)
        } catch {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return performRequest(request, responseType: Pet.self)
    }
    
    /// Delete pet profile
    func deletePet(id: String) -> AnyPublisher<Void, APIError> {
        guard let url = URL(string: "\(baseURL)/pets/\(id)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = createRequest(url: url, method: "DELETE")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { _ in () }
            .mapError { error in
                APIError.networkError(error.localizedDescription)
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Scan Endpoints

extension APIService {
    /// Create a new scan
    func createScan(_ scan: ScanCreate) -> AnyPublisher<Scan, APIError> {
        guard let url = URL(string: "\(baseURL)/scans/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try JSONEncoder().encode(scan)
        } catch {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return performRequest(request, responseType: Scan.self)
    }
    
    /// Analyze scan text
    func analyzeScan(_ analysisRequest: ScanAnalysisRequest) -> AnyPublisher<Scan, APIError> {
        guard let url = URL(string: "\(baseURL)/scans/analyze") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try JSONEncoder().encode(analysisRequest)
        } catch {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return performRequest(request, responseType: Scan.self)
    }
    
    /// Get user's scans
    func getScans(petId: String? = nil) -> AnyPublisher<[Scan], APIError> {
        var urlString = "\(baseURL)/scans/"
        if let petId = petId {
            urlString += "?pet_id=\(petId)"
        }
        
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = createRequest(url: url)
        return performRequest(request, responseType: [Scan].self)
    }
    
    /// Get specific scan
    func getScan(id: String) -> AnyPublisher<Scan, APIError> {
        guard let url = URL(string: "\(baseURL)/scans/\(id)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = createRequest(url: url)
        return performRequest(request, responseType: Scan.self)
    }
}

// MARK: - Ingredient Endpoints

extension APIService {
    /// Analyze ingredients for a pet
    func analyzeIngredients(
        ingredients: [String],
        petSpecies: PetSpecies,
        petAllergies: [String] = []
    ) -> AnyPublisher<[IngredientAnalysis], APIError> {
        guard let url = URL(string: "\(baseURL)/ingredients/analyze") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
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
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return performRequest(request, responseType: [IngredientAnalysis].self)
    }
    
    /// Get common allergens
    func getCommonAllergens() -> AnyPublisher<[String], APIError> {
        guard let url = URL(string: "\(baseURL)/ingredients/common-allergens") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = createRequest(url: url)
        return performRequest(request, responseType: [String].self)
    }
    
    /// Get safe alternatives
    func getSafeAlternatives() -> AnyPublisher<[String], APIError> {
        guard let url = URL(string: "\(baseURL)/ingredients/safe-alternatives") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = createRequest(url: url)
        return performRequest(request, responseType: [String].self)
    }
}
