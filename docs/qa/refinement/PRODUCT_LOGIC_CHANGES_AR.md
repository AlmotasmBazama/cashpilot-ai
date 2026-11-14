# تغييرات منطق المنتج

## نطاق القرار

التغييرات أدناه جاءت من عيوب قابلة لإعادة الإنتاج أو فجوات قبول محددة. لم تُبدل معادلات مالية أو سياسات ملكية بلا دليل، ولم يُعد بناء التطبيق أو تصميمه الشامل.

## 1. دورة حياة المعاملة العادية

- أصبح إنشاء المعاملة العادية يقبل `pending` أو `posted` فقط. الحالات النهائية مثل cancelled/reversed تحتاج كيانًا موجودًا وانتقالًا معلومًا، لذلك رفضها صار typed عند حدود repository.
- أضيف تحرير للمعاملة المعلقة/المنشورة غير التحويلية من شاشة التفاصيل. النموذج يعيد تعبئة amount/account/category/payee/date/note/location/status ويحافظ على id وcreatedAt والهوية المالية.
- التحرير المعلق يظل balance-neutral. التحويل من pending إلى posted يطبق القيمة المعدلة مرة واحدة. الرجوع من posted إلى pending يعكس الأثر القديم مرة واحدة. تكرار الحفظ لا يكرر mutation.
- التحويلات لا تمر عبر هذا النموذج لأن الزوج المالي له processor وهوية جماعية مختلفة.

## 2. Pagination والبحث

- لم يُغيّر الاستعلام الإنتاجي لأنه اجتاز corpus من 275 سجلًا: 50 ثم 250 ثم 275، بلا duplicates أو gaps، مع بحث/فلتر لاحق وترتيب amount عالمي وsecondary ID ثابت عند تساوي التاريخ.
- النتيجة المنطقية: pagination الحالي صالح؛ التغيير كان إغلاق فجوة إثبات، لا إعادة كتابة بلا داعٍ.

## 3. Dashboard وReports

- Retry/refresh في Dashboard يمسح accounts وcategories قبل snapshot، بدل إعادة قراءة derived state فوق AppFailure مخبأ.
- Retry في Reports يطبق نفس العقد.
- التقرير السنوي يعرض Yearly income/expense/savings بدل Monthly labels. قيم التقرير نفسها لم تتغير.

## 4. التصنيفات

- بذر التصنيفات الافتراضية صار conflict-tolerant عبر insert-or-ignore. هذا يغلق سباق first-use بين Dashboard/Reports/opening ledger من دون تغيير مجموعة التصنيفات أو نطاق المالك.

## 5. الإيصالات

- الواجهة تعرض المرحلة الحالية: اختيار/تهيئة، حفظ draft، تحميل context، تحليل.
- الإلغاء يفصل المستخدم فورًا، يلغي lease، ويمنع persistence/provider بعد الإلغاء؛ أي bytes متأخرة تُصفّر/تُهمل.
- لا يُدعى أن OCR حي مقبول؛ الذي ثبت هو عقد UX/cancellation والعامل المعزول.

## 6. AI

- لم يُفعل financial execution ولم تُخفف consent/owner gates.
- المسار الحقيقي المثبت بقي: preference auto، Groq غير مفعّل، general conversation إلى Firebase، model `gemini-3.6-flash`.
- الأسئلة العربية والإنجليزية غير التحية نجحت، والفشل دون شبكة ظهر retryable، وRetry ثم reopen نجحا.

## حصيلة المنطق

تم إغلاق **6 مشكلات منطقية أساسية**: تحرير pending، منع الحالة الابتدائية النهائية، عكس posted→pending، استعادة Dashboard، استعادة Reports، وصحة labels السنوية. تحسين UX الإيصال ومواءمات التوثيق مسجلة منفصلة حتى لا تُضخم هذا العد.
