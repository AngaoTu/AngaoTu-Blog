[toc]

# PHVideoRequestOptions

-   一组影响从图像管理器请求的视频资产的选项。

## 属性

```swift
// 是否联网，从icloud获取图片
@available(iOS 8, *)
open var isNetworkAccessAllowed: Bool

// 获取视频版本
@available(iOS 8, *)
open var version: PHVideoRequestOptionsVersion

@available(iOS 8, iOS 8, *)
public enum PHVideoRequestOptionsVersion : Int {
    @available(iOS 8, *)
    case current = 0 // 当前版本，包括编辑内容

    @available(iOS 8, *)
    case original = 1 // 请求原版数据
}

// 视频交付模式
@available(iOS 8, *)
open var deliveryMode: PHVideoRequestOptionsDeliveryMode

@available(iOS 8, iOS 8, *)
public enum PHVideoRequestOptionsDeliveryMode : Int {

    @available(iOS 8, *)
    case automatic = 0 // 只在PHVideoRequestOptionsVersionCurrent下使用

    @available(iOS 8, *)
    case highQualityFormat = 1 // 只会返回最高质量图像

    @available(iOS 8, *)
    case mediumQualityFormat = 2 // 只会返回最中等质量图像(typ. 720p)

    @available(iOS 8, *)
    case fastFormat = 3 // 只会返回最低质量图像(typ. 360p MP4)
}

// 从icloud下载视频时，会定期返回下载进度
@available(iOS 8, *)
open var progressHandler: PHAssetVideoProgressHandler?
```

