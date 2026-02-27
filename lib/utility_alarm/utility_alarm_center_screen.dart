// lib/utility_dashboard/utility_alarm_center/utility_alarm_center_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'alarm_event.dart';
import 'alarm_provider.dart';

class UtilityAlarmCenterScreen extends StatefulWidget {
  const UtilityAlarmCenterScreen({super.key});

  @override
  State<UtilityAlarmCenterScreen> createState() =>
      _UtilityAlarmCenterScreenState();
}

class _UtilityAlarmCenterScreenState extends State<UtilityAlarmCenterScreen> {
  final _qCtrl = TextEditingController();

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AlarmProvider>(
      builder: (context, p, _) {
        return Column(
          children: [
            _Header(p: p),
            const SizedBox(height: 10),
            _Filters(
              qCtrl: _qCtrl,
              onApply: () {
                p.setFilters(q: _qCtrl.text);
              },
              onClear: () {
                _qCtrl.text = '';
                p.setFilters(facId: null, cate: null, acked: null, q: '');
              },
              onAckedChanged: (v) => p.setFilters(acked: v),
            ),
            const SizedBox(height: 10),
            Expanded(child: _Body(p: p)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final AlarmProvider p;

  const _Header({required this.p});

  @override
  Widget build(BuildContext context) {
    Widget badge(String label, int v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(
        '$label: $v',
        style: TextStyle(
          color: Colors.white.withOpacity(0.90),
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Row(
      children: [
        const Icon(
          Icons.notifications_active_rounded,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Alarm & Event Center',
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        badge('ALARM', p.alarmCount),
        const SizedBox(width: 8),
        badge('WARN', p.warningCount),
        const SizedBox(width: 8),
        badge('OFFLINE', p.offlineCount),
        const SizedBox(width: 10),
        IconButton(
          onPressed: p.fetch,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  final TextEditingController qCtrl;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<bool?> onAckedChanged;

  const _Filters({
    required this.qCtrl,
    required this.onApply,
    required this.onClear,
    required this.onAckedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: qCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search: fac / box / D18 / message...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            onSubmitted: (_) => onApply(),
          ),
        ),
        const SizedBox(width: 10),
        _AckedDropdown(onChanged: onAckedChanged),
        const Spacer(),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          label: const Text('Clear'),
        ),
        const SizedBox(width: 6),
        ElevatedButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.filter_alt_rounded),
          label: const Text('Apply'),
        ),
      ],
    );
  }
}

class _AckedDropdown extends StatefulWidget {
  final ValueChanged<bool?> onChanged;

  const _AckedDropdown({required this.onChanged});

  @override
  State<_AckedDropdown> createState() => _AckedDropdownState();
}

class _AckedDropdownState extends State<_AckedDropdown> {
  bool? _v; // null all, false unacked, true acked

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: DropdownButton<bool?>(
        value: _v,
        dropdownColor: const Color(0xFF1a1a2e),
        underline: const SizedBox.shrink(),
        iconEnabledColor: Colors.white,
        style: const TextStyle(color: Colors.white),
        items: const [
          DropdownMenuItem(value: null, child: Text('All')),
          DropdownMenuItem(value: false, child: Text('Unacked')),
          DropdownMenuItem(value: true, child: Text('Acked')),
        ],
        onChanged: (v) {
          setState(() => _v = v);
          widget.onChanged(v);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AlarmProvider p;

  const _Body({required this.p});

  @override
  Widget build(BuildContext context) {
    if (p.loading && p.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null && p.items.isEmpty) {
      return Center(
        child: Text(
          'API error:\n${p.error}',
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (p.items.isEmpty) {
      return Center(
        child: Text(
          'No alarms/events',
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ),
      );
    }

    return ListView.separated(
      itemCount: p.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = p.items[i];
        return _AlarmCard(
          e: e,
          onAck: e.acked ? null : () => p.ack(e.id),
          onOpen: () => showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF0a0e27),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (_) => _AlarmDetail(e: e),
          ),
        );
      },
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final AlarmEvent e;
  final VoidCallback? onAck;
  final VoidCallback onOpen;

  const _AlarmCard({
    required this.e,
    required this.onAck,
    required this.onOpen,
  });

  Color _sevColor(AlarmSeverity s) {
    switch (s) {
      case AlarmSeverity.alarm:
        return const Color(0xFFEF4444);
      case AlarmSeverity.warning:
        return const Color(0xFFFACC15);
      case AlarmSeverity.offline:
        return const Color(0xFF94A3B8);
      case AlarmSeverity.info:
        return const Color(0xFF60A5FA);
    }
  }

  String _sevText(AlarmSeverity s) {
    switch (s) {
      case AlarmSeverity.alarm:
        return 'ALARM';
      case AlarmSeverity.warning:
        return 'WARNING';
      case AlarmSeverity.offline:
        return 'OFFLINE';
      case AlarmSeverity.info:
        return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _sevColor(e.severity);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 64,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(text: _sevText(e.severity), color: c),
                      _Pill(text: e.facId, color: Colors.white24),
                      _Pill(text: e.cate, color: Colors.white24),
                      _Pill(text: e.plcAddress, color: Colors.white24),
                      if (e.acked) _Pill(text: 'ACKED', color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${e.boxDeviceId}'
                    '${e.value != null ? ' • ${e.value}${e.unit ?? ''}' : ''}'
                    ' • ${_fmtTs(e.ts)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.70)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (onAck != null)
              OutlinedButton.icon(
                onPressed: onAck,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('ACK'),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtTs(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.92),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AlarmDetail extends StatelessWidget {
  final AlarmEvent e;

  const _AlarmDetail({required this.e});

  @override
  Widget build(BuildContext context) {
    Text row(String k, String v) =>
        Text('$k: $v', style: TextStyle(color: Colors.white.withOpacity(0.85)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alarm Detail',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          row('Facility', e.facId),
          row('Category', e.cate),
          row('Box', e.boxDeviceId),
          row('Tag', e.plcAddress),
          row('Time', e.ts.toIso8601String()),
          if (e.value != null) row('Value', '${e.value}${e.unit ?? ''}'),
          row('Message', e.message),
          const SizedBox(height: 12),
          row('ACK', e.acked ? 'Yes' : 'No'),
          if (e.acked) row('AckBy', e.ackBy ?? '-'),
          if (e.acked) row('AckAt', e.ackAt?.toIso8601String() ?? '-'),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}
