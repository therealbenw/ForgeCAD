import SwiftUI
import ForgeDocument

/// The parametric history, one row per feature, with regeneration errors
/// surfaced inline the way desktop CAD flags a broken feature.
struct FeatureTreeView: View {
    @Binding var document: Document
    @Environment(PartSession.self) private var session
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        @Bindable var session = session
        List(selection: $session.selectedFeature) {
            Section("Features") {
                ForEach(document.features, id: \.id) { feature in
                    row(for: feature)
                        .tag(feature.id)
                }
                .onDelete { offsets in
                    let ids = offsets.map { document.features[$0].id }
                    session.commit("Delete Feature", on: $document, undoManager: undoManager) { doc in
                        ids.forEach { doc.remove($0) }
                    }
                }
            }
            if !session.result.bodies.isEmpty {
                Section("Bodies") {
                    ForEach(Array(session.result.bodies.enumerated()), id: \.offset) { index, body in
                        Label("Body \(index + 1) · \(body.solid.faces.count) faces", systemImage: "cube.fill")
                    }
                }
            }
        }
        .overlay {
            if document.features.isEmpty {
                ContentUnavailableView(
                    "No features yet",
                    systemImage: "square.on.square.dashed",
                    description: Text("Tap “Add box” to sketch a rectangle and extrude it.")
                )
            }
        }
    }

    @ViewBuilder
    private func row(for feature: Feature) -> some View {
        let error = session.result.errors.first { $0.feature == feature.id }
        HStack {
            Label(feature.name, systemImage: icon(for: feature))
            Spacer()
            if let error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(error.message)
            }
        }
    }

    private func icon(for feature: Feature) -> String {
        switch feature {
        case .sketch: return "pencil.and.ruler"
        case .extrude: return "arrow.up.and.down.square"
        }
    }
}
