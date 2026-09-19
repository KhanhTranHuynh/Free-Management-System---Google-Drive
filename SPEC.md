# Quy chuẩn cấu trúc thư mục dự án Flutter

Tài liệu này mô tả cách tổ chức code trong thư mục `lib/`, vai trò của từng thư mục và các quy tắc bắt buộc khi viết code. Mọi thành viên cần đọc và tuân thủ để codebase đồng nhất, dễ bảo trì.

Cấu trúc được thiết kế theo tư duy quen thuộc của React (component, page, store, api), nhưng vẫn dùng đúng cách viết của Flutter (Widget, Provider).

---

## 1. Tổng quan

```
lib/
├── apis/          # Gọi API và các thao tác liên quan đến API
├── components/    # Component (widget) dùng chung, không chứa nghiệp vụ
├── configs/       # Cấu hình: biến môi trường, theme, hằng số
├── pages/         # Các trang chính, mỗi trang gắn với một route
├── routes/        # Khai báo route, điều hướng, bảo vệ trang
├── stores/        # State dùng chung toàn app (Provider / ChangeNotifier)
├── utils/         # Hàm tiện ích dùng lại
├── views/         # Các khối giao diện lớn của một trang
├── app.dart       # Widget gốc: MaterialApp, MultiProvider, theme, routes
└── main.dart      # Điểm khởi động: khởi tạo rồi runApp()
.env               # Biến môi trường (KHÔNG commit lên git)
pubspec.yaml       # Khai báo thư viện, asset
SETUP.md           # Hướng dẫn cài đặt và chạy dự án
```

### Đối chiếu với React

| Thư mục Flutter | Tương đương trong React                      |
| --------------- | -------------------------------------------- |
| `apis/`         | `services/` hoặc `api/` (axios, fetch)       |
| `components/`   | `components/` (Button, Input, Card...)       |
| `configs/`      | `config/`, `.env`, theme, constants          |
| `pages/`        | `pages/` (Next.js) hoặc các route component  |
| `views/`        | Các section/container lớn bên trong một page |
| `stores/`       | Redux, Zustand, Context                      |
| `routes/`       | React Router (kèm ProtectedRoute)            |
| `utils/`        | `utils/`, `lib/`                             |

---

## 2. Nguyên tắc chung

1. **Mỗi file một trách nhiệm.** Mỗi widget lớn nằm trong file riêng, tên file khớp với tên class.
2. **Giao diện không gọi API trực tiếp.** Giao diện đọc dữ liệu từ `stores/`, `stores/` gọi `apis/`.
3. **Tuân thủ chiều phụ thuộc** (mục 4). Không import ngược lên tầng trên.
4. **Không viết cứng** màu, URL, chuỗi cấu hình trong widget. Lấy từ `configs/`.
5. **Ưu tiên tái sử dụng.** Thấy đoạn giao diện hoặc hàm lặp lại từ lần thứ hai thì tách ra `components/` hoặc `utils/`.
6. **Tách widget thành class**, không tách thành hàm kiểu `Widget buildXxx()`.
7. **Dùng `const`** cho constructor và khi gọi widget bất biến để Flutter không dựng lại thừa.

---

## 3. Chi tiết từng thư mục

### 3.1 `apis/`: gọi API

Nơi duy nhất được phép giao tiếp với server. Bao gồm cấu hình client HTTP, interceptor (gắn token, xử lý lỗi 401), và các hàm gọi từng nhóm endpoint.

**Đặt gì ở đây:**

- Client HTTP dùng chung (base URL, timeout, interceptor)
- Các file API theo nhóm: `auth_api.dart`, `photo_api.dart`
- Model dữ liệu trả về từ API (hoặc để trong thư mục `apis/models/` nếu muốn gom gọn)

**Không đặt ở đây:** code giao diện, `BuildContext`, logic hiển thị.

```
apis/
├── api_client.dart      # Cấu hình HTTP client, interceptor
├── auth_api.dart
├── photo_api.dart
└── models/
    ├── user.dart
    └── photo.dart
```

