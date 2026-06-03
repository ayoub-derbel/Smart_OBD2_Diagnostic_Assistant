class RagMeta {
  final List<String> chunkIds;
  final List<double> scores;

  const RagMeta({
    required this.chunkIds,
    required this.scores,
  });

  factory RagMeta.fromJson(Map<String, dynamic> json) {
    final ids = json['chunk_ids'];
    final scoresRaw = json['scores'];
    return RagMeta(
      chunkIds: ids is List ? ids.map((e) => e.toString()).toList() : const [],
      scores: scoresRaw is List
          ? scoresRaw.map((e) => (e as num).toDouble()).toList()
          : const [],
    );
  }
}

class RagDiagnoseResponse {
  final String text;
  final RagMeta rag;

  const RagDiagnoseResponse({
    required this.text,
    required this.rag,
  });

  factory RagDiagnoseResponse.fromJson(Map<String, dynamic> json) {
    return RagDiagnoseResponse(
      text: json['text']?.toString() ?? '',
      rag: RagMeta.fromJson(
        json['rag'] is Map<String, dynamic>
            ? json['rag'] as Map<String, dynamic>
            : const {},
      ),
    );
  }
}
