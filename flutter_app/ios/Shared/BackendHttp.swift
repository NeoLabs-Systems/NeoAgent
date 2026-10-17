import Foundation

/// Plain HTTP to the NeoAgent backend for native background work.
enum BackendHttp {
  struct Response {
    let code: Int
    let body: Data
  }

  static func request(
    _ method: String,
    baseUrl: String,
    path: String,
    cookie: String? = nil,
    json: Data? = nil
  ) async throws -> Response {
    guard let base = URL(string: baseUrl.trimmingCharacters(in: .whitespaces)),
          let url = URL(string: path, relativeTo: base)
    else { throw URLError(.badURL) }
    var request = URLRequest(url: url, timeoutInterval: 20)
    request.httpMethod = method
    // The app's session cookie is the only sign-in; stored cookies stay out.
    request.httpShouldHandleCookies = false
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let cookie, !cookie.isEmpty {
      request.setValue(cookie, forHTTPHeaderField: "Cookie")
    }
    if let json {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = json
    }
    let (body, response) = try await URLSession.shared.data(for: request)
    return Response(code: (response as? HTTPURLResponse)?.statusCode ?? 0, body: body)
  }
}
