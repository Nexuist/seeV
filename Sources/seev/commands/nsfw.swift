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
      // Handle model results
      let request = VNCoreMLRequest(model: vnModel) { request, error in
        if let error = error {
          print("Error: \(error)")
          return
        }
        guard let results = request.results as? [VNClassificationObservation] else {
          print("No results")
          return
        }
        for result in results {
          print("\(result.identifier): \(result.confidence)")
        }
      }
      // Run the model
      try handler.perform([request])
    } catch {
      print("Error: \(error)")
    }
  }
}
