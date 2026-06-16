# Sub2api 开发任务清单

> 状态图例:✅ 已完成 · 🚧 进行中 · ⬜ 未开始
> 优先级:**P0** 当前版本必须 · **P1** 第一个可用版本应有 · **P2** 后续增强
>
> **执行规约**(对人和智能体同样生效):
> 1. 动工前先读 `README.md` 第三节「项目框架」,代码必须落位到表中「模块位置」;
> 2. 文案一律 `context.tr()`,新增键同时更新 `assets/i18n/zh-CN.json` 与 `en-US.json`;
> 3. 每完成一个可运行的小功能:`flutter analyze` 0 告警 + `flutter test` 全绿 → 本地 `git commit`(中文提交信息);
> 4. 完成或开工时同步更新本表状态;
> 5. 上游 API 以 `D:\github\sub2api\frontend\src\api\*.ts` 为准,禁止凭空杜撰端点。

## 阶段 0 · 项目基建(已全部完成)

| 任务 | 模块位置 | 优先级 | 状态 |
|---|---|---|---|
| Flutter 五平台脚手架(Android/iOS/Windows/macOS/Linux) | 仓库根 | P0 | ✅ |
| 全平台应用显示名统一为 Sub2api | `android/ ios/ windows/ macos/ linux/` | P0 | ✅ |
| 官方 Logo 生成全平台启动图标(含 Android 自适应) | `assets/icon/` + `tool/prepare_icon.dart` | P0 | ✅ |
| 核心依赖引入(dio/riverpod/go_router/secure_storage/fl_chart) | `pubspec.yaml` | P0 | ✅ |
| 运行时语言包 i18n 系统(内置 zh-CN/en-US,默认跟随系统) | `lib/src/i18n/` + `assets/i18n/` | P0 | ✅ |
| 外置语言包热加载(免编译新增语言,模拟器实测) | `lib/src/i18n/language_pack_loader.dart` | P0 | ✅ |
| Material 3 品牌主题(明/暗)+ 主题切换持久化 | `lib/src/core/theme/` | P0 | ✅ |
| 设置页(主题/语言/语言包重载/关于) | `lib/src/features/settings/` | P0 | ✅ |
| 路由骨架 + 首页占位 | `lib/src/core/router/` + `features/home/` | P0 | ✅ |
| i18n 单元测试(解析/回退/插值) | `test/i18n_test.dart` | P0 | ✅ |
| Windows 下 Kotlin daemon 构建崩溃绕过(in-process) | `android/gradle.properties` | P0 | ✅ |
| 项目简介(框架定义)与任务清单文档 | `README.md` + `docs/TASKS.md` | P0 | ✅ |

## 里程碑 M1 · 网络与会话基础(P0,后续一切的前置)

| 任务 | 模块位置 | 优先级 | 状态 |
|---|---|---|---|
| ApiClient:dio 封装、BaseURL 注入、Bearer 鉴权拦截器、错误归一化(ApiException) | `lib/src/core/network/` | P0 | ✅ |
| SecureStore:令牌安全存取封装 | `lib/src/core/storage/secure_store.dart` | P0 | ✅ |
| 多后端 ServerProfile:模型、增删改查、当前选中(默认 `https://ai.alsl.xyz`) | `lib/src/core/server/` | P0 | ✅ |
| 会话控制器:登录态/当前用户/角色(user·admin),启动时恢复会话 | `lib/src/core/session/` | P0 | ✅ |
| 登录页:邮箱+密码、TOTP 两步验证、服务器选择入口 | `lib/src/features/auth/` | P0 | ✅ |
| 注册页(若后端开放注册)+ 忘记密码引导 | `lib/src/features/auth/` | P1 | ✅ |
| 登录后导航壳:用户端底部导航(总览/密钥/用量/我的),管理员显示管理入口 | `lib/src/features/shell/` | P0 | ✅ |
| 路由守卫:未登录跳登录页,已登录禁回登录页 | `lib/src/core/router/app_router.dart` | P0 | ✅ |

## 里程碑 M2 · 用户端「Pro 数据控制台」重做 + 功能补全

> 用户判定原 M2 设计不合理,要求从零重做为 Pro 数据控制台并补齐缺失功能。方案见 `.claude/plans/playful-roaming-acorn.md`,分阶段 P0–P9。

