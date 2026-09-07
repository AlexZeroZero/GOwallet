# GOwallet 1.0.0 高等级告警深入复核

> 最新修复：Isar 加固已在 [1.0.2 安全修复与验证](VERIFICATION-1.0.2.md) 完成并记录；本文保留原版本的历史结果。

> 版本提示：本文保留 1.0.0 的历史检查结果。后续修复、新 APK 校验值和未解决项见 [1.0.1 安全修复与验证](VERIFICATION-1.0.1.md)。

日期：2026-09-07。本次按“分析问题、保持 APP 逻辑和运行不变”进行只读复核，**没有修改 APP 代码、依赖、数据格式、钱包数据、签名或 APK，也没有连接或调整服务器**。仅补充说明和证据。

复核对象仍为正式 APK，SHA-256：`a960cc5ad89c6586061e704247e586b50e171723050b5d9cb1434bcb6e5fc901`。原 [MobSF 报告](AUTOMATED-SECURITY.md) 的 59/100 分数和告警全部保留；下面是项目侧复核意见，不是独立审计认证或修复结果。

## 结论

| 项目 | 本次确认的事实 | 状态 |
| --- | --- | --- |
| 安全存储 CBC | 正常主路径使用 AES256-SIV/GCM；插件初始化失败时存在旧存储回退，旧算法默认 CBC | **需要优先处理的回退行为，尚未修复；未证实存在可利用的 padding oracle** |
| 安全存储迁移 | 旧值迁移逐项写入目标后删除源值，两端均使用异步 `apply()`；异常仅写日志 | **需验证中断/写入失败场景的数据完整性；尚未复现数据丢失** |
| 生物识别 CBC | AndroidX 兼容辅助 CryptoObject；该命中没有显示助记词加解密调用 | **不能据此认定钱包密钥使用 CBC；不建议直接删除生物识别依赖** |
| SQLite / Isar | 六个库文件均未检出常见 canary/FORTIFY 动态符号，但有 GNU_RELRO、立即绑定和不可执行栈 | **加固项仍需评估；未发现或复现具体内存破坏漏洞** |
| 两个 Flutter libapp 的 RELRO | 没有 GOT/PLT、没有重定位，动态符号仅包含三个 Dart 快照导出 | **工具所述“覆盖 GOT”机制不适用于这两个产物；不是应直接补丁修改的普通 C 库** |
| Flutter libapp 的 canary/FORTIFY | 未检出对应符号，但属于 Dart AOT 快照产物 | **通用 C/C++ 符号规则不足以判断 Dart 内存安全；不据此宣称无漏洞** |

## 1. 安全存储：真正需要关注的是异常回退和迁移

主入口 [secure_store_provider.dart](../lib/providers/global/secure_store_provider.dart) 和 [main.dart](../lib/main.dart) 中的数据库升级入口都设置了 `encryptedSharedPreferences: true`、`resetOnError: false`。存储包装器未传入单次覆盖选项时，插件继续使用实例配置，没有因传入 null 而回到默认选项。

检查锁定的 **flutter_secure_storage 8.1.0** 源码及 APK 反编译结果，正常初始化调用 AndroidX EncryptedSharedPreferences，键名使用 AES256-SIV，值使用 AES256-GCM。读取时返回的字符串是该加密存储接口解密后的值，**不能把这一行返回字符串误解为明文落盘**。

但是，插件 `FlutterSecureStorage.java` 的 `ensureInitialized()` 在 EncryptedSharedPreferences 初始化抛异常后，会切到旧 SharedPreferences 并设置 `failedToUseEncryptedSharedPreferences = true`。后续 `getUseEncryptedSharedPreferences()` 返回 false，读写进入旧 cipher 路径。`StorageCipherFactory` 的旧存储默认算法为 AES_CBC_PKCS7Padding；历史记录的算法可能影响实际选择。APK 中 `w1/C0768a.java` 可交叉确认这一行为。

因此，“主配置已启用 GCM”不足以排除 CBC 的可达路径。**`resetOnError: false` 禁用错误后自动清空，不等于禁用初始化失败后的算法回退。** 回退标志存在于插件实例中，后续访问可能持续走旧路径，直到实例重新建立。

这仍不等于已发现远程盗币漏洞：目前没有证明不受信任的外部应用或网络端可以提交任意密文、获得可区分的解密反馈。旧值位于应用私有存储，文件读写能力、插件入口可达性及错误观察能力都需要单独验证。

另一个可靠性风险在 `checkAndMigrateToEncrypted()`：它逐项解密旧值，调用目标 `apply()`，再调用源 `apply()` 删除旧值；两份存储之间没有代码层面的事务，失败只记日志。**这是需要进一步故障注入验证的实现风险，不能直接宣称已发生丢失。** 正常路径测试通过也不能排除进程中断、磁盘写入失败、密钥暂不可用等场景。

较稳妥的后续处理应当是：初始化失败时明确报告“安全存储暂不可用”，停止敏感写入；保留旧数据及必要的旧格式读取能力；迁移必须验证目标数据成功持久保存并可解密，再考虑清理旧数据。不能简单删掉 CBC 类、强制清空存储、改主密钥别名或直接更换加密方案，否则可能让旧钱包无法访问。具体实现和升级演练尚未进行。

