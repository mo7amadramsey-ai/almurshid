# نظام العمل المتوازي على «المرشد ← المُلزم»

الاتجاه العام: `docs/ROADMAP_MULZIM.md`. المستودع عام، لذلك **لا تُكتب عناوين Gmail ولا أسرار في أي ملف هنا**.

## الأدوار (8 جلسات)
| الرمز | الدور | المالك الافتراضي |
|---|---|---|
| **M** | المدير: دمج وبناء وإصدار وقرارات وصلاحية تعديل كل شيء | الحساب الذي أنشأ هذه الوثيقة (محجوز في `docs/claims/M.json`) |
| R1 | واجهة وتصميم وشاشات التبويبات | يُحجز بالأسبقية |
| R2 | محرك استيراد مودل | يُحجز بالأسبقية |
| R3 | الخطة والإلزام والإشعارات والإحصاءات | يُحجز بالأسبقية |
| R5 | القفل الدراسي v2 | يُحجز بالأسبقية |
| R4 | البيانات والأمان (SQLite، نسخ احتياطي، قفل الدخول) | يُحجز بالأسبقية |
| R6 | الوسائط: مشغّل، مكتبة، تنزيلات، مستندات | يُحجز بالأسبقية |
| R7 | الذكاء الاصطناعي والتعلّم: مرشد، اختبارات، مراجعة، دفتر محاضرات | يُحجز بالأسبقية |

ترتيب الحجز (من الأهم إذا اشتغل عدد أقل من الحسابات): **R1، R2، R3، R5، R4، R6، R7**.
لا ارتباط بين الدور وحساب بعينه. أول محادثة تُحجز أولاً تأخذ الدور، سواء كان حسابها يعمل أم لا. الحسابات المعطّلة لا تشغل أدواراً.

## الحجز (ذرّي ولا يمكن أن يأخذه اثنان)
الجلسة تنشئ ملف `docs/claims/<الدور>.json` عبر GitHub Contents API **بدون** `sha`. إن كان الملف موجوداً يرد GitHub بـ 422، أي أن الدور محجوز، فتجرّب الدور التالي. النص الجاهز في `docs/sessions/START_PROMPT.md`.
- الدور الذي لا يُنجز فيه شيء 48 ساعة (لا commit ولا تقرير) يستطيع M تحريره بحذف ملف الحجز مع commit باسم `[M] release Rn`.
- لا تحجز جلسة أكثر من دور واحد.

## صلاحيات المدير M
M يستطيع تعديل أي ملف، وإعادة التوزيع، وإلغاء أي تغيير، وحسم أي تعارض. قرارات M تُسجَّل في `docs/DECISIONS.md` وتُلزم الجميع.
الملفات المشتركة لا يعدّلها غير M: `pubspec.yaml`، `android/**` المولَّد، `android_overlay/app/src/main/AndroidManifest.xml`، `.github/**`، `HANDOFF.md`، `docs/TEAM.md`، `docs/ROADMAP_MULZIM.md`، `docs/DECISIONS.md`، `docs/reports/INDEX.md`، `analysis_options.yaml`.
إن احتاج دور تبعية جديدة أو صلاحية أو تعديلاً على ملف مشترك: يكتب ملف طلب في `docs/requests/` (انظر أدناه).

## الفروع والدمج
- القاعدة (التكامل): `feature/modern-redesign-hardening`. `main` لا يُدفع إليه إلا M.
- كل دور يعمل على فرعه: `session/r<n>-<اسم>` (مثل `session/r3-planner`)، وينشئ Pull Request إلى فرع التكامل، وM يدمج.
- يُسمح بالدفع المباشر إلى فرع التكامل **فقط** لملفات: `docs/claims/<دورك>.json`، `docs/reports/sessions/<دورك>/**`، `docs/requests/<دورك>-*.md`، `docs/contracts/<دورك>.md`.
- بداية العمل وقبل كل PR: `git pull --rebase origin feature/modern-redesign-hardening`.
- الـ commit يبدأ بالرمز: `[R3] وصف قصير`.
- شرط الـ PR: تمرير `flutter analyze` والاختبارات في CI، واختبارات جديدة لكل منطق جديد.
- أي ملف يملكه دور آخر لا تعدّله؛ اطلب (انظر الطلبات).

