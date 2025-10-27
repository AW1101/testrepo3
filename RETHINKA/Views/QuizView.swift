//
//  QuizView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import WidgetKit
import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var quiz: DailyQuiz
    
    var customTitle: String? = nil

    @State private var currentQuestionIndex = 0
    @State private var showingResults = false
    @State private var selectedAnswer: Int?
    @State private var textFieldAnswer: String = ""
    @State private var hasAnswered = false
    @State private var showingCancelConfirmation = false

    private var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentQuestionIndex]
    }

    private var canSubmit: Bool {
        guard let question = currentQuestion else { return false }

        if question.type == "textField" {
            return !textFieldAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return selectedAnswer != nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if quiz.questions.isEmpty {
                    EmptyQuizView()
                } else if showingResults {
                    // Results view replaces the quiz content in-place
                    QuizResultView(quiz: quiz, onClose: {
                        // close the entire pushed QuizView
                        dismiss()
                    })
                } else {
                    VStack(spacing: 0) {
                        // Progress Header
                        QuizProgressHeader(
                            currentQuestion: currentQuestionIndex + 1,
                            totalQuestions: quiz.questions.count
                        )

                        // Question Content
                        ScrollView {
                            VStack(spacing: 25) {
                                if let question = currentQuestion {
                                    // Question
                                    VStack(alignment: .leading, spacing: 15) {
                                        HStack {
                                            Text("Question \(currentQuestionIndex + 1)")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))

                                            Spacer()

                                            Text(question.type == "textField" ? "Written Answer" : "Multiple Choice")
                                                .font(.caption2)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.white.opacity(0.2))
                                                .cornerRadius(10)
                                                .foregroundColor(.white)
                                        }

                                        Text(question.question)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .cardStyle()

                                    // Options
                                    VStack(spacing: 15) {
                                        if question.type == "textField" {
                                            VStack(alignment: .leading, spacing: 10) {
                                                Text("Your Answer:")
                                                    .font(.subheadline)
                                                    .foregroundColor(.white.opacity(0.8))

                                                TextEditor(text: $textFieldAnswer)
                                                    .frame(minHeight: 120)
                                                    .padding(8)
                                                    .background(.white)
                                                    .cornerRadius(12)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.clear, lineWidth: 0)
                                                    )
                                                    .disabled(hasAnswered)

                                                if hasAnswered {
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        HStack {
                                                            Image(systemName: "lightbulb.fill")
                                                                .foregroundColor(.orange)
                                                            Text("Suggested Answer:")
                                                                .font(.caption)
                                                                .fontWeight(.bold)
                                                                .foregroundColor(.orange)
                                                        }

                                                        Text(question.options[question.correctAnswerIndex])
                                                            .font(.subheadline)
                                                            .foregroundColor(.white.opacity(0.9))
                                                            .padding()
                                                            .background(Color.orange.opacity(0.2))
                                                            .cornerRadius(10)
                                                    }
                                                    .padding(.top, 10)
                                                }
                                            }
                                            .padding(.horizontal)
                                        } else {
                                            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                                                AnswerOption(
                                                    option: option,
                                                    index: index,
                                                    isSelected: selectedAnswer == index,
                                                    isCorrect: hasAnswered ? index == question.correctAnswerIndex : nil,
                                                    onSelect: {
                                                        if !hasAnswered { selectedAnswer = index }
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }

                        // Action Button
                        VStack(spacing: 10) {
                            if hasAnswered {
                                Button(action: nextQuestion) {
                                    HStack {
                                        Text(currentQuestionIndex < quiz.questions.count - 1 ? "Next Question" : "Finish Quiz")
                                        Image(systemName: "arrow.right.circle.fill")
                                    }
                                    .font(.headline)
                                }
                                .buttonStyle(Theme.PrimaryButton())
                            } else {
                                Button(action: submitAnswer) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Submit Answer")
                                    }
                                    .font(.headline)
                                }
                                .buttonStyle(Theme.PrimaryButton(isDisabled: !canSubmit))
                                .disabled(!canSubmit)
                            }
                        }
                        .padding()
                        .background(Theme.background)
                    }
                }
            }
            .navigationTitle(customTitle ?? "Day \(quiz.dayNumber) Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)

            // Show the Cancel button only while the user is answering (not on results screen)
            .toolbar {
                if !showingResults {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showingCancelConfirmation = true
                        }) {
                            Text("Cancel")
                                .foregroundColor(.white)
                        }
                    }
                }
            }

            .alert("Cancel Quiz?", isPresented: $showingCancelConfirmation) {
                Button("Continue Quiz", role: .cancel) { }
                Button("Yes, Cancel", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("Your progress will not be saved. Are you sure you want to cancel?")
            }
        }
    }

    private func submitAnswer() {
        guard let question = currentQuestion else { return }

        if question.type == "textField" {
            quiz.questions[currentQuestionIndex].userAnswer = textFieldAnswer
            quiz.questions[currentQuestionIndex].selectedAnswerIndex = question.correctAnswerIndex
        } else {
            guard let selectedAnswer = selectedAnswer else { return }
            quiz.questions[currentQuestionIndex].selectedAnswerIndex = selectedAnswer

            if !quiz.questions[currentQuestionIndex].isAnsweredCorrectly {
                quiz.questions[currentQuestionIndex].timesAnsweredIncorrectly += 1
            }
        }

        hasAnswered = true
    }

    private func nextQuestion() {
        if currentQuestionIndex < quiz.questions.count - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
            textFieldAnswer = ""
            hasAnswered = false
        } else {
            completeQuiz()
        }
    }

    private func completeQuiz() {
        let correctAnswers = quiz.questions.filter { $0.isAnsweredCorrectly }.count
        let score = Double(correctAnswers) / Double(quiz.questions.count)

        quiz.isCompleted = true
        quiz.score = score
        quiz.completedDate = Date()

        do {
            try modelContext.save()

            WidgetCenter.shared.reloadAllTimelines()
            print("Widget refreshed after quiz completion")

            // show results (this will remove the Cancel button because of the toolbar conditional)
            showingResults = true
        } catch {
            print("Error saving quiz: \(error)")
        }
    }
}


