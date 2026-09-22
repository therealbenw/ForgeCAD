import SwiftUI
import ForgeDocument

/// The parametric history, one row per feature, with regeneration errors
/// surfaced inline the way desktop CAD flags a broken feature.
struct FeatureTreeView: View {
    @Environment(DocumentStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selectedFeature) {
            Section("Features") {
                ForEach(store.document.features, id: \.id) { feature in
                    row(for: feature)
                        .tag(feature.id)
                }
                .onDelete { offsets in
                    let ids = offsets.map { store.document.features[$0].id }
                    store.commit { doc in ids.forEach { doc.remove($0) } }
                }
            }
            if !store.result.bodies.isEmpty {
                Section("Bodies") {
                    ForEach(Array(store.result.bodies.enumerated()), id: \.offset) { index, body in
                        Label("Body \(index + 1) · \(body.solid.faces.count) faces", systemImage: "cube.fill")
                    }
                }
            }
        }
        .overlay {
            if store.document.features.isEmpty {
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
        let error = store.result.errors.first { $0.feature == feature.id }
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
