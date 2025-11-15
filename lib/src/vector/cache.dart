import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'provider.dart';


/// Class for caching rasterized vector images.
///
/// Implements a least-recently-used cache of up to 1000 images, and up to 100
/// MB. The maximum size can be adjusted using [maximumSize] and
/// [maximumSizeBytes].
///
/// The cache also holds a list of 'live' references. An image is considered
/// live if its [ImageStreamCompleter]'s listener count has never dropped to
/// zero after adding at least one listener. The cache uses
/// [ImageStreamCompleter.addOnLastListenerRemovedCallback] to determine when
/// this has happened.
///
/// The [putIfAbsent] method is the main entry-point to the cache API. It
/// returns the previously cached [ImageStreamCompleter] for the given key, if
/// available; if not, it calls the given callback to obtain it first. In either
/// case, the key is moved to the 'most recently used' position.
///
/// A caller can determine whether an image is already in the cache by using
/// [containsKey], which will return true if the image is tracked by the cache
/// in a pending or completed state. More fine grained information is available
/// by using the [statusForKey] method.
///
/// Generally this class is not used directly. The [VectorProvider] class and
/// its subclasses automatically handle the caching of images.
///
/// A shared instance of this cache is retained by [VectorImageCache.instance].
class VectorImageCache extends ImageCache
{
  /// Common cache.
  static final instance = VectorImageCache._();

  /// Returns the previously cached [ImageStream] for the given key, if available;
  /// if not, calls the given callback to obtain it first. In either case, the
  /// key is moved to the 'most recently used' position.
  ///
  /// In the event that the loader throws an exception, it will be caught only if
  /// `onError` is also provided. When an exception is caught resolving an image,
  /// no completers are cached and `null` is returned instead of a new
  /// completer.
  ///
  /// Images that are larger than [maximumSizeBytes] are not cached, and do not
  /// cause other images in the cache to be evicted.
  @override
  ImageStreamCompleter? putIfAbsent(
    covariant final VectorImageKey key,
    final ImageStreamCompleter Function() loader, {
    final ImageErrorListener? onError,
  })
  {
    final status = statusForKey(key);
    if (status.tracked) {
      return super.putIfAbsent(key, loader, onError: onError);
    }
    final tmpItem = _tmpItems[key];
    if (tmpItem != null) {
      return tmpItem.completer;
    }
    try {
      final completer = loader();
      // The returning completer will load the raster asynchronously, so the
      // painter's listener (like DecorationImage) will get the image
      // asynchronously, and this will cause it to notify repainting like
      // InkDecoration do it.
      // To prevent this, we store the completer for some time to give the
      // painter a chance to peak the same completer. Then the painter will
      // check the completer is the same and won't notify repainting.
      _tmpItems[key] = _AutodisposableCacheItem(completer,
        delay: const Duration(milliseconds: 200),
        beforeDispose: () {
          _tmpItems.remove(key);
        }
      );
      // Debouncing by key.vectorInfo is needed to discard temporary sizes of
      // the vector info while animating. This prevents the cache from
      // overflowing with multiple images of the same vectorInfo with
      // intermediate sizes.
      final vectorKey = key.vectorInfo.hashCode;
      _savingItems.remove(vectorKey)?.dispose();
      _savingItems[vectorKey] = _AutodisposableCacheItem(completer,
        delay: const Duration(milliseconds: 150),
        beforeDispose: () {
          super.putIfAbsent(key, () => completer, onError: onError);
        }
      );
      return completer;
    } catch (error, stackTrace) {
      if (onError != null) {
        onError(error, stackTrace);
        return null;
      } else {
        rethrow;
      }
    }
  }

  /// The [VectorImageCacheStatus] information for the given `key`.
  VectorImageCacheStatus getStatusForKey(final VectorImageKey key)
  {
    final status = super.statusForKey(key);
    return VectorImageCacheStatus._(
      pending: status.pending,
      keepAlive: status.keepAlive,
      live: status.live,
      temp: _tmpItems.containsKey(key),
    );
  }

