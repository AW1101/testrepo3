//
//  TimelineMistakesView.swift
//  RETHINKA
//
//  Created by YUDONG LU on 19/10/2025.
//

import SwiftUI

// Displays the wrong question in one ExamTimeline.
struct TimelineMistakesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var title: String
    var dailyQuizzes: [DailyQuiz]
    @State var mistakes: [QuizQuestion] = []
        
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                if mistakes.isEmpty {
                    VStack {
                        Text("No mistakes in '\(title)'!")
                            .font(.title2)
                            .foregroundColor(Theme.primary)
                        
                        Text("Great job, you got this!")
                            .font(.headline)
                            .foregroundColor(Theme.secondary)
                    }
                }
                else {
                    VStack(spacing: 25) {
                        ForEach(Array(mistakes.enumerated()), id: \.element.id) { index, question in
                            if !question.isAnsweredCorrectly {
                                QuestionReviewCard(question: question, questionNumber: index + 1)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Mistakes in \"\(title)\"")
        .onAppear() {
            mistakes = dailyQuizzes.flatMap(\.questions).filter { !$0.isAnsweredCorrectly && $0.isAnswered }
        }
    }
}

// Preview stuff
struct MistakeReviewView_Previews: PreviewProvider {
    static var samepleQuizzes: [DailyQuiz] = [quiz1, quiz2]
    
    static var quiz1: DailyQuiz {
        let dq = DailyQuiz(
            date: Date(),
            examTimelineId: UUID(),
            dayNumber: 1,
            topic: "Sample Quiz 1"
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
    
    static var quiz2: DailyQuiz {
        let dq = DailyQuiz(
            date: Date(),
            examTimelineId: UUID(),
            dayNumber: 2,
            topic: "Sample Quiz 2"
        )

        // Placeholder questions
        let q1 = QuizQuestion(
            question: "What is the result of x ^ 2 = 1?",
            options: ["1 or -1", "1", "-1", "0"],
            correctAnswerIndex: 0,
            topic: dq.topic,
            type: "singleChoice"
        )
        q1.selectedAnswerIndex = 1 // wrong

        let q2 = QuizQuestion(
            question: "What is the capital of Australia?",
            options: ["Sydney", "Canberra", "Melbourne", "Perth"],
            correctAnswerIndex: 1,
            topic: dq.topic,
            type: "singleChoice"
        )
        q2.selectedAnswerIndex = 0 // wrong

        let q3 = QuizQuestion(
            question: "Under what circumstances does this statement hold true? . a ^ 2 + b ^ 2 = 2ab",
            options: ["a > b", "a < b", "a = b", "a = 0"], // placeholder for textField
            correctAnswerIndex: 2,
            topic: dq.topic,
            type: "singleChoice"
        )
        q3.selectedAnswerIndex = 3 // wrong

        dq.questions = [q1, q2, q3]
        dq.isCompleted = true
        dq.completedDate = Date()
        dq.score = 80

        return dq
    }
    

    static var previews: some View {
        TimelineMistakesView(title: "Science", dailyQuizzes: samepleQuizzes)
    }
}
