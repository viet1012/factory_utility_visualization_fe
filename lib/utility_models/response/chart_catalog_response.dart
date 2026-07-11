import 'chart_catalog_item.dart';

class ChartCatalogResponse {
  final int totalScadas;
  final int totalBoxes;
  final int totalDevices;
  final int totalParams;

  final List<ChartCatalogItem> items;

  const ChartCatalogResponse({
    required this.totalScadas,
    required this.totalBoxes,
    required this.totalDevices,
    required this.totalParams,
    required this.items,
  });

  factory ChartCatalogResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return ChartCatalogResponse(
      totalScadas: (json['totalScadas'] as num?)?.toInt() ?? 0,
      totalBoxes: (json['totalBoxes'] as num?)?.toInt() ?? 0,
      totalDevices: (json['totalDevices'] as num?)?.toInt() ?? 0,
      totalParams: (json['totalParams'] as num?)?.toInt() ?? 0,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => ChartCatalogItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}
