import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'cache.dart';
import 'config.dart';
import 'downloader.dart';
import 'image_item.dart';
import 'ink_image.dart';
import 'vector/provider.dart';


typedef OnLoadingDone = void Function(bool success);

typedef OnImageAppear = void Function(Size? size);


/// The widget downloads an image from the network and displays it.
///
/// First it looks in the memory cache. If there is no image in the memory cache
/// it looks for the image in the filesystem and starts downloading the image
/// simultaneously. If the image is found in the filesystem, it appears. If the
/// image is downloaded successfully, it replaces the image from the filesystem
/// if it's already appeared. After successful downloading the image from the
/// network it's saved in the filesystem (replacing the previous one if it was
/// there).
///
/// If the [url] of the image changes in the same widget (with the same [key]),
/// the widget starts loading the new image and smoothly replaces the old image
/// with the new one using animation with the specified [animationDuration].
class UrlImage extends StatefulWidget
{
  static const defaultAnimationDuration = Duration(milliseconds: 500);

  /// Common configuration.
  static UrlImageConfig get config => UrlImageConfig.instance;

  /// Common cache.
  static UrlImageCache get cache => UrlImageCache.instance;

  static Widget defaultLoadingBuilder(final BuildContext context)
  {
    return const Center(child: CircularProgressIndicator());
  }

  /// The [name] is used to store the image in the filesystem when the image is
  /// downloaded. Also [name] is used to load the image from the filesystem when
  /// the image can't be downloaded from the network.
  ///
  /// The value of [name] should uniquely identify the image among all images
  /// displayed by the [UrlImage].
  ///
  /// Use [UrlImage.nameless] constructor if it's not important how to name the
  /// file in the filesystem. In this case the name will be calculated from the
  /// [url] automatically.
  final String name;

  /// The [url] of the image that should be downloaded.
  final String url;

  /// An alternative downloader instead of common downloader from the
  /// [UrlImageConfig].
  final DownloadDelegate? downloader;

  /// The width of the image to be presented on a material.
  final double? width;

  /// The height of the image to be presented on a material.
  final double? height;

  /// How the image should be inscribed into the box.
  ///
  /// See the discussion at [paintImage] for more details.
  final BoxFit? fit;

  /// How to align the image within its bounds.
  ///
  /// If the [alignment] is [TextDirection]-dependent (i.e. if it is a
  /// [AlignmentDirectional]), then a [TextDirection] must be available
  /// when the image is painted.
  ///
  /// Defaults to [Alignment.center].
  ///
  /// See also:
  ///
  ///  * [Alignment], a class with convenient constants typically used to
  ///    specify an [AlignmentGeometry].
  ///  * [AlignmentDirectional], like [Alignment] for specifying alignments
  ///    relative to text direction.
  final AlignmentGeometry alignment;

  /// How to align animated images, when a new image is fading in and the old
  /// one is fading out.
  ///
  /// Defaults to [AlignmentDirectional.topStart].
  final AlignmentGeometry animationAlignment;

  /// How to fit animated images in the stack, when a new image is fading in and
  /// the old one is fading out.
  ///
  /// Defaults to [StackFit.loose].
  final StackFit animationFit;

  /// How long it takes to replace current image with another one.
  ///
  /// E.g. if the image changed in the network since last time it's downloaded,
  /// the old one from the local file system is presented firstly, and after
  /// successfull downloading the new image is replacing the old one smoothly
  /// with specified [animationDuration].
  ///
  /// Defaults to [defaultAnimationDuration].
  final Duration animationDuration;

  /// The curve of the fade in animation.
  ///
  /// Defaulte to [Curves.easeIn].
  final Curve animationFadeInCurve;

  /// The curve of the fade out animation.
  ///
  /// Defaults to [Curves.easeOut].
  final Curve animationFadeOutCurve;

  /// Wether the first loaded image should appear with fadein animation.
  ///
  /// If true, the first image appears with animation, otherwise it shows
  /// immediately.
  ///
  /// Defaulte to `true`.
  final bool animateInitialImage;

  /// Whether the image is drawing on the underlying material, so that [InkWell]
  /// and [InkResponse] splashes will render over it.
  ///
  /// Defaults to `false`.
  final bool ink;

  /// The [child] contained by the container.
  final Widget? child;

  /// The widget to replace the standard [CircularProgressIndicator] centered on
  /// a material.
  final WidgetBuilder loadingBuilder;

