import 'package:file_storage/file_storage.dart';
import 'package:url_image/url_image.dart';


class MyFileStorage implements FileStorageDelegate
{
  @override
  Future<bool> fileExists(final String fileName)
  {
    return _fileStorage.fileExists(fileName);
  }

  @override
  Future<String> getCachePath()
  {
    return _fileStorage.getCachePath(path: 'images', create: true);
  }

  @override
  Future<List<int>?> loadData(final String fileName)
  {
    return _fileStorage.loadData(fileName);
  }

  @override
  Future<bool> saveData(final String fileName, final List<int> data)
  {
    return _fileStorage.saveData(fileName, data);
  }

  @override
  Future<bool> saveStream(final String fileName, final Stream<List<int>> stream)
  {
    return _fileStorage.saveStream(fileName, stream);
  }

  final _fileStorage = FileStorage();
}
