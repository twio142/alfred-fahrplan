// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "alfred-fahrplan",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/apple/swift-testing.git", from: "6.0.0"),
  ],
  targets: [
    .target(name: "FahrplanLib"),
    .executableTarget(name: "Fahrplan", dependencies: ["FahrplanLib"]),
    .testTarget(
      name: "FahrplanTests",
      dependencies: [
        "FahrplanLib",
        .product(name: "Testing", package: "swift-testing"),
      ]
    ),
  ]
)
