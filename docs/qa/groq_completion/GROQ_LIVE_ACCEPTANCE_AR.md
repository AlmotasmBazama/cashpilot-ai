# قبول Groq الحي — Android وCloud Run

التاريخ: 2026-08-14 (Africa/Tripoli).

## نطاق القبول

نُفذت الاختبارات على Pixel_6 Android emulator (`emulator-5554`) بنظام Android
17/API 37، وعلى مراجعة Cloud Run المرشحة
`cashpilot-ai-gateway-staging-00005-civ` في `europe-west1`. بقيت المراجعة عند
0% من الحركة أثناء التصحيح، ثم نُقلت إليها 100% بعد نجاح البوابات. الرابط
الثابت بعد الترويج نجح 3/3 وبقيت المراجعة القديمة نقطة تراجع بلا حركة موجبة.

لا تحتوي الأدلة على مفاتيح أو Firebase tokens أو App Check tokens أو UIDs أو
نصوص المطالبات/الردود. المستخدمون الاصطناعيون حُذفوا best-effort ونجحت عمليات
الحذف المسجلة.

## ملخص النتائج

| البوابة | النتيجة | الدليل الآمن |
|---|---|---|
| صحة المرشح | PASS | 3/3 HTTP 200؛ 574/117/102ms؛ ready=true؛ no-store |
| Models API | PASS | 20b و120b ACTIVE |
| HTTP/Auth/CORS | PASS | 24/24 أُعيدت على stable/`00005-civ=100%`؛ صفر طلب مؤهل لـGroq |
| valid Android Auth + App Check | PASS | token issuance وقبول endpoint |
| missing/invalid App Check مع valid Auth | PASS | 401/gatewayAppCheckRequired للحالتين |
| العربية عبر Groq SSE | PASS | 1657ms أول محتوى؛ 2113ms اكتمال |
| الإنجليزية عبر Groq SSE | PASS | 1430ms أول محتوى؛ 1435ms اكتمال |
| إلغاء stream حي عام | PASS | cancel 9ms؛ صفر late/completed/failure بعده |
| Offline ثم Retry | PASS | typed gatewayUnreachable؛ user turn واحد؛ نجاح Retry |
| rate limit والعزل | PASS | 20 ثم 429/Retry-After؛ مستخدم ثانٍ معزول |
| force-stop/launcher reopen | PASS | PID القديم غاب؛ MAIN/LAUNCHER؛ PID جديد مختلف؛ سؤال ثانٍ مكتمل |
| Firebase text fallback | PASS config/routing | false؛ Groq-only harness؛ لا Firebase AI text object |
| Receipt Vision | UNCHANGED | Firebase؛ لم يُنفذ Groq Vision |

## أوامر القبول الحي

شُغلت الأدوات المنقحة التالية مع رابط المرشح HTTPS؛ كل واحدة تعيد فقط markers
مغلقة الحقول:

```text
node tool/run_android_live_groq_acceptance.cjs --gateway-url <candidate-url>
node tool/run_android_live_groq_failure_recovery.cjs --gateway-url <candidate-url>
node tool/run_android_live_groq_rate_limit.cjs --gateway-url <candidate-url>
node tool/run_android_live_groq_force_stop_reopen.cjs --gateway-url <stable-url> --execute-live --promotion-confirmed --dedicated-device
```

لم يُطبع stderr الخاص بـApp Check لأن SDK قد يكتب debug secret فيه. runner
يقرأ المخزن الذي يديره SDK، ويسجل secret في Firebase في الذاكرة، ويحافظ على
التسجيل بدل حذفه. عندما تزيل Flutter الحزمة بين الاختبارات، ينتظر runner
bootstrap جديدًا بحد زمني بدل تخمين الرمز.

## العربية والإنجليزية والبث

| اللغة | provider | sessions | raw deltas | Flutter partials | bytes | TTFC | completion |
|---|---|---:|---:|---:|---:|---:|---:|
| ar | Groq | 1 | 240 | 8 | 1471 | 1657ms | 2113ms |
| en | Groq | 1 | 21 | 1 | 300 | 1430ms | 1435ms |

كل حالة بدأت مرة واكتملت مرة، ولم تسجل failure event أو duplicate. سجل Cloud
المنقح أثبت اختيار `openai/gpt-oss-20b` وupstream success. الفروق بين عدد
upstream chunks وعدد Flutter deltas متوقعة بسبب تجميع/حدود SSE ولا تعني
إرسالًا مكررًا.

## Auth وApp Check وCORS

الـ24 probe غطت المسارات الأربعة المحمية وnative no-Origin وallowed/disallowed
origin وpreflight والطرق/content-types والأجسام غير الصحيحة/الكبيرة. لأن auth
يفحص أولًا، أضاف Android test دليلًا منفصلًا باستخدام valid ID token:

- header App Check مفقود: 401 + `gatewayAppCheckRequired`.
- header App Check غير صالح: 401 + `gatewayAppCheckRequired`.
- DebugProvider صالح ومسجل: الطلب العربي والإنجليزي وصلا واكتملا.

