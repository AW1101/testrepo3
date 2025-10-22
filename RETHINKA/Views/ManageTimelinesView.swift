//
//  ManageTimelinesView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import SwiftUI
import SwiftData

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
                                .fill(.white)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "list.bullet.clipboard")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(Theme.primary)
                                )
                            
                            Text("Manage Timelines")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top)
                        
                        // Active Timelines Section
                        if !activeTimelines.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Active Timelines (\(activeTimelines.count))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
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
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("No active timelines")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                        }
                        
                        // Completed/Archived Timelines Section
                        if !completedTimelines.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Archived Timelines (\(completedTimelines.count))")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                                
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
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
                        .foregroundColor(.white)
                    
                    Text("Exam: \(timeline.examDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if daysUntilExam >= 0 {
                        Text("\(daysUntilExam) days remaining")
                            .font(.caption)
                            .foregroundColor(daysUntilExam < 7 ? .orange : .white)
                    } else {
                        Text("Exam passed")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Circle()
                    .fill(.white)
                    .frame(width: 50, height: 50)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("\(Int(progress * 100))%")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                        }
                    )
            }
            
            ProgressView(value: progress)
                .tint(.white)
            
            Text("\(completedQuizzes) of \(totalQuizzes) quizzes completed")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 10) {
                Button(action: onArchive) {
                    HStack {
                        Image(systemName: "archivebox")
                        Text("Archive")
                    }
                    .font(.caption)
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(.white)
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
                            .foregroundColor(.white.opacity(0.9))
                        
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("Exam: \(timeline.examDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if let lastQuiz = timeline.dailyQuizzes.last(where: { $0.isCompleted }) {
                        if let score = lastQuiz.score {
                            Text("Final score: \(Int(score * 100))%")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
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
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(.white)
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
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ManageTimelinesView()
}
