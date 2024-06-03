import 'package:flutter/painting.dart';

export 'package:flutter/painting.dart'
  show ImageProvider, ImageInfo, ImageConfiguration, ImageStreamListener;


abstract class DisposableProvider<T extends Object> extends ImageProvider<T>
{
  const DisposableProvider();

  void dispose();
}
