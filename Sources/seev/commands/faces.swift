import ArgumentParser
import Vision

@available(macOS 15.0, *)
struct Faces: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Detects faces in an image or representative video frames.",
    discussion:
      "The JSON output includes the roll, yaw, pitch, bounding box, and confidence of each face. If an output path is provided, a PNG image with the bounding boxes drawn will be saved."
  )

  @OptionGroup var args: MediaOutputOptions

  @Flag(
    name: [.customShort("c"), .long],
    help: "Crop the output to the largest face bounding box found"
  )
  var cropped = false

  @Flag(
    name: [.customShort("e"), .long],
    help: "Generate embeddings for each cropped face"
  )
  var embeddings = false

  mutating func run() async throws {
    try args.validateImageOutput(cropped: cropped)

    let result = try await analyzeMedia(
      input: args.input,
      maxFrames: args.maxFrames,
      operationName: "faces"
    ) { input in
      try faceAnalysis(input: input, includeEmbeddings: embeddings)
    }
    printDict(result.output)

    guard let artifact = result.imageArtifact else {
      return
    }
    if cropped {
      guard
        let largestFace = artifact.observations.max(by: {
          $0.boundingBox.width * $0.boundingBox.height
            < $1.boundingBox.width * $1.boundingBox.height
        })
      else {
        throw SeeVError.noSubjectFound
      }
      let output = try cropImage(
        inputImagePath: args.input,
        boundingBox: largestFace.boundingBox
      )
      saveOutput(output: output, outputImagePath: args.output!)
      printStatus("Saved cropped image to \(args.output!)")
    } else if let output = args.output {
      draw(
        inputImagePath: args.input,
        outputImagePath: output,
        points: [],
        boxes: artifact.observations.map(\.boundingBox),
        lines: []
      )
      printStatus("Saved bounding boxes to \(output)")
    }
  }
}
