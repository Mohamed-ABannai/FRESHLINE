import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'network_request.dart';

const int freshlineImageUploadLimitBytes = 5 * 1024 * 1024;
const int freshlineDocumentUploadLimitBytes = 10 * 1024 * 1024;
const int _freshlineMaxImageDimension = 1600;
const int _freshlineMinImageDimension = 720;
const String freshlineImageOversizeErrorMessage =
    'Selected image is too large. Freshline supports images up to 5 MB.';
const String freshlineImageInvalidTypeMessage =
    'Freshline could not read the selected image. Try a different photo or export it again from your gallery.';
const String freshlineImagePickerErrorMessage =
    'Freshline could not open your gallery. Check photo access and try again.';

class PreparedUploadFile {
  const PreparedUploadFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

Future<PreparedUploadFile?> pickFreshlineImageUpload({
  required String dialogTitle,
}) async {
  if (_prefersNativeGalleryPicker) {
    try {
      final XFile? pickedImage = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (pickedImage != null) {
        return prepareFreshlineImageUploadFromXFile(pickedImage);
      }
      return null;
    } catch (_) {
      throw StateError(freshlineImagePickerErrorMessage);
    }
  }

  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: true,
    type: FileType.image,
    dialogTitle: dialogTitle,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  return prepareFreshlineImageUpload(result.files.single);
}

Future<PreparedUploadFile> prepareFreshlineImageUpload(
  PlatformFile file, {
  int maxBytes = freshlineImageUploadLimitBytes,
}) async {
  final Uint8List originalBytes = await readPickedFileBytes(file);
  return _prepareFreshlineImageUploadBytes(
    originalBytes,
    fileName: file.name,
    maxBytes: maxBytes,
  );
}

Future<PreparedUploadFile> prepareFreshlineImageUploadFromXFile(
  XFile file, {
  int maxBytes = freshlineImageUploadLimitBytes,
}) async {
  final Uint8List originalBytes = await file.readAsBytes();
  return _prepareFreshlineImageUploadBytes(
    originalBytes,
    fileName: file.name,
    maxBytes: maxBytes,
  );
}

Future<PreparedUploadFile> prepareFreshlinePdfUpload(
  PlatformFile file, {
  int maxBytes = freshlineDocumentUploadLimitBytes,
  required String fieldLabel,
}) async {
  final String originalName = _sanitizedFileName(
    file.name,
    fallback: 'freshline-document.pdf',
  );
  if (!_hasPdfExtension(originalName)) {
    throw StateError('$fieldLabel must be a PDF file.');
  }
  if (file.size > maxBytes) {
    throw StateError('$fieldLabel must be 10 MB or less.');
  }

  final Uint8List bytes = await readPickedFileBytes(file);
  if (bytes.isEmpty) {
    throw StateError('Freshline could not read the selected file.');
  }
  if (bytes.length > maxBytes) {
    throw StateError('$fieldLabel must be 10 MB or less.');
  }

  return PreparedUploadFile(
    bytes: bytes,
    fileName: _replaceFileExtension(originalName, 'pdf'),
    contentType: 'application/pdf',
  );
}

Future<Uint8List> readPickedFileBytes(PlatformFile file) async {
  final Uint8List? memoryBytes = file.bytes;
  if (memoryBytes != null && memoryBytes.isNotEmpty) {
    return memoryBytes;
  }

  if (file.readStream case final Stream<List<int>> readStream) {
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final List<int> chunk in readStream) {
      if (chunk.isEmpty) {
        continue;
      }
      builder.add(chunk);
    }
    final Uint8List streamBytes = builder.takeBytes();
    if (streamBytes.isNotEmpty) {
      return streamBytes;
    }
  }

  try {
    final Uint8List fileBytes = await file.xFile.readAsBytes();
    if (fileBytes.isNotEmpty) {
      return fileBytes;
    }
  } catch (_) {
    // Fall through to the empty result below.
  }

  return Uint8List(0);
}

