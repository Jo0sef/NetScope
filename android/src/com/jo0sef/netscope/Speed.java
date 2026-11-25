package com.jo0sef.netscope;

import android.os.Handler;
import android.os.Looper;
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;

public class Speed {
    interface CB { void phase(String p); void live(double mbps); void done(Result r); }
    static class Result { double ping = -1, jitter = 0, down = 0, up = 0; String server, err; long ts = System.currentTimeMillis(); }

    final CB cb;
    final Handler main = new Handler(Looper.getMainLooper());
    static class Run { final AtomicLong bytes = new AtomicLong(); volatile boolean cancelled; }
    volatile boolean running;
    volatile String lastErr;
    final Result res = new Result();

    static final String[][] DL = {
        {"https://speed.cloudflare.com/__down?bytes=25000000", "Cloudflare"},
        {"https://cachefly.cachefly.net/10mb.test", "CacheFly"},
        {"https://ash-speed.hetzner.com/100MB.bin", "Hetzner"},
        {"https://download.thinkbroadband.com/10MB.zip", "ThinkBroadband"}};
    static final String[][] UL = {{"https://speed.cloudflare.com/__up", "Cloudflare"}, {"https://httpbin.org/post", "httpbin"}};

    Speed(CB cb) { this.cb = cb; }

    void start() {
        if (running) return;
        running = true;
        new Thread(this::run).start();
    }

    void post(Runnable r) { main.post(r); }

    void run() {
        try {
            post(() -> cb.phase("Ping"));
            pingStage();
            // download
            res.down = 0;
            String dlErr = null;
            for (int i = 0; i < DL.length; i++) {
                post(() -> cb.phase("Download"));
                lastErr = null;
                double r = measure(false, DL[i][0], 9);
                if (r >= 0) { res.down = r; res.server = DL[i][1]; dlErr = null; break; }
                dlErr = "Download failed: " + (lastErr != null ? lastErr : "no server reachable");
            }
            // upload
            String ulErr = null;
            for (int i = 0; i < UL.length; i++) {
                post(() -> cb.phase("Upload"));
                lastErr = null;
                double r = measure(true, UL[i][0], 8);
                if (r >= 0) { res.up = r; ulErr = null; break; }
                ulErr = "Upload failed: " + (lastErr != null ? lastErr : "no server reachable");
            }
            res.err = dlErr != null ? dlErr : ulErr;
        } catch (Throwable t) {
            res.err = String.valueOf(t.getMessage());
        }
        running = false;
        post(() -> cb.done(res));
    }

    // ICMP via the system ping binary, HTTP timing fallback, 10 s watchdog
    void pingStage() {
        final List<Double> times = Collections.synchronizedList(new ArrayList<Double>());
        Thread t = new Thread(() -> {
            String[] targets = {"1.1.1.1", "8.8.8.8"};
            for (String h : targets) {
                int fails = 0;
                for (int i = 0; i < 6 && fails < 2; i++) {
                    double ms = Net.ping(h, 1);
                    if (ms >= 0) times.add(ms); else fails++;
                    try { Thread.sleep(120); } catch (Exception e) { }
                }
                if (times.size() >= 3) return;
            }
            if (times.isEmpty()) {
                String[] urls = {"https://www.gstatic.com/generate_204", "https://speed.cloudflare.com/__down?bytes=0"};
                for (String u : urls) {
                    int fails = 0;
                    for (int i = 0; i < 6 && fails < 2; i++) {
                        long t0 = System.nanoTime();
                        try {
                            HttpURLConnection c = (HttpURLConnection) new URL(u + (u.contains("?") ? "&" : "?") + "r=" + System.nanoTime()).openConnection();
                            c.setConnectTimeout(2500); c.setReadTimeout(2500); c.setUseCaches(false);
                            c.getResponseCode(); c.disconnect();
                            if (i > 0) times.add((System.nanoTime() - t0) / 1e6);
                        } catch (Exception e) { fails++; }
                    }
                    if (!times.isEmpty()) return;
                }
            }
        });
        t.start();
        try { t.join(10000); } catch (Exception e) { }
        List<Double> ts;
        synchronized (times) { ts = new ArrayList<>(times); }
        if (!ts.isEmpty()) {
            double mn = 1e9, jit = 0;
            for (double d : ts) mn = Math.min(mn, d);
            for (int i = 1; i < ts.size(); i++) jit += Math.abs(ts.get(i) - ts.get(i - 1));
            res.ping = mn; res.jitter = ts.size() > 1 ? jit / (ts.size() - 1) : 0;
        }
    }

    // returns Mbps, or -1 if no data arrived within 4 s
    double measure(boolean upload, String url, double secs) {
        final Run run = new Run();
        final int n = 4;
        List<Thread> ths = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            Thread t = new Thread(() -> worker(run, upload, url));
            t.setDaemon(true); t.start(); ths.add(t);
        }
        long t0 = System.nanoTime(), lastT = t0, warmT = 0, lastB = 0, atWarm = 0;
        boolean warm = false;
        double result;
        while (true) {
            try { Thread.sleep(200); } catch (Exception e) { }
            long now = System.nanoTime();
            long b = run.bytes.get();
            double elapsed = (now - t0) / 1e6;
            if (b == 0 && elapsed > 4000) { run.cancelled = true; return -1; }
            double inst = (b - lastB) * 8.0 / 1e6 / Math.max(0.05, (now - lastT) / 1e9);
            lastB = b; lastT = now;
            final double li = inst;
            post(() -> cb.live(li));
            if (!warm && elapsed > 1500) { warm = true; atWarm = b; warmT = now; }
            if (elapsed >= secs * 1000) {
                result = (warm && (now - warmT) > 5e8) ? (b - atWarm) * 8.0 / 1e6 / ((now - warmT) / 1e9) : b * 8.0 / 1e6 / Math.max(0.1, (now - t0) / 1e9);
                break;
            }
        }
        run.cancelled = true;
        return result;
    }

    void worker(Run run, boolean upload, String url) {
        byte[] buf = new byte[64 * 1024];
        while (!run.cancelled) {
            HttpURLConnection c = null;
            try {
                String u = url + (upload ? "" : (url.contains("?") ? "&" : "?") + "r=" + System.nanoTime());
                c = (HttpURLConnection) new URL(u).openConnection();
                c.setConnectTimeout(4000); c.setReadTimeout(5000); c.setUseCaches(false);
                if (upload) {
                    long len = 512L * 1024;
                    c.setRequestMethod("POST"); c.setDoOutput(true);
                    c.setFixedLengthStreamingMode(len);
                    c.setRequestProperty("Content-Type", "application/octet-stream");
                    OutputStream os = c.getOutputStream();
                    long sent = 0;
                    while (sent < len && !run.cancelled) { int k = (int) Math.min(buf.length, len - sent); os.write(buf, 0, k); sent += k; }
                    if (run.cancelled) { return; }
                    os.flush();
                    int rc = c.getResponseCode();
                    if (rc >= 200 && rc < 300) run.bytes.addAndGet(len); else { lastErr = "Server error " + rc; Thread.sleep(500); }
                } else {
                    int code = c.getResponseCode();
                    if (code < 200 || code >= 300) { lastErr = "Server error " + code; Thread.sleep(500); continue; }
                    InputStream in = c.getInputStream();
                    int k;
                    while (!run.cancelled && (k = in.read(buf)) > 0) run.bytes.addAndGet(k);
                }
            } catch (Exception e) {
                if (!run.cancelled) { lastErr = e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName(); try { Thread.sleep(400); } catch (Exception x) { } }
            } finally { if (c != null) c.disconnect(); }
        }
    }
}
