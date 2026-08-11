import ArgumentParser
import Foundation
import Vision

@available(macOS 12.0, *)
struct Embeddings: ParsableCommand {

  static var configuration = CommandConfiguration(
    abstract: "Extracts embeddings from an image and returns the results as JSON.",
    discussion: "The JSON output includes the embeddings of the input image."
  )

  @OptionGroup() var args: Options

  mutating func run() throws {
    let embeddings: [VNFeaturePrintObservation] = try performRequest(
      request: VNGenerateImageFeaturePrintRequest(),
      inputImagePath: args.input
    )
    guard let embedding = embeddings.first else {
      throw SeeVError.noFeaturePrintFound
    }
    printDict([
      "input": args.input,
      "embedding": embedding.data.withUnsafeBytes {
        Array($0.bindMemory(to: Float.self))
      },
    ])
  }
}
