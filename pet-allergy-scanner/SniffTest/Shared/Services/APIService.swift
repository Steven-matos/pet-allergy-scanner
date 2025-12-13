//
//  APIService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Security

/// Empty response model for API calls that don't return data
struct EmptyResponse: Codable {}

/// Protocol to help handle optional types at runtime
private protocol AnyOptional {
    static var nilValue: Any { get }
}

extension Optional: AnyOptional {
    static var nilValue: Any {
        return Optional<Wrapped>.none as Any
    }
}

/// Main API service for communicating with the backend using Swift Concurrency
/// Enhanced with URLSession-level caching for optimal performance
@MainActor
class APIService: ObservableObject, @unchecked Sendable {
    static let shared = APIService()
    
    private let baseURL = Configuration.apiBaseURL
    private let authTokenKey = "authToken"
    private let refreshTokenKey = "refreshToken"
    private let tokenExpiryKey = "tokenExpiry"
    private var _authToken: String?
    private var _refreshToken: String?
    private var _tokenExpiry: Date?
    private let authTokenQueue = DispatchQueue(label: "authToken", qos: .userInitiated)
    private var isRefreshing = false
    private var refreshTask: Task<Void, Error>?
    
    /// Use cached URLSession from UnifiedCacheCoordinator for HTTP-level caching
    private var urlSession: URLSession {
        return UnifiedCacheCoordinator.shared.cachedURLSession
    }
    
    /// Get authentication token asynchronously
    private var authToken: String? {
        get async {
            if let token = _authToken {
                return token
            }
            return await KeychainHelper.read(forKey: authTokenKey)
        }
    }
    
    /// Get refresh token asynchronously
    private var refreshToken: String? {
        get async {
            if let token = _refreshToken {
                return token
            }
            return await KeychainHelper.read(forKey: refreshTokenKey)
        }
    }
    
    /// Get token expiry date
    var tokenExpiry: Date? {
        get async {
            if let expiry = _tokenExpiry {
                return expiry
            }
            if let expiryString = await KeychainHelper.read(forKey: tokenExpiryKey),
               let expiryTimestamp = Double(expiryString) {
                return Date(timeIntervalSince1970: expiryTimestamp)
            }
            return nil
        }
    }
    
    /// Set authentication token asynchronously
    private func setAuthTokenInternal(_ token: String?) async {
        _authToken = token
        if let token = token {
            await KeychainHelper.save(token, forKey: authTokenKey)
        } else {
            await KeychainHelper.delete(forKey: authTokenKey)
        }
    }
    
    /// Set refresh token asynchronously
    private func setRefreshTokenInternal(_ token: String?) async {
        _refreshToken = token
        if let token = token {
            await KeychainHelper.save(token, forKey: refreshTokenKey)
        } else {
            await KeychainHelper.delete(forKey: refreshTokenKey)
        }
    }
    
    /// Set token expiry date
    private func setTokenExpiryInternal(_ expiry: Date?) async {
        _tokenExpiry = expiry
        if let expiry = expiry {
            let expiryString = String(expiry.timeIntervalSince1970)
            await KeychainHelper.save(expiryString, forKey: tokenExpiryKey)
        } else {
            await KeychainHelper.delete(forKey: tokenExpiryKey)
        }
    }
    
    /// Check if user has authentication token
    var hasAuthToken: Bool {
        get async {
            let token = await authToken
            let hasToken = token != nil
            #if DEBUG
            print("🔐 APIService: hasAuthToken = \(hasToken)")
            #endif
            return hasToken
        }
    }
    
    private init() {}
    
    /// Set authentication token for API requests
    /// Only saves if tokens have actually changed to avoid unnecessary keychain writes
    func setAuthToken(_ token: String, refreshToken: String? = nil, expiresIn: Int? = nil) async {
        // Check if token is already set to avoid unnecessary saves
        let currentToken = await authToken
        let currentRefreshTokenValue = await self.refreshToken
        let currentExpiry = await tokenExpiry
        
        // Calculate new expiry
        let newExpiry: Date
        if let expiresIn = expiresIn {
            newExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            newExpiry = Date().addingTimeInterval(30 * 24 * 60 * 60) // Default to 30 days
        }
        
        // Only save if tokens have changed
        let tokenChanged = currentToken != token
        let refreshTokenChanged = refreshToken != nil && currentRefreshTokenValue != refreshToken
        let expiryChanged = abs((currentExpiry?.timeIntervalSince1970 ?? 0) - newExpiry.timeIntervalSince1970) > 60 // 1 minute tolerance
        
        guard tokenChanged || refreshTokenChanged || expiryChanged else {
            #if DEBUG
            print("🔐 APIService: Tokens unchanged - skipping save")
            #endif
            return
        }
        
        #if DEBUG
        print("🔐 APIService: Setting auth token")
        #endif
        await setAuthTokenInternal(token)
        
        if let refreshToken = refreshToken {
            #if DEBUG
            print("🔐 APIService: Setting refresh token (length: \(refreshToken.count) chars)")
            #endif
            await setRefreshTokenInternal(refreshToken)
        } else {
            #if DEBUG
            let existingRefreshToken = await self.refreshToken
            if existingRefreshToken != nil {
                print("ℹ️ APIService: No refresh token provided - preserving existing refresh token in keychain")
            } else {
                print("⚠️ APIService: No refresh token provided and none exists - token refresh will not be possible")
            }
            #endif
        }
        
        if let expiresIn = expiresIn {
            // Set expiry to expiresIn seconds from now
            await setTokenExpiryInternal(newExpiry)
            #if DEBUG
            print("🔐 APIService: Token expires in \(expiresIn) seconds")
            #endif
        } else {
            // Default to 30 days if no expiry provided
            await setTokenExpiryInternal(newExpiry)
            #if DEBUG
            print("🔐 APIService: Token expires in 30 days (default)")
            #endif
        }
        
        // Verify all tokens are accessible after saving (only once to reduce logging)
        #if DEBUG
        let verification = await KeychainHelper.verifyAuthTokens()
        let allAccessible = verification.values.allSatisfy { $0 }
        if allAccessible {
            print("✅ APIService: All auth tokens verified and accessible in keychain")
        } else {
            print("⚠️ APIService: Some auth tokens may not be accessible:")
            for (key, accessible) in verification where !accessible {
                print("   - \(key): NOT accessible")
            }
        }
        #endif
    }
    
