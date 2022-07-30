[toc]

# PHAssetCreationRequest

-   请求通过`PHAssetResource`创建一个新的`Photos`资产(照片库`performChanges`中执行)。
-   在照片库`performChanges`中使用的`PHAssetCreationRequest`对象从数据资源中构造一个新的照片或视频资产，并将其添加到照片库中。这个类以原始数据资源的方式工作，这些原始数据资源共同构成一个资产，因此您可以将它与`PHAssetResource`类一起使用，以执行资产底层资源的完整复制(或备份和恢复)。
-   要想简单地从图像对象、图像文件或视频文件创建一个新的资产，可以通过`PHAssetChangeRequest`。
-   使用方式：
    -   在`performChanges`中，使用`forAsset()`方法创建一个新的资产创建请求。
    -   使用为新资产提供`AssetResource`列出的方法添加图像、视频或数据资源
-   在`Photos`运行更改块并调用完成处理程序后，新的资产将在`Photos`库中创建。
-   如果你在照片库更改块之外实例化或使用这个类，`Photos`会抛出一个异常。



-   `PHAssetChangeRequest`和`PHAssetCreationRequest`区别

如果有图片的数据(Data 或 NSData)，可以用`Photos`的方法保存到相册。

1.   从 iOS 9 开始，可以使用 `PHAssetCreationRequest` 的方法

```swift
func addResource(with type: PHAssetResourceType, data: Data, options: PHAssetResourceCreationOptions?)
```

2.   iOS 8 比较麻烦，需要把数据写入临时文件，用临时文件的 `URL` 作为参数，调用 `PHAssetChangeRequest` 的类方法

```swift
class func creationRequestForAssetFromImage(atFileURL fileURL: URL) -> Self?
```

## 方法

```swift
 // 创建通过assetResource向照片库添加新资产的请求
@available(iOS 9, *)
open class func forAsset() -> Self

// 表示photos是否支持使用指定的资源类型组合创建asset
// 当你请求从resourceData中创建一个PHAsset时，照片不会验证资源是否可以构建一个完整的PHAsset，直到完整的PHPhotoLibrary performChanges(_:completionHandler:)更改块执行。(如果一个资产不能从提供的资源构建，照片调用completionHandler你在该方法中提供的错误描述失败。)若要在执行资产创建请求之前执行预验证，请使用此方法验证您希望从中创建PHAsset的资源类型集是否正确。
// 此方法只验证资产资源类型的集合是否有效(例如，确保您不会尝试在没有图像数据的情况下构造照片资产)，因此如果数据本身不完整或无效，资产创建请求仍然可能失败。然而，通过使用此方法调用，您可以在执行读取(并可能下载或传输)资产资源数据的昂贵操作之前避免某些类型的资产创建失败。
@available(iOS 9, *)
open class func supportsAssetResourceTypes(_ types: [NSNumber]) -> Bool

// 使用指定的数据向正在创建的PHAsset添加数据资源
@available(iOS 9, *)
open func addResource(with type: PHAssetResourceType, fileURL: URL, options: PHAssetResourceCreationOptions?)

// 使用位于指定URL的文件将数据资源添加到正在创建的PHAsset
@available(iOS 9, *)
open func addResource(with type: PHAssetResourceType, data: Data, options: PHAssetResourceCreationOptions?)
```

