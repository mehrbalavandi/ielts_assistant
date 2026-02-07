// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'content_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StudyContent {

 List<Book> get books;
/// Create a copy of StudyContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudyContentCopyWith<StudyContent> get copyWith => _$StudyContentCopyWithImpl<StudyContent>(this as StudyContent, _$identity);

  /// Serializes this StudyContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudyContent&&const DeepCollectionEquality().equals(other.books, books));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(books));

@override
String toString() {
  return 'StudyContent(books: $books)';
}


}

/// @nodoc
abstract mixin class $StudyContentCopyWith<$Res>  {
  factory $StudyContentCopyWith(StudyContent value, $Res Function(StudyContent) _then) = _$StudyContentCopyWithImpl;
@useResult
$Res call({
 List<Book> books
});




}
/// @nodoc
class _$StudyContentCopyWithImpl<$Res>
    implements $StudyContentCopyWith<$Res> {
  _$StudyContentCopyWithImpl(this._self, this._then);

  final StudyContent _self;
  final $Res Function(StudyContent) _then;

/// Create a copy of StudyContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? books = null,}) {
  return _then(_self.copyWith(
books: null == books ? _self.books : books // ignore: cast_nullable_to_non_nullable
as List<Book>,
  ));
}

}


/// Adds pattern-matching-related methods to [StudyContent].
extension StudyContentPatterns on StudyContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudyContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudyContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudyContent value)  $default,){
final _that = this;
switch (_that) {
case _StudyContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudyContent value)?  $default,){
final _that = this;
switch (_that) {
case _StudyContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Book> books)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudyContent() when $default != null:
return $default(_that.books);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Book> books)  $default,) {final _that = this;
switch (_that) {
case _StudyContent():
return $default(_that.books);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Book> books)?  $default,) {final _that = this;
switch (_that) {
case _StudyContent() when $default != null:
return $default(_that.books);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudyContent implements StudyContent {
  const _StudyContent({required final  List<Book> books}): _books = books;
  factory _StudyContent.fromJson(Map<String, dynamic> json) => _$StudyContentFromJson(json);

 final  List<Book> _books;
@override List<Book> get books {
  if (_books is EqualUnmodifiableListView) return _books;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_books);
}


/// Create a copy of StudyContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudyContentCopyWith<_StudyContent> get copyWith => __$StudyContentCopyWithImpl<_StudyContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudyContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudyContent&&const DeepCollectionEquality().equals(other._books, _books));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_books));

@override
String toString() {
  return 'StudyContent(books: $books)';
}


}

/// @nodoc
abstract mixin class _$StudyContentCopyWith<$Res> implements $StudyContentCopyWith<$Res> {
  factory _$StudyContentCopyWith(_StudyContent value, $Res Function(_StudyContent) _then) = __$StudyContentCopyWithImpl;
@override @useResult
$Res call({
 List<Book> books
});




}
/// @nodoc
class __$StudyContentCopyWithImpl<$Res>
    implements _$StudyContentCopyWith<$Res> {
  __$StudyContentCopyWithImpl(this._self, this._then);

  final _StudyContent _self;
  final $Res Function(_StudyContent) _then;

/// Create a copy of StudyContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? books = null,}) {
  return _then(_StudyContent(
books: null == books ? _self._books : books // ignore: cast_nullable_to_non_nullable
as List<Book>,
  ));
}


}


/// @nodoc
mixin _$Book {

 String get name; List<Unit> get units;
/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookCopyWith<Book> get copyWith => _$BookCopyWithImpl<Book>(this as Book, _$identity);

  /// Serializes this Book to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Book&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.units, units));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(units));

@override
String toString() {
  return 'Book(name: $name, units: $units)';
}


}

/// @nodoc
abstract mixin class $BookCopyWith<$Res>  {
  factory $BookCopyWith(Book value, $Res Function(Book) _then) = _$BookCopyWithImpl;
@useResult
$Res call({
 String name, List<Unit> units
});




}
/// @nodoc
class _$BookCopyWithImpl<$Res>
    implements $BookCopyWith<$Res> {
  _$BookCopyWithImpl(this._self, this._then);

  final Book _self;
  final $Res Function(Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? units = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,units: null == units ? _self.units : units // ignore: cast_nullable_to_non_nullable
as List<Unit>,
  ));
}

}


