# GOwallet 1.0.1 安全修复与验证

> 最新修复：Isar 加固已在 [1.0.2 安全修复与验证](VERIFICATION-1.0.2.md) 完成并记录；本文保留原版本的历史结果。

日期：2026-09-07。版本 **1.0.1+10**，Android 包名 `org.gowallet.pow`。这是项目侧修复、回归测试及第三方工具扫描记录，**不是独立安全机构审计认证，也不表示所有风险已消除**。

[下载 1.0.1](https://github.com/AlexZeroZero/GOwallet/releases/tag/v1.0.1) · [完整证据](../evidence/1.0.1) · [MobSF 原始 PDF](../evidence/1.0.1/mobsf-report.pdf) · [1.0.0 历史复核](SECURITY-FOLLOWUP.md)

## 修复范围

本次保持现有 UI、地址派生、交易签名、币种/网络配置及数据库格式。仅对 Android 安全存储插件和 SQLite 编译方式做针对性修改；没有操作用户钱包或调整 Electrum 服务器。

| 问题 | 1.0.1 的处理 | 兼容性措施 |
| --- | --- | --- |
| 加密存储初始化失败后回退到旧 CBC 路径 | 失败明确返回 `secure_storage_unavailable`；不降级、不自动清空、不将错误当成空钱包 | 保留原文件名、前缀、主密钥别名和 AES256-SIV/GCM 格式，允许后续重试 |
| 旧数据迁移缺少持久化确认与完整性检查 | 先解密和检查全部旧值及冲突，再同步提交加密副本、核对读回结果，最后同步清理旧条目；任一步失败均向调用方报告 | 同一个 XML 中保留旧密文直到受保护副本成功提交；中断可重试，不覆盖冲突值 |
| 旧密钥损坏时可能生成替代密钥 | 缺失或损坏的旧包装密钥/RSA 别名导致迁移失败，不重新生成替代密钥 | CBC/GCM 旧格式仅用于迁移读取；正常路径不初始化旧密钥 |
| SQLite 预编译库缺少常规栈保护/FORTIFY 证据 | 使用原 SQLite 3.46.1 源码、原 SQL 编译功能，保留 NDK 默认保护并启用强栈保护、FORTIFY、RELRO、立即绑定、不可执行栈 | SQLite 源码由 SHA-256 固定，不升级数据库引擎或改变功能选项 |

同步 `commit()` 和读回检查提高迁移可靠性，但不等同于对所有设备断电、闪存故障和操作系统损坏的证明。若升级后安全存储报错，请保留应用数据并反馈脱敏信息，不要尝试通过卸载或清除数据“修复”。

插件补丁和许可证：[安全存储](../vendor/flutter_secure_storage/GOWALLET-PATCHES.md)、[SQLite](../vendor/sqlite3_flutter_libs/GOWALLET-PATCHES.md)。APK 构建所用代码提交为 [`7de5f44`](https://github.com/AlexZeroZero/GOwallet/commit/7de5f44)；最终发布标签另包含报告、证据、构建产物忽略规则及精确公钥哈希扫描允许项。这些后续文件不改变已验证 APK。

## 已完成的验证

| 检查 | 实际结果与范围 |
| --- | --- |
| Dart 回归 | **98 项通过**：包括备份加密/错误口令/篡改、PIN、交易与签名、自定义币种和费用边界；使用测试数据，不涉及真实资金广播 |
| Android 安全存储 | **17 项通过，0 失败/错误**：Android API 35 x86_64 模拟器调用实际 AndroidKeyStore 与 EncryptedSharedPreferences；覆盖初始化失败、CBC 迁移、写入/清理失败、重试、冲突、篡改、密钥缺失/损坏及错误回调；故障注入采用隔离测试存储 |
| 正式 APK 覆盖安装 | 同签名 **1.0.0+9 → 1.0.1+10** 安装成功；旧测试 PIN 可解锁、自定义 BTC 钱包仍在，SCASH 收款地址前后一致；未清除应用数据 |
| 截图保护与运行 | 关闭允许截屏时实际截图全黑；该测试过程应用进程的 Flutter/AndroidRuntime 错误日志为 0 行，不代表覆盖所有运行场景 |
| SQLite 双向兼容演练 | 原库创建合成数据库 → 最终 APK 内新库读取/运行 → 原库再次读取。表结构、整数/blob、WAL、FTS5、RTREE、JSON、完整性检查、事务回滚通过；版本、源码 ID、非编译器功能选项一致 |
| 原生加固 | APK 中三个 SQLite ABI 均检出 canary 和 FORTIFY 符号、RELRO、不可执行栈；Isar 库与 1.0.0 逐字节一致 |
| 签名 | APK v2/v3 验证通过，签名证书与原版本一致 |
| ClamAV | **1.5.4，3,628,051 条病毒签名，感染文件 0**；只代表该版本病毒库对此文件的扫描结果 |
| MobSF | 官方 v4.5.2 镜像自托管静态扫描，**59/100**；Scorecard 仍为 **1 high / 7 warning / 2 info / 2 secure / 1 hotspot** |

## 仍然存在的告警与边界

- MobSF 的 CBC 命中仍包括旧格式迁移读取和 AndroidX 生物识别兼容辅助代码。禁用错误回退不等于删除全部 CBC 字符串，也未声称已证明或消除一个远程 padding oracle。
- 按 `binary_analysis` 中唯一 `lib/` 路径统计，原生规则命中由 **10 high / 11 warning 降为 7 high / 8 warning**；这些是规则数量，不是可利用漏洞数量，也不是 Scorecard 的计数。
- **Isar 的原生加固告警尚未修复**。本次未替换该数据库，避免未经验证的 ABI/数据迁移变更。缺少常见加固符号本身不证明存在可利用内存破坏漏洞。
- Flutter `libapp.so` 的通用 RELRO/canary/FORTIFY 告警仍保留。1.0.0 深入复核确认其无 GOT/PLT/重定位，需要结合 Dart AOT 判断适用性，不能仅为评分修改快照二进制。
- 没有进行真实手机/TEE 验证、完整卸载后恢复演练、真实资金广播或独立渗透测试。回归中的备份加解密测试不等于完整设备恢复测试。
- 尚未取得 VirusTotal 多引擎报告。没有新增完整 SPV；Electrum 节点仍影响查询隐私、可用性、确认数可信度和广播。非托管不等于节点可信或受感染设备安全。

## APK 校验与证据完整性

文件：`gowallet-1.0.1-android-release.apk`，**96,731,051 字节**。

```text
APK SHA-256
e3a4dff2a9b74d1cdd148bd4997104dce02099e6e14d6a5d93ce75213761e50d

签名证书 SHA-256（与 1.0.0 相同）
6e796fcb039900ddf4e0bd6b488fe524f665049b37fc480454fcf0f4c5a43f6e
```

Android API 24 及以上，支持 ARM64/x86_64；APK 附带的 ARMv7 原生库不代表完整支持 ARMv7（没有该架构的 Flutter 引擎/应用库）。

证据目录内 [SHA256SUMS](../evidence/1.0.1/SHA256SUMS) 校验公开文件。MobSF PDF 与工具导出逐字节相同，JSON 仅调整缩进且解析值一致，没有移除告警。原始导出哈希及环境/限制记录在 [release.json](../evidence/1.0.1/release.json)。Android 测试摘要包含原 JUnit 哈希；测试钱包地址只属于无真实资金的演示钱包。

Gitleaks 对签名输出的三个命中已核实为 **apksigner 公钥摘要**，仅对该证据文件和三个精确摘要设置允许项，未整体排除报告或测试目录。公钥摘要和证书指纹不是签名私钥。

升级前确认离线助记词备份，**直接覆盖安装，不要先卸载或清除数据**。更换版本不需要转移链上资产。GOwallet 是非托管式客户端，节点由币种官方或第三方独立运营；节点自身故障属于节点服务问题，APP 自身逻辑或安全缺陷仍应向项目反馈。详见 [Electrum 说明](ELECTRUM.md)。
