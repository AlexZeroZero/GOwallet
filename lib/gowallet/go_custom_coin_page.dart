import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utilities/connection_check/electrum_connection_check.dart';
import '../wallets/crypto_currency/coins/custom_electrum.dart';
import 'custom_coin_definition.dart';
import 'custom_coin_registry.dart';
import 'l10n/go_localizations.dart';

class GoCustomCoinPage extends ConsumerStatefulWidget {
  const GoCustomCoinPage({super.key});
  @override
  ConsumerState<GoCustomCoinPage> createState() => _GoCustomCoinPageState();
}

class _GoCustomCoinPageState extends ConsumerState<GoCustomCoinPage> {
  static const labels = <String, String>{
    'name': '币种名称',
    'ticker': '币种符号',
    'genesis': '创世区块哈希',
    'decimals': '小数位数',
    'slip44': 'SLIP-44 币种编号',
    'p2pkh': 'P2PKH 地址前缀',
    'p2sh': 'P2SH 地址前缀',
    'wif': 'WIF 私钥前缀',
    'bip32Public': 'BIP32 公钥前缀',
    'bip32Private': 'BIP32 私钥前缀',
    'hrp': 'Bech32 HRP',
    'txVersion': '交易版本',
    'blockTime': '目标出块秒数',
    'confirmations': '普通交易确认数',
    'coinbaseMaturity': '挖矿奖励成熟确认数',
    'dust': '最小输出（最小单位）',
    'feePerKb': '默认费率（最小单位/kB）',
    'explorer': '浏览器交易 URL 前缀（可选）',
    'host': '服务器域名或 IP',
    'port': '端口',
  };
  static const numeric = {
    'decimals',
    'slip44',
    'p2pkh',
    'p2sh',
    'wif',
    'bip32Public',
    'bip32Private',
    'txVersion',
    'blockTime',
    'confirmations',
    'coinbaseMaturity',
    'dust',
    'feePerKb',
    'port',
  };
  final _form = GlobalKey<FormState>();
  final _importController = TextEditingController();
  final fields = {for (final k in labels.keys) k: TextEditingController()};
  bool _segwit = false, _tls = true, _confirmed = false, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    // Common defaults are visible and must be confirmed against the project.
    for (final e in {
      'decimals': '8',
      'bip32Public': '0x0488b21e',
      'bip32Private': '0x0488ade4',
      'txVersion': '1',
      'blockTime': '60',
      'confirmations': '1',
      'coinbaseMaturity': '100',
      'dust': '546',
      'feePerKb': '1000',
      'port': '50002',
    }.entries) {
      fields[e.key]!.text = e.value;
    }
  }

  @override
  void dispose() {
    _importController.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _profile() => {
    'schema': 1,
    'segwit': _segwit,
    'tls': _tls,
    for (final e in fields.entries)
      e.key: numeric.contains(e.key)
          ? int.parse(e.value.text.trim())
          : e.value.text.trim(),
  };

  Future<void> _import() async {
    final controller = _importController..clear();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(goTr(ctx, '导入币种参数')),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: controller,
            maxLines: 8,
            maxLength: 65536,
            decoration: InputDecoration(
              hintText: goTr(ctx, '粘贴 GOwallet 币种配置 JSON，不含助记词或私钥'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(goTr(ctx, '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(goTr(ctx, '导入')),
          ),
        ],
      ),
    );
    // The route may still be animating; the dialog owns no persistent secrets.
    if (raw == null || !mounted) return;
    try {
      if (utf8.encode(raw).length > 65536) throw const FormatException();
      final p = CustomCoinDefinition.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      ).toJson();
      setState(() {
        for (final k in fields.keys) {
          fields[k]!.text = '${p[k]}';
        }
        _segwit = p['segwit'] as bool;
        _tls = p['tls'] as bool;
        _confirmed = false;
        _error = null;
      });
    } catch (_) {
      setState(() => _error = goTr(context, '币种参数无效，请核对格式、范围和是否与内置币种重复'));
    }
  }

  Future<void> _save() async {
    if (!_confirmed || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final definition = CustomCoinDefinition.fromJson(_profile());
      CustomCoinRegistry.mergeProfiles(
        CustomCoinRegistry.instance.coins.map((c) => c.definition).toList(),
        [definition],
      );
      if (CustomCoinRegistry.instance.coins.any(
        (c) => c.identifier == definition.identifier,
      )) {
        throw const FormatException('Duplicate');
      }
      final ok = await checkElectrumServer(
        host: definition.string('host'),
        port: definition.integer('port'),
        useSSL: definition.flag('tls'),
        expectedGenesis: definition.string('genesis'),
      );
      if (!ok) throw StateError('network');
      await CustomCoinRegistry.instance.importProfiles([definition.toJson()]);
      await ref.read(nodeServiceChangeNotifierProvider).updateDefaults();
      if (mounted) Navigator.pop(context, CustomElectrumCurrency(definition));
    } catch (e) {
      if (mounted)
        setState(
          () => _error = goTr(
            context,
            e is StateError
                ? '无法验证服务器，请检查域名、端口、TLS 和币种是否一致'
                : '币种参数无效，请核对格式、范围和是否与内置币种重复',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(goTr(context, '自定义币种')),
      actions: [
        IconButton(
          tooltip: goTr(context, '导入币种参数'),
          onPressed: _busy ? null : _import,
          icon: const Icon(Icons.file_download_outlined),
        ),
      ],
    ),
    body: AbsorbPointer(
      absorbing: _busy,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              goTr(
                context,
                '支持标准 Bitcoin 交易格式、BIP39/BIP44，可选 SegWit。仅有 Electrum 接口并不代表兼容；不支持特殊交易格式、代币或隐私币协议。',
              ),
            ),
            const SizedBox(height: 16),
            _section('基础信息', ['name', 'ticker', 'genesis', 'decimals']),
            _section('地址与派生参数', [
              'slip44',
              'p2pkh',
              'p2sh',
              'wif',
              'bip32Public',
              'bip32Private',
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(goTr(context, '该链支持 SegWit')),
              value: _segwit,
              onChanged: (v) => setState(() => _segwit = v),
            ),
            if (_segwit) _field('hrp'),
            _section('交易与费用参数', [
              'txVersion',
              'blockTime',
              'confirmations',
              'coinbaseMaturity',
              'dust',
              'feePerKb',
              'explorer',
            ]),
            _section('初始网络', ['host', 'port']),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(goTr(context, '启用 TLS 加密')),
              subtitle: Text(
                goTr(context, _tls ? '严格验证证书和域名' : '明文 TCP 会暴露地址查询，建议使用 TLS'),
              ),
              value: _tls,
              onChanged: (v) => setState(() => _tls = v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(goTr(context, '已从项目官方核对以上参数，并确认该链使用兼容的交易格式')),
              subtitle: Text(goTr(context, '添加后链参数不可修改；请同时备份助记词与币种参数。')),
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v!),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _busy || !_confirmed ? null : _save,
              child: Text(goTr(context, _busy ? '正在验证网络…' : '验证并添加币种')),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  Widget _section(String name, List<String> keys) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          goTr(context, name),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      ...keys.map(_field),
    ],
  );
  Widget _field(String key) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('custom_$key'),
      controller: fields[key],
      maxLength: key == 'genesis'
          ? 64
          : key == 'explorer' || key == 'host'
          ? 253
          : 40,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: goTr(context, labels[key]!),
        counterText: '',
        helperText: numeric.contains(key)
            ? goTr(context, '十进制或 0x 开头的十六进制')
            : null,
      ),
      validator: (raw) {
        if ((raw ?? '').trim().isEmpty &&
            !const {'hrp', 'explorer'}.contains(key))
          return goTr(context, '请填写此项');
        if (numeric.contains(key) && int.tryParse(raw!.trim()) == null)
          return goTr(context, '请输入有效整数');
        return null;
      },
    ),
  );
}

Future<void> showCustomCoinProfile(
  BuildContext context,
  CustomElectrumCurrency coin,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text('${coin.ticker} · ${goTr(ctx, '币种参数')}'),
    content: SingleChildScrollView(
      child: SelectableText(
        const JsonEncoder.withIndent('  ').convert(coin.definition.toJson()),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          Clipboard.setData(
            ClipboardData(text: jsonEncode(coin.definition.toJson())),
          );
          Navigator.pop(ctx);
        },
        child: Text(goTr(ctx, '复制参数')),
      ),
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text(goTr(ctx, '关闭')),
      ),
    ],
  ),
);