/// Adds pattern-matching-related methods to [Book].
extension BookPatterns on Book {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Book value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Book value)  $default,){
final _that = this;
switch (_that) {
case _Book():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Book value)?  $default,){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  List<Unit> units)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.name,_that.units);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  List<Unit> units)  $default,) {final _that = this;
switch (_that) {
case _Book():
return $default(_that.name,_that.units);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  List<Unit> units)?  $default,) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.name,_that.units);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Book implements Book {
  const _Book({required this.name, required final  List<Unit> units}): _units = units;
  factory _Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);

@override final  String name;
 final  List<Unit> _units;
@override List<Unit> get units {
  if (_units is EqualUnmodifiableListView) return _units;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_units);
}


/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookCopyWith<_Book> get copyWith => __$BookCopyWithImpl<_Book>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Book&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._units, _units));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_units));

@override
String toString() {
  return 'Book(name: $name, units: $units)';
}


}

/// @nodoc
abstract mixin class _$BookCopyWith<$Res> implements $BookCopyWith<$Res> {
  factory _$BookCopyWith(_Book value, $Res Function(_Book) _then) = __$BookCopyWithImpl;
@override @useResult
$Res call({
 String name, List<Unit> units
});




}
/// @nodoc
class __$BookCopyWithImpl<$Res>
    implements _$BookCopyWith<$Res> {
  __$BookCopyWithImpl(this._self, this._then);

  final _Book _self;
  final $Res Function(_Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? units = null,}) {
  return _then(_Book(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,units: null == units ? _self._units : units // ignore: cast_nullable_to_non_nullable
as List<Unit>,
  ));
}


}


/// @nodoc
mixin _$Unit {

 String get name; List<Topic> get topics; List<OtherContent>? get otherContents;
/// Create a copy of Unit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnitCopyWith<Unit> get copyWith => _$UnitCopyWithImpl<Unit>(this as Unit, _$identity);

  /// Serializes this Unit to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Unit&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.topics, topics)&&const DeepCollectionEquality().equals(other.otherContents, otherContents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(topics),const DeepCollectionEquality().hash(otherContents));

@override
String toString() {
  return 'Unit(name: $name, topics: $topics, otherContents: $otherContents)';
}


}

/// @nodoc
abstract mixin class $UnitCopyWith<$Res>  {
  factory $UnitCopyWith(Unit value, $Res Function(Unit) _then) = _$UnitCopyWithImpl;
@useResult
$Res call({
 String name, List<Topic> topics, List<OtherContent>? otherContents
});




}
/// @nodoc
class _$UnitCopyWithImpl<$Res>
    implements $UnitCopyWith<$Res> {
  _$UnitCopyWithImpl(this._self, this._then);

  final Unit _self;
  final $Res Function(Unit) _then;

/// Create a copy of Unit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? topics = null,Object? otherContents = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,topics: null == topics ? _self.topics : topics // ignore: cast_nullable_to_non_nullable
as List<Topic>,otherContents: freezed == otherContents ? _self.otherContents : otherContents // ignore: cast_nullable_to_non_nullable
as List<OtherContent>?,
  ));
}

}


