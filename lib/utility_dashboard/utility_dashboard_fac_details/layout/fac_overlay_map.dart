import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/map_geometry_helper.dart';
import '../models/fac_detail_callbacks.dart';
import '../models/fac_device_view_data.dart';
import '../models/group_frame_types.dart';
import '../widgets/group_frame.dart';
import '../widgets/hover_box_panel.dart';
import 'scada_style.dart';

class FacOverlayMap extends StatefulWidget {
  final String facId;

  final List<String> boxDeviceIds;
  final Map<String, FacDeviceViewData> devicesById;

  final Map<String, Offset> groupLayout;
  final Map<String, ArrowDirection> directions;
  final Map<String, Color> colors;

  final bool editMode;
  final String? editingBoxDeviceId;

  final ValueChanged<String?> onPickEditingDevice;
  final UpdateGroupPosition onUpdateGroupPosition;
  final UpdateGroupDirection onUpdateDirection;

  const FacOverlayMap({
    super.key,
    required this.facId,
    required this.boxDeviceIds,
    required this.devicesById,
    required this.groupLayout,
    required this.directions,
    required this.colors,
    required this.editMode,
    required this.editingBoxDeviceId,
    required this.onPickEditingDevice,
    required this.onUpdateGroupPosition,
    required this.onUpdateDirection,
  });

  @override
  State<FacOverlayMap> createState() {
    return _FacOverlayMapState();
  }
}

class _FacOverlayMapState extends State<FacOverlayMap> {
  final TransformationController _transformController =
      TransformationController();

  final FocusNode _focusNode = FocusNode();

  Size _imageSize = ScadaStyle.imageFallbackSize;

  bool _imageReady = false;

  /// Box đang được click để mở table.
  String? _selectedBoxDeviceId;

  String get _imagePath {
    return 'assets/images/${widget.facId.toLowerCase()}.png';
  }

