import ArgumentParser
import CommonCrypto
import Foundation
import Vision

struct SHA1: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Hashes the image using the SHA-1 algorithm."
  )

  @OptionGroup() var args: Options

  mutating func run() {
    do {
      printDict([
        "input": args.input,
        "sha1": try hashFile(inputImagePath: args.input),
      ])
    } catch {
      print("Error: \(error)")
    }
  }
}

func hashFile(inputImagePath: String) throws -> String {
  let inputURL = inputImagePathToURL(inputImagePath)
  let data = try Data(contentsOf: inputURL)
  var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
  data.withUnsafeBytes {
    _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
  }
  let hash = digest.map { String(format: "%02x", $0) }.joined()
  return hash
}
