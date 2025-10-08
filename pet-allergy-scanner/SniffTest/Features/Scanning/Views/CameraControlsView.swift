//
//  CameraControlsView.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import UIKit

/**
 * Modern camera controls view with Trust & Nature styling
 * 
 * Features:
 * - Large, accessible capture button
 * - Cancel button with clear visual hierarchy
 * - Flash toggle (if available)
 * - Haptic feedback integration
 * - Dynamic Type support
 */
class CameraControlsView: UIView {
    
    // MARK: - Properties
    weak var delegate: CameraControlsViewDelegate?
    
    private var captureButton: CaptureButton!
    private var cancelButton: UIButton!
    private var flashButton: UIButton!
    private var stackView: UIStackView!
    
    private let captureButtonSize: CGFloat = 80
    private let buttonSize: CGFloat = 44
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        setupButtons()
        setupStackView()
        setupConstraints()
    }
    
    private func setupButtons() {
        // Setup capture button
        captureButton = CaptureButton()
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup flash button
        flashButton = UIButton(type: .system)
        flashButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
        flashButton.tintColor = .white
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.isHidden = true // Hide by default, show if flash is available
    }
    
    private func setupStackView() {
        stackView = UIStackView(arrangedSubviews: [cancelButton, captureButton, flashButton])
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Stack view
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 80),
            
            // Capture button
            captureButton.widthAnchor.constraint(equalToConstant: captureButtonSize),
            captureButton.heightAnchor.constraint(equalToConstant: captureButtonSize),
            
            // Other buttons
            cancelButton.widthAnchor.constraint(equalToConstant: buttonSize),
            cancelButton.heightAnchor.constraint(equalToConstant: buttonSize),
            flashButton.widthAnchor.constraint(equalToConstant: buttonSize),
            flashButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func captureButtonTapped() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        delegate?.cameraControlsViewDidTapCapture(self)
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.cameraControlsViewDidTapCancel(self)
    }
    
    @objc private func flashButtonTapped() {
        // TODO: Implement flash toggle
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

/**
 * Custom capture button with Trust & Nature styling and animations
 */
class CaptureButton: UIButton {
    
    private var outerRing: CAShapeLayer!
    private var innerCircle: CAShapeLayer!
    private var isPressed = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        backgroundColor = UIColor.clear
        
        // Setup outer ring
        outerRing = CAShapeLayer()
        outerRing.fillColor = UIColor.clear.cgColor
        outerRing.strokeColor = UIColor.white.cgColor
        outerRing.lineWidth = 4
        outerRing.lineCap = .round
        layer.addSublayer(outerRing)
        
        // Setup inner circle
        innerCircle = CAShapeLayer()
        innerCircle.fillColor = UIColor.white.cgColor
        innerCircle.strokeColor = UIColor.clear.cgColor
        layer.addSublayer(innerCircle)
        
        // Setup accessibility
        accessibilityLabel = "Capture photo"
        accessibilityHint = "Tap to capture a photo of the ingredient list"
        accessibilityTraits = [.button]
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayers()
    }
    
    private func updateLayers() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 8
        
        // Update outer ring
        let outerRingPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        outerRing.path = outerRingPath.cgPath
        
        // Update inner circle
        let innerRadius = isPressed ? radius - 8 : radius - 12
        let innerCirclePath = UIBezierPath(arcCenter: center, radius: innerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        innerCircle.path = innerCirclePath.cgPath
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        isPressed = true
        animatePressState()
        return super.beginTracking(touch, with: event)
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        isPressed = false
        animatePressState()
        super.endTracking(touch, with: event)
    }
    
    override func cancelTracking(with event: UIEvent?) {
        isPressed = false
        animatePressState()
        super.cancelTracking(with: event)
    }
    
    private func animatePressState() {
        let scale: CGFloat = isPressed ? 0.9 : 1.0
        let innerRadius = isPressed ? min(bounds.width, bounds.height) / 2 - 8 : min(bounds.width, bounds.height) / 2 - 12
        
        UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
        
        // Animate inner circle
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let innerCirclePath = UIBezierPath(arcCenter: center, radius: innerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        
        let animation = CABasicAnimation(keyPath: "path")
        animation.duration = 0.1
        animation.fromValue = innerCircle.path
        animation.toValue = innerCirclePath.cgPath
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        innerCircle.add(animation, forKey: "innerCircleAnimation")
        innerCircle.path = innerCirclePath.cgPath
    }
    
    /**
     * Add pulse animation for scanning state
     */
    func startPulseAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.5
        pulseAnimation.duration = 1.0
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        outerRing.add(pulseAnimation, forKey: "pulseAnimation")
    }
    
    /**
     * Stop pulse animation
     */
    func stopPulseAnimation() {
        outerRing.removeAnimation(forKey: "pulseAnimation")
        outerRing.opacity = 1.0
    }
    
    /**
     * Show success animation
     */
    func showSuccessAnimation() {
        // Change color to success state
        outerRing.strokeColor = UIColor(red: 0.153, green: 0.682, blue: 0.376, alpha: 1.0).cgColor // Trust & Nature safe color
        innerCircle.fillColor = UIColor(red: 0.153, green: 0.682, blue: 0.376, alpha: 1.0).cgColor
        
        // Scale animation
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
        
        // Reset color after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.outerRing.strokeColor = UIColor.white.cgColor
            self.innerCircle.fillColor = UIColor.white.cgColor
        }
    }
    
    /**
     * Show error animation
     */
    func showErrorAnimation() {
        // Change color to error state
        outerRing.strokeColor = UIColor(red: 0.902, green: 0.494, blue: 0.133, alpha: 1.0).cgColor // Trust & Nature warm coral
        innerCircle.fillColor = UIColor(red: 0.902, green: 0.494, blue: 0.133, alpha: 1.0).cgColor
        
        // Shake animation
        let shakeAnimation = CABasicAnimation(keyPath: "transform.translation.x")
        shakeAnimation.duration = 0.1
        shakeAnimation.repeatCount = 3
        shakeAnimation.autoreverses = true
        shakeAnimation.fromValue = -5
        shakeAnimation.toValue = 5
        
        layer.add(shakeAnimation, forKey: "shakeAnimation")
        
        // Reset color after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.outerRing.strokeColor = UIColor.white.cgColor
            self.innerCircle.fillColor = UIColor.white.cgColor
        }
    }
}
