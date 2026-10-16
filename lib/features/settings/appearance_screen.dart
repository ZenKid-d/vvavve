import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/theme_settings.dart';
import '../../design/icons/app_icons.dart';
import '../../design/skin.dart';
import '../../design/skin_registry.dart';
import '../../design/tokens/design_tokens.dart';

/// Экран «Внешний вид».
///
/// Четыре ручки: тема, фон, акцент, анимации. Раньше здесь же были «вид плеера»
/// (винил/обложка/CD), «скругления углов» и «шрифт» — их убрали вместе с
/// винилом и CD: форму и шрифт задаёт скин, а не этот экран.
class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  double _hue = 260;
  double _sat = 0.6;

  @override
  void initState() {
    super.initState();
    final hsv =
        HSVColor.fromColor(Color(ref.read(themeSettingsProvider).customColor));
    _hue = hsv.hue;
    _sat = hsv.saturation.clamp(0.2, 1.0);
  }

  void _applyCustom() {
    final c = HSVColor.fromAHSV(1, _hue, _sat, 0.9).toColor();
    ref.read(themeSettingsProvider).setCustomColor(c.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(themeSettingsProvider);
    final ctl = ref.read(themeSettingsProvider);
    final skin = ref.watch(skinProvider);
    // Токены текущего скина: экран внешнего вида — единственное место, где
    // ручки настроек и оформление должны быть одного вида, иначе переключатель
    // темы выглядел бы как чужеродная вставка.
    final tokens = skinFor(skin).tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        title: Text(
          'Внешний вид',
          style: tokens.title.copyWith(color: tokens.textPrimary),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.space16,
          tokens.space8,
          tokens.space16,
          tokens.space24,
        ),
        children: [
          _section(tokens, 'Тема'),
          _Seg(
            tokens: tokens,
            labels: const ['iOS', 'iPod'],
            index: skin.index,
            // Скин по умолчанию — первый в перечислении, поэтому индексы
            // совпадают с SkinId.values.
            onTap: (i) => ref.read(skinProvider.notifier).select(SkinId.values[i]),
          ),
          _section(tokens, 'Фон'),
          Row(
            children: [
              for (var i = 0; i < kBgPresets.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == 0 ? tokens.space12 : 0,
                    ),
                    child: _BgCard(
                      tokens: tokens,
                      preset: kBgPresets[i],
                      selected: ts.bgIndex == i,
                      onTap: () => ctl.setBackground(i),
                    ),
                  ),
                ),
            ],
          ),
          _section(tokens, 'Акцентный цвет'),
          _Seg(
            tokens: tokens,
            labels: const ['Динамический', 'Пресеты', 'Свой'],
            index: ts.accentMode.index,
            onTap: (i) => ctl.setAccentMode(AccentMode.values[i]),
          ),
          if (ts.accentMode == AccentMode.preset) ...[
            SizedBox(height: tokens.space12),
            Wrap(
              spacing: tokens.space12,
              runSpacing: tokens.space12,
              children: [
                for (var i = 0; i < kAccentPresets.length; i++)
                  _Swatch(
                    tokens: tokens,
                    color: kAccentPresets[i],
                    selected: ts.presetIndex == i,
                    onTap: () => ctl.setPreset(i),
                  ),
              ],
            ),
          ],
          if (ts.accentMode == AccentMode.custom) ...[
            SizedBox(height: tokens.space16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(ts.customColor),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: tokens.space12),
                Text(
                  'Свой цвет',
                  style: tokens.body.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
            SizedBox(height: tokens.space8),
            _label(tokens, 'Оттенок'),
            Slider(
              min: 0,
              max: 360,
              value: _hue,
              onChanged: (v) {
                setState(() => _hue = v);
                _applyCustom();
              },
            ),
            _label(tokens, 'Насыщенность'),
            Slider(
              min: 0.2,
              max: 1,
              value: _sat,
              onChanged: (v) {
                setState(() => _sat = v);
                _applyCustom();
              },
            ),
          ],
          _section(tokens, 'Анимации'),
          _Seg(
            tokens: tokens,
            labels: const ['Максимум', 'Сдержанные', 'Минимум'],
            index: ts.animLevel.index,
            onTap: (i) => ctl.setAnimLevel(AnimLevel.values[i]),
          ),
        ],
      ),
    );
  }

  Widget _section(DesignTokens tokens, String t) => Padding(
        padding: EdgeInsets.only(top: tokens.space24, bottom: tokens.space12),
        child: Text(
          t,
          style: tokens.caption.copyWith(
            color: tokens.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _label(DesignTokens tokens, String t) => Padding(
        padding: EdgeInsets.only(left: tokens.space2, top: tokens.space4),
        child: Text(
          t,
          style: tokens.micro.copyWith(color: tokens.textTertiary),
        ),
      );
}

class _BgCard extends StatelessWidget {
  const _BgCard({
    required this.tokens,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final DesignTokens tokens;
  final BgPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: preset.background,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(
            color: selected ? tokens.accent : tokens.separator,
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.bottomLeft,
        padding: EdgeInsets.all(tokens.space8),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: preset.surface2,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
            ),
            SizedBox(width: tokens.space8),
            Expanded(
              child: Text(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.caption.copyWith(color: tokens.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.tokens,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final DesignTokens tokens;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? tokens.accent : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? AppIcon(AppIcons.check, size: 20, color: tokens.accentOn)
            : null,
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.tokens,
    required this.labels,
    required this.index,
    required this.onTap,
  });

  final DesignTokens tokens;
  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(vertical: tokens.space8),
                  decoration: BoxDecoration(
                    color: i == index
                        ? tokens.accent.withValues(alpha: 0.20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                      color: i == index ? tokens.accent : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.caption.copyWith(
                      color: i == index
                          ? tokens.textPrimary
                          : tokens.textSecondary,
                      fontWeight: i == index
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}