import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/'
    'utility_dashboard_fac_details/layout/scada_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/utility_facade_service.dart';
import '../../../utility_state/latest_provider.dart';
import '../../utility_dashboard_overview/'
    'utility_dashboard_overview_models/latest_tree_response.dart';
import '../models/group_frame_types.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/edit_actions.dart';
import '../widgets/group_frame.dart';
import '../widgets/hover_box_panel.dart';
import '../widgets/scada_gradient.dart';
import '../widgets/top_header.dart';
import 'overlay_layout_store.dart';

class UtilityFacDetailScreensDemo extends StatelessWidget {
  final String facId;
  final UtilityFacadeService svc;

  const UtilityFacDetailScreensDemo({
    super.key,
    required this.facId,
    required this.svc,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        return OverlayGroupLayoutStore(svc)..loadGroups(facId);
      },
      child: _FacDetailBody(facId: facId),
    );
  }
}

class _FacDetailBody extends StatefulWidget {
  final String facId;

  const _FacDetailBody({required this.facId});

  @override
  State<_FacDetailBody> createState() {
    return _FacDetailBodyState();
  }
}

class _FacDetailBodyState extends State<_FacDetailBody> {
  bool _editMode = false;

  String? _editingBoxDeviceId;

  final Map<String, ArrowDirection> _localDirections = {};

  OverlayGroupLayoutStore get _layoutStore {
    return context.read<OverlayGroupLayoutStore>();
  }

  @override
  void initState() {
    super.initState();

    _loadFacility();
  }

  @override
  void didUpdateWidget(covariant _FacDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId) {
      _resetLocalState();
      _loadFacility();
    }
  }

  void _loadFacility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<LatestProvider>().refreshFacility(
        widget.facId,
        silent: false,
      );
    });
  }

  void _resetLocalState() {
    _editMode = false;
    _editingBoxDeviceId = null;
    _localDirections.clear();
  }

  void _toggleEditMode() {
    setState(() {
      _editMode = !_editMode;

      if (!_editMode) {
        _editingBoxDeviceId = null;
      }
    });
  }

  void _selectEditingDevice(String? boxDeviceId) {
    setState(() {
      _editingBoxDeviceId = boxDeviceId;
    });
  }

  void _ensureEditingDevice(List<String> boxDeviceIds) {
    if (!_editMode) return;
    if (_editingBoxDeviceId != null) return;
    if (boxDeviceIds.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_editMode) return;
      if (_editingBoxDeviceId != null) return;

      setState(() {
        _editingBoxDeviceId = boxDeviceIds.first;
      });
    });
  }

  Future<void> _pickColor() async {
    final boxDeviceId = _editingBoxDeviceId;

    if (boxDeviceId == null) return;

    final color = await showDialog<Color>(
      context: context,
      builder: (_) {
        return const ColorPickerDialog();
      },
    );

    if (!mounted || color == null) return;

    await _layoutStore.setGroupColor(
      facId: widget.facId,
      boxDeviceId: boxDeviceId,
      color: color,
    );
  }

  Future<void> _saveEditingDirection(ArrowDirection direction) async {
    final boxDeviceId = _editingBoxDeviceId;

    if (boxDeviceId == null) return;

    await _saveDirection(boxDeviceId: boxDeviceId, direction: direction);
  }

  Future<void> _saveDirection({
    required String boxDeviceId,
    required ArrowDirection direction,
  }) async {
    setState(() {
      _localDirections[boxDeviceId] = direction;
    });

    final position = _layoutStore.groupLayoutOf(widget.facId)[boxDeviceId];

    if (position == null) return;

    await _saveGroupLayout(
      boxDeviceId: boxDeviceId,
      position: position,
      direction: direction,
    );
  }

  Future<void> _saveGroupLayout({
    required String boxDeviceId,
    required Offset position,
    required ArrowDirection direction,
  }) {
    return _layoutStore.setGroupPos(
      facId: widget.facId,
      boxDeviceId: boxDeviceId,
      pos01: position,
      direction: direction,
      color: _layoutStore.groupColorOf(widget.facId)[boxDeviceId],
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestProvider = context.watch<LatestProvider>();
    final layoutStore = context.watch<OverlayGroupLayoutStore>();

    final facility = latestProvider.facilityOf(widget.facId);

    final devicesById = _LatestTreeHelper.groupDevices(facility);

    final boxDeviceIds = devicesById.keys.toList()..sort(_compareText);

    final lastUpdated = _LatestTreeHelper.findLatestTime(devicesById.values);

    final directions = <String, ArrowDirection>{
      ...layoutStore.groupDirectionOf(widget.facId),
      ..._localDirections,
    };

    _ensureEditingDevice(boxDeviceIds);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ScadaStyle.dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: TopHeader(
          facId: widget.facId,
          lastText: _formatTime(lastUpdated),
          editMode: _editMode,
          onToggleEdit: _toggleEditMode,
        ),
        actions: [
          if (_editMode && _editingBoxDeviceId != null)
            EditActions(
              selectedDirection:
                  directions[_editingBoxDeviceId] ?? ArrowDirection.right,
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
              // SizedBox(
              //   width: 220,
              //   child: Column(
              //     children: [
              //       Expanded(
              //         child: MonthlyUtilityUsagePanel(fac: widget.facId),
              //       ),
              //       Expanded(
              //         child: MonthlyUtilityUsagePanel(
              //           fac: widget.facId,
              //           nameEn: 'TEST',
              //           cate: 'water',
              //         ),
              //       ),
              //       Expanded(
              //         child: MonthlyUtilityUsagePanel(
              //           fac: widget.facId,
              //           nameEn: 'TEST',
              //           cate: 'compressed air',
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

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
                      'assets/images/'
                      '${widget.facId.toLowerCase()}.png',
                      fit: BoxFit.contain,
                    ),
                    boxDeviceIds: boxDeviceIds,
                    devicesById: devicesById,
                    groupLayout: layoutStore.groupLayoutOf(widget.facId),
                    directions: directions,
                    colors: layoutStore.groupColorOf(widget.facId),
                    editMode: _editMode,
                    editingBoxDeviceId: _editingBoxDeviceId,
                    onPickEditingDevice: _selectEditingDevice,
                    onUpdateDirection:
                        ({
                          required String boxDeviceId,
                          required ArrowDirection direction,
                        }) {
                          return _saveDirection(
                            boxDeviceId: boxDeviceId,
                            direction: direction,
                          );
                        },
                    onUpdateGroupPosition:
                        ({
                          required String boxDeviceId,
                          required Offset position,
                        }) {
                          return _saveGroupLayout(
                            boxDeviceId: boxDeviceId,
                            position: position,
                            direction:
                                directions[boxDeviceId] ?? ArrowDirection.right,
                          );
                        },
                  ),
                ),
              ),

              //////////////////////////////////////////////////////////
              /// RIGHT CHART PANEL
              //////////////////////////////////////////////////////////
              // SizedBox(
              //   width: 270,
              //   child: MonthlyUtilityUsagePanel(
              //     fac: widget.facId,
              //     nameEn: 'TEST',
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef UpdateGroupPosition =
    Future<void> Function({
      required String boxDeviceId,
      required Offset position,
    });

