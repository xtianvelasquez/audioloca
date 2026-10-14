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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: ClayDecorations.card(radius: 20),
          child: Row(
            children: [
              // Thumbnail with rank or rounded corners
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      imageUrl: imageUrl,
                      placeholder: (_, __) => Container(
                        width: 52,
                        height: 52,
                        color: AppColors.pillBg,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryPurple,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: AppColors.pillBg,
                        child: const Icon(
                          Icons.music_note_rounded,
                          size: 28,
                          color: AppColors.color2,
                        ),
                      ),
                    ),
                  ),
                  if (showRank && rank != null)
                    Positioned(
                      top: -6,
                      left: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppGradients.primaryButton,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withValues(
                                alpha: 0.4,
                              ),
                              offset: const Offset(1, 2),
                              blurRadius: 4,
                            ),
                          ],
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
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Title and subtitle/stream count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.dark,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (formattedCount != null) ...[
                          const SizedBox(width: 6),
                          const Text(
                            "•",
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$formattedCount plays",
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Duration
              Text(
                duration,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(width: 10),

              // Clay Play Button
              ClayPlayButton(
                size: 34,
                onPressed: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
