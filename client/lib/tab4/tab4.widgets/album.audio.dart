import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';

class AudioListItem extends StatelessWidget {
  final String title;
  final int plays;
  final String duration;
  final VoidCallback onTap;

  const AudioListItem({
    super.key,
    required this.title,
    required this.plays,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$plays plays"),
        trailing: Text(duration),
      ),
    );
  }
}
