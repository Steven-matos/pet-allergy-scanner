//
//  MFASetupView.swift
//  pet-allergy-scanner
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

struct MFASetupView: View {
    @EnvironmentObject var mfaService: MFAService
    @State private var verificationToken = ""
    @State private var showingBackupCodes = false
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Multi-Factor Authentication")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Add an extra layer of security to your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                if mfaService.isMFASetup && !mfaService.isMFAEnabled {
                    // MFA Setup Complete - Show QR Code
                    VStack(spacing: 20) {
                        if let qrCodeImage = mfaService.qrCodeImage {
                            VStack(spacing: 16) {
                                Text("Scan this QR code with your authenticator app")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                
                                // QR Code Image
                                if let imageData = Data(base64Encoded: qrCodeImage),
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 200, height: 200)
                                        .cornerRadius(12)
                                        .shadow(radius: 8)
                                        .accessibilityLabel("QR code for MFA setup")
                                        .accessibilityHint("Scan this QR code with your authenticator app to set up multi-factor authentication")
                                }
                                
                                Text("Or enter this code manually:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(mfaService.qrCodeImage ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        // Verification Token Input
                        VStack(spacing: 16) {
                            Text("Enter the 6-digit code from your authenticator app")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            TextField("000000", text: $verificationToken)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title)
                                .monospacedDigit()
                                .frame(maxWidth: 200)
                                .accessibilityLabel("Enter 6-digit verification code")
                                .accessibilityHint("Enter the 6-digit code from your authenticator app")
                            
                            Button("Enable MFA") {
                                handleEnableMFA()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .disabled(verificationToken.count != 6 || mfaService.isLoading)
                        }
                    }
                } else if mfaService.isMFAEnabled {
                    // MFA Already Enabled
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("MFA is Enabled")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Your account is protected with multi-factor authentication")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("View Backup Codes") {
                            showingBackupCodes = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else {
                    // Setup MFA
                    VStack(spacing: 20) {
                        Text("Set up multi-factor authentication to secure your account")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Button("Setup MFA") {
                            handleSetupMFA()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(mfaService.isLoading)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(mfaService.errorMessage ?? "An error occurred")
            }
            .onChange(of: mfaService.errorMessage) { _, errorMessage in
                if errorMessage != nil {
                    showingAlert = true
                }
            }
            .sheet(isPresented: $showingBackupCodes) {
                BackupCodesView()
            }
        }
    }
    
    private func handleSetupMFA() {
        Task {
            await mfaService.setupMFA()
        }
    }
    
    private func handleEnableMFA() {
        Task {
            await mfaService.enableMFA(token: verificationToken)
            if mfaService.isMFAEnabled {
                HapticFeedback.success()
                verificationToken = ""
            } else if mfaService.errorMessage != nil {
                HapticFeedback.error()
            }
        }
    }
}

struct BackupCodesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backupCodes: [String] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Backup Codes")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Save these codes in a secure location. Each code can only be used once.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Backup Codes List
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(backupCodes, id: \.self) { code in
                        Text(code)
                            .font(.monospaced(.body)())
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .navigationTitle("Backup Codes")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                backupCodes = MFAService.shared.generateBackupCodes()
            }
        }
    }
}

#Preview {
    MFASetupView()
        .environmentObject(MFAService.shared)
}
