/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2023 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:flutter/material.dart';

/// The wallet hero is ONE neutral surface for every coin, with white ink.
///
/// The coin's colour has not gone anywhere — it still paints the coin icon,
/// its card on the home screen, and the accents. It just stopped being the
/// wall the balance sits on.
///
/// Two earlier rules are in the session notes, and both failed on the same
/// coin. The hero began as the coin's own colour with white ink, which put
/// white on Bellscoin's Bell Bag Gold #F3C532 at 1.64:1 — near invisible.
/// The fix after that adapted the INK per coin, which was always legible but
/// flipped between white and near-black from coin to coin, so three coins read
/// as three products. Deepening the fills to earn white was tried and pulled:
/// it stopped matching Bellscoin's brand kit.
///
/// Measured, which is what ruled the alternatives out:
///
///     BitFinite  #245BF3   white 5.43:1   near-black 3.48:1
///     Pepecoin   #269B4D   white 3.57:1   near-black 5.07:1
///     Bellscoin  #F3C532   white 1.64:1   near-black 11.08:1
///
/// White cannot be used on that gold at all, so no single ink was reachable
/// while the surface stayed the coin's colour. Moving the surface instead
/// settles it once: white lands at 17.72:1 on every coin, and it keeps
/// working for a fourth coin whatever colour that turns out to be, which
/// neither of the other rules did.
const Color kHeroSurface = Color(0xFF18181B);

/// Always white now. Kept as a function because every hero label calls it, and
/// a single definition is what stops the ink drifting apart again.
Color heroInk(Color hero) => Colors.white;

/// Hero de-emphasis opacities, passed through unchanged.
///
/// This used to map each white-tuned opacity onto a higher dark-ink one,
/// because dark ink on a mid-luminance fill had less headroom. There is no
/// dark ink on the hero any more, and every step clears AA against
/// [kHeroSurface] by a wide margin, so the shipped values stand as measured.
double heroEmphasis(Color ink, double whiteTunedOpacity) => whiteTunedOpacity;

/// Ink for content on any *other* filled surface — dock pills, the dock itself.
///
/// Unlike the hero, these are not a brand statement, and unreadable text here
/// is a defect rather than a style. The rule is "trust the theme, verify the
/// result": a theme's declared ink is used as-is, and replaced only when it
/// actually fails against the surface it lands on.
///
/// This exists because tokens can disagree with reality. The Orange theme sets
/// `bottom_nav_text` and `popup_bg` to the *same* `#FFFFFF`, so its inactive
/// nav label was painted in the dock's own background — 1.00:1, invisible.
/// No amount of trusting the token fixes that.
///
/// The 4.0 floor sits just under the 4.5 AA line on purpose. Forest puts white
/// at 4.41:1, which reads correctly and was signed off; snapping at 4.5 would
/// restyle Forest over a 0.09 difference. Only genuine failures are replaced.
Color readableInk(Color preferred, Color surface, {double min = 4.0}) {
  if (_contrast(preferred, surface) >= min) return preferred;
  return _contrast(Colors.white, surface) >= _contrast(kInkDark, surface)
      ? Colors.white
      : kInkDark;
}

/// A theme's own signal colour (green up, red down, amber busy), made safe to
/// use on [kHeroSurface].
///
/// The hero used to refuse status colours outright and render every figure in
/// hero ink, because a coin-coloured hero could not promise contrast for them —
/// green on Bellscoin gold measured under 2:1. That objection died with the
/// coin-coloured hero: the surface is one fixed dark neutral now, so a colour
/// only has to clear one known background.
///
/// The theme still chooses the hue. Its greens and reds are authored against
/// the PAGE, though, and a theme with a deep forest green would sit at 2.5:1 on
/// this surface, so the colour is lifted toward white only as far as it takes
/// to clear the floor. A theme whose colour already reads is returned
/// untouched, which is every bundled theme.
Color onHeroSignal(Color themeColor, {double min = 4.5}) {
  var c = themeColor;
  // 0.08 a step, capped, so a colour that cannot be rescued lands on something
  // near white rather than looping.
  for (var i = 0; i < 24 && _contrast(c, kHeroSurface) < min; i++) {
    c = Color.lerp(c, Colors.white, 0.08)!;
  }
  return c;
}

/// A near-black rather than pure black: on a saturated fill pure black reads as
/// a hole punched in the surface.
const Color kInkDark = Color(0xFF14161A);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
