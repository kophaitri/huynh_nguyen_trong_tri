import 'package:flutter/material.dart';

import '../../core/validation/crud_validators.dart';
import '../../models/leave_request_model.dart';
import '../../models/paged_response.dart';
import '../../services/auth_service.dart';
import '../../services/leave_service.dart';
import '../../widgets/crud_widgets.dart';
import '../shared/crud_form_frame.dart';
import '../shared/crud_route.dart';
import '../shared/record_list_screen.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  LeaveStatus? _status;
  @override
  Widget build(BuildContext context) {
    final service = LeaveService(widget.auth);
    return RecordListScreen<LeaveRequestModel>(
      key: ValueKey(_status),
      title: 'Đơn nghỉ phép',
      load: (_, query) async =>
          PagedResponse.unpaged(await service.list(status: _status)),
      nameOf: (l) => '${l.userName} · #${l.id}',
      subtitleOf: (l) =>
          '${l.fromDate} → ${l.toDate}\n${l.reason}\nTạo lúc: ${l.createdAt.toLocal()}',
      badge: (l) => StatusBadge(l.status),
      filter: DropdownButtonFormField<LeaveStatus>(
        initialValue: _status,
        decoration: const InputDecoration(labelText: 'Trạng thái'),
        items: [
          const DropdownMenuItem<LeaveStatus>(
            value: null,
            child: Text('Tất cả'),
          ),
          ...LeaveStatus.values.map(
            (s) => DropdownMenuItem(value: s, child: Text(s.label)),
          ),
        ],
        onChanged: (status) => setState(() => _status = status),
      ),
      onCreate: () => openCrudPage<bool>(
        context,
        widget.auth,
        (_) => _LeaveForm(auth: widget.auth),
      ),
      onEdit: (l) => openCrudPage<bool>(
        context,
        widget.auth,
        (_) => _LeaveForm(auth: widget.auth, item: l),
      ),
      canEdit: service.canEdit,
      onDelete: service.delete,
      canDelete: service.canDelete,
      extraActions: (l, busy, perform) => !service.canReview(l)
          ? []
          : [
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final ok = await confirmCrudAction(
                          context,
                          title: 'Duyệt đơn #${l.id}',
                          message:
                              'Đồng ý đơn nghỉ của ${l.userName} từ ${l.fromDate} đến ${l.toDate}?',
                          confirmLabel: 'Duyệt',
                        );
                        if (ok && mounted) {
                          await perform(() => service.review(l, approve: true));
                        }
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Duyệt'),
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final ok = await confirmCrudAction(
                          context,
                          title: 'Từ chối đơn #${l.id}',
                          message: 'Từ chối đơn nghỉ của ${l.userName}?',
                          confirmLabel: 'Từ chối',
                        );
                        if (ok && mounted) {
                          await perform(
                            () => service.review(l, approve: false),
                          );
                        }
                      },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Từ chối'),
              ),
            ],
    );
  }
}

class _LeaveForm extends StatefulWidget {
  const _LeaveForm({required this.auth, this.item});
  final AuthService auth;
  final LeaveRequestModel? item;
  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<_LeaveForm> {
  late final _from = TextEditingController(
    text: widget.item?.fromDate ?? CrudValidators.formatDate(DateTime.now()),
  );
  late final _to = TextEditingController(
    text: widget.item?.toDate ?? CrudValidators.formatDate(DateTime.now()),
  );
  late final _reason = TextEditingController(text: widget.item?.reason);
  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: CrudValidators.parseDate(controller.text) ?? DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (date != null) controller.text = CrudValidators.formatDate(date);
  }

  @override
  Widget build(BuildContext context) => CrudFormFrame(
    title: widget.item == null ? 'Tạo đơn nghỉ phép' : 'Sửa đơn nghỉ phép',
    fields: [
      CrudTextField(
        controller: _from,
        label: 'Từ ngày',
        hint: 'yyyy-MM-dd',
        validator: CrudValidators.date,
      ),
      TextButton.icon(
        onPressed: () => _pick(_from),
        icon: const Icon(Icons.calendar_today_outlined),
        label: const Text('Chọn ngày bắt đầu'),
      ),
      CrudTextField(
        controller: _to,
        label: 'Đến ngày',
        hint: 'yyyy-MM-dd',
        validator: (v) {
          final error = CrudValidators.date(v);
          if (error != null) return error;
          return CrudValidators.parseDate(_from.text) != null &&
                  v!.compareTo(_from.text) < 0
              ? 'Ngày kết thúc không được trước ngày bắt đầu.'
              : null;
        },
      ),
      TextButton.icon(
        onPressed: () => _pick(_to),
        icon: const Icon(Icons.calendar_today_outlined),
        label: const Text('Chọn ngày kết thúc'),
      ),
      CrudTextField(
        controller: _reason,
        label: 'Lý do',
        maxLines: 4,
        validator: CrudValidators.requiredText,
      ),
    ],
    onSave: () async {
      final input = LeaveInput(
        fromDate: _from.text,
        toDate: _to.text,
        reason: _reason.text,
      );
      final service = LeaveService(widget.auth);
      if (widget.item == null) {
        await service.create(input);
      } else {
        await service.update(widget.item!, input);
      }
    },
  );
}
