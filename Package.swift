// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YouFixIt",
    // 14.4: @Observable, MenuBarExtra(.window), SMAppService, CoreAudio process objects all exist here.
    platforms: [.macOS("14.4")],
    targets: [
        .executableTarget(name: "YouFixIt")
    ]
)
