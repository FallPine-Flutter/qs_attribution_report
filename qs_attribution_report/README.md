# qs_attribution_report

归因数据上报 Flutter 插件，支持 Android Adjust 归因信息上报、iOS Apple Search Ads 归因信息上报，并内置失败后的内存后台退避补报能力。

## 功能

- Android Adjust 归因数据上报
- iOS Apple Search Ads 归因数据上报，内部自动获取 attribution token 和归因明细
- 自动补充 App 版本、设备类型、设备型号、系统版本、IP 位置信息等设备上下文
- 请求参数 AES 加密后上报
- 网络失败、服务端返回失败或 iOS ASA 归因明细获取失败时，自动在内存中保存任务并在后台退避重试
- 上报成功后记录成功标记，后续重复调用会直接返回 `true`

## 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  qs_attribution_report: ^1.0.1
```

然后执行：

```bash
flutter pub get
```

## 导入

```dart
import 'package:qs_attribution_report/qs_attribution_report.dart';
```

## Android Adjust 归因上报

```dart
final success = await QsAttributionReport.reportAndroidAttributionInfo(
  apiUrl: "https://example.com/attribution/android",
  aesSecretKey: "your_aes_secret_key",
  aesIv: "your_aes_iv",
  aesSctToken: "your_sct_token",
  userId: "user_id",
  packageName: "com.example.app",
  adjustAdid: "adjust_adid",
  trackerToken: "tracker_token",
  trackerName: "tracker_name",
  network: "network",
  campaign: "campaign",
  adgroup: "adgroup",
  creative: "creative",
  clickLabel: "click_label",
  costType: "cost_type",
  costAmount: 1.23,
  costCurrency: "USD",
  jsonResponse: '{"key":"value"}',
);

if (success) {
  // 首次上报成功
} else {
  // 首次上报失败；如果是网络或服务端失败，插件会自动加入内存后台补报队列
}
```

### Android 参数说明

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `apiUrl` | `String` | Android 归因上报接口地址 |
| `aesSecretKey` | `String` | AES 加密密钥 |
| `aesIv` | `String` | AES 加密 IV |
| `aesSctToken` | `String` | 请求头 `sct` token |
| `userId` | `String` | 用户 ID |
| `packageName` | `String` | 应用包名 |
| `adjustAdid` | `String` | Adjust ADID |
| `trackerToken` | `String?` | Adjust tracker token |
| `trackerName` | `String?` | Adjust tracker name |
| `network` | `String?` | 广告网络 |
| `campaign` | `String?` | 广告 campaign |
| `adgroup` | `String?` | 广告 adgroup |
| `creative` | `String?` | 广告 creative |
| `clickLabel` | `String?` | 点击标签 |
| `costType` | `String?` | 成本类型 |
| `costAmount` | `num?` | 成本金额 |
| `costCurrency` | `String?` | 成本币种 |
| `jsonResponse` | `String?` | 原始归因 JSON 字符串，插件会解析后放入 `raw` 字段 |

## iOS Apple Search Ads 归因上报

```dart
final success = await QsAttributionReport.reportIOSAttributionInfo(
  apiUrl: "https://example.com/attribution/ios",
  aesSecretKey: "your_aes_secret_key",
  aesIv: "your_aes_iv",
  aesSctToken: "your_sct_token",
  userId: "user_id",
  fcmId: "fcm_id",
  locale: "en_US",
  pushState: true,
);

if (success) {
  // 获取到非空 ASA 归因明细，并且上传成功
} else {
  // ASA 归因明细获取失败、网络失败或服务端失败，插件会自动加入内存后台补报队列
}
```

插件会内部通过 `qs_asa_attribution_info` 获取 Apple Search Ads 的 attribution token 和归因明细，调用方不需要再传入 `attributionToken` 或 `attribution`。

iOS 上报成功条件：

- `attribution` 必须不为 `null` 且不为空 Map。
- `attributionToken` 可以为空；为空时会按空字符串继续上传。
- 服务端返回 `code == 0`。

### iOS 参数说明

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `apiUrl` | `String` | iOS ASA 归因上报接口地址 |
| `aesSecretKey` | `String` | AES 加密密钥 |
| `aesIv` | `String` | AES 加密 IV |
| `aesSctToken` | `String` | 请求头 `sct` token |
| `userId` | `String` | 用户 ID |
| `fcmId` | `String` | 推送 ID |
| `locale` | `String` | 用户语言环境，例如 `en_US`、`zh_CN` |
| `pushState` | `bool` | 推送开关状态 |

## 请求格式

插件会先组装归因参数，再使用 AES 加密完整 JSON 内容，最终发送到 `apiUrl`。

请求 body：

```json
{
  "data": "encrypted_json_content"
}
```

请求头会携带：

```json
{
  "sct": "your_sct_token"
}
```

当服务端返回 `code == 0` 时，插件认为上传成功；其他返回或请求异常都会视为可重试失败。

## 失败补报机制

- 首次上报成功：记录成功标记并返回 `true`，不会写入失败队列。
- 已经成功上报过：直接返回 `true`，不会再次组装或上传数据。
- 首次上报失败：返回 `false`，并把已加密请求或 iOS ASA 补报配置写入当前进程内存失败队列。
- iOS ASA 归因明细为空：不执行加密上传，保存本次 iOS 上报配置，后续补报时重新获取 ASA 数据。
- JSON 编码失败或 AES 加密失败：返回 `false`，不会进入失败队列。
- 后台补报成功：记录已上传标记，并清空当前进程内存失败队列。
- 后台补报再次失败：更新失败次数和下一次重试时间。

退避间隔：

| 失败次数 | 下一次重试间隔 |
| --- | --- |
| 1 | 2 秒 |
| 2 | 5 秒 |
| 3 | 10 秒 |
| 4 | 20 秒 |
| 5 | 40 秒 |
| 6 及以上 | 60 秒 |

失败队列只保存在当前进程内存中。网络或服务端失败时只保存已加密内容；iOS ASA 归因明细获取失败时会保存本次补报所需配置，用于后续重新获取 ASA 数据。App 重启后队列会清空，业务再次调用上报方法即可重新触发上报。

成功标记会通过 `qs_storage_tool` 持久化保存；如果业务需要重新上报，需要自行清理对应业务状态或调整调用时机。

## 注意事项

- 请确保 `apiUrl`、`aesSecretKey`、`aesIv`、`aesSctToken` 与服务端配置一致。
- 插件会通过 IP 获取位置信息；获取失败时会使用空字符串继续上报，不会中断主流程。
- iOS 会通过 `qs_asa_attribution_info` 访问 Apple AdServices Attribution API，请确保业务 App 的 iOS 环境满足 Apple Search Ads 归因获取要求。
- `jsonResponse` 不是合法 JSON 时，Android 上报中的 `raw` 字段会被置为 `null`，上报流程仍会继续。
- 后台补报依赖当前 App 进程存活；App 重启后不会恢复历史失败队列，用户再次调用上报方法时会重新触发上报。