| 任务 | 模块位置 | 优先级 | 状态 |
|---|---|---|---|
| P0 共享组件库 + 主题 + 依赖(url_launcher/qr_flutter) | `lib/src/shared/widgets/` | P0 | ✅ |
| P1 总览重做:品牌 hero + KPI 磁贴 + 多线趋势 + 平台分布 + 快捷入口 | `lib/src/features/user/dashboard/` | P0 | ✅ |
| P2 密钥重做:卡片增信息 + 密钥详情页(日用量/窗口) | `lib/src/features/user/keys/` | P0 | ✅ |
| P3 用量重做:时间筛选 + 多线趋势 + 按模型表;使用记录多维筛选 + 记录详情 | `lib/src/features/user/usage/` `usage_logs/` | P0 | ✅ |
| P4 公告重做:列表卡 + 沉浸详情页(替代弹窗) | `lib/src/features/user/announcements/` | P1 | ✅ |
| P5 充值:套餐/金额 + 支付方式 + 二维码/跳转 + 核验 + 订单历史 | `lib/src/features/user/recharge/` | P1 | ✅ |
| P6 邀请返利:邀请码/链接(二维码)+ 额度卡 + 转入余额 + 被邀请人 | `lib/src/features/user/affiliate/` | P1 | ✅ |
| P7 可用渠道 + 渠道状态(可用率/延迟/时间轴/多窗口详情) | `lib/src/features/user/channels_view/` | P2 | ✅ |
| P8 导航整合:新模块入口接线 + 总览快捷入口 + 我的页账号入口 | `lib/src/features/shell/` `core/router/` | P1 | ✅ |
| P9 收尾:各模块 data 层单测 + 文档 + 模拟器验收 | `test/` `docs/` | P1 | ✅ |
| 订阅管理 / 兑换码 / 个人资料 / 绑定设置 / TOTP | `lib/src/features/user/{subscriptions,redeem,profile}/` | P1 | ✅ |
| **多账号(以账号为单位)**:账号存储/切换/登出/删除;登录页选/加服务器;登录条款 checkbox+modal | `lib/src/core/account/` `features/settings/accounts_screen.dart` `features/auth/` | P1 | ✅ |


## 里程碑 M3 · 管理端(P1)

| 任务                   | 模块位置 | 优先级 | 状态 |
|----------------------|---|---|---|
| 管理仪表盘:平台总览指标         | `lib/src/features/admin/dashboard/` | P1 | ⬜ |
| 上游账号池:列表/详情/启停/删除/创建 | `lib/src/features/admin/accounts/` | P1 | 🚧 |
| └ 账号编辑/新增 全功能对照 web(按 平台×类型 装配:凭据/模型限制(白名单·映射)/池模式/自定义错误码/配额控制(总日周+重置+通知)/高级配额(窗口·会话·RPM·TLS·掩码·缓存TTL·BaseURL)/OpenAI·Anthropic·Antigravity 平台开关/临时不可调度/拦截预热;Bedrock·ServiceAccount·upstream 凭据;OAuth 授权创建待做) | `features/admin/accounts/presentation/sections/` `data/account_{model_mapping,quota,platform_options}.dart` | P1 | ✅ |
| 用户管理:列表/搜索/余额调整/启停   | `lib/src/features/admin/users/` | P1 | ✅ |
| 分组管理:列表/启停/权重        | `lib/src/features/admin/groups/` | P1 | ✅ |
| 兑换码管理:批量生成/列表/作废     | `lib/src/features/admin/redeem/` | P1 | ✅ |
| 渠道监控:状态一览            | `lib/src/features/admin/monitor/` | P2 | ✅ |
| 优惠码、订阅计划、系统设置管理      | `lib/src/features/admin/…` | P2 | ⬜ |

## 里程碑 M4 · 体验与工程化(P2)

| 任务 | 模块位置 | 优先级 | 状态 |
|---|---|---|---|
| 通用组件沉淀:空态/错误重试/加载骨架/确认弹窗 | `lib/src/shared/widgets/` | P1 | ⬜ |
| 桌面端宽屏适配:侧边导航、双栏布局 | `lib/src/features/shell/` | P2 | ⬜ |
| 深链与桌面窗口尺寸记忆 | `core/router/` + 平台宿主 | P2 | ⬜ |
| CI:GitHub Actions(analyze + test + Android 构建) | `.github/workflows/` | P2 | ⬜ |
| 应用内更新检查(GitHub Releases) | `lib/src/core/` | P2 | ⬜ |
| 更多内置语言?(暂定不做,社区语言包覆盖) | `assets/i18n/` | P2 | ⬜ |

## 已知技术注意事项

- 本开发机无 VS C++ 工具链,**Windows 桌面构建不可用**,统一以 Android 模拟器验证(`flutter build apk --debug` + adb 安装);
- `android/gradle.properties` 中 `kotlin.compiler.execution.strategy=in-process` 与 `kotlin.incremental=false` 是对 Kotlin 2.3 daemon 在 Windows 上增量缓存崩溃的绕过,移除前需确认上游修复;
- 上游 Sub2API 的 Web 前端(Vue)是 API 行为的权威参考;移动端不实现 Turnstile 人机校验时,部分后端若强制开启会导致登录受限(届时在服务器配置中提示用户)。
