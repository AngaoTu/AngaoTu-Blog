[toc]

# PHAssetCollectionChangeRequest

-   运用于照片库`performChanges`中，创建、删除、修改照片集合
-   在创建变更请求之前，使用`canPerform(_:)`方法来验证集合是否允许您所请求的编辑操作。如果尝试执行不支持的编辑操作，`Photos`将抛出异常。

## 属性

```swift
// 变更请求创建的资产的占位符对象
// 1. 可以使用-localIdentifier在变更块完成后获取新创建的资产
// 2. 它也可以直接添加到当前更改块中的集合中
@available(iOS 8, *)
open var placeholderForCreatedAssetCollection: PHObjectPlaceholder { get }

// 资产集合的名称
@available(iOS 8, *)
open var title: String
```

## 方法

-   初始化方法

```swift
// 如果资产集合不允许所请求的变更类型，这些方法将引发一个异常，调用canPerformEditOperation:对资产集合来确定是否允许编辑操作的类型。
@available(iOS 8, *)
public convenience init?(for assetCollection: PHAssetCollection)

// 为了确保您指定的索引集是有效的，即使从获取集合列表以来已经发生了更改，在重新安排子集合之前，使用init(for:assets:)方法创建一个更改请求，其中包含集合列表内容的快照。
@available(iOS 8, *)
public convenience init?(for assetCollection: PHAssetCollection, assets: PHFetchResult<PHAsset>)
```

-   管理资产集合

```swift
// 创建新的集合
@available(iOS 8, *)
open class func creationRequestForAssetCollection(withTitle title: String) -> Self

// 删除指定集合
@available(iOS 8, *)
open class func deleteAssetCollections(_ assetCollections: NSFastEnumeration)
```

-   管理资产

```swift
// 将指定资产添加到集合中
@available(iOS 8, *)
open func addAssets(_ assets: NSFastEnumeration)

// 将指定的资产插入到指定索引处的集合中
@available(iOS 8, *)
open func insertAssets(_ assets: NSFastEnumeration, at indexes: IndexSet)

// 从集合中移除指定的资产
@available(iOS 8, *)
open func removeAssets(_ assets: NSFastEnumeration)

// 从集合中删除指定索引处的资产
@available(iOS 8, *)
open func removeAssets(at indexes: IndexSet)

// 用指定的资产替换集合中指定索引处的资产
@available(iOS 8, *)
open func replaceAssets(at indexes: IndexSet, withAssets assets: NSFastEnumeration)

// 将集合中指定索引处的资产移动到新索引
@available(iOS 8, *)
open func moveAssets(at fromIndexes: IndexSet, to toIndex: Int)
```

