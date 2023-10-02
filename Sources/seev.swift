import ArgumentParser

struct Options: ParsableArguments {
  @Argument(help: "The filepath of the input image")
  var input: String

  @Option(name: [.customShort("o"), .long], help: "The filepath of the output image")
  var output = "output.png"
}

enum SeeVError: Error {
  case noSubjectFound
  case invalidCVPixelBuffer(Int32)
}

@available(macOS 14.0, *)
@main
struct seev: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "A command line wrapper over Apple's Vision framework.",
    version: "1.0.0",
    subcommands: [Subject.self],
    defaultSubcommand: Subject.self
  )

  struct Subject: ParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Removes the background from an image."
    )

    @OptionGroup() var args: Options

    mutating func run() {
      do {
        print("Removing background from \(args.input)...")
        try extractSubject(inputImagePath: args.input, outputImagePath: args.output)
        print("Saved to \(args.output)")
      } catch {
        print("Error: \(error)")
        return
      }
    }
  }
}
