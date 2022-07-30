[toc]

# PHLivePhoto

-   一种实况照片的可显示表示形式——包含捕捉前后瞬间的动作和声音的图片

-   `PHLivePhoto`类在`Live Photos`中的作用与`UIImage`在静态图像中的作用是一样的。`UIImage`对象表示的不是加载图像的数据文件，而是一个可以在视图中显示的现成的图像类似地，`PHLivePhoto`对象表示的是一个可以用`PHLivePhotoView`对象显示运动和声音的实时照片，而不是照片库中的条目或构成实时照片的数据资源。(使用`Live Photos`作为`Photos`库的元素，使用`PHAsset`类。要处理组成`Live Photo`的数据文件，请使用`PHAssetResource`类。)

## 属性

```swift
// 图片大小
@available(iOS 9.1, *)
open var size: CGSize { get }
```

## 方法

```swift
// 使用此方法可以用以前从Photos库导出的数据文件中加载Live Photo对象以显示
// 如果需要数据文件LivePhoto导入photos库中，可以使用PHAssetCreationRequest
@available(iOS 9.1, *)
open class func request(withResourceFileURLs fileURLs: [URL], placeholderImage image: UIImage?, targetSize: CGSize, contentMode: PHImageContentMode, resultHandler: @escaping (PHLivePhoto?, [AnyHashable : Any]) -> Void) -> PHLivePhotoRequestID

// 取消请求
@available(iOS 9.1, *)
open class func cancelRequest(withRequestID requestID: PHLivePhotoRequestID)
```

