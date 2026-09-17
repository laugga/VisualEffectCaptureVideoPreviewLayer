// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LAUCaptureVideoPreviewLayer",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LAUCaptureVideoPreviewLayer",
            targets: ["LAUCaptureVideoPreviewLayer"]
        )
    ],
    targets: [
        // Types shared between the library and the Metal shading language sources,
        // so that the uniform and vertex layouts are guaranteed to match on both sides
        .target(
            name: "LAUCaptureVideoPreviewLayerShaderTypes"
        ),
        .target(
            name: "LAUCaptureVideoPreviewLayer",
            dependencies: ["LAUCaptureVideoPreviewLayerShaderTypes"]
        ),
        .testTarget(
            name: "LAUCaptureVideoPreviewLayerTests",
            dependencies: ["LAUCaptureVideoPreviewLayer"],
            resources: [
                .process("Samples.xcassets")
            ]
        )
    ]
)
