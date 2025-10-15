//
//  HomeView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 14/10/2025.
//

import Foundation
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ExamTimeline> { $0.isActive }, sort: \ExamTimeline.examDate)
    private var activeTimelines: [ExamTimeline]
    
    @State private var showingCreateExam = false
    @State private var showingManageTimelines = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App "Logo" (will probably replace later)/Title
                    VStack(spacing: 10) {
                        Circle()
                            .fill(Theme.primary)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "brain.head.profile")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.white)
                            )
                        
                        Text("RETHINKA")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Theme.primary)
                    }
                    .padding(.top, 40)
                    
                    // Active Timelines Summary
                    if !activeTimelines.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Active Timelines")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                            
                            ForEach(activeTimelines.prefix(3)) { timeline in
                                NavigationLink(destination: TimelineView(timeline: timeline)) {
                                    ActiveTimelineCard(timeline: timeline)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 15) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.secondary.opacity(0.5))
                            
                            Text("No active timelines")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Text("Create your first exam timeline to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Main Action Buttons
                    VStack(spacing: 20) {
                        Button(action: {
                            showingCreateExam = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create New Timeline")
                            }
                            .font(.headline)
                        }
                        .buttonStyle(Theme.PrimaryButton())
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                showingManageTimelines = true
                            }) {
                                VStack {
                                    Image(systemName: "list.bullet")
                                        .font(.title2)
                                }
                            }
                            .buttonStyle(Theme.CircularButton(backgroundColor: Theme.secondary))
                            
                            Button(action: {
                                showingSettings = true
                            }) {
                                VStack {
                                    Image(systemName: "gearshape.fill")
                                        .font(.title2)
                                }
                            }
                            .buttonStyle(Theme.CircularButton(backgroundColor: Theme.secondary))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .sheet(isPresented: $showingCreateExam) {
                CreateExamView()
            }
            .sheet(isPresented: $showingManageTimelines) {
                ManageTimelinesView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                NotificationManager.shared.requestAuthorization()
            }
        }
    }
}

struct ActiveTimelineCard: View {
    let timeline: ExamTimeline
    
    private var daysUntilExam: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: timeline.examDate).day ?? 0
    }
    
    private var completedQuizzes: Int {
        timeline.dailyQuizzes.filter { $0.isCompleted }.count
    }
    
    private var totalQuizzes: Int {
        timeline.dailyQuizzes.count
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Theme.secondary)
                .frame(width: 50, height: 50)
                .overlay(
                    Text("\(daysUntilExam)")
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 5) {
                Text(timeline.examName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(completedQuizzes)/\(totalQuizzes) quizzes completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Exam: \(timeline.examDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.primary)
        }
        .padding()
        .cardStyle()
    }
}

// HomeView Preview

#Preview {
    HomeView()
}
