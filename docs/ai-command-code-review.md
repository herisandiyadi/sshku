# Review Kode & Daftar Perbaikan — Fitur AI Command

## Info Dokumen

| Field | Nilai |
|-------|-------|
| Produk | SSHKU |
| Cakupan review | `lib/features/ai_command/**`, integrasi di `terminal_page.dart` & `settings/ai_config_page.dart`, seam `SshService` |
| Tanggal | 2026-09-28 |
| Status | ✅ Selesai — semua item (H1,H2,M1–M5,L1–L5) sudah diperbaiki & diverifikasi |

Review manual atas kode fitur AI Command yang baru ditambahkan. Setiap temuan diberi
prioritas dan rekomendasi. **Semua item sudah diperbaiki** (lihat penanda ✅ dan
"Status perbaikan" di tiap item). Verifikasi akhir: `flutter analyze` bersih pada file
fitur, `flutter test` → 99 test lulus.

Prioritas: 🔴 tinggi (bug/keamanan), 🟡 sedang (redundansi/desain), 🟢 rendah (rapi-rapi).

---

## 🔴 Prioritas Tinggi

### ✅ H1. Command dari AI tidak tercatat ke Command History (bug logika) — SELESAI

**Status perbaikan:** ditambahkan `TerminalCubit.runCommand(cmd)` yang mengirim `'$cmd\r'`,
mereset `_currentLine`, dan mencatat history sekali via `_logCommand` (dibagikan dengan
`sendInput`). `_openAiPanel` kini memanggil `runCommand`. Test: `run_command_test.dart`
(4 test) memverifikasi input `\r`, history 1×, dan baris manual berikutnya tidak rusak.

**Lokasi:** `terminal_cubit.dart` `sendInput()` ↔ `terminal_page.dart` `_openAiPanel`.

`_openAiPanel` mengirim command sebagai satu string utuh:
`terminalCubit.sendInput('$command\r')`. Namun `sendInput` mencatat history hanya bila
`input == '\r'` (per-keystroke), dan mengakumulasi `_currentLine` karakter demi karakter:

```dart
if (input == '\r' || input == '\n') { /* log _currentLine */ _currentLine = ''; }
else if (input.codeUnitAt(0) >= 32) { _currentLine += input; }
```

Karena input AI berupa `'restart nginx\r'` (bukan `'\r'` tunggal), maka:
1. Command **tidak pernah ter-log** ke tabel `command_history`.
2. Seluruh string (termasuk `\r`) ditambahkan ke `_currentLine`, sehingga **mengotori
   baris berikutnya** yang diketik user manual.

**Rekomendasi:** pisahkan "mengirim command AI" dari alur keystroke. Opsi:
- Tambah method eksplisit di `TerminalCubit`, mis. `runCommand(String cmd)` yang menulis
  ke `_ssh.sendInput('$cmd\r')` **dan** melakukan `insertHistory` sekali, lalu reset
  `_currentLine`. `_openAiPanel` memanggil ini alih-alih `sendInput`.
- Ini juga seam yang lebih benar untuk fitur AI (satu titik untuk logging/telemetri).

**Regresi test:** tambah test yang memverifikasi `runCommand` menulis satu baris history
dan tidak merusak `_currentLine`.

### ✅ H2. `http.Client` tidak pernah ditutup (resource leak) — SELESAI

**Status perbaikan:** `AiProviderDatasource.dispose()` menutup `_client`. `AiCommandCubit`
melacak kepemilikan (`_ownsDatasource`) dan menutup datasource di `close()` bila dibuatnya
sendiri. `AiConfigPage` memegang satu datasource dan menutupnya di `dispose()`.

**Lokasi:** `ai_provider_datasource.dart`.

`AiProviderDatasource` membuat `http.Client()` di konstruktor tapi tidak punya `dispose`/
`close`. Tiap instansiasi baru membuka client baru yang tak pernah ditutup.

Diperparah H3/H4: datasource diinstansiasi berkali-kali.

**Rekomendasi:** tambah `void dispose() => _client.close();`, panggil saat pemilik selesai
(mis. di `AiCommandCubit.close()`), atau gunakan satu `http.Client` yang dibagikan.

---

## 🟡 Prioritas Sedang

### ✅ M1. Wiring `AiConfigRepository(...)` diduplikasi — SELESAI

