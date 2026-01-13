import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// 权限管理助手
class PermissionHelper {
  /// 检查是否有存储权限
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) {
      return true; // iOS和其他平台不需要特殊权限
    }

    // Android 13+ (API 33+)
    if (Platform.isAndroid) {
      final androidInfo = await Permission.storage.status;
      if (androidInfo.isGranted) {
        return true;
      }

      // 对于 Android 11+，尝试请求管理所有文件权限
      if (await _isAndroid11OrAbove()) {
        return await Permission.manageExternalStorage.isGranted;
      }
    }

    return false;
  }

  /// 请求存储权限
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    // Android 11+ (API 30+)
    if (await _isAndroid11OrAbove()) {
      // 尝试请求管理所有文件权限
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        return true;
      }
    }

    // 回退到请求存储权限
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// 检查是否是 Android 11 或更高版本
  static Future<bool> _isAndroid11OrAbove() async {
    if (!Platform.isAndroid) return false;
    // 这里简化处理，实际应该检查 Android 版本
    // 对于 Flutter，我们可以通过尝试请求权限来判断
    return true; // 简化：假设是 Android 11+
  }
}
