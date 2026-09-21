import SwiftUI

struct NetworkStatusBanner: View {
    let state: NetworkMonitor.ConnectionState

    var body: some View {
        Group {
            switch state {
            case .checking:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking connection…")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)

            case .offline:
                HStack(spacing: 9) {
                    Image(systemName: "wifi.slash")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("You’re offline")
                            .font(.caption.weight(.semibold))
                        Text("Local chores still work. Online features will retry when you reconnect.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.orange.opacity(0.25), lineWidth: 1)
                )

            case .online:
                EmptyView()
            }
        }
    }
}
