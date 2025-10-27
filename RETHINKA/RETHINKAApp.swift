//
//  RETHINKAApp.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import SwiftUI
import SwiftData
import WidgetKit

@main
struct RETHINKAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ExamTimeline.self,
            QuizQuestion.self,
            CourseNote.self,
            DailyQuiz.self
        ])
        
        // Use App Group to share data with widget
        let appGroupID = "group.A4.RETHINKA"
        
        // Try to get App Group URL
        if let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            // App Groups configured, use shared storage
            let storeURL = appGroupURL.appendingPathComponent("RETHINKA.sqlite")
            print("App: Using App Group storage at: \(storeURL.path)")
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer with App Group: \(error)")
            }
        } else {
            // App Groups not configured - fall back to default (widget won't work)
            print("WARNING: App Groups not configured! Widget will NOT see data.")
            print("Add App Groups capability with ID: \(appGroupID)")
            
            let modelConfiguration = ModelConfiguration(schema: schema)
            
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .onAppear {
                    
                    // Initialize notification settings on app launch
                    setupInitialNotifications()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupInitialNotifications() {
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        
        // Only set up if user hasn't explicitly disabled them
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            // First launch, request permission
            NotificationManager.shared.requestAuthorization { granted in
                UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
                if granted {
                    let hour = UserDefaults.standard.integer(forKey: "notificationTime")
                    NotificationManager.shared.scheduleDailyReminders(at: hour > 0 ? hour : 9)
                }
            }
        } else if notificationsEnabled {
            // User has enabled notifications, schedule them
            let hour = UserDefaults.standard.integer(forKey: "notificationTime")
            NotificationManager.shared.scheduleDailyReminders(at: hour > 0 ? hour : 9)
        }
    }
}
