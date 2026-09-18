# SuperTarot Memory

## Maintenance Rule

- Update this file after every repo change.
- If a change modifies structure, schemas, runtime behavior, or adds/removes logic, also update `CLAUDE.md` and `AGENTS.md`.
- Keep entries concise: date, intent, files touched, verification.

## 2026-09-18

- Tìm kiếm web: gõ "2" không ra "Two of …" vì chỉ so substring tên tiếng Anh. Thêm `web/src/lib/search.ts`: khóa = tên + số lá (Ẩn Chính 0-21, Ace 1…Ten 10) + tên bộ vi/en, bỏ dấu tiếng Việt; số khớp chính xác, chữ khớp tiền tố. "2" → 4 lá Two + The High Priestess; "2 cốc"/"2 coc"/"2 cups" → Two of Cups. Placeholder ô tìm đổi thành gợi ý "Tìm theo tên, số hoặc bộ, vd. 2 cốc".
- Chọn bộ bài ở trang chủ: từ 640px xếp 5 ô ngang (ô dựng đứng, glyph + mũi tên trên, tên dưới); dưới 640px giữ mỗi bộ một hàng.
- Thêm Agentation cho `astro dev`. Thử `@astrojs/react` + `<Agentation client:only="react" />` sau `import.meta.env.DEV` trước: build production vẫn đóng gói React + Agentation (~600 KB, SW precache 196 mục). Đổi sang `web/src/dev/agentation.ts` mount React thủ công, `Base.astro` chỉ chèn thẻ script khi DEV; bỏ `@astrojs/react`. Build production sạch, precache về 193 mục.
- Agentation render qua portal vào một div riêng trong body, không vào `#agentation-root`; nút nằm góc dưới phải.
- Verification:
  - `npm test` 35 pass (thêm `test/search.test.ts` 8 test), `astro check` 0 lỗi, build 175 trang, `dist` không có chuỗi `agentation`/`createRoot`
  - `astro dev` + headless Chrome: toolbar Agentation hiện, không lỗi console; tìm "2", "2 cốc", "10 kiem", "0", "prie" đúng; 1280px 5 ô 205×151 cùng hàng, 390px 5 hàng 350×81, không tràn ngang

## 2026-09-17

- Lỗi: sau deploy Bốc bài/Kiểm tra, user vẫn thấy site cũ trên trình duyệt đã vào trước đó (trình duyệt khác thì thấy bản mới). Server đã đúng; nguyên nhân là SW `generateSW` phục vụ HTML từ precache trước, còn Cloudflare gửi `sw.js` với `Cache-Control: max-age=14400` nên trình duyệt không lấy SW mới trong tối đa 4 giờ.
- Sửa: `@vite-pwa/astro` chuyển sang `injectManifest` với `web/src/sw.ts` tự viết. Navigation network-first, `fetch(cache: 'no-cache')`, timeout 4s; offline dùng cache `pages` rồi precache. Precache, ảnh CacheFirst + fallback SVG giữ nguyên. Thêm devDependencies `workbox-*` 7.4.0.
- Bẫy: plugin lưu precache theo URL thư mục (`vi/spread/`), `matchPrecache('/vi/spread/index.html')` trả undefined. Phát hiện nhờ test offline trang chưa xem.
- User yêu cầu: theme mặc định sáng, không theo `prefers-color-scheme`. Bỏ media query dark trong `global.css` và trang redirect gốc; nút đổi nền chỉ còn light ↔ dark; `theme-color` cập nhật theo lựa chọn.
- Việc của user nếu muốn (không làm hộ vì là tài khoản Cloudflare): Browser Cache TTL = "Respect existing headers" để `sw.js` về max-age 600 của GitHub Pages.
- Verification:
  - `npm test` 27 pass, `astro check` 0 lỗi, build injectManifest precache 193 entries
  - Server local giả lập header production (sw.js 4h, còn lại 10 phút) + headless Chrome: cài SW, sửa HTML trong dist mà không đổi sw.js → tải lại hiện ngay bản mới; `/vi` → `/vi/`; tắt server → `/vi/` ra bản mới nhất, `/en/card/death/` chưa xem vẫn mở, ảnh placeholder 88px, `/vi/spread/` mở
  - Emulate OS dark: nền vẫn `rgb(255, 251, 240)`, không có `data-theme`