/// Adds pattern-matching-related methods to [Unit].
extension UnitPatterns on Unit {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Unit value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Unit() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Unit value)  $default,){
final _that = this;
switch (_that) {
case _Unit():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Unit value)?  $default,){
final _that = this;
switch (_that) {
case _Unit() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  List<Topic> topics,  List<OtherContent>? otherContents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Unit() when $default != null:
return $default(_that.name,_that.topics,_that.otherContents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  List<Topic> topics,  List<OtherContent>? otherContents)  $default,) {final _that = this;
switch (_that) {
case _Unit():
return $default(_that.name,_that.topics,_that.otherContents);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  List<Topic> topics,  List<OtherContent>? otherContents)?  $default,) {final _that = this;
switch (_that) {
case _Unit() when $default != null:
return $default(_that.name,_that.topics,_that.otherContents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Unit implements Unit {
  const _Unit({required this.name, required final  List<Topic> topics, required final  List<OtherContent>? otherContents}): _topics = topics,_otherContents = otherContents;
  factory _Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);

@override final  String name;
 final  List<Topic> _topics;
@override List<Topic> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}

 final  List<OtherContent>? _otherContents;
@override List<OtherContent>? get otherContents {
  final value = _otherContents;
  if (value == null) return null;
  if (_otherContents is EqualUnmodifiableListView) return _otherContents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of Unit
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnitCopyWith<_Unit> get copyWith => __$UnitCopyWithImpl<_Unit>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnitToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Unit&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._topics, _topics)&&const DeepCollectionEquality().equals(other._otherContents, _otherContents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_topics),const DeepCollectionEquality().hash(_otherContents));

@override
String toString() {
  return 'Unit(name: $name, topics: $topics, otherContents: $otherContents)';
}


}

/// @nodoc
abstract mixin class _$UnitCopyWith<$Res> implements $UnitCopyWith<$Res> {
  factory _$UnitCopyWith(_Unit value, $Res Function(_Unit) _then) = __$UnitCopyWithImpl;
@override @useResult
$Res call({
 String name, List<Topic> topics, List<OtherContent>? otherContents
});




}
/// @nodoc
class __$UnitCopyWithImpl<$Res>
    implements _$UnitCopyWith<$Res> {
  __$UnitCopyWithImpl(this._self, this._then);

  final _Unit _self;
  final $Res Function(_Unit) _then;

/// Create a copy of Unit
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? topics = null,Object? otherContents = freezed,}) {
  return _then(_Unit(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<Topic>,otherContents: freezed == otherContents ? _self._otherContents : otherContents // ignore: cast_nullable_to_non_nullable
as List<OtherContent>?,
  ));
}


}


/// @nodoc
mixin _$Topic {

 String get name; String get realmId; List<PageContent> get pageContents;
/// Create a copy of Topic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopicCopyWith<Topic> get copyWith => _$TopicCopyWithImpl<Topic>(this as Topic, _$identity);

  /// Serializes this Topic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Topic&&(identical(other.name, name) || other.name == name)&&(identical(other.realmId, realmId) || other.realmId == realmId)&&const DeepCollectionEquality().equals(other.pageContents, pageContents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,realmId,const DeepCollectionEquality().hash(pageContents));

@override
String toString() {
  return 'Topic(name: $name, realmId: $realmId, pageContents: $pageContents)';
}


}

/// @nodoc
abstract mixin class $TopicCopyWith<$Res>  {
  factory $TopicCopyWith(Topic value, $Res Function(Topic) _then) = _$TopicCopyWithImpl;
@useResult
$Res call({
 String name, String realmId, List<PageContent> pageContents
});




}
/// @nodoc
class _$TopicCopyWithImpl<$Res>
    implements $TopicCopyWith<$Res> {
  _$TopicCopyWithImpl(this._self, this._then);

  final Topic _self;
  final $Res Function(Topic) _then;

/// Create a copy of Topic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? realmId = null,Object? pageContents = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,realmId: null == realmId ? _self.realmId : realmId // ignore: cast_nullable_to_non_nullable
as String,pageContents: null == pageContents ? _self.pageContents : pageContents // ignore: cast_nullable_to_non_nullable
as List<PageContent>,
  ));
}

}


