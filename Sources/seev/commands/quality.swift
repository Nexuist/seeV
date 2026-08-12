import ArgumentParser

@available(macOS 15.0, *)
struct Quality: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Scores the aesthetic quality of an image or representative video frames."
  )

  @OptionGroup var args: MediaOptions

  mutating func run() async throws {
    let result = try await analyzeMedia(
      input: args.input,
      maxFrames: args.maxFrames,
      operationName: "quality",
      analysis: qualityAnalysis
    )
    printDict(result.output)
  }
}