- Web: bỏ dòng "Dữ liệu từ labyrinthos.co" ở chân trang (dữ liệu đã dịch lại), thay bằng tác giả Bùi Hải; thêm `<meta name="author">` và `author` trong JSON-LD trang lá bài. Hằng số ở `web/src/lib/site.ts`.
- Đổi "Rút bài" thành "Kiểm tra" (en: Quiz), route `draw` → `quiz`. `/vi/draw/`, `/en/draw/` thành stub redirect trong `<head>` để link cũ và shortcut PWA đã cài không 404; sitemap lọc bỏ. Giữ key `supertarot-draw-<lang>` để không mất tiến độ.
- Thêm "Bốc bài" (en: Spread) `/<lang>/spread/`: 3 lá ngẫu nhiên khác nhau, Quá khứ/Hiện tại/Tương lai, mỗi lá xuôi/ngược 50% (ảnh ngược xoay 180°). Bảng 3 cột kẻ viền, mỗi phần một hàng tiêu đề: từ khóa, nghĩa cô đọng, ý nghĩa, tình yêu, sự nghiệp, tài chính, cảm xúc, hành động, tương ứng. Điện thoại: bảng min-width 780px cuộn ngang, nhãn phần sticky, có dòng "Vuốt ngang". Lưu spread cuối vào localStorage.
- Tự chọn (user không nói rõ): vị trí Quá khứ/Hiện tại/Tương lai và cho phép lá ngược.
- Nav và hero trang chủ: Tra cứu · Bốc bài · Kiểm tra. Manifest PWA: 4 shortcut (bốc bài/kiểm tra × vi/en). Icon mới `cards`.
- Không đổi app Android: app không có trang "Rút bài" (tab Học bài là bản kiểm tra có chấm AI).
- Verification:
  - `npm test` 27 pass (thêm `test/spread.test.ts` 7 test), `npm run check` 0 lỗi, build 175 trang
  - Headless Chrome qua CDP: bảng 18 hàng (9 phần), `scrollWidth == clientWidth` ở 1280 và 390px, spread còn nguyên sau reload, nhãn phần dính trái khi cuộn ngang, `/en/draw/` → `/en/quiz/` và nút rút vẫn chạy, chân trang "By Bùi Hải"
  - Sửa sau khi chụp: `scroll-margin-top` cho kết quả để header dính không che chip vị trí


- Web thành PWA cài được — cách để người dùng iPhone có SuperTarot mà không cần bản iOS.
- `@vite-pwa/astro` trong `web/astro.config.mjs`: manifest (standalone, beige, 2 shortcut rút bài vi/en), precache toàn bộ HTML/CSS/JS/icon; ảnh lá bài cache runtime `CacheFirst` với fallback `public/card-offline.svg`. Bỏ ảnh khỏi precache để lần vào đầu trên 4G không phải tải 6,6 MB.
- `web/src/components/InstallHint.astro` + `web/src/lib/install.ts` (+ `test/install.test.ts`): nút Cài đặt trên Chromium, hướng dẫn Chia sẻ → Thêm vào MH chính trên iOS, ẩn trong in-app browser, khi standalone, hoặc đã đóng.
- `prepare_web_assets.py` sinh thêm `apple-touch-icon.png`, `icon-192/512.png`, `icon-maskable-512.png` trên nền be đặc.
- Thêm `web/tsconfig.json` + `web/src/env.d.ts`: trước đó chưa có tsconfig nên `astro check` không thấy type của `virtual:pwa-info`.
- Bẫy khi verify: `TaskStop` trên `npx astro preview` không giết tiến trình node con, server vẫn trả lời nên lần thử "offline" đầu tiên không có giá trị. Phải kill theo cổng 4321.
- Verification:
  - `npm test` 20 pass, `npm run check` 0 lỗi, build: precache 187 entries
  - Headless Chrome qua CDP: `getInstallabilityErrors` rỗng, manifest không lỗi, SW activated, cache 186 entries
  - Tắt hẳn server: `/vi/card/the-fool/`, `/en/card/ten-of-cups/`, `/en/draw/` vẫn mở; lá chưa xem (`king-of-swords`) hiện placeholder SVG

## 2026-09-16

- Đổi ô lá bài trong lưới: tên nằm trong một thanh trắng bên trong khung, chữ to hơn, thay vì text rời bên dưới khung.
- Làm ở cả hai nơi để app và web không lệch nhau: `web/src/components/CardGrid.astro` (viền + bóng chuyển từ `.card-tile__art` lên `.card-tile`, thêm `overflow:hidden`, thanh tên có `border-top`) và `mobile/lib/src/screens/browse_screen.dart` (NeuBox bọc cả Column, `ClipRRect` bán kính trừ đi độ dày viền).
- Cỡ chữ: web 0.95rem thường / 0.8rem khi từ 4 cột; app 13.5 / 10.5. Chiều cao nhãn trong `_CardGridState` tăng 34→46 và 26→32 vì thanh tên giờ nằm trong khung.
- User chốt: từ giờ tự merge PR của release-please, không đưa link chờ merge tay. Đã lưu vào memory cá nhân.
- Verification:
  - web: `astro check` 0 lỗi, `npm test` 11 pass, build 171 trang, chụp ở 2 và 4 cột
  - app: `flutter analyze` sạch, `flutter test` 37 pass, cài lên emulator và chụp lưới thật

## 2026-09-16

