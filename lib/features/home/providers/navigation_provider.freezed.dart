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

 Book? get selectedBook; Unit? get selectedUnit; OtherContent? get selectedOtherContent; Topic? get selectedTopic;// ListeningContent? selectedListeningContent,
 PageContent? get selectedPage; FinalTopic? get selectedFinalTopic; FinalTopic? get selectedFinalTopicSearch; bool get isLoading;
/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NavigationStateCopyWith<NavigationState> get copyWith => _$NavigationStateCopyWithImpl<NavigationState>(this as NavigationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NavigationState&&(identical(other.selectedBook, selectedBook) || other.selectedBook == selectedBook)&&(identical(other.selectedUnit, selectedUnit) || other.selectedUnit == selectedUnit)&&(identical(other.selectedOtherContent, selectedOtherContent) || other.selectedOtherContent == selectedOtherContent)&&(identical(other.selectedTopic, selectedTopic) || other.selectedTopic == selectedTopic)&&(identical(other.selectedPage, selectedPage) || other.selectedPage == selectedPage)&&(identical(other.selectedFinalTopic, selectedFinalTopic) || other.selectedFinalTopic == selectedFinalTopic)&&(identical(other.selectedFinalTopicSearch, selectedFinalTopicSearch) || other.selectedFinalTopicSearch == selectedFinalTopicSearch)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading));
}


@override
int get hashCode => Object.hash(runtimeType,selectedBook,selectedUnit,selectedOtherContent,selectedTopic,selectedPage,selectedFinalTopic,selectedFinalTopicSearch,isLoading);

@override
String toString() {
  return 'NavigationState(selectedBook: $selectedBook, selectedUnit: $selectedUnit, selectedOtherContent: $selectedOtherContent, selectedTopic: $selectedTopic, selectedPage: $selectedPage, selectedFinalTopic: $selectedFinalTopic, selectedFinalTopicSearch: $selectedFinalTopicSearch, isLoading: $isLoading)';
}


}

