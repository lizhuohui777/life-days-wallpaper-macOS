# 人生天数壁纸 / Life Days Wallpaper

[![macOS validation](https://github.com/lizhuohui777/life-days-wallpaper-macOS/actions/workflows/macos.yml/badge.svg)](https://github.com/lizhuohui777/life-days-wallpaper-macOS/actions/workflows/macos.yml)

**把人生的每一天，放进你喜欢的风景里。**

选择照片、起始日期和玩家名字，让 Mac 桌面每天自动显示人生天数。起始当天计为第 1 天。

![狮子背景：用户自行导入照片后的壁纸效果](docs/images/lion-wallpaper.jpg)

狮子照片由作者本人拍摄，展示**自行上传背景图片**后的效果；`Player` 和 `10,000 Days` 为演示数据。

## 下载与安装

适用于 macOS 13 及以上，支持 Apple 芯片和 Intel Mac。

1. 从 [下载页面](https://github.com/lizhuohui777/life-days-wallpaper-macOS/releases/tag/v1.8.1-beta.1) 下载 **Life-Days-Wallpaper-1.8.1-beta.1.dmg**。GitHub 的 `Source code` 是开发源码，不是安装包。
2. 打开 DMG，把「人生天数壁纸」拖到「Applications / 应用程序」，再打开应用。
3. 设置日期和玩家名字；点击「选择背景图片…」导入自己的照片，再点击「应用并开启每日更新」。首次应用时允许控制 System Events。

当前下载为**预发布测试版，使用临时签名，尚未完成 Apple 公证**。若 macOS 拦截启动，仅在确认下载来自本仓库且信任软件后，按[安装说明](docs/INSTALL.md)操作；不要关闭系统安全保护。

## 换成你喜欢的风景

照片由用户主动选择，处理都在本机完成，不上传服务器。支持 JPEG、PNG、HEIC、TIFF，可随时恢复自带背景。

喜欢预览里的狮子？下载[附赠狮子照片](bonus/lion.jpg)后在应用内导入。照片已清除隐私元数据，使用范围见[附赠图片说明](bonus/README.md)。

程序默认使用自动生成的山丘背景。狮子照片独立放在 `bonus/` 中，不自动打包进应用。

### 查看原生界面结构与默认背景

![界面结构示意](docs/images/interface.svg)

![程序默认山丘背景](docs/images/example-wallpaper.png)

界面图为结构示意，非系统截图；两张壁纸图由程序预览模式生成。

## 每日更新

- 按本机时区计算自然日，每 60 秒检查日期，并安排午夜检查；休眠时不运行，唤醒后恢复检查。
- 更新内容使用新的图片路径，避免系统复用旧缓存；确认应用后清理本程序不再被系统引用的旧图。退出设置窗口后，已开启的后台任务仍运行。
- 旧墙纸记录兼容清理默认关闭；仅在遇到旧图片循环问题时启用。
- 不修改 Dock、Command＋Tab 或系统显示缩放。

固定画布为 3024 × 1964，不同屏幕比例或锁屏时钟下可能裁切、遮挡。兼容清理依赖 macOS 内部格式，未来系统版本可能变化。

## 文档与开发

日常安装只需要 DMG。仓库文件按用途归档：`Sources/` 源码、`Resources/` 应用资源、`Tests/` 测试、`scripts/` 构建工具、`docs/` 文档、`bonus/` 附赠图片。

- [安装与启动问题](docs/INSTALL.md) · [停用与卸载](docs/UNINSTALL.md)
- [从源码构建](docs/DEVELOPMENT.md) · [贡献指南](docs/CONTRIBUTING.md)
- [隐私说明](docs/PRIVACY.md) · [安全说明](SECURITY.md)
- [更新记录](docs/CHANGELOG.md) · [发布与 App Store 准备](docs/RELEASING.md)
- [素材权利](docs/ASSETS.md) · [许可状态](LICENSE) · [验证记录](docs/VALIDATION.md)

仓库公开供查看，代码开源许可仍待作者确认；照片使用范围单独说明。原始照片、个人设置和日志不随仓库发布。报告问题前请删除姓名、日期、个人路径和照片。
