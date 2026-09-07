# GOwallet 1.0.2：Isar 加固与验证

日期：2026-09-07。版本 **1.0.2+11**，包名 `org.gowallet.pow`。本次完成 Isar 原生库加固及兼容性验证，保留现有 UI、钱包派生、交易签名、币种/网络配置、密钥和数据库格式。**这是项目侧测试与自托管第三方工具扫描，不是独立机构审计认证，也不是零漏洞保证。**

[下载 1.0.2](https://github.com/AlexZeroZero/GOwallet/releases/tag/v1.0.2) · [52 页 MobSF 原始 PDF](../evidence/1.0.2/mobsf-report.pdf) · [完整证据](../evidence/1.0.2) · [1.0.1 历史记录](VERIFICATION-1.0.1.md)

## 修复了什么

原 APK 的 Isar 库来自 Pub 包中的预编译文件，修改 APP 的普通编译参数不会加固这些文件。现在从固定版本的源码构建 Android 原生库，给内嵌 C 数据库引擎增加强栈保护和 FORTIFY，并明确启用 RELRO、立即绑定、不可执行栈和 16 KiB 链接页对齐。

- **Isar 仍为 3.3.0-dev.2，libmdbx 仍为 v0.13.8**；没有升级数据库格式、修改业务 schema 或改动 Dart FFI 接口。
- 固定 Isar 源码提交 `39ea19ff035518aef4d0e776206d96a428f57789` 与 libmdbx 提交 `4d58857f8fd0aba400706610ba05ba4dd869f04e`，保留许可证。构建不再动态解析 libmdbx 标签。
- 上游未发布此标签的 Cargo.lock，无法据此重建其历史上解析的每个 Rust 依赖版本。本次对声明的依赖重新解析并锁定；Rust 1.88.0 与上游 Android 构建脚本一致。相关兼容性经过实际测试，而不是仅凭版本号假定。
- 保留 hosted Isar Dart/plugin 包；Gradle 仅替换其 Android JNI 库目录。缺少加固库时构建明确失败，避免静默打包旧库。

源码、补丁、许可证和构建要求见 [GOWALLET-PATCHES.md](../vendor/isar_native/GOWALLET-PATCHES.md) 与 [BUILD.md](BUILD.md)。APK 来自代码提交 [`173d71c`](https://github.com/AlexZeroZero/GOwallet/commit/173d71c)；最终发布标签另包含扩展压力测试、报告和证据，这些后续文件不改变已验证 APK。

## 验证结果

| 检查 | 实际结果 |
| --- | --- |
| 最终 APK 内的 Isar | ARM64、ARMv7、x86_64 三个库均检出 stack canary、FORTIFY、RELRO、立即绑定、不可执行栈；不是仅检查构建参数 |
| 导出接口 | 三个架构各 93 个全局导出符号名与原库一致；这项符号检查不能单独证明所有 ABI/运行行为正确 |
| 数据库双向兼容 | Android API 35 x86_64 模拟器：原库创建合成数据库 → 最终 APK 内新库读取/写入 → 原库读回，数据、Unicode、长整数、字节/字符串列表、唯一索引、关联关系和完整性检查通过 |
| 事务与中断 | 显式回滚通过；进程退出前未提交的写入没有出现在后续新旧库读取中 |
| 批量与大字段 | 最终 APK 的库完成 **1,040 条批量写入/删除，包含 16 个 10,000 字符的大字段**，记录数量及索引/数据库完整性检查通过 |
| 钱包回归 | **98 项 Dart 回归测试全部通过**，包括备份加密、错误口令/篡改、PIN、签名、币种与费用边界；测试数据不涉及真实资金广播 |
| 正式覆盖升级 | 同签名 **1.0.1+10 → 1.0.2+11** 安装成功；旧测试 PIN 可解锁、SCASH 与自定义 BTC 钱包保留、SCASH 收款地址一致 |
| 截图与运行 | 关闭允许截屏时实际截图全黑；该升级验证过程应用进程的 Flutter/AndroidRuntime 错误日志为 0 行 |
| ClamAV | 1.5.4，3,628,051 条病毒签名，**感染文件 0**；只代表该病毒库对这个 APK 的结果 |
| MobSF | 官方 v4.5.2 固定镜像扫描这个 APK，**59/100**，Scorecard 为 **1 high / 7 warning / 2 info / 2 secure / 1 hotspot** |

数据库测试源码见 [isar_compatibility_probe.c](../tool/isar_compatibility_probe.c)。各阶段在独立进程运行，目录限定为隔离的合成数据库；没有读取或改动用户手机钱包数据。

## 为什么综合评分仍为 59

**Isar 原先三项高等级栈保护告警、三项 FORTIFY 警告已经消除**，三个库对应的原生规则在新报告中均为 info。按 `binary_analysis` 中唯一 `lib/` 路径统计，原生规则命中由 **7 high / 8 warning → 4 high / 5 warning**；相对于 1.0.0 的 **10 high / 11 warning** 也有下降。这是规则计数，不是可利用漏洞数量。

MobSF 的 Scorecard 与原生规则计数不是同一套统计。综合分数未随本次 Isar 加固变化，原始结果全部保留，没有通过删规则、伪造符号或改报告来提分。

仍需区分以下边界：

- **Flutter `libapp.so` 通用告警**：两个架构仍有 RELRO/canary/FORTIFY 命中；实际 ELF 没有 GOT/PLT、没有重定位，属于 Dart AOT 快照，不能直接套用普通 C 库的“覆盖 GOT”攻击描述。并未因此宣称整个 Flutter/FFI 无风险。
- **secp256k1 的 FORTIFY 符号警告**：三个库没有检出 `_chk` 动态符号，但实际 C 编译参数已经包含 `_FORTIFY_SOURCE=2` 和强栈保护。见 [编译参数证据](../evidence/1.0.2/secp-compile-flags.json)。没有符号本身不足以证明保护参数未开启，不能为了消除字符串规则而修改交易签名库。
- **CBC 等代码规则**：旧格式迁移读取、AndroidX 生物识别兼容辅助代码等仍会命中。1.0.1 已修复存储初始化失败后的降级与迁移可靠性问题；保留旧格式读取能力用于兼容，未声称已证实或消除某个远程 padding oracle。
- **Rust 依赖维护公告**：OSV 对 Cargo.lock 中 91 个 crates.io 包匹配到 `paste 1.0.15` 的 **RUSTSEC-2024-0436（停止维护）**。它是编译期过程宏；该公告不证明存在可利用的运行时漏洞。保留 [扫描记录](../evidence/1.0.2/cargo-osv.json) 和 [原公告](../evidence/1.0.2/paste-advisory.json)，后续仍需维护。

本次没有实机/TEE 验证、完整卸载后设备恢复演练、真实资金广播或独立人工渗透测试。原生兼容性动态验证运行于 x86_64；ARM 架构完成编译和静态检查。新增 C 引擎保护不等于每个 Rust 函数都有栈保护，也不能证明所有存储故障均可恢复。没有新增完整 SPV；VirusTotal 多引擎结果尚未取得。

## APK 校验、报告与升级

文件 `gowallet-1.0.2-android-release.apk`：**96,780,231 字节**。

```text
APK SHA-256
c944ad5725d5836e5428459043a82f217267b68db7b4dce20ec8a9afa2b37b4a

签名证书 SHA-256（与旧版相同，v2/v3 验证通过）
6e796fcb039900ddf4e0bd6b488fe524f665049b37fc480454fcf0f4c5a43f6e
```

Android API 24+，target SDK 36，支持 ARM64/x86_64；附带 ARMv7 原生库不代表完整 Flutter ARMv7 支持。MobSF PDF 的版本/SDK 自动提取字段为空，这是工具限制；这里的版本与 SDK 已使用 Android 构建工具独立核对，并完成实际安装。

证据目录内 [SHA256SUMS](../evidence/1.0.2/SHA256SUMS) 校验公开文件；[release.json](../evidence/1.0.2/release.json) 记录原始导出哈希和测试范围。PDF 与工具导出逐字节相同，JSON 仅调整缩进、解析值不变。公钥摘要是公开签名信息，密钥扫描仅对已核实的精确值设置允许项；未整体排除报告目录。1.0.1 Release 和仓库内的历史证据保留。发布前核查时 GitHub 的 v1.0.0 Release 已不可用；本次修复没有执行删除旧 Release、标签或附件的操作。

**确认离线助记词备份后直接覆盖安装，不要先卸载或清除数据。** GOwallet 是非托管式钱包；节点由币种官方或第三方独立运营。节点自身故障属于节点服务侧问题，APP 自身逻辑或安全缺陷仍应向本项目反馈。TLS 不保证节点诚实，更换兼容节点或升级 APP 无需转移链上资产。详见 [Electrum 与责任边界](ELECTRUM.md)。
