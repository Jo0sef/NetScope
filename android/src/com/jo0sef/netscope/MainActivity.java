package com.jo0sef.netscope;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.*;
import android.text.InputType;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.net.*;
import java.text.SimpleDateFormat;
import java.util.*;

import static com.jo0sef.netscope.UI.*;

public class MainActivity extends Activity {
    SharedPreferences prefs;
    final Handler main = new Handler(Looper.getMainLooper());
    FrameLayout content;
    LinearLayout tabBar;
    View[] pages = new View[4];
    TextView[] tabViews = new TextView[4];
    ImageView[] tabIcons = new ImageView[4];
    int curTab = 0;
    final ArrayList<View> stack = new ArrayList<>();
    FrameLayout root;

    // devices page state
    final ArrayList<Net.Dev> devices = new ArrayList<>();
    LinearLayout devList; TextView devCount, devNet; TextView scanBtn; ProgressBar prog;
    Seg filter; boolean scanning; Net.Bonjour bonjour;
    long lastRebuild;

    // speed page state
    Gauge gauge; TextView sPing, sJit, sDl, sUl, hist, speedBtn; Speed speed;

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        prefs = getSharedPreferences("p", 0);
        UI.dens = getResources().getDisplayMetrics().density;
        I18n.ar = prefs.getBoolean("arabic", false);
        UI.accent = ACCENTS[Math.max(0, Math.min(ACCENTS.length - 1, prefs.getInt("accent", 0)))];
        int ap = prefs.getInt("appearance", 2);
        UI.dark = ap == 2 || (ap == 0 && (getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES);
        build(prefs.getInt("tab", 0));
    }

    void build(int tab) {
        Window w = getWindow();
        w.setStatusBarColor(bg()); w.setNavigationBarColor(bg());
        int flags = dark ? 0 : (View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | (Build.VERSION.SDK_INT >= 26 ? View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR : 0));
        w.getDecorView().setSystemUiVisibility(flags);
        root = new FrameLayout(this);
        root.setBackgroundColor(bg());
        root.setLayoutDirection(I18n.ar ? View.LAYOUT_DIRECTION_RTL : View.LAYOUT_DIRECTION_LTR);
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        content = new FrameLayout(this);
        col.addView(content, new LinearLayout.LayoutParams(-1, 0, 1));
        tabBar = new LinearLayout(this);
        tabBar.setOrientation(LinearLayout.HORIZONTAL);
        tabBar.setBackgroundColor(dark ? 0xFF0B0B0C : 0xFFF4F4F6);
        String[] names = {"Devices", "Speed", "Tools", "Settings"};
        int[] icons = {R_ic_wifi(), R_ic_speed(), R_ic_tools(), R_ic_gear()};
        for (int i = 0; i < 4; i++) {
            final int idx = i;
            LinearLayout cell = new LinearLayout(this);
            cell.setOrientation(LinearLayout.VERTICAL);
            cell.setGravity(Gravity.CENTER);
            cell.setPadding(0, dp(8), 0, dp(6));
            ImageView iv = new ImageView(this);
            iv.setImageResource(icons[i]);
            cell.addView(iv, new LinearLayout.LayoutParams(dp(26), dp(26)));
            TextView t = new TextView(this);
            t.setGravity(Gravity.CENTER);
            t.setText(I18n.t(names[i]));
            t.setTextSize(11);
            t.setSingleLine(true);
            cell.addView(t, lp(-2, -2, 0, 2, 0, 0));
            cell.setOnClickListener(v -> selectTab(idx));
            tabBar.addView(cell, new LinearLayout.LayoutParams(0, -2, 1));
            tabViews[i] = t; tabIcons[i] = iv;
        }
        col.addView(tabBar, new LinearLayout.LayoutParams(-1, -2));
        root.addView(col, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);
        pages[0] = devicesPage(); pages[1] = speedPage(); pages[2] = toolsPage(); pages[3] = settingsPage();
        for (View p : pages) content.addView(p, new FrameLayout.LayoutParams(-1, -1));
        stack.clear();
        selectTab(tab);
        requestLocationOnce();
    }

    int R_ic_wifi() { return getResources().getIdentifier("ic_wifi", "drawable", getPackageName()); }
    int R_ic_speed() { return getResources().getIdentifier("ic_speed", "drawable", getPackageName()); }
    int R_ic_tools() { return getResources().getIdentifier("ic_tools", "drawable", getPackageName()); }
    int R_ic_gear() { return getResources().getIdentifier("ic_gear", "drawable", getPackageName()); }

