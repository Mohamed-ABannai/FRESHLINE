import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'package:freshline_tt/src/data/app_data.dart';
import 'package:freshline_tt/src/services/platform_repository.dart';
import 'package:freshline_tt/src/services/salon_owner_service.dart';

void main() {
  final Uint8List pngBytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 8, height: 8)),
  );
  final Uint8List pdfBytes = Uint8List.fromList(
    utf8.encode('%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'),
  );
  final Uint8List heicBytes = Uint8List.fromList(<int>[
    0x00,
    0x00,
    0x00,
    0x18,
    0x66,
    0x74,
    0x79,
    0x70,
    0x68,
    0x65,
    0x69,
    0x63,
    0x00,
    0x00,
    0x00,
    0x00,
    0x68,
    0x65,
    0x69,
    0x63,
    0x6D,
    0x69,
    0x66,
    0x31,
  ]);

  test(
    'supabase profile image upload requests picker bytes and posts to storage',
    () async {
      final _RecordingFilePicker picker = _RecordingFilePicker(
        result: FilePickerResult(<PlatformFile>[
          PlatformFile(
            name: 'avatar.png',
            size: pngBytes.length,
            bytes: pngBytes,
          ),
        ]),
      );
      FilePicker.platform = picker;

      late http.Request uploadRequest;
      final SupabasePlatformRepository repository = SupabasePlatformRepository(
        client: MockClient((http.Request request) async {
          uploadRequest = request;
          return http.Response('{}', 200);
        }),
      );

      final String? publicUrl = await repository.pickAndUploadProfileImage(
        profileKey: 'User Profile',
      );

      expect(picker.lastWithData, isTrue);
      expect(picker.lastWithReadStream, isFalse);
      expect(picker.lastType, FileType.image);
      expect(picker.lastAllowedExtensions, isNull);
      expect(uploadRequest.method, 'POST');
      expect(uploadRequest.headers['Content-Type'], 'image/png');
      expect(
        uploadRequest.url.path,
        contains('/storage/v1/object/salon-media/profiles/user-profile/'),
      );
      expect(uploadRequest.bodyBytes, pngBytes);
      expect(
        publicUrl,
        contains(
          '/storage/v1/object/public/salon-media/profiles/user-profile/',
        ),
      );
    },
  );

  test(
    'supabase product image upload requests picker bytes and posts to storage',
    () async {
      final _RecordingFilePicker picker = _RecordingFilePicker(
        result: FilePickerResult(<PlatformFile>[
          PlatformFile(
            name: 'product.png',
            size: pngBytes.length,
            bytes: pngBytes,
          ),
        ]),
      );
      FilePicker.platform = picker;

      late http.Request uploadRequest;
      final SupabasePlatformRepository repository = SupabasePlatformRepository(
        client: MockClient((http.Request request) async {
          uploadRequest = request;
          return http.Response('{}', 200);
        }),
      );

      final String? publicUrl = await repository.pickAndUploadSalonProductImage(
        productKey: 'Argan Oil',
      );

      expect(picker.lastWithData, isTrue);
      expect(picker.lastWithReadStream, isFalse);
      expect(picker.lastType, FileType.image);
      expect(picker.lastAllowedExtensions, isNull);
      expect(uploadRequest.method, 'POST');
      expect(uploadRequest.headers['Content-Type'], 'image/png');
      expect(
        uploadRequest.url.path,
        contains('/storage/v1/object/salon-media/products/argan-oil/'),
      );
      expect(uploadRequest.bodyBytes, pngBytes);
      expect(
        publicUrl,
        contains('/storage/v1/object/public/salon-media/products/argan-oil/'),
      );
    },
  );

  test(
    'supabase profile image upload accepts heic files with the matching content type',
    () async {
      final _RecordingFilePicker picker = _RecordingFilePicker(
        result: FilePickerResult(<PlatformFile>[
          PlatformFile(
            name: 'avatar.heic',
            size: heicBytes.length,
            bytes: heicBytes,
          ),
        ]),
      );
      FilePicker.platform = picker;

      late http.Request uploadRequest;
      final SupabasePlatformRepository repository = SupabasePlatformRepository(
        client: MockClient((http.Request request) async {
          uploadRequest = request;
          return http.Response('{}', 200);
        }),
      );

      final String? publicUrl = await repository.pickAndUploadProfileImage(
        profileKey: 'HEIC User',
      );

      expect(picker.lastType, FileType.image);
      expect(picker.lastAllowedExtensions, isNull);
      expect(uploadRequest.headers['Content-Type'], 'image/heic');
      expect(uploadRequest.bodyBytes, heicBytes);
      expect(
        publicUrl,
        contains('/storage/v1/object/public/salon-media/profiles/heic-user/'),
      );
    },
  );

  test(
    'salon image upload requests picker bytes and posts to media storage',
    () async {
      final _RecordingFilePicker picker = _RecordingFilePicker(
        result: FilePickerResult(<PlatformFile>[
          PlatformFile(
            name: 'salon.png',
            size: pngBytes.length,
            bytes: pngBytes,
          ),
        ]),
      );
      FilePicker.platform = picker;

      late http.Request uploadRequest;
      final SupabaseSalonOwnerRepository repository =
          SupabaseSalonOwnerRepository(
            client: MockClient((http.Request request) async {
              uploadRequest = request;
              return http.Response('{}', 200);
            }),
          );

      final UploadedSalonAsset? asset = await repository.pickAndUploadAsset(
        owner: _ownerUser(),
        type: SalonUploadType.salonImage,
      );

      expect(picker.lastWithData, isTrue);
      expect(picker.lastWithReadStream, isFalse);
      expect(picker.lastType, FileType.image);
      expect(picker.lastAllowedExtensions, isNull);
      expect(uploadRequest.headers['Content-Type'], 'image/png');
      expect(
        uploadRequest.url.path,
        contains(
          '/storage/v1/object/salon-media/salon-requests/owner-1/images/',
        ),
      );
      expect(
        asset?.publicUrl,
        contains(
          '/storage/v1/object/public/salon-media/salon-requests/owner-1/images/',
        ),
      );
    },
  );

  test(
    'salon document upload requests picker bytes and posts pdf to document storage',
    () async {
      final _RecordingFilePicker picker = _RecordingFilePicker(
        result: FilePickerResult(<PlatformFile>[
          PlatformFile(
            name: 'commercial-registration.pdf',
            size: pdfBytes.length,
            bytes: pdfBytes,
          ),
        ]),
      );
      FilePicker.platform = picker;

      late http.Request uploadRequest;
      final SupabaseSalonOwnerRepository repository =
          SupabaseSalonOwnerRepository(
            client: MockClient((http.Request request) async {
              uploadRequest = request;
              return http.Response('{}', 200);
            }),
          );

      final UploadedSalonAsset? asset = await repository.pickAndUploadAsset(
        owner: _ownerUser(),
        type: SalonUploadType.commercialRegistration,
      );

      expect(picker.lastWithData, isTrue);
      expect(picker.lastWithReadStream, isFalse);
      expect(picker.lastType, FileType.custom);
      expect(picker.lastAllowedExtensions, const <String>['pdf']);
      expect(uploadRequest.headers['Content-Type'], 'application/pdf');
      expect(
        uploadRequest.url.path,
        contains(
          '/storage/v1/object/salon-documents/salon-requests/owner-1/commercial/',
        ),
      );
      expect(uploadRequest.bodyBytes, pdfBytes);
      expect(
        asset?.publicUrl,
        contains(
          '/storage/v1/object/public/salon-documents/salon-requests/owner-1/commercial/',
        ),
      );
    },
  );
}

AppUser _ownerUser() {
  return const AppUser(
    profileId: 'owner-1',
    name: 'Owner User',
    email: 'owner@freshline.app',
    phone: '+97330000000',
    city: 'Manama',
    role: AppRole.salonOwner,
  );
}

class _RecordingFilePicker extends FilePicker {
  _RecordingFilePicker({required this.result});

  final FilePickerResult? result;
  bool? lastWithData;
  bool? lastWithReadStream;
  FileType? lastType;
  List<String>? lastAllowedExtensions;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    lastWithData = withData;
    lastWithReadStream = withReadStream;
    lastType = type;
    lastAllowedExtensions = allowedExtensions;
    return result;
  }
}
