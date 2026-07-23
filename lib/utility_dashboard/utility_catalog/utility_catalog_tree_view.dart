import 'package:flutter/material.dart';

import '../utility_dashboard_overview/'
    'utility_dashboard_overview_models/latest_tree_response.dart';

class UtilityCatalogTreeView extends StatefulWidget {
  final List<LatestFacilityDto> items;
  final int dataVersion;

  final String keyword;
  final String? selectedFacility;
  final String? selectedCategory;
  final String? selectedScada;
  final String? selectedBox;
  final String? selectedStatus;

  const UtilityCatalogTreeView({
    super.key,
    required this.items,
    required this.dataVersion,
    this.keyword = '',
    this.selectedFacility,
    this.selectedCategory,
    this.selectedScada,
    this.selectedBox,
    this.selectedStatus,
  });

  @override
  State<UtilityCatalogTreeView> createState() => _UtilityCatalogTreeViewState();
}

class _UtilityCatalogTreeViewState extends State<UtilityCatalogTreeView> {
  final TextEditingController _factorySearchController =
      TextEditingController();

  final TextEditingController _signalSearchController = TextEditingController();

  final Set<String> _expandedKeys = <String>{};

  String _factoryKeyword = '';
  String _signalKeyword = '';

  _StructurePath? _selectedPath;

  int _signalPage = 0;

  static const int _signalPageSize = 20;
  static const Duration _staleDuration = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();

    _factorySearchController.addListener(_handleFactorySearch);

