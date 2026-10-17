import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/providers.dart';
import '../../design/icons/app_icons.dart';
import '../common/skin_tokens.dart';

/// Встроенные пресеты как 5-точечные профили (дБ), интерполируются под число
/// полос устройства.
const _builtinPresets = <String, List<double>>{
  'Плоский': [0, 0, 0, 0, 0],
  'Бас-буст': [7, 4, 0, 1, 2],
  'Вокал': [-2, 0, 3, 3, 1],
  'Рок': [5, 2, -1, 2, 4],
  'Поп': [2, 3, 1, 0, 1],
  'Джаз': [3, 1, 0, 1, 3],
  'Классика': [4, 2, 0, 2, 3],
  'Высокие': [0, 0, 0, 3, 6],
};

class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  late final AndroidEqualizer _eq = ref.read(audioHandlerProvider).equalizer;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _enabled = _eq.enabled;
  }

  List<MapEntry<String, List<double>>> get _customPresets {
    final raw = ref.read(prefsProvider).getStringList('eq_presets') ?? const [];
    return raw.map((e) {
      final m = jsonDecode(e) as Map<String, dynamic>;
      return MapEntry(
          m['name'] as String,
          (m['gains'] as List).map((x) => (x as num).toDouble()).toList());
    }).toList();
  }

  void _applyProfile(AndroidEqualizerParameters params, List<double> p) {
    final bands = params.bands;
    final n = bands.length;
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? 0.0 : i * (p.length - 1) / (n - 1);
      final lo = x.floor().clamp(0, p.length - 1);
      final hi = x.ceil().clamp(0, p.length - 1);
      final frac = x - lo;
      final g = (p[lo] * (1 - frac) + p[hi] * frac)
          .clamp(params.minDecibels, params.maxDecibels);
      bands[i].setGain(g);
    }
    _eq.setEnabled(true);
    setState(() => _enabled = true);
  }

  Future<void> _saveCurrent(AndroidEqualizerParameters params) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) {
        final t = skinOf(context).tokens;
        final c = TextEditingController();
        return AlertDialog(
          // Поверхность диалога из токенов: светлая Material-подложка на
          // графите iPod читалась бы чужеродным элементом.
          backgroundColor: t.surface,
          title: Text('Сохранить пресет',
              style: t.headline.copyWith(color: t.textPrimary)),
          content: TextField(
              controller: c,
              autofocus: true,
              style: t.body.copyWith(color: t.textPrimary),
              decoration: InputDecoration(
                  hintStyle: t.body.copyWith(color: t.textTertiary),
                  hintText: 'Название')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Отмена',
                    style: t.caption.copyWith(color: t.textSecondary))),
            FilledButton(
                onPressed: () => Navigator.pop(context, c.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.accentOn,
                ),
                child: const Text('Сохранить')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final gains = params.bands.map((b) => b.gain).toList();
    final list = ref.read(prefsProvider).getStringList('eq_presets') ?? [];
    list.add(jsonEncode({'name': name, 'gains': gains}));
    await ref.read(prefsProvider).setStringList('eq_presets', list);
    setState(() {});
  }

  Future<void> _deleteCustom(String name) async {
    final list = (ref.read(prefsProvider).getStringList('eq_presets') ?? [])
        .where((e) => (jsonDecode(e) as Map)['name'] != name)
        .toList();
    await ref.read(prefsProvider).setStringList('eq_presets', list);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        title: Text('Эквалайзер', style: t.headline.copyWith(color: t.textPrimary)),
      ),
      body: Column(
        children: [
          // Своя строка с тумблером вместо SwitchListTile: цвет включённого
          // состояния — акцент скина, в iPod он монохромный. Строка кликабельна
          // целиком, а не только по самому переключателю.
          InkWell(
            onTap: () {
              _eq.setEnabled(!_enabled);
              setState(() => _enabled = !_enabled);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space16,
                vertical: t.space12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Включить эквалайзер',
                        style: t.body.copyWith(color: t.textPrimary)),
                  ),
                  Switch(
                    value: _enabled,
                    onChanged: (v) {
                      _eq.setEnabled(v);
                      setState(() => _enabled = v);
                    },
                    activeThumbColor: t.accent,
                  ),
                ],
              ),
            ),
          ),
          // Разделитель — из токенов, а не Divider: толщина и совпадают с
          // линиями списков скина.
          Container(height: 1, color: t.separator),
          Expanded(
            child: FutureBuilder<AndroidEqualizerParameters>(
              future: _eq.parameters,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(
                      child: CircularProgressIndicator(color: t.accent));
                }
                if (!snap.hasData) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(t.space24),
                      child: Text(
                        'Эквалайзер недоступен (запустите трек и откройте снова).',
                        textAlign: TextAlign.center,
                        style: t.body.copyWith(color: t.textTertiary),
                      ),
                    ),
                  );
                }
                final params = snap.data!;
                final custom = _customPresets;
                return ListView(
                  padding: EdgeInsets.symmetric(vertical: t.space8),
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(t.space16, t.space4,
                          t.space16, t.space8),
                      child: Text('Пресеты',
                          style: t.caption.copyWith(color: t.textSecondary)),
                    ),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding:
                            EdgeInsets.symmetric(horizontal: t.space12),
                        children: [
                          for (final e in _builtinPresets.entries)
                            _PresetChip(
                              label: e.key,
                              onTap: () => _applyProfile(params, e.value),
                            ),
                          for (final e in custom)
                            _PresetChip(
                              label: e.key,
                              custom: true,
                              onTap: () => _applyProfile(params, e.value),
                              onLong: () => _deleteCustom(e.key),
                            ),
                          Padding(
                            padding: EdgeInsets.only(left: t.space4),
                            child: ActionChip(
                              avatar: AppIcon(
                                AppIcons.plus,
                                size: 16,
                                color: t.textSecondary,
                              ),
                              label: Text('Сохранить',
                                  style: t.caption
                                      .copyWith(color: t.textSecondary)),
                              onPressed: () => _saveCurrent(params),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 1,
                      color: t.separator,
                      margin: EdgeInsets.symmetric(vertical: t.space8),
                    ),
                    for (final band in params.bands)
                      _BandRow(
                        band: band,
                        min: params.minDecibels,
                        max: params.maxDecibels,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.onTap,
    this.onLong,
    this.custom = false,
  });
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLong;
  final bool custom;

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return Padding(
      padding: EdgeInsets.only(right: t.space8),
      child: GestureDetector(
        onLongPress: onLong,
        child: ActionChip(
          // Свои пресеты помечаем «плюс-звёздой» (sparkles): персонаж-иконка из
          // Material в монохромном скине читалась бы как из другой системы.
          avatar: custom
              ? AppIcon(AppIcons.sparkles, size: 15, color: t.accent)
              : null,
          label: Text(label,
              style: t.caption.copyWith(color: t.textPrimary)),
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({
    required this.band,
    required this.min,
    required this.max,
  });

  final AndroidEqualizerBand band;
  final double min;
  final double max;

  String _freq(double hz) =>
      hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)}кГц'
                 : '${hz.round()}Гц';

  @override
  Widget build(BuildContext context) {
    final t = skinOf(context).tokens;
    return StreamBuilder<double>(
      stream: band.gainStream,
      initialData: band.gain,
      builder: (context, snap) {
        final gain = (snap.data ?? band.gain).clamp(min, max);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space16, vertical: t.space2),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(_freq(band.centerFrequency),
                    style: t.caption.copyWith(color: t.textSecondary)),
              ),
              Expanded(
                child: Slider(
                  min: min,
                  max: max,
                  value: gain,
                  onChanged: (v) => band.setGain(v),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('${gain.toStringAsFixed(1)} дБ',
                    textAlign: TextAlign.right,
                    style: t.micro.copyWith(color: t.textTertiary)),
              ),
            ],
          ),
        );
      },
    );
  }
}
