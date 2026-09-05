# Privacy Policy — Sijil IT / سياسة الخصوصية

---

## English

### 1. What Sijil IT is

Sijil IT is a workplace IT-asset management client. It does not have servers of
its own. It connects, over XML-RPC, to the **Odoo instance operated by the
organisation that deployed it** — your employer. All business data you see or
enter (assets, employees, maintenance requests, handovers) lives on that Odoo
server and is governed by your organisation's own privacy policy, not by this
one.

### 2. Data the app handles

#### Odoo server URL, database name, username, password / API key
Used to sign you in to your organisation's Odoo. Sent only to that Odoo server, and stored on the device inside the operating system's own keystore — Android EncryptedSharedPreferences, iOS Keychain. Kept until you sign out or uninstall the app.

#### Asset, employee and maintenance records
The core function of the app. Read from and written to your organisation's Odoo. A copy is cached on the device so the app works without a connection, and that copy is cleared when you sign out.

#### Photos you attach when returning an asset
Evidence of the asset's condition on the return record. Uploaded to your organisation's Odoo as an attachment. The app keeps no separate copy.

#### Handover signatures you draw
Proof that a handover took place. Uploaded to your organisation's Odoo. The app keeps no separate copy.

#### Camera frames while scanning a QR or barcode
Used only to decode the code, and processed entirely on the device. No frame is ever stored or transmitted.

#### Microphone audio while you hold the voice-search button
Used only to turn speech into a search term. The audio is handed to the device's own speech-recognition service, which is part of the operating system; the app receives the resulting text and never stores or transmits the audio.

#### Biometric or device-unlock check ("Require unlock")
Used only to lock the app. Handled entirely by Android or iOS — the app receives a pass or fail result and never sees your fingerprint, face, PIN or password.

#### Crash reports and diagnostics
Sent **only in builds where crash reporting is enabled at build time**; a build without a reporting key sends nothing at all. Where it is enabled, reports go to Sentry with screenshots, view hierarchies, network request bodies and tap-by-tap breadcrumbs all switched off, and every report is stripped of credentials before it leaves the device. Retained according to Sentry's retention period.

### 3. What the app does *not* do

