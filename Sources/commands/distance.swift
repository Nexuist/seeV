import ArgumentParser
import Foundation
import Vision

@available(macOS 12.0, *)
struct Distance: ParsableCommand {

  static var configuration = CommandConfiguration(
    abstract:
      "Calculates embeddings for the input and output images and the distance between them."
  )

  @OptionGroup() var args: Options

  mutating func run() {
    do {
      let req1 = VNGenerateImageFeaturePrintRequest()
      let embedding1: VNFeaturePrintObservation = try performRequest(
        request: req1, inputImagePath: args.input
      ).first!
      let weights1 = embedding1.data.withUnsafeBytes {
        Array($0.bindMemory(to: Float.self))
      }
      let req2 = VNGenerateImageFeaturePrintRequest()
      let embedding2: VNFeaturePrintObservation = try performRequest(
        request: req2, inputImagePath: args.output!
      ).first!
      let weights2 = embedding2.data.withUnsafeBytes {
        Array($0.bindMemory(to: Float.self))
      }
      // Calculate cosine similarity
      printDict([
        "A": args.input,
        "B": args.output!,
        "distance": 1 - cosineSimilarity(weights1, weights2),
      ])
    } catch {
      print("Error: \(error)")
    }
  }
}
