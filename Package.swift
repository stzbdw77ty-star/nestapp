// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [.library(name: "NestCore", targets: ["NestCore"]), .library(name: "NestServices", targets: ["NestServices"])]
var targets: [Target] = [
    .target(name: "NestCore"),
    .testTarget(name: "NestCoreTests", dependencies: ["NestCore"])
]
#if os(Linux)
targets += [
    .target(name: "NestServices", dependencies: ["NestCore"], exclude: ["SessionKeychain.swift"]),
    .testTarget(name: "NestServicesTests", dependencies: ["NestCore", "NestServices"])
]
#else
products += [
    .library(name: "NestUI", targets: ["NestUI"]),
    .executable(name: "NestPreview", targets: ["NestPreview"])
]
targets += [
    .target(name: "NestServices", dependencies: ["NestCore"]),
    .target(name: "NestUI", dependencies: ["NestCore", "NestServices"]),
    .executableTarget(name: "NestPreview", dependencies: ["NestUI"]),
    .testTarget(name: "NestServicesTests", dependencies: ["NestCore", "NestServices"]),
    .testTarget(name: "NestUITests", dependencies: ["NestCore", "NestUI"])
]
#endif
let package = Package(
    name: "Nest", platforms: [.iOS(.v17), .macOS(.v14)],
    products: products, targets: targets
)
