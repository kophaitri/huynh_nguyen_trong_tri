import 'package:flutter/material.dart';

import '../../core/validation/crud_validators.dart';
import '../../models/department_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/department_service.dart';
import '../../widgets/crud_widgets.dart';
import '../shared/crud_form_frame.dart';
import '../shared/crud_route.dart';
import '../shared/record_list_screen.dart';

class DepartmentScreen extends StatelessWidget {
  const DepartmentScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  Widget build(BuildContext context) {
    final service = DepartmentService(auth);
    final admin = auth.user?.role == UserRole.admin;
    return RecordListScreen<DepartmentModel>(
      title: 'Phòng ban',
      load: (page, _) => service.list(page: page),
      nameOf: (d) => d.name,
      subtitleOf: (d) => d.description ?? 'Chưa có mô tả',
      onCreate: admin
          ? () => openCrudPage<bool>(
              context,
              auth,
              (_) => _DepartmentForm(auth: auth),
            )
          : null,
      onEdit: admin
          ? (d) => openCrudPage<bool>(
              context,
              auth,
              (_) => _DepartmentForm(auth: auth, item: d),
            )
          : null,
      onDelete: admin ? (d) => service.delete(d.id) : null,
    );
  }
}

class _DepartmentForm extends StatefulWidget {
  const _DepartmentForm({required this.auth, this.item});
  final AuthService auth;
  final DepartmentModel? item;
  @override
  State<_DepartmentForm> createState() => _DepartmentFormState();
}

class _DepartmentFormState extends State<_DepartmentForm> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _description = TextEditingController(
    text: widget.item?.description,
  );
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CrudFormFrame(
    title: widget.item == null ? 'Thêm phòng ban' : 'Sửa phòng ban',
    fields: [
      CrudTextField(
        controller: _name,
        label: 'Tên phòng ban',
        validator: CrudValidators.requiredText,
      ),
      CrudTextField(controller: _description, label: 'Mô tả', maxLines: 3),
    ],
    onSave: () async {
      final input = DepartmentInput(
        name: _name.text,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
      );
      final service = DepartmentService(widget.auth);
      if (widget.item == null) {
        await service.create(input);
      } else {
        await service.update(widget.item!.id, input);
      }
    },
  );
}
