# GOwallet 1.0.0 自动安全扫描报告

检查日期：2026-09-07。**使用第三方开源工具 MobSF 在项目开发环境自行运行的静态扫描，不是 MobSF 团队或独立审计机构签发的审计报告。** 本次有未关闭告警，不能表述为“第三方审计通过”“无漏洞”或“资金安全认证”。

后续 [高等级告警深入复核](SECURITY-FOLLOWUP.md) 已检查安全存储回退、迁移实现和实际 ELF 结构，发现需要优先处理的存储回退行为，并为两个 Flutter AOT 产物的 RELRO 规则适用性提供了证据。该复核没有修改 APP 或原始扫描结果，不能视为问题已修复。

## 结果和扫描对象

| 项目 | 实际结果 |
| --- | --- |
| MobSF | 官方 v4.5.2，静态 APK 分析；无动态设备分析 |
| 开始 / 完成 | 2026-09-07 01:37:31 / 01:38:15 UTC |
| 文件 | `gowallet-1.0.0-android-release.apk`，96,733,087 字节 |
| APK SHA-256 | `a960cc5ad89c6586061e704247e586b50e171723050b5d9cb1434bcb6e5fc901` |
| 包名 / 发布版本 | `org.gowallet.pow` / `1.0.0+9`；版本来自独立发布验证，MobSF 对版本字段提取为空 |
| MobSF 评分 | **59/100，工具标记 MEDIUM RISK**；评分不是安全概率或认证等级 |
| Scorecard 分类计数 | **1 high、7 warning、2 info、2 secure、1 hotspot**；hotspot 包含相机和通知两项危险权限 |
| 原生库规则 | 13 个 APK 库路径中另有 **10 high、11 warning** 规则命中，不能被上述 1 high 概括 |
| 已知追踪 SDK | 在本次 432 条追踪器签名范围内未检出；不等于没有网络行为或隐私风险 |
| APK 签名 | MobSF 检出 v2/v3 签名，证书指纹与发布记录一致 |
| ClamAV | 此前对相同 APK 检出感染文件 0；见[查毒证据](VERIFICATION.md) |
| VirusTotal | **尚未取得可公开核验的多引擎结果**；未列为检测通过 |

