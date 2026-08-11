import ArgumentParser

@available(macOS 15.0, *)
struct All: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Performs all operations on an image or representative video frames.",
    discussion:
      "Successful operations are returned even when another operation fails. Failures are included in the errors object."
  )

  @OptionGroup var args: MediaOptions

  @Option(
    name: [.customLong("ollama-host")],
    help: "Base URL of the Ollama service used for NSFW classification."
  )
  var ollamaHost = ShieldGemmaNSFWClassifier.defaultHost

  mutating func run() async throws {
    var classifier: ShieldGemmaNSFWClassifier?
    var nsfwSetupError: String?
    do {
      classifier = try ShieldGemmaNSFWClassifier(host: ollamaHost)
    } catch {
      nsfwSetupError = error.localizedDescription
    }

    try await runCombinedMediaAnalysis(
      input: args.input,
      maxFrames: args.maxFrames,
      includeEmbeddings: true,
      nsfwClassifier: classifier,
      nsfwSetupError: nsfwSetupError
    )
  }
}
