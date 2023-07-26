import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:pro_resumable_upload/src/blob_config.dart';
import 'package:pro_resumable_upload/src/cache.dart';
import 'package:pro_resumable_upload/src/upload_metadata.dart';
import 'package:pro_resumable_upload/src/upload_status.dart';
import 'package:http/http.dart' as http;

import 'exception.dart';

typedef ProgressCallback = void Function(
    int count, int total, http.Response? response);

typedef CompleteCallback = void Function(http.Response response);

class UploadClient {
  final File file;

  Map<String, dynamic>? headers;

  BlobConfig? blobConfig;

  final int chunkSize;

  int fileSize = 0;

  UploadStatus _status;

  List<String> blockIds = [];

  late UploadMetaData metaData;

  int offset = 0;

  late String fingerPrint;

  ProgressCallback? _onProgress;

  CompleteCallback? _onComplete;

  final UploadCache cache;

  UploadClient(
      {required this.file,
      this.headers,
      this.blobConfig,
      int? chunkSize,
      UploadCache? cache})
      : chunkSize = chunkSize ?? 1 * 1024 * 1024,
        cache = cache ?? MemoryCache(),
        _status = UploadStatus.initialized {
    fingerPrint = generateFingerprint();
    metaData = UploadMetaData(fingerPrint, offset);
  }

  uploadBlob({
    ProgressCallback? onProgress,
    CompleteCallback? onComplete,
  }) async {
    if (blobConfig == null)
      throw ResumableUploadException('Blob config missing');
    _status = UploadStatus.started;

    _onProgress = onProgress;

    _onComplete = onComplete;

    final commitUri = blobConfig!.getCommitUri();

    await _upload(blobConfig!.getRequestUri);

    final blockListXml =
        '<BlockList>${blockIds.map((id) => '<Latest>$id</Latest>').join()}</BlockList>';

    http.Response response = await _commitUpload(commitUri, blockListXml);

    cache.delete(fingerPrint);

    _onComplete?.call(response);
  }

  _upload(Function(String) getUrl) async {
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

      final response = await http.put(url, body: chunkData);
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
  }

  cancel() => _status = UploadStatus.cancelled;

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
