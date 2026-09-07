import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../themes/stack_colors.dart';
import 'assets.dart';

/// Themed "?" help icon used in app bars / inline helpers. The bare
/// `Assets.svg.circleQuestion` bakes a dark color and disappears on dark
/// backgrounds; routing help icons through here guarantees a theme-aware,
/// visible color (and SF Symbol on iOS). Systematic fix for the dark-mode
/// invisible help button.
Widget questionHelpIcon(BuildContext context, {double size = 20, Color? color}) {
  return adaptiveIcon(
    Assets.svg.circleQuestion,
    CupertinoIcons.question_circle,
    size: size,
    color:
        color ?? Theme.of(context).extension<StackColors>()!.topNavIconPrimary,
  );
}

/// Maps the app's settings-row SVG assets to native SF Symbols. Used by
/// [SettingsListButton] so every settings row picks up the iOS icon set in one
/// place. Returns null on non-iOS or for unmapped assets (falls back to SVG).
IconData? cupertinoForSettingAsset(String assetPath) {
  if (!Platform.isIOS) return null;
  return _settingsAssetToCupertino[assetPath];
}

/// Drop-in replacement for `SvgPicture.asset(...)` that renders the mapped SF
/// Symbol on iOS and falls back to the original SVG everywhere else (and for
/// any asset without a mapping). Lets call sites adopt the native icon set
/// without naming a CupertinoIcon at each site.
Widget adaptiveSvg(String svgAsset, {double size = 20, Color? color}) {
  final cupertino = Platform.isIOS ? _settingsAssetToCupertino[svgAsset] : null;
  if (cupertino != null) {
    return Icon(cupertino, size: size, color: color);
  }
  return SvgPicture.asset(svgAsset, width: size, height: size, color: color);
}

final Map<String, IconData> _settingsAssetToCupertino = <String, IconData>{
  // --- general UI icons (address book, network settings, dialogs, ...) ---
  Assets.svg.user: CupertinoIcons.person_fill,
  Assets.svg.thickX: CupertinoIcons.xmark,
  Assets.svg.plus: CupertinoIcons.plus,
  Assets.svg.star: CupertinoIcons.star_fill,
  Assets.svg.pencil: CupertinoIcons.pencil,
  Assets.svg.copy: CupertinoIcons.doc_on_doc,
  Assets.svg.trash: CupertinoIcons.trash,
  Assets.svg.share: CupertinoIcons.share,
  Assets.svg.clipboard: CupertinoIcons.doc_on_clipboard,
  Assets.svg.qrcode: CupertinoIcons.qrcode,
  Assets.svg.search: CupertinoIcons.search,
  Assets.svg.filter: CupertinoIcons.line_horizontal_3_decrease,
  Assets.svg.circleInfo: CupertinoIcons.info_circle,
  Assets.svg.chevronUp: CupertinoIcons.chevron_up,
  Assets.svg.chevronDown: CupertinoIcons.chevron_down,
  Assets.svg.verticalEllipsis: CupertinoIcons.ellipsis,
  Assets.svg.networkWired: CupertinoIcons.square_stack_3d_up_fill,
  Assets.svg.gear: CupertinoIcons.gear_solid,
  Assets.svg.folder: CupertinoIcons.folder_fill,
  Assets.svg.eyeSlash: CupertinoIcons.eye_slash_fill,
  Assets.svg.checkCircle: CupertinoIcons.checkmark_circle_fill,
  Assets.svg.arrowsTwoWay: CupertinoIcons.arrow_2_circlepath,
  Assets.svg.network: CupertinoIcons.antenna_radiowaves_left_right,
  Assets.svg.radio: CupertinoIcons.wifi,
  Assets.svg.radioSyncing: CupertinoIcons.arrow_2_circlepath,
  Assets.svg.radioProblem: CupertinoIcons.wifi_slash,
  Assets.svg.circleQuestion: CupertinoIcons.question_circle,
  // --- settings rows ---
  Assets.svg.addressBook: CupertinoIcons.person_2_fill,
  Assets.svg.downloadFolder: CupertinoIcons.arrow_down_doc_fill,
  Assets.svg.lock: CupertinoIcons.lock_fill,
  Assets.svg.dollarSign: CupertinoIcons.money_dollar,
  Assets.svg.language: CupertinoIcons.globe,
  Assets.svg.tor: CupertinoIcons.shield_lefthalf_fill,
  Assets.svg.node: CupertinoIcons.square_stack_3d_up_fill,
  Assets.svg.arrowRotate: CupertinoIcons.arrow_2_circlepath,
  Assets.svg.arrowUpRight: CupertinoIcons.power,
  Assets.svg.sun: CupertinoIcons.paintbrush_fill,
  Assets.svg.circleAlert: CupertinoIcons.exclamationmark_circle_fill,
  Assets.svg.ellipsis: CupertinoIcons.ellipsis,
  Assets.svg.solidSliders: CupertinoIcons.slider_horizontal_3,
  Assets.svg.key: CupertinoIcons.gear_alt_fill,
  Assets.svg.questionMessage: CupertinoIcons.question_circle_fill,
  Assets.svg.eye: CupertinoIcons.eye_fill,
  Assets.svg.swap: CupertinoIcons.arrow_2_squarepath,
  Assets.svg.peers: CupertinoIcons.person_3_fill,
};

/// Renders a native SF Symbol ([CupertinoIcons]) on iOS, falling back to the
/// app's bundled SVG asset on every other platform. Lets us adopt the native
/// iOS icon set without touching Android/desktop.
Widget adaptiveIcon(
  String svgAsset,
  IconData cupertino, {
  double size = 20,
  Color? color,
}) {
  if (Platform.isIOS) {
    return Icon(cupertino, size: size, color: color);
  }
  return SvgPicture.asset(
    svgAsset,
    width: size,
    height: size,
    color: color,
  );
}
