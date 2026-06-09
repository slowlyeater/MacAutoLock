// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacAutoLock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacAutoLockShared", targets: ["MacAutoLockShared"]),
        .executable(name: "MacAutoLockMac", targets: ["MacAutoLockMac"])
    ],
    targets: [
        .target(
            name: "MacAutoLockShared",
            path: "Sources/MacAutoLockShared"
        ),
        .executableTarget(
            name: "MacAutoLockMac",
            dependencies: ["MacAutoLockShared"],
            path: "Apps/MacAutoLockMac"
        ),
        .testTarget(
            name: "MacAutoLockSharedTests",
            dependencies: ["MacAutoLockShared"],
            path: "Tests/MacAutoLockSharedTests"
        )
    ]
)
