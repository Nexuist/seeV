import ArgumentParser
import Foundation

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
  case invalidURL
}

@available(macOS 14.0, *)
@main
struct seev: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "A command line wrapper over Apple's Vision framework.",
    version: "1.1.1",
    subcommands: [Subject.self, Faces.self],
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
      }
    }
  }

  struct Faces: ParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Detects faces in an image and returns the results as JSON.",
      discussion:
        "The JSON output includes the roll, yaw, pitch, bounding box, and confidence of each face. If an output path is provided, a PNG image with the bounding boxes drawn will be saved."

    )

    @OptionGroup() var args: Options

    mutating func run() {
      do {
        let faces = try extractFaces(inputImagePath: args.input)
        let faceDict: [String: Any] = [
          "input": args.input,
          "faces": faces.map { face in
            return [
              "roll": face.roll ?? 0,
              "yaw": face.yaw ?? 0,
              "pitch": face.pitch ?? 0,
              "boundingBox": [
                "x": face.boundingBox.origin.x,
                "y": face.boundingBox.origin.y,
                "width": face.boundingBox.width,
                "height": face.boundingBox.height,
              ],
              "confidence": face.confidence,
            ] as [String: Any]
          },
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: faceDict, options: .prettyPrinted)
        print(String(data: jsonData, encoding: .utf8)!)
        if !args.stdout {
          writeBoundingBoxes(inputImagePath: args.input, outputImagePath: args.output, faces: faces)
          print("Saved bounding boxes to \(args.output)")
        }
      } catch {
        print("Error: \(error)")
      }
    }
  }
}
