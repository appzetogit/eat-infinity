import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_user_application/src/core/network/api_client.dart';
import 'package:food_user_application/src/core/storage/token_storage.dart';
import 'package:food_user_application/src/data/datasources/auth_remote_datasource.dart';
import 'package:food_user_application/src/data/repository/auth_repository_impl.dart';

/// Exercises the real network stack against the live backend.
///
/// Run with:  flutter test test/auth_integration_test.dart
///
/// Covers the parts most likely to break silently: envelope unwrapping,
/// token persistence, and the Bearer-authenticated round trip.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ApiClient's response cache hydrates from SharedPreferences, which has
  // no platform implementation under `flutter test`.
  SharedPreferences.setMockInitialValues(<String, Object>{});

  // flutter_secure_storage is a platform channel — back it with an in-memory
  // map so the repository's real persistence path runs under test.
  final store = <String, String>{};
  setUpAll(() {
    // flutter_test installs HttpOverrides that stub every request with a 400.
    // This suite deliberately talks to the real backend.
    HttpOverrides.global = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        switch (call.method) {
          case 'write':
            store[call.arguments['key'] as String] = call.arguments['value'] as String;
            return null;
          case 'read':
            return store[call.arguments['key'] as String];
          case 'delete':
            store.remove(call.arguments['key'] as String);
            return null;
          case 'readAll':
            return store;
          case 'deleteAll':
            store.clear();
            return null;
        }
        return null;
      },
    );
  });

  // One QA number per test that requests an OTP, rather than one shared by the
  // whole file.
  //
  // The backend caps OTP requests at 3 per phone per 10 minutes (see
  // /api/v1/health/rate-limit). Four tests here request a code, so sharing a
  // single number put the last one over the cap and failed it with "Too many
  // OTP requests" — a rate limit doing its job, reported as if the app were
  // broken. One number each keeps every test at a single request, so the file
  // can be re-run roughly three times in ten minutes before the cap applies.
  const leakPhone = '9999900002';
  const flowPhone = '9999900004';
  const wrongOtpPhone = '9999900005';
  const profilePhone = '9999900006';
  const testOtp = '1234';

  late TokenStorage tokens;
  late AuthRepositoryImpl repo;

  setUp(() {
    store.clear();
    tokens = TokenStorage();
    final client = ApiClient(tokens: tokens);
    repo = AuthRepositoryImpl(AuthRemoteDataSource(client), tokens);
  });

  // Requests an OTP and returns the code to verify with.
  //
  // Deliberately tolerant of *which* backend it is pointed at, because the code
  // can legitimately arrive two ways: a hardened deployment issues a fixed code
  // to allowlisted QA numbers and returns nothing, while a non-production one
  // (NODE_ENV != production, or USE_DEFAULT_OTP) echoes the real code back in
  // the response body. Preferring the echoed code when it is there keeps the
  // flow assertions below meaningful on both, instead of the whole suite going
  // red on a config difference that says nothing about the app.
  //
  // That the echo happens at all is a *backend* problem, not an app one, so it
  // is asserted on its own below rather than being folded in here.
  Future<String> obtainOtp(String phone) async {
    final result = await repo.requestOtp(phone);
    expect(result.isSuccess, isTrue, reason: result.message);
    return result.data ?? testOtp;
  }

  test('request-otp must never return the OTP to the client', () async {
    final otpResult = await repo.requestOtp(leakPhone);
    expect(otpResult.isSuccess, isTrue, reason: otpResult.message);
    expect(
      otpResult.data,
      isNull,
      reason: 'The backend echoed the OTP back in the request-otp response. '
          'Anyone who can reach the API can then log in as any phone number '
          'without seeing the SMS, so this is an authentication bypass rather '
          'than a test-only convenience. It is gated on NODE_ENV/USE_DEFAULT_OTP '
          'server-side — set NODE_ENV=production and USE_DEFAULT_OTP=false on '
          'the deployment. Do not delete this assertion to make the suite green.',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('request OTP → verify → session persisted → authed profile fetch', () async {
    final otp = await obtainOtp(flowPhone);

    // Verify. This is where the envelope is unwrapped and tokens are saved.
    final session = await repo.verifyOtp(phone: flowPhone, otp: otp);
    expect(session.isSuccess, isTrue, reason: session.message);
    expect(session.data!.accessToken, isNotEmpty);
    expect(session.data!.user.phone, flowPhone);

    // 3. Tokens actually landed in secure storage.
    expect(await tokens.hasSession, isTrue);
    expect(await tokens.accessToken, isNotEmpty);

    // 4. Authenticated round trip using the stored Bearer token.
    final profile = await repo.getProfile();
    expect(profile.isSuccess, isTrue, reason: profile.message);
    expect(profile.data!.id, session.data!.user.id);

    // 5. Session restore is what cold start relies on.
    final restored = await repo.restoreSession();
    expect(restored.data, isNotNull);

    // 6. Logout clears the session locally even though the server call is
    //    best-effort.
    await repo.logout();
    expect(await tokens.hasSession, isFalse);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a wrong OTP surfaces the backend message, not a crash', () async {
    final otp = await obtainOtp(wrongOtpPhone);
    // '0000' unless that is genuinely the issued code, in which case any other
    // value is wrong — otherwise this "wrong OTP" test can log in by accident.
    final wrong = otp == '0000' ? '1111' : '0000';
    final result = await repo.verifyOtp(phone: wrongOtpPhone, otp: wrong);
    expect(result.isSuccess, isFalse);
    expect(result.message, isNotNull);
    expect(await tokens.hasSession, isFalse, reason: 'failed login must not persist tokens');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('validation rejections surface the backend reason, not a generic fallback', () async {
    // The API puts validation reasons under `error`, not `message` — regression
    // guard for the client reading only one of the two.
    // No request-otp call: a malformed code is rejected by validation before
    // any OTP is looked up, so this test costs nothing against the cap.
    final result = await repo.verifyOtp(phone: wrongOtpPhone, otp: '12');
    expect(result.isSuccess, isFalse);
    expect(result.message, contains('4 digits'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('profile update round-trips through PATCH', () async {
    final otp = await obtainOtp(profilePhone);
    final session = await repo.verifyOtp(phone: profilePhone, otp: otp);
    expect(session.isSuccess, isTrue, reason: session.message);

    final name = 'QA ${DateTime.now().millisecondsSinceEpoch % 100000}';
    final updated = await repo.updateProfile(name: name);
    expect(updated.isSuccess, isTrue, reason: updated.message);
    expect(updated.data!.name, name);

    // Confirm the server, not just the local object, actually changed.
    final refetched = await repo.getProfile();
    expect(refetched.data!.name, name);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
