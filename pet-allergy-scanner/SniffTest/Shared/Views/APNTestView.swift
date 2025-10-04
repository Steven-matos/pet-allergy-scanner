//
//  APNTestView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/10/25.
//

import SwiftUI
import UserNotifications

/// Test view for APN functionality
/// Provides UI to test push notification registration and sending
struct APNTestView: View {
    @StateObject private var pushService = PushNotificationService.shared
    @State private var deviceToken: String = ""
    @State private var isTesting = false
    @State private var testResults: [String] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("APN Testing")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Test push notification functionality")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                    
                    // Status Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status")
                            .font(.headline)
                        
                        StatusRow(
                            title: "Authorization",
                            status: pushService.isAuthorized ? "✅ Granted" : "❌ Not Granted",
                            color: pushService.isAuthorized ? .green : .red
                        )
                        
                        StatusRow(
                            title: "Device Token",
                            status: pushService.deviceToken != nil ? "✅ Registered" : "❌ Not Registered",
                            color: pushService.deviceToken != nil ? .green : .red
                        )
                        
                        StatusRow(
                            title: "APNs Connection",
                            status: pushService.isConnectedToAPNs ? "✅ Connected" : "❌ Not Connected",
                            color: pushService.isConnectedToAPNs ? .green : .red
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Device Token Section
                    if let token = pushService.deviceToken {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Device Token")
                                .font(.headline)
                            
                            Text(token)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Button("Copy Token") {
                                UIPasteboard.general.string = token
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Test Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Actions")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            Button("Request Permission") {
                                Task {
                                    await requestPermission()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isTesting)
                            
                            Button("Test Engagement Notification") {
                                Task {
                                    await testEngagementNotification()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isTesting || pushService.deviceToken == nil)
                            
                            Button("Test Birthday Notification") {
                                Task {
                                    await testBirthdayNotification()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isTesting || pushService.deviceToken == nil)
                            
                            Button("Send Test Notification") {
                                Task {
                                    await sendTestNotification()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isTesting || pushService.deviceToken == nil)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Test Results
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Test Results")
                                .font(.headline)
                            
                            ForEach(testResults, id: \.self) { result in
                                Text(result)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("APN Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadDeviceToken()
        }
    }
    
    // MARK: - Private Methods
    
    /// Request push notification permission
    private func requestPermission() async {
        isTesting = true
        addResult("🔄 Requesting push notification permission...")
        
        let granted = await pushService.requestPushNotificationPermission()
        
        if granted {
            addResult("✅ Permission granted successfully")
        } else {
            addResult("❌ Permission denied")
        }
        
        isTesting = false
    }
    
    /// Test engagement notification
    private func testEngagementNotification() async {
        guard pushService.deviceToken != nil else {
            addResult("❌ No device token available")
            return
        }
        
        isTesting = true
        addResult("🔄 Testing engagement notification...")
        
        await pushService.sendEngagementNotification(
            type: .weekly,
            title: "🔍 Time for a Scan!",
            body: "Keep your pet safe by scanning their food ingredients regularly."
        )
        
        addResult("✅ Engagement notification sent")
        isTesting = false
    }
    
    /// Test birthday notification
    private func testBirthdayNotification() async {
        guard pushService.deviceToken != nil else {
            addResult("❌ No device token available")
            return
        }
        
        isTesting = true
        addResult("🔄 Testing birthday notification...")
        
        await pushService.sendBirthdayNotification(
            petName: "Buddy",
            petId: "test_pet_id"
        )
        
        addResult("✅ Birthday notification sent")
        isTesting = false
    }
    
    /// Send test notification
    private func sendTestNotification() async {
        guard let deviceToken = pushService.deviceToken else {
            addResult("❌ No device token available")
            return
        }
        
        isTesting = true
        addResult("🔄 Sending test notification...")
        
        // Create test payload
        let testPayload: [String: Any] = [
            "aps": [
                "alert": [
                    "title": "🧪 APN Test",
                    "body": "This is a test notification from Pet Allergy Scanner"
                ],
                "sound": "default",
                "badge": 1
            ],
            "type": "test",
            "action": "navigate_to_scan"
        ]
        
        do {
            try await APIService.shared.sendPushNotification(
                payload: testPayload,
                deviceToken: deviceToken
            )
            addResult("✅ Test notification sent successfully")
        } catch {
            addResult("❌ Failed to send test notification: \(error.localizedDescription)")
        }
        
        isTesting = false
    }
    
    /// Load device token from UserDefaults
    private func loadDeviceToken() {
        if let token = UserDefaults.standard.string(forKey: "device_token") {
            deviceToken = token
        }
    }
    
    /// Add result to test results
    private func addResult(_ result: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        testResults.append("[\(timestamp)] \(result)")
    }
}

/// Status row component
struct StatusRow: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(status)
                .font(.subheadline)
                .foregroundColor(color)
        }
    }
}

#Preview {
    APNTestView()
}
