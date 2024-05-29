import ArgumentParser
import Foundation
import Vision

@available(macOS 12.0, *)
struct Humans: ParsableCommand {

  static var configuration = CommandConfiguration(
    abstract: "Detects humans in an image and returns the results as JSON.",
    discussion:
      "The JSON output includes the bounding box and confidence of each human. If an output path is provided, a PNG image with the bounding boxes drawn will be saved."
  )

  @OptionGroup() var args: Options

  mutating func run() {
    do {
      let humans: [VNHumanObservation] = try performRequest(
        request: VNDetectHumanRectanglesRequest(),
        inputImagePath: args.input
      )
      printDict([
        "input": args.input,
        "humans": humans.map { human in
          return [
            "boundingBox": [
              "x": human.boundingBox.origin.x,
              "y": human.boundingBox.origin.y,
              "width": human.boundingBox.width,
              "height": human.boundingBox.height,
            ],
            "confidence": human.confidence,
          ] as [String: Any]
        },
      ])
      if args.output != nil {
        draw(
          inputImagePath: args.input,
          outputImagePath: args.output!,
          points: [],
          boxes: humans.map(\.boundingBox),
          lines: []
        )
        print("Saved bounding boxes to \(args.output!)")
      }
    } catch {
      print("Error: \(error)")
    }
  }
}
