<div align="center">

# ✦ lumenparty ✦

**AI agent untuk Claude Code, khusus app Flutter, mobile, dan web.**
16 hero. 14 skill. 5 spell yang tidak makan token. Satu gerbang yang tidak bisa diterobos merge sembarangan.

[English](README.md) · **Bahasa Indonesia**

[![ci](https://github.com/saimskywalker/lumenparty/actions/workflows/ci.yml/badge.svg)](https://github.com/saimskywalker/lumenparty/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-d97757)](https://docs.anthropic.com/en/docs/claude-code)

> 「仲間たちよ、クリスタルが汝らを選んだ。集え——このコードに調和を取り戻すために。」
> *"Wahai party, kristal telah memilih kalian. Berkumpullah, dan kembalikan keteraturan ke kode ini."*

</div>

---

Kamu adalah **Cosmos**, yang memanggil para hero. Mereka bekerja untuk
codebase-mu: ada yang membaca desain Figma, ada yang membangun layarnya, ada
yang mencari semua cara layar itu bisa rusak, ada yang mereview kode
pembayaran seperti penyerang, ada yang membaca laporan crash tiap pagi.

Di antara mereka ada **spell**: hook shell biasa yang mencegah kesalahan
khas AI agent jam dua pagi. Contohnya push ke `main`, menjalankan semua test
sekaligus di laptop, atau membuka file signing key. Semuanya dicegah
sebelum terjadi, tanpa memakai token sedikit pun.

## Kenapa perlu?

AI agent itu cepat, dan justru di situ masalahnya. Kalau dilepas begitu saja, mereka:

- **menulis kode kebanyakan**: pasang library hanya untuk date picker, atau bikin helper yang sebenarnya sudah ada;
- **boros token**: memanggil sub-agent untuk perubahan satu baris;
- **bikin laptop hang**: `flutter test` dan build Gradle jalan barengan;
- **merge dan push yang tidak seharusnya**;
- **lupa aturan** yang kamu tulis di prompt tiga jam sebelumnya.

lumenparty menjawab masing-masing dengan aturan yang tidak bisa lupa:

| Masalah | Solusinya |
|---|---|
| Kode kebanyakan | Urutan "malas" **Auron** (pakai yang sudah ada → standard library → fitur platform → kode seminimal mungkin), plus spell **Mini**: peringatan di 300 baris, diblokir di 500 baris per file |
| Boros token | **Cosmos** mengerjakan sendiri dulu. Hero baru dipanggil untuk kerja paralel, baca banyak file, atau review. Haiku mengumpulkan, Sonnet membangun, Opus menilai risiko |
| Laptop hang | Spell **Slow**: kerja berat jalan satu per satu, prioritas rendah, menunggu kalau RAM menipis, ada batas waktunya |
| Merge berbahaya | Spell **Protect** menutup semua jalan ke branch yang dilindungi. **Crystal Gate** hanya mau merge kalau CI hijau, tidak ada konflik, dan reviewer bilang PASS |
| Aturan terlupa | Pakai hook, bukan prompt: jalan di setiap tool call, untuk setiap agent, setiap saat |

## Pasang dalam semenit

**Sebagai plugin Claude Code** (disarankan). Ketik ini di dalam Claude Code:

```
/plugin install lumenparty --marketplace saimskywalker/lumenparty
```

Kalau Claude Code-mu versi lama, tambahkan marketplace-nya dulu:
`/plugin marketplace add saimskywalker/lumenparty`, lalu
`/plugin install lumenparty@lumenparty`.

Setelah itu, di folder app-mu, buat setelan project sekali saja (pilih preset):

```bash
lumenparty init flutter      # atau: web | fullstack
```

Lalu panggil mereka:

```
Lumenparty, assemble!
```

Agent dan skill dari plugin punya awalan namanya sendiri (`lumenparty:noctis`),
jadi tidak bentrok dengan agent milikmu. Setelan dan file sementara disimpan
di `.claude/wol/` project-mu. Commit `config.sh` kalau ingin setelannya
dipakai bareng tim.

**Tanpa plugin** (dipasang ke satu project lewat script):

```bash
git clone https://github.com/saimskywalker/lumenparty.git
./lumenparty/install.sh --preset flutter ~/code/my-app   # tambah --team untuk di-commit bareng tim
```

Defaultnya pribadi: semua file masuk ke `.claude/` dan disembunyikan dari git
lewat `.git/info/exclude`. Hapus kapan saja dengan `./uninstall.sh ~/code/my-app`.

Butuh `jq`, `git`, `perl`, dan `gh` untuk merge gate. Jalan di macOS dan Linux.

### Perintah `lumenparty`

| Perintah | Fungsinya |
|---|---|
| `lumenparty init <preset>` | membuat `.claude/wol/config.sh` untuk project ini |
| `lumenparty slow '<perintah>'` | menjalankan perintah berat lewat antrian |
| `lumenparty gate <pr> --report` | menampilkan semua syarat Crystal Gate untuk satu PR |
| `lumenparty libra` | siapa yang pegang antrian, proses berat, RAM bebas, riwayat terakhir |
| `lumenparty awake start` / `lumenparty rest` | dipakai Laguna: jaga laptop tetap menyala, lalu beres-beres di akhir |

Kalau pakai plugin, `lumenparty` langsung ada di PATH. Kalau lewat `install.sh`,
perintahnya ada di `.claude/wol/bin/lumenparty`. Perintah lama `wol` masih bisa
dipakai sebagai alias.

## ⚔️ Para hero (sub-agent)

| Hero | Dari | Tugas | Model | Akses |
|---|---|---|---|---|
| **Bartz** | V | Membaca design system dan Figma, menulis spec untuk builder | sonnet | baca |
| **Zidane** | IX | Membangun UI: widget Flutter atau komponen web, semua state, semua ukuran layar | sonnet | edit |
| **Cloud** | VII | Membangun backend: API, function, migration, dashboard | sonnet | edit |
| **Tidus** | X | Memikirkan skenario normal / tepi / terburuk / penyalahgunaan, lalu menulis test yang kurang | sonnet | edit test |
| **Squall** | VIII | Mereview diff untuk mencari bug dan crash | opus | baca |
| **Warrior of Light** | I | Membaca output analyzer, type checker, dan linter, lalu mencari yang mereka lewatkan | sonnet | baca |
| **Lightning** | XIII | Membaca CI yang gagal, memisahkan kegagalan asli dari yang cuma flaky | haiku | baca |
| **Clive** | XVI | Membetulkan test yang gagal dengan jujur: tidak di-skip, tidak dilonggarkan | sonnet | edit |
| **Cecil** | IV | Mencari dead code, dan file mana yang layak di-refactor (churn × bug × kompleksitas) | opus | baca |
| **Vaan** | XII | Mencari issue dan PR yang masih menunggu balasan seseorang | haiku | baca |
| **Terra** | VI | Teks di semua bahasa, aturan listing store dan teks izin aplikasi | sonnet | baca |
| **Noctis** | XV | Keamanan login, sesi, pembayaran, IAP, dan webhook, per PR | opus | baca |
| **Firion** | II | Audit keamanan menyeluruh: MASVS, OWASP Top 10, kebocoran data, rules Firebase/Supabase | opus | baca |
| **Y'shtola** | XIV | Membaca Crashlytics / Sentry: crash baru per versi, dipetakan ke file:baris | sonnet | baca |
| **Shantotto** | XI | Menjawab pertanyaan dari database secara read-only (agregat saja) dan mereview migration | sonnet | baca |
| **Luneth** | III | Performa dan analytics: waktu buka app, ANR, Web Vitals, funnel dibanding threshold-mu | sonnet | baca |

Setiap reviewer menutup jawabannya dengan blok yang sama, jadi keputusan bisa diambil secara otomatis:

```
VERDICT: PASS | BLOCK | NEEDS-HUMAN
AGENT: noctis
FINDINGS:
- [HIGH] lib/purchase/verify.dart:42 — receipt dipercaya dari client, tidak pernah dicek ke store
SUMMARY: satu temuan HIGH: validasi receipt di server belum ada
```

## ✨ Skill

| Skill | Aktif saat |
|---|---|
| **Cosmos** | summon, sebelum mendelegasikan kerja, memilih reviewer yang dibutuhkan sebuah diff |
| **Auron** | sebelum menulis kode apa pun: urutan "malas", daftar yang tidak boleh dipangkas, batas ukuran file, cepat sejak awal |
| **Lulu** | sebelum menjalankan build dan test: antrian Slow, tidak ada full suite di laptop |
| **Ignis** | commit, rebase, isi PR: satu PR per fitur, tanpa atribusi AI, tidak pernah merge sendiri |
| **Rikku** | CI merah |
| **Relm** | Figma → Flutter / web, dengan batas jumlah panggilan dan jebakan konversinya |
| **Rosa** | setiap perubahan UI: aksesibilitas (label, kontras, ukuran teks, fokus, area sentuh) |
| **Ashe** | sebelum submit ke store: checklist review App Store dan Google Play |
| **Cid** | rilis: semua disiapkan, lalu BERHENTI menunggu keputusanmu |
| **Aerith** | health check pagi: crash, performa, dan data dalam satu ringkasan |
| **Laguna** | kerja tengah malam: selesaikan, tunggu CI hijau, merge lewat gerbang, lalu istirahat |
| **Yuna** | handoff sebelum kamu clear context |
| **Steiner** | ada kebocoran atau pembobolan: bendung, ganti kunci, cabut akses, cek, catat |
| **Lunafreya** | "apa yang masih menunggu siapa": draft rekap atau standup, tidak pernah dikirim otomatis |

## 🛡️ Spell (hook, tanpa token)

| Spell | Mengawasi | Mencegah |
|---|---|---|
| **Protect** | setiap perintah shell | merge lokal; push ke `main` / `release/*`; push force, mirror, atau hapus branch; merge lewat `gh api`; `--admin`; tag produksi; `firebase deploy`, `vercel --prod`, `fastlane release`, `eas submit`; membuka file keystore |
| **Shell** | setiap file yang dibaca dan diedit | signing key, service account, file env produksi |
| **Silence** | tool SQL lewat MCP | apa pun selain SELECT / WITH / EXPLAIN / SHOW; lock; sleep; banyak statement sekaligus |
| **Mini** | setiap edit | file yang membesar lewat 300 baris (peringatan) atau 500 baris (diblokir) |
| **Slow** | perintah berat | kerja berat yang jalan barengan; RAM menipis; proses yang tidak berhenti |

Semua polanya ada di satu file, `.claude/wol/config.sh`, dengan preset untuk Flutter, web, dan fullstack.

### Apa yang bisa dan tidak bisa dilihat Protect

Protect menilai perintah yang benar-benar akan dijalankan, bukan hanya kata
pertamanya. Ia membuka `sh -c` / `bash -c` / `eval`, `$(...)` dan backtick,
serta membuang awalan `env`, `nice`, `nohup`, `sudo`, `xargs`, `command`,
garis miring terbalik di depan, dan opsi git `-C` / `-c`. Perintah yang
disimpan di variabel (`$CMD push …`) tidak bisa dibaca sebelum dijalankan,
jadi baris seperti itu ditolak kalau bisa melakukan push atau merge.

Ini pagar pengaman untuk agent, bukan sandbox untuk menahan penyerang. Script
terpisah yang melakukan push, alias di profil shell-mu, atau program di
`PATH`-mu ada di luar jangkauannya. Tetap aktifkan branch protection di GitHub.

## 🔮 Crystal Gate

`gh pr merge` hanya bisa lewat gerbang ini, dan gerbangnya baru terbuka kalau
**semua** syarat berikut terpenuhi, dicek langsung ke GitHub saat merge:

- Laguna dipanggil untuk PR ini **malam ini**, dan PR-nya milikmu;
- bukan draft, tidak ada label `needs-human`;
- **bisa di-merge tanpa konflik**, status merge `CLEAN`, sudah up to date dengan base;
- **semua check hijau** di commit terakhir;
- tidak ada thread review yang belum selesai;
- tidak menyentuh file CI, rilis, atau infrastruktur (yang seperti itu di-merge manusia);
- ada verdict `PASS` untuk commit ini dari setiap reviewer yang dibutuhkan diff-nya.

```bash
lumenparty gate 12 --report
✓ author is the owner
✓ mergeable, no conflict
✗ checks not green: test=IN_PROGRESS
✗ noctis verdict PASS for head 3c673ac2b missing
```

## 🗺️ Alur kerja

- **Fitur baru**: Bartz → Zidane ∥ Cloud → Tidus → Warrior of Light ∥ Squall ∥ gerbang → Clive → Ignis
- **Crash di produksi**: Y'shtola → Squall → Tidus (test reproduksi dulu) → perbaikan → Clive
- **CI merah**: Lightning → Warrior of Light / Clive
- **Refactor**: Cecil → Tidus (kunci perilakunya dulu) → Zidane / Cloud → review
- **Rilis**: Cid → gerbang → **berhenti menunggumu** → 24 jam kemudian Y'shtola + Luneth dibanding threshold-mu
- **Pagi**: Aerith → Y'shtola ∥ Luneth ∥ Shantotto → satu ringkasan
- **Tengah malam**: Laguna → selesaikan → CI → verdict → Crystal Gate → Yuna → istirahat

## 💬 Cara memanggil

```
Cosmos, send Noctis to review PR #12
Cosmos, run the refactor pipeline on lib/features/checkout
Relm, build this Figma frame: https://www.figma.com/design/…
Cid, prepare release 2.3.0
Aerith, run the health check
Laguna, finish PR #12 and rest
```

Perintahnya boleh juga ditulis dalam bahasa Indonesia, misalnya *"Cosmos, minta Noctis review PR #12"*.

## Aturan menulis kode (Auron)

1. **Baca dulu**, lalu berhenti di langkah pertama yang cukup: apakah ini perlu
   ada → sudah ada di codebase → ada di standard library → ada fitur platformnya →
   ada dependency yang sudah terpasang → bisa satu baris → baru tulis yang
   minimum, plus satu test kecil kalau ada logikanya.
2. **Tidak pernah dipangkas**: validasi di batas kepercayaan, penanganan
   kehilangan data, keamanan, aksesibilitas, pesan error yang bisa ditindaklanjuti,
   transaksi uang yang tidak tercatat dua kali.
3. **300 / 500 baris** per file yang ditulis manusia, dijaga oleh Mini.
4. **Benar sekali jalan**: ikuti gaya kode di sekitarnya, `switch` daripada
   rantai if, satu tipe state (sealed) daripada banyak boolean, ekstrak baru
   di pemakaian ketiga.
5. **Cepat sejak awal**: tanpa N+1, satu polling per layar, widget `const` dan
   `select` di provider, tanpa layout bergeser, index dan pagination,
   optimasi hanya kalau ada angka pengukurannya.

## 📊 Benchmark: coba sendiri, kabari kami

Empat tugas, dijalankan di project biasa dan di project yang sudah memasang
crew, dinilai otomatis (test lulus, bug yang ditanam disebut, `main` tidak
bergerak, file lain tidak berubah):

```bash
bench/run.sh --dry            # gratis: cek alurnya saja
bench/run.sh --runs 3         # sesi sungguhan; laporannya mencantumkan biaya
```

Lalu [bagikan tabel hasilnya](https://github.com/saimskywalker/lumenparty/issues/new?template=benchmark.yml)
atau [ceritakan hero yang keliru](https://github.com/saimskywalker/lumenparty/issues/new?template=feedback.yml).
Kami tidak memasang angka apa pun sebelum ada hasil dari orang-orang seperti kamu.
Detailnya: [bench/README.md](bench/README.md).

## FAQ

**Bisa jalan tanpa Figma, Crashlytics, atau database?** Bisa. Hero yang butuh
sumber data yang belum kamu sambungkan akan bilang begitu lalu berhenti. Sisanya tetap jalan.

**Apakah bikin Claude jadi lambat?** Spell-nya cuma script shell kecil yang
selesai dalam hitungan milidetik. Penghematannya justru datang dari Cosmos
yang mengerjakan tugas kecil sendiri tanpa memanggil agent.

**Batasnya bisa diubah?** Semua ada di `.claude/wol/config.sh`: branch yang
dilindungi, perintah berat, perintah deploy, file rahasia, batas ukuran, dan aturan path untuk gerbang.

**Apakah merge gate menggantikan branch protection?** Tidak. Gerbang ini pagar
lokal untuk agent-mu. Kalau paket GitHub-mu mendukung, tetap pasang branch protection.

## Kontribusi

Hero baru, spell, preset (React Native, KMP, SwiftUI, …), dan kasus test
sangat diterima. Lihat [CONTRIBUTING.md](CONTRIBUTING.md). Kalau crew ini pernah
menyelamatkan malammu, ⭐ membantu orang lain menemukannya.

Terima kasih untuk [@jaanya0502-glitch](https://github.com/jaanya0502-glitch), yang membuat terjemahan bahasa Indonesia pertama.

## Kredit dan disclaimer

Urutan "malas"-nya diadaptasi dari [ponytail](https://github.com/DietrichGebert/ponytail) (MIT); pemberitahuan lisensinya ada di [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
Ini karya penggemar dan tidak resmi. FINAL FANTASY dan para karakternya adalah
merek dagang Square Enix, yang tidak berafiliasi dengan dan tidak mendukung proyek
ini. Nama-nama itu hanya dipakai sebagai label peran. Tidak ada aset game yang disertakan.

MIT © saimskywalker
