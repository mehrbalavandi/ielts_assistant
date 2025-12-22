// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(books)
const booksProvider = BooksProvider._();

final class BooksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Book>>,
          List<Book>,
          FutureOr<List<Book>>
        >
    with $FutureModifier<List<Book>>, $FutureProvider<List<Book>> {
  const BooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'booksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$booksHash();

  @$internal
  @override
  $FutureProviderElement<List<Book>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Book>> create(Ref ref) {
    return books(ref);
  }
}

String _$booksHash() => r'e5550c82f2e776a126f615d62a36f1d89bdc1a69';

@ProviderFor(SelectedBook)
const selectedBookProvider = SelectedBookProvider._();

final class SelectedBookProvider
    extends $NotifierProvider<SelectedBook, Book?> {
  const SelectedBookProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedBookProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedBookHash();

  @$internal
  @override
  SelectedBook create() => SelectedBook();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Book? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Book?>(value),
    );
  }
}

String _$selectedBookHash() => r'e4ba1ac2947a7dc53124c82bc8c683b4cd14f7c4';

abstract class _$SelectedBook extends $Notifier<Book?> {
  Book? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Book?, Book?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Book?, Book?>,
              Book?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