  VectorImageCache._();

  final _tmpItems = <VectorImageKey, _AutodisposableCacheItem>{};
  final _savingItems = <int, _AutodisposableCacheItem>{};
}


/// Information about how the [VectorImageCache] is tracking an image.
///
/// A [pending] image is one that has not completed yet. It may also be tracked
/// as [live] because something is listening to it.
///
/// A [keepAlive] image is being held in the cache, which uses Least Recently
/// Used semantics to determine when to evict an image. These images are subject
/// to eviction based on [VectorImageCache.maximumSizeBytes] and
/// [VectorImageCache.maximumSize]. It may be [live], but not [pending].
///
/// A [live] image is being held until its [ImageStreamCompleter] has no more
/// listeners. It may also be [pending] or [keepAlive].
///
/// A [temp] image is being held for a short time regardless of cache limits.
/// 
/// An [untracked] image is not being cached.
///
/// To obtain an [VectorImageCacheStatus], use [VectorImageCache.getStatusForKey].
class VectorImageCacheStatus
{
  /// An image that has been submitted to [VectorImageCache.putIfAbsent], but
  /// not yet completed.
  final bool pending;

  /// An image that has been submitted to [VectorImageCache.putIfAbsent], has
  /// completed, fits based on the sizing rules of the cache, and has not been
  /// evicted.
  ///
  /// Such images will be kept alive even if [live] is false, as long
  /// as they have not been evicted from the cache based on its sizing rules.
  final bool keepAlive;

  /// An image that has been submitted to [VectorImageCache.putIfAbsent] and has
  /// at least one listener on its [ImageStreamCompleter].
  ///
  /// Such images may also be [keepAlive] if they fit in the cache based on its
  /// sizing rules. They may also be [pending] if they have not yet resolved.
  final bool live;

  /// An image that has been submitted to [VectorImageCache.putIfAbsent] and has
  /// at least one listener on its [ImageStreamCompleter].
  ///
  /// Such images may also be [keepAlive] if they fit in the cache based on its
  /// sizing rules. They may also be [pending] if they have not yet resolved.
  final bool temp;

  /// An image that is tracked in some way by the [VectorImageCache], whether
  /// [pending], [keepAlive], or [live].
  bool get tracked => pending || keepAlive || live || temp;

  /// An image that either has not been submitted to
  /// [VectorImageCache.putIfAbsent] or has otherwise been evicted from the
  /// [keepAlive] and [live] caches.
  bool get untracked => !pending && !keepAlive && !live && !temp;

  @override
  bool operator ==(Object other) => other is VectorImageCacheStatus
    && other.runtimeType == runtimeType
    && other.pending == pending
    && other.keepAlive == keepAlive
    && other.live == live
    && other.temp == temp;

  @override
  int get hashCode => Object.hash(pending, keepAlive, live, temp);

  @override
  String toString() => '${objectRuntimeType(this, 'VectorImageCacheStatus')}'
    '(pending: $pending, live: $live, keepAlive: $keepAlive, temp: $temp)';

  const VectorImageCacheStatus._({
    this.pending = false,
    this.keepAlive = false,
    this.live = false,
    this.temp = false,
  }) : assert(!pending || !keepAlive);
}


class _AutodisposableCacheItem
{
  final ImageStreamCompleter completer;

  _AutodisposableCacheItem(this.completer, {
    required final Duration delay,
    required final VoidCallback beforeDispose,
  })
  {
    _completerHandle = completer.keepAlive();
    _timer = Timer(delay, () {
      beforeDispose();
      dispose();
    });
  }
  
  void dispose()
  {
    if (_disposed) return;
    _timer.cancel();
    _completerHandle.dispose();
    _disposed = true;
  }

  /// Timer for deferred cache update.
  late final Timer _timer;

  /// The handle to unlock the completer to be disposed.
  late final ImageStreamCompleterHandle _completerHandle;

  bool _disposed = false;
}
