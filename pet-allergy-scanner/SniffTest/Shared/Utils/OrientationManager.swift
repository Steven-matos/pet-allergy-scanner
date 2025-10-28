//
//  OrientationManager.swift
//  SniffTest
//
//  Created by Steven Matos on 10/28/25.
//

@preconcurrency import SwiftUI
import UIKit

/// Utility for handling device orientation and responsive design
/// Follows Apple's guidelines for supporting all interface orientations
@MainActor
class OrientationManager: ObservableObject {
    @Published var isLandscape: Bool = false
    @Published var orientation: UIDeviceOrientation = .portrait
    
    private var orientationObserver: NSObjectProtocol?
    
    init() {
        setupOrientationObserver()
    }
    
    deinit {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// Set up orientation change observer
    private func setupOrientationObserver() {
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateOrientation()
            }
        }
        
        // Initial orientation check
        updateOrientation()
    }
    
    /// Update current orientation state
    private func updateOrientation() {
        let currentOrientation = UIDevice.current.orientation
        
        // Only update if orientation is valid
        guard currentOrientation.isValidInterfaceOrientation else { return }
        
        orientation = currentOrientation
        isLandscape = currentOrientation.isLandscape
    }
    
    /// Get responsive padding based on orientation
    var responsivePadding: CGFloat {
        isLandscape ? 16 : 20
    }
    
    /// Get responsive spacing based on orientation
    var responsiveSpacing: CGFloat {
        isLandscape ? 12 : 16
    }
    
    /// Get responsive font size multiplier
    var fontMultiplier: CGFloat {
        isLandscape ? 0.9 : 1.0
    }
    
    /// Check if current orientation is portrait
    var isPortrait: Bool {
        !isLandscape
    }
}

/// View modifier for responsive orientation handling
struct ResponsiveOrientationModifier: ViewModifier {
    @StateObject private var orientationManager = OrientationManager()
    
    func body(content: Content) -> some View {
        content
            .environmentObject(orientationManager)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                // Trigger view update on orientation change
            }
    }
}

/// Extension to add responsive orientation support to any view
extension View {
    /// Add responsive orientation handling to the view
    func responsiveOrientation() -> some View {
        modifier(ResponsiveOrientationModifier())
    }
}

/// Extension for UIDeviceOrientation to check valid interface orientations
extension UIDeviceOrientation {
    /// Check if orientation is a valid interface orientation
    var isValidInterfaceOrientation: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }
    
    /// Check if orientation is landscape
    var isLandscape: Bool {
        self == .landscapeLeft || self == .landscapeRight
    }
}
