import SwiftUI
import NestUI

@main
struct NestPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            NestRoot(inMemory: ProcessInfo.processInfo.arguments.contains("--in-memory"))
                .frame(minWidth: 390, idealWidth: 430, minHeight: 700, idealHeight: 900)
        }.defaultSize(width: 430, height: 900)
    }
}
