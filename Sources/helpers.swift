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
@available(macOS 13.0, *)
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

/// Write bounding boxes around the detected faces in the input image
@available(macOS 11.0, *)
func writeBoundingBoxes(inputImagePath: String, outputImagePath: String, faces: [VNFaceObservation])
{
  // let inputURL = URL(fileURLWithPath: inputImagePath)
  // let inputImage = CIImage(contentsOf: inputURL)
  // let context = CIContext()
  // let graphics = NSGraphicsContext()
  // for face in faces {
  //   let boundingBox = face.boundingBox
  //   let rect = CGRect(
  //     x: boundingBox.origin.x * inputImage.extent.width,
  //     y: (1 - boundingBox.origin.y - boundingBox.height) * inputImage.extent.height,
  //     width: boundingBox.width * inputImage.extent.width,
  //     height: boundingBox.height * inputImage.extent.height
  //   )
  //   let path = NSBezierPath(rect: rect)
  //   path.lineWidth = 5.0
  //   NSColor.red.setStroke()
  //   path.stroke()
  // }
  // graphics.flushGraphics()
  // let output = context.createCGImage(inputImage, from: inputImage.extent)!
  // saveOutput(output: output, outputImagePath: outputImagePath)
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
