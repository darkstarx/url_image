import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';


Widget buildErrorWidget(final BuildContext context, final Object error, {
  final ImageErrorWidgetBuilder? errorBuilder,
  final StackTrace? stackTrace,
  final double? width,
  final double? height,
  final double? opacity,
})
{
  if (errorBuilder != null) {
    return errorBuilder(context, error, stackTrace);
  }
  if (kDebugMode) {
    final widget = Placeholder(
      color: const Color(0xCF8D021F),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Center(
          child: Text('$error',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              shadows: <Shadow>[ Shadow(blurRadius: 1.0) ],
            ),
          ),
        ),
      ),
    );
    if (opacity == null) return widget;
    return Opacity(opacity: opacity, child: widget);
  }
  return SizedBox(width: width, height: height);
}


class InkImage extends StatefulWidget
{
  /// The image to be painted into the decoration.
  final ImageProvider image;

  /// The image size.
  final Size imageSize;

  /// A width to apply to the widget.
  final double? width;

  /// A height to apply to the widget.
  final double? height;

  /// How the image should be inscribed into the box.
  final BoxFit? fit;

  /// How to align the image within its bounds.
  final AlignmentGeometry alignment;

  /// An opacity of the image.
  final double? opacity;

  /// The [child] contained by the widget.
  final Widget? child;

  /// A builder function that is called if an error occurs during image loading.
  final ImageErrorWidgetBuilder? errorBuilder;

  const InkImage({
    super.key,
    required this.image,
    required this.imageSize,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.opacity,
    this.child,
    this.errorBuilder,
  });

  @override
  State<InkImage> createState() => _InkImageState();
}


class _InkImageState extends State<InkImage>
{
  @override
  void initState()
  {
    super.initState();
    _errorCompleter = Completer();
  }

  @override
  void didUpdateWidget(final InkImage oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _errorCompleter = Completer();
    }
  }

  @override
  Widget build(final BuildContext context)
  {
    return FutureBuilder(
      future: _errorCompleter.future,
      builder: (context, snapshot) {
        final opacity = widget.opacity;
        if (snapshot.connectionState == ConnectionState.done
          && snapshot.hasError
        ) {
          return buildErrorWidget(context, snapshot.error!,
            errorBuilder: widget.errorBuilder,
            stackTrace: snapshot.stackTrace,
            width: widget.width,
            height: widget.height,
            opacity: opacity,
          );
        }
        return RawInkImage(
          image: widget.image,
          imageSize: widget.imageSize,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          opacity: widget.opacity,
          onImageError: (exception, stackTrace) {
            if (_errorCompleter.isCompleted) return;
            _errorCompleter.completeError(exception, stackTrace);
          },
          child: widget.child,
        );
      },
    );
  }

  late Completer _errorCompleter;
}


class RawInkImage extends SingleChildRenderObjectWidget
{
  /// The image to be painted into the decoration.
  final ImageProvider image;

  /// The image size.
  final Size imageSize;

  /// A width to apply to the widget.
  final double? width;

  /// A height to apply to the widget.
  final double? height;

  /// How the image should be inscribed into the box.
  final BoxFit? fit;

  /// How to align the image within its bounds.
  final AlignmentGeometry alignment;

  /// An opacity of the [image].
  final double? opacity;

  /// An optional error callback for errors emitted when loading the [image].
  final ImageErrorListener? onImageError;

  const RawInkImage({
    super.key,
    required this.image,
    required this.imageSize,
    this.width,
    this.height,
    this.fit,
    required this.alignment,
    this.opacity,
    this.onImageError,
    super.child,
  });

  @override
  RenderObject createRenderObject(final BuildContext context)
  {
    return InkImageRenderObject(
      image: image,
      imageSize: imageSize,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      opacity: opacity,
      controller: Material.maybeOf(context),
      configuration: createLocalImageConfiguration(context),
      onImageError: onImageError,
    );
  }

  @override
  void updateRenderObject(final BuildContext context,
    final InkImageRenderObject renderObject,
  )
  {
    super.updateRenderObject(context, renderObject);
    renderObject
      ..image = image
      ..imageSize = imageSize
      ..width = width
      ..height = height
      ..fit = fit
      ..alignment = alignment
      ..opacity = opacity
      ..controller = Material.maybeOf(context)
      ..configuration = createLocalImageConfiguration(context)
      ..onImageError = onImageError
    ;
  }
}


class InkImageRenderObject extends RenderProxyBox
{
  ImageProvider get image => _image;

  set image(final ImageProvider value)
  {
    if (_image == value) return;
    _image = value;
    _updateDecoration();
  }

  Size get imageSize => _imageSize;