/// Adds pattern-matching-related methods to [Topic].
extension TopicPatterns on Topic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Topic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Topic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Topic value)  $default,){
final _that = this;
switch (_that) {
case _Topic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Topic value)?  $default,){
final _that = this;
switch (_that) {
case _Topic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String realmId,  List<PageContent> pageContents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Topic() when $default != null:
return $default(_that.name,_that.realmId,_that.pageContents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String realmId,  List<PageContent> pageContents)  $default,) {final _that = this;
switch (_that) {
case _Topic():
return $default(_that.name,_that.realmId,_that.pageContents);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String realmId,  List<PageContent> pageContents)?  $default,) {final _that = this;
switch (_that) {
case _Topic() when $default != null:
return $default(_that.name,_that.realmId,_that.pageContents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Topic implements Topic {
  const _Topic({required this.name, required this.realmId, required final  List<PageContent> pageContents}): _pageContents = pageContents;
  factory _Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);

@override final  String name;
@override final  String realmId;
 final  List<PageContent> _pageContents;
@override List<PageContent> get pageContents {
  if (_pageContents is EqualUnmodifiableListView) return _pageContents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pageContents);
}


/// Create a copy of Topic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopicCopyWith<_Topic> get copyWith => __$TopicCopyWithImpl<_Topic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Topic&&(identical(other.name, name) || other.name == name)&&(identical(other.realmId, realmId) || other.realmId == realmId)&&const DeepCollectionEquality().equals(other._pageContents, _pageContents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,realmId,const DeepCollectionEquality().hash(_pageContents));

@override
String toString() {
  return 'Topic(name: $name, realmId: $realmId, pageContents: $pageContents)';
}


}

/// @nodoc
abstract mixin class _$TopicCopyWith<$Res> implements $TopicCopyWith<$Res> {
  factory _$TopicCopyWith(_Topic value, $Res Function(_Topic) _then) = __$TopicCopyWithImpl;
@override @useResult
$Res call({
 String name, String realmId, List<PageContent> pageContents
});




}
/// @nodoc
class __$TopicCopyWithImpl<$Res>
    implements _$TopicCopyWith<$Res> {
  __$TopicCopyWithImpl(this._self, this._then);

  final _Topic _self;
  final $Res Function(_Topic) _then;

/// Create a copy of Topic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? realmId = null,Object? pageContents = null,}) {
  return _then(_Topic(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,realmId: null == realmId ? _self.realmId : realmId // ignore: cast_nullable_to_non_nullable
as String,pageContents: null == pageContents ? _self._pageContents : pageContents // ignore: cast_nullable_to_non_nullable
as List<PageContent>,
  ));
}


}


/// @nodoc
mixin _$PageContent {

 String get name; String get realmId; List<FinalTopic> get finalTopics;
/// Create a copy of PageContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PageContentCopyWith<PageContent> get copyWith => _$PageContentCopyWithImpl<PageContent>(this as PageContent, _$identity);

  /// Serializes this PageContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageContent&&(identical(other.name, name) || other.name == name)&&(identical(other.realmId, realmId) || other.realmId == realmId)&&const DeepCollectionEquality().equals(other.finalTopics, finalTopics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,realmId,const DeepCollectionEquality().hash(finalTopics));

@override
String toString() {
  return 'PageContent(name: $name, realmId: $realmId, finalTopics: $finalTopics)';
}


}

/// @nodoc
abstract mixin class $PageContentCopyWith<$Res>  {
  factory $PageContentCopyWith(PageContent value, $Res Function(PageContent) _then) = _$PageContentCopyWithImpl;
@useResult
$Res call({
 String name, String realmId, List<FinalTopic> finalTopics
});




}
/// @nodoc
class _$PageContentCopyWithImpl<$Res>
    implements $PageContentCopyWith<$Res> {
  _$PageContentCopyWithImpl(this._self, this._then);

  final PageContent _self;
  final $Res Function(PageContent) _then;

/// Create a copy of PageContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? realmId = null,Object? finalTopics = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,realmId: null == realmId ? _self.realmId : realmId // ignore: cast_nullable_to_non_nullable
as String,finalTopics: null == finalTopics ? _self.finalTopics : finalTopics // ignore: cast_nullable_to_non_nullable
as List<FinalTopic>,
  ));
}

}


