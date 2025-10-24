//
//  ReinforceTopicView.swift
//  RETHINKA
//
//  Created by YUDONG LU on 20/10/2025.
//

import SwiftUI

struct ReinforceTopicView: View {
    var questions: [QuizQuestion] = []
    @State private var quiz = DailyQuiz(date: Date(), examTimelineId: UUID(), dayNumber: 0, topic: "Reinforcement")
    
    var body: some View {
        VStack {
            if quiz.questions.isEmpty {
                Text("No reinforce question available")
                    .font(.title2)
                    .foregroundColor(Theme.primary)
            } else {
                QuizView(quiz: quiz)
            }
        }
        .onAppear {
            convertQuestionsToQuiz()
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func convertQuestionsToQuiz() {
        quiz.questions = questions
    }
}

#Preview {
    ReinforceTopicView()
}
