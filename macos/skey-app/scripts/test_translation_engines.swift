import Foundation

let emailText = """
Dear Team, Following up on our discussion yesterday regarding the Q3 product roadmap, I would like to propose a slight adjustment to the delivery schedule. We should prioritize the core engine stability and cross-platform compatibility before rolling out the AI assistant features to beta users.
"""

func testGoogleMobile(text: String) async -> (timeMs: Double, result: String?) {
    let start = DispatchTime.now()
    var components = URLComponents(string: "https://translate.google.com/m")!
    components.queryItems = [
        URLQueryItem(name: "sl", value: "auto"),
        URLQueryItem(name: "tl", value: "vi"),
        URLQueryItem(name: "q", value: text)
    ]

    guard let url = components.url else { return (0, nil) }

    var request = URLRequest(url: url)
    request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 10

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
        
        if let html = String(data: data, encoding: .utf8) {
            if let range1 = html.range(of: "class=\"result-container\">"),
               let range2 = html[range1.upperBound...].range(of: "</div>") {
                let extracted = String(html[range1.upperBound..<range2.lowerBound])
                let decoded = extracted
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                return (elapsed, decoded)
            }
        }
    } catch {
        print("Error: \(error)")
    }
    return (0, nil)
}

Task {
    print("TEST 2: EMAIL / KINH DOANH")
    let res = await testGoogleMobile(text: emailText)
    print("Latency: \(String(format: "%.1f", res.timeMs)) ms")
    print("Result:\n\(res.result ?? "[Failed]")")
    exit(0)
}

dispatchMain()