  BoxDecoration get _mapDecoration {
    return BoxDecoration(
      color: Colors.black.withOpacity(0.18),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(covariant FacOverlayMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId) {
      _resetMap();
      _loadImageSize();
      return;
    }

    if (widget.editMode && _selectedBoxDeviceId != null) {
      _closeTable();
    }

    if (_selectedBoxDeviceId != null &&
        !widget.devicesById.containsKey(_selectedBoxDeviceId)) {
      _closeTable();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformController.dispose();

    super.dispose();
  }

  Future<void> _loadImageSize() async {
    final requestedFacId = widget.facId;
    final requestedImagePath = _imagePath;

    final provider = AssetImage(requestedImagePath);
    final completer = Completer<ImageInfo>();

    final stream = provider.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);

        if (!completer.isCompleted) {
          completer.complete(info);
        }
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);

        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    stream.addListener(listener);

    try {
      final info = await completer.future;

      if (!mounted) return;

      if (widget.facId != requestedFacId || _imagePath != requestedImagePath) {
        return;
      }

      setState(() {
        _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );

        _imageReady = true;
      });
    } catch (error) {
      if (!mounted) return;
      if (widget.facId != requestedFacId) return;

      debugPrint('[FacOverlayMap] Load image size error: $error');

      setState(() {
        _imageSize = ScadaStyle.imageFallbackSize;
        _imageReady = true;
      });
    }
  }

  void _resetMap() {
    setState(() {
      _selectedBoxDeviceId = null;

      _imageReady = false;
      _imageSize = ScadaStyle.imageFallbackSize;

      _transformController.value = Matrix4.identity();
    });
  }

  FacDeviceViewData? _deviceOf(String boxDeviceId) {
    return widget.devicesById[boxDeviceId];
  }

  Offset _devicePosition(String boxDeviceId) {
    final savedPosition = widget.groupLayout[boxDeviceId];

    if (savedPosition != null) {
      return savedPosition;
    }

    return MapGeometryHelper.autoPlace(
      widget.boxDeviceIds.indexOf(boxDeviceId),
    );
  }

  void _toggleTable(String boxDeviceId) {
    if (widget.editMode) {
      return;
    }

    final device = _deviceOf(boxDeviceId);

    if (device == null || device.signals.isEmpty) {
      return;
    }

    setState(() {
      if (_selectedBoxDeviceId == boxDeviceId) {
        _selectedBoxDeviceId = null;
      } else {
        _selectedBoxDeviceId = boxDeviceId;
      }
    });
  }

  void _closeTable() {
    if (_selectedBoxDeviceId == null) {
      return;
    }

    setState(() {
      _selectedBoxDeviceId = null;
    });
  }

  void _handleMapTap() {
    _focusNode.requestFocus();

    if (!widget.editMode) {
      _closeTable();
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _selectedBoxDeviceId != null) {
      _closeTable();
      return KeyEventResult.handled;
    }

    if (!widget.editMode) {
      return KeyEventResult.ignored;
    }

    final boxDeviceId = widget.editingBoxDeviceId;

    if (boxDeviceId == null) {
      return KeyEventResult.ignored;
    }

    final direction = _keyboardDirection(event.logicalKey);

    if (direction == Offset.zero) {
      return KeyEventResult.ignored;
    }

    final nextPosition = MapGeometryHelper.clampPosition(
      _devicePosition(boxDeviceId) + direction * _keyboardStep(),
    );

    unawaited(
      widget.onUpdateGroupPosition(
        boxDeviceId: boxDeviceId,
        position: nextPosition,
      ),
    );

    return KeyEventResult.handled;
  }

  double _keyboardStep() {
    if (HardwareKeyboard.instance.isAltPressed) {
      return 0.002;
    }

    if (HardwareKeyboard.instance.isShiftPressed) {
      return 0.02;
    }

    return 0.008;
  }

  Offset _keyboardDirection(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) {
      return const Offset(0, -1);
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      return const Offset(0, 1);
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      return const Offset(-1, 0);
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      return const Offset(1, 0);
    }

    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _mapDecoration,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: _imageReady ? _buildMapContent() : const _MapImageLoading(),
      ),
    );
  }

  Widget _buildMapContent() {
    return LayoutBuilder(
      key: ValueKey('map-${widget.facId}'),
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);

        final imageRect = MapGeometryHelper.containRect(
          containerSize,
          _imageSize,
        );

        final localImageRect = Rect.fromLTWH(
          0,
          0,
          imageRect.width,
          imageRect.height,
        );

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (_, event) {
            return _handleKeyEvent(event);
          },
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.8,
            maxScale: 5,

            // Khi table đang mở vẫn cho zoom/pan.
            // Chỉ khóa trong edit mode.
            panEnabled: !widget.editMode,
            scaleEnabled: !widget.editMode,

            child: SizedBox(
              width: containerSize.width,
              height: containerSize.height,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleMapTap,
                    ),
                  ),

                  Positioned.fromRect(
                    rect: imageRect,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleMapTap,
                      child: Image.asset(
                        _imagePath,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),

                  Positioned.fromRect(
                    rect: imageRect,
                    child: ClipRect(
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          for (final boxDeviceId in widget.boxDeviceIds)
                            _buildDeviceFrame(
                              boxDeviceId: boxDeviceId,
                              imageRect: localImageRect,
                            ),
                        ],
                      ),
                    ),
                  ),

                  _buildSelectedTable(imageRect),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceFrame({
    required String boxDeviceId,
    required Rect imageRect,
  }) {
    final device = _deviceOf(boxDeviceId);
    final position = _devicePosition(boxDeviceId);

    final isTableSelected = _selectedBoxDeviceId == boxDeviceId;

    return Positioned(
      left: position.dx * imageRect.width,
      top: position.dy * imageRect.height,
      child: MouseRegion(
        cursor: widget.editMode
            ? SystemMouseCursors.move
            : SystemMouseCursors.click,
        child: GroupFrame(
          boxDeviceId: boxDeviceId,
          scadaText: device?.scadaText ?? '',
          cate: device?.primaryCategory,
          boxColor: widget.colors[boxDeviceId],
          hasAlarm: false,
          groupPos01: position,
          parentSize: imageRect.size,
          editMode: widget.editMode,

          // Trong edit mode: selected theo controller.
          // Ngoài edit mode: selected theo table đang mở.
          isEditing: widget.editMode
              ? widget.editingBoxDeviceId == boxDeviceId
              : isTableSelected,

          direction: widget.directions[boxDeviceId] ?? ArrowDirection.right,

          onTap: () {
            _focusNode.requestFocus();

            if (widget.editMode) {
              widget.onPickEditingDevice(boxDeviceId);
              return;
            }

            _toggleTable(boxDeviceId);
          },

          onDragGroup01: widget.editMode
              ? (position) {
                  return widget.onUpdateGroupPosition(
                    boxDeviceId: boxDeviceId,
                    position: position,
                  );
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildSelectedTable(Rect imageRect) {
    final boxDeviceId = _selectedBoxDeviceId;

    if (boxDeviceId == null || widget.editMode) {
      return const SizedBox.shrink();
    }

    final device = _deviceOf(boxDeviceId);

    if (device == null || device.signals.isEmpty) {
      return const SizedBox.shrink();
    }

    return HoverBoxPanel(
      boxId: boxDeviceId,
      scadaId: device.scadaText,
      imageRect: imageRect,
      pos01: _devicePosition(boxDeviceId),
      rows: device.signals,
      category: device.primaryCategory,

      // Table giờ không cần quản lý enter/exit.
      onEnterPanel: () {},
      onExitPanel: () {},
    );
  }
}

class _MapImageLoading extends StatelessWidget {
  const _MapImageLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      key: ValueKey('map-loading'),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
