# Linux 支持指南

<!-- markdownlint-disable-next-line MD033 -->
<img src="../Logo-512px.png" alt="M3U8Falcon 标志" width="200">

M3U8Falcon 在 Linux 平台上的完整使用指南。

## 📋 目录

1. [概述](#概述)
2. [安装](#安装)
3. [平台特定功能](#平台特定功能)
4. [架构](#架构)
5. [平台差异](#平台差异)
6. [构建和测试](#构建和测试)
7. [故障排除](#故障排除)
8. [性能考虑](#性能考虑)

## 概述

M3U8Falcon 提供完整的 Linux 支持，并提供平台特定优化。库会自动检测平台并使用相应的实现来处理进程执行、网络流和文件系统操作。

### 支持的 Linux 发行版

- ✅ Ubuntu 20.04+
- ✅ Debian 11+
- ✅ Fedora 34+
- ✅ RHEL 8+
- ✅ Arch Linux
- ✅ 其他支持 Swift 6.0+ 的发行版

### 系统要求

- **Swift**: 6.0 或更高版本
- **FFmpeg**: 视频处理必需
- **系统库**: 标准 Linux 系统库（libc、libpthread 等）

## 安装

### 步骤 1: 安装 Swift

```bash
# Ubuntu/Debian
wget -q https://swift.org/builds/swift-6.0-release/ubuntu2204/swift-6.0-RELEASE/swift-6.0-RELEASE-ubuntu22.04.tar.gz
tar xzf swift-6.0-RELEASE-ubuntu22.04.tar.gz
sudo mv swift-6.0-RELEASE-ubuntu22.04 /opt/swift
export PATH=/opt/swift/usr/bin:$PATH

# Fedora/RHEL
sudo dnf install swift-lang

# Arch Linux
yay -S swift-bin
```

### 步骤 2: 安装 FFmpeg

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install ffmpeg

# Fedora/RHEL
sudo dnf install ffmpeg

# Arch Linux
sudo pacman -S ffmpeg
```

### 步骤 3: 添加到项目

在 `Package.swift` 中添加 M3U8Falcon：

```swift
dependencies: [
    .package(url: "https://github.com/ftitreefly/m3u8-falcon.git", from: "1.2.0")
]
```

### 步骤 4: 验证安装

```bash
# 克隆仓库
git clone https://github.com/ftitreefly/m3u8-falcon.git
cd m3u8-falcon

# 构建项目
swift build

# 运行测试
swift test

# 测试 CLI
swift run m3u8-falcon --version
```

## 平台特定功能

### 1. 进程执行

Linux 使用基于轮询的方法来捕获进程输出，针对 Linux 的进程处理进行了优化：

```swift
// Linux 自动使用 LinuxProcessExecutor
let result = try await processExecutor.execute(
    executable: "/usr/bin/ffmpeg",
    arguments: ["-version"],
    timeout: 10.0
)
```

**关键特性：**
- ✅ 使用 `DispatchGroup` 进行连续轮询，可靠捕获输出
- ✅ 线程安全的数据累积
- ✅ 正确的信号处理和清理
- ✅ 支持超时和取消

### 2. 流式下载

Linux 使用 `URLSessionDataDelegate` 进行字节流传输，提供高效的内存使用：

```swift
// 自动使用 LinuxStreamingNetworkClient
let (response, stream) = try await streamingClient.fetchAsyncBytes(from: url)
for try await byte in stream {
    // 处理字节
}
```

**关键特性：**
- ✅ 批处理缓冲（8KB 批次）以提高性能
- ✅ 内存高效的流式传输
- ✅ 正确的错误处理和清理
- ✅ 线程安全的 continuation 管理

### 3. 文件系统操作

Linux 遵循 XDG Base Directory 规范：

```swift
// 下载目录解析
// macOS: ~/Downloads
// Linux: XDG_DOWNLOAD_DIR 或 ~/Downloads
let downloadsDir = FileManager.default.urls(
    for: .downloadsDirectory,
    in: .userDomainMask
).first!
```

**XDG 合规性：**
- ✅ 遵循 `XDG_DOWNLOAD_DIR` 环境变量
- ✅ 回退到 `~/.config/user-dirs.dirs`
- ✅ 如果未配置 XDG，则默认使用 `~/Downloads`

### 4. 线程安全

Linux 使用 `NSLock` 和 `DispatchGroup` 进行线程安全操作：

```swift
// 平台感知的并发
private let lock = NSLock()
private let group = DispatchGroup()

lock.lock()
defer { lock.unlock() }
// 线程安全操作
```


## 构建和测试

### 构建命令

```bash
# 调试构建
swift build

# 发布构建
swift build -c release

# 详细输出构建
swift build -v

# 清理构建
swift package clean
swift build
```

### 运行测试

```bash
# 运行所有测试
swift test

# 详细输出运行
swift test --verbose

# 运行特定测试套件
swift test --filter ParseTests

# 并行运行测试
swift test --parallel
```

### CLI 使用

```bash
# 构建 CLI
swift build -c release

# 直接运行 CLI
swift run m3u8-falcon https://example.com/video.m3u8

# 安装 CLI（可选）
sudo cp .build/release/m3u8-falcon /usr/local/bin/
```

## 故障排除

### 常见问题

#### 1. 找不到 FFmpeg

**问题：** `FFmpeg not found in PATH`

**解决方案：**
```bash
# 验证 FFmpeg 安装
which ffmpeg
ffmpeg -version

# 如果未找到，安装 FFmpeg
sudo apt install ffmpeg  # Ubuntu/Debian
sudo dnf install ffmpeg  # Fedora/RHEL

# 或指定自定义路径
export PATH=$PATH:/custom/path/to/ffmpeg
```

#### 2. Swift 版本问题

**问题：** `Swift version 6.0 or later is required`

**解决方案：**
```bash
# 检查 Swift 版本
swift --version

# 更新 Swift（参见安装部分）
# 或使用 Swift 工具链管理器
```

#### 3. 权限被拒绝

**问题：** 无法写入下载目录

**解决方案：**
```bash
# 检查目录权限
ls -ld ~/Downloads

# 如需要，修复权限
chmod 755 ~/Downloads

# 或使用自定义目录
export XDG_DOWNLOAD_DIR=/path/to/downloads
```

#### 4. 网络超时

**问题：** Linux 上下载超时

**解决方案：**
```swift
// 在配置中增加超时时间
let config = DIConfiguration(
    downloadTimeout: 120.0  // 2 分钟
)
await M3U8Falcon.initialize(with: config)
```

#### 5. 进程执行挂起

**问题：** Linux 上进程执行器挂起

**解决方案：**
- 确保设置了适当的超时
- 检查进程是否实际运行：`ps aux | grep ffmpeg`
- 验证进程具有适当的权限
- 检查系统资源（内存、CPU）

### 调试模式

启用详细日志进行故障排除：

```swift
// 启用调试日志
Logger.configure(.development())

// 或自定义配置
let config = LoggerConfiguration(
    minimumLevel: .debug,
    includeTimestamps: true,
    enableColors: true
)
Logger.configure(config)
```

## 性能考虑

### 优化技巧

1. **批处理大小**：Linux 流式传输使用 8KB 批次以获得最佳性能
2. **轮询间隔**：进程执行器使用 10ms 轮询间隔
3. **并发下载**：在 Linux 上限制为 10-15 个并发任务以获得最佳性能
4. **内存管理**：流式下载通过批处理缓冲实现内存高效

### 基准测试

```bash
# 构建发布版本
swift build -c release

# 运行性能测试
swift test --filter PerformanceOptimizedTests
```

### 资源使用

- **内存**：约 50-100MB 基础，每个并发下载 +10-20MB
- **CPU**：空闲时最少，随并发下载扩展
- **网络**：受系统网络堆栈和带宽限制

## 其他资源

- [主 README](../README.md) - 项目概览
- [用户指南](USER_GUIDE_zh.md) - 完整使用指南
- [开发者指南](DEVELOPER_GUIDE_zh.md) - 扩展和贡献指南
- [项目概览](PROJECT_OVERVIEW_zh.md) - 架构详情

## 支持

- **GitHub Issues**：[报告 Linux 特定问题](https://github.com/ftitreefly/m3u8-falcon/issues)
- **GitHub Discussions**：[提问](https://github.com/ftitreefly/m3u8-falcon/discussions)

---

**最后更新**：2026-05-22
**M3U8Falcon 版本**：1.3.2+

