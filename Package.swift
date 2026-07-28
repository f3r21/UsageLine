// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UsageLine",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "UsageLine", targets: ["UsageLine"]),
    ],
    targets: [
        .executableTarget(
            name: "UsageLine",
            path: "Sources/UsageLine"
        )
    ]
)
