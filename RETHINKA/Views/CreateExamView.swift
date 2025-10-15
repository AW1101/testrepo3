//
//  CreateExamView.swift
//  RETHINKA
//
//  Created by Aston Walsh on 14/10/2025.
//

import Foundation
import SwiftUI
import SwiftData

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
    
    private var isValidInput: Bool {
        !examName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !examBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        examDate > Date()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 10) {
                            Circle()
                                .fill(Theme.primary)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "doc.text.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.white)
                                )
                            
                            Text("Create Exam Timeline")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.primary)
                        }
                        .padding(.top)
                        
                        // Exam Name
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Exam Name", systemImage: "pencil.circle.fill")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                            
                            TextField("e.g., iOS Development Final", text: $examName)
                                .textFieldStyle(.roundedBorder)
                                .padding()
                                .background(Theme.cardBackground)
                                .cornerRadius(15)
                        }
                        .padding(.horizontal)
                        
                        // Exam Brief (Mandatory)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Exam Brief", systemImage: "doc.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(Theme.primary)
                                
                                Text("(Required)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            TextEditor(text: $examBrief)
                                .frame(minHeight: 150)
                                .padding(8)
                                .background(Theme.cardBackground)
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Theme.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                        
                        // Exam Date
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Exam Date", systemImage: "calendar.circle.fill")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                            
                            DatePicker("Select Date", selection: $examDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(Theme.cardBackground)
                                .cornerRadius(15)
                        }
                        .padding(.horizontal)
                        
                        // Course Notes Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Label("Course Notes", systemImage: "note.text")
                                    .font(.headline)
                                    .foregroundColor(Theme.primary)
                                
                                Text("(Optional)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingAddNote = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(Theme.secondary)
                                }
                            }
                            
                            if notes.isEmpty {
                                Text("No notes added yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                                    .background(Theme.cardBackground)
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
                        
                        // Create Button
                        Button(action: createTimeline) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Create Timeline")
                            }
                            .font(.headline)
                        }
                        .buttonStyle(Theme.PrimaryButton(isDisabled: !isValidInput))
                        .disabled(!isValidInput)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
            errorMessage = "Please fill in all required fields and ensure the exam date is in the future."
            showingError = true
            return
        }
        
        let timeline = ExamTimeline(
            examName: examName,
            examBrief: examBrief,
            examDate: examDate,
            notes: notes
        )
        
        timeline.generateDailyQuizzes()
        
        modelContext.insert(timeline)
        
        do {
            try modelContext.save()
            NotificationManager.shared.scheduleDailyQuizNotification(for: timeline)
            dismiss()
        } catch {
            errorMessage = "Failed to create timeline: \(error.localizedDescription)"
            showingError = true
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
                .fill(Theme.secondary)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(index)")
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 5) {
                Text(note.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(note.content.prefix(50))\(note.content.count > 50 ? "..." : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                            .foregroundColor(Theme.primary)
                        
                        TextField("e.g., Lecture 1: SwiftUI Basics", text: $noteTitle)
                            .textFieldStyle(.roundedBorder)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(15)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Note Content")
                            .font(.headline)
                            .foregroundColor(Theme.primary)
                        
                        TextEditor(text: $noteContent)
                            .frame(minHeight: 300)
                            .padding(8)
                            .background(Theme.cardBackground)
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Theme.secondary.opacity(0.3), lineWidth: 1)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
