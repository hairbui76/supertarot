# SuperTarot Web

*Đọc bản [English](README.md) — đây là bản chính.*

Site tĩnh dựng bằng Astro, công bố ý nghĩa 78 lá tarot cho ai có trình duyệt.
Tự deploy lên GitHub Pages mỗi lần push vào `main`.

**Không có AI.** Hỏi đáp và chấm bài nằm ở app Android, vì hai phần đó cần API
key và gọi nhà cung cấp. Bản web chỉ làm những gì chạy offline và miễn phí: tra
cứu, tìm kiếm, rút bài.

## Có gì

| Trang | Nội dung |
| --- | --- |
| `/<lang>/` | Hero, năm bộ bài theo đúng thứ tự tarot, và lưới tìm kiếm đủ 78 lá. |
| `/<lang>/suit/<suit>/` | Một bộ, từ Ace tới King. |
| `/<lang>/card/<slug>/` | Một lá: ảnh, correspondences, nghĩa cô đọng, mô tả, biểu tượng, và đầy đủ hai chiều xuôi/ngược. Prerender sẵn nên index được. |
| `/<lang>/draw/` | Rút một lá và một facet, kèm gợi ý. Bấm để xem đáp án tham chiếu, vì không có phần chấm. |

`<lang>` là `vi` hoặc `en`; mỗi trang đều trỏ sang bản ngôn ngữ kia bằng
`hreflang`. Đường dẫn gốc redirect về `/vi/`.

Lưới hiển thị 1 tới 5 lá mỗi hàng: bấm nút, hoặc pinch trên màn cảm ứng. Số
cột, ngôn ngữ và lựa chọn nền sáng/tối đều lưu trong `localStorage`.

## Yêu cầu

- Node 20+
- Python 3.10+ ở thư mục gốc repo, để sinh dữ liệu đầu vào

## Sinh dữ liệu đầu vào

Chạy từ thư mục gốc của repo. **Bắt buộc** sau mỗi lần dữ liệu tarot đổi:

```bash
python web/tools/prepare_web_assets.py
```

Lệnh này ghi ra (tất cả đều gitignore và dựng lại trong CI):

- `web/src/data/cards_{en,vi}.json` — 78 lá theo thứ tự bộ bài, bản tiếng Việt
  đã backfill metadata từ bản tiếng Anh, mỗi lá kèm slug URL và chỉ số vị trí.
- `web/public/cards/*.jpg` — ảnh lá bài.
- `web/public/{logo,favicon,og}.png` — suy ra từ `mobile/icon/app_icon.png` để
  site và icon launcher Android là cùng một dấu hiệu. Phần decode/resize PNG tự
  viết bằng thư viện chuẩn, không kéo thêm dependency ảnh chỉ vì ba file.

Không có embedding index: ở đây không có AI, và tìm kiếm là theo tên lá bài.

## Phát triển

```bash
cd web
npm install
npm run dev      # http://localhost:4321/
npm test         # logic rút bài
npm run check    # astro check
npm run build    # output tĩnh vào web/dist
npm run preview
```

## Triển khai

`.github/workflows/pages.yml` build và deploy mỗi lần push vào `main`.

`site` và `base` lấy từ `actions/configure-pages` lúc build chứ không hard-code,
vì tài khoản đang phục vụ Pages qua custom domain. Giá trị fallback trong
`astro.config.mjs` chỉ dùng khi build ở máy cá nhân.

`robots.txt` cũng sinh từ `Astro.site` vì lý do đó: hard-code URL sitemap sẽ trỏ
sai origin.

## Logic dùng chung

`src/lib/study.ts` là bản port của `learning/study.py`, khớp với
`mobile/lib/src/services/study_service.dart`: cùng thứ tự facet, cùng câu chữ
của câu hỏi và gợi ý, cùng vòng 78 lá không lặp.

`test/study.test.ts` phủ đúng cái mà ảnh chụp không thể cho thấy — rằng một lá
không bao giờ lặp trước khi hết vòng, và bộ đếm vòng tăng sau đó.

## Thiết kế

Neubrutalism theo `DESIGN.md` ở gốc repo: viền 3px, bóng cứng lệch 4px không
blur, màu phẳng bão hòa cao, không gradient, nhãn đậm viết hoa. Token nằm trong
`src/styles/global.css`, và dark mode đổi màu viền/bóng sang gần trắng vì viền
đen trên nền tối là vô hình.

Icon là SVG inline trong `src/lib/icons.ts`, không dùng emoji. Năm biểu tượng bộ
bài cũng vẽ bằng path ở đó, giống `suit_glyph.dart` của app.
