//
//  ReinforceTopicView.swift
//  RETHINKA
//
//  Created by YUDONG LU on 20/10/2025.
//

import SwiftUI

struct ReinforceTopicView: View {
    @Environment(\.dismiss) private var dismiss
    var questions: [QuizQuestion] = []
    @State private var quiz = DailyQuiz(date: Date(), examTimelineId: UUID(), dayNumber: 0, topic: "Reinforcement")
    @State private var showingCancelConfirmation = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if quiz.questions.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("No Practice Questions Available")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Unable to generate practice questions. Please try again.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Go Back")
                            .font(.headline)
                            .foregroundColor(Theme.primary)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(.white)
                            .cornerRadius(20)
                    }
                    .padding(.top)
                }
                .padding()
            } else {
                QuizView(quiz: quiz, customTitle: "Practice Quiz")
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if quiz.questions.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingCancelConfirmation = true
                    }) {
                        Text("Cancel")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear {
            convertQuestionsToQuiz()
        }
        .alert("Cancel Practice Quiz?", isPresented: $showingCancelConfirmation) {
            Button("Continue Quiz", role: .cancel) { }
            Button("Yes, Cancel", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Your progress will not be saved. Are you sure you want to cancel?")
        }
    }

    private func convertQuestionsToQuiz() {
        quiz.questions = questions
        quiz.topic = "Practice Questions"
    }
}


#Preview {
    NavigationStack {
        ReinforceTopicView(questions: [
            QuizQuestion(
                question: "Sample practice question?",
                options: ["A", "B", "C", "D"],
                correctAnswerIndex: 0,
                topic: "Practice",
                type: "multipleChoice"
            )
        ])
    }
}
