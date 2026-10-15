import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/widgets/chart_loading_widgets.dart';
import '../shared/widgets/chart_state_widgets.dart';
import '../shared/widgets/debounced_layout_builder.dart';
import 'controllers/water_check_controller.dart';
import 'models/water_check_models.dart';
import 'widgets/water_check_format.dart';
import 'widgets/water_check_header.dart';
import 'widgets/water_facility_column.dart';
import 'widgets/water_issue_card.dart';
import 'widgets/water_layout.dart';
import 'widgets/water_signal_chart_dialog.dart';

/// Tab WATER CHECK: tong quan diem do nuoc cua 3 xuong (bo cuc laptop
/// >= 1280px). Polling do dashboard dang ky (scope [PollingScope.waterCheck]).
class WaterCheckScreen extends StatefulWidget {
  final WaterCheckController controller;

  /// Chuyen sang CHARTS › Minutes voi dung fac / box / device.
  final void Function(WaterSignalRef signal) onOpenInCharts;

  /// Dang full screen (dashboard an thanh tab + fullscreen trinh duyet).
  final bool fullScreen;
  final VoidCallback? onToggleFullScreen;

  const WaterCheckScreen({
    super.key,
    required this.controller,
    required this.onOpenInCharts,
    this.fullScreen = false,
    this.onToggleFullScreen,
  });

  @override
  State<WaterCheckScreen> createState() => _WaterCheckScreenState();
}

class _WaterCheckScreenState extends State<WaterCheckScreen> {
  static const Duration _flashDuration = Duration(milliseconds: 1500);

  /// Loc theo trang thai (null = hien tat ca).
  WaterStatus? _filter;

  /// Key widget cua tung diem do (cuon toi tu "To check").
  final Map<String, GlobalKey> _signalKeys = {};

  String? _flashKey;
  int _flashToken = 0;
  Timer? _flashTimer;

  /// Index theo khoa diem do, tinh lai khi response doi.
  WaterCheckResponse? _indexed;
  Map<String, ({WaterSignal signal, WaterGroup group})> _index = const {};

  /// Bo cuc: chi tinh lai khi kich thuoc vung noi dung (da debounce), chu ky
  /// du lieu (so diem do / nhom) hoac chieu cao phan tren doi; khong tinh
  /// moi lan polling.
  WaterLayoutPlan _plan = WaterLayoutPlan.fallback;
  String? _planKey;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _reindex(WaterCheckResponse data) {
    if (identical(_indexed, data)) return;
    _indexed = data;

    _index = {
      for (final fac in data.facilities)
        for (final group in fac.groups)
          for (final signal in group.signals)
            waterSignalKey(fac.facId, signal.boxDeviceId, signal.plcAddress): (
              signal: signal,
              group: group,
            ),
    };
    _signalKeys.removeWhere((key, _) => !_index.containsKey(key));
  }

  /// [top]: chieu cao chua scale cua banner + header + To check + khoang
  /// cach; phan tren scale theo clamp(s, 1.0, 1.3) nen tru theo s.
  WaterLayoutPlan _planFor(WaterCheckResponse data, Size area, double top) {
    final key =
        '${waterLayoutSignature(data.facilities)}#$area#'
        '${top.toStringAsFixed(1)}';
    if (key == _planKey) return _plan;

    _planKey = key;
    _plan = planWaterLayout(
      data.facilities,
      area,
      reservedHeight: (scale) => top * scale.clamp(1.0, 1.3),
    );
    debugPrint(
      'WaterCheck layout ${area.width.round()}×${area.height.round()}: '
      '$_plan',
    );
    return _plan;
  }

  /// Chieu cao chua scale cua phan tren (khop voi [_buildTop]).
  static double _topHeight(WaterCheckResponse data, bool hasError) {
    final issues = data.issues.length;
    final card = issues == 0
        ? 32.0
        : math.min(issues, WaterIssueCard.maxRows) * WaterIssueCard.rowHeight +
              10;

    return (hasError ? _ErrorBanner.height : 0) +
        WaterCheckHeader.height +
        6 +
        card +
        8;
  }

  GlobalKey _keyOf(String signalKey) {
    return _signalKeys.putIfAbsent(signalKey, GlobalKey.new);
  }

  void _toggleFilter(WaterStatus status) {
    setState(() => _filter = _filter == status ? null : status);
  }

