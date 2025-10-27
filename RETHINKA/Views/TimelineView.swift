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

    // New state for programmatic navigation (push)
    @State private var pushQuiz = false
    @State private var pushReview = false

    private var sortedQuizzes: [DailyQuiz] {
        timeline.dailyQuizzes.sorted {
            if $0.date == $1.date {
                return $0.topic < $1.topic
            }
            return $0.date < $1.date
        }
    }

    private var mistakesCount: Int {
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

    // Updated computed property for days until exam
    private var daysUntilExam: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExamDate = calendar.startOfDay(for: timeline.examDate)

        guard let days = calendar.dateComponents([.day], from: startOfToday, to: startOfExamDate).day else {
            return 0
        }

        return max(0, days + 1)
    }

    var body: some View {
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
                                Image(systemName: "calendar")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(Theme.primary)
                            )

                        Text(timeline.examName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Exam: \(timeline.examDate, style: .date)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        Text("\(daysUntilExam) \(daysUntilExam == 1 ? "day" : "days") until exam")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))

                        // Progress Bar
                        ProgressView(value: progressValue)
                            .tint(.white)
                            .padding(.horizontal, 40)

                        Text("\(completedCount)/\(totalCount) quizzes completed")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top)

                    // Review mistakes button
                    if mistakesCount > 0 {
                        NavigationLink(destination: TimelineMistakesView(title: timeline.examName, dailyQuizzes: sortedQuizzes)) {
                            HStack(spacing: 10) {
                                Text("Review all mistakes")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(.white.opacity(0.2))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal, 40)
                    }

                    // Today's Quizzes Highlight
                    if !todayQuizzes.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Today's Quizzes")
                                .font(.headline)
                                .foregroundColor(.white)

                            ForEach(todayQuizzes) { quiz in
                                TodayQuizCard(quiz: quiz, onStart: {
                                    if quiz.isCompleted {
                                        // push review
                                        reviewQuiz = quiz
                                        pushReview = true
                                    } else {
                                        // push quiz
                                        selectedQuiz = quiz
                                        pushQuiz = true
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
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        ForEach(quizzesByDay, id: \.0) { date, quizzes in
                            VStack(alignment: .leading, spacing: 10) {
                                // Day Header
                                HStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Text("\(quizzes.first?.dayNumber ?? 0)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(Theme.primary)
                                        )

                                    Text(date, style: .date)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)

                                    Spacer()

                                    let completedCount = quizzes.filter { $0.isCompleted }.count
                                    Text("\(completedCount)/\(quizzes.count) completed")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
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
                                                pushReview = true
                                            } else if isQuizAvailable(quiz) {
                                                selectedQuiz = quiz
                                                pushQuiz = true
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

            // Hidden NavigationLinks to perform programmatic push navigation
            // Quiz push
            NavigationLink(
                destination: Group {
                    if let quiz = selectedQuiz {
                        QuizView(quiz: quiz)
                    } else {
                        EmptyView()
                    }
                },
                isActive: $pushQuiz
            ) {
                EmptyView()
            }
            .hidden()

            // Review push
            NavigationLink(
                destination: Group {
                    if let review = reviewQuiz {
                        // Use a NavigationStack inside the pushed view if needed by the review view
                        QuizReviewView(quiz: review)
                    } else {
                        EmptyView()
                    }
                },
                isActive: $pushReview
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // clear selected quiz when user navigates back
        .onChange(of: pushQuiz) { newValue in
            if !newValue {
                selectedQuiz = nil
            }
        }
        .onChange(of: pushReview) { newValue in
            if !newValue {
                reviewQuiz = nil
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

    // UPDATED: New logic - quiz is available if it has questions (has been generated)
    private func isQuizAvailable(_ quiz: DailyQuiz) -> Bool {
        // Quiz is available if it has questions (has been generated)
        // No more sequential locking - users can do any quiz that's ready
        return !quiz.questions.isEmpty
    }

    // UPDATED: Helper to check if quiz is pending generation
    private func isQuizPending(_ quiz: DailyQuiz) -> Bool {
        return quiz.questions.isEmpty
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
                        .foregroundColor(.white)
                }

                Text(quiz.topic)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)

                Text(quiz.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                if quiz.isCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        if let score = quiz.score {
                            Text("\(Int(score * 100))% Score")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                } else {
                    Text("Ready to start")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }

            Spacer()

            Button(action: onStart) {
                Text(quiz.isCompleted ? "Review" : "Start")
                    .font(.headline)
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 10)
                    .background(.white)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.15)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
    }
}

struct QuizTimelineCard: View {
    let quiz: DailyQuiz
    let isAvailable: Bool
    let onTap: () -> Void

    // Check if quiz has been generated
    private var isGenerated: Bool {
        !quiz.questions.isEmpty
    }

    private var statusColor: Color {
        if quiz.isCompleted {
            return .green
        } else if isAvailable {
            return .white
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
            return "hourglass.circle"
        }
    }

    private var statusText: String {
        if quiz.isCompleted {
            return "Tap to review answers"
        } else if isAvailable {
            return "Ready to start"
        } else {
            return "Questions generating soon"
        }
    }

    private var lockText: String {
        if !isGenerated {
            return "Not yet generated"
        }
        return ""
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
                            .foregroundColor(quiz.isCompleted ? .white : Theme.primary)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(quiz.topic)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text("Day \(quiz.dayNumber)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))

                        if quiz.isCompleted {
                            Text("•")
                                .foregroundColor(.white.opacity(0.8))
                            if let score = quiz.score {
                                Text("Score: \(Int(score * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else if !isAvailable {
                            Text("•")
                                .foregroundColor(.white.opacity(0.8))
                            Text("Pending")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(isAvailable || quiz.isCompleted ? .white : .white.opacity(0.7))

                    if !isGenerated && !quiz.isCompleted {
                        Text(lockText)
                            .font(.caption2)
                            .foregroundColor(.orange)
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
            examDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        )

        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        // Yesterday's quizzes (generated)
        let q1 = DailyQuiz(date: yesterday, examTimelineId: timeline.id, dayNumber: 1, topic: "Yesterday Quiz 1")
        q1.isCompleted = true
        q1.score = 0.8
        q1.questions = [QuizQuestion(question: "Test", options: ["A", "B", "C", "D"], correctAnswerIndex: 0)]

        let q2 = DailyQuiz(date: yesterday, examTimelineId: timeline.id, dayNumber: 1, topic: "Yesterday Quiz 2")
        q2.isCompleted = false
        q2.questions = [QuizQuestion(question: "Test", options: ["A", "B", "C", "D"], correctAnswerIndex: 0)]

        // Today's quizzes (generated)
        let q3 = DailyQuiz(date: today, examTimelineId: timeline.id, dayNumber: 2, topic: "Today Quiz 1")
        q3.isCompleted = false
        q3.questions = [QuizQuestion(question: "Test", options: ["A", "B", "C", "D"], correctAnswerIndex: 0)]

        let q4 = DailyQuiz(date: today, examTimelineId: timeline.id, dayNumber: 2, topic: "Today Quiz 2")
        q4.isCompleted = true
        q4.score = 0.9
        q4.questions = [QuizQuestion(question: "Test", options: ["A", "B", "C", "D"], correctAnswerIndex: 0)]

        // Tomorrow's quiz (not generated yet - empty questions)
        let q5 = DailyQuiz(date: tomorrow, examTimelineId: timeline.id, dayNumber: 3, topic: "Tomorrow Quiz")
        q5.isCompleted = false
        // No questions added - simulating pending generation

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
