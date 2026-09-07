import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_config.dart';
import '../providers/global/prefs_provider.dart';
import '../pages/settings_views/global_settings_view/manage_nodes_views/coin_nodes_view.dart';
import '../pages/settings_views/global_settings_view/security_views/security_view.dart';
import '../pages/settings_views/global_settings_view/appearance_settings/appearance_settings_view.dart';
import 'go_ui.dart';
import 'go_add_network.dart';
import 'go_custom_coin_page.dart';
import 'custom_coin_registry.dart';
import '../wallets/crypto_currency/coins/custom_electrum.dart';
import 'dart:io';
import '../pages/settings_views/global_settings_view/language_view.dart';

class GoNetworks extends ConsumerWidget {
  const GoNetworks({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pCustomCoins);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GoSection(
          title: goTr(context, "网络与节点"),
          subtitle: goTr(context, "选择你信任的数据来源"),
        ),
        GoNotice(
          title: goTr(context, "连接状态 ≠ 全网同步"),
          detail: goTr(
            context,
            "钱包读取 ElectrumX 索引。节点连通或钱包同步完成，不代表服务端已追上全网，也不代表交易已被完整共识验证。",
          ),
          icon: Icons.hub_outlined,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<bool>(builder: (_) => const GoAddNetwork())),
          icon: const Icon(Icons.add_link),
          label: Text(goTr(context, '新增网络')),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<CustomElectrumCurrency>(
              builder: (_) => const GoCustomCoinPage(),
            ),
          ),
          icon: const Icon(Icons.add_circle_outline),
          label: Text(goTr(context, '自定义币种')),
        ),
        const SizedBox(height: 12),
        for (final coin in AppConfig.coins)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: const Icon(Icons.dns_outlined),
              title: Text(
                '${coin.ticker} · ${coin.prettyName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                goTr(context, "查看、测试和切换节点"),
                style: TextStyle(fontSize: 12),
              ),
              trailing: coin is CustomElectrumCurrency
                  ? IconButton(
                      icon: const Icon(Icons.data_object),
                      tooltip: goTr(context, '币种参数'),
                      onPressed: () => showCustomCoinProfile(context, coin),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(
                context,
              ).pushNamed(CoinNodesView.routeName, arguments: coin),
            ),
          ),
        const SizedBox(height: 18),
        GoNotice(
          title: goTr(context, "TCP 为明文连接"),
          detail: goTr(
            context,
            "TCP 可被监听或篡改，节点能看到地址查询。服务器支持时请启用 TLS。客户端会核对创世块，发现错链则拒绝查询。",
          ),
          icon: Icons.lock_open_rounded,
        ),
      ],
    );
  }
}

class GoSecurity extends ConsumerWidget {
  const GoSecurity({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsChangeNotifierProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GoSection(
          title: goTr(context, "安全中心"),
          subtitle: goTr(context, "让保护措施可见、可检查"),
        ),
        GoNotice(
          title: goTr(context, "你的密钥，你的责任"),
          detail: goTr(
            context,
            "GOwallet 不托管密钥。保护设备和离线备份同样重要；安全设置不能消除恶意系统、假节点或助记词泄露带来的风险。",
          ),
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(goTr(context, "语言 / Language")),
            subtitle: Text(prefs.language),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                Navigator.of(context).pushNamed(LanguageSettingsView.routeName),
          ),
        ),
        if (Platform.isAndroid)
          Card(
            elevation: 0,
            child: SwitchListTile.adaptive(
              secondary: const Icon(Icons.screenshot_rounded),
              title: Text(goTr(context, "允许截屏")),
              subtitle: Text(goTr(context, "默认关闭。开启后请避免截取助记词、私钥或余额等敏感信息。")),
              value: !prefs.disableScreenShots,
              onChanged: (allowed) => prefs.disableScreenShots = !allowed,
            ),
          ),
        _Status(
          title: goTr(context, "应用锁"),
          detail: prefs.hasPin
              ? goTr(context, "已设置 PIN · 错误尝试持续限速")
              : goTr(context, "尚未设置 PIN"),
          active: prefs.hasPin,
        ),
        _Status(
          title: goTr(context, "离开应用"),
          detail: goTr(context, "返回时重新验证身份"),
          active: true,
        ),
        _Status(
          title: goTr(context, "闲置锁定"),
          detail: prefs.autoLockInfo.enabled
              ? goTr(context, "{0} 分钟无操作后锁定", [prefs.autoLockInfo.minutes])
              : goTr(context, "当前已关闭，请在安全设置中开启"),
          active: prefs.autoLockInfo.enabled,
        ),
        _Status(
          title: goTr(context, "外部行情请求"),
          detail: prefs.externalCalls
              ? goTr(context, "已开启，会向外部行情服务发送请求")
              : goTr(context, "已关闭，仅使用所选节点进行钱包查询"),
          active: !prefs.externalCalls,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text(goTr(context, "PIN、生物识别与自动锁定")),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                Navigator.of(context).pushNamed(SecurityView.routeName),
          ),
        ),
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.contrast_rounded),
            title: Text(goTr(context, "外观与显示")),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(
              context,
            ).pushNamed(AppearanceSettingsView.routeName),
          ),
        ),
        const SizedBox(height: 18),
        GoNotice(
          title: goTr(context, "转账前的三次核对"),
          detail: goTr(
            context,
            "确认币种和网络；核对完整收款地址；确认金额、手续费和总支出。先做小额测试，广播后的交易通常无法撤回。",
          ),
          icon: Icons.fact_check_outlined,
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.title,
    required this.detail,
    required this.active,
  });
  final String title, detail;
  final bool active;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Icon(
          active
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          color: active ? GoPalette.teal : const Color(0xFFAA6215),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(detail, style: const TextStyle(fontSize: 12, height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );
}
