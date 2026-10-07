import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/app_data.dart';
import '../utils/bahrain_locations.dart';
import '../utils/bahrain_phone.dart';
import '../utils/network_request.dart';
import '../utils/password_hash.dart';
import '../utils/upload_preparation.dart';

abstract class SalonOwnerRepository {
  Future<SalonOwnerSession> registerOwner({
    required String ownerName,
    required String email,
    required String password,
  });

  Future<SalonOwnerSession> signInOwner({
    required String email,
    required String password,
  });

  Future<UploadedSalonAsset?> pickAndUploadAsset({
    required AppUser owner,
    required SalonUploadType type,
  });

  Future<SalonRegistrationRequest?> loadLatestRequest({required AppUser owner});

  Future<SalonRegistrationRequest> saveRequest({
    required AppUser owner,
    required SalonRegistrationRequest request,
  });
}

class MemorySalonOwnerRepository implements SalonOwnerRepository {
  final Map<String, _MemoryOwnerRecord> _ownersByEmail =
      <String, _MemoryOwnerRecord>{};
  final Map<String, SalonRegistrationRequest> _requestsByOwnerId =
      <String, SalonRegistrationRequest>{};

  @override
  Future<SalonOwnerSession> registerOwner({
    required String ownerName,
    required String email,
    required String password,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final String hashedPassword = hashProfilePassword(password);
    final _MemoryOwnerRecord? existing = _ownersByEmail[normalizedEmail];
    if (existing != null &&
        !verifyProfilePassword(
          storedPasswordHash: existing.password,
          password: password,
        )) {
      throw StateError(
        'This salon owner account already exists. Sign in instead.',
      );
    }

    final String ownerId =
        existing?.user.profileId ?? 'owner-${normalizedEmail.hashCode.abs()}';
    final AppUser user = AppUser(
      profileId: ownerId,
      name: ownerName.trim(),
      email: normalizedEmail,
      phone: '',
      city: 'Manama',
      role: AppRole.salonOwner,
    );
    _ownersByEmail[normalizedEmail] = _MemoryOwnerRecord(
      user: user,
      password: hashedPassword,
    );
    return SalonOwnerSession(user: user, request: _requestsByOwnerId[ownerId]);
  }

  @override
  Future<SalonOwnerSession> signInOwner({
    required String email,
    required String password,
  }) async {
    final _MemoryOwnerRecord? existing =
        _ownersByEmail[email.trim().toLowerCase()];
    if (existing == null ||
        !verifyProfilePassword(
          storedPasswordHash: existing.password,
          password: password,
        )) {
      throw StateError('Salon owner email or password is incorrect.');
    }

    return SalonOwnerSession(
      user: existing.user,
      request: _requestsByOwnerId[existing.user.profileId ?? ''],
    );
  }

  @override
  Future<UploadedSalonAsset?> pickAndUploadAsset({
    required AppUser owner,
    required SalonUploadType type,
  }) async {
    final String suffix = switch (type) {
      SalonUploadType.salonImage => 'salon-image.jpg',
      SalonUploadType.commercialRegistration => 'commercial-registration.pdf',
      SalonUploadType.governmentLicense => 'government-license.pdf',
    };
    final String folder = _safeKey(owner.email);
    return UploadedSalonAsset(
      fileName: suffix,
      storagePath: 'memory/$folder/$suffix',
      publicUrl: 'memory://$folder/$suffix',
      contentType: _contentTypeForFileName(suffix),
    );
  }

  @override
  Future<SalonRegistrationRequest?> loadLatestRequest({
    required AppUser owner,
  }) async {
    final String? ownerId = owner.profileId;
    if (ownerId == null) {
      return null;
    }
    return _requestsByOwnerId[ownerId];
  }

  @override
  Future<SalonRegistrationRequest> saveRequest({
    required AppUser owner,
    required SalonRegistrationRequest request,
  }) async {
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(
      request.salonPhone,
      fieldLabel: 'Salon phone number',
    );
    final String normalizedCity = normalizeBahrainLocation(request.city);
    final String ownerId =
        owner.profileId ??
        (request.ownerId.trim().isNotEmpty
            ? request.ownerId
            : 'owner-${owner.email.hashCode.abs()}');
    final DateTime now = DateTime.now();
    final SalonRegistrationRequest saved = request.copyWith(
      id: request.id ?? 'request-${now.microsecondsSinceEpoch}',
      ownerId: ownerId,
      city: normalizedCity,
      salonPhone: normalizedPhone,
      status: SalonRequestStatus.pending,
      updatedAt: now,
      createdAt: request.createdAt ?? now,
      clearAdminNote: true,
    );
    _requestsByOwnerId[ownerId] = saved;
    return saved;
  }
}

class SupabaseSalonOwnerRepository implements SalonOwnerRepository {
  SupabaseSalonOwnerRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<SalonOwnerSession> registerOwner({
    required String ownerName,
    required String email,
    required String password,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final String hashedPassword = hashProfilePassword(password);
    final Map<String, dynamic>? existingProfile = await _fetchProfileByEmail(
      normalizedEmail,
    );
    if (existingProfile != null) {
      final String role = _readString(existingProfile['role']);
      if (role != 'salon_owner') {
        throw StateError(
          'This email is already used by another Freshline account.',
        );
      }

      if (!verifyProfilePassword(
        storedPasswordHash: _readString(existingProfile['password_hash']),
        password: password,
      )) {
        throw StateError(
          'This salon owner account already exists. Sign in instead.',
        );
      }

      return signInOwner(email: normalizedEmail, password: password);
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'role': 'salon_owner',
      'full_name': ownerName.trim(),
      'username': _safeKey(ownerName),
      'email': normalizedEmail,
      'password_hash': hashedPassword,
      'phone': '',
      'city': 'Manama',
      'avatar_url': null,
      'is_active': true,
      'is_super_admin': false,
    };

    final List<dynamic> rows = await _postRows(
      '/rest/v1/profiles?on_conflict=email',
      body: <Map<String, dynamic>>[payload],
      prefer: 'resolution=merge-duplicates,return=representation',
    );

    if (rows.isEmpty) {
      throw StateError('Freshline could not create the salon owner account.');
    }

    final AppUser user = _userFromProfile(rows.first as Map<String, dynamic>);
    return SalonOwnerSession(
      user: user,
      request: await loadLatestRequest(owner: user),
    );
  }

  @override
  Future<SalonOwnerSession> signInOwner({
    required String email,
    required String password,
  }) async {
    final Map<String, dynamic>? profile = await _fetchProfileByEmail(
      email.trim().toLowerCase(),
    );
    if (profile == null || _readString(profile['role']) != 'salon_owner') {
      throw StateError('Salon owner account was not found.');
    }

    if (!verifyProfilePassword(
      storedPasswordHash: _readString(profile['password_hash']),
      password: password,
    )) {
      throw StateError('Salon owner email or password is incorrect.');
    }

    if (profile['is_active'] == false) {
      throw StateError('This salon owner account is currently inactive.');
    }

    final AppUser user = _userFromProfile(profile);
    return SalonOwnerSession(
      user: user,
      request: await loadLatestRequest(owner: user),
    );
  }

  @override
  Future<UploadedSalonAsset?> pickAndUploadAsset({
    required AppUser owner,
    required SalonUploadType type,
  }) async {
    PreparedUploadFile? uploadFile;
    if (type == SalonUploadType.salonImage) {
      uploadFile = await pickFreshlineImageUpload(
        dialogTitle: 'Select ${type.label}',
      );
    } else {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
        dialogTitle: 'Select ${type.label}',
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      uploadFile = await prepareFreshlinePdfUpload(
        result.files.single,
        fieldLabel: type.label,
      );
    }
    if (uploadFile == null) {
      return null;
    }
    final PreparedUploadFile resolvedUploadFile = uploadFile;

    final String safeName = _safeFileName(resolvedUploadFile.fileName);
    final String ownerKey = _safeKey(owner.profileId ?? owner.email);
    final String subFolder = switch (type) {
      SalonUploadType.salonImage => 'images',
      SalonUploadType.commercialRegistration => 'commercial',
      SalonUploadType.governmentLicense => 'licenses',
    };
    final String bucket = type == SalonUploadType.salonImage
        ? supabaseSalonMediaBucket
        : supabaseSalonDocumentsBucket;
    final String storagePath =
        'salon-requests/$ownerKey/$subFolder/${DateTime.now().millisecondsSinceEpoch}-$safeName';

    final Uri uri = Uri.parse(
      '$supabaseUrl/storage/v1/object/$bucket/${_encodePath(storagePath)}',
    );
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.post(
        uri,
        headers: <String, String>{
          ..._supabaseHeaders(),
          'Content-Type': resolvedUploadFile.contentType,
          'x-upsert': 'true',
        },
        body: resolvedUploadFile.bytes,
      ),
      fallback: 'Freshline could not upload ${type.label.toLowerCase()}.',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        freshlineStorageUploadErrorMessage(
          response,
          fallback: 'Freshline could not upload ${type.label.toLowerCase()}.',
          oversizeMessage: type == SalonUploadType.salonImage
              ? freshlineImageOversizeErrorMessage
              : '${type.label} must be 10 MB or less.',
          invalidTypeMessage: type == SalonUploadType.salonImage
              ? freshlineImageInvalidTypeMessage
              : '${type.label} must be a PDF file.',
        ),
      );
    }

