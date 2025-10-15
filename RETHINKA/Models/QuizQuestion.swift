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
    
    init(question: String, options: [String], correctAnswerIndex: Int, topic: String = "General", difficulty: Int = 1) {
        self.id = UUID()
        self.question = question
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.topic = topic
        self.difficulty = difficulty
        self.timesAnsweredIncorrectly = 0
    }
    
    var isAnsweredCorrectly: Bool {
        guard let selected = selectedAnswerIndex else { return false }
        return selected == correctAnswerIndex
    }
}