typedef UpdateGroupDirection =
    Future<void> Function({
      required String boxDeviceId,
      required ArrowDirection direction,
    });

class _FacOverlayMapGroup extends StatefulWidget {
  final String facId;
  final Widget image;

  final List<String> boxDeviceIds;
  final Map<String, _DeviceViewData> devicesById;

  final Map<String, Offset> groupLayout;
  final Map<String, ArrowDirection> directions;
  final Map<String, Color> colors;

  final bool editMode;
  final String? editingBoxDeviceId;

  final ValueChanged<String?> onPickEditingDevice;
  final UpdateGroupPosition onUpdateGroupPosition;
  final UpdateGroupDirection onUpdateDirection;

  const _FacOverlayMapGroup({
    required this.facId,
    required this.image,
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
  State<_FacOverlayMapGroup> createState() {
    return _FacOverlayMapGroupState();
  }
}

class _FacOverlayMapGroupState extends State<_FacOverlayMapGroup> {
  final TransformationController _transformController =
      TransformationController();

  final FocusNode _focusNode = FocusNode();

  Size _realImageSize = ScadaStyle.imageFallbackSize;

  String? _hoveredBoxDeviceId;

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
      _resetMapState();
      _loadImageSize();
    }

    if (widget.editMode && _hoveredBoxDeviceId != null) {
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

  void _resetMapState() {
    _hoverTimer?.cancel();

    setState(() {
      _hoveredBoxDeviceId = null;
      _hoveringPanel = false;
      _lockViewer = false;
      _realImageSize = ScadaStyle.imageFallbackSize;
    });
  }

  Future<void> _loadImageSize() async {
    final imageProvider = AssetImage(
      'assets/images/${widget.facId.toLowerCase()}.png',
    );

    final completer = Completer<ImageInfo>();

    final stream = imageProvider.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (imageInfo, _) {
        stream.removeListener(listener);

        if (!completer.isCompleted) {
          completer.complete(imageInfo);
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
      final imageInfo = await completer.future;

      if (!mounted) return;

      setState(() {
        _realImageSize = Size(
          imageInfo.image.width.toDouble(),
          imageInfo.image.height.toDouble(),
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

    final boxDeviceId = widget.editingBoxDeviceId;

    if (boxDeviceId == null) {
      return KeyEventResult.ignored;
    }

    final direction = _keyboardDirection(event.logicalKey);

    if (direction == Offset.zero) {
      return KeyEventResult.ignored;
    }

    final currentPosition = _devicePosition(boxDeviceId);

    final nextPosition = _clampPosition(
      currentPosition + direction * _keyboardStep(),
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

  Offset _clampPosition(Offset position) {
    return Offset(position.dx.clamp(0.0, 1.0), position.dy.clamp(0.0, 1.0));
  }

  Offset _devicePosition(String boxDeviceId) {
    final savedPosition = widget.groupLayout[boxDeviceId];

    if (savedPosition != null) {
      return savedPosition;
    }

    final index = widget.boxDeviceIds.indexOf(boxDeviceId);

    return _autoPlace(index);
  }

  _DeviceViewData? _deviceOf(String boxDeviceId) {
    return widget.devicesById[boxDeviceId];
  }

  List<LatestSignalDto> _deviceSignals(String boxDeviceId) {
    return _deviceOf(boxDeviceId)?.signals ?? const <LatestSignalDto>[];
  }

  void _showHover(String boxDeviceId) {
    if (widget.editMode) return;

    final signals = _deviceSignals(boxDeviceId);

    if (signals.isEmpty) return;

    _hoverTimer?.cancel();

    if (_hoveredBoxDeviceId == boxDeviceId && _lockViewer) {
      return;
    }

    setState(() {
      _hoveredBoxDeviceId = boxDeviceId;
      _hoveringPanel = false;
      _lockViewer = true;
    });
  }

  void _clearHover() {
    _hoverTimer?.cancel();

    final alreadyCleared =
        _hoveredBoxDeviceId == null && !_hoveringPanel && !_lockViewer;

    if (alreadyCleared) return;

    setState(() {
      _hoveredBoxDeviceId = null;
      _hoveringPanel = false;
      _lockViewer = false;
    });
  }

  void _scheduleHideHover() {
    if (widget.editMode) return;

    _hoverTimer?.cancel();

    _hoverTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || _hoveringPanel) return;

      setState(() {
        _hoveredBoxDeviceId = null;
        _lockViewer = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);

        final imageRect = _coverRect(containerSize, _realImageSize);

        final overlayRect = Rect.fromLTWH(
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              _focusNode.requestFocus();
            },
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
                            for (final boxDeviceId in widget.boxDeviceIds)
                              _buildDeviceFrame(
                                boxDeviceId: boxDeviceId,
                                imageRect: overlayRect,
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
    final boxDeviceId = _hoveredBoxDeviceId;

    if (boxDeviceId == null) {
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
      category: device.category,
      onEnterPanel: () {
        _hoverTimer?.cancel();

        if (_hoveringPanel && _lockViewer) {
          return;
        }

        setState(() {
          _hoveringPanel = true;
          _lockViewer = true;
        });
      },
      onExitPanel: () {
        _hoveringPanel = false;
        _scheduleHideHover();
      },
    );
  }

  Widget _buildDeviceFrame({
    required String boxDeviceId,
    required Rect imageRect,
  }) {
    final position = _devicePosition(boxDeviceId);
    final device = _deviceOf(boxDeviceId);

    return Positioned(
      left: position.dx * imageRect.width,
      top: position.dy * imageRect.height,
      child: MouseRegion(
        cursor: widget.editMode
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) {
          _showHover(boxDeviceId);
        },
        onExit: (_) {
          _scheduleHideHover();
        },
        child: GroupFrame(
          boxDeviceId: boxDeviceId,
          scadaText: device?.scadaText ?? '',
          cate: device?.category,
          boxColor: widget.colors[boxDeviceId],
          hasAlarm: false,
          groupPos01: position,
          parentSize: imageRect.size,
          editMode: widget.editMode,
          isEditing: widget.editingBoxDeviceId == boxDeviceId,
          direction: widget.directions[boxDeviceId] ?? ArrowDirection.right,
          onTap: widget.editMode
              ? () {
                  _focusNode.requestFocus();

                  widget.onPickEditingDevice(boxDeviceId);
                }
              : null,
          onDragGroup01: widget.editMode
              ? (newPosition) {
                  return widget.onUpdateGroupPosition(
                    boxDeviceId: boxDeviceId,
                    position: newPosition,
                  );
                }
              : null,
        ),
      ),
    );
  }
}

class _DeviceViewData {
  final String boxDeviceId;

  final Set<String> categories;
  final Set<String> scadaIds;

  final List<LatestSignalDto> signals;

  _DeviceViewData({required this.boxDeviceId})
    : categories = <String>{},
      scadaIds = <String>{},
      signals = <LatestSignalDto>[];

  String? get category {
    final values =
        categories
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList()
          ..sort(_compareText);

    if (values.isEmpty) {
      return null;
    }

    return values.first;
  }

  String get scadaText {
    final values =
        scadaIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList()
          ..sort(_compareText);

    return values.join(', ');
  }
}

class _LatestTreeHelper {
  const _LatestTreeHelper._();

  static Map<String, _DeviceViewData> groupDevices(
    LatestFacilityDto? facility,
  ) {
    final grouped = <String, _DeviceViewData>{};

    if (facility == null) {
      return grouped;
    }

    for (final category in facility.categories) {
      for (final scada in category.scadas) {
        for (final box in scada.boxes) {
          for (final device in box.devices) {
            final boxDeviceId = _cleanText(device.boxDeviceId);

            if (boxDeviceId.isEmpty) {
              continue;
            }

            final group = grouped.putIfAbsent(
              boxDeviceId,
              () => _DeviceViewData(boxDeviceId: boxDeviceId),
            );

            final categoryName = _cleanText(category.cate);

            final scadaId = _cleanText(scada.scadaId);

            if (categoryName.isNotEmpty) {
              group.categories.add(categoryName);
            }

            if (scadaId.isNotEmpty) {
              group.scadaIds.add(scadaId);
            }

            group.signals.addAll(device.signals);
          }
        }
      }
    }

    for (final group in grouped.values) {
      group.signals.sort((first, second) {
        final nameCompare = _compareText(
          _signalName(first),
          _signalName(second),
        );

        if (nameCompare != 0) {
          return nameCompare;
        }

        return _compareText(
          _signalPlcAddress(first),
          _signalPlcAddress(second),
        );
      });
    }

    return grouped;
  }

  static DateTime? findLatestTime(Iterable<_DeviceViewData> devices) {
    DateTime? latest;

    for (final device in devices) {
      for (final signal in device.signals) {
        final recordedAt = _signalRecordedAt(signal);

        if (recordedAt == null) {
          continue;
        }

        if (latest == null || recordedAt.isAfter(latest)) {
          latest = recordedAt;
        }
      }
    }

    return latest;
  }
}

String _signalName(LatestSignalDto signal) {
  final nameEn = _cleanText(signal.nameEn);

  if (nameEn.isNotEmpty) {
    return nameEn;
  }

  return _signalPlcAddress(signal);
}

String _signalPlcAddress(LatestSignalDto signal) {
  return _cleanText(signal.plcAddress);
}

DateTime? _signalRecordedAt(LatestSignalDto signal) {
  final value = signal.recordedAt;

  if (value is DateTime) {
    return value;
  }

  return DateTime.tryParse(value.toString());
}

String _cleanText(Object? value) {
  return value?.toString().trim() ?? '';
}

int _compareText(String first, String second) {
  return first.trim().toLowerCase().compareTo(second.trim().toLowerCase());
}

String _formatTime(DateTime? time) {
  if (time == null) {
    return '—';
  }

  String pad(int value) {
    return value.toString().padLeft(2, '0');
  }

  return '${pad(time.hour)}:'
      '${pad(time.minute)}:'
      '${pad(time.second)}';
}

Offset _autoPlace(int index) {
  final safeIndex = index < 0 ? 0 : index;

  const columns = 4;

  const startX = 0.08;
  const startY = 0.08;

  const gapX = 0.22;
  const gapY = 0.12;

  final column = safeIndex % columns;
  final row = safeIndex ~/ columns;

  return Offset(
    (startX + column * gapX).clamp(0.02, 0.88),
    (startY + row * gapY).clamp(0.02, 0.88),
  );
}

Rect _coverRect(Size containerSize, Size imageSize) {
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    return Rect.fromLTWH(0, 0, containerSize.width, containerSize.height);
  }

  final scaleX = containerSize.width / imageSize.width;

  final scaleY = containerSize.height / imageSize.height;

  final scale = scaleX > scaleY ? scaleX : scaleY;

  final width = imageSize.width * scale;
  final height = imageSize.height * scale;

  return Rect.fromLTWH(
    (containerSize.width - width) / 2,
    (containerSize.height - height) / 2,
    width,
    height,
  );
}
