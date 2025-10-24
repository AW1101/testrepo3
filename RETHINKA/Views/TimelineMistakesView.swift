//
//  TimelineMistakesView.swift
//  RETHINKA
//
//  Created by YUDONG LU on 19/10/2025.
//

import SwiftUI
import SwiftData

struct TimelineMistakesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var mistakes: [QuizQuestion] = []
    @State private var isReinforcing: Bool = false
    @State private var reinforceQuestions: [QuizQuestion] = []
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    var title: String
    var dailyQuizzes: [DailyQuiz]
        
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                if mistakes.isEmpty {
                    // Display when there is no wrong answer
                    VStack {
                        Spacer()
                        Circle()
                            .fill(.white)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "checkmark.seal.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(Theme.primary)
                            )
                        
                        Text("No mistakes in '\(title)'!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Great job, you got this!")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                    }
                    .padding()
                }
                else {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 10) {
                            Circle()
                                .fill(.white)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.orange)
                                )
                            
                            Text("Review Your Mistakes")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("\(mistakes.count) \(mistakes.count == 1 ? "question" : "questions") to review")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top)
                        .padding(.horizontal)
                        
                        // Mistakes List
                        ForEach(Array(mistakes.enumerated()), id: \.element.id) { index, question in
                            VStack(spacing: 12) {
                                QuestionReviewCard(question: question, questionNumber: index + 1)
                                
                                // Generate questions with same topic and navigate to ReinforceTopicView when it's successful
                                Button(action: {
                                    generateReinforceQuestions(mistake: question)
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Practice Similar Questions")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Theme.secondary)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Mistakes in \"\(title)\"")
        .onAppear() {
            mistakes = dailyQuizzes.flatMap(\.questions).filter { !$0.isAnsweredCorrectly && $0.isAnswered }
        }
        .navigationDestination(isPresented: $isReinforcing) {
            ReinforceTopicView(questions: reinforceQuestions)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func generateReinforceQuestions(mistake: QuizQuestion) {
        AIQuestionGenerator.shared.generateVariants(for: mistake) { result in
            switch result {
            case .success(let generatedQuestions):
                DispatchQueue.main.async {
                    let converted = generatedQuestions.map { gen in
                        QuizQuestion(
                            question: gen.question,
                            options: gen.options,
                            correctAnswerIndex: gen.correctAnswerIndex,
                            topic: mistake.topic,
                            difficulty: 1,
                            type: gen.type
                        )
                    }
                    self.reinforceQuestions = converted
                    
                    for question in self.reinforceQuestions {
                        modelContext.insert(question)
                    }
                    do {
                        try modelContext.save()
                        self.isReinforcing = true
                    } catch {
                        errorMessage = "Failed to create reinforcement questions: \(error.localizedDescription)"
                        self.isReinforcing = false
                        showingError = true
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    errorMessage = "Could not generate questions: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// Preview
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

