import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// GOwallet visual primitives. Status colors never imply consensus validation.
abstract final class GoPalette {
  static const ink = Color(0xFF122421);
  static const mint = Color(0xFF45E0B5);
  static const teal = Color(0xFF087B63);
  static const amber = Color(0xFFFFCC80);
}

class GoMark extends StatelessWidget {
  const GoMark({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/in_app_logo_icons/electrum-wallet.svg',
    width: size,
    height: size,
    semanticsLabel: 'GOwallet',
  );
}

class GoSection extends StatelessWidget {
  const GoSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = false,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 8 : 16, top: compact ? 4 : 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 16 : 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: EdgeInsets.only(top: compact ? 3 : 6),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .68),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class GoNotice extends StatelessWidget {
  const GoNotice({
    super.key,
    required this.title,
    required this.detail,
    this.icon = Icons.info_outline_rounded,
  });
  final String title, detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .12),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(detail, style: const TextStyle(fontSize: 13, height: 1.6)),
            ],
          ),
        ),
      ],
    ),
  );
}
