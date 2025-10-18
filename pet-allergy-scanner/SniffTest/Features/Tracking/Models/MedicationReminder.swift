//
//  MedicationReminder.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import UserNotifications

/**
 * Medication Reminder Model
 * 
 * Represents a scheduled medication reminder for a pet
 * Follows SOLID principles with single responsibility for medication scheduling
 * Implements DRY by reusing common patterns from other models
 * Follows KISS by keeping the reminder system simple and focused
 */
struct MedicationReminder: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let healthEventId: String
    let petId: String
    let userId: String
    let medicationName: String
    let dosage: String
    let frequency: MedicationFrequency
    let reminderTimes: [MedicationReminderTime]
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    /// Validation for medication reminder data
    var isValid: Bool {
        return !id.isEmpty && !healthEventId.isEmpty && !petId.isEmpty && !userId.isEmpty && 
               !medicationName.isEmpty && !dosage.isEmpty && !reminderTimes.isEmpty
    }
    
    /// Check if reminder is currently active
    var isCurrentlyActive: Bool {
        let now = Date()
        return isActive && now >= startDate && (endDate == nil || now <= endDate!)
    }
    
    /// Get next reminder time
    var nextReminderTime: Date? {
        guard isCurrentlyActive else { return nil }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Find the next reminder time from today
        for reminderTime in reminderTimes {
            let nextDate = calendar.nextDate(after: now, matching: reminderTime.timeComponents, matchingPolicy: .nextTime) ?? now
            if nextDate > now {
                return nextDate
            }
        }
        
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case healthEventId = "health_event_id"
        case petId = "pet_id"
        case userId = "user_id"
        case medicationName = "medication_name"
        case dosage
        case frequency
        case reminderTimes = "reminder_times"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/**
 * Medication Frequency Enumeration
 * 
 * Defines how often medication should be taken
 */
enum MedicationFrequency: String, Codable, CaseIterable {
    case once = "once"
    case daily = "daily"
    case twiceDaily = "twice_daily"
    case threeTimesDaily = "three_times_daily"
    case everyOtherDay = "every_other_day"
    case weekly = "weekly"
    case asNeeded = "as_needed"
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .once: return "Once"
        case .daily: return "Daily"
        case .twiceDaily: return "Twice Daily"
        case .threeTimesDaily: return "Three Times Daily"
        case .everyOtherDay: return "Every Other Day"
        case .weekly: return "Weekly"
        case .asNeeded: return "As Needed"
        }
    }
    
    /// Description for UI
    var description: String {
        switch self {
        case .once: return "One time only"
        case .daily: return "Once per day"
        case .twiceDaily: return "Morning and evening"
        case .threeTimesDaily: return "Morning, afternoon, and evening"
        case .everyOtherDay: return "Every other day"
        case .weekly: return "Once per week"
        case .asNeeded: return "When symptoms occur"
        }
    }
    
    /// Default reminder times for this frequency
    var defaultReminderTimes: [MedicationReminderTime] {
        switch self {
        case .once:
            return [MedicationReminderTime(time: "09:00", label: "Morning")]
        case .daily:
            return [MedicationReminderTime(time: "09:00", label: "Morning")]
        case .twiceDaily:
            return [
                MedicationReminderTime(time: "09:00", label: "Morning"),
                MedicationReminderTime(time: "21:00", label: "Evening")
            ]
        case .threeTimesDaily:
            return [
                MedicationReminderTime(time: "09:00", label: "Morning"),
                MedicationReminderTime(time: "14:00", label: "Afternoon"),
                MedicationReminderTime(time: "21:00", label: "Evening")
            ]
        case .everyOtherDay:
            return [MedicationReminderTime(time: "09:00", label: "Morning")]
        case .weekly:
            return [MedicationReminderTime(time: "09:00", label: "Weekly")]
        case .asNeeded:
            return []
        }
    }
}

/**
 * Medication Reminder Time
 * 
 * Represents a specific time for medication reminders
 */
struct MedicationReminderTime: Codable, Equatable, Hashable {
    let time: String // Format: "HH:mm"
    let label: String // e.g., "Morning", "Evening"
    
    /// Time components for scheduling
    var timeComponents: DateComponents {
        let timeParts = time.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else {
            return DateComponents(hour: 9, minute: 0)
        }
        return DateComponents(hour: hour, minute: minute)
    }
    
    /// Display time for UI
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let timeParts = time.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else {
            return "9:00 AM"
        }
        
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

/**
 * Medication Reminder Creation Model
 * 
 * Used for creating new medication reminders
 */
struct MedicationReminderCreate: Codable {
    let healthEventId: String
    let petId: String
    let medicationName: String
    let dosage: String
    let frequency: MedicationFrequency
    let reminderTimes: [MedicationReminderTime]
    let startDate: Date
    let endDate: Date?
    
    /// Validation for medication reminder creation
    var isValid: Bool {
        return !healthEventId.isEmpty && !petId.isEmpty && !medicationName.isEmpty && 
               !dosage.isEmpty && !reminderTimes.isEmpty
    }
    
    /// Validation errors for medication reminder creation
    var validationErrors: [String] {
        var errors: [String] = []
        
        if healthEventId.isEmpty {
            errors.append("Health event ID is required")
        }
        
        if petId.isEmpty {
            errors.append("Pet ID is required")
        }
        
        if medicationName.isEmpty {
            errors.append("Medication name is required")
        }
        
        if dosage.isEmpty {
            errors.append("Dosage is required")
        }
        
        if reminderTimes.isEmpty {
            errors.append("At least one reminder time is required")
        }
        
        return errors
    }
    
    enum CodingKeys: String, CodingKey {
        case healthEventId = "health_event_id"
        case petId = "pet_id"
        case medicationName = "medication_name"
        case dosage
        case frequency
        case reminderTimes = "reminder_times"
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

/**
 * Medication Reminder Update Model
 * 
 * Used for updating existing medication reminders
 */
struct MedicationReminderUpdate: Codable {
    let medicationName: String?
    let dosage: String?
    let frequency: MedicationFrequency?
    let reminderTimes: [MedicationReminderTime]?
    let startDate: Date?
    let endDate: Date?
    let isActive: Bool?
    
    /// Check if any fields are being updated
    var hasUpdates: Bool {
        return medicationName != nil || dosage != nil || frequency != nil || 
               reminderTimes != nil || startDate != nil || endDate != nil || isActive != nil
    }
    
    enum CodingKeys: String, CodingKey {
        case medicationName = "medication_name"
        case dosage
        case frequency
        case reminderTimes = "reminder_times"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
    }
}
