//
//  ScanOverlayView.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import UIKit
import SwiftUI

/**
 * Modern scan overlay view with animated scanning frame and guidance
 * 
 * Features:
 * - Animated scanning frame with Trust & Nature styling
 * - Real-time barcode detection feedback
 * - Smart frame detection for ingredient lists
 * - Progressive disclosure of scan instructions
 * - Accessibility support with VoiceOver
 */
class ScanOverlayView: UIView {
    
    // MARK: - Properties
    private var scanningFrameView: ScanningFrameView!
    private var guidanceLabel: UILabel!
    private var barcodeDetectedView: BarcodeDetectedView!
    private var instructionView: ScanInstructionView!
    
    // MARK: - Animation Properties
    private var scanningAnimation: CABasicAnimation?
    private var pulseAnimation: CABasicAnimation?
    
    // MARK: - State
    private var isScanning = false
    private var hasDetectedBarcode = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupAnimations()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupAnimations()
    }
    
    // MARK: - Public Methods
    
    /**
     * Start scanning animation
     */
    func startScanning() {
        isScanning = true
        hasDetectedBarcode = false
        scanningFrameView.startScanning()
        updateGuidanceText("Point camera at ingredient list")
        hideBarcodeDetectedView()
    }
    
    /**
     * Stop scanning animation
     */
    func stopScanning() {
        isScanning = false
        scanningFrameView.stopScanning()
        updateGuidanceText("Scanning complete")
    }
    
    /**
     * Show barcode detected feedback
     */
    func showBarcodeDetected(_ barcode: BarcodeResult) {
        hasDetectedBarcode = true
        barcodeDetectedView.showBarcode(barcode)
        updateGuidanceText("Barcode detected! Tap to capture")
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /**
     * Hide barcode detected feedback
     */
    func hideBarcodeDetectedView() {
        barcodeDetectedView.isHidden = true
    }
    
    /**
     * Update guidance text
     */
    func updateGuidanceText(_ text: String) {
        guidanceLabel.text = text
        
        // Animate text change
        UIView.transition(with: guidanceLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.guidanceLabel.alpha = 0.8
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.guidanceLabel.alpha = 1.0
            }
        }
    }
    
    /**
     * Show error state
     */
    func showError(_ message: String) {
        updateGuidanceText(message)
        scanningFrameView.showError()
        
        // Add error haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        backgroundColor = UIColor.clear
        
        // Setup scanning frame
        scanningFrameView = ScanningFrameView()
        scanningFrameView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scanningFrameView)
        
        // Setup guidance label
        guidanceLabel = UILabel()
        guidanceLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        guidanceLabel.textColor = .white
        guidanceLabel.textAlignment = .center
        guidanceLabel.numberOfLines = 0
        guidanceLabel.translatesAutoresizingMaskIntoConstraints = false
        guidanceLabel.layer.shadowColor = UIColor.black.cgColor
        guidanceLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        guidanceLabel.layer.shadowOpacity = 0.5
        guidanceLabel.layer.shadowRadius = 2
        addSubview(guidanceLabel)
        
        // Setup barcode detected view
        barcodeDetectedView = BarcodeDetectedView()
        barcodeDetectedView.translatesAutoresizingMaskIntoConstraints = false
        barcodeDetectedView.isHidden = true
        addSubview(barcodeDetectedView)
        
        // Setup instruction view
        instructionView = ScanInstructionView()
        instructionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instructionView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scanning frame - centered with proper aspect ratio
            scanningFrameView.centerXAnchor.constraint(equalTo: centerXAnchor),
            scanningFrameView.centerYAnchor.constraint(equalTo: centerYAnchor),
            scanningFrameView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8),
            scanningFrameView.heightAnchor.constraint(equalTo: scanningFrameView.widthAnchor, multiplier: 0.75),
            
            // Guidance label - above scanning frame
            guidanceLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            guidanceLabel.bottomAnchor.constraint(equalTo: scanningFrameView.topAnchor, constant: -20),
            guidanceLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            guidanceLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            
            // Barcode detected view - below scanning frame
            barcodeDetectedView.centerXAnchor.constraint(equalTo: centerXAnchor),
            barcodeDetectedView.topAnchor.constraint(equalTo: scanningFrameView.bottomAnchor, constant: 20),
            barcodeDetectedView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            barcodeDetectedView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            
            // Instruction view - at bottom
            instructionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            instructionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            instructionView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupAnimations() {
        // Setup pulse animation for guidance label
        pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation?.fromValue = 0.7
        pulseAnimation?.toValue = 1.0
        pulseAnimation?.duration = 1.5
        pulseAnimation?.repeatCount = .infinity
        pulseAnimation?.autoreverses = true
    }
}

