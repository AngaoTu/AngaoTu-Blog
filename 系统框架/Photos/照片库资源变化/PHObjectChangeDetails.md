[toc]

# PHObjectChangeDetails

-   资产或集合对象中发生的更改的描述
-   对于资产集合或集合列表，`PHObjectChangeDetails`对象仅描述集合属性的更改。如果您对集合成员关系的更改感兴趣，可以获取集合的内容，并使用`changeDetails(for:)`方法跟踪对获取结果的更改。

## 属性

```swift
// 反映其代表的资产或集合的原始状态的对象。
@available(iOS 8, *)
open var objectBeforeChanges: ObjectType { get }

// 反映其代表的资产或集合的当前状态的对象。
@available(iOS 8, *)
open var objectAfterChanges: ObjectType? { get }

// 一个布尔值，指示资产的照片或视频内容是否已更改
@available(iOS 8, *)
open var assetContentChanged: Bool { get }

// 一个布尔值，指示对象是否已从照片库中删除
@available(iOS 8, *)
open var objectWasDeleted: Bool { get }
```

