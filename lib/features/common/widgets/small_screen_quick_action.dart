import 'package:flutter/material.dart';

class SmallScreenQuickAction extends StatelessWidget {
  const SmallScreenQuickAction({
    super.key,
    required this.title,
    required this.icon,
    required this.subTitle,
  });

  final String title;
  final IconData icon;
  final String subTitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmall = constraints.maxWidth < 160;

        return Padding(
          padding: EdgeInsets.all(isVerySmall ? 4 : 6),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: EdgeInsets.all(isVerySmall ? 4 : 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isVerySmall ? 6 : 8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isVerySmall ? 14 : 16,
                ),
              ),

              SizedBox(width: isVerySmall ? 6 : 8),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isVerySmall ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isVerySmall ? 1 : 2),
                    Text(
                      subTitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: isVerySmall ? 8 : 9,
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Arrow hint
              if (constraints.maxWidth > 140) // Chỉ hiện arrow khi đủ rộng
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: isVerySmall ? 10 : 12,
                ),
            ],
          ),
        );
      },
    );
  }
}
