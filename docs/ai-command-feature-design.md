# Desain Fitur: AI Command

## Info Dokumen

| Field | Nilai |
|-------|-------|
| Produk | SSHKU |
| Fitur | AI Command (natural language → terminal input) |
| Versi | 0.1 (Draft desain, pra-implementasi) |
| Status | Draft — menunggu persetujuan |
| Tanggal | 2026-09-28 |
| Sumber acuan | `docs/ai-agent-ideation.md`, `docs/ai-agent-terminal-prd.md` |

> Dokumen ini adalah desain implementasi ringkas untuk versi pertama yang benar-benar
> akan dibangun. PRD lengkap (`ai-agent-terminal-prd.md`) tetap jadi acuan visi jangka
> panjang; di sini ruang lingkup sengaja dipersempit ke permintaan konkret:
> **AI menuliskan command ke terminal, user cukup memberi instruksi, dan konfigurasi
> AI (base URL provider + API key) diletakkan di Settings.**

---

## 1. Ruang Lingkup

### Termasuk (v1)
- Input instruksi natural language dari user (mendukung EN/ID).
- AI menerjemahkan instruksi → satu atau beberapa shell command.
- Command ditampilkan sebagai preview; user menyetujui sebelum dieksekusi.
- Command yang disetujui **diketikkan ke shell terminal aktif** (alur PTY yang sudah ada).
- Konfigurasi di Settings: **Base URL provider**, **API Key**, dan **nama model**.
- API key disimpan terenkripsi (Android Keystore, reuse `CredentialManager`).

### Tidak Termasuk (v1)
- Tidak menyediakan API key (model BYOK — user membawa key sendiri).
- Tidak ada auto-execute tanpa persetujuan (semua command wajib di-preview).
- Tidak ada background task, task history persist, atau integrasi SFTP/Docker (menyusul).
- Tidak ada tiering/paywall (IAP di luar scope dokumen ini).
- Tidak ada multi-step otonom (AI tidak membaca output lalu lanjut sendiri di v1).

---

## 2. Keputusan Desain Utama & Alasannya

### 2.1 Cara AI menjalankan command → "mengetik" ke shell, bukan `execute()`

Terminal SSHKU adalah **shell PTY interaktif**. `TerminalCubit.sendInput(String)` mengirim
keystroke mentah ke shell via isolate (`DartSshService.sendInput`). Sudah ada juga
`DartSshService.execute(cmd)` yang menjalankan command lewat channel `run()` terpisah —
**tetapi** output-nya tidak masuk ke buffer terminal dan tidak berbagi working directory /
environment dengan sesi shell user.

**Keputusan:** command yang disetujui dikirim lewat `sendInput('<command>\r')` — identik
dengan user mengetik lalu menekan Enter. Konsekuensi:
- Output langsung tampil di terminal seperti biasa (tidak perlu UI output terpisah).
- Command otomatis tercatat di `command_history` (logika logging di `sendInput` sudah ada).
- Working directory & env konsisten dengan sesi user.

> `ponytail:` v1 tidak menangkap exit code / output command untuk dianalisis AI. Jalur
> analisis output (mis. "Ask AI to fix") butuh capture stdout+exit code — ditunda ke iterasi
> berikut, kemungkinan lewat `execute()` atau sentinel marker di shell.

### 2.2 Penyimpanan konfigurasi → SharedPreferences + Keystore

Mengikuti pola eksisting: `SettingsCubit` sudah pakai `SharedPreferences`, dan penyimpanan
rahasia (password SSH) pakai `CredentialManager` → Android Keystore platform channel.

**Keputusan:**
- `SharedPreferences`: `ai_base_url`, `ai_model`, `ai_provider` (non-sensitif).
- **Keystore** (`CredentialManager.encryptPassword`): API key → simpan ciphertext-nya di
  `SharedPreferences` (`ai_api_key_enc`). Key plaintext tidak pernah ditulis ke disk.
- Tidak menambah tabel DB untuk config (cukup key-value).

### 2.3 Format API provider → OpenAI-compatible Chat Completions

Base URL yang bisa diisi user menandakan target utamanya adalah endpoint
**OpenAI-compatible** (`POST {baseUrl}/chat/completions`) — pola ini didukung OpenAI,
Groq, OpenRouter, Ollama, LM Studio, banyak gateway lokal, dan mudah diadaptasi.

