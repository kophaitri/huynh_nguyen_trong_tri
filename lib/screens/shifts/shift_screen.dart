import 'package:flutter/material.dart';

import '../../core/validation/crud_validators.dart';
import '../../models/shift_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/shift_service.dart';
import '../../widgets/crud_widgets.dart';
import '../shared/crud_form_frame.dart';
import '../shared/crud_route.dart';
import '../shared/record_list_screen.dart';

class ShiftScreen extends StatelessWidget {
  const ShiftScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  Widget build(BuildContext context) {
    final service = ShiftService(auth);
    final admin = auth.user?.role == UserRole.admin;
    return RecordListScreen<ShiftModel>(
      title: 'Ca làm',
      load: (page, _) => service.list(page: page),
      nameOf: (s) => s.name,
      subtitleOf: (s) =>
          '${s.startTime} – ${s.endTime}\nCho phép trễ: ${s.lateToleranceMinutes} phút',
      onCreate: admin
          ? () =>
                openCrudPage<bool>(context, auth, (_) => _ShiftForm(auth: auth))
          : null,
      onEdit: admin
          ? (s) => openCrudPage<bool>(
              context,
              auth,
              (_) => _ShiftForm(auth: auth, item: s),
            )
          : null,
      onDelete: admin ? (s) => service.delete(s.id) : null,
    );
  }
}

class _ShiftForm extends StatefulWidget {
  const _ShiftForm({required this.auth, this.item});
  final AuthService auth;
  final ShiftModel? item;
  @override
  State<_ShiftForm> createState() => _ShiftFormState();
}

class _ShiftFormState extends State<_ShiftForm> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _start = TextEditingController(
    text: widget.item?.startTime ?? '08:00:00',
  );
  late final _end = TextEditingController(
    text: widget.item?.endTime ?? '17:00:00',
  );
  late final _tolerance = TextEditingController(
    text: '${widget.item?.lateToleranceMinutes ?? 10}',
  );
  @override
  void dispose() {
    for (final c in [_name, _start, _end, _tolerance]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CrudFormFrame(
    title: widget.item == null ? 'Thêm ca làm' : 'Sửa ca làm',
    fields: [
      CrudTextField(
        controller: _name,
        label: 'Tên ca',
        validator: CrudValidators.requiredText,
      ),
      CrudTextField(
        controller: _start,
        label: 'Giờ bắt đầu',
        hint: 'HH:mm:ss',
        validator: CrudValidators.time,
      ),
      CrudTextField(
        controller: _end,
        label: 'Giờ kết thúc',
        hint: 'HH:mm:ss',
        validator: CrudValidators.time,
      ),
      CrudTextField(
        controller: _tolerance,
        label: 'Số phút cho phép trễ',
        keyboardType: TextInputType.number,
        validator: CrudValidators.nonNegativeInt,
      ),
    ],
    onSave: () async {
      final input = ShiftInput(
        name: _name.text,
        startTime: _start.text,
        endTime: _end.text,
        lateToleranceMinutes: int.parse(_tolerance.text),
      );
      final service = ShiftService(widget.auth);
      if (widget.item == null) {
        await service.create(input);
      } else {
        await service.update(widget.item!.id, input);
      }
    },
  );
}
