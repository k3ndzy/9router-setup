# 🚀 9Router Auto-Setup Toolkit (macOS & Windows)

Bộ công cụ tự động cài đặt, cấu hình chứng chỉ SSL, DNS nội bộ và vá toàn bộ các lỗi tiềm ẩn của **9Router MITM Proxy** cho **Antigravity IDE**, **GitHub Copilot**, và **Kiro**.

---

## 📁 Danh sách tệp tin trong bộ cài đặt

| Tệp tin | Mô tả |
| :--- | :--- |
| 🍎 **`setup-macos.sh`** | Script cài đặt & cấu hình tự động 1-click cho **macOS**. |
| 🍎 **`start-macos.sh`** | Phím tắt khởi động nhanh 9Router với quyền root trên **macOS**. |
| 🪟 **`setup-windows.ps1`** | Script cài đặt & cấu hình tự động 1-click cho **Windows** (PowerShell). |
| 🪟 **`start-windows.bat`** | File nhấp đúp khởi động nhanh 9Router với quyền Admin trên **Windows**. |
| 🔧 **`patch-9router.js`** | Module tự động kiểm tra và vá 5 lỗi cốt lõi trong mã nguồn 9Router. |

---

## 🛠️ Những lỗi bộ công cụ này tự động xử lý:
1. **Lỗi `ENOENT .mitm.lock`**: Tự động tạo thư mục `~/.9router/mitm` trước khi khởi chạy.
2. **Lỗi `Connection reset by peer`**: Chặn 9Router quét trúng và tự kết liễu tiến trình `sudo` cha.
3. **Lỗi `sudo: 1 incorrect password attempt`**: Bỏ qua `sudo -S` khi ứng dụng đã chạy dưới quyền root.
4. **Cài đặt chứng chỉ SSL tự động**: Tự động đưa Root CA vào macOS System Keychain / Windows Root Store với cờ `Always Trust`.
5. **Cấu hình chuyển hướng DNS**: Tự động thêm các domain `cloudcode-pa.googleapis.com` vào file `hosts` và làm mới DNS cache.
6. **Tự động ánh xạ model**: Thiết lập sẵn file `aliases.json` để Antigravity IDE hoạt động ngay lập tức.

---

## 🍎 Hướng dẫn sử dụng trên macOS

### Bước 1: Cài đặt & cấu hình (chỉ chạy 1 lần đầu)
Mở Terminal, di chuyển vào thư mục này và chạy:
```bash
chmod +x *.sh *.js
sudo ./setup-macos.sh
```

### Bước 2: Khởi động 9Router hàng ngày
Mỗi khi cần dùng, mở Terminal và gõ:
```bash
./start-macos.sh
# Hoặc: sudo $(which 9router)
```
- Mở trình duyệt vào Dashboard: `http://localhost:20128/dashboard/mitm`
- Bấm **Start Server** và bắt đầu code trên Antigravity IDE!

---

## 🪟 Hướng dẫn sử dụng trên Windows

### Bước 1: Cài đặt & cấu hình (chỉ chạy 1 lần đầu)
1. Mở **PowerShell** bằng quyền Administrator (**Run as Administrator**).
2. Di chuyển vào thư mục này và chạy:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows.ps1
```

### Bước 2: Khởi động 9Router hàng ngày
- Chỉ cần nhấp đúp chuột vào file **`start-windows.bat`** (sẽ tự động xin quyền Admin và bật server).
- Mở trình duyệt vào Dashboard: `http://localhost:20128/dashboard/mitm`
- Bấm **Start Server**!
