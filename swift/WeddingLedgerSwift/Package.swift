// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WeddingLedgerSwift",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WeddingLedgerSwift", targets: ["WeddingLedgerSwift"])
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite"
        ),
        .systemLibrary(
            name: "CCommonCrypto"
        ),
        .executableTarget(
            name: "WeddingLedgerSwift",
            dependencies: ["CSQLite", "CCommonCrypto"]
        )
    ]
)