- Thêm bản web tĩnh `web/` bằng Astro, deploy GitHub Pages, cố ý **không có AI**.
- User chốt: Astro (thay vì Flutter Web hay static thuần), GitHub Pages, và 4 tính năng — tra cứu 78 lá, song ngữ vi/en, zoom lưới 1-5 cột, rút bài ngẫu nhiên. Hỏi đáp và chấm bài bỏ vì cần API key.
- 171 trang prerender: `/vi/` và `/en/` với home, `suit/<key>`, `card/<slug>`, `draw`; `/` redirect về `/vi/`. Có canonical, hreflang chéo, Open Graph, JSON-LD cho trang lá bài, sitemap.
- `web/tools/prepare_web_assets.py` sinh `cards_*.json` (kèm slug + order), copy 78 ảnh, và sinh logo/favicon/og từ `mobile/icon/app_icon.png`. Tự viết decoder + encoder PNG trên thư viện chuẩn để không thêm dependency ảnh chỉ vì ba file. Tất cả gitignore, CI dựng lại.
- `web/src/lib/study.ts` là port thứ ba của `learning/study.py` (sau Dart). `web/test/study.test.ts` 11 test, chốt vòng 78 lá không lặp và cursor facet xoay vòng.
- Pages phát hiện tài khoản dùng custom domain chứ không phải `hairbui76.github.io`, nên `site`/`base` lấy từ `actions/configure-pages` lúc build và `robots.txt` sinh từ `Astro.site` thay vì hard-code.
- Domain cuối cùng: `tarot.hairbui76.id.vn`, set làm custom domain của chính repo này nên site ở gốc `/` chứ không phải `/supertarot/`. Vì vậy `astro.config.mjs` dùng `||` chứ không phải `??` cho `BASE_PATH`: khi có custom domain, `configure-pages` trả về chuỗi rỗng, mà `??` không bắt chuỗi rỗng nên base sẽ thành `''` và hỏng.
- Trang `/` là stub redirect. Ban đầu đặt `location.replace` ở cuối `<body>` nên trình duyệt vẽ xong fallback rồi mới chuyển — user thấy nháy một dòng "SuperTarot" trên nền trắng. Đã chuyển script lên `<head>`, thêm `noindex`, `<noscript>` meta refresh, và style fallback cho giống site. Kèm nhớ ngôn ngữ: mỗi trang ghi `supertarot-lang`, stub đọc lại; chưa có thì theo `navigator.languages`, mặc định vi.
- Sitemap loại trang stub bằng `filter`; còn 170 URL.
- DNS: user thêm 4 bản ghi A đúng IP GitHub Pages nhưng ở panel của nhà đăng ký, trong khi nameserver của `hairbui76.id.vn` trỏ về Cloudflare (`jonah/ophelia.ns.cloudflare.com`) — tra `tarot.hairbui76.id.vn` trả NXDOMAIN với authority là SOA của Cloudflare, tức Cloudflare mới là nơi phải thêm record. Sau khi user thêm ở Cloudflare thì site live; record đang ở chế độ Proxied (A trả về IP Cloudflare 172.67/104.21 chứ không phải 185.199), nên HTTPS do Cloudflare cấp chứ không phải GitHub.
- Bẫy đã tránh: ảnh chụp headless Chrome ở `--window-size=420` trông như tràn ngang, nhưng đo `scrollWidth`/`clientWidth` thì bằng nhau ở mọi bề rộng — headless Chrome có viewport tối thiểu ~504px nên ảnh chỉ bị cắt. Muốn xem đúng bề rộng điện thoại thì nhúng site vào iframe 390px rồi chụp.
- Verification:
  - `npm run check` — 0 errors, 0 warnings, 0 hints
  - `npm test` — 11 test pass
  - `npm run build` — 171 trang
  - Chụp headless: home, card, suit, draw ở light/dark, và bản 390px qua iframe — không tràn ngang
- Cập nhật `README.md`, `README.vi.md`, `CLAUDE.md`, `AGENTS.md`, thêm `web/README.md` và `web/README.vi.md`.

## 2026-09-16

- Thêm icon app thật và nút kiểm tra cập nhật trong app.
- Icon: user đặt `mobile/icon/app_icon.png` (1254x1254 RGBA, nền trong suốt, art chiếm 84% canvas). Dùng `flutter_launcher_icons` 0.14.4 sinh 5 density legacy + adaptive icon (XML, foreground `drawable-*`, `values/colors.xml`).
- `adaptive_icon_foreground_inset: 12` vì vùng an toàn của adaptive icon chỉ là 66% giữa canvas, art 84% sẽ bị mask tròn cắt viền; inset 12% kéo về ~64%.
- `adaptive_icon_background` ban đầu đặt `#2196F3` vì xanh dương là màu duy nhất trong palette mà art không có; user muốn nền be nên đổi sang `#DFC79A`.
- Để chọn tone be, viết luôn encoder PNG thuần Python (đã có decoder) để composite foreground lên từng nền ứng viên + mask tròn rồi xem trực tiếp, thay vì build APK từng lần. Cách này cũng dùng để chọn mức inset.
- Be quá sáng không dùng được: trang sách trong art là `#FDF3DC`, nên `#FFFBF0` chỉ cho 1.07:1 — quyển sách mất khối. `#DFC79A` cho 1.49:1.
- Inset đổi từ 12% lên 16%: ở 12% art gần như lấp kín vòng tròn nên không thấy nền be; 20-24% thì art quá nhỏ ở 48px.
- Logo đưa ra trước chữ SUPERTAROT trên app bar: khai `icon/app_icon.png` làm asset Flutter (không tạo file thứ hai để khỏi phải đồng bộ), dùng `cacheWidth` để không decode ảnh 1254px cho ô 28px.
- Updater: `services/update_service.dart` + `widgets/update_section.dart`. Đọc `releases/latest`, so version theo số, chọn asset theo ABI của máy, tải có progress, giao cho package installer qua `open_filex`. Thêm `REQUEST_INSTALL_PACKAGES` vào manifest.
- Package thêm: `package_info_plus`, `device_info_plus`, `open_filex`, `path_provider`, `flutter_launcher_icons` (dev).
- Release notes của release-please là Markdown thô (`##`, link compare, hash commit) nên hiển rất xấu trên card; thêm `formatReleaseNotes()` dọn heading, link, hash, bullet và cắt còn 8 dòng.
- Verification:
  - `flutter analyze` — no issues
  - `flutter test` — 37 test pass (thêm `test/update_service_test.dart`: parse/so sánh version gồm ca 1.10.0 vs 1.9.0, không hạ cấp, chọn asset theo ABI, fallback APK universal, bỏ asset không phải APK, rate limit, chưa có release, tag không phải version, và `formatReleaseNotes`)
  - Chạy thật trên emulator: icon hiện đúng trên launcher không bị cắt; bấm kiểm tra → tìm đúng v1.1.0 từ GitHub → tải APK x86_64 có progress → Android hỏi quyền cài → sau khi cấp hiện đúng "Do you want to update this app?" → cài xong, `dumpsys` xác nhận versionName 1.1.0 / versionCode 101004000
