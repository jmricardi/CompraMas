import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cache/hive_manager.dart';
import '../../../services/locale_service.dart';
import '../../../services/settings_service.dart';
import '../../components/app_header_top_bar.dart';
import '../../components/glass_card.dart';
import 'developer_ad_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _devTapCount = 0;
  bool _isDevUnlocked = false;

  @override
  void initState() {
    super.initState();
    _isDevUnlocked = HiveManager.getSync<bool>('is_dev_mode_unlocked') ?? false;
  }

  void _handleVersionTap() {
    _devTapCount++;
    if (_devTapCount >= 5 || _isDevUnlocked) {
      _isDevUnlocked = true;
      HiveManager.setSync<bool>('is_dev_mode_unlocked', true);
      _devTapCount = 0;
      if (!mounted) return;
      setState(() {});
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DeveloperAdSettingsScreen()),
      );
    } else {
      final remaining = 5 - _devTapCount;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Toca $remaining veces más para acceder al Panel de Anuncios.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _launchExternalUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[Settings] Error al abrir enlace $urlString: $e');
    }
  }

  Future<void> _launchInAppUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[Settings] Error al abrir enlace integrado $urlString: $e');
    }
  }

  Future<void> _launchEmail(String email) async {
    try {
      final uri = Uri(scheme: 'mailto', path: email);
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[Settings] Error al abrir email: $e');
    }
  }

  Future<void> _confirmAndExitApp() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir de CompraMas?'),
        content: const Text(
          'Se cerrará completamente la aplicación y se liberarán todos los recursos del sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      await SystemNavigator.pop();
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeaderTopBar(title: 'Ajustes'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // 1. Contenedor "Configuración"
          _buildConfiguracionContainer(context),
          const SizedBox(height: 10),

          // Panel de anuncios para desarrolladores (si está desbloqueado)
          if (_isDevUnlocked) ...[
            _ActionCard(
              icon: Icons.developer_mode_rounded,
              title: 'Panel de Anuncios (Desarrollador)',
              subtitle: 'Meta, Yandex, Cooldowns y Test Activity',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeveloperAdSettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
          ],

          // 2. Contenedor "Ayuda"
          _buildAyudaContainer(context),
          const SizedBox(height: 10),

          // 4. Contenedor aparte "Contáctenos"
          _buildContactenosContainer(context),
          const SizedBox(height: 18),

          // 5. Botón "Salir de la aplicación"
          _buildExitButton(context),
          const SizedBox(height: 16),

          // 6. Pie de versión de la app (toca 5 veces para activar modo dev)
          InkWell(
            onTap: _handleVersionTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'CompraMas v1.0.0 (build 1)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildConfiguracionContainer(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: primary),
              const SizedBox(width: 8),
              const Text(
                'Configuración',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Idioma
          Consumer<LocaleService>(
            builder: (context, localeSvc, _) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.language, size: 20, color: primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Idioma',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                DropdownButton<String>(
                  value: localeSvc.currentLanguage,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: LocaleService.languages
                      .map((l) => DropdownMenuItem(
                            value: l,
                            child: Text(l, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) localeSvc.setLanguage(val);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Limpiar caché
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Caché limpiada exitosamente.')),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.cleaning_services_outlined, size: 20, color: primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Limpiar caché',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
          const Divider(height: 20),

          // Radio de búsqueda
          Consumer<SettingsService>(
            builder: (context, settingsSvc, _) => _SearchRadiusSection(
              currentRadiusKm: settingsSvc.searchRadiusKm,
              onChanged: (km) => settingsSvc.setSearchRadiusKm(km),
            ),
          ),
          const Divider(height: 20),

          // Etiquetas en búsqueda (contenedor desplegable)
          const _SearchTagsSection(),
        ],
      ),
    );
  }

  Widget _buildAyudaContainer(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.help_center_outlined, size: 20, color: primary),
              const SizedBox(width: 8),
              const Text(
                'Ayuda',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _buildSimpleActionItem(
            icon: Icons.help_outline,
            title: 'Preguntas frecuentes',
            onTap: () => _launchExternalUrl('https://compramas.arandulabs.dev/faq.html'),
          ),
          const Divider(height: 16),

          _buildSimpleActionItem(
            icon: Icons.gavel_outlined,
            title: 'Términos del servicio',
            onTap: () => _launchExternalUrl('https://compramas.arandulabs.dev/terms.html'),
          ),
          const Divider(height: 16),

          _buildSimpleActionItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de privacidad',
            onTap: () => _launchExternalUrl('https://compramas.arandulabs.dev/privacy.html'),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildContactenosContainer(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_outlined, size: 20, color: primary),
              const SizedBox(width: 8),
              const Text(
                'Contáctenos',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Empresa / Dev
          _buildContactItem(
            icon: Icons.business_outlined,
            text: 'Arandu Labs LLC',
          ),
          const SizedBox(height: 8),

          // 2. Web
          _buildContactItem(
            icon: Icons.language_outlined,
            text: 'www.arandulabs.dev',
            onTap: () => _launchInAppUrl('https://arandulabs.dev'),
            isLink: true,
          ),
          const SizedBox(height: 8),

          // 3. Email
          _buildContactItem(
            icon: Icons.email_outlined,
            text: 'soporte@arandulabs.dev',
            onTap: () => _launchEmail('soporte@arandulabs.dev'),
            isLink: true,
          ),
          const SizedBox(height: 8),

          // 4. Telegram enmascarado
          _buildContactItem(
            icon: Icons.send_rounded,
            text: 'Comunidad en Telegram (Arandú Labs)',
            onTap: () => _launchExternalUrl('https://t.me/+qiB5I6sq-O81NTc5'),
            isLink: true,
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool isLink = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    final content = Row(
      children: [
        Icon(icon, size: 18, color: primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isLink ? FontWeight.w500 : FontWeight.w600,
              color: isLink ? primary : null,
              decoration: isLink ? TextDecoration.underline : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isLink)
          Icon(Icons.open_in_new, size: 14, color: primary),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: content,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: content,
    );
  }

  Widget _buildExitButton(BuildContext context) {
    return InkWell(
      onTap: _confirmAndExitApp,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_settings_new_rounded,
                color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text(
              'Salir de la aplicación',
              style: TextStyle(
                color: Color(0xFFEF4444),
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SearchRadiusSection extends StatelessWidget {
  final double currentRadiusKm;
  final ValueChanged<double> onChanged;

  const _SearchRadiusSection({
    required this.currentRadiusKm,
    required this.onChanged,
  });

  String get _radiusLabel {
    return currentRadiusKm % 1 == 0
        ? '${currentRadiusKm.toInt()} km'
        : '${currentRadiusKm.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.radar, size: 20, color: primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Radio de búsqueda',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _radiusLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: currentRadiusKm.clamp(0.5, 20.0),
            min: 0.5,
            max: 20.0,
            divisions: 39,
            label: _radiusLabel,
            onChanged: (val) => onChanged(double.parse(val.toStringAsFixed(1))),
          ),
        ),
      ],
    );
  }
}

class _SearchTagsSection extends StatefulWidget {
  const _SearchTagsSection();

  @override
  State<_SearchTagsSection> createState() => _SearchTagsSectionState();
}

class _SearchTagsSectionState extends State<_SearchTagsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final settings = context.watch<SettingsService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.label_outline_rounded, size: 20, color: primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Etiquetas en búsqueda',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Filtros rápidos visibles al buscar productos',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: primary,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _buildTagCheckbox(
                  'Variedad (recomendado)',
                  'Filtra por tipo de producto (ej: entera, descremada)',
                  settings.showVariedadTag,
                  (v) => settings.setShowVariedadTag(v ?? true),
                  primary,
                ),
                _buildTagCheckbox(
                  'Presentación',
                  'Filtra por contenido o peso (ej: 1 kg, 500 g)',
                  settings.showPresentacionTag,
                  (v) => settings.setShowPresentacionTag(v ?? false),
                  primary,
                ),
                _buildTagCheckbox(
                  'Marca',
                  'Filtra por marcas específicas',
                  settings.showMarcaTag,
                  (v) => settings.setShowMarcaTag(v ?? false),
                  primary,
                ),
                _buildTagCheckbox(
                  'Envase',
                  'Filtra por envase (ej: sachet, caja, botella)',
                  settings.showEnvaseTag,
                  (v) => settings.setShowEnvaseTag(v ?? false),
                  primary,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTagCheckbox(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool?> onChanged,
    Color activeColor,
  ) {
    return CheckboxListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
      ),
      value: value,
      activeColor: activeColor,
      onChanged: onChanged,
    );
  }
}

