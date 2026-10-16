// 🌟 DEV-4: کلیدِ عمومیِ امضای مجوزِ آفلاین (Ed25519، base64ِ ۳۲ بایت).
//
// روی سرور بسازید:  php artisan license:keygen
// خطِ «LICENSE_SIGNING_KEY=…» به .envِ سرور می‌رود و خطِ زیر با مقدارِ چاپ‌شده عوض می‌شود.
// اگر کلیدِ سرور را گم کردید ولی هنوز در .env هست: php artisan license:keygen --show
// راهنمای کامل: SETUP-backend.md بخشِ ۴-الف (مخزنِ لاراول) و WORKFLOW.md بخشِ ۶.
//
// تا وقتی خالی است:
// - نسخه‌ی debug: مجوز وارسی نمی‌شود (برای توسعه).
// - نسخه‌ی release: نسخه‌ی کاملِ کتاب‌ها باز نمی‌شود — عمداً، تا نسخه‌ی بی‌قفل منتشر نشود.
const String kLicensePublicKey = 'YeaDuFgIV1J6sFsYGE6OFlUK4dHFi1q3HH3NceZsOg4=';
