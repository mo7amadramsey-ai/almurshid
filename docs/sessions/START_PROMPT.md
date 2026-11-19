# الرسالة الجاهزة لأي جلسة جديدة (انسخها كما هي إلى المحادثة)

```
أنت جلسة تطوير في مشروع «المرشد» الذي سيصبح «المُلزم»، المستودع: github.com/mo7amadramsey-ai/almurshid
افعل بالترتيب ولا تتخطَّ شيئاً:
1) استنسخ المستودع واقرأ: HANDOFF.md ثم docs/TEAM.md ثم docs/ROADMAP_MULZIM.md ثم docs/DECISIONS.md.
2) احجز دورك بتشغيل النص التالي في bash (ضع التوكن الذي سأعطيك إياه في GH). أول من ينجح يأخذ الدور:
   REPO=mo7amadramsey-ai/almurshid; BR=feature/modern-redesign-hardening; ROLE=""
   for R in R1 R2 R3 R5 R4 R6 R7; do
     BODY=$(R=$R BR=$BR python3 -c "import json,base64,os,datetime; c=json.dumps({'role':os.environ['R'],'claimedAt':datetime.datetime.now(datetime.timezone.utc).isoformat()}); print(json.dumps({'message':'['+os.environ['R']+'] claim role','branch':os.environ['BR'],'content':base64.b64encode(c.encode()).decode()}))")
     CODE=$(curl -s -o /tmp/claim.json -w '%{http_code}' -X PUT -H "Authorization: Bearer $GH" -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$REPO/contents/docs/claims/$R.json" -d "$BODY")
     if [ "$CODE" = "201" ]; then ROLE=$R; echo "تم حجز الدور $R"; break; fi
     if [ "$CODE" != "422" ]; then echo "خطأ $CODE"; cat /tmp/claim.json; break; fi
     echo "الدور $R محجوز، أجرّب التالي"
   done
   - إن كانت كل الأدوار محجوزة: أخبر المستخدم ولا تعمل شيئاً.
   - إن ظهر خطأ غير 422 (مثل 401 أو 403): أخبر المستخدم بدل المتابعة.
3) اقرأ ملف دورك: docs/sessions/<الدور>_*.md ونفّذ ما فيه فقط، ضمن المسارات التي تملكها.
4) اعمل على فرع session/<دورك> وادمج عبر Pull Request إلى feature/modern-redesign-hardening؛ المدير M يدمج.
5) اكتب تقريراً فور الحجز، وتقريراً عند كل إنجاز مهم وعند نهاية الجلسة في docs/reports/sessions/<دورك>/ (الوقت من: TZ=Asia/Jerusalem date).
6) لا تذكر في أي ملف أسراراً أو بريداً إلكترونياً. لا تقل «مكتمل» لما لم يُختبر.
```

التوكن: أنشئه من GitHub ← Settings ← Developer settings ← Fine-grained tokens، لهذا المستودع فقط، Contents وPull requests (قراءة وكتابة)، انتهاء 14 يوماً، وأعطه للجلسة في المحادثة ثم ألغِه بعد الانتهاء.
