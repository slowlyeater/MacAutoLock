import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var model: WatchAppModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: model.isReachable ? "lock.shield.fill" : "lock.shield")
                .font(.title)
                .foregroundStyle(model.isReachable ? .green : .secondary)

            Text("Mac AutoLock")
                .font(.headline)

            Text(model.status)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                model.lockNow()
            } label: {
                Label("Lock", systemImage: "lock.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.isReachable)
        }
        .padding()
    }
}
