import 'chart_catalog_item.dart';

class ChartCatalogResponse {
  final List<ChartCatalogItem> items;

  const ChartCatalogResponse({required this.items});

  factory ChartCatalogResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return ChartCatalogResponse(
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
