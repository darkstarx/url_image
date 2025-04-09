import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';


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
        return Ink.image(
          image: widget.image,
          fit: widget.fit,
          alignment: widget.alignment,
          width: widget.width,
          height: widget.height,
          colorFilter: opacity == null
            ? null
            : ColorFilter.mode(
                Colors.white.withValues(alpha: opacity),
                BlendMode.dstIn,
              ),
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
