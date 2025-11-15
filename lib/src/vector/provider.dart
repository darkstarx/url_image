import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../disposable_provider.dart';
import 'cache.dart';
import 'graphics.dart';


/// Provides widgets with the rasterized image taken from the [vectorInfo].
class VectorProvider extends DisposableProvider<VectorImageKey>
{
  /// The decoded vector picture.
  final VectorInfo vectorInfo;

  const VectorProvider(this.vectorInfo);

  VectorImageKey makeKey(final ImageConfiguration configuration)
  {
    final devicePixelRatio = configuration.devicePixelRatio ?? 1.0;
    final size = configuration.size;
    double scale;
    if (size == null) {
       scale = 1.0;
    } else {
      final width = size.width == double.infinity
        ? vectorInfo.size.width * devicePixelRatio
        : size.width;
      final height = size.height == double.infinity
        ? vectorInfo.size.height * devicePixelRatio
        : size.height;
      scale = min(
        vectorInfo.size.width / width,
        vectorInfo.size.height / height,
      );
    }
    scale = devicePixelRatio / scale;
    final scaledWidth = vectorInfo.size.width * scale;
    final scaledHeight = vectorInfo.size.height * scale;
    return VectorImageKey(
      vectorInfo: vectorInfo,
      scaledWidth: scaledWidth.round(),
      scaledHeight: scaledHeight.round(),
      scale: _roundDouble(scale, 5),
    );
  }

  /// Converts an [ImageProvider]'s settings plus an [ImageConfiguration] to a
  /// key that describes the precise image to load.
  ///
  /// The type of the key is determined by the subclass. It is a value that
  /// unambiguously identifies the image (_including its scale_) that the
  /// [loadImage] method will fetch. Different [ImageProvider]s given the same
  /// constructor arguments and [ImageConfiguration] objects should return keys
  /// that are '==' to each other (possibly by using a class for the key that
  /// itself implements [==]).
  ///
  /// If the result can be determined synchronously, this function should return
  /// a [SynchronousFuture]. This allows image resolution to progress
  /// synchronously during a frame rather than delaying image loading.
  @override
  Future<VectorImageKey> obtainKey(final ImageConfiguration configuration)
  {
    return SynchronousFuture<VectorImageKey>(makeKey(configuration));
  }

  /// Called by [resolve] with the key returned by [obtainKey].
  ///
  /// Subclasses should override this method rather than calling [obtainKey] if
  /// they need to use a key directly. The [resolve] method installs appropriate
  /// error handling guards so that errors will bubble up to the right places in
  /// the framework, and passes those guards along to this method via the
  /// [handleError] parameter.
  ///
  /// It is safe for the implementation of this method to call [handleError]
  /// multiple times if multiple errors occur, or if an error is thrown both
  /// synchronously into the current part of the stack and thrown into the
  /// enclosing [Zone].
  ///
  /// The default implementation uses the key to interact with the [ImageCache],
  /// calling [ImageCache.putIfAbsent] and notifying listeners of the [stream].
  /// Implementers that do not call super are expected to correctly use the
  /// [ImageCache].
  @override
  void resolveStreamForKey(
    final ImageConfiguration configuration,
    final ImageStream stream,
    final VectorImageKey key,
    final ImageErrorListener handleError,
  ) {
    final imageCache = VectorImageCache.instance;
    // This is an unusual edge case where someone has told us that they found
    // the image we want before getting to this method. We should avoid calling
    // load again, but still update the image cache with LRU information.
    if (stream.completer != null) {
      final completer = imageCache.putIfAbsent(
        key,
        () => stream.completer!,
        onError: handleError,
      );
      assert(identical(completer, stream.completer));
      return;
    }
    final completer = imageCache.putIfAbsent(
      key,
      () => loadImage(
        key,
        PaintingBinding.instance.instantiateImageCodecWithSize,
      ),
      onError: handleError,
    );
    if (completer != null) {
      stream.setCompleter(completer);
    }
  }

  @override
  ImageStreamCompleter loadImage(
    final VectorImageKey key,
    final ImageDecoderCallback decode,
  )
  {
    return OneFrameImageStreamCompleter(_loadAsync(key));
  }

  static Future<ImageInfo> _loadAsync(final VectorImageKey key) async
  {
    final vectorInfo = key.vectorInfo;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(key.scale);
    canvas.drawPicture(vectorInfo.picture);
    final picture = recorder.endRecording();
    final image = await picture.toImage(key.scaledWidth, key.scaledHeight);
    return ImageInfo(image: image, scale: key.scale);
  }

  @override
  void dispose()
  {
    vectorInfo.picture.dispose();
  }

  @override
  String toString() => '$runtimeType(${describeIdentity(vectorInfo)})';

  static double _roundDouble(final double value, final int places)
  {
    final mod = pow(10, places);
    return (value * mod).roundToDouble() / mod;
  }
}


@immutable
class VectorImageKey
{
  final VectorInfo vectorInfo;

  final int scaledWidth;

  final int scaledHeight;

  final double scale;

  const VectorImageKey({
    required this.vectorInfo,
    required this.scaledWidth,
    required this.scaledHeight,
    required this.scale,
  });

  @override
  bool operator ==(final Object other) => other is VectorImageKey
    && other.runtimeType == runtimeType
    && other.vectorInfo == vectorInfo
    && other.scaledWidth == scaledWidth
    && other.scaledHeight == scaledHeight
    && other.scale == scale
  ;

  @override
  int get hashCode => Object.hash(
    runtimeType, vectorInfo, scaledWidth, scaledHeight, scale,
  );

  @override
  String toString() => '${objectRuntimeType(this, 'SvgImageKey')}('
    '${describeIdentity(vectorInfo)}, '
    'scaledWidth: $scaledWidth, '
    'scaledHeight: $scaledHeight, '
    'scale: ${scale.toStringAsFixed(5)})'
  ;
}
