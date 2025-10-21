//
//  ManageTimelinesView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import SwiftUI
import SwiftData

// basically works but there's a few minor things needed to be addressed at some point (archiving interacting with next-day stuff, percentages appearing incorrectly etc.)
struct ManageTimelinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTimelines: [ExamTimeline]
    
    @State private var showingDeleteConfirmation = false
    @State private var timelineToDelete: ExamTimeline?
    
    private var activeTimelines: [ExamTimeline] {
        allTimelines.filter { $0.isActive }.sorted { $0.examDate < $1.examDate }
    }
    
    private var completedTimelines: [ExamTimeline] {
        allTimelines.filter { !$0.isActive }.sorted { $0.examDate > $1.examDate }
    }
    
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
                                    Image(systemName: "list.bullet.clipboard")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.white)
                                )
                            
                            Text("Manage Timelines")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.primary)
                        }
                        .padding(.top)
                        
                        // Active Timelines Section
                        if !activeTimelines.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Active Timelines (\(activeTimelines.count))")
                                    .font(.headline)
                                    .foregroundColor(Theme.primary)
                                
                                ForEach(activeTimelines) { timeline in
                                    TimelineManagementCard(
                                        timeline: timeline,
                                        onDelete: {
                                            timelineToDelete = timeline
                                            showingDeleteConfirmation = true
                                        },
                                        onArchive: {
                                            archiveTimeline(timeline)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 15) {
                                Image(systemName: "tray")
                                    .font(.system(size: 50))
                                    .foregroundColor(Theme.secondary.opacity(0.5))
                                
                                Text("No active timelines")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        
                        // Completed/Archived Timelines Section
                        if !completedTimelines.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Archived Timelines (\(completedTimelines.count))")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                ForEach(completedTimelines) { timeline in
                                    ArchivedTimelineCard(
                                        timeline: timeline,
                                        onDelete: {
                                            timelineToDelete = timeline
                                            showingDeleteConfirmation = true
                                        },
                                        onRestore: {
                                            restoreTimeline(timeline)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Timeline", isPresented: $showingDeleteConfirmation, presenting: timelineToDelete) { timeline in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteTimeline(timeline)
                }
            } message: { timeline in
                Text("Are you sure you want to delete '\(timeline.examName)'? This action cannot be undone.")
            }
        }
    }
    
    private func deleteTimeline(_ timeline: ExamTimeline) {
        NotificationManager.shared.cancelNotifications(for: timeline.id)
        modelContext.delete(timeline)
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting timeline: \(error)")
        }
    }
    
    private func archiveTimeline(_ timeline: ExamTimeline) {
        timeline.isActive = false
        NotificationManager.shared.cancelNotifications(for: timeline.id)
        
        do {
            try modelContext.save()
        } catch {
            print("Error archiving timeline: \(error)")
        }
    }
    
    private func restoreTimeline(_ timeline: ExamTimeline) {
        timeline.isActive = true
        NotificationManager.shared.scheduleDailyQuizNotification(for: timeline)
        
        do {
            try modelContext.save()
        } catch {
            print("Error restoring timeline: \(error)")
        }
    }
}

struct TimelineManagementCard: View {
    let timeline: ExamTimeline
    let onDelete: () -> Void
    let onArchive: () -> Void
    
    private var completedQuizzes: Int {
        timeline.dailyQuizzes.filter { $0.isCompleted }.count
    }
    
    private var totalQuizzes: Int {
        timeline.dailyQuizzes.count
    }
    
    private var progress: Double {
        guard totalQuizzes > 0 else { return 0 }
        return Double(completedQuizzes) / Double(totalQuizzes)
    }
    
    private var daysUntilExam: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: timeline.examDate).day ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(timeline.examName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Exam: \(timeline.examDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if daysUntilExam >= 0 {
                        Text("\(daysUntilExam) days remaining")
                            .font(.caption)
                            .foregroundColor(daysUntilExam < 7 ? .orange : Theme.secondary)
                    } else {
                        Text("Exam passed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 50, height: 50)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("\(Int(progress * 100))%")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    )
            }
            
            ProgressView(value: progress)
                .tint(Theme.secondary)
            
            Text("\(completedQuizzes) of \(totalQuizzes) quizzes completed")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                Button(action: onArchive) {
                    HStack {
                        Image(systemName: "archivebox")
                        Text("Archive")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(Theme.secondary)
                    .cornerRadius(15)
                }
                
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(15)
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

struct ArchivedTimelineCard: View {
    let timeline: ExamTimeline
    let onDelete: () -> Void
    let onRestore: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(timeline.examName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Exam: \(timeline.examDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastQuiz = timeline.dailyQuizzes.last(where: { $0.isCompleted }) {
                        if let score = lastQuiz.score {
                            Text("Final score: \(Int(score * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 10) {
                Button(action: onRestore) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Restore")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(Theme.primary)
                    .cornerRadius(15)
                }
                
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(15)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground.opacity(0.5))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ManageTimelinesView()
}
