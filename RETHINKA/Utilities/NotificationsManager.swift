//
//  NotificationsManager.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import UserNotifications
import SwiftData

class NotificationManager {
    static let shared = NotificationManager()
    
    private let dailyReminderIdentifier = "daily-quiz-reminder"
    
    private init() {}
    
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
            
            completion?(granted)
        }
    }
    
    // Daily Reminders
    
    func scheduleDailyReminders(at hour: Int) {
        // Cancel existing reminders
        cancelAllReminders()
        
        // Schedule new daily reminder
        let content = UNMutableNotificationContent()
        content.title = "Daily Quiz Reminder"
        content.body = "You have incomplete quizzes today. Keep up the momentum!"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "DAILY_REMINDER"
        
        // Create date components for the notification time
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        
        // Create trigger that repeats daily
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily reminder: \(error.localizedDescription)")
            } else {
                print("Daily reminder scheduled for \(hour):00")
            }
        }
    }
    
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
        UNUserNotificationCenter.current().setBadgeCount(0)
        print("Cancelled all daily reminders")
    }
    
    // Timeline-Specific Notifications (Legacy - kept for compatibility)
    
    func scheduleDailyQuizNotification(for timeline: ExamTimeline) {
        let center = UNUserNotificationCenter.current()
        
        // Remove existing notifications for this timeline
        center.removePendingNotificationRequests(withIdentifiers: [timeline.id.uuidString])
        
        for quiz in timeline.dailyQuizzes where !quiz.isCompleted {
            let content = UNMutableNotificationContent()
            content.title = "Quiz Available"
            content.body = "Complete today's quiz for \(timeline.examName)"
            content.sound = .default
            content.badge = 1
            
            let calendar = Calendar.current
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: quiz.date)
            dateComponents.hour = 9
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let identifier = "\(timeline.id.uuidString)-\(quiz.id.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func cancelNotifications(for timelineId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.filter { $0.identifier.hasPrefix(timelineId.uuidString) }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
    
    // Update Badge Count
    
    func updateBadgeCount(incompleteQuizCount: Int) {
        UNUserNotificationCenter.current().setBadgeCount(incompleteQuizCount)
    }
}
