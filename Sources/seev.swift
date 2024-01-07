import ArgumentParser

struct Options: ParsableArguments {
  @Argument(help: "The filepath of the input image")
  var input: String

  @Option(name: [.customShort("o"), .long], help: "The filepath of the output image")
  var output = "output.png"

  @Flag(name: [.customShort("c"), .long], help: "Crop the output to the subject's bounding box")
  var cropped: Bool = false

  @Flag(name: [.long], help: "Write output to stdout")
  var stdout: Bool = false
}

enum SeeVError: Error {
  case noSubjectFound
  case invalidCVPixelBuffer(Int32)
  case outputError
}

@available(macOS 14.0, *)
@main
struct seev: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "A command line wrapper over Apple's Vision framework.",
    version: "1.0.2",
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
        let output = try extractSubject(inputImagePath: args.input, cropped: args.cropped)
        if args.stdout {
          try writeOutput(output: output)
        } else {
          saveOutput(output: output, outputImagePath: args.output)
          print("Saved to \(args.output)")
        }
      } catch {
        print("Error: \(error)")
        return
      }
    }
  }
}
