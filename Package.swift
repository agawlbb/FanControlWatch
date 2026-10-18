// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FanControlCore", platforms: [.watchOS(.v10), .macOS(.v13)], products: [.library(name: "FanControlCore", targets: ["FanControlCore"])], targets: [.target(name: "FanControlCore"), .testTarget(name: "FanControlCoreTests", dependencies: ["FanControlCore"])])
