// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SentenceNotifier)
const sentenceProvider = SentenceNotifierProvider._();

final class SentenceNotifierProvider
    extends $NotifierProvider<SentenceNotifier, Map<int, SentenceStatus>> {
  const SentenceNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sentenceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sentenceNotifierHash();

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
}

String _$sentenceNotifierHash() => r'4b813f567cb43819d3cdbfa39182cbed90ed3eed';

abstract class _$SentenceNotifier extends $Notifier<Map<int, SentenceStatus>> {
  Map<int, SentenceStatus> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
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