PreparedUploadFile _prepareFreshlineImageUploadBytes(
  Uint8List originalBytes, {
  required String fileName,
  required int maxBytes,
}) {
  if (originalBytes.isEmpty) {
    throw StateError('Freshline could not read the selected image.');
  }

  final String originalName = _sanitizedFileName(
    fileName,
    fallback: 'freshline-image.jpg',
  );
  final String? detectedContentType = detectFreshlineImageContentType(
    originalBytes,
    fileName: originalName,
  );
  final String? signatureContentType = _detectImageContentTypeFromBytes(
    originalBytes,
  );
  final int maxSide = _maxImageSideFromBytes(originalBytes);
  if (detectedContentType != null &&
      originalBytes.length <= maxBytes &&
      maxSide > 0 &&
      maxSide <= _freshlineMaxImageDimension) {
    return PreparedUploadFile(
      bytes: originalBytes,
      fileName: originalName,
      contentType: detectedContentType,
    );
  }

  final img.Image? decodedImage = img.decodeImage(originalBytes);
  if (decodedImage == null) {
    if (signatureContentType == null) {
      throw StateError(freshlineImageInvalidTypeMessage);
    }
    if (originalBytes.length > maxBytes) {
      throw StateError(freshlineImageOversizeErrorMessage);
    }
    return PreparedUploadFile(
      bytes: originalBytes,
      fileName: originalName,
      contentType: signatureContentType,
    );
  }

  int targetDimension = math.min(
    math.max(decodedImage.width, decodedImage.height),
    _freshlineMaxImageDimension,
  );
  int quality = 88;

  Uint8List encoded = _encodeOptimizedJpeg(
    decodedImage,
    targetDimension: targetDimension,
    quality: quality,
  );

  while (encoded.length > maxBytes &&
      (quality > 52 || targetDimension > _freshlineMinImageDimension)) {
    if (quality > 52) {
      quality -= 8;
    } else {
      targetDimension = math.max(
        _freshlineMinImageDimension,
        (targetDimension * 0.85).round(),
      );
      quality = 82;
    }
    encoded = _encodeOptimizedJpeg(
      decodedImage,
      targetDimension: targetDimension,
      quality: quality,
    );
  }

  if (encoded.length > maxBytes) {
    throw StateError(freshlineImageOversizeErrorMessage);
  }

  return PreparedUploadFile(
    bytes: encoded,
    fileName: _replaceFileExtension(originalName, 'jpg'),
    contentType: 'image/jpeg',
  );
}

String freshlineStorageUploadErrorMessage(
  http.Response response, {
  required String fallback,
  required String oversizeMessage,
  String? invalidTypeMessage,
}) {
  final String? transientMessage = freshlineTransientHttpErrorMessage(
    response.statusCode,
  );
  if (transientMessage != null) {
    return transientMessage;
  }

  final String body = response.body.trim();
  String? parsedMessage;
  if (body.isNotEmpty) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        parsedMessage = _readString(
          decoded['message'] ??
              decoded['error'] ??
              decoded['msg'] ??
              decoded['details'],
        ).trim();
      }
    } catch (_) {
      parsedMessage = body;
    }
  }

  final String loweredMessage = (parsedMessage ?? '').toLowerCase();
  if (response.statusCode == 413 ||
      loweredMessage.contains('payload too large') ||
      loweredMessage.contains('maximum allowed size')) {
    return oversizeMessage;
  }
  if (invalidTypeMessage != null &&
      (loweredMessage.contains('mime') ||
          loweredMessage.contains('content-type') ||
          loweredMessage.contains('file type') ||
          loweredMessage.contains('invalid'))) {
    return invalidTypeMessage;
  }

  return parsedMessage?.isNotEmpty == true ? parsedMessage! : fallback;
}

String? detectFreshlineImageContentType(
  Uint8List bytes, {
  required String fileName,
}) {
  return _detectImageContentTypeFromBytes(bytes) ??
      _imageContentTypeForFileName(fileName);
}

