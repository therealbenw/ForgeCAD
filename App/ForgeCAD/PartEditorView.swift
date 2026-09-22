import SwiftUI
import UniformTypeIdentifiers
import ForgeDocument

/// Editor for one open `.forge` part: feature tree on the left, viewport on
/// the right. Owns the `PartSession` for the document it was given.
struct PartEditorView: View {
    @Binding var document: Document
    @State private var session = PartSession()
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationSplitView {
            FeatureTreeView(document: $document)
                .navigationTitle(document.name)
        } detail: {
            ViewportView()
                .ignoresSafeArea()
                .toolbar { toolbarContent }
        }
        .environment(session)
        .onChange(of: document, initial: true) { _, current in
            session.regenerate(current)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button("Undo", systemImage: "arrow.uturn.backward") { undoManager?.undo() }
                .disabled(!(undoManager?.canUndo ?? false))
            Button("Redo", systemImage: "arrow.uturn.forward") { undoManager?.redo() }
                .disabled(!(undoManager?.canRedo ?? false))
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Add box", systemImage: "cube") {
                session.addSampleBox(on: $document, undoManager: undoManager)
            }
            if let stl = session.stlData(name: document.name) {
                ShareLink(
                    item: ExportFile(data: stl, name: document.name),
                    preview: SharePreview("\(document.name).stl")
                ) {
                    Label("Export STL", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

/// A `Transferable` wrapper so STL exports can go straight into the share sheet.
struct ExportFile: Transferable {
    var data: Data
    var name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .stl) { $0.data }
            .suggestedFileName { "\($0.name).stl" }
    }
}
