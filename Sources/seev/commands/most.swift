import ArgumentParser

@available(macOS 12.0, *)
struct Most: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Performs combined image analysis without generating embeddings.",
    discussion:
      "Runs the same independent operations as all, except full-image and per-face embeddings are omitted."
  )

  @Argument(help: "The filepath of the input image")
  var input: String

  mutating func run() throws {
    try runCombinedAnalysis(input: input, includeEmbeddings: false)
  }
}
