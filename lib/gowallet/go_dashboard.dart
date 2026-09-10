import 'dart:io';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app_config.dart';
import '../models/add_wallet_list_entity/sub_classes/coin_entity.dart';
import '../pages/add_wallet_views/add_wallet_view/add_wallet_view.dart';
import '../pages/add_wallet_views/create_or_restore_wallet_view/create_or_restore_wallet_view.dart';
import '../pages/wallets_view/sub_widgets/wallet_list_item.dart';
import '../providers/providers.dart';
import '../themes/coin_icon_provider.dart';
import '../themes/stack_colors.dart';
import '../utilities/amount/amount.dart';
import '../wallets/crypto_currency/crypto_currency.dart';
import '../wallets/isar/providers/all_wallets_info_provider.dart';
import 'go_portfolio.dart';
import 'go_ui.dart';
import 'custom_coin_registry.dart';
import 'l10n/go_localizations.dart';

final pGoHideAssets = StateProvider<bool>((ref) => false);

String goFiat(Decimal value, String locale) =>
    value > Decimal.zero && value < Decimal.parse('0.00000001')
    ? '<0.00000001'
    : value.toAmount(fractionDigits: 8).fiatString(locale: locale);

class GoDashboard extends ConsumerWidget {
  const GoDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(pGoPortfolio);
    return RefreshIndicator(
      color: GoPalette.teal,
      onRefresh: () async {
        ref.read(pGoQuoteEpoch.state).state++;
        final ids = ref.read(pAllWalletsInfo).map((w) => w.walletId).toSet();
        final wallets = ref
            .read(pWallets)
            .wallets
            .where((w) => ids.contains(w.walletId));
        try {
          await Future.wait(
            wallets.map((w) async {
              await w.init();
              await w.refresh();
            }),
          ).timeout(const Duration(seconds: 30));
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(goTr(context, '部分钱包仍在同步，请稍后查看'))),
            );
          }
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          GoAssetSummary(portfolio: portfolio),
          const SizedBox(height: 10),
          GoSection(
            title: goTr(context, '我的资产'),
            compact: true,
            subtitle: goTr(context, '按币种汇总 · 下拉更新余额'),
            trailing: IconButton.filledTonal(
              tooltip: goTr(context, '添加钱包'),
              onPressed: () =>
                  Navigator.of(context).pushNamed(AddWalletView.routeName),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          if (portfolio.holdings.isEmpty) ...[
            GoNotice(
              title: goTr(context, '从一个钱包开始'),
              detail: goTr(context, '新建助记词，或恢复你已有的钱包。GOwallet 不会代你保存助记词。'),
              icon: Icons.add_card_rounded,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AddWalletView.routeName),
              style: FilledButton.styleFrom(
                backgroundColor: GoPalette.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(goTr(context, '创建 / 恢复钱包')),
            ),
          ],
          for (final holding in portfolio.holdings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GoHoldingTile(
                holding: holding,
                onTap: () => openWalletGroup(
                  context,
                  ref,
                  holding.coin,
                  holding.walletCount,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            goTr(context, '余额为最近同步结果；折合资产仅供参考。'),
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color:
                  (Theme.of(context).extension<StackColors>()?.textSubtitle1 ??
                  Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 20),
          GoNotice(
            title: goTr(context, '先备份，再收款'),
            detail: goTr(context, '助记词是找回资产的凭证。离线抄写并核对，不发给任何人，也不要保存在截图或聊天里。'),
            icon: Icons.key_rounded,
          ),
        ],
      ),
    );
  }
}

class GoAssetSummary extends ConsumerWidget {
  const GoAssetSummary({super.key, required this.portfolio});
  final GoPortfolio portfolio;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(pGoHideAssets);
    final currency = ref.watch(
      prefsChangeNotifierProvider.select((p) => p.currency),
    );
    final enabled = ref.watch(
      prefsChangeNotifierProvider.select((p) => p.externalCalls),
    );
    final quotes = ref.watch(pGoQuotes);
    final locale = Localizations.localeOf(context).languageCode == 'zh'
        ? 'zh_CN'
        : 'en_US';
    final amount = portfolio.estimate;
    final status = !enabled
        ? '行情未开启'
        : quotes is AsyncLoading
        ? '正在获取行情'
        : quotes is AsyncError ||
              quotes.maybeWhen(data: (v) => v.isEmpty, orElse: () => false)
        ? '行情暂不可用'
        : 'CoinGecko 参考行情';
    return Container(
      key: const Key('goAssetSummary'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF193C33), GoPalette.ink],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GoPalette.mint.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goTr(context, '资产总览'),
                  style: const TextStyle(
                    color: GoPalette.mint,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: goTr(context, hidden ? '显示余额' : '隐藏余额'),
                onPressed: () => ref.read(pGoHideAssets.state).state = !hidden,
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFFB9CDC7),
                  size: 18,
                ),
              ),
            ],
          ),
          Text(
            '${goTr(context, portfolio.complete ? '钱包折合总资产' : '已知部分估值')} · $currency',
            style: const TextStyle(color: Color(0xFFB9CDC7), fontSize: 11),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                hidden
                    ? '••••••'
                    : amount == null
                    ? '—'
                    : '≈ ${goFiat(amount, locale)}',
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!portfolio.complete)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                goTr(context, '{0} 个币种尚未计入：等待余额或有效行情', [
                  portfolio.missingCount,
                ]),
                style: const TextStyle(
                  color: GoPalette.amber,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Divider(height: 1, color: GoPalette.mint.withValues(alpha: .16)),
          Row(
            children: [
              Expanded(
                child: Text(
                  goTr(context, '{0} 个已添加币种', [portfolio.holdings.length]),
                  style: const TextStyle(
                    color: Color(0xFFB9CDC7),
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: GoPalette.mint,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => showGoValuationSettings(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          goTr(context, status),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.tune_rounded, size: 15),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GoCoinIcon extends ConsumerWidget {
  const GoCoinIcon(this.coin, {super.key, this.size = 40});
  final CryptoCurrency coin;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      coin is CustomElectrumCurrency
      ? CircleAvatar(
          radius: size / 2,
          backgroundColor: GoPalette.teal,
          child: Text(
            coin.ticker.substring(0, coin.ticker.length.clamp(1, 2)),
            style: TextStyle(
              fontSize: size * .3,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
      : SvgPicture.file(
          File(ref.watch(coinIconProvider(coin))),
          width: size,
          height: size,
        );
}

class GoHoldingTile extends ConsumerWidget {
  const GoHoldingTile({
    super.key,
    required this.holding,
    required this.onTap,
    this.compact = false,
  });
  final GoHolding holding;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(pGoHideAssets);
    final currency = ref.watch(
      prefsChangeNotifierProvider.select((p) => p.currency),
    );
    final locale = Localizations.localeOf(context).languageCode == 'zh'
        ? 'zh_CN'
        : 'en_US';
    final colors = Theme.of(context).extension<StackColors>();
    final muted =
        colors?.textSubtitle1 ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      key: Key('goHolding-${holding.coin.identifier}'),
      color: colors?.popupBG ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 12,
          ),
          child: Row(
            children: [
              GoCoinIcon(holding.coin, size: compact ? 24 : 30),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.coin.ticker,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      holding.walletCount == 1
                          ? goTr(context, '1 个钱包')
                          : goTr(context, '{0} 个钱包', [holding.walletCount]),
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          hidden
                              ? '••••••'
                              : holding.balance?.toString() ??
                                    goTr(context, '等待同步'),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: compact ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hidden
                          ? '••••'
                          : holding.estimate == null
                          ? goTr(context, '折合价值暂不可用')
                          : '≈ ${goFiat(holding.estimate!, locale)} $currency',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 15, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showGoValuationSettings(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final prefs = ref.watch(prefsChangeNotifierProvider);
      final currencies = {'USD', 'CNY', 'EUR', prefs.currency}.toList();
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goTr(context, '资产估值设置'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: prefs.currency,
                decoration: InputDecoration(labelText: goTr(context, '计价货币')),
                items: currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) prefs.currency = value;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(goTr(context, '启用外部行情')),
                value: prefs.externalCalls,
                activeTrackColor: GoPalette.teal,
                onChanged: (value) => prefs.externalCalls = value,
              ),
              Text(
                goTr(
                  context,
                  '通过 CoinGecko 查询公开币价；不发送钱包地址或余额。服务商可看到设备 IP。价格超过 15 分钟或不可用时，不计入估值。',
                ),
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(goTr(context, '完成')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);

class GoCoinDrawer extends ConsumerWidget {
  const GoCoinDrawer({super.key, required this.onOpen, required this.onAdd});
  final void Function(GoHolding) onOpen;
  final void Function(CryptoCurrency) onAdd;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pCustomCoins);
    final holdings = ref.watch(pGoPortfolio).holdings;
    return Drawer(
      width: MediaQuery.sizeOf(context).width * .88,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          children: [
            Row(
              children: [
                const GoMark(size: 26),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'GOwallet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: goTr(context, '关闭'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _GoDrawerSection(title: goTr(context, '已添加币种')),
            if (holdings.isEmpty) Text(goTr(context, '尚未添加钱包')),
            for (final holding in holdings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GoHoldingTile(
                  compact: true,
                  holding: holding,
                  onTap: () => onOpen(holding),
                ),
              ),
            const SizedBox(height: 6),
            _GoDrawerSection(title: goTr(context, '支持的币种')),
            for (final coin in AppConfig.coins)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                dense: true,
                minTileHeight: 48,
                minVerticalPadding: 4,
                horizontalTitleGap: 10,
                minLeadingWidth: 24,
                visualDensity: VisualDensity.standard,
                leading: GoCoinIcon(coin, size: 24),
                title: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      coin.ticker,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      coin.prettyName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 19,
                ),
                onTap: () => onAdd(coin),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoDrawerSection extends StatelessWidget {
  const _GoDrawerSection({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 6),
    child: Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

void goAddCoin(BuildContext context, CryptoCurrency coin) => Navigator.of(
  context,
).pushNamed(CreateOrRestoreWalletView.routeName, arguments: CoinEntity(coin));
