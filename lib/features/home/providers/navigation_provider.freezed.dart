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

 Book? get selectedBook; Unit? get selectedUnit; Topic? get selectedTopic; PageContent? get selectedPage; FinalTopic? get selectedFinalTopic; List<TextSegmentEnglish>? get currentTextSegmentsEnglish; List<TextSegmentPersian>? get currentTextSegmentsPersian; List<TextSegmentPersian>? get currentNoteTextSegments; bool get isLoading;
/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NavigationStateCopyWith<NavigationState> get copyWith => _$NavigationStateCopyWithImpl<NavigationState>(this as NavigationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NavigationState&&(identical(other.selectedBook, selectedBook) || other.selectedBook == selectedBook)&&(identical(other.selectedUnit, selectedUnit) || other.selectedUnit == selectedUnit)&&(identical(other.selectedTopic, selectedTopic) || other.selectedTopic == selectedTopic)&&(identical(other.selectedPage, selectedPage) || other.selectedPage == selectedPage)&&(identical(other.selectedFinalTopic, selectedFinalTopic) || other.selectedFinalTopic == selectedFinalTopic)&&const DeepCollectionEquality().equals(other.currentTextSegmentsEnglish, currentTextSegmentsEnglish)&&const DeepCollectionEquality().equals(other.currentTextSegmentsPersian, currentTextSegmentsPersian)&&const DeepCollectionEquality().equals(other.currentNoteTextSegments, currentNoteTextSegments)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading));
}


@override
int get hashCode => Object.hash(runtimeType,selectedBook,selectedUnit,selectedTopic,selectedPage,selectedFinalTopic,const DeepCollectionEquality().hash(currentTextSegmentsEnglish),const DeepCollectionEquality().hash(currentTextSegmentsPersian),const DeepCollectionEquality().hash(currentNoteTextSegments),isLoading);

@override
String toString() {
  return 'NavigationState(selectedBook: $selectedBook, selectedUnit: $selectedUnit, selectedTopic: $selectedTopic, selectedPage: $selectedPage, selectedFinalTopic: $selectedFinalTopic, currentTextSegmentsEnglish: $currentTextSegmentsEnglish, currentTextSegmentsPersian: $currentTextSegmentsPersian, currentNoteTextSegments: $currentNoteTextSegments, isLoading: $isLoading)';
}


}

