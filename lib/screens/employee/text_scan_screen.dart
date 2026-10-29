import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/text_scan_result.dart';
import '../../services/text_scan_service.dart';
import '../../widgets/text_result_card.dart';

class TextScanScreen extends StatefulWidget {
  const TextScanScreen({super.key});
  @override
  State<TextScanScreen> createState() => _TextScanScreenState();
}

class _TextScanScreenState extends State<TextScanScreen> {
  final _service = TextScanService();
  final _picker = ImagePicker();
  TextLanguage _source = TextLanguage.english;
  TextScanResult? _result;
  bool _busy = false;
  bool _permissionError = false;
  String? _error;
  String _status = '';

  @override
  void initState() {
    super.initState();
    if (TextScanService.supported &&
        defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_recoverImage());
    }
  }

  void _progress(String value) {
    if (mounted) setState(() => _status = value);
  }

  Future<void> _recoverImage() => _run(() async {
    final lost = await _picker.retrieveLostData();
    if (!mounted) return;
    if (lost.exception != null) throw lost.exception!;
    if (lost.files?.isNotEmpty == true) await _recognize(lost.files!.first);
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _permissionError = false;
    });
    try {
      await action();
    } on TextScanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error = 'Quá thời gian xử lý hoặc tải mô hình. Kiểm tra Internet khi tải lần đầu rồi thử lại. Nội dung đã nhận dạng vẫn được giữ.',
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _permissionError =
              e.code.toLowerCase().contains('access') ||
              e.code.toLowerCase().contains('denied');
          _error = _permissionError
              ? 'Chưa được phép truy cập camera/ảnh. Cấp quyền trong cài đặt rồi thử lại.'
              : 'Không xử lý được ảnh hoặc mô hình. Kiểm tra camera, chọn ảnh JPG/PNG rõ chữ; nếu đang tải mô hình, kiểm tra Internet và dung lượng trống rồi thử lại.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể xử lý. Hãy chọn ảnh khác hoặc thử lại; không có dữ liệu nào được gửi lên backend.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(ImageSource source) => _run(() async {
    _progress('Đang chờ ảnh…');
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 95,
      requestFullMetadata: false,
    );
    if (file != null && mounted) await _recognize(file);
  });

  Future<void> _recognize(XFile file) async {
    _progress('Đang nhận dạng chữ trên thiết bị…');
    final result = await _service.recognize(file.path);
    if (mounted) setState(() => _result = result);
  }

  Future<void> _translate() => _run(() async {
    final original = _result?.original;
    if (original == null) return;
    final text = await _service.translate(original, _source, _progress);
    if (mounted) {
      setState(
        () => _result = TextScanResult(original: original, translation: text),
      );
    }
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quét và dịch văn bản')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF132D50),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.document_scanner_outlined,
                        color: Color(0xFF87E7C2),
                        size: 36,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Từ hình ảnh đến ngôn ngữ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Chụp hoặc chọn ảnh rõ chữ Latin, đọc nội dung rồi dịch Anh ↔ Việt ngay trên thiết bị.',
                        style: TextStyle(color: Color(0xFFD5E6F5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (!TextScanService.supported)
                  const Text(
                    'Nhận dạng và dịch ảnh hiện hỗ trợ Android/iOS. Hãy mở trên điện thoại.',
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy || !TextScanService.supported
                          ? null
                          : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _result == null ? 'Chụp ảnh' : 'Chụp lại ảnh',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || !TextScanService.supported
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Chọn ảnh'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<TextLanguage>(
                  initialValue: _source,
                  decoration: const InputDecoration(
                    labelText: 'Ngôn ngữ trong ảnh',
                  ),
                  items: TextLanguage.values
                      .map(
                        (l) => DropdownMenuItem(value: l, child: Text(l.label)),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _source = value;
                              if (_result != null) {
                                _result = TextScanResult(
                                  original: _result!.original,
                                );
                              }
                            });
                          }
                        },
                ),
                const SizedBox(height: 12),
                Text(
                  'Dịch sang ${_source.opposite.label}. Lần đầu cần tải mô hình qua Internet (có thể dùng dữ liệu di động); các lần sau dịch offline khi mô hình còn trên máy.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || _result == null ? null : _translate,
                  icon: const Icon(Icons.translate),
                  label: Text('Dịch với Google → ${_source.opposite.label}'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(_status),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (_permissionError)
                    TextButton(
                      onPressed: Geolocator.openAppSettings,
                      child: const Text('Mở cài đặt quyền'),
                    ),
                ],
                const SizedBox(height: 16),
                TextResultCard(
                  title: 'Văn bản gốc',
                  text: _result?.original ?? '',
                ),
                TextResultCard(
                  title: 'Bản dịch · ${_source.opposite.label}',
                  text: _result?.translation ?? '',
                ),
                const Text(
                  'Bản dịch tự động · powered by Google Translate (ML Kit trên thiết bị)',
                  style: TextStyle(color: Color(0xFF63738A), fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nhận dạng và bản dịch tự động có thể sai, hãy đối chiếu ảnh gốc. Không gửi ảnh/văn bản lên backend. Ảnh chụp có thể nằm tạm trong cache của trình chọn ảnh; chỉ sao chép khi bạn bấm nút.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