- Lưu ý: dialog "update this app" chứng minh APK từ CI cùng chữ ký với bản build local — nếu khác key Android sẽ từ chối thay vì coi là update.
- Cập nhật `mobile/README.md`, `mobile/README.vi.md`, `CLAUDE.md`, `AGENTS.md`.

## 2026-09-16

- Thêm zoom lưới bài 1-5 cột và chuyển toàn bộ UI app sang neubrutalism theo `DESIGN.md`.
- Zoom: `SettingsStore.gridColumns` (clamp 1..5, lưu prefs), pinch trên lưới, kèm nút tăng/giảm trên app bar cho dễ thấy.
- Bug quan trọng: bản đầu dùng `GestureDetector(onScaleStart/onScaleUpdate)` bọc `GridView` — pinch không bao giờ chạy vì scale recognizer tranh chấp với drag recognizer của GridView trong gesture arena và thua. Widget test bắt được (nút thì chạy nên test tay không phát hiện). Đổi sang `Listener` thô theo dõi pointer, ngoài gesture arena; đóng băng scroll khi có 2 ngón để không trượt lưới giữa lúc đổi cột.
- Chiều cao ô tính từ chiều rộng thật qua `LayoutBuilder` thay vì `childAspectRatio` cố định, nên ảnh lá bài không bị cắt ở bất kỳ số cột nào.
- Design system: `lib/src/theme.dart` giữ `NeuTokens` (ThemeExtension) — viền 3px, bóng cứng lệch 4px không blur, radius 8px, palette vàng/đỏ/xanh dương + xanh lá và tím thêm vào cho đủ 5 bộ. `lib/src/widgets/neu.dart` có `NeuBox/NeuButton/NeuIconButton/NeuChip/NeuHeading/NeuSection/NeuField`; không màn hình nào hard-code viền hay bóng.
- Dark mode: `line` và `shadow` đổi sang gần trắng, vì viền đen trên nền tối là vô hình. Đã kiểm bằng `adb shell cmd uimode night yes`.
- Bỏ toàn bộ emoji trong UI theo yêu cầu của DESIGN.md, thay bằng icon vector. Năm biểu tượng bộ bài vẽ tay trong `lib/src/widgets/suit_glyph.dart` (gậy, chén, gươm, đồng xu có ngôi sao 5 cánh, sparkle cho Ẩn Chính) — Material Icons không có gươm/chén/đồng xu, và bản đầu tôi dùng nhầm icon nguyên tố (lửa/giọt nước/gió/cây) nên user phản hồi đúng là phải dùng biểu tượng của bộ.
- Màu bộ theo nguyên tố: lửa đỏ, nước xanh dương, khí vàng, đất xanh lá, tím cho Ẩn Chính.
- Tách `MarkupText` ra `lib/src/widgets/markup_text.dart`, xóa `section_block.dart`.
- Phần Execution Rules user gửi kèm viết cho landing page web (Navbar/Hero/Pricing/Testimonials/Footer, thẻ `<head>`, Tailwind CDN, Open Graph) nên không áp dụng cho app Flutter; chỉ áp dụng phần visual style. Cũng giữ nguyên song ngữ vi/en thay vì ép toàn bộ text sang tiếng Anh, vì app có toggle ngôn ngữ và dữ liệu tarot có bản tiếng Việt.
- DESIGN.md tự mâu thuẫn ở mục Do's/Don'ts ("No pure black", "saturation cap 80%") và Components ("1px border stroke", "subtle shadow 0 2px 12px rgba") so với chính spec neubrutalism trong cùng file; ưu tiên spec của style.
- Đã viết lại `DESIGN.md` theo yêu cầu bỏ phần landing page cho đỡ nhầm về sau:
  - Bỏ hết nội dung landing/web: "Ideal for landing pages, saas", hero split-screen, feature zig-zag, CSS Grid 1280px, z-index sticky-nav, mobile collapse 768px, và các Don't về `h-screen`, picsum.photos, lorem ipsum, AI copywriting clichés.
  - Sửa luôn các chỗ tự mâu thuẫn vì chúng cũng gây nhầm: bỏ "No pure black" và "saturation cap 80%", chốt radius 8px (Elevation cũ ghi "sharp corners 0px" trái với Shapes 8px), viết lại Components theo đúng cái đã implement (3px border, bóng cứng 4px) thay vì boilerplate 1px border + bóng mờ.
  - Thêm mục Scope nói rõ đây là style reference cho app Flutter trong `mobile/`, không phải blueprint trang web, và code (`theme.dart`) mới là source of truth nếu hai bên lệch nhau.
  - Thêm bảng surface light/dark, quy tắc dark mode đổi màu viền/bóng sang gần trắng, mục Icons, và block `tokens:` trong front matter khớp `NeuTokens`.
