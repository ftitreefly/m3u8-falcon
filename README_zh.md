# M3U8Falcon

<!-- markdownlint-disable-next-line MD033 -->
<img src="Logo-512px.png" alt="M3U8Falcon 标志" width="300">

中文文档 | [English](README.md)

一个高性能的Swift库和CLI工具，用于下载、解析和处理M3U8视频文件。基于Swift 6+特性、现代并发模式和全面的依赖注入架构构建。

## ✨ 特性

- 🚀 **Swift 6+ 就绪**: 使用最新的Swift 6特性构建，包括严格的并发检查
- 🔧 **依赖注入**: 完整的DI架构，提高可测试性和模块化
- 📱 **跨平台**: 支持 macOS 12.0+ 和 Linux，提供库和CLI两种接口
- 🐧 **Linux 兼容**: 完整的 Linux 支持，提供平台特定优化
- 🛡️ **全面的错误处理**: 详细的错误类型和上下文信息
- 🔄 **并发下载**: 可配置的并发下载支持（最多20个并发任务）
- 📊 **高级日志系统**: 多级别日志，支持分类和彩色输出
- 🎯 **多源支持**: 支持Web URL和本地M3U8文件
- 🎬 **视频处理**: FFmpeg集成，用于视频片段合并
- 🔐 **加密支持**: 内置加密M3U8流支持，可自定义密钥/IV覆盖
- 🔌 **可扩展架构**: 基于协议的设计，便于第三方集成
- 🧪 **广泛测试**: 全面的测试套件，覆盖所有主要功能

## 🚀 快速开始 - 5分钟上手

### 安装

#### macOS

```bash
# 1. 安装FFmpeg（视频处理必需）
brew install ffmpeg

# 2. 添加到你的Package.swift
dependencies: [
    .package(url: "https://github.com/ftitreefly/m3u8-falcon.git", from: "1.0.0")
]
```

#### Linux

```bash
# 1. 安装FFmpeg（视频处理必需）
# Ubuntu/Debian
sudo apt update && sudo apt install ffmpeg

# Fedora/RHEL
sudo dnf install ffmpeg

# Arch Linux
sudo pacman -S ffmpeg

# 2. 添加到你的Package.swift
dependencies: [
    .package(url: "https://github.com/ftitreefly/m3u8-falcon.git", from: "1.0.0")
]
```

### 基础使用示例

```swift
import M3U8Falcon

// 初始化库
await M3U8Falcon.initialize()

// 从M3U8 URL下载视频
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "my-video",
    verbose: true
)

print("✅ 视频下载成功！")
```

### CLI工具 - 一条命令下载视频

```bash
# 使用单条命令下载M3U8视频
m3u8-falcon download https://example.com/video.m3u8

# 使用自定义文件名和详细输出下载
m3u8-falcon download https://example.com/video.m3u8 --name my-video -v

# 从网页提取M3U8链接
m3u8-falcon extract "https://example.com/video-page"
```

就是这样！更多高级功能请参见下面的章节。

---

## 🔌 M3U8LinkExtractorProtocol - 第三方集成核心接口

`M3U8LinkExtractorProtocol` 是M3U8Falcon的核心扩展接口，允许第三方开发者轻松集成各种视频网站的M3U8链接提取功能。

### 协议概述

```swift
public protocol M3U8LinkExtractorProtocol: Sendable {
    /// 从网页中提取M3U8链接
    func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link]
    
    /// 返回该提取器支持的域名列表
    func getSupportedDomains() -> [String]
    
    /// 返回提取器的完整信息
    func getExtractorInfo() -> ExtractorInfo
    
    /// 检查该提取器是否能处理指定URL
    func canHandle(url: URL) -> Bool
}
```

### 完整可运行示例

以下是一个完整的、可运行的示例，展示如何实现自定义M3U8提取器：

```swift
import Foundation
import M3U8Falcon

// 1️⃣ 创建自定义提取器
final class CustomVideoSiteExtractor: M3U8LinkExtractorProtocol {
    
    private let supportedDomains = ["example.com", "video.example.com"]
    
    public init() {}
    
    // 提取M3U8链接的核心方法
    public func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link] {
        // 下载网页内容
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // 自定义提取函数
        var links: [M3U8Link] = []
        for index in 0 ... 5 {
            let m3u8URL = "video-\(index).m3u8"
            let videoName = "name-\(index)"
            
            links.append(M3U8Link(
                url: m3u8URL,
                name: videoName
            ))
        }
        
        return links
    }
    
    // 返回支持的域名
    public func getSupportedDomains() -> [String] {
        return supportedDomains
    }
    
    // 返回提取器信息
    public func getExtractorInfo() -> ExtractorInfo {
        return ExtractorInfo(
            name: "Custom Video Site Extractor",
            version: "1.0.0",
            supportedDomains: getSupportedDomains(),
            capabilities: [.directLinks, .javascriptVariables]
        )
    }
    
    // 检查是否能处理该URL
    public func canHandle(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return supportedDomains.contains { host.hasSuffix($0) }
    }
}

// 2️⃣ 注册并使用提取器
async func main() async throws {
    // 创建提取器注册表
    let registry = DefaultM3U8ExtractorRegistry()
    
    // 注册你的自定义提取器
    let customExtractor = CustomVideoSiteExtractor()
    registry.registerExtractor(customExtractor)
    
    // 使用提取器提取M3U8链接
    let url = URL(string: "https://example.com/video-page")!
    let links = try await registry.extractM3U8Links(
        from: url,
        options: LinkExtractionOptions.default
    )
    
    // 处理提取到的链接
    print("找到 \(links.count) 个M3U8链接：")
    for link in links {
        print("  📹 \(link.name)")
        print("     URL: \(link.url)")
    }
    
    // 3️⃣ 下载提取到的第一个视频
    if let firstLink = links.first {
        await M3U8Falcon.initialize()
        try await M3U8Falcon.download(
            .web,
            url: firstLink.url,
            savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
            name: firstLink.name,
            verbose: true
        )
        print("✅ 视频下载成功！")
    }
}

// 运行示例
try await main()
```

