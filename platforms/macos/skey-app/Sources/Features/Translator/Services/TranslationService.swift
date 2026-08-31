import AppKit
import Foundation

// MARK: - Translation Result

public struct TranslationResult: Equatable {
    public let originalText: String
    public let translatedText: String
    public let engineUsed: TranslationEngineType
    public let latencyMs: Double
    public let sourceLanguage: String
    public let targetLanguage: String

    public init(
        originalText: String,
        translatedText: String,
        engineUsed: TranslationEngineType,
        latencyMs: Double,
        sourceLanguage: String = "auto",
        targetLanguage: String = "vi"
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.engineUsed = engineUsed
        self.latencyMs = latencyMs
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

// MARK: - Translation Service

public final class TranslationService: ObservableObject {
    public static let shared = TranslationService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Cascade Translation

    /// Translates text using the user's configured priority list of engines.
    /// Falls back to the next available engine in priority order if an engine fails.
    public func translate(
        text: String,
        from sourceLang: String = "auto",
        to targetLang: String = "vi"
    ) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TranslationResult(
                originalText: text,
                translatedText: "",
                engineUsed: .google,
                latencyMs: 0,
                sourceLanguage: sourceLang,
                targetLanguage: targetLang
            )
        }

        let orderedEngines = AppSettings.shared.translator.engines.filter { $0.isEnabled }
        var lastError: Error?

        for engineConfig in orderedEngines {
            let start = DispatchTime.now()
            do {
                let translated: String
                switch engineConfig.type {
                case .google:
                    translated = try await translateWithGoogle(text: trimmed, from: sourceLang, to: targetLang)

                case .gemini:
                    guard !engineConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        continue // Skip if no API key configured
                    }
                    translated = try await translateWithGemini(
                        text: trimmed,
                        apiKey: engineConfig.apiKey,
                        from: sourceLang,
                        to: targetLang
                    )

                case .deepl:
                    guard !engineConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        continue // Skip if no API key configured
                    }
                    translated = try await translateWithDeepL(
                        text: trimmed,
                        apiKey: engineConfig.apiKey,
                        from: sourceLang,
                        to: targetLang
                    )

                case .groq:
                    guard !engineConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        continue // Skip if no API key configured
                    }
                    translated = try await translateWithGroq(
                        text: trimmed,
                        apiKey: engineConfig.apiKey,
                        from: sourceLang,
                        to: targetLang
                    )

                case .apple:
                    // Fallback to Google if running below macOS 15 or in background tap
                    translated = try await translateWithGoogle(text: trimmed, from: sourceLang, to: targetLang)
                }

                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
                return TranslationResult(
                    originalText: trimmed,
                    translatedText: translated,
                    engineUsed: engineConfig.type,
                    latencyMs: elapsed,
                    sourceLanguage: sourceLang,
                    targetLanguage: targetLang
                )
            } catch {
                lastError = error
                // Proceed to next engine in priority list
            }
        }

        // Fallback: If all configured engines failed, attempt Google NMT as universal safety net
        let fallbackStart = DispatchTime.now()
        do {
            let fallbackResult = try await translateWithGoogle(text: trimmed, from: sourceLang, to: targetLang)
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - fallbackStart.uptimeNanoseconds) / 1_000_000.0
            return TranslationResult(
                originalText: trimmed,
                translatedText: fallbackResult,
                engineUsed: .google,
                latencyMs: elapsed,
                sourceLanguage: sourceLang,
                targetLanguage: targetLang
            )
        } catch {
            throw lastError ?? error
        }
    }

    // MARK: - Engine 1: Google Mobile NMT (100% Free, Zero Key, Robust)

    private func translateWithGoogle(text: String, from source: String, to target: String) async throws -> String {
        var components = URLComponents(string: "https://translate.google.com/m")!
        components.queryItems = [
            URLQueryItem(name: "sl", value: source),
            URLQueryItem(name: "tl", value: target),
            URLQueryItem(name: "q", value: text)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        if let range1 = html.range(of: "class=\"result-container\">"),
           let range2 = html[range1.upperBound...].range(of: "</div>") {
            let extracted = String(html[range1.upperBound..<range2.lowerBound])
            return decodeHTMLEntities(extracted)
        }

        throw URLError(.cannotParseResponse)
    }

    // MARK: - Engine 2: DeepL API

    private func translateWithDeepL(text: String, apiKey: String, from source: String, to target: String) async throws -> String {
        let isFreeEndpoint = apiKey.hasSuffix(":fx")
        let host = isFreeEndpoint ? "https://api-free.deepl.com" : "https://api.deepl.com"
        guard let url = URL(string: "\(host)/v2/translate") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyParams: [String] = [
            "text=\(text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")",
            "target_lang=\(target.uppercased())"
        ]
        if source != "auto" {
            bodyParams.append("source_lang=\(source.uppercased())")
        }
        request.httpBody = bodyParams.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let translations = json["translations"] as? [[String: Any]],
           let first = translations.first,
           let translated = first["text"] as? String {
            return translated
        }

        throw URLError(.cannotParseResponse)
    }

    // MARK: - Engine 3: Google Gemini 2.0 Flash AI

    private func translateWithGemini(text: String, apiKey: String, from source: String, to target: String) async throws -> String {
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let targetName = target == "vi" ? "Vietnamese" : (target == "en" ? "English" : target)
        let prompt = "Translate the following text accurately and naturally into \(targetName). Output ONLY the translated text without explanations, quotes, or markdown code blocks:\n\n\(text)"

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let textResult = firstPart["text"] as? String {
            return textResult.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw URLError(.cannotParseResponse)
    }

    // MARK: - Engine 4: Groq Llama 3.3 AI

    private func translateWithGroq(text: String, apiKey: String, from source: String, to target: String) async throws -> String {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let targetName = target == "vi" ? "Vietnamese" : (target == "en" ? "English" : target)
        let systemPrompt = "You are an expert translator. Translate input text accurately and naturally into \(targetName). Return only the raw translation result."

        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.2
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw URLError(.cannotParseResponse)
    }

    // MARK: - Helper HTML Entity Decoder

    private func decodeHTMLEntities(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
