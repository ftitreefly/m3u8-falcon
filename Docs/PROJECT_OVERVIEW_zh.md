# M3U8Falcon - 项目概览

## 简介

M3U8Falcon 是一个高性能的 Swift 库和命令行工具，专为下载、解析和处理 M3U8 视频文件而设计。基于 Swift 6+ 特性、现代并发模式和全面的依赖注入架构构建，为处理 HTTP 直播流（HLS）内容提供了强大的解决方案。

## 什么是 M3U8？

M3U8 是一种基于文本的播放列表格式，用于 HTTP 直播流（HLS）。它包含对组成视频流的媒体片段的引用。M3U8 文件通常被视频流媒体服务用于提供自适应比特率流媒体内容。

## 项目目标

### 主要目标

1. **高性能**：高效下载和处理 M3U8 视频流，资源占用最小
2. **可靠性**：强大的错误处理和网络操作重试机制
3. **可扩展性**：基于协议的架构，便于集成自定义提取器和处理器
4. **开发体验**：清晰的 API 设计，提供全面的文档和示例
5. **生产就绪**：广泛的测试、适当的错误处理和日志功能

### 核心特性

- **Swift 6+ 就绪**：利用最新的 Swift 并发特性，包括严格的并发检查
- **依赖注入**：完整的 DI 架构，提高可测试性和模块化
- **跨平台**：支持 macOS 12.0+，提供库和 CLI 两种接口
- **全面的错误处理**：详细的错误类型和上下文信息
- **并发下载**：可配置的并发下载支持（最多 20 个并发任务）
- **高级日志系统**：多级别日志，支持分类和彩色输出
- **多源支持**：支持 Web URL 和本地 M3U8 文件
- **视频处理**：FFmpeg 集成，用于视频片段合并
- **加密支持**：内置加密 M3U8 流支持，可自定义密钥/IV 覆盖
- **可扩展架构**：基于协议的设计，便于第三方集成

## 架构概览

### 核心组件

#### 1. 依赖注入系统
- **位置**：`Sources/M3U8Falcon/Core/DependencyInjection/`
- **目的**：管理服务注册和解析
- **关键文件**：
  - `DependencyContainer.swift`：主 DI 容器
  - `DIConfiguration.swift`：配置管理

#### 2. M3U8 解析器
- **位置**：`Sources/M3U8Falcon/Core/Parsers/M3U8Parser/`
- **目的**：解析 M3U8 播放列表文件（主播放列表和媒体播放列表）
- **关键特性**：
  - 主播放列表解析
  - 媒体播放列表解析
  - 基于标签的解析系统

#### 3. 下载服务
- **位置**：`Sources/M3U8Falcon/Services/Default/`
- **目的**：处理 M3U8 文件和视频片段的下载
- **关键组件**：
  - `DefaultM3U8Downloader.swift`：主下载编排器
  - `StreamingDownloader.swift`：流式下载支持
  - `DefaultTaskManager.swift`：并发任务管理

#### 4. 网络层
- **位置**：`Sources/M3U8Falcon/Services/Network/`
- **目的**：带重试策略的网络通信
- **关键特性**：
  - 带重试逻辑的增强网络客户端
  - 可配置的重试策略
  - 超时处理

#### 5. 视频处理
- **位置**：`Sources/M3U8Falcon/Services/Default/DefaultVideoProcessor.swift`
- **目的**：使用 FFmpeg 合并视频片段
- **特性**：
  - 片段合并
  - 加密处理
  - 格式转换支持

#### 6. 链接提取
- **位置**：`Sources/M3U8Falcon/Services/Default/`
- **目的**：从网页中提取 M3U8 链接
- **关键组件**：
  - `DefaultM3U8LinkExtractor.swift`：基础提取器
  - `DefaultM3U8ExtractorRegistry.swift`：提取器注册表
  - 基于协议的自定义提取器设计

#### 7. CLI 接口
- **位置**：`Sources/M3U8FalconCLI/`
- **目的**：面向最终用户的命令行接口
- **命令**：
  - `download`：下载 M3U8 视频
  - `extract`：从网页提取 M3U8 链接
  - `info`：显示工具信息

### 设计模式

#### 依赖注入
所有服务都通过依赖注入容器注册，允许：
- 使用模拟服务轻松测试
- 灵活的配置
- 组件之间的松耦合

#### 面向协议编程
核心功能通过协议定义：
- `M3U8LinkExtractorProtocol`：用于自定义链接提取器
- `ServiceProtocols.swift`：核心服务协议
- 便于扩展和自定义

#### 现代 Swift 并发
- 使用 `async/await` 进行异步操作
- `Task` 和 `TaskGroup` 用于并发操作
- 启用严格的并发检查

## 技术栈

### 核心技术
- **Swift 6.0+**：具有严格并发的现代 Swift
- **Foundation**：核心系统框架
- **Swift Argument Parser**：CLI 参数解析

### 外部依赖
- **FFmpeg**：视频处理和片段合并（系统依赖）

### 开发工具
- **Swift Package Manager**：依赖管理
- **XCTest**：测试框架

## 项目结构

```
M3U8Falcon/
├── Sources/
│   ├── M3U8Falcon/          # 核心库
│   │   ├── Core/            # 核心组件
│   │   ├── Services/        # 服务实现
│   │   └── Utilities/       # 工具函数
│   └── M3U8FalconCLI/       # CLI 工具
├── Tests/                   # 测试套件
├── Docs/                    # 文档
└── Package.swift            # 包配置
```

## 使用场景

### 1. 视频下载
从 M3U8 播放列表下载完整视频以供离线观看。

### 2. 链接提取
自动从视频托管网站提取 M3U8 链接。

### 3. 播放列表分析
解析和分析 M3U8 播放列表结构以进行调试或分析。

### 4. 自定义集成
将 M3U8 下载功能集成到您自己的应用程序中。

## 目标受众

### 最终用户
- 想要从 M3U8 流下载视频的用户
- 需要离线访问流媒体内容的用户
- 偏好命令行工具的用户

### 开发者
- 构建视频相关应用程序的 Swift 开发者
- 需要 M3U8 解析功能的开发者
- 创建自定义视频提取器的开发者

## 性能特征

- **并发下载**：最多 20 个并发片段下载
- **内存高效**：流式下载，内存占用最小
- **网络优化**：重试策略和超时处理
- **资源管理**：自动清理临时文件

## 安全考虑

- **加密支持**：支持加密流的 AES-128 解密
- **自定义密钥**：支持自定义解密密钥和 IV
- **安全下载**：支持 HTTPS 安全连接
- **输入验证**：全面验证 URL 和文件路径

## 未来路线图

潜在的未来增强功能：
- 更多平台支持（Linux、Windows）
- 更多视频格式支持
- 增强的提取器生态系统
- GUI 应用程序
- 高级视频处理选项

## 贡献

我们欢迎贡献！请参阅[贡献指南](CONTRIBUTING.md)了解详情：
- 代码风格指南
- 测试要求
- 拉取请求流程
- 问题报告

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](../LICENSE) 文件。

## 支持

- **文档**：请参阅 `Docs/` 目录中的其他指南
- **问题**：[GitHub Issues](https://github.com/ftitreefly/m3u8-falcon/issues)
- **讨论**：[GitHub Discussions](https://github.com/ftitreefly/m3u8-falcon/discussions)

---

由 M3U8Falcon 团队用 ❤️ 制作

