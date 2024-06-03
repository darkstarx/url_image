import 'package:logging/logging.dart';

import 'downloader.dart';
import 'file_storage.dart';
import 'logger.dart';
import 'vector_graphics.dart';


class UrlImageConfig
{
  static final instance = UrlImageConfig();

  /// The level of internal messages.
  Level get logLevel => log.level;

  set logLevel(final Level? value)
  {
    if (log.level == value) return;
    hierarchicalLoggingEnabled = true;
    log.level = value;
  }

  /// The delegate which purpose is downloading the data and defining its type.
  DownloadDelegate? downloader;

  /// The delegate which purpose is to load and save data in the file system.
  FileStorageDelegate? fileStorage;

  /// The delegate which purpose is to rasterize vector graphics.
  VectorDecodeDelegate? vectorDecoder;
}
