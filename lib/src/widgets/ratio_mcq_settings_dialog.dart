import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/edo_ratio.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'settings_dialogs.dart';

const int _minimumEdo = 12;
const int _maximumEdo = 72;
const int _minimumRatioCount = 2;
const int _maximumRatioCount = 10;
const int _maximumRatioComponent = 31;

Future<ChordleSettings?> showRatioMcqSettingsDialog(
  BuildContext context,
  ChordleSettings settings, {
  bool firstRun = false,
}) {
  return showDialog<ChordleSettings>(
    context: context,
    barrierDismissible: !firstRun,
    builder: (context) =>
        _RatioMcqSettingsDialog(settings: settings, firstRun: firstRun),
  );
}

class _RatioMcqSettingsDialog extends StatefulWidget {
  const _RatioMcqSettingsDialog({
    required this.settings,
    required this.firstRun,
  });

  final ChordleSettings settings;
  final bool firstRun;

  @override
  State<_RatioMcqSettingsDialog> createState() =>
      _RatioMcqSettingsDialogState();
}

class _RatioMcqSettingsDialogState extends State<_RatioMcqSettingsDialog> {
  final TextEditingController _numeratorController = TextEditingController();
  final TextEditingController _denominatorController = TextEditingController();

  late Set<int> _edos;
  late bool _jiEnabled;
  late List<String> _ratios;
  late int _optionCount;
  late int _instrumentProgram;
  String? _ratioError;
  String? _settingsError;

  @override
  void initState() {
    super.initState();
    _edos = widget.firstRun
        ? <int>{}
        : widget.settings.ratioMcqEdos
              .where((edo) => edo >= _minimumEdo && edo <= _maximumEdo)
              .toSet();
    _jiEnabled = widget.firstRun ? false : widget.settings.ratioMcqJiEnabled;
    _ratios = widget.firstRun
        ? <String>[]
        : _normalizedStoredRatios(widget.settings.ratioMcqRatios);
    _optionCount = _ratios.length < _minimumRatioCount
        ? _minimumRatioCount
        : widget.settings.ratioMcqOptionCount.clamp(
            _minimumRatioCount,
            _ratios.length,
          );
    _instrumentProgram = widget.settings.instrumentProgram;
  }

  @override
  void dispose() {
    _numeratorController.dispose();
    _denominatorController.dispose();
    super.dispose();
  }

  void _addRatio() {
    final numerator = int.tryParse(_numeratorController.text);
    final denominator = int.tryParse(_denominatorController.text);
    if (numerator == null || denominator == null) {
      setState(() => _ratioError = '请完整输入分子与分母');
      return;
    }
    if (numerator < 1 ||
        numerator > _maximumRatioComponent ||
        denominator < 1 ||
        denominator > _maximumRatioComponent) {
      setState(() => _ratioError = '分子和分母都必须是 1–31 的整数');
      return;
    }
    final normalized = parsePositiveRatio('$numerator/$denominator').label;
    if (_ratios.contains(normalized)) {
      setState(() => _ratioError = '$normalized 已经在备选项中');
      return;
    }
    if (_ratios.length >= _maximumRatioCount) {
      setState(() => _ratioError = '最多只能设置 $_maximumRatioCount 个比例');
      return;
    }
    setState(() {
      _ratios = <String>[..._ratios, normalized];
      _numeratorController.clear();
      _denominatorController.clear();
      _ratioError = null;
      _settingsError = null;
    });
  }

  void _removeRatio(String ratio) {
    if (!widget.firstRun && _ratios.length <= _minimumRatioCount) {
      setState(() => _ratioError = '至少保留 $_minimumRatioCount 个比例');
      return;
    }
    setState(() {
      _ratios = _ratios.where((candidate) => candidate != ratio).toList();
      _optionCount = _ratios.length < _minimumRatioCount
          ? _minimumRatioCount
          : _optionCount.clamp(_minimumRatioCount, _ratios.length);
      _ratioError = null;
    });
  }

  Future<void> _openTuningSelector() async {
    final selection = await showDialog<_TuningSelection>(
      context: context,
      builder: (context) => _TuningSelectorDialog(
        initialEdos: _edos,
        initialJiEnabled: _jiEnabled,
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _edos = selection.edos;
      _jiEnabled = selection.jiEnabled;
      _settingsError = null;
    });
  }

