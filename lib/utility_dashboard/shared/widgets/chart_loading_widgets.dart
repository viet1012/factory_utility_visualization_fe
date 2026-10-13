import 'package:flutter/material.dart';

/// Skeleton tinh cua vung chart trong mot the (khong animation, khong ton CPU
/// khi nhieu the cung cho).
class ChartBodySkeleton extends StatelessWidget {
  final Color color;

  /// Hien them thanh tom tat (42px) phia tren chart.
  final bool withSummary;

  const ChartBodySkeleton({
    super.key,
    required this.color,
    this.withSummary = true,
  });

  static const List<double> _bars = [
    .35,
    .5,
    .42,
    .6,
    .55,
    .72,
    .64,
    .48,
    .58,
    .4,
    .52,
    .66,
  ];

  @override
  Widget build(BuildContext context) {
    final block = Colors.white.withValues(alpha: .05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (withSummary) ...[
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: block,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .025),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final factor in _bars)
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: factor,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Grid the rong (khung + skeleton) khi chua co danh sach signal: giu bo cuc
/// cua tab ngay tu dau thay vi chan bang mot spinner.
class ChartGridSkeleton extends StatelessWidget {
  final Color color;
  final int cards;

  const ChartGridSkeleton({super.key, required this.color, this.cards = 6});

  static int columnsFor(double width) {
    if (width >= 1700) return 3;
    if (width >= 1150) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: const EdgeInsets.only(top: 4),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnsFor(constraints.maxWidth),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 16 / 10,
          ),
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: .03),
              border: Border.all(color: color.withValues(alpha: .14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cho cua header the.
                Container(
                  height: 28,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Expanded(child: ChartBodySkeleton(color: color)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Giu noi dung cu (lam mo, khong bam duoc) kem progress bar manh o tren
/// trong luc dang tai lai (doi filter / range), thay vi nhay ve skeleton.
///
/// [child] luon o cung vi tri trong cay nen state cua chart duoc giu.
class ChartBusyOverlay extends StatelessWidget {
  final bool busy;
  final Color color;
  final Widget child;

  const ChartBusyOverlay({
    super.key,
    required this.busy,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: busy ? .4 : 1,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(ignoring: busy, child: child),
          ),
        ),
        if (busy)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: color,
              backgroundColor: color.withValues(alpha: .12),
            ),
          ),
      ],
    );
  }
}
