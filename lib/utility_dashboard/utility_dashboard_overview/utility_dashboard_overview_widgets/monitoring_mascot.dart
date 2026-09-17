import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'mascot/mascot_models.dart';
part 'mascot/mascot_character.dart';
part 'mascot/mascot_painter.dart';

class MovingMascot extends StatefulWidget {
  final double size;
  final Alignment idleAlignment;

  const MovingMascot({
    super.key,
    this.size = 180,
    this.idleAlignment = const Alignment(-0.60, 0.80),
  });

  @override
  State<MovingMascot> createState() => _MovingMascotState();
}

class _MovingMascotState extends State<MovingMascot>
    with SingleTickerProviderStateMixin {
  static const double _distanceEpsilon = 0.001;
  static const double _arcHeight = 0.07;
  static const Duration _minMoveDuration = Duration(milliseconds: 750);
  static const Duration _maxMoveDuration = Duration(milliseconds: 1900);
  static const String _logoAsset = 'assets/images/logo_misumi.png';

  late final AnimationController _moveController;

  Alignment _startAlignment = Alignment.center;
  Alignment _endAlignment = Alignment.center;

  /// HÃ†Â°Ã¡Â»â€ºng nhÃƒÂ¬n gÃ¡ÂºÂ§n nhÃ¡ÂºÂ¥t.
  double _lastFacing = 1;

  ui.Image? _misumiLogo;

  @override
  void initState() {
    super.initState();

    _startAlignment = widget.idleAlignment;
    _endAlignment = widget.idleAlignment;

    _moveController = AnimationController(
      vsync: this,
      duration: _minMoveDuration,
    );

    _moveController.addStatusListener(_handleMoveStatus);

    _loadLogo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _moveTo(widget.idleAlignment);
    });
  }

  @override
  void didUpdateWidget(covariant MovingMascot oldWidget) {
    super.didUpdateWidget(oldWidget);

    final idleChanged = oldWidget.idleAlignment != widget.idleAlignment;

    if (idleChanged) {
      _moveTo(widget.idleAlignment);
    }
  }

  void _handleMoveStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    // ChÃ¡Â»â€˜t chÃƒÂ­nh xÃƒÂ¡c vÃ¡Â»â€¹ trÃƒÂ­ cuÃ¡Â»â€˜i.
    _startAlignment = _endAlignment;
    _moveController.value = 0;
  }

  Future<void> _loadLogo() async {
    try {
      final image = await loadUiImage(_logoAsset);

      if (!mounted) {
        image.dispose();
        return;
      }

      setState(() {
        _misumiLogo?.dispose();
        _misumiLogo = image;
      });
    } catch (error, stackTrace) {
      debugPrint('MovingMascot load logo failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _moveTo(Alignment destination) {
    // LÃ¡ÂºÂ¥y Ã„â€˜ÃƒÂºng vÃ¡Â»â€¹ trÃƒÂ­ mascot tÃ¡ÂºÂ¡i thÃ¡Â»Âi Ã„â€˜iÃ¡Â»Æ’m hiÃ¡Â»â€¡n tÃ¡ÂºÂ¡i.
    // NhÃ¡Â»Â vÃ¡ÂºÂ­y Ã„â€˜Ã¡Â»â€¢i target giÃ¡Â»Â¯a lÃƒÂºc Ã„â€˜ang chÃ¡ÂºÂ¡y cÃ…Â©ng khÃƒÂ´ng bÃ¡Â»â€¹ nhÃ¡ÂºÂ£y.
    final currentPosition = _currentAlignment;

    final distance = _distanceBetween(currentPosition, destination);

    if (distance <= _distanceEpsilon) {
      _moveController.stop();

      _startAlignment = destination;
      _endAlignment = destination;
      _moveController.value = 0;

      if (mounted) {
        setState(() {});
      }

      return;
    }

    final dx = destination.x - currentPosition.x;

    if (dx.abs() > _distanceEpsilon) {
      _lastFacing = dx >= 0 ? 1 : -1;
    }

    _startAlignment = currentPosition;
    _endAlignment = destination;

    _moveController
      ..stop()
      ..duration = _calculateMoveDuration(distance)
      ..forward(from: 0);
  }

  Duration _calculateMoveDuration(double distance) {
    final minMs = _minMoveDuration.inMilliseconds;
    final maxMs = _maxMoveDuration.inMilliseconds;

    // Alignment toÃƒÂ n mÃƒÂ n hÃƒÂ¬nh thÃ†Â°Ã¡Â»Âng cÃƒÂ³ khoÃ¡ÂºÂ£ng cÃƒÂ¡ch 0 Ã¢â€ â€™ 2.8.
    final normalizedDistance = (distance / 2.8).clamp(0.0, 1.0);

    final milliseconds = minMs + ((maxMs - minMs) * normalizedDistance).round();

    return Duration(milliseconds: milliseconds);
  }

  double _distanceBetween(Alignment from, Alignment to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;

    return math.sqrt(dx * dx + dy * dy);
  }

  Alignment get _currentAlignment {
    if (!_moveController.isAnimating && _moveController.value == 0) {
      return _startAlignment;
    }

    return _calculateAlignment(_moveController.value);
  }

  Alignment _calculateAlignment(double controllerValue) {
    final progress = Curves.easeInOutCubic.transform(
      controllerValue.clamp(0.0, 1.0),
    );

    final inverse = 1.0 - progress;

    final middleAlignment = Alignment(
      (_startAlignment.x + _endAlignment.x) / 2,
      ((_startAlignment.y + _endAlignment.y) / 2) - _arcHeight,
    );

    // Quadratic BÃƒÂ©zier:
    //
    // P(t) = (1-t)Ã‚Â²P0 + 2(1-t)tP1 + tÃ‚Â²P2
    return Alignment(
      inverse * inverse * _startAlignment.x +
          2 * inverse * progress * middleAlignment.x +
          progress * progress * _endAlignment.x,
      inverse * inverse * _startAlignment.y +
          2 * inverse * progress * middleAlignment.y +
          progress * progress * _endAlignment.y,
    );
  }

  _MascotMoveFrame _calculateMoveFrame() {
    final rawProgress = _moveController.value.clamp(0.0, 1.0);

    final easedProgress = Curves.easeInOutCubic.transform(rawProgress);

    final alignment = _calculateAlignment(rawProgress);

    final dx = _endAlignment.x - _startAlignment.x;
    final dy = _endAlignment.y - _startAlignment.y;

    final distance = math.sqrt(dx * dx + dy * dy);

    final isWalking =
        _moveController.isAnimating && distance > _distanceEpsilon;

    final facing = dx.abs() > _distanceEpsilon
        ? (dx >= 0 ? 1.0 : -1.0)
        : _lastFacing;

    final walkStrength = isWalking ? (distance * 1.75).clamp(0.25, 1.0) : 0.0;

    // NghiÃƒÂªng mÃ¡ÂºÂ¡nh nhÃ¡ÂºÂ¥t Ã¡Â»Å¸ giÃ¡Â»Â¯a Ã„â€˜Ã†Â°Ã¡Â»Âng, vÃ¡Â»Â 0 Ã¡Â»Å¸ Ã„â€˜Ã¡ÂºÂ§u vÃƒÂ  cuÃ¡Â»â€˜i.
    final movementEnvelope = math.sin(easedProgress * math.pi);

    final lean = isWalking
        ? dx.clamp(-1.0, 1.0) * 0.09 * movementEnvelope
        : 0.0;

    // Ã„Âi xa thÃƒÂ¬ cÃƒÂ³ nhiÃ¡Â»Âu bÃ†Â°Ã¡Â»â€ºc hÃ†Â¡n.
    final stepCount = (distance * 6.5).clamp(2.0, 10.0);

    final walkPhase = rawProgress * math.pi * stepCount;

    return _MascotMoveFrame(
      alignment: alignment,
      facing: facing,
      lean: lean,
      walkStrength: walkStrength,
      isWalking: isWalking,
      walkPhase: walkPhase,
    );
  }

  @override
  void dispose() {
    _moveController.removeStatusListener(_handleMoveStatus);

    _moveController.dispose();
    _misumiLogo?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _moveController,
        builder: (context, child) {
          final frame = _calculateMoveFrame();

          return Align(
            alignment: frame.alignment,
            child: MonitoringMascot(
              size: widget.size,
              facing: frame.facing,
              lean: frame.lean,
              walkStrength: frame.walkStrength,
              isWalking: frame.isWalking,
              walkPhase: frame.walkPhase,
              groundY: widget.size * 0.90,
              misumiLogo: _misumiLogo,
            ),
          );
        },
      ),
    );
  }
}
