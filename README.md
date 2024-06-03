# UrlImage Package
This is a cross-platform widget that displays a remote image loaded from the network by URL and supports persistent cache. The widget supports all raster image formats supported by flutter, as well as SVG images.

It can be a nice alternative to the `Image.network` if you need to display SVG pictures from the network or if you need persistent cache to quikly show remote images on app restart.

<img width="250" alt="grouped" src="https://raw.githubusercontent.com/darkstarx/url_image/main/example/media/example.gif">

## Features
- Displaying images from the network by URL, including raster and vector formats.
- Storing images in persistent cache, so when the app restarts, all previously downloaded images will appear from the file storage immediately.
- Image providers are not removed from the memory cache when the last widget disposes, so when the widget appears on the screen again, the image is displayed immediately.
- Renewing internal storage smoothly. If previously downloaded image has changed in the remote storage, the widget will show changing animation.
- Custom placeholder builders, i.e. loading widget builder and error widget builder.
- Custom file storage, downloader and vector decoder.
- Supports message logging using the standart [logging](https://pub.dev/packages/logging) package and custom log level.
- Optional notifications about such events like successful or failed attempt to load an image, or displaying an image with its original size (can be useful when the image is used in the photo view gallery).
- Painting the image as regular widget or as an ink on underlying material, so riffles will show over the image.

## Getting started
First add the package to the project `flutter pub add url_image` and import it `import 'package:url_image/url_image.dart';`.

Then configure the config, providing custom delegates:
```dart
  UrlImage.config
    ..fileStorage = MyFileStorage()
    ..downloader = const MyDownloader()
    ..vectorDecoder = const MyVectorDecoder()
  ;
```
You have to implement these delegates first using instruments that you prefer to use in your project. For example, you can use `http` or `dio` for implementing `DownloadDelegate`, or may be you have implemented your own http client, or you can write special repository of images that provides custom headers and needs authorization of requests.
If you don't provide any delegate, the widget will show corresponding message in log when trying to use the delegate.

### FileStorageDelegate
This delegate provides the `UrlImageCache` with functionality to store and load images from the file storage.
It is optional. If you don't provide this delegate, the widget won't restore data from the file storage when the app restarts, so all images will appear with some delay (some time is required to download an image from the Internet).

### DownloadDelegate
This delegate is responsible for downloading the image using its URL. You can implement the downloading method as you wish, but finally you have to provide the widget with the bytes and format (raster/vector) of the downloaded image.
It is optional as well, but you hardly ever will use `UrlImage` without downloading images from the network.

### VectorDecodeDelegate
You may need to show svg pictures from the network. The `UrlImage` can display svg pictures with help of this delegate. It's quite simple, just import the [flutter_svg](https://pub.dev/packages/flutter_svg) package and use it in the implemented delegate to decode the svg picture like that:

```dart
  @override
  Future<VectorInfo> decode(final Uint8List bytes, {
    bool clipViewbox = true,
  }) async
  {
    final info = await vg.loadPicture(SvgBytesLoader(bytes), null,
      clipViewbox: clipViewbox,
    );
    return VectorInfo(info.picture, info.size);
  }
```
Thats it! Now you can download and display svg pictures using `UrlImage` widget, just specify the url of svg picture like you do for other bitmap images.

You can see the implementation examples in the `example` project of this package.

### Logging
If you use the `loggin` package, you can provide the log level for the widget, like:
```dart
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(onMessage);
  UrlImage.config.logLevel = Level.OFF;
```

## Usage

Then you just use the `UrlImage` in your widget tree like you usually use widgets `Image` or `Image.network`:

```dart
  UrlImage(
    name: 'user_profile',
    url: user.pictureUrl,
    fit: BixFit.contain,
  ),
```
