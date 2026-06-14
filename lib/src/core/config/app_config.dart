/// 应用级常量与编译期配置。运行时可变的设置请走 prefs / 服务器配置。
class AppConfig {
  const AppConfig._();

  static const String appName = 'Sub2api';

  /// 默认后端服务器地址(用户可在登录/设置中切换为自建后端)。
  static const String defaultBaseUrl = 'https://ai.alsl.xyz';

  /// 仓库地址,关于页可展示。
  static const String repoUrl = 'https://github.com/gucooing/sub2api-app';

  /// 本 app 对齐开发的 Sub2API 后端版本(上游 `backend/cmd/server/VERSION`)。
  /// 后端升级后,据此版本号比对 Sub2API 的 git 记录即可快速跟进 app 适配。
  static const String compatibleBackendVersion = '0.1.136';

  /// 请求默认超时。
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
