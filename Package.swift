// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KehaiApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "KehaiApp",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources"
        )
    ]
)