- Emulator: GlazeWM tile cửa sổ làm emulator chết liên tục. Cách chạy ổn định là `emulator.exe` qua background task của harness rồi `glazewm command set-floating` ngay sau đó. Launch bằng `(cmd &)` trong Bash thì process bị kill.
- Verification:
  - `flutter analyze` — no issues
  - `flutter test` — 22 test pass (thêm `test/grid_zoom_test.dart`: mặc định 2 cột, pinch ra còn 1, pinch vào tăng cột, stepper đi hết dải 1..5 và clamp hai đầu, giữ cột qua rebuild)
  - Chạy thật trên emulator: lưới 2/5/1 cột đều đúng và nút clamp đúng, style hiển thị chuẩn ở cả light lẫn dark, glyph bộ bài đúng biểu tượng
- Cập nhật `mobile/README.md`, `mobile/README.vi.md`, `CLAUDE.md`, `AGENTS.md`.

## 2026-09-16

- Thêm phát hành tự động bằng release-please, khởi tạo git và push lên `hairbui76/supertarot`.
- `release-please-config.json`: một package ở path `.`, `release-type: simple`, `include-component-in-tag: false` (tag `vX.Y.Z`), `extra-files` kiểu `generic` bump `mobile/pubspec.yaml` qua marker `# x-release-please-version`. Kèm `version.txt` và `.release-please-manifest.json` khởi tạo 1.0.0.
- `.github/workflows/release.yml`: release-please job + job `apk` (khôi phục keystore từ secret, sinh index + assets, analyze/test, build `--split-per-abi`, đổi tên `supertarot-<version>-<abi>.apk`, upload vào Release, xoá keystore ở `if: always()`).
- `.github/workflows/ci.yml`: chạy trên PR và push main. Có vì `release.yml` build APK sau khi Release đã tạo, nên main hỏng sẽ đẻ Release rỗng.
- Bốn chi tiết release-please đã tra tài liệu để tránh sai: không đặt `release-type` trong workflow (sẽ bỏ qua config file); `version.txt` phải tồn tại sẵn vì updater dùng `createIfMissing: false`; output cho path `.` là `release_created` không tiền tố và rỗng khi không release nên phải kiểm tra truthiness; cần `contents/issues/pull-requests: write` cộng setting cho phép Actions tạo PR.
- Bug đã sửa trong lúc verify: `versionCode` suy ra theo `major*1e6 + minor*1e3 + patch` bị đụng với offset ABI mà `--split-per-abi` cộng vào (`abiCode * 1000`). Đo bằng `aapt2 dump badging`: 1.0.0/arm64 ra 1002000 thay vì 1000000. Đổi sang `(major*10000 + minor*100 + patch) * 10000` để chừa 4 chữ số cuối cho offset. Kết quả: 100001000 / 100002000 / 100004000.
- Phát hiện `minSdk = 23` đặt trước đó đã quay về `flutter.minSdkVersion`; đổi thành `maxOf(flutter.minSdkVersion, 23)` để giữ yêu cầu mà vẫn theo sàn của Flutter.
- Phát hiện `data/embeddings/` bị stale: build 2026-05-24, sau đó `tarot_meanings_vi.json` sửa "Sao Thổ in Song Ngư" → "trong", làm 73/1170 chunk còn text cũ. Đã build lại index và mobile assets.
- Quyết định: `data/embeddings/` và `mobile/assets/` không commit, CI sinh lại từ `data/output/` + `data/images/` bằng provider `hash`. Đã kiểm bằng venv trống rằng cả hai bước chỉ cần Python chuẩn, không cần dependency hay API key. Repo ~10MB thay vì ~37MB và index không thể lệch với JSON nguồn nữa.
- `.gitignore` gốc: loại `.env` (chứa Telegram token và API key thật), `*.jks`, `key.properties`, `.venv`, `data/raw|cache|cheatsheets|embeddings|bot_state`, `mobile/build`, `mobile/assets`. Giữ `data/*.html` vì tài liệu tham chiếu parser.
- Đã set 4 secret ký APK trên repo và bật `can_approve_pull_request_reviews` để release-please mở được PR.
- Thêm `CONTRIBUTING.md` (Conventional Commits, luồng phát hành, versionCode, secrets, dữ liệu sinh ra).
- Verification:
  - `flutter analyze` / `flutter test` (17 test) pass sau khi đổi pubspec và gradle
  - `aapt2 dump badging` xác nhận versionCode 100001000 / 100002000 / 100004000 cho 1.0.0
  - Quét toàn bộ staged diff không thấy pattern `sk-`, `ghp_`, `sk-ant-`, `AIza`, hay Telegram token
  - Push `main` thành công; workflow `Release` xanh và release-please đã mở PR `chore(main): release 1.0.0`
  - Workflow `CI` trên `main` xanh sau 1m52s: compile Python, build index, sinh assets, analyze, test đều pass trên Linux
