import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Building blocks for the auth-style pages (forgot password, the Post tab's
/// guest page): red brand header, a card lifted over it, the field style,
/// error box and buttons — the same look as the login and sign-up screens.

/// Red gradient header with the logo (or [icon]) in a white tile.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.topPadding = 52,
  });

  final String title;
  final String subtitle;

  /// Shown in the tile instead of the logo.
  final IconData? icon;

  /// Space above the tile, below the status bar (room for an app bar).
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + topPadding, 24, 66),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFFC81B00)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: icon != null
                ? Icon(icon, color: AppColors.primary, size: 38)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/images/logo.png',
                        fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The white card that overlaps the header's bottom edge.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child, this.lift = 42});

  final Widget child;
  final double lift;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkNavy : Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: isDark ? Border.all(color: AppColors.borderDark) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Page background behind the header and card.
Color authBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.backgroundDark
        : const Color(0xFFF6F6F8);

Color authMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textMuted;

Color authTitle(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.textLight
        : AppColors.textDark;

/// Card heading + note.
class AuthCardHeading extends StatelessWidget {
  const AuthCardHeading({super.key, required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: authTitle(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          note,
          style:
              TextStyle(color: authMuted(context), fontSize: 13.5, height: 1.5),
        ),
      ],
    );
  }
}

/// Outlined field with a leading icon that turns red when focused.
InputDecoration authFieldDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  Widget? suffix,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  final idle = isDark ? AppColors.borderDark : AppColors.borderLight;
  return InputDecoration(
    labelText: label,
    floatingLabelStyle:
        const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
    prefixIcon: Icon(icon, size: 22),
    prefixIconColor: WidgetStateColor.resolveWith((states) =>
        states.contains(WidgetState.focused)
            ? AppColors.primary
            : (isDark ? AppColors.iconMutedDark : AppColors.textMuted)),
    suffixIcon: suffix,
    filled: true,
    fillColor: isDark ? AppColors.surfaceElevatedDark : const Color(0xFFF7F7F9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: border(idle),
    enabledBorder: border(idle),
    focusedBorder: border(AppColors.primary, 1.6),
  );
}

/// Red-tinted box with an icon for a form error.
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width red button with a trailing arrow and a busy spinner.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 20),
                ],
              ),
      ),
    );
  }
}

/// "— prompt —" divider followed by a full-width outlined button.
class AuthSecondaryAction extends StatelessWidget {
  const AuthSecondaryAction({
    super.key,
    required this.prompt,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
  });

  final String prompt;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = isDark ? AppColors.borderDark : AppColors.borderLight;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: line)),
            Flexible(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(prompt,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: authMuted(context), fontSize: 13)),
              ),
            ),
            Expanded(child: Divider(color: line)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            key: buttonKey,
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.4),
              backgroundColor: isDark ? AppColors.cardDarkNavy : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small icon + text line, e.g. a tip or a benefit.
class AuthInfoLine extends StatelessWidget {
  const AuthInfoLine({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? authMuted(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text,
                  style: TextStyle(fontSize: 13.5, color: c, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
