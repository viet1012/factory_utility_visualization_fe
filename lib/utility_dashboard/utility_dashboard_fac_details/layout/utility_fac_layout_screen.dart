import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/response/latest_record.dart';
import '../../../utility_models/utility_facade_service.dart';
import '../../../utility_state/FacLatestDetailProvider.dart';
import 'overlay_layout_store.dart';

enum ArrowDirection { right, left, up, down }

enum LabelOrientation { horizontal, vertical }

class _ScadaStyle {
  static const dark = Color(0xFF0A0E27);
  static const defaultBoxColor = Color(0xFF1E88E5);

  static const imageFallbackSize = Size(1920, 1080);

  static const gradient = LinearGradient(
    colors: [Color(0xFF0A0E27), Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class UtilityFacDetailScreens extends StatelessWidget {
  final String facId;
  final UtilityFacadeService svc;

  const UtilityFacDetailScreens({
    super.key,
    required this.facId,
    required this.svc,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FacLatestDetailProvider(svc: svc, facId: facId)
            ..fetch()
            ..startPolling(const Duration(seconds: 10)),
        ),
        ChangeNotifierProvider(
          create: (_) => OverlayGroupLayoutStore(svc)..loadGroups(facId),
        ),
      ],
      child: _FacDetailBody(facId: facId),
    );
  }
}

class _FacDetailBody extends StatefulWidget {
  final String facId;

  const _FacDetailBody({required this.facId});

  @override
  State<_FacDetailBody> createState() => _FacDetailBodyState();
}

class _FacDetailBodyState extends State<_FacDetailBody> {
  bool _editMode = false;
  String? _editingBoxId;

  final Map<String, ArrowDirection> _localDirections = {};

  OverlayGroupLayoutStore get _layoutStore =>
      context.read<OverlayGroupLayoutStore>();

  void _toggleEditMode() {
    setState(() {
      _editMode = !_editMode;

      if (!_editMode) {
        _editingBoxId = null;
      }
    });
  }

  void _selectEditingBox(String? boxId) {
    setState(() {
      _editingBoxId = boxId;
    });
  }

