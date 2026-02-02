// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SentenceNotifier)
const sentenceProvider = SentenceNotifierFamily._();

final class SentenceNotifierProvider
    extends $NotifierProvider<SentenceNotifier, Map<int, SentenceStatus>> {
  const SentenceNotifierProvider._({
    required SentenceNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sentenceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sentenceNotifierHash();

  @override
  String toString() {
    return r'sentenceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SentenceNotifier create() => SentenceNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, SentenceStatus> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, SentenceStatus>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SentenceNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sentenceNotifierHash() => r'af4a71ee1761f80088db1746024c4fb986a98dab';

final class SentenceNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          SentenceNotifier,
          Map<int, SentenceStatus>,
          Map<int, SentenceStatus>,
          Map<int, SentenceStatus>,
          String
        > {
  const SentenceNotifierFamily._()
    : super(
        retry: null,
        name: r'sentenceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SentenceNotifierProvider call(String finalTopicId) =>
      SentenceNotifierProvider._(argument: finalTopicId, from: this);

  @override
  String toString() => r'sentenceProvider';
}

abstract class _$SentenceNotifier extends $Notifier<Map<int, SentenceStatus>> {
  late final _$args = ref.$arg as String;
  String get finalTopicId => _$args;

  Map<int, SentenceStatus> build(String finalTopicId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<Map<int, SentenceStatus>, Map<int, SentenceStatus>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<int, SentenceStatus>, Map<int, SentenceStatus>>,
              Map<int, SentenceStatus>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
