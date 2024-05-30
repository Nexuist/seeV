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

  mutating func run() {
    do {
      let embeddings: [VNFeaturePrintObservation] = try performRequest(
        request: VNGenerateImageFeaturePrintRequest(),
        inputImagePath: args.input
      )
      printDict([
        "input": args.input,
        "embedding": embeddings.first!.data.withUnsafeBytes {
          Array($0.bindMemory(to: Float.self))
        },
      ])
    } catch {
      print("Error: \(error)")
    }
  }
}
