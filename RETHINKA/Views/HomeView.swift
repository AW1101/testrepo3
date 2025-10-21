//
//  HomeView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

// I need to go over the topic generation for the next-day questions creation again, need to test it further to see if it is actually going out of its way to make it different from the last (questions themselves seem to be fine/new though)
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
                                .fill(Theme.primary)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image("rethinkalogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
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
                                    .foregroundColor(.white)
                                    .background(Theme.secondary)
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
                                    .foregroundColor(.white)
                                    .background(Theme.secondary)
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
                checkAndGenerateDailyQuizzes()
            }
        }
    }
    
    private func checkAndGenerateDailyQuizzes() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for timeline in activeTimelines {
            // Get today's quizzes
            let todayQuizzes = timeline.dailyQuizzes.filter { quiz in
                calendar.isDate(quiz.date, inSameDayAs: today)
            }
            
            // Check if any of today's quizzes are empty (not generated yet)
            let needsGeneration = todayQuizzes.contains { $0.questions.isEmpty }
            
            if needsGeneration {
                generateDailyQuizzesFor(timeline: timeline, date: today)
                return // Generate one timeline at a time
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
        
        // Get all previously used topics to avoid repetition
        let existingTopics = timeline.dailyQuizzes
            .filter { !$0.questions.isEmpty }
            .map { $0.topic }
        
        // Simulate progress during API call
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
            existingTopics: existingTopics // Pass existing topics
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
                                // Take exactly 10 questions
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
                                
                                // Pad to 10 if needed
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

struct DailyQuizGenerationOverlay: View {
    let progress: Double
    let status: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .stroke(Theme.primary.opacity(0.2), lineWidth: 10)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Theme.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.primary)
                }
                
                VStack(spacing: 10) {
                    Text("Generating Today's Quizzes")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(status)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .foregroundColor(Theme.primary)
                }
            }
            .padding(40)
            .background(Theme.cardBackground)
            .cornerRadius(30)
            .shadow(radius: 20)
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
                    .multilineTextAlignment(.leading)
                
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

#Preview {
    HomeView()
}
