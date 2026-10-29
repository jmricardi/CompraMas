import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';

class AppHeaderTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const AppHeaderTopBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(77.0);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = (screenWidth * 0.035).clamp(10.0, 20.0);

    return SizedBox(
      height: preferredSize.height,
      width: screenWidth,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/header.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF047857), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.35),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 4),
                  ],
                  const _FontScaleControls(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty)
                    ...actions!
                  else
                    SizedBox(width: (screenWidth * 0.16).clamp(52.0, 74.0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontScaleControls extends StatelessWidget {
  const _FontScaleControls();

  @override
  Widget build(BuildContext context) {
    SettingsService? settings;
    try {
      settings = Provider.of<SettingsService>(context, listen: true);
    } catch (_) {
      settings = null;
    }

    if (settings == null) {
      return const SizedBox.shrink();
    }
    final activeSettings = settings;

    final canDecrease = activeSettings.fontSize > SettingsService.minFontSize;
    final canIncrease = activeSettings.fontSize < SettingsService.maxFontSize;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.text_decrease),
            iconSize: 24.0,
            tooltip: 'Reducir letra',
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            color: Colors.white,
            disabledColor: Colors.white.withValues(alpha: 0.35),
            onPressed: canDecrease ? () => activeSettings.decreaseFontScale() : null,
          ),
          Container(
            width: 1,
            height: 20,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            iconSize: 24.0,
            tooltip: 'Aumentar letra',
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            color: Colors.white,
            disabledColor: Colors.white.withValues(alpha: 0.35),
            onPressed: canIncrease ? () => activeSettings.increaseFontScale() : null,
          ),
        ],
      ),
    );
  }
}
