import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/map_geometry_helper.dart';
import '../models/fac_box_view_data.dart';
import '../models/fac_detail_callbacks.dart';
import '../models/group_frame_types.dart';
import '../widgets/group_frame.dart';
import '../widgets/hover_box_panel.dart';
import 'scada_style.dart';

class FacOverlayMap extends StatefulWidget {
  final String facId;

  /// Danh sách Box ID, không còn là Box Device ID.
  final List<String> boxIds;

  /// Dữ liệu đã gom theo Box ID.
  final Map<String, FacBoxViewData> boxesById;

  /// Các map này cũng dùng Box ID làm key.
  final Map<String, Offset> groupLayout;
  final Map<String, ArrowDirection> directions;
  final Map<String, Color> colors;

  final bool editMode;

  /// Dù controller bên ngoài còn tên cũ,
  /// giá trị truyền vào đây là Box ID.
  final String? editingBoxId;

  final ValueChanged<String?> onPickEditingBox;

  final UpdateGroupPosition onUpdateGroupPosition;
  final UpdateGroupDirection onUpdateDirection;

  const FacOverlayMap({
    super.key,
    required this.facId,
    required this.boxIds,
    required this.boxesById,
    required this.groupLayout,
    required this.directions,
    required this.colors,
    required this.editMode,
    required this.editingBoxId,
    required this.onPickEditingBox,
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

  /// Box ID đang được click để mở table.
  String? _selectedBoxId;

  String get _imagePath {
    return 'assets/images/'
        '${widget.facId.toLowerCase()}.png';
  }

  BoxDecoration get _mapDecoration {
    return BoxDecoration(
      color: Colors.black.withOpacity(.18),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(.08)),
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

    /*
     * Khi chuyển sang edit mode,
     * đóng table đang mở.
     */
    if (widget.editMode && _selectedBoxId != null) {
      _closeTable();
      return;
    }

    /*
     * Nếu dữ liệu refresh làm mất Box ID đang chọn,
     * đóng table.
     */
    final selectedBoxId = _selectedBoxId;

    if (selectedBoxId != null && !widget.boxesById.containsKey(selectedBoxId)) {
      _closeTable();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformController.dispose();

    super.dispose();
  }

  // ============================================================
  // IMAGE
  // ============================================================

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

      if (!mounted) {
        return;
      }

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
      if (!mounted) {
        return;
      }

      if (widget.facId != requestedFacId) {
        return;
      }

      debugPrint(
        '[FacOverlayMap] '
        'Load image size error: $error',
      );

      setState(() {
        _imageSize = ScadaStyle.imageFallbackSize;

        _imageReady = true;
      });
    }
  }

  void _resetMap() {
    setState(() {
      _selectedBoxId = null;

      _imageReady = false;
      _imageSize = ScadaStyle.imageFallbackSize;

      _transformController.value = Matrix4.identity();
    });
  }

  // ============================================================
  // BOX DATA
  // ============================================================

  FacBoxViewData? _boxOf(String boxId) {
    return widget.boxesById[boxId];
  }

  Offset _boxPosition(String boxId) {
    final savedPosition = widget.groupLayout[boxId];

    if (savedPosition != null) {
      return savedPosition;
    }

    return MapGeometryHelper.autoPlace(widget.boxIds.indexOf(boxId));
  }

  // ============================================================
  // TABLE
  // ============================================================

  void _toggleTable(String boxId) {
    if (widget.editMode) {
      return;
    }

    final box = _boxOf(boxId);

    if (box == null || box.signals.isEmpty) {
      return;
    }

    setState(() {
      _selectedBoxId = _selectedBoxId == boxId ? null : boxId;
    });
  }

  void _closeTable() {
    if (_selectedBoxId == null) {
      return;
    }

    setState(() {
      _selectedBoxId = null;
    });
  }

  void _handleMapTap() {
    _focusNode.requestFocus();

    if (!widget.editMode) {
      _closeTable();
    }
  }

  // ============================================================
  // KEYBOARD
  // ============================================================

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _selectedBoxId != null) {
      _closeTable();

      return KeyEventResult.handled;
    }

    if (!widget.editMode) {
      return KeyEventResult.ignored;
    }