  void _ensureEditingBox(List<String> boxIds) {
    if (!_editMode || _editingBoxId != null || boxIds.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editMode || _editingBoxId != null) return;

      setState(() {
        _editingBoxId = boxIds.first;
      });
    });
  }

  Future<void> _pickColor() async {
    final boxId = _editingBoxId;
    if (boxId == null) return;

    final color = await showDialog<Color>(
      context: context,
      builder: (_) => const _ColorPickerDialog(),
    );

    if (color == null || !mounted) return;

    await _layoutStore.setGroupColor(
      facId: widget.facId,
      boxDeviceId: boxId,
      color: color,
    );
  }

  Future<void> _saveDirection(String boxId, ArrowDirection direction) async {
    setState(() {
      _localDirections[boxId] = direction;
    });

    final pos = _layoutStore.groupLayoutOf(widget.facId)[boxId];
    if (pos == null) return;

    await _saveGroupLayout(boxId: boxId, pos01: pos, direction: direction);
  }

  Future<void> _saveEditingDirection(ArrowDirection direction) async {
    final boxId = _editingBoxId;
    if (boxId == null) return;

    await _saveDirection(boxId, direction);
  }

  Future<void> _saveGroupLayout({
    required String boxId,
    required Offset pos01,
    required ArrowDirection direction,
  }) async {
    await _layoutStore.setGroupPos(
      facId: widget.facId,
      boxDeviceId: boxId,
      pos01: pos01,
      direction: direction,
      color: _layoutStore.groupColorOf(widget.facId)[boxId],
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestProvider = context.watch<FacLatestDetailProvider>();
    final layoutStore = context.watch<OverlayGroupLayoutStore>();

    final rows = latestProvider.rows;
    final boxIds = _extractSortedBoxIds(rows);
    final groupedRows = _groupRowsByBox(rows);

    final directions = {
      ...layoutStore.groupDirectionOf(widget.facId),
      ..._localDirections,
    };

    _ensureEditingBox(boxIds);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _ScadaStyle.dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _TopHeader(
          facId: widget.facId,
          lastText: _formatTime(latestProvider.lastUpdated),
          editMode: _editMode,
          onToggleEdit: _toggleEditMode,
        ),
        actions: [
          if (_editMode && _editingBoxId != null)
            _EditActions(
              selectedDirection:
                  directions[_editingBoxId] ?? ArrowDirection.right,
              onPickColor: _pickColor,
              onChangeDirection: _saveEditingDirection,
            ),
        ],
      ),
      body: _ScadaGradient(
        child: SafeArea(
          child: _FacOverlayMapGroup(
            facId: widget.facId,
            image: Image.asset(
              'assets/images/${widget.facId.toLowerCase()}.png',
              fit: BoxFit.contain,
            ),
            boxIds: boxIds,
            groupedRows: groupedRows,
            groupLayout: layoutStore.groupLayoutOf(widget.facId),
            directions: directions,
            colors: layoutStore.groupColorOf(widget.facId),
            editMode: _editMode,
            editingBoxId: _editingBoxId,
            onPickEditingBox: _selectEditingBox,
            onUpdateDirection: _saveDirection,
            onUpdateGroupPos: (boxId, pos01) {
              return _saveGroupLayout(
                boxId: boxId,
                pos01: pos01,
                direction: directions[boxId] ?? ArrowDirection.right,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FacOverlayMapGroup extends StatefulWidget {
  final String facId;
  final Widget image;
  final List<String> boxIds;
  final Map<String, Offset> groupLayout;
  final Map<String, ArrowDirection> directions;
  final Map<String, Color> colors;
  final Map<String, List<LatestRecordDto>> groupedRows;
  final bool editMode;
  final String? editingBoxId;
  final ValueChanged<String?> onPickEditingBox;
  final Future<void> Function(String boxDeviceId, Offset pos01)
  onUpdateGroupPos;
  final Future<void> Function(String boxDeviceId, ArrowDirection direction)
  onUpdateDirection;

  const _FacOverlayMapGroup({
    required this.facId,
    required this.image,
    required this.boxIds,
    required this.groupedRows,
    required this.groupLayout,
    required this.directions,
    required this.colors,
    required this.editMode,
    required this.editingBoxId,
    required this.onPickEditingBox,
    required this.onUpdateGroupPos,
    required this.onUpdateDirection,
  });

  @override
  State<_FacOverlayMapGroup> createState() => _FacOverlayMapGroupState();
}

class _FacOverlayMapGroupState extends State<_FacOverlayMapGroup> {
  final _transformController = TransformationController();
  final _focusNode = FocusNode();

  Size _realImageSize = _ScadaStyle.imageFallbackSize;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(covariant _FacOverlayMapGroup oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId) {
      _loadImageSize();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    final provider = AssetImage(
      'assets/images/${widget.facId.toLowerCase()}.png',
    );

    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info);
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        completer.completeError(error, stackTrace);
      },
    );

    stream.addListener(listener);

    try {
      final info = await completer.future;

      if (!mounted) return;

      setState(() {
        _realImageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _realImageSize = _ScadaStyle.imageFallbackSize;
      });
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !widget.editMode) {
      return KeyEventResult.ignored;
    }

    final boxId = widget.editingBoxId;
    if (boxId == null) return KeyEventResult.ignored;

    final delta = _keyboardDelta(event.logicalKey);
    if (delta == Offset.zero) return KeyEventResult.ignored;

    final current =
        widget.groupLayout[boxId] ?? _autoPlace(widget.boxIds.indexOf(boxId));

    final next = _clampOffset01(current + delta * _keyboardStep());

    widget.onUpdateGroupPos(boxId, next);

    return KeyEventResult.handled;
  }

  double _keyboardStep() {
    if (HardwareKeyboard.instance.isAltPressed) return 0.002;
    if (HardwareKeyboard.instance.isShiftPressed) return 0.02;

    return 0.008;
  }

  Offset _keyboardDelta(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return const Offset(0, -1);
    if (key == LogicalKeyboardKey.arrowDown) return const Offset(0, 1);
    if (key == LogicalKeyboardKey.arrowLeft) return const Offset(-1, 0);
    if (key == LogicalKeyboardKey.arrowRight) return const Offset(1, 0);

    return Offset.zero;
  }

  Offset _clampOffset01(Offset value) {
    return Offset(value.dx.clamp(0.0, 1.0), value.dy.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          final imageRect = _containRect(containerSize, _realImageSize);

          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (_, event) => _handleKeyEvent(event),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _focusNode.requestFocus(),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.8,
                maxScale: 5,
                panEnabled: !widget.editMode,
                scaleEnabled: !widget.editMode,
                child: SizedBox(
                  width: containerSize.width,
                  height: containerSize.height,
                  child: Stack(
                    children: [
                      Positioned.fromRect(rect: imageRect, child: widget.image),
                      for (final boxId in widget.boxIds)
                        _buildBox(boxId: boxId, imageRect: imageRect),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBox({required String boxId, required Rect imageRect}) {
    final pos01 =
        widget.groupLayout[boxId] ?? _autoPlace(widget.boxIds.indexOf(boxId));

    final rows = widget.groupedRows[boxId] ?? const <LatestRecordDto>[];
    final hasAlarm = _hasAlarm(rows);

    return Positioned(
      left: imageRect.left + pos01.dx * imageRect.width,
      top: imageRect.top + pos01.dy * imageRect.height,
      child: _GroupFrame(
        boxDeviceId: boxId,
        scadaText: _uniqueScadaText(rows),
        boxColor: hasAlarm ? Colors.redAccent : widget.colors[boxId],
        hasAlarm: hasAlarm,
        groupPos01: pos01,
        parentSize: imageRect.size,
        editMode: widget.editMode,
        isEditing: widget.editingBoxId == boxId,
        direction: widget.directions[boxId] ?? ArrowDirection.right,
        onTap: widget.editMode
            ? () {
                _focusNode.requestFocus();
                widget.onPickEditingBox(boxId);
              }
            : null,
        onDragGroup01: widget.editMode
            ? (newPos) => widget.onUpdateGroupPos(boxId, newPos)
            : null,
      ),
    );
  }
}

class _GroupFrame extends StatefulWidget {
  final String boxDeviceId;
  final String? scadaText;
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

  const _GroupFrame({
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
  });

  @override
  State<_GroupFrame> createState() => _GroupFrameState();
}

class _GroupFrameState extends State<_GroupFrame>
    with SingleTickerProviderStateMixin {
  late Offset _pos01;
  bool _dragging = false;

  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;

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

    _syncBlink();
  }

  @override
  void didUpdateWidget(covariant _GroupFrame oldWidget) {
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
    final normalColor = widget.boxColor ?? _ScadaStyle.defaultBoxColor;
    final baseColor = widget.hasAlarm ? Colors.redAccent : normalColor;
    final selected = widget.isEditing;

    return Align(
      alignment: _alignment,
      child: MouseRegion(
        cursor: _cursor,
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
            animation: _blinkAnimation,
            builder: (context, _) {
              final blinkValue = widget.hasAlarm ? _blinkAnimation.value : 1.0;

              return RepaintBoundary(
                child: AnimatedScale(
                  scale: _dragging ? 1.04 : (selected ? 1.03 : 1.0),
                  duration: const Duration(milliseconds: 120),
                  child: _ArrowLabel(
                    color: baseColor,
                    blinkValue: blinkValue,
                    selected: selected,
                    hasAlarm: widget.hasAlarm,
                    direction: widget.direction,
                    padding: _padding,
                    constraints: _constraints,
                    child: _FrameContent(
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

class _ArrowLabel extends StatelessWidget {
  final Color color;
  final double blinkValue;
  final bool selected;
  final bool hasAlarm;
  final ArrowDirection direction;
  final EdgeInsets padding;
  final BoxConstraints constraints;
  final Widget child;

  const _ArrowLabel({
    required this.color,
    required this.blinkValue,
    required this.selected,
    required this.hasAlarm,
    required this.direction,
    required this.padding,
    required this.constraints,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = hasAlarm
        ? blinkValue
        : selected
        ? 0.88
        : 0.58;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(
              hasAlarm
                  ? blinkValue
                  : selected
                  ? 0.45
                  : 0.22,
            ),
            blurRadius: hasAlarm
                ? 22
                : selected
                ? 16
                : 10,
            spreadRadius: hasAlarm
                ? 2
                : selected
                ? 1
                : 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _ArrowPainter(
          color: color.withOpacity(opacity),
          borderColor: hasAlarm
              ? Colors.yellowAccent
              : selected
              ? Colors.amberAccent
              : Colors.black.withOpacity(0.85),
          direction: direction,
        ),
        child: Container(
          padding: padding,
          constraints: constraints,
          child: IntrinsicWidth(child: child),
        ),
      ),
    );
  }
}

class _FrameContent extends StatelessWidget {
  final String boxDeviceId;
  final String? scadaText;
  final LabelOrientation orientation;
  final bool hasAlarm;

  const _FrameContent({
    required this.boxDeviceId,
    required this.scadaText,
    required this.orientation,
    required this.hasAlarm,
  });

  static const _labelShadows = [
    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
    Shadow(color: Colors.black, blurRadius: 10, offset: Offset.zero),
  ];

  bool get _hasScada {
    return (scadaText ?? '').trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (orientation == LabelOrientation.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.view_quilt_rounded,
            size: 16,
            color: Colors.white.withOpacity(0.95),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: RotatedBox(quarterTurns: 1, child: _label),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _label,
            if (hasAlarm) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.yellowAccent,
                size: 15,
              ),
            ],
          ],
        ),
        if (_hasScada) ...[
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              scadaText!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget get _label {
    return Text(
      boxDeviceId,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 12,
        height: 1.1,
        shadows: _labelShadows,
      ),
    );
  }
}

class _EditActions extends StatelessWidget {
  final ArrowDirection selectedDirection;
  final VoidCallback onPickColor;
  final ValueChanged<ArrowDirection> onChangeDirection;

  const _EditActions({
    required this.selectedDirection,
    required this.onPickColor,
    required this.onChangeDirection,
  });

  static const _buttons = [
    (Icons.arrow_left, ArrowDirection.left),
    (Icons.keyboard_arrow_up, ArrowDirection.up),
    (Icons.keyboard_arrow_down, ArrowDirection.down),
    (Icons.arrow_right, ArrowDirection.right),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AppBarIconButton(
          icon: Icons.palette,
          selected: false,
          onTap: onPickColor,
        ),
        const SizedBox(width: 6),
        for (final button in _buttons)
          _AppBarIconButton(
            icon: button.$1,
            selected: selectedDirection == button.$2,
            onTap: () => onChangeDirection(button.$2),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AppBarIconButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.amberAccent : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: selected
                ? Colors.amber.withOpacity(0.18)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? Colors.amberAccent
                  : Colors.white.withOpacity(0.14),
            ),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog();

  static const colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.yellow,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
    Colors.grey,
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final color in colors) _ColorPickItem(color: color)],
        ),
      ),
    );
  }
}

class _ColorPickItem extends StatelessWidget {
  final Color color;

  const _ColorPickItem({required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, color),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)],
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final ArrowDirection direction;

  const _ArrowPainter({
    required this.color,
    required this.borderColor,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _arrowPath(size);

    canvas
      ..drawPath(path, Paint()..color = color)
      ..drawPath(
        path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
  }

  Path _arrowPath(Size size) {
    const tip = 10.0;
    const neck = 6.0;

    switch (direction) {
      case ArrowDirection.right:
        return Path()
          ..moveTo(0, neck)
          ..lineTo(size.width - tip, neck)
          ..lineTo(size.width - tip, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(size.width - tip, size.height)
          ..lineTo(size.width - tip, size.height - neck)
          ..lineTo(0, size.height - neck)
          ..close();

      case ArrowDirection.left:
        return Path()
          ..moveTo(tip, 0)
          ..lineTo(tip, neck)
          ..lineTo(size.width, neck)
          ..lineTo(size.width, size.height - neck)
          ..lineTo(tip, size.height - neck)
          ..lineTo(tip, size.height)
          ..lineTo(0, size.height / 2)
          ..close();

      case ArrowDirection.up:
        return Path()
          ..moveTo(neck, tip)
          ..lineTo(size.width / 2 - neck, tip)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width / 2 + neck, tip)
          ..lineTo(size.width - neck, tip)
          ..lineTo(size.width - neck, size.height)
          ..lineTo(neck, size.height)
          ..close();

      case ArrowDirection.down:
        return Path()
          ..moveTo(neck, 0)
          ..lineTo(size.width - neck, 0)
          ..lineTo(size.width - neck, size.height - tip)
          ..lineTo(size.width / 2 + neck, size.height - tip)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width / 2 - neck, size.height - tip)
          ..lineTo(neck, size.height - tip)
          ..close();
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.direction != direction;
  }
}

class _TopHeader extends StatelessWidget {
  final String facId;
  final String lastText;
  final bool editMode;
  final VoidCallback onToggleEdit;

  const _TopHeader({
    required this.facId,
    required this.lastText,
    required this.editMode,
    required this.onToggleEdit,
  });

  @override
  Widget build(BuildContext context) {
    final accent = editMode ? Colors.amberAccent : Colors.lightBlueAccent;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.factory_rounded, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: _HeaderText(facId: facId, lastText: lastText),
          ),
          _EditToggleButton(editMode: editMode, onTap: onToggleEdit),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String facId;
  final String lastText;

  const _HeaderText({required this.facId, required this.lastText});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          facId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        Text(
          'Last update • $lastText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EditToggleButton extends StatelessWidget {
  final bool editMode;
  final VoidCallback onTap;

  const _EditToggleButton({required this.editMode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = editMode ? Colors.amberAccent : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: editMode
              ? Colors.amber.withOpacity(0.16)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: editMode
                ? Colors.amberAccent
                : Colors.white.withOpacity(0.14),
          ),
        ),
        child: Row(
          children: [
            Icon(
              editMode ? Icons.edit_off_rounded : Icons.edit_rounded,
              size: 17,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              editMode ? 'Editing' : 'Edit',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScadaGradient extends StatelessWidget {
  final Widget child;

  const _ScadaGradient({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _ScadaStyle.gradient),
      child: child,
    );
  }
}

bool _hasAlarm(List<LatestRecordDto> rows) {
  return rows.any((e) => (e.alarm ?? '').trim().toLowerCase() == 'alarm');
}

List<String> _extractSortedBoxIds(List<LatestRecordDto> rows) {
  final ids = rows
      .map((e) => (e.boxId ?? '').trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  ids.sort();

  return ids;
}

Map<String, List<LatestRecordDto>> _groupRowsByBox(List<LatestRecordDto> rows) {
  final grouped = <String, List<LatestRecordDto>>{};

  for (final row in rows) {
    final boxId = (row.boxId ?? '').trim();

    if (boxId.isEmpty) continue;

    grouped.putIfAbsent(boxId, () => <LatestRecordDto>[]).add(row);
  }

  return grouped;
}

String _uniqueScadaText(List<LatestRecordDto> rows) {
  final ids = rows
      .map((e) => (e.scadaId ?? '').trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  ids.sort();

  return ids.join(', ');
}

String _formatTime(DateTime? time) {
  if (time == null) return '—';

  String pad(int value) {
    return value.toString().padLeft(2, '0');
  }

  return '${pad(time.hour)}:${pad(time.minute)}:${pad(time.second)}';
}

Offset _autoPlace(int index) {
  final safeIndex = index < 0 ? 0 : index;
  final col = safeIndex % 3;
  final row = safeIndex ~/ 3;

  return Offset(0.2 + col * 0.25, 0.2 + row * 0.2);
}

Rect _containRect(Size containerSize, Size childSize) {
  final scaleX = containerSize.width / childSize.width;
  final scaleY = containerSize.height / childSize.height;
  final scale = scaleX < scaleY ? scaleX : scaleY;

  final width = childSize.width * scale;
  final height = childSize.height * scale;

  return Rect.fromLTWH(
    (containerSize.width - width) / 2,
    (containerSize.height - height) / 2,
    width,
    height,
  );
}
