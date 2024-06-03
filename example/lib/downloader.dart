import 'dart:io';

import 'package:http/http.dart';
import 'package:url_image/url_image.dart';


class MyDownloader implements DownloadDelegate
{
  const MyDownloader();

  @override
  Future<DownloadedData> download(final String url) async
  {
    final uri = Uri.parse(url);
    final response = await get(uri);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Response code ${response.statusCode}', uri: uri);
    }
    final contentTypeHeader = response.headers[HttpHeaders.contentTypeHeader];
    var isSvg = false;
    if (contentTypeHeader != null) {
      final contentType = ContentType.parse(contentTypeHeader);
      if (contentType.primaryType == 'image') {
        isSvg = contentType.subType == 'svg+xml';
      } else if (contentType.primaryType == ContentType.binary.primaryType
          && contentType.subType == ContentType.binary.subType
      ) {
      } else {
        throw('Bad content: $contentTypeHeader');
      }
    }
    isSvg |= url.endsWith('.svg');
    return DownloadedData(response.bodyBytes,
      type: isSvg ? DownloadedDataType.vector : DownloadedDataType.raster,
    );
  }
}