- README chuyển sang song ngữ, bản chính tiếng Anh: `README.md` (EN) + `README.vi.md` (VI), `mobile/README.md` (EN) + `mobile/README.vi.md` (VI), có dòng chuyển ngữ ở đầu mỗi file. `CONTRIBUTING.md` vẫn tiếng Việt.
- Nhân dịp viết lại: sửa chỗ README nói "cache/output đã có sẵn trong data/" vì `data/embeddings/` giờ không commit — thêm bước build index trước khi smoke test, và mô tả rõ thư mục nào commit, thư mục nào sinh ra.
- Workflow release: rút gọn message lỗi khi thiếu `ANDROID_KEYSTORE_BASE64` và thêm `keytool -list` ngay sau khi giải mã keystore để fail sớm thay vì lỗi Gradle khó đọc.
- Đã verify base64 round-trip của keystore khớp bit-perfect và alias/password mở được, vì job `apk` chưa chạy thật lần nào.
- Còn lại: PR release 1.0.0 chưa merge nên job `apk` chưa chạy lần nào. CI trên PR do release-please tạo ở trạng thái `action_required` vì PR được tạo bằng GITHUB_TOKEN.

## 2026-09-16

- Sắp xếp lá bài trong `/learn` theo thứ tự bộ bài thay vì alphabet.
- Thêm `learning/deck_order.py` với `MAJOR_ARCANA_ORDER` (The Fool 0 → The World 21), `SUIT_ORDER` (Wands, Cups, Swords, Pentacles), `RANK_ORDER` (Ace → Ten → Page → Knight → Queen → King), `deck_position()` và `sort_cards()`. Tên lá bài trong cả JSON EN và VI đều tiếng Anh nên một bảng tra dùng chung. Tên lạ sort xuống cuối thay vì raise.
- `app/learn.py::cards_for_suit()` gọi `sort_cards()`; nút chọn bộ trong `app/telegram_bot.py::learn_suit_keyboard()` đổi sang Ẩn Chính → Gậy → Cốc → Kiếm → Tiền Vàng.
- Verification:
  - `python -m compileall app learning`
  - smoke test in ra 5 bộ: Major đúng 0-21, mỗi chất đúng Ace→King.

- Thêm ứng dụng Android `mobile/` (Flutter) dùng chung dữ liệu tarot của repo.
- `mobile/tools/prepare_assets.py` export `cards_{en,vi}.json` (đã sort deck order, VI backfill metadata), tách embedding index thành `index_*.json` (metadata) + `index_*.f32` (vector float32 little-endian phẳng), copy 78 ảnh lá bài. Bundle ~16 MB. Phải chạy lại sau mỗi lần đổi dữ liệu.
- Bốn tab: Tra cứu, Học bài, Hỏi đáp, Cài đặt. Tra cứu/rút bài/retrieval chạy offline hoàn toàn; API key OpenAI/Anthropic/Google người dùng nhập trong Cài đặt, lưu bằng `flutter_secure_storage`, app gọi thẳng nhà cung cấp.
- Port 1-1 sang Dart: `deck_order.py`, `HashEmbeddingProvider`, `search_index()`, `learning/study.py`, `learning/verification.py` + `app/grading.py`, `app/qa.py`, `app/llm.py`.
- Hai bẫy parity đã xử lý: `\w` của Dart chỉ ASCII nên phải dùng `[\p{L}\p{N}_]+` cho tiếng Việt; `int.from_bytes(digest, "big")` là 64-bit không dấu nên phải modulo theo từng byte thay vì ép `int` có dấu.
- Bug đã sửa trong lúc test trên emulator: lưu API key làm banner cảnh báo biến mất, list shift một vị trí, Flutter rebind state của `_ProviderCard` sang card kế bên (Anthropic hiện model `gpt-4.1-mini`). Fix bằng `ValueKey<LlmProvider>`.
- Bug đã sửa: trước lần rút đầu tiên hiển thị "còn 0 lá"; `progress()` giờ nhận `deckSize` và báo đủ bộ khi vòng chưa bắt đầu.
- Android config: applicationId `co.astravision.supertarot`, label SuperTarot, minSdk 23 (EncryptedSharedPreferences), thêm quyền INTERNET vào main manifest, ký release qua `android/key.properties` (gitignored, fallback debug key).
- Cập nhật `README.md`, `CLAUDE.md`, `AGENTS.md`, thêm `mobile/README.md`.
- Verification:
  - `flutter analyze` — no issues
  - `flutter test` — 17 test pass (parity hash embedder với vector tham chiếu Python, deck order, load assets EN/VI, cosine search)
  - `flutter build apk --release --split-per-abi` — arm64 25.6 MB, armeabi-v7a 23.2 MB, x86_64 27.0 MB
  - Cài lên emulator x86_64, chạy thật: duyệt bộ + chi tiết lá bài, rút bài học, lưu API key, Q&A retrieve + fallback khi key sai. Không crash.
- Ghi chú chất lượng: index đang bundle build bằng provider `hash` (bag-of-words), nên retrieval của cả app và bot chỉ ở mức từ khóa — truy vấn `Queen of Cups` trả `Knight of Cups` trước. Đã xác nhận Python cho kết quả y hệt. Muốn tốt hơn phải build index bằng OpenAI và cho app gọi API embedding cho query.

## 2026-05-24