  /// The widget to present if there is no image to present from the network or
  /// local file system.
  final ImageErrorWidgetBuilder? errorBuilder;

  /// A function that will be called when the image load completes successfully
  /// or fails. The result (success or failure) will be passed to this function
  /// as the argument.
  final OnLoadingDone? onLoadingDone;

  /// A function that will be called when a new image comes visible.
  ///
  /// If the size of the new image is resolved, it goes to the argument of this
  /// callback.
  final OnImageAppear? onImageAppear;

  const UrlImage({
    super.key,
    required this.name,
    required this.url,
    this.downloader,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.animationAlignment = AlignmentDirectional.topStart,
    this.animationFit = StackFit.loose,
    this.animationDuration = defaultAnimationDuration,
    this.animationFadeInCurve = Curves.easeIn,
    this.animationFadeOutCurve = Curves.easeOut,
    this.animateInitialImage = true,
    this.ink = false,
    this.child,
    this.loadingBuilder = defaultLoadingBuilder,
    this.errorBuilder,
    this.onLoadingDone,
    this.onImageAppear,
  });

  UrlImage.nameless({
    super.key,
    required this.url,
    this.downloader,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.animationAlignment = AlignmentDirectional.topStart,
    this.animationFit = StackFit.loose,
    this.animationDuration = defaultAnimationDuration,
    this.animationFadeInCurve = Curves.easeIn,
    this.animationFadeOutCurve = Curves.easeOut,
    this.animateInitialImage = true,
    this.ink = false,
    this.child,
    this.loadingBuilder = defaultLoadingBuilder,
    this.errorBuilder,
    this.onLoadingDone,
    this.onImageAppear,
  })
  : name = url.hashCode.toString();

  @override
  State<UrlImage> createState() => UrlImageState();
}


