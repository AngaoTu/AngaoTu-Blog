[toc]

# PHFetchResultChangeDetails

-   对提取结果中列出的资产或集合对象集中发生的更改的描述

-   change details对象提供了用于更新列出获取结果内容的UI的有用信息，例如添加、删除和重新排列对象的索引。

## 方法

```swift
// 为每个对象在获取结果中从一个索引移动到另一个索引的情况运行指定的块
// 在应用removedIndexes和insertedindex之后，相对于获取结果的'before'状态，枚举移动项的索引
@available(iOS 8, *)
open func enumerateMoves(_ handler: @escaping (Int, Int) -> Void)
```

## 属性

```swift
// 原始获取结果，最近没有更改
@available(iOS 8, *)
open var fetchResultBeforeChanges: PHFetchResult<ObjectType> { get }

// 当前获取结果，包含最近的更改
@available(iOS 8, *)
open var fetchResultAfterChanges: PHFetchResult<ObjectType> { get }

// 一个布尔值，指示是否可以增量描述对获取结果的更改
// 如果该值为true，则使用insertedindex、removedIndexes和changedIndexes属性(或insertedObjects、removedObjects和changedObjects属性)来查找获取结果中添加、删除或更新了哪些对象。你也可以使用hasMoves属性和enumerateMoves(_:)方法来找出取回结果中哪些对象被重新安排了。这些属性对于更新集合视图或显示获取结果内容的类似界面非常有用。
// 如果该值为false，则获取结果与原始状态差别太大，增量更改信息没有意义。使用fetchResultAfterChanges属性获取获取结果的当前成员。(如果显示获取结果的内容，请重新加载用户界面以匹配新的获取结果。)
@available(iOS 8, *)
open var hasIncrementalChanges: Bool { get }

// 已删除对象的索引
// 对应与取回结果 befor状态，如果hasIncrementalChanges为false则返回nil
@available(iOS 8, *)
open var removedIndexes: IndexSet? { get }

// 已删除的对象
// 如果hasIncrementalChanges为false则返回nil
@available(iOS 8, *)
open var removedObjects: [ObjectType] { get }

// 插入对象的索引
// 对于应用removedIndexes后的fetch结果的'before'状态，如果hasIncrementalChanges为false则返回nil
@available(iOS 8, *)
open var insertedIndexes: IndexSet? { get }

// 插入的对象
// 如果hasIncrementalChanges为false则返回nil
@available(iOS 8, *)
open var insertedObjects: [ObjectType] { get }

// 获取结果中内容或元数据已更新的对象的索引
// 相对于获取结果的'after'状态, 如果hasIncrementalChanges为false则返回nil
@available(iOS 8, *)
open var changedIndexes: IndexSet? { get }

// 获取结果中内容或元数据已更新的对象
// 如果hasIncrementalChanges为false则返回nil
@available(iOS 8, *)
open var changedObjects: [ObjectType] { get }

// 一个布尔值，表示对象是否已在提取结果中重新排列。
// 如果hasIncrementalChanges为false则返回nil
// 如果该值为true，则使用enumerateMoves(_:)方法来找出哪些元素被移动了，以及它们的新索引是什么。
@available(iOS 8, *)
open var hasMoves: Bool { get }
```