    return UploadedSalonAsset(
      fileName: uploadFile.fileName,
      storagePath: storagePath,
      publicUrl:
          '$supabaseUrl/storage/v1/object/public/$bucket/${_encodePath(storagePath)}',
      contentType: resolvedUploadFile.contentType,
    );
  }

  @override
  Future<SalonRegistrationRequest?> loadLatestRequest({
    required AppUser owner,
  }) async {
    final String? ownerId = owner.profileId;
    if (ownerId == null || ownerId.trim().isEmpty) {
      return null;
    }

    final Uri uri = Uri.parse(
      '$supabaseUrl/rest/v1/salon_applications?select=*&owner_id=eq.$ownerId&order=updated_at.desc.nullslast&limit=1',
    );
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.get(uri, headers: _supabaseHeaders()),
      fallback: 'Freshline could not load the salon request status.',
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Freshline could not load the salon request status.');
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic> || decoded.isEmpty) {
      return null;
    }

    return _requestFromJson(decoded.first as Map<String, dynamic>);
  }

  @override
  Future<SalonRegistrationRequest> saveRequest({
    required AppUser owner,
    required SalonRegistrationRequest request,
  }) async {
    final String? ownerId = owner.profileId;
    if (ownerId == null || ownerId.trim().isEmpty) {
      throw StateError('Freshline is missing the salon owner profile id.');
    }

    if (request.commercialRegistration == null ||
        request.governmentLicense == null) {
      throw StateError('Please upload the required registration PDFs.');
    }
    final String normalizedPhone = normalizeBahrainPhoneOrThrow(
      request.salonPhone,
      fieldLabel: 'Salon phone number',
    );
    final String normalizedCity = normalizeBahrainLocation(request.city);

    final Map<String, dynamic> payload = <String, dynamic>{
      'owner_id': ownerId,
      'salon_name': request.salonName.trim(),
      'business_email': request.salonEmail.trim().toLowerCase(),
      'phone': normalizedPhone,
      'city': normalizedCity,
      'address': request.address.trim(),
      'website_url': request.websiteUrl?.trim(),
      'location_url': request.locationUrl.trim(),
      'salon_image_url': request.salonImage?.publicUrl,
      'commercial_registration_pdf_url':
          request.commercialRegistration?.publicUrl ?? '',
      'government_license_pdf_url': request.governmentLicense?.publicUrl ?? '',
      'status': SalonRequestStatus.pending.value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final List<dynamic> rows = request.id == null
        ? await _postRows(
            '/rest/v1/salon_applications',
            body: <Map<String, dynamic>>[payload],
            prefer: 'return=representation',
          )
        : await _patchRows(
            '/rest/v1/salon_applications?id=eq.${request.id}',
            body: payload,
            prefer: 'return=representation',
          );

    if (rows.isEmpty) {
      throw StateError('Freshline could not save the salon request.');
    }

    final SalonRegistrationRequest saved = _requestFromJson(
      rows.first as Map<String, dynamic>,
    );
    await _notifyAdminsForRequest(saved);
    return saved;
  }

  Future<Map<String, dynamic>?> _fetchProfileByEmail(String email) async {
    final Uri uri = Uri.parse(
      '$supabaseUrl/rest/v1/profiles?select=*&email=eq.${Uri.encodeQueryComponent(email)}&limit=1',
    );
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.get(uri, headers: _supabaseHeaders()),
      fallback: 'Freshline could not check the salon owner account.',
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Freshline could not check the salon owner account.');
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic> || decoded.isEmpty) {
      return null;
    }

    return decoded.first as Map<String, dynamic>;
  }

  Future<List<dynamic>> _postRows(
    String path, {
    required Object body,
    required String prefer,
  }) async {
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.post(
        Uri.parse('$supabaseUrl$path'),
        headers: <String, String>{
          ..._supabaseHeaders(),
          'Content-Type': 'application/json',
          'Prefer': prefer,
        },
        body: jsonEncode(body),
      ),
      fallback: 'Freshline could not save salon owner data.',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _supabaseWriteErrorMessage(
          response,
          fallback: 'Freshline could not save salon owner data.',
        ),
      );
    }

    return _decodeRowList(response.body);
  }

  Future<List<dynamic>> _patchRows(
    String path, {
    required Map<String, dynamic> body,
    required String prefer,
  }) async {
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.patch(
        Uri.parse('$supabaseUrl$path'),
        headers: <String, String>{
          ..._supabaseHeaders(),
          'Content-Type': 'application/json',
          'Prefer': prefer,
        },
        body: jsonEncode(body),
      ),
      fallback: 'Freshline could not update the salon request.',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _supabaseWriteErrorMessage(
          response,
          fallback: 'Freshline could not update the salon request.',
        ),
      );
    }

    return _decodeRowList(response.body);
  }

  AppUser _userFromProfile(Map<String, dynamic> row) {
    return AppUser(
      profileId: _readString(row['id']),
      name: _readString(
        row['full_name'] ?? row['username'],
        fallback: 'Salon Owner',
      ),
      email: _readString(row['email']),
      phone: _readString(row['phone']),
      city: _readString(row['city'], fallback: 'Manama'),
      role: AppRole.salonOwner,
      avatarPath: normalizeProfileImageUrl(row['avatar_url']),
      preferredLanguage: 'EN',
    );
  }

  SalonRegistrationRequest _requestFromJson(Map<String, dynamic> row) {
    return SalonRegistrationRequest(
      id: _readString(row['id']),
      ownerId: _readString(row['owner_id']),
      salonName: _readString(row['salon_name'], fallback: 'Freshline Salon'),
      salonEmail: _readString(row['business_email']),
      salonPhone: _readString(row['phone']),
      city: _readString(row['city'], fallback: 'Manama'),
      address: _readString(row['address']),
      locationUrl: _readString(row['location_url']),
      websiteUrl: _readString(row['website_url']),
      salonImage: _nullableAsset(
        row['salon_image_url'],
        fallbackName: 'salon-image.jpg',
      ),
      commercialRegistration: _nullableAsset(
        row['commercial_registration_pdf_url'],
        fallbackName: 'commercial-registration.pdf',
        contentType: 'application/pdf',
      ),
      governmentLicense: _nullableAsset(
        row['government_license_pdf_url'],
        fallbackName: 'government-license.pdf',
        contentType: 'application/pdf',
      ),
      status: salonRequestStatusFromValue(
        _readString(row['status'], fallback: 'pending'),
      ),
      adminNote: _readString(row['admin_note']),
      createdAt: _readDateTime(row['created_at']),
      updatedAt: _readDateTime(row['updated_at']),
    );
  }

  Future<void> _notifyAdminsForRequest(SalonRegistrationRequest request) async {
    try {
      final http.Response response = await performFreshlineHttpRequest(
        () => _client.post(
          Uri.parse('$supabaseUrl/rest/v1/notifications'),
          headers: <String, String>{
            ..._supabaseHeaders(),
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'title': 'New Salon Request',
              'body':
                  '${request.salonName} submitted a salon request and is waiting for review.',
              'audience': 'admins',
              'sent_at': DateTime.now().toUtc().toIso8601String(),
            },
          ]),
        ),
        fallback: 'Freshline could not create the notification.',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
    } catch (_) {
      // Ignore notification failures because the request itself is already saved.
    }
  }

  UploadedSalonAsset? _nullableAsset(
    Object? value, {
    required String fallbackName,
    String contentType = 'application/octet-stream',
  }) {
    final String url = _readString(value);
    if (url.isEmpty) {
      return null;
    }

    return UploadedSalonAsset.fromPublicUrl(
      url,
      fallbackName: fallbackName,
      contentType: contentType,
    );
  }

  List<dynamic> _decodeRowList(String responseBody) {
    if (responseBody.trim().isEmpty) {
      return const <dynamic>[];
    }

    final Object? decoded = jsonDecode(responseBody);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      return <dynamic>[decoded];
    }
    return const <dynamic>[];
  }

  Map<String, String> _supabaseHeaders() {
    return <String, String>{
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $supabaseAnonKey',
    };
  }

  void dispose() {
    _client.close();
  }
}

