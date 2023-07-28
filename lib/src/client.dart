import 'dart:convert';
import 'dart:io';

import 'package:resumable_upload/src/blob_config.dart';
import 'package:resumable_upload/src/cache.dart';
import 'package:resumable_upload/src/upload_metadata.dart';
import 'package:resumable_upload/src/upload_status.dart';
import 'package:http/http.dart' as http;

import 'exception.dart';

typedef ProgressCallback = void Function(
    int count, int total, http.Response? response);

typedef CompleteCallback = void Function(String path, http.Response response);

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

  UploadClient(
      {required this.file,
      this.headers,
      this.blobConfig,
      int? chunkSize,
      UploadCache? cache,
      Duration? timeout})
      : chunkSize = chunkSize ?? 4 * 1024 * 1024,
        cache = cache ?? MemoryCache(),
        timeout = timeout ?? const Duration(seconds: 30),
        _status = UploadStatus.initialized {
    fingerPrint = generateFingerprint();
    metaData = UploadMetaData(fingerPrint, offset);
  }

  uploadBlob({
    ProgressCallback? onProgress,
    CompleteCallback? onComplete,
    Function()? onTimeout,
  }) async {
    if (blobConfig == null) {
      throw ResumableUploadException('Blob config missing');
    }

    _status = UploadStatus.started;

    _onProgress = onProgress;

    _onComplete = onComplete;

    _onTimeout = onTimeout;

    final commitUri = blobConfig!.getCommitUri();

    http.Response? uploadResposne = await _upload(blobConfig!.getRequestUri);

    // If Response has Timeout to stop following process
    if (uploadResposne?.statusCode == HttpStatus.requestTimeout) return;

    final blockListXml =
        '<BlockList>${blockIds.map((id) => '<Latest>$id</Latest>').join()}</BlockList>';

    http.Response response = await _commitUpload(commitUri, blockListXml);

    cache.delete(fingerPrint);

    _onComplete?.call(response.request!.url.path, response);
  }

  Future<http.Response?> _upload(Function(String) getUrl) async {
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

      final String blockId = _generateBlockId(metaData.index);

      final url = getUrl(blockId);

      final List<int> data = await file.readAsBytes();

      final size =
          offset + chunkSize > data.length ? data.length : offset + chunkSize;

      final chunkData = data.sublist(offset, size);

      Future? uploadFuture = http.put(url, body: chunkData);
      final response = await uploadFuture.timeout(timeout, onTimeout: () {
        _onTimeout?.call();
        return http.Response('', HttpStatus.requestTimeout,
            reasonPhrase: 'Request timeout');
      });
      if (response.statusCode == 201) {
        blockIds.add(blockId);

        offset += chunkData.length;

        metaData.offset = offset;
        metaData.blockIds.add(blockId);
        metaData.index++;
        metaData.isUploading = true;
        cache.set(metaData);
        _onProgress?.call(offset, fileSize, response);
      } else {
        metaData.isUploading = false;
        cache.set(metaData);
        _status = UploadStatus.error;
        throw ResumableUploadException('Upload Failed', response: response);
      }
    }
    return null;
  }

  cancel() {
    _status = UploadStatus.cancelled;
    cache.delete(fingerPrint);
    return ResumableUploadException('User cancelled upload!');
  }

  clearCache() => cache.clearAll();

  _updateUploadStatus(bool isUploading) {
    metaData.isUploading = isUploading;
    cache.set(metaData);
  }

  Future<http.Response> _commitUpload(Uri commitUri, dynamic body) async {
    final commitResponse = await http.put(commitUri, body: body);
    if (commitResponse.statusCode == 201) {
      return commitResponse;
    } else {
      _updateUploadStatus(false);
      throw ResumableUploadException('Error in committing blocks',
          response: commitResponse);
    }
  }

  String _generateBlockId(int index) {
    final String blockId = 'pro-${index.toString().padLeft(5, '0')}';
    return base64.encode(utf8.encode(blockId));
  }

  String generateFingerprint() =>
      file.path.split('/').last.replaceAll(RegExp(r'\W+'), '');

  void _canResume() async {
    UploadMetaData? uploadData = await cache.get(fingerPrint);

    if (uploadData == null) return;

    offset = uploadData.offset;

    blockIds = uploadData.blockIds;

    uploadData.isUploading = true;

    metaData = uploadData;

    _onProgress?.call(offset, fileSize, null);
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
        return ResumableUploadException('Upload failed!');
    }
  }
}
