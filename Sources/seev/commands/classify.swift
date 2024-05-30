import ArgumentParser
import Foundation
import Vision

@available(macOS 10.15, *)
struct Classify: ParsableCommand {
  static var configuration: CommandConfiguration = CommandConfiguration(
    abstract: "Classify an image using a Core ML model.",
    discussion: "A list of classifications and their confidence levels."
  )

  @OptionGroup() var args: Options
  @Option(name: .shortAndLong, help: "Minimum confidence for predictions.")
  var minimumConfidence: Float = 0.4
  @Option(
    name: .shortAndLong,
    parsing: .upToNextOption,
    help: "Identifiers to include even if they don't meet the minimum confidence.")
  var includeIdentifiers: [String] = []

  mutating func run() {
    do {
      let classifications: [VNClassificationObservation] = try performRequest(
        request: VNClassifyImageRequest(),
        inputImagePath: args.input
      )
      let filteredClassifications = classifications.filter { $0.confidence >= minimumConfidence }
      var classificiationsDict: [String: Any] = [
        "input": args.input,
        "classifications": filteredClassifications.map { classification in
          [
            "identifier": classification.identifier,
            "confidence": classification.confidence,
          ]
        },
      ]
      for identifier in includeIdentifiers {
        if !filteredClassifications.contains(where: { $0.identifier == identifier }) {
          var mutableClassifications = classificiationsDict["classifications"] as! [[String: Any]]
          mutableClassifications.append([
            "identifier": identifier,
            "confidence": classifications.first(where: { $0.identifier == identifier })?.confidence
              ?? 0,
          ])
          classificiationsDict["classifications"] = mutableClassifications
        }
      }
      printDict(classificiationsDict)

    } catch {
      print("Error: \(error)")
    }
  }

}
