# GOwallet 1.0.0 查毒与发布验证

> 版本提示：本文保留 1.0.0 的历史检查结果。后续修复、新 APK 校验值和未解决项见 [1.0.1 安全修复与验证](VERIFICATION-1.0.1.md)。

验证日期：2026-09-07。所有 APK 结果对应下面这个最终签名文件；不是旧版本或源码文件的检测结果。

| 项目 | 结果 |
| --- | --- |
| 文件 | `gowallet-1.0.0-android-release.apk` |
| 大小 | 96,733,087 字节 |
| 版本 / 包名 | `1.0.0+9` / `org.gowallet.pow` |
| APK SHA-256 | `a960cc5ad89c6586061e704247e586b50e171723050b5d9cb1434bcb6e5fc901` |
| 签名证书 SHA-256 | `6e796fcb039900ddf4e0bd6b488fe524f665049b37fc480454fcf0f4c5a43f6e` |
| 签名检查 | Android apksigner v2 / v3 通过，签名身份与 0.4.2 相同 |
| Android 配置 | API 24+，ARM64 / x86_64，非 debuggable，禁止 Android 系统备份 |
| 钱包回归 | 98 项通过，包括交易输入认证、费用边界、备份篡改、PIN、后台锁定、自定义币种与中英文 UI |
| 定向静态分析 | `verified_prevouts.dart`、`bounded_fee.dart`、`go_launch_art.dart` 无问题 |
| 依赖公告 | OSV 查询 254 个锁定 Pub 托管依赖，0 个命中 |
| 覆盖升级 | 测试模拟器从 0.4.2 升至 1.0.0；旧 PIN、SCASH 收款地址、自定义 BTC 钱包保留；截图关闭时为黑屏，启动错误日志为 0 |

## 实际查毒结果

使用从 [Cisco-Talos/clamav 官方发布](https://github.com/Cisco-Talos/clamav/releases/tag/clamav-1.5.4) 获取的 **ClamAV 1.5.4**，通过 FreshClam 从官方镜像更新病毒库后扫描最终 APK：

- 引擎已加载签名：3,628,051；daily 病毒库版本 28115（构建于 2026-09-06 06:26 UTC），main 63，bytecode 339。
- 扫描文件 1 个，感染文件 **0**，退出码 **0**。
- 实际扫描数据 219.96 MiB（APK/归档内容），读取 92.25 MiB；耗时 63.852 秒。
- 扫描结束：2026-09-07 01:04:18 UTC / 北京时间 09:04:18。
- 启用归档扫描，单文件上限 1024 MiB、总扫描上限 2048 MiB、递归深度 30，并启用超限告警。

公开证据：[扫描记录](../evidence/malware-scan.json)、[扫描输出](../evidence/clamav-apk.txt)、[APK 验证](../evidence/release.json)、[回归输出](../evidence/regression-tests.txt)、[依赖公告结果](../evidence/pub-osv.json)、[覆盖升级验证](../evidence/upgrade.json)。发布附件提供相同的检测资料和校验文件，方便离线核对。

**这是单引擎静态检测，不是 VirusTotal 多引擎结果，也不是独立第三方安全认证。** 本次没有获得可公开核验的 VirusTotal 检测报告；构建机 Windows Defender 未启用，因此也没有声称 Defender 检测通过。扫描无命中不表示未来引擎不会报警，更不能证明所有行为安全或没有未知漏洞。

## 源码与安全审核

### MobSF 静态扫描补充（2026-09-07）

已使用官方 MobSF v4.5.2 对上述相同 SHA-256 的 APK 完成自托管静态扫描，评分 **59/100**。Scorecard 包含 **1 high、7 warning、2 info、2 secure、1 hotspot**；原生库分析另有加固规则命中。没有将这些告警视为全部修复或扫描通过，也不是 MobSF 官方或独立机构签发的认证。

[查看完整报告、告警核查与扫描限制](AUTOMATED-SECURITY.md)，含 PDF、完整 JSON、日志、环境版本和补充校验值。MobSF 的部分版本/SDK 字段提取为空；Flutter AOT 核心逻辑和运行时行为没有被全面覆盖。原 APK 和已有发布证据保持不变。

APK 中嵌入的构建源码提交为 [`d14c311d4f2ee67d14f7f24efe463a534355fa0f`](https://github.com/AlexZeroZero/GOwallet/commit/d14c311d4f2ee67d14f7f24efe463a534355fa0f)。`v1.0.0` 标签在此之后加入发布说明和检测证据；这些后续提交不改变 APP 源码。源码 ZIP 使用发布标签，GitHub 也提供自动源码归档。没有宣称独立的逐字节可复现构建。

公开源码经过 Gitleaks 8.30.1 检查，检查规则没有整体排除 Markdown 或测试目录；仅精确豁免已核对的 PIN 存储键名和公开 USDC mint 地址。上游内置 Trocador API 常量已清空。检查源码历史与归档（含嵌套资源归档），未检出未处理的规则命中。私钥、运维数据与开发日志不进入公开仓库。

已修复问题、攻击模拟与未覆盖项目详见 [安全审核记录](SECURITY-REVIEW.md)。OSV 结果只覆盖 Pub 托管包，排除 Git/path/native/SDK；定向静态分析不等于全项目零告警。未完成独立第三方全量审计、真实资金广播、实机硬件攻击或卸载恢复演练。

## 自行核验下载

从 [正式 Release](https://github.com/AlexZeroZero/GOwallet/releases/tag/v1.0.0) 同时下载 APK 与 `SHA256SUMS`：

```powershell
Get-FileHash ./gowallet-1.0.0-android-release.apk -Algorithm SHA256
apksigner verify --verbose --print-certs ./gowallet-1.0.0-android-release.apk
```

核对以上 APK SHA-256 和证书指纹。校验文件与下载来自同一来源时不能防止该来源整体被攻陷；建议保留已信任的签名指纹。已有同签名 GOwallet 用户应覆盖安装，不要先卸载。

安装 ClamAV、更新官方病毒库后，可自行重新检测：

```text
freshclam
clamscan --max-filesize=1024M --max-scansize=2048M --max-recursion=30 --alert-exceeds-max=yes gowallet-1.0.0-android-release.apk
```

重新扫描的引擎、库版本与日期可能不同，请记录自己的结果。检测报告不得作为索取助记词、私钥或备份口令的理由。
