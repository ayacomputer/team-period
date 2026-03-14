import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/cycle_settings.dart';
import '../services/notification_service.dart';

/// Bottom sheet for editing cycle settings and notification preferences.
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
  bool _requestingPermission = false;

  @override
  void initState() {
    super.initState();
    _cycleLength = widget.settings.averageCycleLength;
    _periodLength = widget.settings.averagePeriodLength;
    _partnerName = widget.settings.partnerName;
    _notificationsEnabled = widget.settings.notificationsEnabled;
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
          const SnackBar(
            content: Text('Notification permission denied'),
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
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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

            const Text(
              'Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),

            // Partner name
            const Text(
              'Partner\'s name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _partnerName),
              onChanged: (v) => _partnerName = v,
              decoration: InputDecoration(
                hintText: 'e.g. Alex',
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
              label: 'Average cycle length',
              value: _cycleLength,
              min: 18,
              max: 45,
              unit: 'days',
              onChanged: (v) => setState(() => _cycleLength = v),
            ),
            const SizedBox(height: 16),

            // Period length
            _SliderSetting(
              label: 'Average period length',
              value: _periodLength,
              min: 2,
              max: 10,
              unit: 'days',
              onChanged: (v) => setState(() => _periodLength = v),
            ),
            const SizedBox(height: 24),

            // Notifications
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partner notifications',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'Notify your partner at key phases',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                _requestingPermission
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
                      const Text(
                        'Couple ID',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Share this ID with your partner so you both see the same data.',
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
                            border:
                                Border.all(color: Colors.grey.shade300),
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
                            const SnackBar(
                                content: Text('Couple ID copied')),
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
                    onSubmit: (id) async {
                      // TODO: validate and sync with Firestore
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Couple ID updated — reload to sync')),
                      );
                    },
                  ),
                ],
              ),
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
                child: const Text('Save settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
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
          divisions: max - min,
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

class _EnterPartnerIdField extends StatefulWidget {
  const _EnterPartnerIdField({required this.onSubmit});
  final Future<void> Function(String) onSubmit;

  @override
  State<_EnterPartnerIdField> createState() => _EnterPartnerIdFieldState();
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
        label: const Text('Enter partner\'s ID'),
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
              hintText: 'Paste partner\'s Couple ID',
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Use', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
