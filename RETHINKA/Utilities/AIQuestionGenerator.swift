//
//  AIQuestionGenerator.swift
//  RETHINKA
//
//  Created by Aston Walsh on 12/10/2025.
//

// Works somewhat well, i've previously had issues with it generating the wrong number of questions/answers but i think that's fixed, there's still a lot left to rework (text field questions are particularly vague, other questions can be a bit simplistic ((not that bad really, to be expected sometimes)), difficulty stuff isnt implemented in any way yet etc.)


import Foundation

struct GeneratedQuestion: Codable {
    let question: String
    let options: [String]
    var correctAnswerIndex: Int
    let type: String // "multipleChoice" or "textField"
}

final class AIQuestionGenerator {
    static let shared = AIQuestionGenerator()
    
    private let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    private let timeout: TimeInterval = 60.0
    
    // Get difficulty from UserDefaults
    private var currentDifficulty: String {
        UserDefaults.standard.string(forKey: "difficultyLevel") ?? "Medium"
    }
    
    private var difficultyInstructions: String {
        switch currentDifficulty {
        case "Easy":
            return """
            DIFFICULTY: EASY
            - Use straightforward language
            - Focus on basic concepts and definitions
            - Questions should test recall and basic understanding
            - Avoid complex scenarios or multi-step reasoning
            - Example: "What is the definition of X?"
            """
        case "Hard":
            return """
            DIFFICULTY: HARD
            - Use complex scenarios requiring analysis
            - Questions should test application and synthesis
            - Include multi-step reasoning and edge cases
            - Require deep understanding, not just memorization
            - Example: "In scenario X, what would happen if Y changed, and why?"
            """
        default: // Medium
            return """
            DIFFICULTY: MEDIUM
            - Balance between recall and application
            - Questions should test understanding and basic application
            - Include some scenario-based questions
            - Require comprehension beyond simple memorization
            - Example: "How would you apply concept X in situation Y?"
            """
        }
    }
    
    // Main generator
    func generateTopicQuizzes(
        examBrief: String,
        notes: [String],
        topicsWanted: Int = 3,
        questionsPerTopic: Int = 10,
        existingTopics: [String] = [],
        completion: @escaping (Result<[String: [GeneratedQuestion]], Error>) -> Void
    ) {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("No API key found. Using fallback.")
            completion(.success(localFallbackTopics(count: topicsWanted, questionsPerTopic: questionsPerTopic)))
            return
        }
        
        let combinedInput = """
        EXAM BRIEF:
        \(examBrief.prefix(1500))

        NOTES:
        \(notes.joined(separator: "\n").prefix(1000))
        """
        
        let systemPrompt = """
        You are a quiz generator. Generate exactly \(topicsWanted) topics with EXACTLY \(questionsPerTopic) questions each.
        
        \(difficultyInstructions)
        
        CRITICAL RULES:
        - EVERY question must have EXACTLY 4 options in the options array
        - For multipleChoice: all 4 options must be distinct answers
        - For textField: options[0] = the ONE correct answer (highly specific, absolutely no room for interpretation), options[1-3] = "" (empty strings)
        - correctAnswerIndex is ALWAYS 0 for textField questions
        - Mix 70% multipleChoice and 30% textField
        - ALL questions must match the specified difficulty level
        
        Output MUST be valid JSON:
        {
          "topics": [
            {
              "topic": "Topic Name",
              "questions": [
                {
                  "question": "Question text?",
                  "options": ["Option A", "Option B", "Option C", "Option D"],
                  "correctAnswerIndex": 2,
                  "type": "multipleChoice"
                },
                {
                  "question": "Define this concept:",
                  "options": ["The specific correct answer here", "", "", ""],
                  "correctAnswerIndex": 0,
                  "type": "textField"
                }
              ]
            }
          ]
        }
        
        IMPORTANT: Each topic MUST have EXACTLY \(questionsPerTopic) questions, and EVERY question MUST have EXACTLY 4 options.
        """
        
