import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:freshline_tt/src/data/app_data.dart';
import 'package:freshline_tt/src/services/platform_repository.dart';
import 'package:freshline_tt/src/utils/password_hash.dart';

void main() {
  test(
    'supabase repo creates the customer profile without sending auth email on signup',
    () async {
      final List<String> requestOrder = <String>[];
      final List<Map<String, dynamic>> profileWrites = <Map<String, dynamic>>[];

      final MockClient client = MockClient((http.Request request) async {
        requestOrder.add(
          '${request.method} ${request.url.path}?${request.url.query}',
        );

        if (request.method == 'GET' &&
            request.url.path == '/rest/v1/profiles') {
          return http.Response('[]', 200);
        }

        if (request.method == 'POST' &&
            request.url.path == '/rest/v1/profiles') {
          final List<dynamic> payload =
              jsonDecode(request.body) as List<dynamic>;
          final Map<String, dynamic> row = Map<String, dynamic>.from(
            payload.first as Map,
          );
          profileWrites.add(row);
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              _profileRow(
                id: 'profile-1',
                email: 'new@freshline.app',
                passwordHash: _readString(row['password_hash']),
                emailVerifiedAt: null,
              ),
            ]),
            201,
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/rest/v1/notifications') {
          return http.Response('[]', 201);
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      });

      final SupabasePlatformRepository repository = SupabasePlatformRepository(
        client: client,
      );

      final AppUser user = await repository.registerCustomer(
        name: 'New User',
        email: 'new@freshline.app',
        phone: '+973 3000 0000',
        city: 'Manama',
        password: 'freshline123',
      );

      expect(user.email, 'new@freshline.app');
      expect(user.isEmailVerified, isFalse);
      expect(profileWrites, hasLength(2));
      expect(requestOrder, <String>[
        'GET /rest/v1/profiles?select=*&email=eq.new%40freshline.app&limit=1',
        'POST /rest/v1/profiles?on_conflict=email',
        'POST /rest/v1/profiles?on_conflict=email',
        'POST /rest/v1/notifications?',
      ]);
      expect(
        profileWrites.first['password_hash'],
        hashProfilePassword('freshline123'),
      );
      expect(profileWrites.first['auth_user_id'], isNull);
      expect(profileWrites.last['auth_user_id'], isNull);
    },
  );

  test(
    'supabase repo sends email verification only from account details',
    () async {
      final List<String> requestOrder = <String>[];
      Map<String, dynamic>? sentPayload;

      final MockClient client = MockClient((http.Request request) async {
        requestOrder.add(
          '${request.method} ${request.url.path}?${request.url.query}',
        );

        if (request.method == 'GET' &&
            request.url.path == '/rest/v1/profiles') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              _profileRow(
                id: 'profile-1',
                email: 'new@freshline.app',
                passwordHash: hashProfilePassword('freshline123'),
                emailVerifiedAt: null,
              ),
            ]),
            200,
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/functions/v1/send-auth-otp') {
          sentPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode(<String, dynamic>{'success': true}),
            200,
          );
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      });

      final SupabasePlatformRepository repository = SupabasePlatformRepository(
        client: client,
      );

      await repository.sendEmailVerificationCode(email: 'new@freshline.app');

      expect(requestOrder, <String>[
        'GET /rest/v1/profiles?select=*&email=eq.new%40freshline.app&limit=1',
        'POST /functions/v1/send-auth-otp?',
      ]);
      expect(sentPayload, <String, dynamic>{
        'email': 'new@freshline.app',
        'purpose': 'email_verification',
        'profileId': 'profile-1',
      });
    },
  );

  test(
    'supabase repo verifies email code with rpc and marks the profile verified',
    () async {
      final List<String> requestOrder = <String>[];
      Map<String, dynamic>? verifyPayload;
      Map<String, dynamic>? patchPayload;

      final MockClient client = MockClient((http.Request request) async {
        requestOrder.add(
          '${request.method} ${request.url.path}?${request.url.query}',
        );

        if (request.method == 'GET' &&
            request.url.path == '/rest/v1/profiles') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              _profileRow(
                id: 'profile-1',
                email: 'new@freshline.app',
                passwordHash: hashProfilePassword('freshline123'),
                emailVerifiedAt: null,
              ),
            ]),
            200,
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/rest/v1/rpc/verify_auth_email_otp') {
          verifyPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response('true', 200);
        }

        if (request.method == 'PATCH' &&
            request.url.path == '/rest/v1/profiles') {
          patchPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response('[]', 200);
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      });

      final SupabasePlatformRepository repository = SupabasePlatformRepository(
        client: client,
      );

      await repository.verifyEmailAddressCode(
        email: 'new@freshline.app',
        code: '246810',
      );

      expect(requestOrder, <String>[
        'GET /rest/v1/profiles?select=*&email=eq.new%40freshline.app&limit=1',
        'POST /rest/v1/rpc/verify_auth_email_otp?',
        'PATCH /rest/v1/profiles?email=eq.new%40freshline.app',
      ]);
      expect(verifyPayload, <String, dynamic>{
        'p_email': 'new@freshline.app',
        'p_purpose': 'email_verification',
        'p_code': '246810',
        'p_profile_id': 'profile-1',
      });
      expect(_readString(patchPayload?['email_verified_at']), isNotEmpty);
      expect(_readString(patchPayload?['updated_at']), isNotEmpty);
    },
  );

  test(
    'supabase repo retries verify otp without profile id for older rpc signatures',
    () async {
      final List<String> requestOrder = <String>[];
      final List<Map<String, dynamic>> verifyPayloads =
          <Map<String, dynamic>>[];
      Map<String, dynamic>? patchPayload;

      final MockClient client = MockClient((http.Request request) async {
        requestOrder.add(
          '${request.method} ${request.url.path}?${request.url.query}',
        );

        if (request.method == 'GET' &&
            request.url.path == '/rest/v1/profiles') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              _profileRow(
                id: 'profile-1',
                email: 'new@freshline.app',
                passwordHash: hashProfilePassword('freshline123'),
                emailVerifiedAt: null,
              ),
            ]),
            200,
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/rest/v1/rpc/verify_auth_email_otp') {
          final Map<String, dynamic> payload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          verifyPayloads.add(payload);
          if (verifyPayloads.length == 1) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'code': 'PGRST202',
                'message':
                    'Could not find the function public.verify_auth_email_otp(p_code, p_email, p_profile_id, p_purpose) in the schema cache',
              }),
              404,
            );
          }
          return http.Response('true', 200);
        }

        if (request.method == 'PATCH' &&
            request.url.path == '/rest/v1/profiles') {
          patchPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response('[]', 200);
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      });

      final SupabasePlatformRepository repository = SupabasePlatformRepository(
        client: client,
      );

      await repository.verifyEmailAddressCode(
        email: 'new@freshline.app',
        code: '246810',
      );

      expect(requestOrder, <String>[
        'GET /rest/v1/profiles?select=*&email=eq.new%40freshline.app&limit=1',
        'POST /rest/v1/rpc/verify_auth_email_otp?',
        'POST /rest/v1/rpc/verify_auth_email_otp?',
        'PATCH /rest/v1/profiles?email=eq.new%40freshline.app',
      ]);
      expect(verifyPayloads, <Map<String, dynamic>>[
        <String, dynamic>{
          'p_email': 'new@freshline.app',
          'p_purpose': 'email_verification',
          'p_code': '246810',
          'p_profile_id': 'profile-1',
        },
        <String, dynamic>{
          'p_email': 'new@freshline.app',
          'p_purpose': 'email_verification',
          'p_code': '246810',
        },
      ]);
      expect(_readString(patchPayload?['email_verified_at']), isNotEmpty);
      expect(_readString(patchPayload?['updated_at']), isNotEmpty);
    },
  );

  test(
    'supabase repo sends and completes password reset with Freshline otp',
    () async {
      final List<String> requestOrder = <String>[];
      Map<String, dynamic>? sendPayload;
      Map<String, dynamic>? verifyPayload;
      Map<String, dynamic>? patchPayload;

      final MockClient client = MockClient((http.Request request) async {
        requestOrder.add(
          '${request.method} ${request.url.path}?${request.url.query}',
        );

        if (request.method == 'GET' &&
            request.url.path == '/rest/v1/profiles') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              _profileRow(
                id: 'profile-1',
                email: 'new@freshline.app',
                passwordHash: hashProfilePassword('freshline123'),
                emailVerifiedAt: null,
              ),
            ]),
            200,
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/functions/v1/send-auth-otp') {
          sendPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode(<String, dynamic>{'success': true}),
            200,
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/rest/v1/rpc/verify_auth_email_otp') {
          verifyPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response('true', 200);
        }

        if (request.method == 'PATCH' &&
            request.url.path == '/rest/v1/profiles') {
          patchPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response('[]', 200);
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      });

      final SupabasePlatformRepository repository = SupabasePlatformRepository(
        client: client,
      );

      await repository.sendPasswordResetCode(email: 'new@freshline.app');
      final String verificationToken = await repository.verifyPasswordResetCode(
        email: 'new@freshline.app',
        code: '246810',
      );
      await repository.completePasswordReset(
        email: 'new@freshline.app',
        verificationToken: verificationToken,
        newPassword: 'newpass123',
      );

      expect(requestOrder, <String>[
        'GET /rest/v1/profiles?select=*&email=eq.new%40freshline.app&limit=1',
        'POST /functions/v1/send-auth-otp?',
        'GET /rest/v1/profiles?select=*&email=eq.new%40freshline.app&limit=1',
        'POST /rest/v1/rpc/verify_auth_email_otp?',
        'GET /rest/v1/profiles?select=*&email=eq.new%40freshline.app&limit=1',
        'PATCH /rest/v1/profiles?id=eq.profile-1',
      ]);
      expect(sendPayload, <String, dynamic>{
        'email': 'new@freshline.app',
        'purpose': 'password_reset',
        'profileId': 'profile-1',
      });
      expect(verifyPayload, <String, dynamic>{
        'p_email': 'new@freshline.app',
        'p_purpose': 'password_reset',
        'p_code': '246810',
        'p_profile_id': 'profile-1',
      });
      expect(patchPayload?['password_hash'], hashProfilePassword('newpass123'));
      expect(_readString(patchPayload?['updated_at']), isNotEmpty);
    },
  );

  test('supabase repo shows a clear timeout message for 504 responses', () async {
    final List<String> requestOrder = <String>[];

    final MockClient client = MockClient((http.Request request) async {
      requestOrder.add(
        '${request.method} ${request.url.path}?${request.url.query}',
      );

      if (request.method == 'GET' && request.url.path == '/rest/v1/profiles') {
        return http.Response('[]', 200);
      }

      if (request.method == 'POST' && request.url.path == '/rest/v1/profiles') {
        return http.Response('', 504);
      }

      return http.Response('Not found', 404);
    });

    final SupabasePlatformRepository repository = SupabasePlatformRepository(
      client: client,
    );

    await expectLater(
      repository.registerCustomer(
        name: 'New User',
        email: 'new@freshline.app',
        phone: '+973 3000 0000',
        city: 'Manama',
        password: 'freshline123',
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'Freshline timed out while waiting for the server. Please try again.',
        ),
      ),
    );

    expect(requestOrder, <String>[
      'GET /rest/v1/profiles?select=*&email=eq.new%40freshline.app&limit=1',
      'POST /rest/v1/profiles?on_conflict=email',
    ]);
  });

  test(
    'supabase repo shows a clear offline message with no internet',
    () async {
      final MockClient client = MockClient((http.Request request) async {
        throw const SocketException('Failed host lookup');
      });

      final SupabasePlatformRepository repository = SupabasePlatformRepository(
        client: client,
      );

      await expectLater(
        repository.registerCustomer(
          name: 'New User',
          email: 'new@freshline.app',
          phone: '+973 3000 0000',
          city: 'Manama',
          password: 'freshline123',
        ),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            'No internet connection. Check your internet and try again.',
          ),
        ),
      );
    },
  );
}

Map<String, dynamic> _profileRow({
  required String id,
  required String email,
  required String passwordHash,
  required String? emailVerifiedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'role': AppRole.customer.value,
    'full_name': 'New User',
    'username': 'new_user',
    'email': email,
    'password_hash': passwordHash,
    'phone': '+973 3000 0000',
    'city': 'Manama',
    'address': null,
    'avatar_url': defaultProfileImageUrl,
    'is_active': true,
    'is_super_admin': false,
    'auth_user_id': null,
    'email_verified_at': emailVerifiedAt,
    'last_login_at': null,
    'created_at': '2026-04-06T00:00:00Z',
    'updated_at': '2026-04-06T00:00:00Z',
  };
}

String _readString(Object? value) => value?.toString() ?? '';
