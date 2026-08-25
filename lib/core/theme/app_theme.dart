import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Central ResQ themes. The dark palette is tuned to the Pet Match UI.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme.light(
        primary: AppColors.primaryBlue,
        onPrimary: Colors.white,
        secondary: AppColors.secondaryCoral,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF2A2A2A),
        outline: Color(0xFFD0C4B5));
    return _baseTheme(
        brightness: Brightness.light,
        scheme: scheme,
        scaffold: const Color(0xFFFBEFE2),
        appBar: const Color(0xFFFBEFE2),
        extension: ResQThemeExtension.light);
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
        primary: Color(0xFF08B8BC),
        onPrimary: Color(0xFF001F20),
        primaryContainer: Color(0xFF07383B),
        onPrimaryContainer: Color(0xFFD9FFFF),
        secondary: Color(0xFF6EE8E9),
        onSecondary: Color(0xFF002021),
        surface: Color(0xFF091014),
        onSurface: Color(0xFFF1F7F8),
        outline: Color(0xFF23353B),
        error: Color(0xFFFF7373),
        onError: Colors.black);
    return _baseTheme(
        brightness: Brightness.dark,
        scheme: scheme,
        scaffold: const Color(0xFF050A0D),
        appBar: const Color(0xFF050A0D),
        extension: ResQThemeExtension.dark);
  }

  static ThemeData _baseTheme(
      {required Brightness brightness,
      required ColorScheme scheme,
      required Color scaffold,
      required Color appBar,
      required ResQThemeExtension extension}) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: scheme,
        scaffoldBackgroundColor: scaffold,
        fontFamily: 'Poppins',
        appBarTheme: AppBarTheme(
            backgroundColor: appBar,
            foregroundColor: extension.textPrimary,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: extension.textPrimary),
            titleTextStyle: TextStyle(
                color: extension.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins')),
        cardTheme: CardThemeData(
            color: extension.cardBackground,
            surfaceTintColor: Colors.transparent,
            elevation: 0),
        dividerTheme: DividerThemeData(color: extension.dividerColor),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: extension.fieldFill,
            hintStyle: TextStyle(color: extension.hintText),
            labelStyle: TextStyle(color: extension.textSecondary),
            border: _inputBorder(extension.fieldBorder),
            enabledBorder: _inputBorder(extension.fieldBorder),
            focusedBorder: _inputBorder(extension.accentOrange),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                elevation: 0,
                foregroundColor:
                    isDark ? const Color(0xFF002021) : Colors.white,
                backgroundColor: extension.accentOrange,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)))),
        textTheme: TextTheme(
            bodyMedium: TextStyle(color: extension.textPrimary),
            bodySmall: TextStyle(color: extension.textSecondary)),
        extensions: [extension]);
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color));
}

@immutable
class ResQThemeExtension extends ThemeExtension<ResQThemeExtension> {
  const ResQThemeExtension(
      {required this.scaffoldBackground,
      required this.cardBackground,
      required this.cardBorder,
      required this.textPrimary,
      required this.textSecondary,
      required this.accentOrange,
      required this.accentOrangeGlow,
      required this.fieldFill,
      required this.fieldBorder,
      required this.hintText,
      required this.navBarBackground,
      required this.navBarBorder,
      required this.navSelected,
      required this.navUnselected,
      required this.logoTextColor,
      required this.watermarkColor,
      required this.dividerColor,
      required this.outlinedButtonBackground,
      required this.outlinedButtonBorder,
      required this.inputTextColor});
  final Color scaffoldBackground,
      cardBackground,
      cardBorder,
      textPrimary,
      textSecondary,
      accentOrange,
      accentOrangeGlow,
      fieldFill,
      fieldBorder,
      hintText,
      navBarBackground,
      navBarBorder,
      navSelected,
      navUnselected,
      logoTextColor,
      watermarkColor,
      dividerColor,
      outlinedButtonBackground,
      outlinedButtonBorder,
      inputTextColor;