    /// Clear authentication token
    func clearAuthToken() async {
        await setAuthTokenInternal(nil)
        await setRefreshTokenInternal(nil)
        await setTokenExpiryInternal(nil)
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
    }
    
    /// Check if token needs refresh (refresh 1 hour before expiry or if already expired)
    private func shouldRefreshToken() async -> Bool {
        guard let expiry = await tokenExpiry else {
            // If no expiry stored, check if we have a refresh token and try refresh
            return await refreshToken != nil
        }
        
        // Refresh if token expires in less than 1 hour OR already expired
        let refreshThreshold = Date().addingTimeInterval(60 * 60) // 1 hour
        return expiry < refreshThreshold
    }
    
    /// Refresh authentication token using refresh token
    /// This works even when access token is expired (up to 30 days)
    func refreshAuthToken() async throws {
        // Prevent multiple simultaneous refresh attempts
        if isRefreshing {
            // Wait for existing refresh to complete
            try await refreshTask?.value
            return
        }
        
        isRefreshing = true
        
        let task = Task<Void, Error> {
            // Check if refresh token exists before attempting refresh
            guard let refreshToken = await self.refreshToken else {
                #if DEBUG
                print("❌ APIService: Cannot refresh - no refresh token found in keychain")
                #endif
                self.isRefreshing = false
                throw APIError.authenticationError
            }
            
            #if DEBUG
            print("🔐 APIService: Attempting token refresh with refresh token (length: \(refreshToken.count) chars)")
            #endif
            
            guard let url = URL(string: "\(baseURL)/auth/refresh/") else {
                self.isRefreshing = false
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("iOS", forHTTPHeaderField: "User-Agent")
            request.setValue("1.0.0", forHTTPHeaderField: "X-Client-Version")
            
            // Send refresh token in request body
            let refreshData = ["refresh_token": refreshToken]
            request.httpBody = try JSONSerialization.data(withJSONObject: refreshData)
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.isRefreshing = false
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                // Try to parse error response for better debugging
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    #if DEBUG
                    print("⚠️ APIService: Refresh failed with error: \(errorResponse.detail)")
                    #endif
                }
                
                // Refresh token is invalid or expired (older than 30 days)
                // Only clear tokens if it's a 401/403 error, not other errors (like network errors)
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    #if DEBUG
                    print("⚠️ APIService: Refresh token expired or invalid (status: \(httpResponse.statusCode)) - clearing tokens")
                    #endif
                    await self.clearAuthToken()
                    self.isRefreshing = false
                    throw APIError.authenticationError
                } else {
                    // For other errors (network, server errors), don't clear tokens
                    // The token might still be valid, just the refresh endpoint had an issue
                    #if DEBUG
                    print("⚠️ APIService: Refresh failed with status \(httpResponse.statusCode) - keeping tokens")
                    #endif
                    self.isRefreshing = false
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            
            // Parse response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let authResponse = try decoder.decode(AuthResponse.self, from: data)
            
            // Check if refresh token was returned - if not, preserve existing one
            let refreshTokenToSave = authResponse.refreshToken
            if refreshTokenToSave == nil {
                #if DEBUG
                let existingRefreshToken = await self.refreshToken
                if existingRefreshToken != nil {
                    print("⚠️ APIService: Server did not return refresh token - preserving existing refresh token")
                } else {
                    print("⚠️ APIService: Server did not return refresh token and none exists - future refreshes may fail")
                }
                #endif
            } else {
                #if DEBUG
                print("✅ APIService: Server returned new refresh token - will save to keychain")
                #endif
            }
            
            // Store new tokens with proper expiry
            // Supabase tokens typically expire in 3600 seconds (1 hour)
            // But refresh tokens last 30 days, so we'll refresh every hour automatically
            // CRITICAL: Always pass refresh token from response to ensure we save the new rotated refresh token
            // If server doesn't return one, preserve existing refresh token (handled in setAuthToken)
            let existingRefreshToken = await self.refreshToken
            let finalRefreshToken = refreshTokenToSave ?? existingRefreshToken
            
            if finalRefreshToken == nil {
                #if DEBUG
                print("❌ APIService: CRITICAL - No refresh token available after refresh! Future refreshes will fail.")
                #endif
            }
            
            await self.setAuthToken(
                authResponse.accessToken,
                refreshToken: refreshTokenToSave, // Pass the new refresh token if provided, nil otherwise
                expiresIn: authResponse.expiresIn ?? 3600 // Default to 1 hour if not provided
            )
            
            // Verify refresh token was saved correctly after refresh
            #if DEBUG
            let savedRefreshToken = await self.refreshToken
            if savedRefreshToken != nil {
                print("✅ APIService: Refresh successful - refresh token saved to keychain (length: \(savedRefreshToken?.count ?? 0) chars)")
                if let refreshTokenToSave = refreshTokenToSave, refreshTokenToSave != savedRefreshToken {
                    print("⚠️ APIService: WARNING - Refresh token from server doesn't match saved token!")
                }
            } else {
                print("❌ APIService: CRITICAL - Refresh token NOT saved to keychain after successful refresh!")
            }
            #endif
            
            self.isRefreshing = false
        }
        
        refreshTask = task
        try await task.value
    }
    
    // MARK: - Push Notification Methods
    
    /// Register device token with the server for push notifications
    /// - Parameter deviceToken: The device token to register
    func registerDeviceToken(_ deviceToken: String) async throws {
        // Try authenticated endpoint first if we have a token
        if await authToken != nil {
            do {
                try await registerDeviceTokenAuthenticated(deviceToken)
                return
            } catch {
                // Continue to anonymous registration
            }
        }
        
        // Fall back to anonymous endpoint
        try await registerDeviceTokenAnonymous(deviceToken)
    }
    
