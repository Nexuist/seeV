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
    // let vnModel = try VNCoreMLModel(for: model.model)
    // Get a URL to the model
    let model = try OpenNSFW(
      contentsOf: Bundle.module.url(forResource: "OpenNSFW", withExtension: "mlmodelc")!,
      configuration: MLModelConfiguration())
  }
}
