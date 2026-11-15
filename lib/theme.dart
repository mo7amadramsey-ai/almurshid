import 'package:flutter/material.dart';

// Al-Murshid identity: moss / forest green + beige + sand, gold accent
const kBg = Color(0xFFF4ECDC);       // beige
const kSurface = Color(0xFFFBF7EC);  // light beige card
const kSurface2 = Color(0xFFE6D9BC); // sand
const kMoss = Color(0xFF5E7036);    // moss green (primary)
const kInk = Color(0xFF283420);     // deep green-black text
const kForest = Color(0xFF4F6B2E);  // forest green accent
const kOutline = Color(0xFFD8CCA8);
const kGold = Color(0xFFD4B25E);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kMoss, brightness: Brightness.light).copyWith(
    primary: kMoss,
    onPrimary: Colors.white,
    secondary: kForest,
    onSecondary: Colors.white,
    surface: kSurface,
    onSurface: kInk,
    outline: kOutline,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent, // AppBackdrop paints the page
    navigationBarTheme: const NavigationBarThemeData(indicatorColor: kSurface2),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kInk),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kForest,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        side: const BorderSide(color: kOutline),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: shape,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kInk,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: kOutline,
  );
}

BoxDecoration cardBox([double r = 18]) => BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: kOutline),
    );

/// Page background: beige with a faint eight-point-star lattice (assets/bg_tile.png)
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kBg,
          image: DecorationImage(image: AssetImage('assets/bg_tile.png'), repeat: ImageRepeat.repeat, scale: 2.5),
        ),
        child: child,
      );
}
