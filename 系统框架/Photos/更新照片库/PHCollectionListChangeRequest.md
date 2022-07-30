[toc]

# PHCollectionListChangeRequest

-   运用于照片库`performChanges`中，创建、删除、修改照片集合

-   在创建变更请求之前，使用`canPerform(_:)`方法来验证集合是否允许您所请求的编辑操作。如果尝试执行不支持的编辑操作，`Photos`将抛出异常。

-   调用`creationRequestForCollectionList(withTitle:)`方法来创建一个新的文件夹。

    调用`deleteCollectionLists(_:)`方法来删除现有的文件夹。

    调用`init(for:)`或`init(for:childCollections:)`方法来修改文件夹的元数据或其子集合列表。

## 属性

```swift
// 变更请求创建的资产的占位符对象
// 1. 可以使用-localIdentifier在变更块完成后获取新创建的资产
// 2. 它也可以直接添加到当前更改块中的集合中
@available(iOS 8, *)
open var placeholderForCreatedCollectionList: PHObjectPlaceholder { get }

// 集合列表名称
@available(iOS 8, *)
open var title: String
```

## 方法

-   初始化方法

```swift
// 如果集合列表不允许所请求的更改类型，这些方法将引发一个异常，在集合列表上调用canPerformEditOperation:来确定是否允许编辑操作的类型。
@available(iOS 8, *)
public convenience init?(for collectionList: PHCollectionList)

// 这个用来针对某个文件夹的，可以是顶级目录下文件夹，也可以是某个文件夹下的子文件夹
// 为了确保您指定的索引集是有效的，即使从获取集合列表以来已经发生了更改，在重新安排子集合之前，使用init(for:childCollections:)方法创建一个更改请求，其中包含集合列表内容的快照。
@available(iOS 8, *)
public convenience init?(for collectionList: PHCollectionList, childCollections: PHFetchResult<PHCollection>)

// 这个用来针对顶级目录下的文件夹
// 为了确保您指定的索引集是有效的，即使从获取集合列表以来已经发生了更改，在重新安排子集合之前，使用init(childCollections:)方法创建一个更改请求，其中包含“顶部创建”集合列表内容的快照。
@available(iOS 14.2, *)
public convenience init?(forTopLevelCollectionListUserCollections childCollections: PHFetchResult<PHCollection>)
```

-   管理集合列表

```swift
// 创建新的文件夹
@available(iOS 8, *)
open class func creationRequestForCollectionList(withTitle title: String) -> Self

// 删除指定的文件夹
// 删除集合列表也会删除其中包含的任何子集合。要保留这些集合，请在删除它们之前从集合列表中删除它们(使用removeChildCollections(_:)或removeChildCollections(at:)方法)。删除集合列表不会删除其子集合中包含的资产。
@available(iOS 8, *)
open class func deleteCollectionLists(_ collectionLists: NSFastEnumeration)
```

-   管理集合

```swift
// 添加指定的集合作为文件夹的子项
@available(iOS 8, *)
open func addChildCollections(_ collections: NSFastEnumeration)

// 将指定的集合添加到文件夹指定索引处
// 为了确保您指定的索引集是有效的，即使从获取集合列表以来已经发生了更改，在插入子集合之前，使用init(for:childCollections:)方法创建一个更改请求，其中包含集合列表内容的快照。
@available(iOS 8, *)
open func insertChildCollections(_ collections: NSFastEnumeration, at indexes: IndexSet)

// 从文件夹中删除指定的集合
@available(iOS 8, *)
open func removeChildCollections(_ collections: NSFastEnumeration)

// 从文件夹中删除指定索引处的集合
// 为了确保您指定的索引集是有效的，即使从获取集合列表以来已经发生了更改，在删除子集合之前，使用init(for:childCollections:)方法创建一个更改请求，其中包含集合列表内容的快照。要根据对象的标识(不考虑它们在集合中的索引)删除对象，请使用removeChildCollections(_:)方法。
@available(iOS 8, *)
open func removeChildCollections(at indexes: IndexSet)

// 用指定的集合替换文件夹中指定索引处集合
// 为了确保您指定的索引集是有效的，即使从获取集合列表以来已经发生了更改，在删除子集合之前，使用init(for:childCollections:)方法创建一个更改请求，其中包含集合列表内容的快照。要根据对象的标识(不考虑它们在集合中的索引)删除对象，请使用removeChildCollections(_:)方法。
@available(iOS 8, *)
open func replaceChildCollections(at indexes: IndexSet, withChildCollections collections: NSFastEnumeration)

// 将文件夹中指定索引处的集合移动到新的索引处
// 当调用此方法时，Photos首先从集合中删除索引参数中的项，然后将它们插入toIndex参数指定的位置。
// 为了确保您指定的索引集是有效的，即使从获取集合列表以来已经发生了更改，在重新安排子集合之前，使用init(for:childCollections:)方法创建一个更改请求，其中包含集合列表内容的快照。
@available(iOS 8, *)
open func moveChildCollections(at indexes: IndexSet, to toIndex: Int)
```