/// Adds pattern-matching-related methods to [PageContent].
extension PageContentPatterns on PageContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PageContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PageContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PageContent value)  $default,){
final _that = this;
switch (_that) {
case _PageContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PageContent value)?  $default,){
final _that = this;
switch (_that) {
case _PageContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String realmId,  List<FinalTopic> finalTopics)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PageContent() when $default != null:
return $default(_that.name,_that.realmId,_that.finalTopics);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String realmId,  List<FinalTopic> finalTopics)  $default,) {final _that = this;
switch (_that) {
case _PageContent():
return $default(_that.name,_that.realmId,_that.finalTopics);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String realmId,  List<FinalTopic> finalTopics)?  $default,) {final _that = this;
switch (_that) {
case _PageContent() when $default != null:
return $default(_that.name,_that.realmId,_that.finalTopics);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PageContent implements PageContent {
  const _PageContent({required this.name, required this.realmId, required final  List<FinalTopic> finalTopics}): _finalTopics = finalTopics;
  factory _PageContent.fromJson(Map<String, dynamic> json) => _$PageContentFromJson(json);

@override final  String name;
@override final  String realmId;
 final  List<FinalTopic> _finalTopics;
@override List<FinalTopic> get finalTopics {
  if (_finalTopics is EqualUnmodifiableListView) return _finalTopics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_finalTopics);
}


/// Create a copy of PageContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PageContentCopyWith<_PageContent> get copyWith => __$PageContentCopyWithImpl<_PageContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PageContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageContent&&(identical(other.name, name) || other.name == name)&&(identical(other.realmId, realmId) || other.realmId == realmId)&&const DeepCollectionEquality().equals(other._finalTopics, _finalTopics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,realmId,const DeepCollectionEquality().hash(_finalTopics));

@override
String toString() {
  return 'PageContent(name: $name, realmId: $realmId, finalTopics: $finalTopics)';
}


}

/// @nodoc
abstract mixin class _$PageContentCopyWith<$Res> implements $PageContentCopyWith<$Res> {
  factory _$PageContentCopyWith(_PageContent value, $Res Function(_PageContent) _then) = __$PageContentCopyWithImpl;
@override @useResult
$Res call({
 String name, String realmId, List<FinalTopic> finalTopics
});




}
/// @nodoc
class __$PageContentCopyWithImpl<$Res>
    implements _$PageContentCopyWith<$Res> {
  __$PageContentCopyWithImpl(this._self, this._then);

  final _PageContent _self;
  final $Res Function(_PageContent) _then;

/// Create a copy of PageContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? realmId = null,Object? finalTopics = null,}) {
  return _then(_PageContent(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,realmId: null == realmId ? _self.realmId : realmId // ignore: cast_nullable_to_non_nullable
as String,finalTopics: null == finalTopics ? _self._finalTopics : finalTopics // ignore: cast_nullable_to_non_nullable
as List<FinalTopic>,
  ));
}


}


/// @nodoc
mixin _$OtherContent {

 String get name; String get realmId; List<FinalTopic> get finalTopics;
/// Create a copy of OtherContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OtherContentCopyWith<OtherContent> get copyWith => _$OtherContentCopyWithImpl<OtherContent>(this as OtherContent, _$identity);

  /// Serializes this OtherContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OtherContent&&(identical(other.name, name) || other.name == name)&&(identical(other.realmId, realmId) || other.realmId == realmId)&&const DeepCollectionEquality().equals(other.finalTopics, finalTopics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,realmId,const DeepCollectionEquality().hash(finalTopics));

@override
String toString() {
  return 'OtherContent(name: $name, realmId: $realmId, finalTopics: $finalTopics)';
}


}

/// @nodoc
abstract mixin class $OtherContentCopyWith<$Res>  {
  factory $OtherContentCopyWith(OtherContent value, $Res Function(OtherContent) _then) = _$OtherContentCopyWithImpl;
@useResult
$Res call({
 String name, String realmId, List<FinalTopic> finalTopics
});




}
/// @nodoc
class _$OtherContentCopyWithImpl<$Res>
    implements $OtherContentCopyWith<$Res> {
  _$OtherContentCopyWithImpl(this._self, this._then);

  final OtherContent _self;
  final $Res Function(OtherContent) _then;

/// Create a copy of OtherContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? realmId = null,Object? finalTopics = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,realmId: null == realmId ? _self.realmId : realmId // ignore: cast_nullable_to_non_nullable
as String,finalTopics: null == finalTopics ? _self.finalTopics : finalTopics // ignore: cast_nullable_to_non_nullable
as List<FinalTopic>,
  ));
}

}


