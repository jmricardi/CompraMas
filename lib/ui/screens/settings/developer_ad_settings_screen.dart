import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/ad_manager.dart';
import '../../components/app_header_top_bar.dart';
import '../../components/glass_card.dart';

/// Panel de control y monitoreo de monetización publicitaria para desarrolladores.
/// Permite conmutar redes publicitarias, inspeccionar cooldowns en tiempo real,
/// abrir el Test Activity de Yandex y verificar identificadores de prueba (AAID y FBAdPrefs).
class DeveloperAdSettingsScreen extends StatefulWidget {
  const DeveloperAdSettingsScreen({super.key});

  @override
  State<DeveloperAdSettingsScreen> createState() => _DeveloperAdSettingsScreenState();
}

class _DeveloperAdSettingsScreenState extends State<DeveloperAdSettingsScreen> {
  Timer? _ticker;
  Map<String, dynamic> _deviceInfo = {};

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    final info = await AdManager.instance.getDeviceInfo();
    if (!mounted) return;
    setState(() {
      _deviceInfo = info;
    });
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: const AppHeaderTopBar(title: 'Panel de Anuncios (Dev)'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // 1. Interruptores de redes
          _buildNetworkTogglesCard(primary),
          const SizedBox(height: 12),

          // 2. Estado de inicialización de SDKs
          _buildSdkStatusCard(),
          const SizedBox(height: 12),

          // 3. Temporizadores de enfriamiento (Cooldowns independientes)
          _buildCooldownsCard(primary),
          const SizedBox(height: 12),

          // 4. Identificadores de dispositivo de pruebas
          _buildDeviceIdentifiersCard(primary),
          const SizedBox(height: 16),

          // 5. Botones de acción manual y Test Activity de Yandex
          _buildActionButtons(primary),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNetworkTogglesCard(Color primary) {
    final adManager = AdManager.instance;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.toggle_on_outlined, color: primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Redes Publicitarias',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: adManager.debugMetaEnabledNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Meta Audience Network', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Facebook Banners, Nativos e Interstitials', style: TextStyle(fontSize: 11)),
              value: enabled,
              onChanged: (val) async {
                await adManager.toggleNetwork('meta', val);
                if (!mounted) return;
                setState(() {});
              },
            ),
          ),
          const Divider(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: adManager.debugYandexEnabledNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Yandex Mobile Ads', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Yandex Banners, Nativos e Interstitials', style: TextStyle(fontSize: 11)),
              value: enabled,
              onChanged: (val) async {
                await adManager.toggleNetwork('yandex', val);
                if (!mounted) return;
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSdkStatusCard() {
    final metaInit = _deviceInfo['isMetaInitialized'] as bool? ?? false;
    final yandexInit = _deviceInfo['isYandexInitialized'] as bool? ?? false;
    final isTestDevice = _deviceInfo['isTestDevice'] as bool? ?? false;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de los SDKs en Tiempo Real',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildStatusRow('Meta Audience Network', metaInit),
          const SizedBox(height: 6),
          _buildStatusRow('Yandex Mobile Ads', yandexInit),
          const SizedBox(height: 6),
          _buildStatusRow('Test Device Auto-Detectado', isTestDevice, customTrueLabel: 'Activo / Protegido'),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isOk, {String? customTrueLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Row(
          children: [
            Icon(
              isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isOk ? Colors.green : Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              isOk ? (customTrueLabel ?? 'Inicializado') : 'No inicializado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOk ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCooldownsCard(Color primary) {
    final adManager = AdManager.instance;
    final remInterstitial = adManager.getRemainingCooldown(AdManager.placementInterstitial);
    final remFeed = adManager.getRemainingCooldown(AdManager.placementFeedCompact);
    final remDetail = adManager.getRemainingCooldown(AdManager.placementArticleDetail);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Enfriamiento por Placement (Cooldown)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCooldownItem('Interstitial (min 120s)', remInterstitial, 120),
          const Divider(height: 12),
          _buildCooldownItem('Native Feed Compact (min 60s)', remFeed, 60),
          const Divider(height: 12),
          _buildCooldownItem('Native Article Detail (min 60s)', remDetail, 60),
        ],
      ),
    );
  }

  Widget _buildCooldownItem(String placement, int remainingSeconds, int totalSeconds) {
    final isReady = remainingSeconds == 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(placement, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isReady ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isReady ? 'Listo' : '${remainingSeconds}s',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isReady ? Colors.green : Colors.orange[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceIdentifiersCard(Color primary) {
    final aaid = _deviceInfo['aaid']?.toString() ?? '36142cbb-659e-49f9-a60a-10ca1ad1abe1';
    final metaHash = _deviceInfo['metaDeviceHash']?.toString() ?? 'c92a4e70-6c57-47fe-a817-0b649cf75f5e';
    final aaidMd5 = _deviceInfo['aaidMd5']?.toString() ?? '881a434a51174f08b1f40b7e16bd9609';

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Identificadores de Dispositivo de Pruebas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCopyableIdRow('AAID / GAID', aaid),
          const SizedBox(height: 6),
          _buildCopyableIdRow('FBAdPrefs Hash', metaHash),
          const SizedBox(height: 6),
          _buildCopyableIdRow('AAID MD5', aaidMd5),
        ],
      ),
    );
  }

  Widget _buildCopyableIdRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(
                value,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 16),
          tooltip: 'Copiar $label',
          onPressed: () => _copyToClipboard(label, value),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Color primary) {
    return Column(
      children: [
        // Botón principal: Test Activity de Yandex (Integration Inspector / Debug Panel)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFC3F1D), // Rojo corporativo Yandex
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.bug_report_rounded, size: 20),
            label: const Text(
              'Test Activity de Yandex',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () async {
              final ok = await AdManager.instance.showYandexTestActivity();
              if (!mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No se pudo abrir el Test Activity de Yandex.')),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Resetear Cooldowns'),
                onPressed: () {
                  AdManager.instance.resetCooldownsAndCounters();
                  if (!mounted) return;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cooldowns y contadores reiniciados a cero.')),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Probar Interstitial'),
                onPressed: () async {
                  final shown = await AdManager.instance.showInterstitial(source: 'developer_test');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(shown ? 'Interstitial desplegado con éxito.' : 'No hay anuncio listo para mostrar.')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
