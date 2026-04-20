import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> downloadAndInstallNative(
  BuildContext context,
  Map<String, dynamic> updateInfo,
  Dio dio,
) async {
  if (Platform.isAndroid) {
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('앱 설치 권한이 필요합니다. 설정에서 허용해주세요.')),
        );
      }
      return;
    }
  }

  final dir = await getTemporaryDirectory();
  final savePath = '${dir.path}/smart_vocab_update.apk';

  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        dio: dio,
        savePath: savePath,
        onComplete: () {
          Navigator.of(ctx).pop();
          OpenFilex.open(savePath);
        },
        onError: (msg) {
          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        },
      ),
    );
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final Dio dio;
  final String savePath;
  final VoidCallback onComplete;
  final void Function(String) onError;

  const _DownloadProgressDialog({
    required this.dio,
    required this.savePath,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      await widget.dio.download(
        '/api/update/download',
        widget.savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() => _progress = received / total);
          }
        },
      );
      widget.onComplete();
    } catch (e) {
      widget.onError('다운로드에 실패했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('업데이트 다운로드 중'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 12),
          Text('${(_progress * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}
