import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'disposable_provider.dart';
import 'vector_graphics.dart';


/// Provides widgets with the rasterized image taken from the [vectorInfo].
class VectorProvider extends DisposableProvider<SvgImageKey>
{
  /// The decoded vector picture.
  final VectorInfo vectorInfo;

  const VectorProvider(this.vectorInfo);

  @override
  Future<SvgImageKey> obtainKey(final ImageConfiguration configuration)
  {
    final devicePixelRatio = configuration.devicePixelRatio ?? 1.0;
    var scale = 1.0 / devicePixelRatio;
    final size = configuration.size;
    if (size != null) {
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
    final scaledWidth = vectorInfo.size.width * devicePixelRatio / scale;
    final scaledHeight = vectorInfo.size.height * devicePixelRatio / scale;
    return SynchronousFuture<SvgImageKey>(
      SvgImageKey(
        vectorInfo: vectorInfo,
        scaledWidth: scaledWidth,
        scaledHeight: scaledHeight,
        scale: scale,
        pixelRatio: devicePixelRatio,
      ),
    );
  }

  @override
  ImageStreamCompleter loadImage(
    final SvgImageKey key,
    final ImageDecoderCallback decode,
  )
  {
    return OneFrameImageStreamCompleter(_loadAsync(key));
  }

  static Future<ImageInfo> _loadAsync(final SvgImageKey key) async
  {
    final vectorInfo = key.vectorInfo;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(key.pixelRatio / key.scale);
    canvas.drawPicture(vectorInfo.picture);
    final rasterPicture = recorder.endRecording();
    final image = await rasterPicture.toImage(
      key.scaledWidth.round(),
      key.scaledHeight.round(),
    );
    return ImageInfo(image: image, scale: 1.0);
  }

  @override
  void dispose()
  {
    vectorInfo.picture.dispose();
  }

  @override
  String toString() => '$runtimeType(${describeIdentity(vectorInfo)})';
}


@immutable
class SvgImageKey
{
  final VectorInfo vectorInfo;

  final double scaledWidth;

  final double scaledHeight;

  final double scale;

  final double pixelRatio;

  const SvgImageKey({
    required this.vectorInfo,
    required this.scaledWidth,
    required this.scaledHeight,
    required this.scale,
    required this.pixelRatio,
  });

  @override
  bool operator ==(final Object other)
  {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SvgImageKey
      && other.vectorInfo == vectorInfo
      && other.scaledWidth == scaledWidth
      && other.scaledHeight == scaledHeight
      && other.scale == scale
      && other.pixelRatio == pixelRatio;
  }

  @override
  int get hashCode => Object.hash(vectorInfo, scaledWidth, scaledHeight, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'SvgImageKey')}('
    '${describeIdentity(vectorInfo)}, '
    'scaledWidth: ${scaledWidth.toStringAsFixed(1)}, '
    'scaledHeight: ${scaledHeight.toStringAsFixed(1)}, '
    'scale: ${scale.toStringAsFixed(1)}, '
    'pixelRatio: ${pixelRatio.toStringAsFixed(1)})';
}
