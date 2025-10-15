//
//  TimelineView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 14/10/2025.
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var timeline: ExamTimeline
    
    @State private var selectedQuiz: DailyQuiz?
    @State private var showingReview = false
    @State private var reviewQuiz: DailyQuiz?
    
    private var sortedQuizzes: [DailyQuiz] {
        timeline.dailyQuizzes.sorted {
            if $0.date == $1.date {
                return $0.topic < $1.topic
            }
            return $0.date < $1.date
        }
    }
    
    // Group quizzes by day
    private var quizzesByDay: [(Date, [DailyQuiz])] {
        let grouped = Dictionary(grouping: sortedQuizzes) { quiz in
            Calendar.current.startOfDay(for: quiz.date)
        }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value.sorted { $0.topic < $1.topic }) }
    }
    
    private var todayQuizzes: [DailyQuiz] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sortedQuizzes.filter { calendar.isDate($0.date, inSameDayAs: today) }
    }
    
    var body: some View {
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
                                Image(systemName: "calendar")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                            )
                        
                        Text(timeline.examName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.primary)
                        
                        Text("Exam: \(timeline.examDate, style: .date)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Progress Bar
                        ProgressView(value: progressValue)
                            .tint(Theme.secondary)
                            .padding(.horizontal, 40)
                        
                        Text("\(completedCount)/\(totalCount) quizzes completed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Today's Quizzes Highlight
                    if !todayQuizzes.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Today's Quizzes")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                            
                            ForEach(todayQuizzes) { quiz in
                                TodayQuizCard(quiz: quiz, onStart: {
                                    if quiz.isCompleted {
                                        reviewQuiz = quiz
                                        showingReview = true
                                    } else {
                                        selectedQuiz = quiz
                                    }
                                })
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // All Quizzes Timeline (Grouped by Day)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Quiz Timeline")
                            .font(.headline)
                            .foregroundColor(Theme.primary)
                            .padding(.horizontal)
                        
                        ForEach(quizzesByDay, id: \.0) { date, quizzes in
                            VStack(alignment: .leading, spacing: 10) {
                                // Day Header
                                HStack {
                                    Circle()
                                        .fill(Theme.secondary)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Text("\(quizzes.first?.dayNumber ?? 0)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text(date, style: .date)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    let completedCount = quizzes.filter { $0.isCompleted }.count
                                    Text("\(completedCount)/\(quizzes.count) completed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                
                                // Quizzes for this day
                                ForEach(quizzes) { quiz in
                                    QuizTimelineCard(
                                        quiz: quiz,
                                        isAvailable: isQuizAvailable(quiz),
                                        onTap: {
                                            if quiz.isCompleted {
                                                reviewQuiz = quiz
                                                showingReview = true
                                            } else if isQuizAvailable(quiz) {
                                                selectedQuiz = quiz
                                            }
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedQuiz) { quiz in
            QuizView(quiz: quiz)
        }
        .sheet(isPresented: $showingReview) {
            if let quiz = reviewQuiz {
                NavigationStack {
                    QuizReviewView(quiz: quiz)
                }
            }
        }
    }
    
    private var progressValue: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    private var completedCount: Int {
        timeline.dailyQuizzes.filter { $0.isCompleted }.count
    }
    
    private var totalCount: Int {
        timeline.dailyQuizzes.count
    }
    
    private func isQuizAvailable(_ quiz: DailyQuiz) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let quizDate = calendar.startOfDay(for: quiz.date)
        
        // Quiz is available if it's today or in the past
        if quizDate <= today {
            // Check if previous quizzes on same day are completed
            let sameDay = sortedQuizzes.filter { calendar.isDate($0.date, inSameDayAs: quiz.date) }
            if let quizIndex = sameDay.firstIndex(where: { $0.id == quiz.id }) {
                // If first quiz of the day, check previous day's last quiz
                if quizIndex == 0 {
                    // Find previous day's quizzes
                    if let previousDayQuizzes = quizzesByDay.first(where: { $0.0 < quizDate })?.1 {
                        // Check if last quiz of previous day is completed
                        if let lastPreviousQuiz = previousDayQuizzes.last {
                            return lastPreviousQuiz.isCompleted
                        }
                    }
                    // If no previous day, it's the first quiz overall
                    return true
                } else {
                    // Check if previous quiz in same day is completed
                    let previousQuiz = sameDay[quizIndex - 1]
                    return previousQuiz.isCompleted
                }
            }
        }
        
        return false
    }
}

struct TodayQuizCard: View {
    let quiz: DailyQuiz
    let onStart: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Day \(quiz.dayNumber)")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(quiz.topic)
                    .font(.subheadline)
                    .foregroundColor(Theme.secondary)
                    .fontWeight(.semibold)
                
                Text(quiz.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if quiz.isCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        if let score = quiz.score {
                            Text("\(Int(score * 100))% Score")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("• Tap to review")
                            .font(.caption2)
                            .foregroundColor(Theme.primary)
                    }
                } else {
                    Text("Ready to start")
                        .font(.caption)
                        .foregroundColor(Theme.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onStart) {
                Text(quiz.isCompleted ? "Review" : "Start")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 10)
                    .background(quiz.isCompleted ? Theme.secondary : Theme.primary)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Theme.primary.opacity(0.1), Theme.secondary.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.primary.opacity(0.3), lineWidth: 2)
        )
    }
}

struct QuizTimelineCard: View {
    let quiz: DailyQuiz
    let isAvailable: Bool
    let onTap: () -> Void
    
    private var statusColor: Color {
        if quiz.isCompleted {
            return .green
        } else if isAvailable {
            return Theme.primary
        } else {
            return .gray
        }
    }
    
    private var statusIcon: String {
        if quiz.isCompleted {
            return "checkmark.circle.fill"
        } else if isAvailable {
            return "play.circle.fill"
        } else {
            return "lock.circle.fill"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 45, height: 45)
                    .overlay(
                        Image(systemName: statusIcon)
                            .font(.title3)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(quiz.topic)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Day \(quiz.dayNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if quiz.isCompleted {
                            Text("•")
                                .foregroundColor(.secondary)
                            if let score = quiz.score {
                                Text("Score: \(Int(score * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else if !isAvailable {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Locked")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if quiz.isCompleted {
                        Text("Tap to review answers")
                            .font(.caption2)
                            .foregroundColor(Theme.primary)
                    } else if !isAvailable {
                        Text("Complete previous quiz first")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            .padding()
            .cardStyle()
            .opacity(isAvailable || quiz.isCompleted ? 1.0 : 0.6)
        }
        .disabled(!isAvailable && !quiz.isCompleted)
    }
}
