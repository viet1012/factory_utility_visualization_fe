import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../utility_api/dio_client.dart';
import '../utility_dashboard_overview_widgets/month_label_badge.dart';
import 'solar_detail_screen.dart';

/// Toàn bộ chuyển động "idle" (xoay tia nắng, đung đưa lá/cây, thở nền,
/// thở status dot, mũi tên chảy) dùng CHUNG một chu kỳ 120 giây, chạy trên
/// DUY NHẤT một AnimationController (_timeController) để giảm số Ticker
/// hoạt động song song trong 1 card — đây là nguyên nhân chính gây lag khi
/// có nhiều card hiển thị cùng lúc.
const double _kCycleSeconds = 120.0;

double _elapsedSeconds(Animation<double> time) => time.value * _kCycleSeconds;

/// Sóng sin chuẩn hoá theo chu kỳ [periodSeconds], trả về [-1, 1].
double _wave(double elapsedSeconds, double periodSeconds) {
  return math.sin((elapsedSeconds / periodSeconds) * 2 * math.pi);
}

class SolarSummaryCard extends StatefulWidget {
  final String facId;

  /// yyyyMM
  /// Ví dụ: 202608
  final String month;

  /// Tự động tải lại dữ liệu sau khoảng thời gian này.
  final Duration refreshInterval;

  const SolarSummaryCard({
    super.key,
    required this.facId,
    required this.month,
    this.refreshInterval = const Duration(minutes: 1),
  });

  @override
  State<SolarSummaryCard> createState() => _SolarSummaryCardState();
}

