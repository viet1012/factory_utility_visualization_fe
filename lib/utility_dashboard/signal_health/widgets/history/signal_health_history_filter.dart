import 'package:flutter/material.dart';

import '../../models/signal_health_history_models.dart';
import '../../signal_health_style.dart';
import '../../utils/signal_health_history_utils.dart';

/// Filter bar for HISTORY mode: date range plus the four facet dropdowns.
///
/// Purely presentational. It never mutates the filter itself — every change is
/// handed to [onChanged] as a complete [SignalHealthHistoryFilter] so the
/// controller remains the single source of truth.
class SignalHealthHistoryFilterBar extends StatelessWidget {
  final SignalHealthHistoryFilter filter;

  final List<String> facOptions;
  final List<String> cateOptions;
  final List<String> scadaOptions;
  final List<String> boxDeviceOptions;

  final ValueChanged<SignalHealthHistoryFilter> onChanged;
  final VoidCallback onRefresh;

  final bool busy;

  const SignalHealthHistoryFilterBar({
    super.key,
    required this.filter,
    required this.facOptions,
    required this.cateOptions,
    required this.scadaOptions,
    required this.boxDeviceOptions,
    required this.onChanged,
    required this.onRefresh,
    this.busy = false,
  });

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: filter.from,
        // showDateRangePicker treats the range as inclusive dates; subtract a
        // second so an exclusive `to` at midnight does not select an extra day.
        end: filter.to.subtract(const Duration(seconds: 1)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.brightnessOf(context) == Brightness.dark
              ? ThemeData.dark()
              : ThemeData.light(),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;

    /*
     * Chuan hoa ve bien gio: from = 00:00 ngay bat dau,
     * to = 00:00 ngay ke tiep cua ngay ket thuc (exclusive),
     * de khop voi bucket theo gio cua backend.
     */
    final from = DateTime(
      picked.start.year,
      picked.start.month,
      picked.start.day,
    );

    final endDay = DateTime(picked.end.year, picked.end.month, picked.end.day);

    final to = endDay.add(const Duration(days: 1));

    onChanged(filter.copyWith(from: from, to: to));
  }

  void _applyPreset(Duration span) {
    final now = DateTime.now();

    final to = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(const Duration(hours: 1));

    onChanged(filter.copyWith(from: to.subtract(span), to: to));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _RangeButton(
                label:
                    '${formatFilterDateTime(filter.from)}'
                    '  →  '
                    '${formatFilterDateTime(filter.to)}',
                onTap: () => _pickRange(context),
              ),
            ),
            const SizedBox(width: 10),
            _PresetButton(
              label: '24h',
              onTap: () => _applyPreset(const Duration(hours: 24)),
            ),
            const SizedBox(width: 6),
            _PresetButton(
              label: '7d',
              onTap: () => _applyPreset(const Duration(days: 7)),
            ),
            const SizedBox(width: 6),
            _PresetButton(
              label: '30d',
              onTap: () => _applyPreset(const Duration(days: 30)),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRefresh,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kBlue,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 17),
                label: Text(
                  busy ? 'Loading...' : 'Refresh',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBlue,
                  disabledForegroundColor: kBlue.withValues(alpha: .55),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: BorderSide(color: kBlue.withValues(alpha: .45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _FacetDropdown(
              hint: 'Facility',
              value: filter.fac,
              items: facOptions,
              onChanged: (value) {
                onChanged(filter.copyWith(fac: value, clearFac: value == null));
              },
            ),
            const SizedBox(width: 12),
            _FacetDropdown(
              hint: 'Category',
              value: filter.cate,
              items: cateOptions,
              onChanged: (value) {
                onChanged(
                  filter.copyWith(cate: value, clearCate: value == null),
                );
              },
            ),
            const SizedBox(width: 12),
            _FacetDropdown(
              hint: 'SCADA',
              value: filter.scadaId,
              items: scadaOptions,
              onChanged: (value) {
                onChanged(
                  filter.copyWith(scadaId: value, clearScadaId: value == null),
                );
              },
            ),
            const SizedBox(width: 12),
            _FacetDropdown(
              hint: 'Device',
              value: filter.boxDeviceId,
              items: boxDeviceOptions,
              width: 240,
              onChanged: (value) {
                onChanged(
                  filter.copyWith(
                    boxDeviceId: value,
                    clearBoxDeviceId: value == null,
                  ),
                );
              },
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}

class _RangeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RangeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kCard,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, color: kSubText, size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: kSubText,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: const BorderSide(color: kBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Dropdown whose "All" entry maps to a null filter value rather than the
/// literal string 'ALL', so the API layer can omit the parameter entirely.
class _FacetDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final double width;

  const _FacetDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    // A stale selection (device vanished from the new range) must not be passed
    // to DropdownButton, which asserts on a value missing from its items.
    final safeValue = (value != null && items.contains(value)) ? value : null;

    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: safeValue,
          hint: Text(
            hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kSubText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          dropdownColor: kCard,
          iconEnabledColor: kText,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'All $hint',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kSubText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
