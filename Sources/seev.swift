import ArgumentParser
import Foundation

let VERSION = "1.8.1"

struct Options: ParsableArguments {
  @Argument(help: "The filepath of the input image")
  var input: String

  @Option(name: [.customShort("o"), .long], help: "The filepath of the output image")
  var output: String?
}

@available(macOS 15.0, *)
@main
struct seev: ParsableCommand {
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
      Poses.self,
      All.self,
      SHA1.self,
    ],
    defaultSubcommand: Subject.self
  )
}