/// Adds pattern-matching-related methods to [OtherContent].
extension OtherContentPatterns on OtherContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OtherContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OtherContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OtherContent value)  $default,){
final _that = this;
switch (_that) {
case _OtherContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OtherContent value)?  $default,){
final _that = this;
switch (_that) {
case _OtherContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String realmId,  List<FinalTopic> finalTopics)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OtherContent() when $default != null:
return $default(_that.name,_that.realmId,_that.finalTopics);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String realmId,  List<FinalTopic> finalTopics)  $default,) {final _that = this;
switch (_that) {
case _OtherContent():
return $default(_that.name,_that.realmId,_that.finalTopics);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String realmId,  List<FinalTopic> finalTopics)?  $default,) {final _that = this;
switch (_that) {
case _OtherContent() when $default != null:
return $default(_that.name,_that.realmId,_that.finalTopics);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OtherContent implements OtherContent {
  const _OtherContent({required this.name, required this.realmId, required final  List<FinalTopic> finalTopics}): _finalTopics = finalTopics;
  factory _OtherContent.fromJson(Map<String, dynamic> json) => _$OtherContentFromJson(json);

@override final  String name;
@override final  String realmId;
 final  List<FinalTopic> _finalTopics;
@override List<FinalTopic> get finalTopics {
  if (_finalTopics is EqualUnmodifiableListView) return _finalTopics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_finalTopics);
}


/// Create a copy of OtherContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OtherContentCopyWith<_OtherContent> get copyWith => __$OtherContentCopyWithImpl<_OtherContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OtherContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OtherContent&&(identical(other.name, name) || other.name == name)&&(identical(other.realmId, realmId) || other.realmId == realmId)&&const DeepCollectionEquality().equals(other._finalTopics, _finalTopics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,realmId,const DeepCollectionEquality().hash(_finalTopics));

@override
String toString() {
  return 'OtherContent(name: $name, realmId: $realmId, finalTopics: $finalTopics)';
}


}

/// @nodoc
abstract mixin class _$OtherContentCopyWith<$Res> implements $OtherContentCopyWith<$Res> {
  factory _$OtherContentCopyWith(_OtherContent value, $Res Function(_OtherContent) _then) = __$OtherContentCopyWithImpl;
@override @useResult
$Res call({
 String name, String realmId, List<FinalTopic> finalTopics
});




}
/// @nodoc
class __$OtherContentCopyWithImpl<$Res>
    implements _$OtherContentCopyWith<$Res> {
  __$OtherContentCopyWithImpl(this._self, this._then);

  final _OtherContent _self;
  final $Res Function(_OtherContent) _then;

/// Create a copy of OtherContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? realmId = null,Object? finalTopics = null,}) {
  return _then(_OtherContent(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,realmId: null == realmId ? _self.realmId : realmId // ignore: cast_nullable_to_non_nullable
as String,finalTopics: null == finalTopics ? _self._finalTopics : finalTopics // ignore: cast_nullable_to_non_nullable
as List<FinalTopic>,
  ));
}


}


/// @nodoc
mixin _$FinalTopic {

 String get name; String get realmId; String get filePathEnglish; String get filePathPersian; List<TextSegmentEnglish> get contentEnglish; List<TextSegmentPersian> get contentPersian; String get notesFilePath;// required List<String> audioFilePaths,
 String? get audioFileName;
/// Create a copy of FinalTopic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FinalTopicCopyWith<FinalTopic> get copyWith => _$FinalTopicCopyWithImpl<FinalTopic>(this as FinalTopic, _$identity);

  /// Serializes this FinalTopic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FinalTopic&&(identical(other.name, name) || other.name == name)&&(identical(other.realmId, realmId) || other.realmId == realmId)&&(identical(other.filePathEnglish, filePathEnglish) || other.filePathEnglish == filePathEnglish)&&(identical(other.filePathPersian, filePathPersian) || other.filePathPersian == filePathPersian)&&const DeepCollectionEquality().equals(other.contentEnglish, contentEnglish)&&const DeepCollectionEquality().equals(other.contentPersian, contentPersian)&&(identical(other.notesFilePath, notesFilePath) || other.notesFilePath == notesFilePath)&&(identical(other.audioFileName, audioFileName) || other.audioFileName == audioFileName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,realmId,filePathEnglish,filePathPersian,const DeepCollectionEquality().hash(contentEnglish),const DeepCollectionEquality().hash(contentPersian),notesFilePath,audioFileName);

@override
String toString() {
  return 'FinalTopic(name: $name, realmId: $realmId, filePathEnglish: $filePathEnglish, filePathPersian: $filePathPersian, contentEnglish: $contentEnglish, contentPersian: $contentPersian, notesFilePath: $notesFilePath, audioFileName: $audioFileName)';
}


}

