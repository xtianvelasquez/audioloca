import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioloca/theme.dart';

class AlbumHeaderCard extends StatelessWidget {
  final String albumCoverUrl;
  final String albumName;
  final DateTime createdAt;
  final String description;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AlbumHeaderCard({
    super.key,
    required this.albumCoverUrl,
    required this.albumName,
    required this.createdAt,
    required this.description,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: AppColors.color3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CachedNetworkImage(
                  imageUrl: albumCoverUrl,
                  imageBuilder: (_, imageProvider) => Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: AppColors.color1),
                  ),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(albumName, style: AppTextStyles.subtitle),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat("MM/dd/yyyy").format(createdAt),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onEdit, child: const Text("EDIT")),
                const SizedBox(width: 8),
                TextButton(onPressed: onDelete, child: const Text("DELETE")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
