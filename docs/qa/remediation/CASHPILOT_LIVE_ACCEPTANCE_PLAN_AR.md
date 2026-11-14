# خطة القبول الحي بعد المعالجة

## المتطلبات المسبقة

- مشروع Firebase staging معزول ومثبت الاسم، لا production.
- حسابان اصطناعيان A وB وبيانات مالية/إيصالات اصطناعية فقط.
- App Check staging/debug token مسجل عبر القناة الآمنة دون طباعته.
- Gateway staging على Node 20 وHTTPS وorigin دقيق وSecret Manager؛ لا مفتاح داخل Flutter أو الأدلة.
- جهاز Android فعلي/AVD متصل، وmacOS/iOS منفصل عند القبول الشامل.
- قواعد Firestore المنشورة مطابقة للملف المحلي، مع خطة cleanup قابلة للتحقق.

## مصفوفة القبول

1. **A→B isolation — AI-001/002, OF-009/014/021:** أوقف كل await boundary عمدًا؛ لا قراءة B لطلب A، لا upload لصورة A بسياق B، لا policy/consent/default متوارث، ولا late UI/provider event.
2. **Deletion identity — OF-006/008/012:** ابدأ A ثم بدّل إلى B؛ إما يكمل A فقط أو يفشل قبل mutation، ولا يُحذف B. كل public entry يمر بمسار واحد.
3. **No resurrection — OF-007/026/027/029/036:** pending upload متوقف ثم deletion/opt-out؛ صفر write بعد fence، لا sensitive tombstone fields، وunknown nested child يُحذف recursive.
4. **Auth/App Check:** valid staging token يمر؛ missing/invalid/revoked/wrong-audience يفشل قبل provider؛ logs لا تعرض tokens.
5. **Groq — GW-01/02/03:** corpus عربي/إنجليزي للأرقام والادعاءات والسياق؛ unsupported fact وfalse execution claim وunknown/private context تُرفض قبل العرض/المزوّد.
6. **Streaming — AI-011/012 وGW-04/05/06:** لا text قبل source validation، لا cross-model fallback بعد أول byte، disconnect يلغي upstream، والحدود/timeout مصنفة صحيحًا.
7. **Receipts — AI-002 وOF-014/017/018/034/035:** consent مستقل، provider الصحيح، camera/gallery synthetic، retention choice مثبت، crash/restart يستعيد cleanup دون orphan أو cross-owner state.
8. **Deployed rules/backup:** owner/cross-user/anonymous/list/batch/transaction tests على staging المعزول، ثم مقارنة version/hash للقواعد المنشورة.
9. **Node/container:** gateway test/lint/typecheck/build/secret-scan/audit داخل Node 20 image، ثم CORS/HTTPS/ingress/multi-instance rate-limit acceptance.
10. **Devices/accessibility:** Android وiOS وWeb المدعوم، RTL/LTR، 320px/tablet، large text، keyboard/screen reader، background/restart.

## دليل القبول والتنظيف

- احفظ فقط IDs اصطناعية غير قابلة للربط، counts، exit codes، timestamps، وhashes/config names غير السرية.
- لا تحفظ UID أو token أو prompt/response أو صورة/نص إيصال أو مبالغ حقيقية.
- بعد كل run احذف الحسابات والبيانات الاصطناعية عبر workflow الاختبار، ثم اثبت صفر descendants وصفر writers وصفر ملفات محلية.
- أي prerequisite غائب يبقى Blocked؛ لا يتحول إلى Pass بمحاكاة unit.

## قرار البوابات

حتى تنفيذ هذه الخطة بعد نجاح الإصلاح المحلي: Financial AI=NO-GO، staging=NO-GO، production=NO-GO.

