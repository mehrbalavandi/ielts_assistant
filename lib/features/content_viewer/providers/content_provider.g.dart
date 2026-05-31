// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AllContent)
final allContentProvider = AllContentProvider._();

final class AllContentProvider
    extends $AsyncNotifierProvider<AllContent, List<Book>> {
  AllContentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allContentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allContentHash();

  @$internal
  @override
  AllContent create() => AllContent();
}

String _$allContentHash() => r'c5d3824fe5b4c1e6e98e7833ccc366bae50c9c62';

abstract class _$AllContent extends $AsyncNotifier<List<Book>> {
  FutureOr<List<Book>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Book>>, List<Book>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Book>>, List<Book>>,
              AsyncValue<List<Book>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
