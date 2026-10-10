import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tournament_model.dart';
import '../../services/tournament_service.dart';
import '../../utils/toast_helper.dart';

class DamaTournamentModal extends StatefulWidget {
  final TournamentModel? tournamentToEdit;

  const DamaTournamentModal({super.key, this.tournamentToEdit});

  static Future<void> show(BuildContext context, {TournamentModel? tournamentToEdit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DamaTournamentModal(tournamentToEdit: tournamentToEdit),
    );
  }

  @override
  State<DamaTournamentModal> createState() => _DamaTournamentModalState();
}

class _DamaTournamentModalState extends State<DamaTournamentModal> {
  final TournamentService _tournamentService = TournamentService();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _formatCtrl;
  late TextEditingController _winnerExpCtrl;
  late TextEditingController _runnerUpExpCtrl;
  late TextEditingController _participantExpCtrl;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  int _durationMinutes = 15;
  TournamentStatus _status = TournamentStatus.upcoming;

  final List<String> _formatPresets = [
    'Single Elimination Blitz',
    'Swiss Round-Robin',
    'Grandmaster Knockout',
    'Speed Checkers Championship',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.tournamentToEdit;
    _titleCtrl = TextEditingController(text: t?.title ?? 'Grand Scholar Dama Championship');
    _descCtrl = TextEditingController(text: t?.description ?? '8x8 Dama tournament battle! Crown your kings, execute flying jumps, and take the championship cup.');
    _formatCtrl = TextEditingController(text: t?.topic ?? 'Single Elimination Blitz');
    _winnerExpCtrl = TextEditingController(text: '${t?.winnerExpReward ?? 1500}');
    _runnerUpExpCtrl = TextEditingController(text: '${t?.runnerUpExpReward ?? 700}');
    _participantExpCtrl = TextEditingController(text: '${t?.participantExpReward ?? 200}');

    final start = t?.startDateTime ?? DateTime.now().add(const Duration(hours: 2));
    _selectedDate = DateTime(start.year, start.month, start.day);
    _selectedTime = TimeOfDay(hour: start.hour, minute: start.minute);
    _durationMinutes = t?.durationMinutes ?? 15;
    _status = t?.status ?? TournamentStatus.upcoming;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _formatCtrl.dispose();
    _winnerExpCtrl.dispose();
    _runnerUpExpCtrl.dispose();
    _participantExpCtrl.dispose();
    super.dispose();
  }

  DateTime get _computedStartDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _handleSaveTournament() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final format = _formatCtrl.text.trim();
    final winnerExp = int.tryParse(_winnerExpCtrl.text.trim()) ?? 1500;
    final runnerUpExp = int.tryParse(_runnerUpExpCtrl.text.trim()) ?? 700;
    final participantExp = int.tryParse(_participantExpCtrl.text.trim()) ?? 200;

    if (title.isEmpty) {
      showErrorToast(context, 'Please enter a Dama tournament title.');
      return;
    }

    final tournament = (widget.tournamentToEdit ?? TournamentModel(
      title: title,
      topic: format,
      startDateTime: _computedStartDateTime,
      gameType: 'dama',
    )).copyWith(
      title: title,
      description: desc,
      topic: format,
      startDateTime: _computedStartDateTime,
      durationMinutes: _durationMinutes,
      winnerExpReward: winnerExp,
      runnerUpExpReward: runnerUpExp,
      participantExpReward: participantExp,
      status: _status,
      teamSize: 1,
      gameType: 'dama',
    );

    await _tournamentService.saveDamaTournament(tournament);

    if (mounted) {
      showSuccessToast(context, 'Scholar Dama Tournament scheduled successfully!');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.grid_4x4_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Schedule Dama Tournament',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Configure 8x8 Board Tournament & EXP Rewards',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              children: [
                // Title
                _buildSectionHeader('Dama Tournament Title'),
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tournament Title',
                    prefixIcon: const Icon(Icons.emoji_events_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Tournament Rules & Format Notes',
                    prefixIcon: const Icon(Icons.description_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),

                // Tournament Format
                _buildSectionHeader('Competition Format'),
                TextField(
                  controller: _formatCtrl,
                  decoration: InputDecoration(
                    labelText: 'Format Preset',
                    prefixIcon: const Icon(Icons.tune_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _formatPresets.map((fmt) {
                    final isSelected = _formatCtrl.text == fmt;
                    return ChoiceChip(
                      label: Text(fmt, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _formatCtrl.text = fmt);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Date & Time
                _buildSectionHeader('Match Schedule (Start Date & Time)'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(DateFormat('EEE, MMM d, yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        onPressed: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        onPressed: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Match Duration
                _buildSectionHeader('Round Duration'),
                Wrap(
                  spacing: 8,
                  children: [10, 15, 20, 30].map((mins) {
                    final isSelected = _durationMinutes == mins;
                    return ChoiceChip(
                      label: Text('$mins Minutes', style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _durationMinutes = mins);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // EXP Rewards
                _buildSectionHeader('Scholar EXP Rewards (Tiered)'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _winnerExpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '🏆 1st Place',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _runnerUpExpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '🥈 2nd Place',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _participantExpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '🎖️ 3rd Place',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Status
                _buildSectionHeader('Tournament Status'),
                DropdownButton<TournamentStatus>(
                  value: _status,
                  items: TournamentStatus.values.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save & Schedule Dama Tournament', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    onPressed: _handleSaveTournament,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }
}
