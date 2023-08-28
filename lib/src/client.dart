import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:resumable_upload/src/blob_config.dart';
import 'package:resumable_upload/src/cache.dart';
import 'package:resumable_upload/src/upload_metadata.dart';
import 'package:resumable_upload/src/upload_status.dart';
import 'package:dio/dio.dart';

import 'exception.dart';

typedef ProgressCallback = void Function(
    int count, int total, Response? response);

typedef CompleteCallback = void Function(String path, Response response);

typedef FailedCallback = void Function(String e);

class UploadClient {
  // The file to upload
  final File file;

  // Any additional header
  Map<String, dynamic>? headers;

  // Azure blob configuration
  BlobConfig? blobConfig;

  // The chunk size
  // default is 4Mb
  final int chunkSize;

  // Upload file size in bytes
  int fileSize = 0;

  // Upload status
  UploadStatus _status;

  // BlockId list
  List<String> blockIds = [];

  // Upload meta data for store
  late UploadMetaData metaData;

  // Offset value
  int offset = 0;

  // unique generated string by file name
  late String fingerPrint;

  // Callback function on progress
  ProgressCallback? _onProgress;

  // Callback function after upload
  CompleteCallback? _onComplete;

  // Upload Cache
  // default is MemoryCache
  final UploadCache cache;

  // Request timeout
  // default is 30 seconds
  final Duration timeout;

  // Callback fucntion on timeout request
  Function()? _onTimeout;

  FailedCallback? _onFailed;

  UploadClient({
    required this.file,
    this.headers,
    this.blobConfig,
    int? chunkSize,
    UploadCache? cache,
    Duration? timeout,
  })  : chunkSize = chunkSize ?? 4 * 1024 * 1024,
        cache = cache ?? MemoryCache(),
        timeout = timeout ?? const Duration(seconds: 30),
        _status = UploadStatus.initialized {
    fingerPrint = generateFingerprint();
    metaData = UploadMetaData(fingerPrint, offset);
  }

  uploadBlob({
    ProgressCallback? onProgress,
    CompleteCallback? onComplete,
    FailedCallback? onFailed,
    Function()? onTimeout,
  }) async {
    if (blobConfig == null) {
      throw ResumableUploadException('Blob config missing');
    }

    _status = UploadStatus.started;

    _onProgress = onProgress;

    _onComplete = onComplete;

    _onFailed = onFailed;

    _onTimeout = onTimeout;

    final commitUri = blobConfig!.getCommitUri();

    if (!metaData.isChucksCompleted) {
      _canResume();
      await uploadChunk(blobConfig!.getRequestUri);
    }

    if (metaData.offset >= fileSize) {
      final blockListXml =
          '<BlockList>${blockIds.map((id) => '<Latest>$id</Latest>').join()}</BlockList>';

      final response = await _commitUpload(commitUri, blockListXml);

      cache.delete(fingerPrint);

      _onComplete?.call(response.requestOptions.path, response);
    }
  }

  Future<Response?> uploadChunk(Function(String) getUrl) async {
    Response? response;
    fileSize = await file.length();

    _canResume();

    while (offset < fileSize) {
      bool canUpload = [
        UploadStatus.paused,
        UploadStatus.started,
        UploadStatus.initialized,
        UploadStatus.uploading
      ].contains(_status);

      if (!canUpload) throw _uploadError();

      final blockId = generateBlockId(metaData.index);

      if (blockIds.contains(blockId)) continue;

      print("${metaData.index}  $blockId");

      final url = getUrl(blockId);

      final List<int> data = await file.readAsBytes();

      final size =
          offset + chunkSize > data.length ? data.length : offset + chunkSize;

      final chunkData = data.sublist(offset, size);

      try {
        response = await Dio().put(
          url,
          data: Stream.fromIterable(chunkData.map((e) => [e])),
          options: Options(
            headers: {
              'x-ms-blob-type': 'BlockBlob',
              'Content-Length': chunkData.length,
            },
            receiveTimeout: timeout.inMilliseconds,
          ),
          onSendProgress: (count, total) {
            _onProgress?.call(count, total, null);
          },
        ).timeout(timeout, onTimeout: () {
          _onTimeout?.call();
          return Response(requestOptions: RequestOptions(path: ""));
        });

        if (response.statusCode == 201 &&
            !metaData.blockIds.contains(blockId)) {
          blockIds.add(blockId);
          offset += chunkData.length;
          metaData.offset = offset;
          metaData.index++;

          metaData.isUploading = true;

          if (offset >= fileSize) {
            metaData.isChucksCompleted = true;
          }
          cache.set(metaData);
          _onProgress?.call(offset, fileSize, response);
        } else {
          metaData.isUploading = false;
          cache.set(metaData);
          _status = UploadStatus.error;
          throw ResumableUploadException('Upload Failed', response: response);
        }
        print(blockIds.toString());
      } catch (e) {
        if (e is SocketException) {
          _onFailed?.call('failed due to network');
        } else {
          _onFailed?.call('failed');
        }
        metaData.isUploading = false;
        cancelClient();
        break;
      }
    }
    return response;
  }

  void cancelClient() {
    _status = UploadStatus.error;
  }

  void cancel() {
    _status = UploadStatus.cancelled;
    cache.delete(fingerPrint);
    clearCache();
    throw ResumableUploadException('User cancelled upload!');
  }

  clearCache() => cache.clearAll();
  Future<Response> _commitUpload(commitUri, dynamic body) async {
    Response commitResponse;
    try {
      _onFailed?.call('Processing');
      commitResponse = await Dio().put(commitUri, data: body);

      if (commitResponse.statusCode == 201) {
        cache.delete(fingerPrint);
        return commitResponse;
      }
      _onFailed?.call('failed to commit');
      return commitResponse;
    } catch (e) {
      if (e is SocketException) {
        _updateUploadStatus(false);
        _onFailed?.call('failed');
        cancelClient();
      } else {
        cancel();
      }

      throw ResumableUploadException('Error in committing blocks');
    }
  }

  Future<void> _canResume() async {
    final uploadData = await cache.get(fingerPrint);

    if (uploadData == null) return;

    offset = uploadData.offset;
    blockIds = uploadData.blockIds;
    uploadData.isUploading = true;
    metaData = uploadData;
    _onProgress?.call(offset, fileSize, null);
  }

  void _updateUploadStatus(bool isUploading) {
    metaData.isUploading = isUploading;
    cache.set(metaData);
  }

  String generateFingerprint() =>
      file.path.split('/').last.replaceAll(RegExp(r'\W+'), '');

  String generateBlockId(int index) {
    final String blockId = 'pro-${index.toString().padLeft(5, '0')}';
    return base64.encode(utf8.encode(blockId));
  }

  ResumableUploadException _uploadError() {
    _updateUploadStatus(false);
    switch (_status) {
      case UploadStatus.cancelled:
        return ResumableUploadException('User cancelled upload!');
      case UploadStatus.error:
        return ResumableUploadException('Upload failed with error!');
      case UploadStatus.completed:
        return ResumableUploadException('Upload already completed!');
      default:
        cache.delete(fingerPrint);
        return ResumableUploadException('Upload failed!');
    }
  }
}