struct EmptyQuizView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("No Questions Available")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("This quiz has no questions. Please contact support.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct QuizProgressHeader: View {
    let currentQuestion: Int
    let totalQuestions: Int
    
    private var progress: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(currentQuestion) / Double(totalQuestions)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Question \(currentQuestion) of \(totalQuestions)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            ProgressView(value: progress)
                .tint(.white)
        }
        .padding()
        .background(Color.white.opacity(0.15))
    }
}

struct AnswerOption: View {
    let option: String
    let index: Int
    let isSelected: Bool
    let isCorrect: Bool?
    let onSelect: () -> Void
    
    private var backgroundColor: Color {
        if let isCorrect = isCorrect {
            if isCorrect {
                return Color.green.opacity(0.3)
            } else if isSelected {
                return Color.red.opacity(0.3)
            }
        } else if isSelected {
            return Color.white.opacity(0.2)
        }
        return Color.white.opacity(0.1)
    }
    
    private var borderColor: Color {
        if let isCorrect = isCorrect {
            if isCorrect {
                return .green
            } else if isSelected {
                return .red
            }
        } else if isSelected {
            return .white
        }
        return Color.white.opacity(0.3)
    }
    
    private var icon: String? {
        if let isCorrect = isCorrect {
            return isCorrect ? "checkmark.circle.fill" : (isSelected ? "xmark.circle.fill" : nil)
        }
        return nil
    }
    
    private var iconColor: Color {
        if let isCorrect = isCorrect {
            return isCorrect ? .green : .red
        }
        return .white
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Circle()
                    .fill(isSelected ? .white : Color.white.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("\(["A", "B", "C", "D"][index])")
                            .font(.headline)
                            .foregroundColor(isSelected ? Theme.primary : .white.opacity(0.8))
                    )
                
                Text(option)
                    .font(.body)
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
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .disabled(isCorrect != nil)
    }
}

struct QuizView_Previews: PreviewProvider {
    static var sampleQuiz: DailyQuiz {
        let dq = DailyQuiz(
            date: Date(),
            examTimelineId: UUID(),
            dayNumber: 1,
            topic: "Sample Quiz"
        )
        
        let q1 = QuizQuestion(
            question: "What is 2 + 2?",
            options: ["3", "4", "5", "6"],
            correctAnswerIndex: 1,
            topic: dq.topic,
            type: "multipleChoice"
        )
        
        let q2 = QuizQuestion(
            question: "Pick the colour red",
            options: ["Red", "Blue", "Green", "Yellow"],
            correctAnswerIndex: 0,
            topic: dq.topic,
            type: "multipleChoice"
        )
        
        let q3 = QuizQuestion(
            question: "Say hello.",
            options: ["Hello", "", "", ""],
            correctAnswerIndex: 0,
            topic: dq.topic,
            type: "textField"
        )
        q3.userAnswer = "Hello"
        
        dq.questions = [q1, q2, q3]
        return dq
    }
    
    static var previews: some View {
        NavigationStack {
            QuizView(quiz: sampleQuiz)
                .environment(\.colorScheme, .light)
        }
    }
}