### 核心组件

#### M3U8Link 结构

```swift
public struct M3U8Link: Sendable {
    let url: URL              // M3U8播放列表URL（必需）
    let name: String          // 视频名称（必需）
    // 其他可选字段：bandwidth（带宽）、resolution（分辨率）、source（来源）等
}
```

#### LinkExtractionOptions

```swift
public struct LinkExtractionOptions: Sendable {
    let timeout: TimeInterval        // 请求超时时间
    let maxRetries: Int              // 最大重试次数
    let methods: [ExtractionMethod]  // 提取方法
    let headers: [String: String]    // HTTP headers
    
    public static let `default`: LinkExtractionOptions
}
```

#### ExtractorInfo

```swift
public struct ExtractorInfo: Sendable {
    let name: String                    // 提取器名称
    let version: String                 // 版本号
    let supportedDomains: [String]      // 支持的域名列表
    let capabilities: [Capability]      // 功能列表
}
```

### CLI集成

你的自定义提取器也可以通过CLI使用：

```bash
# 提取M3U8链接
m3u8-falcon extract "https://example.com/video-page"

# 查看已注册的提取器
m3u8-falcon extract "https://example.com/video-page" --show-extractors

# 指定提取方法
m3u8-falcon extract "https://example.com/video-page" --methods direct-links
```

---

## 🐧 Linux 支持

M3U8Falcon 完整支持 Linux，并提供平台特定优化：

### 平台特定功能

- ✅ **进程执行**: Linux 优化的基于轮询的输出捕获
- ✅ **流式下载**: 使用 URLSessionDataDelegate 的自定义字节流实现
- ✅ **线程安全**: 平台感知的并发管理，使用 NSLock 和 DispatchGroup
- ✅ **路径解析**: 支持 XDG Base Directory 规范的用户目录
- ✅ **FFmpeg 集成**: 自动检测常见 Linux 安装位置的 FFmpeg 路径

### 平台差异

库会自动处理平台差异：

| 功能 | macOS/iOS | Linux |
|------|-----------|-------|
| 进程输出捕获 | `readabilityHandler` | 基于 `DispatchGroup` 的轮询 |
| 流式下载 | `URLSession.bytes` | `URLSessionDataDelegate` |
| 终端检测 | `Darwin.isatty` | `Glibc.isatty` |
| URL 缓存 | `directory` 参数 | `diskPath` 参数 |
| 下载目录 | `~/Downloads` | XDG_DOWNLOAD_DIR / `~/.config/user-dirs.dirs` |

### 在 Linux 上构建

```bash
# 克隆并构建
git clone https://github.com/ftitreefly/m3u8-falcon.git
cd m3u8-falcon
swift build

# 运行测试
swift test

# 运行 CLI
swift run m3u8-falcon download https://example.com/video.m3u8 -v
```

---

## 📚 文档

- **[项目概览](Docs/PROJECT_OVERVIEW_zh.md)** - 项目架构和技术栈说明
- **[快速开始指南](Docs/QUICKSTART_zh.md)** - 5分钟快速上手
- **[用户指南](Docs/USER_GUIDE_zh.md)** - 完整的功能文档和使用示例
- **[开发者指南](Docs/DEVELOPER_GUIDE_zh.md)** - 架构说明、开发流程和贡献指南
- **[文档索引](Docs/README.md)** - 所有文档的中心枢纽

---

## 📖 高级用法

### 下载视频

```swift
import M3U8Falcon

// 初始化工具
await M3U8Falcon.initialize()

// 下载M3U8文件并显示详细输出
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "/Users/username/Downloads/videos/"),
    name: "my-video",
    verbose: true
)

// 使用自定义解密密钥和IV下载加密的M3U8
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "/Users/username/Downloads/videos/"),
    name: "encrypted-video",
    customKey: "0123456789abcdef0123456789abcdef",
    customIV: "0123456789abcdef0123456789abcdef"
)
```