签名证书 SHA-256：`6e796fcb039900ddf4e0bd6b488fe524f665049b37fc480454fcf0f4c5a43f6e`。APK 对应源码提交为 [`d14c311d4f2ee67d14f7f24efe463a534355fa0f`](https://github.com/AlexZeroZero/GOwallet/commit/d14c311d4f2ee67d14f7f24efe463a534355fa0f)。本次仅新增扫描证据和说明，没有重新构建或替换 1.0.0 APK。

## 下载实际报告

- [MobSF 原始 PDF（52 页）](../evidence/automated-security/2026-09-07/mobsf-report.pdf)
- [完整 JSON 报告](../evidence/automated-security/2026-09-07/mobsf-report.json)
- [Scorecard](../evidence/automated-security/2026-09-07/mobsf-scorecard.json)
- [扫描阶段日志](../evidence/automated-security/2026-09-07/mobsf-scan-logs.json)
- [扫描环境与时间](../evidence/automated-security/2026-09-07/scan-metadata.json)、[导出及发布元数据](../evidence/automated-security/2026-09-07/publication-metadata.json)
- [报告文件 SHA-256](../evidence/automated-security/2026-09-07/SHA256SUMS)

[v1.0.0 Release](https://github.com/AlexZeroZero/GOwallet/releases/tag/v1.0.0) 补充提供 `gowallet-1.0.0-mobsf-20260907.zip`、`gowallet-1.0.0-mobsf-20260907.pdf` 和 `AUTOMATED-SECURITY-SHA256SUMS`。原 APK、源码 ZIP、版本标签及已有校验文件未被替换。

JSON 仅重新缩进排版，已验证解析后的全部值与 API 原始输出相同；PDF 保持逐字节不变。没有删除、降级或抑制工具告警。元数据保留 API 原始导出的哈希，可与排版后的发布文件区分。项目说明中的核查意见不修改原始结果。

## 告警核查与未完成事项

下列是项目侧对规则的初步复核，不是独立专家审计，也没有完成利用验证。反编译路径以完整 JSON 中的路径为准。

| 告警 | 核查结果与后续工作 |
| --- | --- |
| **High：CBC + PKCS7** | 命中 `s/AbstractC0693i.java:105` 和 `x1/h.java:79`。前者是 AndroidX Biometric 的辅助 CryptoObject，后者是 Flutter 安全存储依赖中的 CBC 实现。当前主存储入口显式启用 `encryptedSharedPreferences: true`（[配置](../lib/providers/global/secure_store_provider.dart)）。仅发现 CBC 代码不能证明存在可访问的 padding oracle；仍须核查旧数据迁移、回退路径、错误可观察性和密文篡改处理。**告警保持开放，不认定为已修复或已证实可利用。** |
| **High/Warning：原生库加固** | 三种 ABI 的 `libsqlite3.so` 和 `libisar.so` 未检出 stack canary、FORTIFY；`libsecp256k1.so` 检出 canary 和 Full RELRO，但未检出 FORTIFY。两个 `libapp.so` 另被标记无 canary、无 RELRO、无 FORTIFY。Flutter AOT 的部分通用 ELF 规则可能不适用，需要结合产物布局确认；SQLite/Isar 等本地库需检查编译参数及实际暴露面。不能把所有项统一视为 Flutter 误报，也没有证明存在内存破坏利用。 |
| Warning：非标准 Activity 启动模式 | 实际清单为 `singleInstance`。需进一步测试任务栈、外部 Intent 与锁定状态；不应在 Intent 携带助记词、私钥或口令。未在本次修改该行为。 |
| Warning：导出的 ProfileInstallReceiver | 清单使用系统 `android.permission.DUMP` 保护。它不是普通应用可直接取得的一般权限；实际访问还取决于系统权限级别、签名/特权及调试授权。规则要求核实保护级别，不等于“任意应用均可访问”。本次未做跨应用实机攻击验证。 |
| Warning：非密码学随机数 | `t2`/`u2` 命中 Java Random/ThreadLocalRandom 相关实现；规则未建立其与钱包助记词生成的调用关系。不能据此认定助记词弱随机，也不能据此证明熵源安全；需要对 Dart 及原生调用链单独核查。 |
| Warning：外部存储 | Android/插件的文件路径 API 命中不证明明文密钥已写入公共目录。需继续验证所有导入/导出、分享与取消流程，尤其备份文件及临时文件生命周期。 |
| Warning：疑似硬编码凭据 | 已核对的通知插件命中是 `CALLBACK_*_KEY`、`groupKey` 等字段名；安全存储中 Base64 常量是 SharedPreferences 的键名，真实 AES 密钥由 SecureRandom 生成后封装保存。报告还列出其他字符串候选，不能将整个候选列表一概判定为凭据泄露或全部误报；原始候选保留供复核。 |
| Warning：临时文件 | 条码库在条件启用时把扫描图片写入应用 `getCacheDir()`。这是应用缓存路径，但图像仍可能包含敏感二维码；应继续核查调用开关、删除时机及系统备份边界。 |
| Info：日志和剪贴板 | 检测到相关 API。需检查运行时是否有敏感数据进入日志或剪贴板、后台时是否清除；静态规则不能证明没有泄露。 |
| Hotspot：相机和通知权限 | 属于危险权限类别，分别支持扫码和通知能力。应按需申请、允许拒绝；不应把“危险权限”直接当成恶意软件证据。 |

原始 binary analysis 同时列出 `lib/...` 和解包副本 `apktool_out/lib/...`，共 26 条记录。上述 13 个库路径、10 high 和 11 warning 按原 APK 的 `lib/...` 统计，每项代表一个规则命中，**不是 10 个已确认漏洞**。原报告保留重复记录。

## 工具与覆盖限制

- 官方工具来源：[MobSF v4.5.2](https://github.com/MobSF/Mobile-Security-Framework-MobSF/releases/tag/v4.5.2)。使用镜像 `opensecurity/mobile-security-framework-mobsf`，固定 digest：`sha256:af94f81f8b13872cdf556327fab58f52d446299fe153be6e1eeec177f31b503b`。
- 扫描接口仅绑定本机回环地址，在隔离容器中上传已经公开的签名 APK，没有挂载钱包数据、助记词或发布签名私钥。扫描日志完成到数据库保存阶段，记录的 exception 均为空；这不代表各工具无漏报。
- MobSF 输出的 versionName/versionCode/minSdk/targetSdk 字段为空，PDF 封面图标未成功渲染。保留原始输出，不补造字段；请用[独立 APK 验证](VERIFICATION.md)核对版本和 SDK。依赖这些字段的规则覆盖可能受影响。
- MobSF 主要分析 Manifest、反编译 Java/DEX、资源字符串及 ELF 特征，**没有全面反编译审计 Flutter AOT 内的钱包逻辑**。签名算法、种子熵、PIN 派生、密钥内存、TLS 运行时行为与恶意节点响应等需要独立代码和动态验证。
- `network_security` 没有告警不意味着所有连接加密。GOwallet 仍允许用户配置明文 TCP；建议 TLS。没有抓包、动态恶意软件行为测试、完整 SPV 或全量密码学审计。
- “未检出已知追踪 SDK”和字符串域名信誉结果不覆盖全部运行时目的地。APK 查毒、代码安全分析和人工审计是不同工作。
- VirusTotal 上传页面要求同意服务条款、隐私声明及样本共享；本次报告发布时尚未完成该项提交与结果核验，不提供虚构的检测计数。

## 自行复核

先下载正式 APK 并核对 SHA-256。可使用上述官方镜像 digest 启动自己的 MobSF，将 Web 端口仅映射到 `127.0.0.1`，上传该文件，运行静态分析并导出 JSON、scorecard、扫描日志和 PDF。比较输入哈希、工具版本、日期和各项告警，而非只看评分。追踪器库、域名信誉服务和工具版本变化可能导致后续结果不同。

报告应与[既有源码复核与未覆盖项](SECURITY-REVIEW.md)、[非托管和 Electrum 信任边界](ELECTRUM.md)一起阅读。**节点由币种项目官方或第三方运营者独立维护；节点故障属于节点服务问题，APP 自身缺陷仍应反馈和修复。** 非托管不保证设备或节点安全，也不免除应用自身的安全责任。

## English summary

GOwallet's project environment ran **self-hosted MobSF v4.5.2 static analysis** against the exact released 1.0.0 APK on 2026-09-07. This is a third-party open-source tool's automated output, **not an independent audit or certification issued by MobSF**. Score: **59/100**. The scorecard lists 1 high, 7 warnings, 2 informational findings, 2 secure findings and 1 hotspot. Native binary analysis additionally reports 10 high and 11 warning rule matches across 13 unique APK library paths; these are not confirmed exploitable vulnerabilities.

CBC code, native hardening, task-stack behavior, random-number use, storage, logs and clipboard findings remain subject to further review. Some matches involve library helpers or field names, but findings have not been suppressed or declared universally false positive. Version/SDK extraction fields are empty and the original PDF cover icon did not render. Flutter AOT wallet logic and runtime behavior are not comprehensively covered.

Full JSON values are unchanged (indentation only); the 52-page PDF is unmodified. Supplemental Release assets have their own checksums. The original APK and release tag are unchanged. No verifiable VirusTotal multi-engine result is available in this publication. Earlier ClamAV evidence applies to the same APK but is not a substitute for independent security review. See the linked reports, checksums and existing noncustodial/node-service limitations.
