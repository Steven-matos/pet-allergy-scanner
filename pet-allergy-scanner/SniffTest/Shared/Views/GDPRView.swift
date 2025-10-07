//
//  GDPRView.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

/**
 * GDPR Data & Privacy Rights View
 * 
 * Provides comprehensive data privacy controls following Trust & Nature Design System
 * 
 * Features:
 * - Card-based layout with warm, trustworthy design
 * - Clear data rights information with visual hierarchy
 * - GDPR-compliant data management actions
 * - Trust & Nature color palette throughout
 * - Professional, accessible design
 * 
 * Design System Compliance:
 * - Uses ModernDesignSystem for all styling
 * - Follows Trust & Nature color palette
 * - Implements consistent spacing scale
 * - Applies proper shadows and corner radius
 * - Maintains accessibility standards
 */
struct GDPRView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gdprService: GDPRService
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Header Card
                    headerCard
                    
                    // Data Retention Information Card
                    if let retentionInfo = gdprService.dataRetentionInfo {
                        dataRetentionCard(retentionInfo)
                    }
                    
                    // Data Subject Rights Card
                    if let rights = gdprService.dataSubjectRights {
                        dataRightsCard(rights)
                        contactInformationCard(rights)
                    }
                    
                    // Loading State
                    if gdprService.isLoading {
                        loadingCard
                    }
                    
                    // Action Buttons Card
                    dataActionsCard
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Data & Privacy Rights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
            }
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
            .onChange(of: gdprService.errorMessage) { oldValue, newValue in
                // Only show alert for critical errors (export, delete failures)
                // Don't show alerts for optional data loading failures
                if let error = newValue {
                    let isCriticalError = error.contains("export") || 
                                         error.contains("delete") || 
                                         error.contains("Failed to save")
                    if isCriticalError {
                        showingAlert = true
                    } else {
                        // Clear non-critical errors silently
                        gdprService.clearError()
                    }
                }
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
        }
    }
    
    // MARK: - Header Card
    /// Hero header card with shield icon and description
    private var headerCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            VStack(spacing: ModernDesignSystem.Spacing.xs) {
                Text("Privacy & Data Rights")
                    .font(ModernDesignSystem.Typography.title)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Manage your personal data and exercise your privacy rights under GDPR")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Data Retention Card
    /// Card displaying data retention policy information
    private func dataRetentionCard(_ retentionInfo: DataRetentionInfo) -> some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "clock.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Data Retention Policy")
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("How long we keep your data")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                // Retention Period
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: "calendar")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Retention Period")
                            .font(ModernDesignSystem.Typography.bodyEmphasized)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text("\(retentionInfo.retentionDays) days after account closure")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(ModernDesignSystem.Spacing.md)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                    .padding(.leading, ModernDesignSystem.Spacing.lg)
                
                // Policy Version
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: "doc.text")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .frame(width: 24)
                    
                    Text("Policy Version")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text(retentionInfo.policyVersion)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(ModernDesignSystem.Spacing.md)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                    .padding(.leading, ModernDesignSystem.Spacing.lg)
                
                // Last Updated
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .frame(width: 24)
                    
                    Text("Last Updated")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text(retentionInfo.lastUpdated, style: .date)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(ModernDesignSystem.Spacing.md)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                    .padding(.leading, ModernDesignSystem.Spacing.lg)
                
                // Deletion Status
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: retentionInfo.shouldDelete ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(retentionInfo.shouldDelete ? ModernDesignSystem.Colors.warning : ModernDesignSystem.Colors.safe)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Deletion Status")
                            .font(ModernDesignSystem.Typography.bodyEmphasized)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text(retentionInfo.shouldDelete ? "Data scheduled for deletion" : "\(retentionInfo.daysUntilDeletion) days until automatic deletion")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(retentionInfo.shouldDelete ? ModernDesignSystem.Colors.warning : ModernDesignSystem.Colors.safe)
                    }
                    
                    Spacer()
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .fill(Color.white.opacity(0.5))
            )
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Data Rights Card
    /// Card displaying GDPR data subject rights
    private func dataRightsCard(_ rights: DataSubjectRights) -> some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Your Data Rights")
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Rights guaranteed under GDPR")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                ForEach(rights.dataSubjectRights.rights, id: \.article) { right in
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        HStack(spacing: ModernDesignSystem.Spacing.md) {
                            Image(systemName: right.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(right.isAvailable ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.error)
                                .font(ModernDesignSystem.Typography.title3)
                            
                            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                                Text(right.name)
                                    .font(ModernDesignSystem.Typography.bodyEmphasized)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                
                                Text(right.description)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text(right.howToExercise)
                                    .font(ModernDesignSystem.Typography.caption2)
                                    .foregroundColor(ModernDesignSystem.Colors.primary)
                                    .italic()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .fill(Color.white.opacity(0.5))
                        )
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Contact Information Card
    /// Card displaying contact information for privacy inquiries
    private func contactInformationCard(_ rights: DataSubjectRights) -> some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Contact Information")
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Reach out for privacy questions")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                // Data Protection Officer
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Data Protection Officer")
                            .font(ModernDesignSystem.Typography.bodyEmphasized)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text(rights.contactInformation.dataProtectionOfficer)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                    
                    Spacer()
                }
                .padding(ModernDesignSystem.Spacing.md)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                    .padding(.leading, ModernDesignSystem.Spacing.lg)
                
                // Privacy Policy
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: "doc.text")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Privacy Policy")
                            .font(ModernDesignSystem.Typography.bodyEmphasized)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text(rights.contactInformation.privacyPolicy)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                    
                    Spacer()
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .fill(Color.white.opacity(0.5))
            )
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Loading Card
    /// Card displaying loading state during async operations
    private var loadingCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ModernDesignSystem.Colors.primary)
            
            Text("Processing your request...")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ModernDesignSystem.Spacing.xl)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Data Actions Card
    /// Card with actionable data management buttons
    private var dataActionsCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Data Actions")
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Manage your personal data")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                // Export Data Button
                Button(action: handleExportData) {
                    HStack(spacing: ModernDesignSystem.Spacing.md) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Export My Data")
                                .font(ModernDesignSystem.Typography.bodyEmphasized)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text("Download a copy of all your personal data")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(ModernDesignSystem.Spacing.md)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(gdprService.isLoading)
                .opacity(gdprService.isLoading ? 0.5 : 1.0)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                    .padding(.leading, ModernDesignSystem.Spacing.lg)
                
                // Delete Data Button - Dangerous Action
                Button(action: { showingDeleteConfirmation = true }) {
                    HStack(spacing: ModernDesignSystem.Spacing.md) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(ModernDesignSystem.Colors.error)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Delete My Data")
                                .font(ModernDesignSystem.Typography.bodyEmphasized)
                                .foregroundColor(ModernDesignSystem.Colors.error)
                            
                            Text("Permanently delete all your data and close your account")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(ModernDesignSystem.Spacing.md)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(gdprService.isLoading)
                .opacity(gdprService.isLoading ? 0.5 : 1.0)
            }
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .fill(Color.white.opacity(0.5))
            )
            
            // Warning Footer
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.warning)
                
                Text("Data deletion is permanent and cannot be undone. Please export your data before deletion if needed.")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .fill(ModernDesignSystem.Colors.warning.opacity(0.08))
            )
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Helper Methods
    
    /// Load GDPR information on view appear
    /// Silently fails if endpoints are not available - the action buttons will still work
    private func loadGDPRInfo() {
        Task {
            // Clear any previous errors before loading
            gdprService.clearError()
            
            // Try to load optional information
            // These are informational only - the view works without them
            await gdprService.getDataRetentionInfo()
            await gdprService.getDataSubjectRights()
            
            // Clear any loading errors since these are optional
            if gdprService.errorMessage != nil {
                gdprService.clearError()
            }
        }
    }
    
    /// Handle data export request
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
    
    /// Handle data deletion request
    private func handleDeleteData() {
        Task {
            let success = await gdprService.deleteUserData()
            if success {
                // Handle successful deletion (e.g., logout user)
                // The GDPRService already handles logout
                HapticFeedback.success()
            }
        }
    }
}

#Preview {
    GDPRView()
        .environmentObject(GDPRService.shared)
}