    /// Register device token with authentication
    /// - Parameter deviceToken: The device token to register
    private func registerDeviceTokenAuthenticated(_ deviceToken: String) async throws {
        guard let url = URL(string: "\(baseURL)/notifications/register-device") else {
            throw APIError.invalidURL
        }
        
        let payload = ["device_token": deviceToken]
        let requestData = try JSONSerialization.data(withJSONObject: payload)
        
        let request = await createRequest(url: url, method: "POST", body: requestData)
        
        
        let (_, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Register device token anonymously (before authentication)
    /// - Parameter deviceToken: The device token to register
    private func registerDeviceTokenAnonymous(_ deviceToken: String) async throws {
        guard let url = URL(string: "\(baseURL)/notifications/register-device-anonymous") else {
            throw APIError.invalidURL
        }
        
        let payload = ["device_token": deviceToken]
        let requestData = try JSONSerialization.data(withJSONObject: payload)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("1.0.0", forHTTPHeaderField: "X-Client-Version")
        request.httpBody = requestData
        
        
        let (_, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Send push notification via server
    /// - Parameters:
    ///   - payload: Notification payload
    ///   - deviceToken: Target device token
    func sendPushNotification(payload: [String: Any], deviceToken: String) async throws {
        let url = URL(string: "\(baseURL)/notifications/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Ensure delay is an integer if present
        var sanitizedPayload = payload
        if let delayValue = payload["delay"] {
            if let delayDouble = delayValue as? Double {
                sanitizedPayload["delay"] = Int(delayDouble)
            } else if let delayInt = delayValue as? Int {
                sanitizedPayload["delay"] = delayInt
            }
        }
        
        let requestPayload: [String: Any] = [
            "device_token": deviceToken,
            "payload": sanitizedPayload
        ]
        
        // Validate request payload before sending
        guard !deviceToken.isEmpty else {
            throw APIError.serverMessage("device_token cannot be empty")
        }
        
        guard !sanitizedPayload.isEmpty else {
            throw APIError.serverMessage("payload cannot be empty")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestPayload)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            // Log response body for debugging
            if let responseBody = String(data: data, encoding: .utf8) {
                print("❌ Push notification error (\(httpResponse.statusCode)): \(responseBody)")
            }
            
            if httpResponse.statusCode == 422 {
                // Parse validation error details from FastAPI
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw APIError.serverMessage(errorResponse.detail)
                } else if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Try to extract error details from response
                    if let detail = errorData["detail"] as? String {
                        throw APIError.serverMessage(detail)
                    } else if let message = errorData["message"] as? String {
                        throw APIError.serverMessage(message)
                    } else if let errors = errorData["errors"] as? [[String: Any]] {
                        // Parse Pydantic validation errors
                        let errorMessages = errors.compactMap { error -> String? in
                            guard let loc = error["loc"] as? [String], let msg = error["msg"] as? String else {
                                return nil
                            }
                            return "\(loc.joined(separator: ".")): \(msg)"
                        }
                        throw APIError.serverMessage(errorMessages.joined(separator: "; "))
                    }
                }
            }
            
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Cancel all push notifications for the current user
    func cancelAllPushNotifications() async throws {
        let url = URL(string: "\(baseURL)/notifications/cancel-all")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Get current authentication token
    /// - Returns: The current auth token or nil if not set
    func getAuthToken() async -> String? {
        return await authToken
    }
    
    /// Ensure token is valid by refreshing if needed
    /// This is called when app becomes active to maintain session
    func ensureValidToken() async {
        // Check if we have any tokens
        guard await hasAuthToken else {
            #if DEBUG
            print("🔐 APIService: No auth token found - skipping token refresh")
            #endif
            return
        }
        
        // Check if we have a refresh token before attempting refresh
        let hasRefreshToken = await self.refreshToken != nil
        guard hasRefreshToken else {
            #if DEBUG
            print("🔐 APIService: No refresh token found - cannot refresh")
            #endif
            return
        }
        
        // Refresh token if it's about to expire or already expired
        if await shouldRefreshToken() {
            do {
                try await refreshAuthToken()
                #if DEBUG
                print("✅ APIService: Token refreshed successfully on app activation")
                #endif
            } catch {
                // If refresh fails, log but don't clear tokens here
                // The refresh endpoint will handle clearing if refresh token is expired
                #if DEBUG
                print("⚠️ APIService: Failed to refresh token on app activation: \(error)")
                print("   This may be normal if refresh token is expired (>30 days)")
                #endif
            }
        } else {
            #if DEBUG
            print("ℹ️ APIService: Token is still valid - no refresh needed")
            #endif
        }
    }
    
    /// Debug method to check authentication state
    func debugAuthState() async {
        let _ = await authToken
        let _ = await refreshToken
        let _ = await tokenExpiry
        let _ = await hasAuthToken
        
    }
    
    /// Test method to verify authentication is working
    func testAuthentication() async throws {
        // Check if we have a token
        let hasToken = await hasAuthToken
        
        if !hasToken {
            throw APIError.authenticationError
        }
        
        // Try to get current user to verify token is valid
        do {
            let _ = try await getCurrentUser()
        } catch {
            throw error
        }
    }
    
    // MARK: - Generic HTTP Methods
    
    /**
     * Generic GET request method
     * - Parameter endpoint: The API endpoint to call
     * - Parameter bypassCache: If true, ignores local cache and fetches fresh data
     * - Returns: Decoded response of type T
     */
    func get<T: Codable>(endpoint: String, responseType: T.Type, bypassCache: Bool = false) async throws -> T {
        let fullURLString = "\(baseURL)\(endpoint)"
        guard let url = URL(string: fullURLString) else {
            print("❌ [APIService.get] Invalid URL: \(fullURLString)")
            throw APIError.invalidURL
        }
        
        // Log health events requests for debugging
        if endpoint.contains("health-events") {
            print("🌐 [APIService.get] Making GET request:")
            print("   Full URL: \(fullURLString)")
            print("   Endpoint: \(endpoint)")
            print("   Base URL: \(baseURL)")
        }
        
        let request = await createRequest(url: url, bypassCache: bypassCache)
        
        // Log request details for health events
        if endpoint.contains("health-events") {
            if let httpMethod = request.httpMethod {
                print("   HTTP Method: \(httpMethod)")
            }
            if let headers = request.allHTTPHeaderFields {
                print("   Headers: \(headers.keys.joined(separator: ", "))")
                if let authHeader = headers["Authorization"] {
                    print("   Authorization: \(authHeader.prefix(20))...")
                } else {
                    print("   ⚠️ WARNING: No Authorization header found!")
                }
            }
            print("   Request URL: \(request.url?.absoluteString ?? "nil")")
        }
        
        do {
            return try await performRequest(request, responseType: T.self)
        } catch {
            // Enhanced error logging for health events
            if endpoint.contains("health-events") {
                print("❌ [APIService.get] Health events request failed:")
                print("   URL: \(fullURLString)")
                print("   Error: \(error)")
                if let urlError = error as? URLError {
                    print("   URLError code: \(urlError.code.rawValue)")
                    print("   URLError description: \(urlError.localizedDescription)")
                }
            }
            throw error
        }
    }
    
    /**
     * Generic POST request method
     * - Parameter endpoint: The API endpoint to call
     * - Parameter body: The request body to send
     * - Returns: Decoded response of type T
     */
    func post<T: Codable, U: Codable>(endpoint: String, body: T, responseType: U.Type) async throws -> U {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try createJSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: U.self)
    }
    
    /**
     * Generic POST request method with no body
     * - Parameter endpoint: The API endpoint to call
     * - Returns: Decoded response of type T
     */
    func post<T: Codable>(endpoint: String, responseType: T.Type) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url, method: "POST")
        return try await performRequest(request, responseType: T.self)
    }
    
    /**
     * Generic PUT request method
     * - Parameter endpoint: The API endpoint to call
     * - Parameter body: The request body to send
     * - Returns: Decoded response of type T
     */
    func put<T: Codable, U: Codable>(endpoint: String, body: T, responseType: U.Type) async throws -> U {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "PUT")
        
        do {
            request.httpBody = try createJSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: U.self)
    }
    
    /**
     * Generic DELETE request method
     * - Parameter endpoint: The API endpoint to call
     */
    func delete(endpoint: String) async throws {
        // Ensure endpoint starts with / if baseURL doesn't end with /
        let normalizedEndpoint = endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)"
        let fullURLString = baseURL.hasSuffix("/") ? "\(baseURL.dropLast())\(normalizedEndpoint)" : "\(baseURL)\(normalizedEndpoint)"
        
        guard let url = URL(string: fullURLString) else {
            print("❌ [APIService] Invalid URL: baseURL=\(baseURL), endpoint=\(endpoint), fullURL=\(fullURLString)")
            throw APIError.invalidURL
        }
        
        // Log the delete request for debugging
        print("🗑️ [APIService] DELETE request to: \(baseURL)\(normalizedEndpoint)")
        print("🗑️ [APIService] Full URL: \(url.absoluteString)")
        
        let request = await createRequest(url: url, method: "DELETE")
        
        // Log request details
        print("🗑️ [APIService] Request method: \(request.httpMethod ?? "unknown")")
        print("🗑️ [APIService] Request URL: \(request.url?.absoluteString ?? "unknown")")
        print("🗑️ [APIService] Has Authorization header: \(request.value(forHTTPHeaderField: "Authorization") != nil)")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🗑️ [APIService] Response status: \(httpResponse.statusCode)")
                
                // Log response body for 404 errors to help debug
                if httpResponse.statusCode == 404 {
                    if let responseBody = String(data: data, encoding: .utf8) {
                        print("🗑️ [APIService] 404 Response body: \(responseBody)")
                    }
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    print("🗑️ [APIService] DELETE successful")
                    return // Success
                case 401:
                    print("🗑️ [APIService] DELETE failed: Authentication error")
                    throw APIError.authenticationError
                case 404:
                    // Try to parse error message from response
                    if let errorResponse = try? createJSONDecoder().decode(APIErrorResponse.self, from: data) {
                        print("🗑️ [APIService] DELETE 404 error: \(errorResponse.detail)")
                        throw APIError.serverMessage("Server error: \(errorResponse.detail)")
                    } else if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let detail = errorDict["detail"] as? String {
                        print("🗑️ [APIService] DELETE 404 error: \(detail)")
                        throw APIError.serverMessage("Server error: \(detail)")
                    } else {
                        print("🗑️ [APIService] DELETE failed: Not found (404)")
                        throw APIError.serverMessage("Server error: 404")
                    }
                case 400...499:
                    print("🗑️ [APIService] DELETE failed: Client error \(httpResponse.statusCode)")
                    throw APIError.serverError(httpResponse.statusCode)
                case 500...599:
                    print("🗑️ [APIService] DELETE failed: Server error \(httpResponse.statusCode)")
                    throw APIError.serverError(httpResponse.statusCode)
                default:
                    print("🗑️ [APIService] DELETE failed: Unknown error")
                    throw APIError.unknownError
                }
            }
        } catch let error as APIError {
            print("🗑️ [APIService] DELETE failed with APIError: \(error)")
            throw error
        } catch {
            print("🗑️ [APIService] DELETE failed with error: \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
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
            
            // Try ISO8601 format first (with time)
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // Try simple date format (YYYY-MM-DD)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        return decoder
    }
    
    /// Create URL request with authentication headers and security features
    private func createRequest(url: URL, method: String = "GET", body: Data? = nil, bypassCache: Bool = false) async -> URLRequest {
        // Check if token needs refresh before making the request
        if await shouldRefreshToken() {
            do {
                try await refreshAuthToken()
            } catch {
                // Continue with existing token, let the request fail if needed
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("1.0.0", forHTTPHeaderField: "X-Client-Version")
        
        // Add security headers
        request.setValue("en-US", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        // CRITICAL: Bypass cache for dynamic data endpoints (weight, goals, health events, etc.)
        // Health events are always dynamic and should never be cached
        if bypassCache || url.absoluteString.contains("health-events") {
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
            request.setValue("must-revalidate", forHTTPHeaderField: "Cache-Control")
            #if DEBUG
            if url.absoluteString.contains("health-events") {
                print("🚫 APIService: Cache bypassed for health-events endpoint (always fresh)")
            } else {
                print("🚫 APIService: Cache bypassed for fresh data")
            }
            #endif
        }
        
        // Add authorization header
        let token = await authToken
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            print("🔐 APIService: Authorization header added")
            #endif
        } else {
            #if DEBUG
            // Only log warning for endpoints that require auth (not registration/login endpoints)
            let requiresAuth = !url.absoluteString.contains("/auth/register") && 
                              !url.absoluteString.contains("/auth/login") &&
                              !url.absoluteString.contains("/auth/reset-password") &&
                              !url.absoluteString.contains("/notifications/register-device-anonymous")
            if requiresAuth {
                print("⚠️ APIService: No auth token available for request")
            }
            #endif
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        // Set timeout for security
        request.timeoutInterval = 30.0
        
        
        return request
    }
    
    /// Perform network request with error handling using async/await
    /// Uses cached URLSession for HTTP-level caching
    private func performRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        do {
            // Use cached URLSession which has URLCache configured
            let (data, response) = try await urlSession.data(for: request)
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    break // Success
                case 401:
                    // Try to refresh token before logging out
                    if await refreshToken != nil {
                        do {
                            try await refreshAuthToken()
                            // Retry the original request with new token
                            var retryRequest = request
                            if let newToken = await authToken {
                                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                            }
                            let (retryData, retryResponse) = try await urlSession.data(for: retryRequest)
                            if let retryHttpResponse = retryResponse as? HTTPURLResponse,
                               (200...299).contains(retryHttpResponse.statusCode) {
                                // Success after refresh, decode and return
                                let decoder = createJSONDecoder()
                                return try decoder.decode(T.self, from: retryData)
                            }
                        } catch {
                            // Refresh failed, continue to error handling
                        }
                    }
                    
                    // Try to decode error message from response
                    if let errorResponse = try? createJSONDecoder().decode(APIErrorResponse.self, from: data) {
                        // Clear invalid token only if this is a session/token error
                        if errorResponse.message.lowercased().contains("invalid authentication") ||
                           errorResponse.message.lowercased().contains("token") ||
                           errorResponse.message.lowercased().contains("expired") {
                            await clearAuthToken()
                        }
                        throw APIError.serverMessage(errorResponse.message)
                    }
                    // Fallback to generic authentication error
                    // Don't automatically clear tokens on generic 401 - let the caller decide
                    throw APIError.authenticationError
                case 403:
                    // Try to refresh token before treating as error
                    if await refreshToken != nil {
                        do {
                            try await refreshAuthToken()
                            // Retry the original request with new token
                            var retryRequest = request
                            if let newToken = await authToken {
                                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                            }
                            let (retryData, retryResponse) = try await urlSession.data(for: retryRequest)
                            if let retryHttpResponse = retryResponse as? HTTPURLResponse,
                               (200...299).contains(retryHttpResponse.statusCode) {
                                // Success after refresh, decode and return
                                let decoder = createJSONDecoder()
                                return try decoder.decode(T.self, from: retryData)
                            }
                        } catch {
                            // Refresh failed, continue to error handling
                        }
                    }
                    
                    // Check if this is an email verification error
                    // First, try to get the error message from the response
                    var errorMessage: String? = nil
                    
                    // Try decoding as APIErrorResponse first (has 'detail' field - FastAPI standard)
                    if let errorResponse = try? createJSONDecoder().decode(APIErrorResponse.self, from: data) {
                        errorMessage = errorResponse.detail
                    }
                    // Also check raw JSON for both 'error' and 'detail' fields (different error formats)
                    else if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Check 'error' field first (custom error handler format)
                        if let errorField = errorDict["error"] as? String {
                            errorMessage = errorField
                        }
                        // Fall back to 'detail' field (FastAPI HTTPException format)
                        else if let detailMessage = errorDict["detail"] as? String {
                            errorMessage = detailMessage
                        }
                    }
                    
                    // Check if it's an email verification error
                    if let message = errorMessage {
                        let lowerMessage = message.lowercased()
                        let isEmailVerificationError = lowerMessage.contains("verify your email") || 
                                                       lowerMessage.contains("check your email") ||
                                                       (lowerMessage.contains("email") && lowerMessage.contains("verification")) ||
                                                       (lowerMessage.contains("verify") && lowerMessage.contains("email"))
                        
                        if isEmailVerificationError {
                            throw APIError.emailNotVerified(message)
                        }
                    }
                    
                    // If we get here and it's a 403, log the response for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("⚠️ APIService: 403 error response (not email verification): \(responseString)")
                    }
                    throw APIError.authenticationError
                case 429:
                    // Rate limit exceeded
                    throw APIError.rateLimitExceeded
                case 404:
                    // Resource deleted - invalidate cache for this endpoint
                    await handle404Response(request: request)
                    // Try to decode error response
                    if let errorResponse = try? createJSONDecoder().decode(APIErrorResponse.self, from: data) {
                        throw APIError.serverMessage(errorResponse.message)
                    }
                    // Try to decode as generic error response
                    if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorDict["error"] as? String) ?? (errorDict["detail"] as? String) {
                        throw APIError.serverMessage(errorMessage)
                    }
                    throw APIError.serverError(httpResponse.statusCode)
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
                    // Try to extract error message from 5xx responses too
                    if let errorResponse = try? createJSONDecoder().decode(APIErrorResponse.self, from: data) {
                        throw APIError.serverMessage(errorResponse.message)
                    }
                    if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorDict["error"] as? String) ?? (errorDict["detail"] as? String) {
                        throw APIError.serverMessage(errorMessage)
                    }
                    throw APIError.serverError(httpResponse.statusCode)
                default:
                    throw APIError.unknownError
                }
            }
            
            // Decode successful response
            let decoder = createJSONDecoder()
            let responseString = String(data: data, encoding: .utf8) ?? ""
            
            // Handle null responses for optional types
            let trimmedResponse = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedResponse == "null" || data.isEmpty {
                // For optional types, Swift's JSONDecoder should handle null automatically
                // But we'll try to handle it explicitly if decoding fails
                print("📝 [APIService] Received null/empty response: '\(trimmedResponse)'")
            }
            
            do {
                let decoded = try decoder.decode(T.self, from: data)
                if trimmedResponse == "null" {
                    print("✅ [APIService] Successfully decoded null as optional type")
                }
                return decoded
            } catch let decodingError as DecodingError {
                // Log the raw response for debugging
                print("❌ [APIService] Decoding error. Response: '\(trimmedResponse)'")
                print("   Error: \(decodingError)")
                
                // If it's a null response, try to handle it for optional types
                if trimmedResponse == "null" {
                    if let optionalType = T.self as? AnyOptional.Type {
                        print("✅ [APIService] Returning nil for optional type from null response")
                        return optionalType.nilValue as! T
                    }
                }
                
                throw APIError.networkError("Failed to decode response: \(decodingError.localizedDescription)")
            } catch {
                // Log the raw response for debugging
                print("❌ [APIService] Unexpected error. Response: '\(trimmedResponse)'")
                print("   Error: \(error)")
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
    
    // MARK: - 404 Cache Invalidation Helpers
    
    /**
     * Handle 404 response by invalidating cache appropriately
     * - Parameter request: The request that returned 404
     * 
     * Note: Not all 404s mean "permanently deleted"
     * - Computed/aggregated data (daily summaries, trends) may return 404 when no source data exists
     * - These should be cleared from cache but not marked as "permanently deleted"
     * - Only permanent resources (pets, users) should be marked as deleted
     */
    private func handle404Response(request: URLRequest) async {
        guard let url = request.url else { return }
        
        let path = url.path
        let cacheCoordinator = UnifiedCacheCoordinator.shared
        
        // Don't treat subscription status 404s as deleted resources
        if path.contains("/subscriptions/status") {
            print("⚠️ [APIService] Subscription status endpoint returned 404 - not treating as deleted resource")
            return
        }
        
        // Don't treat computed/aggregated data 404s as permanently deleted
        // These are computed from source data and may not exist yet
        if path.contains("/nutrition/summaries") || path.contains("/nutrition/trends") {
            // Just invalidate cache - don't mark as permanently deleted
            // This allows re-checking when source data (meals, weights) is added
            if let resourceId = extractResourceId(from: path) {
                let cacheKey = inferCacheKey(from: path, resourceId: resourceId)
                await MainActor.run {
                    cacheCoordinator.invalidate(forKey: cacheKey)
                }
                print("🔄 [APIService] 404 for computed data - invalidated cache (will re-check when source data added): \(cacheKey)")
                return
            }
            return
        }
        
        // Don't treat food analysis 404s as permanently deleted
        // Food analyses may be missing temporarily or the ID might be incorrect
        // Feeding records reference them, so we should allow retry attempts
        if path.contains("/nutrition/analysis/food-analysis/") {
            // Just invalidate cache - don't mark as permanently deleted
            // This allows re-checking if the food analysis is recreated or ID is corrected
            if let resourceId = extractResourceId(from: path) {
                let cacheKey = inferCacheKey(from: path, resourceId: resourceId)
                await MainActor.run {
                    cacheCoordinator.invalidate(forKey: cacheKey)
                }
                print("🔄 [APIService] 404 for food analysis - invalidated cache (may be missing temporarily): \(cacheKey)")
            }
            return
        }
        
        // For permanent resources (pets, users, etc.), mark as deleted
        if let resourceId = extractResourceId(from: path) {
            let cacheKey = inferCacheKey(from: path, resourceId: resourceId)
            await MainActor.run {
                cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                print("🗑️ [APIService] 404 detected - marked as deleted resource: \(cacheKey)")
            }
        }
    }
    
    /**
     * Extract resource ID from URL path
     * - Parameter path: URL path (e.g., "/pets/123", "/nutrition/feeding/456")
     * - Returns: Resource ID if found
     */
    private func extractResourceId(from path: String) -> String? {
        // Common patterns: /pets/{id}, /nutrition/feeding/{id}, /pets/{id}/weight, etc.
        let components = path.split(separator: "/")
        
        // Look for UUID-like strings or numeric IDs
        for component in components.reversed() {
            let componentStr = String(component)
            // Check if it looks like a UUID or ID
            if componentStr.count >= 8 && (componentStr.contains("-") || componentStr.allSatisfy { $0.isNumber || $0.isLetter }) {
                return componentStr
            }
        }
        
        return nil
    }
    
    /**
     * Infer cache key from URL path and resource ID
     * - Parameters:
     *   - path: URL path
     *   - resourceId: Extracted resource ID
     * - Returns: Cache key for the resource
     */
    private func inferCacheKey(from path: String, resourceId: String) -> String {
        // Map URL patterns to cache keys
        if path.contains("/pets/") && !path.contains("/nutrition") && !path.contains("/weight") {
            return CacheKey.petDetails.scoped(forPetId: resourceId)
        } else if path.contains("/nutrition/feeding/") || path.contains("/nutrition/feeding/record/") {
            return CacheKey.feedingRecords.scoped(forPetId: resourceId)
        } else if path.contains("/nutrition/requirements/") {
            return CacheKey.nutritionRequirements.scoped(forPetId: resourceId)
        } else if path.contains("/nutrition/summaries/") {
            return CacheKey.dailySummaries.scoped(forPetId: resourceId)
        } else if path.contains("/weight/") || path.contains("/weight-records/") {
            return CacheKey.weightRecords.scoped(forPetId: resourceId)
        } else if path.contains("/weight-goals/") {
            return CacheKey.weightGoals.scoped(forPetId: resourceId)
        }
        
        // Fallback: use path as cache key
        return path.replacingOccurrences(of: "/", with: "_")
    }
}

