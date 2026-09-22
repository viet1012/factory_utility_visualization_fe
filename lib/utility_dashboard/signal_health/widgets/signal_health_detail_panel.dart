import 'package:flutter/material.dart';

import '../signal_health_style.dart';
import '../utils/signal_health_utils.dart';
import 'signal_health_common_widgets.dart';

class SignalHealthDetailPanel extends StatefulWidget {
  final Map<String, dynamic> device;

  const SignalHealthDetailPanel({super.key, required this.device});

  @override
  State<SignalHealthDetailPanel> createState() =>
      _SignalHealthDetailPanelState();
}

class _SignalHealthDetailPanelState extends State<SignalHealthDetailPanel> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawSignals = widget.device['signals'];
    final signals = rawSignals is List
        ? rawSignals
              .whereType<Map>()
              .map((signal) => Map<String, dynamic>.from(signal))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final issueSignals = signals.where(isSignalNg).toList(growable: false);
    final normalSignals = signals
        .where((signal) => !isSignalNg(signal))
        .toList(growable: false);

    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Register Details',
                style: TextStyle(
                  color: kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${signals.length} signals',
                style: const TextStyle(
                  color: kSubText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll(Color(0xff00E5FF)),
                trackColor: WidgetStatePropertyAll(Color(0xff1e293b)),
                trackBorderColor: WidgetStatePropertyAll(Color(0xff38bdf8)),
                thickness: const WidgetStatePropertyAll(4),
                radius: Radius.circular(3),
              ),
              child: Scrollbar(
                controller: _controller,
                trackVisibility: true,
                thumbVisibility: true,
                interactive: true,
                radius: const Radius.circular(12),
                child: ListView(
                  controller: _controller,
                  children: [
                    _SignalGroupHeader(
                      title: 'ISSUES',
                      count: issueSignals.length,
                      color: kRed,
                    ),
                    ...issueSignals.map(
                      (signal) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _SignalMetricCard(signal: signal),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SignalGroupHeader(
                      title: 'NORMAL',
                      count: normalSignals.length,
                      color: kGreen,
                    ),
                    ...normalSignals.map(
                      (signal) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _SignalMetricCard(signal: signal),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SignalGroupHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: color.withValues(alpha: .35), height: 1),
          ),
        ],
      ),
    );
  }
}

class _SignalMetricCard extends StatelessWidget {
  final Map<String, dynamic> signal;

  const _SignalMetricCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final status = '${signal['status']}';
    final isNg = isSignalNg(signal);
    // Issue cards carry a left accent bar instead of a full orange outline;
    // normal cards stay near-neutral so ISSUES dominates the column.
    final borderColor = !isNg
        ? kBorder.withValues(alpha: .45)
        : kOrange.withValues(alpha: .30);
    final bgColor = !isNg
        ? kCard2.withValues(alpha: .45)
        : kOrange.withValues(alpha: .07);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar: severity cue for issue cards without wrapping
            // the whole card in a loud orange outline.
            if (isNg) Container(width: 3, color: kOrange),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(isNg ? 9 : 8, 8, 8, 8),
                child: _content(isNg, status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(bool isNg, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              !isNg ? Icons.check_circle : Icons.warning_amber_rounded,
              color: !isNg ? kGreen : kOrange,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${signal['signalName']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kText,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  if ((signal['unit'] ?? '').toString().isNotEmpty)
                    Text(
                      'Unit: ${signal['unit']}',
                      style: const TextStyle(
                        color: kSubText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            StatusBadge(status, isNg: isNg),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _MetaChip('PLC', '${signal['plcAddress']}'),
            const Spacer(),
            Text(
              _formatTime('${signal['recordedAt']}'),
              style: const TextStyle(
                color: kSubText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ValueBox(
                label: 'PREV',
                value:
                    '${signal['prevValue'] ?? '-'} '
                    '${signal['unit'] ?? ''}',
                color: kText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ValueBox(
                label: 'CURRENT',
                value:
                    '${signal['currentValue'] ?? '-'} '
                    '${signal['unit'] ?? ''}',
                color: !isNg ? kGreen : kRed,
                highlight: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ValueBox(
                label: 'JUMP',
                value: '${signal['jumpSize']}',
                color: _jumpColor(signal['jumpSize']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Text(
            '${signal['description']}',
            style: TextStyle(
              color: !isNg ? kSubText : const Color(0xffffd28a),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static Color _jumpColor(dynamic value) {
    final number = num.tryParse('$value') ?? 0;
    if (number == 0) return kSubText;
    if (number > 1000) return kRed;
    return kOrange;
  }

  static String _formatTime(String value) {
    if (value.length >= 19) {
      return value.substring(0, 19).replaceFirst('T', ' ');
    }
    return value;
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: kSubText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _ValueBox({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    // CURRENT (highlight) keeps full contrast; PREV/JUMP recede so the live
    // value is the strongest element in the card.
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? .16 : .06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: highlight ? .38 : .18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: highlight ? .9 : .6),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ? color : color.withValues(alpha: .75),
              fontSize: highlight ? 21 : 17,
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