  static const light = ResQThemeExtension(
      scaffoldBackground: Color(0xFFFBEFE2),
      cardBackground: Colors.white,
      cardBorder: Color(0xFFE7DCCB),
      textPrimary: Color(0xFF2A2A2A),
      textSecondary: Color(0xFF6B6B6B),
      accentOrange: AppColors.secondaryCoral,
      accentOrangeGlow: Color(0x28F97350),
      fieldFill: Colors.white,
      fieldBorder: Color(0xFFD0C4B5),
      hintText: Color(0xFF9E9E9E),
      navBarBackground: Colors.white,
      navBarBorder: Color(0xFFE7DCCB),
      navSelected: AppColors.secondaryCoral,
      navUnselected: Color(0xFFAAAAAA),
      logoTextColor: Color(0xFF2A2A2A),
      watermarkColor: Color(0xFF2A2A2A),
      dividerColor: Color(0xFFE7DCCB),
      outlinedButtonBackground: Color(0xFFF5F0EC),
      outlinedButtonBorder: Color(0xFFD0C4B5),
      inputTextColor: Color(0xFF2A2A2A));
  static const dark = ResQThemeExtension(
      scaffoldBackground: Color(0xFF050A0D),
      cardBackground: Color(0xFF0B1418),
      cardBorder: Color(0xFF23353B),
      textPrimary: Color(0xFFF1F7F8),
      textSecondary: Color(0xFFB5C5C8),
      accentOrange: Color(0xFF08B8BC),
      accentOrangeGlow: Color(0x4208B8BC),
      fieldFill: Color(0xFF0B1418),
      fieldBorder: Color(0xFF23353B),
      hintText: Color(0xFF97A9AD),
      navBarBackground: Color(0xFF0B1418),
      navBarBorder: Color(0xFF23353B),
      navSelected: Color(0xFF08B8BC),
      navUnselected: Color(0xFFB5C5C8),
      logoTextColor: Colors.white,
      watermarkColor: Colors.white,
      dividerColor: Color(0xFF23353B),
      outlinedButtonBackground: Color(0xFF0B1418),
      outlinedButtonBorder: Color(0xFF08B8BC),
      inputTextColor: Colors.white);

  @override
  ResQThemeExtension copyWith(
          {Color? scaffoldBackground,
          Color? cardBackground,
          Color? cardBorder,
          Color? textPrimary,
          Color? textSecondary,
          Color? accentOrange,
          Color? accentOrangeGlow,
          Color? fieldFill,
          Color? fieldBorder,
          Color? hintText,
          Color? navBarBackground,
          Color? navBarBorder,
          Color? navSelected,
          Color? navUnselected,
          Color? logoTextColor,
          Color? watermarkColor,
          Color? dividerColor,
          Color? outlinedButtonBackground,
          Color? outlinedButtonBorder,
          Color? inputTextColor}) =>
      ResQThemeExtension(
          scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
          cardBackground: cardBackground ?? this.cardBackground,
          cardBorder: cardBorder ?? this.cardBorder,
          textPrimary: textPrimary ?? this.textPrimary,
          textSecondary: textSecondary ?? this.textSecondary,
          accentOrange: accentOrange ?? this.accentOrange,
          accentOrangeGlow: accentOrangeGlow ?? this.accentOrangeGlow,
          fieldFill: fieldFill ?? this.fieldFill,
          fieldBorder: fieldBorder ?? this.fieldBorder,
          hintText: hintText ?? this.hintText,
          navBarBackground: navBarBackground ?? this.navBarBackground,
          navBarBorder: navBarBorder ?? this.navBarBorder,
          navSelected: navSelected ?? this.navSelected,
          navUnselected: navUnselected ?? this.navUnselected,
          logoTextColor: logoTextColor ?? this.logoTextColor,
          watermarkColor: watermarkColor ?? this.watermarkColor,
          dividerColor: dividerColor ?? this.dividerColor,
          outlinedButtonBackground:
              outlinedButtonBackground ?? this.outlinedButtonBackground,
          outlinedButtonBorder:
              outlinedButtonBorder ?? this.outlinedButtonBorder,
          inputTextColor: inputTextColor ?? this.inputTextColor);

  @override
  ResQThemeExtension lerp(ResQThemeExtension? other, double t) {
    if (other is! ResQThemeExtension) return this;
    Color b(Color a, Color c) => Color.lerp(a, c, t)!;
    return ResQThemeExtension(
        scaffoldBackground: b(scaffoldBackground, other.scaffoldBackground),
        cardBackground: b(cardBackground, other.cardBackground),
        cardBorder: b(cardBorder, other.cardBorder),
        textPrimary: b(textPrimary, other.textPrimary),
        textSecondary: b(textSecondary, other.textSecondary),
        accentOrange: b(accentOrange, other.accentOrange),
        accentOrangeGlow: b(accentOrangeGlow, other.accentOrangeGlow),
        fieldFill: b(fieldFill, other.fieldFill),
        fieldBorder: b(fieldBorder, other.fieldBorder),
        hintText: b(hintText, other.hintText),
        navBarBackground: b(navBarBackground, other.navBarBackground),
        navBarBorder: b(navBarBorder, other.navBarBorder),
        navSelected: b(navSelected, other.navSelected),
        navUnselected: b(navUnselected, other.navUnselected),
        logoTextColor: b(logoTextColor, other.logoTextColor),
        watermarkColor: b(watermarkColor, other.watermarkColor),
        dividerColor: b(dividerColor, other.dividerColor),
        outlinedButtonBackground:
            b(outlinedButtonBackground, other.outlinedButtonBackground),
        outlinedButtonBorder:
            b(outlinedButtonBorder, other.outlinedButtonBorder),
        inputTextColor: b(inputTextColor, other.inputTextColor));
  }
}
