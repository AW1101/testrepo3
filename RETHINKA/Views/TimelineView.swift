//
//  TimelineView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
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
    
    private var mistakesCount: Int {
        // Count completed quizzes that likely had mistakes (score < 100%)
        timeline.dailyQuizzes.filter { $0.isCompleted && (($0.score ?? 0) < 1.0) }.count
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
    
    
    
    enum ActiveSheet: Identifiable {
        case quiz(DailyQuiz)
        case review(DailyQuiz)
        
        var id: UUID {
            switch self {
            case .quiz(let quiz), .review(let quiz):
                return quiz.id
            }
        }
    }

    @State private var activeSheet: ActiveSheet?
    
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
                    
                    //review mistakes button
                    if mistakesCount > 0 {
                        NavigationLink(destination: TimelineMistakesView(title: timeline.examName, dailyQuizzes: sortedQuizzes)) {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.leading, 6)

                                Text("Review all mistakes")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                Spacer(minLength: 8)

                                // number of mistakes
                                Text("\(mistakesCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Theme.primary)
                            .cornerRadius(12)
                            .shadow(color: Theme.primary.opacity(0.15), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal, 40)
                    }

                    // Today's Quizzes Highlight
                    if !todayQuizzes.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Today's Quizzes")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                            
                            ForEach(todayQuizzes) { quiz in
                                // Start or Review Quiz
                                TodayQuizCard(quiz: quiz, onStart: {
                                    if quiz.isCompleted {
                                        activeSheet = .review(quiz)
                                    } else {
                                        activeSheet = .quiz(quiz)
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
                                                activeSheet = .review(quiz)
                                            } else if isQuizAvailable(quiz) {
                                                activeSheet = .quiz(quiz)
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .quiz(let quiz):
                QuizView(quiz: quiz)
            case .review(let quiz):
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
                        .multilineTextAlignment(.leading)
                    
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

struct TimelineView_Previews: PreviewProvider {
    static var sampleTimeline: ExamTimeline {
        let timeline = ExamTimeline(
            examName: "Sample Exam",
            examBrief: "A short description of the sample exam.",
            examDate: Date()
        )
        
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Placeholder quizzes
        let q1 = DailyQuiz(date: yesterday, examTimelineId: timeline.id, dayNumber: 1, topic: "Yesterday quiz 1")
        q1.isCompleted = true
        q1.score = 0.8
        
        let q2 = DailyQuiz(date: yesterday, examTimelineId: timeline.id, dayNumber: 1, topic: "Yesterday Quiz 2")
        q2.isCompleted = false
        
        let q3 = DailyQuiz(date: today, examTimelineId: timeline.id, dayNumber: 2, topic: "Today Quiz 1")
        q3.isCompleted = false
        
        let q4 = DailyQuiz(date: today, examTimelineId: timeline.id, dayNumber: 2, topic: "Today Quiz 2")
        q4.isCompleted = true
        q4.score = 0.9
        
        let q5 = DailyQuiz(date: tomorrow, examTimelineId: timeline.id, dayNumber: 3, topic: "Tomorrow Quiz")
        q5.isCompleted = false
        
        timeline.dailyQuizzes = [q1, q2, q3, q4, q5]
        return timeline
    }
    
    static var previews: some View {
        NavigationStack {
            TimelineView(timeline: sampleTimeline)
                .environment(\.colorScheme, .light)
        }
    }
}

