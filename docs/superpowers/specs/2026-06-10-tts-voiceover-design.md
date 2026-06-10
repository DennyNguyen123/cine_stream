# Design Spec: TTS Voice-over (Thuyết minh tự động từ Subtitle)

## 1. Mục tiêu (Goal)
Tự động chuyển đổi Subtitle thành âm thanh (Thuyết minh) ngay trong lúc phát video để mang lại trải nghiệm xem phim rảnh mắt. Hỗ trợ cả Native TTS của thiết bị và tùy chọn cấu hình Custom OpenAI TTS.

## 2. Kiến trúc (Architecture)
Áp dụng **Strategy Pattern** cho service TTS để tách biệt logic điều khiển và dễ mở rộng.
- Tạo Interface `TtsService` với các phương thức cốt lõi: `speak(text, durationMs)`, `stop()`, `pause()`, `resume()`.
- **`NativeTtsImpl`**: Sử dụng package `flutter_tts` gọi trực tiếp TextToSpeech của hệ điều hành. Phù hợp vì miễn phí và offline.
- **`OpenAiTtsImpl`**: Dùng cho Cách 2, gọi HTTP API tương thích chuẩn OpenAI (`/v1/audio/speech`).

## 3. Luồng dữ liệu và Đồng bộ (Data Flow & Sync)
1. **Nguồn đọc (Source Selection)**: Do màn hình có 2 phụ đề (Trên và Dưới), hệ thống sẽ ưu tiên đọc **Phụ đề Dưới** (Bottom Subtitle / `_currentSecondaryCue`) làm mặc định (vì đây thường là phụ đề ngôn ngữ mẹ đẻ). Người dùng có thể dễ dàng chuyển sang đọc **Phụ đề Trên** (Top Subtitle / `_currentPrimaryCue`) thông qua phần cài đặt Voice-over.
2. **Đồng bộ thời điểm bắt đầu**: Cả 2 phụ đề đều có chứa `startMs` và `endMs`. Khi biến phụ đề được chỉ định cập nhật câu mới, hệ thống gọi `TtsService.speak()` chính xác tại mốc `startMs`. Nhờ vậy, *thời điểm cất giọng sẽ khớp tuyệt đối 100% với lúc dòng chữ xuất hiện*.
3. **Đồng bộ thời lượng (Dynamic Speed)**:
   - Dù bắt đầu cùng lúc, nhưng thời gian để giọng máy đọc xong câu văn có thể kéo dài hơn thời gian hiển thị của Subtitle (`endMs - startMs`).
   - *Giải pháp:* Thuật toán sẽ đo độ dài câu và thời gian cho phép, từ đó tự động tăng nhẹ tham số `SpeechRate` (tốc độ đọc) để lời nói kết thúc vừa vặn với lúc dòng chữ biến mất (tối đa tăng tốc 1.5x để giọng không bị méo).
4. **Điều khiển (Playback Control)**:
   - Video Pause / Seek -> Gọi `TtsService.stop()`.
   - Tính năng ngắt mềm (Smart Cut-off) khi 2 dòng thoại xuất hiện quá sát nhau.

## 4. Giao diện (UI) & Cấu hình (Settings)
- **Trong PlayerScreen (Bật/Tắt nhanh)**: Thêm nút **Voice-over** (Icon micro/loa) vào thanh `TvControls` kế bên nút Subtitles. Đây là công tắc (Toggle) để người dùng có thể dễ dàng Bật/Tắt (ON/OFF) tính năng thuyết minh bất cứ lúc nào khi đang xem phim.
- **Trong Settings Screen (Cấu hình chi tiết)**: Thêm section **Voice-over Configuration**:
  - `Engine`: Chọn "System Default" (Native TTS) hoặc "OpenAI Compatible".
  - `Source`: Chọn đọc từ "Bottom Subtitle" (mặc định) hoặc "Top Subtitle".
  - Các ô nhập liệu cho OpenAI: `Base URL`, `API Key`, `Voice Model` (alloy, echo, v.v.).
- **Đồng bộ QR / WebDAV**: Các cấu hình của phần TTS này (`tts_engine`, `tts_source`, `tts_api_key`, `tts_base_url`, `tts_model`) sẽ được bổ sung vào payload JSON mã hoá trong QR Code của tính năng Mobile Sync (`mobile_sync_screen.dart`). Qua đó người dùng chỉ cần nhập API Key phức tạp trên điện thoại và quét mã QR để đồng bộ cấu hình sang bản cài đặt trên TV/Desktop một cách dễ dàng.

## 5. Xử lý lỗi (Error Handling)
- Lỗi thiết bị không có gói ngôn ngữ tiếng Việt -> Báo Toast hướng dẫn người dùng cài đặt.
- Lỗi kết nối API (khi dùng OpenAI custom) -> Tự động Fallback dùng Native TTS và báo Toast.
