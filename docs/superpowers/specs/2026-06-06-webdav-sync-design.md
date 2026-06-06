# Thiết kế Kiến trúc: Đồng bộ Dữ liệu Đa Thiết Bị qua WebDAV

## 1. Tổng quan (Overview)
Tính năng đồng bộ cho phép người dùng chia sẻ lịch sử xem phim và tiến trình xem (resume playback) giữa các nền tảng (Mobile, TV, PC) thông qua một máy chủ WebDAV cá nhân. Tính năng này được chia làm 2 giai đoạn:
- **Khởi tạo:** Chia sẻ thông tin đăng nhập WebDAV từ thiết bị đã cấu hình (Điện thoại) sang thiết bị mới (TV) bằng mã QR kết hợp SSH Tunnel.
- **Vận hành:** Đồng bộ dữ liệu lịch sử xem phim 2 chiều liên tục thông qua WebDAV.

## 2. Truyền Cấu hình WebDAV (Config Sync)
Sử dụng phương pháp **SSH Tunnel (Reverse Port Forwarding)** để vượt rào cản Local LAN, cho phép Điện thoại truyền cấu hình sang TV dù khác mạng Wifi.

### Luồng xử lý (Trên TV - Nhận cấu hình):
1. Khởi tạo một Local HTTP Server trên một port ngẫu nhiên.
2. Dùng thư viện `dartssh2` thiết lập một SSH Tunnel ngầm tới dịch vụ free (như `serveo.net` hoặc `localhost.run`).
3. Nhận public URL (vd: `https://xyz.serveo.net`).
4. Hiển thị public URL dưới dạng Mã QR trên màn hình TV (kèm theo một mã PIN 4 số ngẫu nhiên dùng để giải mã).
5. Lắng nghe HTTP POST request tại Local Server. Khi nhận được JSON chứa cấu hình WebDAV -> Giải mã -> Lưu vào local storage -> Tắt HTTP Server & SSH Tunnel.

### Luồng xử lý (Trên Điện thoại - Gửi cấu hình):
1. Mở camera, quét mã QR trên TV để lấy public URL.
2. Nhập mã PIN 4 số hiển thị trên TV.
3. Đóng gói thông tin WebDAV (URL, Username, Password) thành JSON và mã hoá AES với key là mã PIN 4 số (để đảm bảo nhà mạng Tunnel không đọc được).
4. Gửi HTTP POST request chứa payload mã hoá tới public URL.

## 3. Đồng bộ Dữ liệu 2 Chiều (Data Sync)
Dữ liệu sẽ được lưu tại gốc của WebDAV dưới dạng file `cine_stream_history.json`.

### Cấu trúc Dữ liệu:
```json
{
  "movie_123": {
    "episode_id": "ep_5",
    "progress_seconds": 300,
    "duration_seconds": 2400,
    "updated_at": 1717654321
  }
}
```

### Cơ chế Trigger (Lúc nào đồng bộ):
- **PULL (Tải về & Merge):** 
  - Khi App khởi động (Startup).
  - Khi App được mở lại từ Background (AppLifecycleState.resumed).
  - Ngay trước khi vào màn hình Player của một bộ phim.
- **PUSH (Cập nhật lên):**
  - Khi người dùng thoát màn hình Player (Pause/Stop/Back).
  - Khi App bị đẩy xuống Background (AppLifecycleState.paused).

### Giải quyết Xung đột (Conflict Resolution):
Sử dụng thuật toán **Merge by Timestamp (Last-Write-Wins trên từng bộ phim)**:
1. Khi PULL, thiết bị tải `remote_history.json` từ WebDAV.
2. Lặp qua từng `movie_id` của `remote_history.json` và `local_history.json`.
3. So sánh trường `updated_at`:
   - Nếu `remote.updated_at > local.updated_at`: Cập nhật Local bằng dữ liệu của Remote.
   - Nếu `local.updated_at > remote.updated_at`: Đưa dữ liệu Local vào danh sách cần PUSH.
4. Gộp toàn bộ lại thành `merged_history.json`.
5. Nếu có dữ liệu Local mới hơn, tiến hành ghi đè `merged_history.json` ngược lên WebDAV.
