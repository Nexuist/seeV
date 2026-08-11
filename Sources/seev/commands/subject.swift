import AppKit
import ArgumentParser
import CoreGraphics
import CoreImage
import Foundation
import UniformTypeIdentifiers
import VideoToolbox
import Vision

@available(macOS 14.0, *)
struct Subject: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Removes the background from an image.",
    discussion:
      "The output image will have the background removed. If the --cropped flag is provided, the output will be cropped to the subject's bounding box. Without --output, the PNG is written to stdout."
  )

  @OptionGroup var args: ImageOutputOptions
  @Flag(name: [.customShort("c"), .long], help: "Crop the output to the subject's bounding box")
  var cropped: Bool = false

  mutating func run() throws {
    guard !isVideoInput(args.input) else {
      throw ValidationError("Subject extraction supports images only.")
    }

    printStatus("Removing background from \(args.input)...")
    let output = try extractSubject(inputImagePath: args.input, cropped: cropped)
    if let outputPath = args.output {
      saveOutput(output: output, outputImagePath: outputPath)
      printStatus("Saved to \(outputPath)")
    } else {
      try writeOutput(output: output)
    }
  }
}

/// Extract the subject from the input image and return it as a CGImage
@available(macOS 14.0, *)
func extractSubject(inputImagePath: String, cropped: Bool) throws -> CGImage {
  let inputURL = inputImagePathToURL(inputImagePath)
  let request = VNGenerateForegroundInstanceMaskRequest()
  let handler = VNImageRequestHandler(url: inputURL)
  try handler.perform([request])
  guard let result: VNInstanceMaskObservation = request.results?.first else {
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
