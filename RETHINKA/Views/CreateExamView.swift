//
//  CreateExamView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import SwiftUI
import SwiftData
import WidgetKit

struct CreateExamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var examName: String = ""
    @State private var examBrief: String = ""
    @State private var examDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notes: [CourseNote] = []
    @State private var showingAddNote = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0
    @State private var generationStatus = ""
    
    private var isValidInput: Bool {
        !examName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !examBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        examDate > Date()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if isGenerating {
                    GenerationLoadingView(progress: generationProgress, status: generationStatus)
                } else {
                    ScrollView {
                        VStack(spacing: 25) {
                            // Header
                            VStack(spacing: 10) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "doc.text.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(Theme.primary)
                                    )
                                
                                Text("Create Exam Timeline")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .padding(.top)
                            
                            // Exam Name
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Exam Name", systemImage: "pencil.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                TextField("e.g., iOS Development Final", text: $examName)
                                    .padding()
                                    .background(.white)
                                    .cornerRadius(15)
                            }
                            .padding(.horizontal)
                            
                            // Exam Brief (Mandatory)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("Exam Brief", systemImage: "doc.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("(Required)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                TextEditor(text: $examBrief)
                                    .frame(minHeight: 150)
                                    .padding(8)
                                    .background(.white)
                                    .cornerRadius(15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.clear, lineWidth: 0)
                                    )
                            }
                            .padding(.horizontal)
                            
                            // Exam Date
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Exam Date", systemImage: "calendar.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                DatePicker("Select Date", selection: $examDate, in: Date()..., displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .padding()
                                    .background(.white)
                                    .cornerRadius(15)
                                    .colorScheme(.light)
                            }
                            .padding(.horizontal)
                            
                            // Course Notes Section
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Label("Course Notes", systemImage: "note.text")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showingAddNote = true
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                if notes.isEmpty {
                                    Text("No notes added yet")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(15)
                                } else {
                                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                                        NoteCard(note: note, index: index + 1) {
                                            notes.removeAll { $0.id == note.id }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Info Box
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Smart Generation")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("Today's 3 quizzes will be generated now. Future quizzes generate automatically each day.")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(15)
                            .padding(.horizontal)
                            
                            // Create Button
                            Button(action: createTimeline) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Create Timeline")
                                }
                                .font(.headline)
                            }
                            .buttonStyle(Theme.PrimaryButton(isDisabled: !isValidInput || isGenerating))
                            .disabled(!isValidInput || isGenerating)
                            .padding(.horizontal)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isGenerating)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(isGenerating)
                }
            }
            .sheet(isPresented: $showingAddNote) {
                AddNoteView { note in
                    notes.append(note)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createTimeline() {
        guard isValidInput else {
            errorMessage = "Please fill in all required fields."
            showingError = true
            return
        }
        
        isGenerating = true
        generationProgress = 0.1
        generationStatus = "Creating timeline..."
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.startOfDay(for: examDate)
        
        guard let daysDifference = calendar.dateComponents([.day], from: startDate, to: endDate).day,
              daysDifference > 0 else {
            errorMessage = "Exam date must be in the future."
            showingError = true
            isGenerating = false
            return
        }
        
        // Create timeline
        let timeline = ExamTimeline(
            examName: examName,
            examBrief: examBrief,
            examDate: examDate,
            notes: notes
        )
        
        // Create EMPTY placeholder quizzes for all days
        generationStatus = "Scheduling quiz days..."
        generationProgress = 0.2
        
        for dayOffset in 0...daysDifference {
            guard let quizDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                continue
            }
            
            // Create 3 empty quizzes per day
            for quizNum in 0..<3 {
                let quiz = DailyQuiz(
                    date: quizDate,
                    examTimelineId: timeline.id,
                    dayNumber: dayOffset + 1,
                    topic: "Pending..." // Will be populated when generated
                )
                timeline.dailyQuizzes.append(quiz)
            }
        }
        
        modelContext.insert(timeline)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to create timeline: \(error.localizedDescription)"
            showingError = true
            isGenerating = false
            return
        }
        
        generationProgress = 0.3
        generationStatus = "Generating today's quizzes..."
        
        // Generate ONLY today's 3 quizzes
        generateTodayQuizzes(for: timeline)
    }
    
    private func generateTodayQuizzes(for timeline: ExamTimeline) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get today's 3 quizzes
        let todayQuizzes = timeline.dailyQuizzes
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
            .prefix(3)
        
        guard todayQuizzes.count > 0 else {
            // No quizzes today (shouldn't happen)
            finishCreation(for: timeline)
            return
        }
        
        let notesArray = notes.map { $0.content }
        
        // Request 3 topics with 10 questions each
        AIQuestionGenerator.shared.generateTopicQuizzes(
            examBrief: examBrief,
            notes: notesArray,
            topicsWanted: 3,
            questionsPerTopic: 10,
            existingTopics: [] // First generation, no existing topics
        ) { result in
            DispatchQueue.main.async {
                self.generationProgress = 0.7
                
                switch result {
                case .failure(let err):
                    print("Generation failed: \(err.localizedDescription)")
                    // Use fallback questions
                    self.useFallbackQuestions(for: Array(todayQuizzes), in: timeline)
                    
                case .success(let topicMap):
                    self.generationStatus = "Populating quizzes..."
                    self.generationProgress = 0.8
                    
                    var topicKeys = Array(topicMap.keys)
                    if topicKeys.isEmpty {
                        self.useFallbackQuestions(for: Array(todayQuizzes), in: timeline)
                        return
                    }
                    
                    // Assign topics and questions to today's 3 quizzes
                    for (index, quiz) in todayQuizzes.enumerated() {
                        let topicIndex = index % topicKeys.count
                        let topic = topicKeys[topicIndex]
                        
                        // Update quiz in timeline
                        if let quizIdx = timeline.dailyQuizzes.firstIndex(where: { $0.id == quiz.id }) {
                            timeline.dailyQuizzes[quizIdx].topic = topic
                            timeline.dailyQuizzes[quizIdx].questions.removeAll()
                            
                            if let generatedQuestions = topicMap[topic] {
                                // Take exactly 10 questions (or pad if needed)
                                let questionsToUse = Array(generatedQuestions.prefix(10))
                                
                                for genQ in questionsToUse {
                                    let question = QuizQuestion(
                                        question: genQ.question,
                                        options: genQ.options,
                                        correctAnswerIndex: genQ.correctAnswerIndex,
                                        topic: topic,
                                        difficulty: 1,
                                        type: genQ.type
                                    )
                                    timeline.dailyQuizzes[quizIdx].questions.append(question)
                                }
                                
                                // If we got fewer than 10, pad with fallback
                                while timeline.dailyQuizzes[quizIdx].questions.count < 10 {
                                    let paddingQ = QuizQuestion(
                                        question: "Explain a key concept.",
                                        options: ["Provide a detailed answer", "", "", ""],
                                        correctAnswerIndex: 0,
                                        topic: topic,
                                        type: "textField"
                                    )
                                    timeline.dailyQuizzes[quizIdx].questions.append(paddingQ)
                                }
                            }
                        }
                    }
                    
                    self.finishCreation(for: timeline)
                }
            }
        }
    }
    
    private func useFallbackQuestions(for quizzes: [DailyQuiz], in timeline: ExamTimeline) {
        generationStatus = "Using offline questions..."
        
        let fallbackTopics = ["Core Concepts", "Key Principles", "Practice Questions"]
        
        for (index, quiz) in quizzes.enumerated() {
            let topic = fallbackTopics[index % fallbackTopics.count]
            
            if let quizIdx = timeline.dailyQuizzes.firstIndex(where: { $0.id == quiz.id }) {
                timeline.dailyQuizzes[quizIdx].topic = topic
                timeline.dailyQuizzes[quizIdx].questions.removeAll()
                
                // Generate 10 simple fallback questions
                for i in 1...10 {
                    let question = QuizQuestion(
                        question: "Question \(i) about \(topic.lowercased()): Describe a key concept.",
                        options: ["", "", "", ""],
                        correctAnswerIndex: 0,
                        topic: topic,
                        type: "textField"
                    )
                    timeline.dailyQuizzes[quizIdx].questions.append(question)
                }
            }
        }
        
        finishCreation(for: timeline)
    }
    
    private func finishCreation(for timeline: ExamTimeline) {
        generationProgress = 0.95
        generationStatus = "Finalizing..."
        
        do {
            try modelContext.save()
            NotificationManager.shared.scheduleDailyQuizNotification(for: timeline)
            
            // Force widget to refresh immediately
            WidgetCenter.shared.reloadAllTimelines()
            print("App: Forced widget refresh after timeline creation")
            
            generationProgress = 1.0
            generationStatus = "Complete!"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isGenerating = false
                self.dismiss()
            }
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showingError = true
            isGenerating = false
        }
    }
}

