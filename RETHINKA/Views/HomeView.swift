//
//  HomeView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import WidgetKit
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
    @State private var isGeneratingDailyQuizzes = false
    @State private var generationProgress: Double = 0
    @State private var generationStatus = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if isGeneratingDailyQuizzes {
                    DailyQuizGenerationOverlay(progress: generationProgress, status: generationStatus)
                } else {
                    VStack(spacing: 30) {
                        VStack(spacing: 10) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image("rethinkalogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
                                )
                            
                            Text("RETHINKA")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)
                        
                        // Active Timelines Summary
                        if !activeTimelines.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Active Timelines")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
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
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("No active timelines")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Create your first exam timeline to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
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
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .padding(.horizontal)
                            }
                            .buttonStyle(Theme.PrimaryButton())

                            HStack(spacing: 16) {
                                // Manage Timelines
                                Button(action: {
                                    showingManageTimelines = true
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "list.bullet")
                                        Text("Manage")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .padding(.horizontal)
                                    .foregroundColor(Theme.primary)
                                    .background(.white)
                                    .cornerRadius(18)
                                }

                                // Settings
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "gearshape.fill")
                                        Text("Settings")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .padding(.horizontal)
                                    .foregroundColor(Theme.primary)
                                    .background(.white)
                                    .cornerRadius(18)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
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
                setupNotifications()
                updateNotificationBadge()
                checkAndGenerateDailyQuizzes()
            }
            .onChange(of: activeTimelines.count) { _, _ in
                updateNotificationBadge()
            }
            
        }
    }
    
    private func checkAndGenerateDailyQuizzes() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for timeline in activeTimelines {
            let todayQuizzes = timeline.dailyQuizzes.filter { quiz in
                calendar.isDate(quiz.date, inSameDayAs: today)
            }
            
            let needsGeneration = todayQuizzes.contains { $0.questions.isEmpty }
            
            if needsGeneration {
                generateDailyQuizzesFor(timeline: timeline, date: today)
                return
            }
        }
    }
    
    private func generateDailyQuizzesFor(timeline: ExamTimeline, date: Date) {
        isGeneratingDailyQuizzes = true
        generationProgress = 0.1
        generationStatus = "Preparing today's quizzes..."
        
        let calendar = Calendar.current
        let todayQuizzes = timeline.dailyQuizzes.filter { quiz in
            calendar.isDate(quiz.date, inSameDayAs: date) && quiz.questions.isEmpty
        }.prefix(3)
        
        guard todayQuizzes.count > 0 else {
            isGeneratingDailyQuizzes = false
            return
        }
        
        generationProgress = 0.3
        generationStatus = "Generating questions..."
        
        let notesArray = timeline.notes.map { $0.content }
        
        let existingTopics = timeline.dailyQuizzes
            .filter { !$0.questions.isEmpty }
            .map { $0.topic }
        
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            DispatchQueue.main.async {
                if self.generationProgress < 0.65 {
                    self.generationProgress += 0.05
                }
            }
        }
        
        AIQuestionGenerator.shared.generateTopicQuizzes(
            examBrief: timeline.examBrief,
            notes: notesArray,
            topicsWanted: 3,
            questionsPerTopic: 10,
            existingTopics: existingTopics
        ) { result in
            DispatchQueue.main.async {
                progressTimer.invalidate()
                self.generationProgress = 0.7
                
                switch result {
                case .failure(let err):
                    print("Daily generation failed: \(err.localizedDescription)")
                    self.useFallbackForDaily(quizzes: Array(todayQuizzes), in: timeline)
                    
                case .success(let topicMap):
                    self.generationStatus = "Finalizing..."
                    self.generationProgress = 0.8
                    
                    var topicKeys = Array(topicMap.keys)
                    if topicKeys.isEmpty {
                        self.useFallbackForDaily(quizzes: Array(todayQuizzes), in: timeline)
                        return
                    }
                    
                    for (index, quiz) in todayQuizzes.enumerated() {
                        let topicIndex = index % topicKeys.count
                        let topic = topicKeys[topicIndex]
                        
                        if let quizIdx = timeline.dailyQuizzes.firstIndex(where: { $0.id == quiz.id }) {
                            timeline.dailyQuizzes[quizIdx].topic = topic
                            timeline.dailyQuizzes[quizIdx].questions.removeAll()
                            
                            if let generatedQuestions = topicMap[topic] {
                                let questionsToUse = Array(generatedQuestions.prefix(10))
                                
                                for genQ in questionsToUse {
                                    let question = QuizQuestion(
                                        question: genQ.question,
                                        options: genQ.options,
                                        correctAnswerIndex: genQ.correctAnswerIndex,
                                        topic: topic,
                                        difficulty: 1,
                                        type: genQ.type
                                    )
                                    timeline.dailyQuizzes[quizIdx].questions.append(question)
                                }
                                
                                while timeline.dailyQuizzes[quizIdx].questions.count < 10 {
                                    let paddingQ = QuizQuestion(
                                        question: "Question about \(topic.lowercased()): Explain a concept.",
                                        options: ["Detailed answer expected", "", "", ""],
                                        correctAnswerIndex: 0,
                                        topic: topic,
                                        type: "textField"
                                    )
                                    timeline.dailyQuizzes[quizIdx].questions.append(paddingQ)
                                }
                            }
                        }
                    }
                    
                    self.finishDailyGeneration(for: timeline)
                }
            }
        }
    }
    
    private func useFallbackForDaily(quizzes: [DailyQuiz], in timeline: ExamTimeline) {
        generationStatus = "Using offline questions..."
        
        let fallbackTopics = ["Review Topics", "Key Concepts", "Practice"]
        
        for (index, quiz) in quizzes.enumerated() {
            let topic = fallbackTopics[index % fallbackTopics.count]
            
            if let quizIdx = timeline.dailyQuizzes.firstIndex(where: { $0.id == quiz.id }) {
                timeline.dailyQuizzes[quizIdx].topic = topic
                timeline.dailyQuizzes[quizIdx].questions.removeAll()
                
                for i in 1...10 {
                    let question = QuizQuestion(
                        question: "Question \(i): Describe a concept from \(topic.lowercased()).",
                        options: ["", "", "", ""],
                        correctAnswerIndex: 0,
                        topic: topic,
                        type: "textField"
                    )
                    timeline.dailyQuizzes[quizIdx].questions.append(question)
                }
            }
        }
        
        finishDailyGeneration(for: timeline)
    }
    
    private func finishDailyGeneration(for timeline: ExamTimeline) {
        generationProgress = 0.95
        generationStatus = "Saving..."
        
        do {
            try modelContext.save()
            
            WidgetCenter.shared.reloadAllTimelines()
            print("Widget refreshed after daily generation")
            
            generationProgress = 1.0
            generationStatus = "Ready!"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isGeneratingDailyQuizzes = false
            }
        } catch {
            print("Error saving daily quizzes: \(error)")
            isGeneratingDailyQuizzes = false
        }
    }
}