## ملكية المسارات
تُعدَّل المسارات الحالية بحسب مالكها، والميزات الجديدة تذهب إلى `lib/features/<مجال>/` يملكها دورها.
- **R1**: `lib/theme.dart`، `lib/widgets.dart`، `lib/main.dart`، `lib/pages/shell.dart`، `today_page`، `plan_page`، `courses_page`، `follow_page`، `calendar_page`، `settings_page`، `assets/fonts/**`، `lib/features/more/**`.
- **R2**: `lib/crawler/**`، `lib/sync_page.dart`، `lib/models.dart`، `lib/tree_page.dart`، `test/parser_test.dart`، `crawler_test.dart`، `due_test.dart`، `lib/features/moodle/**`.
- **R3**: `lib/planner.dart`، `lib/alerts.dart`، `lib/chapters.dart`، `lib/notifier.dart`، `Notifier.kt`، `test/planner_test.dart`، `alerts_test.dart`، `chapters_test.dart`، `lib/features/commitment/**`، `lib/features/stats/**`.
- **R4**: `lib/study_store.dart`، `lib/study_models.dart`، `lib/secrets.dart`، `lib/data_panel.dart`، `lib/app_state.dart`، `lib/core/database/**`، `lib/core/security/**`، `test/secrets_test.dart`، `data_safety_test.dart`.
- **R5**: `LockService.kt`، `MainActivity.kt`، `lib/pages/strict_page.dart`، `lib/lock_setup.dart`، `lib/strict_info.dart`، `lib/channel.dart`، `lib/features/study_lock/**`.
- **R6**: `lib/viewer/**`، `lib/features/media/**`، `library/**`، `downloads/**`، `documents/**`، `test/viewer_test.dart`.
- **R7**: `lib/ai.dart`، `lib/pages/mentor_page.dart`، `lib/features/ai/**`، `quiz/**`، `review/**`، `notebook/**`، `test/ai_test.dart`.

## العقود بين الأدوار
قبل أن يعتمد دور على آخر يُنشئ المالك ملف `docs/contracts/<الدور>.md` يصف الواجهة التي يقدّمها (أسماء الدوال والأنواع والأحداث)، ويكتب الآخرون على أساسه. تغيير عقد منشور يحتاج موافقة M.
العقود المطلوبة مبدئياً: R6 يقدّم `PlaybackEvents` (تشغيل/إيقاف/إطفاء الشاشة) لـ R5، و`VideoDuration` لـ R3. R4 يقدّم واجهات مخازن البيانات لـ R2 وR3 وR6 وR7. R1 يقدّم `docs/design/TOKENS.md` لكل من يبني شاشات.

## الطلبات
ملف `docs/requests/<دورك>-<رقم>.md` يتضمن: ما المطلوب، لماذا، من المخاطَب، الاستعجال. M يجيب برد داخل الملف نفسه ويسجّل القرار.

## التقارير (إلزامية على كل جلسة)
- المسار: `docs/reports/sessions/<الدور>/YYYY-MM-DD_HHMM_<الدور>_report-NN.md`، والرقم NN خاص بالدور.
- الوقت حقيقي من `TZ=Asia/Jerusalem date`، لا يُخمَّن.
- متى: تقرير بداية (الدور الذي حُجز والخطة) ثم تقرير عند كل إنجاز مهم وعند نهاية كل جلسة عمل، ولا تنتهي جلسة دون تقرير.
- المحتوى: ما أُنجز، الملفات المعدّلة والجديدة، الاختبارات ونتائجها (رابط تشغيل CI)، ما لم يُختبر على هاتف، المشكلات، طلبات لغيرك، الخطوة التالية. لا كلمة «مكتمل» لميزة لم تُختبر.
- M يجمع الفهرس في `docs/reports/INDEX.md`.

## الأمان
- لا مفاتيح ولا توكنات في الكود أو الـ commit أو التقارير.
- توكن GitHub لكل جلسة: Fine-grained، لهذا المستودع فقط، صلاحية Contents (قراءة وكتابة) وPull requests، بانتهاء قصير، ويُلغى بعد الانتهاء.
- لا تُستخدم أسماء الحسابات الشخصية أو بريدها داخل المستودع.