  void _focusIssue(WaterIssue issue) {
    final key = waterSignalKey(
      issue.facId,
      issue.boxDeviceId,
      issue.plcAddress,
    );
    final entry = _index[key];

    // Diem do bi bo loc an: bo loc truoc khi cuon.
    if (_filter != null && entry != null && entry.signal.status != _filter) {
      setState(() => _filter = null);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final target = _signalKeys[key]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .3,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }

      _flashTimer?.cancel();
      setState(() {
        _flashKey = key;
        _flashToken++;
      });
      _flashTimer = Timer(_flashDuration, () {
        if (mounted) setState(() => _flashKey = null);
      });
    });
  }

  void _openSignal(WaterSignalRef signal) {
    showWaterSignalChartDialog(
      context,
      signal: signal,
      onOpenInCharts: widget.onOpenInCharts,
    );
  }

  void _openIssue(WaterIssue issue) {
    final entry =
        _index[waterSignalKey(
          issue.facId,
          issue.boxDeviceId,
          issue.plcAddress,
        )];

    _openSignal(
      WaterSignalRef(
        facId: issue.facId,
        boxDeviceId: issue.boxDeviceId,
        plcAddress: issue.plcAddress,
        name: issue.name,
        deviceName: entry?.signal.deviceName ?? '',
        unit: issue.unit,
      ),
    );
  }

  /// Dashboard tu ve nen toi trong khi theme app la sang: hinh / chu cua tab
  /// doc mau tu theme toi nay (doi sang theme sang chi can doi o day).
  static ThemeData _themeOf(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: kWaterAccent,
            brightness: Brightness.dark,
          ).copyWith(
            onSurface: const Color(0xFFE2E8F0),
            onSurfaceVariant: const Color(0xFF94A3B8),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: _themeOf(context), child: _buildBody());
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final data = controller.data;

        if (data == null) {
          if (controller.error != null && !controller.loading) {
            return ChartApiErrorState(
              onRetry: controller.retry,
              title: 'Unable to load water check',
            );
          }
          return const _WaterCheckSkeleton();
        }

        _reindex(data);

        final hasError = controller.error != null;
        final top = _topHeight(data, hasError);

        return DebouncedLayoutBuilder(
          builder: (context, constraints) {
            final plan = _planFor(data, constraints.biggest, top);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScaledTop(
                  scale: plan.chromeScale,
                  width: constraints.maxWidth,
                  child: _buildTop(data, controller, hasError),
                ),
                Expanded(child: _buildColumns(data, plan)),
              ],
            );
          },
        );
      },
    );
  }

  /// Banner + header + To check (+ khoang cach), chieu cao = [_topHeight].
  Widget _buildTop(
    WaterCheckResponse data,
    WaterCheckController controller,
    bool hasError,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasError)
          _ErrorBanner(loading: controller.loading, onRetry: controller.retry),
        WaterCheckHeader(
          generatedAt: data.generatedAt,
          summary: data.summary,
          filter: _filter,
          loading: controller.loading,
          onToggleFilter: _toggleFilter,
          fullScreen: widget.fullScreen,
          onToggleFullScreen: widget.onToggleFullScreen,
        ),
        const SizedBox(height: 6),
        WaterIssueCard(
          issues: data.issues,
          deviceNameOf: (issue) =>
              _index[waterSignalKey(
                    issue.facId,
                    issue.boxDeviceId,
                    issue.plcAddress,
                  )]
                  ?.signal
                  .deviceName ??
              '',
          decimalsOf: (issue) {
            final group =
                _index[waterSignalKey(
                      issue.facId,
                      issue.boxDeviceId,
                      issue.plcAddress,
                    )]
                    ?.group;
            return waterDecimals(
              code: group?.code,
              unit: group?.unit ?? issue.unit,
            );
          },
          onFocus: _focusIssue,
          onOpenChart: _openIssue,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildColumns(WaterCheckResponse data, WaterLayoutPlan plan) {
    if (data.facilities.isEmpty) {
      return const EmptyChartState(
        icon: Icons.water_drop_outlined,
        title: 'No water points',
        message: 'The water check returned no facilities.',
      );
    }

    // Cot cao theo noi dung, canh tren cung.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < data.facilities.length; i++) ...[
          if (i > 0) const SizedBox(width: WaterColumnMetrics.columnGap),
          Expanded(
            child: WaterFacilityColumn(
              facility: data.facilities[i],
              filter: _filter,
              plan: plan,
              keyOf: _keyOf,
              flashKey: _flashKey,
              flashToken: _flashToken,
              onOpenSignal: _openSignal,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// STATES
// ============================================================

class _WaterCheckSkeleton extends StatelessWidget {
  const _WaterCheckSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = Colors.white.withValues(alpha: .05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: WaterCheckHeader.height,
          decoration: BoxDecoration(
            color: block,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: block,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: .03),
                      border: Border.all(
                        color: kWaterAccent.withValues(alpha: .14),
                      ),
                    ),
                    child: const ChartBodySkeleton(color: kWaterAccent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Phong to phan tren theo [scale]: layout o be rong width / scale roi
/// scale deu ca chu, icon va chieu cao.
class _ScaledTop extends StatelessWidget {
  final double scale;
  final double width;
  final Widget child;

  const _ScaledTop({
    required this.scale,
    required this.width,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (scale == 1) return child;

    return FittedBox(
      fit: BoxFit.fitWidth,
      alignment: Alignment.topLeft,
      child: SizedBox(width: width / scale, child: child),
    );
  }
}

/// Banner mong tren cung: lan tai gan nhat loi, van giu du lieu cu.
class _ErrorBanner extends StatelessWidget {
  final bool loading;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.loading, required this.onRetry});

  /// Cao 28 + margin duoi 6.
  static const double height = 34;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kWaterOverColor.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kWaterOverColor.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 14, color: kWaterOverColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unable to refresh — showing last data.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: loading ? null : onRetry,
            style: TextButton.styleFrom(
              foregroundColor: kWaterOverColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              loading ? 'Retrying…' : 'Retry',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
