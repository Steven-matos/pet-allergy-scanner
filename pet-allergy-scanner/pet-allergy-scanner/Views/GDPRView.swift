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
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Privacy & Data Rights")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Manage your personal data and privacy settings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Data Retention Information
                    if let retentionInfo = gdprService.dataRetentionInfo {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Retention Policy")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Retention Period:")
                                    Spacer()
                                    Text("\(retentionInfo.retentionDays) days")
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Policy Version:")
                                    Spacer()
                                    Text(retentionInfo.policyVersion)
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Last Updated:")
                                    Spacer()
                                    Text(retentionInfo.lastUpdated, style: .date)
                                        .fontWeight(.medium)
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Data Subject Rights
                    if let rights = gdprService.dataSubjectRights {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Data Rights")
                                .font(.headline)
                            
                            ForEach(rights.rights, id: \.name) { right in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: right.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(right.isAvailable ? .green : .red)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(right.name)
                                            .fontWeight(.medium)
                                        
                                        Text(right.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Contact Information")
                                    .fontWeight(.medium)
                                
                                Text("Email: \(rights.contactEmail)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("Response Time: \(rights.responseTime)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Export Data Button
                        Button(action: handleExportData) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Export My Data")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(gdprService.isLoading)
                        
                        // Delete Data Button
                        Button(action: { showingDeleteConfirmation = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete My Data")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(gdprService.isLoading)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadGDPRInfo()
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
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
                if gdprService.saveExportedDataToFile() != nil {
                    showingExportSuccess = true
                }
            }
        }
    }
    
    private func handleDeleteData() {
        Task {
            let success = await gdprService.deleteUserData()
            if success {
                // Handle successful deletion (e.g., logout user)
            }
        }
    }
}

#Preview {
    GDPRView()
        .environmentObject(GDPRService.shared)
}
