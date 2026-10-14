import 'package:flutter/material.dart';

class AppColors {
  // Brand & Palette matching reference Claymorphism design
  static const color1 = Color(0xFF6539C4); // Primary deep purple
  static const color2 = Color(0xFFA58BEB); // Medium pastel purple
  static const color3 = Color(0xFFF2EDFC); // Soft lavender surface

  static const primaryPurple = Color(0xFF673AB7);
  static const primaryDark = Color(0xFF4E26A4);
  static const primaryLight = Color(0xFF8F70FA);

  static const bgLight = Color(0xFFF7F5FE);
  static const bgMid = Color(0xFFEDE7FB);
  static const bgTop = Color(0xFFDDD2F8);

  static const cardBg = Color(0xFFFAF8FE);
  static const cardBgSecondary = Color(0xFFF0EBFB);
  static const pillBg = Color(0xFFE8DEF8);
  static const pillActive = Color(0xFF6E44C7);

  static const light = Colors.white;
  static const dark = Color(0xFF26154A);
  static const textSecondary = Color(0xFF7E7399);
  static const textMuted = Color(0xFFA197B8);

  static const shadowDark = Color(0x245832A8);
  static const shadowLight = Color(0xFFFFFFFF);
}

class AppGradients {
  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFDCD2F8),
      Color(0xFFEDE7FC),
      Color(0xFFF6F4FD),
    ],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF3EEFD),
    ],
  );

  static const primaryButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8C6CF8),
      Color(0xFF6237BE),
    ],
  );

  static const pillActive = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8463F5),
      Color(0xFF5D31B8),
    ],
  );

  static const headerBanner = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9E80FB),
      Color(0xFF754DDE),
      Color(0xFF6136C7),
    ],
  );
}

class ClayDecorations {
  // Standard Claymorphism Card decoration with soft top-left highlight and bottom-right shadow
  static BoxDecoration card({
    double radius = 22,
    Color? color,
    Gradient? gradient,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? (gradient == null ? AppColors.cardBg : null),
      gradient: color != null ? null : (gradient ?? AppGradients.cardGradient),
      borderRadius: BorderRadius.circular(radius),
      border: border ??
          Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1.2,
          ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowDark,
          offset: const Offset(4, 7),
          blurRadius: 14,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.9),
          offset: const Offset(-3, -3),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ],
    );
  }

  // Raised Pill / Button decoration
  static BoxDecoration pill({
    bool isActive = false,
    double radius = 30,
  }) {
    if (isActive) {
      return BoxDecoration(
        gradient: AppGradients.primaryButton,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.35),
            offset: const Offset(2, 6),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            offset: const Offset(-2, -2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      );
    } else {
      return BoxDecoration(
        color: AppColors.pillBg.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.12),
            offset: const Offset(2, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-2, -2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      );
    }
  }

  // Circular Play button / icon button decoration
  static BoxDecoration circle({
    bool isPrimary = false,
    double size = 38,
  }) {
    if (isPrimary) {
      return BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.primaryButton,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.4),
            offset: const Offset(2, 5),
            blurRadius: 10,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            offset: const Offset(-2, -2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      );
    }

    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFECE5F9)],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.9),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowDark.withValues(alpha: 0.18),
          offset: const Offset(3, 4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.white,
          offset: const Offset(-2, -2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ],
    );
  }
}

class AppTextStyles {
  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.dark,
    letterSpacing: -0.3,
  );

  static const subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.dark,
  );

  static const body = TextStyle(
    fontSize: 14,
    color: AppColors.dark,
  );

  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const keyword = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bgMid,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryPurple,
      primary: AppColors.primaryPurple,
      surface: AppColors.cardBg,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
      ),
    ),
  );
}

// -------------------------------------------------------------
// REUSABLE CLAYMORPHISM WIDGETS
// -------------------------------------------------------------

class ClayCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ClayCard({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      margin: margin,
      decoration: ClayDecorations.card(radius: radius),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null || onLongPress != null) {
      return InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(radius),
        child: container,
      );
    }
    return container;
  }
}

class ClayButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool isSecondary;

  const ClayButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.radius = 28,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: padding,
        decoration: isSecondary
            ? ClayDecorations.pill(isActive: false, radius: radius)
            : ClayDecorations.pill(isActive: true, radius: radius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: isSecondary ? AppColors.dark : Colors.white,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                color: isSecondary ? AppColors.dark : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClayCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool isPrimary;
  final Color? iconColor;

  const ClayCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize = 20,
    this.isPrimary = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: ClayDecorations.circle(isPrimary: isPrimary, size: size),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor ??
                (isPrimary ? Colors.white : AppColors.primaryPurple),
          ),
        ),
      ),
    );
  }
}

class ClayPlayButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;
  final bool isPlaying;

  const ClayPlayButton({
    super.key,
    this.onPressed,
    this.size = 36,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: ClayDecorations.circle(isPrimary: false, size: size),
        child: Center(
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: size * 0.58,
            color: AppColors.primaryPurple,
          ),
        ),
      ),
    );
  }
}

class ClayPillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const ClayPillChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: ClayDecorations.pill(isActive: isSelected, radius: 24),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primaryDark,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
