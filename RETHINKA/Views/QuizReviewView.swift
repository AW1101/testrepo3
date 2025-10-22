//
//  QuizReviewView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 12/10/2025.
//

import WidgetKit
import SwiftUI
import SwiftData

struct QuizReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var quiz: DailyQuiz
    
    @State private var showingRetakeConfirmation = false
    
    private var correctCount: Int {
        quiz.questions.filter { $0.isAnsweredCorrectly }.count
    }
    
    private var scorePercentage: Int {
        guard !quiz.questions.isEmpty else { return 0 }
        return Int((Double(correctCount) / Double(quiz.questions.count)) * 100)
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Header Card
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Day \(quiz.dayNumber) Quiz")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.primary)
                                
                                Text(quiz.topic)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.secondary)
                            }
                            
                            Spacer()
                            
                            Circle()
                                .fill(scoreColor)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    VStack(spacing: 2) {
                                        Text("\(scorePercentage)%")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                )
                        }
                        
                        HStack(spacing: 20) {
                            StatPill(icon: "checkmark.circle.fill", value: "\(correctCount)", label: "Correct", color: .green)
                            StatPill(icon: "xmark.circle.fill", value: "\(quiz.questions.count - correctCount)", label: "Incorrect", color: .red)
                            StatPill(icon: "calendar", value: completedDateString, label: "Completed", color: Theme.secondary)
                        }
                    }
                    .padding()
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // Retake Quiz Button
                    Button(action: {
                        showingRetakeConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Retake Quiz")
                        }
                        .font(.headline)
                    }
                    .buttonStyle(Theme.PrimaryButton())
                    .padding(.horizontal)
                    
                    // Questions Review
                    VStack(alignment: .leading, spacing: 15) {
                        Text("All Questions")
                            .font(.headline)
                            .foregroundColor(Theme.primary)
                            .padding(.horizontal)
                        
                        ForEach(Array(quiz.questions.enumerated()), id: \.element.id) { index, question in
                            QuestionReviewCard(question: question, questionNumber: index + 1)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .padding(.top)
            }
        }
        .navigationTitle("Quiz Review")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Retake Quiz?", isPresented: $showingRetakeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Retake", role: .destructive) {
                retakeQuiz()
            }
        } message: {
            Text("This will reset your current score and let you retake the quiz. Are you sure?")
        }
    }
    
    private var scoreColor: Color {
        if scorePercentage >= 80 {
            return .green
        } else if scorePercentage >= 60 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var completedDateString: String {
        guard let date = quiz.completedDate else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func retakeQuiz() {
        // Reset all answers
        for question in quiz.questions {
            question.selectedAnswerIndex = nil
            question.userAnswer = nil
        }
        
        // Reset quiz status
        quiz.isCompleted = false
        quiz.score = nil
        quiz.completedDate = nil
        
        do {
            try modelContext.save()
            
            // force widget refresh
            WidgetCenter.shared.reloadAllTimelines()
            print("Widget refreshed after quiz retake")
            
            dismiss()
        } catch {
            print("Error resetting quiz: \(error)")
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(color.opacity(0.08))
        .cornerRadius(15)
    }
}

struct QuestionReviewCard: View {
    let question: QuizQuestion
    let questionNumber: Int
    
    private var isCorrect: Bool {
        question.isAnsweredCorrectly
    }
    
    private var borderColor: Color {
        isCorrect ? .green : .red
    }
    
    private var headerColor: Color {
        isCorrect ? .green.opacity(0.1) : .red.opacity(0.1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Question Header
            HStack {
                Circle()
                    .fill(borderColor)
                    .frame(width: 35, height: 35)
                    .overlay(
                        Text("\(questionNumber)")
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(question.question)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(question.type == "textField" ? "Written Answer" : "Multiple Choice")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(borderColor)
            }
            .padding()
            .background(headerColor)
            .cornerRadius(15)
            
            // Answer Content
            if question.type == "textField" {
                // Text field answer review
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                            Text("Your Answer:")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Text(question.userAnswer ?? "No answer provided")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.orange)
                            Text("Suggested Answer:")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        
                        Text(question.correctAnswer)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            } else {
                // Multiple choice answer options
                VStack(spacing: 10) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        ReviewAnswerOption(
                            option: option,
                            index: index,
                            isCorrect: index == question.correctAnswerIndex,
                            isSelected: index == question.selectedAnswerIndex
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Explanation if wrong (multiple choice only)
            if !isCorrect && question.type != "textField" {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("Review")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    
                    if let selectedIndex = question.selectedAnswerIndex {
                        Text("You selected: \(question.options[selectedIndex])")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Correct answer: \(question.correctAnswer)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(15)
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor.opacity(0.5), lineWidth: 2)
        )
    }
}

struct ReviewAnswerOption: View {
    let option: String
    let index: Int
    let isCorrect: Bool
    let isSelected: Bool
    
    private var backgroundColor: Color {
        if isCorrect {
            return Color.green.opacity(0.15)
        } else if isSelected {
            return Color.red.opacity(0.15)
        }
        return Theme.cardBackground
    }
    
    private var borderColor: Color {
        if isCorrect {
            return .green
        } else if isSelected {
            return .red
        }
        return Theme.secondary.opacity(0.3)
    }
    
    private var icon: String? {
        if isCorrect {
            return "checkmark.circle.fill"
        } else if isSelected {
            return "xmark.circle.fill"
        }
        return nil
    }
    
    private var iconColor: Color {
        isCorrect ? .green : .red
    }
    
    private var labelColor: Color {
        if isCorrect {
            return .green
        } else if isSelected {
            return .red
        }
        return Theme.secondary
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(labelColor.opacity(isCorrect || isSelected ? 1.0 : 0.3))
                .frame(width: 28, height: 28)
                .overlay(
                    Text("\(["A", "B", "C", "D"][index])")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            Text(option)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isCorrect || isSelected ? 2 : 1)
        )
    }
}

// Preview stuff
struct QuizReviewView_Previews: PreviewProvider {
    static var sampleQuiz: DailyQuiz {
        let dq = DailyQuiz(
            date: Date(),
            examTimelineId: UUID(),
            dayNumber: 1,
            topic: "Sample Quiz"
        )

        // Placeholder questions
        let q1 = QuizQuestion(
            question: "What is 2 + 2?",
            options: ["3", "4", "5", "6"],
            correctAnswerIndex: 1,
            topic: dq.topic,
            type: "multipleChoice"
        )
        q1.selectedAnswerIndex = 1 // correct

        let q2 = QuizQuestion(
            question: "Pick the colour red",
            options: ["Red", "Green", "Blue", "Yellow"],
            correctAnswerIndex: 0,
            topic: dq.topic,
            type: "multipleChoice"
        )
        q2.selectedAnswerIndex = 2 // wrong

        let q3 = QuizQuestion(
            question: "Write a greeting.",
            options: ["Hello", "", "", ""], // placeholder for textField
            correctAnswerIndex: 0,
            topic: dq.topic,
            type: "textField"
        )
        q3.userAnswer = "Hello" // what the user typed

        dq.questions = [q1, q2, q3]
        dq.isCompleted = true
        dq.completedDate = Date()
        dq.score = 80

        return dq
    }

    static var previews: some View {
        NavigationStack {
            QuizReviewView(quiz: sampleQuiz)
        }
    }
}
