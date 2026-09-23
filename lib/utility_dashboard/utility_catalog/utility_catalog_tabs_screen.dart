import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/utility_catalog_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'catalog_view_models.dart';
import 'widgets/catalog_left_panels.dart';
import 'widgets/catalog_signal_detail.dart';
import 'models/latest_tree_response.dart';
import 'providers/latest_provider.dart';

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

  String _keyword = '';
  String? _selectedFacility;
  String? _selectedCategory;
  String? _selectedScada;
  String? _selectedBox;
  String? _selectedStatus;

  String? _selectedTreeKey;
  String? _selectedDeviceKey;

  /// Selection da reconcile dang cho ghi vao state sau frame hien tai.
  _CatalogSelection? _pendingSelection;

  int _devicePage = 0;

  static const int _devicePageSize = 50;

  int _cachedDataVersion = -1;
  String _cachedFilterKey = '';

  List<CatalogTableRow> _cachedRows = const [];

  String _deviceKey(CatalogTableRow row) {
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

    _latestProvider = context.read<LatestProvider>();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final next = _searchController.text.trim().toLowerCase();

      if (next == _keyword) return;

      setState(() {
        _keyword = next;

        if (next.isNotEmpty) {
          _resetNavigationSelection();
        }
      });
    });
  }

  Future<void> _refresh() async {
    final provider = _latestProvider;

    if (provider == null || provider.loading) {
      return;
    }

    /*
     * Khong chan theo provider.refreshing nua: refreshAll da tu coalesce,
     * nen neu polling dang chay thi nut Refresh se await chung request do
     * thay vi khong lam gi ca.
     */
    await provider.refreshAll();
  }

  /// Xoa selection dieu huong khi buoc vao global filter mode.
  void _resetNavigationSelection() {
    _selectedTreeKey = null;
    _selectedDeviceKey = null;
    _devicePage = 0;
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

      // Bo loc xong, _resolveNormalSelection chon lai ngay trong build nay.
      _devicePage = 0;
    });
  }

  /*
   * Global filter mode: khi co search hoac bat ky filter nao tren toolbar,
   * bang ben phai hien thi toan bo ket qua loc, khong bi gioi han theo
   * device dang chon o cay ben trai.
   */
  bool get _hasActiveSearchOrFilter {
    return _keyword.trim().isNotEmpty ||
        _selectedFacility != null ||
        _selectedCategory != null ||
        _selectedScada != null ||
        _selectedBox != null ||
        _selectedStatus != null;
  }

  List<CatalogTableRow> _prepareRows(
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

    final rows = <CatalogTableRow>[];
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
                final row = CatalogTableRow(
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

    _cachedRows = List<CatalogTableRow>.unmodifiable(rows);

    return _cachedRows;
  }

  bool _matchesKeyword(CatalogTableRow row, String keyword, DateTime now) {
    if (keyword.isEmpty) {
      return true;
    }

    return row.searchTextAt(now).contains(keyword);
  }

  int _compareRows(CatalogTableRow first, CatalogTableRow second) {
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

  List<CatalogDeviceGroup> _buildDeviceGroups(List<CatalogTableRow> rows) {
    final grouped = <String, List<CatalogTableRow>>{};

    for (final row in rows) {
      final key = _deviceKey(row);

      grouped.putIfAbsent(key, () => <CatalogTableRow>[]);

      grouped[key]!.add(row);
    }

    final result = grouped.entries.map((entry) {
      final signals = entry.value;
      final first = signals.first;

      signals.sort((a, b) {
        return _naturalCompare(a.plcAddress, b.plcAddress);
      });

      return CatalogDeviceGroup(
        key: entry.key,
        facility: first.facility,
        category: first.category,
        scadaId: first.scadaId,
        boxId: first.boxId,
        boxDeviceId: first.boxDeviceId,
        signals: List<CatalogTableRow>.unmodifiable(signals),
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

  List<CatalogTreeGroup> _buildTreeGroups(List<CatalogDeviceGroup> devices) {
    final grouped = <String, List<CatalogDeviceGroup>>{};

    for (final device in devices) {
      final key = _treeKey(scadaId: device.scadaId, boxId: device.boxId);

      grouped.putIfAbsent(key, () => <CatalogDeviceGroup>[]);

      grouped[key]!.add(device);
    }

    final result = <CatalogTreeGroup>[];

    for (final entry in grouped.entries) {
      final devices = List<CatalogDeviceGroup>.from(entry.value);

      if (devices.isEmpty) continue;

      devices.sort((first, second) {
        return _naturalCompare(first.boxDeviceId, second.boxDeviceId);
      });

      final first = devices.first;

      result.add(
        CatalogTreeGroup(
          key: entry.key,
          scadaId: first.scadaId,
          boxId: first.boxId,
          devices: List<CatalogDeviceGroup>.unmodifiable(devices),
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

  /*
   * Selection duoc reconcile ngay trong build, khong qua addPostFrameCallback.
   *
   * Ly do: sau mot lan refresh, dataset co the khong con chua tree/device
   * dang chon. Neu doi den frame sau moi sua, frame hien tai se render bang
   * key da chet -> detail panel trong, device list trong, tree va detail
   * khong khop nhau trong mot frame.
   *
   * Ham nay chi TINH ra selection hop le cho dataset hien tai va tra ve cho
   * build dung ngay. Viec ghi lai vao state (de cac callback nhu onSelected,
   * phan trang doc dung gia tri) duoc hoan sang sau frame qua
   * _persistSelection, nen khong co setState nao chay trong luc build.
   */
  _CatalogSelection _resolveNormalSelection({
    required List<CatalogTreeGroup> treeGroups,
    required List<CatalogDeviceGroup> devices,
  }) {
    if (treeGroups.isEmpty) {
      return const _CatalogSelection(treeKey: null, deviceKey: null);
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

    return _CatalogSelection(treeKey: nextTreeKey, deviceKey: nextDeviceKey);
  }

  /// Ghi selection da reconcile vao state sau khi frame hien tai ket thuc.
  ///
  /// Frame hien tai da render bang chinh cac gia tri nay, nen setState o day
  /// khong lam thay doi giao dien, chi dong bo lai state cho cac tuong tac
  /// tiep theo.
  void _persistSelection(_CatalogSelection selection) {
    if (selection.treeKey == _selectedTreeKey &&
        selection.deviceKey == _selectedDeviceKey) {
      return;
    }

    if (_pendingSelection == selection) {
      return;
    }

    _pendingSelection = selection;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_pendingSelection != selection) return;

      _pendingSelection = null;

      if (selection.treeKey == _selectedTreeKey &&
          selection.deviceKey == _selectedDeviceKey) {
        return;
      }

      setState(() {
        _selectedTreeKey = selection.treeKey;
        _selectedDeviceKey = selection.deviceKey;
        _devicePage = 0;
      });
    });
  }

  List<CatalogDeviceGroup> _devicesForTree(
    List<CatalogDeviceGroup> devices,
    String? treeKey,
  ) {
    if (treeKey == null) {
      return const <CatalogDeviceGroup>[];
    }

    return devices.where((device) {
      return _treeKey(scadaId: device.scadaId, boxId: device.boxId) == treeKey;
    }).toList();
  }

  int _pageCount(int itemCount) {
    if (itemCount == 0) return 1;

    return (itemCount / _devicePageSize).ceil();
  }

  List<CatalogDeviceGroup> _pagedDevices(List<CatalogDeviceGroup> devices) {
    final pageCount = _pageCount(devices.length);

    final safePage = _devicePage.clamp(0, pageCount - 1);

    final start = safePage * _devicePageSize;

    if (start >= devices.length) {
      return const <CatalogDeviceGroup>[];
    }

    final end = (start + _devicePageSize).clamp(0, devices.length);

    return devices.sublist(start, end);
  }

  /*
   * LAST UPDATED = sample timestamp moi nhat trong cac row DANG HIEN THI.
   *
   * Giu nguyen ngu nghia cu: toan bo cum header (devices / online / stale)
   * deu tinh theo rows da loc, nen LAST UPDATED cung phai theo rows da loc
   * thi con so moi nhat quan.
   *
   * Han che: neu backend tra ve dung timestamp cu, mot lan refresh thanh cong
   * se khong lam gia tri nay doi. Vi vay thoi diem refresh thanh cong duoc
   * hien thi rieng o tooltip cua nut refresh (lastRefreshAt), khong tron
   * vao con so nay.
   */
  DateTime? _latestTime(List<CatalogTableRow> rows) {
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
          lastRefreshAt: provider.lastRefreshAt,
        );
      },
      shouldRebuild: (previous, next) {
        return previous.loading != next.loading ||
            previous.refreshing != next.refreshing ||
            previous.error != next.error ||
            previous.dataVersion != next.dataVersion ||
            previous.lastRefreshAt != next.lastRefreshAt;
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

        final isGlobalFilterMode = _hasActiveSearchOrFilter;

        final allDevices = _buildDeviceGroups(rows);

        final treeGroups = _buildTreeGroups(allDevices);

        /*
         * Global filter mode khong dung navigation selection, nen giu nguyen
         * key da luu. Normal mode reconcile ngay tai day de frame hien tai
         * luon render bang selection hop le voi dataset vua nhan.
         */
        final selection = isGlobalFilterMode
            ? _CatalogSelection(
                treeKey: _selectedTreeKey,
                deviceKey: _selectedDeviceKey,
              )
            : _resolveNormalSelection(
                treeGroups: treeGroups,
                devices: allDevices,
              );

        if (!isGlobalFilterMode) {
          _persistSelection(selection);
        }

        final effectiveTreeKey = selection.treeKey;
        final effectiveDeviceKey = selection.deviceKey;

        final devicesForTree = _devicesForTree(allDevices, effectiveTreeKey);

        final pagedDevices = _pagedDevices(devicesForTree);

        final selectedDevice = allDevices
            .cast<CatalogDeviceGroup?>()
            .firstWhere(
              (item) => item?.key == effectiveDeviceKey,
              orElse: () => null,
            );

        final selectedSignals =
            selectedDevice?.signals ?? const <CatalogTableRow>[];

        final visibleSignals = isGlobalFilterMode ? rows : selectedSignals;

        final dataSource = CatalogDataSource(
          rows: visibleSignals,
          globalMode: isGlobalFilterMode,
        );

        final summary = CatalogSummary.fromRows(rows);

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
                color: Colors.black.withValues(alpha: .22),
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
                lastRefreshAt: vm.lastRefreshAt,
                onRefresh: _refresh,
                viewMode: _viewMode,
                onViewModeChanged: (value) {
                  if (_viewMode == value) return;

                  setState(() {
                    _viewMode = value;
                  });
                },
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

                    _resetNavigationSelection();
                  });
                },
                onCategoryChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _selectedScada = null;
                    _selectedBox = null;

                    _resetNavigationSelection();
                  });
                },
                onScadaChanged: (value) {
                  setState(() {
                    _selectedScada = value;
                    _selectedBox = null;

                    _resetNavigationSelection();
                  });
                },
                onBoxChanged: (value) {
                  setState(() {
                    _selectedBox = value;

                    _resetNavigationSelection();
                  });
                },
                onStatusChanged: (value) {
                  setState(() {
                    _selectedStatus = value;

                    _resetNavigationSelection();
                  });
                },
                onClearFilters: _clearFilters,
              ),

              Expanded(
                child: _viewMode == UtilityCatalogViewMode.monitor
                    ? Row(
                        children: [
                          SizedBox(
                            width: 230,
                            child: CatalogScadaBoxTreePanel(
                              groups: treeGroups,
                              selectedKey: effectiveTreeKey,
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
                            child: CatalogDeviceListPanel(
                              devices: pagedDevices,
                              selectedDeviceKey: effectiveDeviceKey,
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
                            child: CatalogSignalDetail(
                              device: selectedDevice,
                              dataSource: dataSource,
                              globalMode: isGlobalFilterMode,
                              rows: visibleSignals,
                            ),
                          ),
                        ],
                      )
                    : UtilityCatalogTreeView(
                        items: vm.items,
                        dataVersion: vm.dataVersion,
                      ),
              ),

              if (_viewMode == UtilityCatalogViewMode.monitor)
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

/// Cap tree/device da duoc reconcile cho dataset hien tai.
@immutable
class _CatalogSelection {
  final String? treeKey;
  final String? deviceKey;

  const _CatalogSelection({required this.treeKey, required this.deviceKey});

  @override
  bool operator ==(Object other) {
    return other is _CatalogSelection &&
        other.treeKey == treeKey &&
        other.deviceKey == deviceKey;
  }

  @override
  int get hashCode => Object.hash(treeKey, deviceKey);
}

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

  /// Thoi diem refresh thanh cong gan nhat, dung cho tooltip nut refresh.
  final DateTime? lastRefreshAt;

  const _CatalogVm({
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.items,
    required this.dataVersion,
    required this.lastRefreshAt,
  });
}

// ============================================================
// HEADER / FILTERS
// ============================================================
class _UtilityCatalogViewSwitcher extends StatelessWidget {
  final UtilityCatalogViewMode value;
  final ValueChanged<UtilityCatalogViewMode> onChanged;

  const _UtilityCatalogViewSwitcher({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF07111F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          _ViewModeButton(
            icon: Icons.view_column_rounded,
            tooltip: 'Monitor view',
            selected: value == UtilityCatalogViewMode.monitor,
            onTap: () {
              onChanged(UtilityCatalogViewMode.monitor);
            },
          ),
          _ViewModeButton(
            icon: Icons.account_tree_rounded,
            tooltip: 'Tree view',
            selected: value == UtilityCatalogViewMode.tree,
            onTap: () {
              onChanged(UtilityCatalogViewMode.tree);
            },
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 34,
          height: 32,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF155E75) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : const Color(0xFF71869F),
          ),
        ),
      ),
    );
  }
}

