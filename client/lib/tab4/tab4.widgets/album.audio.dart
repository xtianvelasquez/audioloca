import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/core/utils.dart';
import 'package:audioloca/environment.dart';

class AudioListItem extends StatelessWidget {
  final String audioPhoto;
  final String title;
  final int plays;
  final String duration;
  final VoidCallback onTap;

  const AudioListItem({
    super.key,
    required this.audioPhoto,
    required this.title,
    required this.plays,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final audioPhotoUrl = '${Environment.audiolocaBaseUrl}/$audioPhoto';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            imageUrl: audioPhotoUrl,
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$plays plays"),
        trailing: Text(formatDuration(duration)),
      ),
    );
  }
}
