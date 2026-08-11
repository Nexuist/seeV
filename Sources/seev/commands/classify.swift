import ArgumentParser

@available(macOS 15.0, *)
struct Classify: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Classifies an image or representative video frames using Vision.",
    discussion: "A list of classifications and their confidence levels."
  )

  @OptionGroup var args: MediaOptions

  @Option(name: .shortAndLong, help: "Minimum confidence for predictions.")
  var minimumConfidence: Float = 0.4

  @Option(
    name: .shortAndLong,
    parsing: .upToNextOption,
    help: "Identifiers to include even if they don't meet the minimum confidence."
  )
  var includeIdentifiers: [String] = []

  mutating func run() async throws {
    let result = try await analyzeMedia(
      input: args.input,
      maxFrames: args.maxFrames,
      operationName: "classifications"
    ) { input in
      try classificationAnalysis(
        input: input,
        minimumConfidence: minimumConfidence,
        includeIdentifiers: includeIdentifiers
      )
    }
    printDict(result.output)
  }
}