// Supporting Views
struct GenerationLoadingView: View {
    let progress: Double
    let status: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2.5)
                    .frame(width: 120, height: 120)
                
                VStack(spacing: 10) {
                    Text("Setting Up Your Timeline")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(status)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(Color.white.opacity(0.15))
            .cornerRadius(30)
            .shadow(radius: 20)
        }
    }
}

struct NoteCard: View {
    let note: CourseNote
    let index: Int
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(.white)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(index)")
                        .font(.headline)
                        .foregroundColor(Theme.primary)
                )
            
            VStack(alignment: .leading, spacing: 5) {
                Text(note.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(note.content.prefix(50))\(note.content.count > 50 ? "..." : "")")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .foregroundColor(.red)
                    .font(.title3)
            }
        }
        .padding()
        .cardStyle()
    }
}

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var noteTitle: String = ""
    @State private var noteContent: String = ""
    let onSave: (CourseNote) -> Void
    
    private var isValid: Bool {
        !noteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Note Title")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("e.g., Lecture 1: SwiftUI Basics", text: $noteTitle)
                            .padding()
                            .background(.white)
                            .cornerRadius(15)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Note Content")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextEditor(text: $noteContent)
                            .frame(minHeight: 300)
                            .padding(8)
                            .background(.white)
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.clear, lineWidth: 0)
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        let note = CourseNote(title: noteTitle, content: noteContent)
                        onSave(note)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Add Note")
                        }
                        .font(.headline)
                    }
                    .buttonStyle(Theme.PrimaryButton(isDisabled: !isValid))
                    .disabled(!isValid)
                }
                .padding()
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    CreateExamView()
}