// MARK: - Authentication Endpoints

extension APIService {
    /// Register a new user
    func register(user: UserCreate) async throws -> RegistrationResponse {
        guard let url = URL(string: "\(baseURL)/auth/register/") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try createJSONEncoder().encode(user)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: RegistrationResponse.self)
    }
    
    /// Login user
    func login(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/login/") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "POST")
        
        let loginData = ["email_or_username": email, "password": password]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            throw APIError.encodingError
        }
        return try await performRequest(request, responseType: AuthResponse.self)
    }
    
    /// Sign in with Apple ID token
    /// - Parameters:
    ///   - idToken: The identity token from Apple Sign-In
    ///   - nonce: The nonce used during Apple Sign-In (unhashed)
    ///   - fullName: Optional user's full name (only available on first sign-in)
    ///   - email: Optional user's email (only available on first sign-in)
    /// - Returns: AuthResponse containing access token and user data
    func signInWithApple(
        idToken: String,
        nonce: String,
        fullName: PersonNameComponents? = nil,
        email: String? = nil
    ) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/apple/") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "POST")
        
        // Build request payload
        var appleAuthData: [String: Any] = [
            "id_token": idToken,
            "nonce": nonce
        ]
        
        // Include optional user data if available
        if let email = email {
            appleAuthData["email"] = email
        }
        if let fullName = fullName {
            if let givenName = fullName.givenName {
                appleAuthData["first_name"] = givenName
            }
            if let familyName = fullName.familyName {
                appleAuthData["last_name"] = familyName
            }
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: appleAuthData)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: AuthResponse.self)
    }
    
    /// Reset password for user (sends reset email)
    func resetPassword(email: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/reset-password/") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "POST")
        
        let resetData = ["email": email]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: resetData)
        } catch {
            throw APIError.encodingError
        }
        
        let _: EmptyResponse = try await performRequest(request, responseType: EmptyResponse.self)
    }
    
    /// Update password for authenticated user (after clicking reset link)
    /// - Parameter newPassword: The new password to set
    func updatePassword(newPassword: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/update-password/") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "POST")
        
        let passwordData = ["password": newPassword]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: passwordData)
        } catch {
            throw APIError.encodingError
        }
        
        let _: EmptyResponse = try await performRequest(request, responseType: EmptyResponse.self)
    }
    
    /// Get current user information
    func getCurrentUser() async throws -> User {
        guard let url = URL(string: "\(baseURL)/auth/me/") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: User.self)
    }
    
    /// Update current user
    func updateUser(_ userUpdate: UserUpdate) async throws -> User {
        guard let url = URL(string: "\(baseURL)/auth/me/") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "PUT")
        
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
        
        var request = await createRequest(url: url, method: "POST")
        
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

        let request = await createRequest(url: url)
        
        // Get raw data first to check response format
        do {
            let (data, _) = try await urlSession.data(for: request)
            
            // Try to decode as array first
            do {
                let pets = try createJSONDecoder().decode([Pet].self, from: data)
                return pets
            } catch let DecodingError.typeMismatch(type, _) where type is [Any].Type {
                // Fallback: API returned single object, wrap it in array
                print("⚠️ [APIService] GET /pets/ returned single Pet object (not array), wrapping in array")
                let singlePet = try createJSONDecoder().decode(Pet.self, from: data)
                return [singlePet]
            }
        } catch {
            // Handle network errors
            throw error
        }
    }
    
    /// Get specific pet
    func getPet(id: String) async throws -> Pet {
        guard let url = URL(string: "\(baseURL)/pets/\(id)") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: Pet.self)
    }
    
    /// Update pet profile
    func updatePet(id: String, petUpdate: PetUpdate) async throws -> Pet {
        guard let url = URL(string: "\(baseURL)/pets/\(id)") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "PUT")
        
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
        
        let request = await createRequest(url: url, method: "DELETE")
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            
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
        guard let url = URL(string: "\(baseURL)/scanning/") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try createJSONEncoder().encode(scan)
        } catch {
            throw APIError.encodingError
        }
        
        return try await performRequest(request, responseType: Scan.self)
    }
    
    /// Analyze scan text - creates scan first, then analyzes it
    func analyzeScan(_ analysisRequest: ScanAnalysisRequest) async throws -> Scan {
        print("🔍 [API_SERVICE] Starting analyzeScan API call...")
        print("🔍 [API_SERVICE] Base URL: \(baseURL)")
        
        // Step 1: Create a scan record first
        print("🔍 [API_SERVICE] Step 1: Creating scan record...")
        let scanCreate = ScanCreate(
            petId: analysisRequest.petId,
            imageUrl: nil,
            rawText: analysisRequest.extractedText,
            status: .pending,
            scanMethod: analysisRequest.scanMethod
        )
        
        let createdScan = try await createScan(scanCreate)
        print("🔍 [API_SERVICE] ✅ Scan created with ID: \(createdScan.id)")
        
        // Step 2: Analyze the scan
        print("🔍 [API_SERVICE] Step 2: Analyzing scan...")
        guard let url = URL(string: "\(baseURL)/scanning/\(createdScan.id)/analyze") else {
            print("🔍 [API_SERVICE] ❌ Invalid URL: \(baseURL)/scanning/\(createdScan.id)/analyze")
            throw APIError.invalidURL
        }
        
        print("🔍 [API_SERVICE] Analysis URL: \(url)")
        
        var request = await createRequest(url: url, method: "POST")
        
        do {
            request.httpBody = try createJSONEncoder().encode(analysisRequest)
            print("🔍 [API_SERVICE] Request body encoded successfully")
        } catch {
            print("🔍 [API_SERVICE] ❌ Encoding error: \(error)")
            throw APIError.encodingError
        }
        
        print("🔍 [API_SERVICE] Making analysis request...")
        do {
            let result = try await performRequest(request, responseType: Scan.self)
            print("🔍 [API_SERVICE] ✅ Analysis successful, received scan: \(result.id)")
            return result
        } catch {
            print("🔍 [API_SERVICE] ❌ Analysis request failed: \(error)")
            throw error
        }
    }
    
    /// Get user's scans
    func getScans(petId: String? = nil) async throws -> [Scan] {
        var urlString = "\(baseURL)/scanning/"
        if let petId = petId {
            urlString += "?pet_id=\(petId)"
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: [Scan].self)
    }
    
    /// Get specific scan
    func getScan(id: String) async throws -> Scan {
        guard let url = URL(string: "\(baseURL)/scanning/\(id)") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: Scan.self)
    }
    
    /// Clear all scans for the current user
    func clearAllScans() async throws {
        guard let url = URL(string: "\(baseURL)/scanning/clear") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url, method: "DELETE")
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            
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
        
        var request = await createRequest(url: url, method: "POST")
        
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
        guard let url = URL(string: "\(baseURL)/ingredients/allergens") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: [String].self)
    }
    
    /// Get safe alternatives
    func getSafeAlternatives() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/ingredients/safe") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: [String].self)
    }
}