لم تُرسل Firebase ID/App Check tokens أو UID إلى Groq؛ client يرسلها إلى
gateway فقط، والبوابة تنشئ طلب Groq من الرسائل المنقحة دون principal.

## Offline وRetry

غيّر host runner حالة شبكة المحاكي فعلًا:

1. أثبت reachability أولًا.
2. فعّل airplane mode وعطل Wi-Fi/data.
3. ظهر loading ومنع double-send.
4. انتهى الفشل بـ`gatewayUnreachable` و`retryable=true`، مع user turn واحد.
5. أعاد الشبكة وانتظر health بصورة bounded.
6. ضغط Retry مرة؛ بدأت session ثانية واكتمل جواب واحد دون duplicate.
7. أثبت New Conversation cleanup، ثم أعاد الشبكة في `finally` وحذف المستخدم.

## الإلغاء وlate chunks

المجس الحي ألغى subscription فور أول text delta:

- first content: 1246ms.
- cancel completion: 9ms.
- قبل الإلغاء: delta واحد/4 bytes.
- بعد الإلغاء: completed=0، failure=0، late=0.

اختبارات action-specific منفصلة أثبتت discard عند navigate-away، محادثة جديدة،
stop، logout/account switch، والخلفية. هذه تستخدم fake non-cooperative streams؛
لذلك لا تُسجّل كأن كل trigger نُفذ حيًا ضد Groq. دليل الخادم على abort يضاف من
السجل الآمن إن كان متاحًا.

## rate limit

استخدم الاختبار route اختيار الأدوات المعطل كي يختبر limiter بلا كلفة Groq:

- المستخدم A: أول 20 طلبًا مرّت من limiter.
- الطلب 21: HTTP 429 + `groqRateLimited` + `Retry-After` موجب.
- المستخدم B: أول طلب لم يكن 429، فأثبت العزل.
- لا حلقة retry ولا إرسال تلقائي من Flutter، وعدد Groq calls في الاختبار صفر.

## المشكلات التي كشفها القبول وأُصلحت

1. App Check SDK store يختفي بعد uninstall التلقائي: أضيف bootstrap/poll/register
   آمن لا يطبع secret.
2. `تم` كان يطابق داخل `يتم/تتم` ويحظر شرح الفائدة العربي: أضيفت حدود Unicode.
3. phone regex كان يفحص UUID، ومحاكاة 100,000 UUID رفضت 36.81% خطأ: أصبح
   التنقيح path-aware، وبقي نفس النمط مرفوضًا داخل message/financial label.
4. أمر airplane mode في recovery runner كان معكوسًا وفحص health لحظيًا:
   صُححت الأوامر وأضيف انتظار bounded.
5. dispose عدّل Riverpod أثناء بناء الشجرة: أصبح cancel microtask مع mounted
   guard واختبار navigate-away.

## ما يثبته غياب Firebase AI text وما لا يثبته

في قبول Groq:

- كل flags هي Groq-only وfallback=false.
- model gateway المبني هو Groq، ولا يُنشأ Firebase AI model/backend object.
- سجل Cloud Run أثبت model 20b والنجاح.
- اختبارات routing تعدّ مكالمات Firebase وتثبت صفرًا عند fallback=false.

لا يوجد packet capture كامل لكل egress في full production Riverpod graph؛ لذلك
الدليل مركب من configuration + construction + counters + Cloud trace، وليس
ادعاءً بوجود اعتراض شبكي شامل للنظام.

## حالة تحويل الحركة

### force-stop والفتح من المشغّل

شُغّل debug APK مقيّد بعلم قبول compile-time، مع widgets والراوتر الفعليين وAndroid
Debug App Check. اكتمل السؤال الأول في واجهة التطبيق خلال 17418ms. بعد
`am force-stop` ثبت غياب PID القديم، ثم فُتح التطبيق عبر intent
`MAIN/LAUNCHER` وظهر PID جديد مختلف خلال 3709ms. استُعيدت الجلسة واكتمل سؤال
Groq ثانٍ خلال 17076ms؛ بقي `provider=groq` و`route=generalConversation` و
`firebaseFallback=false`.

سجلات `00005-civ` في نافذة التشغيل أعادت traceين بالضبط: كلاهما 20b/HTTP 200/
completed/upstream success/retry=0. كان duration/TTFC/completion للخادم
497/368/129ms ثم 495/317/178ms، مع 93 ثم 189 chunk. لم تُستعلم أو تُسجل IDs أو
UID أو محتويات. نجح حذف وثيقة Firestore الاصطناعية مع تأكيد 404، وحذف مستخدم
Auth، وتنظيف App Check وUI dump وlogcat والحزمة. هذا إثبات debug/staging، وليس
إثبات signed release أو Play Integrity، ولم يحدث force-stop أثناء طلب نشط.

اكتمل التحويل إلى `00005-civ=100%` في 22.021s، ونجحت صحة الرابط الثابت
331/106/92ms مع config/IAM/digest مطابقين. اكتملت بوابات الاستخدام الداخلي على
المحاكي. يبقى التراجع الجاهز إلى `cashpilot-ai-gateway-staging-00002-sww=100%`
إذا ظهر محفز تشغيلي لاحق.
