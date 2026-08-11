import ArgumentParser
import CoreGraphics
import Foundation
import Vision

struct FaceAnalysisArtifact {
  let observations: [VNFaceObservation]
  let embeddingFailureCount: Int
}

func faceAnalysis(
  input: AnalysisInput,
  includeEmbeddings: Bool
) throws -> FrameAnalysisResult<FaceAnalysisArtifact> {
  let faces: [VNFaceObservation] = try input.perform(VNDetectFaceRectanglesRequest())
  var embeddingFailureCount = 0
  let output = faces.map { face in
    var result: [String: Any] = [
      "roll": face.roll ?? 0,
      "yaw": face.yaw ?? 0,
      "pitch": face.pitch ?? 0,
      "boundingBox": boundingBoxDictionary(face.boundingBox),
      "confidence": face.confidence,
    ]

    guard includeEmbeddings else {
      return result
    }

    do {
      let faceImage = try input.crop(to: face.boundingBox)
      let featurePrint: VNFeaturePrintObservation = try firstObservation(
        request: VNGenerateImageFeaturePrintRequest(),
        input: .image(faceImage)
      )
      result["embedding"] = embeddingArray(featurePrint)
    } catch {
      embeddingFailureCount += 1
    }
    return result
  }

  return FrameAnalysisResult(
    output: ["faces": output],
    artifact: FaceAnalysisArtifact(
      observations: faces,
      embeddingFailureCount: embeddingFailureCount
    )
  )
}

func humanAnalysis(
  input: AnalysisInput
) throws -> FrameAnalysisResult<[VNHumanObservation]> {
  let humans: [VNHumanObservation] = try input.perform(VNDetectHumanRectanglesRequest())
  return FrameAnalysisResult(
    output: [
      "humans": humans.map { human in
        [
          "boundingBox": boundingBoxDictionary(human.boundingBox),
          "confidence": human.confidence,
        ] as [String: Any]
      }
    ],
    artifact: humans
  )
}

func textAnalysis(
  input: AnalysisInput,
  customWords: [String] = []
) throws -> FrameAnalysisResult<[VNRecognizedTextObservation]> {
  let request = VNRecognizeTextRequest()
  request.recognitionLevel = .accurate
  request.usesLanguageCorrection = true
  request.customWords = customWords
  let observations: [VNRecognizedTextObservation] = try input.perform(request)
  return FrameAnalysisResult(
    output: [
      "text": observations.map { observation in
        [
          "boundingBox": boundingBoxDictionary(observation.boundingBox),
          "text": observation.topCandidates(1).first?.string ?? "Failed to recognize text",
          "confidence": observation.confidence,
        ] as [String: Any]
      }
    ],
    artifact: observations
  )
}

func poseAnalysis(
  input: AnalysisInput
) throws -> FrameAnalysisResult<[VNHumanBodyPoseObservation]> {
  let poses: [VNHumanBodyPoseObservation] = try input.perform(VNDetectHumanBodyPoseRequest())
  return FrameAnalysisResult(
    output: [
      "poses": poses.map { pose in
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
            ]
          }
        ]
      }
    ],
    artifact: poses
  )
}

func classificationAnalysis(
  input: AnalysisInput,
  minimumConfidence: Float,
  includeIdentifiers: [String]
) throws -> FrameAnalysisResult<Void> {
  let classifications: [VNClassificationObservation] = try input.perform(VNClassifyImageRequest())
  let filtered = classifications.filter { $0.confidence >= minimumConfidence }
  var output = filtered.map { classification in
    [
      "identifier": classification.identifier,
      "confidence": classification.confidence,
    ] as [String: Any]
  }
  for identifier in includeIdentifiers
  where !filtered.contains(where: { $0.identifier == identifier }) {
    output.append([
      "identifier": identifier,
      "confidence": classifications.first(where: { $0.identifier == identifier })?.confidence ?? 0,
    ])
  }
  return FrameAnalysisResult(output: ["classifications": output])
}

func embeddingAnalysis(input: AnalysisInput) throws -> FrameAnalysisResult<Void> {
  let observation: VNFeaturePrintObservation = try firstObservation(
    request: VNGenerateImageFeaturePrintRequest(),
    input: input
  )
  return FrameAnalysisResult(output: ["embedding": embeddingArray(observation)])
}

