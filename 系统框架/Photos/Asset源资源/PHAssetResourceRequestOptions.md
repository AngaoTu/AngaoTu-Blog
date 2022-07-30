[toc]

## PHAssetResourceRequestOptions

-   影响从`PHAssetResourceManager`请求的资产数据的交付

## 属性

```swift
// 指定照片是否可以从 iCloud 下载请求的资产资源数据
@available(iOS 9, *)
open var isNetworkAccessAllowed: Bool

// 从icloud下载图片时，会定期返回下载进度
@available(iOS 9, *)
open var progressHandler: PHAssetResourceProgressHandler?
```