```dart
// apis/auth_api.dart
class AuthApi {
  final ApiClient _client;
  AuthApi(this._client);

  Future<User> login(String email, String password) async {
    final res = await _client.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return User.fromJson(res.data);
  }
}
```

**Quy tắc:**

- Hàm API chỉ nhận tham số và trả về dữ liệu (model), không hiển thị dialog hay điều hướng.
- Lỗi được ném ra (throw) để `stores/` xử lý.
- Tên file kết thúc bằng `_api.dart`.

---

### 3.2 `components/`: component dùng chung

Các widget **giao diện thuần**, dùng ở nhiều nơi, **không biết gì về nghiệp vụ** của app. Giống thư viện UI kit nội bộ.

**Ví dụ:** `AppButton`, `AppTextField`, `AppCard`, `AppAvatar`, `LoadingView`, `EmptyState`, `AppDialog`.

```
components/
├── app_button.dart
├── app_text_field.dart
├── app_card.dart
├── loading_view.dart
└── empty_state.dart
```

```dart
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
```

**Quy tắc:**

- **Không import** `stores/` hay `apis/` trong component. Dữ liệu và hành động truyền vào qua tham số (giống props).
- Tên class có tiền tố `App` để phân biệt với widget gốc của Flutter (trừ những widget hiển thị trạng thái như `LoadingView`, `EmptyState`).
- Màu, cỡ chữ, khoảng cách lấy từ `configs/` hoặc `Theme.of(context)`.
- Mỗi component một file.

---

### 3.3 `configs/`: cấu hình

Thông số cơ bản của ứng dụng. Nơi này là nguồn duy nhất cho các giá trị cấu hình.

**Đặt gì ở đây:**

- `env.dart`: đọc biến môi trường từ `.env` (base URL, key...)
- `app_theme.dart`: `ThemeData` cho toàn app
- `app_colors.dart`, `app_spacing.dart`, `app_text_styles.dart`: design tokens
- `app_constants.dart`: hằng số chung (timeout, số item mỗi trang, tên key lưu trữ...)

```
configs/
├── env.dart
├── app_theme.dart
├── app_colors.dart
├── app_spacing.dart
└── app_constants.dart
```

```dart
// configs/env.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
}
```

**Quy tắc:**

- **`.env` không được commit lên git.** Thêm vào `.gitignore` và cung cấp file mẫu `.env.example` (không chứa giá trị thật).
- Nếu dùng `flutter_dotenv`, phải khai báo `.env` trong mục `assets` của `pubspec.yaml`.
- Không đặt bí mật quan trọng (secret key của server) trong app, vì app có thể bị dịch ngược.
- Thư mục này **không import** bất kỳ thư mục nào khác của `lib/`.

---

### 3.4 `pages/`: các trang chính

Mỗi file là **một màn hình hoàn chỉnh**, gắn trực tiếp với một route. Page đóng vai trò "khung": dựng `Scaffold`, `AppBar`, lấy dữ liệu từ store và ghép các `views` lại với nhau.

```
pages/
├── login_page.dart
├── home_page.dart
└── photo_detail_page.dart
```

```dart
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang chủ')),
      body: const Column(
        children: [
          HomeHeaderView(),
          Expanded(child: PhotoGridView()),
        ],
      ),
    );
  }
}
```

**Quy tắc:**

- Tên file kết thúc bằng `_page.dart`, tên class kết thúc bằng `Page`.
- Page **mỏng**: chủ yếu ghép views, không chứa hàng trăm dòng giao diện chi tiết.
- Page được phép đọc `stores/` (qua `context.watch` / `context.read`).
- Một trang một route, đăng ký trong `routes/`.

---

### 3.5 `views/`: các khối giao diện của một trang

Một page thường lớn, nên chia thành nhiều **khối (section)** có nghiệp vụ riêng, ví dụ khu vực header, danh sách ảnh, form đăng nhập, thanh lọc. Mỗi khối là một view.

