import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../models/reference_chunk.dart';
import 'hash_embedder.dart';

/// In-memory embedding index loaded from the bundled assets.
///
/// Chunk metadata lives in `index_<lang>.json`; the vectors live in a flat
/// little-endian float32 blob so startup does not have to parse ~1.2M JSON
/// numbers.
class EmbeddingIndex {
  EmbeddingIndex._({
    required this.language,
    required this.dimensions,
    required List<_ChunkMeta> chunks,
    required Float32List vectors,
  })  : _chunks = chunks,
        _vectors = vectors,
        _embedder = HashEmbedder(dimensions: dimensions);

  static Future<EmbeddingIndex> load(String language) async {
    final String rawMeta =
        await rootBundle.loadString('assets/data/index_$language.json');
    final Map<String, dynamic> meta =
        jsonDecode(rawMeta) as Map<String, dynamic>;
    final int dimensions = meta['dimensions'] as int;

    final ByteData blob =
        await rootBundle.load('assets/data/index_$language.f32');
    // Copy into a fresh buffer: the bundle's ByteData is not guaranteed to be
    // 4-byte aligned, which asFloat32List requires.
    final Uint8List bytes = Uint8List.fromList(
      blob.buffer.asUint8List(blob.offsetInBytes, blob.lengthInBytes),
    );
    final Float32List vectors = bytes.buffer.asFloat32List();

    final List<_ChunkMeta> chunks = <_ChunkMeta>[
      for (final dynamic item in meta['chunks'] as List<dynamic>)
        _ChunkMeta.fromJson(item as Map<String, dynamic>),
    ];

    if (vectors.length != chunks.length * dimensions) {
      throw StateError(
        'Embedding blob for "$language" has ${vectors.length} floats, '
        'expected ${chunks.length * dimensions}',
      );
    }

    return EmbeddingIndex._(
      language: language,
      dimensions: dimensions,
      chunks: chunks,
      vectors: vectors,
    );
  }

  final String language;
  final int dimensions;
  final List<_ChunkMeta> _chunks;
  final Float32List _vectors;
  final HashEmbedder _embedder;

  int get chunkCount => _chunks.length;

  /// Cosine-similarity search, optionally narrowed the way
  /// `search_index()` in `learning/embeddings.py` narrows by card, orientation
  /// and facet. Stored vectors are already normalised, so only the query needs
  /// its norm divided out — and `HashEmbedder` normalises that too.
  List<ReferenceChunk> search(
    String query, {
    required int topK,
    String? cardName,
    String? orientation,
    String? facet,
  }) {
    final Float32List queryVector = _embedder.embed(query);
    final List<ReferenceChunk> scored = <ReferenceChunk>[];

    for (int i = 0; i < _chunks.length; i++) {
      final _ChunkMeta chunk = _chunks[i];
      if (cardName != null && chunk.cardName != cardName) {
        continue;
      }
      if (orientation != null && chunk.orientation != orientation) {
        continue;
      }
      if (facet != null && chunk.facet != facet) {
        continue;
      }

      double dot = 0;
      final int offset = i * dimensions;
      for (int d = 0; d < dimensions; d++) {
        dot += queryVector[d] * _vectors[offset + d];
      }

      scored.add(
        ReferenceChunk(
          id: chunk.id,
          cardName: chunk.cardName,
          orientation: chunk.orientation,
          facet: chunk.facet,
          title: chunk.title,
          text: chunk.text,
          score: dot,
        ),
      );
    }

    scored.sort((ReferenceChunk a, ReferenceChunk b) =>
        b.score.compareTo(a.score));
    return scored.length <= topK ? scored : scored.sublist(0, topK);
  }
}

class _ChunkMeta {
  const _ChunkMeta({
    required this.id,
    required this.cardName,
    required this.orientation,
    required this.facet,
    required this.title,
    required this.text,
  });

  factory _ChunkMeta.fromJson(Map<String, dynamic> json) => _ChunkMeta(
        id: json['id'] as String,
        cardName: json['card_name'] as String,
        orientation: json['orientation'] as String?,
        facet: json['facet'] as String,
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );

  final String id;
  final String cardName;
  final String? orientation;
  final String facet;
  final String title;
  final String text;
}
