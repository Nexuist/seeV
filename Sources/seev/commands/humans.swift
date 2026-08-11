import ArgumentParser

@available(macOS 15.0, *)
struct Humans: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Detects humans in an image or representative video frames.",
    discussion:
      "The JSON output includes the bounding box and confidence of each human. If an output path is provided, a PNG image with the bounding boxes drawn will be saved."
  )

  @OptionGroup var args: MediaOutputOptions

  mutating func run() async throws {
    try args.validateImageOutput()

    let result = try await analyzeMedia(
      input: args.input,
      maxFrames: args.maxFrames,
      operationName: "humans",
      analysis: humanAnalysis
    )
    printDict(result.output)

    if let humans = result.imageArtifact, let output = args.output {
      draw(
        inputImagePath: args.input,
        outputImagePath: output,
        points: [],
        boxes: humans.map(\.boundingBox),
        lines: []
      )
      printStatus("Saved bounding boxes to \(output)")
    }
  }
}
