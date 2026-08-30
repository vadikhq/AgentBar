// swift-tools-version: 6.2
import Foundation
import PackageDescription

let sweetCookieKitPath = "../SweetCookieKit"
let useLocalSweetCookieKit =
    ProcessInfo.processInfo.environment["AGENTBAR_USE_LOCAL_SWEETCOOKIEKIT"] == "1"
let sweetCookieKitDependency: Package.Dependency =
    useLocalSweetCookieKit && FileManager.default.fileExists(atPath: sweetCookieKitPath)
    ? .package(path: sweetCookieKitPath)
    : .package(url: "https://github.com/steipete/SweetCookieKit", from: "0.5.2")

let sqlite3LibDir = ProcessInfo.processInfo.environment["AGENTBAR_SQLITE3_LIB_DIR"]?
    .trimmingCharacters(in: .whitespacesAndNewlines)
let sqlite3LinkerSettings: [LinkerSetting] = if let sqlite3LibDir, !sqlite3LibDir.isEmpty {
    [.unsafeFlags(["-L\(sqlite3LibDir)"], .when(platforms: [.linux]))]
} else {
    []
}

let package = Package(
    name: "AgentBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: {
        var products: [Product] = [
            .library(name: "AgentBarCore", targets: ["AgentBarCore"]),
            .executable(name: "AgentBarCLI", targets: ["AgentBarCLI"]),
            // Offline adaptive-refresh replay harness. Keep the supporting library package-internal.
            .executable(name: "AdaptiveReplayCLI", targets: ["AdaptiveReplayCLI"]),
        ]

        #if os(macOS)
        products.append(contentsOf: [
            .executable(name: "AgentBar", targets: ["AgentBar"]),
            .executable(name: "AgentBarClaudeWatchdog", targets: ["AgentBarClaudeWatchdog"]),
            .executable(name: "AgentBarWidget", targets: ["AgentBarWidget"]),
            .executable(name: "AgentBarClaudeWebProbe", targets: ["AgentBarClaudeWebProbe"]),
        ])
        #endif

        return products
    }(),
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.3"),
        .package(url: "https://github.com/steipete/Commander", from: "0.2.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.13.2"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
        .package(url: "https://github.com/zats/Vortex", revision: "ef5392088d4aeb255c4eee83157dbdafcd31bf07"),
        sweetCookieKitDependency,
    ],
    targets: {
        var targets: [Target] = [
            .target(
                name: "CQuickJS",
                path: "Sources/CQuickJS",
                exclude: ["README.md", "LICENSE"],
                publicHeadersPath: "include",
                cSettings: [
                    .define("_GNU_SOURCE"),
                ],
                linkerSettings: [
                    .linkedLibrary("m", .when(platforms: [.linux])),
                ]),
            // Both glibc and static-musl CLI builds use this target; the module map supplies sqlite3 linkage.
            .systemLibrary(
                name: "CSQLite3",
                providers: [
                    .apt(["libsqlite3-dev"]),
                    .brew(["sqlite3"]),
                ]),
            .target(
                name: "AgentBarCore",
                dependencies: [
                    "CQuickJS",
                    .target(name: "CSQLite3", condition: .when(platforms: [.linux])),
                    .product(name: "Crypto", package: "swift-crypto"),
                    .product(name: "Logging", package: "swift-log"),
                    .product(name: "SweetCookieKit", package: "SweetCookieKit"),
                ],
                resources: [
                    .process("Resources"),
                ],
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ],
                linkerSettings: sqlite3LinkerSettings + [
                    .linkedFramework("JavaScriptCore", .when(platforms: [.macOS])),
                ]),
            .executableTarget(
                name: "AgentBarCLI",
                dependencies: [
                    "AgentBarCore",
                    .product(name: "Commander", package: "Commander"),
                    .product(name: "Crypto", package: "swift-crypto"),
                ],
                path: "Sources/AgentBarCLI",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ],
                linkerSettings: sqlite3LinkerSettings),
            // Crash-test subprocess: tests SIGKILL it mid-save to prove the cost store's
            // save cycle is atomic. Not shipped; built only as a test dependency.
            .executableTarget(
                name: "AgentBarCostStoreCrashProbe",
                dependencies: ["AgentBarCore"],
                path: "Sources/AgentBarCostStoreCrashProbe",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ],
                linkerSettings: sqlite3LinkerSettings),
            // Sole owner of the adaptive refresh decision table. Package-internal so the app and
            // offline replay tool share behavior without publishing another library product.
            .target(
                name: "AdaptiveRefreshCore",
                dependencies: [],
                path: "Sources/AdaptiveRefreshCore",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            // Offline adaptive-refresh replay harness: pure Foundation,
            // no AgentBar/AgentBarCore dependency, so it builds anywhere AgentBarCore does.
            .target(
                name: "AdaptiveReplayKit",
                dependencies: ["AdaptiveRefreshCore"],
                path: "Sources/AdaptiveReplayKit",
                exclude: ["README.md"],
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "AdaptiveReplayCLI",
                dependencies: ["AdaptiveReplayKit"],
                path: "Sources/AdaptiveReplayCLI",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .testTarget(
                name: "AdaptiveReplayCLITests",
                dependencies: ["AdaptiveReplayCLI", "AdaptiveReplayKit"],
                path: "Tests/AdaptiveReplayCLITests",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                    .enableExperimentalFeature("SwiftTesting"),
                ]),
            .testTarget(
                name: "AdaptiveReplayKitTests",
                dependencies: ["AdaptiveRefreshCore", "AdaptiveReplayKit"],
                path: "Tests/AdaptiveReplayKitTests",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                    .enableExperimentalFeature("SwiftTesting"),
                ]),
            .testTarget(
                name: "AgentBarPluginTests",
                dependencies: ["AgentBarCore"],
                path: "TestsPlugin",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                    .enableExperimentalFeature("SwiftTesting"),
                ]),
            .testTarget(
                name: "AgentBarLinuxTests",
                dependencies: [
                    "AgentBarCore",
                    "AgentBarCLI",
                    .target(name: "CSQLite3", condition: .when(platforms: [.linux])),
                ],
                path: "TestsLinux",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                    .enableExperimentalFeature("SwiftTesting"),
                ]),
        ]

        #if os(macOS)
        targets.append(contentsOf: [
            .executableTarget(
                name: "AgentBarClaudeWatchdog",
                dependencies: [],
                path: "Sources/AgentBarClaudeWatchdog",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "AgentBar",
                dependencies: [
                    .product(name: "Sparkle", package: "Sparkle"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "Vortex", package: "Vortex"),
                    "AdaptiveRefreshCore",
                    "AgentBarCore",
                ],
                path: "Sources/AgentBar",
                resources: [
                    .process("Resources"),
                ],
                swiftSettings: [
                    // Opt into Swift 6 strict concurrency (approachable migration path).
                    .enableUpcomingFeature("StrictConcurrency"),
                    .define("ENABLE_SPARKLE"),
                ]),
            .executableTarget(
                name: "AgentBarWidget",
                dependencies: ["AgentBarCore"],
                path: "Sources/AgentBarWidget",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "AgentBarClaudeWebProbe",
                dependencies: ["AgentBarCore"],
                path: "Sources/AgentBarClaudeWebProbe",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
        ])

        targets.append(.testTarget(
            name: "AgentBarTests",
            dependencies: ["AgentBar", "AgentBarCore", "AgentBarCLI", "AgentBarCostStoreCrashProbe", "AgentBarWidget"],
            path: "Tests",
            exclude: [
                "AdaptiveReplayCLITests",
                "AdaptiveReplayKitTests",
                "AgentBarTests/ProviderPluginDetailsParityTests.swift",
                "AgentBarTests/ProviderPluginExtensionParityTests.swift",
                "AgentBarTests/ProviderPluginParityTests.swift",
                "AgentBarTests/ProviderPluginRuntimeTests.swift",
                "AgentBarTests/Sub2APIPluginGoldenTests.swift",
            ],
            resources: [
                .copy("AgentBarTests/Fixtures"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]))
        #endif

        return targets
    }())
