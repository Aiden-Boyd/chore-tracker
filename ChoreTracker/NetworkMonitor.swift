import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    enum ConnectionState: Equatable {
        case checking
        case online
        case offline
    }

    @Published private(set) var state: ConnectionState = .checking

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.newlifemedia.choretracker.network")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.state = path.status == .satisfied ? .online : .offline
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