// MARK: - GDPR Endpoints

extension APIService {
    /// Export user data
    func exportUserData() async throws -> Data {
        guard let url = URL(string: "\(baseURL)/gdpr/export") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        let (data, _) = try await urlSession.data(for: request)
        return data
    }
    
    /// Delete user data
    func deleteUserData() async throws {
        guard let url = URL(string: "\(baseURL)/gdpr/delete") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url, method: "DELETE")
        let _: [String: String] = try await performRequest(request, responseType: [String: String].self)
    }
    
    /// Anonymize user data
    func anonymizeUserData() async throws {
        guard let url = URL(string: "\(baseURL)/gdpr/anonymize") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url, method: "POST")
        let _: [String: String] = try await performRequest(request, responseType: [String: String].self)
    }
    
    /// Get data retention information
    func getDataRetentionInfo() async throws -> DataRetentionInfo {
        guard let url = URL(string: "\(baseURL)/gdpr/retention") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: DataRetentionInfo.self)
    }
    
    /// Get data subject rights information
    func getDataSubjectRights() async throws -> DataSubjectRights {
        guard let url = URL(string: "\(baseURL)/gdpr/rights") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
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
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: HealthStatus.self)
    }
    
    /// Get system metrics
    func getMetrics(hours: Int = 24) async throws -> SystemMetrics {
        guard let url = URL(string: "\(baseURL)/monitoring/metrics?hours=\(hours)") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: SystemMetrics.self)
    }
    
    /// Get system status
    func getSystemStatus() async throws -> SystemStatus {
        guard let url = URL(string: "\(baseURL)/monitoring/status") else {
            throw APIError.invalidURL
        }
        
        let request = await createRequest(url: url)
        return try await performRequest(request, responseType: SystemStatus.self)
    }
}