extension HomeView {
    private func updateNotificationBadge() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var incompleteCount = 0
        
        for timeline in activeTimelines {
            let todayQuizzes = timeline.dailyQuizzes.filter { quiz in
                calendar.isDate(quiz.date, inSameDayAs: today) && !quiz.isCompleted
            }
            incompleteCount += todayQuizzes.count
        }
        
        NotificationManager.shared.updateBadgeCount(incompleteQuizCount: incompleteCount)
    }
    
    private func setupNotifications() {
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        let notificationTime = UserDefaults.standard.integer(forKey: "notificationTime")
        
        if notificationsEnabled {
            NotificationManager.shared.requestAuthorization { granted in
                if granted {
                    NotificationManager.shared.scheduleDailyReminders(at: notificationTime > 0 ? notificationTime : 9)
                }
            }
        }
        
        updateNotificationBadge()
    }
}

struct DailyQuizGenerationOverlay: View {
    let progress: Double
    let status: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2.5)
                    .frame(width: 120, height: 120)
                
                VStack(spacing: 10) {
                    Text("Generating Today's Quizzes")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(status)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(Color.white.opacity(0.15))
            .cornerRadius(30)
            .shadow(radius: 20)
        }
    }
}

struct ActiveTimelineCard: View {
    let timeline: ExamTimeline
    
    private var daysUntilExam: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExamDate = calendar.startOfDay(for: timeline.examDate)
        
        guard let days = calendar.dateComponents([.day], from: startOfToday, to: startOfExamDate).day else {
            return 0
        }
        
        return max(0, days + 1)
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
                .fill(.white)
                .frame(width: 50, height: 50)
                .overlay(
                    VStack(spacing: 0) {
                        Text("\(daysUntilExam)")
                            .font(.headline)
                            .foregroundColor(Theme.primary)
                        Text("days")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.primary)
                    }
                )
            
            VStack(alignment: .leading, spacing: 5) {
                Text(timeline.examName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Text("\(completedQuizzes)/\(totalQuizzes) quizzes completed")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Exam: \(timeline.examDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white)
        }
        .padding()
        .cardStyle()
    }
}

#Preview {
    HomeView()
}