/// @nodoc
abstract mixin class $FinalTopicCopyWith<$Res>  {
  factory $FinalTopicCopyWith(FinalTopic value, $Res Function(FinalTopic) _then) = _$FinalTopicCopyWithImpl;
@useResult
$Res call({
 String name, String realmId, String filePathEnglish, String filePathPersian, List<TextSegmentEnglish> contentEnglish, List<TextSegmentPersian> contentPersian, String notesFilePath, String? audioFileName
});




}
/// @nodoc
class _$FinalTopicCopyWithImpl<$Res>
    implements $FinalTopicCopyWith<$Res> {
  _$FinalTopicCopyWithImpl(this._self, this._then);

  final FinalTopic _self;
  final $Res Function(FinalTopic) _then;

/// Create a copy of FinalTopic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? realmId = null,Object? filePathEnglish = null,Object? filePathPersian = null,Object? contentEnglish = null,Object? contentPersian = null,Object? notesFilePath = null,Object? audioFileName = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,realmId: null == realmId ? _self.realmId : realmId // ignore: cast_nullable_to_non_nullable
as String,filePathEnglish: null == filePathEnglish ? _self.filePathEnglish : filePathEnglish // ignore: cast_nullable_to_non_nullable
as String,filePathPersian: null == filePathPersian ? _self.filePathPersian : filePathPersian // ignore: cast_nullable_to_non_nullable
as String,contentEnglish: null == contentEnglish ? _self.contentEnglish : contentEnglish // ignore: cast_nullable_to_non_nullable
as List<TextSegmentEnglish>,contentPersian: null == contentPersian ? _self.contentPersian : contentPersian // ignore: cast_nullable_to_non_nullable
as List<TextSegmentPersian>,notesFilePath: null == notesFilePath ? _self.notesFilePath : notesFilePath // ignore: cast_nullable_to_non_nullable
as String,audioFileName: freezed == audioFileName ? _self.audioFileName : audioFileName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FinalTopic].
extension FinalTopicPatterns on FinalTopic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FinalTopic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FinalTopic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FinalTopic value)  $default,){
final _that = this;
switch (_that) {
case _FinalTopic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FinalTopic value)?  $default,){
final _that = this;
switch (_that) {
case _FinalTopic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String realmId,  String filePathEnglish,  String filePathPersian,  List<TextSegmentEnglish> contentEnglish,  List<TextSegmentPersian> contentPersian,  String notesFilePath,  String? audioFileName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FinalTopic() when $default != null:
return $default(_that.name,_that.realmId,_that.filePathEnglish,_that.filePathPersian,_that.contentEnglish,_that.contentPersian,_that.notesFilePath,_that.audioFileName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String realmId,  String filePathEnglish,  String filePathPersian,  List<TextSegmentEnglish> contentEnglish,  List<TextSegmentPersian> contentPersian,  String notesFilePath,  String? audioFileName)  $default,) {final _that = this;
switch (_that) {
case _FinalTopic():
return $default(_that.name,_that.realmId,_that.filePathEnglish,_that.filePathPersian,_that.contentEnglish,_that.contentPersian,_that.notesFilePath,_that.audioFileName);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String realmId,  String filePathEnglish,  String filePathPersian,  List<TextSegmentEnglish> contentEnglish,  List<TextSegmentPersian> contentPersian,  String notesFilePath,  String? audioFileName)?  $default,) {final _that = this;
switch (_that) {
case _FinalTopic() when $default != null:
return $default(_that.name,_that.realmId,_that.filePathEnglish,_that.filePathPersian,_that.contentEnglish,_that.contentPersian,_that.notesFilePath,_that.audioFileName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FinalTopic implements FinalTopic {
  const _FinalTopic({required this.name, required this.realmId, required this.filePathEnglish, required this.filePathPersian, required final  List<TextSegmentEnglish> contentEnglish, required final  List<TextSegmentPersian> contentPersian, required this.notesFilePath, this.audioFileName}): _contentEnglish = contentEnglish,_contentPersian = contentPersian;
  factory _FinalTopic.fromJson(Map<String, dynamic> json) => _$FinalTopicFromJson(json);

@override final  String name;
@override final  String realmId;
@override final  String filePathEnglish;
@override final  String filePathPersian;
 final  List<TextSegmentEnglish> _contentEnglish;
@override List<TextSegmentEnglish> get contentEnglish {
  if (_contentEnglish is EqualUnmodifiableListView) return _contentEnglish;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contentEnglish);
}

 final  List<TextSegmentPersian> _contentPersian;
@override List<TextSegmentPersian> get contentPersian {
  if (_contentPersian is EqualUnmodifiableListView) return _contentPersian;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contentPersian);
}

@override final  String notesFilePath;
// required List<String> audioFilePaths,
@override final  String? audioFileName;

/// Create a copy of FinalTopic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FinalTopicCopyWith<_FinalTopic> get copyWith => __$FinalTopicCopyWithImpl<_FinalTopic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FinalTopicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FinalTopic&&(identical(other.name, name) || other.name == name)&&(identical(other.realmId, realmId) || other.realmId == realmId)&&(identical(other.filePathEnglish, filePathEnglish) || other.filePathEnglish == filePathEnglish)&&(identical(other.filePathPersian, filePathPersian) || other.filePathPersian == filePathPersian)&&const DeepCollectionEquality().equals(other._contentEnglish, _contentEnglish)&&const DeepCollectionEquality().equals(other._contentPersian, _contentPersian)&&(identical(other.notesFilePath, notesFilePath) || other.notesFilePath == notesFilePath)&&(identical(other.audioFileName, audioFileName) || other.audioFileName == audioFileName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,realmId,filePathEnglish,filePathPersian,const DeepCollectionEquality().hash(_contentEnglish),const DeepCollectionEquality().hash(_contentPersian),notesFilePath,audioFileName);

@override
String toString() {
  return 'FinalTopic(name: $name, realmId: $realmId, filePathEnglish: $filePathEnglish, filePathPersian: $filePathPersian, contentEnglish: $contentEnglish, contentPersian: $contentPersian, notesFilePath: $notesFilePath, audioFileName: $audioFileName)';
}


}

/// @nodoc
abstract mixin class _$FinalTopicCopyWith<$Res> implements $FinalTopicCopyWith<$Res> {
  factory _$FinalTopicCopyWith(_FinalTopic value, $Res Function(_FinalTopic) _then) = __$FinalTopicCopyWithImpl;
@override @useResult
$Res call({
 String name, String realmId, String filePathEnglish, String filePathPersian, List<TextSegmentEnglish> contentEnglish, List<TextSegmentPersian> contentPersian, String notesFilePath, String? audioFileName
});




}
/// @nodoc
class __$FinalTopicCopyWithImpl<$Res>
    implements _$FinalTopicCopyWith<$Res> {
  __$FinalTopicCopyWithImpl(this._self, this._then);

  final _FinalTopic _self;
  final $Res Function(_FinalTopic) _then;

/// Create a copy of FinalTopic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? realmId = null,Object? filePathEnglish = null,Object? filePathPersian = null,Object? contentEnglish = null,Object? contentPersian = null,Object? notesFilePath = null,Object? audioFileName = freezed,}) {
  return _then(_FinalTopic(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,realmId: null == realmId ? _self.realmId : realmId // ignore: cast_nullable_to_non_nullable
as String,filePathEnglish: null == filePathEnglish ? _self.filePathEnglish : filePathEnglish // ignore: cast_nullable_to_non_nullable
as String,filePathPersian: null == filePathPersian ? _self.filePathPersian : filePathPersian // ignore: cast_nullable_to_non_nullable
as String,contentEnglish: null == contentEnglish ? _self._contentEnglish : contentEnglish // ignore: cast_nullable_to_non_nullable
as List<TextSegmentEnglish>,contentPersian: null == contentPersian ? _self._contentPersian : contentPersian // ignore: cast_nullable_to_non_nullable
as List<TextSegmentPersian>,notesFilePath: null == notesFilePath ? _self.notesFilePath : notesFilePath // ignore: cast_nullable_to_non_nullable
as String,audioFileName: freezed == audioFileName ? _self.audioFileName : audioFileName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
