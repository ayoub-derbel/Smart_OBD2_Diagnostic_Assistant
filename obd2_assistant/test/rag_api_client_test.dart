import 'package:flutter_test/flutter_test.dart';
import 'package:obd2_assistant/domain/entities/rag_response.dart';

void main() {
  test('RagDiagnoseResponse parse JSON', () {
    final response = RagDiagnoseResponse.fromJson({
      'text': '{"safety":"caution"}',
      'rag': {
        'chunk_ids': ['dtc-P0171-def', 'dtc-P0300-causes-lean'],
        'scores': [23.0, 25.0],
      },
    });

    expect(response.text, contains('safety'));
    expect(response.rag.chunkIds.length, 2);
    expect(response.rag.scores.first, 23.0);
  });

  test('RagMeta handles empty rag', () {
    final meta = RagMeta.fromJson({});
    expect(meta.chunkIds, isEmpty);
    expect(meta.scores, isEmpty);
  });
}