**Status perbaikan:** ditambahkan factory `AiConfigRepository.create()` yang merakit
`CredentialManager(KeystorePlatformChannel())`. `ai_input_panel` & `ai_config_page` memakai
factory; import wiring yang tak perlu dihapus.

**Lokasi:** `ai_input_panel.dart`, `ai_config_page.dart` (dan implicit di `AiCommandCubit`).

Rantai konstruksi yang sama diulang di ≥2 tempat. Belum ada factory/DI, padahal repo punya
`get_it` + `injectable` (walau `injection.config.dart` masih kosong).

**Rekomendasi (pilih satu):**
- Ringan: satu factory statis, mis. `AiConfigRepository.create()` yang merakit dependensinya.
- Konsisten dengan repo: daftarkan ke `get_it` bila DI mulai dipakai nyata.

### ✅ M2. `AiProviderDatasource()` diinstansiasi ulang — SELESAI

**Status perbaikan:** `AiConfigPage` kini memegang satu `_datasource` (dipakai untuk Test
Connection) dan menutupnya di `dispose()`. Cubit memakai satu instance dan menutupnya.

**Lokasi:** `ai_config_page._test()` membuat instance baru; `AiCommandCubit` juga membuat
default sendiri. Tiap instance = `http.Client` baru (lihat H2).

**Rekomendasi:** bagikan satu instance (via factory/DI) atau injeksikan dari pemilik.

### ✅ M3. "Test Connection" memakai `generate('echo hello')` — SELESAI

**Status perbaikan:** ditambahkan `AiProviderDatasource.testConnection()` yang mengirim
request minimal (`max_tokens: 1`) dan hanya memeriksa HTTP 2xx — tidak mewajibkan respons
ter-parse jadi command, sehingga tak lagi false-negative. `ai_config_page._test` memakainya.

**Lokasi:** `ai_config_page._test()`.

Uji koneksi memanggil `generate` penuh (system prompt + minta JSON command). Ini:
- Membebani model untuk menghasilkan JSON, bukan sekadar cek reachability/auth.
- Bisa **gagal parse** (`FormatException`) walau koneksi & key sebenarnya valid, sehingga
  melaporkan "Gagal" yang menyesatkan.

**Rekomendasi:** buat metode ringan khusus test, mis. request minimal `max_tokens: 1` atau
sekadar cek status HTTP 2xx dari endpoint, tanpa mewajibkan hasil ter-parse jadi command.

### ✅ M4. Tombol AI selalu tampil walau AI belum dikonfigurasi — SELESAI

**Status perbaikan:** `_openAiPanel` kini `_guardAndOpenAi` — memuat `AiConfig` dulu; bila
`!isConfigured`, tampilkan dialog dengan aksi "Buka Settings" yang menavigasi ke
`AiConfigPage`, bukan memaksa user menemui error setelah mengetik.

**Lokasi:** `terminal_page.dart` AppBar; guard hanya di `AiCommandCubit.generate` (baru
ketahuan setelah user mengetik → `AiError`).

**Rekomendasi:** cek `AiConfig.isConfigured` sebelum membuka panel; bila belum, arahkan
langsung ke `AiConfigPage` (atau tampilkan CTA "Konfigurasikan AI") daripada memaksa user
menemuinya lewat pesan error.

### ✅ M5. Feedback UX saat AI belum dikonfigurasi — SELESAI

**Status perbaikan:** ditangani bersama M4 — dialog guard menyediakan tombol navigasi
langsung ke `AiConfigPage` sebelum panel dibuka.

Pesan `AiError('AI belum dikonfigurasi. Buka Settings > AI Command.')` hanya teks. Tidak ada
tombol navigasi langsung ke halaman config. (Beririsan dengan M4.)

**Rekomendasi:** sediakan aksi/tombol di state kosong yang membuka `AiConfigPage`.

---

## 🟢 Prioritas Rendah

### ✅ L1. `AiCommand.copyWith` asimetris — SELESAI

`copyWith` kini menerima `cmd`, `desc`, `blocked`, `risk`.

`copyWith` hanya bisa mengubah `blocked` & `risk`, bukan `cmd`/`desc`. Cukup untuk pemakaian
`SafetyEngine` saat ini, tapi mudah menjebak pemakai berikutnya.

**Rekomendasi:** lengkapi `copyWith` atau beri komentar bahwa keterbatasannya disengaja.

### ✅ L2. Snackbar "Dijalankan: $cmd" berpotensi menumpuk — SELESAI

