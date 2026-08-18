import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utility_api/dio_client.dart';
import '../../../utility_state/latest_provider.dart';
import '../controllers/fac_detail_edit_controller.dart';
import '../helpers/fac_detail_formatters.dart';
import '../layout/fac_overlay_map.dart';
import '../layout/overlay_layout_store.dart';
import '../layout/scada_style.dart';
import '../mappers/fac_box_group_mapper.dart';
import '../mappers/latest_tree_device_mapper.dart';
import '../models/fac_box_view_data.dart';
import '../models/group_frame_types.dart';
import '../period/utility_period_overview_panel.dart';
import '../utility_period_api.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/scada_gradient.dart';
import '../widgets/top_header.dart';

// ============================================================
// FAC DETAIL BODY
// ============================================================

class FacDetailBody extends StatefulWidget {
  final String facId;

  const FacDetailBody({super.key, required this.facId});

  @override
  State<FacDetailBody> createState() {
    return _FacDetailBodyState();
  }
}

// ============================================================
// STATE
// ============================================================

class _FacDetailBodyState extends State<FacDetailBody> {
  // ============================================================
  // UTILITY TYPE
  // ============================================================

  static const String _electricity = 'ELECTRICITY';

  String _utilityType = _electricity;

  // ============================================================
  // PERIOD API
  //
  // Tạo 1 lần.
  // Không new UtilityPeriodApi trong build().
  // ============================================================

  late final UtilityPeriodApi _periodApi;

  // ============================================================
  // STORE
  // ============================================================

  OverlayGroupLayoutStore get _layoutStore {
    return context.read<OverlayGroupLayoutStore>();
  }

  FacDetailEditController get _editController {
    return context.read<FacDetailEditController>();
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _periodApi = UtilityPeriodApi(DioClient.dio);

    _refreshFacility();
  }

  // ============================================================
  // FAC CHANGE
  // ============================================================

  @override
  void didUpdateWidget(covariant FacDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId == widget.facId) {
      return;
    }

    _editController.reset();

    // Khi đổi FAC:
    // mặc định quay lại Electricity.
    _utilityType = _electricity;

