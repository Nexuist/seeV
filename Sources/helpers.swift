import CoreGraphics
import CoreImage
import UniformTypeIdentifiers
import VideoToolbox
import Vision

@available(macOS 14.0, *)
func extractSubject(inputImagePath: String, outputImagePath: String) throws {
  let inputURL = URL(fileURLWithPath: inputImagePath)
  let outputURL = URL(fileURLWithPath: outputImagePath)
  let request = VNGenerateForegroundInstanceMaskRequest()
  let handler = VNImageRequestHandler(url: inputURL)
  try handler.perform([request])
  guard let result = request.results?.first else {
    throw SeeVError.noSubjectFound
  }
  // This returns a CVPixelBuffer
  let maskBuffer = try result.generateMaskedImage(
    ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: false
  )
  var output: CGImage?
  let conversionCode = VTCreateCGImageFromCVPixelBuffer(maskBuffer, options: nil, imageOut: &output)
  guard conversionCode == 0 else {
    throw SeeVError.invalidCVPixelBuffer(conversionCode)
  }
  let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, output!, nil)
  CGImageDestinationFinalize(destination)
}
