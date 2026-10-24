# H69K 控制台 · HINLINK OPC-H69K 掌上控制台（iOS）

原生 iPhone 应用，专为 **HINLINK OPC-H69K 双模路由**（OpenWrt 24.10 / 4G 内存 / 200G 存储 / 5G 蜂窝）打造的远程控制台。
后端为路由器上自研的 **Python3 JSON API 网关（:8788）**，App 通过局域网 HTTP 直连，秒级响应，无需任何云服务。

## 界面预览

路由后台登录界面（丰年科技定制主题 · 系统状态实时展示）

![登录界面](docs/screenshot-login.png)

## 为什么选它

- **纯 SwiftUI 原生开发**，深色专业运维风格，交互参考华硕 ASUS Router / 小米路由器 App
- **iOS 14 起兼容**，越狱设备配合 AppSync Unified 无需签名即可直装
- **GitHub Actions 云端自动化构建**，无需 Mac 即可产出 IPA
- **与路由器插件深度联动**：5G 拨号、短信收发、双线路切换、散热风扇控制、Aria2 下载

## 功能一览

### 总览 · 专业仪表盘

- 渐变状态横幅：在线状态徽章 / 设备型号 / 出口 IP / 5G IP / 网络模式
- 实时流量卡：上下行速率大数字 + 实时速率曲线（40 点滑动窗口）
- 快捷控制：WiFi 开关 / 5G 数据开关 / 风扇自动 / 宽带优先 一键切换
- 系统资源：CPU / 内存双环形仪表，负载与温度实时监控
- 接入设备列表：在线 / 离线状态、设备图标识别（iPhone / TV / 电脑）
- 5G 模组日志实时回读

### 网络 · 5G 蜂窝

- 5G 信号条仪表（CSQ 换算 5 级）+ dBm 大数字 + 等级文本 + 注册状态徽章
- 网络模式切换：自动（宽带优先） / 仅 5G / 仅宽带 / 全部关闭
- WiFi 频段与开关：2.4G / 5G / 访客网络
- 拨号 IP、信号质量（CSQ/31）实时回读

### 短信 · 会话式收发

- 按号码分组会话列表，未读角标，长按删除整个会话
- 点击进入对话详情：气泡消息界面（仿 iPhone 短信 App）
- 底部输入框直接回复，发送后本地即时上屏
- 进入会话自动标记全部已读
- 右上角新建短信（Compose）入口

### 下载 · Aria2

- 全局统计：下载 / 上传速度、活动 / 等待 / 停止任务数
- 任务管理：进度环、实时速度、暂停 / 继续 / 删除
- 支持添加磁力链接（magnet）与直链下载

### 服务

- **OpenClash**：运行状态、节点数、今日流量、节点延迟测速（独立 35s 超时，不卡界面）
- **AdGuard Home**：拦截统计（今日拦截 / 总查询），走 TTL 缓存 83ms 秒回
- **轮询分级**：流量 5s / 负载 10s / 统计 30s，保证操作流畅不卡顿

### 设置

- 连接配置：服务器地址 + Token + 连接测试
- 散热风扇：档位控制与自动模式切换
- 外观与常用设置
- 关于：网关版本（v2.3 TTL 缓存优化）/ App 版本

## 技术栈

- SwiftUI（iOS 14 最低，兼容越狱直装）
- XcodeGen（`project.yml` 声明式生成 Xcode 工程）
- URLSession + Combine
- 深色专业运维设计（蓝紫渐变呼应 LuCI argon 主题）
- 路由后端：Python3 `http.server` + TTL 缓存 + 多线程，Bearer Token 鉴权

## 构建（GitHub Actions 云端，无需 Mac）

1. 在 GitHub 新建仓库，把本目录全部文件 push 上去（`.github/workflows/build.yml` 必须包含）
2. Actions 自动触发构建，产物为 `H69KControl-unsigned-ipa`（无签名 IPA）
3. 下载 IPA，用越狱工具（Sileo / Filza + AppSync Unified）直接安装

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
| /api/status | GET | 系统状态（Bearer，2s TTL） |
| /api/5g | GET | 5G 拨号状态（Bearer，8s TTL） |
| /api/sms | GET / DELETE | 短信列表 / 删除（Bearer，8s TTL） |
| /api/aria2 | POST | Aria2 RPC 转发（Bearer） |
| /api/action | POST | 控制动作（Bearer） |
| /api/wifi | GET | WiFi 状态（Bearer） |
| /api/clash / /api/clash/traffic / /api/clash/delay | GET | OpenClash 状态 / 流量 / 测速 |
| /api/adguard / /api/adguard/stats | GET | AdGuard 状态 / 拦截统计（5s / 10s TTL） |
| /api/devices | GET | 接入设备列表（Bearer，5s TTL） |

## 交流反馈

欢迎 Star / Issues / PR。使用问题与建议可联系 QQ：**619297429**。

## 更新记录

- **v1.3**：全页面 UI 重设计（专业仪表盘 / 5G 信号仪表 / 会话式短信 / 分区设置页）；网关 v2.3 性能优化（统计接口 20s → 83ms）
- **v1.2**：接入设备列表、Clash 实时流量与节点测速、AdGuard 拦截统计
- **v1.1**：新增网络 / 短信 / 服务页面、设置页扩充、八卦太极图标
- **v1.0**：首个版本，总览 + 下载 + 控制 + 设置