```
views/
├── home/
│   ├── home_header_view.dart
│   └── photo_grid_view.dart
└── auth/
    └── login_form_view.dart
```

Nên gom view vào thư mục con theo trang hoặc theo tính năng.

**Phân biệt `views/` và `components/`:**

|                       | `components/`               | `views/`                         |
| --------------------- | --------------------------- | -------------------------------- |
| Biết về nghiệp vụ app | Không                       | Có                               |
| Dùng ở nhiều trang    | Có                          | Thường chỉ dùng cho một trang    |
| Đọc `stores/`         | Không                       | Được                             |
| Ví dụ                 | `AppButton`, `AppTextField` | `LoginFormView`, `PhotoGridView` |

**Quy tắc:**

- Tên file kết thúc bằng `_view.dart`, tên class kết thúc bằng `View`.
- View được ghép từ `components/`.
- Nếu một view bắt đầu được dùng lại ở nhiều trang và không còn phụ thuộc nghiệp vụ, hãy chuyển nó sang `components/`.

---

### 3.6 `routes/`: điều hướng và bảo vệ trang

Khai báo tất cả route tập trung. Muốn thêm màn hình mới, sửa ở đây.

```dart
// routes/app_routes.dart
class AppRoutes {
  AppRoutes._();

  static const String login = '/';
  static const String home = '/home';

  /// Các route cần đăng nhập mới được vào
  static const Set<String> protected = {home};

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name;

    Widget page;
    switch (name) {
      case login:
        page = const LoginPage();
        break;
      case home:
        page = const HomePage();
        break;
      default:
        page = const NotFoundPage();
    }

    // Bảo vệ route: chưa đăng nhập thì chuyển về trang login
    if (protected.contains(name)) {
      page = AuthGuard(child: page);
    }

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
```

```dart
// routes/auth_guard.dart
class AuthGuard extends StatelessWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthStore>().isLoggedIn;
    if (!isLoggedIn) return const LoginPage();
    return child;
  }
}
```

Trong `app.dart` dùng `onGenerateRoute: AppRoutes.onGenerateRoute` thay cho `routes:` khi cần bảo vệ trang.

**Quy tắc:**

- Không viết chuỗi đường dẫn cứng ở nơi khác, luôn dùng hằng số `AppRoutes.xxx`.
- Điều hướng bằng `Navigator.pushNamed(context, AppRoutes.home)`.
- Logic bảo vệ trang (kiểm tra đăng nhập, phân quyền) đặt ở thư mục này.

---

### 3.7 `stores/`: state dùng chung

Lưu dữ liệu và trạng thái dùng chung giữa nhiều màn hình (phiên đăng nhập, danh sách ảnh, cài đặt...). Dùng `ChangeNotifier` kết hợp package `provider`.

```
stores/
├── auth_store.dart
└── photo_store.dart
```

```dart
class AuthStore extends ChangeNotifier {
  final AuthApi _api;
  AuthStore(this._api);

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _api.login(email, password);
    } catch (e) {
      _error = 'Đăng nhập thất bại';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
```

Đăng ký store ở `app.dart`:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthStore(AuthApi(ApiClient()))),
  ],
  child: MaterialApp(...),
)
```

Sử dụng trong giao diện:

```dart
final auth = context.watch<AuthStore>();       // đọc và tự vẽ lại khi đổi
context.read<AuthStore>().login(email, pass);  // chỉ gọi hàm (dùng trong onPressed)
```

**Quy tắc:**

- Tên file kết thúc bằng `_store.dart`, tên class kết thúc bằng `Store`.
- Store là nơi **duy nhất** gọi `apis/` (giao diện không gọi API trực tiếp).
- Luôn gọi `notifyListeners()` sau khi đổi state.
- Dữ liệu chỉ dùng trong một widget (ô nhập, tab đang chọn) thì dùng `StatefulWidget` + `setState`, **không** đưa vào store.
- Store không chứa `BuildContext` và không hiển thị giao diện.

---

### 3.8 `utils/`: hàm tiện ích

Các hàm dùng lại nhiều nơi, độc lập với giao diện và state của app.

```
utils/
├── date_utils.dart      # định dạng ngày giờ
├── validators.dart      # kiểm tra email, mật khẩu, số điện thoại
├── formatters.dart      # định dạng tiền, dung lượng file
└── extensions.dart      # extension cho String, DateTime...
```

```dart
class Validators {
  Validators._();

