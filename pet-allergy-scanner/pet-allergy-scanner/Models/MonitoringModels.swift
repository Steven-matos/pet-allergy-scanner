//
//  MonitoringModels.swift
//  pet-allergy-scanner
//
//  Created by Code Assistant, 2025.
//

import Foundation

/// System health status model
struct HealthStatus: Codable {
    let status: String
    let version: String
    let environment: String
    let debugMode: Bool
    let database: DatabaseStatus
    let timestamp: Double
    
    enum CodingKeys: String, CodingKey {
        case status
        case version
        case environment
        case debugMode = "debug_mode"
        case database
        case timestamp
    }
}

/// Database status model
struct DatabaseStatus: Codable {
    let status: String
    let connectionCount: Int
    let responseTime: Double
    let lastCheck: Date
    
    enum CodingKeys: String, CodingKey {
        case status
        case connectionCount = "connection_count"
        case responseTime = "response_time"
        case lastCheck = "last_check"
    }
}

/// System metrics model
struct SystemMetrics: Codable {
    let system: SystemInfo
    let applicationHealth: HealthStatus
    let timestamp: Double
    
    enum CodingKeys: String, CodingKey {
        case system
        case applicationHealth = "application_health"
        case timestamp
    }
}

/// System information model
struct SystemInfo: Codable {
    let cpuPercent: Double
    let memoryPercent: Double
    let memoryTotalMB: Double
    let memoryUsedMB: Double
    let diskPercent: Double
    let diskTotalGB: Double
    let diskUsedGB: Double
    
    enum CodingKeys: String, CodingKey {
        case cpuPercent = "cpu_percent"
        case memoryPercent = "memory_percent"
        case memoryTotalMB = "memory_total_mb"
        case memoryUsedMB = "memory_used_mb"
        case diskPercent = "disk_percent"
        case diskTotalGB = "disk_total_gb"
        case diskUsedGB = "disk_used_gb"
    }
}

/// System status model
struct SystemStatus: Codable {
    let isHealthy: Bool
    let uptime: Double
    let activeUsers: Int
    let totalRequests: Int
    let errorRate: Double
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case isHealthy = "is_healthy"
        case uptime
        case activeUsers = "active_users"
        case totalRequests = "total_requests"
        case errorRate = "error_rate"
        case lastUpdated = "last_updated"
    }
}
