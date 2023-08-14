class BlobConfig {
  final String sasToken;

  final String blobUrl;

  BlobConfig({required this.blobUrl, required this.sasToken});

  getRequestUri(String blockId) {
    final String url = '$blobUrl'
        '?comp=block&blockid=$blockId&$sasToken';
    return url;
  }

  getCommitUri() {
    final String url = '$blobUrl'
        '?comp=blocklist&$sasToken';
    return url;
  }
}
