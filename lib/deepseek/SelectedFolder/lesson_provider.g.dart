// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(lessons)
const lessonsProvider = LessonsFamily._();

final class LessonsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Lesson>>,
          List<Lesson>,
          FutureOr<List<Lesson>>
        >
    with $FutureModifier<List<Lesson>>, $FutureProvider<List<Lesson>> {
  const LessonsProvider._({
    required LessonsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'lessonsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lessonsHash();

  @override
  String toString() {
    return r'lessonsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Lesson>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Lesson>> create(Ref ref) {
    final argument = this.argument as String;
    return lessons(ref, bookId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LessonsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lessonsHash() => r'7319bfa2ec9fef7791ea35bc8f85c0e8901fcad5';

final class LessonsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Lesson>>, String> {
  const LessonsFamily._()
    : super(
        retry: null,
        name: r'lessonsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LessonsProvider call({required String bookId}) =>
      LessonsProvider._(argument: bookId, from: this);

  @override
  String toString() => r'lessonsProvider';
}

@ProviderFor(SelectedLesson)
const selectedLessonProvider = SelectedLessonProvider._();

final class SelectedLessonProvider
    extends $NotifierProvider<SelectedLesson, Lesson?> {
  const SelectedLessonProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedLessonProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedLessonHash();

  @$internal
  @override
  SelectedLesson create() => SelectedLesson();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Lesson? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Lesson?>(value),
    );
  }
}

String _$selectedLessonHash() => r'fc53905494556ecec3a2f128b1906b5ee7b8306b';

abstract class _$SelectedLesson extends $Notifier<Lesson?> {
  Lesson? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Lesson?, Lesson?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Lesson?, Lesson?>,
              Lesson?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
