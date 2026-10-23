import Foundation
import Combine

// MARK: - 设置存储（UserDefaults）
final class AppSettings: ObservableObject {
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    @Published var token: String {
        didSet { UserDefaults.standard.set(token, forKey: "token") }
    }

    static let shared = AppSettings()

    init() {
        let def = UserDefaults.standard
        serverURL = def.string(forKey: "serverURL") ?? "http://192.168.8.1:8788"
        token = def.string(forKey: "token") ?? ""
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
    private func request(path: String, body: [String: Any]? = nil,
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
        req.setValue("Bearer " + s.token, forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 25
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
}
