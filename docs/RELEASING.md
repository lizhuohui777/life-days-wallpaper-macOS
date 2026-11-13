# 发布与上架

## 发布前仍需审批

代码开源许可（候选 MIT）仍待确认；照片已获作者授权在 bonus/ 目录公开附赠，供本项目个人壁纸使用。扩大到商业复用、独立再分发或其他开放许可仍需作者确认。原始拍摄文件不包含在仓库中。

## GitHub 发布流程

先确认许可，更新 `Resources/Info.plist` 与 docs/CHANGELOG，再执行测试、通用架构构建和手动 GUI 验证。普通提交和 PR 只运行测试与构建；推送符合 `v版本-beta.序号` 格式的标签后，CI 会构建通用 DMG，通过测试后自动建立预发布 Release，并附上安装包与 SHA256 校验文件。发布权限仅授予标签触发的发布任务，不发布个人照片。

运行 `python3 scripts/export_public_source.py /private/tmp/life-days-public` 导出白名单源码。核对其中的 README、素材及许可后，再在该目录初始化 Git 并设置远程。不要把上一级“技能树”目录整体上传。

DMG 放到 GitHub Releases，不放源码提交中。历史 1.7 安装包在照片元数据清理前生成，不应直接公开上传；应从当前干净源码重新构建。使用授权图片构建二进制前，须单独核对素材许可；`.gitignore` 不能阻止图片进入二进制。正式版公开分发前完成 Developer ID 签名、Hardened Runtime、Apple 公证与 stapling。临时签名包仅能作为明确标注未公证的预发布测试版，不应冒充正式签名版本。凭据由仓库 Secret 或钥匙串提供，不写入源码。

## Mac App Store

当前包不能直接提交。需要实现 App Sandbox、容器内数据存储、用户选中文件访问、正式签名与公开 API 的墙纸设置；商店版应移除内部墙纸 plist 修改和进程终止功能。

后台执行应迁移到适用的 SMAppService/登录项方案，明确用户同意与停用方式，并验证沙箱下的系统权限和实际审核结果。完成隐私政策、支持联系方式、截图、应用图标、描述与素材权利证明。

参考：[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)、[App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)、[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)。满足技术要求并不保证审核通过。
