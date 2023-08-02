import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resumable_upload/resumable_upload.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resumable upload Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Resumable upload Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String process = '0%';
  late UploadClient? client;
  final LocalCache _localCache = LocalCache();

  _upload_func() async {
    final filePath = await filePathPicker();
    final File file = File(filePath!);
    const String blobUrl =
        'https://worksamplestorageaccount.blob.core.windows.net/blob-video/tempVideo.mp4';
    const String sasToken =
        'sv=2021-10-04&spr=https%2Chttp&si=policy&sr=c&sig=8HviQasX5hHatEhc%2BQM91flI8hVobQ8WGfyZxj1kCII%3D';

    try {
      client = UploadClient(
        file: file,
        cache: _localCache,
        blobConfig: BlobConfig(blobUrl: blobUrl, sasToken: sasToken),
      );
      client!.uploadBlob(
        onProgress: (count, total, response) {
          final num = ((count / total) * 100).toInt().toString();
          setState(() {
            process = '$num%';
          });
        },
        onComplete: (path, response) {
          setState(() {
            process = 'Completed';
          });
        },
      );
    } catch (e) {
      setState(() {
        process = e.toString();
      });
    }
  }

  Future<String?> filePathPicker() async {
    File? file;

    try {
      final XFile? galleryFile = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
      );

      if (galleryFile == null) {
        return null;
      }

      file = File(galleryFile.path);
    } catch (e) {
      return null;
    }

    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '$process',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(
              height: 20.0,
            ),
            InkWell(
              onTap: () {
                setState(() {
                  process = 'Cancelled';
                });
                client!.cancel();
              },
              child: Container(
                color: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32.0, vertical: 16.0),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _upload_func,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
