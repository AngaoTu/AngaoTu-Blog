[toc]

# PHAssetResourceManager

-   `Photos`底层存储的数据的资源管理器。
-   一个`PHAsset`可以有多个底层数据资源(例如，原始和编辑的版本，每个都由一个`PHAssetResource`对象表示)。
-   `PHImageManager`类提供并将资产的主要表示形式缓存为缩略图、图像对象或视频对象，与此不同，`PHAssetResourceManager`提供对这些底层数据资源的直接访问。

## 方法

```swift
// 返回PHAssetResourceManager单例对象
@available(iOS 9, *)
open class func `default`() -> PHAssetResourceManager

// 请求指定资产资源的底层数据，以异步交付
// 处理程序是在任意串行队列上调用的。数据的生存期不能保证超过处理程序的生存期。
// 当您调用此方法时，Photos将开始异步地读取资产资源的基础数据。根据您指定的选项和资产的当前状态，照片可以从网络下载资产数据。
// 在读取(或下载)资产资源数据时，Photos至少调用一次处理程序块，逐步提供数据块。在读取所有数据之后，Photos调用completionHandler块来表示数据已经完成。(此时，资产的完整数据是所有调用到处理程序块的数据参数的连接。)如果照片不能完成读取或下载资产资源数据，它调用completionHandler块，并描述错误。如果用户取消下载，当数据完成时，照片也可以调用completionHandler块，并给出一个非nil错误。
@available(iOS 9, *)
open func requestData(for resource: PHAssetResource, options: PHAssetResourceRequestOptions?, dataReceivedHandler handler: @escaping (Data) -> Void, completionHandler: @escaping (Error?) -> Void) -> PHAssetResourceDataRequestID

// 请求指定资产资源的底层数据，以异步写入本地文件
@available(iOS 9, *)
open func writeData(for resource: PHAssetResource, toFile fileURL: URL, options: PHAssetResourceRequestOptions?, completionHandler: @escaping (Error?) -> Void)

// 请求指定资产资源的底层数据，以异步写入本地文件
@available(iOS 9, *)
open func writeData(for resource: PHAssetResource, toFile fileURL: URL, options: PHAssetResourceRequestOptions?) async throws

// 取消异步请求
@available(iOS 9, *)
open func cancelDataRequest(_ requestID: PHAssetResourceDataRequestID)
```

