package com.jo0sef.netscope;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.net.wifi.WifiManager;
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

public class Net {
    // ---------- model ----------
    static class Dev {
        long ip; String host, bonjour, mac, vendor;
        Set<String> services = Collections.synchronizedSet(new HashSet<String>());
        List<Integer> ports = new ArrayList<>();
        double ping = -1; boolean me, isNew;
        String ipStr() { return ipString(ip); }
        boolean hasPort(int p) { return ports.contains(p); }
        boolean hasSvc(String s) { synchronized (services) { for (String x : services) if (x.contains(s)) return true; } return false; }
        boolean randomMac() { try { return mac != null && (Integer.parseInt(mac.substring(0, 2), 16) & 2) != 0; } catch (Exception e) { return false; } }
        String kind() {
            if (me) return "This phone";
            String n = (bonjour != null ? bonjour : host != null ? host : "").toLowerCase();
            String v = vendor == null ? "" : vendor.toLowerCase();
            if (hasSvc("googlecast") || hasPort(8008) || hasPort(8009)) return n.contains("tv") ? "Smart TV" : "Chromecast / Cast";
            if (n.contains("iphone")) return "iPhone";
            if (n.contains("ipad")) return "iPad";
            if (n.contains("macbook") || n.contains("imac") || n.contains("mac-") || n.contains("mac mini")) return "Mac";
            if (n.contains("android") || n.contains("galaxy") || n.contains("pixel") || n.contains("xiaomi") || n.contains("redmi") || n.contains("oppo") || n.contains("huawei") || n.contains("realme") || n.contains("poco")) return "Android phone";
            if (n.contains("desktop") || n.contains("laptop") || n.contains("-pc")) return "Windows PC";
            if (n.contains("tv") || n.contains("roku") || n.contains("bravia")) return "Smart TV";
            if (n.contains("echo") || n.contains("alexa") || n.contains("homepod")) return "Smart speaker";
            if (hasSvc("printer") || hasSvc("ipp") || hasPort(9100) || hasPort(631) || hasPort(515)) return "Printer";
            if (hasSvc("airplay") || hasSvc("raop") || hasPort(7000)) return "Apple TV / AirPlay";
            if (hasPort(62078)) return "iPhone / iPad";
            if (hasPort(554)) return "IP camera";
            if (hasPort(3389) || hasPort(135) || hasPort(139)) return "Windows PC";
            if (hasPort(445) || hasPort(548) || hasSvc("smb")) return "Computer / NAS";
            if (hasPort(22)) return "Server / Linux";
            if (v.contains("samsung") || v.contains("xiaomi") || v.contains("huawei") || v.contains("oppo") || v.contains("vivo") || v.contains("oneplus") || v.contains("motorola") || v.contains("realme")) return "Android phone";
            if (v.contains("apple")) return "Apple device";
            if (v.contains("tp-link") || v.contains("tplink") || v.contains("huawei tech") || v.contains("zte") || v.contains("netgear") || v.contains("d-link") || v.contains("mikrotik")) { if ((ip & 255) == 1 || (ip & 255) == 254) return "Router"; }
            if (hasSvc("companion-link") || hasSvc("device-info")) return "Apple device";
            long last = ip & 255;
            if ((last == 1 || last == 254) && (hasPort(80) || hasPort(443) || hasPort(53))) return "Router";
            if (hasPort(80) || hasPort(443) || hasPort(8080)) return "Web device";
            return "Unknown";
        }
        String icon() {
            String k = kind();
            if (k.equals("Router")) return "📡";
            if (k.contains("iPad")) return "📱";
            if (k.contains("phone") || k.contains("iPhone")) return "📱";
            if (k.equals("Mac") || k.equals("Windows PC")) return "💻";
            if (k.contains("TV") || k.contains("Cast")) return "📺";
            if (k.contains("speaker")) return "🔊";
            if (k.equals("Printer")) return "🖨";
            if (k.contains("camera")) return "📷";
            if (k.contains("Server") || k.contains("NAS")) return "🖥";
            if (k.contains("Apple")) return "";
            return "❓";
        }
        String title(Context c) {
            String nick = c.getSharedPreferences("p", 0).getString("nick_" + ipStr(), null);
            if (nick != null && nick.length() > 0) return nick;
            if (me) return I18n.t("This phone");
            if (bonjour != null && bonjour.length() > 0) return bonjour;
            if (host != null && host.length() > 0) return host;
            if (vendor != null && !randomMac()) return vendor;
            return I18n.t(kind());
        }
    }