    _refreshFacility();
  }

  // ============================================================
  // REFRESH LATEST FACILITY
  // ============================================================

  void _refreshFacility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(
        context.read<LatestProvider>().refreshFacility(
          widget.facId,
          silent: false,
        ),
      );
    });
  }

  // ============================================================
  // SET UTILITY
  // ============================================================

  void _setUtility(String value) {
    if (_utilityType == value) {
      return;
    }

    setState(() {
      _utilityType = value;
    });

    // Clear box utility cũ.
    _editController.clearSelection();
  }

  Map<String, FacBoxViewData> _filterBoxesByUtility(
    Map<String, FacBoxViewData> source,
  ) {
    final result = <String, FacBoxViewData>{};

    for (final entry in source.entries) {
      final box = entry.value;

      if (_isBoxForUtility(box: box, utilityType: _utilityType)) {
        result[entry.key] = box;
      }
    }

    return result;
  }

  bool _isBoxForUtility({
    required FacBoxViewData box,
    required String utilityType,
  }) {
    return (box.primaryCategory ?? '').trim().toUpperCase() ==
        utilityType.trim().toUpperCase();
  }

  // ============================================================
  // APP BAR UTILITY BUTTON
  //
  // Compact để không chiếm quá nhiều width.
  // ============================================================

  // ============================================================
  // COLOR
  //
  // Controller / Store vẫn dùng tên boxDeviceId,
  // nhưng key thực tế hiện tại là boxId.
  // ============================================================

  Future<void> _pickColor() async {
    final boxId = _editController.editingBoxDeviceId;

    if (boxId == null || boxId.trim().isEmpty) {
      return;
    }

    final color = await showDialog<Color>(
      context: context,

      builder: (_) {
        return const ColorPickerDialog();
      },
    );

    if (!mounted || color == null) {
      return;
    }

    await _layoutStore.setGroupColor(
      facId: widget.facId,

      boxDeviceId: boxId.trim(),

      color: color,
    );
  }

  // ============================================================
  // SAVE DIRECTION
  // ============================================================

  Future<void> _saveDirection({
    required String boxId,
    required ArrowDirection direction,
  }) async {
    final normalizedBoxId = boxId.trim();

    if (normalizedBoxId.isEmpty) {
      return;
    }

    // Local update trước
    _editController.setLocalDirection(normalizedBoxId, direction);

    final position = _layoutStore.groupLayoutOf(widget.facId)[normalizedBoxId];

    // Chưa từng save position:
    // chỉ giữ direction local.
    if (position == null) {
      return;
    }

    await _savePosition(
      boxId: normalizedBoxId,
      position: position,
      direction: direction,
    );
  }

  // ============================================================
  // SAVE POSITION
  // ============================================================

  Future<void> _savePosition({
    required String boxId,
    required Offset position,
    required ArrowDirection direction,
  }) {
    final normalizedBoxId = boxId.trim();

    if (normalizedBoxId.isEmpty) {
      return Future<void>.value();
    }

    return _layoutStore.setGroupPos(
      facId: widget.facId,

      // Store vẫn tên boxDeviceId,
      // nhưng key hiện tại = boxId.
      boxDeviceId: normalizedBoxId,

      pos01: position,

      direction: direction,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // PROVIDERS
    // ==========================================================

    final latestProvider = context.watch<LatestProvider>();

    final layoutStore = context.watch<OverlayGroupLayoutStore>();

    final editController = context.watch<FacDetailEditController>();

    // ==========================================================
    // LATEST FACILITY
    // ==========================================================

    final facility = latestProvider.facilityOf(widget.facId);

    // ==========================================================
    // TREE -> DEVICES
    // ==========================================================

    final devicesById = LatestTreeDeviceMapper.mapFacility(facility);

    // ==========================================================
    // DEVICE -> BOX
    //
    // Ví dụ:
    //
    // DB-01_ES35-SW
    // DB-01_TEMP
    // DB-01_POWER
    //
    // => DB-01
    // ==========================================================
    final allBoxesById = FacBoxGroupMapper.groupDevices(devicesById);

    // ============================================================
    // FILTER THEO UTILITY ĐANG CHỌN
    // ============================================================

    final boxesById = _filterBoxesByUtility(allBoxesById);

    final boxIds = FacBoxGroupMapper.sortedKeys(boxesById);

    // ==========================================================
    // LAST UPDATED
    // ==========================================================

    final lastUpdated = LatestTreeDeviceMapper.latestRecordedAt(
      devicesById.values,
    );

    // ==========================================================
    // LAYOUT
    // ==========================================================

    final savedDirections = layoutStore.groupDirectionOf(widget.facId);

    final directions = <String, ArrowDirection>{
      ...savedDirections,
      ...editController.localDirections,
    };

    final groupLayout = layoutStore.groupLayoutOf(widget.facId);

    final groupColors = layoutStore.groupColorOf(widget.facId);

    // ==========================================================
    // EDIT SELECT
    // ==========================================================

    _ensureEditingBox(controller: editController, boxIds: boxIds);

    final editingBoxId = editController.editingBoxDeviceId;

    // ==========================================================
    // SCREEN
    // ==========================================================

    return Scaffold(
      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: ScadaStyle.dark,

        elevation: 0,

        toolbarHeight: 60,

        titleSpacing: 0,

        leading: IconButton(
          tooltip: 'Back',

          icon: const Icon(Icons.arrow_back, color: Colors.white),

          onPressed: () {
            Navigator.of(context).pop();
          },
        ),

        title: TopHeader(
          // =========================================================
          // FAC
          // =========================================================
          facId: widget.facId,

          lastText: FacDetailFormatters.time(lastUpdated),

          // =========================================================
          // UTILITY
          // =========================================================
          utilityType: _utilityType,

          onUtilityChanged: _setUtility,

          // =========================================================
          // EDIT
          // =========================================================
          editMode: editController.editMode,

          onToggleEdit: editController.toggleEditMode,

          selectedDirection: editingBoxId == null
              ? ArrowDirection.right
              : directions[editingBoxId] ?? ArrowDirection.right,

          onPickColor: _pickColor,

          onChangeDirection: (direction) {
            final currentBoxId = editController.editingBoxDeviceId;

            if (currentBoxId == null) {
              return;
            }

            unawaited(
              _saveDirection(boxId: currentBoxId, direction: direction),
            );
          },
        ),
      ),

      // ========================================================
      // BODY
      //
      // Không còn utility selector ở đây.
      // ========================================================
      body: ScadaGradient(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              // ================================================
              // FACTORY MAP = 51%
              // ================================================

              final mapWidth = width * .51;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  // ===========================================
                  // LEFT
                  // FACTORY LAYOUT
                  // ===========================================
                  SizedBox(
                    width: mapWidth,

                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.10),

                        borderRadius: BorderRadius.circular(14),

                        border: Border.all(
                          color: Colors.white.withOpacity(.08),
                        ),
                      ),

                      clipBehavior: Clip.antiAlias,

                      child: FacOverlayMap(
                        facId: widget.facId,

                        boxIds: boxIds,

                        boxesById: boxesById,

                        groupLayout: groupLayout,

                        directions: directions,

                        colors: groupColors,

                        editMode: editController.editMode,

                        editingBoxId: editingBoxId,

                        // =====================================
                        // PICK BOX
                        // =====================================
                        onPickEditingBox: (boxId) {
                          editController.selectDevice(boxId);
                        },

                        // =====================================
                        // DIRECTION
                        // =====================================
                        onUpdateDirection:
                            ({required boxDeviceId, required direction}) {
                              return _saveDirection(
                                boxId: boxDeviceId,

                                direction: direction,
                              );
                            },

                        // =====================================
                        // POSITION
                        // =====================================
                        onUpdateGroupPosition:
                            ({required boxDeviceId, required position}) {
                              final boxId = boxDeviceId.trim();

                              final direction =
                                  directions[boxId] ?? ArrowDirection.right;

                              return _savePosition(
                                boxId: boxId,

                                position: position,

                                direction: direction,
                              );
                            },
                      ),
                    ),
                  ),

                  // ===========================================
                  // GAP
                  // ===========================================
                  const SizedBox(width: 2),

                  // ===========================================
                  // RIGHT
                  // UTILITY OVERVIEW
                  // ===========================================
                  Expanded(
                    child: UtilityPeriodOverviewPanel(
                      facId: widget.facId,

                      utilityType: _utilityType,

                      // Không tạo API mới mỗi build.
                      api: _periodApi,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AUTO SELECT BOX KHI BẬT EDIT
  // ============================================================

  void _ensureEditingBox({
    required FacDetailEditController controller,

    required List<String> boxIds,
  }) {
    if (!controller.editMode) {
      return;
    }

    if (controller.editingBoxDeviceId != null) {
      return;
    }

    if (boxIds.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      controller.ensureSelected(boxIds);
    });
  }
}
