import 'dart:typed_data';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_image/url_image.dart';


class MyVectorDecoder implements VectorDecodeDelegate
{
  const MyVectorDecoder();

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
}
