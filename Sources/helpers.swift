import AppKit
import CoreGraphics
import CoreImage
import UniformTypeIdentifiers
import VideoToolbox
import Vision

func inputImagePathToURL(_ inputImagePath: String) -> URL {
  if inputImagePath.starts(with: "http") {
    return URL(string: inputImagePath)!
  } else {
    return URL(fileURLWithPath: inputImagePath)
  }
}

/// Extract the subject from the input image and return it as a CGImage
@available(macOS 14.0, *)
func extractSubject(inputImagePath: String, cropped: Bool) throws -> CGImage {
  let inputURL = inputImagePathToURL(inputImagePath)
  let request = VNGenerateForegroundInstanceMaskRequest()
  let handler = VNImageRequestHandler(url: inputURL)
  try handler.perform([request])
  guard let result = request.results?.first else {
    throw SeeVError.noSubjectFound
  }
  // This returns a CVPixelBuffer
  let maskBuffer = try result.generateMaskedImage(
    ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: cropped
  )
  var output: CGImage?
  let conversionCode = VTCreateCGImageFromCVPixelBuffer(maskBuffer, options: nil, imageOut: &output)
  guard conversionCode == 0 else {
    throw SeeVError.invalidCVPixelBuffer(conversionCode)
  }
  return output!
}

/// Detect faces in the input image and return the results as an array of VNFaceObservation
func extractFaces(inputImagePath: String) throws -> [VNFaceObservation] {
  let inputURL = inputImagePathToURL(inputImagePath)
  let request = VNDetectFaceRectanglesRequest()
  let handler = VNImageRequestHandler(url: inputURL)
  try handler.perform([request])
  guard let result = request.results else {
    return []
  }
  return result
}

@available(macOS 12.0, *)
func extractHumans(inputImagePath: String) throws -> [VNHumanObservation] {
  let inputURL = inputImagePathToURL(inputImagePath)
  let request = VNDetectHumanRectanglesRequest()
  let handler = VNImageRequestHandler(url: inputURL)
  try handler.perform([request])
  guard let result = request.results else {
    return []
  }
  return result
}

@available(macOS 10.15, *)
func extractText(inputImagePath: String, customWords: [String]? = []) throws
  -> [VNRecognizedTextObservation]
{
  let inputURL = inputImagePathToURL(inputImagePath)
  let request = VNRecognizeTextRequest()
  request.recognitionLevel = .accurate
  request.usesLanguageCorrection = true
  request.customWords = []
  let handler = VNImageRequestHandler(url: inputURL)
  try handler.perform([request])
  guard let result = request.results else {
    return []
  }
  return result
}

/// Draw bounding boxes into the image and save it to disk
@available(macOS 11.0, *)
func writeBoundingBoxes(inputImagePath: String, outputImagePath: String, boxes: [CGRect]) {
  let inputURL = inputImagePathToURL(inputImagePath)
  let inputImage = CIImage(contentsOf: inputURL)!
  let nsImage = NSImage(size: inputImage.extent.size, flipped: false) { _ in
    inputImage.draw(at: .zero, from: inputImage.extent, operation: .copy, fraction: 1.0)
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
