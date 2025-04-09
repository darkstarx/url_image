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
