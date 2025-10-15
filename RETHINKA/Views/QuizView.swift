//
//  QuizView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 14/10/2025.
//

import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var quiz: DailyQuiz
    
    @State private var currentQuestionIndex = 0
    @State private var showingResults = false
    @State private var selectedAnswer: Int?
    @State private var hasAnswered = false
    @State private var isGenerating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var timeline: ExamTimeline?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if quiz.questions.isEmpty {
                    // Empty state - questions will be generated
                    VStack(spacing: 20) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            
                            Text("Generating Questions...")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                            
                            Text("Using AI to create \(quiz.topic) quiz")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.secondary)
                            
                            Text("Quiz Generation")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.primary)
                            
                            Text("Questions will be automatically generated based on your exam brief and notes.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Text("Topic: \(quiz.topic)")
                                .font(.caption)
                                .foregroundColor(Theme.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Theme.secondary.opacity(0.1))
                                .cornerRadius(15)
                            
                            Button(action: generateQuestions) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Generate Questions")
                                }
                                .font(.headline)
                            }
                            .buttonStyle(Theme.PrimaryButton())
                            .padding(.horizontal, 40)
                        }
                    }
                } else if showingResults {
                    QuizResultView(quiz: quiz, onClose: {
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
                                if currentQuestionIndex < quiz.questions.count {
                                    let question = quiz.questions[currentQuestionIndex]
                                    
                                    // Question
                                    VStack(alignment: .leading, spacing: 15) {
                                        Text("Question \(currentQuestionIndex + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(question.question)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .cardStyle()
                                    
                                    // Options
                                    VStack(spacing: 15) {
                                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                                            AnswerOption(
                                                option: option,
                                                index: index,
                                                isSelected: selectedAnswer == index,
                                                isCorrect: hasAnswered ? index == question.correctAnswerIndex : nil,
                                                onSelect: {
                                                    if !hasAnswered {
                                                        selectedAnswer = index
                                                    }
                                                }
                                            )
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
                                .buttonStyle(Theme.PrimaryButton(isDisabled: selectedAnswer == nil))
                                .disabled(selectedAnswer == nil)
                            }
                        }
                        .padding()
                        .background(Theme.background)
                    }
                }
            }
            .navigationTitle("Day \(quiz.dayNumber) Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                fetchTimeline()
            }
        }
    }
    
    private func fetchTimeline() {
        let timelineId = quiz.examTimelineId   // capture UUID value

        let descriptor = FetchDescriptor<ExamTimeline>(
            predicate: #Predicate { $0.id == timelineId }
        )

        if let fetchedTimeline = try? modelContext.fetch(descriptor).first {
            timeline = fetchedTimeline
        }
    }
    
    private func generateQuestions() {
        guard let timeline = timeline else {
            errorMessage = "Could not find timeline information"
            showingError = true
            return
        }
        
        isGenerating = true
        
        // Get all existing questions from all quizzes to avoid duplicates
        let allExistingQuestions = timeline.dailyQuizzes.flatMap { $0.questions }
        
        // Generate questions on background thread
        Task {
            let questions = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let generated = AIQuestionGenerator.shared.generateQuestions(
                        from: timeline.examBrief,
                        notes: timeline.notes,
                        count: 5,
                        existingQuestions: allExistingQuestions
                    )
                    continuation.resume(returning: generated)
                }
            }
            
            await MainActor.run {
                isGenerating = false
                
                if questions.isEmpty {
                    errorMessage = "Could not generate questions. Please check your exam brief and notes contain enough information."
                    showingError = true
                } else {
                    quiz.questions = questions
                    do {
                        try modelContext.save()
                    } catch {
                        errorMessage = "Failed to save questions: \(error.localizedDescription)"
                        showingError = true
                    }
                }
            }
        }
    }
    
    private func submitAnswer() {
        guard let selectedAnswer = selectedAnswer, currentQuestionIndex < quiz.questions.count else { return }
        
        quiz.questions[currentQuestionIndex].selectedAnswerIndex = selectedAnswer
        
        if !quiz.questions[currentQuestionIndex].isAnsweredCorrectly {
            quiz.questions[currentQuestionIndex].timesAnsweredIncorrectly += 1
        }
        
        hasAnswered = true
    }
    
    private func nextQuestion() {
        if currentQuestionIndex < quiz.questions.count - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
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
            showingResults = true
        } catch {
            print("Error saving quiz: \(error)")
        }
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
                    .foregroundColor(Theme.primary)
                
                Spacer()
            }
            
            ProgressView(value: progress)
                .tint(Theme.secondary)
        }
        .padding()
        .background(Theme.cardBackground)
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
                return Color.green.opacity(0.2)
            } else if isSelected {
                return Color.red.opacity(0.2)
            }
        } else if isSelected {
            return Theme.primary.opacity(0.1)
        }
        return Theme.cardBackground
    }
    
    private var borderColor: Color {
        if let isCorrect = isCorrect {
            if isCorrect {
                return .green
            } else if isSelected {
                return .red
            }
        } else if isSelected {
            return Theme.primary
        }
        return Theme.secondary.opacity(0.3)
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
        return Theme.primary
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Circle()
                    .fill(isSelected ? Theme.primary : Theme.secondary.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("\(["A", "B", "C", "D"][index])")
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .secondary)
                    )
                
                Text(option)
                    .font(.body)
                    .foregroundColor(.primary)
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
