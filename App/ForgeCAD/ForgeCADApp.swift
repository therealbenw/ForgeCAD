import SwiftUI

@main
struct ForgeCADApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ForgeFileDocument()) { file in
            PartEditorView(document: file.$document.part)
        }
    }
}
