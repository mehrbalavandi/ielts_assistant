# ─────────────────────────────────────────────────────────────────────────────
#  بازچینشِ ساختارِ پوشه‌ها و نام‌گذاریِ پروژه‌ی ielts_assistant — نسخه‌ی PowerShell
#
#  دقیقاً همان کارِ tools/restructure.sh را می‌کند، برای ویندوز که bash ندارد.
#  فقط فایل‌ها را جابه‌جا/حذف می‌کند و importها را به‌روز می‌کند؛ هیچ منطقی
#  داخلِ هیچ فایلی عوض نمی‌شود. از git mv استفاده می‌کند تا تاریخچه‌ی هر فایل
#  حفظ شود (git log --follow).
#
#  اجرا از ریشه‌ی پروژه، روی شاخه‌ی تمیز:
#      git checkout -b refactor/structure
#      powershell -ExecutionPolicy Bypass -File tools\restructure.ps1
#      dart format lib ; flutter analyze
# ─────────────────────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'

if (-not (Test-Path 'pubspec.yaml') -or -not (Test-Path 'lib')) {
    Write-Host 'X باید از ریشه‌ی پروژه‌ی فلاتر اجرا شود.' -ForegroundColor Red
    exit 1
}
if (git status --porcelain) {
    Write-Host 'X تغییرِ ذخیره‌نشده دارید. اول commit یا stash کنید.' -ForegroundColor Red
    exit 1
}

# ── ۱) فایل‌های مرده ──────────────────────────────────────────────────────
# هیچ فایلی اینها را import نمی‌کند و هیچ symbolشان جای دیگری استفاده نشده.
# در تاریخچه‌ی git می‌مانند، پس بازگرداندنی‌اند.
Write-Host '> حذف فایل‌های بلااستفاده'
$dead = @(
    'lib/features/content_viewer/using_gemini/search_engine.dart',
    'lib/features/content_viewer/using_gemini/audio_player/audio_notifier.dart',
    'lib/features/content_viewer/using_gemini/audio_player/audio_notifier.g.dart',
    'lib/features/content_viewer/using_gemini/audio_player/player_state.dart',
    'lib/features/content_viewer/using_gemini/audio_player/player_state.freezed.dart',
    'lib/common/app_font_weight.dart',
    'lib/common/enums.dart',
    'lib/shared/utility_persian.dart',
    'lib/shared/providers/storage_provider.dart'
)
foreach ($f in $dead) { git rm -q -- $f }