Uint8List _encodeOptimizedJpeg(
  img.Image source, {
  required int targetDimension,
  required int quality,
}) {
  img.Image output = source;
  final int sourceMaxSide = math.max(source.width, source.height);
  if (sourceMaxSide > targetDimension) {
    if (source.width >= source.height) {
      output = img.copyResize(
        source,
        width: targetDimension,
        interpolation: img.Interpolation.average,
      );
    } else {
      output = img.copyResize(
        source,
        height: targetDimension,
        interpolation: img.Interpolation.average,
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(output, quality: quality));
}

int _maxImageSideFromBytes(Uint8List bytes) {
  final img.Image? image = img.decodeImage(bytes);
  if (image == null) {
    return 0;
  }
  return math.max(image.width, image.height);
}

bool _hasPdfExtension(String fileName) {
  return fileName.toLowerCase().endsWith('.pdf');
}

String? _imageContentTypeForFileName(String fileName) {
  final String lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.jfif')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lower.endsWith('.bmp')) {
    return 'image/bmp';
  }
  if (lower.endsWith('.tif') || lower.endsWith('.tiff')) {
    return 'image/tiff';
  }
  if (lower.endsWith('.heic')) {
    return 'image/heic';
  }
  if (lower.endsWith('.heif')) {
    return 'image/heif';
  }
  if (lower.endsWith('.avif')) {
    return 'image/avif';
  }
  return null;
}

String? _detectImageContentTypeFromBytes(Uint8List bytes) {
  if (_startsWithBytes(bytes, const <int>[0xFF, 0xD8, 0xFF])) {
    return 'image/jpeg';
  }
  if (_startsWithBytes(bytes, const <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return 'image/png';
  }
  if (_startsWithAscii(bytes, 'GIF87a') || _startsWithAscii(bytes, 'GIF89a')) {
    return 'image/gif';
  }
  if (_startsWithAscii(bytes, 'BM')) {
    return 'image/bmp';
  }
  if (_startsWithBytes(bytes, const <int>[0x49, 0x49, 0x2A, 0x00]) ||
      _startsWithBytes(bytes, const <int>[0x4D, 0x4D, 0x00, 0x2A])) {
    return 'image/tiff';
  }
  if (bytes.length >= 12 &&
      _startsWithAscii(bytes, 'RIFF') &&
      _startsWithAscii(bytes, 'WEBP', offset: 8)) {
    return 'image/webp';
  }
  return _detectIsoBmffImageContentType(bytes);
}

String? _detectIsoBmffImageContentType(Uint8List bytes) {
  if (bytes.length < 16 || !_startsWithAscii(bytes, 'ftyp', offset: 4)) {
    return null;
  }

  final int headerEnd = math.min(bytes.length, 40);
  final String brands = ascii
      .decode(bytes.sublist(8, headerEnd), allowInvalid: true)
      .toLowerCase();
  if (brands.contains('avif') || brands.contains('avis')) {
    return 'image/avif';
  }
  if (brands.contains('heic') ||
      brands.contains('heix') ||
      brands.contains('heim') ||
      brands.contains('heis')) {
    return 'image/heic';
  }
  if (brands.contains('heif') ||
      brands.contains('hevc') ||
      brands.contains('hevx') ||
      brands.contains('mif1') ||
      brands.contains('msf1')) {
    return 'image/heif';
  }
  return null;
}

bool _startsWithBytes(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) {
    return false;
  }
  for (int index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) {
      return false;
    }
  }
  return true;
}

bool _startsWithAscii(Uint8List bytes, String text, {int offset = 0}) {
  if (bytes.length < offset + text.length) {
    return false;
  }
  final List<int> encoded = ascii.encode(text);
  for (int index = 0; index < encoded.length; index++) {
    if (bytes[offset + index] != encoded[index]) {
      return false;
    }
  }
  return true;
}

String _sanitizedFileName(String value, {required String fallback}) {
  final String sanitized = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), '-');
  return sanitized.isEmpty ? fallback : sanitized;
}

String _replaceFileExtension(String fileName, String extension) {
  final int dotIndex = fileName.lastIndexOf('.');
  final String baseName = dotIndex <= 0
      ? fileName
      : fileName.substring(0, dotIndex);
  return '$baseName.${extension.toLowerCase()}';
}

String _readString(Object? value, {String fallback = ''}) {
  final String text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

bool get _prefersNativeGalleryPicker {
  if (kIsWeb) {
    return false;
  }
  WidgetsBinding? binding;
  try {
    binding = WidgetsBinding.instance;
  } catch (_) {
    binding = null;
  }
  if (binding == null) {
    return false;
  }
  if (binding.runtimeType.toString().contains('Test')) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