// MARK: - Food Management Endpoints

extension APIService {
    /**
     * Look up food product by barcode
     * - Parameter barcode: The barcode value (e.g., EAN-13, UPC-A)
     * - Returns: FoodProduct if found in database, nil otherwise
     */
    func lookupProductByBarcode(_ barcode: String) async throws -> FoodProduct? {
        // Normalize barcode: trim whitespace and remove any non-alphanumeric chars except dash
        let cleanedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("📡 [APIService] Barcode lookup - Original: '\(barcode)'")
        print("📡 [APIService] Barcode lookup - Cleaned: '\(cleanedBarcode)'")
        
        guard let url = URL(string: "\(baseURL)/foods/barcode/\(cleanedBarcode)") else {
            print("❌ [APIService] Invalid URL for barcode: \(cleanedBarcode)")
            throw APIError.invalidURL
        }
        
        print("📡 [APIService] Request URL: \(url.absoluteString)")
        
        // Create request with CACHE BYPASS - always fetch fresh data for barcode lookups
        var request = await createRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        print("🔄 [APIService] Cache policy: BYPASS - fetching fresh data")
        
        do {
            let product = try await performRequest(request, responseType: FoodProduct.self)
            print("✅ [APIService] Found product: \(product.name), barcode in DB: \(product.barcode ?? "none")")
            return product
        } catch APIError.notFound {
            // Product not found in database - this is expected, not an error
            print("❌ [APIService] Product not found for barcode: '\(cleanedBarcode)'")
            return nil
        } catch {
            print("❌ [APIService] Barcode lookup error: \(error)")
            throw error
        }
    }
    
