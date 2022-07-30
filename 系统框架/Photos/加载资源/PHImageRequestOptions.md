[toc]

# PHImageReqeustOptions

-   一组影响从图片管理器中获取的照片资源的质量、大小等属性。

## 属性

```swift
// 图片版本
@available(iOS 8, *)
open var version: PHImageRequestOptionsVersion

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

// 请求图像的大小，默认为fast
@available(iOS 8, *)
open var resizeMode: PHImageRequestOptionsResizeMode

@available(iOS 8, iOS 8, *)
public enum PHImageRequestOptionsResizeMode : Int {
    @available(iOS 8, *)
    case none = 0 // 不做任何调整

    @available(iOS 8, *)
    case fast = 1 // 最快速的调整图像，有可能比给定大小略大

    @available(iOS 8, *)
    case exact = 2 // 与给定大小一致，如果使用normalizedCropRect属性，则必须指定为该模式。
}

// 是否对原图进行裁剪
// 如果你指定了裁剪的矩形，那么你必须对resizeMode属性设置为.exact
@available(iOS 8, *)
open var normalizedCropRect: CGRect

// 是否可以从iCloud中下载图片，默认为false
@available(iOS 8, *)
open var isNetworkAccessAllowed: Bool

// 是否同步请求照片，默认是NO
@available(iOS 8, *)
open var isSynchronous: Bool

// 从icloud下载图片是，会定期返回下载进度
@available(iOS 8, *)
open var progressHandler: PHAssetImageProgressHandler?
```

