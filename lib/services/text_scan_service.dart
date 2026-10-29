import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../models/text_scan_result.dart';

class TextScanException implements Exception {
  const TextScanException(this.message);
  final String message;
}

/// Local OCR/translation only; no attendance API or content logging.
class TextScanService {
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final _models = OnDeviceTranslatorModelManager();

  Future<TextScanResult> recognize(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    // Keep native resources alive until the native operation actually completes,
    // including when the UI has already reported a timeout.
    final operation = () async {
      try {
        final result = await recognizer.processImage(
          InputImage.fromFilePath(path),
        );
        if (result.text.trim().isEmpty) {
          throw const TextScanException(
            'Không tìm thấy chữ. Chụp rõ nét, đủ sáng và giữ thẳng tài liệu.',
          );
        }
        return TextScanResult(original: result.text.trim());
      } finally {
        await recognizer.close();
      }
    }();
    return operation.timeout(const Duration(seconds: 35));
  }

  TranslateLanguage _language(TextLanguage value) =>
      value == TextLanguage.english
      ? TranslateLanguage.english
      : TranslateLanguage.vietnamese;

  Future<String> translate(
    String text,
    TextLanguage source,
    void Function(String) onStatus,
  ) async {
    if (text.length > 5000) {
      throw const TextScanException(
        'Ảnh có quá nhiều chữ (tối đa 5.000 ký tự mỗi lần dịch). Hãy chụp từng phần.',
      );
    }
    onStatus('Đang kiểm tra mô hình ngôn ngữ trên thiết bị…');
    for (final language in [
      TranslateLanguage.english,
      TranslateLanguage.vietnamese,
    ]) {
      final ready = await _models
          .isModelDownloaded(language.bcpCode)
          .timeout(const Duration(seconds: 10));
      if (!ready) {
        onStatus(
          'Đang tải mô hình ${language == TranslateLanguage.english ? 'tiếng Anh' : 'tiếng Việt'}… Cần Internet, có thể tốn dữ liệu di động.',
        );
        final downloaded = await _models
            .downloadModel(language.bcpCode, isWifiRequired: false)
            .timeout(const Duration(seconds: 90));
        if (!downloaded) {
          throw const TextScanException(
            'Chưa tải được mô hình. Kiểm tra Internet và dung lượng trống, rồi bấm Dịch lại. Văn bản gốc vẫn được giữ.',
          );
        }
      }
    }
    onStatus('Đang dịch trên thiết bị…');
    final translator = OnDeviceTranslator(
      sourceLanguage: _language(source),
      targetLanguage: _language(source.opposite),
    );
    final operation = () async {
      try {
        return await translator.translateText(text);
      } finally {
        await translator.close();
      }
    }();
    return operation.timeout(const Duration(seconds: 35));
  }
}