  static bool isEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
}

extension DateFormatX on DateTime {
  String get short => '$day/$month/$year';
}
```

**Quy tắc:**

- Ưu tiên **hàm thuần** (cùng đầu vào cho cùng kết quả), không phụ thuộc store hay API.
- Chia file theo chủ đề, **không** gom mọi thứ vào một `utils.dart`.
- Hàm gắn với một kiểu dữ liệu thì viết dạng `extension`.
- Hàm cần `BuildContext` (hiện dialog, snackbar) nên đặt thành helper riêng, ví dụ `utils/ui_helper.dart`, và ghi rõ trong tên file.

---

### 3.9 `app.dart` và `main.dart`

**`main.dart`**: chỉ khởi tạo những gì cần có trước khi app chạy rồi gọi `runApp`.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}
```

**`app.dart`**: widget gốc gồm `MultiProvider`, `MaterialApp`, theme và routes. Không chứa logic nghiệp vụ.

---

## 4. Chiều phụ thuộc (ai được import ai)

```
pages  →  views  →  components
  │         │
  └────┬────┘
       ▼
     stores  →  apis  →  configs

utils và configs: mọi tầng đều có thể dùng, nhưng chúng không import ngược lên.
```

Bảng chi tiết:

| Thư mục       | Được import                                                   | Không được import                        |
| ------------- | ------------------------------------------------------------- | ---------------------------------------- |
| `pages/`      | `views`, `components`, `stores`, `configs`, `utils`, `routes` | `apis`                                   |
| `views/`      | `components`, `stores`, `configs`, `utils`                    | `apis`, `pages`                          |
| `components/` | `configs`, `utils`                                            | `stores`, `apis`, `views`, `pages`       |
| `stores/`     | `apis`, `configs`, `utils`                                    | `pages`, `views`, `components`           |
| `apis/`       | `configs`, `utils`                                            | `stores`, `pages`, `views`, `components` |
| `routes/`     | `pages`, `stores`, `configs`                                  | `apis`                                   |
| `utils/`      | (không phụ thuộc thư mục app nào)                             | tất cả                                   |
| `configs/`    | (không phụ thuộc thư mục app nào)                             | tất cả                                   |

Quy tắc ngắn gọn: **giao diện không gọi API; API không biết giao diện; component không biết nghiệp vụ.**

---

## 5. Luồng dữ liệu ví dụ: đăng nhập

```
LoginPage
  └─ LoginFormView            (view: form đăng nhập)
       ├─ AppTextField        (component: ô nhập)
       └─ AppButton           (component: nút)
             │ onPressed
             ▼
        AuthStore.login()     (store: quản lý state, loading, lỗi)
             │
             ▼
        AuthApi.login()       (api: gọi server)
             │
             ▼
        Server → trả User → store lưu → notifyListeners()
             │
             ▼
        Giao diện tự vẽ lại → điều hướng sang AppRoutes.home
```

---

## 6. Quy ước đặt tên

