class BlobConfig {
  final String sasToken;

  final String blobUrl;

  BlobConfig({required this.blobUrl, required this.sasToken});

  Uri getRequestUri(String blockId) {
    final String url = '$blobUrl'
        '?comp=block&blockid=$blockId&$sasToken';
    return Uri.parse(url);
  }

  Uri getCommitUri() {
    final String url = '$blobUrl'
        '?comp=blocklist&$sasToken';
    return Uri.parse(url);
  }
}
