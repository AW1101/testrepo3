//
//  AppDelegate.swift
//  RETHINKA
//
//  Created by Aston Walsh on 20/10/2025.
//


import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Set initial badge count
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification tap - could navigate to specific timeline or quiz
        print("Notification tapped: \(userInfo)")
        
        completionHandler()
    }
    
    // Update badge when app becomes active
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear badge when user opens app
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
