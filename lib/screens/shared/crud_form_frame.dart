import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../widgets/auth_frame.dart';

class CrudFormFrame extends StatefulWidget {
  const CrudFormFrame({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
  });
  final String title;
  final List<Widget> fields;
  final Future<void> Function() onSave;
  @override
  State<CrudFormFrame> createState() => _CrudFormFrameState();
}

class _CrudFormFrameState extends State<CrudFormFrame> {
  final _key = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, true);
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${error.message}\nThao tác chưa được xác nhận. Nếu kết nối gián đoạn, hãy làm mới danh sách trước khi gửi lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: !_saving,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Form(
                key: _key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) AuthMessage(_error!),
                    AbsorbPointer(
                      absorbing: _saving,
                      child: Column(children: widget.fields),
                    ),
                    const SizedBox(height: 8),
                    AuthButton(label: 'Lưu', busy: _saving, onPressed: _save),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
