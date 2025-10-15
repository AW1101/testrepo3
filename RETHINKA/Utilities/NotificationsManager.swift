//
//  NotificationsManager.swift
//  RETHINKA
//
//  Created by Aston Walsh on 14/10/2025.
//

import Foundation
import UserNotifications

// Have to rework a lot of this myself, still pretty stock standard/wrong/from a template
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleDailyQuizNotification(for timeline: ExamTimeline) {
        let center = UNUserNotificationCenter.current()
        
        // Remove existing notifications for this timeline
        center.removePendingNotificationRequests(withIdentifiers: [timeline.id.uuidString])
        
        for quiz in timeline.dailyQuizzes where !quiz.isCompleted {
            let content = UNMutableNotificationContent()
            content.title = "Daily Quiz Ready!"
            content.body = "Complete today's quiz for \(timeline.examName)"
            content.sound = .default
            content.badge = 1
            
            let calendar = Calendar.current
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: quiz.date)
            dateComponents.hour = 9 // 9 AM notification
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
}
