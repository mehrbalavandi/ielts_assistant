// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ActiveBook)
final activeBookProvider = ActiveBookProvider._();

final class ActiveBookProvider
    extends $NotifierProvider<ActiveBook, BookModel?> {
  ActiveBookProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeBookProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeBookHash();

  @$internal
  @override
  ActiveBook create() => ActiveBook();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookModel? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookModel?>(value),
    );
  }
}

String _$activeBookHash() => r'c8f7e4411010b46366b7ef90070a1bbacb9ab1fc';

abstract class _$ActiveBook extends $Notifier<BookModel?> {
  BookModel? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<BookModel?, BookModel?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BookModel?, BookModel?>,
              BookModel?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
