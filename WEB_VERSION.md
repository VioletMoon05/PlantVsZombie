# Bản Web — Plants vs. Zombies

Project này đã có bản chạy trên trình duyệt. Thư mục `web/` chứa trang khởi chạy và cấu hình PWA; game gốc được biên dịch từ Go sang WebAssembly nên dùng lại gameplay, màn chơi, hình ảnh, âm thanh và hệ thống lưu hiện có thay vì làm lại thành một bản demo riêng.

## Build trên Windows

Cần Go 1.24 trở lên và kết nối Internet lần đầu để Go tải các dependency. Không cần Node.js hoặc npm.

Mở PowerShell tại thư mục `D:\pvz`:

```powershell
go version
.\scripts\build-web.ps1
```

Nếu PowerShell chặn script, chạy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-web.ps1
```

File web hoàn chỉnh sẽ được tạo tại `build\web\`. Thư mục này gồm `index.html`, `pvz.wasm`, `wasm_exec.js`, manifest, service worker và icon web.

## Chạy thử trên máy

Không mở trực tiếp `index.html` bằng `file://`; trình duyệt cần HTTP để tải WebAssembly và bật service worker. Sau khi build, chạy:

```powershell
.\scripts\serve-web.ps1
```

Mở `http://127.0.0.1:8080`. Nếu cổng 8080 đang bận, dùng `-Port` khác, ví dụ `.\scripts\serve-web.ps1 -Port 8090`.

Nếu PowerShell chặn script máy chủ, chạy `powershell -ExecutionPolicy Bypass -File .\scripts\serve-web.ps1`.

Nếu Windows từ chối mở máy chủ PowerShell, có thể dùng Python thay thế:

```powershell
python -m http.server 8080 --directory build\web
```

## Public game trên GitHub Pages

Workflow `.github/workflows/pages.yml` tự build game thành WebAssembly và deploy thư mục `build/web` mỗi khi push lên nhánh `main` hoặc `master`.

1. Tạo một repository **Public** trên GitHub. Đừng chỉ upload file ZIP: hãy giải nén và đưa các file/thư mục của project vào gốc repository để GitHub Actions đọc được `.github/workflows/pages.yml`.
2. Push project lên nhánh `main` hoặc `master`.
3. Trong repository, vào **Settings → Pages → Build and deployment → Source**, chọn **GitHub Actions**.
4. Mở tab **Actions**, chờ workflow **Build and deploy PvZ Web** chạy thành công. Trang game sẽ được publish tại `https://<tên-tài-khoản>.github.io/<tên-repository>/` (repository tên `<tên-tài-khoản>.github.io` thì URL không cần phần tên repository).

Ví dụ lệnh push project từ `D:\pvz` sau khi đã tạo repository trống trên GitHub:

```powershell
git init
git add .
git commit -m "Publish PvZ web game"
git branch -M main
git remote add origin https://github.com/<username>/<repository>.git
git push -u origin main
```

Sau lần push đầu tiên, mỗi lần push commit mới lên `main`/`master`, workflow sẽ deploy lại tự động. Build tạo `pvz.wasm` khoảng 85 MiB; người chơi chỉ cần mở URL GitHub Pages, không cần chạy PowerShell hay cài Go.

## Đưa lên hosting tĩnh khác

Build lại rồi upload **toàn bộ nội dung** của `build\web\` lên hosting tĩnh (GitHub Pages, Cloudflare Pages, nginx...). Nên dùng HTTPS; `localhost` được trình duyệt cho phép khi phát triển. Với cấu hình hiện tại, không cần backend riêng.

Lần tải đầu có thể hơi lâu vì `pvz.wasm` khoảng 85 MiB và chứa tài nguyên game. Service worker cache phần giao diện và thử lưu WASM; do kích thước lớn, trình duyệt có thể từ chối hoặc tự xóa cache, nên không đảm bảo chơi offline.

Tiến trình và thiết lập lưu trong bộ nhớ trình duyệt của từng profile/origin, không tự đồng bộ với bản desktop hoặc giữa các thiết bị. Trên điện thoại nên xoay ngang; thao tác trong game dùng chuột/chạm theo hỗ trợ sẵn của Ebitengine.
