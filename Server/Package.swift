// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "NestServer", platforms: [.macOS(.v13)], dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.110.0")
], targets: [.executableTarget(name: "NestServer", dependencies: [.product(name: "Vapor", package: "vapor")])])
