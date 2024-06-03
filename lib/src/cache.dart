import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'config.dart';
import 'disposable_provider.dart';
import 'downloader.dart';
import 'logger.dart';
import 'raster_provider.dart';
import 'vector_provider.dart';


enum ImageType
{
  stale,
  fresh,
}

class ImageCacheItem
{
  final DisposableProvider image;
  final ImageType imageType;
  final Size? imageSize;

  const ImageCacheItem(this.image, this.imageType, {
    this.imageSize,
  });

  ImageCacheItem stale() => ImageCacheItem(
    image, ImageType.stale, imageSize: imageSize,
  );

  ImageCacheItem fresh() => ImageCacheItem(
    image, ImageType.fresh, imageSize: imageSize,
  );
}


class UrlImageCache
{
  /// Common cache.
  static final instance = UrlImageCache._();

  /// Common configuration.
  static UrlImageConfig get config => UrlImageConfig.instance;

  /// Tries to precache the image by specified [url] and returns if the image
  /// successfully precashed.
  Future<bool> precache(final String url, {
    final String? name,
    final DownloadDelegate? downloader,
  }) async
  {
    final cached = await get(url, name: name, downloader: downloader).toList();
    return cached.isNotEmpty;
  }

  /// Returns cached image item by its url if exists.
  ///
  /// Returned item may be stale (loaded from the filesystem while downloading
  /// in progress), fresh (the most actual) and null (when the image has never
  /// been downloaded yet).
  ImageCacheItem? getAny(final String url) => _cache[url.hashCode];

  /// Returns cached image item by its url. If it doesn't exist, tries to load
  /// and returns the first result.
  Future<ImageCacheItem?> getCached(final String url, {
    final String? name,
    final DownloadDelegate? downloader,
  }) async
  {
    final stream = get(url, name: name, downloader: downloader);
    await for (var item in stream) return item;
    return null;
  }

  /// Returns the stream of image items by the url.
  ///
  /// The stream contains image items ranged by their freshness. The stream may
  /// return nothing if the image has never been downloaded yet and downloading
  /// is failed.
  Stream<ImageCacheItem> get(final String url, {
    String? name,
    final DownloadDelegate? downloader,
  }) async*
  {
    final key = url.hashCode;
    final item = _cache[key];
    if (item != null) {
      yield item;
      if (item.imageType == ImageType.fresh) return;
    }
    var stream = _streams[key];
    if (stream == null) {
      name ??= key.toString();
      stream = _stream(name, url, downloader: downloader).asBroadcastStream();
      _streams[key] = stream;
    }
    yield* stream;
  }

  /// Makes specified image item by its [url] stale, so when it is requested
  /// from the cache, a new version of the image will be downloaded again.
  /// If [url] is `null`, all items become stale.
  void invalidate(final String? url)
  {
    final invalidated = <int, ImageCacheItem>{};
    final key = url?.hashCode;
    if (key == null) {
      _cache.forEach((key, value) {
        if (value.imageType == ImageType.fresh) {
          invalidated[key] = value.stale();
        }
      });
    } else {
      final value = _cache[key];
      if (value != null) {
        invalidated[key] = value.stale();
      }
    }
    invalidated.forEach((key, value) {
      _cache[key] = value;
    });
  }

  UrlImageCache._();

  Stream<ImageCacheItem> _stream(final String name, final String url, {
    final DownloadDelegate? downloader,
  }) async*
  {
    final key = url.hashCode;
    final cached = _cache[key];
    Uint8List? bytes;
    DownloadedDataType? dataType;
    String? fileName;
    if (cached == null) {
      final fileStorage = UrlImageConfig.instance.fileStorage;
      if (fileStorage != null) {
        fileName = await _getFileName(name);
        if (fileName != null) {
          final fileExists = await fileStorage.fileExists(fileName);
          if (fileExists) {
            final data = await fileStorage.loadData(fileName);
            if (data != null && data.isNotEmpty) {
              dataType = DownloadedDataType.fromIndex(data.first);
              bytes = Uint8List.fromList(data.sublist(1));
              final item = await _makeItem(
                bytes,
                ImageType.stale,
                dataType,
              );
              if (item != null) {
                _cache[key]?.image.dispose();
                _cache[key] = item;
                yield item;
              }
            }
          }
        }
      }
    } else if (cached.imageType == ImageType.fresh) {
      _streams.remove(key);
      return;
    }
    final data = await _download(url, downloader: downloader);
    if (data != null) {
      final cached = _cache[key];
      if (cached != null
        && data.type == dataType
        && bytesEqual(data.bytes, bytes)
      ) {
        _cache[key] = cached.fresh();
      } else {
        final fileStorage = UrlImageConfig.instance.fileStorage;
        if (fileStorage != null) {
          fileName ??= await _getFileName(name);
          if (fileName != null) {
            await fileStorage.saveStream(fileName, Stream.fromIterable([
              [ data.type.index ], data.bytes,
            ]));
          }
        }
        final item = await _makeItem(data.bytes, ImageType.fresh, data.type);
        if (item != null) {
          _cache[key]?.image.dispose();
          _cache[key] = item;
          yield item;
        }
      }
    }
    _streams.remove(key);
  }

