import Foundation

/// Adds fail-closed handling for HTTP(S) requests routed through Foundation's
/// shared/default URL Loading System. This is defense in depth, not a firewall
/// for arbitrary custom session configurations.
final class OfflineNetworkGuard: URLProtocol {
    static func install() {
        URLProtocol.registerClass(OfflineNetworkGuard.self)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(
            self,
            didFailWithError: URLError(.notConnectedToInternet)
        )
    }

    override func stopLoading() {}
}
