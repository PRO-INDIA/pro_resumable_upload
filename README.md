# Resumable file upload package developed by PRO India.

latest version is 0.0.2


# pro_resumable_upload
pro_resumable_upload is a Flutter package that provides support for resumable file uploads. It allows you to upload large files to a server and resume the upload from where it left off in case of interruptions or failures.

# Features
> Resumable file uploads.
> Support for large files.
> Easily handle upload interruptions.
> Configurable options for upload behavior.

# Installation
1.Add pro_resumable_upload to your pubspec.yaml file:
--------------------------------------------------
    dependencies:
        resumable_upload: ^1.0.0
2.Usage
-------------------------------------------------
    Import the package:
    import 'package:pro_resumable_upload/pro_resumable_upload.dart';

3.Create an instance of ResumableUpload:
-------------------------------------------------
    client = UploadClient(
    file: file,
    cache: _localCache,
    blobConfig: BlobConfig(blobUrl: blobUrl, sasToken: sasToken),
    );
    
4.Start the upload:
-----------------------------------------------
    client!.uploadBlob(
    onProgress: (count, total, response) {
        // Handle progress updates
    },
    onComplete: (path, response) {
        // Handle complete updates
    },
);


# Configuration Options
@You can configure the behavior of the ResumableUpload by setting the following optional parameters:

> chunkSize: Set the size of each chunk to be uploaded. Default is 1 MB.
> maxAttempts: Set the maximum number of attempts to resume an upload. Default is 3.
> headers: Add custom headers to the upload request. Default is an empty Map<String, String>.
> timeout: Set the timeout duration for each upload request. Default is 60 seconds.

# Sample code:
------------------------------------------------------------------------
client = UploadClient(
    file: file,
    cache: _localCache,
    blobConfig: BlobConfig(blobUrl: blobUrl, sasToken: sasToken),
    );
client!.uploadBlob(
    onProgress: (count, total, response) {
        // Handle progress updates
    },
    onComplete: (path, response) {
        // Handle complete updates
    },
);
---------------------------------------------------------------------

# Contributing
We welcome contributions to this package. Feel free to open issues and pull requests to suggest improvements or report bugs.

# License
This project is licensed under the MIT License.
