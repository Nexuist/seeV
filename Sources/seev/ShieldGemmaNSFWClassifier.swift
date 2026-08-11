import Foundation

enum NSFWClassifierError: LocalizedError {
  case modelNotInstalled(String)
  case ollamaUnavailable(String)
  case unknown(String)

  var errorDescription: String? {
    switch self {
    case .modelNotInstalled(let model):
      return
        "Ollama model '\(model)' is not installed. Install it with 'ollama pull \(model)'."
    case .ollamaUnavailable(let reason):
      return "Ollama is unavailable: \(reason)"
    case .unknown(let reason):
      return "Unknown NSFW classification error: \(reason)"
    }
  }
}

@available(macOS 12.0, *)
struct ShieldGemmaNSFWClassifier {
  static let defaultHost = "http://127.0.0.1:11434"
  static let model = "hf.co/infil00p/shieldgemma-2-4b-it-GGUF:Q4_K_M"
  static let policyName = "nsfw"

  private static let prompt = """
    Review the image using only this policy:

    <BEGIN_SAFETY_POLICY>
    Flag the image if it contains nudity or visible intimate body parts, including nipples, genitals, or \
    uncovered buttocks. Also flag clearly erotic posing or presentation. Apply this policy to photographs, \
    artwork, and illustrations.
    </END_SAFETY_POLICY>

    Does the image violate the policy? Answer exactly 'Yes' or 'No'.
    """

  private struct GenerateRequest: Encodable {
    private struct Options: Encodable {
      let temperature = 0
      let numPredict = 4

      enum CodingKeys: String, CodingKey {
        case temperature
        case numPredict = "num_predict"
      }
    }

    let model: String
    let prompt: String
    let images: [String]
    let stream = false
    private let options = Options()
  }

  private struct GenerateResponse: Decodable {
    let response: String
  }

  private struct ErrorResponse: Decodable {
    let error: String
  }

  private let baseURL: URL
  private let session: URLSession

  init(host: String = defaultHost, session: URLSession = .shared) throws {
    guard
      let url = URL(string: host),
      let scheme = url.scheme?.lowercased(),
      ["http", "https"].contains(scheme),
      url.host != nil
    else {
      throw NSFWClassifierError.ollamaUnavailable(
        "Invalid host '\(host)'. Use an http or https URL."
      )
    }

    self.baseURL = url
    self.session = session
  }

  func isNSFW(imageAt imageURL: URL) async throws -> Bool {
    let imageData: Data
    do {
      imageData = try Data(contentsOf: imageURL)
    } catch {
      throw NSFWClassifierError.unknown("Could not read the image: \(error.localizedDescription)")
    }

    let payload = GenerateRequest(
      model: Self.model,
      prompt: Self.prompt,
      images: [imageData.base64EncodedString()]
    )
    var request = URLRequest(url: endpoint("api/generate"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    do {
      request.httpBody = try JSONEncoder().encode(payload)
    } catch {
      throw NSFWClassifierError.unknown(
        "Could not prepare the Ollama request: \(error.localizedDescription)"
      )
    }
    request.timeoutInterval = 300

    let data = try await send(request)
    let response: GenerateResponse
    do {
      response = try JSONDecoder().decode(GenerateResponse.self, from: data)
    } catch {
      throw NSFWClassifierError.unknown(
        "Ollama returned an invalid response: \(error.localizedDescription)"
      )
    }
    return try Self.parse(response.response)
  }

  private static func parse(_ response: String) throws -> Bool {
    switch response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "yes":
      return true
    case "no":
      return false
    default:
      throw NSFWClassifierError.unknown(
        "ShieldGemma returned '\(response)' instead of exactly 'Yes' or 'No'."
      )
    }
  }

  private func endpoint(_ path: String) -> URL {
    baseURL.appendingPathComponent(path)
  }

  private func send(_ request: URLRequest) async throws -> Data {
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw NSFWClassifierError.ollamaUnavailable(
        "Could not reach \(baseURL.absoluteString): \(error.localizedDescription). Start it with 'ollama serve'."
      )
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw NSFWClassifierError.unknown("Ollama returned a non-HTTP response.")
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      if httpResponse.statusCode == 404 {
        throw NSFWClassifierError.modelNotInstalled(Self.model)
      }

      let message =
        (try? JSONDecoder().decode(ErrorResponse.self, from: data).error)
        ?? String(data: data, encoding: .utf8)
        ?? "No response body"
      throw NSFWClassifierError.unknown(
        "Ollama returned HTTP \(httpResponse.statusCode): \(message)"
      )
    }
    return data
  }
}
