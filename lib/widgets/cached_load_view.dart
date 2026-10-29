import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/api_config.dart';
import '../core/network/api_failure.dart';
import '../core/network/api_client.dart';

class LoadSnapshot<T> {
  const LoadSnapshot({this.data, this.error, required this.loading});
  final T? data;
  final Object? error;
  final bool loading;
  bool get hasData => data != null;
  bool get hasError => error != null;
  ConnectionState get connectionState =>
      loading ? ConnectionState.waiting : ConnectionState.done;
}

/// Keeps the last successful value while refreshing. Authentication failures
/// discard it. No timer, retry loop or write request is started by this widget.
class CachedLoadView<T> extends StatefulWidget {
  const CachedLoadView({
    super.key,
    required this.load,
    required this.builder,
    this.cached,
    this.active = true,
    this.dataKey,
    this.expand = false,
  });
  final Future<T> Function(bool forceRefresh) load;
  final T? Function()? cached;
  final Widget Function(BuildContext, LoadSnapshot<T>) builder;
  final bool active;
  final Object? dataKey;
  final bool expand;
  @override
  State<CachedLoadView<T>> createState() => CachedLoadViewState<T>();
}

class CachedLoadViewState<T> extends State<CachedLoadView<T>> {
  T? _data;
  Object? _error;
  bool _loading = false;
  bool _fromCache = false;
  DateTime? _loadedAt;
  int _generation = 0;
  Future<void>? _operation;
  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  void _initialLoad() {
    _loading = false;
    _loadedAt = null;
    try {
      _data = widget.cached?.call();
    } catch (_) {
      _data = null;
    }
    _fromCache = _data != null;
    if (_data != null) {
      _loadedAt = DateTime.now();
    } else {
      unawaited(_load(false));
    }
  }

  @override
  void didUpdateWidget(covariant CachedLoadView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataKey != widget.dataKey) {
      _generation++;
      _operation = null;
      _data = null;
      _error = null;
      _initialLoad();
    } else if (!oldWidget.active &&
        widget.active &&
        (_loadedAt == null ||
            DateTime.now().difference(_loadedAt!) >= ApiConfig.cacheLifetime ||
            (widget.cached != null && !_hasCache()))) {
      unawaited(_load(false));
    }
  }

  bool _hasCache() {
    try {
      return widget.cached?.call() != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh() => _load(true);
  Future<void> _load(bool force) {
    final pending = _operation;
    if (pending != null) return pending;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    final operation = () async {
      try {
        DateTime? cachedAt;
        final value = await ApiClient.observeReads(() => widget.load(force), (
          at,
        ) {
          if (cachedAt == null || at.isBefore(cachedAt!)) cachedAt = at;
        }).timeout(const Duration(seconds: 25));
        if (!mounted || generation != _generation) return;
        setState(() {
          _data = value;
          _fromCache = cachedAt != null;
          _loadedAt = cachedAt ?? DateTime.now();
        });
      } catch (error) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _error = error is ApiFailure
              ? error
              : const ApiFailure(
                  'Tải dữ liệu quá thời gian chờ hoặc gặp lỗi. Vui lòng thử lại.',
                );
          if (error is ApiFailure && error.isUnauthorized) _data = null;
        });
      } finally {
        if (mounted && generation == _generation) {
          setState(() => _loading = false);
        }
      }
    }();
    _operation = operation;
    return operation.whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.builder(
      context,
      LoadSnapshot(data: _data, error: _error, loading: _loading),
    );
    final notices = <Widget>[
      if (_data != null && (_loading || _fromCache || _error != null))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading) const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(
                _loading
                    ? 'Đang cập nhật · vẫn hiển thị dữ liệu đã tải.'
                    : _error != null
                    ? 'Cập nhật thất bại · dữ liệu hiển thị là lần tải trước.'
                    : 'Dữ liệu trong bộ nhớ (tối đa 60 giây).',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF63738A)),
              ),
              if (_error != null)
                TextButton(onPressed: refresh, child: const Text('Thử lại')),
              if (_error is ApiFailure)
                Text(
                  (_error as ApiFailure).message,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        ...notices,
        if (widget.expand) Expanded(child: content) else content,
      ],
    );
  }
}
