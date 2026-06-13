# Sub2api

<div align="center">

**Sub2API 网关平台的跨平台客户端(用户端 + 管理端)**

Flutter 构建 · Android / iOS / Windows / macOS / Linux

</div>

---

## 一、项目概述

Sub2api 是为 [Sub2API](https://github.com/Wei-Shaw/sub2api) AI API 网关平台开发的移动端/桌面端客户端。Sub2API 平台用于把 AI 产品订阅额度转换为 API 配额进行分发与管理;本客户端让用户和管理员无需打开网页即可随时随地完成日常操作:

- **用户端**:控制台总览、API 密钥管理、用量统计、订阅管理、余额与兑换、公告查看、个人资料与两步验证;
- **管理端**(管理员登录后解锁):平台仪表盘、上游账号池管理、用户管理、分组管理、渠道监控、兑换码/优惠码管理等;
- **多后端**:默认连接 `https://ai.alsl.xyz`,支持添加并切换任意自建 Sub2API 后端。

> ⚠️ **使用须知**:Sub2API 平台本身的使用可能违反上游 AI 服务商的服务条款,请在遵守当地法律法规及相关用户协议的前提下使用;由此产生的风险由使用者自行承担。本项目仅供技术学习与研究。

| 基本信息 | |
|---|---|
| 应用名称 | Sub2api |
| 包名 / Bundle ID | `com.gucooing.sub2api` |
| 仓库 | <https://github.com/gucooing/sub2api-app> |
| 默认后端 | `https://ai.alsl.xyz` |
| 当前版本 | 0.1.0+1 |
| 许可 | 与上游生态保持一致,暂未单独声明 |

## 二、技术栈

| 组件 | 选型 | 用途 |
|---|---|---|
| 框架 | Flutter 3.44 / Dart 3.12 | 一套代码五端运行 |
| 状态管理 | flutter_riverpod 3.x | 全局状态、依赖注入、可测试 |
| 路由 | go_router 17.x | 声明式路由、深链 |
| 网络 | dio 5.x | REST 请求、拦截器、超时控制 |
| 安全存储 | flutter_secure_storage | 登录令牌等敏感信息 |
| 本地配置 | shared_preferences | 语言、主题、服务器列表 |
| 图表 | fl_chart | 用量/趋势可视化 |
| 国际化 | 自研运行时语言包系统 + flutter_localizations | 见「四、多语言语言包系统」 |
| 图标生成 | flutter_launcher_icons + 自研 `tool/prepare_icon.dart` | 全平台启动图标 |

## 三、项目框架(目录与文件职责)

> **本节是项目的框架基准**:新增代码必须落位到下述对应位置;新增模块时必须同步更新本节与 `docs/TASKS.md`。

```
sub2api/
├── android/  ios/  windows/  macos/  linux/   # 各平台宿主工程(显示名已统一为 Sub2api)
│   └── android/gradle.properties              # 含 Kotlin in-process 编译配置(绕过 Windows 下
│                                              #   Kotlin 2.3 daemon 增量缓存崩溃,勿随意删除)
├── assets/                                    # 静态资源(pubspec.yaml 中注册)
│   ├── branding/logo.png                      # Sub2API 官方 Logo 原图(应用内展示用)
│   ├── icon/                                  # 由 tool/prepare_icon.dart 生成,勿手改
│   │   ├── app_icon.png                       #   通用 1024 方形图标(Windows/macOS/通用)
│   │   ├── app_icon_ios.png                   #   iOS 满幅无透明版本
│   │   └── app_icon_foreground.png            #   Android 自适应图标前景层
│   └── i18n/                                  # 内置语言包(运行时 JSON,非编译期资源)
│       ├── manifest.json                      #   语言包清单:packs 列表 + fallback 回退语言
│       ├── zh-CN.json                         #   简体中文(内置)
│       └── en-US.json                         #   English(内置,回退语言)
├── docs/
│   └── TASKS.md                               # 开发任务清单:模块位置/优先级/完成状态
├── lib/
│   ├── main.dart                              # 入口:初始化 prefs + 语言包注册表,装配 ProviderScope
│   ├── app.dart                               # 根组件 Sub2apiApp:MaterialApp.router、主题、本地化装配
│   └── src/
│       ├── core/                              # 与业务无关的基础设施层
│       │   ├── config/app_config.dart         #   编译期常量:应用名、默认后端、超时、仓库地址
│       │   ├── router/app_router.dart         #   go_router 路由表(全部路由集中于此)
│       │   ├── network/                       #   dio 封装:ApiClient、ApiException、鉴权拦截器、
│       │   │                                  #     api_client_provider(按激活账号/指定服务器构建)
│       │   ├── account/                       #   多账号:AccountProfile + AccountStore(令牌按账号分键)
│       │   ├── server/                        #   多后端:ServerProfile 模型与 ServerStore 持久化
│       │   ├── session/                       #   会话:SessionController(以账号为单位)、AuthApi、
│       │   │                                  #     auth_models(AppUser/PublicSettingsLite/登录条款)
│       │   ├── preferences/                   #   轻量偏好(外置浏览器开关等)
│       │   ├── storage/
│       │   │   ├── prefs_store.dart           #   SharedPreferences Provider + PrefKeys 键名集中管理
│       │   │   └── secure_store.dart          #   flutter_secure_storage 封装(令牌按账号、凭据按服务器)
│       │   └── theme/
│       │       ├── app_colors.dart            #   品牌色板(取自官方 Logo:#1A2E63/#4ADE80/#3B82F6)
│       │       ├── app_theme.dart             #   Material 3 明暗主题工厂
│       │       └── theme_controller.dart      #   主题模式状态(system/light/dark + 持久化)
│       ├── i18n/                              # 运行时语言包系统(框架核心,见第四节)
│       │   ├── language_pack.dart             #   语言包模型:JSON 解析、嵌套键扁平化、locale 解析
│       │   ├── language_pack_loader.dart      #   加载器:内置 assets + 外置目录两个来源
│       │   ├── language_pack_registry.dart    #   注册表:标签→语言包,精确/同语言/回退三级解析
│       │   ├── app_localizations.dart         #   本地化入口:AppLocalizations.of / context.tr / 委托
│       │   └── locale_controller.dart         #   语言状态:跟随系统/手动选择/外置包热重载
│       ├── features/                          # 业务功能层,按域组织;每个子目录 = 一个功能模块
│       │   ├── auth/                          #   登录(选/加服务器 + 登录条款)、注册、登录条款组件
│       │   ├── settings/                      #   设置、服务器管理(servers_screen)、账号管理(accounts_screen)
│       │   ├── shell/                         #   登录后外壳:home_shell(底部导航+顶栏)、me_tab、splash
│       │   ├── user/                          #   用户端,三层(data/providers/presentation)分模块:
│       │   │                                  #     dashboard/ keys/ usage/ usage_logs/ announcements/
│       │   │                                  #     subscriptions/ redeem/ profile/ features/
│       │   │                                  #     recharge/ affiliate/ channels_view/
│       │   └── admin/                         #   [规划中,M3 暂停] dashboard/ accounts/ users/ …
│       └── shared/                            # 跨功能复用的纯 UI 组件与工具
│           ├── format/formatters.dart         #   数值/日期/金额格式化(formatCompact/Cost/Int/Date…)
│           └── widgets/                       #   Pro 组件库:kpi_tile/sparkline/metric_trend_chart/
│                                              #     multi_series_trend_chart/token_*/status_pill/
│                                              #     availability_bar/uptime_timeline/data_table_card/
│                                              #     brand_header/section_header/confirm_dialog/
│                                              #     app_toast/markdown_text/user_avatar/empty_state… 等
├── test/                                      # 单元测试(i18n/account/session/各模块 data 层解析)
│   ├── i18n_test.dart  account_store_test.dart  session_controller_test.dart
│   ├── server_store_test.dart  api_client_test.dart
│   └── user_*_test.dart                       #   dashboard/keys/usage_logs/features/modules 解析
├── tool/
│   └── prepare_icon.dart                      # 图标生成脚本:dart run tool/prepare_icon.dart
├── pubspec.yaml                               # 依赖、资源注册、flutter_launcher_icons 配置
└── README.md                                  # 本文档
```

### 架构分层规则

1. **依赖方向**:`features → (core | i18n | shared)`;`core` 之间允许互相引用;**`core`/`i18n`/`shared` 禁止反向依赖 `features`**。
2. **功能模块内部结构**(进入实质开发后遵循):
   ```
   features/<域>/<模块>/
   ├── data/          # 数据访问:API 调用封装、DTO 模型(fromJson/toJson)
   ├── providers/     # Riverpod 状态(Notifier/FutureProvider)
   └── presentation/  # 页面与模块内组件
   ```
   单文件能讲清楚的小模块可以先平铺(如当前 `settings_screen.dart`),复杂化后再拆分,但拆分形态必须是上述结构。
3. **路由**:全部路由集中注册在 `core/router/app_router.dart`,路径常量随路由定义;不在页面内裸写字符串路径。
4. **存储键名**:统一收敛在 `prefs_store.dart` 的 `PrefKeys`,禁止散落魔法字符串。
5. **文案**:界面一律 `context.tr('模块.键')`,**禁止硬编码中英文文案**;新增键必须同时写入 `zh-CN.json` 与 `en-US.json`(两包键集保持一致)。
6. **网络**:所有请求经由 `core/network` 的 ApiClient(规划中)发出,业务层不直接 new Dio。
7. **质量门槛**:提交前 `flutter analyze` 0 告警、`flutter test` 全绿。

### Git 约定

- 提交信息中文,格式 `<type>: <主题>`,type ∈ `feat / fix / docs / refactor / test / chore`;
- 每完成一个可运行的小功能即提交本地仓库(细粒度里程碑);
- 远程仓库 `origin = https://github.com/gucooing/sub2api-app`,推送需项目负责人确认。

## 四、多语言语言包系统(核心设计)

设计目标:**新增/修订语言无需重新编译或重新安装应用**,与 Sub2API 网页端一致地默认跟随系统语言;内置简体中文与英文,其它语言由社区语言包补充。

### 工作机制

```
启动 → LanguagePackLoader
        ├─ 读 assets/i18n/manifest.json → 加载内置包(zh-CN、en-US)
        └─ 扫描 <应用文档目录>/sub2api/i18n/*.json → 加载外置包(同标签覆盖内置)
      → LanguagePackRegistry(标签 → 语言包;en-US 为回退包)
      → LocaleController 决定生效语言:
          用户手动选择(持久化) > 系统语言(默认) > 回退语言
      → AppLocalizationsDelegate 同步装配,UI 经 context.tr('key') 取文案
运行时 → 设置页「重新加载外部语言包」按钮 → 重扫外置目录,热更新语言列表与文案
```

- **键查找回退链**:当前语言包 → en-US 回退包 → 键名本身(保证界面永不空白);
- **系统语言匹配**:精确标签(`zh-CN`)→ 同语言(`zh-*`)→ 回退(`en-US`);
- **外置目录**:Android 为 `/data/user/0/com.gucooing.sub2api/app_flutter/sub2api/i18n`,桌面端为系统文档目录下 `sub2api/i18n`,设置页内有完整路径展示与复制。

### 语言包 JSON 格式规范(社区语言包按此编写)

```jsonc
{
  "@@locale": "ja-JP",        // 必填:BCP-47 语言标签,同时作为语言包标识
  "@@name": "Japanese",       // 选填:语言英文名
  "@@nativeName": "日本語",    // 选填:语言自称,显示在语言选择列表
  "common": { "ok": "OK" },   // 任意层级嵌套,运行时扁平化为 "common.ok"
  "home":   { "welcome": "{name} へようこそ" }   // {占位符} 由 tr(params:) 替换
}
```

将上述 `.json` 文件放入外置目录后,在「设置 → 语言包 → 重新加载外部语言包」即可生效(已在 Android 模拟器实测通过:日语包投放 → 重载 → 语言列表即时出现「日本語」)。

## 五、开发环境与常用命令

| 操作 | 命令 |
|---|---|
| 安装依赖 | `flutter pub get` |
| 运行(调试) | `flutter run -d <device>` |
| 静态检查 | `flutter analyze` |
| 单元测试 | `flutter test` |
| Android APK | `flutter build apk` |
| iOS / macOS | `flutter build ios` / `flutter build macos`(需 macOS + Xcode) |
| Windows | `flutter build windows`(需 VS C++ 工具链;本仓库开发机不可用,统一用 Android 模拟器验证) |
| Linux | `flutter build linux`(需 Linux + GTK 开发库) |
| 重新生成启动图标 | `dart run tool/prepare_icon.dart && dart run flutter_launcher_icons` |

> Linux 桌面启动器图标不在 flutter_launcher_icons 范围内,打包(deb/rpm/AppImage)时把 `assets/icon/app_icon.png` 写入 `.desktop` 文件即可。

## 六、持续集成与发布(GitHub Actions)

工作流:[`.github/workflows/build.yml`](.github/workflows/build.yml)

- **每次提交 / PR**:运行 `flutter analyze` + `flutter test` 检查代码(构建/发布的前置门槛);
- **手动触发**(Actions → build → Run workflow):
  - **填写「版本号」**(如 `0.2.0`):检查通过后构建五端产物并**自动创建该版本号的 GitHub Release** 上传;
  - **留空**:仅构建五端产物(可在 Artifacts 下载),不发布 Release。

> 发布以「运行工作流时填写的版本号」为准,无需手动打 tag;Release 会以该版本号为 tag 名在当前提交上创建。构建时版本号经 `--build-name` 写入应用,可在「设置 → 关于」查看;构建时间经 `--dart-define=APP_BUILD_TIME` 注入。

构建覆盖的平台 / 架构:

| 平台 | 架构 / 产物 |
|---|---|
| Android | `arm64-v8a` / `armeabi-v7a` / `x86_64` 三个 ABI 的 APK |
| Windows | x64:便携 `zip` + Inno Setup `setup.exe` |
| Linux | x64:`tar.gz` + `deb` + `AppImage` |
| macOS | universal(arm64 + x64)`dmg` |
| iOS | arm64 **未签名** ipa(未提供证书;自签 / 侧载用) |

> 各平台基本是单架构(Android 3 个 ABI、macOS 为 arm64+x64 通用二进制);Windows/Linux 桌面 Flutter 目前主力为 x64。打包脚本见 `.github/version.sh`、`.github/package-linux.sh`。

### Android 签名密钥(仓库 Settings → Secrets and variables → Actions)

| Secret 名称 | 值 |
|---|---|
| `SIGN_KEYSTORE_BASE64` | keystore 文件的 Base64(`base64 -w0 your.jks`) |
| `KEYSTORE_PASSWORD` | 生成 keystore 时的 **store** 密码 |
| `KEY_ALIAS` | 生成时使用的 alias |
| `KEY_PASSWORD` | key 密码(可与 store 相同) |

CI 会把 `SIGN_KEYSTORE_BASE64` 解码为 `android/app/upload-keystore.jks` 并生成 `android/key.properties`;`android/app/build.gradle.kts` 在检测到 `key.properties` 时启用发布签名,否则回退 debug 签名(本地无需密钥即可 `flutter run --release`)。`key.properties` 与 `*.jks` 已在 `.gitignore` 中,切勿提交。

### 发布一个版本 / 应用内更新

发布:打开 GitHub → **Actions → build → Run workflow**,在「版本号」里填 `0.2.0` 后运行,即自动构建五端并发布名为 `0.2.0` 的 Release(留空则只构建不发布)。

应用内更新检查:启动时静默检查、设置页可手动「检查更新」,均比对 GitHub 最新 Release;有新版本时弹窗,按当前平台/架构匹配 Release 资产直接前往下载(匹配不到则打开 Releases 页)。

> 生成 keystore:`keytool -genkey -v -keystore your.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your-key-alias`

## 七、文档索引

- [docs/TASKS.md](docs/TASKS.md) —— 开发任务清单(模块位置 / 优先级 / 完成状态),**开发前必读**;
- 上游平台 API 参考:`D:\github\sub2api`(本地克隆)中 `frontend/src/api/*.ts` 为各端点的权威调用方式,`backend/internal/handler` 为服务端实现。
