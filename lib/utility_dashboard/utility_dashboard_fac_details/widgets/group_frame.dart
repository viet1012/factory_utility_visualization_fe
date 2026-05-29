import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../models/group_frame_types.dart';
import 'arrow_label.dart';
import 'frame_content.dart';

class GroupFrame extends StatefulWidget {
  final String boxDeviceId;
  final String? scadaText;
  final String? cate;
  final Offset groupPos01;
  final Size parentSize;
  final bool editMode;
  final bool isEditing;
  final bool hasAlarm;
  final Color? boxColor;
  final ArrowDirection direction;
  final LabelOrientation orientation;
  final VoidCallback? onTap;
  final Future<void> Function(Offset)? onDragGroup01;

  const GroupFrame({
    required this.boxDeviceId,
    required this.groupPos01,
    required this.parentSize,
    required this.editMode,
    required this.isEditing,
    required this.onTap,
    required this.onDragGroup01,
    required this.direction,
    this.scadaText,
    this.boxColor,
    this.hasAlarm = false,
    this.orientation = LabelOrientation.horizontal,
    this.cate,
  });

  @override
  State<GroupFrame> createState() => _GroupFrameState();
}

class _GroupFrameState extends State<GroupFrame> with TickerProviderStateMixin {
  late Offset _pos01;
  bool _dragging = false;
  bool _hovered = false;

  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;

  late final AnimationController _effectController;

  @override
  void initState() {
    super.initState();

    _pos01 = widget.groupPos01;

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _blinkAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _effectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _syncBlink();
  }

  @override
  void didUpdateWidget(covariant GroupFrame oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_dragging) {
      _pos01 = widget.groupPos01;
    }

    if (oldWidget.hasAlarm != widget.hasAlarm) {
      _syncBlink();
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _effectController.dispose();
    super.dispose();
  }

  void _syncBlink() {
    if (widget.hasAlarm) {
      _blinkController.repeat(reverse: true);
      return;
    }

    _blinkController.stop();
    _blinkController.value = 1.0;
  }

  bool get _canDrag {
    return widget.editMode && widget.onDragGroup01 != null;
  }

  MouseCursor get _cursor {
    if (!_canDrag) return SystemMouseCursors.click;
    return _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab;
  }

  BoxConstraints get _constraints {
    if (widget.orientation == LabelOrientation.vertical) {
      return const BoxConstraints(minWidth: 54, minHeight: 56, maxWidth: 76);
    }

    return const BoxConstraints(minWidth: 88, minHeight: 40, maxWidth: 240);
  }

  EdgeInsets get _padding {
    switch (widget.direction) {
      case ArrowDirection.right:
        return const EdgeInsets.fromLTRB(10, 6, 16, 6);
      case ArrowDirection.left:
        return const EdgeInsets.fromLTRB(16, 6, 10, 6);
      case ArrowDirection.up:
        return const EdgeInsets.fromLTRB(10, 14, 10, 6);
      case ArrowDirection.down:
        return const EdgeInsets.fromLTRB(10, 6, 10, 14);
    }
  }

  Alignment get _alignment {
    switch (widget.direction) {
      case ArrowDirection.right:
        return Alignment.centerRight;
      case ArrowDirection.left:
        return Alignment.centerLeft;
      case ArrowDirection.up:
        return Alignment.topCenter;
      case ArrowDirection.down:
        return Alignment.bottomCenter;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final next = Offset(
      (_pos01.dx + details.delta.dx / widget.parentSize.width).clamp(0.0, 1.0),
      (_pos01.dy + details.delta.dy / widget.parentSize.height).clamp(0.0, 1.0),
    );

    if (next == _pos01) return;

    setState(() {
      _pos01 = next;
    });
  }

  Future<void> _finishDrag() async {
    setState(() {
      _dragging = false;
    });

    await widget.onDragGroup01?.call(_pos01);
  }

  void _cancelDrag() {
    setState(() {
      _dragging = false;
      _pos01 = widget.groupPos01;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.getThemeByCate(widget.cate);

    final normalColor = widget.boxColor ?? theme.line;
    final selected = widget.isEditing;

    final activeEffect = (_hovered || selected || widget.hasAlarm)
        ? theme.effect
        : GroupFrameEffect.none;

    return Align(
      alignment: _alignment,
      child: MouseRegion(
        cursor: _cursor,
        onEnter: (_) {
          if (!widget.editMode) {
            setState(() => _hovered = true);
          }
        },
        onExit: (_) {
          if (!widget.editMode) {
            setState(() => _hovered = false);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanStart: _canDrag
              ? (_) {
                  setState(() {
                    _dragging = true;
                  });
                }
              : null,
          onPanUpdate: _canDrag ? _handlePanUpdate : null,
          onPanEnd: _canDrag ? (_) => _finishDrag() : null,
          onPanCancel: _canDrag ? _cancelDrag : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([_blinkAnimation, _effectController]),
            builder: (context, _) {
              final blinkValue = widget.hasAlarm ? _blinkAnimation.value : 1.0;

              return RepaintBoundary(
                child: AnimatedScale(
                  scale: _dragging ? 1.04 : (selected || _hovered ? 1.03 : 1.0),
                  duration: const Duration(milliseconds: 120),
                  child: ArrowLabel(
                    color: normalColor,
                    effectColor: theme.accent,
                    blinkValue: blinkValue,
                    selected: selected,
                    hasAlarm: widget.hasAlarm,
                    direction: widget.direction,
                    padding: _padding,
                    constraints: _constraints,
                    effect: activeEffect,
                    effectValue: _effectController.value,
                    child: FrameContent(
                      boxDeviceId: widget.boxDeviceId,
                      scadaText: widget.scadaText,
                      orientation: widget.orientation,
                      hasAlarm: widget.hasAlarm,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
