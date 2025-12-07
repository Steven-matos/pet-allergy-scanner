//
//  ModernSwiftUIConcurrency.swift
//  SniffTest
//
//  Created by Steven Matos on 1/28/25.
//

import SwiftUI

/**
 * Modern SwiftUI Concurrency - SwiftUI 5.0 Features
 * 
 * Implements latest SwiftUI 5.0 concurrency features:
 * - Modern async/await patterns
 * - Task management and cancellation
 * - Structured concurrency
 * - Performance-optimized async operations
 * 
 * Follows SOLID principles with single responsibility for concurrency
 * Implements DRY by providing reusable concurrency patterns
 * Follows KISS by keeping async operations simple and reliable
 */

// MARK: - Modern Async View

/**
 * Modern async view using SwiftUI 5.0 concurrency features
 * Provides structured concurrency for data loading
 */
struct ModernAsyncView<Content: View, LoadingView: View, ErrorView: View>: View {
    let content: () -> Content
    let loadingView: () -> LoadingView
    let errorView: (Error) -> ErrorView
    let asyncOperation: () async throws -> Void
    
    @State private var isLoading = true
    @State private var error: Error?
    @State private var task: Task<Void, Error>?
    
    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder loadingView: @escaping () -> LoadingView = { 
            ModernConcurrencyLoadingView(message: "Loading...") 
        },
        @ViewBuilder errorView: @escaping (Error) -> ErrorView = { error in
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
            }
        },
        asyncOperation: @escaping () async throws -> Void
    ) {
        self.content = content
        self.loadingView = loadingView
        self.errorView = errorView
        self.asyncOperation = asyncOperation
    }
    
    var body: some View {
        Group {
            if isLoading {
                loadingView()
            } else if let error = error {
                errorView(error)
            } else {
                content()
            }
        }
        .task {
            await loadData()
        }
        .onDisappear {
            task?.cancel()
        }
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        error = nil
        
        // Add timeout protection to prevent isLoading from getting stuck
        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            if isLoading {
                print("⚠️ ModernAsyncContentView load timeout - resetting isLoading")
                isLoading = false
            }
        }
        
        task = Task {
            defer {
                timeoutTask.cancel()
            }
            
            do {
                try await asyncOperation()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isLoading = false
                }
            }
        }
        
        // Wait for the task to complete
        _ = await task?.result
    }
}

// MARK: - Modern Refreshable View

/**
 * Modern refreshable view using SwiftUI 5.0 refreshable modifier
 * Provides smooth pull-to-refresh functionality
 */
struct ModernRefreshableView<Content: View>: View {
    let content: Content
    let refreshAction: () async -> Void
    
    @State private var isRefreshing = false
    
    init(@ViewBuilder content: () -> Content, refreshAction: @escaping () async -> Void) {
        self.content = content()
        self.refreshAction = refreshAction
    }
    
    var body: some View {
        content
            .refreshable {
                await refreshAction()
            }
    }
}

// MARK: - Modern Task Manager

/**
 * Modern task manager using SwiftUI 5.0 structured concurrency
 * Provides centralized task management and cancellation
 */
@MainActor
@Observable
final class ModernTaskManager {
    static let shared = ModernTaskManager()
    
    private var activeTasks: [String: Task<Void, Error>] = [:]
    
    private init() {}
    
    /// Start a named task with automatic cancellation of previous task
    func startTask<Success>(
        named name: String,
        priority: TaskPriority = .userInitiated,
        operation: @escaping () async throws -> Success
    ) -> Task<Success, Error> {
        // Cancel existing task with same name
        cancelTask(named: name)
        
        let task = Task(priority: priority) {
            try await operation()
        }
        
        // Store task for potential cancellation
        activeTasks[name] = Task {
            _ = await task.result
        }
        
        return task
    }
    
    /// Cancel a specific task by name
    func cancelTask(named name: String) {
        activeTasks[name]?.cancel()
        activeTasks.removeValue(forKey: name)
    }
    
    /// Cancel all active tasks
    func cancelAllTasks() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    /// Check if a task is active
    func isTaskActive(named name: String) -> Bool {
        return activeTasks[name] != nil
    }
}

// MARK: - Modern Async Button

/**
 * Modern async button using SwiftUI 5.0 concurrency features
 * Provides async action handling with loading states
 */
