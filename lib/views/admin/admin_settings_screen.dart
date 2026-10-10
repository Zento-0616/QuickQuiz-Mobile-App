import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../models/admin_settings_model.dart';
import '../../utils/toast_helper.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _capCtrl = TextEditingController();
  bool _repeatQuizExp = false;
  Map<int, int> _dailyExpCaps = {
    1: 500,
    2: 500,
    3: 500,
    4: 500,
    5: 500,
    6: 500,
    7: 500,
  };
  int _selectedDay = DateTime.now().weekday;
  bool _isLoading = true;
  bool _isSaving = false;

  static const _dayNames = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  static const _fullDayNames = {
    1: 'Monday (Day 1)',
    2: 'Tuesday (Day 2)',
    3: 'Wednesday (Day 3)',
    4: 'Thursday (Day 4)',
    5: 'Friday (Day 5)',
    6: 'Saturday (Day 6)',
    7: 'Sunday (Day 7)',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await AdminSettingsModel.loadSettings();
    if (mounted) {
      setState(() {
        _repeatQuizExp = settings.repeatQuizExpEnabled;
        _dailyExpCaps = Map<int, int>.from(settings.dailyExpCaps);
        _capCtrl.text = (_dailyExpCaps[_selectedDay] ?? 500).toString();
        _isLoading = false;
      });
    }
  }

  void _switchSelectedDay(int day) {
    final currentVal = int.tryParse(_capCtrl.text.trim()) ?? (_dailyExpCaps[_selectedDay] ?? 500);
    _dailyExpCaps[_selectedDay] = currentVal;
    setState(() {
      _selectedDay = day;
      _capCtrl.text = (_dailyExpCaps[day] ?? 500).toString();
    });
  }

  void _applyToAllDays() {
    final val = int.tryParse(_capCtrl.text.trim()) ?? 500;
    setState(() {
      for (int d = 1; d <= 7; d++) {
        _dailyExpCaps[d] = val;
      }
    });
    showSuccessToast(context, 'Set all 7 days to $val EXP cap.');
  }

  @override
  void dispose() {
    _capCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final parsedCap = int.tryParse(_capCtrl.text.trim()) ?? (_dailyExpCaps[_selectedDay] ?? 500);
    if (parsedCap < 0) {
      showWarningToast(context, 'Daily EXP Cap cannot be negative');
      return;
    }
    _dailyExpCaps[_selectedDay] = parsedCap;

    setState(() => _isSaving = true);
    final newSettings = AdminSettingsModel(
      repeatQuizExpEnabled: _repeatQuizExp,
      dailyExpCaps: _dailyExpCaps,
      dailyLoginRewards: _dailyExpCaps,
    );

    await newSettings.saveSettings();

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      showSuccessToast(context, 'Daily Scholar EXP Caps updated & synced!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.speed_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Scholar EXP Cap',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set custom daily EXP caps and daily calendar rewards for Monday through Sunday. Synchronizes directly to all scholar phones & reward calendars.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 360;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: isCompact ? 0.65 : 0.85,
                        crossAxisSpacing: isCompact ? 6 : 8,
                        mainAxisSpacing: isCompact ? 6 : 8,
                      ),
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final dayNumber = index + 1;
                        final isToday = dayNumber == DateTime.now().weekday;
                        final isSel = _selectedDay == dayNumber;
                        final cap = _dailyExpCaps[dayNumber] ?? 500;

                        return InkWell(
                          onTap: () => _switchSelectedDay(dayNumber),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppTheme.primaryColor.withValues(alpha: 0.18)
                                  : (isToday
                                      ? Colors.amber.withValues(alpha: 0.10)
                                      : Theme.of(context).cardTheme.color),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSel
                                    ? AppTheme.primaryColor
                                    : (isToday
                                        ? Colors.amber
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                                width: isSel ? 2 : (isToday ? 1.5 : 1),
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Day $dayNumber',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isSel
                                            ? AppTheme.primaryColor
                                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    Text(
                                      '${_dayNames[dayNumber]}${isToday ? " (Today)" : ""}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isSel
                                            ? AppTheme.primaryColor
                                            : (isToday ? Colors.amber.shade700 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Icon(
                                      isSel
                                          ? Icons.stars_rounded
                                          : (isToday ? Icons.bolt_rounded : Icons.star_rounded),
                                      color: isSel
                                          ? AppTheme.primaryColor
                                          : (isToday ? Colors.amber : Colors.amber.shade400),
                                      size: 22,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '+${cap == 0 ? "∞" : "$cap"} EXP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11.5,
                                        color: isSel ? AppTheme.primaryColor : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Editing: ${_fullDayNames[_selectedDay]}${_selectedDay == DateTime.now().weekday ? " (TODAY)" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryColor),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.copy_all_rounded, size: 15),
                      label: const Text('Apply to All 7 Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                      onPressed: _applyToAllDays,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _capCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (val) {
                    final v = int.tryParse(val.trim());
                    if (v != null) {
                      setState(() {
                        _dailyExpCaps[_selectedDay] = v;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: '${_dayNames[_selectedDay]} EXP Cap & Daily Reward (0 = Unlimited)',
                    hintText: 'e.g. 500',
                    suffixText: 'EXP',
                    prefixIcon: const Icon(Icons.bolt_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip(300),
                    _buildPresetChip(500),
                    _buildPresetChip(1000),
                    _buildPresetChip(2000),
                    _buildPresetChip(0, label: 'Unlimited (0)'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving EXP Caps...' : 'Save Daily Scholar EXP Caps',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(int value, {String? label}) {
    final currentVal = int.tryParse(_capCtrl.text.trim()) ?? -1;
    final isSelected = currentVal == value;

    return ChoiceChip(
      label: Text(label ?? '$value EXP'),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _capCtrl.text = value.toString();
          _dailyExpCaps[_selectedDay] = value;
        });
      },
    );
  }
}
