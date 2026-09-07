# 安全问题反馈

GOwallet 为非托管式钱包，节点由相关币种官方或第三方运营者独立部署维护。节点自身离线、同步延迟、错误响应或停止服务属于节点服务侧问题，与 APP 软件本身无关；可先更换兼容节点核实。APP 自身的逻辑或安全缺陷仍请通过下列渠道报告。详见 [节点服务与信任边界](docs/ELECTRUM.md)。

请通过 GitHub 仓库的 Security → Report a vulnerability 私密报告安全漏洞：
https://github.com/AlexZeroZero/GOwallet/security/advisories/new

请提供版本、复现步骤、受影响代码与使用公开测试向量的最小样例。不要发送真实助记词、私钥、PIN、备份口令、备份文件或完整未脱敏日志。不要在公开 Issue 中先披露尚未修复的可利用漏洞。

当前维护基线为 1.0.x。安全审核范围、已修复问题与限制见 [安全审核记录](docs/SECURITY-REVIEW.md)。没有设立漏洞赏金承诺，也不声称全部漏洞已发现。
