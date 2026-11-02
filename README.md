# 番茄 TV · 番茄短剧大屏版

基于 [guoapp](https://github.com/Xanerix/guoapp)（真果鉴）改造的 Android TV 短剧应用，把**番茄短剧**接成了内置站源，遥控器全流程可用。

- 包名 `com.fanqie.duanju`，应用名「番茄」
- 面向大屏 / 投影仪，arm64-v8a，Android 8.0+
- 本仓库只提供源码与技术记录，**不提供安装包**，需要自行构建

> 本项目仅用于个人设备上的技术研究与自用。`prebuilt/` 下的 `libfanqie_shim.so` 由 GPL-3.0 的上游 [ch6vip/fqapp](https://github.com/ch6vip/fqapp) 的 Rust 核心编译而来，源码可从上游获取。请勿用于商业用途或对外分发安装包。

## 和上游的区别

| 项 | guoapp（真果鉴） | 本项目（番茄） |
| --- | --- | --- |
| 站源 | 多个采集站，设置里逐个开关 | 只剩番茄短剧，内置为唯一首选源 |
| 播放核心 | 纯 Go（`libduanju_core.so`） | Go + 内嵌 Rust 核心（`libfanqie_shim.so`） |
| 应用名 / 包名 | 真果鉴 / `com.duanju.duanju_app` | 番茄 / `com.fanqie.duanju` |
| 目标 | 通用多端 | 只出 TV 版 arm64 单包 |

## 架构

```
Flutter UI (lib/)
   │  FFI
   ▼
libduanju_core.so  (Go mobile，站源框架)
   │  provider_fanqie.go —— 把目录/搜索/详情/播放地址转发成 HTTP
   ▼  http://127.0.0.1:18921
libfanqie_shim.so  (Rust，cdylib)
   │  在进程内起 tokio runtime，调 fqapi_core 的 loopback server
   ▼
番茄 upstream（homepage / series-feed / search / videos / src 流式播放）
```

要点：**没有移植 Rust 的签名算法**。什锦铺（`com.fqapp.fqapp`）的 Rust 核心本身是个完整的 HTTP 服务，这里把它编译成 shim 塞进 guoapp 进程直接跑，Go 侧只做协议转换。这样签名、风控、防盗链逻辑全部复用原实现，不怕上游改算法。

## 新增 / 改动的文件

```
native/fanqie_shim/            # Rust shim 源码（FFI: fanqie_start）
  Cargo.toml  Cargo.lock  src/lib.rs
prebuilt/arm64-v8a/
  libfanqie_shim.so            # 预编译产物，构建时拷进 jniLibs
native/core/provider_fanqie.go # 番茄站源：目录/搜索/详情/章节/播放地址
lib/fanqie_backend.dart        # FFI 加载 shim，运行时目录指向外部存储便于取日志
assets/fanqie/config.json      # 番茄站点配置
assets/fanqie/filter.json      # 分类过滤规则
```

接线改动（都在 `native/core/`）：`app_runtime.go`（`FanqieURL` 配置 + 三分派）、`app_build.go`、`provider_huangguo.go`（`sourceFanqie`）、`app_categories.go`、`provider_media.go`。

Dart 侧：`app_build.dart`（固定 `appName=番茄`、`appSlug=fanqie`）、`models.dart`（注册首选源）、`pubspec.yaml`（`assets/fanqie/`）、`android/app/build.gradle.kts`（`applicationId`、`appLabel`）。

## 遥控器交互

播放器 UI 沿用上游真果鉴的电视模式，本项目只负责把番茄的目录、详情和播放地址喂进去。在极米 Z6 上实测通过：

- 首页分类横排，左右切分类、上下选剧，滑到底自动加载下一页
- 详情页分集网格支持方向键，几十上百集也能直接翻
- 播放控制条按方向键唤出，可与分集列表互切
- 一集播完自动连播下一集，并预缓存后续若干集
- 退出播放回到详情页时保留原来的分集位置

## 构建

前置：Flutter 3.x、JDK 17、Android SDK（NDK 可选）、Rust（仅重编 shim 时需要）。

```bash
# 1) shim 已预编译，直接把 so 放进 jniLibs
mkdir -p android/app/src/main/jniLibs/arm64-v8a
cp prebuilt/arm64-v8a/libfanqie_shim.so android/app/src/main/jniLibs/arm64-v8a/

# 2) 出包
flutter pub get
flutter build apk --release --target-platform android-arm64
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

重新编译 shim（additionally 需要 `fqapp` 的 Rust 源码放在 `../fqapp/rust`，`Cargo.toml` 里是 path 依赖）：

```bash
cd native/fanqie_shim
cargo build --release --target aarch64-linux-android
cp ../../target/aarch64-linux-android/release/libfanqie_shim.so ../../prebuilt/arm64-v8a/
```

签名：`android/app/build.gradle.kts` 只在环境变量 `RELEASE_KEYSTORE_FILE` / `RELEASE_STORE_PASSWORD` / `RELEASE_KEY_ALIAS` / `RELEASE_KEY_PASSWORD` 四个都齐全时才配 `signingConfig`，缺一个就出未签名包（安装报 `INSTALL_PARSE_FAILED_NO_CERTIFICATES`）。

## 踩过的坑

**Android 上 `reqwest::Client` 裸 builder 会让进程直接 panic。** 原实现里 `streaming_client()` 用 `reqwest::Client::builder()` 起客户端，桌面跑得好好的，一到 Android 调播放接口就 EOF 断连，日志里是：

```
panic: rustls-platform-verifier ... Expect to be initialized
```

原因是 reqwest 2 在 Android 上走 `rustls-platform-verifier`，需要传入 Android Context 初始化信任库，而裸 builder 拿不到。改成复用上游 `crate::upstream::http::build_tls_config()`（其内部 `ensure_crypto_provider()` 会把 verifier 配好）之后立刻正常。

排查手法：给 shim 加 panic hook 把 panic 信息落盘到 `fanqie_engine.log`。Flutter 侧的崩溃在设备 logcat 里对 adb shell 不可读，落盘是唯一能拿到的线索。

## 许可与致谢

- 上游 [Xanerix/guoapp](https://github.com/Xanerix/guoapp)，GPL-3.0，本仓库同样以 GPL-3.0 发布，见 [LICENSE](LICENSE)
- 番茄站协议实现依赖 `fqapi_core`（[ch6vip/fqapp](https://github.com/ch6vip/fqapp)，GPL-3.0）
- 上游说明文档保留在 [README.upstream.md](README.upstream.md)

**对应源码（GPLv3 §6）**：本仓库分发的二进制——`prebuilt/arm64-v8a/libfanqie_shim.so`，以及构建产物 APK 内的 `libduanju_core.so`——其完整对应源码可分两部分获取：guoapp 与本项目的改动即本仓库，`fqapi_core` 部分见 [ch6vip/fqapp](https://github.com/ch6vip/fqapp) 的 `rust/` 目录。两者均通过公开的 GitHub 仓库提供，与本仓库同时可得。
