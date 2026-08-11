import ArgumentParser

@available(macOS 12.0, *)
struct Most: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Performs combined image analysis without embeddings or NSFW classification.",
    discussion:
      "Runs faces, humans, text, poses, classification, and SHA-1 without requiring Ollama."
  )

  @Argument(help: "The filepath of the input image")
  var input: String

  mutating func run() async throws {
    try await runCombinedAnalysis(input: input, includeEmbeddings: false, ollamaHost: nil)
  }
}