  set imageSize(final Size value)
  {
    if (_imageSize == value) return;
    _imageSize = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  double? get width => _width;

  set width(final double? value)
  {
    if (_width == value) return;
    _width = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  double? get height => _height;

  set height(final double? value)
  {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  BoxFit? get fit => _fit;

  set fit(final BoxFit? value)
  {
    if (_fit == value) return;
    _fit = value;
    _updateDecoration();
  }

  AlignmentGeometry get alignment => _alignment;

  set alignment(final AlignmentGeometry value)
  {
    if (_alignment == value) return;
    _alignment = value;
    _updateDecoration();
  }

  double? get opacity => _opacity;

  set opacity(final double? value)
  {
    if (_opacity == value) return;
    _opacity = value;
    _updateDecoration();
  }

  ImageErrorListener? get onImageError => _onImageError;

  set onImageError(final ImageErrorListener? value)
  {
    if (_onImageError == value) return;
    _onImageError = value;
    _updateDecoration();
  }

  MaterialInkController? get controller => _controller;

  set controller(final MaterialInkController? value)
  {
    if (_controller == value) return;
    _controller = value;
    _updateDecoration();
  }

  ImageConfiguration get configuration => _configuration;

  set configuration(final ImageConfiguration value)
  {
    if (_configuration == value) return;
    _configuration = value;
    _updateDecoration();
  }

  InkImageRenderObject({
    required final ImageProvider image,
    required final Size imageSize,
    final double? width,
    final double? height,
    final BoxFit? fit,
    required final AlignmentGeometry alignment,
    final double? opacity,
    final MaterialInkController? controller,
    required final ImageConfiguration configuration,
    final ImageErrorListener? onImageError,
  })
  : _image = image
  , _imageSize = imageSize
  , _width = width
  , _height = height
  , _fit = fit
  , _alignment = alignment
  , _opacity = opacity
  , _controller = controller
  , _configuration = configuration
  , _onImageError = onImageError
  ;

  @override
  void attach(final PipelineOwner owner)
  {
    super.attach(owner);
    _updateDecoration();
  }

  @override
  void detach()
  {
    _disposeInk();
    assert(_inkDecoration == null);
    super.detach();
  }

  @override
  double computeMinIntrinsicWidth(final double height)
  {
    if (height.isFinite) {
      return _calculateSize(BoxConstraints.tightFor(height: height)).width;
    }
    if (_width != null) {
      return _width!;
    }
    if (_height != null) {
      if (_imageSize.height == 0.0) return 0.0;
      return _height! * (_imageSize.width / _imageSize.height);
    }
    return _imageSize.width;
  }

  @override
  double computeMaxIntrinsicWidth(final double height)
  {
    return computeMinIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(final double width)
  {
    if (width.isFinite) {
      return _calculateSize(BoxConstraints.tightFor(width: width)).height;
    }
    if (_height != null) {
      return _height!;
    }
    if (_width != null) {
      if (_imageSize.width == 0.0) return 0.0;
      return _width! * (_imageSize.height / _imageSize.width);
    }
    return _imageSize.height;
  }

  @override
  double computeMaxIntrinsicHeight(final double width)
  {
    return computeMinIntrinsicHeight(width);
  }

  @override
  void performLayout()
  {
    size = _calculateSize(constraints);
    if (child != null) {
      child!.layout(BoxConstraints.tight(size), parentUsesSize: true);
    }
  }

  Size _calculateSize(final BoxConstraints constraints)
  {
    final Size size;
    switch (_fit) {
      case BoxFit.scaleDown:
        size = constraints.loosen()
          .constrainSizeAndAttemptToPreserveAspectRatio(_imageSize);
      case BoxFit.contain:
      case BoxFit.cover:
      case BoxFit.fill:
      case BoxFit.fitHeight:
      case BoxFit.fitWidth:
      case BoxFit.none:
      case null:
        size = BoxConstraints.tight(constraints.biggest)
          .constrainSizeAndAttemptToPreserveAspectRatio(_imageSize)
        ;
    }
    return constraints.constrain(Size(
      _width ?? size.width,
      _height ?? size.height
    ));
  }

  void _updateDecoration()
  {
    if (!attached) return;
    final controller = _controller;
    if (controller == null || _inkDecoration?.controller != controller) {
      _disposeInk();
    }
    if (controller != null) {
      final decoration = BoxDecoration(
        image: DecorationImage(
          image: _image,
          fit: _fit,
          alignment: _alignment,
          opacity: _opacity ?? 1.0,
          onError: _onImageError,
        ),
      );
      if (_inkDecoration == null) {
        _inkDecoration = InkDecoration(
          decoration: decoration,
          configuration: _configuration,
          controller: controller,
          referenceBox: this,
          onRemoved: _onInkRemoved,
        );
      } else {
        _inkDecoration!.decoration = decoration;
        _inkDecoration!.configuration = _configuration;
      }
    }
  }

  void _disposeInk()
  {
    _inkDecoration?.dispose();
  }

  void _onInkRemoved()
  {
    _inkDecoration = null;
  }

  ImageProvider _image;
  Size _imageSize;
  double? _width;
  double? _height;
  BoxFit? _fit;
  AlignmentGeometry _alignment;
  double? _opacity;
  ImageErrorListener? _onImageError;

  MaterialInkController? _controller;
  ImageConfiguration _configuration;

  InkDecoration? _inkDecoration;
}
