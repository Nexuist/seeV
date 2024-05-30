// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "seev",
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "seev",
      dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")],
      resources: [.copy("./OpenNSFW.mlmodelc")]
    )
  ]
)