### 解析M3U8文件

```swift
// 解析M3U8文件
let result = try await M3U8Falcon.parse(
    url: URL(string: "https://example.com/video.m3u8")!
)

switch result {
case .master(let masterPlaylist):
    print("主播放列表包含 \(masterPlaylist.tags.streamTags.count) 个流")
case .media(let mediaPlaylist):
    print("媒体播放列表包含 \(mediaPlaylist.tags.mediaSegments.count) 个片段")
case .cancelled:
    print("解析已取消")
}
```

### CLI命令

```bash
# 使用默认设置下载M3U8文件
m3u8-falcon download https://example.com/video.m3u8

# 使用自定义文件名下载
m3u8-falcon download https://example.com/video.m3u8 --name my-video

# 使用自定义解密密钥下载加密的M3U8
m3u8-falcon download https://example.com/video.m3u8 --key 0123456789abcdef0123456789abcdef

# 使用自定义密钥和IV下载
m3u8-falcon download https://example.com/video.m3u8 \
  --key 0123456789abcdef0123456789abcdef \
  --iv 0123456789abcdef0123456789abcdef \
  --name my-video \
  -v

# 显示工具信息
m3u8-falcon info
```

注意：CLI URL必须使用http或https协议。

---

## 🔧 配置和高级功能

### 自定义配置

```swift
let customConfig = DIConfiguration(
    ffmpegPath: "/custom/path/ffmpeg",
    maxConcurrentDownloads: 10,
    downloadTimeout: 60,
    key: "0123456789abcdef0123456789abcdef",  // 可选：默认解密密钥
    iv: "0123456789abcdef0123456789abcdef"     // 可选：默认IV
)

await M3U8Falcon.initialize(with: customConfig)
```

### 日志系统

```swift
// 生产环境配置 - 最小输出
Logger.configure(.production())

// 开发环境配置 - 详细输出
Logger.configure(.development())

// 自定义配置
let customConfig = LoggerConfiguration(
    minimumLevel: .debug,
    includeTimestamps: true,
    includeCategories: true,
    enableColors: true
)
Logger.configure(customConfig)
```

### 加密M3U8支持

对于加密的M3U8流，你可以提供自定义的AES-128解密密钥：

```swift
// 方法1：通过配置（应用于所有下载）
let config = DIConfiguration(
    key: "0123456789abcdef0123456789abcdef",
    iv: "0123456789abcdef0123456789abcdef"
)
await M3U8Falcon.initialize(with: config)

// 方法2：单次下载覆盖（优先于配置）
try await M3U8Falcon.download(
    .web,
    url: encryptedVideoURL,
    savedDirectory: outputDir,
    key: "0123456789abcdef0123456789abcdef",
    iv: "0123456789abcdef0123456789abcdef"
)
```

**密钥格式**：十六进制字符串（128位AES为32个字符）

- 示例：`"0123456789abcdef0123456789abcdef"`
- 空格和`0x`前缀会自动移除

### 错误处理

```swift
do {
    try await M3U8Falcon.download(.web, url: videoURL, verbose: true)
} catch let error as FileSystemError {
    print("文件系统错误：\(error.message)")
} catch let error as NetworkError {
    print("网络错误：\(error.message)")
} catch {
    print("意外错误：\(error)")
}
```

---

## 🧪 测试和开发

### 运行测试

```bash
# 运行所有测试
swift test

# 运行详细输出的测试
swift test --verbose

# 运行特定测试
swift test --filter NetworkLayerTests
```

### 开发环境设置

```bash
# 克隆仓库
git clone https://github.com/ftitreefly/m3u8-falcon.git
cd m3u8-falcon

# 构建项目
swift build

# 运行测试
swift test

# 构建和运行CLI
swift run m3u8-falcon --help

# 使用详细输出测试下载
swift run m3u8-falcon download https://example.com/video.m3u8 -v
```

---

## 📄 许可证

本项目采用MIT许可证 - 详见[LICENSE](LICENSE)文件。

### 第三方声明

本项目包含改编自[go-swifty-m3u8](https://github.com/gal-orlanczyk/go-swifty-m3u8)的代码，该项目采用MIT许可证：

```text
Copyright (c) Gal Orlanczyk

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

---

## 🆘 支持与资源

- **📖 完整文档**: [文档索引](Docs/README.md)
- **🐛 问题反馈**: [GitHub Issues](https://github.com/ftitreefly/m3u8-falcon/issues)
- **💬 讨论**: [GitHub Discussions](https://github.com/ftitreefly/m3u8-falcon/discussions)
- **👥 开发者指南**: [开发者文档](Docs/DEVELOPER_GUIDE_zh.md)
- **📝 更新日志**: [CHANGELOG.md](CHANGELOG.md)

---

## 🌟 Star历史

如果您觉得这个项目有帮助，请考虑在GitHub上给它一个star ⭐️！

---

由M3U8Falcon团队用 ❤️ 制作
