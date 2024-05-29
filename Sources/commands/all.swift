import ArgumentParser
import Foundation
import Vision

@available(macOS 12.0, *)
struct All: ParsableCommand {
  static var configuration: CommandConfiguration = CommandConfiguration(
    abstract: "Performs all operations on an image and returns the results as JSON.",
    discussion:
      "The JSON output includes faces, humans, text, poses, classifications, and embeddings."
  )

  @OptionGroup() var args: Options

  mutating func run() {
    do {
      let inputURL = inputImagePathToURL(args.input)
      let handler = VNImageRequestHandler(url: inputURL)
      let facesRequest = VNDetectFaceRectanglesRequest()
      let humansRequest = VNDetectHumanRectanglesRequest()
      let textRequest = VNRecognizeTextRequest()
      textRequest.recognitionLevel = .accurate
      textRequest.usesLanguageCorrection = true
      let poseRequest = VNDetectHumanBodyPoseRequest()
      let classifyRequest = VNClassifyImageRequest()
      let embeddingRequest = VNGenerateImageFeaturePrintRequest()
      try handler.perform([
        facesRequest, humansRequest, textRequest, poseRequest, classifyRequest, embeddingRequest,
      ])
      var result: [String: Any] = [:]
      result["input"] = args.input
      // Faces
      if let faces = facesRequest.results {
        result["faces"] = faces.map { face in
          var faceResult: [String: Any] = [
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
          ]
          let faceImage = try? cropImage(
            inputImagePath: args.input,
            boundingBox: face.boundingBox)
          if faceImage == nil { return faceResult }
          let featurePrint: [VNFeaturePrintObservation]? = try? performRequest(
            request: embeddingRequest,
            input: faceImage!
          )
          if featurePrint == nil { return faceResult }
          faceResult["embedding"] = featurePrint!.first!.data.withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
          }
          return faceResult
        }
      }
      // Humans
      if let humans = humansRequest.results {
        result["humans"] = humans.map { human in
          return [
            "boundingBox": [
              "x": human.boundingBox.origin.x,
              "y": human.boundingBox.origin.y,
              "width": human.boundingBox.width,
              "height": human.boundingBox.height,
            ],
            "confidence": human.confidence,
          ] as [String: Any]
        }
      }
      // Text
      if let text = textRequest.results {
        result["text"] = text.map { text in
          return [
            "boundingBox": [
              "x": text.boundingBox.origin.x,
              "y": text.boundingBox.origin.y,
              "width": text.boundingBox.width,
              "height": text.boundingBox.height,
            ],
            "text": text.topCandidates(1).first?.string ?? "Failed to recognize text",
            "confidence": text.confidence,
          ] as [String: Any]
        }
      }
      // Poses
      if let poses = poseRequest.results {
        result["poses"] = poses.map { pose in
          return [
            "joints": pose.availableJointNames.map {
              [
                "name": $0.rawValue,
                "x": try! pose.recognizedPoint($0).location.x,
                "y": try! pose.recognizedPoint($0).location.y,
                "confidence": try! pose.recognizedPoint($0).confidence,
              ]
            }
          ]
        }
      }
      // Classification
      if let classifications = classifyRequest.results {
        result["classifications"] =
          classifications
          .filter { $0.confidence >= 0.4 }
          .map { classification in
            return [
              "identifier": classification.identifier,
              "confidence": classification.confidence,
            ]
          }
      }
      // Embedding
      if let embeddings = embeddingRequest.results {
        result["embedding"] = embeddings.first!.data.withUnsafeBytes {
          Array($0.bindMemory(to: Float.self))
        }
      }
      // Print the result
      printDict(result)
    } catch {
      print("Error: \(error)")
    }
  }
}
