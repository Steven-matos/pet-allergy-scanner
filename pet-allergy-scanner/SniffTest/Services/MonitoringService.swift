//
//  MonitoringService.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Observation

/// Monitoring service for checking system health and performance
@Observable
@MainActor
class MonitoringService {
    static let shared = MonitoringService()
    
    var isLoading = false
    var errorMessage: String?
    var healthStatus: HealthStatus?
    var systemMetrics: SystemMetrics?
    var systemStatus: SystemStatus?
    
    private let apiService = APIService.shared
    
    private init() {}
    
    /// Check system health status
    func checkHealthStatus() async {
        isLoading = true
        errorMessage = nil
        
        do {
            healthStatus = try await apiService.getHealthStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Get system metrics
    func getSystemMetrics(hours: Int = 24) async {
        guard await apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            systemMetrics = try await apiService.getMetrics(hours: hours)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Get system status
    func getSystemStatus() async {
        guard await apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            systemStatus = try await apiService.getSystemStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Check if system is healthy
    var isSystemHealthy: Bool {
        return healthStatus?.status == "healthy"
    }
    
    /// Get system uptime in hours
    var systemUptimeHours: Double {
        return systemStatus?.uptime ?? 0.0
    }
    
    /// Get error rate percentage
    var errorRatePercentage: Double {
        return systemStatus?.errorRate ?? 0.0
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Reset service state
    func reset() {
        healthStatus = nil
        systemMetrics = nil
        systemStatus = nil
        errorMessage = nil
    }
}
