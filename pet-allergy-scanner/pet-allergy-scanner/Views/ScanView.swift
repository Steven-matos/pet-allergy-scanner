//
//  ScanView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import AVFoundation

struct ScanView: View {
    @EnvironmentObject var petService: PetService
    @StateObject private var ocrService = OCRService.shared
    @StateObject private var scanService = ScanService.shared
    @State private var showingCamera = false
    @State private var showingPetSelection = false
    @State private var selectedPet: Pet?
    @State private var showingResults = false
    @State private var scanResult: Scan?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Scan Pet Food")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Point your camera at the ingredient list")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Camera Button
                Button(action: {
                    if petService.pets.isEmpty {
                        showingPetSelection = true
                    } else {
                        showingCamera = true
                    }
                }) {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("Tap to Scan")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(width: 200, height: 200)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(100)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(ocrService.isProcessing)
                
                // Processing Indicator
                if ocrService.isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Processing image...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                }
                
                // Extracted Text Preview
                if !ocrService.extractedText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Extracted Text:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ScrollView {
                            Text(ocrService.extractedText)
                                .font(.body)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 150)
                        
                        Button("Analyze Ingredients") {
                            analyzeIngredients()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                Spacer()
                
                // Recent Scans
                if !scanService.recentScans.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Scans")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(scanService.recentScans.prefix(5)) { scan in
                                    RecentScanCard(scan: scan)
                                        .onTapGesture {
                                            scanResult = scan
                                            showingResults = true
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    ocrService.extractText(from: image)
                }
            }
            .sheet(isPresented: $showingPetSelection) {
                PetSelectionView { pet in
                    selectedPet = pet
                    showingCamera = true
                }
            }
            .sheet(isPresented: $showingResults) {
                if let scan = scanResult {
                    ScanResultView(scan: scan)
                }
            }
            .onAppear {
                scanService.loadRecentScans()
            }
        }
    }
    
    private func analyzeIngredients() {
        guard let pet = selectedPet ?? petService.pets.first else { return }
        
        let ingredients = ocrService.processIngredients(from: ocrService.extractedText)
        
        let analysisRequest = ScanAnalysisRequest(
            petId: pet.id,
            extractedText: ocrService.extractedText,
            productName: nil
        )
        
        scanService.analyzeScan(analysisRequest) { result in
            scanResult = result
            showingResults = true
        }
    }
}

struct RecentScanCard: View {
    let scan: Scan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.blue)
                Text(scan.result?.productName ?? "Unknown Product")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let result = scan.result {
                HStack {
                    Circle()
                        .fill(colorForSafety(result.overallSafety))
                        .frame(width: 8, height: 8)
                    Text(result.safetyDisplayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(scan.createdAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .frame(width: 120)
    }
    
    private func colorForSafety(_ safety: String) -> Color {
        switch safety {
        case "safe":
            return .green
        case "caution":
            return .yellow
        case "unsafe":
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    ScanView()
        .environmentObject(PetService.shared)
}
