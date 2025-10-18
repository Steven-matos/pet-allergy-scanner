//
//  MedicationReminderService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import UserNotifications
import SwiftUI

/**
 * Medication Reminder Service
 * 
 * Manages medication reminders and notifications for pets
 * Follows SOLID principles with single responsibility for medication scheduling
 * Implements DRY by reusing common patterns from other services
 * Follows KISS by keeping the service focused and simple
 */
@MainActor
class MedicationReminderService: NSObject, ObservableObject {
    static let shared = MedicationReminderService()
    
    @Published var medicationReminders: [String: [MedicationReminder]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Constants
    
    private enum UserDefaultsKeys {
        static let medicationReminders = "medication_reminders"
    }
    
    private enum NotificationIdentifiers {
        static let medicationPrefix = "medication_reminder_"
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        loadMedicationReminders()
        setupNotificationCenter()
    }
    
    // MARK: - Public Methods
    
    /// Create a new medication reminder
    /// - Parameters:
    ///   - healthEventId: ID of the associated health event
    ///   - petId: ID of the pet
    ///   - medicationName: Name of the medication
    ///   - dosage: Dosage information
    ///   - frequency: How often to take the medication
    ///   - reminderTimes: Specific times for reminders
    ///   - startDate: When to start the reminders
    ///   - endDate: When to end the reminders (optional)
    /// - Returns: Created medication reminder
    func createMedicationReminder(
        healthEventId: String,
        petId: String,
        medicationName: String,
        dosage: String,
        frequency: MedicationFrequency,
        reminderTimes: [MedicationReminderTime],
        startDate: Date,
        endDate: Date? = nil
    ) async throws -> MedicationReminder {
        
        let reminder = MedicationReminder(
            id: UUID().uuidString,
            healthEventId: healthEventId,
            petId: petId,
            userId: "current_user", // TODO: Get from auth service
            medicationName: medicationName,
            dosage: dosage,
            frequency: frequency,
            reminderTimes: reminderTimes,
            startDate: startDate,
            endDate: endDate,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Add to local storage
        if medicationReminders[petId] == nil {
            medicationReminders[petId] = []
        }
        medicationReminders[petId]?.append(reminder)
        
        // Schedule notifications
        await scheduleMedicationNotifications(for: reminder)
        
        // Save to UserDefaults
        saveMedicationReminders()
        
        return reminder
    }
    
    /// Update an existing medication reminder
    /// - Parameters:
    ///   - reminderId: ID of the reminder to update
    ///   - petId: ID of the pet
    ///   - update: Update data
    /// - Returns: Updated medication reminder
    func updateMedicationReminder(
        reminderId: String,
        petId: String,
        update: MedicationReminderUpdate
    ) async throws -> MedicationReminder? {
        
        guard var reminders = medicationReminders[petId],
              let index = reminders.firstIndex(where: { $0.id == reminderId }) else {
            return nil
        }
        
        var updatedReminder = reminders[index]
        
        // Update fields
        if let medicationName = update.medicationName {
            updatedReminder = MedicationReminder(
                id: updatedReminder.id,
                healthEventId: updatedReminder.healthEventId,
                petId: updatedReminder.petId,
                userId: updatedReminder.userId,
                medicationName: medicationName,
                dosage: update.dosage ?? updatedReminder.dosage,
                frequency: update.frequency ?? updatedReminder.frequency,
                reminderTimes: update.reminderTimes ?? updatedReminder.reminderTimes,
                startDate: update.startDate ?? updatedReminder.startDate,
                endDate: update.endDate ?? updatedReminder.endDate,
                isActive: update.isActive ?? updatedReminder.isActive,
                createdAt: updatedReminder.createdAt,
                updatedAt: Date()
            )
        }
        
        // Cancel existing notifications
        await cancelMedicationNotifications(for: updatedReminder)
        
        // Schedule new notifications if active
        if updatedReminder.isActive {
            await scheduleMedicationNotifications(for: updatedReminder)
        }
        
        // Update local storage
        reminders[index] = updatedReminder
        medicationReminders[petId] = reminders
        
        // Save to UserDefaults
        saveMedicationReminders()
        
        return updatedReminder
    }
    
    /// Delete a medication reminder
    /// - Parameters:
    ///   - reminderId: ID of the reminder to delete
    ///   - petId: ID of the pet
    func deleteMedicationReminder(reminderId: String, petId: String) async throws {
        guard var reminders = medicationReminders[petId],
              let index = reminders.firstIndex(where: { $0.id == reminderId }) else {
            return
        }
        
        let reminder = reminders[index]
        
        // Cancel notifications
        await cancelMedicationNotifications(for: reminder)
        
        // Remove from local storage
        reminders.remove(at: index)
        medicationReminders[petId] = reminders
        
        // Save to UserDefaults
        saveMedicationReminders()
    }
    
    /// Get medication reminders for a specific pet
    /// - Parameter petId: ID of the pet
    /// - Returns: Array of medication reminders
    func getMedicationReminders(for petId: String) -> [MedicationReminder] {
        return medicationReminders[petId] ?? []
    }
    
    /// Get active medication reminders for a specific pet
    /// - Parameter petId: ID of the pet
    /// - Returns: Array of active medication reminders
    func getActiveMedicationReminders(for petId: String) -> [MedicationReminder] {
        return getMedicationReminders(for: petId).filter { $0.isCurrentlyActive }
    }
    
    /// Get medication reminders for a specific health event
    /// - Parameter healthEventId: ID of the health event
    /// - Returns: Array of medication reminders
    func getMedicationRemindersForHealthEvent(_ healthEventId: String) -> [MedicationReminder] {
        return medicationReminders.values.flatMap { $0 }.filter { $0.healthEventId == healthEventId }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationCenter() {
        notificationCenter.delegate = self
    }
    
    private func scheduleMedicationNotifications(for reminder: MedicationReminder) async {
        guard reminder.isActive else { return }
        
        for (index, reminderTime) in reminder.reminderTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "💊 Medication Reminder"
            content.body = "Time to give \(reminder.medicationName) (\(reminder.dosage)) to your pet"
            content.sound = .default
            content.badge = 1
            
            // Create unique identifier for each reminder time
            let identifier = "\(NotificationIdentifiers.medicationPrefix)\(reminder.id)_\(index)"
            
            // Schedule based on frequency
            let trigger: UNNotificationTrigger
            
            switch reminder.frequency {
            case .once:
                // Schedule for start date at the specified time
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day], from: reminder.startDate)
                let timeComponents = reminderTime.timeComponents
                let finalComponents = DateComponents(
                    year: components.year,
                    month: components.month,
                    day: components.day,
                    hour: timeComponents.hour,
                    minute: timeComponents.minute
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: finalComponents, repeats: false)
                
            case .daily:
                // Schedule daily at the specified time
                trigger = UNCalendarNotificationTrigger(
                    dateMatching: reminderTime.timeComponents,
                    repeats: true
                )
                
            case .twiceDaily, .threeTimesDaily:
                // Schedule daily at the specified time
                trigger = UNCalendarNotificationTrigger(
                    dateMatching: reminderTime.timeComponents,
                    repeats: true
                )
                
            case .everyOtherDay:
                // Schedule every other day at the specified time
                let calendar = Calendar.current
                let startComponents = calendar.dateComponents([.year, .month, .day], from: reminder.startDate)
                let timeComponents = reminderTime.timeComponents
                let finalComponents = DateComponents(
                    year: startComponents.year,
                    month: startComponents.month,
                    day: startComponents.day,
                    hour: timeComponents.hour,
                    minute: timeComponents.minute
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: finalComponents, repeats: true)
                
            case .weekly:
                // Schedule weekly at the specified time
                let calendar = Calendar.current
                let weekday = calendar.component(.weekday, from: reminder.startDate)
                let timeComponents = reminderTime.timeComponents
                let finalComponents = DateComponents(
                    hour: timeComponents.hour,
                    minute: timeComponents.minute,
                    weekday: weekday
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: finalComponents, repeats: true)
                
            case .asNeeded:
                // Don't schedule automatic reminders for as-needed medications
                continue
            }
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            do {
                try await notificationCenter.add(request)
                print("✅ Scheduled medication reminder: \(reminder.medicationName) at \(reminderTime.displayTime)")
            } catch {
                print("❌ Failed to schedule medication reminder: \(error)")
            }
        }
    }
    
    private func cancelMedicationNotifications(for reminder: MedicationReminder) async {
        let identifiers = reminder.reminderTimes.enumerated().map { index, _ in
            "\(NotificationIdentifiers.medicationPrefix)\(reminder.id)_\(index)"
        }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("✅ Cancelled medication reminders for: \(reminder.medicationName)")
    }
    
    private func loadMedicationReminders() {
        guard let data = userDefaults.data(forKey: UserDefaultsKeys.medicationReminders),
              let reminders = try? JSONDecoder().decode([String: [MedicationReminder]].self, from: data) else {
            return
        }
        
        medicationReminders = reminders
    }
    
    private func saveMedicationReminders() {
        guard let data = try? JSONEncoder().encode(medicationReminders) else {
            return
        }
        
        userDefaults.set(data, forKey: UserDefaultsKeys.medicationReminders)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension MedicationReminderService: UNUserNotificationCenterDelegate {
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let identifier = response.notification.request.identifier
        
        if identifier.hasPrefix(NotificationIdentifiers.medicationPrefix) {
            // Handle medication reminder tap
            print("📱 User tapped medication reminder: \(identifier)")
        }
        
        completionHandler()
    }
}