  Future<ImageCacheItem?> _makeItem(
    final Uint8List bytes,
    final ImageType imageType,
    final DownloadedDataType? dataType,
  ) async
  {
    switch (dataType) {
      case null:
        return null;
      case DownloadedDataType.raster:
        final imageProvider = RasterProvider(Uint8List.fromList(bytes));
        final imageSize = await _resolveImageSize(imageProvider);
        return ImageCacheItem(imageProvider, imageType,
          imageSize: imageSize,
        );
      case DownloadedDataType.vector:
        final vectorDecoder = UrlImageConfig.instance.vectorDecoder;
        if (vectorDecoder == null) {
          log.warning('Vector decoder is not set.');
          return ImageCacheItem(RasterProvider.invalid, imageType,
            imageSize: Size.zero,
          );
        } else {
          try {
            final vectorInfo = await vectorDecoder.decode(
              Uint8List.fromList(bytes),
              clipViewbox: false,
            );
            final imageProvider = VectorProvider(vectorInfo);
            return ImageCacheItem(imageProvider, imageType,
              imageSize: vectorInfo.size,
            );
          } catch (e) {
            log.warning('Failed to decode vector graphics: $e');
            return ImageCacheItem(RasterProvider.invalid, imageType,
              imageSize: Size.zero,
            );
          }
        }
    }
  }

  Future<String?> _getFileName(String imageName) async
  {
    final fileStorage = UrlImageConfig.instance.fileStorage;
    if (fileStorage == null) return null;
    final cachePath = await fileStorage.getCachePath();
    return '$cachePath/$imageName';
  }

  Future<DownloadedData?> _download(final String url, {
    DownloadDelegate? downloader,
  }) async
  {
    if (_downloads.containsKey(url)) {
      return await _downloads[url]!;
    }
    final completer = Completer<DownloadedData?>();
    _downloads[url] = completer.future;
    try {
      downloader ??= config.downloader;
      if (downloader == null) {
        throw Exception('Downloader is not set.');
      }
      final data = await downloader.download(url);
      completer.complete(data);
      return data;
    } catch (e) {
      log.warning('Failed to download external image $url: $e');
      completer.complete(null);
      return null;
    } finally {
      _downloads.remove(url);
    }
  }

  Future<Size?> _resolveImageSize(final ImageProvider imageProvider) async
  {
    final completer = Completer<ImageInfo>();
    final imageStream = imageProvider.resolve(
      const ImageConfiguration(),
    );
    final imageStreamListener = ImageStreamListener(
      (info, synchronousCall) => completer.complete(info),
      onError: (error, stackTrace) {
        log.warning(error);
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    imageStream.addListener(imageStreamListener);
    try {
      final info = await completer.future;
      final size = Size(
        info.image.width * info.scale,
        info.image.height * info.scale,
      );
      info.image.dispose();
      return size;
    } catch (e) {
      log.warning(e);
    }
    return null;
  }

  final _cache = <int, ImageCacheItem>{};
  final _streams = <int, Stream<ImageCacheItem>>{};
  final _downloads = <String, Future<DownloadedData?>>{};
}


/// Effectively compares two lists of bytes.
///
/// Returns `true` if all bytes in the [bytes1] list are equal to bytes in the
/// [bytes2] list.
bool bytesEqual(final Uint8List? bytes1, final Uint8List? bytes2)
{
  if (bytes1 == null && bytes2 == null) return true;
  if (bytes1 == null || bytes2 == null) return false;
  if (identical(bytes1, bytes2)) return true;
  if (bytes1.lengthInBytes != bytes2.lengthInBytes) return false;

  final numWords = bytes1.lengthInBytes ~/ 8;
  final words1 = bytes1.buffer.asUint64List(0, numWords);
  final words2 = bytes2.buffer.asUint64List(0, numWords);

  for (var i = 0; i < words1.length; ++i) {
    if (words1[i] != words2[i]) return false;
  }
  for (var i = words1.lengthInBytes; i < bytes1.lengthInBytes; ++i) {
    if (bytes1[i] != bytes2[i]) return false;
  }

  return true;
}
