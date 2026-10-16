import 'package:flutter/material.dart';

import 'controller/power_usage_controller.dart';
import 'model/power_usage.dart';
import 'widgets/electricity_style.dart';
import 'widgets/factory_cards.dart';
import 'widgets/power_usage_header.dart';
import 'widgets/purpose_table_card.dart';
import 'widgets/supply_mix_card.dart';
import 'widgets/total_card.dart';

/// MONITORING › Electricity: cot trai ~27% (Total, Period vs period, By
/// factory), cot phai ~73% (Change by purpose), duoi la Energy supply mix.
class ElectricityScreen extends StatelessWidget {
  final PowerUsageController controller;
  final OpenMeterCallback? onOpenMeter;

  const ElectricityScreen({
    super.key,
    required this.controller,
    this.onOpenMeter,
  });

  static const double _gap = 10;
  static const double _wideBreakpoint = 980;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = controller.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PowerUsageHeader(controller: controller),
            const SizedBox(height: 6),
            SizedBox(
              height: 3,
              child: controller.loading && data != null
                  ? const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      color: ElectricityColors.facB,
                    )
                  : null,
            ),
            if (data != null && controller.error != null)
              _InlineError(
                message: controller.error!,
                onRetry: controller.retry,
              ),
            const SizedBox(height: 6),
            Expanded(child: _body(data)),
          ],
        );
      },
    );
  }

  Widget _body(PowerUsageResponse? data) {
    if (data == null) {
      if (controller.error != null && !controller.loading) {
        return _ErrorView(
          message: controller.error!,
          onRetry: controller.retry,
        );
      }
      return const _Skeleton();
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: controller.loading ? .5 : 1,
      child: IgnorePointer(
        ignoring: controller.loading,
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= _wideBreakpoint;
            final unit = controller.unit;

            final left = [
              TotalCard(data: data, unit: unit),
              const SizedBox(height: _gap),
              PeriodCompareCard(data: data),
              const SizedBox(height: _gap),
              FactoryDonutCard(data: data),
            ];
            final right = PurposeTableCard(
              data: data,
              period: controller.period,
              onOpenMeter: onOpenMeter,
            );

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 27,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: left,
                          ),
                        ),
                        const SizedBox(width: _gap),
                        Expanded(flex: 73, child: right),
                      ],
                    )
                  else ...[
                    ...left,
                    const SizedBox(height: _gap),
                    right,
                  ],
                  const SizedBox(height: _gap),
                  SupplyMixCard(data: data),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 27,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: SkeletonBox()),
                    SizedBox(height: 10),
                    Expanded(flex: 4, child: SkeletonBox()),
                    SizedBox(height: 10),
                    Expanded(flex: 3, child: SkeletonBox()),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Expanded(flex: 73, child: SkeletonBox()),
            ],
          ),
        ),
        SizedBox(height: 10),
        SkeletonBox(height: 90),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: ElectricityColors.up,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ElectricityColors.text, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: ElectricityColors.up,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ElectricityColors.up, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
