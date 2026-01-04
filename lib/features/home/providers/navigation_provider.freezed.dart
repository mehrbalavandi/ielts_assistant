// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'navigation_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NavigationState {

 Book? get selectedBook; Unit? get selectedUnit; Topic? get selectedTopic; PageContent? get selectedPage;
/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NavigationStateCopyWith<NavigationState> get copyWith => _$NavigationStateCopyWithImpl<NavigationState>(this as NavigationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NavigationState&&(identical(other.selectedBook, selectedBook) || other.selectedBook == selectedBook)&&(identical(other.selectedUnit, selectedUnit) || other.selectedUnit == selectedUnit)&&(identical(other.selectedTopic, selectedTopic) || other.selectedTopic == selectedTopic)&&(identical(other.selectedPage, selectedPage) || other.selectedPage == selectedPage));
}


@override
int get hashCode => Object.hash(runtimeType,selectedBook,selectedUnit,selectedTopic,selectedPage);

@override
String toString() {
  return 'NavigationState(selectedBook: $selectedBook, selectedUnit: $selectedUnit, selectedTopic: $selectedTopic, selectedPage: $selectedPage)';
}


}

/// @nodoc
abstract mixin class $NavigationStateCopyWith<$Res>  {
  factory $NavigationStateCopyWith(NavigationState value, $Res Function(NavigationState) _then) = _$NavigationStateCopyWithImpl;
@useResult
$Res call({
 Book? selectedBook, Unit? selectedUnit, Topic? selectedTopic, PageContent? selectedPage
});


$BookCopyWith<$Res>? get selectedBook;$UnitCopyWith<$Res>? get selectedUnit;$TopicCopyWith<$Res>? get selectedTopic;$PageContentCopyWith<$Res>? get selectedPage;

}
/// @nodoc
class _$NavigationStateCopyWithImpl<$Res>
    implements $NavigationStateCopyWith<$Res> {
  _$NavigationStateCopyWithImpl(this._self, this._then);

  final NavigationState _self;
  final $Res Function(NavigationState) _then;

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedBook = freezed,Object? selectedUnit = freezed,Object? selectedTopic = freezed,Object? selectedPage = freezed,}) {
  return _then(_self.copyWith(
selectedBook: freezed == selectedBook ? _self.selectedBook : selectedBook // ignore: cast_nullable_to_non_nullable
as Book?,selectedUnit: freezed == selectedUnit ? _self.selectedUnit : selectedUnit // ignore: cast_nullable_to_non_nullable
as Unit?,selectedTopic: freezed == selectedTopic ? _self.selectedTopic : selectedTopic // ignore: cast_nullable_to_non_nullable
as Topic?,selectedPage: freezed == selectedPage ? _self.selectedPage : selectedPage // ignore: cast_nullable_to_non_nullable
as PageContent?,
  ));
}
/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookCopyWith<$Res>? get selectedBook {
    if (_self.selectedBook == null) {
    return null;
  }

  return $BookCopyWith<$Res>(_self.selectedBook!, (value) {
    return _then(_self.copyWith(selectedBook: value));
  });
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UnitCopyWith<$Res>? get selectedUnit {
    if (_self.selectedUnit == null) {
    return null;
  }

  return $UnitCopyWith<$Res>(_self.selectedUnit!, (value) {
    return _then(_self.copyWith(selectedUnit: value));
  });
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TopicCopyWith<$Res>? get selectedTopic {
    if (_self.selectedTopic == null) {
    return null;
  }

  return $TopicCopyWith<$Res>(_self.selectedTopic!, (value) {
    return _then(_self.copyWith(selectedTopic: value));
  });
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageContentCopyWith<$Res>? get selectedPage {
    if (_self.selectedPage == null) {
    return null;
  }

  return $PageContentCopyWith<$Res>(_self.selectedPage!, (value) {
    return _then(_self.copyWith(selectedPage: value));
  });
}
}


/// Adds pattern-matching-related methods to [NavigationState].
extension NavigationStatePatterns on NavigationState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NavigationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NavigationState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NavigationState value)  $default,){
final _that = this;
switch (_that) {
case _NavigationState():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NavigationState value)?  $default,){
final _that = this;
switch (_that) {
case _NavigationState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Book? selectedBook,  Unit? selectedUnit,  Topic? selectedTopic,  PageContent? selectedPage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NavigationState() when $default != null:
return $default(_that.selectedBook,_that.selectedUnit,_that.selectedTopic,_that.selectedPage);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Book? selectedBook,  Unit? selectedUnit,  Topic? selectedTopic,  PageContent? selectedPage)  $default,) {final _that = this;
switch (_that) {
case _NavigationState():
return $default(_that.selectedBook,_that.selectedUnit,_that.selectedTopic,_that.selectedPage);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Book? selectedBook,  Unit? selectedUnit,  Topic? selectedTopic,  PageContent? selectedPage)?  $default,) {final _that = this;
switch (_that) {
case _NavigationState() when $default != null:
return $default(_that.selectedBook,_that.selectedUnit,_that.selectedTopic,_that.selectedPage);case _:
  return null;

}
}

}

