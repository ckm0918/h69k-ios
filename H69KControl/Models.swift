import Foundation
import SwiftUI

// MARK: - 数据模型（对应 h69k API 网关返回）

struct SystemStatus: Codable {
    let ts: Int
    var cpu: Double?
    var load: [String]?
    var memTotalMb: Int?
    var memAvailMb: Int?
    var tempC: [Double]?
    var uptimeS: Int?
    var net: [String: NetIf]?
    var netConf: [String: String]?
    var netMode: String?
    var wanIp: String?
    var wwanIp: String?
    var modemStatus: String?
    var modemCellinfo: String?

    enum CodingKeys: String, CodingKey {
        case ts, cpu, load, net
        case memTotalMb = "mem_total_mb"
        case memAvailMb = "mem_avail_mb"
        case tempC = "temp_c"
        case uptimeS = "uptime_s"
        case netConf = "net_conf"
        case netMode = "net_mode"
        case wanIp = "wan_ip"
        case wwanIp = "wwan_ip"
        case modemStatus = "modem_status"
        case modemCellinfo = "modem_cellinfo"
    }
}

struct NetIf: Codable {
    let rxB: Int64
    let txB: Int64

    enum CodingKeys: String, CodingKey {
        case rxB = "rx_b"
        case txB = "tx_b"
    }
}

// MARK: - Aria2
struct Aria2Task: Codable, Identifiable {
    let gid: String
    var status: String
    var totalLength: String
    var completedLength: String
    var downloadSpeed: String
    var uploadSpeed: String
    var connections: String
    var numSeeders: String
    var errorCode: String?
    var errorMessage: String?
    var files: [Aria2File]?
    var infoHash: String?

    var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, status, connections, files
        case totalLength = "totalLength"
        case completedLength = "completedLength"
        case downloadSpeed = "downloadSpeed"
        case uploadSpeed = "uploadSpeed"
        case numSeeders = "numSeeders"
        case errorCode = "errorCode"
        case errorMessage = "errorMessage"
        case infoHash = "infoHash"
    }

    var totalBytes: Int64 { Int64(totalLength) ?? 0 }
    var doneBytes: Int64 { Int64(completedLength) ?? 0 }
    var speedBytes: Int64 { Int64(downloadSpeed) ?? 0 }
    var progress: Double { totalBytes > 0 ? Double(doneBytes) / Double(totalBytes) : 0 }

    var displayName: String {
        if let f = files?.first {
            let p = f.path as NSString
            let last = p.lastPathComponent
            if last.hasPrefix("[METADATA]") { return String(last.dropFirst(10)) + " · 获取元数据中…" }
            return last
        }
        return infoHash ?? gid
    }

    var stateColor: (String, String) {
        switch status {
        case "active":
            if totalBytes == 0 { return ("获取元数据", "warn") }
            return ("下载中", "good")
        case "paused": return ("已暂停", "secondary")
        case "waiting": return ("等待中", "secondary")
        case "error": return ("错误", "danger")
        case "complete": return ("已完成", "good")
        default: return (status, "secondary")
        }
    }
}

struct Aria2File: Codable {
    var path: String
    var length: String
    var completedLength: String
}

struct Aria2GlobalStat: Codable {
    var downloadSpeed: String
    var uploadSpeed: String
    var numActive: String
    var numWaiting: String
    var numStopped: String

    enum CodingKeys: String, CodingKey {
        case downloadSpeed, uploadSpeed, numActive, numWaiting, numStopped
    }
}

// MARK: - 5G 状态
struct FiveGStatus: Codable {
    var raw: String?
    var signal: SignalInfo?
    var net: NetModeInfo?
    var cereg: String?
    var registered: Bool?
    var wwanIp: String?

    struct SignalInfo: Codable {
        var csq: Int?
        var rssiDbm: Int?
        var level: String?

        enum CodingKeys: String, CodingKey {
            case csq
            case rssiDbm = "rssi_dbm"
            case level
        }

        var levelText: String {
            switch level {
            case "excellent": return "极好"
            case "good": return "良好"
            case "fair": return "一般"
            case "poor": return "较差"
            case "bad": return "极差"
            default: return "未知"
            }
        }
        var levelColor: Color {
            switch level {
            case "excellent", "good": return AppTheme.good
            case "fair": return AppTheme.warn
            case "poor", "bad": return AppTheme.danger
            default: return AppTheme.textSecondary
            }
        }
    }

    struct NetModeInfo: Codable {
        var modeCode: String?
        var mode: String?
        var detail: [String]?

        enum CodingKeys: String, CodingKey {
            case modeCode = "mode_code"
            case mode
            case detail
        }
    }
}

