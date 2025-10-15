//
//  QuizResultView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 14/10/2025.
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
                                .stroke(scoreColor.opacity(0.2), lineWidth: 15)
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
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 30)
                        
                        Text("Day \(quiz.dayNumber) Quiz Complete")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.primary)
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
                            color: Theme.secondary
                        )
                    }
                    .padding(.horizontal)
                    
                    // Incorrect Questions Review
                    if incorrectCount > 0 {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Review Incorrect Answers")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                                .padding(.horizontal)
                            
                            ForEach(Array(quiz.questions.enumerated()), id: \.element.id) { index, question in
                                if !question.isAnsweredCorrectly {
                                    IncorrectQuestionCard(question: question, questionNumber: index + 1)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 15) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.yellow)
                            
                            Text("Perfect Score!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.primary)
                            
                            Text("You answered all questions correctly!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
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
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle()
    }
}

struct IncorrectQuestionCard: View {
    let question: QuizQuestion
    let questionNumber: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("\(questionNumber)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    )
                
                Text(question.question)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if let selectedIndex = question.selectedAnswerIndex {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Your answer: \(question.options[selectedIndex])")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Correct answer: \(question.options[question.correctAnswerIndex])")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}