| Đối tượng            | Quy tắc                              | Ví dụ                                      |
| -------------------- | ------------------------------------ | ------------------------------------------ |
| Tên file             | `snake_case.dart`                    | `photo_grid_view.dart`                     |
| Tên class            | `PascalCase`                         | `PhotoGridView`                            |
| Page                 | file `_page.dart`, class `...Page`   | `home_page.dart` → `HomePage`              |
| View                 | file `_view.dart`, class `...View`   | `home_header_view.dart` → `HomeHeaderView` |
| Component dùng chung | tiền tố `App`                        | `AppButton`                                |
| Store                | file `_store.dart`, class `...Store` | `auth_store.dart` → `AuthStore`            |
| API                  | file `_api.dart`, class `...Api`     | `photo_api.dart` → `PhotoApi`              |
| Hằng số              | `lowerCamelCase` trong class         | `AppConstants.pageSize`                    |
| Thành phần private   | tiền tố `_`                          | `_buildRow`, `_HomeState`                  |

---

## 7. Quy trình thêm một tính năng mới

Ví dụ: thêm trang "Danh sách ảnh".

1. **Model**: tạo `apis/models/photo.dart` (kèm `fromJson`).
2. **API**: tạo `apis/photo_api.dart` với các hàm gọi endpoint.
3. **Store**: tạo `stores/photo_store.dart`, đăng ký trong `MultiProvider` ở `app.dart`.
4. **Component**: nếu cần widget chung mới (ví dụ `AppCard`), thêm vào `components/`.
5. **View**: tạo các khối giao diện trong `views/photo/`.
6. **Page**: tạo `pages/photo_list_page.dart`, ghép các view.
7. **Route**: thêm hằng số và case mới trong `routes/app_routes.dart` (thêm vào `protected` nếu cần đăng nhập).

---

## 8. Điều nên làm và không nên làm

**Nên:**

- Tách widget thành class riêng, mỗi widget lớn một file.
- Dùng `const` ở mọi nơi có thể.
- Xử lý đủ 3 trạng thái khi lấy dữ liệu: đang tải, có lỗi, có dữ liệu (kể cả rỗng).
- Đặt giá trị cấu hình vào `configs/`.
- Dùng `context.read` trong `onPressed`, `context.watch` trong `build`.

**Không nên:**

- Gọi API trực tiếp trong widget hoặc trong `pages/`, `views/`.
- Import `stores/` hoặc `apis/` vào `components/`.
- Viết cứng màu, URL, đường dẫn route trong code giao diện.
- Đưa state cục bộ (của một ô nhập, một tab) vào store.
- Gom nhiều class không liên quan vào một file, hoặc tạo file `utils.dart` khổng lồ.
- Commit file `.env` chứa giá trị thật.
- Để một `build()` dài hàng trăm dòng mà không tách nhỏ.

---

## 9. Checklist review code

- [ ] File nằm đúng thư mục theo vai trò
- [ ] Tên file và tên class đúng quy ước
- [ ] Không vi phạm chiều phụ thuộc ở mục 4
- [ ] Không có màu, URL, chuỗi cấu hình viết cứng
- [ ] Không gọi API trực tiếp từ giao diện
- [ ] Widget bất biến đã dùng `const`
- [ ] Có xử lý trạng thái loading và lỗi
- [ ] Không có widget tái sử dụng bị copy-paste (nên đưa vào `components/`)
- [ ] Không commit thông tin nhạy cảm
- [ ] Đã chạy `flutter analyze` và không còn cảnh báo

---

## 10. Thư viện đề xuất

| Mục đích                         | Package                  |
| -------------------------------- | ------------------------ |
| Quản lý state                    | `provider`               |
| Gọi API                          | `dio` (hoặc `http`)      |
| Biến môi trường                  | `flutter_dotenv`         |
| Lưu dữ liệu nhỏ (token, cài đặt) | `shared_preferences`     |
| Lưu dữ liệu nhạy cảm (token)     | `flutter_secure_storage` |
| Kiểm tra code                    | `flutter_lints`          |

Bất kỳ package mới nào cũng cần thống nhất với nhóm trước khi thêm vào `pubspec.yaml`.

---

## 11. Lệnh thường dùng

```bash
flutter pub get          # tải thư viện
flutter run              # chạy app
flutter analyze          # kiểm tra lỗi và cảnh báo
dart format lib          # định dạng code
flutter clean            # dọn build khi gặp lỗi lạ
```