    void selectTab(int i) {
        curTab = i;
        prefs.edit().putInt("tab", i).apply();
        while (!stack.isEmpty()) popPage();
        for (int k = 0; k < 4; k++) {
            pages[k].setVisibility(k == i ? View.VISIBLE : View.GONE);
            tabViews[k].setTextColor(k == i ? accent : fg2());
            tabIcons[k].setColorFilter(k == i ? accent : fg2(), android.graphics.PorterDuff.Mode.SRC_IN);
        }
        if (i == 0 && devices.isEmpty() && !scanning) startScan();
    }

    void pushPage(View v) {
        stack.add(v);
        content.addView(v, new FrameLayout.LayoutParams(-1, -1));
        v.setBackgroundColor(bg());
    }
    void popPage() {
        if (stack.isEmpty()) return;
        View v = stack.remove(stack.size() - 1);
        content.removeView(v);
    }
    @Override public void onBackPressed() { if (!stack.isEmpty()) popPage(); else super.onBackPressed(); }

    // ---------- helpers ----------
    ScrollView scroll(LinearLayout inner) {
        ScrollView sv = new ScrollView(this);
        sv.setFillViewport(false);
        inner.setPadding(dp(16), dp(12), dp(16), dp(24));
        sv.addView(inner, new ScrollView.LayoutParams(-1, -2));
        return sv;
    }
    LinearLayout col() { LinearLayout l = new LinearLayout(this); l.setOrientation(LinearLayout.VERTICAL); return l; }
    TextView title(String s) {
        TextView t = text(this, s, 32, true, fg());
        t.setPadding(dp(4), dp(10), 0, dp(10));
        return t;
    }
    void toast(String s) { Toast.makeText(this, I18n.t(s), Toast.LENGTH_SHORT).show(); }
    void share(String text) {
        Intent i = new Intent(Intent.ACTION_SEND); i.setType("text/plain"); i.putExtra(Intent.EXTRA_TEXT, text);
        startActivity(Intent.createChooser(i, I18n.t("Share")));
    }
    void copy(String s) { ((ClipboardManager) getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("netscope", s)); }

