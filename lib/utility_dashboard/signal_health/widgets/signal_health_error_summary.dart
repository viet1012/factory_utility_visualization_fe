import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/scada_tab_button.dart';
import '../models/signal_health_view_models.dart';
import '../signal_health_style.dart';

class SignalHealthErrorSummary extends StatefulWidget {
  final List<ErrorSummaryItem> items;
  final List<BoxIssueItem> boxItems;
  final String? selectedErrorKey;
  final String? selectedBoxDeviceId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onBoxSelected;
  final VoidCallback onClear;

  const SignalHealthErrorSummary({
    super.key,
    required this.items,
    required this.boxItems,
    required this.selectedErrorKey,
    required this.selectedBoxDeviceId,
    required this.onSelected,
    required this.onBoxSelected,
    required this.onClear,
  });
  @override
  State<SignalHealthErrorSummary> createState() =>
      _SignalHealthErrorSummaryState();
}

class _SignalHealthErrorSummaryState extends State<SignalHealthErrorSummary> {
  final ScrollController _errorScrollController = ScrollController();
  final ScrollController _boxScrollController = ScrollController();

  @override
  void didUpdateWidget(covariant SignalHealthErrorSummary oldWidget) {
    super.didUpdateWidget(oldWidget);

    final boxDeviceId = widget.selectedBoxDeviceId;
    if (boxDeviceId == null ||
        boxDeviceId == oldWidget.selectedBoxDeviceId ||
        widget.boxItems.isEmpty) {
      return;
    }

    _scrollSelectedBoxIntoView(boxDeviceId);
  }

  /// Brings the selected box chip into the visible part of the BOX WITH ISSUES
  /// row after a selection made elsewhere (e.g. a Device Table row click).
  ///
  /// Chip widths vary, so the target is approximated proportionally from the
  /// item's index rather than measured - close enough to reveal the chip.
  void _scrollSelectedBoxIntoView(String boxDeviceId) {
    final index = widget.boxItems.indexWhere(
      (item) => item.boxDeviceId == boxDeviceId,
    );
    if (index < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_boxScrollController.hasClients) return;

      final position = _boxScrollController.position;
      final maxScroll = position.maxScrollExtent;
      // Nothing to reveal when every chip already fits on screen.
      if (maxScroll <= 0) return;

      final lastIndex = widget.boxItems.length - 1;
      final ratio = lastIndex <= 0 ? 0.0 : index / lastIndex;

      _boxScrollController.animateTo(
        (ratio * maxScroll).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _errorScrollController.dispose();
    _boxScrollController.dispose();
    super.dispose();
  }

  Widget _emptyRow(String message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: const TextStyle(color: kSubText, fontSize: 11),
      ),
    );
  }

  Widget _chipRow({
    required ScrollController controller,
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return ScrollbarTheme(
      data: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Color(0xff00E5FF)),
        trackColor: WidgetStatePropertyAll(Color(0xff1e293b)),
        trackBorderColor: WidgetStatePropertyAll(Color(0xff38bdf8)),
        thickness: WidgetStatePropertyAll(4),
        radius: Radius.circular(10),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: ScrollConfiguration(
          // Flutter leaves the mouse out of dragDevices by default, so on web
          // and desktop these chip rows could not be panned by pointer drag.
          // Scoped to this row only; app-wide scroll behavior is untouched.
          // scrollbars: false keeps this from adding a second, unthemed bar
          // over the styled Scrollbar above.
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 2),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => itemBuilder(index),
          ),
        ),
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required int count,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required double minWidth,
    required double maxWidth,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            // Unselected chips stay neutral; the accent appears only on the
            // active quick filter.
            color: isSelected ? kRed.withValues(alpha: .12) : kCard2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? kRed : kBorder.withValues(alpha: .55),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? kRed : kSubText.withValues(alpha: .8),
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? kText : kSubText,
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Container(width: 1, height: 15, color: kBorder),
              const SizedBox(width: 9),
              Text(
                '$count',
                style: const TextStyle(
                  color: kRed,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
      decoration: BoxDecoration(
        // Neutral ribbon container: red is reserved for the icon, the counts
        // and the active filter, not for the panel chrome itself.
        color: kCard.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ERROR SUMMARY — CURRENT FILTER',
                  style: TextStyle(
                    color: kSubText,
                    fontSize: 11,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),
              ),

              if (widget.selectedErrorKey != null ||
                  widget.selectedBoxDeviceId != null)
                ScadaTabButton(
                  label: 'CLEAR',
                  selected: true,
                  color: kRed,
                  minWidth: 58,
                  height: 26,
                  onTap: widget.onClear,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: widget.items.isEmpty
                ? _emptyRow('No abnormal signals in the current filter.')
                : _chipRow(
                    controller: _errorScrollController,
                    itemCount: widget.items.length,
                    itemBuilder: (index) {
                      final item = widget.items[index];
                      final isSelected =
                          item.errorKey == widget.selectedErrorKey;
                      return _summaryChip(
                        label: item.signalName,
                        count: item.deviceCount,
                        isSelected: isSelected,
                        icon: isSelected
                            ? Icons.filter_alt_rounded
                            : Icons.warning_amber_rounded,
                        minWidth: 160,
                        maxWidth: 260,
                        onTap: () => widget.onSelected(item.errorKey),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: widget.boxItems.isEmpty
                ? _emptyRow('No box device with issues in the current filter.')
                : _chipRow(
                    controller: _boxScrollController,
                    itemCount: widget.boxItems.length,
                    itemBuilder: (index) {
                      final item = widget.boxItems[index];
                      final isSelected =
                          item.boxDeviceId == widget.selectedBoxDeviceId;
                      return _summaryChip(
                        label: item.boxDeviceId,
                        count: item.issueCount,
                        isSelected: isSelected,
                        icon: isSelected
                            ? Icons.check_circle_rounded
                            : Icons.developer_board_rounded,
                        minWidth: 140,
                        maxWidth: 240,
                        onTap: () => widget.onBoxSelected(item.boxDeviceId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