## 2. 生物识别 CBC：与钱包存储告警分开判断

`s/AbstractC0693i.java` 使用 `androidxBiometric` 别名创建辅助 CryptoObject。检查到的调用者是 AndroidX 的生物识别兼容与能力检测逻辑，其中包含旧 Android 版本的处理分支。该辅助方法只构造并初始化 Cipher，本次没有发现它接收或加解密助记词。

因此不能把它与安全存储中的 CBC 视为同一攻击面。可以评估兼容的 AndroidX/认证插件更新，但不建议仅为了消除字符串命中就移除生物识别能力。本次没有进行实机生物识别绕过测试。

## 3. 原生数据库库：加固不足的范围更明确

使用 Android NDK 28.0.13004108 的 LLVM 19 `llvm-readelf`，直接检查正式 APK 中 13 个原生库的 ELF 元数据。SQLite、Isar 的 ARM64、ARMv7、x86_64 文件均存在 GNU_RELRO，动态标记包含立即绑定，GNU_STACK 为 RW 而非可执行；没有检出 `__stack_chk_*` 或 FORTIFY `_chk` 动态符号。

“没有符号”说明未找到相应常规加固证据，不能单独证明每个函数都未受保护或存在缓冲区漏洞。FORTIFY 是否产生符号还受可加固函数、编译器和优化影响；Rust 等实现不能直接套用全部 C 编译假设。

- SQLite 三个 APK 库与缓存依赖 `eu.simonbinder:sqlite3-native-library:3.46.1+1` 中对应文件逐字节一致。仅修改 APP 的 Gradle 参数不会重新加固这些预编译文件。
- Isar 来自锁定依赖 `isar_community_flutter_libs 3.3.0-dev.2`。整文件哈希与缓存文件不同，但本次比较的 `.text`、`.rodata`、`.data`、`.data.rel.ro`、动态符号、动态字符串、动态表和 build-id 等存在的对应节内容均一致。这里只确认已比较的节，**不据此声称整文件一致或已解释全部差异**。
- 若后续加固，应保持数据库格式及 FFI/ABI 兼容，先在副本环境验证读写、升级、迁移及中断恢复，再决定是否替换依赖。不要为消除告警直接替换数据引擎。

## 4. Flutter AOT：两项 RELRO 描述存在明确适用性问题

ARM64 和 x86_64 的 `libapp.so` 均没有 `.got`、`.got.plt` 或 `.plt`；`readelf` 报告没有重定位项。动态符号表除空符号外仅有 `_kDartSnapshotText`、`_kDartSnapshotData`、`_kDartSnapshotBuildId`。加载段分别为只读、可读执行、可读写，没有 RWX 段；栈也没有执行权限。

所以，对这两个文件，原始规则“没有 RELRO 导致可写 GOT 被覆盖”的描述没有对应目标。这是**有二进制证据的规则适用性判断**，不会更改 MobSF 原始输出或宣称整个 Dart 运行时安全。AOT 快照仍有可写数据段，也仍需要正常的运行时及 FFI 安全审查。

缺少 canary/FORTIFY 符号同样不能直接套用普通 C 函数栈的判断。真正的 Flutter 引擎 `libflutter.so` 在两个架构都检出栈保护和 FORTIFY 符号；这只说明对应加固存在，不表示所有引擎代码都安全。

## 5. 顺带核查：助记词随机数

普通 BIP39 新建钱包路径调用 `bip39.generateMnemonic(strength: strength)`，没有传入自定义随机数函数。锁定的 stack-bip39 提交 `20bc8ca0bf0a30c6965977a26c41475a9e862020` 中，默认字节生成使用 Dart `Random.secure()`。

这为该源码调用路径提供了密码学随机源证据，不能把 MobSF 在 Java/Kotlin 库中发现的普通 Random 直接等同于弱助记词。此项不是熵源实机测试，也没有覆盖所有上游币种或被控制操作系统的情况。

## 证据和后续验收条件

证据目录：[security-followup/2026-09-07](../evidence/security-followup/2026-09-07)。包含 [ELF 摘要](../evidence/security-followup/2026-09-07/elf-review.json)、两个 libapp 的原始 readelf 输出、依赖文件/节对照、带行号及文件哈希的[源码片段](../evidence/security-followup/2026-09-07/source-excerpts.json)、范围元数据及 SHA256SUMS。未包含私钥、钱包数据或运维信息。

本次没有运行 APP、不注入存储故障、不修改现有安装，也没有生成新版本。只读证据不能替代修复后的验证。未来涉及安全存储的修复必须通过以下验收，才能宣称不影响已有使用：

1. 同签名覆盖升级后，旧 PIN、收款地址、已有钱包和自定义网络保持可用。
2. 旧加密数据可读，新写入数据正确加密；初始化失败不降级写入、不自动清空、不将故障当成空钱包。
3. 错误口令和篡改数据被拒绝；迁移在中途退出、写入失败后能安全重试或回滚。
4. 备份恢复、无真实资金的签名/交易验证和数据库读写回归通过，最后重新扫描精确的新 APK。

在这些步骤完成前，不把任何分析结论写成“已修复”或“审计通过”。
