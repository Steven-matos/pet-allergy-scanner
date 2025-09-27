//
//  HistoryView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var scanService = ScanService.shared
    
    var body: some View {
        NavigationView {
            VStack {
                if scanService.isLoading {
                    ProgressView("Loading history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if scanService.recentScans.isEmpty {
                    EmptyHistoryView()
                } else {
                    List(scanService.recentScans) { scan in
                        ScanHistoryRowView(scan: scan)
                    }
                }
            }
            .navigationTitle("Scan History")
            .onAppear {
                scanService.loadRecentScans()
            }
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Scans Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start scanning pet food ingredients to see your history here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ScanHistoryRowView: View {
    let scan: Scan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(scan.result?.productName ?? "Unknown Product")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let result = scan.result {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForSafety(result.overallSafety))
                            .frame(width: 8, height: 8)
                        Text(result.safetyDisplayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let result = scan.result {
                Text("Found \(result.ingredientsFound.count) ingredients")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(scan.createdAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
    HistoryView()
}