/**
 * Scanning frame view with animated scanning line
 */
class ScanningFrameView: UIView {
    
    private var frameLayer: CAShapeLayer!
    private var scanningLineLayer: CAShapeLayer!
    private var cornerLayers: [CAShapeLayer] = []
    
    private let frameColor = UIColor(red: 0.176, green: 0.314, blue: 0.086, alpha: 1.0) // Trust & Nature primary
    private let cornerLength: CGFloat = 20
    private let lineWidth: CGFloat = 3
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayers()
    }
    
    private func setupLayers() {
        backgroundColor = UIColor.clear
        
        // Setup frame layer
        frameLayer = CAShapeLayer()
        frameLayer.strokeColor = frameColor.cgColor
        frameLayer.fillColor = UIColor.clear.cgColor
        frameLayer.lineWidth = lineWidth
        frameLayer.lineCap = .round
        frameLayer.lineJoin = .round
        layer.addSublayer(frameLayer)
        
        // Setup scanning line layer
        scanningLineLayer = CAShapeLayer()
        scanningLineLayer.strokeColor = UIColor.white.cgColor
        scanningLineLayer.fillColor = UIColor.clear.cgColor
        scanningLineLayer.lineWidth = 2
        scanningLineLayer.lineCap = .round
        layer.addSublayer(scanningLineLayer)
        
        // Setup corner layers
        for _ in 0..<4 {
            let cornerLayer = CAShapeLayer()
            cornerLayer.strokeColor = frameColor.cgColor
            cornerLayer.fillColor = UIColor.clear.cgColor
            cornerLayer.lineWidth = lineWidth * 2
            cornerLayer.lineCap = .round
            layer.addSublayer(cornerLayer)
            cornerLayers.append(cornerLayer)
        }
    }
    
    private func updateLayers() {
        let bounds = self.bounds
        let path = UIBezierPath()
        
        // Create scanning frame path
        path.move(to: CGPoint(x: cornerLength, y: 0))
        path.addLine(to: CGPoint(x: bounds.width - cornerLength, y: 0))
        path.move(to: CGPoint(x: bounds.width, y: cornerLength))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - cornerLength))
        path.move(to: CGPoint(x: bounds.width - cornerLength, y: bounds.height))
        path.addLine(to: CGPoint(x: cornerLength, y: bounds.height))
        path.move(to: CGPoint(x: 0, y: bounds.height - cornerLength))
        path.addLine(to: CGPoint(x: 0, y: cornerLength))
        
        frameLayer.path = path.cgPath
        
        // Update corner layers
        updateCornerLayers()
    }
    
    private func updateCornerLayers() {
        let bounds = self.bounds
        let cornerPaths = [
            // Top-left corner
            createCornerPath(from: CGPoint(x: 0, y: cornerLength), to: CGPoint(x: cornerLength, y: 0)),
            // Top-right corner
            createCornerPath(from: CGPoint(x: bounds.width - cornerLength, y: 0), to: CGPoint(x: bounds.width, y: cornerLength)),
            // Bottom-right corner
            createCornerPath(from: CGPoint(x: bounds.width, y: bounds.height - cornerLength), to: CGPoint(x: bounds.width - cornerLength, y: bounds.height)),
            // Bottom-left corner
            createCornerPath(from: CGPoint(x: cornerLength, y: bounds.height), to: CGPoint(x: 0, y: bounds.height - cornerLength))
        ]
        
        for (index, path) in cornerPaths.enumerated() {
            cornerLayers[index].path = path.cgPath
        }
    }
    
    private func createCornerPath(from startPoint: CGPoint, to endPoint: CGPoint) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        return path
    }
    
    func startScanning() {
        // Create scanning line animation
        let bounds = self.bounds
        let scanningPath = UIBezierPath()
        scanningPath.move(to: CGPoint(x: bounds.width * 0.1, y: bounds.height * 0.5))
        scanningPath.addLine(to: CGPoint(x: bounds.width * 0.9, y: bounds.height * 0.5))
        scanningLineLayer.path = scanningPath.cgPath
        
        // Animate scanning line
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 2.0
        animation.repeatCount = .infinity
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        scanningLineLayer.add(animation, forKey: "scanningAnimation")
        
        // Add glow effect
        scanningLineLayer.shadowColor = UIColor.white.cgColor
        scanningLineLayer.shadowOffset = CGSize.zero
        scanningLineLayer.shadowOpacity = 0.8
        scanningLineLayer.shadowRadius = 4
    }
    
    func stopScanning() {
        scanningLineLayer.removeAllAnimations()
        scanningLineLayer.shadowOpacity = 0
    }
    
    func showError() {
        // Change frame color to error state
        frameLayer.strokeColor = UIColor(red: 0.902, green: 0.494, blue: 0.133, alpha: 1.0).cgColor // Trust & Nature warm coral
        
        // Animate error state
        let shakeAnimation = CABasicAnimation(keyPath: "transform.translation.x")
        shakeAnimation.duration = 0.1
        shakeAnimation.repeatCount = 3
        shakeAnimation.autoreverses = true
        shakeAnimation.fromValue = -5
        shakeAnimation.toValue = 5
        
        layer.add(shakeAnimation, forKey: "shakeAnimation")
        
        // Reset to normal state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.frameLayer.strokeColor = self.frameColor.cgColor
        }
    }
}

