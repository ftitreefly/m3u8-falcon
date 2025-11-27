# M3U8Falcon

<!-- markdownlint-disable-next-line MD033 -->
<img src="Logo-512px.png" alt="M3U8Falcon 标志" width="300">

中文文档 | [English](README.md)

一个高性能的Swift库和CLI工具，用于下载、解析和处理M3U8视频文件。基于Swift 6+特性、现代并发模式和全面的依赖注入架构构建。

## ✨ 特性

- 🚀 **Swift 6+**: 现代并发模式和依赖注入架构
- 📱 **跨平台**: 支持 macOS 12.0+ 和 Linux（库和 CLI）
- 🔄 **高性能**: 并发下载（最多 20 个任务）和流式支持
- 🎬 **视频处理**: FFmpeg 集成，支持片段合并和格式转换
- 🔐 **加密**: 内置 AES-128 解密，支持自定义密钥/IV
- 🔌 **可扩展**: 基于协议的设计，支持自定义提取器和集成
- 🛡️ **生产就绪**: 全面的错误处理、日志和测试覆盖

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

// ⚠️ 重要：首先初始化库（必需）
await M3U8Falcon.initialize()

// 从M3U8 URL下载视频
// savedDirectory 是可选的 - 默认为 Downloads 文件夹
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    name: "my-video"
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

// 下载M3U8文件（savedDirectory 是可选的，默认为 Downloads 文件夹）
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    name: "my-video"
)

// 使用自定义目录下载
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "/Users/username/Downloads/videos/"),
    name: "my-video"
)

// 使用自定义AES-128解密下载加密的M3U8
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    name: "encrypted-video",
    strategy: .customAES128(
        key: "0123456789abcdef0123456789abcdef",
        iv: "0123456789abcdef0123456789abcdef"
    )
)

// 仅使用密钥下载加密的M3U8（IV从片段序列号派生）
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    name: "encrypted-video",
    strategy: .customAES128(key: "0123456789abcdef0123456789abcdef")
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

### 从网页提取M3U8链接

```swift
import M3U8Falcon

// 首先初始化库
await M3U8Falcon.initialize()

// 创建提取器注册表（使用DI容器中的配置）
let registry = await DefaultM3U8ExtractorRegistry.create()

// 或使用默认配置创建（一行代码）
// let registry = DefaultM3U8ExtractorRegistry()

// 注册自定义提取器（可选）
// registry.registerExtractor(YouTubeExtractor())
// registry.registerExtractor(VimeoExtractor())

// 从网页提取M3U8链接
let links = try await registry.extractM3U8Links(
    from: URL(string: "https://example.com/video-page")!,
    options: LinkExtractionOptions.default
)

for link in links {
    print("找到M3U8链接: \(link.url) (置信度: \(link.confidence))")
}
```

### CLI命令

```bash
# 使用默认设置下载M3U8文件
m3u8-falcon download https://example.com/video.m3u8

# 使用自定义文件名下载
m3u8-falcon download https://example.com/video.m3u8 --name my-video

# 下载到自定义目录
m3u8-falcon download https://example.com/video.m3u8 --output /path/to/videos

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
// 配置详细日志
let customConfig = DIConfiguration(
    ffmpegPath: "/custom/path/ffmpeg",
    maxConcurrentDownloads: 10,
    downloadTimeout: 60,
    logLevel: .verbose  // 启用详细日志
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

对于加密的M3U8流，你可以使用 `DecryptionStrategy` 枚举提供自定义的AES-128解密：

```swift
// 无解密（默认）
try await M3U8Falcon.download(
    .web,
    url: videoURL,
    name: "video"
)

// 使用密钥和IV的自定义AES-128解密
try await M3U8Falcon.download(
    .web,
    url: encryptedVideoURL,
    name: "encrypted-video",
    strategy: .customAES128(
        key: "0123456789abcdef0123456789abcdef",
        iv: "0123456789abcdef0123456789abcdef"
    )
)

// 仅使用密钥的自定义AES-128解密（IV从片段序列号派生）
try await M3U8Falcon.download(
    .web,
    url: encryptedVideoURL,
    name: "encrypted-video",
    strategy: .customAES128(key: "0123456789abcdef0123456789abcdef")
)
```

**密钥格式**：十六进制字符串（128位AES为32个字符）

- 示例：`"0123456789abcdef0123456789abcdef"`
- 空格和`0x`前缀会自动移除
- IV 是可选的 - 如果未提供，将从片段序列号派生

### 错误处理

```swift
do {
    try await M3U8Falcon.download(.web, url: videoURL, name: "my-video")
} catch let error as FileSystemError {
    print("文件系统错误：\(error.message)")
} catch let error as NetworkError {
    print("网络错误：\(error.message)")
} catch let error as ConfigurationError {
    print("配置错误：\(error.message)")
    // 确保首先调用 M3U8Falcon.initialize()
} catch {
    print("意外错误：\(error)")
}
```

---

## 🧪 测试和开发

M3U8Falcon 使用 Swift Testing 框架进行全面的测试覆盖。

### 运行测试

```bash
# 运行所有测试
swift test

# 运行详细输出的测试
swift test --verbose

# 运行特定测试套件
swift test --filter ParseTests
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
