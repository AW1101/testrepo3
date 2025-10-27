//
//  ExamTimeline.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import SwiftData

@Model
final class ExamTimeline {
    var id: UUID
    var examName: String
    var examBrief: String
    var examDate: Date
    var createdDate: Date
    var notes: [CourseNote]
    var dailyQuizzes: [DailyQuiz]
    var isActive: Bool
    
    init(examName: String, examBrief: String, examDate: Date, notes: [CourseNote] = []) {
        self.id = UUID()
        self.examName = examName
        self.examBrief = examBrief
        self.examDate = examDate
        self.createdDate = Date()
        self.notes = notes
        self.dailyQuizzes = []
        self.isActive = true
    }
    
    // Helper computed properties
    var totalQuizCount: Int {
        dailyQuizzes.count
    }
    
    var completedQuizCount: Int {
        dailyQuizzes.filter { $0.isCompleted }.count
    }
    
    var progressPercentage: Double {
        guard totalQuizCount > 0 else { return 0 }
        return Double(completedQuizCount) / Double(totalQuizCount)
    }
    
    var daysUntilExam: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExamDate = calendar.startOfDay(for: examDate)
        
        guard let days = calendar.dateComponents([.day], from: startOfToday, to: startOfExamDate).day else {
            return 0
        }
        // Add 1 to include today in the count
        // e.g., if exam is tomorrow, we want to show "1 day" not "0 days"
        return max(0, days + 1)
    }
}

@Model
final class DailyQuiz {
    var id: UUID
    var date: Date
    var examTimelineId: UUID
    var dayNumber: Int
    var topic: String
    var questions: [QuizQuestion]
    var isCompleted: Bool
    var score: Double?
    var completedDate: Date?
    
    init(date: Date, examTimelineId: UUID, dayNumber: Int, topic: String = "General") {
        self.id = UUID()
        self.date = date
        self.examTimelineId = examTimelineId
        self.dayNumber = dayNumber
        self.topic = topic
        self.questions = []
        self.isCompleted = false
    }
    
    // Helper computed properties
    var correctAnswerCount: Int {
        questions.filter { $0.isAnsweredCorrectly }.count
    }
    
    var incorrectAnswerCount: Int {
        questions.count - correctAnswerCount
    }
}