**Keputusan:** v1 menargetkan satu kontrak: OpenAI-compatible Chat Completions dengan
header `Authorization: Bearer <key>`. Gemini/Claude native (skema berbeda) ditunda; user
yang pakai keduanya bisa lewat gateway OpenAI-compatible.

> `ponytail:` menghindari 3 datasource terpisah (OpenAI/Gemini/Claude) seperti di PRD.
> Satu adapter OpenAI-compatible menutup mayoritas kasus dengan kode paling sedikit.
> Naik ke multi-provider native saat ada permintaan nyata.

### 2.4 Dependency baru → `http`

Belum ada HTTP client di `pubspec.yaml`. Tambah `http` (paket resmi Dart, ringan). Tidak
perlu `dio` — kebutuhan hanya satu POST JSON.

### 2.5 Safety → blocklist + preview wajib (subset PRD §6)

Ambil inti safety PRD tanpa over-engineering: **preview wajib** (sudah menutup risiko
utama karena tidak ada yang jalan tanpa mata user) + **blocklist keras** untuk pola
katastrofik. Klasifikasi risiko 3-tingkat (Safe/Caution/Dangerous) disederhanakan jadi
penanda visual opsional; yang mengikat adalah blocklist + approval.

Blocklist minimal (regex, case-insensitive, cek terhadap tiap command hasil AI):
- `rm -rf /`, `rm -rf /*`, `rm -rf ~`
- `mkfs`, `dd if=... of=/dev/sd*`
- fork bomb `:(){ :|:& };:`
- `chmod -R 000 /`, `chmod -R 777 /`
- `> /dev/sd*`
- `shutdown`, `reboot`, `init 0`

Command yang kena blocklist tidak bisa disetujui; user diberi penjelasan dan diarahkan
mengetik manual bila benar-benar perlu.

---

## 3. Alur Pengguna

```
1. User buka terminal (sesi SSH aktif seperti biasa).
2. User tap tombol "AI" di AppBar terminal → panel input AI muncul.
   - Jika AI belum dikonfigurasi → arahkan ke Settings > AI Command.
3. User ketik instruksi, mis. "restart nginx dan cek statusnya".
4. AI Command Cubit kirim prompt (+ konteks) ke provider → terima daftar command.
5. Panel preview menampilkan command + deskripsi singkat + penanda risiko.
   - Command kena blocklist → ditandai terblokir, tidak bisa disetujui.
6. User: [Setujui & Jalankan] / [Edit] / [Batal].
7. Command disetujui → dikirim ke shell via sendInput('<cmd>\r') satu per satu.
8. Output tampil di terminal seperti biasa.
```

### State AI Command Cubit
```
AiIdle
  → AiGenerating        (menunggu respons provider)
  → AiPreview(commands) (ada hasil, menunggu approval)   | AiError(msg)
AiPreview
  → AiExecuting         (mengetik command ke shell)
  → AiIdle              (batal)
AiExecuting
  → AiIdle              (selesai dikirim)
```

---

## 4. Kontrak Provider (OpenAI-compatible)

**Request** — `POST {baseUrl}/chat/completions`
```json
{
  "model": "<ai_model>",
  "messages": [
    { "role": "system", "content": "<system prompt>" },
    { "role": "user", "content": "<instruksi user>" }
  ],
  "temperature": 0.2
}
```
Header: `Authorization: Bearer <api_key>`, `Content-Type: application/json`.

**System prompt (draft)** — meminta AI membalas JSON murni:
```
You are a shell command generator for an SSH terminal.
Target shell: bash on Linux (assume POSIX if unknown).
Return ONLY valid minified JSON, no prose, matching:
{"commands":[{"cmd":"string","desc":"string"}]}
Rules:
- Prefer safe, reversible commands.
- Never include destructive filesystem or disk commands.
- If the request is ambiguous, return a single command that inspects state first.
- Output one command per logical step.
```

**Parsing respons:** ambil `choices[0].message.content`, parse sebagai JSON ke
`List<AiCommand>`. Jika parsing gagal (model membungkus dengan teks), fallback: ekstraksi
blok JSON pertama; jika tetap gagal → `AiError` dengan pesan "AI response tidak dapat
dibaca, coba lagi".

---

