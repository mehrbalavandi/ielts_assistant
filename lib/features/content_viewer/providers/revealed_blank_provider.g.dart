// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revealed_blank_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RevealedBlankNotifier)
const revealedBlankProvider = RevealedBlankNotifierFamily._();

final class RevealedBlankNotifierProvider
    extends
        $NotifierProvider<
          RevealedBlankNotifier,
          Map<int, RevealedBlankStatus>
        > {
  const RevealedBlankNotifierProvider._({
    required RevealedBlankNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'revealedBlankProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$revealedBlankNotifierHash();

  @override
  String toString() {
    return r'revealedBlankProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RevealedBlankNotifier create() => RevealedBlankNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, RevealedBlankStatus> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, RevealedBlankStatus>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RevealedBlankNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$revealedBlankNotifierHash() =>
    r'3f2267ab5d18f4b11ff0a22f73cb801aebd19fc3';

final class RevealedBlankNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          RevealedBlankNotifier,
          Map<int, RevealedBlankStatus>,
          Map<int, RevealedBlankStatus>,
          Map<int, RevealedBlankStatus>,
          String
        > {
  const RevealedBlankNotifierFamily._()
    : super(
        retry: null,
        name: r'revealedBlankProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RevealedBlankNotifierProvider call(String finalTopicId) =>
      RevealedBlankNotifierProvider._(argument: finalTopicId, from: this);

  @override
  String toString() => r'revealedBlankProvider';
}

abstract class _$RevealedBlankNotifier
    extends $Notifier<Map<int, RevealedBlankStatus>> {
  late final _$args = ref.$arg as String;
  String get finalTopicId => _$args;

  Map<int, RevealedBlankStatus> build(String finalTopicId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref
            as $Ref<
              Map<int, RevealedBlankStatus>,
              Map<int, RevealedBlankStatus>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<int, RevealedBlankStatus>,
                Map<int, RevealedBlankStatus>
              >,
              Map<int, RevealedBlankStatus>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
