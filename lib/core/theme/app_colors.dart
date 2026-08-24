import 'package:flutter/material.dart';

/// A warm, printed-almanac palette: cream paper, deep forest green ink, and
/// gold for anything worth counting. The previous grey-and-white scheme read
/// as an empty spreadsheet; this one gives every screen a colour temperature
/// while still letting colour carry meaning.
abstract final class AppColors {
  // ------------------------------------------------------------- surfaces
  /// Page background — warm cream, like the paper of a farm ledger.
  static const canvas = Color(0xFFF7F0E1);

  /// Cards and raised content.
  static const surface = Color(0xFFFFFCF4);

  /// Inset fills: input backgrounds, empty progress track.
  static const surfaceAlt = Color(0xFFF1E8D4);

  static const line = Color(0xFFE6DBC2);
  static const lineStrong = Color(0xFFD3C4A4);

  // --------------------------------------------------------------- accent
  /// Headers, primary buttons, the top bar on every screen.
  static const forest = Color(0xFF1B5C46);
  static const forestDeep = Color(0xFF12402F);
  static const accent = Color(0xFF2C7B5C);
  static const accentDeep = forest;
  static const accentSoft = Color(0xFFDDEBE1);
  static const accentInk = Color(0xFF11402F);

  // ----------------------------------------------------------------- gold
  /// Counts, totals, anything the keeper is accumulating.
  static const gold = Color(0xFFE0A32E);
  static const goldDeep = Color(0xFFB77A11);
  static const goldSoft = Color(0xFFFAEDCF);

  // ------------------------------------------------------------- semantic
  static const warn = Color(0xFFD9862A);
  static const warnSoft = Color(0xFFFBEBD3);

  static const danger = Color(0xFFB94A32);
  static const dangerSoft = Color(0xFFFAE3DC);

  static const info = Color(0xFF3E85A0);
  static const infoSoft = Color(0xFFE0EEF3);

  static const berry = Color(0xFF7B5EA7);
  static const berrySoft = Color(0xFFEDE7F6);

  // ----------------------------------------------------------------- text
  static const ink = Color(0xFF2A2418);
  static const inkMuted = Color(0xFF7A6E58);
  static const inkFaint = Color(0xFFA1947C);
  static const onAccent = Color(0xFFFFFFFF);

  // ------------------------------------------- difficulty / intensity ramp
  // Used by charts and gauges so "easy to hard" always reads the same way.
  static const rampLow = Color(0xFF4CA06B);
  static const rampMid = Color(0xFFD3C43C);
  static const rampHigh = Color(0xFFE08A2E);
  static const rampPeak = Color(0xFFC0503A);

  // --------------------------------------------------- compatibility names
  static const meadowDeep = forest;
  static const meadow = accent;
  static const grass = accentSoft;
  static const grassSoft = Color(0xFFC9DFD1);
  static const cream = canvas;
  static const shell = surfaceAlt;
  static const paper = surface;
  static const amber = gold;
  static const sky = info;
  static const water = info;
  static const bark = Color(0xFF8A7350);
  static const barkDeep = ink;
  static const inkSoft = inkMuted;

  // ------------------------------------------ coop layout area categories
  static const zoneNesting = gold;
  static const zoneFeeding = bark;
  static const zoneWater = info;
  static const zoneFree = accent;
  static const zoneCollection = berry;
}

/// Gradients do real work here: the hero band at the top of a screen, the
/// gold of a total, and the low-to-high ramp shared by every chart.
abstract final class AppGradients {
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF237056), AppColors.forestDeep],
  );

  static const bar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.forest, AppColors.forestDeep],
  );

  static const goldenEgg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0C05A), AppColors.goldDeep],
  );

  /// Low → high. Elevation, difficulty, workload, lay rate.
  static const ramp = LinearGradient(
    colors: [
      AppColors.rampLow,
      AppColors.rampMid,
      AppColors.rampHigh,
      AppColors.rampPeak,
    ],
  );
}