/// @nodoc


class _NavigationState implements NavigationState {
  const _NavigationState({this.selectedBook, this.selectedUnit, this.selectedTopic, this.selectedPage});
  

@override final  Book? selectedBook;
@override final  Unit? selectedUnit;
@override final  Topic? selectedTopic;
@override final  PageContent? selectedPage;

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NavigationStateCopyWith<_NavigationState> get copyWith => __$NavigationStateCopyWithImpl<_NavigationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NavigationState&&(identical(other.selectedBook, selectedBook) || other.selectedBook == selectedBook)&&(identical(other.selectedUnit, selectedUnit) || other.selectedUnit == selectedUnit)&&(identical(other.selectedTopic, selectedTopic) || other.selectedTopic == selectedTopic)&&(identical(other.selectedPage, selectedPage) || other.selectedPage == selectedPage));
}


@override
int get hashCode => Object.hash(runtimeType,selectedBook,selectedUnit,selectedTopic,selectedPage);

@override
String toString() {
  return 'NavigationState(selectedBook: $selectedBook, selectedUnit: $selectedUnit, selectedTopic: $selectedTopic, selectedPage: $selectedPage)';
}


}

/// @nodoc
abstract mixin class _$NavigationStateCopyWith<$Res> implements $NavigationStateCopyWith<$Res> {
  factory _$NavigationStateCopyWith(_NavigationState value, $Res Function(_NavigationState) _then) = __$NavigationStateCopyWithImpl;
@override @useResult
$Res call({
 Book? selectedBook, Unit? selectedUnit, Topic? selectedTopic, PageContent? selectedPage
});


@override $BookCopyWith<$Res>? get selectedBook;@override $UnitCopyWith<$Res>? get selectedUnit;@override $TopicCopyWith<$Res>? get selectedTopic;@override $PageContentCopyWith<$Res>? get selectedPage;

}
/// @nodoc
class __$NavigationStateCopyWithImpl<$Res>
    implements _$NavigationStateCopyWith<$Res> {
  __$NavigationStateCopyWithImpl(this._self, this._then);

  final _NavigationState _self;
  final $Res Function(_NavigationState) _then;

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedBook = freezed,Object? selectedUnit = freezed,Object? selectedTopic = freezed,Object? selectedPage = freezed,}) {
  return _then(_NavigationState(
selectedBook: freezed == selectedBook ? _self.selectedBook : selectedBook // ignore: cast_nullable_to_non_nullable
as Book?,selectedUnit: freezed == selectedUnit ? _self.selectedUnit : selectedUnit // ignore: cast_nullable_to_non_nullable
as Unit?,selectedTopic: freezed == selectedTopic ? _self.selectedTopic : selectedTopic // ignore: cast_nullable_to_non_nullable
as Topic?,selectedPage: freezed == selectedPage ? _self.selectedPage : selectedPage // ignore: cast_nullable_to_non_nullable
as PageContent?,
  ));
}

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookCopyWith<$Res>? get selectedBook {
    if (_self.selectedBook == null) {
    return null;
  }

  return $BookCopyWith<$Res>(_self.selectedBook!, (value) {
    return _then(_self.copyWith(selectedBook: value));
  });
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UnitCopyWith<$Res>? get selectedUnit {
    if (_self.selectedUnit == null) {
    return null;
  }

  return $UnitCopyWith<$Res>(_self.selectedUnit!, (value) {
    return _then(_self.copyWith(selectedUnit: value));
  });
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TopicCopyWith<$Res>? get selectedTopic {
    if (_self.selectedTopic == null) {
    return null;
  }

  return $TopicCopyWith<$Res>(_self.selectedTopic!, (value) {
    return _then(_self.copyWith(selectedTopic: value));
  });
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageContentCopyWith<$Res>? get selectedPage {
    if (_self.selectedPage == null) {
    return null;
  }

  return $PageContentCopyWith<$Res>(_self.selectedPage!, (value) {
    return _then(_self.copyWith(selectedPage: value));
  });
}
}

// dart format on