class _SolarSummaryCardState extends State<SolarSummaryCard>
    with SingleTickerProviderStateMixin {
  SolarDashboardData? _data;

  Timer? _refreshTimer;

  bool _isLoading = true;
  bool _isRefreshing = false;

  String? _errorMessage;

  /// Ticker DUY NHẤT cho mọi hiệu ứng idle trong toàn bộ card.
  late final AnimationController _timeController;

  Dio get _dio => DioClient.dio;

  int _requestVersion = 0;
  bool _requestRunning = false;

  @override
  void initState() {
    super.initState();

    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..repeat();

    _loadData();
    _startAutoRefresh();
  }

  @override
  void didUpdateWidget(covariant SolarSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final facChanged = oldWidget.facId != widget.facId;

    final monthChanged = oldWidget.month != widget.month;

    if (facChanged || monthChanged) {
      _loadData(showMainLoading: true);
    }

    if (oldWidget.refreshInterval != widget.refreshInterval) {
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    _requestVersion++;

    _refreshTimer?.cancel();
    _refreshTimer = null;

    _timeController.dispose();

    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(
      widget.refreshInterval,
      (_) => _loadData(showMainLoading: false),
    );
  }

  Future<void> _loadData({bool showMainLoading = false}) async {
    if (!mounted) return;

    /*
   * Refresh định kỳ không tạo request mới
   * nếu request cũ vẫn đang chạy.
   *
   * Khi đổi FAC hoặc MONTH thì cho phép request mới.
   */
    if (_requestRunning && !showMainLoading) {
      return;
    }

    final requestVersion = ++_requestVersion;

    // ============================================================
    // FAC
    // ============================================================

    final requestedFac = widget.facId.trim().isEmpty
        ? 'KVH'
        : widget.facId.trim();

    // ============================================================
    // MONTH
    //
    // yyyyMM
    // Ví dụ: 202608
    // ============================================================

    final requestedMonth = widget.month.trim();

    if (requestedMonth.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'Month is required';
      });

      return;
    }

    _requestRunning = true;

    setState(() {
      if (showMainLoading || _data == null) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }

      _errorMessage = null;
    });

    try {
      // ==========================================================
      // API MONTHLY SOLAR
      // ==========================================================

      final response = await _dio.get<dynamic>(
        '/api/solar/monthly',
        queryParameters: {'facId': requestedFac, 'month': requestedMonth},
      );

      if (response.data is! Map) {
        throw const FormatException('Invalid solar dashboard response');
      }

      final result = SolarDashboardData.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      // ==========================================================
      // BỎ RESPONSE CŨ
      //
      // Ví dụ:
      // request FAC_A/202607 chưa xong
      // user chuyển FAC_A/202608
      //
      // response 202607 về sau -> bỏ.
      // ==========================================================

      if (!mounted ||
          requestVersion != _requestVersion ||
          requestedFac !=
              (widget.facId.trim().isEmpty ? 'KVH' : widget.facId.trim()) ||
          requestedMonth != widget.month.trim()) {
        return;
      }

      setState(() {
        _data = result;

        _isLoading = false;
        _isRefreshing = false;

        _errorMessage = null;
      });
    } on DioException catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;

        _errorMessage = _dioErrorMessage(error);
      });
    } catch (e) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;

        _errorMessage = 'Cannot load solar data';
      });
    } finally {
      if (requestVersion == _requestVersion) {
        _requestRunning = false;
      }
    }
  }

  String _dioErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;

    if (statusCode != null) {
      return 'Solar API error: HTTP $statusCode';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Solar API timeout';
    }

    return 'Cannot load solar data';
  }

  String get monthLabel {
    final raw = widget.month.trim();

    if (raw.length != 6) return raw;

    final year = raw.substring(0, 4);
    final monthNumber = int.tryParse(raw.substring(4, 6));

    if (monthNumber == null || monthNumber < 1 || monthNumber > 12) {
      return raw;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[monthNumber - 1]} $year';
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  SolarDetailScreen(facId: widget.facId, month: widget.month),
            ),
          );
        },
        child: Container(
          // clipBehavior: Clip.antiAlias,
          // decoration: BoxDecoration(
          //   borderRadius: BorderRadius.circular(14),
          //   border: Border.all(color: const Color(0xff1c5478), width: 1),
          // ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              /// Ambient background không dùng Positioned.
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _timeController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: SolarIsometricSystemPainter(),
                      isComplex: false,
                      willChange: true,
                    );
                  },
                ),
              ),

              /// Nội dung chính.
              Column(
                children: [
                  _buildHeader(),

                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _buildBody(),
                    ),
                  ),
                ],
              ),

              /// Loading bar có thể bỏ Positioned bằng Align.
              if (_isRefreshing)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(
                    minHeight: 1.5,
                    backgroundColor: Colors.transparent,
                    color: Color(0xff25d8ff),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isOnline = _data != null && _errorMessage == null;

    return SizedBox(
      height: 34,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'SOLAR IMPACT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFFFB400),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            MonthLabelBadge(monthLabel: monthLabel),

            _StatusDot(isOnline: isOnline, time: _timeController),

            const SizedBox(width: 6),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xff55d7ff).withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xff55d7ff).withOpacity(0.22),
                ),
              ),
              child: Text(
                widget.facId.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xff55d7ff),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(width: 4),

            SizedBox(
              width: 26,
              height: 26,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Refresh',
                onPressed: _isRefreshing
                    ? null
                    : () => _loadData(showMainLoading: false),
                icon: AnimatedRotation(
                  turns: _isRefreshing ? 1 : 0,
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 17,
                    color: _isRefreshing
                        ? Colors.white30
                        : const Color(0xff55d7ff),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _data == null) {
      return const Center(
        key: ValueKey('loading'),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xff35d5ff),
          ),
        ),
      );
    }

    if (_errorMessage != null && _data == null) {
      return _buildError();
    }

    final data = _data;

    if (data == null) {
      return _buildError();
    }

    return Padding(
      key: const ValueKey('content'),
      padding: const EdgeInsets.all(5),
      child: _SolarImpactDonutLayout(data: data),
    );
  }

  Widget _buildError() {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xffff6868),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'No solar data',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 7),
            TextButton.icon(
              onPressed: () => _loadData(showMainLoading: true),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Reload'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chấm trạng thái online/offline. Hiệu ứng "thở" dùng opacity + scale
/// (KHÔNG dùng BoxShadow động — shadow phải tính lại path mỗi frame, khá tốn).
class _SolarImpactDonutLayout extends StatelessWidget {
  final SolarDashboardData data;

  const _SolarImpactDonutLayout({required this.data});

  static const solarColor = Color(0xFF76FF03);
  static const mainsColor = Color(0xFFFFB300);
  static const greenColor = Color(0xff43d17a);

  static const double _middleGap = 21;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===================================================
            // LEFT - DONUT
            // ===================================================
            Expanded(
              flex: compact ? 8 : 9,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _SolarShareDonut(
                    solarPercent: data.solarSharePercent,
                    gridPercent: data.gridSharePercent,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ===================================================
            // RIGHT
            // ===================================================
            Expanded(
              flex: compact ? 11 : 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // =================================================
                  // SOLAR + MAINS
                  // =================================================
                  Expanded(
                    flex: 5,
                    child: _EnergyMixSummary(data: data, middleGap: _middleGap),
                  ),

                  // =================================================
                  // CO2 + TREE
                  // =================================================
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        Expanded(
                          child: _ImpactMiniCard(
                            iconType: _ImpactMiniType.co2,
                            label: 'CO₂ AVOIDED',
                            value: _formatAnimatedNumber(
                              data.todayCo2Ton,
                              3,
                              compact: true,
                            ),
                            unit: 'ton',
                            color: greenColor,
                          ),
                        ),

                        SizedBox(
                          width: _middleGap,
                          child: Center(
                            child: Container(
                              width: 1,
                              height: 38,
                              color: const Color(0xff214058).withOpacity(.65),
                            ),
                          ),
                        ),

                        Expanded(
                          child: _ImpactMiniCard(
                            iconType: _ImpactMiniType.tree,
                            label: 'EQUIVALENT',
                            value: _formatAnimatedNumber(
                              data.todayEquivalentTrees,
                              0,
                              compact: true,
                            ),
                            unit: 'trees',
                            color: const Color(0xff67df78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SolarShareDonut extends StatelessWidget {
  final double solarPercent;
  final double gridPercent;

  const _SolarShareDonut({
    required this.solarPercent,
    required this.gridPercent,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: solarPercent.clamp(0, 100)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedSolar, _) {
        return RepaintBoundary(
          child: CustomPaint(
            painter: _SolarDonutPainter(solarPercent: animatedSolar),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // const CustomPaint(
                  //   size: Size(26, 26),
                  //   painter: _SunPainter(color: Color(0xffffc43d), rotation: 0),
                  // ),
                  const SizedBox(height: 6),

                  Text(
                    '${animatedSolar.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Color(0xFF76FF03),
                      fontSize: 30,
                      height: .95,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'SOLAR SHARE',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.72),
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SolarDonutPainter extends CustomPainter {
  final double solarPercent;

  const _SolarDonutPainter({required this.solarPercent});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);

    final strokeWidth = math.min(size.width, size.height) * .115;

    final radius = math.min(size.width, size.height) / 2 - strokeWidth;

    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = -math.pi / 2;

    final solarSweep = math.pi * 2 * (solarPercent.clamp(0, 100) / 100);

    final gridSweep = math.pi * 2 - solarSweep;

    // subtle back track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    // Grid
    final gridPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFFFFB300), Color(0xFFFFB300), Color(0xFFFFB300)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(rect, startAngle + solarSweep, gridSweep, false, gridPaint);

    // Solar
    final solarPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF76FF03), Color(0xFF76FF03)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(rect, startAngle, solarSweep, false, solarPaint);

    // inner border
    final innerBorder = Paint()
      ..color = const Color(0xff4db6ff).withOpacity(.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius - strokeWidth / 2 - 5, innerBorder);
  }

  @override
  bool shouldRepaint(covariant _SolarDonutPainter oldDelegate) {
    return oldDelegate.solarPercent != solarPercent;
  }
}

class _EnergyMixSummary extends StatelessWidget {
  final SolarDashboardData data;
  final double middleGap;

  const _EnergyMixSummary({required this.data, required this.middleGap});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _EnergyMixMetric(
            color: const Color(0xFF76FF03),
            label: 'SOLAR',
            value: data.solarKwh,
            percent: data.solarSharePercent,
          ),
        ),

        SizedBox(
          width: middleGap,
          child: Center(
            child: Container(
              width: 1,
              height: 38,
              color: const Color(0xff214058).withOpacity(.65),
            ),
          ),
        ),

        Expanded(
          child: _EnergyMixMetric(
            color: const Color(0xFFFFB300),
            label: 'MAINS',
            value: data.gridKwh,
            percent: data.gridSharePercent,
          ),
        ),
      ],
    );
  }
}

class _EnergyMixMetric extends StatelessWidget {
  final Color color;
  final String label;
  final double value;
  final double percent;

  const _EnergyMixMetric({
    required this.color,
    required this.label,
    required this.value,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // =====================================================
        // DOT
        // =====================================================
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withOpacity(.25), blurRadius: 4),
            ],
          ),
        ),

        const SizedBox(width: 7),

        // =====================================================
        // CONTENT
        // =====================================================
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LABEL + %
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              // VALUE
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: RichText(
                  maxLines: 1,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _formatAnimatedNumber(value, 1, compact: true),
                        style: const TextStyle(
                          color: Color(0xffedf4f9),
                          fontSize: 22,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const TextSpan(
                        text: ' kWh',
                        style: TextStyle(
                          color: Color(0xffedf4f9),
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ImpactMiniType { co2, tree }

class _ImpactMiniCard extends StatelessWidget {
  final _ImpactMiniType iconType;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _ImpactMiniCard({
    required this.iconType,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: switch (iconType) {
              _ImpactMiniType.co2 => CustomPaint(
                size: const Size(24, 24),
                painter: _LeafPainter(color: color),
              ),

              _ImpactMiniType.tree => CustomPaint(
                size: const Size(24, 24),
                painter: _ProfessionalTreePainter(color: color),
              ),
            },
          ),
        ),

        const SizedBox(width: 4),

        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 5),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          color: Color(0xfff1f6fa),
                          fontSize: 20,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          color: Color(0xffbecbd4),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool isOnline;
  final Animation<double> time;

  const _StatusDot({required this.isOnline, required this.time});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? const Color(0xff37e47c) : const Color(0xffff6262);

    if (!isOnline) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: time,
        builder: (context, _) {
          final es = _elapsedSeconds(time);
          final w = (_wave(es, 2) + 1) / 2;

          return SizedBox(
            width: 16,
            height: 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0.20 + w * 0.30,
                  child: Transform.scale(
                    scale: 1.0 + w * 1.1,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _ImpactEffect { solar, co2, tree }

/// Icon minh hoạ. Chỉ giữ 1 AnimationController RIÊNG cho hiệu ứng xuất hiện
/// (entrance, one-shot, tự dừng sau khi chạy xong — không tốn ticker liên
/// tục). Chuyển động nhàn rỗi (xoay/đung đưa) lấy pha từ [time] dùng chung
/// của cả card, không tạo controller riêng.
class _AnimatedImpactIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final _ImpactEffect effect;
  final Animation<double> time;

  const _AnimatedImpactIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.effect,
    required this.time,
  });

  @override
  State<_AnimatedImpactIcon> createState() => _AnimatedImpactIconState();
}

class _AnimatedImpactIconState extends State<_AnimatedImpactIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _entranceCurve;

  @override
  void initState() {
    super.initState();

    final entranceDuration = Duration(
      milliseconds: widget.effect == _ImpactEffect.tree ? 700 : 550,
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: entranceDuration,
    )..forward();

    _entranceCurve = CurvedAnimation(
      parent: _entranceController,
      curve: widget.effect == _ImpactEffect.tree
          ? Curves.easeOutCubic
          : Curves.easeOutBack,
    );
  }

  double get _idlePeriodSeconds {
    switch (widget.effect) {
      case _ImpactEffect.solar:
        return 7;
      case _ImpactEffect.co2:
        return 3;
      case _ImpactEffect.tree:
        return 4;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entranceCurve,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1).animate(_entranceCurve),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: widget.time,
            builder: (context, child) {
              final elapsed = _elapsedSeconds(widget.time);

              final wave = _wave(elapsed, _idlePeriodSeconds);

              final angle = switch (widget.effect) {
                _ImpactEffect.solar => 0.0,
                _ImpactEffect.co2 => wave * 0.05,
                _ImpactEffect.tree => wave * 0.018,
              };

              final y = switch (widget.effect) {
                _ImpactEffect.solar => 0.0,
                _ImpactEffect.co2 => wave * 0.8,
                _ImpactEffect.tree => wave * 0.4,
              };

              return Transform.translate(
                offset: Offset(0, y),
                child: Transform.rotate(angle: angle, child: child),
              );
            },
            child: _buildStaticIcon(),
          ),
        ),
      ),
    );
  }

  Widget _buildStaticIcon() {
    return SizedBox(
      width: 38,
      height: 38,
      child: Center(
        child: switch (widget.effect) {
          _ImpactEffect.solar => CustomPaint(
            size: const Size(31, 31),
            painter: _SunPainter(color: widget.color, rotation: 0),
          ),

          _ImpactEffect.co2 => CustomPaint(
            size: const Size(21, 21),
            painter: _LeafPainter(color: widget.color),
          ),

          _ImpactEffect.tree => CustomPaint(
            size: const Size(36, 36),
            painter: _ProfessionalTreePainter(color: widget.color),
          ),
        },
      ),
    );
  }
}

/// Mũi tên nối. Chỉ giữ controller riêng cho entrance (one-shot). Chấm chảy
/// liên tục lấy pha từ [time] dùng chung — không còn controller lặp riêng,
/// và không còn dùng MaskFilter.blur (đắt nhất trong các thứ đã bỏ).
class _ImpactFlowArrow extends StatefulWidget {
  final String animationKey;
  final Animation<double> time;

  const _ImpactFlowArrow({required this.animationKey, required this.time});

  @override
  State<_ImpactFlowArrow> createState() => _ImpactFlowArrowState();
}

class _ImpactFlowArrowState extends State<_ImpactFlowArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  static const double _flowPeriodSeconds = 1.8;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _ImpactFlowArrow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animationKey != widget.animationKey) {
      _entrance
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, widget.time]),
      builder: (context, _) {
        final entranceProgress = Curves.easeOutCubic.transform(_entrance.value);

        final elapsedSeconds = _elapsedSeconds(widget.time);

        final rawProgress =
            (elapsedSeconds % _flowPeriodSeconds) / _flowPeriodSeconds;

        final flowState = _resolveFlowState(rawProgress);

        return Transform.translate(
          offset: Offset(-4 + entranceProgress * 4, 0),
          child: Opacity(
            opacity: entranceProgress,
            child: RepaintBoundary(
              child: SizedBox(
                width: 24,
                height: 20,
                child: CustomPaint(
                  painter: _FlowArrowPainter(
                    progress: flowState.progress,
                    particleOpacity: flowState.opacity,
                  ),
                  isComplex: false,
                  willChange: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _FlowState _resolveFlowState(double rawProgress) {
    const travelEnd = 0.78;
    const fadeEnd = 0.92;

    if (rawProgress <= travelEnd) {
      final normalized = rawProgress / travelEnd;

      /*
     * Linear giúp hạt chạy đều như dòng điện,
     * không tăng tốc rồi giảm tốc.
     */
      return _FlowState(progress: normalized, opacity: 1);
    }

    if (rawProgress <= fadeEnd) {
      final fadeProgress = (rawProgress - travelEnd) / (fadeEnd - travelEnd);

      return _FlowState(
        progress: 1,
        opacity:
            1 - Curves.easeOutCubic.transform(fadeProgress.clamp(0.0, 1.0)),
      );
    }

    /*
   * Khoảng nghỉ ngắn khi hạt đã trong suốt.
   * Lúc reset về đầu, người xem không thấy cú nhảy.
   */
    return const _FlowState(progress: 0, opacity: 0);
  }
}

class _FlowState {
  final double progress;
  final double opacity;

  const _FlowState({required this.progress, required this.opacity});
}

class SolarDashboardData {
  final String facId;
  final DateTime? generatedAt;

  final double currentPowerKw;

  // TODAY ENERGY MIX
  final double solarKwh;
  final double gridKwh;
  final double totalKwh;
  final double solarSharePercent;

  // TODAY ENVIRONMENT IMPACT
  final double todayCo2Kg;
  final double todayCo2Ton;
  final double todayEquivalentTrees;

  const SolarDashboardData({
    required this.facId,
    required this.generatedAt,
    required this.currentPowerKw,
    required this.solarKwh,
    required this.gridKwh,
    required this.totalKwh,
    required this.solarSharePercent,
    required this.todayCo2Kg,
    required this.todayCo2Ton,
    required this.todayEquivalentTrees,
  });

  factory SolarDashboardData.fromJson(Map<String, dynamic> json) {
    return SolarDashboardData(
      facId: json['facId']?.toString() ?? 'KVH',

      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),

      currentPowerKw: _toDouble(json['currentPowerKw']),

      solarKwh: _toDouble(json['solarKwh']),

      gridKwh: _toDouble(json['gridKwh']),

      totalKwh: _toDouble(json['totalKwh']),

      solarSharePercent: _toDouble(json['solarSharePercent']),

      todayCo2Kg: _toDouble(json['todayCo2Kg']),

      todayCo2Ton: _toDouble(json['todayCo2Ton']),

      todayEquivalentTrees: _toDouble(json['todayEquivalentTrees']),
    );
  }

  double get gridSharePercent {
    return (100 - solarSharePercent).clamp(0, 100).toDouble();
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

String _formatAnimatedNumber(
  double value,
  int fractionDigits, {
  bool compact = false,
}) {
  if (!value.isFinite) {
    return '0';
  }

  if (compact) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
  }

  final fixed = value.toStringAsFixed(fractionDigits);
  final parts = fixed.split('.');

  final formattedInteger = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  if (parts.length == 1 || fractionDigits == 0) {
    return formattedInteger;
  }

  return '$formattedInteger.${parts.last}';
}

/// Mặt trời với tia nắng xoay chậm liên tục (pha lấy từ time chung của card).
class _SunPainter extends CustomPainter {
  final Color color;
  final double rotation;

  const _SunPainter({required this.color, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final coreRadius = size.width * 0.26;

    final rayPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;

    const rayCount = 8;
    final rayLength = size.width * 0.17;

    for (var i = 0; i < rayCount; i++) {
      final angle = rotation + (i * (2 * math.pi / rayCount));
      final dir = Offset(math.cos(angle), math.sin(angle));

      final start = center + dir * (coreRadius + 2);
      final end = center + dir * (coreRadius + 2 + rayLength);

      canvas.drawLine(start, end, rayPaint);
    }

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [Color.lerp(color, Colors.white, 0.35) ?? color, color],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));

    canvas.drawCircle(center, coreRadius, corePaint);
  }

  @override
  bool shouldRepaint(covariant _SunPainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.color != color;
  }
}

/// Chiếc lá đơn giản, tinh gọn dùng cho chỉ số CO₂.
class _LeafPainter extends CustomPainter {
  final Color color;

  const _LeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.25) ?? color, color],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final veinPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.04)
      ..quadraticBezierTo(
        size.width * 0.98,
        size.height * 0.28,
        size.width * 0.5,
        size.height * 0.96,
      )
      ..quadraticBezierTo(
        size.width * 0.02,
        size.height * 0.28,
        size.width * 0.5,
        size.height * 0.04,
      )
      ..close();

    canvas.drawPath(path, fillPaint);

    final veinPath = Path()
      ..moveTo(size.width * 0.5, size.height * 0.16)
      ..lineTo(size.width * 0.5, size.height * 0.84);

    canvas.drawPath(veinPath, veinPaint);
  }

  @override
  bool shouldRepaint(covariant _LeafPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Mũi tên + chấm sáng chạy dọc đường. KHÔNG dùng MaskFilter.blur — thay
/// bằng 2 lớp vòng tròn màu đặc, rẻ hơn nhiều cho GPU khi chạy liên tục.
class _FlowArrowPainter extends CustomPainter {
  final double progress;
  final double particleOpacity;

  const _FlowArrowPainter({
    required this.progress,
    required this.particleOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final y = size.height / 2;
    final lineEnd = size.width - 6;

    final linePaint = Paint()
      ..color = const Color(0xff4ccc83).withOpacity(0.30)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(Offset.zero.translate(0, y), Offset(lineEnd, y), linePaint);

    final headPaint = Paint()
      ..color = const Color(0xff4ccc83)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final headPath = Path()
      ..moveTo(lineEnd, y - 3.5)
      ..lineTo(size.width, y)
      ..lineTo(lineEnd, y + 3.5)
      ..close();

    canvas.drawPath(headPath, headPaint);

    final safeProgress = progress.clamp(0.0, 1.0);

    final safeOpacity = particleOpacity.clamp(0.0, 1.0);

    if (safeOpacity <= 0.001) {
      return;
    }

    final dotX = lineEnd * safeProgress;
    final center = Offset(dotX, y);

    /*
     * Không dùng MaskFilter.blur.
     * Ba vòng tròn đồng tâm nhẹ hơn đáng kể trên Web.
     */
    final outerGlowPaint = Paint()
      ..color = const Color(0xff82f5ad).withOpacity(0.08 * safeOpacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final innerGlowPaint = Paint()
      ..color = const Color(0xffb6ffcf).withOpacity(0.22 * safeOpacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final dotPaint = Paint()
      ..color = const Color(0xffedfff3).withOpacity(safeOpacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(center, 4.2, outerGlowPaint);

    canvas.drawCircle(center, 2.8, innerGlowPaint);

    canvas.drawCircle(center, 1.35, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _FlowArrowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particleOpacity != particleOpacity;
  }
}

/// Cây với tán lá gồm 3 khối tròn mềm, lay nhẹ theo pha idle chung của card.
class _ProfessionalTreePainter extends CustomPainter {
  final Color color;

  const _ProfessionalTreePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final trunkPaint = Paint()
      ..color = color.withOpacity(0.72)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final crownPaint = Paint()
      ..shader = RadialGradient(
        colors: [Color.lerp(color, Colors.white, 0.18) ?? color, color],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = size.width / 2;

    final trunkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        cx - size.width * 0.07,
        size.height * 0.55,
        size.width * 0.14,
        size.height * 0.28,
      ),
      Radius.circular(size.width * 0.03),
    );

    canvas.drawRRect(trunkRect, trunkPaint);

    canvas.drawCircle(
      Offset(cx, size.height * 0.34),
      size.width * 0.22,
      crownPaint,
    );

    canvas.drawCircle(
      Offset(cx - size.width * 0.16, size.height * 0.46),
      size.width * 0.19,
      crownPaint,
    );

    canvas.drawCircle(
      Offset(cx + size.width * 0.16, size.height * 0.46),
      size.width * 0.19,
      crownPaint,
    );

    canvas.drawCircle(
      Offset(cx - size.width * 0.08, size.height * 0.29),
      size.width * 0.07,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfessionalTreePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class SolarIsometricSystemPainter extends CustomPainter {
  const SolarIsometricSystemPainter();

  // ============================================================
  // COLORS
  // ============================================================

  static const Color _bgTop = Color(0xff071827);
  static const Color _bgBottom = Color(0xff030b14);

  static const Color _solar = Color(0xffffc300);
  static const Color _solarBright = Color(0xffffe066);

  static const Color _blue = Color(0xff35b9ff);
  static const Color _blueDeep = Color(0xff0a4168);

  static const Color _cyan = Color(0xff43d9ff);

  static const Color _green = Color(0xff64ed79);

  static const Color _metalLight = Color(0xff9db5c7);
  static const Color _metalMid = Color(0xff557181);
  static const Color _metalDark = Color(0xff172b38);

  static const Color _factoryLight = Color(0xff526d7b);
  static const Color _factoryDark = Color(0xff172936);

  // ============================================================
  // MAIN
  // ============================================================

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final w = size.width;
    final h = size.height;

    _drawBackground(canvas, size);

    _drawPerspectiveGrid(canvas, size);

    /*
     * Layout:
     *
     * SUN
     *      \
     *       PANEL ---- INVERTER ---- FACTORY
     */

    final systemY = h * .56;

    final sunCenter = Offset(w * .075, h * .18);

    final panelCenter = Offset(w * .25, systemY);

    final inverterCenter = Offset(w * .54, systemY);

    final factoryCenter = Offset(w * .68, systemY);

    // ==========================================================
    // AMBIENT GLOW
    // ==========================================================

    _drawSolarAmbientGlow(canvas, center: panelCenter, radius: w * .19);

    _drawFactoryAmbientGlow(canvas, center: factoryCenter, radius: w * .18);

    // ==========================================================
    // FLOW BEHIND OBJECTS
    // ==========================================================

    _drawSunBeam(
      canvas,
      from: sunCenter,
      to: Offset(panelCenter.dx - w * .06, panelCenter.dy - h * .08),
    );

    _drawEnergyCable(
      canvas,
      start: Offset(panelCenter.dx + w * .11, systemY + h * .015),
      end: Offset(factoryCenter.dx - w * .11, systemY + h * .015),
      color: _solar,
    );

    // ==========================================================
    // OBJECTS
    // ==========================================================

    _drawSun(canvas, center: sunCenter, radius: math.min(w, h) * .035);

    _drawSolarPlatform(
      canvas,
      center: panelCenter,
      width: w * .22,
      depth: h * .12,
    );

    _drawSolarArray(
      canvas,
      center: panelCenter,
      width: w * .185,
      height: h * .15,
    );

    _drawFactoryPlatform(
      canvas,
      center: factoryCenter,
      width: w * .22,
      depth: h * .12,
    );

    _drawFactory(
      canvas,
      center: factoryCenter,
      width: w * .17,
      height: h * .20,
    );
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_bgTop, Color(0xff061321), _bgBottom],
        stops: [0, .55, 1],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  // ============================================================
  // ISOMETRIC GRID
  // ============================================================

  void _drawPerspectiveGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _blue.withOpacity(.035)
      ..strokeWidth = .7
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final horizon = size.height * .34;

    const spacing = 26.0;

    // Diagonal /
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, horizon),
        Offset(x + size.height * 1.1, size.height),
        paint,
      );
    }

    // Diagonal \
    for (double x = 0; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, horizon),
        Offset(x - size.height * 1.1, size.height),
        paint,
      );
    }

    // horizontal perspective lines
    for (double y = horizon; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  // ============================================================
  // SUN
  // ============================================================

  void _drawSun(
    Canvas canvas, {
    required Offset center,
    required double radius,
  }) {
    // outer glow

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _solar.withOpacity(.22),
          _solar.withOpacity(.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 3));

    canvas.drawCircle(center, radius * 3, glowPaint);

    // core

    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xffffffff), _solarBright, _solar],
        stops: [0, .42, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, corePaint);

    final borderPaint = Paint()
      ..color = _solarBright.withOpacity(.80)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, borderPaint);

    // rays

    final rayPaint = Paint()
      ..color = _solarBright.withOpacity(.64)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const rayCount = 12;

    for (var i = 0; i < rayCount; i++) {
      final angle = i * math.pi * 2 / rayCount;

      final direction = Offset(math.cos(angle), math.sin(angle));

      canvas.drawLine(
        center + direction * (radius * 1.35),
        center + direction * (radius * 2.05),
        rayPaint,
      );
    }

    // tech circles

    final techPaint = Paint()
      ..color = _solar.withOpacity(.16)
      ..strokeWidth = .7
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius * 2.25, techPaint);

    canvas.drawCircle(center, radius * 2.6, techPaint);
  }

  // ============================================================
  // SUN → PANEL
  // ============================================================

  void _drawSunBeam(Canvas canvas, {required Offset from, required Offset to}) {
    final mainPaint = Paint()
      ..shader = LinearGradient(
        colors: [_solar.withOpacity(.03), _solar.withOpacity(.40)],
      ).createShader(Rect.fromPoints(from, to))
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(from.dx + i * 4, from.dy + 8),
        Offset(to.dx + i * 8, to.dy),
        mainPaint,
      );
    }
  }

  // ============================================================
  // SOLAR PLATFORM
  // ============================================================

  void _drawSolarPlatform(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double depth,
  }) {
    final top = _isoDiamond(
      center: Offset(center.dx, center.dy + depth * .45),
      width: width,
      depth: depth,
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xff18394e).withOpacity(.75),
          const Color(0xff071722).withOpacity(.90),
        ],
      ).createShader(top.getBounds());

    canvas.drawPath(top, fillPaint);

    final borderPaint = Paint()
      ..color = _cyan.withOpacity(.30)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawPath(top, borderPaint);

    _drawPlatformDepth(
      canvas,
      center: Offset(center.dx, center.dy + depth * .45),
      width: width,
      depth: depth,
      height: depth * .17,
      color: _blueDeep,
    );
  }

  // ============================================================
  // SOLAR ARRAY
  // ============================================================

  void _drawSolarArray(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
  }) {
    /*
     * 2 rows × 3 panels.
     */

    final panelW = width / 3.35;

    final panelH = height / 2.25;

    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        final x =
            center.dx -
            width / 2 +
            panelW / 2 +
            col * panelW * 1.08 +
            row * panelW * .17;

        final y = center.dy - height * .46 + row * panelH * .82;

        _drawSingleSolarPanel(
          canvas,
          center: Offset(x, y),
          width: panelW,
          height: panelH,
        );
      }
    }
  }

  void _drawSingleSolarPanel(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
  }) {
    /*
     * Isometric panel with ~30° visual tilt.
     */

    final dx = width * .17;

    final dy = height * .22;

    final p1 = Offset(center.dx - width / 2 + dx, center.dy - height / 2);

    final p2 = Offset(center.dx + width / 2 + dx, center.dy - height / 2);

    final p3 = Offset(center.dx + width / 2 - dx, center.dy + height / 2);

    final p4 = Offset(center.dx - width / 2 - dx, center.dy + height / 2);

    final panelPath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    // panel shadow

    final shadowPath = panelPath.shift(const Offset(2, 4));

    canvas.drawPath(shadowPath, Paint()..color = Colors.black.withOpacity(.25));

    // panel fill

    final rect = panelPath.getBounds();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff165da0), Color(0xff0b3d72), Color(0xff071c3a)],
      ).createShader(rect);

    canvas.drawPath(panelPath, fillPaint);

    // glass

    final glassPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(.22), Colors.transparent],
      ).createShader(rect);

    canvas.drawPath(panelPath, glassPaint);

    // border

    final borderPaint = Paint()
      ..color = const Color(0xffa9dcff).withOpacity(.75)
      ..strokeWidth = .9
      ..style = PaintingStyle.stroke;

    canvas.drawPath(panelPath, borderPaint);

    // cells

    final cellPaint = Paint()
      ..color = _cyan.withOpacity(.25)
      ..strokeWidth = .5
      ..style = PaintingStyle.stroke;

    for (var i = 1; i < 4; i++) {
      final t = i / 4;

      final start = Offset.lerp(p1, p4, t)!;

      final end = Offset.lerp(p2, p3, t)!;

      canvas.drawLine(start, end, cellPaint);
    }

    for (var i = 1; i < 5; i++) {
      final t = i / 5;

      final start = Offset.lerp(p1, p2, t)!;

      final end = Offset.lerp(p4, p3, t)!;

      canvas.drawLine(start, end, cellPaint);
    }

    // support

    final supportPaint = Paint()
      ..color = _metalLight.withOpacity(.35)
      ..strokeWidth = .9;

    canvas.drawLine(
      Offset(center.dx - width * .2, center.dy + height * .5),
      Offset(center.dx - width * .12, center.dy + height * .72),
      supportPaint,
    );

    canvas.drawLine(
      Offset(center.dx + width * .2, center.dy + height * .5),
      Offset(center.dx + width * .12, center.dy + height * .72),
      supportPaint,
    );
  }

  void _drawFactoryPlatform(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double depth,
  }) {
    final c = Offset(center.dx, center.dy + depth * .72);

    final base = _isoDiamond(center: c, width: width, depth: depth);

    canvas.drawPath(
      base,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xff17364a).withOpacity(.85),
            const Color(0xff07141e).withOpacity(.95),
          ],
        ).createShader(base.getBounds()),
    );

    canvas.drawPath(
      base,
      Paint()
        ..color = _cyan.withOpacity(.28)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    _drawPlatformDepth(
      canvas,
      center: c,
      width: width,
      depth: depth,
      height: depth * .18,
      color: const Color(0xff06131d),
    );
  }

  // ============================================================
  // FACTORY
  // ============================================================

  void _drawFactory(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
  }) {
    final depth = width * .28;

    final left = center.dx - width / 2;
    final right = center.dx + width / 2;

    final top = center.dy - height / 2;
    final bottom = center.dy + height / 2;

    // ============================================================
    // SHADOW
    // ============================================================

    final shadowRect = Rect.fromCenter(
      center: Offset(center.dx + depth * .25, bottom + height * .08),
      width: width * 1.25,
      height: height * .28,
    );

    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.black.withOpacity(.32), Colors.transparent],
        ).createShader(shadowRect),
    );

    // ============================================================
    // FRONT WALL
    // ============================================================

    final front = Path()
      ..moveTo(left, top + height * .22)
      ..lineTo(right, top)
      ..lineTo(right, bottom - depth * .72)
      ..lineTo(left, bottom)
      ..close();

    final frontBounds = front.getBounds();

    final frontPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff6e8998), Color(0xff405b69), Color(0xff1a303c)],
        stops: [0, .52, 1],
      ).createShader(frontBounds);

    canvas.drawPath(front, frontPaint);

    // ============================================================
    // RIGHT SIDE
    // ============================================================

    final side = Path()
      ..moveTo(right, top)
      ..lineTo(right + depth, top + depth * .72)
      ..lineTo(right + depth, bottom - depth * .16)
      ..lineTo(right, bottom - depth * .72)
      ..close();

    final sideBounds = side.getBounds();

    final sidePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff314b59), Color(0xff182b36), Color(0xff0d1d26)],
      ).createShader(sideBounds);

    canvas.drawPath(side, sidePaint);

    // ============================================================
    // ROOF
    // ============================================================

    final roof = Path()
      ..moveTo(left, top + height * .22)
      ..lineTo(right, top)
      ..lineTo(right + depth, top + depth * .72)
      ..lineTo(left + depth, top + height * .22 + depth)
      ..close();

    final roofBounds = roof.getBounds();

    final roofPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff8ba1ad), Color(0xff536d7a), Color(0xff2a414e)],
      ).createShader(roofBounds);

    canvas.drawPath(roof, roofPaint);

    // ============================================================
    // OUTLINE
    // ============================================================

    final outlinePaint = Paint()
      ..color = _cyan.withOpacity(.34)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawPath(front, outlinePaint);

    canvas.drawPath(side, outlinePaint);

    canvas.drawPath(roof, outlinePaint);

    // ============================================================
    // ROOF EDGE
    // ============================================================

    final roofEdgePaint = Paint()
      ..color = Colors.white.withOpacity(.15)
      ..strokeWidth = .7
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(left + width * .03, top + height * .22),
      Offset(right - width * .02, top + height * .01),
      roofEdgePaint,
    );

    // ============================================================
    // FRONT WINDOWS
    // ============================================================

    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 4; col++) {
        final windowCenter = Offset(
          left + width * (.15 + col * .18),
          top + height * (.42 + row * .22),
        );

        _drawFactoryWindow(
          canvas,
          center: windowCenter,
          width: width * .115,
          height: height * .105,
        );
      }
    }

    // ============================================================
    // SIDE WINDOWS
    // ============================================================

    for (var row = 0; row < 2; row++) {
      final y = top + depth * .78 + row * height * .22;

      final sideWindow = Path()
        ..moveTo(right + depth * .18, y)
        ..lineTo(right + depth * .72, y + depth * .16)
        ..lineTo(right + depth * .72, y + height * .10 + depth * .16)
        ..lineTo(right + depth * .18, y + height * .10)
        ..close();

      final bounds = sideWindow.getBounds();

      canvas.drawPath(
        sideWindow,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xffffe682), Color(0xffffa726)],
          ).createShader(bounds),
      );

      canvas.drawPath(
        sideWindow,
        Paint()
          ..color = Colors.white.withOpacity(.14)
          ..strokeWidth = .5
          ..style = PaintingStyle.stroke,
      );
    }

    // ============================================================
    // MAIN LOADING SHUTTER
    // ============================================================

    final shutterRect = Rect.fromLTWH(
      left + width * .36,
      bottom - height * .29,
      width * .25,
      height * .23,
    );

    final shutterPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff203742), Color(0xff0b1a22)],
      ).createShader(shutterRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(shutterRect, Radius.circular(width * .015)),
      shutterPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(shutterRect, Radius.circular(width * .015)),
      Paint()
        ..color = _cyan.withOpacity(.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );

    final shutterLinePaint = Paint()
      ..color = Colors.white.withOpacity(.07)
      ..strokeWidth = .5;

    for (var i = 1; i < 5; i++) {
      final y = shutterRect.top + shutterRect.height * i / 5;

      canvas.drawLine(
        Offset(shutterRect.left, y),
        Offset(shutterRect.right, y),
        shutterLinePaint,
      );
    }

    // ============================================================
    // SIDE DOOR
    // ============================================================

    final doorRect = Rect.fromLTWH(
      left + width * .73,
      bottom - height * .25,
      width * .10,
      height * .20,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(doorRect, Radius.circular(width * .01)),
      Paint()..color = const Color(0xff071823),
    );

    canvas.drawCircle(
      Offset(doorRect.right - 2, doorRect.center.dy),
      1,
      Paint()..color = _solarBright,
    );

    // ============================================================
    // ROOFTOP SOLAR ARRAY
    // ============================================================

    _drawRoofPanel(
      canvas,
      center: Offset(center.dx - width * .13, top + height * .16),
      width: width * .34,
      height: height * .11,
    );

    // second panel
    _drawRoofPanel(
      canvas,
      center: Offset(center.dx + width * .12, top + height * .105),
      width: width * .20,
      height: height * .075,
    );

    // ============================================================
    // HVAC
    // ============================================================

    _drawRooftopUnit(
      canvas,
      center: Offset(right - width * .12, top + height * .09),
      width: width * .14,
      height: height * .075,
    );

    _drawRooftopUnit(
      canvas,
      center: Offset(right + depth * .22, top + depth * .48),
      width: width * .11,
      height: height * .06,
    );

    // ============================================================
    // CHIMNEYS
    // ============================================================

    _drawPremiumChimney(
      canvas,
      base: Offset(right - width * .05, top + height * .02),
      width: width * .055,
      height: height * .46,
    );

    _drawPremiumChimney(
      canvas,
      base: Offset(right + width * .08, top + height * .08),
      width: width * .045,
      height: height * .37,
    );

    // ============================================================
    // FLOOR LIGHTS
    // ============================================================

    final lightPaint = Paint()..color = _solar.withOpacity(.85);

    final glowPaint = Paint()..color = _solar.withOpacity(.12);

    for (var i = 0; i < 3; i++) {
      final p = Offset(left + width * (.13 + i * .34), bottom + height * .015);

      canvas.drawCircle(p, 4, glowPaint);

      canvas.drawCircle(p, 1.2, lightPaint);
    }

    // ============================================================
    // BASE LINE
    // ============================================================

    canvas.drawLine(
      Offset(left - width * .05, bottom + height * .025),
      Offset(right + depth + width * .03, bottom - depth * .10),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.transparent,
            Color(0x6635d5ff),
            Color(0x2264ed79),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(left, bottom, right + depth, bottom + 4))
        ..strokeWidth = .8,
    );
  }

  void _drawFactoryWindow(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
  }) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width * .08)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffffef9a), Color(0xffffbc3d), Color(0xffd87800)],
        ).createShader(rect),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width * .08)),
      Paint()
        ..color = Colors.white.withOpacity(.12)
        ..strokeWidth = .5
        ..style = PaintingStyle.stroke,
    );

    final framePaint = Paint()
      ..color = const Color(0xff263944).withOpacity(.85)
      ..strokeWidth = .65;

    canvas.drawLine(
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      framePaint,
    );

    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      framePaint,
    );

    // glass highlight
    canvas.drawLine(
      Offset(rect.left + 1, rect.top + 1),
      Offset(rect.right - 1, rect.top + 1),
      Paint()
        ..color = Colors.white.withOpacity(.25)
        ..strokeWidth = .5,
    );
  }

  void _drawRooftopUnit(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
  }) {
    final depth = width * .22;

    final front = Rect.fromCenter(center: center, width: width, height: height);

    final frontRRect = RRect.fromRectAndRadius(
      front,
      Radius.circular(width * .08),
    );

    canvas.drawRRect(
      frontRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffaebec7), Color(0xff607884), Color(0xff2f4652)],
        ).createShader(front),
    );

    canvas.drawRRect(
      frontRRect,
      Paint()
        ..color = Colors.white.withOpacity(.15)
        ..strokeWidth = .5
        ..style = PaintingStyle.stroke,
    );

    final fanCenter = Offset(center.dx, center.dy);

    canvas.drawCircle(
      fanCenter,
      math.min(width, height) * .22,
      Paint()..color = const Color(0xff152832),
    );

    canvas.drawCircle(
      fanCenter,
      math.min(width, height) * .14,
      Paint()
        ..color = _cyan.withOpacity(.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );

    // subtle side depth
    canvas.drawLine(
      Offset(front.right, front.top + depth * .15),
      Offset(front.right + depth, front.top + depth),
      Paint()
        ..color = Colors.white.withOpacity(.08)
        ..strokeWidth = .6,
    );
  }

  // ============================================================
  // CHIMNEY
  // ============================================================

  void _drawPremiumChimney(
    Canvas canvas, {
    required Offset base,
    required double width,
    required double height,
  }) {
    final rect = Rect.fromLTWH(
      base.dx - width / 2,
      base.dy - height,
      width,
      height,
    );

    // shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(1.2, 1.5)),
        Radius.circular(width * .30),
      ),
      Paint()..color = Colors.black.withOpacity(.20),
    );

    // body
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width * .30)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xff263943),
            Color(0xff718893),
            Color(0xffc0ccd1),
            Color(0xff536b77),
            Color(0xff1e303a),
          ],
          stops: [0, .25, .50, .73, 1],
        ).createShader(rect),
    );

    // vertical highlight
    canvas.drawLine(
      Offset(rect.left + width * .42, rect.top + 2),
      Offset(rect.left + width * .42, rect.bottom - 2),
      Paint()
        ..color = Colors.white.withOpacity(.22)
        ..strokeWidth = .6,
    );

    // top rim
    final rim = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top),
      width: width * 1.08,
      height: width * .32,
    );

    canvas.drawOval(rim, Paint()..color = const Color(0xffd7e0e4));

    canvas.drawOval(
      rim.deflate(width * .16),
      Paint()..color = const Color(0xff172730),
    );

    // status ring
    canvas.drawOval(
      rim.inflate(width * .08),
      Paint()
        ..color = const Color(0xffff754d).withOpacity(.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  // ============================================================
  // ROOF SOLAR PANEL
  // ============================================================

  void _drawRoofPanel(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
  }) {
    final path = Path()
      ..moveTo(center.dx - width / 2, center.dy)
      ..lineTo(center.dx + width * .35, center.dy - height / 2)
      ..lineTo(center.dx + width / 2, center.dy)
      ..lineTo(center.dx - width * .35, center.dy + height / 2)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xff0f548c));

    canvas.drawPath(
      path,
      Paint()
        ..color = _cyan.withOpacity(.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
  }

  // ============================================================
  // ENERGY CABLE
  // ============================================================

  void _drawEnergyCable(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required Color color,
  }) {
    final rect = Rect.fromPoints(start, end);

    // outer glow

    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color.withOpacity(.08)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    // secondary glow

    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color.withOpacity(.16)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // core

    final corePaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(.45), color, color.withOpacity(.55)],
      ).createShader(rect)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, corePaint);

    // static flow markers

    final distance = (end - start).distance;

    final count = math.max(1, (distance / 35).floor());

    for (var i = 1; i <= count; i++) {
      final t = i / (count + 1);

      final position = Offset.lerp(start, end, t)!;

      canvas.drawCircle(
        position,
        1.6,
        Paint()..color = Colors.white.withOpacity(.75),
      );
    }
  }

  // ============================================================
  // PLATFORM DEPTH
  // ============================================================

  void _drawPlatformDepth(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double depth,
    required double height,
    required Color color,
  }) {
    final left = Offset(center.dx - width / 2, center.dy);

    final bottom = Offset(center.dx, center.dy + depth / 2);

    final right = Offset(center.dx + width / 2, center.dy);

    final leftBottom = left + Offset(0, height);

    final bottomBottom = bottom + Offset(0, height);

    final rightBottom = right + Offset(0, height);

    final leftFace = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(bottomBottom.dx, bottomBottom.dy)
      ..lineTo(leftBottom.dx, leftBottom.dy)
      ..close();

    final rightFace = Path()
      ..moveTo(bottom.dx, bottom.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(rightBottom.dx, rightBottom.dy)
      ..lineTo(bottomBottom.dx, bottomBottom.dy)
      ..close();

    canvas.drawPath(
      leftFace,
      Paint()..color = Color.lerp(color, Colors.black, .18) ?? color,
    );

    canvas.drawPath(
      rightFace,
      Paint()..color = Color.lerp(color, Colors.black, .38) ?? color,
    );
  }

  // ============================================================
  // ISOMETRIC DIAMOND
  // ============================================================

  Path _isoDiamond({
    required Offset center,
    required double width,
    required double depth,
  }) {
    return Path()
      ..moveTo(center.dx, center.dy - depth / 2)
      ..lineTo(center.dx + width / 2, center.dy)
      ..lineTo(center.dx, center.dy + depth / 2)
      ..lineTo(center.dx - width / 2, center.dy)
      ..close();
  }

  // ============================================================
  // GLOWS
  // ============================================================

  void _drawSolarAmbientGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [_solar.withOpacity(.055), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  void _drawFactoryAmbientGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [_green.withOpacity(.035), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  // ============================================================
  // NO ANIMATION
  // ============================================================

  @override
  bool shouldRepaint(covariant SolarIsometricSystemPainter oldDelegate) {
    return false;
  }
}