## 5. Struktur Modul (mengikuti Clean Architecture repo)

```
lib/features/ai_command/
├── data/
│   ├── models/
│   │   └── ai_command.dart          # {cmd, desc, blocked, riskHint}
│   ├── datasources/
│   │   └── ai_provider_datasource.dart   # HTTP POST ke chat/completions
│   └── repositories/
│       └── ai_config_repository.dart     # baca/tulis config (prefs + Keystore)
├── domain/
│   ├── safety_engine.dart           # cek blocklist + penanda risiko
│   └── prompt_builder.dart          # rakit system prompt (+ konteks OS jika ada)
└── presentation/
    ├── cubit/
    │   ├── ai_command_cubit.dart
    │   └── ai_command_state.dart
    └── widgets/
        ├── ai_input_panel.dart      # input instruksi (bottom sheet / panel)
        └── ai_preview_card.dart     # preview command + tombol approve/edit/cancel
```

Settings (extend fitur yang ada, bukan modul baru):
```
lib/features/settings/presentation/pages/ai_config_page.dart   # form base URL, key, model, Test
```
Config dibaca lewat `AiConfigRepository` yang sama.

### Titik integrasi ke kode eksisting
| Sumber | Target | Perubahan |
|--------|--------|-----------|
| `terminal_page.dart` | AppBar | Tambah tombol "AI" → buka `AiInputPanel` (hanya jika config ada) |
| `AiCommandCubit` | `TerminalCubit.sendInput` | Kirim command yang disetujui ke shell |
| `settings_page.dart` | section baru "AI Command" | ListTile → `AiConfigPage` |
| `CredentialManager` | `AiConfigRepository` | Reuse encrypt/decrypt untuk API key |

---

## 6. Halaman Settings — AI Command

Field:
- **Provider Base URL** (text) — mis. `https://api.openai.com/v1`, `http://192.168.1.10:11434/v1`.
- **API Key** (obscure + toggle show/hide) — boleh kosong untuk endpoint lokal tanpa auth.
- **Model** (text) — mis. `gpt-4o-mini`, `llama3.1`.
- **Test Connection** — kirim satu request minimal, tampilkan sukses/gagal + pesan error jelas.
- Aksi hapus konfigurasi (hapus key dari Keystore + prefs).

Validasi: base URL wajib bila fitur diaktifkan; key tidak pernah di-log; simpan hanya
setelah user menekan Save.

---

## 7. Verifikasi (self-check minimal per ponytail)

Logika non-trivial yang wajib punya satu check runnable:
1. **`SafetyEngine`** — test unit: pola blocklist (`rm -rf /`, fork bomb, dll) → `blocked=true`;
   command aman (`ls`, `systemctl status nginx`) → `blocked=false`. (`test/ai_command/safety_engine_test.dart`)
2. **Parsing respons AI** — test unit: JSON valid → list command; JSON dibungkus teks →
   fallback ekstraksi; sampah → error. (`test/ai_command/ai_response_parse_test.dart`)

Widget/HTTP tidak dites di v1 (butuh mock jaringan) kecuali diminta. Seam yang disepakati
untuk TDD: `SafetyEngine` dan parser respons.

---

## 8. Pertanyaan Terbuka (perlu keputusan Anda)

1. **Multi-command approval:** setujui semua sekaligus, atau satu per satu? (rekomendasi: satu
   per satu untuk keamanan, dengan opsi "Setujui semua" untuk urutan yang semuanya Safe).
2. **Provider native (Gemini/Claude):** cukup OpenAI-compatible di v1? (rekomendasi: ya).
3. **Konteks OS ke prompt:** kirim hasil `uname -a`/shell type ke AI untuk akurasi? Ini butuh
   `execute()` sekali saat sesi mulai. (rekomendasi: v1 tanpa itu, asumsikan bash/Linux;
   tambah nanti jika akurasi kurang).
4. **Lokasi entry point:** tombol AI di AppBar terminal saja, atau juga floating action?
   (rekomendasi: AppBar, konsisten dengan tombol keyboard yang ada).
5. **Bahasa balasan `desc`:** ikut bahasa instruksi user atau selalu Inggris? (rekomendasi:
   ikut bahasa instruksi).

---

*Draft desain — belum ada kode yang diubah. Menunggu konfirmasi sebelum implementasi.*
