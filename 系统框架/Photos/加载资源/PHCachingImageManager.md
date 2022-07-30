[toc]

# PHCachingImageManager

-   对`Photos`的图片或视频**资源**提供了加载或生成预览缩略图和全尺寸图片的方法，针对预处理巨量的**资源**进行了优化。

-   如何使用缓存图片管理器：
    1.  创建一个`PHCachingImageManager`实例。（这一步取代了使用`PHImageManager`单例。）
    2.  使用`PHAsset`类方法来加载你需要的**资源**。
    3.  为这些**资源**准备图像，调用`func startCachingImages(for assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?)`方法，并传入你在之后单独获取某一个**资源**时要用的`targetSize`，`contentMode`和`options`。
    4.  当你需要单独获取某一个**资源**的图像时，调用`func requestImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?, resultHandler: @escaping (UIImage?, [AnyHashable : Any]?) -> Void) -> PHImageRequestID`方法，并且传入你之前预加载时使用的同样的参数。
    5.  如果你请求的图像已经准备好了，`PHCachingImageManager`会立刻返回这个图像。否则，**Photos**会准备这个图像并缓存以备下次使用。
-   注意点：虽然`PHCachingImageManager`继承于`PHImageManager`，可以调用父类的`default()`生成一个`PHImageManager`的单例，如果是子类`PHCachingImageManager`，调用该方法并调用子类方法会`crash`，原因：这个方法返回的是`PHImageManager`类别的实例，去调用子类的方法会查找不到，就会crash。解决办法：扩展`PHCachingImageManager`，重写`default()`方法，返回一个`PHCachingImageManager`单例。

## 方法

```swift
// 开始缓存指定PHAssets
/*
当你调用这个方法，Photos会开始在后台获取图像数据并生成缩略图。在之后的任何时间，你可以使用- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(PHImageRequestOptions *)options resultHandler:(void (^)(UIImage *result, NSDictionary *info))resultHandler;
方法来请求已经缓存的单个图片。如果Photos已经完成了缓存一组图片，这个方法会立刻提供已经缓存的图像。

Photos使用这个方法中你提供的targetSize、contentMode和options来缓存图片。如果你在之后请求图片时，例如，使用不同的targetSize调用这个方法，Photos都不会使用已经缓存的图片，而是获取或生成一个新的图片。
*/
@available(iOS 8, *)
open func startCachingImages(for assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?)

// 取消缓存指定PHAssets
/*
这个方法通过给定的options取消对给定的资源的图片缓存。当不再需要这些图片缓存的时候使用这个方法来取消缓存（有可能正在缓存过程中）。
*/
@available(iOS 8, *)
open func stopCachingImages(for assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?)

// 取消当前缓存的所有图片
@available(iOS 8, *)
open func stopCachingImagesForAllAssets()
```

## 属性

```swift
// 是否缓存高质量照片，默认false
// 官方库注释：Defaults to YES，但是经过我测试默认值为false
/*
如果设置为true，图像管理器将会准备高质量的图像。这个选项将在高性能成本下提供更好的图像。
想要在准备大量的图像的时候有更快更好的性能——比如说用户快速的滑动缩略图集合视图的时候——设置这个属性为false。
*/

@available(iOS 8, *)
open var allowsCachingHighQualityImages: Bool // Defaults to false
```

