import '../core/network/json_reader.dart';

class DepartmentModel {
  const DepartmentModel({
    required this.id,
    required this.name,
    this.description,
  });
  final int id;
  final String name;
  final String? description;
  factory DepartmentModel.fromJson(Map<String, dynamic> j) => DepartmentModel(
    id: JsonReader.integer(j['id']),
    name: JsonReader.string(j['name']),
    description: JsonReader.optionalString(j['description']),
  );
}

class DepartmentInput {
  const DepartmentInput({required this.name, this.description});
  final String name;
  final String? description;
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'description': description?.trim(),
  };
}
