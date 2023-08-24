import 'dart:convert';

class UploadMetaData {
  late String key;

  late int offset;

  late int totalSize;

  late List<String> blockIds;

  late int index;

  late bool isUploading;

  late bool isChucksCompleted;

  UploadMetaData(this.key, this.offset)
      : totalSize = 0,
        index = 1,
        blockIds = [],
        isUploading = false,
        isChucksCompleted = false;

  @override
  String toString() {
    Map<String, dynamic> data = {
      'key': key,
      'offset': offset,
      'totalSize': totalSize,
      'blockIds': blockIds,
      'index': index,
      'isUploading': isUploading,
      'isChucksCompleted': isChucksCompleted
    };
    return jsonEncode(data);
  }

  UploadMetaData.fromJson(Map<String, dynamic> data) {
    key = data['key'];
    offset = data['offset'];
    totalSize = data['totalSize'];
    blockIds = List.from(data['blockIds']).cast<String>();
    index = data['index'];
    isUploading = data['isUploading'];
    isChucksCompleted = data['isChucksCompleted'];
  }
}
