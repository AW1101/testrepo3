//
//  QuizQuestion.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import SwiftData

@Model
final class QuizQuestion {
    var id: UUID
    var question: String
    var options: [String]
    var correctAnswerIndex: Int
    var selectedAnswerIndex: Int?
    var topic: String
    var difficulty: Int
    var timesAnsweredIncorrectly: Int
    var type: String // "multipleChoice" or "textField"
    var userAnswer: String? // For textField answers

    init(
        question: String,
        options: [String],
        correctAnswerIndex: Int,
        topic: String = "General",
        difficulty: Int = 1,
        type: String = "multipleChoice"
    ) {
        self.id = UUID()
        self.question = question
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.topic = topic
        self.difficulty = difficulty
        self.timesAnsweredIncorrectly = 0
        self.type = type
    }
    
    var isAnsweredCorrectly: Bool {
        // For textField questions, validate against expected answer
        if type == "textField" {
            guard let userAnswer = userAnswer?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !userAnswer.isEmpty else {
                return false
            }
            
            let correctAnswer = options[correctAnswerIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            // Check for exact match or substantial overlap
            if userAnswer == correctAnswer {
                return true
            }
            
            // Check if user answer contains key words from correct answer
            let correctWords = Set(correctAnswer.split(separator: " ").map { String($0) })
            let userWords = Set(userAnswer.split(separator: " ").map { String($0) })
            
            // If user answer contains at least 40% of key words, consider it correct
            let intersection = correctWords.intersection(userWords)
            let matchPercentage = Double(intersection.count) / Double(correctWords.count)
            
            return matchPercentage >= 0.4
        }
        
        // For multiple choice, check selected answer
        guard let selected = selectedAnswerIndex else { return false }
        return selected == correctAnswerIndex
    }
    
    var isAnswered: Bool {
        if type == "textField" {
            return userAnswer != nil && !userAnswer!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedAnswerIndex != nil
    }
    
    var correctAnswer: String {
        guard correctAnswerIndex >= 0 && correctAnswerIndex < options.count else {
            return "No answer available"
        }
        return options[correctAnswerIndex]
    }
}
