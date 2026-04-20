import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

Future<void> downloadAndInstallNative(
  BuildContext context,
  Map<String, dynamic> updateInfo,
  Dio dio,
) async {
  // 웹에서는 APK 업데이트 불필요 — no-op
}
