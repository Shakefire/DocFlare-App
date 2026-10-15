import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class FileTypeIcon extends StatelessWidget {
  final String contentType;
  final double size;

  const FileTypeIcon({
    super.key,
    required this.contentType,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color color;

    final lower = contentType.toLowerCase();
    if (lower.startsWith('image/')) {
      iconData = Icons.image_rounded;
      color = AppColors.info;
    } else if (lower == 'application/pdf') {
      iconData = Icons.picture_as_pdf_rounded;
      color = AppColors.danger;
    } else if (lower.startsWith('video/')) {
      iconData = Icons.videocam_rounded;
      color = Colors.purple;
    } else if (lower.contains('officedocument') || lower.contains('word') || lower.contains('msword')) {
      iconData = Icons.description_rounded;
      color = Colors.blue.shade700;
    } else if (lower.contains('excel') || lower.contains('spreadsheet')) {
      iconData = Icons.table_chart_rounded;
      color = Colors.green.shade700;
    } else if (lower == 'text/plain') {
      iconData = Icons.article_rounded;
      color = AppColors.textSecondary;
    } else {
      iconData = Icons.insert_drive_file_rounded;
      color = AppColors.textSecondary;
    }

    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: Icon(iconData, size: size, color: color),
      ),
    );
  }
}
