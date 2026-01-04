// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drawer_expansion_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DrawerExpansion)
const drawerExpansionProvider = DrawerExpansionProvider._();

final class DrawerExpansionProvider
    extends $NotifierProvider<DrawerExpansion, Map<String, String?>> {
  const DrawerExpansionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'drawerExpansionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$drawerExpansionHash();

  @$internal
  @override
  DrawerExpansion create() => DrawerExpansion();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, String?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, String?>>(value),
    );
  }
}

String _$drawerExpansionHash() => r'b2ba5525bfa5afe4d664c4fcd428d93ad885f039';

abstract class _$DrawerExpansion extends $Notifier<Map<String, String?>> {
  Map<String, String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<String, String?>, Map<String, String?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, String?>, Map<String, String?>>,
              Map<String, String?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
