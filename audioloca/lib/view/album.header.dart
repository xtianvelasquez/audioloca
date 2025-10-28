import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';

class AlbumHeader extends StatelessWidget {
  final String imageUrl;
  final String title;
  final DateTime subtitle;

  const AlbumHeader({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: AppColors.color3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const CircularProgressIndicator(color: AppColors.color1),
                errorWidget: (_, __, ___) => Container(
                  height: 100,
                  width: 100,
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.broken_image,
                    size: 40,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Created on ${DateFormat('MMM dd, yyyy').format(subtitle)}",
                    style: AppTextStyles.keyword,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