# ── ۲) ساختِ درختِ جدید ───────────────────────────────────────────────────
Write-Host '> ساخت پوشه‌های جدید'
$dirs = @(
    'lib/app',
    'lib/core/network',
    'lib/core/storage',
    'lib/core/text',
    'lib/features/auth/presentation',
    'lib/features/auth/providers',
    'lib/features/library/presentation',
    'lib/features/library/providers',
    'lib/features/reader/data',
    'lib/features/reader/domain',
    'lib/features/reader/presentation/rendering',
    'lib/features/audio/presentation',
    'lib/features/audio/providers',
    'lib/features/search/data',
    'lib/features/search/presentation',
    'lib/features/settings/presentation',
    'lib/features/settings/providers',
    'lib/shared/widgets'
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

# ── ۳) جابه‌جایی ──────────────────────────────────────────────────────────
# نکته: فایلِ ‎.g.dart‎ همراهِ صاحبش می‌رود، وگرنه دستورِ `part` می‌شکند.
Write-Host '> جابه‌جایی فایل‌ها'
$moves = @(
    @('lib/features/content_viewer/using_gemini/providers/app_settings_provider.dart', 'lib/core/network/dio_provider.dart'),
    @('lib/features/content_viewer/using_gemini/services/storage_service.dart', 'lib/core/storage/storage_service.dart'),
    @('lib/features/content_viewer/using_gemini/search_text_utils.dart', 'lib/core/text/document_text_utils.dart'),
    @('lib/features/content_viewer/using_gemini/login_screen.dart', 'lib/features/auth/presentation/login_screen.dart'),
    @('lib/features/content_viewer/using_gemini/providers/auth_provider.dart', 'lib/features/auth/providers/auth_provider.dart'),
    @('lib/features/content_viewer/using_gemini/library_screen.dart', 'lib/features/library/presentation/library_screen.dart'),
    @('lib/features/content_viewer/using_gemini/providers/book_provider.dart', 'lib/features/library/providers/books_provider.dart'),
    @('lib/features/content_viewer/using_gemini/models.dart', 'lib/features/reader/domain/document_models.dart'),
    @('lib/features/content_viewer/using_gemini/document_loader.dart', 'lib/features/reader/data/document_loader.dart'),
    @('lib/features/content_viewer/using_gemini/paged_book_store.dart', 'lib/features/reader/data/paged_book_store.dart'),
    @('lib/features/content_viewer/using_gemini/main_book_screen.dart', 'lib/features/reader/presentation/reader_screen.dart'),
    @('lib/features/content_viewer/using_gemini/reading_canvas_screen.dart', 'lib/features/reader/presentation/reading_canvas.dart'),
    @('lib/features/content_viewer/using_gemini/text_render_engine.dart', 'lib/features/reader/presentation/rendering/text_render_engine.dart'),
    @('lib/features/content_viewer/using_gemini/audio_player/audio_player_provider.dart', 'lib/features/audio/providers/audio_player_provider.dart'),
    @('lib/features/content_viewer/using_gemini/audio_player/audio_player_provider.g.dart', 'lib/features/audio/providers/audio_player_provider.g.dart'),
    @('lib/features/content_viewer/using_gemini/audio_player/presentation/widgets/telegram_audio_player.dart', 'lib/features/audio/presentation/audio_player_bar.dart'),
    @('lib/features/content_viewer/using_gemini/cross_book_search_engine.dart', 'lib/features/search/data/book_search_engine.dart'),
    @('lib/features/content_viewer/using_gemini/book_search_delegate.dart', 'lib/features/search/presentation/book_search_delegate.dart'),
    @('lib/features/content_viewer/using_gemini/settings_screen.dart', 'lib/features/settings/presentation/settings_screen.dart'),
    @('lib/features/content_viewer/using_gemini/language_provider.dart', 'lib/features/settings/providers/language_provider.dart'),
    @('lib/features/content_viewer/using_gemini/app_drawer.dart', 'lib/shared/widgets/app_drawer.dart')
)
foreach ($m in $moves) { git mv -- $m[0] $m[1] }

foreach ($d in @('lib/features/content_viewer', 'lib/common', 'lib/shared/providers')) {
    if (Test-Path $d) { Remove-Item -Recurse -Force $d }
}

# ── ۴) به‌روزرسانی importها و نامِ کلاس‌ها ─────────────────────────────────
# همه‌ی importهای داخلی مطلق‌اند (package:ielts_assistant/...)، پس جایگزینیِ
# متنیِ ساده کافی است و هیچ import نسبی‌ای نمی‌شکند.
Write-Host '> به‌روزرسانی importها و نام کلاس‌ها'
$imports = @(
    @('package:ielts_assistant/features/content_viewer/using_gemini/providers/app_settings_provider.dart', 'package:ielts_assistant/core/network/dio_provider.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/services/storage_service.dart', 'package:ielts_assistant/core/storage/storage_service.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/search_text_utils.dart', 'package:ielts_assistant/core/text/document_text_utils.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/login_screen.dart', 'package:ielts_assistant/features/auth/presentation/login_screen.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/providers/auth_provider.dart', 'package:ielts_assistant/features/auth/providers/auth_provider.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/library_screen.dart', 'package:ielts_assistant/features/library/presentation/library_screen.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart', 'package:ielts_assistant/features/library/providers/books_provider.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/models.dart', 'package:ielts_assistant/features/reader/domain/document_models.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/document_loader.dart', 'package:ielts_assistant/features/reader/data/document_loader.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/paged_book_store.dart', 'package:ielts_assistant/features/reader/data/paged_book_store.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/main_book_screen.dart', 'package:ielts_assistant/features/reader/presentation/reader_screen.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/reading_canvas_screen.dart', 'package:ielts_assistant/features/reader/presentation/reading_canvas.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/text_render_engine.dart', 'package:ielts_assistant/features/reader/presentation/rendering/text_render_engine.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/audio_player/audio_player_provider.dart', 'package:ielts_assistant/features/audio/providers/audio_player_provider.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/audio_player/presentation/widgets/telegram_audio_player.dart', 'package:ielts_assistant/features/audio/presentation/audio_player_bar.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart', 'package:ielts_assistant/features/search/data/book_search_engine.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/book_search_delegate.dart', 'package:ielts_assistant/features/search/presentation/book_search_delegate.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/settings_screen.dart', 'package:ielts_assistant/features/settings/presentation/settings_screen.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/language_provider.dart', 'package:ielts_assistant/features/settings/providers/language_provider.dart'),
    @('package:ielts_assistant/features/content_viewer/using_gemini/app_drawer.dart', 'package:ielts_assistant/shared/widgets/app_drawer.dart')
)

# اگر فعلاً فقط جابه‌جایی می‌خواهید، این آرایه را خالی کنید: $renames = @()
# نام‌های قدیمی یا محلِ کلاس را توصیف می‌کردند یا الهام‌گرفته از اپِ دیگری
# بودند («تلگرام»)، نه نقشِ خودشان را.
# دو موردِ آخر جداگانه لازم‌اند: در regex زیرخط یک «کاراکترِ کلمه» است، پس
# \b در ابتدای _MainBookScreenState اصلاً مرزی نمی‌بیند و آن اسم از قلمِ
# قاعده‌ی بالایی می‌افتد.
$renames = @(
    @('TelegramAudioPlayer', 'AudioPlayerBar'),
    @('MainBookScreen', 'ReaderScreen'),
    @('ReadingCanvasScreen', 'ReadingCanvas'),
    @('CrossBookSearchEngine', 'BookSearchEngine'),
    @('MyApp', 'IeltsAssistantApp'),
    @('_MainBookScreenState', '_ReaderScreenState'),
    @('_ReadingCanvasScreenState', '_ReadingCanvasState')
)

# با .NET IO می‌نویسیم و نه Set-Content: در Windows PowerShell سوئیچِ
# ‎-Encoding UTF8‎ فایل را با BOM ذخیره می‌کند و آن BOM سرِ همه‌ی فایل‌های
# دارت می‌نشیند. این شکل، UTF-8 بدونِ BOM می‌نویسد و پایانِ خط‌ها هم
# دست‌نخورده می‌مانند.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$files = Get-ChildItem -Path 'lib' -Recurse -Filter '*.dart'

foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    $orig = $text
    foreach ($r in $imports) { $text = $text.Replace($r[0], $r[1]) }
    foreach ($r in $renames) {
        $text = [regex]::Replace($text, ('\b' + $r[0] + '\b'), $r[1])
    }
    if ($text -ne $orig) {
        [System.IO.File]::WriteAllText($file.FullName, $text, $utf8NoBom)
    }
}

Write-Host ''
Write-Host 'OK تمام شد. حالا:' -ForegroundColor Green
Write-Host '    dart format lib'
Write-Host '    flutter analyze'
Write-Host '    flutter run'