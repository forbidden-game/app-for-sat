import Foundation

public enum UserFacingError {
    public static func message(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return message(for: urlError)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            return message(for: URLError(code))
        }

        return error.localizedDescription
    }

    private static func message(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "网络未连接。请检查 Wi-Fi/蜂窝网络后重试。"
        case .timedOut:
            return "请求超时。请检查网络后重试。"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "无法连接服务器。请检查网络或 DNS/VPN 设置后重试。"
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
            return "TLS/证书连接失败。若你在校园网/公司网/代理环境，可能会拦截 HTTPS。请尝试切换网络或开启 VPN。"
        default:
            return error.localizedDescription
        }
    }
}
