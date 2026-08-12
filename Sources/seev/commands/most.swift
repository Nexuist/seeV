import ArgumentParser

@available(macOS 15.0, *)
struct Most: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract:
      "Performs combined analysis on an image or representative video frames without embeddings or NSFW classification.",
    discussion:
      "Runs faces, humans, text, poses, classification, quality, and SHA-1 without requiring Ollama."
  )

  @OptionGroup var args: MediaOptions

  mutating func run() async throws {
    try await runCombinedMediaAnalysis(
      input: args.input,
      maxFrames: args.maxFrames,
      includeEmbeddings: false
    )
  }
}
