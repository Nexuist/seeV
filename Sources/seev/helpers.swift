import AppKit
import CoreGraphics
import CoreImage
import UniformTypeIdentifiers
import VideoToolbox
import Vision

enum SeeVError: Error {
  case noSubjectFound
  case noFeaturePrintFound
  case invalidCVPixelBuffer(Int32)
  case outputError
  case invalidURL
}

/// Convert the input image path to a URL
func inputImagePathToURL(_ inputImagePath: String) -> URL {
  if inputImagePath.starts(with: "http") {
    return URL(string: inputImagePath)!
  } else {
    return URL(fileURLWithPath: inputImagePath)
  }
}

func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
  let dotProduct = zip(a, b).map(*).reduce(0, +)
  let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
  let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
  return dotProduct / (magnitudeA * magnitudeB)
}

/// Crop the input image using the specified bounding box and return the result as a CGImage
func cropImage(inputImagePath: String, boundingBox: CGRect) throws -> CGImage {
  let inputURL = inputImagePathToURL(inputImagePath)
  return try cropImage(inputURL: inputURL, boundingBox: boundingBox)
}

func cropImage(inputURL: URL, boundingBox: CGRect) throws -> CGImage {
  guard let inputImage = CIImage(contentsOf: inputURL) else {
    throw SeeVError.outputError
  }
  let adjustedBoundingBox = CGRect(
    x: boundingBox.origin.x * inputImage.extent.width,
    y: boundingBox.origin.y * inputImage.extent.height,
    width: boundingBox.width * inputImage.extent.width,
    height: boundingBox.height * inputImage.extent.height
  )
  let croppedImage = inputImage.cropped(to: adjustedBoundingBox)
  let context = CIContext(options: nil)
  guard let image = context.createCGImage(croppedImage, from: croppedImage.extent) else {
    throw SeeVError.outputError
  }
  return image
}

/// Crop a CGImage using a normalized Vision bounding box.
func cropImage(input: CGImage, boundingBox: CGRect) throws -> CGImage {
  let inputImage = CIImage(cgImage: input)
  let adjustedBoundingBox = CGRect(
    x: boundingBox.origin.x * inputImage.extent.width,
    y: boundingBox.origin.y * inputImage.extent.height,
    width: boundingBox.width * inputImage.extent.width,
    height: boundingBox.height * inputImage.extent.height
  )
  let croppedImage = inputImage.cropped(to: adjustedBoundingBox)
  let context = CIContext(options: nil)
  guard let image = context.createCGImage(croppedImage, from: croppedImage.extent) else {
    throw SeeVError.outputError
  }
  return image
}

@available(macOS 11.0, *)
func draw(
  inputImagePath: String,
  outputImagePath: String,
  points: [CGPoint],
  boxes: [CGRect],
  lines: [(CGPoint, CGPoint)]
) {
  let inputURL = inputImagePathToURL(inputImagePath)
  let inputImage = CIImage(contentsOf: inputURL)!
  let nsImage = NSImage(size: inputImage.extent.size, flipped: false) { _ in
    inputImage.draw(at: .zero, from: inputImage.extent, operation: .copy, fraction: 1.0)
    for point in points {
      // Draw circles
      let rect = CGRect(
        x: point.x * inputImage.extent.width - 2,
        y: point.y * inputImage.extent.height - 2,
        width: 4,
        height: 4
      )
      let path = NSBezierPath(ovalIn: rect)
      path.lineWidth = 2.0
      NSColor.red.setStroke()
      path.stroke()
    }
    for box in boxes {
      let rect = CGRect(
        x: box.origin.x * inputImage.extent.width,
        y: box.origin.y * inputImage.extent.height,
        width: box.width * inputImage.extent.width,
        height: box.height * inputImage.extent.height
      )
      let path = NSBezierPath(rect: rect)
      path.lineWidth = 2.0
      NSColor.red.setStroke()
      path.stroke()
    }
    for (start, end) in lines {
      let path = NSBezierPath()
      path.move(
        to: CGPoint(x: start.x * inputImage.extent.width, y: start.y * inputImage.extent.height))
      path.line(
        to: CGPoint(x: end.x * inputImage.extent.width, y: end.y * inputImage.extent.height))
      path.lineWidth = 2.0
      NSColor.red.setStroke()
      path.stroke()
    }
    return true
  }
  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
  saveOutput(output: cgImage, outputImagePath: outputImagePath)
}

/// Save the output image to the specified path
@available(macOS 11.0, *)
func saveOutput(output: CGImage, outputImagePath: String) {
  let outputURL = URL(fileURLWithPath: outputImagePath)
  let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, output, nil)
  CGImageDestinationFinalize(destination)
}

/// Write the output image to stdout
func writeOutput(output: CGImage) throws {
  let bitmap = NSBitmapImageRep(cgImage: output)
  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    throw SeeVError.outputError
  }
  let stdout = FileHandle.standardOutput
  stdout.write(png)
}

/// Print a human-readable status message to stderr.
func printStatus(_ message: String) {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
}

/// Print a JSON dictionary to stdout
func printDict(_ dict: [String: Any]) {
  printJSON(dict)
}

/// Print any JSON value to stdout
func printJSON(_ value: Any) {
  let jsonData = try! JSONSerialization.data(
    withJSONObject: value,
    options: [.prettyPrinted, .fragmentsAllowed]
  )
  print(String(data: jsonData, encoding: .utf8)!)
}
