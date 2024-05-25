import ArgumentParser
import Foundation
import Vision

@available(macOS 11.0, *)
struct Poses: ParsableCommand {
  static var configuration: CommandConfiguration = CommandConfiguration(
    abstract: "Detects the poses of humans in an image.",
    discussion: "The JSON output."
  )

  @OptionGroup() var args: Options

  mutating func run() {
    do {
      let request = VNDetectHumanBodyPoseRequest()
      let poses: [VNHumanBodyPoseObservation] =
        try performRequest(
          request: request, inputImagePath: args.input)
      let posesDict: [String: Any] = [
        "input": args.input,
        "poses": poses.map { pose in
          [
            "joints": pose.availableJointNames.map {
              [
                "name": $0.rawValue,
                "x": try! pose.recognizedPoint($0).location.x,
                "y": try! pose.recognizedPoint($0).location.y,
                "confidence": try! pose.recognizedPoint($0).confidence,
              ]
            }
          ]
        },
      ]
      printDict(posesDict)
      let points: [CGPoint] = poses.flatMap { pose in
        pose.availableJointNames.map {
          try! pose.recognizedPoint($0).location
        }
      }
      var lines: [(CGPoint, CGPoint)] = []
      for pose in poses {
        func addPair(
          _ A: VNHumanBodyPoseObservation.JointName, _ B: VNHumanBodyPoseObservation.JointName
        ) {
          if pose.availableJointNames.contains(A) && pose.availableJointNames.contains(B) {
            let pointA = try! pose.recognizedPoint(A)
            let pointB = try! pose.recognizedPoint(B)
            if pointA.confidence < 0.5 || pointB.confidence < 0.5 {
              return
            }
            lines.append(
              (
                pointA.location,
                pointB.location
              ))
          }
        }
        addPair(.neck, .root)
        addPair(.leftShoulder, .rightShoulder)
        addPair(.leftShoulder, .leftElbow)
        addPair(.rightShoulder, .rightElbow)
        addPair(.leftElbow, .leftWrist)
        addPair(.rightElbow, .rightWrist)
        addPair(.leftHip, .rightHip)
        addPair(.leftHip, .leftKnee)
        addPair(.rightHip, .rightKnee)
        addPair(.leftKnee, .leftAnkle)
        addPair(.rightKnee, .rightAnkle)
      }
      if args.output != nil {
        draw(
          inputImagePath: args.input, outputImagePath: args.output!, points: points,
          boxes: [], lines: lines)
      }
    } catch {
      print("Error: \(error)")
    }
  }
}
