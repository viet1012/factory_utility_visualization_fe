import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_fac_details/layout/scada_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/response/latest_record.dart';
import '../../../utility_models/utility_facade_service.dart';
import '../../../utility_state/FacLatestDetailProvider.dart';
import '../../utility_dashboard_overview/utility_dashboard_overview_monthly/monthly_utility_usage_panel.dart';
import '../models/group_frame_types.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/edit_actions.dart';
import '../widgets/group_frame.dart';
import '../widgets/hover_box_panel.dart';
import '../widgets/scada_gradient.dart';
import '../widgets/top_header.dart';
import 'overlay_layout_store.dart';

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
      builder: (_) => const ColorPickerDialog(),
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
    debugPrint('Total box items: ${boxIds.length}');

    final directions = {
      ...layoutStore.groupDirectionOf(widget.facId),
      ..._localDirections,
    };

    _ensureEditingBox(boxIds);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ScadaStyle.dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TopHeader(
          facId: widget.facId,
          lastText: _formatTime(latestProvider.lastUpdated),
          editMode: _editMode,
          onToggleEdit: _toggleEditMode,
        ),
        actions: [
          if (_editMode && _editingBoxId != null)
            EditActions(
              selectedDirection:
                  directions[_editingBoxId] ?? ArrowDirection.right,
              onPickColor: _pickColor,
              onChangeDirection: _saveEditingDirection,
            ),
        ],
      ),
      body: ScadaGradient(
        child: SafeArea(
          child: Row(
            children: [
              //////////////////////////////////////////////////////////
              /// LEFT CHART PANEL
              //////////////////////////////////////////////////////////
              SizedBox(
                width: 220,
                child: Column(
                  children: [
                    Expanded(
                      child: MonthlyUtilityUsagePanel(fac: widget.facId),
                    ),
                    Expanded(
                      child: MonthlyUtilityUsagePanel(
                        fac: widget.facId,
                        nameEn: "TEST",
                        cate: "water",
                      ),
                    ),
                    Expanded(
                      child: MonthlyUtilityUsagePanel(
                        fac: widget.facId,
                        nameEn: "TEST",
                        cate: "compressed air",
                      ),
                    ),
                  ],
                ),
              ),
              //////////////////////////////////////////////////////////
              /// MAP
              //////////////////////////////////////////////////////////
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
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
              //////////////////////////////////////////////////////////
              /// RIGHT CHART PANEL
              //////////////////////////////////////////////////////////
              SizedBox(
                width: 270,
                child: MonthlyUtilityUsagePanel(
                  fac: widget.facId,
                  nameEn: "TEST",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////////////
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
  final TransformationController _transformController =
      TransformationController();

  final FocusNode _focusNode = FocusNode();

  Size _realImageSize = ScadaStyle.imageFallbackSize;

  String? _hoveredBoxId;
  bool _hoveringPanel = false;
  bool _lockViewer = false;
  Timer? _hoverTimer;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(covariant _FacOverlayMapGroup oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId) {
      _hoverTimer?.cancel();

      setState(() {
        _hoveredBoxId = null;
        _hoveringPanel = false;
        _lockViewer = false;
        _realImageSize = ScadaStyle.imageFallbackSize;
      });

      _loadImageSize();
    }

    if (widget.editMode && _hoveredBoxId != null) {
      _clearHover();
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
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
        _realImageSize = ScadaStyle.imageFallbackSize;
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

  void _showHover(String boxId) {
    if (widget.editMode) return;

    final rows = widget.groupedRows[boxId];
    if (rows == null || rows.isEmpty) return;

    _hoverTimer?.cancel();

    if (_hoveredBoxId == boxId && _lockViewer) return;

    setState(() {
      _hoveredBoxId = boxId;
      _hoveringPanel = false;
      _lockViewer = true;
    });
  }

  void _clearHover() {
    _hoverTimer?.cancel();

    if (_hoveredBoxId == null && !_lockViewer && !_hoveringPanel) return;

    setState(() {
      _hoveredBoxId = null;
      _hoveringPanel = false;
      _lockViewer = false;
    });
  }

  void _scheduleHideHover() {
    if (widget.editMode) return;

    _hoverTimer?.cancel();

    _hoverTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      if (_hoveringPanel) return;

      setState(() {
        _hoveredBoxId = null;
        _lockViewer = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);

        // final imageRect = _containRect(containerSize, _realImageSize);
        final imageRect = _coverRect(containerSize, _realImageSize);
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
              panEnabled: !widget.editMode && !_lockViewer,
              scaleEnabled: !widget.editMode && !_lockViewer,
              child: SizedBox(
                width: containerSize.width,
                height: containerSize.height,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fromRect(rect: imageRect, child: widget.image),
                    Positioned.fromRect(
                      rect: imageRect,
                      child: ClipRect(
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            for (final boxId in widget.boxIds)
                              _buildBox(
                                boxId: boxId,
                                imageRect: Rect.fromLTWH(
                                  0,
                                  0,
                                  imageRect.width,
                                  imageRect.height,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    _buildHoverPanel(imageRect),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHoverPanel(Rect imageRect) {
    final boxId = _hoveredBoxId;
    if (boxId == null) return const SizedBox.shrink();

    final rows = widget.groupedRows[boxId];
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();

    final pos01 =
        widget.groupLayout[boxId] ?? _autoPlace(widget.boxIds.indexOf(boxId));
    final cate = _uniqueCate(rows);

    return HoverBoxPanel(
      boxId: boxId,
      imageRect: imageRect,
      pos01: pos01,
      rows: rows,
      category: cate,
      onEnterPanel: () {
        _hoverTimer?.cancel();

        if (!_hoveringPanel || !_lockViewer) {
          setState(() {
            _hoveringPanel = true;
            _lockViewer = true;
          });
        }
      },
      onExitPanel: () {
        _hoveringPanel = false;
        _scheduleHideHover();
      },
    );
  }

  String? _uniqueCate(List<LatestRecordDto> rows) {
    final cates = rows
        .map((e) => (e.cate ?? '').trim())
        .where((cate) => cate.isNotEmpty)
        .toSet()
        .toList();

    cates.sort();

    if (cates.isEmpty) return null;
    return cates.first;
  }

  Widget _buildBox({required String boxId, required Rect imageRect}) {
    final pos01 =
        widget.groupLayout[boxId] ?? _autoPlace(widget.boxIds.indexOf(boxId));

    final rows = widget.groupedRows[boxId] ?? const <LatestRecordDto>[];
    final hasAlarm = _hasAlarm(rows);
    final cate = _uniqueCate(rows);
    return Positioned(
      left: pos01.dx * imageRect.width,
      top: pos01.dy * imageRect.height,
      child: MouseRegion(
        cursor: widget.editMode
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => _showHover(boxId),
        onExit: (_) => _scheduleHideHover(),
        child: GroupFrame(
          boxDeviceId: boxId,
          scadaText: _uniqueScadaText(rows),
          cate: cate,
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
      ),
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

  const cols = 4;
  const startX = 0.08;
  const startY = 0.08;
  const gapX = 0.22;
  const gapY = 0.12;

  final col = safeIndex % cols;
  final row = safeIndex ~/ cols;

  return Offset(
    (startX + col * gapX).clamp(0.02, 0.88),
    (startY + row * gapY).clamp(0.02, 0.88),
  );
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

Rect _coverRect(Size containerSize, Size childSize) {
  final scaleX = containerSize.width / childSize.width;
  final scaleY = containerSize.height / childSize.height;
  final scale = scaleX > scaleY ? scaleX : scaleY;

  final width = childSize.width * scale;
  final height = childSize.height * scale;

  return Rect.fromLTWH(
    (containerSize.width - width) / 2,
    (containerSize.height - height) / 2,
    width,
    height,
  );
}