class _MemoryOwnerRecord {
  const _MemoryOwnerRecord({required this.user, required this.password});

  final AppUser user;
  final String password;
}

String _safeKey(String value) {
  final String collapsed = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return collapsed.isEmpty ? 'freshline' : collapsed;
}

String _safeFileName(String value) {
  final String sanitized = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), '-');
  return sanitized.isEmpty ? 'freshline-file' : sanitized;
}

String _encodePath(String path) {
  return path
      .split('/')
      .where((String segment) => segment.trim().isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
}

String _contentTypeForFileName(String fileName) {
  final String lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lower.endsWith('.pdf')) {
    return 'application/pdf';
  }
  return 'image/jpeg';
}

String _readString(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final String stringValue = value.toString().trim();
  return stringValue.isEmpty ? fallback : stringValue;
}

DateTime? _readDateTime(Object? value) {
  final String raw = _readString(value);
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

String _supabaseWriteErrorMessage(
  http.Response response, {
  required String fallback,
}) {
  final String? transientMessage = freshlineTransientHttpErrorMessage(
    response.statusCode,
  );
  if (transientMessage != null) {
    return transientMessage;
  }

  if (response.statusCode == 401 || response.statusCode == 403) {
    return 'Supabase blocked this write request. Re-run supabase/freshline_schema.sql, then try again.';
  }

  final String body = response.body.trim();
  if (body.isEmpty) {
    return fallback;
  }

  try {
    final Object? decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final String message = _readString(
        decoded['message'] ?? decoded['hint'] ?? decoded['details'],
      );
      if (message.isNotEmpty) {
        return message;
      }
    }
  } catch (_) {
    // Ignore parse errors and fall back to the default message.
  }

  return fallback;
}
