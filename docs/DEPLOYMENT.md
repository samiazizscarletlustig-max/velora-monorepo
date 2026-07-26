# Velora - Deployment & Integration Checklist

## 🔌 INTEGRATION POINTS TRACKER (نقاط الربط الأساسية)

يجب إعداد جميع النقاط التالية قبل إطلاق المشروع (Production Launch). لا تقم بتضمين المفاتيح السرية في الكود المصدري أبداً؛ استخدم المتغيرات البيئية (Environment Variables) و (GitHub Secrets).

### 1. Supabase (Database & Auth & Edge Functions)
- [ ] `SUPABASE_URL`: رابط المشروع الأساسي (مطلوب لـ Flutter، Scraper، Edge Functions).
- [ ] `SUPABASE_ANON_KEY`: مفتاح الواجهة الأمامية (مطلوب لـ Flutter App في `supabase_config.dart`).
- [ ] `SUPABASE_SERVICE_ROLE_KEY`: مفتاح الصلاحيات الكاملة (مطلوب لـ Scraper في `.github/workflows/daily_scrape.yml` و Edge Functions. **إياك أن تضعه في تطبيق Flutter**).

### 2. Gemini AI Engine (Edge Functions)
- [ ] `GEMINI_API_KEY`: مفتاح حساب Google AI Studio المجاني (مطلوب لـ `generate-insights` في Edge Functions). يجب تعيينه عبر `supabase secrets set GEMINI_API_KEY=your_key`.

### 3. Flutter Web Hosting (Firebase)
- [ ] إعداد مشروع Firebase في `.firebaserc`.
- [ ] تشغيل `flutter build web` لإنشاء الحزمة النهائية.
- [ ] تشغيل `firebase deploy --only hosting` لرفع التطبيق (مسار الملفات مضبوط على `apps/flutter_app/build/web` في `firebase.json`).

### 4. GitHub Actions (Automation & Scraper)
- [ ] تعيين `SUPABASE_URL` في GitHub Repository Secrets.
- [ ] تعيين `SUPABASE_SERVICE_ROLE_KEY` في GitHub Repository Secrets.
- [ ] التحقق من عمل `daily_scrape.yml` لجدولة الـ Scraper يومياً.
- [ ] التحقق من عمل `keep_supabase_alive.yml` لمنع الإيقاف التلقائي في الخطة المجانية.

### 5. Lemon Squeezy (Monetization - 0% Upfront Cost)
- [ ] `LEMON_SQUEEZY_WEBHOOK_SECRET`: لتأكيد الدفعات الواردة في مجلد `apps/supabase_functions/webhooks/`.

### 6. Resend (Email Automation - Free Tier)
- [ ] `RESEND_API_KEY`: لإرسال تنبيهات (Alerts) للمستخدمين (اختياري / مرحلة مستقبلية).
