import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/cycle_settings.dart';
import '../services/notification_service.dart';

/// Bottom sheet for editing cycle settings, notification preferences,
/// and app language (English / 日本語).
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.coupleId,
    required this.onSave,
  });

  final CycleSettings settings;
  final String coupleId;
  final void Function(CycleSettings) onSave;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late int _cycleLength;
  late int _periodLength;
  late String _partnerName;
  late bool _notificationsEnabled;
  late String _languageCode;
  late int _waterGoalMl;
  late bool _pillReminderEnabled;
  late int _pillReminderHour;
  late int _pillReminderMinute;
  bool _requestingPermission = false;

  @override
  void initState() {
    super.initState();
    _cycleLength = widget.settings.averageCycleLength;
    _periodLength = widget.settings.averagePeriodLength;
    _partnerName = widget.settings.partnerName;
    _notificationsEnabled = widget.settings.notificationsEnabled;
    _languageCode = widget.settings.languageCode;
    _waterGoalMl = widget.settings.dailyWaterGoalMl;
    _pillReminderEnabled = widget.settings.pillReminderEnabled;
    _pillReminderHour = widget.settings.pillReminderHour;
    _pillReminderMinute = widget.settings.pillReminderMinute;
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value && !_notificationsEnabled) {
      setState(() => _requestingPermission = true);
      final granted = await NotificationService.instance.requestPermission();
      setState(() {
        _notificationsEnabled = granted;
        _requestingPermission = false;
      });
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).notificationDenied),
          ),
        );
      }
    } else {
      setState(() => _notificationsEnabled = value);
      if (!value) await NotificationService.instance.cancelAll();
    }
  }

  void _save() {
    widget.onSave(
      widget.settings.copyWith(
        averageCycleLength: _cycleLength,
        averagePeriodLength: _periodLength,
        partnerName: _partnerName,
        notificationsEnabled: _notificationsEnabled,
        languageCode: _languageCode,
        dailyWaterGoalMl: _waterGoalMl,
        pillReminderEnabled: _pillReminderEnabled,
        pillReminderHour: _pillReminderHour,
        pillReminderMinute: _pillReminderMinute,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),

            Text(
              t.settingsTitle,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),

            // Partner name
            Text(
              t.partnerName,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _partnerName),
              onChanged: (v) => _partnerName = v,
              decoration: InputDecoration(
                hintText: t.partnerNameHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Cycle length
            _SliderSetting(
              label: t.avgCycleLength,
              value: _cycleLength,
              min: 18,
              max: 45,
              unit: t.days,
              onChanged: (v) => setState(() => _cycleLength = v),
            ),
            const SizedBox(height: 16),

            // Period length
            _SliderSetting(
              label: t.avgPeriodLength,
              value: _periodLength,
              min: 2,
              max: 10,
              unit: t.days,
              onChanged: (v) => setState(() => _periodLength = v),
            ),
            const SizedBox(height: 24),

            // Language selector
            _LanguageSelector(
              languageCode: _languageCode,
              onChanged: (code) => setState(() => _languageCode = code),
              t: t,
            ),
            const SizedBox(height: 24),

            // Notifications
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.partnerNotifications,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      t.notificationsDesc,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                _requestingPermission
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                      ),
              ],
            ),
            const SizedBox(height: 24),

            // Couple ID share section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.link,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.coupleId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.coupleIdDesc,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.grey.shade300),
                          ),
                          child: Text(
                            widget.coupleId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: widget.coupleId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(t.coupleIdCopied)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FaIcon(
                            FontAwesomeIcons.copy,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Enter partner's ID
                  _EnterPartnerIdField(
                    t: t,
                    onSubmit: (id) async {
                      // TODO: validate and sync with Firestore
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(t.coupleIdUpdated)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Water goal slider
            _SliderSetting(
              label: t.waterGoal,
              value: _waterGoalMl,
              min: 500,
              max: 4000,
              unit: 'ml',
              divisions: 14, // steps of 250 ml
              onChanged: (v) => setState(() => _waterGoalMl = v),
            ),
            const SizedBox(height: 24),

            // Pill reminder toggle
            _PillReminderSection(
              enabled: _pillReminderEnabled,
              hour: _pillReminderHour,
              minute: _pillReminderMinute,
              onToggle: (v) => setState(() => _pillReminderEnabled = v),
              onTimePicked: (h, m) => setState(() {
                _pillReminderHour = h;
                _pillReminderMinute = m;
              }),
              t: t,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(t.saveSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Language selector ─────────────────────────────────────────────────────────

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.languageCode,
    required this.onChanged,
    required this.t,
  });

  final String languageCode;
  final void Function(String) onChanged;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.language,
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _LangChip(
              label: t.languageEnglish,
              selected: languageCode == 'en',
              onTap: () => onChanged('en'),
            ),
            const SizedBox(width: 8),
            _LangChip(
              label: t.languageJapanese,
              selected: languageCode == 'ja',
              onTap: () => onChanged('ja'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const rose = Color(0xFFE11D48);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? rose.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? rose : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? rose : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ── Slider setting ────────────────────────────────────────────────────────────

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.divisions,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final void Function(int) onChanged;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final divs = divisions ?? (max - min);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            Text(
              '$value $unit',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divs,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$min',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
            Text('$max',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }
}

// ── Pill reminder section ─────────────────────────────────────────────────────

class _PillReminderSection extends StatelessWidget {
  const _PillReminderSection({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.onToggle,
    required this.onTimePicked,
    required this.t,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final void Function(bool) onToggle;
  final void Function(int hour, int minute) onTimePicked;
  final AppLocalizations t;

  String _formatTime() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.pillReminder,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  t.pillReminderDesc,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            Switch(value: enabled, onChanged: onToggle),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: hour, minute: minute),
              );
              if (picked != null) {
                onTimePicked(picked.hour, picked.minute);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm, size: 18, color: Color(0xFFE11D48)),
                  const SizedBox(width: 10),
                  Text(
                    t.pillReminderTime,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 18, color: Color(0xFFE11D48)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Enter partner ID field ────────────────────────────────────────────────────

class _EnterPartnerIdField extends StatefulWidget {
  const _EnterPartnerIdField({required this.onSubmit, required this.t});
  final Future<void> Function(String) onSubmit;
  final AppLocalizations t;

  @override
  State<_EnterPartnerIdField> createState() =>
      _EnterPartnerIdFieldState();
}

class _EnterPartnerIdFieldState extends State<_EnterPartnerIdField> {
  final _controller = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) {
      return TextButton.icon(
        icon: const FaIcon(FontAwesomeIcons.userPlus, size: 12),
        label: Text(widget.t.enterPartnerId),
        onPressed: () => setState(() => _show = true),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.t.partnerIdHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () async {
            final id = _controller.text.trim();
            if (id.isEmpty) return;
            await widget.onSubmit(id);
            setState(() => _show = false);
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(widget.t.useButton,
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
