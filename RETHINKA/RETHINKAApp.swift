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
    
    // Configure shared model container using App Groups for widget data sharing
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ExamTimeline.self,
            QuizQuestion.self,
            CourseNote.self,
            DailyQuiz.self
        ])
        
        let appGroupID = "group.A4.RETHINKA"
        
        if let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
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
                    setupInitialNotifications()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // Set up notifications on first launch or if previously enabled
    private func setupInitialNotifications() {
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            NotificationManager.shared.requestAuthorization { granted in
                UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
                if granted {
                    let hour = UserDefaults.standard.integer(forKey: "notificationTime")
                    NotificationManager.shared.scheduleDailyReminders(at: hour > 0 ? hour : 9)
                }
            }
        } else if notificationsEnabled {
            let hour = UserDefaults.standard.integer(forKey: "notificationTime")
            NotificationManager.shared.scheduleDailyReminders(at: hour > 0 ? hour : 9)
        }
    }
}
