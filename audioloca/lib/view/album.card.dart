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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 100,
                width: 100,
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.color1,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 100,
                width: 100,
                color: Colors.grey[300],
                child: Icon(Icons.broken_image, color: Colors.grey[700]),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
