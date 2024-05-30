import ArgumentParser
import Foundation
import SensitiveContentAnalysis
import Vision

@available(macOS 14.0, *)
struct NSFW: AsyncParsableCommand {
  static var configuration: CommandConfiguration = CommandConfiguration(
    abstract: "Uses Yahoo's OpenNSFW model to detect NSFW content in an image."
  )

  @OptionGroup() var args: Options

  mutating func run() async throws {
    do {
      // Load the model
      let model = try OpenNSFW(
        contentsOf: Bundle.module.url(forResource: "OpenNSFW", withExtension: "mlmodelc")!,
        configuration: MLModelConfiguration()
      )
      let vnModel = try VNCoreMLModel(for: model.model)
      let handler = VNImageRequestHandler(url: inputImagePathToURL(args.input))
      let request = VNCoreMLRequest(model: vnModel)
      // Run the model
      try handler.perform([request])
      guard let results = request.results as? [VNClassificationObservation] else {
        return printDict([
          "input": args.input
        ])
      }
      printDict([
        "input": args.input,
        "nsfw": results[0].confidence,
        "sfw": results[1].confidence,
      ])
    } catch {
      print("Error: \(error)")
    }
  }
}
