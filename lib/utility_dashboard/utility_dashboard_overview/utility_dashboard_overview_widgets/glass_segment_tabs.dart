import 'dart:ui';

import 'package:flutter/material.dart';

class GlassTabItem {
  final String label;
  final IconData? icon;
  final Color color;

  const GlassTabItem({required this.label, required this.color, this.icon});
}

class GlassSegmentTabs extends StatelessWidget {
  final List<GlassTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  final double height;
  final double fontSize;
  final double iconSize;
  final bool compact;

  const GlassSegmentTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 34,
    this.fontSize = 10,
    this.iconSize = 13,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(.12),
                Colors.white.withOpacity(.04),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.28),
                blurRadius: 22,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final active = selectedIndex == index;
              final color = item.color;

              final tab = InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: active ? color.withOpacity(.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active
                          ? color.withOpacity(.50)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.icon != null) ...[
                        Icon(
                          item.icon,
                          size: iconSize,
                          color: active ? color : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        item.label,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white70,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: compact ? tab : Expanded(child: tab),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
