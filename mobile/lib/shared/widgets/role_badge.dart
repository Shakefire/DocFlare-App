import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class RoleBadge extends StatelessWidget {
  final String role;

  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (role.toLowerCase()) {
      case 'admin':
        bg = AppColors.primary.withValues(alpha: 0.15);
        fg = AppColors.primaryDark;
        break;
      case 'manager':
        bg = AppColors.info.withValues(alpha: 0.15);
        fg = AppColors.info;
        break;
      case 'viewer':
      default:
        bg = AppColors.textSecondary.withValues(alpha: 0.12);
        fg = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