- No advertising, no advertising identifier, no ad SDKs.
- No analytics or user-behaviour tracking.
- No selling or sharing of data with third parties for advertising or any other purpose.
- No location collection.
- No contacts, calendar, SMS or call-log access. (The *Email* and *Call* buttons on an employee's profile simply open your own mail app or dialler with the address already filled in — the app does not place the call or read your contacts.)

### 4. Permissions and why

- **Camera** — scanning asset QR/barcodes, and taking a return photo. Asked for when you first scan.
- **Microphone** — voice search only. Asked for when you press the microphone button.
- **Notifications** — warranty-expiry reminders. Asked for only when you turn that switch on in Settings.
- **Internet / network state** — talking to your Odoo server.

Each is optional: decline it and only that one feature is unavailable.

### 5. Children

Sijil IT is a workplace tool intended for employees aged 18 and over. It is not
directed at children and does not knowingly collect data from them.

### 6. Your rights

Because the data belongs to your organisation's Odoo instance, requests to
access, correct or delete it should go to your organisation's IT or data
protection contact. Removing the app's local copy is immediate: sign out, or
uninstall the app.

### 7. Changes

Material changes to this policy will be published at this URL with an updated
date above.

### 8. Contact

m.badr@digital-harbor.net

---

## العربية

### 1. ما هو تطبيق Sijil IT

تطبيق «سجل IT» هو عميل لإدارة الأصول التقنية داخل المؤسسة. لا يملك التطبيق
خوادم خاصة به، بل يتصل عبر XML-RPC بخادم **Odoo الخاص بالمؤسسة التي فعّلته**
— أي جهة عملك. جميع بيانات العمل التي تراها أو تدخلها (الأصول، الموظفون، طلبات
الصيانة، التسليم والاستلام) محفوظة على خادم Odoo هذا وتخضع لسياسة خصوصية
مؤسستك، لا لهذه السياسة.

### 2. البيانات التي يتعامل معها التطبيق

#### عنوان خادم Odoo واسم قاعدة البيانات واسم المستخدم وكلمة المرور أو مفتاح الـ API
تُستخدم لتسجيل دخولك إلى Odoo الخاص بمؤسستك، وتُرسل إلى ذلك الخادم وحده. وتُخزَّن على الجهاز داخل مخزن المفاتيح الخاص بنظام التشغيل — EncryptedSharedPreferences على أندرويد، وKeychain على iOS — وتظل محفوظة حتى تسجّل الخروج أو تحذف التطبيق.

#### سجلات الأصول والموظفين والصيانة
هي وظيفة التطبيق الأساسية، وتُقرأ من خادم Odoo الخاص بمؤسستك وتُكتب إليه. ويُحفَظ منها نسخة مؤقتة على الجهاز ليعمل التطبيق دون اتصال، وتُمحى هذه النسخة عند تسجيل الخروج.

#### الصور التي ترفقها عند إرجاع أصل
لتوثيق حالة الأصل في سجل الإرجاع، وتُرفع كمرفق على Odoo الخاص بمؤسستك. ولا يحتفظ التطبيق بنسخة منفصلة منها.

#### التوقيع الذي ترسمه عند التسليم
لإثبات حدوث عملية التسليم، ويُرفع إلى Odoo الخاص بمؤسستك. ولا يحتفظ التطبيق بنسخة منفصلة منه.

#### صورة الكاميرا أثناء مسح رمز QR أو الباركود
تُستخدم لقراءة الرمز فقط، وتُعالَج بالكامل على الجهاز. ولا تُحفَظ أي لقطة ولا تُرسل إلى أي جهة.

#### الصوت أثناء الضغط على زر البحث الصوتي
يُستخدم لتحويل الكلام إلى نص بحث فقط. ويُسلَّم الصوت لخدمة التعرّف على الكلام في نظام التشغيل نفسه، فيستقبل التطبيق النص الناتج ولا يحفظ الصوت ولا يرسله.

#### التحقق بالبصمة أو بقفل الجهاز (خيار «طلب فتح القفل»)
يُستخدم لقفل التطبيق فقط، ويتم بالكامل داخل أندرويد أو iOS. ويستقبل التطبيق نتيجة نجاح أو فشل، ولا يرى بصمتك أو وجهك أو رمزك أو كلمة مرورك.

#### تقارير الأعطال والتشخيص
تُرسَل **فقط في النسخ التي فُعِّل فيها تقرير الأعطال وقت البناء**، والنسخة التي لا تحمل مفتاح تقارير لا ترسل شيئًا على الإطلاق. وفي النسخ المفعَّلة تذهب التقارير إلى Sentry مع تعطيل لقطات الشاشة وبنية الواجهة ومحتوى طلبات الشبكة وتتبّع النقرات، وتُنقّى كل تقرير من بيانات الدخول قبل مغادرته الجهاز. وتُحفَظ حسب مدة الاحتفاظ لدى Sentry.

### 3. ما لا يفعله التطبيق

- لا إعلانات ولا معرِّف إعلاني ولا حِزم إعلانية.
- لا تحليلات ولا تتبُّع لسلوك المستخدم.
- لا بيع للبيانات ولا مشاركتها مع أطراف ثالثة لأي غرض.
- لا يجمع الموقع الجغرافي.
- لا وصول إلى جهات الاتصال أو التقويم أو الرسائل أو سجل المكالمات. (زرّا «البريد» و«الاتصال» في ملف الموظف يفتحان تطبيق البريد أو الهاتف لديك فقط.)

### 4. الأذونات وسببها

- **الكاميرا** — مسح رموز الأصول وتصوير حالة الإرجاع، ويُطلب عند أول عملية مسح.
- **الميكروفون** — البحث الصوتي فقط، ويُطلب عند الضغط على زر الميكروفون.
- **الإشعارات** — تذكيرات انتهاء الضمان، وتُطلب فقط عند تفعيل الخيار من الإعدادات.
- **الإنترنت وحالة الشبكة** — الاتصال بخادم Odoo.

كل إذن اختياري؛ رفضه يعطّل تلك الميزة وحدها.

### 5. الأطفال

التطبيق أداة عمل موجَّهة للموظفين من عمر 18 سنة فأكثر، وليس موجَّهًا للأطفال
ولا يجمع بياناتهم عن قصد.

### 6. حقوقك

لأن البيانات مملوكة لخادم Odoo الخاص بمؤسستك، تُوجَّه طلبات الاطلاع أو التصحيح
أو الحذف إلى إدارة تقنية المعلومات أو مسؤول حماية البيانات في مؤسستك. أما النسخة
المحلية على جهازك فيمكنك إزالتها فورًا بتسجيل الخروج أو حذف التطبيق.

### 7. التعديلات

تُنشر أي تعديلات جوهرية على هذا الرابط مع تحديث التاريخ أعلاه.

### 8. التواصل

m.badr@digital-harbor.net
