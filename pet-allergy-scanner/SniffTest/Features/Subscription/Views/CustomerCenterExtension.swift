//
//  CustomerCenterExtension.swift
//  SniffTest
//
//  Helper extensions for presenting RevenueCat Customer Center.
//

import SwiftUI
import RevenueCatUI
import UIKit

/// Extension to present Customer Center from a UIViewController
extension CustomerCenterView {
    /// Present the Customer Center as a sheet from the given view controller.
    /// - Parameter viewController: The view controller to present from.
    func presentAsSheet(from viewController: UIViewController) {
        let hostingController = UIHostingController(rootView: self)
        hostingController.modalPresentationStyle = .pageSheet
        
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        viewController.present(hostingController, animated: true)
    }
}

