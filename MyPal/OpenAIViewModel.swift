//
//  openAIUtils.swift
//  MyBuddy
//
//  Created by Chidume Nnamdi on 26/06/2025.
//

import Foundation
import FoundationModels

let YOUR_API_KEY = ""

class OpenAIViewModel: ObservableObject {
    
    @Published var loading = false;
    let coreDataUtils = CoreDataUtils.shared;
    static let shared = OpenAIViewModel()

    func callOpenAI(prompt: String, completion: @escaping (String?, URLResponse?, (any Error)?) -> Void) {
        loading = true;
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer " + YOUR_API_KEY, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: json)

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { DispatchQueue.main.async { self.loading = false } }

            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, nil, error)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, response, nil)
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                if let reply = decoded.choices.first?.message.content {
                    DispatchQueue.main.async {
                        self.coreDataUtils.insertResponse(reply: reply)
                        completion(reply, response, nil)
                    }
                } else {
                    print("❌ No choices returned from OpenAI.")
                    print(String(data: data, encoding: .utf8) ?? "❌ Unable to convert data to string")
                    DispatchQueue.main.async {
                        completion(nil, response, nil)
                    }
                }
            } catch {
                print("❌ Decoding error: \(error)")
                print(String(data: data, encoding: .utf8) ?? "❌ Unable to convert data to string")
                DispatchQueue.main.async {
                    completion(nil, response, error)
                }
            }
        }.resume()

        
    }
    
}


struct OpenAIResponse: Codable {
    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    let choices: [Choice]
}
