import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'disposable_provider.dart';


// Method signature for _loadAsync decode callbacks.
typedef _SimpleDecoderCallback = Future<Codec> Function(ImmutableBuffer buffer);

/// Decodes the given [Uint8List] buffer as an image, associating it with the
/// given scale.
///
/// The provided [bytes] buffer should not be changed after it is provided to a
/// [RasterProvider].
class RasterProvider extends DisposableProvider<RasterProvider>
{
  /// The bytes to decode into an image.
  ///
  /// The bytes represent encoded image bytes and can be encoded in any of the
  /// following supported image formats: {@macro dart.ui.imageFormats}
  ///
  /// See also:
  ///
  ///  * [PaintingBinding.instantiateImageCodecWithSize]
  final Uint8List bytes;

  /// The scale to place in the [ImageInfo] object of the image.
  ///
  /// See also:
  ///
  ///  * [ImageInfo.scale], which gives more information on how this scale is
  ///    applied.
  final double scale;

  /// Represents invalid raster image.
  static final invalid = RasterProvider(Uint8List(0));

  /// Creates an object that decodes a [Uint8List] buffer as an image.
  const RasterProvider(this.bytes, { this.scale = 1.0 });

  @override
  Future<RasterProvider> obtainKey(final ImageConfiguration configuration)
  {
    return SynchronousFuture<RasterProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    final RasterProvider key,
    final ImageDecoderCallback decode,
  )
  {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode: decode),
      scale: key.scale,
      debugLabel: 'MemoryImage(${describeIdentity(key.bytes)})',
    );
  }

  Future<Codec> _loadAsync(final RasterProvider key, {
    required _SimpleDecoderCallback decode,
  }) async
  {
    assert(key == this);
    return decode(await ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  void dispose() {}

  @override
  bool operator ==(Object other)
  {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is RasterProvider
        && other.bytes == bytes
        && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(bytes.hashCode, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'RasterProvider')}('
    '${describeIdentity(bytes)}, scale: ${scale.toStringAsFixed(1)})';
}
