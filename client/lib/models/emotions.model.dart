class Emotions {
  final int emotionId;
  final String emotionLabel;

  Emotions({required this.emotionId, required this.emotionLabel});

  factory Emotions.fromJson(Map<String, dynamic> json) {
    return Emotions(
      emotionId: json['emotion_id'],
      emotionLabel: json['emotion_label'],
    );
  }
}
