import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../core/network/api_client.dart';
import '../../models/paged_response.dart';
import '../../widgets/crud_widgets.dart';

class RecordListScreen<T> extends StatefulWidget {
  const RecordListScreen({
    super.key,
    required this.title,
    required this.load,
    required this.nameOf,
    required this.subtitleOf,
    this.onCreate,
    this.onEdit,
    this.onDelete,
    this.onOpen,
    this.extraActions,
    this.badge,
    this.filter,
    this.canEdit,
    this.canDelete,
    this.serverSearch = false,
    this.searchText,
  });
  final String title;
  final Future<PagedResponse<T>> Function(int page, String query) load;
  final String Function(T) nameOf;
  final String Function(T) subtitleOf;
  final String Function(T)? searchText;
  final Future<bool?> Function()? onCreate;
  final Future<bool?> Function(T)? onEdit;
  final Future<void> Function(T)? onDelete;
  final Future<void> Function(T)? onOpen;
  final List<Widget> Function(
    T,
    bool busy,
    Future<void> Function(Future<void> Function()) perform,
  )?
  extraActions;
  final Widget Function(T)? badge;
  final Widget? filter;
  final bool Function(T)? canEdit;
  final bool Function(T)? canDelete;
  final bool serverSearch;
  @override
  State<RecordListScreen<T>> createState() => _RecordListScreenState<T>();
}

class _RecordListScreenState<T> extends State<RecordListScreen<T>> {
  PagedResponse<T>? _data;
  String? _error;
  String _query = '';
  int _page = 1;
  int _request = 0;
  bool _loading = true;
  bool _mutating = false;
  bool _fromCache = false;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _request++;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var fromCache = false;
      var data = await ApiClient.observeReads(
        () => widget.load(_page, _query),
        (_) => fromCache = true,
      );
      if (request != _request || !mounted) return;
      if (data.isPaged && data.items.isEmpty && _page > 1) {
        _page = data.pageCount < _page ? data.pageCount : _page - 1;
        data = await widget.load(_page, _query);
      }
      if (request != _request || !mounted) return;
      setState(() {
        _data = data;
        _fromCache = fromCache;
        _page = data.page;
      });
    } on ApiFailure catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _freshLoad() => ApiClient.freshReads(_load);

  void _search(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    if (widget.serverSearch) {
      // Invalidate an older response immediately, before the debounce fires.
      _request++;
      _debounce = Timer(const Duration(milliseconds: 350), () {
        _page = 1;
        _load();
      });
    }
  }

  Future<void> _edit(T? item) async {
    final changed = item == null
        ? await widget.onCreate?.call()
        : await widget.onEdit?.call(item);
    if (changed == true && mounted) await _load();
  }

  Future<void> _open(T item) async {
    await widget.onOpen!(item);
    if (mounted) await _load();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã cập nhật dữ liệu.')));
        await _load();
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${error.message} Hãy làm mới danh sách trước khi thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(T item) async {
    final confirmed = await confirmCrudAction(
      context,
      title: 'Xác nhận xóa / hủy',
      message:
          'Bạn muốn xóa / hủy “${widget.nameOf(item)}”? Dữ liệu dùng chung với nhóm. Chỉ xác nhận với dữ liệu bạn được phép quản lý.',
      confirmLabel: 'Xóa / hủy',
    );
    if (confirmed && mounted) await _perform(() => widget.onDelete!(item));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final items =
        data?.items
            .where(
              (item) =>
                  widget.serverSearch ||
                  (widget.searchText?.call(item) ??
                          '${widget.nameOf(item)} ${widget.subtitleOf(item)}')
                      .toLowerCase()
                      .contains(_query.trim().toLowerCase()),
            )
            .toList() ??
        <T>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _loading || _mutating ? null : _freshLoad,
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: widget.onCreate == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _mutating ? null : () => _edit(null),
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _freshLoad,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TriSearchBar(
                        onChanged: _search,
                        hint: widget.serverSearch
                            ? 'Tìm tên, email hoặc mã nhân viên'
                            : data?.isPaged == false
                            ? 'Tìm trong danh sách'
                            : 'Tìm trong trang hiện tại',
                      ),
                      if (widget.filter != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: widget.filter!,
                        ),
                      const SizedBox(height: 16),
                      if (_loading || _mutating)
                        const LinearProgressIndicator(),
                      if (_data != null &&
                          (_loading || _fromCache || _error != null))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _loading
                                ? 'Đang cập nhật · vẫn hiển thị kết quả lần tải trước.'
                                : _error != null
                                ? 'Cập nhật thất bại · đây là dữ liệu lần tải trước.'
                                : 'Dữ liệu trong bộ nhớ (tối đa 60 giây).',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (_error != null)
                        CrudErrorState(message: _error!, onRetry: _freshLoad),
                      if (!_loading && _error == null && items.isEmpty)
                        CrudEmptyState(
                          message: _query.isEmpty
                              ? 'Chưa có dữ liệu.'
                              : 'Không tìm thấy kết quả phù hợp.',
                        )
                      else if (_data != null)
                        ...items.map(
                          (item) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      widget.nameOf(item),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(widget.subtitleOf(item)),
                                    isThreeLine: false,
                                    onTap: widget.onOpen == null || _mutating
                                        ? null
                                        : () => _open(item),
                                  ),
                                  if (widget.badge != null)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: widget.badge!(item),
                                    ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (widget.onOpen != null)
                                        TextButton(
                                          onPressed: _mutating
                                              ? null
                                              : () => _open(item),
                                          child: const Text('Chi tiết'),
                                        ),
                                      if (widget.onEdit != null &&
                                          (widget.canEdit?.call(item) ?? true))
                                        TextButton.icon(
                                          onPressed: _mutating
                                              ? null
                                              : () => _edit(item),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('Sửa'),
                                        ),
                                      if (widget.onDelete != null &&
                                          (widget.canDelete?.call(item) ??
                                              true))
                                        TextButton.icon(
                                          onPressed: _mutating
                                              ? null
                                              : () => _delete(item),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text('Xóa / hủy'),
                                        ),
                                      ...?widget.extraActions?.call(
                                        item,
                                        _mutating,
                                        _perform,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (data != null && data.isPaged)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Trang trước',
                                onPressed: _loading || _mutating || _page <= 1
                                    ? null
                                    : () {
                                        _page--;
                                        _load();
                                      },
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text(
                                'Trang ${data.page}/${data.pageCount} · ${data.total} bản ghi',
                              ),
                              IconButton(
                                tooltip: 'Trang sau',
                                onPressed:
                                    _loading || _mutating || !data.hasNext
                                    ? null
                                    : () {
                                        _page++;
                                        _load();
                                      },
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
