import 'package:dio/dio.dart';
import 'crypto_service.dart';
import 'document_service.dart';
import 'secure_storage_service.dart';

/// Thrown for any sync failure; [message] is safe to show to the user.
class SyncException implements Exception {
  final String message;
  SyncException(this.message);

  @override
  String toString() => message;
}

class SyncResult {
  final int uploaded;
  final int downloaded;

  const SyncResult({required this.uploaded, required this.downloaded});

  String get summary => '$uploaded uploaded, $downloaded downloaded';
}

/// Add-only sync against the AccessVault backend: uploads local documents
/// missing on the server and downloads server documents missing locally.
/// Never deletes on either side. Documents are matched by filename.
class SyncService {
  static Future<SyncResult> sync() async {
    final serverUrl = await SecureStorageService.getServerUrl();
    final token = await SecureStorageService.getVaultToken();

    if (serverUrl == null || serverUrl.trim().isEmpty) {
      throw SyncException('No server URL configured. Set one in Settings.');
    }
    if (token == null || token.trim().isEmpty) {
      throw SyncException('No vault token configured. Set one in Settings.');
    }

    final dio = Dio(BaseOptions(
      baseUrl: serverUrl.trim(),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Authorization': 'Bearer ${token.trim()}'},
    ));

    try {
      final localDocs = await DocumentService.loadAll();
      final localNames = localDocs.map((d) => d.name).toSet();

      final response = await dio.get('/documents');
      final serverDocs = _parseDocList(response.data);
      final serverNames = serverDocs.map((d) => d['filename'] as String).toSet();

      var uploaded = 0;
      for (final doc in localDocs) {
        if (serverNames.contains(doc.name)) continue;
        // Local files are encrypted at rest; the server expects plaintext.
        final plainBytes = await DocumentService.decryptDocument(doc);
        await dio.post(
          '/documents/upload',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(plainBytes, filename: doc.name),
          }),
        );
        uploaded++;
      }

      var downloaded = 0;
      for (final sdoc in serverDocs) {
        final filename = sdoc['filename'] as String;
        if (localNames.contains(filename)) continue;
        final id = sdoc['id'];
        final fileResponse = await dio.get<List<int>>(
          '/documents/$id',
          options: Options(responseType: ResponseType.bytes),
        );
        await DocumentService.saveDownloadedFile(
          filename,
          fileResponse.data ?? const [],
        );
        downloaded++;
      }

      return SyncResult(uploaded: uploaded, downloaded: downloaded);
    } on DioException catch (e) {
      throw SyncException(_friendlyMessage(e));
    } on CryptoException catch (e) {
      throw SyncException(e.message);
    }
  }

  static List<Map<String, dynamic>> _parseDocList(dynamic data) {
    final list = data is List
        ? data
        : (data is Map ? data['docs'] as List? : null) ?? const [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static String _friendlyMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Could not reach the server. Check the server URL and that it is running.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          return 'Server rejected the vault token. Check Settings.';
        }
        return 'Server error (${status ?? 'unknown'}) during sync.';
      case DioExceptionType.cancel:
        return 'Sync was cancelled.';
      default:
        return 'Sync failed: ${e.message ?? 'unknown error'}';
    }
  }
}
