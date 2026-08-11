import ArgumentParser
import Foundation
import Vision

@available(macOS 12.0, *)
struct All: ParsableCommand {
  static var configuration: CommandConfiguration = CommandConfiguration(
    abstract: "Performs all operations on an image and returns the results as JSON.",
    discussion:
      "Successful operations are returned even when another operation fails. Failures are included in the errors object."
  )

  @OptionGroup() var args: Options

  mutating func run() throws {
    try runCombinedAnalysis(input: args.input, includeEmbeddings: true)
  }
}

@available(macOS 12.0, *)
func runCombinedAnalysis(input: String, includeEmbeddings: Bool) throws {
  var result: [String: Any] = ["input": input]
  var errors: [String: String] = [:]
  var successCount = 0

  func attempt<T>(_ name: String, _ operation: () throws -> T) -> T? {
    do {
      let value = try operation()
      successCount += 1
      return value
    } catch {
      errors[name] = error.localizedDescription
      return nil
    }
  }

  if let faces: [VNFaceObservation] = attempt(
    "faces",
    {
      try performRequest(
        request: VNDetectFaceRectanglesRequest(),
        inputImagePath: input
      )
    })
  {
    var faceEmbeddingFailures = 0
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

      guard includeEmbeddings else {
        return faceResult
      }

      do {
        let faceImage = try cropImage(
          inputImagePath: input,
          boundingBox: face.boundingBox
        )
        let featurePrint: [VNFeaturePrintObservation] = try performRequest(
          request: VNGenerateImageFeaturePrintRequest(),
          input: faceImage
        )
        guard let embedding = featurePrint.first else {
          throw SeeVError.noFeaturePrintFound
        }
        faceResult["embedding"] = embedding.data.withUnsafeBytes {
          Array($0.bindMemory(to: Float.self))
        }
      } catch {
        faceEmbeddingFailures += 1
      }
      return faceResult
    }
    if faceEmbeddingFailures > 0 {
      errors["faceEmbeddings"] =
        "Failed to generate embeddings for \(faceEmbeddingFailures) of \(faces.count) faces."
    }
  }

  if let humans: [VNHumanObservation] = attempt(
    "humans",
    {
      try performRequest(
        request: VNDetectHumanRectanglesRequest(),
        inputImagePath: input
      )
    })
  {
    result["humans"] = humans.map { human in
      [
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

  let textRequest = VNRecognizeTextRequest()
  textRequest.recognitionLevel = .accurate
  textRequest.usesLanguageCorrection = true
  if let text: [VNRecognizedTextObservation] = attempt(
    "text",
    {
      try performRequest(request: textRequest, inputImagePath: input)
    })
  {
    result["text"] = text.map { observation in
      [
        "boundingBox": [
          "x": observation.boundingBox.origin.x,
          "y": observation.boundingBox.origin.y,
          "width": observation.boundingBox.width,
          "height": observation.boundingBox.height,
        ],
        "text": observation.topCandidates(1).first?.string ?? "Failed to recognize text",
        "confidence": observation.confidence,
      ] as [String: Any]
    }
  }

  if let poses: [VNHumanBodyPoseObservation] = attempt(
    "poses",
    {
      try performRequest(
        request: VNDetectHumanBodyPoseRequest(),
        inputImagePath: input
      )
    })
  {
    result["poses"] = poses.map { pose in
      [
        "joints": pose.availableJointNames.compactMap { jointName -> [String: Any]? in
          guard let point = try? pose.recognizedPoint(jointName) else {
            return nil
          }
          return [
            "name": jointName.rawValue,
            "x": point.location.x,
            "y": point.location.y,
            "confidence": point.confidence,
          ] as [String: Any]
        }
      ]
    }
  }

  if let classifications: [VNClassificationObservation] = attempt(
    "classifications",
    {
      try performRequest(
        request: VNClassifyImageRequest(),
        inputImagePath: input
      )
    })
  {
    result["classifications"] =
      classifications
      .filter { $0.confidence >= 0.4 }
      .map { classification in
        [
          "identifier": classification.identifier,
          "confidence": classification.confidence,
        ] as [String: Any]
      }
  }

  if includeEmbeddings {
    if let embeddings: [VNFeaturePrintObservation] = attempt(
      "embedding",
      {
        try performRequest(
          request: VNGenerateImageFeaturePrintRequest(),
          inputImagePath: input
        )
      })
    {
      if let embedding = embeddings.first {
        result["embedding"] = embedding.data.withUnsafeBytes {
          Array($0.bindMemory(to: Float.self))
        }
      } else {
        errors["embedding"] = String(describing: SeeVError.noFeaturePrintFound)
      }
    }
  }

  if let sha1 = attempt(
    "sha1",
    {
      try hashFile(inputImagePath: input)
    })
  {
    result["sha1"] = sha1
  }

  guard successCount > 0 else {
    let summary = errors.sorted { $0.key < $1.key }
      .map { "\($0.key): \($0.value)" }
      .joined(separator: "; ")
    throw ValidationError("All operations failed. \(summary)")
  }

  if !errors.isEmpty {
    result["errors"] = errors
  }
  printDict(result)
}
