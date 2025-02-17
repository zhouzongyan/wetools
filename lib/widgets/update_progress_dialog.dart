import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateProgressDialog extends StatefulWidget {
  final String downloadUrl;

  const UpdateProgressDialog({super.key, required this.downloadUrl});

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  double _progress = 0;
  String? _error;
  bool _downloadComplete = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _startUpdate();
  }

  Future<void> _startUpdate() async {
    if (_isCancelled) return;

    try {
      final result = await UpdateService.downloadAndUpdate(
        widget.downloadUrl,
        (progress) {
          if (mounted && !_isCancelled) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );

      if (mounted && !_isCancelled) {
        if (result.success) {
          setState(() {
            _downloadComplete = true;
          });
        } else {
          setState(() {
            _error = result.message;
          });
        }
      }
    } catch (e) {
      if (mounted && !_isCancelled) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  void _cancelDownload() {
    setState(() {
      _isCancelled = true;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_downloadComplete ? '更新已就绪' : '正在更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('下载进度: ${(_progress * 100).toStringAsFixed(1)}%'),
              if (!_downloadComplete && _error == null)
                TextButton(
                  onPressed: _cancelDownload,
                  child: const Text('取消'),
                ),
            ],
          ),
          if (_downloadComplete) ...[
            const SizedBox(height: 8),
            const Text('下载完成，点击确认后将重启应用以完成更新'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        if (_downloadComplete)
          FilledButton(
            onPressed: () async {
              try {
                await UpdateService.applyUpdate();
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _error = e.toString();
                  });
                }
              }
            },
            child: const Text('确认更新'),
          ),
      ],
    );
  }
}
