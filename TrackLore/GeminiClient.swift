import Foundation

struct GeminiClient {
    static let shared = GeminiClient()

    private let apiKey = Secrets.geminiApiKey  // Store your Gemini key in Secrets.swift
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key="

    func ask(prompt: String) async throws -> String {
        let urlString = endpoint + apiKey
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.badResponse
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
        return decoded.candidates.first?.content.parts.first?.text ?? "No response"
    }

    enum GeminiError: Error {
        case invalidURL
        case badResponse
    }
}

struct GeminiResponse: Codable {
    struct Candidate: Codable {
        let content: Content
    }

    struct Content: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String
    }

    let candidates: [Candidate]
}