import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';

class AudioListItem extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String duration;
  final int? streamCount;
  final VoidCallback onTap;

  final bool showRank;
  final int? rank;

  const AudioListItem({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.duration,
    this.streamCount,
    required this.onTap,
    this.showRank = false,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final formattedCount = (streamCount != null && streamCount! > 0)
        ? NumberFormat.decimalPattern().format(streamCount)
        : null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.color3,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          alignment: Alignment.topLeft,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                imageUrl: imageUrl,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.color1,
                    strokeWidth: 2,
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.broken_image,
                    size: 40,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
            if (showRank && rank != null)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.color1,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  "#$rank",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, color: AppColors.dark),
            children: [
              TextSpan(text: subtitle),
              if (formattedCount != null) ...[
                const WidgetSpan(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.play_arrow,
                      size: 14,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                TextSpan(text: "$formattedCount plays"),
              ],
            ],
          ),
        ),
        trailing: Text(duration),
      ),
    );
  }
}
