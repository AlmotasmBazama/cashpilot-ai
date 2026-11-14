# دليل قبول HTTP والأمن

الهدف: الرابط الثابت للمراجعة التجريبية؛ لا أسرار محفوظة.

| الطلب | النتيجة |
|---|---|
| health | 200 / ok / no-store |
| PUT على مسار الحذف | 405 / gatewayRequestInvalid |
| text/plain POST | 415 / gatewayRequestInvalid |
| JSON غير صالح | 400 / gatewayRequestInvalid |
| جسم أكبر من الحد | 413 / requestTooLarge |
| مسار غائب | 404 / gatewayRequestInvalid |
| Auth مفقود | 401 / authenticationRequired |
| Auth غير صالح | 401 / authenticationRequired |
| Auth صالح وApp Check مفقود | 401 / appCheckUnavailable |
| Auth صالح وApp Check غير صالح | 401 / appCheckUnavailable |
| طلب Android صالح | 200 / completed |

أُنشئ مستخدم Auth قصير العمر للاختبارات السلبية التي احتاجت token صالحاً ثم
حُذف مباشرة. لم تُكتب قيمة token إلى ملف أو stdout. الطلب الحي الإيجابي عبر
Android أثبت Auth وApp Check والإثبات معاً.

