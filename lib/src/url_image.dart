import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'cache.dart';
import 'config.dart';
import 'downloader.dart';
import 'ink_image.dart';


typedef OnLoadingDone = void Function(bool success);

typedef OnImageAppear = void Function(Size? size);


Widget _defaultLoadingBuilder(final BuildContext context)
{
  return const Center(child: CircularProgressIndicator());
}


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
  /// The default is [BoxFit.cover].
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
  final Alignment alignment;

  /// How long it takes to replace current image with another one.
  ///
  /// E.g. if the image changed in the network since last time it's downloaded,
  /// the old one from the local file system is presented firstly, and after
  /// successfull downloading the new image is replacing the old one smoothly
  /// with specified [animationDuration].
  final Duration animationDuration;

  /// The curve of the fade in animation.
  final Curve animationFadeInCurve;

  /// The curve of the fade out animation.
  final Curve animationFadeOutCurve;

  /// Wether the first loaded image should appear with fadein animation.
  ///
  /// If true, the first image appears with animation, otherwise it shows
  /// immediately.
  final bool animateInitialImage;

  /// Whether the image is drawing on the underlying material, so that [InkWell]
  /// and [InkResponse] splashes will render over it.
  final bool ink;

  /// The [child] contained by the container.
  ///
  /// It's using only when [ink] is true.
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
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.animationDuration = defaultAnimationDuration,
    this.animationFadeInCurve = Curves.easeIn,
    this.animationFadeOutCurve = Curves.easeOut,
    this.animateInitialImage = true,
    this.ink = true,
    this.child,
    this.loadingBuilder = _defaultLoadingBuilder,
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
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.animationDuration = defaultAnimationDuration,
    this.animationFadeInCurve = Curves.easeIn,
    this.animationFadeOutCurve = Curves.easeOut,
    this.animateInitialImage = true,
    this.ink = true,
    this.child,
    this.loadingBuilder = _defaultLoadingBuilder,
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
    _loadImage();
  }

  @override
  void dispose()
  {
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
  void didUpdateWidget(final UrlImage oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration) {
      _animationCtrl.duration = widget.animationDuration;
    }
    if (oldWidget.animationFadeInCurve != widget.animationFadeInCurve
      || oldWidget.animationFadeOutCurve != widget.animationFadeOutCurve
    ) {
      _makeAnimations();
    }
    if (oldWidget.name != widget.name
      || oldWidget.url != widget.url
      || oldWidget.downloader != widget.downloader
      || oldWidget.alignment != widget.alignment
      || oldWidget.width != widget.width
      || oldWidget.height != widget.height
      || oldWidget.fit != widget.fit
      || oldWidget.alignment != widget.alignment
      || oldWidget.ink != widget.ink
      || oldWidget.child != widget.child
    ) {
      _loadImage();
    }
  }

  @override
  Widget build(final BuildContext context)
  {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.constrainWidth(widget.width ?? double.infinity);
      final height = constraints.constrainHeight(widget.height ?? double.infinity);
      Widget content;
      if (_newImage != null) {
        final newImage = _buildImage(_newImage!,
          width: width,
          height: height,
          opacity: _animation.value,
        );
        if (_curImage != null) {
          final curImage = _buildImage(_curImage!,
            width: width,
            height: height,
            opacity: _backAnimation.value,
          );
          content = Stack(
            alignment: Alignment.center,
            children: [ curImage, newImage ],
          );
        } else {
          content = newImage;
        }
      } else if (_curImage != null) {
        content = _buildImage(_curImage!,
          width: width,
          height: height,
        );
      } else if (_done) {
        content = buildErrorWidget(context, Exception('No image'),
          errorBuilder: widget.errorBuilder,
          width: width,
          height: height,
        );
      } else {
        content = widget.loadingBuilder(context);
      }
      return content;
    });
  }

  Widget _buildImage(final ImageProvider image, {
    required double width,
    required double height,
    final double? opacity,
  })
  {
    return widget.ink
      ? InkImage(
          image: image,
          width: width,
          height: height,
          fit: widget.fit,
          alignment: widget.alignment,
          opacity: opacity,
          errorBuilder: widget.errorBuilder,
          child: widget.child,
        )
      : Image(
          image: image,
          width: width,
          height: height,
          fit: widget.fit,
          alignment: widget.alignment,
          opacity: opacity == null
            ? null
            : AlwaysStoppedAnimation(opacity),
          errorBuilder: (context, error, stackTrace) => buildErrorWidget(
            context, error,
            errorBuilder: widget.errorBuilder,
            stackTrace: stackTrace,
            width: width,
            height: height,
            opacity: opacity,
          ),
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

    final firstAnyItem = UrlImage.cache.getAny(widget.url);
    if (firstAnyItem == null) {
      _animateFirst = widget.animateInitialImage;
    } else {
      _addImage(firstAnyItem);
    }

    setState(() => _done = false);
    _reloading = false;
    await for (var item in UrlImage.cache.get(widget.url, name: widget.name)) {
      if (item == firstAnyItem) continue;
      _addImage(item);
      if (_reloading) break;
    }
    if (!_reloading) {
      setState(() => _done = true);
      widget.onLoadingDone?.call(_curImage != null || _newImage != null);
    }

    _loading = null;
    completer.complete();
  }

  void _addImage(final ImageCacheItem image)
  {
    _queue.add(image);
    _checkQueue();
  }

  void _checkQueue()
  {
    if (_animationCtrl.isAnimating == true) return;
    if (_newImage != null) {
      setState(() {
        _curImage = _newImage;
        _newImage = null;
        widget.onImageAppear?.call(_nextImageItem!.imageSize);
        _nextImageItem = null;
      });
    }
    if (!mounted) return;
    if (_queue.isEmpty) return;
    setState(() {
      final nextImageItem = _queue.removeFirst();
      if (_curImage == null && !_animateFirst) {
        _curImage = nextImageItem.image;
        widget.onImageAppear?.call(nextImageItem.imageSize);
      } else {
        _newImage = nextImageItem.image;
        _nextImageItem = nextImageItem;
      }
    });
    if (_newImage != null) {
      _animationCtrl.forward(from: _animationCtrl.lowerBound);
    }
  }

  late AnimationController _animationCtrl;
  late Animation<double> _animation;
  late Animation<double> _backAnimation;

  ImageProvider? _curImage;
  ImageProvider? _newImage;
  ImageCacheItem? _nextImageItem;
  bool _animateFirst = false;
  bool _done = false;
  bool _reloading = false;
  Future? _loading;

  final _queue = Queue<ImageCacheItem>();
}
