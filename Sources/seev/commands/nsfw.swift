import ArgumentParser
import Foundation

@available(macOS 12.0, *)
struct NSFW: AsyncParsableCommand {
  static var configuration: CommandConfiguration = CommandConfiguration(
    abstract: "Checks whether an image is NSFW using ShieldGemma through Ollama."
  )

  @Argument(help: "The filepath of the input image")
  var input: String

  @Option(
    name: [.customLong("ollama-host")],
    help: "Base URL of the Ollama service."
  )
  var ollamaHost = ShieldGemmaNSFWClassifier.defaultHost

  mutating func run() async throws {
    let classifier = try ShieldGemmaNSFWClassifier(host: ollamaHost)
    let violation = try await classifier.isNSFW(imageAt: inputImagePathToURL(input))

    printDict([
      "input": input,
      "model": ShieldGemmaNSFWClassifier.model,
      "policy": ShieldGemmaNSFWClassifier.policyName,
      "violation": violation,
    ])
  }
}
