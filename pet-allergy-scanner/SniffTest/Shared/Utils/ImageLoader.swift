//
//  ImageLoader.swift
//  SniffTest
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI
import UIKit

/// Utility for loading images from both local file paths and remote URLs
/// Handles caching and async loading for remote images
@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let url: String
    private var task: Task<Void, Never>?
    
    init(url: String) {
        self.url = url
        loadImage()
    }
    
    deinit {
        task?.cancel()
    }
    
    /// Load image from URL (local or remote)
    func loadImage() {
        print("🔍 ImageLoader: Loading image from URL: \(url)")
        // Check if it's a remote URL
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            print("🔍 ImageLoader: Loading remote image")
            loadRemoteImage()
        } else {
            print("🔍 ImageLoader: Loading local image")
            loadLocalImage()
        }
    }
    
    /// Load image from local file path
    private func loadLocalImage() {
        guard let localImage = UIImage(contentsOfFile: url) else {
            errorMessage = "Failed to load local image"
            return
        }
        self.image = localImage
    }
    
    /// Load image from remote URL with caching
    private func loadRemoteImage() {
        guard let imageURL = URL(string: url) else {
            errorMessage = "Invalid image URL"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        task = Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: imageURL)
                
                // Check for HTTP errors
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    await MainActor.run {
                        self.errorMessage = "Failed to load image (HTTP \(httpResponse.statusCode))"
                        self.isLoading = false
                    }
                    return
                }
                
                // Create image from data
                guard let loadedImage = UIImage(data: data) else {
                    await MainActor.run {
                        self.errorMessage = "Invalid image data"
                        self.isLoading = false
                    }
                    return
                }
                
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load image: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Cancel current loading task
    func cancel() {
        task?.cancel()
        task = nil
    }
}

/// SwiftUI view that displays images from local or remote URLs
struct RemoteImageView: View {
    let url: String
    let placeholder: Image
    let contentMode: ContentMode
    
    @StateObject private var imageLoader: ImageLoader
    
    init(url: String, placeholder: Image = Image(systemName: "photo"), contentMode: ContentMode = .fill) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
        self._imageLoader = StateObject(wrappedValue: ImageLoader(url: url))
    }
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if imageLoader.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            imageLoader.loadImage()
        }
        .onDisappear {
            imageLoader.cancel()
        }
    }
}

/// Convenience initializer for pet images with species icon fallback
extension RemoteImageView {
    init(petImageUrl: String?, species: PetSpecies, contentMode: ContentMode = .fill) {
        if let imageUrl = petImageUrl, !imageUrl.isEmpty {
            self.init(
                url: imageUrl,
                placeholder: Image(systemName: species.icon),
                contentMode: contentMode
            )
        } else {
            self.init(
                url: "",
                placeholder: Image(systemName: species.icon),
                contentMode: contentMode
            )
        }
    }
}

/// Convenience initializer for user profile images
extension RemoteImageView {
    init(userImageUrl: String?, contentMode: ContentMode = .fill) {
        print("🔍 RemoteImageView: User image URL: \(userImageUrl ?? "nil")")
        if let imageUrl = userImageUrl, !imageUrl.isEmpty {
            print("🔍 RemoteImageView: Using provided image URL")
            self.init(
                url: imageUrl,
                placeholder: Image(systemName: "person.circle.fill"),
                contentMode: contentMode
            )
        } else {
            print("🔍 RemoteImageView: Using placeholder (no image URL)")
            self.init(
                url: "",
                placeholder: Image(systemName: "person.circle.fill"),
                contentMode: contentMode
            )
        }
    }
}
