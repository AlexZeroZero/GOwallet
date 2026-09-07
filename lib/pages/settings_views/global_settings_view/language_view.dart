import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/global/prefs_provider.dart';
import '../../../utilities/enums/languages_enum.dart';

class LanguageSettingsView extends ConsumerWidget {
  const LanguageSettingsView({super.key});
  static const routeName = '/languageSettings';
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsChangeNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: Text(goTr(context, "语言 / Language"))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(goTr(context, "选择后立即生效，并保存在本机。")),
            ),
            for (final language in Language.values)
              Card(
                child: ListTile(
                  title: Text(language.description),
                  trailing: prefs.language == language.description
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () => prefs.language = language.description,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
