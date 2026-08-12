import ArgumentParser
import Foundation

let VERSION = "2.5.0"

private func positiveInteger(_ argument: String) throws -> Int {
  guard let value = Int(argument), value > 0 else {
    throw ValidationError("must be a positive integer")
  }
  return value
}

struct InputOptions: ParsableArguments {
  @Argument(help: "The filepath of the input file")
  var input: String
}

struct ImageOutputOptions: ParsableArguments {
  @Argument(help: "The filepath of the input image")
  var input: String

  @Option(name: [.customShort("o"), .long], help: "The filepath of the output image")
  var output: String?
}

struct MediaOptions: ParsableArguments {
  @Argument(help: "The filepath of the input image or video")
  var input: String

  @Option(
    name: [.customLong("max-frames")],
    help: "Maximum representative frames to analyze for video input.",
    transform: positiveInteger
  )
  var maxFrames = defaultMaxFrames
}

struct MediaOutputOptions: ParsableArguments {
  @OptionGroup var media: MediaOptions

  @Option(name: [.customShort("o"), .long], help: "The filepath of the output image")
  var output: String?

  var input: String { media.input }
  var maxFrames: Int { media.maxFrames }

  func validateImageOutput(cropped: Bool = false) throws {
    if isVideoInput(input), output != nil || cropped {
      throw VideoInputError.imageOutputUnsupported
    }
    if cropped, output == nil {
      throw ValidationError("--cropped requires --output.")
    }
  }
}

@available(macOS 15.0, *)
@main
struct seev: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "A command line wrapper over Apple's Vision framework.",
    version: VERSION,
    subcommands: [
      Subject.self,
      Faces.self,
      Humans.self,
      Text.self,
      Embeddings.self,
      Distance.self,
      Classify.self,
      Quality.self,
      Poses.self,
      All.self,
      Most.self,
      SHA1.self,
      NSFW.self,
    ],
    defaultSubcommand: Subject.self
  )
}
