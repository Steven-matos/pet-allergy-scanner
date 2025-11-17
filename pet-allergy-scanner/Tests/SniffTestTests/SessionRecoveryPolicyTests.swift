//
//  SessionRecoveryPolicyTests.swift
//  SniffTestTests
//
//  Created by GPT-5.1 Codex on 11/17/25.
//

import Testing
@testable import pet_allergy_scanner

/// Tests covering the logic that decides when cached sessions should be invalidated.
@Suite("Session Recovery Policy Tests")
struct SessionRecoveryPolicyTests {
    /// Ensure authentication failures force a logout.
    @Test("Credential failures invalidate session")
    func invalidCredentialsInvalidateSession() {
        #expect(AuthService.shouldInvalidateSession(for: APIError.authenticationError))
        #expect(AuthService.shouldInvalidateSession(for: APIError.serverMessage("token expired")))
    }
    
    /// Ensure transient network issues do not force the user out of the app.
    @Test("Network interruptions preserve session")
    func networkErrorsPreserveSession() {
        #expect(!AuthService.shouldInvalidateSession(for: APIError.networkError("offline")))
        #expect(!AuthService.shouldInvalidateSession(for: APIError.serverError(503)))
    }
}