/// @nodoc
abstract mixin class $NavigationStateCopyWith<$Res>  {
  factory $NavigationStateCopyWith(NavigationState value, $Res Function(NavigationState) _then) = _$NavigationStateCopyWithImpl;
@useResult
$Res call({
 Book? selectedBook, Unit? selectedUnit, OtherContent? selectedOtherContent, Topic? selectedTopic, PageContent? selectedPage, FinalTopic? selectedFinalTopic, FinalTopic? selectedFinalTopicSearch, bool isLoading
});


$BookCopyWith<$Res>? get selectedBook;$UnitCopyWith<$Res>? get selectedUnit;$OtherContentCopyWith<$Res>? get selectedOtherContent;$TopicCopyWith<$Res>? get selectedTopic;$PageContentCopyWith<$Res>? get selectedPage;$FinalTopicCopyWith<$Res>? get selectedFinalTopic;$FinalTopicCopyWith<$Res>? get selectedFinalTopicSearch;

}
/// @nodoc
class _$NavigationStateCopyWithImpl<$Res>
    implements $NavigationStateCopyWith<$Res> {
  _$NavigationStateCopyWithImpl(this._self, this._then);

  final NavigationState _self;
  final $Res Function(NavigationState) _then;

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedBook = freezed,Object? selectedUnit = freezed,Object? selectedOtherContent = freezed,Object? selectedTopic = freezed,Object? selectedPage = freezed,Object? selectedFinalTopic = freezed,Object? selectedFinalTopicSearch = freezed,Object? isLoading = null,}) {
  return _then(_self.copyWith(
selectedBook: freezed == selectedBook ? _self.selectedBook : selectedBook // ignore: cast_nullable_to_non_nullable
as Book?,selectedUnit: freezed == selectedUnit ? _self.selectedUnit : selectedUnit // ignore: cast_nullable_to_non_nullable
as Unit?,selectedOtherContent: freezed == selectedOtherContent ? _self.selectedOtherContent : selectedOtherContent // ignore: cast_nullable_to_non_nullable
as OtherContent?,selectedTopic: freezed == selectedTopic ? _self.selectedTopic : selectedTopic // ignore: cast_nullable_to_non_nullable
as Topic?,selectedPage: freezed == selectedPage ? _self.selectedPage : selectedPage // ignore: cast_nullable_to_non_nullable
as PageContent?,selectedFinalTopic: freezed == selectedFinalTopic ? _self.selectedFinalTopic : selectedFinalTopic // ignore: cast_nullable_to_non_nullable
as FinalTopic?,selectedFinalTopicSearch: freezed == selectedFinalTopicSearch ? _self.selectedFinalTopicSearch : selectedFinalTopicSearch // ignore: cast_nullable_to_non_nullable
as FinalTopic?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
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
$OtherContentCopyWith<$Res>? get selectedOtherContent {
    if (_self.selectedOtherContent == null) {
    return null;
  }

  return $OtherContentCopyWith<$Res>(_self.selectedOtherContent!, (value) {
    return _then(_self.copyWith(selectedOtherContent: value));
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
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FinalTopicCopyWith<$Res>? get selectedFinalTopicSearch {
    if (_self.selectedFinalTopicSearch == null) {
    return null;
  }

  return $FinalTopicCopyWith<$Res>(_self.selectedFinalTopicSearch!, (value) {
    return _then(_self.copyWith(selectedFinalTopicSearch: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Book? selectedBook,  Unit? selectedUnit,  OtherContent? selectedOtherContent,  Topic? selectedTopic,  PageContent? selectedPage,  FinalTopic? selectedFinalTopic,  FinalTopic? selectedFinalTopicSearch,  bool isLoading)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NavigationState() when $default != null:
return $default(_that.selectedBook,_that.selectedUnit,_that.selectedOtherContent,_that.selectedTopic,_that.selectedPage,_that.selectedFinalTopic,_that.selectedFinalTopicSearch,_that.isLoading);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Book? selectedBook,  Unit? selectedUnit,  OtherContent? selectedOtherContent,  Topic? selectedTopic,  PageContent? selectedPage,  FinalTopic? selectedFinalTopic,  FinalTopic? selectedFinalTopicSearch,  bool isLoading)  $default,) {final _that = this;
switch (_that) {
case _NavigationState():
return $default(_that.selectedBook,_that.selectedUnit,_that.selectedOtherContent,_that.selectedTopic,_that.selectedPage,_that.selectedFinalTopic,_that.selectedFinalTopicSearch,_that.isLoading);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Book? selectedBook,  Unit? selectedUnit,  OtherContent? selectedOtherContent,  Topic? selectedTopic,  PageContent? selectedPage,  FinalTopic? selectedFinalTopic,  FinalTopic? selectedFinalTopicSearch,  bool isLoading)?  $default,) {final _that = this;
switch (_that) {
case _NavigationState() when $default != null:
return $default(_that.selectedBook,_that.selectedUnit,_that.selectedOtherContent,_that.selectedTopic,_that.selectedPage,_that.selectedFinalTopic,_that.selectedFinalTopicSearch,_that.isLoading);case _:
  return null;

}
}

}

/// @nodoc


class _NavigationState implements NavigationState {
  const _NavigationState({this.selectedBook, this.selectedUnit, this.selectedOtherContent, this.selectedTopic, this.selectedPage, this.selectedFinalTopic, this.selectedFinalTopicSearch, this.isLoading = false});
  

@override final  Book? selectedBook;
@override final  Unit? selectedUnit;
@override final  OtherContent? selectedOtherContent;
@override final  Topic? selectedTopic;
// ListeningContent? selectedListeningContent,
@override final  PageContent? selectedPage;
@override final  FinalTopic? selectedFinalTopic;
@override final  FinalTopic? selectedFinalTopicSearch;
@override@JsonKey() final  bool isLoading;

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NavigationStateCopyWith<_NavigationState> get copyWith => __$NavigationStateCopyWithImpl<_NavigationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NavigationState&&(identical(other.selectedBook, selectedBook) || other.selectedBook == selectedBook)&&(identical(other.selectedUnit, selectedUnit) || other.selectedUnit == selectedUnit)&&(identical(other.selectedOtherContent, selectedOtherContent) || other.selectedOtherContent == selectedOtherContent)&&(identical(other.selectedTopic, selectedTopic) || other.selectedTopic == selectedTopic)&&(identical(other.selectedPage, selectedPage) || other.selectedPage == selectedPage)&&(identical(other.selectedFinalTopic, selectedFinalTopic) || other.selectedFinalTopic == selectedFinalTopic)&&(identical(other.selectedFinalTopicSearch, selectedFinalTopicSearch) || other.selectedFinalTopicSearch == selectedFinalTopicSearch)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading));
}


@override
int get hashCode => Object.hash(runtimeType,selectedBook,selectedUnit,selectedOtherContent,selectedTopic,selectedPage,selectedFinalTopic,selectedFinalTopicSearch,isLoading);

@override
String toString() {
  return 'NavigationState(selectedBook: $selectedBook, selectedUnit: $selectedUnit, selectedOtherContent: $selectedOtherContent, selectedTopic: $selectedTopic, selectedPage: $selectedPage, selectedFinalTopic: $selectedFinalTopic, selectedFinalTopicSearch: $selectedFinalTopicSearch, isLoading: $isLoading)';
}


}

/// @nodoc
abstract mixin class _$NavigationStateCopyWith<$Res> implements $NavigationStateCopyWith<$Res> {
  factory _$NavigationStateCopyWith(_NavigationState value, $Res Function(_NavigationState) _then) = __$NavigationStateCopyWithImpl;
@override @useResult
$Res call({
 Book? selectedBook, Unit? selectedUnit, OtherContent? selectedOtherContent, Topic? selectedTopic, PageContent? selectedPage, FinalTopic? selectedFinalTopic, FinalTopic? selectedFinalTopicSearch, bool isLoading
});


@override $BookCopyWith<$Res>? get selectedBook;@override $UnitCopyWith<$Res>? get selectedUnit;@override $OtherContentCopyWith<$Res>? get selectedOtherContent;@override $TopicCopyWith<$Res>? get selectedTopic;@override $PageContentCopyWith<$Res>? get selectedPage;@override $FinalTopicCopyWith<$Res>? get selectedFinalTopic;@override $FinalTopicCopyWith<$Res>? get selectedFinalTopicSearch;

}
/// @nodoc
class __$NavigationStateCopyWithImpl<$Res>
    implements _$NavigationStateCopyWith<$Res> {
  __$NavigationStateCopyWithImpl(this._self, this._then);

  final _NavigationState _self;
  final $Res Function(_NavigationState) _then;

/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedBook = freezed,Object? selectedUnit = freezed,Object? selectedOtherContent = freezed,Object? selectedTopic = freezed,Object? selectedPage = freezed,Object? selectedFinalTopic = freezed,Object? selectedFinalTopicSearch = freezed,Object? isLoading = null,}) {
  return _then(_NavigationState(
selectedBook: freezed == selectedBook ? _self.selectedBook : selectedBook // ignore: cast_nullable_to_non_nullable
as Book?,selectedUnit: freezed == selectedUnit ? _self.selectedUnit : selectedUnit // ignore: cast_nullable_to_non_nullable
as Unit?,selectedOtherContent: freezed == selectedOtherContent ? _self.selectedOtherContent : selectedOtherContent // ignore: cast_nullable_to_non_nullable
as OtherContent?,selectedTopic: freezed == selectedTopic ? _self.selectedTopic : selectedTopic // ignore: cast_nullable_to_non_nullable
as Topic?,selectedPage: freezed == selectedPage ? _self.selectedPage : selectedPage // ignore: cast_nullable_to_non_nullable
as PageContent?,selectedFinalTopic: freezed == selectedFinalTopic ? _self.selectedFinalTopic : selectedFinalTopic // ignore: cast_nullable_to_non_nullable
as FinalTopic?,selectedFinalTopicSearch: freezed == selectedFinalTopicSearch ? _self.selectedFinalTopicSearch : selectedFinalTopicSearch // ignore: cast_nullable_to_non_nullable
as FinalTopic?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
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
$OtherContentCopyWith<$Res>? get selectedOtherContent {
    if (_self.selectedOtherContent == null) {
    return null;
  }

  return $OtherContentCopyWith<$Res>(_self.selectedOtherContent!, (value) {
    return _then(_self.copyWith(selectedOtherContent: value));
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
}/// Create a copy of NavigationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FinalTopicCopyWith<$Res>? get selectedFinalTopicSearch {
    if (_self.selectedFinalTopicSearch == null) {
    return null;
  }

  return $FinalTopicCopyWith<$Res>(_self.selectedFinalTopicSearch!, (value) {
    return _then(_self.copyWith(selectedFinalTopicSearch: value));
  });
}
}

// dart format on
