import 'package:flutter/material.dart';

class SummaryCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const SummaryCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: _isHovered
          ? [widget.color.withOpacity(0.3), widget.color.withOpacity(0.6)]
          : [widget.color.withOpacity(0.2), widget.color.withOpacity(0.4)],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: cardGradient,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(_isHovered ? 0.6 : 0.4),
              blurRadius: _isHovered ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: widget.color.withOpacity(_isHovered ? 0.35 : 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon tròn nổi bật
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
              child: Icon(widget.icon, color: widget.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(fontSize: 13, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow nhỏ tinh tế
            // Icon(
            //   Icons.arrow_forward_ios,
            //   size: 16,
            //   color: Colors.white.withOpacity(0.6),
            // ),
          ],
        ),
      ),
    );
  }
}
