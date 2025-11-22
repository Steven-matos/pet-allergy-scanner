//
//  DocumentPickerView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

/**
 * Document Picker View
 * 
 * Component for selecting PDF and image documents for vet paperwork
 * Supports both camera/photo library for images and document picker for PDFs
 * Follows SOLID principles with single responsibility for document selection
 * Implements DRY by reusing common picker patterns
 * Follows KISS by keeping the interface simple and focused
 */
struct DocumentPickerView: View {
    @Binding var selectedDocuments: [VetDocument]
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var showingActionSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isUploading = false
    
    let userId: String
    let petId: String
    let healthEventId: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Vet Paperwork")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Upload photos or PDF documents of vet paperwork for this visit. PDFs can be selected from the Files app.")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            // Upload button
            Button(action: {
                showingActionSheet = true
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    Text("Add Document")
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    Spacer()
                    
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ModernDesignSystem.Colors.primary))
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                        .stroke(ModernDesignSystem.Colors.primary, lineWidth: 1)
                )
            }
            .disabled(isUploading)
            
            // Display uploaded documents
            if !selectedDocuments.isEmpty {
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(selectedDocuments.indices, id: \.self) { index in
                        DocumentItemView(
                            document: selectedDocuments[index],
                            onRemove: {
                                selectedDocuments.remove(at: index)
                            }
                        )
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .fill(ModernDesignSystem.Colors.background)
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
        )
        .confirmationDialog("Add Document", isPresented: $showingActionSheet) {
            Button("Take Photo") {
                sourceType = .camera
                showingImagePicker = true
            }
            Button("Choose Photo") {
                sourceType = .photoLibrary
                showingImagePicker = true
            }
            Button("Choose PDF from Files") {
                showingDocumentPicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                image: Binding(
                    get: { nil },
                    set: { image in
                        if let image = image {
                            handleImageSelected(image)
                        }
                    }
                ),
                sourceType: sourceType
            )
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(
                onDocumentSelected: { url in
                    handlePDFSelected(url: url)
                }
            )
        }
    }
    
    /**
     * Handle image selection and upload
     * - Parameter image: Selected UIImage
     */
    private func handleImageSelected(_ image: UIImage) {
        isUploading = true
        
        Task {
            do {
                let storageService = StorageService.shared
                let documentUrl = try await storageService.uploadVetDocumentImage(
                    image: image,
                    userId: userId,
                    petId: petId,
                    healthEventId: healthEventId
                )
                
                let document = VetDocument(
                    url: documentUrl,
                    type: .image,
                    fileName: "vet-paperwork-\(UUID().uuidString).jpg"
                )
                
                await MainActor.run {
                    selectedDocuments.append(document)
                    isUploading = false
                    HapticFeedback.success()
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    print("❌ Failed to upload image: \(error)")
                }
            }
        }
    }
    
    /**
     * Handle PDF selection and upload
     * - Parameter url: Selected PDF file URL
     */
    private func handlePDFSelected(url: URL) {
        isUploading = true
        
        Task {
            do {
                // Read PDF data
                let pdfData = try Data(contentsOf: url)
                
                // Get filename from URL
                let fileName = url.lastPathComponent
                
                let storageService = StorageService.shared
                let documentUrl = try await storageService.uploadVetDocument(
                    data: pdfData,
                    userId: userId,
                    petId: petId,
                    healthEventId: healthEventId,
                    contentType: "application/pdf",
                    fileName: fileName
                )
                
                let document = VetDocument(
                    url: documentUrl,
                    type: .pdf,
                    fileName: fileName
                )
                
                await MainActor.run {
                    selectedDocuments.append(document)
                    isUploading = false
                    HapticFeedback.success()
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    print("❌ Failed to upload PDF: \(error)")
                }
            }
        }
    }
}

/**
 * Vet Document Model
 * 
 * Represents a document (PDF or image) associated with a vet visit
 */
struct VetDocument: Identifiable, Codable, Equatable {
    let id: String
    let url: String
    let type: DocumentType
    let fileName: String
    
    init(url: String, type: DocumentType, fileName: String) {
        self.id = UUID().uuidString
        self.url = url
        self.type = type
        self.fileName = fileName
    }
    
    enum DocumentType: String, Codable {
        case image
        case pdf
    }
}

/**
 * Document Item View
 * 
 * Displays a single document with preview and remove button
 */
struct DocumentItemView: View {
    let document: VetDocument
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Document icon
            Image(systemName: document.type == .pdf ? "doc.fill" : "photo.fill")
                .font(.system(size: 24))
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                        .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                )
            
            // Document info
            VStack(alignment: .leading, spacing: 2) {
                Text(document.fileName)
                    .font(ModernDesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(document.type == .pdf ? "PDF Document" : "Image")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ModernDesignSystem.Colors.error)
            }
        }
        .padding(ModernDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                .fill(ModernDesignSystem.Colors.background)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
}

/**
 * Document Picker
 * 
 * UIKit document picker wrapper for SwiftUI
 */
struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentSelected: (URL) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                parent.presentationMode.wrappedValue.dismiss()
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            parent.onDocumentSelected(url)
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    DocumentPickerView(
        selectedDocuments: .constant([]),
        userId: "test-user",
        petId: "test-pet",
        healthEventId: "test-event"
    )
}

