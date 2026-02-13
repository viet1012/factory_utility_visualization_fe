enum LayoutNodeKind { scada, panel, gm, ma, noAction }

class LayoutNodeDto {
  final String id;
  final LayoutNodeKind kind;

  // vị trí theo % (0..1)
  final double x, y, w, h;

  // text hiển thị
  final String title;
  final String? subtitle;

  // filter để click / query
  final String? facId;
  final String? scadaId;
  final String? boxId;
  final String? boxDeviceId;
  final String? plcAddress; // nếu muốn show 1 tín hiệu cụ thể

  const LayoutNodeDto({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.title,
    this.subtitle,
    this.facId,
    this.scadaId,
    this.boxId,
    this.boxDeviceId,
    this.plcAddress,
  });
}
