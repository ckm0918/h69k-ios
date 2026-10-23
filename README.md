# H69K 控制台 (iOS)

原生 iPhone App，用于操作 H69K 路由器（192.168.8.1）。
后端为 h69k 上的 Python3 JSON API 网关（:8788），App 通过局域网 HTTP 访问。

## 功能

- **总览**：CPU 环形仪表、内存、双温度、负载、网络流量实时迷你图、5G 模组状态、双线路模式
- **下载**：Aria2 任务管理（进度环、速度、暂停/继续/删除、添加磁力或直链）
- **控制**：双线路模式切换、WiFi 频段、WiFi/5G 数据开关、风扇控制、重启路由器
- **设置**：服务器地址 + Token，连接测试

## 技术栈

- SwiftUI（iOS 14 最低，兼容越狱直装）
- XcodeGen（`project.yml` 生成 Xcode 工程）
- URLSession + Combine
- 深色专业运维设计（蓝紫渐变呼应 LuCI argon 主题）

## 构建（GitHub Actions 云端，无需 Mac）

1. 在 GitHub 新建**私有仓库**
2. 把本目录所有文件 push 上去（注意 `.github/workflows/build.yml` 必须包含）
3. Actions 自动触发构建，产物为 `H69KControl-unsigned-ipa`（无签名 IPA）
4. 下载 IPA，用越狱工具（如 Sileo/Filza + AppSync Unified）直接安装

## 手动构建（有 Mac 时）

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project H69KControl.xcodeproj -scheme H69KControl \
  -configuration Release -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
# 打包 IPA：mkdir Payload && cp -R <build>/H69KControl.app Payload/ && zip -r H69KControl-unsigned.ipa Payload
```

## 配置

打开 App 后在设置页填写：

- 服务器地址：`http://192.168.8.1:8788`
- Token：h69k 上 `cat /mnt/sda1/Apps/h69kapi/token`

## 接口依赖（h69k API 网关）

| 接口 | 方法 | 说明 |
|---|---|---|
| /api/ping | GET | 免鉴权心跳 |
| /api/status | GET | 系统状态（Bearer） |
| /api/aria2 | POST | Aria2 RPC 转发（Bearer） |
| /api/action | POST | 控制动作（Bearer） |
