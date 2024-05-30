import ArgumentParser
import Foundation
import Vision

@available(macOS 15.0, *)
struct Text: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Detects text in an image and returns the results as JSON.",
    discussion:
      "The JSON output includes the bounding box, text, and confidence of each detected text. If an output path is provided, a PNG image with the bounding boxes drawn will be saved."
  )

  @OptionGroup() var args: Options
  @Option(
    name: [.customLong("custom-words")],
    parsing: .upToNextOption,
    help: "Custom words to use for text recognition")
  var customWords: [String] = []

  mutating func run() {
    do {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      request.customWords = customWords
      let text: [VNRecognizedTextObservation] = try performRequest(
        request: request,
        inputImagePath: args.input
      )
      printDict([
        "input": args.input,
        "customWords": customWords,
        "text": text.map { text in
          return [
            "boundingBox": [
              "x": text.boundingBox.origin.x,
              "y": text.boundingBox.origin.y,
              "width": text.boundingBox.width,
              "height": text.boundingBox.height,
            ],
            "text": text.topCandidates(1).first?.string ?? "Failed to recognize text",
            "confidence": text.confidence,
          ] as [String: Any]
        },
      ])
      if args.output != nil {
        draw(
          inputImagePath: args.input,
          outputImagePath: args.output!,
          points: [],
          boxes: text.map(\.boundingBox),
          lines: []
        )
        print("Saved bounding boxes to \(args.output!)")
      }
    } catch {
      print("Error: \(error)")
    }
  }
}
