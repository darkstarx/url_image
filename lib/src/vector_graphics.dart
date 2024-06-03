import 'dart:typed_data';
import 'dart:ui';


/// The deocded result of a vector graphics asset.
class VectorInfo
{
  /// A picture generated from a vector graphics image.
  final Picture picture;

  /// The target size of the picture.
  ///
  /// This information is used to scale and position the picture based on the
  /// available space and alignment.
  final Size size;

  const VectorInfo(this.picture, this.size);
}


abstract interface class VectorDecodeDelegate
{
  Future<VectorInfo> decode(final Uint8List bytes, { bool clipViewbox = true });
}