// MARK: - 短信
struct SMSItem: Codable, Identifiable {
    var id: String
    var sender: String
    var time: String
    var read: Bool
    var text: String
}

struct SMSListEnvelope: Codable {
    var ok: Bool?
    var error: String?
    var items: [SMSItem]?
}

// MARK: - WiFi
struct WifiRadio: Codable {
    var radio: String
    var ssid: String
    var disabled: Bool
    var hwmode: String
    var band: String
}

struct WifiStatus: Codable {
    var ok: Bool?
    var radios: [WifiRadio]?
    var activeBand: String?

    enum CodingKeys: String, CodingKey {
        case ok, radios
        case activeBand = "active_band"
    }
}

// MARK: - OpenClash
struct ClashStatus: Codable {
    var ok: Bool?
    var running: Bool?
    var nodeCount: Int?
    var nodes: [String]?
    var httpPort: Int?
    var socksPort: Int?
    var dnsPort: Int?
    var dashboardPort: Int?
    var configFile: String?

    enum CodingKeys: String, CodingKey {
        case ok, running, nodes
        case nodeCount = "node_count"
        case httpPort = "http_port"
        case socksPort = "socks_port"
        case dnsPort = "dns_port"
        case dashboardPort = "dashboard_port"
        case configFile = "config_file"
    }
}

// MARK: - AdGuard
struct AdGuardStatus: Codable {
    var ok: Bool?
    var running: Bool?
    var webPort: Int?
    var dnsPort: Int?
    var upstreams: [String]?

    enum CodingKeys: String, CodingKey {
        case ok, running, upstreams
        case webPort = "web_port"
        case dnsPort = "dns_port"
    }
}

// MARK: - 接入设备 (v2.2)
struct DeviceItem: Codable, Identifiable {
    var mac: String
    var ip: String
    var name: String
    var online: Bool

    var id: String { mac }
}

struct DevicesList: Codable {
    var ok: Bool?
    var total: Int?
    var onlineCount: Int?
    var devices: [DeviceItem]?

    enum CodingKeys: String, CodingKey {
        case ok, total, devices
        case onlineCount = "online_count"
    }
}

// MARK: - OpenClash 实时流量 (v2.2)
struct ClashTraffic: Codable {
    var ok: Bool?
    var running: Bool?
    var download: Int64?
    var upload: Int64?
    var error: String?
}

// MARK: - OpenClash 节点测速 (v2.2)
struct ClashDelayResult: Codable {
    var name: String
    var delay: Int?
}

struct ClashDelay: Codable {
    var ok: Bool?
    var running: Bool?
    var results: [ClashDelayResult]?
    var tested: Int?
    var okCount: Int?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case ok, running, results, tested, error
        case okCount = "ok_count"
    }
}

// MARK: - AdGuard 统计 (v2.2)
struct AdGuardStats: Codable {
    var ok: Bool?
    var running: Bool?
    var queries: Int?
    var blocked: Int?
    var blockedPercent: Double?
    var window: String?

    enum CodingKeys: String, CodingKey {
        case ok, running, queries, blocked, window
        case blockedPercent = "blocked_percent"
    }
}

// MARK: - 通用 API 响应包装
struct APIEnvelope<T: Codable>: Codable {
    let ok: Bool?
    let data: T?
    let error: String?
    let result: T?
    let value: T?

    func unwrap() -> T? { data ?? result ?? value }
}

struct Aria2Envelope: Codable {
    let result: [String: JSONValue]?
    let error: Aria2Error?
}

struct Aria2Error: Codable {
    let code: Int?
    let message: String?
}

enum JSONValue: Codable {
    case string(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let i = try? c.decode(Int64.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        if c.decodeNil() { self = .null; return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "unknown JSON")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .bool(let b): try c.encode(b)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }
}

// MARK: - 工具函数
enum Fmt {
    static func bytes(_ b: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        return f.string(fromByteCount: b)
    }

    static func speed(_ b: Int64) -> String {
        let kb = Double(b) / 1024.0
        if kb >= 1024 { return String(format: "%.1f MB/s", kb / 1024.0) }
        if kb >= 1 { return String(format: "%.0f KB/s", kb) }
        return String(format: "%.0f B/s", Double(b))
    }

    static func uptime(_ s: Int) -> String {
        let d = s / 86400
        let h = (s % 86400) / 3600
        let m = (s % 3600) / 60
        if d > 0 { return "\(d)天 \(h)小时" }
        if h > 0 { return "\(h)小时 \(m)分" }
        return "\(m)分钟"
    }
}
