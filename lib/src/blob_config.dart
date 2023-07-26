class BlobConfig {
  final String accountName;

  final String containerName;

  final String blobName;

  final String sasToken;

  // final String blobUrl;

  // final String commitUrl;

  BlobConfig(
      {required this.accountName,
      required this.containerName,
      required this.blobName,
      required this.sasToken});

  Uri getRequestUri(String blockId) {
    final String url =
        'https://$accountName.blob.core.windows.net/$containerName/$blobName'
        '?comp=block&blockid=$blockId&$sasToken';
    return Uri.parse(url);
  }

  Uri getCommitUri() {
    final String url =
        'https://$accountName.blob.core.windows.net/$containerName/$blobName'
        '?comp=blocklist&$sasToken';
    return Uri.parse(url);
  }
}
