abstract interface class FileStorageDelegate
{
  /// Returns the path to application's cache in the file storage.
  ///
  /// This is the path to the temporary files. Cached files can be deleted by
  /// the platform at any time.
  Future<String> getCachePath();

  /// Checks whether the file with specified [fileName] exists.
  Future<bool> fileExists(final String fileName);

  /// Loads the data from the file [fileName].
  Future<List<int>?> loadData(final String fileName);

  /// Saves the [data] to the file [fileName].
  Future<bool> saveData(final String fileName, final List<int> data);

  /// Saves the [stream] to the file [fileName].
  Future<bool> saveStream(final String fileName, final Stream<List<int>> stream);
}
