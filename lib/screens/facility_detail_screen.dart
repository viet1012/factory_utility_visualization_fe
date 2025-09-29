import 'package:factory_utility_visualization/api/ApiService.dart';
import 'package:flutter/material.dart';
import '../model/utility_data.dart';

class FacilityDetailScreen extends StatefulWidget {
  final String positionName; // ví dụ: "Tủ P1"

  const FacilityDetailScreen({super.key, required this.positionName});

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  late Future<List<UtilityData>> _futureData;

  @override
  void initState() {
    super.initState();
    _futureData = ApiService().fetchElectricalCabinets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chi tiết ${widget.positionName}")),
      body: FutureBuilder<List<UtilityData>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Không có dữ liệu"));
          }

          /// Lọc theo đúng tủ cần xem
          final filtered = snapshot.data!
              .where((item) => item.position == widget.positionName)
              .toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text("Không tìm thấy dữ liệu cho ${widget.positionName}"),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// --- Thông tin cơ bản ---
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.home_repair_service,
                      color: Colors.blue,
                    ),
                    title: Text("Vị trí: ${filtered.first.position}"),
                    subtitle: Text("Tổng số điểm đo: ${filtered.length}"),
                  ),
                ),
                const SizedBox(height: 16),

                /// --- Danh sách PLC ---
                Expanded(
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  "Địa chỉ",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  "Giá trị",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  "Loại",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  "Thời gian",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(item.plcAddress),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(item.plcValue),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(item.comment),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(item.dataTime.toString()),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
