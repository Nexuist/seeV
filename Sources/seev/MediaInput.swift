import AVFoundation
import ArgumentParser
import CoreGraphics
import Foundation
import UniformTypeIdentifiers
import Vision

let defaultMaxFrames = 10

struct VideoFrame {
  let image: CGImage
  let timestampSeconds: Double
}

struct VideoFrames {
  let durationSeconds: Double
  let frames: [VideoFrame]
}

enum AnalysisInput {
  case url(URL)
  case image(CGImage)

  func perform<T: VNObservation>(_ request: VNRequest) throws -> [T] {
    switch self {
    case .url(let url):
      let handler = VNImageRequestHandler(url: url)
      try handler.perform([request])
    case .image(let image):
      let handler = VNImageRequestHandler(cgImage: image)
      try handler.perform([request])
    }
    return request.results as? [T] ?? []
  }

  func crop(to boundingBox: CGRect) throws -> CGImage {
    switch self {
    case .url(let url):
      return try cropImage(inputURL: url, boundingBox: boundingBox)
    case .image(let image):
      return try cropImage(input: image, boundingBox: boundingBox)
    }
  }

  func isNSFW(using classifier: ShieldGemmaNSFWClassifier) async throws -> Bool {
    switch self {
    case .url(let url):
      return try await classifier.isNSFW(imageAt: url)
    case .image(let image):
      return try await classifier.isNSFW(image: image)
    }
  }
}

struct FrameAnalysisResult<Artifact> {
  let output: [String: Any]
  let artifact: Artifact
}

extension FrameAnalysisResult where Artifact == Void {
  init(output: [String: Any]) {
    self.init(output: output, artifact: ())
  }
}

struct MediaAnalysisResult<Artifact> {
  var output: [String: Any]
  let imageArtifact: Artifact?
}

enum VideoInputError: LocalizedError {
  case invalidVideo(String)
  case noUsableFrames
  case imageOutputUnsupported

  var errorDescription: String? {
    switch self {
    case .invalidVideo(let reason):
      return "Could not read the video: \(reason)"
    case .noUsableFrames:
      return "The video did not contain any decodable frames."
    case .imageOutputUnsupported:
      return "Image output options are not supported for video inputs."
    }
  }
}

func isVideoInput(_ input: String) -> Bool {
  let fileExtension = inputImagePathToURL(input).pathExtension
  guard !fileExtension.isEmpty, let type = UTType(filenameExtension: fileExtension) else {
    return false
  }
  return type.conforms(to: .movie)
}

@available(macOS 13.0, *)
func extractVideoFrames(input: String, maxFrames: Int) async throws -> VideoFrames {
  let asset = AVURLAsset(url: inputImagePathToURL(input))
  let duration: CMTime
  let tracks: [AVAssetTrack]
  do {
    (duration, tracks) = try await asset.load(.duration, .tracks)
  } catch {
    throw VideoInputError.invalidVideo(error.localizedDescription)
  }

  guard tracks.contains(where: { $0.mediaType == .video }) else {
    throw VideoInputError.invalidVideo("no video track was found")
  }

  let durationSeconds = duration.seconds
  guard durationSeconds.isFinite, durationSeconds > 0 else {
    throw VideoInputError.invalidVideo("the duration is missing or invalid")
  }

  let bucketDuration = durationSeconds / Double(maxFrames)
  let primaryTimes = (0..<maxFrames).map { index in
    CMTime(
      seconds: (Double(index) + 0.5) * bucketDuration,
      preferredTimescale: 600
    )
  }

  let generator = AVAssetImageGenerator(asset: asset)
  generator.appliesPreferredTrackTransform = true
  generator.maximumSize = CGSize(width: 1280, height: 1280)
  let tolerance = min(0.5, bucketDuration * 0.2)
  generator.requestedTimeToleranceBefore = CMTime(seconds: tolerance, preferredTimescale: 600)
  generator.requestedTimeToleranceAfter = CMTime(seconds: tolerance, preferredTimescale: 600)

  var selected = await generateVideoFrames(at: primaryTimes, using: generator)
  let missingIndices = selected.indices.filter { selected[$0] == nil }
  if !missingIndices.isEmpty {
    let fallbackTimes = missingIndices.map { index in
      let position = index.isMultiple(of: 2) ? 0.25 : 0.75
      return CMTime(
        seconds: (Double(index) + position) * bucketDuration,
        preferredTimescale: 600
      )
    }
    let fallbacks = await generateVideoFrames(at: fallbackTimes, using: generator)
    for (fallbackIndex, selectedIndex) in missingIndices.enumerated() {
      selected[selectedIndex] = fallbacks[fallbackIndex]
    }
  }

  let sortedFrames = selected.compactMap { $0 }.sorted {
    $0.timestampSeconds < $1.timestampSeconds
  }
  var uniqueFrames: [VideoFrame] = []
  for frame in sortedFrames {
    if let previous = uniqueFrames.last,
      abs(previous.timestampSeconds - frame.timestampSeconds) < 0.001
    {
      continue
    }
    uniqueFrames.append(frame)
  }

  guard !uniqueFrames.isEmpty else {
    throw VideoInputError.noUsableFrames
  }
  return VideoFrames(durationSeconds: durationSeconds, frames: uniqueFrames)
}

@available(macOS 13.0, *)
private func generateVideoFrames(
  at times: [CMTime],
  using generator: AVAssetImageGenerator
) async -> [VideoFrame?] {
  var frames = [VideoFrame?](repeating: nil, count: times.count)
  for await result in generator.images(for: times) {
    guard let index = times.firstIndex(where: { CMTimeCompare($0, result.requestedTime) == 0 })
    else {
      continue
    }

    do {
      let image = try result.image
      frames[index] = VideoFrame(
        image: image,
        timestampSeconds: try result.actualTime.seconds
      )
    } catch {
      continue
    }
  }
  return frames
}

@available(macOS 13.0, *)
func analyzeMedia<Artifact>(
  input: String,
  maxFrames: Int,
  operationName: String,
  analysis: (AnalysisInput) async throws -> FrameAnalysisResult<Artifact>
) async throws -> MediaAnalysisResult<Artifact> {
  guard isVideoInput(input) else {
    let result = try await analysis(.url(inputImagePathToURL(input)))
    var output: [String: Any] = ["input": input]
    output.merge(result.output) { _, new in new }
    return MediaAnalysisResult(
      output: output,
      imageArtifact: result.artifact
    )
  }

  let video = try await extractVideoFrames(input: input, maxFrames: maxFrames)
  var results: [[String: Any]] = []
  var successCount = 0

  for frame in video.frames {
    var frameResult: [String: Any] = ["timestampSeconds": frame.timestampSeconds]
    do {
      let analysisResult = try await analysis(.image(frame.image))
      frameResult.merge(analysisResult.output) { _, new in new }
      successCount += 1
    } catch {
      frameResult["errors"] = [operationName: error.localizedDescription]
    }
    results.append(frameResult)
  }

  guard successCount > 0 else {
    throw ValidationError("Every selected video frame failed \(operationName) analysis.")
  }

  return MediaAnalysisResult(
    output: [
      "input": input,
      "durationSeconds": video.durationSeconds,
      "frames": results,
    ],
    imageArtifact: nil
  )
}
