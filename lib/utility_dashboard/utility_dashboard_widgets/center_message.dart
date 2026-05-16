import 'package:flutter/material.dart';

class CenterMessage extends StatelessWidget {
  final String message;

  final IconData icon;

  final Color color;

  final EdgeInsetsGeometry padding;

  const CenterMessage({
    super.key,
    required this.message,

    this.icon = Icons.info_outline_rounded,

    this.color = const Color(0xFF60A5FA),

    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),

        child: Container(
          margin: const EdgeInsets.all(12),

          padding: padding,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),

            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,

              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),

            border: Border.all(color: color.withOpacity(0.28), width: 1.2),

            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.12),

                blurRadius: 24,

                spreadRadius: 1,

                offset: const Offset(0, 8),
              ),

              BoxShadow(
                color: Colors.black.withOpacity(0.25),

                blurRadius: 18,

                offset: const Offset(0, 10),
              ),
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              //////////////////////////////////////////////////////
              /// ICON
              //////////////////////////////////////////////////////
              Container(
                width: 62,
                height: 62,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: color.withOpacity(0.14),

                  border: Border.all(color: color.withOpacity(0.35)),
                ),

                child: Icon(icon, size: 30, color: color),
              ),

              const SizedBox(height: 18),

              //////////////////////////////////////////////////////
              /// TITLE
              //////////////////////////////////////////////////////
              Text(
                message,

                textAlign: TextAlign.center,

                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),

                  fontSize: 16,

                  height: 1.45,

                  fontWeight: FontWeight.w600,

                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
