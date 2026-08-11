import ArgumentParser

@available(macOS 15.0, *)
struct NSFW: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract:
      "Checks whether an image or representative video frames are NSFW using ShieldGemma through Ollama."
  )

  @OptionGroup var args: MediaOptions

  @Option(
    name: [.customLong("ollama-host")],
    help: "Base URL of the Ollama service."
  )
  var ollamaHost = ShieldGemmaNSFWClassifier.defaultHost

  mutating func run() async throws {
    let classifier = try ShieldGemmaNSFWClassifier(host: ollamaHost)
    let result = try await analyzeMedia(
      input: args.input,
      maxFrames: args.maxFrames,
      operationName: "nsfw"
    ) { input in
      FrameAnalysisResult(output: [
        "nsfw": try await input.isNSFW(using: classifier)
      ])
    }
    if let nsfw = result.output["nsfw"] {
      printJSON(nsfw)
    } else {
      printDict(result.output)
    }
  }
}
