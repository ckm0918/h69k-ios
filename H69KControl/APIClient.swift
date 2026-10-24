import Foundation
import Combine
import SwiftUI

// MARK: - 设置存储（UserDefaults）
final class AppSettings: ObservableObject {
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    @Published var token: String {
        didSet { UserDefaults.standard.set(token, forKey: "token") }
    }
    @Published var themeMode: Int {
        didSet { UserDefaults.standard.set(themeMode, forKey: "themeMode") }
    }

    static let shared = AppSettings()

    init() {
        let def = UserDefaults.standard
        serverURL = def.string(forKey: "serverURL") ?? "http://192.168.8.1:8788"
        token = def.string(forKey: "token") ?? ""
        themeMode = def.object(forKey: "themeMode") as? Int ?? 0
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case 1: return .light
        case 2: return nil
        default: return .dark
        }
    }

    var normalizedURL: String {
        var u = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while u.hasSuffix("/") { u = String(u.dropLast()) }
        return u
    }

    var isValid: Bool {
        !normalizedURL.isEmpty && !token.isEmpty
    }
}

// MARK: - API 客户端（URLSession + completion，iOS 14 兼容）
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    struct APIError: LocalizedError {
        let msg: String
        var errorDescription: String? { msg }
    }

    // MARK: 基础请求
    private func request(path: String, method: String = "GET", body: [String: Any]? = nil,
                         timeout: TimeInterval = 10,
                         completion: @escaping (Result<Data, Error>) -> Void) {
        let s = AppSettings.shared
        guard s.isValid else {
            completion(.failure(APIError(msg: "请先在设置中填写服务器地址和 Token")))
            return
        }
        guard let url = URL(string: s.normalizedURL + path) else {
            completion(.failure(APIError(msg: "服务器地址无效")))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer " + s.token, forHTTPHeaderField: "Authorization")
        req.timeoutInterval = timeout
        if let body = body {
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        session.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(.failure(APIError(msg: "连接失败：\(err.localizedDescription)")))
                return
            }
            guard let data = data, let http = resp as? HTTPURLResponse else {
                completion(.failure(APIError(msg: "无响应")))
                return
            }
            if http.statusCode == 401 {
                completion(.failure(APIError(msg: "Token 无效或被拒绝")))
                return
            }
            guard http.statusCode == 200 else {
                completion(.failure(APIError(msg: "服务器返回 HTTP \(http.statusCode)")))
                return
            }
            completion(.success(data))
        }.resume()
    }

    private func getJSON<T: Decodable>(_ path: String, as type: T.Type,
                                       completion: @escaping (Result<T, Error>) -> Void) {
        request(path: path) { r in
            switch r {
            case .success(let data):
                completion(self.decode(data, as: type))
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    private func postAction(_ path: String, body: [String: Any],
                            completion: @escaping (Result<String, Error>) -> Void) {
        request(path: path, body: body) { r in
            switch r {
            case .success(let data):
                guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(APIError(msg: "响应异常")))
                    return
                }
                if let result = o["result"] as? String {
                    completion(.success(result))
                } else if let ok = o["ok"] as? Bool, ok {
                    completion(.success("ok"))
                } else {
                    completion(.failure(APIError(msg: o["error"] as? String ?? "操作失败")))
                }
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) -> Result<T, Error> {
        do {
            return .success(try JSONDecoder().decode(type, from: data))
        } catch {
            return .failure(APIError(msg: "数据解析失败：\(error.localizedDescription)"))
        }
    }

    // MARK: Ping
    func ping(completion: @escaping (Result<Bool, Error>) -> Void) {
        request(path: "/api/ping") { r in
            switch r {
            case .success(let data):
                if let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ok = o["ok"] as? Bool {
                    completion(.success(ok))
                } else {
                    completion(.failure(APIError(msg: "响应格式异常")))
                }
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    // MARK: 系统状态
    func status(completion: @escaping (Result<SystemStatus, Error>) -> Void) {
        request(path: "/api/status") { [weak self] r in
            guard let self = self else { return }
            switch r {
            case .success(let data):
                guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataObj = o["data"] as? [String: Any],
                      let jsonData = try? JSONSerialization.data(withJSONObject: dataObj) else {
                    completion(.failure(APIError(msg: "状态数据异常")))
                    return
                }
                completion(self.decode(jsonData, as: SystemStatus.self))
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    // MARK: Aria2 RPC 转发
    func aria2(method: String, params: Any? = nil,
               completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var body: [String: Any] = ["method": method]
        if let params = params { body["params"] = params }
        request(path: "/api/aria2", body: body) { r in
            switch r {
            case .success(let data):
                guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(APIError(msg: "Aria2 响应异常")))
                    return
                }
                completion(.success(o))
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    // MARK: 控制动作
    func action(_ action: String, arg: String? = nil,
                completion: @escaping (Result<String, Error>) -> Void) {
        var body: [String: Any] = ["action": action]
        if let arg = arg { body["arg"] = arg }
        request(path: "/api/action", body: body) { r in
            switch r {
            case .success(let data):
                guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let result = o["result"] as? String else {
                    completion(.failure(APIError(msg: "动作响应异常")))
                    return
                }
                completion(.success(result))
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    // MARK: 5G
    func fiveGStatus(completion: @escaping (Result<FiveGStatus, Error>) -> Void) {
        getJSON("/api/5g", as: FiveGEnvelope.self) { r in
            switch r {
            case .success(let e): completion(.success(e.unwrap() ?? FiveGStatus()))
            case .failure(let e): completion(.failure(e))
            }
        }
    }

    func fiveGAction(_ action: String, arg: String? = nil,
                     completion: @escaping (Result<String, Error>) -> Void) {
        var body: [String: Any] = ["action": action]
        if let arg = arg { body["arg"] = arg }
        postAction("/api/5g", body: body, completion: completion)
    }

    // MARK: 短信
    func smsList(completion: @escaping (Result<[SMSItem], Error>) -> Void) {
        getJSON("/api/sms", as: SMSListEnvelope.self) { r in
            switch r {
            case .success(let e):
                if let items = e.items {
                    completion(.success(items))
                } else {
                    completion(.failure(APIError(msg: e.error ?? "短信列表为空")))
                }
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    func smsSend(phone: String, content: String,
                 completion: @escaping (Result<String, Error>) -> Void) {
        postAction("/api/sms", body: ["phone": phone, "content": content], completion: completion)
    }

    func smsDelete(id: String, completion: @escaping (Result<String, Error>) -> Void) {
        request(path: "/api/sms?id=" + id, method: "DELETE") { r in
            switch r {
            case .success(let data):
                if let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = o["result"] as? String {
                    completion(.success(result))
                } else {
                    completion(.success("ok"))
                }
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    func smsRead(id: String, read: Bool,
                 completion: @escaping (Result<String, Error>) -> Void) {
        postAction("/api/sms/read", body: ["id": id, "read": read ? "1" : "0"], completion: completion)
    }

    // MARK: WiFi
    func wifiStatus(completion: @escaping (Result<WifiStatus, Error>) -> Void) {
        getJSON("/api/wifi", as: WifiStatus.self, completion: completion)
    }

    func wifiAction(_ action: String, arg: String? = nil,
                    completion: @escaping (Result<String, Error>) -> Void) {
        var body: [String: Any] = ["action": action]
        if let arg = arg { body["arg"] = arg }
        postAction("/api/wifi", body: body, completion: completion)
    }

    // MARK: OpenClash
    func clashStatus(completion: @escaping (Result<ClashStatus, Error>) -> Void) {
        getJSON("/api/clash", as: ClashStatus.self, completion: completion)
    }

    func clashAction(_ action: String, completion: @escaping (Result<String, Error>) -> Void) {
        postAction("/api/clash", body: ["action": action], completion: completion)
    }

    // MARK: AdGuard
    func adguardStatus(completion: @escaping (Result<AdGuardStatus, Error>) -> Void) {
        getJSON("/api/adguard", as: AdGuardStatus.self, completion: completion)
    }

    func adguardAction(_ action: String, completion: @escaping (Result<String, Error>) -> Void) {
        postAction("/api/adguard", body: ["action": action], completion: completion)
    }

    // MARK: 接入设备 (v2.2)
    func devices(completion: @escaping (Result<DevicesList, Error>) -> Void) {
        getJSON("/api/devices", as: DevicesList.self, completion: completion)
    }

    // MARK: OpenClash 实时流量 (v2.2)
    func clashTraffic(completion: @escaping (Result<ClashTraffic, Error>) -> Void) {
        getJSON("/api/clash/traffic", as: ClashTraffic.self, completion: completion)
    }

    // MARK: OpenClash 节点测速 (v2.2)
    func clashDelay(completion: @escaping (Result<ClashDelay, Error>) -> Void) {
        request(path: "/api/clash/delay", timeout: 35) { r in
            switch r {
            case .success(let data):
                completion(self.decode(data, as: ClashDelay.self))
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    // MARK: AdGuard 统计 (v2.2)
    func adguardStats(completion: @escaping (Result<AdGuardStats, Error>) -> Void) {
        getJSON("/api/adguard/stats", as: AdGuardStats.self, completion: completion)
    }
}

// MARK: - 5G 响应包装
struct FiveGEnvelope: Codable {
    let ok: Bool?
    let data: FiveGStatus?

    func unwrap() -> FiveGStatus? { data }
}