  void _save() {
    if (_edos.isEmpty && !_jiEnabled) {
      setState(() => _settingsError = '请至少选择一种 EDO 调律或 JI');
      return;
    }
    if (_ratios.length < _minimumRatioCount) {
      setState(() => _settingsError = '请至少设置 $_minimumRatioCount 个有理比例');
      return;
    }
    final edos = _edos.toList()..sort();
    Navigator.of(context).pop(
      widget.settings.copyWith(
        ratioMcqEdos: edos,
        ratioMcqJiEnabled: _jiEnabled,
        ratioMcqRatios: List<String>.unmodifiable(_ratios),
        ratioMcqOptionCount: _optionCount.clamp(
          _minimumRatioCount,
          _ratios.length,
        ),
        instrumentProgram: _instrumentProgram,
        ratioMcqConfigured: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tuningCount = _edos.length + (_jiEnabled ? 1 : 0);
    return AlertDialog(
      title: const Text('MCQ of Ratio 设置'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.firstRun) ...[
                const _DialogHint('首次进入请先完成四项设置。保存后会立即按这些范围生成第一题。'),
                const SizedBox(height: 16),
              ],
              _SectionTitle(
                index: 1,
                title: '选取调律',
                trailing: '已选 $tuningCount',
              ),
              const SizedBox(height: 6),
              const _DialogHint('可从 12–72 EDO 与 JI（纯律）中选择任意子集。'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.62),
                  border: Border.all(
                    color: ChordleColors.dialogMuted.withValues(alpha: 0.45),
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _tuningSummary(_edos, _jiEnabled),
                  style: const TextStyle(
                    color: ChordleColors.dialogText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey<String>('ratio-tuning-selector-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ChordleColors.dialogText,
                  side: const BorderSide(color: ChordleColors.dialogMuted),
                ),
                onPressed: _openTuningSelector,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('选择调律集合'),
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                index: 2,
                title: '自定义有理比例',
                trailing: '${_ratios.length}/$_maximumRatioCount',
              ),
              const SizedBox(height: 6),
              const _DialogHint(
                '分子 a 与分母 b 都必须是小于 32 的正整数；约分后相同的比例不能重复。至少 2 个，最多 10 个。',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final ratio in _ratios)
                    InputChip(
                      key: ValueKey<String>('ratio-chip-$ratio'),
                      label: Text(ratio),
                      labelStyle: const TextStyle(
                        color: ChordleColors.dialogText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                      labelPadding: const EdgeInsets.only(left: 4, right: 0),
                      padding: EdgeInsets.zero,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white.withValues(alpha: 0.72),
                      side: BorderSide(
                        color: ChordleColors.dialogMuted.withValues(
                          alpha: 0.45,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      deleteIconColor: ChordleColors.dialogMuted,
                      deleteButtonTooltipMessage: '删除 $ratio',
                      onDeleted:
                          widget.firstRun || _ratios.length > _minimumRatioCount
                          ? () => _removeRatio(ratio)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _RatioEditor(
                numeratorController: _numeratorController,
                denominatorController: _denominatorController,
                canAdd: _ratios.length < _maximumRatioCount,
                onAdd: _addRatio,
              ),
              if (_ratioError case final error?) ...[
                const SizedBox(height: 6),
                Text(error, style: const TextStyle(color: ChordleColors.error)),
              ],
              const SizedBox(height: 22),
              _SectionTitle(
                index: 3,
                title: '设置可选项个数',
                trailing: _ratios.length < _minimumRatioCount
                    ? '待设置'
                    : '$_optionCount 个',
              ),
              const SizedBox(height: 6),
              if (_ratios.length < _minimumRatioCount)
                const _DialogHint('请先设置至少 2 个比例。')
              else ...[
                _DialogHint('可设置为 2–${_ratios.length}，不会超过当前比例总数。'),
                Slider(
                  value: _optionCount.toDouble(),
                  min: _minimumRatioCount.toDouble(),
                  max: _ratios.length.toDouble(),
                  divisions: _ratios.length > _minimumRatioCount
                      ? _ratios.length - _minimumRatioCount
                      : null,
                  label: '$_optionCount',
                  onChanged: (value) =>
                      setState(() => _optionCount = value.round()),
                ),
              ],
              const SizedBox(height: 22),
              _SectionTitle(
                index: 4,
                title: '调整音色',
                trailing: 'Program $_instrumentProgram',
              ),
              const SizedBox(height: 6),
              const _DialogHint('使用 MIDI program number 0–127 选择播放音色。'),
              const SizedBox(height: 8),
              MidiProgramSlider(
                key: const ValueKey<String>('ratio-midi-program-slider'),
                value: _instrumentProgram,
                onChanged: (value) =>
                    setState(() => _instrumentProgram = value),
              ),
              if (_settingsError case final error?) ...[
                const SizedBox(height: 4),
                Text(error, style: const TextStyle(color: ChordleColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: ChordleColors.dialogMuted,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.firstRun ? '返回' : '取消'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: ChordleColors.dialogText,
          ),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.index,
    required this.title,
    required this.trailing,
  });

  final int index;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: ChordleColors.ratioMcq,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(
            color: ChordleColors.dialogMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DialogHint extends StatelessWidget {
  const _DialogHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: ChordleColors.dialogMuted, fontSize: 13.5),
    );
  }
}

class _RatioComponentField extends StatelessWidget {
  const _RatioComponentField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey<String>(
        label == '分子 a' ? 'ratio-numerator-field' : 'ratio-denominator-field',
      ),
      controller: controller,
      keyboardType: TextInputType.number,
      keyboardAppearance: Brightness.light,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: ChordleColors.dialogText,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      cursorColor: ChordleColors.dialogText,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: ChordleColors.dialogMuted,
          fontSize: 12.5,
        ),
        floatingLabelStyle: const TextStyle(
          color: ChordleColors.dialogText,
          fontWeight: FontWeight.w800,
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: ChordleColors.dialogMuted),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: ChordleColors.dialogText, width: 1.8),
        ),
        border: const OutlineInputBorder(),
      ),
      maxLength: 2,
      onSubmitted: (_) => _submitFromField(context),
    );
  }

  void _submitFromField(BuildContext context) {
    final state = context
        .findAncestorStateOfType<_RatioMcqSettingsDialogState>();
    state?._addRatio();
  }
}

class _RatioEditor extends StatelessWidget {
  const _RatioEditor({
    required this.numeratorController,
    required this.denominatorController,
    required this.canAdd,
    required this.onAdd,
  });

  final TextEditingController numeratorController;
  final TextEditingController denominatorController;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final fields = SizedBox(
      width: 176,
      child: Row(
        children: [
          Expanded(
            child: _RatioComponentField(
              controller: numeratorController,
              label: '分子 a',
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '/',
              style: TextStyle(
                color: ChordleColors.dialogText,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: _RatioComponentField(
              controller: denominatorController,
              label: '分母 b',
            ),
          ),
        ],
      ),
    );
    final addButton = SizedBox.square(
      dimension: 42,
      child: IconButton.filled(
        key: const ValueKey<String>('ratio-add-button'),
        tooltip: '增加比例',
        style: IconButton.styleFrom(
          backgroundColor: ChordleColors.ratioMcq,
          foregroundColor: const Color(0xFF172033),
          disabledBackgroundColor: ChordleColors.dialogMuted.withValues(
            alpha: 0.22,
          ),
          disabledForegroundColor: ChordleColors.dialogMuted,
          padding: EdgeInsets.zero,
        ),
        onPressed: canAdd ? onAdd : null,
        icon: const Icon(Icons.add_rounded, size: 24),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [fields, addButton],
      ),
    );
  }
}

final class _TuningSelection {
  _TuningSelection(Set<int> edos, this.jiEnabled)
    : edos = Set<int>.unmodifiable(edos);

  final Set<int> edos;
  final bool jiEnabled;
}

class _TuningSelectorDialog extends StatefulWidget {
  const _TuningSelectorDialog({
    required this.initialEdos,
    required this.initialJiEnabled,
  });

  final Set<int> initialEdos;
  final bool initialJiEnabled;

  @override
  State<_TuningSelectorDialog> createState() => _TuningSelectorDialogState();
}

class _TuningSelectorDialogState extends State<_TuningSelectorDialog> {
  static const Set<int> _commonEdos = <int>{12, 19, 22, 24, 26, 31, 53, 65, 72};
  final ScrollController _scrollController = ScrollController();

  late Set<int> _edos;
  late bool _jiEnabled;

  @override
  void initState() {
    super.initState();
    _edos = Set<int>.of(widget.initialEdos);
    _jiEnabled = widget.initialJiEnabled;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _selectionCount => _edos.length + (_jiEnabled ? 1 : 0);

  void _selectCommon() {
    setState(() {
      _edos = Set<int>.of(_commonEdos);
      _jiEnabled = true;
    });
  }

  void _selectAll() {
    setState(() {
      _edos = <int>{for (var edo = _minimumEdo; edo <= _maximumEdo; edo++) edo};
      _jiEnabled = true;
    });
  }

  void _clear() {
    setState(() {
      _edos.clear();
      _jiEnabled = false;
    });
  }

  void _finish() {
    if (_selectionCount == 0) return;
    Navigator.of(context).pop(_TuningSelection(_edos, _jiEnabled));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialogHeight = (screenHeight * 0.78).clamp(420.0, 680.0).toDouble();
    final textButtonStyle = TextButton.styleFrom(
      foregroundColor: ChordleColors.dialogText,
    );
    return Dialog(
      backgroundColor: ChordleColors.dialogBackground,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          height: dialogHeight,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '选择调律集合',
                        key: ValueKey<String>('ratio-tuning-selector-title'),
                        style: TextStyle(
                          color: ChordleColors.dialogText,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '已选 $_selectionCount',
                      style: const TextStyle(
                        color: ChordleColors.dialogMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      color: ChordleColors.dialogMuted,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    TextButton(
                      style: textButtonStyle,
                      onPressed: _selectCommon,
                      child: const Text('常用组合'),
                    ),
                    TextButton(
                      style: textButtonStyle,
                      onPressed: _selectAll,
                      child: const Text('全选'),
                    ),
                    TextButton(
                      style: textButtonStyle,
                      onPressed: _clear,
                      child: const Text('清空'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: ChordleColors.dialogMuted),
              CheckboxListTile(
                key: const ValueKey<String>('ratio-tuning-ji'),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: ChordleColors.ratioMcq,
                checkColor: const Color(0xFF172033),
                side: const BorderSide(color: ChordleColors.dialogMuted),
                title: const Text(
                  'JI（纯律）',
                  style: TextStyle(
                    color: ChordleColors.dialogText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                value: _jiEnabled,
                onChanged: (value) =>
                    setState(() => _jiEnabled = value ?? false),
              ),
              const Divider(height: 1, color: ChordleColors.dialogMuted),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    key: const ValueKey<String>('ratio-tuning-edo-list'),
                    controller: _scrollController,
                    itemCount: _maximumEdo - _minimumEdo + 1,
                    itemBuilder: (context, index) {
                      final edo = _minimumEdo + index;
                      return CheckboxListTile(
                        key: ValueKey<String>('ratio-tuning-edo-$edo'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: ChordleColors.ratioMcq,
                        checkColor: const Color(0xFF172033),
                        side: const BorderSide(
                          color: ChordleColors.dialogMuted,
                        ),
                        title: Text(
                          '$edo EDO',
                          style: const TextStyle(
                            color: ChordleColors.dialogText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        value: _edos.contains(edo),
                        onChanged: (selected) => setState(() {
                          if (selected ?? false) {
                            _edos.add(edo);
                          } else {
                            _edos.remove(edo);
                          }
                        }),
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 1, color: ChordleColors.dialogMuted),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: textButtonStyle,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ChordleColors.ratioMcq,
                        foregroundColor: const Color(0xFF172033),
                      ),
                      onPressed: _selectionCount == 0 ? null : _finish,
                      child: const Text('应用选择'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _tuningSummary(Set<int> edos, bool jiEnabled) {
  final sorted = edos.toList()..sort();
  if (sorted.length == _maximumEdo - _minimumEdo + 1) {
    return jiEnabled ? '全部 12–72 EDO + JI' : '全部 12–72 EDO';
  }
  if (sorted.isEmpty) return jiEnabled ? '仅 JI（纯律）' : '尚未选择调律';
  final jiSuffix = jiEnabled ? ' + JI' : '';
  if (sorted.length <= 10) {
    return '${sorted.join('、')} EDO$jiSuffix';
  }
  return '已选 ${sorted.length} 个 EDO（范围 ${sorted.first}–${sorted.last}）$jiSuffix';
}

List<String> _normalizedStoredRatios(Iterable<String> ratios) {
  final normalized = <String>[];
  for (final raw in ratios) {
    final match = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s*$').firstMatch(raw);
    if (match == null) continue;
    final numerator = int.tryParse(match.group(1)!);
    final denominator = int.tryParse(match.group(2)!);
    if (numerator == null ||
        denominator == null ||
        numerator < 1 ||
        numerator > _maximumRatioComponent ||
        denominator < 1 ||
        denominator > _maximumRatioComponent) {
      continue;
    }
    final label = parsePositiveRatio('$numerator/$denominator').label;
    if (!normalized.contains(label)) normalized.add(label);
    if (normalized.length == _maximumRatioCount) break;
  }
  return normalized;
}
