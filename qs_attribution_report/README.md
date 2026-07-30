# qs_attribution_report

归因数据上报 Flutter 插件，支持 Android Adjust 归因信息上报、iOS 归因信息上报，并内置失败后的后台退避补报能力。

## 功能

- Android 归因数据上报
- iOS 归因数据上报
- 自动补充 App 版本、设备类型、设备型号、系统版本、IP 位置信息等设备上下文
- 请求参数 AES 加密后上报
- 网络失败或服务端返回失败时，自动保存密文请求并在后台退避重试
- App 重启后可主动唤醒历史失败队列继续补报

## 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  qs_attribution_report: ^1.0.0
```

然后执行：

```bash
flutter pub get
```

## 导入

```dart
import 'package:qs_attribution_report/qs_attribution_report.dart';
```

## App 启动时恢复失败补报

建议在 App 启动后调用一次，用于恢复上一次进程中未完成的失败归因补报。

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  QsAttributionReport.retryFailedAttributionReports();

  runApp(const MyApp());
}
```

`retryFailedAttributionReports()` 只会唤醒后台补报任务，不会等待队列全部完成，也不会阻塞启动流程。同一进程内多次调用不会启动多个并发补报循环。

## Android 归因上报

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
  // 首次上报失败；如果是网络或服务端失败，插件会自动加入后台补报队列
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

## iOS 归因上报

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
  attributionToken: "ios_attribution_token",
  attribution: {
    "campaignId": "campaign_id",
    "adGroupId": "ad_group_id",
  },
);

if (success) {
  // 首次上报成功
} else {
  // 首次上报失败；如果是网络或服务端失败，插件会自动加入后台补报队列
}
```

### iOS 参数说明

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `apiUrl` | `String` | iOS 归因上报接口地址 |
| `aesSecretKey` | `String` | AES 加密密钥 |
| `aesIv` | `String` | AES 加密 IV |
| `aesSctToken` | `String` | 请求头 `sct` token |
| `userId` | `String` | 用户 ID |
| `fcmId` | `String` | 推送 ID |
| `locale` | `String` | 用户语言环境，例如 `en_US`、`zh_CN` |
| `pushState` | `bool` | 推送开关状态 |
| `attributionToken` | `String` | iOS 归因 token |
| `attribution` | `Map<String, dynamic>` | iOS 归因明细数据 |

## 请求格式

插件会先组装归因参数，再使用 AES 加密完整 JSON 内容，最终发送到 `apiUrl`：

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

当服务端返回 `code == 0` 时，插件认为上报成功；其他返回或请求异常都会视为可重试失败。

## 失败补报机制

- 首次上报成功：直接返回 `true`，不会写入失败队列。
- 首次上报失败：返回 `false`，并把已加密的 `data`、`apiUrl`、`sct` 写入本地失败队列。
- JSON 编码失败或 AES 加密失败：返回 `false`，不会进入失败队列。
- 后台补报成功：自动移除对应失败记录。
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

失败队列只持久化已加密内容，不保存明文归因参数、AES key 或 AES IV。

## 注意事项

- 请确保 `apiUrl`、`aesSecretKey`、`aesIv`、`aesSctToken` 与服务端配置一致。
- 插件会通过 IP 获取位置信息；获取失败时会使用空字符串继续上报，不会中断主流程。
- `jsonResponse` 不是合法 JSON 时，Android 上报中的 `raw` 字段会被置为 `null`，上报流程仍会继续。
- 后台补报依赖当前 App 进程存活；App 重启后需要再次调用 `retryFailedAttributionReports()` 唤醒历史队列。
