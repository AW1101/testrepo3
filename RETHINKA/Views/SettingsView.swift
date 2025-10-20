//
//  SettingsView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import SwiftUI

// Still pretty much all placeholder stuff that I made at the start, will need to be revisited/linked with the rest of it later
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notificationTime") private var notificationTime = 9
    @AppStorage("difficultyLevel") private var difficultyLevel = "Medium"
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 10) {
                            Circle()
                                .fill(Theme.primary)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "gearshape.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.white)
                                )
                            
                            Text("Settings")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.primary)
                        }
                        .padding(.top)
                        
                        // Notifications settings
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Notifications")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                            
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    icon: "bell.fill",
                                    title: "Daily Reminders",
                                    subtitle: "Get notified about daily quizzes",
                                    isOn: $notificationsEnabled
                                )
                                
                                Divider()
                                    .padding(.leading, 60)
                                
                                SettingsPickerRow(
                                    icon: "clock.fill",
                                    title: "Notification Time",
                                    subtitle: "Choose when to receive reminders",
                                    selection: $notificationTime,
                                    options: Array(6...22),
                                    formatOption: { "\($0):00" }
                                )
                                .disabled(!notificationsEnabled)
                                .opacity(notificationsEnabled ? 1.0 : 0.5)
                            }
                            .cardStyle()
                        }
                        .padding(.horizontal)
                        
                        // Quiz settings
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Quiz Settings")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                            
                            VStack(spacing: 0) {
                                SettingsPickerRow(
                                    icon: "gauge.medium",
                                    title: "Default Difficulty",
                                    subtitle: "Set quiz difficulty level",
                                    selection: $difficultyLevel,
                                    options: ["Easy", "Medium", "Hard"],
                                    formatOption: { $0 }
                                )
                            }
                            .cardStyle()
                        }
                        .padding(.horizontal)
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    struct SettingsToggleRow: View {
        let icon: String
        let title: String
        let subtitle: String
        @Binding var isOn: Bool
        
        var body: some View {
            HStack(spacing: 15) {
                Circle()
                    .fill(Theme.primary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(Theme.primary)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    .fill(Theme.secondary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(Theme.secondary)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(formatOption(option)).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()
        }
    }
    
    struct SettingsNavigationRow: View {
        let icon: String
        let title: String
        let subtitle: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 15) {
                    Circle()
                        .fill(Theme.primary.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: icon)
                                .foregroundColor(Theme.primary)
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

#Preview {
    SettingsView()
}
