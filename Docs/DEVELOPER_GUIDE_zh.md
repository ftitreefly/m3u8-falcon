# 开发者指南

面向希望扩展或为 M3U8Falcon 做贡献的开发者的完整指南。

## 目录

1. [项目结构](#项目结构)
2. [架构概览](#架构概览)
3. [创建自定义提取器](#创建自定义提取器)
4. [扩展服务](#扩展服务)
5. [测试](#测试)
6. [贡献](#贡献)
7. [代码风格](#代码风格)

## 项目结构

```
M3U8Falcon/
├── Sources/
│   ├── M3U8Falcon/              # 核心库
│   │   ├── Core/
│   │   │   ├── DependencyInjection/  # DI 系统
│   │   │   ├── Parsers/              # M3U8 解析
│   │   │   ├── Protocols/            # 协议定义
│   │   │   └── Types/                # 类型定义
│   │   ├── Services/
│   │   │   ├── Default/              # 默认实现
│   │   │   ├── Network/              # 网络层
│   │   │   └── Streaming/            # 流式支持
│   │   ├── Utilities/
│   │   │   ├── Errors/               # 错误类型
│   │   │   ├── Extensions/           # Swift 扩展
│   │   │   ├── Logging/              # 日志系统
│   │   │   └── ResourceManagement/   # 资源清理
│   │   └── M3U8Falcon.swift          # 公共 API
│   └── M3U8FalconCLI/            # CLI 工具
│       ├── Commands/              # CLI 命令
│       └── Extractors/            # CLI 特定提取器
├── Tests/                        # 测试套件
└── Docs/                         # 文档
```

## 架构概览

### 依赖注入

M3U8Falcon 使用依赖注入系统以提高可测试性和模块化。

#### 核心组件

- **DependencyContainer**：管理服务注册和解析
- **DIConfiguration**：服务配置
- **GlobalDependencies**：单例容器实例

#### 注册服务

```swift
// 服务在 DependencyContainer 中注册
let container = DependencyContainer()
container.register(NetworkClientProtocol.self) { _ in
    EnhancedNetworkClient()
}
```

### 面向协议设计

库广泛使用协议以实现可扩展性：

- **M3U8LinkExtractorProtocol**：用于自定义链接提取器
- **ServiceProtocols**：核心服务协议
- 所有服务都基于协议，便于在测试中模拟

## 创建自定义提取器

### 概述

提取器用于从网页中提取 M3U8 链接。您可以为特定的视频托管网站创建自定义提取器。

### 实现步骤

#### 1. 实现协议

```swift
import Foundation
import M3U8Falcon

final class MyCustomExtractor: M3U8LinkExtractorProtocol {
    
    private let supportedDomains = ["example.com", "video.example.com"]
    
    public init() {}
    
    // 核心提取方法
    public func extractM3U8Links(
        from url: URL,
        options: LinkExtractionOptions
    ) async throws -> [M3U8Link] {
        // 1. 下载网页
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // 2. 解析 HTML 以查找 M3U8 链接
        var links: [M3U8Link] = []
        
        // 您的自定义解析逻辑
        // 示例：使用正则表达式、HTML 解析器或 JavaScript 执行
        
        // 3. 返回找到的链接
        return links
    }
    
    // 返回支持的域名
    public func getSupportedDomains() -> [String] {
        return supportedDomains
    }
    
    // 返回提取器信息
    public func getExtractorInfo() -> ExtractorInfo {
        return ExtractorInfo(
            name: "我的自定义提取器",
            version: "1.0.0",
            supportedDomains: getSupportedDomains(),
            capabilities: [.directLinks, .javascriptVariables]
        )
    }
    
    // 检查此提取器是否可以处理该 URL
    public func canHandle(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return supportedDomains.contains { host.hasSuffix($0) }
    }
}
```

#### 2. 注册提取器

```swift
// 在应用程序初始化中
let registry = DefaultM3U8ExtractorRegistry()
let customExtractor = MyCustomExtractor()
registry.registerExtractor(customExtractor)
```

#### 3. 使用提取器

```swift
let url = URL(string: "https://example.com/video-page")!
let links = try await registry.extractM3U8Links(
    from: url,
    options: LinkExtractionOptions.default
)
```

### 提取器最佳实践

1. **错误处理**：始终优雅地处理错误
2. **超时**：遵守 `LinkExtractionOptions` 中的超时设置
3. **重试**：使用选项中的重试机制
4. **验证**：在返回之前验证提取的 URL
5. **性能**：尽可能缓存解析结果

### 示例：YouTube 提取器

请参阅 `Sources/M3U8FalconCLI/Extractors/YouTubeExtractor.swift` 获取完整示例。

## 扩展服务

### 创建自定义服务

您可以通过实现自定义服务协议来扩展 M3U8Falcon。

#### 示例：自定义网络客户端

```swift
import Foundation
import M3U8Falcon

final class CustomNetworkClient: NetworkClientProtocol {
    
    func download(
        from url: URL,
        timeout: TimeInterval
    ) async throws -> Data {
        // 您的自定义网络实现
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    func download(
        from url: URL,
        to destination: URL,
        timeout: TimeInterval
    ) async throws {
        // 您的自定义下载实现
        let (localURL, _) = try await URLSession.shared.download(from: url)
        try FileManager.default.moveItem(at: localURL, to: destination)
    }
}
```

#### 注册自定义服务

```swift
// 创建自定义配置
var config = DIConfiguration.performanceOptimized()

// 注册自定义服务（如果 DI 系统支持）
// 注意：这可能需要修改 DI 容器

await M3U8Falcon.initialize(with: config)
```

## 测试

M3U8Falcon 使用 Swift Testing 框架进行所有测试。Swift Testing 提供了现代化的、类型安全的测试 API，与 Swift 6+ 无缝集成。

### 运行测试

```bash
# 运行所有测试
swift test

# 运行详细输出的测试
swift test --verbose

# 运行特定测试套件
swift test --filter ParseTests
```

### 编写测试

#### 测试结构

```swift
import Foundation
import Testing
@testable import M3U8Falcon

@Suite("我的提取器测试")
final class MyExtractorTests {
    
    private var extractor: MyCustomExtractor
    
    init() {
        extractor = MyCustomExtractor()
    }
    
    @Test("从 URL 提取 M3U8 链接")
    func testExtraction() async throws {
        let url = URL(string: "https://example.com/video")!
        let links = try await extractor.extractM3U8Links(
            from: url,
            options: .default
        )
        
        #expect(!links.isEmpty)
    }
}
```

#### 模拟服务

```swift
// 创建模拟服务
final class MockNetworkClient: NetworkClientProtocol {
    var downloadData: Data?
    var downloadError: Error?
    
    func download(from url: URL, timeout: TimeInterval) async throws -> Data {
        if let error = downloadError {
            throw error
        }
        return downloadData ?? Data()
    }
    
    func download(from url: URL, to destination: URL, timeout: TimeInterval) async throws {
        // 模拟实现
    }
}
```

### 测试覆盖率

争取高测试覆盖率：
- 单个组件的单元测试
- 工作流的集成测试
- 关键路径的性能测试

## 贡献

### 开始

1. **Fork 仓库**
2. **创建功能分支**：`git checkout -b feature/my-feature`
3. **进行更改**
4. **编写测试**为您的更改
5. **运行测试**：`swift test`
6. **提交更改**：`git commit -am 'Add my feature'`
7. **推送到分支**：`git push origin feature/my-feature`
8. **创建 Pull Request**

### Pull Request 指南

1. **清晰的描述**：描述什么和为什么
2. **测试**：包含新功能的测试
3. **文档**：如需要，更新文档
4. **代码风格**：遵循项目的代码风格
5. **小 PR**：保持拉取请求专注且小

### 问题报告

报告问题时，请包括：
- Swift 版本
- macOS 版本
- 重现步骤
- 预期行为
- 实际行为
- 错误消息/日志

## 代码风格

### Swift 风格指南

遵循 Swift API 设计指南和这些约定：

#### 命名

```swift
// ✅ 好
func downloadVideo(from url: URL) async throws

// ❌ 不好
func dl(url: URL) async throws
```

#### 错误处理

```swift
// ✅ 好 - 特定错误类型
throw NetworkError.timeout(url: url)

// ❌ 不好 - 通用错误
throw NSError(domain: "error", code: 1)
```

#### 并发

```swift
// ✅ 好 - 使用 async/await
func download() async throws -> Data

// ❌ 不好 - 回调
func download(completion: @escaping (Result<Data, Error>) -> Void)
```

#### 文档

```swift
/// 从 URL 下载 M3U8 内容
///
/// - Parameters:
///   - url: 要下载的 URL
///   - timeout: 请求超时时间（秒）
/// - Returns: 下载的数据
/// - Throws: 如果下载失败，抛出 NetworkError
func download(from url: URL, timeout: TimeInterval) async throws -> Data
```

### 文件组织

- 每个文件一个类型（如可能）
- 在文件夹中组织相关类型
- 使用 MARK 注释进行组织

```swift
// MARK: - Public API

// MARK: - Private Helpers
```

## 高级主题

### 内存管理

- 对委托使用弱引用
- 在 `deinit` 中清理资源
- 使用 `TaskGroup` 进行并发操作

### 性能优化

- 适当使用并发下载
- 缓存解析结果
- 最小化内存分配
- 使用 Instruments 进行分析

### 错误处理策略

- 使用特定错误类型
- 在错误中提供上下文
- 适当记录错误
- 不要静默吞掉错误

## 资源

- [Swift 文档](https://swift.org/documentation/)
- [Swift 并发](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Swift Package Manager](https://swift.org/package-manager/)
- [项目概览](PROJECT_OVERVIEW_zh.md)
- [API 参考](API_REFERENCE.md)

## 获取帮助

- **GitHub Issues**：[报告错误或提问](https://github.com/ftitreefly/m3u8-falcon/issues)
- **GitHub Discussions**：[讨论想法](https://github.com/ftitreefly/m3u8-falcon/discussions)
- **代码审查**：提交 PR 进行代码审查

---

祝您编码愉快！💻

