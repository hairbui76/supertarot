import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/digests/blake2b.dart';

/// Dart port of `HashEmbeddingProvider` in `learning/embeddings.py`.
///
/// The bundled index was built with the deterministic `hash-word-v1` provider,
/// so queries must be hashed with the exact same scheme for cosine similarity
/// to mean anything. Unigrams and bigrams are signed-hashed into a fixed
/// number of buckets, then the vector is L2-normalised.
class HashEmbedder {
  HashEmbedder({this.dimensions = 512});

  final int dimensions;

  /// Python's `re.findall(r"\w+", text, re.UNICODE)` matches letters, digits
  /// and underscore. Dart's `\w` is ASCII-only, so the classes are spelled out
  /// to keep Vietnamese text tokenising identically.
  static final RegExp _token = RegExp(r'[\p{L}\p{N}_]+', unicode: true);

  Float32List embed(String text) {
    final Float32List vector = Float32List(dimensions);
    final List<String> tokens = _token
        .allMatches(text.toLowerCase())
        .map((RegExpMatch match) => match.group(0)!)
        .toList(growable: false);

    final List<String> features = <String>[
      ...tokens,
      for (int i = 0; i + 1 < tokens.length; i++) '${tokens[i]} ${tokens[i + 1]}',
    ];

    for (final String feature in features) {
      final Uint8List digest = _blake2b8(feature);
      vector[_modulo(digest, dimensions)] +=
          (digest[digest.length - 1] & 1) == 1 ? 1.0 : -1.0;
    }

    double sum = 0;
    for (final double value in vector) {
      sum += value * value;
    }
    if (sum == 0) {
      return vector;
    }
    final double norm = math.sqrt(sum);
    for (int i = 0; i < vector.length; i++) {
      vector[i] = vector[i] / norm;
    }
    return vector;
  }

  static Uint8List _blake2b8(String feature) {
    final Blake2bDigest digest = Blake2bDigest(digestSize: 8);
    final Uint8List input = Uint8List.fromList(utf8.encode(feature));
    final Uint8List output = Uint8List(8);
    digest.update(input, 0, input.length);
    digest.doFinal(output, 0);
    return output;
  }

  /// `int.from_bytes(digest, "big") % modulus` without 64-bit overflow: the
  /// digest is a full 64-bit value, which does not fit a signed Dart int.
  static int _modulo(Uint8List digest, int modulus) {
    int accumulator = 0;
    for (final int byte in digest) {
      accumulator = (accumulator * 256 + byte) % modulus;
    }
    return accumulator;
  }
}
