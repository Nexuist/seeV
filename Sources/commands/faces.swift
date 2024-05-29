import ArgumentParser
import Foundation
import Vision

@available(macOS 14.0, *)
struct Faces: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Detects faces in an image and returns the results as JSON.",
    discussion:
      "The JSON output includes the roll, yaw, pitch, bounding box, and confidence of each face. If an output path is provided, a PNG image with the bounding boxes drawn will be saved."
  )

  @OptionGroup() var args: Options
  @Flag(
    name: [.customShort("c"), .long],
    help: "Crop the output to the largest face bounding box found")
  var cropped: Bool = false

  @Flag(
    name: [.customShort("e"), .long],
    help: "Generate embeddings for each cropped face"
  )
  var embeddings: Bool = false

  mutating func run() {
    do {
      let faces: [VNFaceObservation] = try performRequest(
        request: VNDetectFaceRectanglesRequest(),
        inputImagePath: args.input
      )
      printDict([
        "input": args.input,
        "faces": faces.map { face in
          var result =
            [
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
          if embeddings {
            let faceImage = try? cropImage(
              inputImagePath: args.input,
              boundingBox: face.boundingBox
            )
            if faceImage == nil { return result }
            let request = VNGenerateImageFeaturePrintRequest()
            let featurePrint: [VNFeaturePrintObservation]? = try? performRequest(
              request: request,
              input: faceImage!
            )
            if featurePrint == nil { return result }
            result["embedding"] = featurePrint!.first!.data.withUnsafeBytes {
              Array($0.bindMemory(to: Float.self))
            }
          }
          return result
        },
      ])
      if cropped {
        let largestFace = faces.max {
          $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width
            * $1.boundingBox.height
        }
        if largestFace != nil {
          let output = try cropImage(
            inputImagePath: args.input, boundingBox: largestFace!.boundingBox)
          saveOutput(output: output, outputImagePath: args.output!)
          print("Saved cropped image to \(args.output!)")
        } else {
          throw SeeVError.noSubjectFound
        }
      } else if args.output != nil {
        draw(
          inputImagePath: args.input,
          outputImagePath: args.output!,
          points: [],
          boxes: faces.map(\.boundingBox),
          lines: [])
        print("Saved bounding boxes to \(args.output!)")
      }
    } catch {
      print("Error: \(error)")
    }
  }
}
