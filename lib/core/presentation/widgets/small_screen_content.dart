// ✅ Content cho màn hình nhỏ (Row layout)
import 'package:flutter/material.dart';

class SmallScreenContent extends StatelessWidget {
  const SmallScreenContent({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),

        // Value
        Container(
          constraints: const BoxConstraints(
            minWidth: 24,
          ), // ✅ Min width để số lượng không bị lệch
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Title
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Arrow
        if (onTap != null)
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withOpacity(0.7),
            size: 12,
          ),
      ],
    );
  }
}
