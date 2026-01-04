// lib/features/home/providers/drawer_expansion_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:get_storage/get_storage.dart';

part 'drawer_expansion_provider.g.dart';

@riverpod
class DrawerExpansion extends _$DrawerExpansion {
  final _box = GetStorage();
  final _bookKey = 'expanded_book';
  final _unitKey = 'expanded_unit';

  @override
  Map<String, String?> build() {
    return {'book': _box.read(_bookKey), 'unit': _box.read(_unitKey)};
  }

  void expandBook(String? bookName) {
    state = {...state, 'book': bookName};
    _box.write(_bookKey, bookName);
  }

  void expandUnit(String? unitName) {
    state = {...state, 'unit': unitName};
    _box.write(_unitKey, unitName);
  }
}