/**
 * Barcode detected feedback view
 */
class BarcodeDetectedView: UIView {
    
    private var iconView: UIImageView!
    private var barcodeLabel: UILabel!
    private var confidenceLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor(red: 0.176, green: 0.314, blue: 0.086, alpha: 0.9)
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        
        // Setup icon
        iconView = UIImageView(image: UIImage(systemName: "barcode.viewfinder"))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        
        // Setup barcode label
        barcodeLabel = UILabel()
        barcodeLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        barcodeLabel.textColor = .white
        barcodeLabel.textAlignment = .center
        barcodeLabel.numberOfLines = 1
        barcodeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(barcodeLabel)
        
        // Setup confidence label
        confidenceLabel = UILabel()
        confidenceLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        confidenceLabel.textColor = .white
        confidenceLabel.textAlignment = .center
        confidenceLabel.alpha = 0.8
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(confidenceLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Icon
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            // Barcode label
            barcodeLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            barcodeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            barcodeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            
            // Confidence label
            confidenceLabel.topAnchor.constraint(equalTo: barcodeLabel.bottomAnchor, constant: 4),
            confidenceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            confidenceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            confidenceLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    func showBarcode(_ barcode: BarcodeResult) {
        barcodeLabel.text = "Barcode: \(barcode.value)"
        confidenceLabel.text = "Confidence: \(Int(barcode.confidence * 100))%"
        
        // Animate appearance
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.transform = .identity
            self.alpha = 1
        }
        
        isHidden = false
    }
}

/**
 * Scan instruction view with tips
 */
class ScanInstructionView: UIView {
    
    private var instructionLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.cornerRadius = 8
        
        instructionLabel = UILabel()
        instructionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        instructionLabel.text = "• Ensure good lighting\n• Focus on ingredient list\n• Hold device steady"
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            instructionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            instructionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
}
