[toc]

# PHFetchOptions

-   通过一些字段来影响(过滤方式、排序方式等)获取资源的结果

## 属性

-   谓词与排序描述符

Photos中仅支持下表中谓词和排序key

| 类                | 支持的keys                                                   |
| ----------------- | ------------------------------------------------------------ |
| PHAsset           | SELF,localIdentifier,creationDate,modificationDate,mediaType,mediaSubtypes,duration,<br />pixelWidth,pixelHeight,isFavorite,isHidden,burstIdentifier |
| PHAssetCollection | SELF,localIdentifier,localizedTitle,startDtae,endDate,estimatedaAssetCount |
| PHCollectionList  | SELF,localIdentifier,localizedTitle,startDtae,endDate        |
| PHCollection      | SELF,localIdentifier,localizedTitle,startDtae,endDate        |

```swift
// 谓词
@available(iOS 8, *)
open var predicate: NSPredicate?

// 通过指定字段来进行排序
@available(iOS 8, *)
open var sortDescriptors: [NSSortDescriptor]?
```

-   其他

```swift
// 是否包含隐藏图片，默认是不包含
@available(iOS 8, *)
open var includeHiddenAssets: Bool

// 是否包含连拍资源，默认是不包含
@available(iOS 8, *)
open var includeAllBurstAssets: Bool

// 获取的资源类型，默认是所有类型
@available(iOS 9, *)
open var includeAssetSourceTypes: PHAssetSourceType

// 搜索结果数量限制，默认为0 没有限制
@available(iOS 9, *)
open var fetchLimit: Int

// 用于确定app是否接收到了具体的改变信息，默认为true
@available(iOS 8, *)
open var wantsIncrementalChangeDetails: Bool
```