- Refined `/random` and `/daily` study draw messages.
- Removed the duplicated top `Lá bài: ...` line from Telegram draw formatting because the generated question already includes the card name.
- Added facet-specific `hint` to `StudyDraw` and included it in the Telegram draw message.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app learning`
  - smoke test confirmed draw formatting contains only one `Lá bài:` line and includes `Gợi ý:`.
  - `python -m app --check`

- Made Telegram `typing...` visible during slow Q&A/grading calls.
- Replaced one-shot `send_typing()` usage with `typing_indicator()` background loop that repeats `sendChatAction=typing` until the slow operation finishes.
- Applied the loop around freeform Q&A and study answer grading.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app`
  - fake-client smoke test confirmed repeated typing actions while the indicator context is active.
  - `python -m app --check`

- Split `/learn` inline details into orientation-specific actions.
- Replaced the new `/learn` summary inline button `Xem đầy đủ` with two buttons: `⬆️ Xuôi` and `⬇️ Ngược` (`⬆️ Upright`/`⬇️ Reversed` for EN).
- Added `format_card_orientation_details()` so callbacks return only the selected orientation's keywords, meaning, love/career/finances/feelings/actions.
- Added `learn_orientation` callback handling and kept legacy `learn_full` callback support for old messages.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app`
  - fake-client smoke test confirmed `/learn` sends two inline orientation buttons and callbacks return orientation-specific HTML without reply keyboard menu.

- Reset Telegram menu state when opening the main menu/help.
- `/help`, `/start`, and `/menu` now clear `learn_menu` before sending `show_menu=True`, so the reply keyboard returns to the main menu even if the user was midway through `/learn`.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - fake-client smoke test confirmed `/help` clears `learn_menu` and sends the main menu keyboard.
  - `python -m compileall app`

- Improved Telegram waiting state and Q&A rendering.
- Added Telegram `sendChatAction=typing` before freeform Q&A and answer grading.
- Q&A replies now send `parse_mode=HTML`, sanitize Markdown bold/list markers into Telegram-safe `<b>` and `•`, and strip generated Lưu ý/Tham chiếu/Nguồn footers.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app`
  - formatter smoke test confirmed raw `**`, `*`, Lưu ý, and Tham chiếu are removed from screenshot-like output.
  - fake-client smoke test confirmed non-command Q&A sends `typing`, `parse_mode=HTML`, and `remove_keyboard`.
  - `python -m app --check`

- Added optional Anthropic and Google/Gemini providers for Q&A and grading.
- Added `app/llm.py` shared provider adapter for OpenAI, Anthropic, and Google REST calls.
- Extended config with `ANTHROPIC_CHAT_MODEL`, `GOOGLE_CHAT_MODEL`, `ANTHROPIC_API_KEY`, and `GOOGLE_API_KEY`/`GEMINI_API_KEY` checks.
- `SUPERTAROT_QA_PROVIDER` now accepts `auto`, `openai`, `anthropic`, `google`, `context`; `SUPERTAROT_GRADING_PROVIDER` accepts `auto`, `openai`, `anthropic`, `google`, `prompt`.
- Updated `.env.example`, `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app`
  - `python -m app --check`
  - Q&A smoke test with `qa_provider=google` and no Google key confirms context fallback reports missing `GOOGLE_API_KEY or GEMINI_API_KEY`.
  - Grading smoke test with `grading_provider=prompt` still returns prompt mode.

- Changed Telegram reply keyboard behavior so the menu no longer auto-opens after every user message.
- Added `/menu` command and made normal responses send `remove_keyboard`; menu keyboard now uses `one_time_keyboard`.
- Kept reply keyboard only for `/menu`, `/start`, `/help`, and `/learn` selection prompts.
- Verification run:
  - `python -m compileall app`
  - fake-client smoke test confirmed `/menu` and `/learn` attach keyboard, while Q&A and `/random` send `remove_keyboard`.

- Improved Tarot Q&A runtime diagnostics.
- Local config check confirmed `.env` is loaded with `SUPERTAROT_QA_PROVIDER=openai`.
- Added startup logging of redacted `AppConfig` and made OpenAI Q&A fallback messages include the actual OpenAI/config error instead of implying the provider was disabled.
- Added `openai` package availability to `python -m app --check` and document reinstall/rebuild steps for OpenAI Q&A fallback cases.
- Removed duplicate `openai` requirement line and installed current requirements in the local Python runtime.
- Verification run:
  - `python -m pip install -r requirements.txt`
  - `python -m app --check` now reports `python_packages.openai=true` and `ok=true`.
  - simulated invalid OpenAI model confirms Q&A fallback now reports OpenAI/config failure explicitly.

- Added freeform Tarot Q&A behavior for Telegram non-command messages.
- Added `app/qa.py` to retrieve embedding chunks and synthesize tarot answers with OpenAI when available, or return context chunks in fallback/context mode.
- Updated `app/telegram_bot.py` routing so plain text becomes Q&A; study grading now requires `/answer ...`.
- Added `SUPERTAROT_QA_PROVIDER` and `SUPERTAROT_QA_TOP_K` config/env support.
- Added root `CONTEXT.md` glossary for Freeform Tarot Question, Study Answer, Retrieved Reference Chunk, Tarot Q&A, and Study Draw.
- Updated `README.md`, `CLAUDE.md`, `AGENTS.md`, and `.env.example`.
- Verification run:
  - `python -m compileall app crawler learning enrichment`
  - `python -m app --check`
  - fake-client smoke test confirmed plain text goes to Tarot Q&A, plain text after `/random` still goes to Tarot Q&A, and `/answer ...` goes to grading.

