[toc]

# PHAssetResource

-   照片库中的照片、视频或`Live photo` `PHAsset`相关联的底层数据资源。
-   每个PHAsset对象引用一个或多个资源。使用这些对象直接处理这些资源，比如在备份或恢复资产时。
    -   照片资产可以同时包含表示同一张照片的`JPEG`和`RAW`文件。
    -   `Live Photo`资产包含静态照片和视频资源。
    -   已编辑的资产包含表示编辑前后资产内容的资源，以及与描述编辑的`PHAdjustmentData`对象对应的资源。
-   要处理`PHAssetResource`中包含的数据，请使用`PHAssetResourceManager`类获取它。

## 属性

```swift
// 此assetResource与其拥有PHAsset的关系
@available(iOS 9, *)
open var type: PHAssetResourceType { get }

@available(iOS 9, iOS 8, *)
public enum PHAssetResourceType : Int {
    @available(iOS 8, *)
    case photo = 1 // 为其PHAsset提供原始照片数据

    @available(iOS 8, *)
    case video = 2 // 为其PHAsset提供原始视频数据

    @available(iOS 8, *)
    case audio = 3 // 为其PHAsset提供原始音频数据

    @available(iOS 8, *)
    case alternatePhoto = 4 // 提供不是其PHAsset主要形式的照片数据

    @available(iOS 8, *)
    case fullSizePhoto = 5 // 提供原始照片PHAsset的修改版本

    @available(iOS 8, *)
    case fullSizeVideo = 6 // 提供原始视频PHAsset的修改版本

    @available(iOS 8, *)
    case adjustmentData = 7 // 提供数据以用于重建对其PHAsset的最近编辑

    @available(iOS 8, *)
    case adjustmentBasePhoto = 8 // 提供其照片PHAsset的未更改版本，用于重建最近的编辑

    @available(iOS 9.1, *)
    case pairedVideo = 9 // 提供LivePhoto的原始视频数据组件

    @available(iOS 10, *)
    case fullSizePairedVideo = 10 // 提供LivePhoto照片资产的当前视频数据组件

    @available(iOS 10, *)
    case adjustmentBasePairedVideo = 11 // 提供其视频PHAsset的未更改版本

    @available(iOS 13, *)
    case adjustmentBaseVideo = 12 // 为LivePhoto提供未更改的视频数据版本，用于重建最近的编辑
}

// 此assetResource关联的PHAsset对应的唯一标识符(PHAsset.localIdentifier)
@available(iOS 9, *)
open var assetLocalIdentifier: String { get }

// assetResource图片或视频数据的统一类型标识符
// https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/understanding_utis/understand_utis_conc/understand_utis_conc.html#//apple_ref/doc/uid/TP40001319-CH202-SW1
@available(iOS 9, *)
open var uniformTypeIdentifier: String { get }

// assetResource在创建时导入的原始名称
@available(iOS 9, *)
open var originalFilename: String { get }
```

## 方法

```swift
// 返回与PHAsset关联的asset资源列表
@available(iOS 9, *)
open class func assetResources(for asset: PHAsset) -> [PHAssetResource]

// 返回与PHLivePhoto关联的livePhoto资源列表
@available(iOS 9.1, *)
open class func assetResources(for livePhoto: PHLivePhoto) -> [PHAssetResource]
```

