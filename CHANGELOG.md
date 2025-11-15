## 1.2.0

* The image `fit` is nullable now and its value is `null` by default.
* Fixed the size of vector images with `BoxFit.none`.
* Added the `animationFit` property. It can be helpful when placing the image in a [Column] or a [Row] with [CrossAxisAlignment.stretch] to properly align animated images with different sizes.
* The `ink` property is now `false` by default.
* Reduced image blinking on hot initialization (from cache).
* Rasterized vector images are now cached in the separate [VectorImageCache] instead of the common `PaintingBinding.instance.imageCache` to eliminate image eviction due to cache overflow and to reduce blinking of vector images during size animation in the [Hero] widget.

## 1.1.0

* Image layout and alignment have been fixed. [UrlImage] now has its own size based on the source image size when placed in an unconstrained area like [Column] and [Row].
* [ImageCacheItem] doesn't have the image size anymore since it depends on the current [BuildContext] parameters.

## 1.0.0

* Updated file storage interface.
* Handling exceptions of caching images to the file storage.

## 0.0.1

* Initial release.

[//]: #
[UrlImage]: https://pub.dev/packages/url_image
[Column]: https://api.flutter.dev/flutter/widgets/Column-class.html
[Row]: https://api.flutter.dev/flutter/widgets/Row-class.html