- Fixed Telegram `Xem đầy đủ` inline callback so it sends the full card message without default reply keyboard markup.
- Cause: `app/telegram_bot.py::send_message` always attached the persistent reply keyboard when `reply_markup` was omitted, so Telegram reopened the menu after callback messages.
- Added `show_menu` to `send_message` and set `show_menu=False` for full-card callback details.
- Verification run:
  - `python -m compileall app`
  - fake callback smoke test confirmed `parse_mode=HTML`, `reply_markup=None`, and callback answered.

- Cleaned accidental CJK/Korean/Japanese fragments from `data/output/tarot_meanings_vi.json`.
- Rebuilt `data/embeddings/tarot_embeddings_vi.json` with the existing hash provider so the VI index no longer contains stale mixed-language text.
- Verification run:
  - `rg -n -P "\p{Han}|\p{Hiragana}|\p{Katakana}|\p{Hangul}" data\output data\embeddings`
  - `python -m learning.embeddings build --provider hash --lang vi`
  - JSON load check for both meaning files and both embedding indexes.

## 2026-05-23

- Added runnable Telegram bot application source under `app/`.
- Added `app/__main__.py` so the app runs with `python -m app`.
- Added runtime modules:
  - `app/config.py` for env config and redacted config checks;
  - `app/telegram_client.py` for direct Telegram Bot API long polling via `requests`;
  - `app/state.py` for `data/bot_state/telegram_bot_state.json`;
  - `app/telegram_bot.py` for commands `/random`, `/daily`, `/schedule`, `/unschedule`, `/answer`, `/lang`, `/status`, `/help`;
  - `app/grading.py` for reference retrieval plus optional OpenAI grading.
- Added `.env.example` documenting `TELEGRAM_BOT_TOKEN`, app language/timezone, image sending, and grading env vars.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md` with app runtime architecture and run commands.
- Verification run:
  - `python -m compileall app crawler learning enrichment`
  - `python -m app --check`
  - `python -m app.telegram_bot --check`
  - fake-client smoke test for `/lang`, `/random`, and `/answer` in prompt mode.

- Separated non-crawler responsibilities into dedicated packages and added run documentation.
- Added `README.md` with setup, module boundaries, run order, local smoke-test commands, API-key notes, and data directory map.
- Moved learning code from `crawler/` to `learning/`:
  - `learning/embeddings.py`
  - `learning/study.py`
  - `learning/verification.py`
  - `learning/console.py` for Windows-safe UTF-8 CLI output.
- Moved enrichment scripts from `crawler/` to `enrichment/`:
  - `enrichment/download_hoctarot_images.py`
  - `enrichment/enrich_cheatsheets.py`
  - `enrichment/translate.py`
  - `enrichment/enrich_vi.py`
- Added compatibility wrappers in `crawler/` for the old module commands.
- Updated `CLAUDE.md` and `AGENTS.md` to describe the split between `crawler`, `enrichment`, and `learning`.
- Verification run:
  - `python -m compileall crawler learning enrichment`
  - `python -m learning.embeddings build --provider hash --lang vi --dry-run`
  - `python -m learning.study draw --user-id readme-test --lang vi --mode random --seed 7 --state data/bot_state/readme_test_state.json`
  - `python -m learning.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "tình yêu mới mở lòng" --top-k 2`
  - compatibility wrapper checks for `crawler.embeddings`, `crawler.study`, and `crawler.verification`.

- Added embedding/retrieval foundation for `data/output/tarot_meanings.json` and `data/output/tarot_meanings_vi.json`.
- Added `crawler/embeddings.py`:
  - chunks each card by overview, correspondences, symbols, upright/reversed summary, love, career, finances, feelings, actions;
  - supports OpenAI production embeddings with `text-embedding-3-small`;
  - supports deterministic `hash` provider for offline smoke tests;
  - writes/searches `data/embeddings/tarot_embeddings_en.json` and `data/embeddings/tarot_embeddings_vi.json`.
- Added `crawler/study.py` for future Telegram bot study flow:
  - per-user deck state in `data/bot_state/study_state.json`;
  - no repeated cards within a 78-card cycle;
  - resets/shuffles when the cycle is exhausted;
  - rotates question facets so daily/random sessions cover all meaning areas over time.
- Added `crawler/verification.py` to retrieve reference chunks and build a GPT grading prompt that returns JSON feedback.
- Updated `requirements.txt` with `openai` for embeddings and `anthropic` because existing translation/enrichment scripts import it.
- Updated `CLAUDE.md` and `AGENTS.md` with the documentation maintenance rule and the new embedding/study/verification pipeline.
- Reconciled `CLAUDE.md` and `AGENTS.md` with current code fields: `yes_no`, card/cheatsheet images, symbols, enriched facet keywords, current metadata lookups, and `crawler/main.py` writer behavior.
- Generated local smoke-test embedding indexes:
  - `data/embeddings/tarot_embeddings_en.json`
  - `data/embeddings/tarot_embeddings_vi.json`
- Verification run:
  - `python -m crawler.embeddings build --provider hash --lang all`
  - `python -m crawler.embeddings search --lang vi --query "tình yêu mới và cảm xúc mở lòng" --top-k 3`
  - `python -m crawler.study draw --user-id local-test --lang vi --mode random --seed 1 --state data/bot_state/test_study_state.json`
  - `python -m crawler.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "..."`
  - no-repeat invariant: 78 first-cycle draws are unique; draw 79 starts cycle 2.
