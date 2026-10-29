import '../core/network/json_reader.dart';

class PagedResponse<T> {
  const PagedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    this.isPaged = true,
  });

  factory PagedResponse.fromJson(
    dynamic value,
    T Function(Map<String, dynamic>) decode,
  ) {
    final json = JsonReader.map(value);
    final total = JsonReader.integer(json['total']);
    final page = JsonReader.integer(json['page']);
    final size = JsonReader.integer(json['pageSize']);
    if (total < 0 || page < 1 || size < 1) JsonReader.invalid();
    return PagedResponse(
      items: JsonReader.list(json['items'], decode),
      total: total,
      page: page,
      pageSize: size,
    );
  }

  factory PagedResponse.unpaged(List<T> items) => PagedResponse(
    items: items,
    total: items.length,
    page: 1,
    pageSize: items.isEmpty ? 1 : items.length,
    isPaged: false,
  );

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final bool isPaged;
  bool get hasNext => page * pageSize < total;
  int get pageCount => total == 0 ? 1 : (total / pageSize).ceil();
}
