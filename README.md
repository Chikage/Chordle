# Chordle Flutter

Chordle 是一个跨平台和弦听辨游戏。玩家先试听目标和弦，再像 Wordle 一样在 6 次机会内猜出组成音。Flutter 层共享全部界面、规则和设置；Android 与 iOS 均使用 FluidSynth 播放内置 SoundFont。

## 功能

- `Normal`：A0–C8 范围内的 12 平均律 MIDI 音高听辨。
- `Extra`：1–72 EDO 微分音听辨，支持 50 cents 近似反馈和 POTD 音名。
- `Free`：在 A0–C8 内自由选择 1–72 EDO 音高，刻度尺默认以 C4 为中心；纯 EDO/JI 都支持无参考比例组、每轮更换隐含根音的循环播放，以及多组顺序/随机试听、组内排序与跨组交换。
- `Overtones`：随机最低音上的 JI 整数比例听辨，支持 1–99 数字输入。
- 绿色、黄色、灰色以及 Extra 模式蓝/粉反馈。
- 行排序、单格和整行回放、上一行正确/错位格拖入下一行。
- 可缩放钢琴键盘和 EDO 标尺、2 × 6 比例数字键盘。
- 音域、音数、EDO、比例数字范围、128 个 MIDI Program 和按键预听设置。
- 完全离线，无账号、网络、广告或分析服务。

## 环境

- Flutter 3.44 或兼容的稳定版。
- Android Studio、Android SDK 24+、NDK `28.2.13676358`、CMake `3.22.1`。
- Xcode 26 或兼容版本；最低部署版本 iOS 16.0。
- Android 原生音频当前仅包含 `arm64-v8a` FluidSynth 依赖。

## Android Studio 构建

在 Android Studio 安装 Flutter/Dart 插件后打开仓库根目录，确认 `android/local.properties` 中的 `flutter.sdk` 和 `sdk.dir` 指向本机 SDK。

```bash
flutter pub get
flutter build apk --debug
flutter build appbundle --release
```

也可以进入 `android/` 后运行 `./gradlew assembleDebug`。Debug 使用默认调试签名；Release 应在本地配置自己的 keystore，仓库不包含私钥。

## Xcode 构建

本项目没有第三方 Flutter 插件，因此不依赖 CocoaPods。先生成 Flutter 配置，再打开 Xcode 工程：

```bash
flutter pub get
flutter build ios --config-only --no-codesign
open ios/Runner.xcodeproj
```

在 Xcode 中选择自己的 Team 后可运行真机或执行 Product → Archive。命令行无签名验证：

```bash
flutter build ios --debug --no-codesign
```

iOS 工程内置支持真机和 arm64/x86_64 模拟器的 `FluidSynth.xcframework`。

## 验证

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
```

参考实现位于同级目录 `Chordle-Android` 与 `Chordle-iOS`。
