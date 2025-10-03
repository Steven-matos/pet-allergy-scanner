//
//  GDPRView.swift
//  pet-allergy-scanner
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

struct GDPRView: View {
    @EnvironmentObject var gdprService: GDPRService
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Header Section
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 50))
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Text("Privacy & Data Rights")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text("Manage your personal data and privacy settings")
                            .font(.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                
                // Data Retention Information
                if let retentionInfo = gdprService.dataRetentionInfo {
                    Section("Data Retention Policy") {
                        HStack {
                            Text("Retention Period")
                            Spacer()
                            Text("\(retentionInfo.retentionDays) days")
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        
                        HStack {
                            Text("Policy Version")
                            Spacer()
                            Text(retentionInfo.policyVersion)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        
                        HStack {
                            Text("Last Updated")
                            Spacer()
                            Text(retentionInfo.lastUpdated, style: .date)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        
                        HStack {
                            Image(systemName: retentionInfo.shouldDelete ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(retentionInfo.shouldDelete ? ModernDesignSystem.Colors.warning : ModernDesignSystem.Colors.safe)
                            Text(retentionInfo.shouldDelete ? "Data scheduled for deletion" : "\(retentionInfo.daysUntilDeletion) days until deletion")
                                .foregroundColor(retentionInfo.shouldDelete ? ModernDesignSystem.Colors.warning : ModernDesignSystem.Colors.safe)
                        }
                    }
                }
                
                // Data Subject Rights
                if let rights = gdprService.dataSubjectRights {
                    Section("Your Data Rights") {
                        ForEach(rights.dataSubjectRights.rights, id: \.article) { right in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: right.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(right.isAvailable ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.error)
                                    Text(right.name)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                
                                Text(right.description)
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                
                                Text(right.howToExercise)
                                    .font(.caption2)
                                    .foregroundColor(ModernDesignSystem.Colors.primary)
                                    .italic()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    
                    Section("Contact Information") {
                        HStack {
                            Text("Data Protection Officer")
                            Spacer()
                            Text(rights.contactInformation.dataProtectionOfficer)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Text(rights.contactInformation.privacyPolicy)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                // Loading State
                if gdprService.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(ModernDesignSystem.Colors.primary)
                                Text("Processing your request...")
                                    .font(.subheadline)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                }
                
                // Action Buttons
                Section("Data Actions") {
                    Button(action: handleExportData) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                            Text("Export My Data")
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        }
                    }
                    .disabled(gdprService.isLoading)
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(ModernDesignSystem.Colors.error)
                            Text("Delete My Data")
                                .foregroundColor(ModernDesignSystem.Colors.error)
                        }
                    }
                    .disabled(gdprService.isLoading)
                    
                    Button(action: handleAnonymizeData) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.minus")
                                .foregroundColor(ModernDesignSystem.Colors.warning)
                            Text("Anonymize My Data")
                                .foregroundColor(ModernDesignSystem.Colors.warning)
                        }
                    }
                    .disabled(gdprService.isLoading)
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadGDPRInfo()
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { 
                    gdprService.clearError()
                }
            } message: {
                Text(gdprService.errorMessage ?? "An error occurred")
            }
            .alert("Delete Data", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    handleDeleteData()
                }
            } message: {
                Text("This action cannot be undone. All your personal data will be permanently deleted.")
            }
            .alert("Export Successful", isPresented: $showingExportSuccess) {
                Button("OK") { }
            } message: {
                Text("Your data has been exported and saved to your device.")
            }
            .onChange(of: gdprService.errorMessage) { _, errorMessage in
                if errorMessage != nil {
                    showingAlert = true
                }
            }
        }
    }
    
    private func loadGDPRInfo() {
        Task {
            await gdprService.getDataRetentionInfo()
            await gdprService.getDataSubjectRights()
        }
    }
    
    private func handleExportData() {
        Task {
            if let _ = await gdprService.exportUserData() {
                if let fileURL = gdprService.saveExportedDataToFile() {
                    showingExportSuccess = true
                    print("✅ Data exported successfully to: \(fileURL)")
                } else {
                    gdprService.errorMessage = "Failed to save exported data to device"
                }
            }
        }
    }
    
    private func handleDeleteData() {
        Task {
            let success = await gdprService.deleteUserData()
            if success {
                // Handle successful deletion (e.g., logout user)
                // The GDPRService already handles logout
            }
        }
    }
    
    private func handleAnonymizeData() {
        Task {
            let success = await gdprService.anonymizeUserData()
            if success {
                // Handle successful anonymization
                showingAlert = true
                gdprService.errorMessage = "Your data has been successfully anonymized. Personal information has been removed while preserving functionality."
            }
        }
    }
}

#Preview {
    GDPRView()
        .environmentObject(GDPRService.shared)
}

