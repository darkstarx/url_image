import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:url_image/url_image.dart';

import 'downloader.dart';
import 'file_storage.dart';
import 'vector_decoder.dart';


Future<void> main() async
{
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(onMessage);
  UrlImage.config
    ..fileStorage = MyFileStorage()
    ..downloader = const MyDownloader()
    ..vectorDecoder = const MyVectorDecoder()
  ;
  await Future.delayed(const Duration(seconds: 2));
  runApp(const MyApp());
}

void onMessage(final LogRecord record)
{
  var msg = '${record.level.name[0]} ${record.time} ${record.message}';
  if (record.error != null) {
    msg += ' (${record.error})';
  }
  log(msg,
    time: record.time,
    sequenceNumber: record.sequenceNumber,
    level: record.level.value,
    name: record.loggerName,
    zone: record.zone,
    error: record.error,
    stackTrace: record.stackTrace,
  );
}


class MyApp extends StatelessWidget
{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}


class MyHomePage extends StatefulWidget
{
  final String title;

  const MyHomePage({ super.key, required this.title });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}


class _MyHomePageState extends State<MyHomePage>
{
  static const urls = [
    'https://raw.githubusercontent.com/darkstarx/url_image/main/example/media/nature1.jpg',
    'https://raw.githubusercontent.com/darkstarx/url_image/main/example/media/nature2.jpg',
    'https://raw.githubusercontent.com/darkstarx/url_image/main/example/media/nature1.svg',
    'https://raw.githubusercontent.com/darkstarx/url_image/main/example/media/nature2.svg',
  ];

  @override
  Widget build(final BuildContext context)
  {
    final url = urls[_index];
    final name = Uri.parse(url).pathSegments.last;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: InkWell(
        onTap: () {},
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: UrlImage(name: name, url: url),
              ),
            ),
            const SizedBox(height: kToolbarHeight),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
          if (++_index >= urls.length) _index = 0;
        }),
        child: const Icon(Icons.navigate_next),
      ),
    );
  }

  var _index = 0;
}