class UrlImageState extends State<UrlImage> with SingleTickerProviderStateMixin
{
  @override
  void initState()
  {
    super.initState();
    _animationCtrl = AnimationController(vsync: this,
      duration: widget.animationDuration,
    )
    ..addListener(() => setState(() {}))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkQueue();
      }
    });
    _makeAnimations();
  }

  @override
  void dispose()
  {
    _queue.clear();
    _animationCtrl.dispose();
    super.dispose();
  }

  @override
  void setState(final VoidCallback fn)
  {
    if (mounted) {
      super.setState(fn);
    } else {
      fn();
    }
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _updateImageConfiguration();
    _loadImage();
  }

  @override
  void didUpdateWidget(final UrlImage oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    if (widget.animationDuration != oldWidget.animationDuration) {
      _animationCtrl.duration = widget.animationDuration;
    }
    if (widget.animationFadeInCurve != oldWidget.animationFadeInCurve
      || widget.animationFadeOutCurve != oldWidget.animationFadeOutCurve
    ) {
      _makeAnimations();
    }
    if (widget.width != oldWidget.width || widget.height != oldWidget.height) {
      _updateImageConfiguration();
    }
    // if (widget.url != oldWidget.url && _queue.isEmpty) {
    //   _curImageItem = null;
    // }
    if (widget.name != oldWidget.name
      || widget.url != oldWidget.url
      || widget.downloader != oldWidget.downloader
      || widget.width != oldWidget.width
      || widget.height != oldWidget.height
    ) {
      _loadImage();
    }
  }

  @override
  Widget build(final BuildContext context)
  {
    final newImageItem = _newImageItem;
    final curImageItem = _curImageItem;
    Widget? newImage;
    Widget? curImage;
    if (newImageItem != null) {
      newImage = InkImage(
        image: newImageItem.image,
        imageSize: newImageItem.size,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        opacity: _animation.value,
        errorBuilder: widget.errorBuilder,
      );
      if (curImageItem != null) {
        curImage = InkImage(
          image: curImageItem.image,
          imageSize: curImageItem.size,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          opacity: _backAnimation.value,
          errorBuilder: widget.errorBuilder
        );
      }
    } else if (curImageItem != null) {
      curImage = InkImage(
        image: curImageItem.image,
        imageSize: curImageItem.size,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        errorBuilder: widget.errorBuilder
      );
    }
    if (curImage != null || newImage != null) {
      final stack = Stack(
        alignment: widget.animationAlignment,
        fit: widget.animationFit,
        children: [
          if (curImage != null) curImage,
          if (newImage != null) newImage,
          ?widget.child,
        ],
      );
      return widget.ink ? stack : Material(
        type: MaterialType.transparency,
        child: stack,
      );
    } else if (_done) {
      return buildErrorWidget(context, Exception('No image'),
        errorBuilder: widget.errorBuilder,
        width: widget.width,
        height: widget.height,
      );
    } else {
      return widget.loadingBuilder(context);
    }
  }

  void _updateImageConfiguration()
  {
    _imageConfiguration = createLocalImageConfiguration(context,
      size: widget.width != null && widget.height != null
        ? Size(widget.width!, widget.height!)
        : null,
    );
  }

  void _makeAnimations()
  {
    _animation = CurvedAnimation(
      parent: _animationCtrl,
      curve: widget.animationFadeInCurve,
    );
    _backAnimation = CurvedAnimation(
      parent: ReverseAnimation(_animationCtrl),
      curve: widget.animationFadeOutCurve,
    );
  }

  Future<void> _loadImage() async
  {
    while (_loading != null) {
      _reloading = true;
      await _loading;
    }
    final completer = Completer();
    _loading = completer.future;

    var loaded = false;

    final firstAnyItem = UrlImage.cache.getAny(widget.url);
    if (firstAnyItem == null) {
      _animateFirst = widget.animateInitialImage;
    } else {
      final sizeOrFuture = _resolveImageSize(firstAnyItem.image);
      final size = sizeOrFuture is Size ? sizeOrFuture : await sizeOrFuture;
      _addImage(ImageItem(image: firstAnyItem.image, size: size));
      loaded = true;
    }

    setState(() => _done = false);
    _reloading = false;
    if (firstAnyItem == null) {
      await for (var item in UrlImage.cache.get(widget.url, name: widget.name)) {
        if (item == firstAnyItem) continue;
        final sizeOrFuture = _resolveImageSize(item.image);
        final size = sizeOrFuture is Size ? sizeOrFuture : await sizeOrFuture;
        _addImage(ImageItem(image: item.image, size: size));
        loaded = true;
        if (_reloading) break;
      }
    }
    if (!_reloading) {
      setState(() {
        _done = true;
        _noData = !loaded;
      });
      if (_noData && !_animationCtrl.isAnimating) {
        setState(() => _curImageItem = null);
      }
      widget.onLoadingDone?.call(_curImageItem != null || _newImageItem != null);
    }

    _loading = null;
    completer.complete();
  }

  void _addImage(final ImageItem image)
  {
    _queue.add(image);
    _checkQueue();
  }

  void _checkQueue()
  {
    if (_animationCtrl.isAnimating == true) return;
    if (_newImageItem != null) {
      setState(() {
        _curImageItem = _newImageItem;
        _newImageItem = null;
        widget.onImageAppear?.call(_curImageItem!.size);
      });
    }
    if (!mounted) return;
    if (_queue.isEmpty) {
      if (_noData) {
        setState(() {
          _curImageItem = null;
          widget.onImageAppear?.call(_curImageItem!.size);
        });
      }
      return;
    }
    setState(() {
      final nextImageItem = _queue.removeFirst();
      assert(_newImageItem == null);
      if (_curImageItem == null && !_animateFirst) {
        _curImageItem = nextImageItem;
        widget.onImageAppear?.call(nextImageItem.size);
      } else {
        _newImageItem = nextImageItem;
      }
    });
    if (_newImageItem != null) {
      _animationCtrl.forward(from: _animationCtrl.lowerBound);
    }
  }

  FutureOr<Size> _resolveImageSize(final ImageProvider imageProvider)
  {
    if (imageProvider is VectorProvider) {
      return imageProvider.vectorInfo.size;
    }
    Size? syncSize;
    final completer = Completer<Size>();
    final imageStream = imageProvider.resolve(_imageConfiguration);
    final imageStreamListener = ImageStreamListener(
      (info, synchronousCall) {
        final size = Size(
          info.image.width / info.scale,
          info.image.height / info.scale,
        );
        if (synchronousCall) {
          syncSize = size;
        }
        completer.complete(size);
        info.dispose();
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    imageStream.addListener(imageStreamListener);
    return syncSize ?? completer.future;
  }

  late AnimationController _animationCtrl;
  late Animation<double> _animation;
  late Animation<double> _backAnimation;
  late ImageConfiguration _imageConfiguration;

  ImageItem? _curImageItem;
  ImageItem? _newImageItem;
  bool _animateFirst = false;
  bool _done = false;
  bool _noData = false;
  bool _reloading = false;
  Future? _loading;

  final _queue = Queue<ImageItem>();
}