@available(macOS 15.0, *)
func qualityAnalysis(input: AnalysisInput) throws -> FrameAnalysisResult<Void> {
  let observation: VNImageAestheticsScoresObservation = try firstObservation(
    request: VNCalculateImageAestheticsScoresRequest(),
    input: input
  )
  return FrameAnalysisResult(output: [
    "overallScore": observation.overallScore,
    "isUtility": observation.isUtility,
  ])
}

@available(macOS 15.0, *)
func combinedAnalysis(
  input: AnalysisInput,
  includeEmbeddings: Bool,
  nsfwClassifier: ShieldGemmaNSFWClassifier?,
  nsfwSetupError: String? = nil
) async throws -> FrameAnalysisResult<Void> {
  var result: [String: Any] = [:]
  var errors: [String: String] = [:]
  var successCount = 0

  func attempt<Artifact>(
    _ name: String,
    _ operation: () throws -> FrameAnalysisResult<Artifact>
  ) -> FrameAnalysisResult<Artifact>? {
    do {
      let value = try operation()
      successCount += 1
      return value
    } catch {
      errors[name] = error.localizedDescription
      return nil
    }
  }

  if let faces = attempt(
    "faces",
    {
      try faceAnalysis(input: input, includeEmbeddings: includeEmbeddings)
    })
  {
    result.merge(faces.output) { _, new in new }
    if faces.artifact.embeddingFailureCount > 0 {
      errors["faceEmbeddings"] =
        "Failed to generate embeddings for \(faces.artifact.embeddingFailureCount) of \(faces.artifact.observations.count) faces."
    }
  }
  if let humans = attempt("humans", { try humanAnalysis(input: input) }) {
    result.merge(humans.output) { _, new in new }
  }
  if let text = attempt("text", { try textAnalysis(input: input) }) {
    result.merge(text.output) { _, new in new }
  }
  if let poses = attempt("poses", { try poseAnalysis(input: input) }) {
    result.merge(poses.output) { _, new in new }
  }
  if let classifications = attempt(
    "classifications",
    {
      try classificationAnalysis(
        input: input,
        minimumConfidence: 0.4,
        includeIdentifiers: []
      )
    })
  {
    result.merge(classifications.output) { _, new in new }
  }
  if let quality = attempt("quality", { try qualityAnalysis(input: input) }) {
    result["quality"] = quality.output
  }
  if includeEmbeddings,
    let embedding = attempt("embedding", { try embeddingAnalysis(input: input) })
  {
    result.merge(embedding.output) { _, new in new }
  }

  if let nsfwClassifier {
    do {
      result["nsfw"] = try await input.isNSFW(using: nsfwClassifier)
      successCount += 1
    } catch {
      errors["nsfw"] = error.localizedDescription
    }
  } else if let nsfwSetupError {
    errors["nsfw"] = nsfwSetupError
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
  return FrameAnalysisResult(output: result)
}

func addFileHash(to result: inout [String: Any], input: String) {
  do {
    result["sha1"] = try hashFile(inputImagePath: input)
  } catch {
    var errors = result["errors"] as? [String: String] ?? [:]
    errors["sha1"] = error.localizedDescription
    result["errors"] = errors
  }
}

@available(macOS 15.0, *)
func runCombinedMediaAnalysis(
  input: String,
  maxFrames: Int,
  includeEmbeddings: Bool,
  nsfwClassifier: ShieldGemmaNSFWClassifier? = nil,
  nsfwSetupError: String? = nil
) async throws {
  var result = try await analyzeMedia(
    input: input,
    maxFrames: maxFrames,
    operationName: "combined"
  ) { analysisInput in
    try await combinedAnalysis(
      input: analysisInput,
      includeEmbeddings: includeEmbeddings,
      nsfwClassifier: nsfwClassifier,
      nsfwSetupError: nsfwSetupError
    )
  }.output
  addFileHash(to: &result, input: input)
  printDict(result)
}

private func boundingBoxDictionary(_ boundingBox: CGRect) -> [String: CGFloat] {
  [
    "x": boundingBox.origin.x,
    "y": boundingBox.origin.y,
    "width": boundingBox.width,
    "height": boundingBox.height,
  ]
}

private func embeddingArray(_ observation: VNFeaturePrintObservation) -> [Float] {
  observation.data.withUnsafeBytes {
    Array($0.bindMemory(to: Float.self))
  }
}

private func firstObservation<T: VNObservation>(
  request: VNRequest,
  input: AnalysisInput
) throws -> T {
  let observations: [T] = try input.perform(request)
  guard let observation = observations.first else {
    throw ValidationError("Vision did not return a result.")
  }
  return observation
}
