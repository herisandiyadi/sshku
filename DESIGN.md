# DESIGN.md — SSHKU

Sumber kebenaran identitas visual SSHKU. Diekstrak dari token aktual di
`lib/core/theme/` — bukan tren, bukan default model. Dipakai bersama skill
`antislop` + `antislop-ui`: setiap keputusan warna/layout/motion mengacu ke sini.

---

## 1. Produk & Karakter

- **Apa:** klien SSH mobile — kelola server, terminal interaktif, jalankan command.
- **Audiens:** DevOps, sysadmin, developer — pengguna teknis, satu tangan, di ponsel.
- **Karakter visual:** _tenang, teknis, padat, tanpa hiasan._ Terminal adalah bintangnya;
  UI di sekelilingnya harus minggir dan tidak berebut perhatian.
- **Tema:** **dark-first** — ini keputusan sadar (R-21), bukan tren "biar terlihat tech":
  alat terminal dipakai lama, sering di lingkungan gelap, dan teks monospace terang di
  latar gelap adalah konvensi terminal yang sah. Light theme tetap disediakan & fungsional.

---

## 2. Palet (sumber: `app_colors.dart`)

Batas palet aktif: **2–3 core + 1 accent** (R-29). Di sini core-nya adalah latar gelap
berjenjang (background/surface) + teks; **primary teal adalah satu-satunya accent**.

| Peran | Token | Hex | Pemakaian |
|-------|-------|-----|-----------|
| Accent (primary) | `AppColors.primary` | `#00BFA5` (teal) | **Momen kunci saja**: CTA utama, fokus, command/kode, indikator SAFE. Bukan untuk setiap ikon/border. |
| Base gelap | `AppColors.background` | `#121212` | Latar scaffold. |
| Surface | `AppColors.surface` | `#1E1E1E` | AppBar, kartu, bottom sheet — satu tingkat di atas background. |
| Teks utama | `AppColors.onSurface` / `onBackground` | `#E0E0E0` | Body & judul. |
| Di atas accent | `AppColors.onPrimary` | `#000000` | Teks/ikon di atas tombol primary. |
| Error / danger | `AppColors.error` | `#CF6679` | State merah: error, DANGEROUS, blocked, aksi hapus. |

**Light theme** (sekunder): background `#FFFFFF`, surface `#F5F5F5`, teks `#1C1B1F`,
error `#B00020`, primary tetap teal.

**Warna semantik tambahan** (dipakai sedikit, hanya untuk state):
- Caution / warning: `#E0A100` (amber) — dipakai pada badge risiko CAUTION.

### Aturan accent (mengikat)
- Teal `#00BFA5` muncul **hanya** di: CTA primary, teks command/kode, dan penanda state SAFE.
- **DILARANG**: teal di setiap ikon, border, garis, glow sekaligus (R- accent). Kalau
  ragu, biarkan elemen memakai `onSurface`/`surface`, bukan accent.
- **DILARANG** gradient biru-ungu / neon / orb radial sebagai treatment (R-01).

---

## 3. Tipografi (sumber: `app_typography.dart`)

- **Body:** default sistem (Roboto di Android), `w400`. `bodyLarge` 16 / `bodyMedium` 14.
  Tidak memaksa font kustom — keterbacaan di atas gaya (R-06).
- **Kode/command:** `monospace` (fallback Courier New/Courier), warna teal. **Monospace hanya
  untuk konten kode nyata** (command, output, key) — bukan sebagai estetika judul (R-06).
- **DILARANG:** judul monospace besar, uppercase ber-letter-spacing ekstrem sebagai hiasan.
  Uppercase hanya untuk label state pendek yang menandai state nyata (mis. badge risiko).

---

## 4. Spasi, Radius, Elevasi (sumber: `app_spacing.dart`)

- **Spacing scale:** `xs 4 · sm 8 · md 16 · lg 24 · xl 32`. Pakai berjenjang untuk rhythm;
  jangan seragamkan semua section (R-05).
- **Radius:** `sm 4 · md 8 · lg 12`. Set kecil, dipakai deliberat (R-11). Bukan pill di
  semua elemen. Default kartu/input/sheet: `md (8)`.
- **Elevasi/shadow:** minimal. Surface dibedakan lewat **warna berjenjang**
  (background → surface), bukan shadow di mana-mana (R-12). Shadow hanya untuk 1–2 elemen
  yang benar-benar perlu naik (mis. sheet modal).
- **Glass/glow:** **tidak dipakai.** Dose cap 0 kecuali ada alasan tertulis (R-10, R-13).

---

## 5. Ikon (R-04)

- Pilih ikon **berdasarkan relevansi fungsi**, bukan kosakata "AI" generik.
- **DILARANG sebagai default:** sparkle/`auto_awesome`, magic, robot, diamond, orb sebagai
  ikon fitur AI. Untuk fitur AI Command, pakai glyph yang menandai aksinya (mis.
  `terminal`, `keyboard_command_key`) — bukan bintang ajaib.
- **Tanpa emoji** di teks UI (heading, bullet, tombol) (R-04).
- Arrow (`→`) bukan identitas default tombol; hanya bila benar-benar memberi arah (R-08).

---

## 6. Dial Antislop (deklarasi untuk skill)

- **RHYTHM = 2** — section/komponen bervariasi sesuai kebutuhan konten; tidak semua kartu
  seragam, tidak semua spasi sama. Bukan mosaik bento tanpa alasan.
- **MOTION = 1** — hanya state hover/press & transisi fungsional (loading, buka sheet).
  **Tanpa** pulse/loop/float abadi (R-19). Indikator berkedip hanya untuk state live nyata.
- **Accent = 1** — satu accent (teal) di momen kunci.

---

## 7. State & Kejujuran (R-17, R-18, R-23, R-27, R-38)

- Angka, daftar, feed = data nyata atau placeholder berlabel jujur. Tidak ada metrik/nama
  palsu (mis. tidak ada "John Doe", tidak ada "+12% this week" tanpa seri nyata).
- Empty/loading/error state menyebut **sebab + aksi berikutnya**, bukan sekadar "No data".
- Setiap item nav & kontrol punya destinasi/aksi nyata, atau label "Coming soon" (R-24, R-26).
- Dot berwarna hanya menandai state nyata (active/live/warning), tanpa glow/pulse hias (R-31).

---

## 8. Catatan penerapan pada fitur AI Command

- Badge risiko `SAFE`/`CAUTION`/`DANGEROUS`/`BLOCKED` = **penanda state nyata** → boleh
  uppercase + warna (teal/amber/error). Ini fungsional, bukan hiasan.
- Ikon tombol AI di AppBar terminal & header panel: **hindari `auto_awesome`** (sparkle) —
  ganti ke glyph relevan terminal/AI-command. (Perbaikan tertunda; lihat
  `docs/ai-command-code-review.md` bila dijadikan item.)
- Bottom sheet AI: surface `#1E1E1E`, radius `md`, tanpa glow. Sudah sesuai.
