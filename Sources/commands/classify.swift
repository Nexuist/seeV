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
      let classifications = try classifyImage(inputImagePath: args.input)
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
      print(includeIdentifiers)
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
      let jsonData = try JSONSerialization.data(
        withJSONObject: classificiationsDict, options: .prettyPrinted)
      print(String(data: jsonData, encoding: .utf8)!)

    } catch {
      print("Error: \(error)")
    }
  }

}

@available(macOS 10.15, *)
func classifyImage(inputImagePath: String) throws -> [VNClassificationObservation] {
  let inputURL = inputImagePathToURL(inputImagePath)
  let request = VNClassifyImageRequest()
  let handler = VNImageRequestHandler(url: inputURL)
  try handler.perform([request])
  guard let result = request.results else {
    return []
  }
  return result

}
