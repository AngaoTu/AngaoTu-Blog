[toc]

## PHAssetResourceCreationOptions

-   影响通过`PHAssetResource`创建`Photos`中新的`PHAsset`一组选项。
-   当你使用`PHAssetCreationRequest`对象创建一个`PHAsset`添加到`Photos`库中时，你可以使用这个类。

## 属性

```swift
// 正在创建的资产资源的文件名
// 如果你没有为这个属性指定一个值，并且使用addResource(使用:fileURL:options:)方法来创建一个资源，Photos会从该方法的fileURL参数中推断文件名。否则，照片会自动生成一个文件名。
// 即使您使用addResource(使用:data:options:)方法从数据而不是从文件创建资源。在创建资产之后，这个信息在相应的PHAssetResource对象的originalFilename属性中可用
@available(iOS 9, *)
open var originalFilename: String?

// 资源的统一类型标识符
// 如果您没有为这个属性指定一个值，当您将资源添加到创建请求时，Photos会从您指定的PHAssetResourceType值推断出数据类型。
@available(iOS 9, *)
open var uniformTypeIdentifier: String?

// 用于确定在创建assetResource时 Photos 是移动还是复制文件
// 此属性仅适用于使用addResource(使用:fileURL:options:)方法创建资产资源时。如果该值为true, Photos将指定的文件移动到Photos库中以创建资产资源，在成功创建资产后删除原始文件。当使用此选项时，Photos不会对资源数据进行中间拷贝，因此不需要额外的存储空间。如果该值为false(默认值)，Photos将原始文件的内容复制到Photos库中。
@available(iOS 9, *)
open var shouldMoveFile: Bool
```

