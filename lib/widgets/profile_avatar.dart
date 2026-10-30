import 'dart:io';

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.path,
    this.radius = 38,
  });
  final String name;
  final String? path;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Center(
      child: Text(
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: radius * .75,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Semantics(
      label: 'Ảnh đại diện',
      image: true,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: ColoredBox(
            color: scheme.primary,
            child: path == null
                ? placeholder
                : Image.file(
                    File(path!),
                    fit: BoxFit.cover,
                    cacheWidth: (radius * 6).round(),
                    errorBuilder: (_, _, _) => placeholder,
                  ),
          ),
        ),
      ),
    );
  }
}
