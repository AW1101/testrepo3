//
//  AIQuestionGenerator.swift
//  RETHINKA
//
//  Created by Aston Walsh on 15/10/2025.
//

import Foundation
import NaturalLanguage

// AI Question Generator
class AIQuestionGenerator {
    static let shared = AIQuestionGenerator()
    
    private init() {}
    
    // Track used questions to prevent duplicates
    private var usedQuestionHashes: Set<String> = []
    
    // Main Generation Function
    func generateQuestions(
        from examBrief: String,
        notes: [CourseNote],
        count: Int = 5,
        existingQuestions: [QuizQuestion] = []
    ) -> [QuizQuestion] {
        // Add existing questions to hash set
        for question in existingQuestions {
            usedQuestionHashes.insert(hashQuestion(question.question))
        }
        
        // Combine all content
        let allContent = combineContent(examBrief: examBrief, notes: notes)
        
        // Extract topics
        let topics = extractKeyTopics(from: allContent)
        
        // Generate questions for each topic
        var generatedQuestions: [QuizQuestion] = []
        var attempts = 0
        let maxAttempts = count * 3 // Try up to 3x the requested count
        
        while generatedQuestions.count < count && attempts < maxAttempts {
            attempts += 1
            
            // Pick a random topic
            guard let topic = topics.randomElement() else { break }
            
            // Generate a question for this topic
            if let question = generateQuestionForTopic(topic: topic, content: allContent) {
                let questionHash = hashQuestion(question.question)
                
                // Only add if not duplicate
                if !usedQuestionHashes.contains(questionHash) {
                    generatedQuestions.append(question)
                    usedQuestionHashes.insert(questionHash)
                }
            }
        }
        
        return generatedQuestions
    }
    
    // Generate Multiple Topic-Based Quizzes
    func generateTopicQuizzes(
        from examBrief: String,
        notes: [CourseNote],
        questionsPerTopic: Int = 5,
        existingQuestions: [QuizQuestion] = []
    ) -> [String: [QuizQuestion]] {
        // Add existing questions to hash set
        for question in existingQuestions {
            usedQuestionHashes.insert(hashQuestion(question.question))
        }
        
        let allContent = combineContent(examBrief: examBrief, notes: notes)
        let topics = extractKeyTopics(from: allContent)
        
        var quizzesByTopic: [String: [QuizQuestion]] = [:]
        
        for topic in topics.prefix(5) { // Limit to 5 topics max per day
            var topicQuestions: [QuizQuestion] = []
            var attempts = 0
            let maxAttempts = questionsPerTopic * 3
            
            while topicQuestions.count < questionsPerTopic && attempts < maxAttempts {
                attempts += 1
                
                if let question = generateQuestionForTopic(topic: topic, content: allContent) {
                    let questionHash = hashQuestion(question.question)
                    
                    if !usedQuestionHashes.contains(questionHash) {
                        topicQuestions.append(question)
                        usedQuestionHashes.insert(questionHash)
                    }
                }
            }
            
            if !topicQuestions.isEmpty {
                quizzesByTopic[topic] = topicQuestions
            }
        }
        
        return quizzesByTopic
    }
    
    // Helper Functions
    
    private func combineContent(examBrief: String, notes: [CourseNote]) -> String {
        var combined = examBrief + "\n\n"
        
        for note in notes {
            combined += note.title + "\n"
            combined += note.content + "\n\n"
        }
        
        return combined
    }
    
    private func extractKeyTopics(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        
        var topics: [String] = []
        var topicFrequency: [String: Int] = [:]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if tag == .noun || tag == .verb {
                let word = String(text[tokenRange])
                
                // Filter out common words and short words
                if word.count > 4 && !commonWords.contains(word.lowercased()) {
                    topicFrequency[word] = (topicFrequency[word] ?? 0) + 1
                }
            }
            return true
        }
        
        // Sort by frequency and take top topics
        let sortedTopics = topicFrequency.sorted { $0.value > $1.value }
        topics = sortedTopics.prefix(15).map { $0.key }
        