"Run all" kini menampilkan satu snackbar ringkas ("Menjalankan N command"), messenger
di-capture sebelum `Navigator.pop` agar aman.

Pada approval per-command, tiap Run memunculkan snackbar. Berturut-turut bisa menumpuk.
"Run all" tidak lewat `_run` sehingga tidak ada snackbar (inkonsistensi kecil).

**Rekomendasi:** samakan feedback antara Run tunggal dan Run all; pertimbangkan menutup
panel setelah Run tunggal atau memakai satu snackbar ringkas.

### ✅ L3. API key ada dalam bentuk plaintext di memori — SELESAI (didokumentasikan)

Batasan dicatat pada doc comment `AiConfig.apiKey`: plaintext hanya di memori untuk header
`Authorization`, tak pernah ditulis plaintext ke disk, tak boleh di-log.

`AiConfig.apiKey` dan `_apiKeyController.text` menyimpan key plaintext selama sesi. Ini wajar
(harus dipakai untuk header `Authorization`), tapi belum tercatat sebagai batasan sadar.

**Rekomendasi:** dokumentasikan sebagai batasan; jangan pernah log; sudah benar tidak
menulis plaintext ke disk.

### ✅ L4. `PromptBuilder.osHint` belum dipakai — SELESAI (ditandai TODO)

Ditambahkan `// TODO(v2): isi osHint dari deteksi OS sesi` pada `systemPrompt`.

Parameter `osHint` sudah ada tapi tak pernah diisi (v1 asumsi bash/Linux). Konsisten dengan
keputusan desain §8, hanya perlu ditandai sebagai TODO agar tidak dikira dead code.

### ✅ L5. Cakupan test terbatas pada domain — SELESAI

Ditambahkan `ai_command_cubit_test.dart` (4 test: sukses→preview terklasifikasi, belum
dikonfigurasi→error, datasource error→error, instruksi kosong→tanpa emisi) dan
`ai_config_repository_test.dart` (5 test: roundtrip, ciphertext bukan plaintext, key kosong
menghapus entri, isConfigured, clear).

Test ada untuk `SafetyEngine` & `AiResponseParser`. Belum ada test untuk `AiCommandCubit`
(alur generate→preview→error) maupun `AiConfigRepository` (roundtrip save/load dengan mock
`CredentialManager`). Seam-nya sudah bagus untuk dites.

**Rekomendasi:** tambah `bloc_test` untuk cubit (mock datasource + config repo) dan unit test
repository dengan fake `CredentialManager`.

---

## Catatan di luar fitur (pre-existing)

- `test/core/platform/` kini kosong setelah `ssh_platform_channel_test.dart` dihapus
  (kelas `SshPlatformChannel` sudah tidak ada). Folder kosong tidak mengganggu test runner.
- `SshNativeDatasourceImpl.execute` punya baris `@override` kosong berlebih (kosmetik) di
  `ssh_native_datasource.dart`.

---

## Ringkasan Prioritas

| ID | Prioritas | Ringkas | Status |
|----|-----------|---------|--------|
| H1 | 🔴 | Command AI tidak masuk history + merusak `_currentLine` | ✅ |
| H2 | 🔴 | `http.Client` tidak ditutup | ✅ |
| M1 | 🟡 | Wiring repository diduplikasi (butuh factory/DI) | ✅ |
| M2 | 🟡 | `AiProviderDatasource` diinstansiasi ulang | ✅ |
| M3 | 🟡 | Test Connection boros & bisa false-negative | ✅ |
| M4 | 🟡 | Tombol AI tak cek konfigurasi lebih dulu | ✅ |
| M5 | 🟡 | State kosong tak ada navigasi ke config | ✅ |
| L1 | 🟢 | `copyWith` asimetris | ✅ |
| L2 | 🟢 | Snackbar Run tunggal vs Run all inkonsisten | ✅ |
| L3 | 🟢 | API key plaintext di memori (dokumentasikan) | ✅ |
| L4 | 🟢 | `osHint` belum dipakai (tandai TODO) | ✅ |
| L5 | 🟢 | Tambah test cubit & repository | ✅ |

**Semua item selesai.** Verifikasi: `flutter test` → 99 test lulus; `flutter analyze`
pada file fitur AI Command & terminal → bersih (sisa 3 info analyze murni pre-existing di
`injection.config.dart` generated & `add_edit_server_page.dart`).