class _SignalMonitorTopBar extends StatelessWidget {
  final bool refreshing;
  final Object? error;
  final CatalogSummary summary;
  final DateTime? lastUpdated;
  final DateTime? lastRefreshAt;
  final Future<void> Function() onRefresh;
  final UtilityCatalogViewMode viewMode;
  final ValueChanged<UtilityCatalogViewMode> onViewModeChanged;

  const _SignalMonitorTopBar({
    required this.refreshing,
    required this.error,
    required this.summary,
    required this.lastUpdated,
    required this.lastRefreshAt,
    required this.onRefresh,
    required this.viewMode,
    required this.onViewModeChanged,
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
              color: const Color(0xFF22D3EE).withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: const Color(0xFF22D3EE).withValues(alpha: .25),
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
          _UtilityCatalogViewSwitcher(
            value: viewMode,
            onChanged: onViewModeChanged,
          ),

          const SizedBox(width: 14),
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
            message: _refreshTooltip(),
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

  /*
   * Loi refresh khi da co data duoc bao o day (icon + tooltip), khong thay
   * the noi dung man hinh. _CatalogErrorState chi dung khi chua co data nao.
   */
  String _refreshTooltip() {
    if (refreshing) {
      return 'Refreshing...';
    }

    final stamp = lastRefreshAt == null ? 'never' : _formatTime(lastRefreshAt);

    if (error != null) {
      return 'Last refresh failed - showing data from $stamp';
    }

    return 'Refresh all data (last refresh $stamp)';
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
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .18)),
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
            color: Colors.white.withValues(alpha: .35),
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
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .10)),
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
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .09)),
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
          border: Border.all(color: Colors.redAccent.withValues(alpha: .30)),
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
                color: Colors.white.withValues(alpha: .52),
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
