//
//  SettingsView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//


import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notificationTime") private var notificationTime = 9
    @AppStorage("difficultyLevel") private var difficultyLevel = "Medium"
    
    @State private var showingPermissionAlert = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 10) {
                            Circle()
                                .fill(.white)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "gearshape.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(Theme.primary)
                                )
                            
                            Text("Settings")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top)
                        
                        // Notifications settings
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Notifications")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    icon: "bell.fill",
                                    title: "Daily Reminders",
                                    subtitle: "Get notified about incomplete quizzes",
                                    isOn: Binding(
                                        get: { notificationsEnabled && notificationStatus == .authorized },
                                        set: { newValue in
                                            if newValue {
                                                if notificationStatus != .authorized {
                                                    showingPermissionAlert = true
                                                } else {
                                                    notificationsEnabled = true
                                                    NotificationManager.shared.scheduleDailyReminders(at: notificationTime)
                                                }
                                            } else {
                                                notificationsEnabled = false
                                                NotificationManager.shared.cancelAllReminders()
                                            }
                                        }
                                    )
                                )
                                
                                if notificationStatus == .denied {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                            Text("Notifications Disabled")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.orange)
                                        }
                                        
                                        Text("Please enable notifications in Settings app")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Button(action: {
                                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                                UIApplication.shared.open(url)
                                            }
                                        }) {
                                            Text("Open Settings")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.25))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                    .padding(.bottom, 10)
                                }
                                
                                Divider()
                                    .background(.white.opacity(0.3))
                                    .padding(.leading, 60)
                                
                                SettingsPickerRow(
                                    icon: "clock.fill",
                                    title: "Notification Time",
                                    subtitle: "Choose when to receive reminders",
                                    selection: Binding(
                                        get: { notificationTime },
                                        set: { newValue in
                                            notificationTime = newValue
                                            if notificationsEnabled && notificationStatus == .authorized {
                                                NotificationManager.shared.scheduleDailyReminders(at: newValue)
                                            }
                                        }
                                    ),
                                    options: Array(6...22),
                                    formatOption: { hour in
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "h:00 a"
                                        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
                                        return formatter.string(from: date)
                                    }
                                )
                                .disabled(!notificationsEnabled || notificationStatus != .authorized)
                                .opacity((notificationsEnabled && notificationStatus == .authorized) ? 1.0 : 0.5)
                            }
                            .cardStyle()
                        }
                        .padding(.horizontal)
                        
                        // Quiz settings
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Quiz Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 0) {
                                SettingsPickerRow(
                                    icon: "gauge.medium",
                                    title: "Difficulty",
                                    subtitle: "Set generated quiz difficulty",
                                    selection: $difficultyLevel,
                                    options: ["Easy", "Medium", "Hard"],
                                    formatOption: { $0 }
                                )
                                
                                // Difficulty explanation
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(.white)
                                        Text("Difficulty Levels")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Group {
                                        Text("Easy: ")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold) +
                                        Text("Straightforward questions, basic concepts")
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Text("Medium: ")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold) +
                                        Text("Moderate complexity, requires understanding")
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Text("Hard: ")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold) +
                                        Text("Complex questions, application & analysis")
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .font(.caption2)
                                }
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            }
                            .cardStyle()
                        }
                        .padding(.horizontal)
                        
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                checkNotificationStatus()
            }
            .alert("Enable Notifications", isPresented: $showingPermissionAlert) {
                Button("Cancel", role: .cancel) {
                    notificationsEnabled = false
                }
                Button("Enable") {
                    NotificationManager.shared.requestAuthorization { granted in
                        DispatchQueue.main.async {
                            if granted {
                                notificationsEnabled = true
                                notificationStatus = .authorized
                                NotificationManager.shared.scheduleDailyReminders(at: notificationTime)
                            } else {
                                notificationsEnabled = false
                                notificationStatus = .denied
                            }
                        }
                    }
                }
            } message: {
                Text("RETHINKA needs permission to send you daily reminders about incomplete quizzes.")
            }
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
                
                // If notifications are enabled but permission denied, disable them
                if notificationsEnabled && settings.authorizationStatus != .authorized {
                    notificationsEnabled = false
                }
            }
        }
    }
    
    // MARK: - Supporting Views
    
    struct SettingsToggleRow: View {
        let icon: String
        let title: String
        let subtitle: String
        @Binding var isOn: Bool
        
        var body: some View {
            HStack(spacing: 15) {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
            .padding()
        }
    }
    
    struct SettingsPickerRow<T: Hashable>: View {
        let icon: String
        let title: String
        let subtitle: String
        @Binding var selection: T
        let options: [T]
        let formatOption: (T) -> String
        
        var body: some View {
            HStack(spacing: 15) {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Picker("", selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(formatOption(option)).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
            .padding()
        }
    }
    
    struct SettingsInfoRow: View {
        let icon: String
        let title: String
        let value: String
        
        var body: some View {
            HStack(spacing: 15) {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(.white)
                    )
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
    }
}

#Preview {
    SettingsView()
}