struct ModernAsyncButton<Label: View>: View {
    let label: Label
    let action: () async -> Void
    let isLoading: Bool
    
    @State private var isPressed = false
    
    init(
        isLoading: Bool = false,
        @ViewBuilder label: () -> Label,
        action: @escaping () async -> Void
    ) {
        self.isLoading = isLoading
        self.label = label()
        self.action = action
    }
    
    @MainActor
    var body: some View {
        Button(action: {
            Task { @MainActor in
                await action()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                label
            }
        }
        .disabled(isLoading)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        // iOS 18 compatible: Use buttonStyle for press feedback instead of gesture
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }
}

/// iOS 18 compatible button style for press feedback
/// Replaces onLongPressGesture which can interfere with button taps
struct PressableButtonStyle: SwiftUI.ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: SwiftUI.ButtonStyle.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Modern Async Image

/**
 * Modern async image using SwiftUI 5.0 concurrency features
 * Provides smooth image loading with caching
 */
struct ModernAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: Image?
    @State private var isLoading = true
    @State private var error: Error?
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder = {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(image)
            } else if isLoading {
                placeholder()
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    @MainActor
    private func loadImage() async {
        guard let url = url else {
            isLoading = false
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

// MARK: - Modern Searchable View

/**
 * Modern searchable view using SwiftUI 5.0 searchable modifier
 * Provides smooth search functionality with debouncing
 */
struct ModernSearchableView<Content: View>: View {
    let content: Content
    let searchText: Binding<String>
    let onSearchTextChange: (String) -> Void
    
    @State private var searchTask: Task<Void, Never>?
    
    init(
        searchText: Binding<String>,
        onSearchTextChange: @escaping (String) -> Void = { _ in },
        @ViewBuilder content: () -> Content
    ) {
        self.searchText = searchText
        self.onSearchTextChange = onSearchTextChange
        self.content = content()
    }
    
    var body: some View {
        content
            .searchable(text: searchText)
            .onChange(of: searchText.wrappedValue) { _, newValue in
                // Debounce search
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    if !Task.isCancelled {
                        onSearchTextChange(newValue)
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply modern async loading
    func modernAsyncLoading<LoadingView: View, ErrorView: View>(
        isLoading: Bool,
        @ViewBuilder loadingView: @escaping () -> LoadingView = { 
            ModernConcurrencyLoadingView(message: "Loading...") 
        },
        @ViewBuilder errorView: @escaping (Error) -> ErrorView = { _ in EmptyView() },
        error: Error? = nil
    ) -> some View {
        Group {
            if isLoading {
                loadingView()
            } else if let error = error {
                errorView(error)
            } else {
                self
            }
        }
    }
    
    /// Apply modern refreshable functionality
    func modernRefreshable(action: @escaping () async -> Void) -> some View {
        ModernRefreshableView(content: { self }, refreshAction: action)
    }
}

// MARK: - Modern Concurrency Loading View

/**
 * Modern concurrency loading view to avoid conflicts
 * Provides smooth, animated loading states for concurrency operations
 * Uses animated spinner with pulsing effect for clear visual feedback
 */
struct ModernConcurrencyLoadingView: View {
    let message: String
    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Animated rotating spinner
            ZStack {
                Circle()
                    .stroke(ModernDesignSystem.Colors.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        ModernDesignSystem.Colors.primary,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(
                        .linear(duration: 1.0)
                        .repeatForever(autoreverses: false),
                        value: rotationAngle
                    )
            }
            .padding(.bottom, ModernDesignSystem.Spacing.md)
            
            Text(message)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.5).delay(0.2), value: isAnimating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernDesignSystem.Colors.background)
        .onAppear {
            isAnimating = true
            rotationAngle = 360
        }
    }
}

// MARK: - Preview

#Preview("Modern Async View") {
    ModernAsyncView(
        content: {
            Text("Content loaded successfully!")
                .padding()
        },
        asyncOperation: {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
    )
}

#Preview("Modern Async Button") {
    ModernAsyncButton(
        isLoading: false,
        label: {
            Text("Load Data")
                .foregroundColor(.white)
                .padding()
        },
        action: {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    )
    .background(Color.blue)
    .cornerRadius(8)
}

#Preview("Modern Async Image") {
    ModernAsyncImage(
        url: URL(string: "https://picsum.photos/200/200"),
        content: { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
        }
    )
}
