import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../utility_state/latest_provider.dart';
import '../utility_dashboard_overview/utility_dashboard_overview_models/latest_tree_response.dart';

// ============================================================
// SCREEN
// ============================================================
enum UtilityCatalogViewMode { monitor, tree }

class UtilityCatalogTabsScreen extends StatefulWidget {
  const UtilityCatalogTabsScreen({super.key});

  @override
  State<UtilityCatalogTabsScreen> createState() =>
      _UtilityCatalogTabsScreenState();
}

class _UtilityCatalogTabsScreenState extends State<UtilityCatalogTabsScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  LatestProvider? _latestProvider;

  bool _requestedInitialLoad = false;

  String _keyword = '';
  String? _selectedFacility;
  String? _selectedCategory;
  String? _selectedScada;
  String? _selectedBox;
  String? _selectedStatus;

  String? _selectedTreeKey;
  String? _selectedDeviceKey;

  int _devicePage = 0;

  static const int _devicePageSize = 50;

  int _cachedDataVersion = -1;
  String _cachedFilterKey = '';

  List<_CatalogTableRow> _cachedRows = const [];

  String _deviceKey(_CatalogTableRow row) {
    return [
      row.facility,
      row.category,
      row.scadaId,
      row.boxId,
      row.boxDeviceId,
    ].join('|');
  }

  UtilityCatalogViewMode _viewMode = UtilityCatalogViewMode.monitor;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_handleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _requestedInitialLoad) {
        return;
      }

      _requestedInitialLoad = true;

      final provider = context.read<LatestProvider>();
      _latestProvider = provider;

      if (!provider.hasData && !provider.loading) {
        await provider.loadInitial();
      }

      if (!mounted) return;

      // Nếu màn hình này tự quản lý polling thì mở dòng này.
      // Nếu dashboard cha đã startPolling thì bỏ dòng này.
      provider.startPolling();
    });
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final next = _searchController.text.trim().toLowerCase();

      if (next == _keyword) return;

      setState(() {
        _keyword = next;
      });
    });
  }

  Future<void> _refresh() async {
    final provider = _latestProvider;

    if (provider == null || provider.loading || provider.refreshing) {
      return;
    }

    await provider.refreshAll();
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _keyword = '';
      _selectedFacility = null;
      _selectedCategory = null;
      _selectedScada = null;
      _selectedBox = null;
      _selectedStatus = null;

      _selectedTreeKey = null;
      _selectedDeviceKey = null;
      _devicePage = 0;
    });
  }

  List<_CatalogTableRow> _prepareRows(
    List<LatestFacilityDto> source,
    int dataVersion,
  ) {
    final filterKey = [
      _keyword,
      _selectedFacility ?? '',
      _selectedCategory ?? '',
      _selectedScada ?? '',
      _selectedBox ?? '',
      _selectedStatus ?? '',
    ].join('|');

    if (_cachedDataVersion == dataVersion && filterKey == _cachedFilterKey) {
      return _cachedRows;
    }

    _cachedDataVersion = dataVersion;
    _cachedFilterKey = filterKey;

    final rows = <_CatalogTableRow>[];
    final now = DateTime.now();

    for (final facility in source) {
      if (_selectedFacility != null && facility.fac != _selectedFacility) {
        continue;
      }

      final categories = List<LatestCategoryDto>.from(facility.categories)
        ..sort(
          (a, b) => _categoryOrder(a.cate).compareTo(_categoryOrder(b.cate)),
        );

      for (final category in categories) {
        final categoryLabel = _categoryLabel(category.cate);

        if (_selectedCategory != null && categoryLabel != _selectedCategory) {
          continue;
        }

        for (final scada in category.scadas) {
          if (_selectedScada != null && scada.scadaId != _selectedScada) {
            continue;
          }

          for (final box in scada.boxes) {
            if (_selectedBox != null && box.boxId != _selectedBox) {
              continue;
            }

            for (final device in box.devices) {
              for (final signal in device.signals) {
                final row = _CatalogTableRow(
                  facility: facility.fac,
                  category: categoryLabel,
                  rawCategory: category.cate,
                  scadaId: scada.scadaId,
                  boxId: box.boxId,
                  boxDeviceId: device.boxDeviceId,
                  plcAddress: signal.plcAddress,
                  cateId: signal.cateId,
                  signalName: signal.nameEn,
                  value: signal.value,
                  unit: signal.unit,
                  recordedAt: signal.recordedAt,
                );

                if (_selectedStatus != null &&
                    row.statusLabelAt(now) != _selectedStatus) {
                  continue;
                }

                if (!_matchesKeyword(row, _keyword, now)) {
                  continue;
                }

                rows.add(row);
              }
            }
          }
        }
      }
    }

    rows.sort(_compareRows);

    _cachedRows = List<_CatalogTableRow>.unmodifiable(rows);

    return _cachedRows;
  }

  bool _matchesKeyword(_CatalogTableRow row, String keyword, DateTime now) {
    if (keyword.isEmpty) {
      return true;
    }

    return row.searchTextAt(now).contains(keyword);
  }

  int _compareRows(_CatalogTableRow first, _CatalogTableRow second) {
    final facCompare = first.facility.compareTo(second.facility);

    if (facCompare != 0) return facCompare;

    final categoryCompare = _categoryOrder(
      first.category,
    ).compareTo(_categoryOrder(second.category));

    if (categoryCompare != 0) {
      return categoryCompare;
    }

    final scadaCompare = first.scadaId.compareTo(second.scadaId);

    if (scadaCompare != 0) return scadaCompare;

    final boxCompare = first.boxId.compareTo(second.boxId);

    if (boxCompare != 0) return boxCompare;

    final deviceCompare = first.boxDeviceId.compareTo(second.boxDeviceId);

    if (deviceCompare != 0) return deviceCompare;

    return _naturalCompare(first.plcAddress, second.plcAddress);
  }

  int _naturalCompare(String first, String second) {
    final exp = RegExp(r'^([A-Za-z]+)(\d+)$');

    final firstMatch = exp.firstMatch(first);
    final secondMatch = exp.firstMatch(second);

    if (firstMatch == null || secondMatch == null) {
      return first.compareTo(second);
    }

    final prefixCompare = firstMatch.group(1)!.compareTo(secondMatch.group(1)!);

    if (prefixCompare != 0) {
      return prefixCompare;
    }

    final firstNumber = int.tryParse(firstMatch.group(2)!) ?? 0;

    final secondNumber = int.tryParse(secondMatch.group(2)!) ?? 0;

    return firstNumber.compareTo(secondNumber);
  }

  List<String> _facilityOptions(List<LatestFacilityDto> source) {
    final values =
        source
            .map((item) => item.fac.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return values;
  }

  List<String> _categoryOptions(List<LatestFacilityDto> source) {
    final values = <String>{};

    for (final facility in source) {
      if (_selectedFacility != null && facility.fac != _selectedFacility) {
        continue;
      }

      for (final category in facility.categories) {
        values.add(_categoryLabel(category.cate));
      }
    }

    final result = values.toList()
      ..sort((a, b) => _categoryOrder(a).compareTo(_categoryOrder(b)));

    return result;
  }

  List<String> _scadaOptions(List<LatestFacilityDto> source) {
    final values = <String>{};

    for (final facility in source) {
      if (_selectedFacility != null && facility.fac != _selectedFacility) {
        continue;
      }

      for (final category in facility.categories) {
        final categoryLabel = _categoryLabel(category.cate);

        if (_selectedCategory != null && categoryLabel != _selectedCategory) {
          continue;
        }

        for (final scada in category.scadas) {
          final value = scada.scadaId.trim();

          if (value.isNotEmpty) {
            values.add(value);
          }
        }
      }
    }

    final result = values.toList()..sort(_naturalCompare);

    return result;
  }

  List<String> _boxOptions(List<LatestFacilityDto> source) {
    final values = <String>{};

    for (final facility in source) {
      if (_selectedFacility != null && facility.fac != _selectedFacility) {
        continue;
      }

      for (final category in facility.categories) {
        final categoryLabel = _categoryLabel(category.cate);

        if (_selectedCategory != null && categoryLabel != _selectedCategory) {
          continue;
        }

        for (final scada in category.scadas) {
          if (_selectedScada != null && scada.scadaId != _selectedScada) {
            continue;
          }

          for (final box in scada.boxes) {
            final value = box.boxId.trim();

            if (value.isNotEmpty) {
              values.add(value);
            }
          }
        }
      }
    }

    final result = values.toList()..sort(_naturalCompare);

    return result;
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

  List<_CatalogDeviceGroup> _buildDeviceGroups(List<_CatalogTableRow> rows) {
    final grouped = <String, List<_CatalogTableRow>>{};

    for (final row in rows) {
      final key = _deviceKey(row);

      grouped.putIfAbsent(key, () => <_CatalogTableRow>[]);

      grouped[key]!.add(row);
    }

    final result = grouped.entries.map((entry) {
      final signals = entry.value;
      final first = signals.first;

      signals.sort((a, b) {
        return _naturalCompare(a.plcAddress, b.plcAddress);
      });

      return _CatalogDeviceGroup(
        key: entry.key,
        facility: first.facility,
        category: first.category,
        scadaId: first.scadaId,
        boxId: first.boxId,
        boxDeviceId: first.boxDeviceId,
        signals: List<_CatalogTableRow>.unmodifiable(signals),
      );
    }).toList();

    result.sort((a, b) {
      final facCompare = a.facility.compareTo(b.facility);

      if (facCompare != 0) {
        return facCompare;
      }

      final categoryCompare = _categoryOrder(
        a.category,
      ).compareTo(_categoryOrder(b.category));

      if (categoryCompare != 0) {
        return categoryCompare;
      }

      final scadaCompare = _naturalCompare(a.scadaId, b.scadaId);

      if (scadaCompare != 0) {
        return scadaCompare;
      }

      return _naturalCompare(a.boxDeviceId, b.boxDeviceId);
    });

    return result;
  }

  String _treeKey({required String scadaId, required String boxId}) {
    return '$scadaId|$boxId';
  }

  List<_CatalogTreeGroup> _buildTreeGroups(List<_CatalogDeviceGroup> devices) {
    final grouped = <String, List<_CatalogDeviceGroup>>{};

    for (final device in devices) {
      final key = _treeKey(scadaId: device.scadaId, boxId: device.boxId);

      grouped.putIfAbsent(key, () => <_CatalogDeviceGroup>[]);

      grouped[key]!.add(device);
    }

    final result = <_CatalogTreeGroup>[];

    for (final entry in grouped.entries) {
      final devices = List<_CatalogDeviceGroup>.from(entry.value);

      if (devices.isEmpty) continue;

      devices.sort((first, second) {
        return _naturalCompare(first.boxDeviceId, second.boxDeviceId);
      });

      final first = devices.first;

      result.add(
        _CatalogTreeGroup(
          key: entry.key,
          scadaId: first.scadaId,
          boxId: first.boxId,
          devices: List<_CatalogDeviceGroup>.unmodifiable(devices),
        ),
      );
    }

    result.sort((first, second) {
      final scadaCompare = _naturalCompare(first.scadaId, second.scadaId);

      if (scadaCompare != 0) {
        return scadaCompare;
      }

      return _naturalCompare(first.boxId, second.boxId);
    });

    return result;
  }

  void _ensureSelections({
    required List<_CatalogTreeGroup> treeGroups,
    required List<_CatalogDeviceGroup> devices,
  }) {
    if (treeGroups.isEmpty) {
      if (_selectedTreeKey != null || _selectedDeviceKey != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          setState(() {
            _selectedTreeKey = null;
            _selectedDeviceKey = null;
            _devicePage = 0;
          });
        });
      }

      return;
    }

    final treeExists = treeGroups.any((item) => item.key == _selectedTreeKey);

    final nextTreeKey = treeExists ? _selectedTreeKey : treeGroups.first.key;

    final visibleDevices = devices.where((device) {
      return _treeKey(scadaId: device.scadaId, boxId: device.boxId) ==
          nextTreeKey;
    }).toList();

    final deviceExists = visibleDevices.any(
      (item) => item.key == _selectedDeviceKey,
    );

    final nextDeviceKey = deviceExists
        ? _selectedDeviceKey
        : visibleDevices.isEmpty
        ? null
        : visibleDevices.first.key;

    if (nextTreeKey == _selectedTreeKey &&
        nextDeviceKey == _selectedDeviceKey) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _selectedTreeKey = nextTreeKey;
        _selectedDeviceKey = nextDeviceKey;
        _devicePage = 0;
      });
    });
  }

  List<_CatalogDeviceGroup> _devicesForSelectedTree(
    List<_CatalogDeviceGroup> devices,
  ) {
    final selectedTreeKey = _selectedTreeKey;

    if (selectedTreeKey == null) {
      return const <_CatalogDeviceGroup>[];
    }

    return devices.where((device) {
      return _treeKey(scadaId: device.scadaId, boxId: device.boxId) ==
          selectedTreeKey;
    }).toList();
  }

  int _pageCount(int itemCount) {
    if (itemCount == 0) return 1;

    return (itemCount / _devicePageSize).ceil();
  }

  List<_CatalogDeviceGroup> _pagedDevices(List<_CatalogDeviceGroup> devices) {
    final pageCount = _pageCount(devices.length);

    final safePage = _devicePage.clamp(0, pageCount - 1);

    final start = safePage * _devicePageSize;

    if (start >= devices.length) {
      return const <_CatalogDeviceGroup>[];
    }

    final end = (start + _devicePageSize).clamp(0, devices.length);

    return devices.sublist(start, end);
  }

  DateTime? _latestTime(List<_CatalogTableRow> rows) {
    DateTime? latest;

    for (final row in rows) {
      final time = row.recordedAt;

      if (time == null) continue;

      if (latest == null || time.isAfter(latest)) {
        latest = time;
      }
    }

    return latest;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _searchController.removeListener(_handleSearchChanged);

    _searchController.dispose();

    // Chỉ stop nếu polling được start riêng tại screen.
    _latestProvider?.stopPolling();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<LatestProvider, _CatalogVm>(
      selector: (_, provider) {
        return _CatalogVm(
          loading: provider.loading,
          refreshing: provider.refreshing,
          error: provider.error,
          items: provider.items,
          dataVersion: provider.dataVersion,
        );
      },
      shouldRebuild: (previous, next) {
        return previous.loading != next.loading ||
            previous.refreshing != next.refreshing ||
            previous.error != next.error ||
            previous.dataVersion != next.dataVersion;
      },
      builder: (context, vm, _) {
        if (vm.loading && vm.items.isEmpty) {
          return const _CatalogLoadingState();
        }

        if (vm.error != null && vm.items.isEmpty) {
          return _CatalogErrorState(
            error: vm.error!,
            onRetry: context.read<LatestProvider>().loadInitial,
          );
        }

        final rows = _prepareRows(vm.items, vm.dataVersion);
        final allDevices = _buildDeviceGroups(rows);

        final treeGroups = _buildTreeGroups(allDevices);

        _ensureSelections(treeGroups: treeGroups, devices: allDevices);

        final devicesForTree = _devicesForSelectedTree(allDevices);

        final pagedDevices = _pagedDevices(devicesForTree);

        final selectedDevice = allDevices
            .cast<_CatalogDeviceGroup?>()
            .firstWhere(
              (item) => item?.key == _selectedDeviceKey,
              orElse: () => null,
            );

        final selectedSignals =
            selectedDevice?.signals ?? const <_CatalogTableRow>[];

        final dataSource = _CatalogDataSource(rows: selectedSignals);

        final summary = _CatalogSummary.fromRows(rows);

        final facilityOptions = _facilityOptions(vm.items);

        final categoryOptions = _categoryOptions(vm.items);

        final scadaOptions = _scadaOptions(vm.items);

        final boxOptions = _boxOptions(vm.items);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF06101D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF263D5D)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _SignalMonitorTopBar(
                refreshing: vm.refreshing,
                error: vm.error,
                summary: summary,
                lastUpdated: _latestTime(rows),
                onRefresh: _refresh,
              ),

              _SignalMonitorFilters(
                searchController: _searchController,
                facilityOptions: facilityOptions,
                categoryOptions: categoryOptions,
                scadaOptions: scadaOptions,
                boxOptions: boxOptions,
                selectedFacility: _selectedFacility,
                selectedCategory: _selectedCategory,
                selectedScada: _selectedScada,
                selectedBox: _selectedBox,
                selectedStatus: _selectedStatus,
                onFacilityChanged: (value) {
                  setState(() {
                    _selectedFacility = value;
                    _selectedCategory = null;
                    _selectedScada = null;
                    _selectedBox = null;

                    _selectedTreeKey = null;
                    _selectedDeviceKey = null;
                    _devicePage = 0;
                  });
                },
                onCategoryChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _selectedScada = null;
                    _selectedBox = null;

                    _selectedTreeKey = null;
                    _selectedDeviceKey = null;
                    _devicePage = 0;
                  });
                },
                onScadaChanged: (value) {
                  setState(() {
                    _selectedScada = value;
                    _selectedBox = null;

                    _selectedTreeKey = null;
                    _selectedDeviceKey = null;
                    _devicePage = 0;
                  });
                },
                onBoxChanged: (value) {
                  setState(() {
                    _selectedBox = value;

                    _selectedTreeKey = null;
                    _selectedDeviceKey = null;
                    _devicePage = 0;
                  });
                },
                onStatusChanged: (value) {
                  setState(() {
                    _selectedStatus = value;

                    _selectedDeviceKey = null;
                    _devicePage = 0;
                  });
                },
                onClearFilters: _clearFilters,
              ),

              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 230,
                      child: _ScadaBoxTreePanel(
                        groups: treeGroups,
                        selectedKey: _selectedTreeKey,
                        onSelected: (key) {
                          setState(() {
                            _selectedTreeKey = key;
                            _selectedDeviceKey = null;
                            _devicePage = 0;
                          });
                        },
                      ),
                    ),

                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Color(0xFF20344D),
                    ),

                    SizedBox(
                      width: 310,
                      child: _DeviceListPanel(
                        devices: pagedDevices,
                        selectedDeviceKey: _selectedDeviceKey,
                        totalDevices: devicesForTree.length,
                        currentPage: _devicePage,
                        pageSize: _devicePageSize,
                        onSelected: (key) {
                          setState(() {
                            _selectedDeviceKey = key;
                          });
                        },
                      ),
                    ),

                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Color(0xFF20344D),
                    ),

                    Expanded(
                      child: _DeviceSignalDetail(
                        device: selectedDevice,
                        dataSource: dataSource,
                      ),
                    ),
                  ],
                ),
              ),

              _DevicePaginationBar(
                totalItems: devicesForTree.length,
                currentPage: _devicePage,
                pageSize: _devicePageSize,
                onPrevious: _devicePage <= 0
                    ? null
                    : () {
                        setState(() {
                          _devicePage--;
                          _selectedDeviceKey = null;
                        });
                      },
                onNext: _devicePage >= _pageCount(devicesForTree.length) - 1
                    ? null
                    : () {
                        setState(() {
                          _devicePage++;
                          _selectedDeviceKey = null;
                        });
                      },
                onPageSelected: (page) {
                  setState(() {
                    _devicePage = page;
                    _selectedDeviceKey = null;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// VIEW MODEL
// ============================================================
// ============================================================
// VIEW MODEL
// ============================================================

class _CatalogVm {
  final bool loading;
  final bool refreshing;
  final Object? error;

  final List<LatestFacilityDto> items;

  /*
   * Tăng mỗi khi LatestProvider nhận data mới.
   * Dùng để buộc cache của màn hình cập nhật.
   */
  final int dataVersion;

  const _CatalogVm({
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.items,
    required this.dataVersion,
  });
}
// ============================================================
// FLATTENED TABLE ROW
// ============================================================

class _CatalogTableRow {
  final String facility;
  final String category;
  final String rawCategory;

  final String scadaId;
  final String boxId;
  final String boxDeviceId;

  final String plcAddress;
  final String cateId;
  final String signalName;

  final double? value;
  final String unit;
  final DateTime? recordedAt;

  /*
   * Các giá trị đã chuẩn hóa.
   * Không cần trim lại trong mỗi lần build.
   */
  final String normalizedFacility;
  final String normalizedCategory;
  final String normalizedRawCategory;

  final String normalizedScadaId;
  final String normalizedBoxId;
  final String normalizedBoxDeviceId;

  final String normalizedPlcAddress;
  final String normalizedCateId;
  final String normalizedSignalName;
  final String normalizedUnit;

  final String searchBaseText;

  _CatalogTableRow({
    required String facility,
    required String category,
    required String rawCategory,
    required String scadaId,
    required String boxId,
    required String boxDeviceId,
    required String plcAddress,
    required String cateId,
    required String signalName,
    required this.value,
    required String unit,
    required this.recordedAt,
  }) : facility = facility,
       category = category,
       rawCategory = rawCategory,
       scadaId = scadaId,
       boxId = boxId,
       boxDeviceId = boxDeviceId,
       plcAddress = plcAddress,
       cateId = cateId,
       signalName = signalName,
       unit = unit,

       normalizedFacility = facility.trim(),
       normalizedCategory = category.trim(),
       normalizedRawCategory = rawCategory.trim(),

       normalizedScadaId = scadaId.trim(),
       normalizedBoxId = boxId.trim(),
       normalizedBoxDeviceId = boxDeviceId.trim(),

       normalizedPlcAddress = plcAddress.trim(),
       normalizedCateId = cateId.trim(),
       normalizedSignalName = signalName.trim(),
       normalizedUnit = unit.trim(),

       searchBaseText = [
         facility,
         category,
         rawCategory,
         scadaId,
         boxId,
         boxDeviceId,
         plcAddress,
         cateId,
         signalName,
         unit,
       ].join('|').toLowerCase();

  // ============================================================
  // STATUS
  // ============================================================

  bool isStaleAt(DateTime now) {
    final time = recordedAt;

    if (time == null) {
      return true;
    }

    final localTime = time.toLocal();

    return now.difference(localTime) > const Duration(minutes: 2);
  }

  /*
   * Dùng cho những chỗ không truyền now.
   * Trong vòng lặp nhiều row nên ưu tiên isStaleAt(now).
   */
  bool get isStale {
    return isStaleAt(DateTime.now());
  }

  String statusLabelAt(DateTime now) {
    return isStaleAt(now) ? 'Stale' : 'Online';
  }

  String get statusLabel {
    return isStale ? 'Stale' : 'Online';
  }

  // ============================================================
  // DISPLAY
  // ============================================================

  String get displaySignalName {
    if (normalizedSignalName.isNotEmpty) {
      return normalizedSignalName;
    }

    if (normalizedCateId.isNotEmpty) {
      return normalizedCateId;
    }

    return '--';
  }

  String get displayValue {
    final currentValue = value;

    if (currentValue == null || !currentValue.isFinite) {
      return '--';
    }

    final valueText = currentValue.abs() >= 1000
        ? currentValue.toStringAsFixed(1)
        : currentValue.toStringAsFixed(2);

    if (normalizedUnit.isEmpty) {
      return valueText;
    }

    return '$valueText $normalizedUnit';
  }

  String get displayTime {
    final time = recordedAt;

    if (time == null) {
      return '--';
    }

    final local = time.toLocal();

    return '${_two(local.day)}/'
        '${_two(local.month)}/'
        '${local.year} '
        '${_two(local.hour)}:'
        '${_two(local.minute)}:'
        '${_two(local.second)}';
  }

  // ============================================================
  // SEARCH
  // ============================================================

  String searchTextAt(DateTime now) {
    return '$searchBaseText|'
        '${displayValue.toLowerCase()}|'
        '${statusLabelAt(now).toLowerCase()}';
  }

  String get searchText {
    return searchTextAt(DateTime.now());
  }

  static String _two(int value) {
    return value.toString().padLeft(2, '0');
  }
}

enum _DeviceHealth { online, warning, offline }

class _CatalogDeviceGroup {
  final String key;

  final String facility;
  final String category;
  final String scadaId;
  final String boxId;
  final String boxDeviceId;

  final List<_CatalogTableRow> signals;

  const _CatalogDeviceGroup({
    required this.key,
    required this.facility,
    required this.category,
    required this.scadaId,
    required this.boxId,
    required this.boxDeviceId,
    required this.signals,
  });

  int get signalCount => signals.length;

  int get staleCount {
    return signals.where((item) => item.isStale).length;
  }

  int get onlineCount {
    return signalCount - staleCount;
  }

  _DeviceHealth get health {
    if (signals.isEmpty || staleCount == signalCount) {
      return _DeviceHealth.offline;
    }

    if (staleCount > 0) {
      return _DeviceHealth.warning;
    }

    return _DeviceHealth.online;
  }

  DateTime? get lastUpdated {
    DateTime? latest;

    for (final signal in signals) {
      final time = signal.recordedAt;

      if (time == null) continue;

      if (latest == null || time.isAfter(latest)) {
        latest = time;
      }
    }

    return latest;
  }
}

class _CatalogTreeGroup {
  final String key;
  final String scadaId;
  final String boxId;
  final List<_CatalogDeviceGroup> devices;

  const _CatalogTreeGroup({
    required this.key,
    required this.scadaId,
    required this.boxId,
    required this.devices,
  });

  int get deviceCount => devices.length;

  int get signalCount {
    return devices.fold(0, (total, device) => total + device.signalCount);
  }

  int get staleDeviceCount {
    return devices
        .where((device) => device.health != _DeviceHealth.online)
        .length;
  }
}
// ============================================================
// SUMMARY
// ============================================================

class _CatalogSummary {
  final int facilities;
  final int devices;
  final int signals;
  final int online;
  final int stale;

  const _CatalogSummary({
    required this.facilities,
    required this.devices,
    required this.signals,
    required this.online,
    required this.stale,
  });

  factory _CatalogSummary.fromRows(List<_CatalogTableRow> rows) {
    final facilities = <String>{};
    final devices = <String>{};

    var online = 0;
    var stale = 0;

    for (final row in rows) {
      facilities.add(row.facility);

      devices.add(
        '${row.facility}|'
        '${row.scadaId}|'
        '${row.boxId}|'
        '${row.boxDeviceId}',
      );

      if (row.isStale) {
        stale++;
      } else {
        online++;
      }
    }

    return _CatalogSummary(
      facilities: facilities.length,
      devices: devices.length,
      signals: rows.length,
      online: online,
      stale: stale,
    );
  }
}

// ============================================================
// HEADER / FILTERS
// ============================================================\
class _SignalMonitorTopBar extends StatelessWidget {
  final bool refreshing;
  final Object? error;
  final _CatalogSummary summary;
  final DateTime? lastUpdated;
  final Future<void> Function() onRefresh;

  const _SignalMonitorTopBar({
    required this.refreshing,
    required this.error,
    required this.summary,
    required this.lastUpdated,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF102139), Color(0xFF091626)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE).withOpacity(.11),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: const Color(0xFF22D3EE).withOpacity(.25),
              ),
            ),
            child: const Icon(Icons.sensors_rounded, color: Color(0xFF67E8F9)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UTILITY SIGNAL MONITOR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .55,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${summary.devices} devices'
                  '  •  ${summary.signals} signals'
                  '  •  ${summary.online} online'
                  '  •  ${summary.stale} stale',
                  style: const TextStyle(
                    color: Color(0xFF8FA5BF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _TopStatusMetric(
            label: 'DEVICES',
            value: '${summary.devices}',
            color: const Color(0xFF60A5FA),
          ),
          const SizedBox(width: 8),
          _TopStatusMetric(
            label: 'ONLINE',
            value: '${summary.online}',
            color: const Color(0xFF4ADE80),
          ),
          const SizedBox(width: 8),
          _TopStatusMetric(
            label: 'STALE',
            value: '${summary.stale}',
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'LAST UPDATED',
                style: TextStyle(
                  color: Color(0xFF71869F),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatTime(lastUpdated),
                style: const TextStyle(
                  color: Color(0xFFD2DEEC),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: error == null ? 'Refresh all data' : 'Last refresh failed',
            child: SizedBox.square(
              dimension: 42,
              child: Material(
                color: error == null
                    ? const Color(0xFF12243A)
                    : const Color(0xFF3A2116),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: refreshing ? null : onRefresh,
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: refreshing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            error == null
                                ? Icons.refresh_rounded
                                : Icons.cloud_off_rounded,
                            color: error == null
                                ? Colors.white
                                : Colors.orangeAccent,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime? time) {
    if (time == null) return '--:--:--';

    final local = time.toLocal();

    String two(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}';
  }
}

class _TopStatusMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TopStatusMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7D92AA),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalMonitorFilters extends StatelessWidget {
  final TextEditingController searchController;

  final List<String> facilityOptions;
  final List<String> categoryOptions;
  final List<String> scadaOptions;
  final List<String> boxOptions;

  final String? selectedFacility;
  final String? selectedCategory;
  final String? selectedScada;
  final String? selectedBox;
  final String? selectedStatus;

  final ValueChanged<String?> onFacilityChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onScadaChanged;
  final ValueChanged<String?> onBoxChanged;
  final ValueChanged<String?> onStatusChanged;

  final VoidCallback onClearFilters;

  const _SignalMonitorFilters({
    required this.searchController,
    required this.facilityOptions,
    required this.categoryOptions,
    required this.scadaOptions,
    required this.boxOptions,
    required this.selectedFacility,
    required this.selectedCategory,
    required this.selectedScada,
    required this.selectedBox,
    required this.selectedStatus,
    required this.onFacilityChanged,
    required this.onCategoryChanged,
    required this.onScadaChanged,
    required this.onBoxChanged,
    required this.onStatusChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: const Color(0xFF091523),
      child: Row(
        children: [
          Expanded(child: _CatalogSearchField(controller: searchController)),
          const SizedBox(width: 8),
          _FilterDropdown(
            width: 160,
            label: 'Facility',
            icon: Icons.factory_rounded,
            value: selectedFacility,
            items: facilityOptions,
            onChanged: onFacilityChanged,
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            width: 165,
            label: 'Category',
            icon: Icons.category_rounded,
            value: selectedCategory,
            items: categoryOptions,
            onChanged: onCategoryChanged,
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            width: 160,
            label: 'SCADA',
            icon: Icons.hub_rounded,
            value: selectedScada,
            items: scadaOptions,
            onChanged: onScadaChanged,
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            width: 160,
            label: 'Box',
            icon: Icons.inventory_2_rounded,
            value: selectedBox,
            items: boxOptions,
            onChanged: onBoxChanged,
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            width: 160,
            label: 'Status',
            icon: Icons.monitor_heart_rounded,
            value: selectedStatus,
            items: const ['Online', 'Stale'],
            onChanged: onStatusChanged,
          ),
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Clear filters',
            onPressed: onClearFilters,
            icon: const Icon(
              Icons.filter_alt_off_rounded,
              color: Color(0xFFA6B8CC),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScadaBoxTreePanel extends StatelessWidget {
  final List<_CatalogTreeGroup> groups;
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  const _ScadaBoxTreePanel({
    required this.groups,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scadaGroups = <String, List<_CatalogTreeGroup>>{};

    for (final group in groups) {
      scadaGroups.putIfAbsent(group.scadaId, () => <_CatalogTreeGroup>[]);

      scadaGroups[group.scadaId]!.add(group);
    }

    return Container(
      color: const Color(0xFF07111F),
      child: Column(
        children: [
          const _PanelHeader(
            icon: Icons.account_tree_rounded,
            title: 'SCADA / BOX TREE',
          ),
          Expanded(
            child: groups.isEmpty
                ? const _SmallEmptyState(message: 'No SCADA or box')
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final entry in scadaGroups.entries)
                        Theme(
                          data: ThemeData.dark().copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            childrenPadding: const EdgeInsets.only(
                              left: 8,
                              bottom: 6,
                            ),
                            leading: const Icon(
                              Icons.hub_rounded,
                              size: 18,
                              color: Color(0xFF60A5FA),
                            ),
                            title: Text(
                              entry.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            children: [
                              for (final group in entry.value)
                                _TreeBoxTile(
                                  group: group,
                                  selected: selectedKey == group.key,
                                  onTap: () {
                                    onSelected(group.key);
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TreeBoxTile extends StatelessWidget {
  final _CatalogTreeGroup group;
  final bool selected;
  final VoidCallback onTap;

  const _TreeBoxTile({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasWarning = group.staleDeviceCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? const Color(0xFF22D3EE).withOpacity(.11)
            : const Color(0xFF0B1828),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF22D3EE).withOpacity(.38)
                    : Colors.white.withOpacity(.05),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 16,
                  color: selected
                      ? const Color(0xFF67E8F9)
                      : const Color(0xFF7C92AC),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.boxId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFBCCBDB),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${group.deviceCount} devices'
                        ' • ${group.signalCount} signals',
                        style: const TextStyle(
                          color: Color(0xFF687E98),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasWarning
                        ? Colors.orangeAccent
                        : const Color(0xFF4ADE80),
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

class _DeviceListPanel extends StatelessWidget {
  final List<_CatalogDeviceGroup> devices;
  final String? selectedDeviceKey;

  final int totalDevices;
  final int currentPage;
  final int pageSize;

  final ValueChanged<String> onSelected;

  const _DeviceListPanel({
    required this.devices,
    required this.selectedDeviceKey,
    required this.totalDevices,
    required this.currentPage,
    required this.pageSize,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalDevices == 0 ? 0 : currentPage * pageSize + 1;

    final end = totalDevices == 0
        ? 0
        : (currentPage * pageSize + devices.length).clamp(0, totalDevices);

    return Container(
      color: const Color(0xFF081321),
      child: Column(
        children: [
          _PanelHeader(
            icon: Icons.memory_rounded,
            title: 'DEVICE LIST',
            trailing: '$start–$end / $totalDevices',
          ),
          Expanded(
            child: devices.isEmpty
                ? const _SmallEmptyState(message: 'No devices')
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];

                      return _DeviceListTile(
                        device: device,
                        selected: selectedDeviceKey == device.key,
                        onTap: () {
                          onSelected(device.key);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeviceListTile extends StatelessWidget {
  final _CatalogDeviceGroup device;
  final bool selected;
  final VoidCallback onTap;

  const _DeviceListTile({
    required this.device,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final healthColor = switch (device.health) {
      _DeviceHealth.online => const Color(0xFF4ADE80),
      _DeviceHealth.warning => Colors.orangeAccent,
      _DeviceHealth.offline => Colors.redAccent,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? const Color(0xFF22D3EE).withOpacity(.10)
            : const Color(0xFF0B1828),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF22D3EE).withOpacity(.38)
                    : Colors.white.withOpacity(.055),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: healthColor.withOpacity(.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.memory_rounded,
                    color: healthColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.boxDeviceId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFD0DCEC),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${device.signalCount} signals'
                        ' • ${device.onlineCount} online'
                        ' • ${device.staleCount} stale',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71869F),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Updated ${_formatDeviceTime(device.lastUpdated)}',
                        style: const TextStyle(
                          color: Color(0xFF60758D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: healthColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDeviceTime(DateTime? value) {
    if (value == null) return '--:--:--';

    final local = value.toLocal();

    String two(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}';
  }
}

class _NoDeviceSelected extends StatelessWidget {
  const _NoDeviceSelected();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, color: Color(0xFF526A84), size: 44),
          SizedBox(height: 12),
          Text(
            'Select a device',
            style: TextStyle(
              color: Color(0xFFB7C8DE),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Signals will appear here',
            style: TextStyle(color: Color(0xFF71869F), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DevicePaginationBar extends StatelessWidget {
  final int totalItems;
  final int currentPage;
  final int pageSize;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSelected;

  const _DevicePaginationBar({
    required this.totalItems,
    required this.currentPage,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSelected,
  });

  int get pageCount {
    if (totalItems <= 0) return 1;

    return (totalItems / pageSize).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : currentPage * pageSize + 1;

    final end = totalItems == 0
        ? 0
        : ((currentPage + 1) * pageSize).clamp(0, totalItems);

    final visiblePages = <int>[];

    final firstPage = (currentPage - 2).clamp(0, pageCount - 1);

    final lastPage = (firstPage + 4).clamp(0, pageCount - 1);

    for (var page = firstPage; page <= lastPage; page++) {
      visiblePages.add(page);
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF091523),
        border: Border(top: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          Text(
            'Showing $start–$end of $totalItems devices',
            style: const TextStyle(
              color: Color(0xFF7F94AD),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton(onPressed: onPrevious, child: const Text('Previous')),
          const SizedBox(width: 4),
          for (final page in visiblePages)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _PageButton(
                page: page,
                selected: page == currentPage,
                onTap: () {
                  onPageSelected(page);
                },
              ),
            ),
          const SizedBox(width: 4),
          TextButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final int page;
  final bool selected;
  final VoidCallback onTap;

  const _PageButton({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: Material(
        color: selected ? const Color(0xFF155E75) : const Color(0xFF0C1A2A),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              '${page + 1}',
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF8FA5BF),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const _PanelHeader({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2B),
        border: Border(bottom: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF8FA5BF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFB7C8DE),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: .55,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: Color(0xFF67E8F9),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallEmptyState extends StatelessWidget {
  final String message;

  const _SmallEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF667C94),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CatalogSearchField extends StatelessWidget {
  final TextEditingController controller;

  const _CatalogSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText:
              'Search facility, category, SCADA, box, device, PLC, signal...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(.35),
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 21,
            color: Color(0xFF8DA3BF),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
          filled: true,
          fillColor: const Color(0xFF07111F),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF22D3EE)),
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  static const String allValue = '__ALL__';

  final double width;
  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.width,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 42,
      child: DropdownButtonFormField<String>(
        value: value ?? allValue,
        isExpanded: true,
        dropdownColor: const Color(0xFF111F32),
        iconEnabledColor: const Color(0xFF8DA3BF),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF8DA3BF)),
          filled: true,
          fillColor: const Color(0xFF07111F),
          contentPadding: const EdgeInsets.only(right: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(.09)),
          ),
        ),
        items: [
          DropdownMenuItem<String>(value: allValue, child: Text('All $label')),
          ...items.map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (selected) {
          onChanged(selected == allValue ? null : selected);
        },
      ),
    );
  }
}

class _DeviceSignalDetail extends StatelessWidget {
  final _CatalogDeviceGroup? device;
  final _CatalogDataSource dataSource;

  const _DeviceSignalDetail({required this.device, required this.dataSource});

  @override
  Widget build(BuildContext context) {
    final selectedDevice = device;

    if (selectedDevice == null) {
      return const _NoDeviceSelected();
    }

    return Container(
      color: const Color(0xFF07111F),
      child: Column(
        children: [
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2B),
              border: Border(bottom: BorderSide(color: Color(0xFF20344D))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedDevice.boxDeviceId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${selectedDevice.facility}'
                        '  •  ${selectedDevice.category}'
                        '  •  ${selectedDevice.scadaId}'
                        '  •  ${selectedDevice.boxId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7F94AD),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _DetailBadge(
                  label: '${selectedDevice.signalCount} Signals',
                  color: const Color(0xFF60A5FA),
                ),
                const SizedBox(width: 7),
                _DetailBadge(
                  label: '${selectedDevice.onlineCount} Online',
                  color: const Color(0xFF4ADE80),
                ),
                const SizedBox(width: 7),
                _DetailBadge(
                  label: '${selectedDevice.staleCount} Stale',
                  color: Colors.orangeAccent,
                ),
              ],
            ),
          ),
          Expanded(
            child: selectedDevice.signals.isEmpty
                ? const _CatalogEmptyState()
                : _DeviceSignalGrid(source: dataSource),
          ),
        ],
      ),
    );
  }
}

class _DeviceSignalGrid extends StatelessWidget {
  final _CatalogDataSource source;

  const _DeviceSignalGrid({required this.source});

  @override
  Widget build(BuildContext context) {
    return SfDataGrid(
      source: source,
      allowSorting: true,
      allowMultiColumnSorting: true,
      rowHeight: 56,
      headerRowHeight: 46,
      frozenColumnsCount: 1,
      columnWidthMode: ColumnWidthMode.none,
      gridLinesVisibility: GridLinesVisibility.horizontal,
      headerGridLinesVisibility: GridLinesVisibility.both,
      horizontalScrollPhysics: const ClampingScrollPhysics(),
      verticalScrollPhysics: const ClampingScrollPhysics(),
      columns: [
        GridColumn(
          columnName: 'plcAddress',
          width: 110,
          label: const _GridHeader(label: 'PLC'),
        ),
        GridColumn(
          columnName: 'signalName',
          width: 360,
          label: const _GridHeader(label: 'SIGNAL'),
        ),
        GridColumn(
          columnName: 'value',
          width: 155,
          label: const _GridHeader(label: 'VALUE'),
        ),
        GridColumn(
          columnName: 'updated',
          width: 180,
          label: const _GridHeader(label: 'UPDATED'),
        ),
        GridColumn(
          columnName: 'status',
          width: 110,
          label: const _GridHeader(label: 'STATUS'),
        ),
      ],
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
// ============================================================
// DATA GRID
// ============================================================

class _GridHeader extends StatelessWidget {
  final String label;

  const _GridHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF16253A),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFB7C8DE),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: .55,
        ),
      ),
    );
  }
}

// ============================================================
// DATA SOURCE
// ============================================================

class _CatalogDataSource extends DataGridSource {
  final List<_CatalogTableRow> rowsData;

  late final List<DataGridRow> _rows;

  final Map<DataGridRow, _CatalogTableRow> _modelByGridRow =
      <DataGridRow, _CatalogTableRow>{};

  _CatalogDataSource({required List<_CatalogTableRow> rows})
    : rowsData = List<_CatalogTableRow>.unmodifiable(rows) {
    _rows = rowsData.map(_createGridRow).toList(growable: false);
  }

  DataGridRow _createGridRow(_CatalogTableRow model) {
    final gridRow = DataGridRow(
      cells: [
        DataGridCell<String>(columnName: 'plcAddress', value: model.plcAddress),
        DataGridCell<String>(
          columnName: 'signalName',
          value: model.displaySignalName,
        ),
        DataGridCell<double>(
          columnName: 'value',
          value: model.value ?? double.negativeInfinity,
        ),
        DataGridCell<int>(
          columnName: 'updated',
          value: model.recordedAt?.millisecondsSinceEpoch ?? -1,
        ),
        DataGridCell<int>(columnName: 'status', value: model.isStale ? 1 : 0),
      ],
    );

    _modelByGridRow[gridRow] = model;

    return gridRow;
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow gridRow) {
    final model = _modelByGridRow[gridRow];

    if (model == null) {
      return DataGridRowAdapter(
        cells: gridRow
            .getCells()
            .map((cell) => _textCell(cell.value?.toString() ?? '--'))
            .toList(growable: false),
      );
    }

    final index = _rows.indexOf(gridRow);

    final background = index.isEven
        ? const Color(0xFF081321)
        : const Color(0xFF0B1728);

    return DataGridRowAdapter(
      color: background,
      cells: gridRow
          .getCells()
          .map((cell) {
            switch (cell.columnName) {
              case 'plcAddress':
                return _plcCell(model);

              case 'signalName':
                return _signalCell(model);

              case 'value':
                return _valueCell(model);

              case 'updated':
                return _updatedCell(model);

              case 'status':
                return _statusCell(model);

              default:
                return _textCell(cell.value?.toString() ?? '--');
            }
          })
          .toList(growable: false),
    );
  }

  Widget _textCell(String text) {
    final displayText = text.trim().isEmpty ? '--' : text.trim();

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        displayText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFC6D4E5),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _plcCell(_CatalogTableRow row) {
    final style = _categoryStyle(row.category);

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: style.color.withOpacity(.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: style.color.withOpacity(.18)),
        ),
        child: Text(
          row.plcAddress.trim().isEmpty ? '--' : row.plcAddress.trim(),
          style: TextStyle(
            color: style.color,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _signalCell(_CatalogTableRow row) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.displaySignalName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (row.cateId.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                row.cateId.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6F859F),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _valueCell(_CatalogTableRow row) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        row.displayValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: row.isStale ? Colors.orangeAccent : const Color(0xFF4ADE80),
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _updatedCell(_CatalogTableRow row) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        row.displayTime,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF9AAEC5),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusCell(_CatalogTableRow row) {
    final color = row.isStale ? Colors.orangeAccent : const Color(0xFF4ADE80);

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              row.statusLabel.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _CategoryVisualStyle _categoryStyle(String category) {
    final value = category.trim().toUpperCase();

    if (value.contains('ELECTRIC')) {
      return const _CategoryVisualStyle(
        color: Color(0xFFFBBF24),
        icon: Icons.bolt_rounded,
      );
    }

    if (value.contains('WATER')) {
      return const _CategoryVisualStyle(
        color: Color(0xFF22D3EE),
        icon: Icons.water_drop_rounded,
      );
    }

    if (value.contains('AIR') || value.contains('COMPRESSED')) {
      return const _CategoryVisualStyle(
        color: Color(0xFFA78BFA),
        icon: Icons.air_rounded,
      );
    }

    return const _CategoryVisualStyle(
      color: Color(0xFF94A3B8),
      icon: Icons.category_rounded,
    );
  }
}

class _CategoryVisualStyle {
  final Color color;
  final IconData icon;

  const _CategoryVisualStyle({required this.color, required this.icon});
}

// ============================================================
// STATES
// ============================================================

class _CatalogLoadingState extends StatelessWidget {
  const _CatalogLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 34,
        child: CircularProgressIndicator(strokeWidth: 2.8),
      ),
    );
  }
}

class _CatalogErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _CatalogErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(.30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.redAccent,
              size: 38,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load utility table',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(.52),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.table_rows_outlined,
            color: Colors.white.withOpacity(.28),
            size: 52,
          ),
          const SizedBox(height: 12),
          Text(
            'No utility signals found',
            style: TextStyle(
              color: Colors.white.withOpacity(.66),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Try changing or clearing the filters',
            style: TextStyle(
              color: Colors.white.withOpacity(.38),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
