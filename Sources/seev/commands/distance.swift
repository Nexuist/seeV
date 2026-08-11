import ArgumentParser
import Foundation
import Vision

@available(macOS 12.0, *)
struct Distance: ParsableCommand {

  static var configuration = CommandConfiguration(
    abstract:
      "Calculates embeddings for two images and the distance between them."
  )

  @Argument(help: "The filepath of the first image")
  var firstImage: String

  @Argument(help: "The filepath of the second image")
  var secondImage: String

  mutating func run() throws {
    guard !isVideoInput(firstImage), !isVideoInput(secondImage) else {
      throw ValidationError("Distance supports images only.")
    }

    let firstInput = AnalysisInput.url(inputImagePathToURL(firstImage))
    let embeddings1: [VNFeaturePrintObservation] = try firstInput.perform(
      VNGenerateImageFeaturePrintRequest()
    )
    guard let embedding1 = embeddings1.first else {
      throw SeeVError.noFeaturePrintFound
    }
    let weights1 = embedding1.data.withUnsafeBytes {
      Array($0.bindMemory(to: Float.self))
    }

    let secondInput = AnalysisInput.url(inputImagePathToURL(secondImage))
    let embeddings2: [VNFeaturePrintObservation] = try secondInput.perform(
      VNGenerateImageFeaturePrintRequest()
    )
    guard let embedding2 = embeddings2.first else {
      throw SeeVError.noFeaturePrintFound
    }
    let weights2 = embedding2.data.withUnsafeBytes {
      Array($0.bindMemory(to: Float.self))
    }

    printDict([
      "A": firstImage,
      "B": secondImage,
      "distance": 1 - cosineSimilarity(weights1, weights2),
    ])
  }
}
