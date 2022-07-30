[toc]

# PHImageManager

-   提供获取或生成预览缩略图的图片数据
-   加载图片或视频数据流程：
    1.   使用`PHAsset`类来获取你感兴趣的资产
    2.   调用`PHImageManager`的`default`方法来获取图像管理器对象
    3.   使用`requetImage`或者`requestVideo`相关方法来获取资产对应的数据

## 方法

-   获取结果中`infos`的`key`

```swift
// Result's handler info dictionary keys

// key (NSNumber): 其值指示照片资产数据是存储在本地设备上还是必须从 iCloud 下载
@available(iOS 8, *)
public let PHImageResultIsInCloudKey: String 

// key (NSNumber): 其值指示结果图像是否是所请求图像的低质量替代品
@available(iOS 8, *)
public let PHImageResultIsDegradedKey: String 

// key (NSNumber): 其值为图像请求的唯一标识符。
@available(iOS 8, *)
public let PHImageResultRequestIDKey: String 

// key (NSNumber): 其值指示图像请求是否被取消。
@available(iOS 8, *)
public let PHImageCancelledKey: String 

// key (NSError): 其值为照片尝试加载图像时发生的错误。
@available(iOS 8, *)
public let PHImageErrorKey: String
```

-   请求图片

```swift
// 通过PHAsset获取UIImage
/*
@param contentMode一个如何使图像适合于所请求大小的宽高比的选项。
    如果资源的宽高比不匹配给定的targetSize, contentMode决定如何调整图像的大小。
    PHImageContentModeAspectFit:通过保持宽高比来适应要求的大小，交付的图像不一定是要求的targetSize(见PHImageRequestOptionsDeliveryMode和PHImageRequestOptionsResizeMode)
    PHImageContentModeAspectFill:填充要求的大小，部分内容可能被剪切，交付的图像不一定是要求的targetSize(见PHImageRequestOptionsDeliveryMode和PHImageRequestOptionsResizeMode)
    PHImageContentModeDefault:当size为PHImageManagerMaximumSize时使用PHImageContentModeDefault(尽管不会对结果进行缩放/裁剪)\
@param options选项，指定照片应该如何处理请求，格式化请求的图像，并通知应用程序的进展或错误。
    如果-[PHImageRequestOptions isSynchronous]返回NO(或者options为nil)， resultHandler可能被调用1次或更多次。通常，在这种情况下，resultHandler将在主线程上与请求的结果异步调用。
			但是，如果deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic，如果有任何图像数据立即可用，则可能在调用线程上同步调用resultHandler。
			如果在第一次传递中返回的图像数据质量不足，则稍后将在主线程上以异步方式调用resultHandler，并返回“正确的”结果。如果请求被取消，则可能根本不会调用resultHandler。
    如果-[PHImageRequestOptions isSynchronous]返回YES，则resultHandler将在调用线程上被同步地调用一次。同步请求不能被取消。
    根据PHImageRequestOptions options参数中指定的选项，在当前线程上同步调用或在主线程上异步调用一次或多次的块。
*/
@available(iOS 8, *)
open func requestImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?, resultHandler: @escaping (UIImage?, [AnyHashable : Any]?) -> Void) -> PHImageRequestID

// 请求指定PHAsset的最大字节的图像和EXIF方向
/*
@param options选项，指定照片应该如何处理请求，格式化请求的图像，并通知应用程序的进展或错误。
		如果请求PHImageRequestOptionsVersionCurrent，并且资源进行了调整，则返回最大的渲染图像数据。在所有其他情况下，返回原始图像数据。
@param resultHandler一个块，根据PHImageRequestOptions选项参数中指定的同步选项(deliveryMode被忽略)，它在当前线程上被同步调用一次，在主线程上被异步调用一次。Orientation是作为CGImagePropertyOrientation的EXIF方向。对于iOS或tvOS，将其转换为UIImageOrientation。
*/
@available(iOS 13, *)
open func requestImageDataAndOrientation(for asset: PHAsset, options: PHImageRequestOptions?, resultHandler: @escaping (Data?, String?, CGImagePropertyOrientation, [AnyHashable : Any]?) -> Void) -> PHImageRequestID
```

-   请求视频

```swift
// 通过PHAsset获取AVPlayerItem
@available(iOS 8, *)
open func requestPlayerItem(forVideo asset: PHAsset, options: PHVideoRequestOptions?, resultHandler: @escaping (AVPlayerItem?, [AnyHashable : Any]?) -> Void) -> PHImageRequestID

// 通过PHAsset获取AVAssetExportSession
@available(iOS 8, *)
open func requestExportSession(forVideo asset: PHAsset, options: PHVideoRequestOptions?, exportPreset: String, resultHandler: @escaping (AVAssetExportSession?, [AnyHashable : Any]?) -> Void) -> PHImageRequestID

// 通过PHAsset获取AVAsset
@available(iOS 8, *)
open func requestAVAsset(forVideo asset: PHAsset, options: PHVideoRequestOptions?, resultHandler: @escaping (AVAsset?, AVAudioMix?, [AnyHashable : Any]?) -> Void) -> PHImageRequestID

/*
当你想要使用一个资源内容的音频和视频轨道工作请使用  requestAVAsset(forVideo asset: PHAsset, options: PHVideoRequestOptions?, resultHandler: @escaping (AVAsset?, AVAudioMix?, [AnyHashable : Any]?) -> Void) -> PHImageRequestID
如果你只想要播放资源，请使用requestPlayerItem(forVideo asset: PHAsset, options: PHVideoRequestOptions?, resultHandler: @escaping (AVPlayerItem?, [AnyHashable : Any]?) -> Void) -> PHImageRequestID
如果你想要导出资源数据，请调用requestExportSession(forVideo asset: PHAsset, options: PHVideoRequestOptions?, exportPreset: String, resultHandler: @escaping (AVAssetExportSession?, [AnyHashable : Any]?) -> Void) -> PHImageRequestID
*/
```

-   请求LivePhoto

```swift
// 请求资源的实时照片表示。使用PHImageRequestOptionsDeliveryModeOpportunistic(或者如果没有指定选项)，
// resultHandler块可以被调用多次(第一次调用可能发生在方法返回之前)。结果处理程序的info参数中的PHImageResultIsDegradedKey键指示何时提供了一个临时的低质量的实时照片。
         
// 通过PHAsset获取PHLivePhoto
@available(iOS 9.1, *)
open func requestLivePhoto(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, options: PHLivePhotoRequestOptions?, resultHandler: @escaping (PHLivePhoto?, [AnyHashable : Any]?) -> Void) -> PHImageRequestID
```