    interface Listener { void progress(float p); void device(Dev d); void done(List<Dev> all); }

    // ---------- ip utils ----------
    static String ipString(long ip) { return ((ip >> 24) & 255) + "." + ((ip >> 16) & 255) + "." + ((ip >> 8) & 255) + "." + (ip & 255); }
    static long ipLong(String s) {
        try { byte[] b = InetAddress.getByName(s).getAddress(); return ((b[0] & 255L) << 24) | ((b[1] & 255L) << 16) | ((b[2] & 255L) << 8) | (b[3] & 255L); } catch (Exception e) { return 0; }
    }
    // returns {ip, prefix} or null
    static long[] localNet() {
        try {
            long[] best = null;
            for (NetworkInterface ni : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!ni.isUp() || ni.isLoopback()) continue;
                String name = ni.getName();
                for (InterfaceAddress ia : ni.getInterfaceAddresses()) {
                    if (!(ia.getAddress() instanceof Inet4Address) || !ia.getAddress().isSiteLocalAddress()) continue;
                    long[] cand = {ipLong(ia.getAddress().getHostAddress()), ia.getNetworkPrefixLength()};
                    if (name.startsWith("wlan") || name.startsWith("ap") || name.startsWith("eth")) return cand;
                    if (best == null && !name.startsWith("rmnet") && !name.startsWith("ccmni")) best = cand;
                }
            }
            return best;
        } catch (Exception e) { return null; }
    }

    // ---------- OUI ----------
    static HashMap<String, String> oui;
    static synchronized String vendor(Context c, String mac) {
        if (mac == null || mac.length() < 8) return null;
        try {
            if (oui == null) {
                oui = new HashMap<>(50000);
                BufferedReader r = new BufferedReader(new InputStreamReader(c.getAssets().open("oui.txt"), "UTF-8"));
                String l;
                while ((l = r.readLine()) != null) if (l.length() > 6) oui.put(l.substring(0, 6), l.substring(6));
                r.close();
            }
            String key = mac.replace(":", "").toUpperCase(Locale.US).substring(0, 6);
            return oui.get(key);
        } catch (Exception e) { return null; }
    }

    // ---------- ARP ----------
    static Map<Long, String> readArp() {
        Map<Long, String> m = new HashMap<>();
        try {
            BufferedReader r = new BufferedReader(new FileReader("/proc/net/arp"));
            r.readLine();
            String l;
            while ((l = r.readLine()) != null) {
                String[] p = l.trim().split("\\s+");
                if (p.length >= 4 && !p[3].equals("00:00:00:00:00:00") && !p[2].equals("0x0")) m.put(ipLong(p[0]), p[3].toUpperCase(Locale.US));
            }
            r.close();
        } catch (Exception e) { }
        return m;
    }

    // ---------- ping via system binary ----------
    static double ping(String host, int timeoutSec) {
        try {
            Process p = new ProcessBuilder("ping", "-c", "1", "-W", String.valueOf(timeoutSec), host).redirectErrorStream(true).start();
            BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
            String l; double ms = -1;
            while ((l = r.readLine()) != null) {
                int i = l.indexOf("time=");
                if (i >= 0) { String s = l.substring(i + 5).trim(); s = s.split(" ")[0]; try { ms = Double.parseDouble(s); } catch (Exception e) { } }
            }
            p.waitFor();
            return ms;
        } catch (Exception e) { return -1; }
    }

    // TCP probe: returns 1 open, 0 refused (host alive), -1 no answer
    static int tcp(long ip, int port, int timeoutMs) {
        Socket s = new Socket();
        try {
            s.connect(new InetSocketAddress(ipString(ip), port), timeoutMs);
            return 1;
        } catch (ConnectException e) {
            String m = String.valueOf(e.getMessage());
            return (m.contains("refused") || m.contains("ECONNREFUSED")) ? 0 : -1;
        } catch (Exception e) { return -1; } finally { try { s.close(); } catch (Exception e) { } }
    }

    static final int[] PROBE_PORTS = {80, 443, 62078, 22, 53, 445, 139, 7000, 8008, 8009, 8080, 9100, 631, 554, 548, 5000};
    static final Map<Integer, String> PORT_NAMES = new LinkedHashMap<>();
    static {
        Object[] a = {21, "FTP", 22, "SSH", 23, "Telnet", 25, "SMTP", 53, "DNS", 80, "HTTP", 110, "POP3", 135, "MS-RPC", 139, "NetBIOS", 143, "IMAP", 443, "HTTPS", 445, "SMB",
            515, "LPD", 548, "AFP", 554, "RTSP", 631, "IPP", 1883, "MQTT", 1900, "UPnP", 3000, "Dev", 3389, "RDP", 5000, "UPnP/NAS", 5900, "VNC", 7000, "AirPlay",
            8000, "HTTP-alt", 8008, "Cast", 8009, "Cast", 8080, "HTTP-alt", 8443, "HTTPS-alt", 8888, "HTTP-alt", 9100, "Printer", 32400, "Plex", 62078, "iOS device"};
        for (int i = 0; i < a.length; i += 2) PORT_NAMES.put((Integer) a[i], (String) a[i + 1]);
    }

    static List<Integer> portScan(final long ip, Collection<Integer> ports, final int timeout) {
        final List<Integer> open = Collections.synchronizedList(new ArrayList<Integer>());
        ExecutorService ex = Executors.newFixedThreadPool(24);
        for (final int p : ports) ex.submit(() -> { if (tcp(ip, p, timeout) == 1) open.add(p); });
        ex.shutdown();
        try { ex.awaitTermination(15, TimeUnit.SECONDS); } catch (Exception e) { }
        List<Integer> r = new ArrayList<>(open);
        Collections.sort(r);
        return r;
    }

    // ---------- name queries ----------
    static String dnsName(byte[] b, int len, int pos) {
        StringBuilder sb = new StringBuilder();
        int guard = 0;
        while (pos < len && guard++ < 20) {
            int l = b[pos] & 255;
            if (l == 0) break;
            if ((l & 0xC0) == 0xC0) { if (pos + 1 >= len) break; pos = ((l & 0x3F) << 8) | (b[pos + 1] & 255); continue; }
            if (pos + 1 + l > len) break;
            if (sb.length() > 0) sb.append('.');
            sb.append(new String(b, pos + 1, l));
            pos += 1 + l;
        }
        return sb.toString();
    }
    static byte[] udp(long ip, int port, byte[] q, int timeout) {
        DatagramSocket s = null;
        try {
            s = new DatagramSocket();
            s.setSoTimeout(timeout);
            s.send(new DatagramPacket(q, q.length, InetAddress.getByName(ipString(ip)), port));
            byte[] buf = new byte[1024];
            DatagramPacket d = new DatagramPacket(buf, buf.length);
            s.receive(d);
            return Arrays.copyOf(buf, d.getLength());
        } catch (Exception e) { return null; } finally { if (s != null) s.close(); }
    }
    static String mdnsName(long ip) {
        try {
            ByteArrayOutputStream o = new ByteArrayOutputStream();
            o.write(new byte[]{0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0});
            String rev = (ip & 255) + "." + ((ip >> 8) & 255) + "." + ((ip >> 16) & 255) + "." + ((ip >> 24) & 255) + ".in-addr.arpa";
            for (String l : rev.split("\\.")) { o.write(l.length()); o.write(l.getBytes()); }
            o.write(new byte[]{0, 0, 12, (byte) 0x80, 1});
            byte[] r = udp(ip, 5353, o.toByteArray(), 600);
            if (r == null || r.length < 12 || ((r[6] & 255) == 0 && (r[7] & 255) == 0)) return null;
            int pos = 12, qd = ((r[4] & 255) << 8) | (r[5] & 255);
            for (int i = 0; i < qd; i++) { while (pos < r.length && r[pos] != 0) { if ((r[pos] & 0xC0) == 0xC0) { pos++; break; } pos += (r[pos] & 255) + 1; } pos += 5; }
            while (pos < r.length && r[pos] != 0) { if ((r[pos] & 0xC0) == 0xC0) { pos++; break; } pos += (r[pos] & 255) + 1; }
            pos += 1;
            if (pos + 10 > r.length) return null;
            int type = ((r[pos] & 255) << 8) | (r[pos + 1] & 255);
            pos += 10;
            if (type != 12) return null;
            String nm = dnsName(r, r.length, pos);
            String first = nm.split("\\.")[0];
            return first.length() > 0 ? first : null;
        } catch (Exception e) { return null; }
    }
    static String nbnsName(long ip) {
        try {
            byte[] q = new byte[50];
            q[0] = 0x4E; q[1] = 0x42; q[5] = 1; q[12] = 0x20; q[13] = 'C'; q[14] = 'K';
            for (int i = 0; i < 30; i++) q[15 + i] = 'A';
            q[47] = 0x21; q[49] = 1;
            byte[] r = udp(ip, 137, q, 600);
            if (r == null || r.length < 70) return null;
            int pos = 12;
            if ((r[pos] & 255) == 0xC0) pos += 2; else pos += 34;
            pos += 10;
            if (pos + 16 > r.length || (r[pos] & 255) < 1) return null;
            String nm = new String(r, pos + 1, 15).trim();
            return nm.length() > 0 ? nm : null;
        } catch (Exception e) { return null; }
    }
    static String reverseDns(final long ip) {
        ExecutorService ex = Executors.newSingleThreadExecutor();
        try {
            Future<String> f = ex.submit(() -> {
                String ipS = ipString(ip);
                String h = InetAddress.getByName(ipS).getCanonicalHostName();
                return (h == null || h.equals(ipS)) ? null : h.split("\\.")[0];
            });
            return f.get(1500, TimeUnit.MILLISECONDS);
        } catch (Exception e) { return null; } finally { ex.shutdownNow(); }
    }

    // ---------- NSD (Bonjour) ----------
    static class Bonjour {
        NsdManager nsd; WifiManager.MulticastLock lock;
        final List<NsdManager.DiscoveryListener> listeners = new ArrayList<>();
        final LinkedList<NsdServiceInfo> queue = new LinkedList<>();
        boolean resolving, stopped;
        final Map<Long, String> names = new ConcurrentHashMap<>();
        final Map<Long, Set<String>> types = new ConcurrentHashMap<>();
        void start(Context c) {
            try {
                WifiManager wm = (WifiManager) c.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
                lock = wm.createMulticastLock("netscope"); lock.setReferenceCounted(false); lock.acquire();
                nsd = (NsdManager) c.getSystemService(Context.NSD_SERVICE);
                String[] ts = {"_http._tcp", "_airplay._tcp", "_raop._tcp", "_googlecast._tcp", "_ipp._tcp", "_printer._tcp", "_smb._tcp", "_device-info._tcp", "_companion-link._tcp", "_workstation._tcp", "_hap._tcp", "_spotify-connect._tcp", "_ssh._tcp", "_androidtvremote2._tcp", "_adb._tcp"};
                for (final String t : ts) {
                    NsdManager.DiscoveryListener l = new NsdManager.DiscoveryListener() {
                        public void onStartDiscoveryFailed(String s, int e) { }
                        public void onStopDiscoveryFailed(String s, int e) { }
                        public void onDiscoveryStarted(String s) { }
                        public void onDiscoveryStopped(String s) { }
                        public void onServiceLost(NsdServiceInfo i) { }
                        public void onServiceFound(NsdServiceInfo i) { synchronized (queue) { queue.add(i); } pump(); }
                    };
                    listeners.add(l);
                    try { nsd.discoverServices(t, NsdManager.PROTOCOL_DNS_SD, l); } catch (Exception e) { }
                }
            } catch (Exception e) { }
        }
        void pump() {
            final NsdServiceInfo i;
            synchronized (queue) { if (resolving || stopped || queue.isEmpty()) return; i = queue.poll(); resolving = true; }
            try {
                nsd.resolveService(i, new NsdManager.ResolveListener() {
                    public void onResolveFailed(NsdServiceInfo s, int e) { synchronized (queue) { resolving = false; } pump(); }
                    public void onServiceResolved(NsdServiceInfo s) {
                        try {
                            InetAddress a = s.getHost();
                            if (a instanceof Inet4Address) {
                                long ip = ipLong(a.getHostAddress());
                                String type = s.getServiceType() == null ? "" : s.getServiceType();
                                names.put(ip, s.getServiceName() == null ? "" : s.getServiceName());
                                Set<String> set = types.get(ip);
                                if (set == null) { set = Collections.synchronizedSet(new HashSet<String>()); types.put(ip, set); }
                                set.add(type);
                            }
                        } catch (Exception e) { }
                        synchronized (queue) { resolving = false; } pump();
                    }
                });
            } catch (Exception e) { synchronized (queue) { resolving = false; } }
        }
        void stop() {
            stopped = true;
            for (NsdManager.DiscoveryListener l : listeners) try { nsd.stopServiceDiscovery(l); } catch (Exception e) { }
            try { if (lock != null && lock.isHeld()) lock.release(); } catch (Exception e) { }
        }
    }

    // ---------- scanner ----------
    static void scan(final Context ctx, final Bonjour bj, final Listener L) {
        new Thread(() -> {
            long[] ln = localNet();
            if (ln == null) { L.done(new ArrayList<Dev>()); return; }
            int prefix = (int) ln[1];
            if (prefix < 22 || prefix > 30) prefix = 24;
            final long mask = (0xFFFFFFFFL << (32 - prefix)) & 0xFFFFFFFFL;
            final long base = ln[0] & mask;
            final long count = (~mask) & 0xFFFFFFFFL;
            final long me = ln[0];
            final Map<Long, Dev> found = new ConcurrentHashMap<>();
            final AtomicInteger done = new AtomicInteger();
            Dev self = new Dev(); self.ip = me; self.me = true; self.ping = 0; found.put(me, self);
            L.device(self);
            ExecutorService ex = Executors.newFixedThreadPool(20);
            for (long i = 1; i < count; i++) {
                final long ip = base + i;
                if (ip == me) { done.incrementAndGet(); continue; }
                ex.submit(() -> {
                    try {
                        double ms = ping(ipString(ip), 1);
                        boolean alive = ms >= 0;
                        List<Integer> open = new ArrayList<>();
                        int[] ports = alive ? PROBE_PORTS : new int[]{80, 443, 62078, 445};
                        for (int p : ports) {
                            int r = tcp(ip, p, alive ? 250 : 200);
                            if (r >= 0) alive = true;
                            if (r == 1) open.add(p);
                        }
                        if (alive) {
                            Dev d = new Dev(); d.ip = ip; d.ping = ms; d.ports = open;
                            if (found.putIfAbsent(ip, d) == null) L.device(d);
                        }
                    } finally {
                        int dc = done.incrementAndGet();
                        if (dc % 8 == 0) L.progress(0.9f * dc / (float) count);
                    }
                });
            }
            ex.shutdown();
            try { ex.awaitTermination(60, TimeUnit.SECONDS); } catch (Exception e) { }
            // ARP: adds MACs (and hosts that only answered ARP). May be blocked on Android 10+.
            Map<Long, String> arp = readArp();
            for (Map.Entry<Long, String> e : arp.entrySet()) {
                long ip = e.getKey();
                if ((ip & mask) != base || ip == me) continue;
                Dev d = found.get(ip);
                if (d == null) { d = new Dev(); d.ip = ip; found.put(ip, d); L.device(d); }
                d.mac = e.getValue();
            }
            // names, vendor, latency
            ExecutorService ex2 = Executors.newFixedThreadPool(8);
            for (final Dev d : found.values()) {
                if (d.me) continue;
                ex2.submit(() -> {
                    String h = reverseDns(d.ip);
                    if (h == null) h = mdnsName(d.ip);
                    if (h == null) h = nbnsName(d.ip);
                    if (h != null) d.host = h;
                    if (d.mac != null) d.vendor = vendor(ctx, d.mac);
                    double best = -1;
                    for (int k = 0; k < 2; k++) { double p = ping(ipString(d.ip), 1); if (p >= 0 && (best < 0 || p < best)) best = p; }
                    d.ping = best;
                });
            }
            ex2.shutdown();
            try { ex2.awaitTermination(30, TimeUnit.SECONDS); } catch (Exception e) { }
            if (bj != null) {
                for (Dev d : found.values()) {
                    String n = bj.names.get(d.ip); if (n != null && n.length() > 0) d.bonjour = n;
                    Set<String> t = bj.types.get(d.ip); if (t != null) d.services.addAll(t);
                }
            }
            List<Dev> all = new ArrayList<>(found.values());
            Collections.sort(all, (a, b) -> Long.compare(a.ip, b.ip));
            L.progress(1f);
            L.done(all);
        }).start();
    }
                  }
