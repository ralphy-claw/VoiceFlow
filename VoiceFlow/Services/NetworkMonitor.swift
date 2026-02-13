import Network
import Foundation

/// Monitors network reachability using NWPathMonitor (#40).
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else {
                    self?.connectionType = nil
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Resilient URLSession Extension (#40)

extension URLSession {
    /// Perform a data task with timeout and retry logic for 429/503 errors.
    func resilientData(for request: URLRequest, maxRetries: Int = 3, timeoutInterval: TimeInterval = 30) async throws -> (Data, URLResponse) {
        var mutableRequest = request
        mutableRequest.timeoutInterval = timeoutInterval
        
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await self.data(for: mutableRequest)
                
                if let http = response as? HTTPURLResponse {
                    switch http.statusCode {
                    case 429, 503:
                        // Retry with exponential backoff
                        let delay = pow(2.0, Double(attempt)) * 0.5
                        try await Task.sleep(for: .seconds(delay))
                        lastError = OpenAIError.apiError("Server returned \(http.statusCode)")
                        continue
                    default:
                        return (data, response)
                    }
                }
                
                return (data, response)
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }
        
        throw lastError ?? OpenAIError.networkError(URLError(.timedOut))
    }
}
