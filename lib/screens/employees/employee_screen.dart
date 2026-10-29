import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../core/validation/auth_validators.dart';
import '../../core/validation/crud_validators.dart';
import '../../models/department_model.dart';
import '../../models/employee_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/department_service.dart';
import '../../services/employee_service.dart';
import '../../widgets/crud_widgets.dart';
import '../../widgets/password_field.dart';
import '../shared/crud_form_frame.dart';
import '../shared/crud_route.dart';
import '../shared/record_list_screen.dart';

class EmployeeScreen extends StatelessWidget {
  const EmployeeScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  Widget build(BuildContext context) {
    final service = EmployeeService(auth);
    final admin = auth.user?.role == UserRole.admin;
    return RecordListScreen<EmployeeModel>(
      title: 'Nhân viên',
      serverSearch: true,
      load: (page, query) => service.list(page: page, query: query),
      nameOf: (e) => e.fullName,
      subtitleOf: (e) =>
          '${e.email}\n${e.employeeCode ?? 'Chưa có mã'} · ${e.department ?? 'Chưa có phòng ban'} · ${e.isActive ? 'Hoạt động' : 'Đã khóa'}',
      onOpen: (e) async {
        await openCrudPage<void>(
          context,
          auth,
          (_) => EmployeeDetailScreen(auth: auth, id: e.id),
        );
      },
      onCreate: admin
          ? () => openCrudPage<bool>(
              context,
              auth,
              (_) => EmployeeFormScreen(auth: auth),
            )
          : null,
      onEdit: admin
          ? (e) => openCrudPage<bool>(
              context,
              auth,
              (_) => EmployeeFormScreen(auth: auth, employeeId: e.id),
            )
          : null,
      onDelete: admin ? (e) => service.delete(e.id) : null,
    );
  }
}

class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({super.key, required this.auth, required this.id});
  final AuthService auth;
  final String id;
  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late Future<EmployeeModel> _future = EmployeeService(widget.auth)
      .get(widget.id);
  void _reload() =>
      setState(() => _future = EmployeeService(widget.auth).get(widget.id));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chi tiết nhân viên'),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Làm mới',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<EmployeeModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: CrudErrorState(
              message: snapshot.error is ApiFailure
                  ? (snapshot.error as ApiFailure).message
                  : 'Không thể tải nhân viên.',
              onRetry: _reload,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final e = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        e.fullName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      Text('Email: ${e.email}'),
                      const SizedBox(height: 12),
                      Text('Mã nhân viên: ${e.employeeCode ?? 'Chưa có'}'),
                      const SizedBox(height: 12),
                      Text(
                        'Phòng ban: ${e.departmentId == null ? 'Chưa có' : '#${e.departmentId}'}',
                      ),
                      const SizedBox(height: 12),
                      Text('Vai trò: ${e.role ?? 'Chưa được cấp'}'),
                      const SizedBox(height: 12),
                      Text(
                        'Trạng thái: ${e.isActive ? 'Hoạt động' : 'Đã khóa'}',
                      ),
                      if (widget.auth.user?.role == UserRole.admin) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () async {
                            final changed = await openCrudPage<bool>(
                              context,
                              widget.auth,
                              (_) => EmployeeFormScreen(
                                auth: widget.auth,
                                employeeId: e.id,
                              ),
                            );
                            if (changed == true && mounted) _reload();
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Sửa nhân viên'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class EmployeeFormScreen extends StatefulWidget {
  const EmployeeFormScreen({super.key, required this.auth, this.employeeId});
  final AuthService auth;
  final String? employeeId;
  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  List<DepartmentModel> _departments = [];
  int? _departmentId;
  String? _role = 'Employee';
  bool _active = true;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = EmployeeService(widget.auth);
      // Both are reads; no employee is created until the user submits the form.
      final results = await Future.wait<Object?>([
        DepartmentService(widget.auth).all(forceRefresh: forceRefresh),
        widget.employeeId == null
            ? Future<EmployeeModel?>.value(null)
            : service.get(widget.employeeId!),
      ]);
      if (!mounted) return;
      _departments = results[0] as List<DepartmentModel>;
      final employee = results[1] as EmployeeModel?;
      if (employee != null) {
        _name.text = employee.fullName;
        _email.text = employee.email;
        _code.text = employee.employeeCode ?? '';
        _departmentId = employee.departmentId;
        _active = employee.isActive;
        _role = const ['Admin', 'Manager', 'Employee'].contains(employee.role)
            ? employee.role
            : null;
      }
    } on ApiFailure catch (error) {
      if (mounted) _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _code, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nhân viên')),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : CrudErrorState(
                  message: _error!,
                  onRetry: () => _load(forceRefresh: true),
                ),
        ),
      );
    }
    return CrudFormFrame(
      title: widget.employeeId == null ? 'Thêm nhân viên' : 'Sửa nhân viên',
      fields: [
        CrudTextField(
          controller: _name,
          label: 'Họ và tên',
          validator: CrudValidators.requiredText,
        ),
        CrudTextField(
          controller: _email,
          label: 'Email',
          readOnly: widget.employeeId != null,
          validator: AuthValidators.email,
          keyboardType: TextInputType.emailAddress,
        ),
        if (widget.employeeId == null) ...[
          PasswordField(
            controller: _password,
            validator: AuthValidators.newPassword,
          ),
          const SizedBox(height: 8),
          const Text('Mật khẩu có ít nhất 6 ký tự, chữ thường và số.'),
          const SizedBox(height: 18),
        ],
        CrudTextField(controller: _code, label: 'Mã nhân viên (tùy chọn)'),
        DropdownButtonFormField<int>(
          initialValue: _departmentId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Phòng ban'),
          items: [
            const DropdownMenuItem<int>(
              value: null,
              child: Text('Không thuộc phòng ban'),
            ),
            if (_departmentId != null &&
                !_departments.any((d) => d.id == _departmentId))
              DropdownMenuItem(
                value: _departmentId,
                child: Text('Phòng ban #$_departmentId'),
              ),
            ..._departments.map(
              (d) => DropdownMenuItem(
                value: d.id,
                child: Text(d.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (id) => setState(() => _departmentId = id),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: _role,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Vai trò nhân viên'),
          hint: const Text('Giữ nguyên vai trò hiện tại'),
          items: const [
            'Employee',
            'Manager',
            'Admin',
          ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (role) => setState(() => _role = role),
        ),
        if (widget.employeeId != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tài khoản hoạt động'),
            value: _active,
            onChanged: (active) => setState(() => _active = active),
          ),
        const SizedBox(height: 18),
      ],
      onSave: () async {
        final service = EmployeeService(widget.auth);
        final code = _code.text.trim().isEmpty ? null : _code.text.trim();
        if (widget.employeeId == null) {
          await service.create(
            EmployeeCreateInput(
              email: _email.text,
              password: _password.text,
              fullName: _name.text,
              employeeCode: code,
              departmentId: _departmentId,
              role: _role!,
            ),
          );
          _password.clear();
        } else {
          await service.update(
            widget.employeeId!,
            EmployeeUpdateInput(
              fullName: _name.text,
              employeeCode: code,
              departmentId: _departmentId,
              role: _role,
              isActive: _active,
            ),
          );
        }
      },
    );
  }
}
