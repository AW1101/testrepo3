//
//  QuizQuestion.swift
//  RETHINKA
//
//  Created by Aston Walsh on 14/10/2025.
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
        guard let selected = selectedAnswerIndex else { return false }
        return selected == correctAnswerIndex
    }
}