        // If we didn't find enough topics, add some defaults
        if topics.isEmpty {
            topics = ["General Concepts", "Key Terms", "Important Ideas"]
        }
        
        return topics
    }
    
    private func generateQuestionForTopic(topic: String, content: String) -> QuizQuestion? {
        // Find sentences containing the topic
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.localizedCaseInsensitiveContains(topic) && $0.count > 20 }
        
        guard let sentence = sentences.randomElement() else {
            return generateTemplateQuestion(topic: topic)
        }
        
        // Generate question from sentence
        let question = generateQuestionFromSentence(sentence, topic: topic)
        let correctAnswer = extractAnswerFromSentence(sentence, topic: topic)
        let wrongAnswers = generateWrongAnswers(correctAnswer: correctAnswer, topic: topic)
        
        var allOptions = [correctAnswer] + wrongAnswers
        allOptions.shuffle()
        
        guard let correctIndex = allOptions.firstIndex(of: correctAnswer) else {
            return nil
        }
        
        return QuizQuestion(
            question: question,
            options: allOptions,
            correctAnswerIndex: correctIndex,
            topic: topic,
            difficulty: 1
        )
    }
    
    private func generateQuestionFromSentence(_ sentence: String, topic: String) -> String {
        // Simple question templates
        let templates = [
            "What is \(topic)?",
            "Which of the following best describes \(topic)?",
            "What is the main purpose of \(topic)?",
            "How does \(topic) work?",
            "What is true about \(topic)?"
        ]
        
        return templates.randomElement() ?? "What is \(topic)?"
    }
    
    private func extractAnswerFromSentence(_ sentence: String, topic: String) -> String {
        // Extract a meaningful phrase from the sentence
        let words = sentence.components(separatedBy: " ")
        
        if words.count > 5 {
            let startIndex = min(words.count - 5, 2)
            let endIndex = min(startIndex + 5, words.count)
            return words[startIndex..<endIndex].joined(separator: " ")
        }
        
        return sentence
    }
    
    private func generateWrongAnswers(correctAnswer: String, topic: String) -> [String] {
        // Generate plausible wrong answers
        let wrongAnswerTemplates = [
            "A method used in advanced \(topic) systems",
            "The opposite approach to \(topic)",
            "An outdated technique for \(topic)",
            "A common misconception about \(topic)",
            "An alternative to \(topic)",
            "The inverse of \(topic)",
            "A related but different concept"
        ]
        
        var wrongAnswers: [String] = []
        
        // Make sure we generate different answers
        var availableTemplates = wrongAnswerTemplates
        availableTemplates.shuffle()
        
        for _ in 0..<3 {
            if let template = availableTemplates.popLast() {
                wrongAnswers.append(template)
            }
        }
        
        return wrongAnswers
    }
    
    private func generateTemplateQuestion(topic: String) -> QuizQuestion {
        let questionTemplates = [
            ("What is the primary function of \(topic)?", "To manage and organize data", ["To delete all files", "To slow down the system", "To create errors"]),
            ("Which statement about \(topic) is correct?", "It is an important concept", ["It is completely obsolete", "It should never be used", "It has no practical applications"]),
            ("What does \(topic) refer to?", "A key component of the system", ["A type of error message", "An outdated feature", "A security vulnerability"])
        ]
        
        let template = questionTemplates.randomElement()!
        var allOptions = [template.1] + template.2
        allOptions.shuffle()
        
        let correctIndex = allOptions.firstIndex(of: template.1)!
        
        return QuizQuestion(
            question: template.0,
            options: allOptions,
            correctAnswerIndex: correctIndex,
            topic: topic,
            difficulty: 1
        )
    }
    
    private func hashQuestion(_ question: String) -> String {
        // Simple hash to detect duplicate questions
        return question.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }
    
    // Common words to filter out
    private let commonWords: Set<String> = [
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
        "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
        "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
        "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
        "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
        "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
        "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
        "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
        "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
        "even", "new", "want", "because", "any", "these", "give", "day", "most", "us"
    ]
}