        let userPrompt = """
        Generate \(topicsWanted) UNIQUE topics (avoid these: \(existingTopics.joined(separator: ", "))) with \(questionsPerTopic) questions at \(currentDifficulty) difficulty based on:
        \(combinedInput)
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.7,
            "max_tokens": 4000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.success(self.localFallbackTopics(count: topicsWanted, questionsPerTopic: questionsPerTopic)))
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(.success(self.localFallbackTopics(count: topicsWanted, questionsPerTopic: questionsPerTopic)))
                return
            }
            
            if let rawString = String(data: data, encoding: .utf8) {
                print("API Response (first 500 chars): \(rawString.prefix(500))")
            }
            
            do {
                let decoded = try self.decodeResponse(data)
                print("Successfully generated \(decoded.keys.count) topics at \(self.currentDifficulty) difficulty")
                completion(.success(decoded))
            } catch {
                print("JSON parse failed: \(error.localizedDescription)")
                if let partialData = try? self.attemptPartialParse(data) {
                    print("Using partial data")
                    completion(.success(partialData))
                } else {
                    print("Falling back to local questions")
                    completion(.success(self.localFallbackTopics(count: topicsWanted, questionsPerTopic: questionsPerTopic)))
                }
            }
        }
        
        task.resume()
    }
    
    private func decodeResponse(_ data: Data) throws -> [String: [GeneratedQuestion]] {
        struct APIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw NSError(domain: "Missing content", code: -2)
        }
        
        var cleanedContent = content
        if cleanedContent.contains("```json") {
            cleanedContent = cleanedContent
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw NSError(domain: "Invalid UTF8", code: -3)
        }
        
        struct Root: Codable {
            struct TopicBlock: Codable {
                let topic: String
                let questions: [GeneratedQuestion]
            }
            let topics: [TopicBlock]
        }
        
        let root = try JSONDecoder().decode(Root.self, from: jsonData)
        
        var validatedTopics: [String: [GeneratedQuestion]] = [:]
        
        for topicBlock in root.topics {
            var validQuestions: [GeneratedQuestion] = []
            
            for question in topicBlock.questions {
                guard question.options.count == 4 else {
                    print("Question skipped: Wrong option count (\(question.options.count))")
                    continue
                }
                
                guard question.correctAnswerIndex >= 0 && question.correctAnswerIndex < 4 else {
                    print("Question skipped: Invalid answer index")
                    continue
                }
                
                if question.type == "textField" && question.correctAnswerIndex != 0 {
                    var fixedQuestion = question
                    fixedQuestion.correctAnswerIndex = 0
                    validQuestions.append(fixedQuestion)
                } else {
                    validQuestions.append(question)
                }
            }
            
            if !validQuestions.isEmpty {
                validatedTopics[topicBlock.topic] = validQuestions
            }
        }
        
        if validatedTopics.isEmpty {
            throw NSError(domain: "No valid questions generated", code: -4)
        }
        
        return validatedTopics
    }
    
    private func attemptPartialParse(_ data: Data) throws -> [String: [GeneratedQuestion]]? {
        return nil
    }
    
    // Fallback generator with difficulty support
    private func localFallbackTopics(count: Int, questionsPerTopic: Int) -> [String: [GeneratedQuestion]] {
        let sampleTopics = [
            "Core Concepts",
            "Key Principles",
            "Practical Applications",
            "Advanced Topics",
            "Review Questions",
            "Case Studies",
            "Theory & Practice",
            "Problem Solving"
        ]
        
        var dict: [String: [GeneratedQuestion]] = [:]
        
        for i in 0..<count {
            let topic = sampleTopics[i % sampleTopics.count]
            var questions: [GeneratedQuestion] = []
            
            for j in 1...questionsPerTopic {
                let isTextField = (j % 4 == 0)
                
                if isTextField {
                    questions.append(GeneratedQuestion(
                        question: getDifficultyAdjustedTextQuestion(topic: topic, number: j),
                        options: [
                            getDifficultyAdjustedAnswer(topic: topic),
                            "",
                            "",
                            ""
                        ],
                        correctAnswerIndex: 0,
                        type: "textField"
                    ))
                } else {
                    questions.append(GeneratedQuestion(
                        question: getDifficultyAdjustedMultipleChoiceQuestion(topic: topic, number: j),
                        options: [
                            "Option A: First statement about \(topic.lowercased())",
                            "Option B: Second statement about \(topic.lowercased())",
                            "Option C: Third statement about \(topic.lowercased())",
                            "Option D: Fourth statement about \(topic.lowercased())"
                        ],
                        correctAnswerIndex: Int.random(in: 0...3),
                        type: "multipleChoice"
                    ))
                }
            }
            
            dict[topic] = questions
        }
        
        return dict
    }
    
    private func getDifficultyAdjustedTextQuestion(topic: String, number: Int) -> String {
        switch currentDifficulty {
        case "Easy":
            return "Define or list key points about \(topic.lowercased()): (Question \(number))"
        case "Hard":
            return "Analyze and evaluate the implications of \(topic.lowercased()) in a complex scenario: (Question \(number))"
        default:
            return "Explain and apply the concepts of \(topic.lowercased()): (Question \(number))"
        }
    }
    
    private func getDifficultyAdjustedMultipleChoiceQuestion(topic: String, number: Int) -> String {
        switch currentDifficulty {
        case "Easy":
            return "What is \(topic.lowercased())? (Question \(number))"
        case "Hard":
            return "In a complex scenario involving \(topic.lowercased()), which approach would be most effective and why? (Question \(number))"
        default:
            return "Which of the following best describes \(topic.lowercased())? (Question \(number))"
        }
    }
    
    private func getDifficultyAdjustedAnswer(topic: String) -> String {
        switch currentDifficulty {
        case "Easy":
            return "A basic explanation of \(topic.lowercased()) covering main points"
        case "Hard":
            return "A comprehensive analysis of \(topic.lowercased()) with examples, implications, and edge cases"
        default:
            return "A comprehensive explanation of \(topic.lowercased()) covering main points and examples"
        }
    }
}
