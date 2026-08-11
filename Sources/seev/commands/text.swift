import ArgumentParser

@available(macOS 15.0, *)
struct Text: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Detects text in an image or representative video frames.",
    discussion:
      "The JSON output includes the bounding box, text, and confidence of each detected text. If an output path is provided, a PNG image with the bounding boxes drawn will be saved."
  )

  @OptionGroup var args: MediaOutputOptions

  @Option(
    name: [.customLong("custom-words")],
    parsing: .upToNextOption,
    help: "Custom words to use for text recognition"
  )
  var customWords: [String] = []

  mutating func run() async throws {
    try args.validateImageOutput()

    var result = try await analyzeMedia(
      input: args.input,
      maxFrames: args.maxFrames,
      operationName: "text"
    ) { input in
      try textAnalysis(input: input, customWords: customWords)
    }
    result.output["customWords"] = customWords
    printDict(result.output)

    if let text = result.imageArtifact, let output = args.output {
      draw(
        inputImagePath: args.input,
        outputImagePath: output,
        points: [],
        boxes: text.map(\.boundingBox),
        lines: []
      )
      printStatus("Saved bounding boxes to \(output)")
    }
  }
}
