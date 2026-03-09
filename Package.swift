// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotifyMeHow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NotifyMeHow", targets: ["NotifyMeHow"])
    ],
    targets: [
        .executableTarget(
            name: "NotifyMeHow",
            dependencies: [],
            path: "Sources"
        )
    ]
)
