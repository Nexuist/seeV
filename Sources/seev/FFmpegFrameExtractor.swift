import CoreGraphics
import Foundation
import ImageIO

enum FFmpegFrameExtractionError: LocalizedError {
  case unavailable
  case failed(String)

  var errorDescription: String? {
    switch self {
    case .unavailable:
      return
        "ffmpeg and ffprobe must be installed and available on PATH. Install them with 'brew install ffmpeg'."
    case .failed(let reason):
      return reason
    }
  }
}

struct FFmpegFrameExtractor {
  private let ffmpeg: URL
  private let ffprobe: URL

  init() throws {
    guard
      let ffmpeg = Self.executable(named: "ffmpeg"),
      let ffprobe = Self.executable(named: "ffprobe")
    else {
      throw FFmpegFrameExtractionError.unavailable
    }
    self.ffmpeg = ffmpeg
    self.ffprobe = ffprobe
  }

  func extract(input: String, maxFrames: Int) throws -> VideoFrames {
    let sourceURL = inputImagePathToURL(input)
    let source = sourceURL.isFileURL ? sourceURL.path : sourceURL.absoluteString
    let durationSeconds = try duration(of: source)
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("seev-frames-\(UUID().uuidString)", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: false
      )
    } catch {
      throw FFmpegFrameExtractionError.failed(
        "Could not create a temporary frame directory: \(error.localizedDescription)"
      )
    }
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let frames = try extractFrames(
      source: source,
      durationSeconds: durationSeconds,
      maxFrames: maxFrames,
      in: temporaryDirectory
    )
    return VideoFrames(durationSeconds: durationSeconds, frames: frames)
  }

  private func duration(of source: String) throws -> Double {
    let result = try run(
      ffprobe,
      arguments: [
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        source,
      ]
    )
    guard result.status == 0 else {
      throw FFmpegFrameExtractionError.failed(
        result.error.isEmpty ? "ffprobe could not read the video." : result.error
      )
    }
    guard
      let duration = Double(result.output.trimmingCharacters(in: .whitespacesAndNewlines)),
      duration.isFinite,
      duration > 0
    else {
      throw FFmpegFrameExtractionError.failed("ffprobe did not return a valid duration.")
    }
    return duration
  }

  private func extractFrames(
    source: String,
    durationSeconds: Double,
    maxFrames: Int,
    in temporaryDirectory: URL
  ) throws -> [VideoFrame] {
    let bucketDuration = durationSeconds / Double(maxFrames)
    let frameRate = Double(maxFrames) / durationSeconds
    let outputPattern = temporaryDirectory.appendingPathComponent("frame-%03d.jpg").path
    let result = try run(
      ffmpeg,
      arguments: [
        "-hide_banner", "-loglevel", "error",
        "-ss", String(bucketDuration / 2),
        "-i", source,
        "-an", "-sn", "-dn",
        "-vf",
        "fps=fps=\(frameRate):round=near:eof_action=pass,scale='min(1280,iw)':'min(1280,ih)':force_original_aspect_ratio=decrease",
        "-frames:v", String(maxFrames),
        "-q:v", "3",
        "-y", outputPattern,
      ]
    )
    guard result.status == 0 else {
      throw FFmpegFrameExtractionError.failed(
        result.error.isEmpty ? "ffmpeg could not decode a frame." : result.error
      )
    }
    var frames: [VideoFrame] = []
    for index in 0..<maxFrames {
      let filename = String(format: "frame-%03d.jpg", index + 1)
      let outputURL = temporaryDirectory.appendingPathComponent(filename)
      guard FileManager.default.fileExists(atPath: outputURL.path) else {
        break
      }
      guard
        let imageSource = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(
          imageSource,
          0,
          [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        ),
        image.width > 0,
        image.height > 0
      else {
        continue
      }
      frames.append(
        VideoFrame(
          image: image,
          timestampSeconds: (Double(index) + 0.5) * bucketDuration
        ))
    }
    guard !frames.isEmpty else {
      throw FFmpegFrameExtractionError.failed("ffmpeg did not produce any decodable frames.")
    }
    return frames
  }

  private func run(_ executable: URL, arguments: [String]) throws -> ProcessResult {
    let process = Process()
    let output = Pipe()
    let error = Pipe()
    process.executableURL = executable
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = error
    do {
      try process.run()
    } catch {
      throw FFmpegFrameExtractionError.failed(
        "Could not run \(executable.lastPathComponent): \(error.localizedDescription)"
      )
    }
    process.waitUntilExit()
    return ProcessResult(
      status: process.terminationStatus,
      output: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        ?? "",
      error: String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    )
  }

  private static func executable(named name: String) -> URL? {
    let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
    for directory in path.split(separator: ":", omittingEmptySubsequences: false) {
      let directoryPath =
        directory.isEmpty ? FileManager.default.currentDirectoryPath : String(directory)
      let candidate = URL(fileURLWithPath: directoryPath).appendingPathComponent(name)
      if FileManager.default.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
    }
    return nil
  }

  private struct ProcessResult {
    let status: Int32
    let output: String
    let error: String
  }
}
