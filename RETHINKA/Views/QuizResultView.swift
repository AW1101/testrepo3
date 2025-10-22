//
//  QuizResultView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import SwiftUI

struct QuizResultView: View {
    let quiz: DailyQuiz
    let onClose: () -> Void

    private var correctCount: Int {
        quiz.questions.filter { $0.isAnsweredCorrectly }.count
    }

    private var incorrectCount: Int {
        quiz.questions.count - correctCount
    }

    private var scorePercentage: Int {
        guard !quiz.questions.isEmpty else { return 0 }
        return Int((Double(correctCount) / Double(quiz.questions.count)) * 100)
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

    private var scoreMessage: String {
        if scorePercentage >= 80 {
            return "Excellent Work!"
        } else if scorePercentage >= 60 {
            return "Good Effort!"
        } else {
            return "Keep Practicing!"
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    // Score Circle
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(scoreColor.opacity(0.3), lineWidth: 15)
                                .frame(width: 200, height: 200)

                            Circle()
                                .trim(from: 0, to: CGFloat(scorePercentage) / 100)
                                .stroke(scoreColor, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 1.0), value: scorePercentage)

                            VStack(spacing: 5) {
                                Text("\(scorePercentage)%")
                                    .font(.system(size: 50, weight: .bold))
                                    .foregroundColor(scoreColor)

                                Text(scoreMessage)
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .padding(.top, 30)

                        Text("Day \(quiz.dayNumber) Quiz Complete")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(quiz.topic)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    // Stats Cards
                    HStack(spacing: 15) {
                        StatCard(
                            icon: "checkmark.circle.fill",
                            value: "\(correctCount)",
                            label: "Correct",
                            color: .green
                        )

                        StatCard(
                            icon: "xmark.circle.fill",
                            value: "\(incorrectCount)",
                            label: "Incorrect",
                            color: .red
                        )

                        StatCard(
                            icon: "list.bullet",
                            value: "\(quiz.questions.count)",
                            label: "Total",
                            color: .white
                        )
                    }
                    .padding(.horizontal)

                    // Show questions
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Review Answers")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        // Iterate by index to ensure every question is shown and numbered 1..N
                        ForEach(Array(quiz.questions.enumerated()), id: \.element.id) { index, question in
                            ResultQuestionCard(question: question, questionNumber: index + 1)
                                .padding(.horizontal)
                        }
                    }

                    // Close Button
                    Button(action: onClose) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Continue")
                        }
                        .font(.headline)
                    }
                    .buttonStyle(Theme.PrimaryButton())
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// StatCard
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.2))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// ResultQuestionCard
struct ResultQuestionCard: View {
    let question: QuizQuestion
    let questionNumber: Int

    private var isCorrect: Bool {
        question.isAnsweredCorrectly
    }

    private var borderColor: Color {
        isCorrect ? .green : .red
    }

    private var headerColor: Color {
        isCorrect ? Color.green.opacity(0.2) : Color.red.opacity(0.2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Circle()
                    .fill(borderColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("\(questionNumber)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(question.question)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(question.type == "textField" ? "Written Answer" : "Multiple Choice")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(borderColor)
            }
            .padding(10)
            .background(headerColor)
            .cornerRadius(12)

            // Body (textField or multiple choice)
            if question.type == "textField" {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                        Text("Your answer:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    Text(question.userAnswer ?? "No answer provided")
                        .font(.subheadline)
                        .foregroundColor(Theme.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white)
                        .cornerRadius(10)

                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("Suggested answer:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }

                    Text(question.correctAnswer)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(10)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        ReviewAnswerOption(
                            option: option,
                            index: index,
                            isCorrect: index == question.correctAnswerIndex,
                            isSelected: index == question.selectedAnswerIndex
                        )
                        .padding(.vertical, 0)
                    }
                }
            }

            // If wrong and multiple choice, a short review box
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
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Text("Correct answer: \(question.correctAnswer)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor.opacity(0.4), lineWidth: 1.5)
        )
    }
}


// Preview stuff
struct QuizResultView_Previews: PreviewProvider {
    static var sampleQuiz: DailyQuiz {
        let dq = DailyQuiz(
            date: Date(),
            examTimelineId: UUID(),
            dayNumber: 1,
            topic: "Sample Quiz"
        )

        // Simple placeholder questions
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
            options: ["Hello", "", "", ""], // placeholder options for textField
            correctAnswerIndex: 0,
            topic: dq.topic,
            type: "textField"
        )
        q3.userAnswer = "Hello" // what the user typed

        dq.questions = [q1, q2, q3]
        dq.isCompleted = true

        return dq
    }

    static var previews: some View {
        QuizResultView(quiz: sampleQuiz, onClose: { })
    }
}
