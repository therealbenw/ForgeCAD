import SwiftUI
import UniformTypeIdentifiers
import ForgeIO

struct ContentView: View {
    @Environment(DocumentStore.self) private var store

    var body: some View {
        NavigationSplitView {
            FeatureTreeView()
                .navigationTitle(store.document.name)
        } detail: {
            ViewportView()
                .ignoresSafeArea()
                .toolbar { toolbarContent }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button("Undo", systemImage: "arrow.uturn.backward") { store.undo() }
                .disabled(!store.canUndo)
            Button("Redo", systemImage: "arrow.uturn.forward") { store.redo() }
                .disabled(!store.canRedo)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Add box", systemImage: "cube") { store.addSampleBox() }
            if let stl = store.stlData() {
                ShareLink(
                    item: ExportFile(data: stl, name: store.document.name, type: .stl),
                    preview: SharePreview("\(store.document.name).stl")
                ) {
                    Label("Export STL", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

/// A `Transferable` wrapper so exports can go straight into the share sheet.
struct ExportFile: Transferable {
    var data: Data
    var name: String
    var type: UTType

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .stl) { $0.data }
            .suggestedFileName { "\($0.name).stl" }
    }
}

extension UTType {
    /// Apple's system-declared identifier for STL.
    static let stl = UTType(importedAs: "public.standard-tessellated-geometry-format", conformingTo: .threeDContent)
    static let forge = UTType(exportedAs: ForgeFileFormat.uniformTypeIdentifier, conformingTo: .json)
}
