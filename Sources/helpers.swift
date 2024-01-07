import AppKit
import CoreGraphics
import CoreImage
import UniformTypeIdentifiers
import VideoToolbox
import Vision

@available(macOS 14.0, *)
func extractSubject(inputImagePath: String, cropped: Bool) throws -> CGImage {
  let inputURL = URL(fileURLWithPath: inputImagePath)
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

@available(macOS 11.0, *)
func saveOutput(output: CGImage, outputImagePath: String) {
  let outputURL = URL(fileURLWithPath: outputImagePath)
  let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, output, nil)
  CGImageDestinationFinalize(destination)
}

func writeOutput(output: CGImage) throws {
  let bitmap = NSBitmapImageRep(cgImage: output)
  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    throw SeeVError.outputError
  }
  let stdout = FileHandle.standardOutput
  stdout.write(png)
}