    final boxId = widget.editingBoxId;

    if (boxId == null) {
      return KeyEventResult.ignored;
    }

    final direction = _keyboardDirection(event.logicalKey);

    if (direction == Offset.zero) {
      return KeyEventResult.ignored;
    }

    final currentPosition = _boxPosition(boxId);

    final nextPosition = MapGeometryHelper.clampPosition(
      currentPosition + direction * _keyboardStep(),
    );

    /*
     * Callback vẫn dùng tên boxDeviceId
     * vì typedef cũ chưa đổi.
     * Giá trị thực tế là boxId.
     */
    unawaited(
      widget.onUpdateGroupPosition(boxDeviceId: boxId, position: nextPosition),
    );

    return KeyEventResult.handled;
  }

  double _keyboardStep() {
    if (HardwareKeyboard.instance.isAltPressed) {
      return .002;
    }

    if (HardwareKeyboard.instance.isShiftPressed) {
      return .02;
    }

    return .008;
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

  // ============================================================
  // BUILD
  // ============================================================

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
        final tableOpened = _selectedBoxId != null;

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (_, event) {
            return _handleKeyEvent(event);
          },
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: .8,
            maxScale: 5,
            trackpadScrollCausesScale: false,
            panEnabled: !widget.editMode && !tableOpened,
            scaleEnabled: !widget.editMode && !tableOpened,

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

                  /*
                   * Overlay chỉ nằm trong vùng ảnh.
                   */
                  Positioned.fromRect(
                    rect: imageRect,
                    child: ClipRect(
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          for (final boxId in widget.boxIds)
                            _buildBoxFrame(
                              boxId: boxId,
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

  // ============================================================
  // BOX FRAME
  // ============================================================

  Widget _buildBoxFrame({required String boxId, required Rect imageRect}) {
    final box = _boxOf(boxId);

    if (box == null) {
      return const SizedBox.shrink();
    }

    final position = _boxPosition(boxId);

    final isTableSelected = _selectedBoxId == boxId;

    return Positioned(
      left: position.dx * imageRect.width,
      top: position.dy * imageRect.height,
      child: MouseRegion(
        cursor: widget.editMode
            ? SystemMouseCursors.move
            : SystemMouseCursors.click,
        child: GroupFrame(
          /*
           * GroupFrame còn tên property cũ,
           * nhưng nội dung hiển thị là Box ID.
           */
          boxDeviceId: box.boxId,

          scadaText: box.scadaText,
          cate: box.primaryCategory,

          boxColor: widget.colors[boxId],

          hasAlarm: false,

          groupPos01: position,
          parentSize: imageRect.size,

          editMode: widget.editMode,

          isEditing: widget.editMode
              ? widget.editingBoxId == boxId
              : isTableSelected,

          direction: widget.directions[boxId] ?? ArrowDirection.right,

          onTap: () {
            _focusNode.requestFocus();

            if (widget.editMode) {
              widget.onPickEditingBox(boxId);

              return;
            }

            _toggleTable(boxId);
          },

          onDragGroup01: widget.editMode
              ? (newPosition) {
                  return widget.onUpdateGroupPosition(
                    /*
                     * Tên parameter cũ,
                     * giá trị thực tế là Box ID.
                     */
                    boxDeviceId: boxId,
                    position: newPosition,
                  );
                }
              : null,
        ),
      ),
    );
  }

  // ============================================================
  // SELECTED TABLE
  // ============================================================

  Widget _buildSelectedTable(Rect imageRect) {
    final boxId = _selectedBoxId;

    if (boxId == null || widget.editMode) {
      return const SizedBox.shrink();
    }

    final box = _boxOf(boxId);

    if (box == null || box.signals.isEmpty) {
      return const SizedBox.shrink();
    }

    return HoverBoxPanel(
      /*
       * Header hiển thị Box ID.
       */
      boxId: box.boxId,

      scadaId: box.scadaText,

      imageRect: imageRect,

      pos01: _boxPosition(boxId),

      /*
       * Toàn bộ signal từ các Box Device
       * nằm trong cùng Box ID.
       */
      rows: box.signals,

      category: box.primaryCategory,

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
