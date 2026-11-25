package com.jo0sef.netscope;

import android.content.Context;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.*;

public class UI {
    static float dens = 3;
    static boolean dark = true;
    static int accent = 0xFF0A84FF;
    static final int[] ACCENTS = {0xFF0A84FF, 0xFFBF5AF2, 0xFF30D158, 0xFFFF9F0A, 0xFFFF2D55, 0xFFFF453A, 0xFFFFD60A, 0xFF00E5FF, 0xFF8E8E93};
    static final String[] ACCENT_NAMES = {"Ocean", "Violet", "Mint", "Sunset", "Rose", "Crimson", "Gold", "Cyber", "Graphite"};

    static int dp(float v) { return Math.round(v * dens); }
    static int bg() { return dark ? 0xFF000000 : 0xFFFFFFFF; }
    static int fg() { return dark ? 0xFFFFFFFF : 0xFF000000; }
    static int fg2() { return dark ? 0x99FFFFFF : 0x99000000; }
    static int fg3() { return dark ? 0x66FFFFFF : 0x66000000; }

    static GradientDrawable round(int fill, int stroke, float r) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setCornerRadius(dp(r));
        if (stroke != 0) g.setStroke(dp(1), stroke);
        return g;
    }

    static LinearLayout card(Context c) {
        LinearLayout l = new LinearLayout(c);
        l.setOrientation(LinearLayout.VERTICAL);
        l.setBackground(round(dark ? 0x1CFFFFFF : 0x0D000000, dark ? 0x2EFFFFFF : 0x22000000, 22));
        l.setPadding(dp(16), dp(14), dp(16), dp(14));
        return l;
    }

    static LinearLayout.LayoutParams lp(int w, int h, int l, int t, int r, int b) {
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(w, h);
        p.setMargins(dp(l), dp(t), dp(r), dp(b));
        return p;
    }

    static TextView text(Context c, String s, float sp, boolean bold, int color) {
        TextView t = new TextView(c);
        t.setText(I18n.t(s));
        t.setTextSize(sp);
        t.setTextColor(color);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        return t;
    }

    static TextView button(Context c, String s, View.OnClickListener l) {
        TextView t = new TextView(c);
        t.setText(I18n.t(s));
        t.setTextSize(16);
        t.setTextColor(0xFFFFFFFF);
        t.setTypeface(Typeface.DEFAULT_BOLD);
        t.setGravity(Gravity.CENTER);
        t.setBackground(round(accent, 0, 16));
        t.setPadding(dp(12), 0, dp(12), 0);
        t.setOnClickListener(l);
        return t;
    }

    static class Seg extends LinearLayout {
        interface OnSel { void sel(int i); }
        TextView[] tabs;
        int sel;
        OnSel cb;
        Seg(Context c, String[] items, int selected, boolean translate, OnSel cb) {
            super(c);
            this.cb = cb;
            setOrientation(HORIZONTAL);
            setBackground(round(dark ? 0x22FFFFFF : 0x14000000, 0, 10));
            setPadding(dp(2), dp(2), dp(2), dp(2));
            tabs = new TextView[items.length];
            for (int i = 0; i < items.length; i++) {
                final int idx = i;
                TextView t = new TextView(c);
                t.setText(translate ? I18n.t(items[i]) : items[i]);
                t.setGravity(Gravity.CENTER);
                t.setTextSize(14);
                t.setTypeface(Typeface.DEFAULT_BOLD);
                t.setPadding(0, dp(8), 0, dp(8));
                t.setOnClickListener(v -> { select(idx); if (this.cb != null) this.cb.sel(idx); });
                addView(t, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
                tabs[i] = t;
            }
            select(selected);
        }
        void select(int i) {
            sel = i;
            for (int k = 0; k < tabs.length; k++) {
                tabs[k].setTextColor(k == i ? (dark ? 0xFFFFFFFF : 0xFF000000) : fg2());
                tabs[k].setBackground(k == i ? round(dark ? 0x44FFFFFF : 0x33FFFFFF | 0xFFFFFF & 0, 0, 8) : null);
                if (k == i && !dark) tabs[k].setBackground(round(0xFFFFFFFF, 0x22000000, 8));
            }
        }
    }

    static class Gauge extends View {
        double value;
        String main = "0", sub = "";
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        Gauge(Context c) { super(c); }
        void set(double v, String subtitle) {
            value = v;
            main = v < 10 ? String.format(java.util.Locale.US, "%.2f", v) : (v < 100 ? String.format(java.util.Locale.US, "%.1f", v) : String.format(java.util.Locale.US, "%.0f", v));
            sub = I18n.t(subtitle);
            invalidate();
        }
        void setSub(String s) { sub = I18n.t(s); invalidate(); }
        @Override protected void onDraw(Canvas cv) {
            float w = getWidth(), h = getHeight();
            float rad = Math.min(w, h) / 2 - dp(14);
            RectF r = new RectF(w / 2 - rad, h / 2 - rad, w / 2 + rad, h / 2 + rad);
            p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(dp(14)); p.setStrokeCap(Paint.Cap.ROUND);
            p.setColor(dark ? 0x22FFFFFF : 0x1A000000);
            cv.drawArc(r, 135, 270, false, p);
            double frac = Math.min(1, Math.log10(1 + value) / Math.log10(1001));
            if (frac > 0.003) { p.setColor(accent); cv.drawArc(r, 135, (float) (270 * frac), false, p); }
            p.setStyle(Paint.Style.FILL); p.setTextAlign(Paint.Align.CENTER);
            p.setColor(fg()); p.setTypeface(Typeface.DEFAULT_BOLD); p.setTextSize(dp(48));
            cv.drawText(main, w / 2, h / 2 + dp(8), p);
            p.setColor(fg2()); p.setTypeface(Typeface.DEFAULT); p.setTextSize(dp(15));
            cv.drawText(sub, w / 2, h / 2 + dp(34), p);
        }
    }
}
