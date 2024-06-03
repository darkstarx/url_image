import 'dart:typed_data';


enum DownloadedDataType
{
  /// Any Flutter supported raster format like jpeg, png, webp, etc.
  raster,

  /// Utf8-encoded SVG-compatible data.
  vector;

  static DownloadedDataType? fromIndex(final int index)
  {
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}


class DownloadedData
{
  final Uint8List bytes;
  final DownloadedDataType type;

  const DownloadedData(this.bytes, { this.type = DownloadedDataType.raster });
}


abstract interface class DownloadDelegate
{
  Future<DownloadedData> download(final String url);
}
