//
//  AIQuestionGenerator.swift
//  RETHINKA
//
//  Created by Aston Walsh on 15/10/2025.
//

import Foundation

struct GeneratedQuestion: Codable {
    let question: String
    let options: [String]
    let correctAnswerIndex: Int
    let type: String // "multipleChoice" or "textField"
}

final class AIQuestionGenerator {
    static let shared = AIQuestionGenerator()

    private let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]

    // MARK: - Main generator
    func generateTopicQuizzes(
        examBrief: String,
        notes: [String],
        topicsWanted: Int = 3,
        questionsPerTopic: Int = 3,
        completion: @escaping (Result<[String: [GeneratedQuestion]], Error>) -> Void
    ) {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("⚠️ No API key found. Using fallback.")
            completion(.success(localFallbackTopics()))
            return
        }

        // Combine the exam brief + notes for context
        let combinedInput = """
        EXAM BRIEF:
        \(examBrief)

        NOTES:
        \(notes.joined(separator: "\n"))
        """

        // Create system & user prompts for structured JSON output
        let systemPrompt = """
        You are an intelligent question generator for university exams.
        You must identify the key topics in the provided text, research those topics conceptually,
        and then create high-quality quiz questions about them.

        Output MUST be in pure JSON format with this structure:
        {
          "topics": [
            {
              "topic": "Topic Name",
              "questions": [
                {
                  "question": "Question text",
                  "options": ["Option 1", "Option 2", "Option 3", "Option 4"],
                  "correctAnswerIndex": 2,
                  "type": "multipleChoice" or "textField"
                }
              ]
            }
          ]
        }

        - Some questions MUST use "textField" type instead of multiple choice.
        - Avoid trivial or obvious questions.
        - Ensure all JSON syntax is valid.
        - DO NOT include explanations or any non-JSON text.
        """

        let userPrompt = """
        Please generate \(topicsWanted) distinct topics with \(questionsPerTopic) questions each
        based on the following exam material:
        \(combinedInput)
        """

        // Build request
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.7
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }

            do {
                // Parse JSON safely from model response
                let decoded = try self.decodeResponse(data)
                completion(.success(decoded))
            } catch {
                print("❌ LLM JSON parse failed: \(error.localizedDescription). Falling back.")
                completion(.success(self.localFallbackTopics()))
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
        guard let jsonString = decoded.choices.first?.message.content.data(using: .utf8) else {
            throw NSError(domain: "Missing content", code: -2)
        }

        struct Root: Codable {
            struct TopicBlock: Codable {
                let topic: String
                let questions: [GeneratedQuestion]
            }
            let topics: [TopicBlock]
        }

        let root = try JSONDecoder().decode(Root.self, from: jsonString)
        return Dictionary(uniqueKeysWithValues: root.topics.map { ($0.topic, $0.questions) })
    }

    // MARK: - Fallback generator
    private func localFallbackTopics() -> [String: [GeneratedQuestion]] {
        let sampleTopics = ["Study Skills", "Exam Strategy", "Revision Techniques"]
        var dict: [String: [GeneratedQuestion]] = [:]
        for topic in sampleTopics {
            let qs = (1...3).map { i in
                GeneratedQuestion(
                    question: "Describe one key idea about \(topic.lowercased()) (\(i)).",
                    options: ["", "", "", ""],
                    correctAnswerIndex: 0,
                    type: "textField"
                )
            }
            dict[topic] = qs
        }
        return dict
    }
}