    _signalSearchController.addListener(_handleSignalSearch);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureInitialSelection();
    });
  }

  @override
  void didUpdateWidget(covariant UtilityCatalogTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final dataChanged = oldWidget.dataVersion != widget.dataVersion;

    final sourceChanged = !identical(oldWidget.items, widget.items);

    final filterChanged =
        oldWidget.keyword != widget.keyword ||
        oldWidget.selectedFacility != widget.selectedFacility ||
        oldWidget.selectedCategory != widget.selectedCategory ||
        oldWidget.selectedScada != widget.selectedScada ||
        oldWidget.selectedBox != widget.selectedBox ||
        oldWidget.selectedStatus != widget.selectedStatus;

    if (!dataChanged && !sourceChanged && !filterChanged) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (dataChanged || sourceChanged) {
        _syncSelectionWithLatestData();
      } else {
        _ensureInitialSelection();
      }
    });
  }

  void _syncSelectionWithLatestData() {
    if (!mounted) return;

    final currentPath = _selectedPath;

    // Chưa có selection thì chọn device đầu tiên.
    if (currentPath == null) {
      final firstPath = _findFirstPath(_sortedFacilities(widget.items));

      setState(() {
        _selectedPath = firstPath;
        _signalPage = 0;

        if (firstPath != null) {
          _expandPath(firstPath);
        }
      });

      return;
    }

    // Tìm đúng đường dẫn cũ nhưng lấy DTO mới từ API.
    final latestPath = _findLatestPath(
      facilityName: currentPath.facility.fac,
      categoryName: currentPath.category.cate,
      scadaId: currentPath.scada.scadaId,
      boxId: currentPath.box.boxId,
      deviceId: currentPath.device.boxDeviceId,
    );

    // Device cũ có thể đã bị xóa khỏi dữ liệu mới.
    final nextPath =
        latestPath ?? _findFirstPath(_sortedFacilities(widget.items));

    setState(() {
      _selectedPath = nextPath;
      _signalPage = 0;

      if (nextPath != null) {
        // Không clear expandedKeys để giữ các node đang mở.
        _expandPath(nextPath);
      }
    });
  }

  _StructurePath? _findLatestPath({
    required String facilityName,
    required String categoryName,
    required String scadaId,
    required String boxId,
    required String deviceId,
  }) {
    for (final facility in widget.items) {
      if (facility.fac != facilityName) {
        continue;
      }

      for (final category in facility.categories) {
        if (category.cate != categoryName) {
          continue;
        }

        for (final scada in category.scadas) {
          if (scada.scadaId != scadaId) {
            continue;
          }

          for (final box in scada.boxes) {
            if (box.boxId != boxId) {
              continue;
            }

            for (final device in box.devices) {
              if (device.boxDeviceId != deviceId) {
                continue;
              }

              return _StructurePath(
                facility: facility,
                category: category,
                scada: scada,
                box: box,
                device: device,
              );
            }
          }
        }
      }
    }

    return null;
  }

  List<LatestFacilityDto> _sortedFacilities(
    Iterable<LatestFacilityDto> source,
  ) {
    final result = List<LatestFacilityDto>.from(source);

    result.sort((first, second) {
      final firstOrder = _facilityOrder(first.fac);
      final secondOrder = _facilityOrder(second.fac);

      final orderCompare = firstOrder.compareTo(secondOrder);

      if (orderCompare != 0) {
        return orderCompare;
      }

      return first.fac.trim().toUpperCase().compareTo(
        second.fac.trim().toUpperCase(),
      );
    });

    return result;
  }

  int _facilityOrder(String facility) {
    final value = facility
        .trim()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    if (value == 'FAC_A' || value == 'A') {
      return 0;
    }

    if (value == 'FAC_B' || value == 'B') {
      return 1;
    }

    if (value == 'FAC_C' || value == 'C') {
      return 2;
    }

    if (value == 'KVH') {
      return 3;
    }

    return 99;
  }

  @override
  void dispose() {
    _factorySearchController.removeListener(_handleFactorySearch);

    _signalSearchController.removeListener(_handleSignalSearch);

    _factorySearchController.dispose();
    _signalSearchController.dispose();

    super.dispose();
  }

  void _handleFactorySearch() {
    final value = _factorySearchController.text.trim().toLowerCase();

    if (value == _factoryKeyword) {
      return;
    }

    setState(() {
      _factoryKeyword = value;
    });
  }

  void _handleSignalSearch() {
    final value = _signalSearchController.text.trim().toLowerCase();

    if (value == _signalKeyword) {
      return;
    }

    setState(() {
      _signalKeyword = value;
      _signalPage = 0;
    });
  }

  // ============================================================
  // INITIAL SELECTION
  // ============================================================

  void _ensureInitialSelection() {
    if (!mounted) return;

    final currentPath = _selectedPath;

    if (currentPath != null) {
      final latestPath = _findLatestPath(
        facilityName: currentPath.facility.fac,
        categoryName: currentPath.category.cate,
        scadaId: currentPath.scada.scadaId,
        boxId: currentPath.box.boxId,
        deviceId: currentPath.device.boxDeviceId,
      );

      if (latestPath != null) {
        setState(() {
          _selectedPath = latestPath;
        });

        return;
      }
    }

    final firstPath = _findFirstPath(_sortedFacilities(widget.items));

    setState(() {
      _selectedPath = firstPath;
      _signalPage = 0;

      if (firstPath != null) {
        _expandedKeys.clear();
        _expandPath(firstPath);
      }
    });
  }

  bool _pathStillExists(_StructurePath path) {
    for (final facility in widget.items) {
      if (facility.fac != path.facility.fac) {
        continue;
      }

      for (final category in facility.categories) {
        if (category.cate != path.category.cate) {
          continue;
        }

        for (final scada in category.scadas) {
          if (scada.scadaId != path.scada.scadaId) {
            continue;
          }

          for (final box in scada.boxes) {
            if (box.boxId != path.box.boxId) {
              continue;
            }

            for (final device in box.devices) {
              if (device.boxDeviceId == path.device.boxDeviceId) {
                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  _StructurePath? _findFirstPath(List<LatestFacilityDto> facilities) {
    for (final facility in facilities) {
      for (final category in facility.categories) {
        for (final scada in category.scadas) {
          for (final box in scada.boxes) {
            for (final device in box.devices) {
              return _StructurePath(
                facility: facility,
                category: category,
                scada: scada,
                box: box,
                device: device,
              );
            }
          }
        }
      }
    }

    return null;
  }

  void _selectPath(_StructurePath path) {
    setState(() {
      _selectedPath = path;
      _signalPage = 0;

      _expandPath(path);
    });
  }

  void _expandPath(_StructurePath path) {
    _expandedKeys
      ..add(_facilityKey(path.facility))
      ..add(_categoryKey(path.facility, path.category))
      ..add(_scadaKey(path.facility, path.category, path.scada))
      ..add(_boxKey(path.facility, path.category, path.scada, path.box))
      ..add(
        _deviceKey(
          path.facility,
          path.category,
          path.scada,
          path.box,
          path.device,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const _TreeEmptyState();
    }

    final path = _selectedPath;

    final rawSignals = path?.device.signals ?? const <LatestSignalDto>[];

    final filteredSignals = _filterSignals(rawSignals);

    final pageCount = _pageCount(filteredSignals.length);

    final safePage = _signalPage.clamp(0, pageCount - 1).toInt();

    final start = safePage * _signalPageSize;

    final end = (start + _signalPageSize)
        .clamp(0, filteredSignals.length)
        .toInt();

    final pagedSignals = start >= filteredSignals.length
        ? const <LatestSignalDto>[]
        : filteredSignals.sublist(start, end);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07111F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF20344D)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(width: 285, child: _buildNavigationPanel()),

          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: Color(0xFF20344D),
          ),

          Expanded(
            child: Column(
              children: [
                _buildBreadcrumb(path),

                Expanded(flex: 4, child: _buildStructurePanel(path)),

                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFF20344D),
                ),

                Expanded(
                  flex: 5,
                  child: _buildSignalsPanel(
                    signals: filteredSignals,
                    pagedSignals: pagedSignals,
                    pageCount: pageCount,
                    safePage: safePage,
                    start: start,
                    end: end,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LEFT NAVIGATION
  // ============================================================

  Widget _buildNavigationPanel() {
    final facilities = _filteredFacilitiesForNavigation();

    return Container(
      color: const Color(0xFF081321),
      child: Column(
        children: [
          _NavigationHeader(facilityCount: widget.items.length),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: _SearchBox(
              controller: _factorySearchController,
              hintText: 'Search factory...',
              onClear: () {
                _factorySearchController.clear();
              },
            ),
          ),

          _buildFacilityQuickList(facilities),

          const Divider(height: 1, color: Color(0xFF20344D)),

          Expanded(
            child: facilities.isEmpty
                ? const _NavigationEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: facilities.length,
                    itemBuilder: (context, index) {
                      return _buildFacilityTree(facilities[index]);
                    },
                  ),
          ),

          _buildNavigationFooter(),
        ],
      ),
    );
  }

  Widget _buildFacilityQuickList(List<LatestFacilityDto> facilities) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        itemCount: facilities.length,
        itemBuilder: (context, index) {
          final facility = facilities[index];

          final selected = _selectedPath?.facility.fac == facility.fac;

          final status = _facilityStatus(facility);

          return _FacilityQuickTile(
            facility: facility.fac,
            selected: selected,
            status: status,
            onTap: () {
              final firstPath = _findFirstPath([facility]);

              if (firstPath == null) {
                return;
              }

              setState(() {
                _selectedPath = firstPath;
                _signalPage = 0;

                _expandedKeys.clear();
                _expandPath(firstPath);
              });
            },
          );
        },
      ),
    );
  }

  List<LatestCategoryDto> _sortedCategories(
    Iterable<LatestCategoryDto> source,
  ) {
    final result = List<LatestCategoryDto>.from(source);

    result.sort((first, second) {
      final orderCompare = _categoryOrder(
        first.cate,
      ).compareTo(_categoryOrder(second.cate));

      if (orderCompare != 0) {
        return orderCompare;
      }

      return first.cate.compareTo(second.cate);
    });

    return result;
  }

  List<LatestScadaDto> _sortedScadas(Iterable<LatestScadaDto> source) {
    final result = List<LatestScadaDto>.from(source);

    result.sort(
      (first, second) => _naturalCompare(first.scadaId, second.scadaId),
    );

    return result;
  }

  List<LatestBoxDto> _sortedBoxes(Iterable<LatestBoxDto> source) {
    final result = List<LatestBoxDto>.from(source);

    result.sort((first, second) => _naturalCompare(first.boxId, second.boxId));

    return result;
  }

  List<LatestDeviceDto> _sortedDevices(Iterable<LatestDeviceDto> source) {
    final result = List<LatestDeviceDto>.from(source);

    result.sort(
      (first, second) => _naturalCompare(first.boxDeviceId, second.boxDeviceId),
    );

    return result;
  }

  int _naturalCompare(String first, String second) {
    final expression = RegExp(r'^(.*?)(\d+)$');

    final firstMatch = expression.firstMatch(first.trim());

    final secondMatch = expression.firstMatch(second.trim());

    if (firstMatch == null || secondMatch == null) {
      return first.trim().toUpperCase().compareTo(second.trim().toUpperCase());
    }

    final prefixCompare = firstMatch
        .group(1)!
        .toUpperCase()
        .compareTo(secondMatch.group(1)!.toUpperCase());

    if (prefixCompare != 0) {
      return prefixCompare;
    }

    final firstNumber = int.tryParse(firstMatch.group(2)!) ?? 0;

    final secondNumber = int.tryParse(secondMatch.group(2)!) ?? 0;

    return firstNumber.compareTo(secondNumber);
  }

  int _categoryOrder(String category) {
    final value = category.trim().toUpperCase();

    if (value.contains('ELECTRIC')) {
      return 0;
    }

    if (value.contains('WATER')) {
      return 1;
    }

    if (value.contains('AIR') || value.contains('COMPRESSED')) {
      return 2;
    }

    return 99;
  }

  Widget _buildFacilityTree(LatestFacilityDto facility) {
    final key = _facilityKey(facility);
    final expanded = _expandedKeys.contains(key);

    return _TreeExpansionNode(
      key: ValueKey(key),
      depth: 0,
      title: facility.fac,
      subtitle: '${_countFacilityDevices(facility)} devices',
      icon: Icons.factory_rounded,
      color: const Color(0xFF60A5FA),
      expanded: expanded,
      trailingText: '${facility.categories.length}',
      onTap: () {
        _toggleExpanded(key);
      },
      children: expanded
          ? _sortedCategories(facility.categories).map((category) {
              return _buildCategoryTree(facility, category);
            }).toList()
          : const [],
    );
  }

  Widget _buildCategoryTree(
    LatestFacilityDto facility,
    LatestCategoryDto category,
  ) {
    final key = _categoryKey(facility, category);

    final expanded = _expandedKeys.contains(key);
    final style = _categoryStyle(category.cate);

    final deviceCount = _countCategoryDevices(category);

    return _TreeExpansionNode(
      key: ValueKey(key),
      depth: 1,
      title: _categoryLabel(category.cate),
      subtitle: '$deviceCount devices',
      icon: style.icon,
      color: style.color,
      expanded: expanded,
      trailingText: '${category.scadas.length}',
      onTap: () {
        _toggleExpanded(key);
      },
      children: expanded
          ? _sortedScadas(category.scadas).map((scada) {
              return _buildScadaTree(facility, category, scada);
            }).toList()
          : const [],
    );
  }

  Widget _buildScadaTree(
    LatestFacilityDto facility,
    LatestCategoryDto category,
    LatestScadaDto scada,
  ) {
    final key = _scadaKey(facility, category, scada);

    final expanded = _expandedKeys.contains(key);

    return _TreeExpansionNode(
      key: ValueKey(key),
      depth: 2,
      title: scada.scadaId,
      subtitle: '${scada.boxes.length} boxes',
      icon: Icons.dns_rounded,
      color: const Color(0xFF8B5CF6),
      expanded: expanded,
      trailingText: '${_countScadaDevices(scada)}',
      onTap: () {
        _toggleExpanded(key);
      },
      children: expanded
          ? _sortedBoxes(scada.boxes).map((box) {
              return _buildBoxTree(facility, category, scada, box);
            }).toList()
          : const [],
    );
  }

  Widget _buildBoxTree(
    LatestFacilityDto facility,
    LatestCategoryDto category,
    LatestScadaDto scada,
    LatestBoxDto box,
  ) {
    final key = _boxKey(facility, category, scada, box);

    final expanded = _expandedKeys.contains(key);

    return _TreeExpansionNode(
      key: ValueKey(key),
      depth: 3,
      title: box.boxId,
      subtitle: '${box.devices.length} devices',
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFF3B82F6),
      expanded: expanded,
      trailingText: '${box.devices.length}',
      onTap: () {
        _toggleExpanded(key);
      },
      children: expanded
          ? _sortedDevices(box.devices).map((device) {
              return _buildDeviceTree(facility, category, scada, box, device);
            }).toList()
          : const [],
    );
  }

  Widget _buildDeviceTree(
    LatestFacilityDto facility,
    LatestCategoryDto category,
    LatestScadaDto scada,
    LatestBoxDto box,
    LatestDeviceDto device,
  ) {
    final key = _deviceKey(facility, category, scada, box, device);

    final expanded = _expandedKeys.contains(key);

    final path = _StructurePath(
      facility: facility,
      category: category,
      scada: scada,
      box: box,
      device: device,
    );

    final selected = _samePath(_selectedPath, path);

    final status = _deviceStatus(device);
    final statusColor = _statusColor(status);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DeviceTreeTile(
          depth: 4,
          device: device,
          selected: selected,
          expanded: expanded,
          statusColor: statusColor,
          onTap: () {
            _selectPath(path);
          },
          onExpandTap: () {
            _toggleExpanded(key);
          },
        ),

        if (expanded) _buildSignalTree(path),
      ],
    );
  }

  Widget _buildSignalTree(_StructurePath path) {
    return Padding(
      padding: const EdgeInsets.only(left: 52, right: 8, bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF091625),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF182C43)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                children: [
                  const Icon(
                    Icons.show_chart_rounded,
                    size: 14,
                    color: Color(0xFF60A5FA),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Signals (${path.device.signals.length})',
                    style: const TextStyle(
                      color: Color(0xFFB8C7D9),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            for (var index = 0; index < path.device.signals.length; index++)
              _NavigationSignalTile(
                signal: path.device.signals[index],
                selected:
                    _selectedPath != null && _samePath(_selectedPath, path),
                onTap: () {
                  _selectPath(path);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationFooter() {
    final counts = _summaryCounts(widget.items);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2B),
        border: Border(top: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          _FooterStatus(
            label: 'Online',
            value: counts.online,
            color: const Color(0xFF22C55E),
          ),
          const SizedBox(width: 12),
          _FooterStatus(
            label: 'Warning',
            value: counts.warning,
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 12),
          _FooterStatus(
            label: 'Offline',
            value: counts.offline,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (!_expandedKeys.add(key)) {
        _expandedKeys.remove(key);
      }
    });
  }

  // ============================================================
  // BREADCRUMB
  // ============================================================

  Widget _buildBreadcrumb(_StructurePath? path) {
    final parts = <String>[
      if (path != null) path.facility.fac,
      if (path != null) _categoryLabel(path.category.cate),
      if (path != null) path.scada.scadaId,
      if (path != null) path.box.boxId,
      if (path != null) path.device.boxDeviceId,
    ];

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2B),
        border: Border(bottom: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          for (var index = 0; index < parts.length; index++) ...[
            Flexible(
              child: Text(
                parts[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: index == parts.length - 1
                      ? const Color(0xFF67E8F9)
                      : const Color(0xFFB8C7D9),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            if (index < parts.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: Color(0xFF526A84),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SYSTEM STRUCTURE
  // ============================================================

  Widget _buildStructurePanel(_StructurePath? path) {
    if (path == null) {
      return const _StructureEmptyState();
    }

    return Container(
      color: const Color(0xFF081321),
      child: Column(
        children: [
          const _PanelTitle(
            title: 'SYSTEM STRUCTURE',
            icon: Icons.account_tree_rounded,
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth - 36,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StructureCard(
                          typeLabel: 'Factory',
                          title: path.facility.fac,
                          icon: Icons.factory_rounded,
                          color: const Color(0xFF3B82F6),
                          status: _facilityStatus(path.facility),
                        ),

                        const _ConnectionArrow(),

                        _StructureCard(
                          typeLabel: 'Category',
                          title: _categoryLabel(path.category.cate),
                          icon: _categoryStyle(path.category.cate).icon,
                          color: _categoryStyle(path.category.cate).color,
                          status: _categoryStatus(path.category),
                        ),

                        const _ConnectionArrow(),

                        _StructureCard(
                          typeLabel: 'SCADA',
                          title: path.scada.scadaId,
                          icon: Icons.dns_rounded,
                          color: const Color(0xFF8B5CF6),
                          status: _scadaStatus(path.scada),
                        ),

                        const _ConnectionArrow(),

                        _StructureCard(
                          typeLabel: 'Box',
                          title: path.box.boxId,
                          icon: Icons.inventory_2_rounded,
                          color: const Color(0xFF2563EB),
                          status: _boxStatus(path.box),
                        ),

                        const _ConnectionArrow(),

                        _StructureCard(
                          width: 220,
                          typeLabel: 'Device',
                          title: path.device.boxDeviceId,
                          icon: Icons.developer_board_rounded,
                          color: const Color(0xFF14B8A6),
                          status: _deviceStatus(path.device),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const _StructureLegend(),
        ],
      ),
    );
  }

  // ============================================================
  // SIGNALS PANEL
  // ============================================================

  Widget _buildSignalsPanel({
    required List<LatestSignalDto> signals,
    required List<LatestSignalDto> pagedSignals,
    required int pageCount,
    required int safePage,
    required int start,
    required int end,
  }) {
    return Container(
      color: const Color(0xFF07111F),
      child: Column(
        children: [
          _SignalsToolbar(
            signalCount: signals.length,
            controller: _signalSearchController,
          ),

          const _SignalTableHeader(),

          Expanded(
            child: pagedSignals.isEmpty
                ? const _SignalsEmptyState()
                : ListView.separated(
                    itemCount: pagedSignals.length,
                    separatorBuilder: (_, __) {
                      return const Divider(height: 1, color: Color(0xFF20344D));
                    },
                    itemBuilder: (context, index) {
                      return _SignalTableRow(
                        signal: pagedSignals[index],
                        isEven: index.isEven,
                      );
                    },
                  ),
          ),

          _SignalPagination(
            total: signals.length,
            start: signals.isEmpty ? 0 : start + 1,
            end: end,
            currentPage: safePage,
            pageCount: pageCount,
            pageSize: _signalPageSize,
            onPrevious: safePage <= 0
                ? null
                : () {
                    setState(() {
                      _signalPage--;
                    });
                  },
            onNext: safePage >= pageCount - 1
                ? null
                : () {
                    setState(() {
                      _signalPage++;
                    });
                  },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================
  List<LatestFacilityDto> get _sortedItems {
    final result = List<LatestFacilityDto>.from(widget.items);

    result.sort((first, second) {
      final firstOrder = _facilityOrder(first.fac);
      final secondOrder = _facilityOrder(second.fac);

      final orderCompare = firstOrder.compareTo(secondOrder);

      if (orderCompare != 0) {
        return orderCompare;
      }

      return first.fac.trim().toUpperCase().compareTo(
        second.fac.trim().toUpperCase(),
      );
    });

    return result;
  }

  List<LatestFacilityDto> _filteredFacilitiesForNavigation() {
    final source = _sortedItems;

    if (_factoryKeyword.isEmpty) {
      return source;
    }

    return source.where((facility) {
      final searchText = <String>[
        facility.fac,

        for (final category in facility.categories) category.cate,

        for (final category in facility.categories)
          for (final scada in category.scadas) scada.scadaId,

        for (final category in facility.categories)
          for (final scada in category.scadas)
            for (final box in scada.boxes) box.boxId,

        for (final category in facility.categories)
          for (final scada in category.scadas)
            for (final box in scada.boxes)
              for (final device in box.devices) device.boxDeviceId,
      ].join('|').toLowerCase();

      return searchText.contains(_factoryKeyword);
    }).toList();
  }

  List<LatestSignalDto> _filterSignals(List<LatestSignalDto> source) {
    if (_signalKeyword.isEmpty) {
      return List<LatestSignalDto>.from(source);
    }

    return source.where((signal) {
      final text = [
        signal.plcAddress,
        signal.cateId,
        signal.nameEn,
        signal.unit,
        signal.value?.toString() ?? '',
        _isStale(signal.recordedAt) ? 'stale' : 'online',
      ].join('|').toLowerCase();

      return text.contains(_signalKeyword);
    }).toList();
  }

  // ============================================================
  // STATUS
  // ============================================================

  _StructureStatus _facilityStatus(LatestFacilityDto facility) {
    final statuses = <_StructureStatus>[];

    for (final category in facility.categories) {
      statuses.add(_categoryStatus(category));
    }

    return _mergeStatuses(statuses);
  }

  _StructureStatus _categoryStatus(LatestCategoryDto category) {
    return _mergeStatuses(
      _sortedScadas(category.scadas).map(_scadaStatus).toList(),
    );
  }

  _StructureStatus _scadaStatus(LatestScadaDto scada) {
    return _mergeStatuses(_sortedBoxes(scada.boxes).map(_boxStatus).toList());
  }

  _StructureStatus _boxStatus(LatestBoxDto box) {
    return _mergeStatuses(
      _sortedDevices(box.devices).map(_deviceStatus).toList(),
    );
  }

  _StructureStatus _deviceStatus(LatestDeviceDto device) {
    if (device.signals.isEmpty) {
      return _StructureStatus.offline;
    }

    final staleCount = device.signals
        .where((signal) => _isStale(signal.recordedAt))
        .length;

    if (staleCount == 0) {
      return _StructureStatus.online;
    }

    if (staleCount == device.signals.length) {
      return _StructureStatus.offline;
    }

    return _StructureStatus.warning;
  }

  _StructureStatus _mergeStatuses(List<_StructureStatus> statuses) {
    if (statuses.isEmpty) {
      return _StructureStatus.offline;
    }

    if (statuses.every((status) => status == _StructureStatus.online)) {
      return _StructureStatus.online;
    }

    if (statuses.every((status) => status == _StructureStatus.offline)) {
      return _StructureStatus.offline;
    }

    return _StructureStatus.warning;
  }

  Color _statusColor(_StructureStatus status) {
    return switch (status) {
      _StructureStatus.online => const Color(0xFF22C55E),
      _StructureStatus.warning => Colors.orangeAccent,
      _StructureStatus.offline => Colors.redAccent,
    };
  }

  bool _isStale(DateTime? recordedAt) {
    if (recordedAt == null) {
      return true;
    }

    return DateTime.now().difference(recordedAt.toLocal()) > _staleDuration;
  }

  // ============================================================
  // COUNT
  // ============================================================

  int _countFacilityDevices(LatestFacilityDto facility) {
    var total = 0;

    for (final category in facility.categories) {
      total += _countCategoryDevices(category);
    }

    return total;
  }

  int _countCategoryDevices(LatestCategoryDto category) {
    var total = 0;

    for (final scada in category.scadas) {
      total += _countScadaDevices(scada);
    }

    return total;
  }

  int _countScadaDevices(LatestScadaDto scada) {
    var total = 0;

    for (final box in scada.boxes) {
      total += box.devices.length;
    }

    return total;
  }

  int _pageCount(int total) {
    if (total <= 0) {
      return 1;
    }

    return (total / _signalPageSize).ceil();
  }

  _NavigationSummary _summaryCounts(List<LatestFacilityDto> facilities) {
    var online = 0;
    var warning = 0;
    var offline = 0;

    for (final facility in facilities) {
      for (final category in facility.categories) {
        for (final scada in category.scadas) {
          for (final box in scada.boxes) {
            for (final device in box.devices) {
              switch (_deviceStatus(device)) {
                case _StructureStatus.online:
                  online++;
                  break;
                case _StructureStatus.warning:
                  warning++;
                  break;
                case _StructureStatus.offline:
                  offline++;
                  break;
              }
            }
          }
        }
      }
    }

    return _NavigationSummary(
      online: online,
      warning: warning,
      offline: offline,
    );
  }

  // ============================================================
  // KEYS
  // ============================================================

  String _facilityKey(LatestFacilityDto facility) {
    return 'FAC|${facility.fac}';
  }

  String _categoryKey(LatestFacilityDto facility, LatestCategoryDto category) {
    return ['CATE', facility.fac, category.cate].join('|');
  }

  String _scadaKey(
    LatestFacilityDto facility,
    LatestCategoryDto category,
    LatestScadaDto scada,
  ) {
    return ['SCADA', facility.fac, category.cate, scada.scadaId].join('|');
  }

  String _boxKey(
    LatestFacilityDto facility,
    LatestCategoryDto category,
    LatestScadaDto scada,
    LatestBoxDto box,
  ) {
    return [
      'BOX',
      facility.fac,
      category.cate,
      scada.scadaId,
      box.boxId,
    ].join('|');
  }

  String _deviceKey(
    LatestFacilityDto facility,
    LatestCategoryDto category,
    LatestScadaDto scada,
    LatestBoxDto box,
    LatestDeviceDto device,
  ) {
    return [
      'DEVICE',
      facility.fac,
      category.cate,
      scada.scadaId,
      box.boxId,
      device.boxDeviceId,
    ].join('|');
  }

  bool _samePath(_StructurePath? first, _StructurePath second) {
    if (first == null) {
      return false;
    }

    return first.facility.fac == second.facility.fac &&
        first.category.cate == second.category.cate &&
        first.scada.scadaId == second.scada.scadaId &&
        first.box.boxId == second.box.boxId &&
        first.device.boxDeviceId == second.device.boxDeviceId;
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  String _categoryLabel(String category) {
    final value = category.trim().toUpperCase();

    if (value.contains('ELECTRIC')) {
      return 'Electricity';
    }

    if (value.contains('WATER')) {
      return 'Water';
    }

    if (value.contains('AIR') || value.contains('COMPRESSED')) {
      return 'Compressed Air';
    }

    return category.trim().isEmpty ? 'Other' : category.trim();
  }

  _CategoryStyle _categoryStyle(String category) {
    final value = category.trim().toUpperCase();

    if (value.contains('ELECTRIC')) {
      return const _CategoryStyle(
        color: Color(0xFFF59E0B),
        icon: Icons.bolt_rounded,
      );
    }

    if (value.contains('WATER')) {
      return const _CategoryStyle(
        color: Color(0xFF06B6D4),
        icon: Icons.water_drop_rounded,
      );
    }

    if (value.contains('AIR') || value.contains('COMPRESSED')) {
      return const _CategoryStyle(
        color: Color(0xFF8B5CF6),
        icon: Icons.air_rounded,
      );
    }

    return const _CategoryStyle(
      color: Color(0xFF64748B),
      icon: Icons.category_rounded,
    );
  }
}

// ============================================================
// MODELS
// ============================================================

enum _StructureStatus { online, warning, offline }

class _StructurePath {
  final LatestFacilityDto facility;
  final LatestCategoryDto category;
  final LatestScadaDto scada;
  final LatestBoxDto box;
  final LatestDeviceDto device;

  const _StructurePath({
    required this.facility,
    required this.category,
    required this.scada,
    required this.box,
    required this.device,
  });
}

class _CategoryStyle {
  final Color color;
  final IconData icon;

  const _CategoryStyle({required this.color, required this.icon});
}

class _NavigationSummary {
  final int online;
  final int warning;
  final int offline;

  const _NavigationSummary({
    required this.online,
    required this.warning,
    required this.offline,
  });
}

// ============================================================
// LEFT PANEL
// ============================================================

class _NavigationHeader extends StatelessWidget {
  final int facilityCount;

  const _NavigationHeader({required this.facilityCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2B),
        border: Border(bottom: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          const Icon(Icons.factory_rounded, color: Color(0xFF60A5FA), size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'FACTORIES ($facilityCount)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: .45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onClear;

  const _SearchBox({
    required this.controller,
    required this.hintText,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 16,
            color: Color(0xFF64748B),
          ),
          suffixIcon: IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 14),
          ),
          filled: true,
          fillColor: const Color(0xFF07111F),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF20344D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF20344D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
          ),
        ),
      ),
    );
  }
}

class _FacilityQuickTile extends StatelessWidget {
  final String facility;
  final bool selected;
  final _StructureStatus status;
  final VoidCallback onTap;

  const _FacilityQuickTile({
    required this.facility,
    required this.selected,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _StructureStatus.online => const Color(0xFF22C55E),
      _StructureStatus.warning => Colors.orangeAccent,
      _StructureStatus.offline => Colors.redAccent,
    };

    final label = switch (status) {
      _StructureStatus.online => 'Online',
      _StructureStatus.warning => 'Warning',
      _StructureStatus.offline => 'Offline',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? const Color(0xFF123247) : const Color(0xFF0B1828),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF3B82F6).withOpacity(.45)
                    : Colors.white.withOpacity(.04),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.factory_rounded,
                  size: 16,
                  color: Color(0xFF60A5FA),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    facility,
                    style: const TextStyle(
                      color: Color(0xFFD2DEEC),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withOpacity(.22)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeExpansionNode extends StatelessWidget {
  final int depth;
  final String title;
  final String subtitle;

  final IconData icon;
  final Color color;

  final bool expanded;
  final String trailingText;

  final VoidCallback onTap;
  final List<Widget> children;

  const _TreeExpansionNode({
    super.key,
    required this.depth,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.expanded,
    required this.trailingText,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 38,
              padding: EdgeInsets.only(left: 8 + depth * 13, right: 8),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? .25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: Color(0xFF71869F),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC5D2E2),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '($trailingText)',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...children,
      ],
    );
  }
}

class _DeviceTreeTile extends StatelessWidget {
  final int depth;
  final LatestDeviceDto device;

  final bool selected;
  final bool expanded;

  final Color statusColor;

  final VoidCallback onTap;
  final VoidCallback onExpandTap;

  const _DeviceTreeTile({
    required this.depth,
    required this.device,
    required this.selected,
    required this.expanded,
    required this.statusColor,
    required this.onTap,
    required this.onExpandTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF123247) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: EdgeInsets.only(left: 8 + depth * 13, right: 8),
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    left: BorderSide(color: Color(0xFF22D3EE), width: 3),
                  )
                : null,
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onExpandTap,
                child: AnimatedRotation(
                  turns: expanded ? .25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: Color(0xFF71869F),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.developer_board_rounded,
                size: 15,
                color: Color(0xFF2DD4BF),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  device.boxDeviceId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC5D2E2),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '(${device.signals.length})',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationSignalTile extends StatelessWidget {
  final LatestSignalDto signal;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationSignalTile({
    required this.signal,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stale =
        signal.recordedAt == null ||
        DateTime.now().difference(signal.recordedAt!.toLocal()) >
            const Duration(minutes: 2);

    final color = stale ? Colors.orangeAccent : const Color(0xFF22C55E);

    final name = signal.nameEn.trim().isNotEmpty
        ? signal.nameEn.trim()
        : signal.cateId.trim().isNotEmpty
        ? signal.cateId.trim()
        : '--';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB8C7D9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      signal.plcAddress,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterStatus extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _FooterStatus({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          '$label $value',
          style: const TextStyle(
            color: Color(0xFF71869F),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// RIGHT STRUCTURE
// ============================================================

class _PanelTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PanelTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2B),
        border: Border(bottom: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF60A5FA), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: .45,
            ),
          ),
        ],
      ),
    );
  }
}

class _StructureCard extends StatelessWidget {
  final double width;

  final String typeLabel;
  final String title;

  final IconData icon;
  final Color color;

  final _StructureStatus status;

  const _StructureCard({
    this.width = 150,
    required this.typeLabel,
    required this.title,
    required this.icon,
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      _StructureStatus.online => const Color(0xFF22C55E),
      _StructureStatus.warning => Colors.orangeAccent,
      _StructureStatus.offline => Colors.redAccent,
    };

    final statusText = switch (status) {
      _StructureStatus.online => 'Online',
      _StructureStatus.warning => 'Warning',
      _StructureStatus.offline => 'Offline',
    };

    return SizedBox(
      width: width,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1828),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(.50)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 54,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: const TextStyle(
                      color: Color(0xFF71869F),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withOpacity(.22)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionArrow extends StatelessWidget {
  const _ConnectionArrow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 38,
      child: Row(
        children: [
          Expanded(child: Divider(thickness: 1.5, color: Color(0xFF3B82F6))),
          Icon(Icons.arrow_right_rounded, size: 18, color: Color(0xFF3B82F6)),
        ],
      ),
    );
  }
}

class _StructureLegend extends StatelessWidget {
  const _StructureLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF20344D))),
      ),
      child: const Row(
        children: [
          _LegendItem(label: 'Factory', color: Color(0xFF3B82F6)),
          SizedBox(width: 16),
          _LegendItem(label: 'Category', color: Color(0xFFF59E0B)),
          SizedBox(width: 16),
          _LegendItem(label: 'SCADA', color: Color(0xFF8B5CF6)),
          SizedBox(width: 16),
          _LegendItem(label: 'Box', color: Color(0xFF2563EB)),
          SizedBox(width: 16),
          _LegendItem(label: 'Device', color: Color(0xFF14B8A6)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF71869F),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SIGNALS
// ============================================================

class _SignalsToolbar extends StatelessWidget {
  final int signalCount;
  final TextEditingController controller;

  const _SignalsToolbar({required this.signalCount, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2B),
        border: Border(bottom: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.show_chart_rounded,
            color: Color(0xFF60A5FA),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'SIGNALS ($signalCount)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 240,
            child: _SearchBox(
              controller: controller,
              hintText: 'Search signals...',
              onClear: controller.clear,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalTableHeader extends StatelessWidget {
  const _SignalTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: const Color(0xFF102033),
      child: const Row(
        children: [
          _SignalHeaderCell(width: 70, text: 'STATUS'),
          _SignalHeaderCell(width: 105, text: 'PLC ADDRESS'),
          _SignalHeaderCell(width: 105, text: 'CATEGORY ID'),
          _SignalHeaderCell(flex: 2, text: 'NAME (EN)'),
          _SignalHeaderCell(width: 110, text: 'VALUE'),
          _SignalHeaderCell(width: 70, text: 'UNIT'),
          _SignalHeaderCell(width: 165, text: 'RECORDED AT'),
        ],
      ),
    );
  }
}

class _SignalHeaderCell extends StatelessWidget {
  final double? width;
  final int? flex;
  final String text;

  const _SignalHeaderCell({required this.text, this.width, this.flex});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .3,
        ),
      ),
    );

    if (flex != null) {
      return Expanded(flex: flex!, child: content);
    }

    return SizedBox(width: width, child: content);
  }
}

class _SignalTableRow extends StatelessWidget {
  final LatestSignalDto signal;
  final bool isEven;

  const _SignalTableRow({required this.signal, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final stale =
        signal.recordedAt == null ||
        DateTime.now().difference(signal.recordedAt!.toLocal()) >
            const Duration(minutes: 2);

    final statusColor = stale ? Colors.orangeAccent : const Color(0xFF22C55E);

    final name = signal.nameEn.trim().isNotEmpty
        ? signal.nameEn.trim()
        : signal.cateId.trim().isNotEmpty
        ? signal.cateId.trim()
        : '--';

    final valueText = signal.value == null
        ? '--'
        : signal.value!.abs() >= 1000
        ? signal.value!.toStringAsFixed(2)
        : signal.value!.toStringAsFixed(2);

    return Container(
      height: 44,
      color: isEven ? const Color(0xFF081321) : const Color(0xFF0A1625),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
            ),
          ),
          _SignalValueCell(width: 105, text: signal.plcAddress),
          _SignalValueCell(width: 105, text: signal.cateId),
          _SignalValueCell(flex: 2, text: name, color: Colors.white),
          _SignalValueCell(
            width: 110,
            text: valueText,
            color: const Color(0xFF3B82F6),
            fontWeight: FontWeight.w900,
          ),
          _SignalValueCell(width: 70, text: signal.unit),
          _SignalValueCell(
            width: 165,
            text: _formatDateTime(signal.recordedAt),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '--';
    }

    final local = value.toLocal();

    String two(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${local.year}-'
        '${two(local.month)}-'
        '${two(local.day)} '
        '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}';
  }
}

class _SignalValueCell extends StatelessWidget {
  final double? width;
  final int? flex;

  final String text;
  final Color? color;
  final FontWeight? fontWeight;

  const _SignalValueCell({
    required this.text,
    this.width,
    this.flex,
    this.color,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Text(
        text.trim().isEmpty ? '--' : text.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? const Color(0xFFB8C7D9),
          fontSize: 14,
          fontWeight: fontWeight ?? FontWeight.w600,
        ),
      ),
    );

    if (flex != null) {
      return Expanded(flex: flex!, child: content);
    }

    return SizedBox(width: width, child: content);
  }
}

class _SignalPagination extends StatelessWidget {
  final int total;
  final int start;
  final int end;

  final int currentPage;
  final int pageCount;
  final int pageSize;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _SignalPagination({
    required this.total,
    required this.start,
    required this.end,
    required this.currentPage,
    required this.pageCount,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF091523),
        border: Border(top: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          Text(
            'Showing $start to $end of $total signals',
            style: const TextStyle(
              color: Color(0xFF71869F),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onPrevious,
            iconSize: 17,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Container(
            width: 32,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${currentPage + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            iconSize: 17,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF07111F),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF20344D)),
            ),
            child: Text(
              '$pageSize / page',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY STATES
// ============================================================

class _TreeEmptyState extends StatelessWidget {
  const _TreeEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No utility data',
        style: TextStyle(
          color: Color(0xFF71869F),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NavigationEmptyState extends StatelessWidget {
  const _NavigationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No factories found',
        style: TextStyle(
          color: Color(0xFF71869F),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StructureEmptyState extends StatelessWidget {
  const _StructureEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Select a device',
        style: TextStyle(
          color: Color(0xFF71869F),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SignalsEmptyState extends StatelessWidget {
  const _SignalsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors_off_rounded, color: Color(0xFF526A84), size: 32),
          SizedBox(height: 8),
          Text(
            'No signals found',
            style: TextStyle(
              color: Color(0xFF71869F),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
