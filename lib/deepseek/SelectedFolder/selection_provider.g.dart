// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SelectionManager)
const selectionManagerProvider = SelectionManagerProvider._();

final class SelectionManagerProvider
    extends $NotifierProvider<SelectionManager, SelectionState> {
  const SelectionManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectionManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectionManagerHash();

  @$internal
  @override
  SelectionManager create() => SelectionManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SelectionState>(value),
    );
  }
}

String _$selectionManagerHash() => r'381bea6aa9c8203399aaa18e5fb8ee0d36e56736';

abstract class _$SelectionManager extends $Notifier<SelectionState> {
  SelectionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SelectionState, SelectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SelectionState, SelectionState>,
              SelectionState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