    void requestLocationOnce() {
        if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED && !prefs.getBoolean("askedLoc", false)) {
            prefs.edit().putBoolean("askedLoc", true).apply();
            requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, 1);
        }
    }
    @Override public void onRequestPermissionsResult(int c, String[] p, int[] r) { updateNet(); }

    String ssid() {
        try {
            if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return null;
            WifiManager wm = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
            WifiInfo wi = wm.getConnectionInfo();
            String s = wi == null ? null : wi.getSSID();
            if (s == null || s.equals("<unknown ssid>")) return null;
            return s.replace("\"", "");
        } catch (Exception e) { return null; }
    }

    // ---------- Devices ----------
    View devicesPage() {
        FrameLayout fl = new FrameLayout(this);
        LinearLayout c = col();
        c.addView(title("Devices"));
        LinearLayout head = card(this);
        devCount = text(this, "0", 44, true, accent);
        TextView lab = text(this, "devices online", 13, false, fg2());
        devNet = text(this, "", 14, false, fg());
        scanBtn = button(this, "Scan network", v -> startScan());
        prog = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        prog.setMax(100); prog.setVisibility(View.INVISIBLE);
        prog.getProgressDrawable().setColorFilter(accent, android.graphics.PorterDuff.Mode.SRC_IN);
        LinearLayout top = new LinearLayout(this); top.setOrientation(LinearLayout.HORIZONTAL); top.setGravity(Gravity.BOTTOM);
        top.addView(devCount); top.addView(lab, lp(-2, -2, 8, 0, 8, 8));
        head.addView(top); head.addView(devNet, lp(-1, -2, 0, 2, 0, 0));
        head.addView(scanBtn, lp(-1, dp(48) / (int) dens > 0 ? dp(48) : 140, 0, 12, 0, 0));
        head.addView(prog, lp(-1, dp(6), 0, 8, 0, 0));
        c.addView(head);
        filter = new Seg(this, new String[]{"All", "New", "Slow"}, 0, true, i -> rebuildList());
        c.addView(filter, lp(-1, -2, 0, 12, 0, 6));
        devList = col();
        c.addView(devList);
        ScrollView sv = scroll(c);
        fl.addView(sv);
        // share button
        TextView sh = text(this, "⇪", 22, true, accent);
        sh.setPadding(dp(14), dp(10), dp(14), dp(10));
        sh.setOnClickListener(v -> shareDevices());
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(-2, -2, Gravity.TOP | Gravity.END);
        lp.topMargin = dp(10); lp.setMarginEnd(dp(8));
        fl.addView(sh, lp);
        updateNet();
        return fl;
    }

    void updateNet() {
        if (devNet == null) return;
        long[] ln = Net.localNet();
        String s = ssid();
        if (ln == null) { devNet.setText(I18n.t("Not connected to Wi-Fi")); return; }
        devNet.setText(I18n.t("Wi-Fi") + (s != null ? " " + s : "") + "  ·  " + I18n.t("My IP ") + Net.ipString(ln[0]) + "/" + ln[1]);
    }

    void shareDevices() {
        StringBuilder sb = new StringBuilder("NetScope scan: " + devices.size() + " devices\n\n");
        for (Net.Dev d : devices) sb.append(d.ipStr()).append("  |  ").append(d.title(this)).append("  |  ").append(I18n.t(d.kind())).append(d.mac != null ? "  |  " + d.mac : "").append(d.ping >= 0 ? "  |  " + Math.round(d.ping) + " ms" : "").append("\n");
        share(sb.toString());
    }

    void startScan() {
        if (scanning) return;
        updateNet();
        scanning = true; devices.clear(); rebuildList();
        devCount.setText("0");
        scanBtn.setText(I18n.t("Scanning…")); scanBtn.setAlpha(0.6f);
        prog.setProgress(0); prog.setVisibility(View.VISIBLE);
        if (bonjour != null) bonjour.stop();
        bonjour = new Net.Bonjour(); bonjour.start(this);
        final Set<String> known = new HashSet<>(prefs.getStringSet("knownIPs", new HashSet<String>()));
        Net.scan(this, bonjour, new Net.Listener() {
            public void progress(final float p) { main.post(() -> prog.setProgress((int) (p * 100))); }
            public void device(final Net.Dev d) {
                main.post(() -> {
                    d.isNew = !known.isEmpty() && !known.contains(d.ipStr()) && !d.me;
                    devices.add(d);
                    Collections.sort(devices, (a, b) -> Long.compare(a.ip, b.ip));
                    devCount.setText(String.valueOf(devices.size()));
                    long now = SystemClock.uptimeMillis();
                    if (now - lastRebuild > 400) { lastRebuild = now; rebuildList(); }
                });
            }
            public void done(final List<Net.Dev> all) {
                main.post(() -> {
                    Map<Long, Boolean> nw = new HashMap<>();
                    for (Net.Dev d : devices) nw.put(d.ip, d.isNew);
                    devices.clear(); devices.addAll(all);
                    Set<String> ips = new HashSet<>();
                    for (Net.Dev d : devices) { Boolean b = nw.get(d.ip); d.isNew = b != null && b; ips.add(d.ipStr()); }
                    prefs.edit().putStringSet("knownIPs", ips).apply();
                    devCount.setText(String.valueOf(devices.size()));
                    if (bonjour != null) { bonjour.stop(); bonjour = null; }
                    scanning = false;
                    scanBtn.setText(I18n.t("Scan again")); scanBtn.setAlpha(1f);
                    prog.setVisibility(View.INVISIBLE);
                    rebuildList();
                    try { devList.performHapticFeedback(HapticFeedbackConstants.CONFIRM); } catch (Throwable t) { }
                });
            }
        });
    }

    void rebuildList() {
        if (devList == null) return;
        devList.removeAllViews();
        for (final Net.Dev d : devices) {
            if (filter.sel == 1 && !d.isNew) continue;
            if (filter.sel == 2 && !(d.ping > 100)) continue;
            devList.addView(deviceRow(d), lp(-1, -2, 0, 5, 0, 5));
        }
    }

    View deviceRow(final Net.Dev d) {
        LinearLayout r = card(this);
        r.setOrientation(LinearLayout.HORIZONTAL);
        r.setGravity(Gravity.CENTER_VERTICAL);
        TextView ic = text(this, d.icon().length() == 0 ? "📱" : d.icon(), 26, false, accent);
        r.addView(ic, lp(dp(36) / 1, -2, 0, 0, 12, 0));
        LinearLayout mid = col();
        mid.addView(text(this, d.title(this), 17, true, fg()));
        String sub = d.ipStr() + "  ·  " + I18n.t(d.kind());
        if (d.vendor != null && !d.randomMac() && !d.title(this).equals(d.vendor)) sub += "  ·  " + d.vendor;
        TextView st = text(this, sub, 13, false, fg2());
        mid.addView(st);
        r.addView(mid, new LinearLayout.LayoutParams(0, -2, 1));
        LinearLayout right = col();
        right.setGravity(Gravity.END);
        right.addView(text(this, d.ping >= 0 ? Math.round(d.ping) + " ms" : "", 13, false, fg2()));
        String badge = null; int bc = accent;
        if (d.me) badge = "YOU"; else if (d.kind().equals("Router")) { badge = "ROUTER"; bc = 0xFFFF9F0A; } else if (d.isNew) { badge = "NEW"; bc = 0xFF30D158; }
        if (badge != null) {
            TextView b = text(this, badge, 10, true, 0xFFFFFFFF);
            b.setBackground(round(bc, 0, 8)); b.setPadding(dp(8), dp(2), dp(8), dp(2));
            right.addView(b, lp(-2, -2, 0, 4, 0, 0));
        }
        r.addView(right);
        r.setOnClickListener(v -> openDevice(d));
        return r;
    }

    void openDevice(final Net.Dev d) {
        LinearLayout c = col();
        TextView back = text(this, "‹ " + I18n.t("Back"), 17, true, accent);
        back.setPadding(dp(4), dp(8), dp(8), dp(8));
        back.setOnClickListener(v -> popPage());
        c.addView(back);
        c.addView(title(d.title(this)));
        LinearLayout info = card(this);
        info.addView(text(this, d.icon() + "  " + I18n.t(d.kind()), 20, true, fg()));
        info.addView(text(this, d.ipStr(), 15, false, fg2()));
        if (d.mac != null) {
            info.addView(text(this, I18n.t("MAC: ") + d.mac, 14, false, fg()), lp(-2, -2, 0, 8, 0, 0));
            if (d.randomMac()) info.addView(text(this, "Private (random) MAC", 13, false, fg2()));
            else if (d.vendor != null) info.addView(text(this, I18n.t("Vendor: ") + d.vendor, 14, false, fg()));
        } else if (!d.me) info.addView(text(this, "MAC not available on this Android version", 12, false, fg3()), lp(-2, -2, 0, 8, 0, 0));
        StringBuilder pn = new StringBuilder();
        for (int p : d.ports) { if (pn.length() > 0) pn.append(", "); pn.append(p).append(" (").append(Net.PORT_NAMES.containsKey(p) ? Net.PORT_NAMES.get(p) : "?").append(")"); }
        info.addView(text(this, pn.length() > 0 ? I18n.t("Open ports: ") + pn : I18n.t("No open ports found in quick scan"), 13, false, fg2()), lp(-2, -2, 0, 8, 0, 0));
        c.addView(info);
        final TextView out = text(this, I18n.t("Tap Ping or Port scan."), 13, false, fg());
        out.setTypeface(Typeface.MONOSPACE);
        out.setLayoutDirection(View.LAYOUT_DIRECTION_LTR);
        out.setTextAlignment(View.TEXT_ALIGNMENT_VIEW_START);
        LinearLayout row1 = new LinearLayout(this), row2 = new LinearLayout(this);
        TextView b1 = button(this, "Ping", v -> { out.setText("PING " + d.ipStr() + "\n"); streamPing(d.ipStr(), 8, out); });
        TextView b2 = button(this, "Port scan", v -> {
            out.setText(I18n.t("Scanning common ports…") + "\n");
            new Thread(() -> {
                final List<Integer> open = Net.portScan(d.ip, Net.PORT_NAMES.keySet(), 1500);
                main.post(() -> {
                    StringBuilder sb = new StringBuilder();
                    for (int p : open) sb.append(String.format(Locale.US, "%-6d open   %s\n", p, Net.PORT_NAMES.get(p)));
                    out.setText(open.isEmpty() ? I18n.t("No open ports found.") : sb.toString());
                    d.ports = open;
                });
            }).start();
        });
        TextView b3 = button(this, "Rename", v -> rename(d));
        TextView b4 = button(this, "Copy IP", v -> { copy(d.ipStr()); toast("IP copied."); });
        row1.addView(b1, lp(0, dp(46), 0, 0, 5, 0)); ((LinearLayout.LayoutParams) b1.getLayoutParams()).weight = 1;
        row1.addView(b2, lp(0, dp(46), 5, 0, 0, 0)); ((LinearLayout.LayoutParams) b2.getLayoutParams()).weight = 1;
        row2.addView(b3, lp(0, dp(46), 0, 0, 5, 0)); ((LinearLayout.LayoutParams) b3.getLayoutParams()).weight = 1;
        row2.addView(b4, lp(0, dp(46), 5, 0, 0, 0)); ((LinearLayout.LayoutParams) b4.getLayoutParams()).weight = 1;
        c.addView(row1, lp(-1, -2, 0, 12, 0, 0)); c.addView(row2, lp(-1, -2, 0, 10, 0, 0));
        LinearLayout oc = card(this); oc.addView(out);
        c.addView(oc, lp(-1, -2, 0, 12, 0, 0));
        pushPage(scroll(c));
    }

    void rename(final Net.Dev d) {
        final EditText et = new EditText(this);
        et.setText(prefs.getString("nick_" + d.ipStr(), ""));
        et.setHint(d.title(this));
        new AlertDialog.Builder(this).setTitle(I18n.t("Rename device")).setView(et)
            .setNegativeButton(I18n.t("Cancel"), null)
            .setPositiveButton(I18n.t("Save"), (x, y) -> {
                String t = et.getText().toString().trim();
                SharedPreferences.Editor e = prefs.edit();
                if (t.length() > 0) e.putString("nick_" + d.ipStr(), t); else e.remove("nick_" + d.ipStr());
                e.apply(); rebuildList();
            }).show();
    }

    // ---------- shell streaming ----------
    void streamPing(final String host, final int count, final TextView out) {
        new Thread(() -> {
            try {
                java.lang.Process p = new ProcessBuilder("ping", "-c", String.valueOf(count), "-W", "2", host).redirectErrorStream(true).start();
                BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
                String l;
                while ((l = r.readLine()) != null) { final String ln = l; main.post(() -> out.append(ln + "\n")); }
                p.waitFor();
            } catch (Exception e) { main.post(() -> out.append(String.valueOf(e.getMessage()) + "\n")); }
        }).start();
    }

    // ---------- Speed ----------
    View speedPage() {
        FrameLayout fl = new FrameLayout(this);
        LinearLayout c = col();
        c.addView(title("Speed Test"));
        LinearLayout gc = card(this);
        gauge = new Gauge(this); gauge.set(0, "Ready");
        gc.addView(gauge, new LinearLayout.LayoutParams(-1, dp(250)));
        c.addView(gc);
        speedBtn = button(this, "Start test", v -> startSpeed());
        c.addView(speedBtn, lp(-1, dp(50), 0, 14, 0, 0));
        sPing = stat(); sJit = stat(); sDl = stat(); sUl = stat();
        c.addView(statRow("PING (ms)", sPing, "JITTER (ms)", sJit), lp(-1, -2, 0, 14, 0, 0));
        c.addView(statRow("DOWNLOAD (Mbps)", sDl, "UPLOAD (Mbps)", sUl), lp(-1, -2, 0, 12, 0, 0));
        LinearLayout hc = card(this);
        hc.addView(text(this, "History", 16, true, fg()));
        hist = text(this, "", 13, false, fg2());
        hc.addView(hist, lp(-1, -2, 0, 8, 0, 0));
        c.addView(hc, lp(-1, -2, 0, 12, 0, 0));
        showHistory();
        fl.addView(scroll(c));
        TextView sh = text(this, "⇪", 22, true, accent);
        sh.setPadding(dp(14), dp(10), dp(14), dp(10));
        sh.setOnClickListener(v -> shareResult());
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(-2, -2, Gravity.TOP | Gravity.END);
        lp.topMargin = dp(10); lp.setMarginEnd(dp(8));
        fl.addView(sh, lp);
        return fl;
    }
    TextView stat() { return text(this, "—", 22, true, fg()); }
    View statRow(String a, TextView av, String b, TextView bv) {
        LinearLayout r = new LinearLayout(this);
        for (int i = 0; i < 2; i++) {
            LinearLayout cd = card(this);
            cd.addView(text(this, i == 0 ? a : b, 12, true, fg2()));
            cd.addView(i == 0 ? av : bv);
            r.addView(cd, lp(0, -2, i == 0 ? 0 : 6, 0, i == 0 ? 6 : 0, 0));
            ((LinearLayout.LayoutParams) cd.getLayoutParams()).weight = 1;
        }
        return r;
    }

    void startSpeed() {
        if (speed != null && speed.running) return;
        sPing.setText("—"); sJit.setText("—"); sDl.setText("—"); sUl.setText("—");
        gauge.set(0, "Ready");
        speedBtn.setText(I18n.t("Testing…")); speedBtn.setAlpha(0.5f);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        final String[] phase = {"Ping"};
        speed = new Speed(new Speed.CB() {
            public void phase(String p) {
                phase[0] = p;
                gauge.set(0, p.equals("Ping") ? "Measuring latency…" : p.equals("Download") ? "Download  Mbps" : "Upload  Mbps");
                if (p.equals("Download") && speed.res.ping >= 0) { sPing.setText(String.valueOf(Math.round(speed.res.ping))); sJit.setText(String.format(Locale.US, "%.1f", speed.res.jitter)); }
                if (p.equals("Upload") && speed.res.down > 0) sDl.setText(String.format(Locale.US, "%.1f", speed.res.down));
            }
            public void live(double m) { if (!phase[0].equals("Ping")) gauge.set(m, phase[0].equals("Download") ? "Download  Mbps" : "Upload  Mbps"); }
            public void done(Speed.Result r) {
                getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                if (r.ping >= 0) { sPing.setText(String.valueOf(Math.round(r.ping))); sJit.setText(String.format(Locale.US, "%.1f", r.jitter)); }
                sDl.setText(r.down > 0 ? String.format(Locale.US, "%.1f", r.down) : "—");
                sUl.setText(r.up > 0 ? String.format(Locale.US, "%.1f", r.up) : "—");
                gauge.set(r.down, r.err != null ? tr(r.err) : (r.server != null ? I18n.t("Done") + " · " + r.server : "Done"));
                speedBtn.setText(I18n.t("Test again")); speedBtn.setAlpha(1f);
                try {
                    org.json.JSONArray h = new org.json.JSONArray(prefs.getString("speedHistory", "[]"));
                    org.json.JSONObject o = new org.json.JSONObject();
                    o.put("ts", r.ts); o.put("down", r.down); o.put("up", r.up); o.put("ping", r.ping); o.put("jitter", r.jitter);
                    org.json.JSONArray n = new org.json.JSONArray(); n.put(o);
                    for (int i = 0; i < Math.min(7, h.length()); i++) n.put(h.get(i));
                    prefs.edit().putString("speedHistory", n.toString()).apply();
                } catch (Exception e) { }
                showHistory();
            }
        });
        speed.start();
    }
    String tr(String e) {
        if (!I18n.ar) return e;
        for (String k : new String[]{"Download failed: ", "Upload failed: ", "no server reachable"}) e = e.replace(k, I18n.t(k));
        return e;
    }
    void showHistory() {
        try {
            org.json.JSONArray h = new org.json.JSONArray(prefs.getString("speedHistory", "[]"));
            if (h.length() == 0) { hist.setText(I18n.t("No tests yet.")); return; }
            SimpleDateFormat f = new SimpleDateFormat("d MMM HH:mm", Locale.US);
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < h.length(); i++) {
                org.json.JSONObject o = h.getJSONObject(i);
                sb.append(String.format(Locale.US, "%s   ↓ %.1f   ↑ %.1f   %.0f ms\n", f.format(new Date(o.getLong("ts"))), o.getDouble("down"), o.getDouble("up"), o.getDouble("ping")));
            }
            hist.setText(sb.toString().trim());
            hist.setLayoutDirection(View.LAYOUT_DIRECTION_LTR);
        } catch (Exception e) { hist.setText(I18n.t("No tests yet.")); }
    }
    void shareResult() {
        try {
            org.json.JSONArray h = new org.json.JSONArray(prefs.getString("speedHistory", "[]"));
            if (h.length() == 0) return;
            org.json.JSONObject o = h.getJSONObject(0);
            share(String.format(Locale.US, "NetScope speed test\nDownload: %.1f Mbps\nUpload: %.1f Mbps\nPing: %.0f ms  Jitter: %.1f ms", o.getDouble("down"), o.getDouble("up"), o.getDouble("ping"), o.getDouble("jitter")));
        } catch (Exception e) { }
    }

    // ---------- Tools ----------
    View toolsPage() {
        LinearLayout c = col();
        c.addView(title("Tools"));
        LinearLayout f = card(this);
        final EditText host = new EditText(this);
        host.setHint(I18n.t("Host or IP  (e.g. google.com)"));
        host.setHintTextColor(fg3()); host.setTextColor(fg()); host.setSingleLine(true);
        host.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        host.setLayoutDirection(View.LAYOUT_DIRECTION_LTR);
        host.setBackground(null);
        f.addView(host);
        c.addView(f);
        final TextView out = text(this, "Network tools. Enter a host, then pick a tool.", 13, false, fg());
        out.setTypeface(Typeface.MONOSPACE);
        out.setLayoutDirection(View.LAYOUT_DIRECTION_LTR);
        out.setTextAlignment(View.TEXT_ALIGNMENT_VIEW_START);
        LinearLayout r = new LinearLayout(this);
        String[] names = {"Ping", "DNS", "Ports", "Trace"};
        for (int i = 0; i < 4; i++) {
            final int k = i;
            TextView b = button(this, names[i], v -> tool(k, host.getText().toString().trim(), out));
            r.addView(b, lp(0, dp(46), i == 0 ? 0 : 4, 0, i == 3 ? 0 : 4, 0));
            ((LinearLayout.LayoutParams) b.getLayoutParams()).weight = 1;
            b.setTextSize(14);
        }
        c.addView(r, lp(-1, -2, 0, 12, 0, 0));
        TextView pub = button(this, "My public IP", v -> publicIp(out));
        c.addView(pub, lp(-1, dp(46), 0, 10, 0, 0));
        LinearLayout oc = card(this); oc.addView(out);
        c.addView(oc, lp(-1, -2, 0, 12, 0, 0));
        return scroll(c);
    }

    void tool(final int k, final String h, final TextView out) {
        if (h.isEmpty()) { out.setText(I18n.t("Enter a host first.")); return; }
        out.setText("");
        new Thread(() -> {
            try {
                if (k == 0) { InetAddress a = InetAddress.getByName(h); post(out, "PING " + h + " (" + a.getHostAddress() + ")\n"); streamPingSync(a.getHostAddress(), 6, out); return; }
                if (k == 1) {
                    long t0 = System.nanoTime();
                    InetAddress[] all = InetAddress.getAllByName(h);
                    post(out, String.format(Locale.US, "DNS lookup %s  (%.0f ms)\n", h, (System.nanoTime() - t0) / 1e6));
                    for (InetAddress a : all) post(out, "  " + (a instanceof Inet4Address ? "A     " : "AAAA  ") + a.getHostAddress() + "\n");
                    return;
                }
                InetAddress a = null;
                for (InetAddress x : InetAddress.getAllByName(h)) if (x instanceof Inet4Address) { a = x; break; }
                if (a == null) { post(out, I18n.t("Could not resolve host.") + "\n"); return; }
                final long ip = Net.ipLong(a.getHostAddress());
                if (k == 2) {
                    post(out, I18n.t("Scanning common ports…") + "\n");
                    List<Integer> open = Net.portScan(ip, Net.PORT_NAMES.keySet(), 2000);
                    post(out, h + " (" + a.getHostAddress() + ")\n");
                    for (int p : open) post(out, String.format(Locale.US, "%-6d open   %s\n", p, Net.PORT_NAMES.get(p)));
                    if (open.isEmpty()) post(out, I18n.t("No open ports found.") + "\n");
                } else {
                    post(out, "Traceroute to " + h + " (" + a.getHostAddress() + "), max 20 hops\n");
                    for (int ttl = 1; ttl <= 20; ttl++) {
                        java.lang.Process p = new ProcessBuilder("ping", "-c", "1", "-t", String.valueOf(ttl), "-W", "2", a.getHostAddress()).redirectErrorStream(true).start();
                        BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
                        String l, hop = null; boolean reached = false; double ms = -1;
                        while ((l = r.readLine()) != null) {
                            java.util.regex.Matcher m = java.util.regex.Pattern.compile("(?:[Ff]rom|bytes from)\\s+([0-9.]+)").matcher(l);
                            if (m.find()) hop = m.group(1);
                            if (l.contains("bytes from")) reached = true;
                            int i = l.indexOf("time="); if (i >= 0) { try { ms = Double.parseDouble(l.substring(i + 5).trim().split(" ")[0]); } catch (Exception e) { } }
                        }
                        p.waitFor();
                        post(out, hop != null ? String.format(Locale.US, "%2d  %-16s %s\n", ttl, hop, ms >= 0 ? Math.round(ms) + " ms" : "") : String.format(Locale.US, "%2d  *\n", ttl));
                        if (reached) break;
                    }
                    post(out, "\nDone.\n");
                }
            } catch (UnknownHostException e) { post(out, I18n.t("Could not resolve host.") + "\n"); }
            catch (Exception e) { post(out, String.valueOf(e.getMessage()) + "\n"); }
        }).start();
    }
    void post(final TextView t, final String s) { main.post(() -> t.append(s)); }
    void streamPingSync(String host, int n, TextView out) throws Exception {
        java.lang.Process p = new ProcessBuilder("ping", "-c", String.valueOf(n), "-W", "2", host).redirectErrorStream(true).start();
        BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
        String l;
        while ((l = r.readLine()) != null) post(out, l + "\n");
        p.waitFor();
    }
    void publicIp(final TextView out) {
        out.setText(I18n.t("Checking…") + "\n");
        new Thread(() -> {
            try {
                HttpURLConnection c = (HttpURLConnection) new URL("https://www.cloudflare.com/cdn-cgi/trace").openConnection();
                c.setConnectTimeout(5000); c.setReadTimeout(5000);
                BufferedReader r = new BufferedReader(new InputStreamReader(c.getInputStream()));
                String l; StringBuilder sb = new StringBuilder();
                while ((l = r.readLine()) != null) {
                    if (l.startsWith("ip=")) sb.append("Public IP : ").append(l.substring(3)).append("\n");
                    if (l.startsWith("loc=")) sb.append("Country   : ").append(l.substring(4)).append("\n");
                    if (l.startsWith("colo=")) sb.append("Edge      : ").append(l.substring(5)).append("\n");
                }
                final String s = sb.toString();
                main.post(() -> out.setText(s));
            } catch (Exception e) { main.post(() -> out.setText(I18n.t("No internet connection.") + "\n")); }
        }).start();
    }

    // ---------- Settings ----------
    View settingsPage() {
        LinearLayout c = col();
        c.addView(title("Settings"));
        LinearLayout g1 = card(this);
        g1.addView(text(this, "Appearance", 16, true, fg()));
        g1.addView(new Seg(this, new String[]{"Automatic", "Light", "Black"}, prefs.getInt("appearance", 2), true, i -> { prefs.edit().putInt("appearance", i).apply(); recreate(); }), lp(-1, -2, 0, 10, 0, 0));
        g1.addView(text(this, "Color theme", 16, true, fg()), lp(-2, -2, 0, 20, 0, 0));
        LinearLayout sw = new LinearLayout(this); sw.setGravity(Gravity.CENTER_VERTICAL);
        int cur = prefs.getInt("accent", 0);
        for (int i = 0; i < ACCENTS.length; i++) {
            final int idx = i;
            View v = new View(this);
            android.graphics.drawable.GradientDrawable gd = round(ACCENTS[i], i == cur ? fg() : 0, 16);
            gd.setShape(android.graphics.drawable.GradientDrawable.OVAL);
            gd.setStroke(i == cur ? dp(3) : 0, fg());
            v.setBackground(gd);
            v.setOnClickListener(x -> { prefs.edit().putInt("accent", idx).apply(); recreate(); });
            sw.addView(v, lp(0, dp(30), 0, 0, 0, 0));
            LinearLayout.LayoutParams p = (LinearLayout.LayoutParams) v.getLayoutParams(); p.weight = 1; p.setMargins(dp(3), 0, dp(3), 0);
        }
        g1.addView(sw, lp(-1, dp(34), 0, 10, 0, 0));
        g1.addView(text(this, "Language", 16, true, fg()), lp(-2, -2, 0, 20, 0, 0));
        g1.addView(new Seg(this, new String[]{"English", "العربية"}, I18n.ar ? 1 : 0, false, i -> { prefs.edit().putBoolean("arabic", i == 1).putInt("tab", 3).apply(); recreate(); }), lp(-1, -2, 0, 10, 0, 0));
        c.addView(g1, lp(-1, -2, 0, 0, 0, 12));
        LinearLayout g2 = card(this);
        g2.addView(text(this, "NetScope Android 1.3", 15, true, fg()));
        g2.addView(text(this, "NetScope finds devices on your Wi-Fi using ping, TCP probes, ARP and Bonjour, and measures speed against public servers. Everything runs on your phone, nothing is uploaded.", 13, false, fg2()), lp(-1, -2, 0, 6, 0, 0));
        c.addView(g2, lp(-1, -2, 0, 0, 0, 12));
        LinearLayout g3 = card(this);
        g3.addView(text(this, "Developer", 12, false, fg2()));
        g3.addView(text(this, "Youssef elbaheriy", 20, true, fg()));
        LinearLayout lr = new LinearLayout(this);
        String[] ln = {"Facebook", "Instagram", "WhatsApp"};
        for (int i = 0; i < 3; i++) {
            final int k = i;
            TextView b = button(this, ln[i], v -> {
                if (k == 2) { copy("jo0seff"); new AlertDialog.Builder(this).setTitle(I18n.t("Copied")).setMessage(I18n.t("WhatsApp username: ") + "jo0seff").setPositiveButton(I18n.t("OK"), null).show(); return; }
                String u = k == 0 ? "https://www.facebook.com/share/1BSuPxYGiZ/?mibextid=wwXIfr" : "https://www.instagram.com/jo0seff?dmpr=enE5d2hzdndibGth&utm_source=qr";
                try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(u))); } catch (Exception e) { }
            });
            b.setTextSize(14);
            lr.addView(b, lp(0, dp(44), i == 0 ? 0 : 4, 0, i == 2 ? 0 : 4, 0));
            ((LinearLayout.LayoutParams) b.getLayoutParams()).weight = 1;
        }
        g3.addView(lr, lp(-1, -2, 0, 12, 0, 0));
        c.addView(g3, lp(-1, -2, 0, 0, 0, 12));
        TextView clr = button(this, "Clear history and names", v -> {
            SharedPreferences.Editor e = prefs.edit();
            for (String k : new ArrayList<>(prefs.getAll().keySet())) if (k.startsWith("nick_") || k.equals("knownIPs") || k.equals("speedHistory")) e.remove(k);
            e.apply(); showHistory(); toast("Cleared");
        });
        clr.setBackground(round(0xFFFF453A, 0, 16));
        c.addView(clr, lp(-1, dp(48), 0, 0, 0, 0));
        return scroll(c);
    }
                  }
