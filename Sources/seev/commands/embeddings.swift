import ArgumentParser

@available(macOS 15.0, *)
struct Embeddings: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Extracts embeddings from an image or representative video frames.",
    discussion: "The JSON output includes the embeddings of the analyzed input."
  )

  @OptionGroup var args: MediaOptions

  mutating func run() async throws {
    let result = try await analyzeMedia(
      input: args.input,
      maxFrames: args.maxFrames,
      operationName: "embedding",
      analysis: embeddingAnalysis
    )
    printDict(result.output)
  }
}
