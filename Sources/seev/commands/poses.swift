import ArgumentParser
import CoreGraphics
import Vision

@available(macOS 15.0, *)
struct Poses: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Detects human poses in an image or representative video frames.",
    discussion: "The JSON output."
  )

  @OptionGroup var args: MediaOutputOptions

  mutating func run() async throws {
    try args.validateImageOutput()

    let result = try await analyzeMedia(
      input: args.input,
      maxFrames: args.maxFrames,
      operationName: "poses",
      analysis: poseAnalysis
    )
    printDict(result.output)

    if let poses = result.imageArtifact, let output = args.output {
      draw(
        inputImagePath: args.input,
        outputImagePath: output,
        points: poses.flatMap(posePoints),
        boxes: [],
        lines: poses.flatMap(poseLines)
      )
    }
  }
}

private func posePoints(_ pose: VNHumanBodyPoseObservation) -> [CGPoint] {
  pose.availableJointNames.compactMap { jointName in
    try? pose.recognizedPoint(jointName).location
  }
}

private func poseLines(_ pose: VNHumanBodyPoseObservation) -> [(CGPoint, CGPoint)] {
  let pairs: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
    (.neck, .root),
    (.leftShoulder, .rightShoulder),
    (.leftShoulder, .leftElbow),
    (.rightShoulder, .rightElbow),
    (.leftElbow, .leftWrist),
    (.rightElbow, .rightWrist),
    (.leftHip, .rightHip),
    (.leftHip, .leftKnee),
    (.rightHip, .rightKnee),
    (.leftKnee, .leftAnkle),
    (.rightKnee, .rightAnkle),
  ]
  return pairs.compactMap { firstJoint, secondJoint in
    guard
      let pointA = try? pose.recognizedPoint(firstJoint),
      let pointB = try? pose.recognizedPoint(secondJoint),
      pointA.confidence >= 0.5,
      pointB.confidence >= 0.5
    else {
      return nil
    }
    return (pointA.location, pointB.location)
  }
}
