import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../core/validation/crud_validators.dart';
import '../../models/shift_model.dart';
import '../../models/user_model.dart';
import '../../models/work_location_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/shift_service.dart';
import '../../widgets/crud_widgets.dart';
import '../shared/crud_form_frame.dart';
import '../shared/crud_route.dart';
import '../shared/record_list_screen.dart';

class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  Widget build(BuildContext context) {
    final service = LocationService(auth);
    final admin = auth.user?.role == UserRole.admin;
    return RecordListScreen<WorkLocationModel>(
      title: 'Địa điểm',
      load: (page, _) => service.list(page: page),
      nameOf: (l) => l.name,
      subtitleOf: (l) =>
          '${l.address ?? 'Chưa có địa chỉ'}\n${l.latitude}, ${l.longitude} · ${l.radiusMeters} m · Ca #${l.shiftId}',
      onCreate: admin
          ? () => openCrudPage<bool>(
              context,
              auth,
              (_) => _LocationForm(auth: auth),
            )
          : null,
      onEdit: admin
          ? (l) => openCrudPage<bool>(
              context,
              auth,
              (_) => _LocationForm(auth: auth, item: l),
            )
          : null,
      onDelete: admin ? (l) => service.delete(l.id) : null,
    );
  }
}

class _LocationForm extends StatefulWidget {
  const _LocationForm({required this.auth, this.item});
  final AuthService auth;
  final WorkLocationModel? item;
  @override
  State<_LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<_LocationForm> {
  late Future<List<ShiftModel>> _shifts = ShiftService(widget.auth).all();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _address = TextEditingController(text: widget.item?.address);
  late final _latitude = TextEditingController(
    text: widget.item?.latitude.toString(),
  );
  late final _longitude = TextEditingController(
    text: widget.item?.longitude.toString(),
  );
  late final _radius = TextEditingController(
    text: '${widget.item?.radiusMeters ?? 100}',
  );
  late int? _shiftId = widget.item?.shiftId;
  @override
  void dispose() {
    for (final c in [_name, _address, _latitude, _longitude, _radius]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ShiftModel>>(
    future: _shifts,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(title: const Text('Địa điểm')),
          body: Center(
            child: snapshot.hasError
                ? CrudErrorState(
                    message: snapshot.error is ApiFailure
                        ? (snapshot.error as ApiFailure).message
                        : 'Không thể tải ca làm.',
                    onRetry: () => setState(
                      () =>
                          _shifts = ShiftService(widget.auth)
                              .all(forceRefresh: true),
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      }
      final shifts = snapshot.data!;
      return CrudFormFrame(
        title: widget.item == null ? 'Thêm địa điểm' : 'Sửa địa điểm',
        fields: [
          CrudTextField(
            controller: _name,
            label: 'Tên địa điểm',
            validator: CrudValidators.requiredText,
          ),
          CrudTextField(controller: _address, label: 'Địa chỉ', maxLines: 2),
          CrudTextField(
            controller: _latitude,
            label: 'Vĩ độ (latitude)',
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            validator: (v) => CrudValidators.coordinate(v, latitude: true),
          ),
          CrudTextField(
            controller: _longitude,
            label: 'Kinh độ (longitude)',
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            validator: (v) => CrudValidators.coordinate(v, latitude: false),
          ),
          CrudTextField(
            controller: _radius,
            label: 'Bán kính (mét)',
            keyboardType: TextInputType.number,
            validator: CrudValidators.positiveInt,
          ),
          DropdownButtonFormField<int>(
            initialValue: _shiftId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ca làm'),
            items: [
              if (_shiftId != null && !shifts.any((s) => s.id == _shiftId))
                DropdownMenuItem(
                  value: _shiftId,
                  child: Text('Ca #$_shiftId (không còn trong danh sách)'),
                ),
              ...shifts.map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (id) => setState(() => _shiftId = id),
            validator: (id) => id == null ? 'Vui lòng chọn ca làm.' : null,
          ),
          if (shifts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Chưa có ca làm. Hãy tạo ca làm trước.'),
            ),
          const SizedBox(height: 18),
        ],
        onSave: () async {
          final input = WorkLocationInput(
            name: _name.text,
            address: _address.text.trim().isEmpty ? null : _address.text,
            latitude: double.parse(_latitude.text),
            longitude: double.parse(_longitude.text),
            radiusMeters: int.parse(_radius.text),
            shiftId: _shiftId!,
          );
          final service = LocationService(widget.auth);
          if (widget.item == null) {
            await service.create(input);
          } else {
            await service.update(widget.item!.id, input);
          }
        },
      );
    },
  );
}