/// @nodoc
abstract mixin class $NavigationStateCopyWith<$Res>  {
  factory $NavigationStateCopyWith(NavigationState value, $Res Function(NavigationState) _then) = _$NavigationStateCopyWithImpl;
@useResult
$Res call({
 Book? selectedBook, Unit? selectedUnit, Topic? selectedTopic, PageContent? selectedPage, FinalTopic? selectedFinalTopic, List<TextSegmentEnglish>? currentTextSegmentsEnglish, List<TextSegmentPersian>? currentTextSegmentsPersian, List<TextSegmentPersian>? currentNoteTextSegments, bool isLoading
});


$BookCopyWith<$Res>? get selectedBook;$UnitCopyWith<$Res>? get selectedUnit;$TopicCopyWith<$Res>? get selectedTopic;$PageContentCopyWith<$Res>? get selectedPage;$FinalTopicCopyWith<$Res>? get selectedFinalTopic;

}
/// @nodoc
class _$NavigationStateCopyWithImpl<$Res>
    implements $NavigationStateCopyWith<$Res> {
  _$NavigationStateCopyWithImpl(this._self, this._then);

  final NavigationState _self;
  final $Res Function(NavigationState) _then;

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedBook = freezed,Object? selectedUnit = freezed,Object? selectedTopic = freezed,Object? selectedPage = freezed,Object? selectedFinalTopic = freezed,Object? currentTextSegmentsEnglish = freezed,Object? currentTextSegmentsPersian = freezed,Object? currentNoteTextSegments = freezed,Object? isLoading = null,}) {
  return _then(_self.copyWith(
selectedBook: freezed == selectedBook ? _self.selectedBook : selectedBook // ignore: cast_nullable_to_non_nullable
as Book?,selectedUnit: freezed == selectedUnit ? _self.selectedUnit : selectedUnit // ignore: cast_nullable_to_non_nullable
as Unit?,selectedTopic: freezed == selectedTopic ? _self.selectedTopic : selectedTopic // ignore: cast_nullable_to_non_nullable
as Topic?,selectedPage: freezed == selectedPage ? _self.selectedPage : selectedPage // ignore: cast_nullable_to_non_nullable
as PageContent?,selectedFinalTopic: freezed == selectedFinalTopic ? _self.selectedFinalTopic : selectedFinalTopic // ignore: cast_nullable_to_non_nullable
as FinalTopic?,currentTextSegmentsEnglish: freezed == currentTextSegmentsEnglish ? _self.currentTextSegmentsEnglish : currentTextSegmentsEnglish // ignore: cast_nullable_to_non_nullable
as List<TextSegmentEnglish>?,currentTextSegmentsPersian: freezed == currentTextSegmentsPersian ? _self.currentTextSegmentsPersian : currentTextSegmentsPersian // ignore: cast_nullable_to_non_nullable
as List<TextSegmentPersian>?,currentNoteTextSegments: freezed == currentNoteTextSegments ? _self.currentNoteTextSegments : currentNoteTextSegments // ignore: cast_nullable_to_non_nullable
as List<TextSegmentPersian>?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,
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
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FinalTopicCopyWith<$Res>? get selectedFinalTopic {
    if (_self.selectedFinalTopic == null) {
    return null;
  }

  return $FinalTopicCopyWith<$Res>(_self.selectedFinalTopic!, (value) {
    return _then(_self.copyWith(selectedFinalTopic: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Book? selectedBook,  Unit? selectedUnit,  Topic? selectedTopic,  PageContent? selectedPage,  FinalTopic? selectedFinalTopic,  List<TextSegmentEnglish>? currentTextSegmentsEnglish,  List<TextSegmentPersian>? currentTextSegmentsPersian,  List<TextSegmentPersian>? currentNoteTextSegments,  bool isLoading)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NavigationState() when $default != null:
return $default(_that.selectedBook,_that.selectedUnit,_that.selectedTopic,_that.selectedPage,_that.selectedFinalTopic,_that.currentTextSegmentsEnglish,_that.currentTextSegmentsPersian,_that.currentNoteTextSegments,_that.isLoading);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Book? selectedBook,  Unit? selectedUnit,  Topic? selectedTopic,  PageContent? selectedPage,  FinalTopic? selectedFinalTopic,  List<TextSegmentEnglish>? currentTextSegmentsEnglish,  List<TextSegmentPersian>? currentTextSegmentsPersian,  List<TextSegmentPersian>? currentNoteTextSegments,  bool isLoading)  $default,) {final _that = this;
switch (_that) {
case _NavigationState():
return $default(_that.selectedBook,_that.selectedUnit,_that.selectedTopic,_that.selectedPage,_that.selectedFinalTopic,_that.currentTextSegmentsEnglish,_that.currentTextSegmentsPersian,_that.currentNoteTextSegments,_that.isLoading);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Book? selectedBook,  Unit? selectedUnit,  Topic? selectedTopic,  PageContent? selectedPage,  FinalTopic? selectedFinalTopic,  List<TextSegmentEnglish>? currentTextSegmentsEnglish,  List<TextSegmentPersian>? currentTextSegmentsPersian,  List<TextSegmentPersian>? currentNoteTextSegments,  bool isLoading)?  $default,) {final _that = this;
switch (_that) {
case _NavigationState() when $default != null:
return $default(_that.selectedBook,_that.selectedUnit,_that.selectedTopic,_that.selectedPage,_that.selectedFinalTopic,_that.currentTextSegmentsEnglish,_that.currentTextSegmentsPersian,_that.currentNoteTextSegments,_that.isLoading);case _:
  return null;

}
}

}

/// @nodoc


class _NavigationState implements NavigationState {
  const _NavigationState({this.selectedBook, this.selectedUnit, this.selectedTopic, this.selectedPage, this.selectedFinalTopic, final  List<TextSegmentEnglish>? currentTextSegmentsEnglish, final  List<TextSegmentPersian>? currentTextSegmentsPersian, final  List<TextSegmentPersian>? currentNoteTextSegments, this.isLoading = false}): _currentTextSegmentsEnglish = currentTextSegmentsEnglish,_currentTextSegmentsPersian = currentTextSegmentsPersian,_currentNoteTextSegments = currentNoteTextSegments;
  

@override final  Book? selectedBook;
@override final  Unit? selectedUnit;
@override final  Topic? selectedTopic;
@override final  PageContent? selectedPage;
@override final  FinalTopic? selectedFinalTopic;
 final  List<TextSegmentEnglish>? _currentTextSegmentsEnglish;
@override List<TextSegmentEnglish>? get currentTextSegmentsEnglish {
  final value = _currentTextSegmentsEnglish;
  if (value == null) return null;
  if (_currentTextSegmentsEnglish is EqualUnmodifiableListView) return _currentTextSegmentsEnglish;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<TextSegmentPersian>? _currentTextSegmentsPersian;
@override List<TextSegmentPersian>? get currentTextSegmentsPersian {
  final value = _currentTextSegmentsPersian;
  if (value == null) return null;
  if (_currentTextSegmentsPersian is EqualUnmodifiableListView) return _currentTextSegmentsPersian;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<TextSegmentPersian>? _currentNoteTextSegments;
@override List<TextSegmentPersian>? get currentNoteTextSegments {
  final value = _currentNoteTextSegments;
  if (value == null) return null;
  if (_currentNoteTextSegments is EqualUnmodifiableListView) return _currentNoteTextSegments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  bool isLoading;

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NavigationStateCopyWith<_NavigationState> get copyWith => __$NavigationStateCopyWithImpl<_NavigationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NavigationState&&(identical(other.selectedBook, selectedBook) || other.selectedBook == selectedBook)&&(identical(other.selectedUnit, selectedUnit) || other.selectedUnit == selectedUnit)&&(identical(other.selectedTopic, selectedTopic) || other.selectedTopic == selectedTopic)&&(identical(other.selectedPage, selectedPage) || other.selectedPage == selectedPage)&&(identical(other.selectedFinalTopic, selectedFinalTopic) || other.selectedFinalTopic == selectedFinalTopic)&&const DeepCollectionEquality().equals(other._currentTextSegmentsEnglish, _currentTextSegmentsEnglish)&&const DeepCollectionEquality().equals(other._currentTextSegmentsPersian, _currentTextSegmentsPersian)&&const DeepCollectionEquality().equals(other._currentNoteTextSegments, _currentNoteTextSegments)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading));
}


@override
int get hashCode => Object.hash(runtimeType,selectedBook,selectedUnit,selectedTopic,selectedPage,selectedFinalTopic,const DeepCollectionEquality().hash(_currentTextSegmentsEnglish),const DeepCollectionEquality().hash(_currentTextSegmentsPersian),const DeepCollectionEquality().hash(_currentNoteTextSegments),isLoading);

@override
String toString() {
  return 'NavigationState(selectedBook: $selectedBook, selectedUnit: $selectedUnit, selectedTopic: $selectedTopic, selectedPage: $selectedPage, selectedFinalTopic: $selectedFinalTopic, currentTextSegmentsEnglish: $currentTextSegmentsEnglish, currentTextSegmentsPersian: $currentTextSegmentsPersian, currentNoteTextSegments: $currentNoteTextSegments, isLoading: $isLoading)';
}


}

/// @nodoc
abstract mixin class _$NavigationStateCopyWith<$Res> implements $NavigationStateCopyWith<$Res> {
  factory _$NavigationStateCopyWith(_NavigationState value, $Res Function(_NavigationState) _then) = __$NavigationStateCopyWithImpl;
@override @useResult
$Res call({
 Book? selectedBook, Unit? selectedUnit, Topic? selectedTopic, PageContent? selectedPage, FinalTopic? selectedFinalTopic, List<TextSegmentEnglish>? currentTextSegmentsEnglish, List<TextSegmentPersian>? currentTextSegmentsPersian, List<TextSegmentPersian>? currentNoteTextSegments, bool isLoading
});


@override $BookCopyWith<$Res>? get selectedBook;@override $UnitCopyWith<$Res>? get selectedUnit;@override $TopicCopyWith<$Res>? get selectedTopic;@override $PageContentCopyWith<$Res>? get selectedPage;@override $FinalTopicCopyWith<$Res>? get selectedFinalTopic;

}
/// @nodoc
class __$NavigationStateCopyWithImpl<$Res>
    implements _$NavigationStateCopyWith<$Res> {
  __$NavigationStateCopyWithImpl(this._self, this._then);

  final _NavigationState _self;
  final $Res Function(_NavigationState) _then;

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedBook = freezed,Object? selectedUnit = freezed,Object? selectedTopic = freezed,Object? selectedPage = freezed,Object? selectedFinalTopic = freezed,Object? currentTextSegmentsEnglish = freezed,Object? currentTextSegmentsPersian = freezed,Object? currentNoteTextSegments = freezed,Object? isLoading = null,}) {
  return _then(_NavigationState(
selectedBook: freezed == selectedBook ? _self.selectedBook : selectedBook // ignore: cast_nullable_to_non_nullable
as Book?,selectedUnit: freezed == selectedUnit ? _self.selectedUnit : selectedUnit // ignore: cast_nullable_to_non_nullable
as Unit?,selectedTopic: freezed == selectedTopic ? _self.selectedTopic : selectedTopic // ignore: cast_nullable_to_non_nullable
as Topic?,selectedPage: freezed == selectedPage ? _self.selectedPage : selectedPage // ignore: cast_nullable_to_non_nullable
as PageContent?,selectedFinalTopic: freezed == selectedFinalTopic ? _self.selectedFinalTopic : selectedFinalTopic // ignore: cast_nullable_to_non_nullable
as FinalTopic?,currentTextSegmentsEnglish: freezed == currentTextSegmentsEnglish ? _self._currentTextSegmentsEnglish : currentTextSegmentsEnglish // ignore: cast_nullable_to_non_nullable
as List<TextSegmentEnglish>?,currentTextSegmentsPersian: freezed == currentTextSegmentsPersian ? _self._currentTextSegmentsPersian : currentTextSegmentsPersian // ignore: cast_nullable_to_non_nullable
as List<TextSegmentPersian>?,currentNoteTextSegments: freezed == currentNoteTextSegments ? _self._currentNoteTextSegments : currentNoteTextSegments // ignore: cast_nullable_to_non_nullable
as List<TextSegmentPersian>?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,
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
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FinalTopicCopyWith<$Res>? get selectedFinalTopic {
    if (_self.selectedFinalTopic == null) {
    return null;
  }

  return $FinalTopicCopyWith<$Res>(_self.selectedFinalTopic!, (value) {
    return _then(_self.copyWith(selectedFinalTopic: value));
  });
}
}

// dart format on
