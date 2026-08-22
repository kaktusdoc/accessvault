import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accessvault/services/crypto_service.dart';
import 'package:accessvault/services/document_service.dart';
import 'package:accessvault/services/pin_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String _base;
  _FakePathProviderPlatform(this._base);

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(_base, 'documents');

  @override
  Future<String?> getTemporaryPath() async => p.join(_base, 'tmp');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('accessvault_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempRoot.path);
    SharedPreferences.setMockInitialValues({});
    CryptoService.clearSessionKey();
  });

  tearDown(() async {
    CryptoService.clearSessionKey();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('set PIN, import, "restart", unlock, open — round-trips correctly',
      () async {
    // 1. First-time PIN setup.
    await PinService.setPin('1234');
    expect(await PinService.hasPin(), isTrue);
    expect(CryptoService.isUnlocked, isTrue);

    // 2. Import a file — content must be encrypted on disk, not plaintext.
    final sourceFile =
        File(p.join(tempRoot.path, 'source', 'notes.txt'));
    await sourceFile.create(recursive: true);
    const plainText = 'these are private vault notes';
    await sourceFile.writeAsString(plainText);

    final doc = await DocumentService.importFile(sourceFile.path);
    final onDiskBytes = await File(doc.localPath).readAsBytes();
    expect(
      String.fromCharCodes(onDiskBytes).contains(plainText),
      isFalse,
      reason: 'file on disk must not contain the plaintext',
    );

    // 3. Simulate an app restart: the in-memory session key is gone, but
    // the encrypted file and metadata persist.
    CryptoService.clearSessionKey();
    expect(CryptoService.isUnlocked, isFalse);
    final docsAfterRestart = await DocumentService.loadAll();
    expect(docsAfterRestart, hasLength(1));

    // 4. Unlock with the correct PIN derives the session key again.
    final unlocked = await PinService.verifyPin('1234');
    expect(unlocked, isTrue);
    expect(CryptoService.isUnlocked, isTrue);

    // 5. "Open" the file: decrypt to a temp file and verify the exact
    // original bytes come back.
    final tempFile =
        await DocumentService.decryptToTempFile(docsAfterRestart.first);
    expect(await tempFile.exists(), isTrue);
    expect(await tempFile.readAsString(), plainText);

    await tempFile.delete();
  });

  test('wrong PIN does not unlock and cannot decrypt', () async {
    await PinService.setPin('1234');
    final sourceFile = File(p.join(tempRoot.path, 'source', 'a.txt'));
    await sourceFile.create(recursive: true);
    await sourceFile.writeAsString('secret');
    await DocumentService.importFile(sourceFile.path);

    CryptoService.clearSessionKey();

    final ok = await PinService.verifyPin('9999');
    expect(ok, isFalse);
    expect(CryptoService.isUnlocked, isFalse);
  });

  test('changePin re-encrypts documents and invalidates the old PIN',
      () async {
    await PinService.setPin('1111');

    final sourceFile = File(p.join(tempRoot.path, 'source', 'doc.txt'));
    await sourceFile.create(recursive: true);
    const plainText = 'contents that must survive a pin change';
    await sourceFile.writeAsString(plainText);
    final doc = await DocumentService.importFile(sourceFile.path);
    final cipherBefore = await File(doc.localPath).readAsBytes();

    await PinService.changePin('1111', '2222');

    // Ciphertext on disk must have changed (re-encrypted with a new key/IV).
    final cipherAfter = await File(doc.localPath).readAsBytes();
    expect(_bytesEqual(cipherBefore, cipherAfter), isFalse);

    // Old PIN must no longer verify.
    CryptoService.clearSessionKey();
    expect(await PinService.verifyPin('1111'), isFalse);
    expect(CryptoService.isUnlocked, isFalse);

    // New PIN unlocks and decrypts the original content correctly.
    expect(await PinService.verifyPin('2222'), isTrue);
    final docs = await DocumentService.loadAll();
    final plain = await DocumentService.decryptDocument(docs.first);
    expect(String.fromCharCodes(plain), plainText);
  });

  test('changePin with the wrong old PIN leaves the vault untouched',
      () async {
    await PinService.setPin('1111');
    final sourceFile = File(p.join(tempRoot.path, 'source', 'doc.txt'));
    await sourceFile.create(recursive: true);
    await sourceFile.writeAsString('untouched');
    final doc = await DocumentService.importFile(sourceFile.path);
    final cipherBefore = await File(doc.localPath).readAsBytes();

    await expectLater(
      PinService.changePin('0000', '2222'),
      throwsA(isA<CryptoException>()),
    );

    final cipherAfter = await File(doc.localPath).readAsBytes();
    expect(_bytesEqual(cipherBefore, cipherAfter), isTrue);

    CryptoService.clearSessionKey();
    expect(await PinService.verifyPin('1111'), isTrue);
  });
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
