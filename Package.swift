// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LMCaptureVideoPreviewLayer",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LMCaptureVideoPreviewLayer",
            targets: ["LMCaptureVideoPreviewLayer"]
        )
    ],
    targets: [
        // Types shared between the library and the Metal shading language sources,
        // so that the uniform and vertex layouts are guaranteed to match on both sides
        .target(
            name: "LMCaptureVideoPreviewLayerShaderTypes"
        ),
        .target(
            name: "LMCaptureVideoPreviewLayer",
            dependencies: ["LMCaptureVideoPreviewLayerShaderTypes"]
        ),
        .testTarget(
            name: "LMCaptureVideoPreviewLayerTests",
            dependencies: ["LMCaptureVideoPreviewLayer"],
            resources: [
                .process("Samples.xcassets")
            ]
        )
    ]
)
