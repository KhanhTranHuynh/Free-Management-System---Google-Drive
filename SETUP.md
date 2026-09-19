# Hướng dẫn cài đặt môi trường Flutter (cho dev nền Web/Node)

## 1. Cài Flutter SDK

**macOS**
```bash
brew install --cask flutter
```
Hoặc tải trực tiếp: https://docs.flutter.dev/get-started/install/macos

**Windows**
1. Tải Flutter SDK zip: https://docs.flutter.dev/get-started/install/windows
2. Giải nén vào `C:\src\flutter` (không để trong `Program Files` vì có thể lỗi quyền)
3. Thêm `C:\src\flutter\bin` vào biến môi trường `PATH`

**Linux**
```bash
sudo snap install flutter --classic
```
Hoặc tải tarball: https://docs.flutter.dev/get-started/install/linux

Kiểm tra cài đặt thành công:
```bash
flutter --version
```

## 2. Chạy Flutter Doctor (bước quan trọng nhất)

```bash
flutter doctor
```

Lệnh này giống `npm doctor` — nó check toàn bộ môi trường và báo thiếu gì:
- Flutter SDK
- Android toolchain (Android Studio, SDK, licenses)
- Xcode (nếu build iOS, chỉ trên macOS)
- Kết nối thiết bị/emulator
- IDE plugin (VS Code / Android Studio)

Cứ dòng nào có dấu `✗` thì làm theo hướng dẫn nó in ra để fix.

## 3. Cài Android Studio (bắt buộc nếu build Android)

1. Tải: https://developer.android.com/studio
2. Mở Android Studio → **More Actions → SDK Manager**
3. Cài:
   - Android SDK Platform (bản mới nhất)
   - Android SDK Build-Tools
   - Android SDK Command-line Tools
   - Android Emulator
4. Chấp nhận license:
```bash
flutter doctor --android-licenses
```
5. Tạo 1 máy ảo (AVD): **Android Studio → Device Manager → Create Device**

## 4. Cài Xcode (chỉ macOS, nếu build iOS)

```bash
xcode-select --install
sudo xcodebuild -runFirstLaunch
```
Mở Xcode ít nhất 1 lần để nó cài thêm component, sau đó:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## 5. Cài VS Code + Extension (khuyên dùng vì bạn đã quen VS Code từ web)

1. Cài extension **Flutter** (tự kèm theo **Dart**) trong VS Code Marketplace
2. Extension này cho bạn: hot reload bằng phím tắt, debug, widget inspector, format on save — trải nghiệm gần giống ESLint/Prettier bên JS

## 6. Kiểm tra thiết bị chạy thử

```bash
flutter devices
```

Có thể chạy trên:
- **Emulator Android** (mở từ Android Studio Device Manager)
- **Simulator iOS** (chỉ macOS): `open -a Simulator`
- **Thiết bị thật**: bật USB debugging (Android) hoặc trust máy tính (iOS)
- **Chrome** (chạy thử nhanh dạng web, không cần emulator): `flutter run -d chrome`

## 7. Chạy dự án starter này

```bash
# Giải nén source rồi vào thư mục
cd flutter_starter

# Tải các package trong pubspec.yaml (giống npm install)
flutter pub get

# Chạy thử trên Chrome (nhanh nhất để test UI không cần emulator)
flutter run -d chrome

# Hoặc chạy trên emulator/thiết bị đang kết nối
flutter run
```

## 8. Các lệnh hay dùng (đối chiếu với npm/yarn cho dễ nhớ)

| Việc cần làm | Lệnh Flutter | Tương đương bên Node |
|---|---|---|
| Cài dependencies | `flutter pub get` | `npm install` |
| Thêm 1 package | `flutter pub add dio` | `npm install dio` |
| Chạy app (dev) | `flutter run` | `npm run dev` |
| Build production Android | `flutter build apk` | `npm run build` |
| Build production iOS | `flutter build ios` | — |
| Check lỗi tĩnh | `flutter analyze` | `eslint .` |
| Format code | `dart format .` | `prettier --write .` |
| Xoá cache khi lỗi lạ | `flutter clean` | `rm -rf node_modules && npm install` |
| Chạy test | `flutter test` | `npm test` |

## 9. Giải thích nhanh cấu trúc source đã tạo

```
lib/
├── main.dart              # Điểm khởi động, chỉ gọi runApp()
├── app.dart                # Cấu hình MaterialApp: theme, route, provider
├── core/                   # Dùng chung toàn app
│   ├── constants/          # Màu, text, kích thước cố định
│   ├── theme/               # Style tổng (giống theme.css / tailwind.config)
│   ├── utils/                # Hàm validate, helper
│   ├── network/            # ApiClient (Dio) + endpoint (giống axios instance)
│   └── widgets/             # Button, TextField tái sử dụng (design system)
├── data/
│   ├── models/               # Định nghĩa shape dữ liệu (type của response API)
│   ├── services/             # Gọi API thô (giống authApi.js)
│   └── repositories/     # Lớp trung gian giữa service và provider
├── providers/            # State management (giống Redux slice/Pinia store)
├── features/               # Chia theo tính năng: mỗi feature có screens/ + widgets/
│   ├── auth/                  # Màn login/register
│   └── home/                # Màn home
└── routes/                  # Khai báo route tập trung (giống React Router config)
```

**Luồng dữ liệu mẫu (login):**
```
LoginForm (UI)
   → gọi authProvider.login()
      → AuthProvider (providers/auth_provider.dart)
         → gọi UserRepository.login()
            → UserRepository (data/repositories)
               → gọi AuthService.login()
                  → AuthService (data/services) gọi Dio → API backend Express
```

Đây chính là kiểu luồng bạn quen thuộc với React: `Component → hook/action → API service`, chỉ đổi tên gọi.

## 10. Việc đầu tiên nên thử để làm quen

1. Đổi `baseUrl` trong `lib/core/network/api_endpoints.dart` trỏ về backend Express thật của bạn
2. Sửa `lib/features/home/screens/home_screen.dart` — thêm 1 `HomeCard` mới, thử `hot reload` (phím `r` trong terminal hoặc Ctrl+S trong VS Code) để thấy UI cập nhật ngay không mất state
3. Thử đổi `AuthStatus.loading` → xem `CustomButton` tự chuyển sang spinner
4. Thêm 1 route mới trong `app_routes.dart` và tạo screen tương ứng để quen luồng điều hướng

## 11. Lỗi hay gặp khi mới bắt đầu

| Lỗi | Nguyên nhân thường gặp | Cách fix |
|---|---|---|
| `flutter doctor` báo Android license chưa accept | Chưa chạy licenses | `flutter doctor --android-licenses` |
| App không hot reload | Đang sửa `main()`, `initState` field khởi tạo | Dùng Hot Restart (`R` hoa hoặc Ctrl+Shift+F5) |
| `Null check operator used on a null value` | Dùng `!` trên biến có thể null | Kiểm tra null trước, dùng `?.` hoặc `??` |
| Build Android lỗi Gradle | Version Gradle/JDK không khớp | `flutter clean` rồi build lại, hoặc update Android Studio |
| CORS khi gọi API từ Chrome | Backend Express chưa bật CORS | Thêm middleware `cors()` bên Express |
