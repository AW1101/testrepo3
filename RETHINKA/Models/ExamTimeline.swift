//
//  ExamTimeline.swift
//  RETHINKA
//
//  Created by Aston Walsh on 14/10/2025.
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
    
    func generateDailyQuizzes() {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.startOfDay(for: examDate)
        
        guard let daysDifference = calendar.dateComponents([.day], from: startDate, to: endDate).day else {
            return
        }
        
        dailyQuizzes.removeAll()
        
        // Simple topic list - will be extracted from content
        let baseTopics = ["Core Concepts", "Key Principles", "Advanced Topics", "Fundamentals", "Practical Applications"]
        
        for dayOffset in 0...daysDifference {
            if let quizDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                // Create 2-3 quizzes per day with different topics
                let quizzesPerDay = min(3, baseTopics.count)
                
                for i in 0..<quizzesPerDay {
                    let topicIndex = (dayOffset * quizzesPerDay + i) % baseTopics.count
                    let topic = baseTopics[topicIndex]
                    
                    let quiz = DailyQuiz(
                        date: quizDate,
                        examTimelineId: id,
                        dayNumber: dayOffset + 1,
                        topic: topic
                    )
                    dailyQuizzes.append(quiz)
                }
            }
        }
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
}
