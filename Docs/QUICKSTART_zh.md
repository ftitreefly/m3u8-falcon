# 快速开始指南

5 分钟快速上手 M3U8Falcon！

## 前置要求

在开始之前，请确保您已安装：

- **macOS 12.0 或更高版本**
- **Swift 6.0 或更高版本**
- **FFmpeg**（视频处理必需）

### 安装 FFmpeg

```bash
# 使用 Homebrew（推荐）
brew install ffmpeg

# 验证安装
ffmpeg -version
```

## 安装

### 方式 1：Swift Package Manager（推荐）

将 M3U8Falcon 添加到您的 `Package.swift`：

```swift
dependencies: [
    .package(url: "https://github.com/ftitreefly/m3u8-falcon.git", from: "1.0.0")
]
```

然后将其添加到您的目标：

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "M3U8Falcon", package: "m3u8-falcon")
    ]
)
```

### 方式 2：Xcode

1. 在 Xcode 中，转到 **File** → **Add Package Dependencies...**
2. 输入仓库 URL：`https://github.com/ftitreefly/m3u8-falcon.git`
3. 选择版本（1.0.0 或更高）
4. 将 `M3U8Falcon` 添加到您的目标

## 基础使用

### 作为库使用

#### 步骤 1：导入模块

```swift
import M3U8Falcon
```

#### 步骤 2：初始化

```swift
// 使用默认配置初始化
await M3U8Falcon.initialize()
```

#### 步骤 3：下载视频

```swift
// 从 M3U8 URL 下载
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "my-video",
    verbose: true
)

print("✅ 视频下载成功！")
```

### 作为 CLI 工具使用

#### 构建 CLI

```bash
# 克隆仓库
git clone https://github.com/ftitreefly/m3u8-falcon.git
cd m3u8-falcon

# 构建 CLI
swift build -c release

# 可执行文件位于：.build/release/m3u8-falcon
```

#### 基础 CLI 命令

```bash
# 下载视频
m3u8-falcon download https://example.com/video.m3u8

# 使用自定义文件名下载
m3u8-falcon download https://example.com/video.m3u8 --name my-video

# 使用详细输出下载
m3u8-falcon download https://example.com/video.m3u8 -v

# 从网页提取 M3U8 链接
m3u8-falcon extract "https://example.com/video-page"

# 显示工具信息
m3u8-falcon info
```

## 常见使用场景

### 1. 下载简单视频

```swift
import M3U8Falcon

await M3U8Falcon.initialize()

try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "my-video"
)
```

### 2. 带进度跟踪的下载

```swift
try await M3U8Falcon.download(
    .web,
    url: videoURL,
    savedDirectory: outputDir,
    name: "my-video",
    verbose: true  // 启用详细输出以显示进度
)
```

### 3. 下载加密视频

```swift
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "encrypted-video",
    customKey: "0123456789abcdef0123456789abcdef",
    customIV: "0123456789abcdef0123456789abcdef"
)
```

### 4. 解析 M3U8 文件

```swift
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

## 配置

### 自定义配置

```swift
let customConfig = DIConfiguration(
    ffmpegPath: "/custom/path/ffmpeg",
    maxConcurrentDownloads: 10,
    downloadTimeout: 60
)

await M3U8Falcon.initialize(with: customConfig)
```

### 日志配置

```swift
// 生产模式（最小输出）
Logger.configure(.production())

// 开发模式（详细输出）
Logger.configure(.development())
```

## 错误处理

```swift
do {
    try await M3U8Falcon.download(.web, url: videoURL, verbose: true)
} catch let error as FileSystemError {
    print("文件系统错误：\(error.message)")
} catch let error as NetworkError {
    print("网络错误：\(error.message)")
} catch let error as ParsingError {
    print("解析错误：\(error.message)")
} catch {
    print("意外错误：\(error)")
}
```

## 下一步

现在您已经掌握了基础知识：

1. **阅读[用户指南](USER_GUIDE_zh.md)**了解详细使用说明
2. **查看[API 参考](API_REFERENCE.md)**获取完整 API 文档
3. **探索[高级功能](../README_zh.md#-高级用法)**了解更多功能
4. **查看[开发者指南](DEVELOPER_GUIDE_zh.md)**如果您想扩展库

## 故障排除

### 常见问题

#### 找不到 FFmpeg

**错误**：`FFmpeg not found at path: /usr/local/bin/ffmpeg`

**解决方案**：
```bash
# 安装 FFmpeg
brew install ffmpeg

# 或在配置中指定自定义路径
let config = DIConfiguration(ffmpegPath: "/your/custom/path/ffmpeg")
await M3U8Falcon.initialize(with: config)
```

#### 网络超时

**错误**：网络超时错误

**解决方案**：在配置中增加超时时间：
```swift
let config = DIConfiguration(downloadTimeout: 120) // 120 秒
await M3U8Falcon.initialize(with: config)
```

#### 无效 URL

**错误**：无效 URL 错误

**解决方案**：确保 URL 使用 `http://` 或 `https://` 协议：
```swift
// ✅ 正确
URL(string: "https://example.com/video.m3u8")

// ❌ 错误
URL(string: "example.com/video.m3u8")
```

## 获取帮助

- **文档**：请参阅 `Docs/` 目录中的其他指南
- **问题**：[GitHub Issues](https://github.com/ftitreefly/m3u8-falcon/issues)
- **讨论**：[GitHub Discussions](https://github.com/ftitreefly/m3u8-falcon/discussions)

---

祝您使用愉快！🚀

