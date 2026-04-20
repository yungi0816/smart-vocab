import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';

// 웹에서 사용 불가능한 패키지 — 조건부 임포트
import 'update_service_native.dart'
    if (dart.library.html) 'update_service_web.dart' as platform_update;

class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  Dio get _dio => Dio(BaseOptions(
    baseUrl: ApiService.instance.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final res = await _dio.get('/api/update/check');
      final remote = res.data;
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final remoteVersion = remote['version'] as String;

      if (_isNewer(remoteVersion, currentVersion)) {
        return remote;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  bool _isNewer(String remote, String current) {
    final r = remote.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }

  Future<void> downloadAndInstall(
    BuildContext context,
    Map<String, dynamic> updateInfo,
  ) async {
    if (kIsWeb) return; // 웹에서는 APK 업데이트 불필요
    await platform_update.downloadAndInstallNative(context, updateInfo, _dio);
  }

  static void showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> updateInfo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 버전이 있습니다'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('버전: ${updateInfo['version']}'),
            const SizedBox(height: 8),
            if (updateInfo['releaseNotes'] != null)
              Text(
                updateInfo['releaseNotes'],
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              UpdateService.instance.downloadAndInstall(context, updateInfo);
            },
            child: const Text('업데이트'),
          ),
        ],
      ),
    );
  }
}
