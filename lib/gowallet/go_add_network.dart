import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../app_config.dart';
import '../models/node_model.dart';
import '../providers/providers.dart';
import '../utilities/connection_check/electrum_connection_check.dart';
import '../wallets/crypto_currency/crypto_currency.dart';
import 'custom_coin_definition.dart';
import 'l10n/go_localizations.dart';

class GoAddNetwork extends ConsumerStatefulWidget {
  const GoAddNetwork({super.key, this.coin});
  final CryptoCurrency? coin;
  @override
  ConsumerState<GoAddNetwork> createState() => _GoAddNetworkState();
}

class _GoAddNetworkState extends ConsumerState<GoAddNetwork> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _host = TextEditingController();
  final _port = TextEditingController(text: '50002');
  late CryptoCurrency _coin = widget.coin ?? AppConfig.coins.first;
  bool _tls = true, _primary = true, _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(nodeServiceChangeNotifierProvider);
    final host = validateElectrumHost(_host.text), port = int.parse(_port.text);
    try {
      if (service
          .getNodesFor(_coin)
          .any((n) => n.host == host && n.port == port && n.useSSL == _tls)) {
        throw StateError('duplicate');
      }
      final valid = await checkElectrumServer(
        host: host,
        port: port,
        useSSL: _tls,
        expectedGenesis: _coin.genesisHash,
      );
      if (!valid) throw StateError('unverified');
      final node = NodeModel(
        host: host,
        port: port,
        name: _name.text.trim(),
        id: const Uuid().v4(),
        useSSL: _tls,
        enabled: true,
        coinName: _coin.identifier,
        isFailover: true,
        isDown: false,
        torEnabled: false,
        clearnetEnabled: true,
        isPrimary: false,
      );
      await service.save(node, null, true);
      if (_primary) await service.setPrimaryNodeFor(coin: _coin, node: node);
      for (final wallet
          in ref
              .read(pWallets)
              .wallets
              .where((w) => w.info.coin.identifier == _coin.identifier)) {
        // Persisted choice is valid even if a later balance refresh is offline.
        try {
          await wallet.updateNode().timeout(const Duration(seconds: 15));
        } catch (_) {}
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = goTr(
            context,
            e is StateError && e.message == 'duplicate'
                ? '该服务器已存在'
                : '无法验证服务器，请检查域名、端口、TLS 和币种是否一致',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(goTr(context, '新增网络'))),
    body: AbsorbPointer(
      absorbing: _busy,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(goTr(context, '为币种添加第三方 Electrum 服务器，可设为首选或备用。')),
            const SizedBox(height: 18),
            DropdownButtonFormField<CryptoCurrency>(
              initialValue: _coin,
              isExpanded: true,
              decoration: InputDecoration(labelText: goTr(context, '币种')),
              items: AppConfig.coins
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.ticker} · ${c.prettyName}'),
                    ),
                  )
                  .toList(),
              onChanged: widget.coin != null
                  ? null
                  : (c) => setState(() => _coin = c!),
            ),
            const SizedBox(height: 12),
            _field(
              _name,
              '网络名称',
              (v) =>
                  v == null || v.trim().isEmpty ? goTr(context, '请填写此项') : null,
              max: 40,
            ),
            _field(_host, '服务器域名或 IP', (v) {
              try {
                validateElectrumHost(v ?? '');
                return null;
              } catch (_) {
                return goTr(context, '请输入域名或 IPv4，不包含协议和路径');
              }
            }, max: 253),
            _field(
              _port,
              '端口',
              (v) {
                final p = int.tryParse(v ?? '');
                return p == null || p < 1 || p > 65535
                    ? goTr(context, '端口范围为 1–65535')
                    : null;
              },
              numeric: true,
              max: 5,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(goTr(context, '启用 TLS 加密')),
              subtitle: Text(
                goTr(context, _tls ? '严格验证证书和域名' : '明文 TCP 会暴露地址查询，建议使用 TLS'),
              ),
              value: _tls,
              onChanged: (v) => setState(() => _tls = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(goTr(context, '设为首选网络')),
              subtitle: Text(goTr(context, '关闭后作为备用服务器，可在节点列表切换')),
              value: _primary,
              onChanged: (v) => setState(() => _primary = v),
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
              onPressed: _busy ? null : _save,
              child: Text(goTr(context, _busy ? '正在验证网络…' : '验证并保存')),
            ),
            const SizedBox(height: 16),
            Text(
              goTr(context, '服务器只能提供链上数据，无法取得你的私钥。核对创世块只能检查链身份，不能代替完整共识验证。'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _field(
    TextEditingController c,
    String label,
    String? Function(String?) validator, {
    bool numeric = false,
    int max = 80,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      maxLength: max,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: goTr(context, label),
        counterText: '',
      ),
      validator: validator,
    ),
  );
}
