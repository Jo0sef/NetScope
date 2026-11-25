package com.jo0sef.netscope;

import java.util.HashMap;
import java.util.Map;

public class I18n {
    static boolean ar = false;
    static final Map<String, String> M = new HashMap<>();
    static {
        String[][] p = {
            {"Devices", "الأجهزة"}, {"Speed", "السرعة"}, {"Tools", "الأدوات"}, {"Settings", "الإعدادات"}, {"Speed Test", "اختبار السرعة"},
            {"devices online", "جهاز متصل"}, {"Scan network", "فحص الشبكة"}, {"Scanning…", "جاري الفحص…"}, {"Scan again", "فحص مرة أخرى"},
            {"All", "الكل"}, {"New", "جديد"}, {"Slow", "بطيء"}, {"Not connected to Wi-Fi", "غير متصل بالواي فاي"},
            {"YOU", "أنت"}, {"ROUTER", "راوتر"}, {"NEW", "جديد"},
            {"Ping", "Ping"}, {"Port scan", "فحص المنافذ"}, {"Rename", "تغيير الاسم"}, {"Copy IP", "نسخ العنوان"},
            {"Tap Ping or Port scan.", "اضغط Ping أو فحص المنافذ."}, {"IP copied.", "تم نسخ العنوان."},
            {"Rename device", "تغيير اسم الجهاز"}, {"Cancel", "إلغاء"}, {"Save", "حفظ"}, {"OK", "حسنًا"}, {"Copied", "تم النسخ"}, {"Cleared", "تم المسح"},
            {"Start test", "ابدأ الاختبار"}, {"Testing…", "جاري الاختبار…"}, {"Test again", "اختبر مرة أخرى"},
            {"PING (ms)", "البنج (مللي ثانية)"}, {"JITTER (ms)", "الجيتر (مللي ثانية)"}, {"DOWNLOAD (Mbps)", "التحميل (ميجابت/ث)"}, {"UPLOAD (Mbps)", "الرفع (ميجابت/ث)"},
            {"History", "السجل"}, {"No tests yet.", "لا توجد اختبارات بعد."}, {"Ready", "جاهز"}, {"Measuring latency…", "جاري قياس التأخير…"},
            {"Download  Mbps", "التحميل ميجابت/ث"}, {"Upload  Mbps", "الرفع ميجابت/ث"}, {"Done", "تم"},
            {"Host or IP  (e.g. google.com)", "الدومين أو الـ IP (مثال: google.com)"}, {"DNS", "DNS"}, {"Ports", "المنافذ"}, {"Trace", "تتبع المسار"},
            {"My public IP", "عنوان IP العام"}, {"Network tools. Enter a host, then pick a tool.", "أدوات الشبكة. اكتب العنوان ثم اختر الأداة."},
            {"Enter a host first.", "اكتب العنوان أولاً."}, {"Checking…", "جاري الفحص…"}, {"Scanning common ports…", "جاري فحص المنافذ الشائعة…"},
            {"No open ports found.", "لا توجد منافذ مفتوحة."}, {"Could not resolve host.", "تعذر الوصول للعنوان."}, {"No internet connection.", "لا يوجد اتصال بالإنترنت."},
            {"Appearance", "المظهر"}, {"Automatic", "تلقائي"}, {"Light", "فاتح"}, {"Black", "أسود"}, {"Color theme", "لون التطبيق"}, {"Language", "اللغة"},
            {"Developer", "المطور"}, {"Clear history and names", "مسح السجل والأسماء"},
            {"This phone", "هذا الموبايل"}, {"Router", "راوتر"}, {"Smart TV", "تلفزيون ذكي"}, {"Chromecast / Cast", "كروم كاست"}, {"Android phone", "موبايل أندرويد"},
            {"Windows PC", "كمبيوتر ويندوز"}, {"Smart speaker", "سماعة ذكية"}, {"Printer", "طابعة"}, {"Apple TV / AirPlay", "Apple TV / AirPlay"},
            {"iPhone / iPad", "آيفون / آيباد"}, {"IP camera", "كاميرا مراقبة"}, {"Computer / NAS", "كمبيوتر / NAS"}, {"Server / Linux", "سيرفر / لينكس"},
            {"Apple device", "جهاز أبل"}, {"Web device", "جهاز ويب"}, {"Unknown", "غير معروف"}, {"Mac", "ماك"}, {"iPhone", "آيفون"}, {"iPad", "آيباد"},
            {"No open ports found in quick scan", "لا توجد منافذ مفتوحة في الفحص السريع"},
            {"Open ports: ", "المنافذ المفتوحة: "}, {"Vendor: ", "الشركة: "}, {"MAC: ", "MAC: "}, {"Private (random) MAC", "MAC خاص (عشوائي)"},
            {"MAC not available on this Android version", "عنوان MAC غير متاح في نسخة أندرويد دي"},
            {"WhatsApp username: ", "يوزر الواتساب: "}, {"Download failed: ", "فشل التحميل: "}, {"Upload failed: ", "فشل الرفع: "}, {"no server reachable", "مفيش سيرفر متاح"},
            {"Share", "مشاركة"}, {"Back", "رجوع"}, {"Wi-Fi", "واي فاي"}, {"My IP ", "عنوان جهازي "}, {"Subnet ", "القناع "},
            {"Allow location to show the Wi-Fi name", "اسمح بالموقع لإظهار اسم الواي فاي"},
            {"About", "عن التطبيق"}, {"Facebook", "فيسبوك"}, {"Instagram", "إنستجرام"}, {"WhatsApp", "واتساب"}, {"Trusted", "موثوق"},
            {"NetScope finds devices on your Wi-Fi using ping, TCP probes, ARP and Bonjour, and measures speed against public servers. Everything runs on your phone, nothing is uploaded.",
             "NetScope بيدوّر على الأجهزة المتصلة بالواي فاي بالـ ping وفحص المنافذ والـ ARP وBonjour، وبيقيس السرعة على سيرفرات عامة. كل حاجة بتشتغل على موبايلك ومفيش حاجة بتترفع."}
        };
        for (String[] x : p) M.put(x[0], x[1]);
    }
    static String t(String s) {
        if (!ar || s == null) return s;
        String r = M.get(s);
        return r != null ? r : s;
    }
}
