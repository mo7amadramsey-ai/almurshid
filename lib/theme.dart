import 'dart:math' as math;
import 'package:flutter/material.dart';

// Al-Murshid design system: calm green + warm paper (light) and deep forest (dark).
// Colours are read through getters so the whole app switches with [Pal.dark] (see main.dart / rebuildAll).
class Pal {
  static bool dark = false;
  static Color pick(int light, int darkValue) => Color(dark ? darkValue : light);
}

Color get kBg => Pal.pick(0xFFF6F3EA, 0xFF11160F); // page
Color get kSurface => Pal.pick(0xFFFFFFFF, 0xFF1A2117); // cards
Color get kSurface2 => Pal.pick(0xFFECE7D8, 0xFF25301F); // tracks, chips, fills
Color get kInk => Pal.pick(0xFF1F2A1C, 0xFFECEADB); // text
Color get kMoss => Pal.pick(0xFF4C6B3C, 0xFF9CC48D); // accent text / icons
Color get kForest => Pal.pick(0xFF3C6B47, 0xFF4C8559); // primary (buttons, progress)
Color get kOutline => Pal.pick(0xFFE3DDCB, 0xFF2E3A29);
Color get kTint => Pal.pick(0xFFE4EBD9, 0xFF2B3A2B); // selected / soft green fill
Color get kGold => Pal.pick(0xFFC9A24B, 0xFFE0BE6A);
Color get kBrown => Pal.pick(0xFF9A7350, 0xFFC9A07A);
Color get kBrownLight => Pal.pick(0xFFEDE3D2, 0xFF3A3023);
Color get kBrownDark => Pal.pick(0xFF5B4128, 0xFFE6CBA8);
Color get kWarnBg => Pal.pick(0xFFF9E7DA, 0xFF3A2A1D);
Color get kWarn => Pal.pick(0xFFB5602E, 0xFFE08A55);
Color get kWarnText => Pal.pick(0xFF9A4A1F, 0xFFF0A878);

ThemeData buildTheme() {
  final b = Pal.dark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3C6B47), brightness: b).copyWith(
    primary: kForest,
    onPrimary: Colors.white,
    secondary: kMoss,
    tertiary: kBrown,
    surface: kSurface,
    onSurface: kInk,
    outline: kOutline,
    surfaceContainerHigh: kSurface,
    surfaceContainerHighest: kSurface2,
  );
  final base = ThemeData(brightness: b, useMaterial3: true).textTheme;
  final text = base.apply(bodyColor: kInk, displayColor: kInk, fontSizeFactor: 1.06);
  final r16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: 'IBMPlexArabic',
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: Colors.transparent, // AppBackdrop paints the page
    dividerColor: kOutline,
    dividerTheme: DividerThemeData(color: kOutline, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kTint,
      height: 68,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: 'IBMPlexArabic',
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? kForest : kInk.withValues(alpha: 0.7),
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? kForest : kInk.withValues(alpha: 0.7))),
    ),
    chipTheme: ChipThemeData(
      selectedColor: kTint,
      backgroundColor: kSurface,
      side: BorderSide(color: kOutline),
      labelStyle: TextStyle(color: kInk, fontFamily: 'IBMPlexArabic'),
      shape: const StadiumBorder(),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'IBMPlexArabic', fontSize: 22, fontWeight: FontWeight.w700, color: kInk),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kForest,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: r16,
        textStyle: const TextStyle(fontFamily: 'IBMPlexArabic', fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        side: BorderSide(color: kOutline),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: r16,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kForest)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kOutline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kOutline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kForest, width: 1.6)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: kSurface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: kSurface, surfaceTintColor: Colors.transparent),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : kMoss),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kForest : kSurface2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Pal.dark ? kSurface2 : const Color(0xFF283420),
      contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'IBMPlexArabic'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

BoxDecoration cardBox([double r = 18]) => BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: kOutline),
    );

/// Page background: one calm flat colour (the busy star lattice was removed for a simpler look)
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ColoredBox(color: kBg, child: child);
}

/// Circular progress used on the Today screen
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final Widget? child;
  const ProgressRing({super.key, required this.value, this.size = 92, this.child});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size.square(size), painter: _RingPainter(value.clamp(0.0, 1.0), kForest, kSurface2)),
          if (child != null) child!,
        ]),
      );
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color fg, bg;
  _RingPainter(this.v, this.fg, this.bg);
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.12;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = bg;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = fg;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (v > 0) canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * v, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.fg != fg || o.bg != bg;
}

/// Forces every widget to rebuild (used after the light/dark palette changes)
void rebuildAll() {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}
