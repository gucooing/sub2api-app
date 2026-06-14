import '../../../../core/network/api_client.dart';

/// 管理端系统设置 API(原始字段映射,配合字段描述子做分类编辑)。
///
/// 后端 `GET/PUT /admin/settings` 字段众多;客户端按「大类 → 字段」分页编辑,
/// PUT 为部分更新(只提交某一类的字段,其余保持不变)。
class AdminSettingsApi {
  AdminSettingsApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> getRaw() async {
    final data = await _client.get<dynamic>('/admin/settings');
    return (data as Map).cast<String, dynamic>();
  }

  /// 部分更新:仅提交 [patch] 中的字段。
  Future<Map<String, dynamic>> update(Map<String, dynamic> patch) async {
    final data = await _client.put<dynamic>('/admin/settings', data: patch);
    return (data as Map).cast<String, dynamic>();
  }
}
