import ArgumentParser
import Vision

@available(macOS 15.0, *)
struct Quality: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Scores the aesthetic quality of an image."
  )

  @Argument(help: "The filepath of the input image")
  var input: String

  mutating func run() throws {
    let observations: [VNImageAestheticsScoresObservation] = try performRequest(
      request: VNCalculateImageAestheticsScoresRequest(),
      inputImagePath: input
    )
    guard let quality = observations.first else {
      throw ValidationError("Vision did not return an image quality score.")
    }

    printDict([
      "input": input,
      "overallScore": quality.overallScore,
      "isUtility": quality.isUtility,
    ])
  }
}
