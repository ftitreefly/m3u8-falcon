# 用户指南

使用 M3U8Falcon 下载和处理 M3U8 视频的完整指南。

## 目录

1. [安装](#安装)
2. [基础使用](#基础使用)
3. [CLI 命令](#cli-命令)
4. [高级功能](#高级功能)
5. [配置](#配置)
6. [错误处理](#错误处理)
7. [最佳实践](#最佳实践)
8. [故障排除](#故障排除)

## 安装

### 系统要求

- macOS 12.0 或更高版本
- Swift 6.0 或更高版本
- FFmpeg（用于视频处理）

### 安装 FFmpeg

```bash
# 使用 Homebrew
brew install ffmpeg

# 验证安装
ffmpeg -version
```

### 安装 M3U8Falcon

请参阅[快速开始指南](QUICKSTART_zh.md)了解详细的安装说明。

## 基础使用

### 库使用

#### 初始化

```swift
import M3U8Falcon

// 使用默认设置初始化
await M3U8Falcon.initialize()

// 或使用自定义配置
let config = DIConfiguration(
    maxConcurrentDownloads: 10,
    downloadTimeout: 60
)
await M3U8Falcon.initialize(with: config)
```

#### 下载视频

```swift
// 基础下载
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "my-video"
)

// 使用详细输出下载
try await M3U8Falcon.download(
    .web,
    url: videoURL,
    savedDirectory: outputDir,
    name: "my-video",
    verbose: true
)
```

#### 解析 M3U8 文件

```swift
let result = try await M3U8Falcon.parse(
    url: URL(string: "https://example.com/video.m3u8")!
)

switch result {
case .master(let masterPlaylist):
    // 处理主播放列表
    for stream in masterPlaylist.tags.streamTags {
        print("流：\(stream.uri)")
    }
case .media(let mediaPlaylist):
    // 处理媒体播放列表
    print("片段数：\(mediaPlaylist.tags.mediaSegments.count)")
case .cancelled:
    print("解析已取消")
}
```

## CLI 命令

### Download 命令

从 URL 下载 M3U8 视频。

```bash
# 基础下载
m3u8-falcon download https://example.com/video.m3u8

# 使用自定义文件名
m3u8-falcon download https://example.com/video.m3u8 --name my-video

# 使用详细输出
m3u8-falcon download https://example.com/video.m3u8 -v

# 使用自定义密钥下载加密视频
m3u8-falcon download https://example.com/video.m3u8 \
  --key 0123456789abcdef0123456789abcdef

# 使用自定义密钥和 IV 下载
m3u8-falcon download https://example.com/video.m3u8 \
  --key 0123456789abcdef0123456789abcdef \
  --iv 0123456789abcdef0123456789abcdef \
  --name my-video \
  -v
```

**选项：**
- `--name <name>`：输出视频的自定义文件名
- `--key <key>`：自定义 AES-128 解密密钥（十六进制字符串）
- `--iv <iv>`：自定义初始化向量（十六进制字符串）
- `-v, --verbose`：启用详细输出

### Extract 命令

从网页提取 M3U8 链接。

```bash
# 从网页提取链接
m3u8-falcon extract "https://example.com/video-page"

# 显示已注册的提取器
m3u8-falcon extract "https://example.com/video-page" --show-extractors

# 指定提取方法
m3u8-falcon extract "https://example.com/video-page" --methods direct-links
```

**选项：**
- `--show-extractors`：显示所有已注册的提取器
- `--methods <methods>`：指定提取方法（逗号分隔）

### Info 命令

显示工具信息。

```bash
m3u8-falcon info
```

## 高级功能

### 加密流

M3U8Falcon 支持使用自定义密钥的 AES-128 加密流。

#### 使用自定义解密密钥

```swift
// 方法 1：每次下载指定密钥
try await M3U8Falcon.download(
    .web,
    url: encryptedVideoURL,
    savedDirectory: outputDir,
    name: "encrypted-video",
    customKey: "0123456789abcdef0123456789abcdef",
    customIV: "0123456789abcdef0123456789abcdef"
)

// 方法 2：全局配置
let config = DIConfiguration(
    key: "0123456789abcdef0123456789abcdef",
    iv: "0123456789abcdef0123456789abcdef"
)
await M3U8Falcon.initialize(with: config)
```

**密钥格式：**
- 十六进制字符串（128 位 AES 为 32 个字符）
- 示例：`"0123456789abcdef0123456789abcdef"`
- 空格和 `0x` 前缀会自动移除

### 并发下载

配置并发片段下载数量：

```swift
let config = DIConfiguration(
    maxConcurrentDownloads: 20  // 最大值：20
)
await M3U8Falcon.initialize(with: config)
```

**建议：**
- 默认：5 个并发下载
- 快速连接：10-15 个
- 最大值：20 个（避免使服务器过载）

### 日志

配置日志级别和输出：

```swift
// 生产模式（最小输出）
Logger.configure(.production())

// 开发模式（详细输出）
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

**日志级别：**
- `.error`：仅错误
- `.warning`：错误和警告
- `.info`：错误、警告和信息消息
- `.debug`：所有消息，包括调试信息

### 链接提取

使用提取器系统从网页提取 M3U8 链接：

```swift
import M3U8Falcon

// 创建提取器注册表
let registry = DefaultM3U8ExtractorRegistry()

// 提取链接
let url = URL(string: "https://example.com/video-page")!
let links = try await registry.extractM3U8Links(
    from: url,
    options: LinkExtractionOptions.default
)

// 处理提取到的链接
for link in links {
    print("找到：\(link.name) - \(link.url)")
}
```

## 配置

### DIConfiguration 选项

```swift
let config = DIConfiguration(
    ffmpegPath: "/usr/local/bin/ffmpeg",      // FFmpeg 可执行文件路径
    maxConcurrentDownloads: 10,                // 最大并发下载数（1-20）
    downloadTimeout: 60,                       // 下载超时时间（秒）
    key: nil,                                  // 默认解密密钥（可选）
    iv: nil                                    // 默认 IV（可选）
)
```

### 环境变量

您也可以通过环境变量配置某些设置：

```bash
# 设置 FFmpeg 路径
export M3U8_FFMPEG_PATH="/custom/path/ffmpeg"

# 设置日志级别
export M3U8_LOG_LEVEL="debug"
```

## 错误处理

### 错误类型

M3U8Falcon 为不同场景提供特定的错误类型：

```swift
do {
    try await M3U8Falcon.download(.web, url: videoURL, verbose: true)
} catch let error as FileSystemError {
    // 文件系统相关错误
    print("文件系统错误：\(error.message)")
    print("路径：\(error.path ?? "未知")")
} catch let error as NetworkError {
    // 网络相关错误
    print("网络错误：\(error.message)")
    print("URL：\(error.url?.absoluteString ?? "未知")")
} catch let error as ParsingError {
    // M3U8 解析错误
    print("解析错误：\(error.message)")
    print("行：\(error.line ?? "未知")")
} catch let error as ProcessingError {
    // 视频处理错误
    print("处理错误：\(error.message)")
} catch {
    // 其他错误
    print("意外错误：\(error)")
}
```

### 常见错误场景

#### 网络超时

```swift
// 增加超时时间
let config = DIConfiguration(downloadTimeout: 120)
await M3U8Falcon.initialize(with: config)
```

#### 找不到 FFmpeg

```swift
// 指定自定义 FFmpeg 路径
let config = DIConfiguration(ffmpegPath: "/custom/path/ffmpeg")
await M3U8Falcon.initialize(with: config)
```

#### 无效的 M3U8 格式

```swift
// 在下载前检查 URL 是否为有效的 M3U8
let result = try await M3U8Falcon.parse(url: videoURL)
// 如果解析成功，继续下载
```

## 最佳实践

### 1. 始终先初始化

```swift
// ✅ 好
await M3U8Falcon.initialize()
try await M3U8Falcon.download(...)

// ❌ 不好
try await M3U8Falcon.download(...)  // 未初始化可能失败
```

### 2. 使用适当的并发下载数

```swift
// ✅ 好 - 适合大多数连接的平衡值
let config = DIConfiguration(maxConcurrentDownloads: 10)

// ❌ 不好 - 太多可能使服务器过载
let config = DIConfiguration(maxConcurrentDownloads: 50)  // 将被限制为 20
```

### 3. 正确处理错误

```swift
// ✅ 好 - 特定错误处理
do {
    try await M3U8Falcon.download(...)
} catch let error as NetworkError {
    // 专门处理网络错误
} catch {
    // 处理其他错误
}

// ❌ 不好 - 通用错误处理
do {
    try await M3U8Falcon.download(...)
} catch {
    print("错误")  // 没有帮助
}
```

### 4. 调试时使用详细模式

```swift
// 故障排除时启用详细输出
try await M3U8Falcon.download(
    .web,
    url: videoURL,
    savedDirectory: outputDir,
    name: "video",
    verbose: true  // 显示详细进度
)
```

### 5. 下载前验证 URL

```swift
// ✅ 好 - 先验证
guard let url = URL(string: urlString),
      url.scheme == "http" || url.scheme == "https" else {
    print("无效 URL")
    return
}

// ❌ 不好 - 可能因模糊错误而失败
let url = URL(string: urlString)!  // 强制解包
```

## 故障排除

### 下载立即失败

**可能原因：**
- FFmpeg 未安装或不在 PATH 中
- URL 格式无效
- 网络连接问题

**解决方案：**
1. 验证 FFmpeg：`ffmpeg -version`
2. 检查 URL 格式（必须使用 http:// 或 https://）
3. 测试网络连接

### 下载速度慢

**可能原因：**
- 并发下载数太少
- 网络带宽限制
- 服务器速率限制

**解决方案：**
1. 增加并发下载数（最多 20 个）
2. 检查网络连接
3. 尝试在不同时间下载

### 视频播放问题

**可能原因：**
- 下载不完整
- 缺少加密密钥
- 片段损坏

**解决方案：**
1. 重新下载视频
2. 如果适用，验证加密密钥
3. 检查 FFmpeg 安装

### 内存使用高

**可能原因：**
- 并发下载太多
- 视频文件过大

**解决方案：**
1. 减少并发下载数
2. 分批处理视频
3. 监控系统资源

## 其他资源

- [快速开始指南](QUICKSTART_zh.md) - 5 分钟快速上手
- [项目概览](PROJECT_OVERVIEW_zh.md) - 架构和设计
- [开发者指南](DEVELOPER_GUIDE_zh.md) - 扩展库
- [API 参考](API_REFERENCE.md) - 完整 API 文档

## 获取帮助

- **GitHub Issues**：[报告错误或请求功能](https://github.com/ftitreefly/m3u8-falcon/issues)
- **GitHub Discussions**：[提问或分享想法](https://github.com/ftitreefly/m3u8-falcon/discussions)
- **文档**：查看 `Docs/` 目录中的其他指南

---

祝您使用愉快！🎬

