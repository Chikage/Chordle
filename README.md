# Chordle

Chordle 是一个 Android 和弦听辨游戏：听一组音，像 Wordle 一样在有限次数内猜出目标和弦。项目使用 Kotlin 与 Jetpack Compose 构建界面，底层通过 C++、Oboe 和 FluidSynth 提供低延迟音频播放。

## 功能

- 三种游戏模式：
  - `Normal`：猜标准 12 平均律 MIDI 音高组成的和弦。
  - `Extra`：猜可配置 EDO（equal divisions of the octave）音级，支持微分音听辨。
  - `Overtones`：猜泛音倍数，题目会随机选择基音与泛音范围。
- Wordle 风格反馈：正确位置、存在但位置不对、不存在等状态会以不同格子状态显示。
- Extra 模式包含 50 cents 容差反馈，但只有完全命中的绿色格子才算胜利。
- 可配置出题音域、和弦音数、EDO 数、泛音范围、MIDI program 音色与按键预听。
- 内置加密 SoundFont 资源，首次启动时解密到缓存并由 FluidSynth 加载。
- 离线运行；Manifest 中只声明了震动权限和可选音频输出特性。

## 技术栈

- Kotlin 2.2.10
- Jetpack Compose + Material 3
- Android Gradle Plugin 9.3.0-rc01
- Gradle Wrapper 9.6.0
- Android SDK：`compileSdk 37` / `targetSdk 37` / `minSdk 24`
- NDK：`28.2.13676358`
- C++14、CMake、Oboe、FluidSynth
- JUnit 4 单元测试

当前构建配置只启用 `arm64-v8a` ABI。

## 项目结构

```text
.
├── app/
│   ├── src/main/java/icu/ringona/chordle/
│   │   ├── MainActivity.kt              # Compose UI、游戏界面、设置弹窗与播放控制
│   │   ├── ChordGame.kt                 # 核心规则、出题、判定与标签生成
│   │   ├── DefaultSoundFontLoader.kt    # 内置 SoundFont 解密与加载
│   │   └── audio/
│   │       ├── NativeAudio.kt           # 原生音频接口
│   │       └── NativeAudioEngine.kt     # JNI 封装
│   ├── src/main/cpp/
│   │   ├── XenAudioEngine.cpp           # C++ 音频引擎
│   │   ├── CMakeLists.txt               # 原生构建配置
│   │   ├── fluidsynth/                  # FluidSynth 头文件与预编译库
│   │   └── oboe/                        # Oboe 头文件与预编译库
│   ├── src/main/assets/blob/            # 加密的默认音色资源
│   └── src/test/java/icu/ringona/chordle/ChordGameTest.kt
├── gradle/libs.versions.toml
├── settings.gradle.kts
└── build.gradle.kts
```

## 本地开发

### 环境要求

1. 安装 Android Studio 或 Android SDK，并确保 `local.properties` 中包含正确的 `sdk.dir`。
2. 安装 JDK 17。
3. 安装 Android NDK `28.2.13676358` 与 CMake `3.22.1` 或更高版本。

### 签名配置

当前 `app/build.gradle.kts` 会在 Gradle 配置阶段读取 release 签名信息，所以即使执行 debug 或测试任务，也需要能找到签名文件与密码。

仓库根目录需要存在：

```text
key.jks
```

签名密码可以放在环境变量、Gradle properties 或本地 `local.properties` 中。支持的键名包括：

```properties
RELEASE_STORE_PASSWORD=your_store_password
RELEASE_KEY_ALIAS=as2134u
RELEASE_KEY_PASSWORD=your_key_password
```

也兼容旧键名：

```properties
sign.store.password=your_store_password
sign.key.alias=as2134u
sign.key.password=your_key_password
```

不要把包含真实密码的 `local.properties` 提交到仓库。

### 常用命令

运行单元测试：

```bash
./gradlew testDebugUnitTest
```

构建 debug APK：

```bash
./gradlew assembleDebug
```

安装到已连接设备：

```bash
./gradlew installDebug
```

构建 release APK：

```bash
./gradlew assembleRelease
```

## 游戏规则概览

每局最多 6 次尝试。玩家先播放目标和弦，再从钢琴键盘、EDO 标尺或泛音面板中选择音高并提交。

- 绿色：音高和位置都正确。
- 黄色：目标中包含该音高，但位置不正确。
- 灰色：目标中不包含该音高。
- Extra 模式还会标出接近目标音高的音级；默认容差为 50 cents。

Normal 与 Extra 模式默认出题音数为 3，可配置为 1 到 10。默认音域为 `C3-C5`，完整可选范围为 `A0-C8`。Overtones 模式默认出题 4 个泛音倍数，默认范围为 `8x-16x`。

## 测试覆盖

现有单元测试主要覆盖：

- 普通模式猜测判定。
- Extra 模式 50 cents 容差与胜利条件。
- EDO 音名标签生成。
- 音域、音数、MIDI program 与泛音范围的边界处理。
- 泛音基音选择与最高频率限制。

## License

本项目使用 MIT License，详见 [LICENSE](LICENSE)。
