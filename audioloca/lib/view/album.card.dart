import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';

class AlbumListItem extends StatelessWidget {
  final String imageUrl;
  final String title;
  final VoidCallback onTap;

  const AlbumListItem({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: ClayDecorations.card(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 90,
                width: 90,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 90,
                  width: 90,
                  color: AppColors.pillBg,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryPurple,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 90,
                  width: 90,
                  color: AppColors.pillBg,
                  child: const Icon(
                    Icons.album_rounded,
                    color: AppColors.color2,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