    /**
     * Create a new food item in the database
     * 
     * - Parameters:
     *   - name: Product name (required)
     *   - brand: Brand name (optional)
     *   - barcode: Barcode/UPC (optional)
     *   - category: Product category (optional)
     *   - species: Target species: "dog" or "cat" (optional)
     *   - language: Language code (optional)
     *   - country: Country code (optional)
     *   - externalSource: External data source (optional)
     *   - nutritionalInfo: Nutritional information dictionary (optional)
     * 
     * - Returns: True if successfully created
     * - Throws: APIError if request fails
     */
    func createFoodItem(
        name: String,
        brand: String?,
        barcode: String?,
        category: String?,
        species: String?,
        language: String?,
        country: String?,
        externalSource: String?,
        nutritionalInfo: [String: Any]?
    ) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/foods") else {
            throw APIError.invalidURL
        }
        
        var request = await createRequest(url: url, method: "POST")
        
        // Build request body
        var foodData: [String: Any] = [
            "name": name
        ]
        
        if let brand = brand {
            foodData["brand"] = brand
        }
        
        if let barcode = barcode {
            foodData["barcode"] = barcode
        }
        
        if let category = category {
            foodData["category"] = category
        }
        
        if let species = species {
            foodData["species"] = species.lowercased()
        }
        
        if let language = language {
            foodData["language"] = language
        }
        
        if let country = country {
            foodData["country"] = country
        }
        
        if let externalSource = externalSource {
            foodData["external_source"] = externalSource
        }
        
        // Generate keywords from brand and product name for searchability
        var keywords: [String] = []
        
        // Add brand words as keywords
        if let brand = brand, !brand.isEmpty {
            let brandWords = brand.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty && $0.count > 1 }
            keywords.append(contentsOf: brandWords)
        }
        
        // Add product name words as keywords
        let nameWords = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 1 }
        keywords.append(contentsOf: nameWords)
        
        // Remove duplicates and common stop words
        let stopWords = Set(["the", "and", "for", "with", "dog", "cat", "pet", "food"])
        keywords = Array(Set(keywords)).filter { !stopWords.contains($0) }
        
        if !keywords.isEmpty {
            foodData["keywords"] = keywords
        }
        
        if let nutritionalInfo = nutritionalInfo {
            foodData["nutritional_info"] = nutritionalInfo
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: foodData)
        } catch {
            throw APIError.encodingError
        }
        
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if let errorMessage = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorMessage["detail"] as? String {
                throw APIError.serverMessage(detail)
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        return true
    }
}

