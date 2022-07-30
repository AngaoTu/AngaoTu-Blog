[toc]

# PHLivePhotoRequestOptions

-   一组影响从图像管理器请求的`LivePhoto`资产的选项。

## 属性

```swift
// 这里和PHImageRequestOptions采用相同的枚举
@available(iOS 8, *)
open var version: PHImageRequestOptionsVersion // 图片版本

@available(iOS 8, iOS 8, *)
public enum PHImageRequestOptionsVersion : Int {

    @available(iOS 8, *)
    case current = 0 // 请求图像资产的最新版本（包括所有编辑的版本）

    @available(iOS 8, *)
    case unadjusted = 1 // 原版，没有任何调整编辑

    @available(iOS 8, *)
    case original = 2 // 请求图像资产的原始、最高保真度版本。
}

 // 图片交付模式，默认是opportunistic
@available(iOS 8, *)
open var deliveryMode: PHImageRequestOptionsDeliveryMode

@available(iOS 8, iOS 8, *)
public enum PHImageRequestOptionsDeliveryMode : Int {

    @available(iOS 8, *)
    case opportunistic = 0 // 平衡图像质量和响应速度，可能会返回一个或者多个结果

    @available(iOS 8, *)
    case highQualityFormat = 1 // 只会返回最高质量图像

    @available(iOS 8, *)
    case fastFormat = 2 // 最快速度得到一个图像结果，可能会牺牲图像质量
}

// 是否可以从iCloud中下载图片，默认为false
@available(iOS 8, *)
open var isNetworkAccessAllowed: Bool

// 从icloud下载图片时，会定期返回下载进度
@available(iOS 8, *)
open var progressHandler: PHAssetImageProgressHandler? 
```

