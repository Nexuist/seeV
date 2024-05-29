import ArgumentParser
import Foundation

let VERSION = "1.8.0"

struct Options: ParsableArguments {
  @Argument(help: "The filepath of the input image")
  var input: String

  @Option(name: [.customShort("o"), .long], help: "The filepath of the output image")
  var output: String?
}

@available(macOS 14.0, *)
@main
struct seev: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "A command line wrapper over Apple's Vision framework.",
    version: VERSION,
    subcommands: [
      Subject.self,
      Faces.self,
      // Humans.self,
      // Text.self,
      // Embeddings.self,
      // Distance.self,
      Classify.self,
      Poses.self,
    ],
    defaultSubcommand: Subject.self
  )

  // struct Humans: ParsableCommand {
  //   static var configuration = CommandConfiguration(
  //     abstract: "Detects humans in an image and returns the results as JSON.",
  //     discussion:
  //       "The JSON output includes the bounding box and confidence of each human. If an output path is provided, a PNG image with the bounding boxes drawn will be saved."
  //   )

  //   @OptionGroup() var args: Options

  //   mutating func run() {
  //     do {
  //       let humans = try extractHumans(inputImagePath: args.input)
  //       let humanDict: [String: Any] = [
  //         "input": args.input,
  //         "humans": humans.map { human in
  //           return [
  //             "boundingBox": [
  //               "x": human.boundingBox.origin.x,
  //               "y": human.boundingBox.origin.y,
  //               "width": human.boundingBox.width,
  //               "height": human.boundingBox.height,
  //             ],
  //             "confidence": human.confidence,
  //           ] as [String: Any]
  //         },
  //       ]
  //       let jsonData = try JSONSerialization.data(
  //         withJSONObject: humanDict, options: .prettyPrinted)
  //       print(String(data: jsonData, encoding: .utf8)!)
  //       if args.output != nil {
  //         writeBoundingBoxes(
  //           inputImagePath: args.input,
  //           outputImagePath: args.output!,
  //           boxes: humans.map(\.boundingBox))
  //         print("Saved bounding boxes to \(args.output!)")
  //       }
  //     } catch {
  //       print("Error: \(error)")
  //     }
  //   }
  // }

  // struct Text: ParsableCommand {
  //   static var configuration = CommandConfiguration(
  //     abstract: "Detects text in an image and returns the results as JSON.",
  //     discussion:
  //       "The JSON output includes the bounding box, text, and confidence of each detected text. If an output path is provided, a PNG image with the bounding boxes drawn will be saved."
  //   )

  //   @OptionGroup() var args: Options
  //   @Option(
  //     name: [.customLong("custom-words")],
  //     parsing: .upToNextOption,
  //     help: "Custom words to use for text recognition")
  //   var customWords: [String] = []

  //   mutating func run() {
  //     do {
  //       let text = try extractText(inputImagePath: args.input, customWords: customWords)
  //       let textDict: [String: Any] = [
  //         "input": args.input,
  //         "customWords": customWords,
  //         "text": text.map { text in
  //           return [
  //             "boundingBox": [
  //               "x": text.boundingBox.origin.x,
  //               "y": text.boundingBox.origin.y,
  //               "width": text.boundingBox.width,
  //               "height": text.boundingBox.height,
  //             ],
  //             "text": text.topCandidates(1).first?.string ?? "Failed to recognize text",
  //             "confidence": text.confidence,
  //           ] as [String: Any]
  //         },
  //       ]
  //       let jsonData = try JSONSerialization.data(
  //         withJSONObject: textDict, options: .prettyPrinted)
  //       print(String(data: jsonData, encoding: .utf8)!)
  //       if args.output != nil {
  //         writeBoundingBoxes(
  //           inputImagePath: args.input,
  //           outputImagePath: args.output!,
  //           boxes: text.map(\.boundingBox))
  //         print("Saved bounding boxes to \(args.output!)")
  //       }
  //     } catch {
  //       print("Error: \(error)")
  //     }
  //   }
  // }

  // struct Embeddings: ParsableCommand {
  //   static var configuration = CommandConfiguration(
  //     abstract: "Extracts embeddings from an image and returns the results as JSON."
  //   )

  //   @OptionGroup() var args: Options

  //   mutating func run() {
  //     do {
  //       let embedding = try inferFeaturePrint(inputImagePath: args.input)
  //       let embeddingDict: [String: Any] = [
  //         "input": args.input,
  //         "embedding": embedding,
  //       ]
  //       let jsonData = try JSONSerialization.data(
  //         withJSONObject: embeddingDict, options: .prettyPrinted)
  //       print(String(data: jsonData, encoding: .utf8)!)
  //     } catch {
  //       print("Error: \(error)")
  //     }
  //   }
  // }

  // struct Distance: ParsableCommand {
  //   static var configuration = CommandConfiguration(
  //     abstract:
  //       "Calculates embeddings for the input and output images and the distance between them."
  //   )

  //   @OptionGroup() var args: Options

  //   mutating func run() {
  //     do {
  //       let embedding1 = try inferFeaturePrint(inputImagePath: args.input)
  //       guard args.output != nil else {
  //         throw SeeVError.noFeaturePrintFound
  //       }
  //       let embedding2 = try inferFeaturePrint(inputImagePath: args.output!)
  //       // Calculate cosine similarity
  //       let distanceDict: [String: Any] = [
  //         "A": args.input,
  //         "B": args.output!,
  //         "distance": 1 - cosineSimilarity(embedding1, embedding2),
  //       ]
  //       let jsonData = try JSONSerialization.data(
  //         withJSONObject: distanceDict, options: .prettyPrinted)
  //       print(String(data: jsonData, encoding: .utf8)!)
  //     } catch {
  //       print("Error: \(error)")
  //     }
  //   }
  // }
}
