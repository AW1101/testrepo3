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
    private let timeout: TimeInterval = 60.0 // Increased timeout
    
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
        
        // Combine the exam brief + notes for context (still unsure about this, again i will rework it all later)
        let combinedInput = """
        EXAM BRIEF:
        \(examBrief.prefix(1500))

        NOTES:
        \(notes.joined(separator: "\n").prefix(1000))
        """
        
        // Simplified prompt for faster response
        let systemPrompt = """
        You are a quiz generator. Generate exactly \(topicsWanted) topics with EXACTLY \(questionsPerTopic) questions each.
        
        CRITICAL RULES:
        - EVERY question must have EXACTLY 4 options in the options array
        - For multipleChoice: all 4 options must be distinct answers
        - For textField: options[0] = the ONE correct answer (specific), options[1-3] = "" (empty strings)
        - correctAnswerIndex is ALWAYS 0 for textField questions
        - Mix 70% multipleChoice and 30% textField
        
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
        Generate \(topicsWanted) UNIQUE topics (avoid these: \(existingTopics.joined(separator: ", "))) with \(questionsPerTopic) questions based on:
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
            "max_tokens": 4000 // Limit response size
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Send request
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
            
            // Debug: Print raw response
            if let rawString = String(data: data, encoding: .utf8) {
                print("API Response (first 500 chars): \(rawString.prefix(500))")
            }
            
            do {
                let decoded = try self.decodeResponse(data)
                print("Successfully generated \(decoded.keys.count) topics")
                completion(.success(decoded))
            } catch {
                print("JSON parse failed: \(error.localizedDescription)")
                // Try to extract partial data
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
        
        // Clean the content (remove markdown code blocks if present)
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
        
        // VALIDATE (Ensure all topics have correct question count and format)
        var validatedTopics: [String: [GeneratedQuestion]] = [:]
        
        for topicBlock in root.topics {
            var validQuestions: [GeneratedQuestion] = []
            
            for question in topicBlock.questions {
                // Validate: Must have exactly 4 options
                guard question.options.count == 4 else {
                    print("Question skipped: Wrong option count (\(question.options.count))")
                    continue
                }
                
                // Validate: correctAnswerIndex must be 0-3
                guard question.correctAnswerIndex >= 0 && question.correctAnswerIndex < 4 else {
                    print("Question skipped: Invalid answer index")
                    continue
                }
                
                // Validate: textField questions must have correctAnswerIndex = 0
                if question.type == "textField" && question.correctAnswerIndex != 0 {
                    var fixedQuestion = question
                    fixedQuestion.correctAnswerIndex = 0
                    validQuestions.append(fixedQuestion)
                } else {
                    validQuestions.append(question)
                }
            }
            
            // Only include topic if it has questions
            if !validQuestions.isEmpty {
                validatedTopics[topicBlock.topic] = validQuestions
            }
        }
        
        // If we don't have enough topics/questions, throw error to trigger fallback
        if validatedTopics.isEmpty {
            throw NSError(domain: "No valid questions generated", code: -4)
        }
        
        return validatedTopics
    }
    
    private func attemptPartialParse(_ data: Data) throws -> [String: [GeneratedQuestion]]? {
        // Try to extract whatever possible from malformed response
        guard let jsonString = String(data: data, encoding: .utf8) else { return nil }
        
        // Look for topic blocks even if incomplete
        // This is still pretty simple, may not work for all cases
        return nil
    }
    
    // Fallback generator (may not be necessary, might have to rework this)
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
            
            // Generate exactly questionsPerTopic questions
            for j in 1...questionsPerTopic {
                let isTextField = (j % 4 == 0) // Every 4th question is text field 
                
                if isTextField {
                    questions.append(GeneratedQuestion(
                        question: "Define or explain this key concept from \(topic.lowercased()): (Question \(j))",
                        options: [
                            "A comprehensive explanation covering main points and examples",
                            "",
                            "",
                            ""
                        ],
                        correctAnswerIndex: 0,
                        type: "textField"
                    ))
                } else {
                    questions.append(GeneratedQuestion(
                        question: "Which of the following best describes \(topic.lowercased())? (Question \(j))",
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
}
