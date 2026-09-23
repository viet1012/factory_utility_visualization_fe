import 'package:flutter/material.dart';

import '../../models/signal_health_history_models.dart';
import '../../signal_health_style.dart';
import '../../utils/signal_health_history_utils.dart';

/// PLC register drill-down for a selected box device.
///
/// Columns: PLC Address, Signal Name, Current Value, Previous Value, Delta,
/// Recorded At. No status badge — the hourly history endpoint does not return
/// a status field for signals.
///
/// Receives an already-flattened signal list from [collectSignalsForDevice].
class SignalHealthHistoryDetail extends StatelessWidget {
  final String? boxDeviceId;
  final List<SignalHealthHistorySignal> signals;
  final VoidCallback onClear;

  const SignalHealthHistoryDetail({
    super.key,
    required this.boxDeviceId,
    required this.signals,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 10),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _header() {
    final device = boxDeviceId;

    return Row(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: kBlue.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.list_alt_rounded, color: kBlue, size: 17),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Register Details',
                style: TextStyle(
                  color: kText,
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                device == null
                    ? 'Signals for selected device'
                    : 'Signals for $device  •  ${signals.length} records',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kSubText, fontSize: 11),
              ),
            ],
          ),
        ),
        if (device != null)
          IconButton(
            onPressed: onClear,
            tooltip: 'Clear selection',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, color: kSubText, size: 17),
          ),
      ],
    );
  }

  Widget _body() {
    if (boxDeviceId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Tap a bar in Top Box Devices to inspect its PLC registers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kSubText, fontSize: 12),
          ),
        ),
      );
    }

    if (signals.isEmpty) {
      return const Center(
        child: Text(
          'No register-level records for this device.',
          textAlign: TextAlign.center,
          style: TextStyle(color: kSubText, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HistoryDetailRow(
          isHeader: true,
          plcAddress: 'PLC ADDRESS',
          name: 'SIGNAL NAME',
          currentValue: 'CURRENT',
          previousValue: 'PREVIOUS',
          delta: 'DELTA',
          recordedAt: 'RECORDED AT',
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.separated(
            itemCount: signals.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, thickness: 1, color: kCard2),
            itemBuilder: (context, index) {
              final signal = signals[index];

              return _HistoryDetailRow(
                plcAddress: signal.plcAddress.isEmpty ? '-' : signal.plcAddress,
                name: signal.displayName,
                currentValue: formatSignalValue(signal.currentValue),
                previousValue: formatSignalValue(signal.previousValue),
                delta: formatSignalDelta(signal.delta),
                deltaValue: signal.delta,
                recordedAt: signal.recordedAt == null
                    ? '-'
                    : formatBucketDateHour(signal.recordedAt!),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryDetailRow extends StatelessWidget {
  final String plcAddress;
  final String name;
  final String currentValue;
  final String previousValue;
  final String delta;
  final String recordedAt;
  final bool isHeader;

  /// Drives the delta colour. Null on header rows and when the delta cannot be
  /// computed, both of which render in the neutral text colour.
  final double? deltaValue;

  const _HistoryDetailRow({
    required this.plcAddress,
    required this.name,
    required this.currentValue,
    required this.previousValue,
    required this.delta,
    required this.recordedAt,
    this.deltaValue,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: isHeader ? kSubText : kText,
      fontSize: isHeader ? 10.5 : 12,
      fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
      letterSpacing: isHeader ? .4 : 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 92, child: _cell(plcAddress, style)),
          Expanded(child: _cell(name, style)),
          SizedBox(
            width: 92,
            child: _cell(currentValue, style, align: TextAlign.right),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: _cell(previousValue, style, align: TextAlign.right),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: _cell(
              delta,
              style.copyWith(color: _deltaColor(style.color)),
              align: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: _cell(recordedAt, style, align: TextAlign.right),
          ),
        ],
      ),
    );
  }

  /// Rising values read red, falling green, unchanged/unknown neutral.
  Color? _deltaColor(Color? fallback) {
    final value = deltaValue;

    if (isHeader || value == null || value == 0) return fallback;

    return value > 0 ? kRed : kGreen;
  }

  Widget _cell(String text, TextStyle style, {TextAlign? align}) {
    return Text(
      text,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
