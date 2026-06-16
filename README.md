# Sub2api

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-跨平台客户端-02569B.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2.svg)](https://dart.dev/)
[![平台](https://img.shields.io/badge/平台-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-4ADE80.svg)](#五开发环境与常用命令)

**Sub2API 网关平台的跨平台客户端**

本项目全程采用 Claude 4.8 与 GPT-5.5 两个模型编写。

用户端 + 管理端 · 多后端 · 多账号 · 运行时语言包

</div>

---

## 重要提示

请在使用本项目之前认真阅读以下内容:

- **服务条款风险**:Sub2API 及其相关网关能力可能违反上游 AI 服务商的服务条款。请在使用前自行阅读并确认相关用户协议,由此产生的风险由使用者自行承担。
- **合规使用**:请仅在遵守所在国家或地区法律法规的前提下使用本项目。禁止将本项目用于任何违法、违规或侵害第三方权益的场景。
- **免责声明**:本项目仅供技术学习与研究。作者不对账号封禁、服务中断、数据丢失、费用损失或其它直接、间接损害承担责任。

## 一、项目概述

Sub2api 是为 [Sub2API 服务端](https://github.com/Wei-Shaw/sub2api) 开发的移动端与桌面端客户端。Sub2API 用于将 AI 产品订阅额度转换为可分发、可计费、可管理的 API 配额;本客户端让普通用户和管理员无需打开网页即可完成日常操作。

本客户端默认连接 `https://ai.alsl.xyz`,也支持添加并切换任意自建 Sub2API 后端。

| 基本信息 | 内容 |
|---|---|
| 应用名称 | Sub2api |
| 包名 / Bundle ID | `com.gucooing.sub2api` |
| 客户端仓库 | <https://github.com/gucooing/sub2api-app> |
| 服务端仓库 | <https://github.com/Wei-Shaw/sub2api> |
| 默认后端 | `https://ai.alsl.xyz` |
| 兼容后端版本 | `0.1.136` |
| 当前版本 | `0.1.0+1` |
| 许可 | [GNU Lesser General Public License v3.0 或更高版本](LICENSE) |

### 功能特性

- **多后端管理**:内置默认后端,支持添加、编辑、切换自建 Sub2API 后端。
- **多账号会话**:账号以「服务器 + 后端用户」为单位隔离,支持登录态恢复、切换、登出与删除。
- **用户控制台**:总览、API 密钥、用量趋势、使用记录、公告、订阅、兑换、充值、邀请返利、可用渠道、个人资料与两步验证。
- **管理端入口**:管理员登录后可进入管理模块,处理平台仪表盘、用户、分组、兑换码、渠道监控、上游账号池与系统设置等功能。
- **精细数据展示**:用量、费用、渠道健康度、订单和记录详情尽量对齐服务端返回字段,便于排查与审计。
- **运行时语言包**:内置简体中文与英文,外置语言包可热加载,新增语言无需重新编译或重新安装。
- **跨平台发布**:同一套 Flutter 代码覆盖 Android、iOS、Windows、macOS、Linux。
- **应用内更新**:通过 GitHub Releases 检查新版本,按当前平台匹配下载资产。

## 赞助商

感谢赞助商对本项目的支持。

| 赞助商 | 链接 | 说明 |
|---|---|---|
| Codex Api | <https://ai.alsl.xyz> | 感谢 Codex Api 赞助本项目。该服务也是客户端内置默认后端入口,用户仍可在应用内切换为自己的 Sub2API 后端。 |

## 二、技术栈

| 组件 | 选型 | 用途 |
|---|---|---|
| 框架 | Flutter / Dart | 一套代码多端运行 |
| 状态管理 | flutter_riverpod 3.x | 全局状态、依赖注入、可测试 |
| 路由 | go_router 17.x | 声明式路由、深链 |
| 网络 | dio 5.x | REST 请求、拦截器、超时控制 |
| 安全存储 | flutter_secure_storage | 登录令牌等敏感信息 |
| 本地配置 | shared_preferences | 语言、主题、服务器列表 |
| 图表 | fl_chart | 用量与趋势可视化 |
| 链接跳转 | url_launcher | 支付、绑定、更新下载等外部跳转 |
| 二维码 | qr_flutter | 充值二维码、邀请链接分享 |
| Markdown | gpt_markdown | 公告、更新说明等富文本展示 |
| 国际化 | 自研运行时语言包系统 + flutter_localizations | 见「四、多语言语言包系统」 |
| 图标生成 | flutter_launcher_icons + 自研 `tool/prepare_icon.dart` | 全平台启动图标 |

## 三、项目框架

> **本节是项目的框架基准**:新增代码必须落位到下述对应位置;新增模块时必须同步更新本节与 `docs/TASKS.md`。

```
sub2api/
├── android/  ios/  windows/  macos/  linux/   # 各平台宿主工程,显示名统一为 Sub2api
│   └── android/gradle.properties              # 含 Kotlin in-process 编译配置,勿随意删除
├── assets/                                    # 静态资源,pubspec.yaml 中注册
│   ├── branding/logo.png                      # Sub2API 官方 Logo 原图
│   ├── icon/                                  # 由 tool/prepare_icon.dart 生成,勿手改
│   │   ├── app_icon.png                       #   通用 1024 方形图标
│   │   ├── app_icon_ios.png                   #   iOS 满幅无透明版本
│   │   └── app_icon_foreground.png            #   Android 自适应图标前景层
│   └── i18n/                                  # 内置语言包,运行时 JSON
│       ├── manifest.json                      #   语言包清单
│       ├── zh-CN.json                         #   简体中文
│       └── en-US.json                         #   英文回退包
├── docs/
│   └── TASKS.md                               # 开发任务清单:模块位置、优先级、完成状态
├── lib/
│   ├── main.dart                              # 入口:初始化 prefs + 语言包注册表,装配 ProviderScope
│   ├── app.dart                               # 根组件 Sub2apiApp:MaterialApp.router、主题、本地化装配
│   └── src/
│       ├── core/                              # 与业务无关的基础设施层
│       │   ├── config/app_config.dart         #   应用名、默认后端、超时、仓库地址、兼容后端版本
│       │   ├── router/app_router.dart         #   go_router 路由表,全部路由集中于此
│       │   ├── network/                       #   dio 封装、鉴权拦截器、错误归一化、ApiClient Provider
│       │   ├── account/                       #   多账号:AccountProfile + AccountStore
│       │   ├── server/                        #   多后端:ServerProfile + ServerStore
│       │   ├── session/                       #   会话:SessionController、AuthApi、公开设置模型
│       │   ├── preferences/                   #   轻量偏好
│       │   ├── storage/                       #   SharedPreferences 与安全存储封装
│       │   ├── theme/                         #   Material 3 主题与主题状态
│       │   └── update/                        #   GitHub Releases 更新检查
│       ├── i18n/                              # 运行时语言包系统,见第四节
│       │   ├── language_pack.dart             #   语言包模型、JSON 解析、键扁平化
│       │   ├── language_pack_loader.dart      #   内置 assets + 外置目录加载
│       │   ├── language_pack_registry.dart    #   精确、同语言、回退三级解析
│       │   ├── app_localizations.dart         #   AppLocalizations.of / context.tr / 委托
│       │   └── locale_controller.dart         #   跟随系统、手动选择、外置包热重载
│       ├── features/                          # 业务功能层,按域组织
│       │   ├── auth/                          #   登录、注册、两步验证、登录条款
│       │   ├── settings/                      #   设置、服务器管理、账号管理、更新检查
│       │   ├── shell/                         #   登录后外壳、底部导航、我的页、启动页
│       │   ├── user/                          #   用户端模块
│       │   │                                  #     dashboard/ keys/ usage/ usage_logs/ announcements/
│       │   │                                  #     subscriptions/ redeem/ profile/ recharge/
│       │   │                                  #     affiliate/ channels_view/ features/
│       │   └── admin/                         #   管理端模块
│       │                                      #     dashboard/ accounts/ users/ groups/ redeem/
│       │                                      #     monitor/ settings/ shared/ shell/
│       └── shared/                            # 跨功能复用的纯 UI 组件与工具
│           ├── format/formatters.dart         #   数值、日期、金额格式化
│           └── widgets/                       #   KPI、图表、状态、表格、弹窗、Toast、Markdown 等组件
├── test/                                      # 单元测试
│   ├── i18n_test.dart  account_store_test.dart  session_controller_test.dart
│   ├── server_store_test.dart  api_client_test.dart
│   └── user_*_test.dart                       #   用户端各模块 data 层解析
├── tool/
│   └── prepare_icon.dart                      # 图标生成脚本
├── pubspec.yaml                               # 依赖、资源注册、图标配置
└── README.md                                  # 本文档
```

### 架构分层规则

1. **依赖方向**:`features → (core | i18n | shared)`;`core` 之间允许互相引用;**`core`/`i18n`/`shared` 禁止反向依赖 `features`**。
2. **功能模块内部结构**:
   ```
   features/<域>/<模块>/
   ├── data/          # 数据访问:API 调用封装、DTO 模型(fromJson/toJson)
   ├── providers/     # Riverpod 状态(Notifier/FutureProvider)
   └── presentation/  # 页面与模块内组件
   ```
   单文件能讲清楚的小模块可以先平铺,复杂化后再拆分,但拆分形态必须是上述结构。
3. **路由**:全部路由集中注册在 `core/router/app_router.dart`,路径常量随路由定义;不在页面内裸写字符串路径。
4. **存储键名**:统一收敛在 `prefs_store.dart` 的 `PrefKeys`,禁止散落魔法字符串。
5. **文案**:界面一律 `context.tr('模块.键')`,**禁止硬编码中英文文案**;新增键必须同时写入 `zh-CN.json` 与 `en-US.json`,两包键集保持一致。
6. **网络**:所有请求经由 `core/network` 的 ApiClient 发出,业务层不直接 new Dio。
7. **质量门槛**:提交前 `flutter analyze` 0 告警、`flutter test` 全绿。

### Git 约定

- 提交信息使用中文,格式为 `<type>: <主题>`,type ∈ `feat / fix / docs / refactor / test / chore`;
- 每完成一个可运行的小功能即提交本地仓库,保持细粒度里程碑;
- 远程仓库 `origin = https://github.com/gucooing/sub2api-app`,推送需项目负责人确认。

## 四、多语言语言包系统

设计目标:**新增或修订语言无需重新编译、无需重新安装应用**。默认跟随系统语言,内置简体中文与英文,其它语言由社区语言包补充。

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

- **键查找回退链**:当前语言包 → en-US 回退包 → 键名本身,保证界面永不空白;
- **系统语言匹配**:精确标签(`zh-CN`)→ 同语言(`zh-*`)→ 回退(`en-US`);
- **外置目录**:Android 为 `/data/user/0/com.gucooing.sub2api/app_flutter/sub2api/i18n`,桌面端为系统文档目录下 `sub2api/i18n`,设置页内有完整路径展示与复制。

### 语言包 JSON 格式规范

```jsonc
{
  "@@locale": "ja-JP",        // 必填:BCP-47 语言标签,同时作为语言包标识
  "@@name": "Japanese",       // 选填:语言英文名
  "@@nativeName": "日本語",    // 选填:语言自称,显示在语言选择列表
  "common": { "ok": "OK" },   // 任意层级嵌套,运行时扁平化为 "common.ok"
  "home": { "welcome": "{name} へようこそ" }
}
```

将上述 `.json` 文件放入外置目录后,在「设置 → 语言包 → 重新加载外部语言包」即可生效。

## 五、开发环境与常用命令

| 操作 | 命令 |
|---|---|
| 安装依赖 | `flutter pub get` |
| 运行调试 | `flutter run -d <device>` |
| 静态检查 | `flutter analyze` |
| 单元测试 | `flutter test` |
| Android APK | `flutter build apk` |
| iOS / macOS | `flutter build ios` / `flutter build macos` |
| Windows | `flutter build windows` |
| Linux | `flutter build linux` |
| 重新生成启动图标 | `dart run tool/prepare_icon.dart && dart run flutter_launcher_icons` |

> Linux 桌面启动器图标不在 flutter_launcher_icons 范围内,打包时把 `assets/icon/app_icon.png` 写入 `.desktop` 文件即可。

### 自建后端兼容提示

- 服务端部署、数据库、Redis、Docker Compose、源码构建等内容以 [Sub2API 服务端 README](https://github.com/Wei-Shaw/sub2api) 为准。
- 若使用 Nginx 反向代理 Sub2API,并且后端需要带下划线的请求头参与会话或调度,请在 Nginx `http` 块中启用:

```nginx
underscores_in_headers on;
```

- 上游 API 行为以服务端仓库的 [frontend/src/api](https://github.com/Wei-Shaw/sub2api/tree/main/frontend/src/api) 为权威参考,服务端实现以 [backend/internal/handler](https://github.com/Wei-Shaw/sub2api/tree/main/backend/internal/handler) 为准。客户端禁止凭空杜撰端点。

## 六、生态

| 项目 | 说明 | 链接 |
|---|---|---|
| Sub2API 服务端 | AI API 网关平台,负责认证、计费、调度、转发、管理后台与公开设置接口 | <https://github.com/Wei-Shaw/sub2api> |
| Sub2api 客户端 | 本项目,负责在移动端与桌面端提供用户端和管理端体验 | <https://github.com/gucooing/sub2api-app> |
| 服务端 Web 前端 | API 行为与字段对齐的权威参考之一 | <https://github.com/Wei-Shaw/sub2api/tree/main/frontend/src/api> |

## 七、持续集成与发布

工作流:[`.github/workflows/build.yml`](.github/workflows/build.yml)

- **每次提交 / PR**:运行 `flutter analyze` + `flutter test` 检查代码,这是构建和发布的前置门槛;
- **手动触发**:进入 GitHub → Actions → build → Run workflow;
- **填写版本号**:例如 `0.2.0`,检查通过后构建五端产物并自动创建该版本号的 GitHub Release;
- **留空版本号**:仅构建五端产物,可在 Artifacts 下载,不发布 Release。

发布以运行工作流时填写的版本号为准,无需手动打 tag。Release 会以该版本号为 tag 名在当前提交上创建。构建时版本号经 `--build-name` 写入应用,构建时间经 `--dart-define=APP_BUILD_TIME` 注入。

构建覆盖的平台 / 架构:

| 平台 | 架构 / 产物 |
|---|---|
| Android | `arm64-v8a` / `armeabi-v7a` / `x86_64` 三个 ABI 的 APK |
| Windows | x64:便携 `zip` + Inno Setup `setup.exe` |
| Linux | x64:`tar.gz` + `deb` + `AppImage` |
| macOS | universal,arm64 + x64 通用 `dmg` |
| iOS | arm64 未签名 ipa,用于自签或侧载 |

### Android 签名密钥

在仓库 Settings → Secrets and variables → Actions 中配置:

| Secret 名称 | 值 |
|---|---|
| `SIGN_KEYSTORE_BASE64` | keystore 文件的 Base64,例如 `base64 -w0 your.jks` |
| `KEYSTORE_PASSWORD` | 生成 keystore 时的 store 密码 |
| `KEY_ALIAS` | 生成时使用的 alias |
| `KEY_PASSWORD` | key 密码,可与 store 相同 |

CI 会把 `SIGN_KEYSTORE_BASE64` 解码为 `android/app/upload-keystore.jks` 并生成 `android/key.properties`;`android/app/build.gradle.kts` 在检测到 `key.properties` 时启用发布签名,否则回退 debug 签名。`key.properties` 与 `*.jks` 已在 `.gitignore` 中,切勿提交。

生成 keystore:

```bash
keytool -genkey -v -keystore your.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your-key-alias
```

### 应用内更新

应用启动时会静默检查更新,设置页也可手动「检查更新」。检查逻辑会比对 GitHub 最新 Release;若存在新版本,应用会按当前平台和架构匹配 Release 资产并前往下载,匹配不到时打开 Releases 页面。

## 八、文档索引

- [docs/TASKS.md](docs/TASKS.md) —— 开发任务清单,包含模块位置、优先级和完成状态,**开发前必读**;
- [Sub2API 服务端 README](https://github.com/Wei-Shaw/sub2api) —— 服务端部署、配置、安全提示与接口生态说明;
- [frontend/src/api](https://github.com/Wei-Shaw/sub2api/tree/main/frontend/src/api) —— 上游 Web 前端 API 调用方式;
- [backend/internal/handler](https://github.com/Wei-Shaw/sub2api/tree/main/backend/internal/handler) —— 服务端接口实现。

## 九、许可证

本项目采用 [GNU Lesser General Public License v3.0 或更高版本](LICENSE) 许可。
