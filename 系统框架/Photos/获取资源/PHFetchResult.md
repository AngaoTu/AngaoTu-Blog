[toc]

# PHFetchResult

-   通过检索方法返回的资产或集合的有序结果(可以把这个类类比为数组)。
-   获取的对象将保存在缓存中，直到内存压力下清除。

## 方法

```swift
// 使用获取结果中的每个对象执行指定的块。
@available(iOS 8, *)
open func object(at index: Int) -> ObjectType // 获取第几个元素 超出该相册数量范围，则直接崩溃

// 判断是否包含某个元素
@available(iOS 8, *)
open func contains(_ anObject: ObjectType) -> Bool 

// 返回某个元素下标
@available(iOS 8, *)
open func index(of anObject: ObjectType) -> Int

// 在某个范围中，返回某个元素下标
@available(iOS 8, *)
open func index(of anObject: ObjectType, in range: NSRange) -> Int

// 返回一个数组，其中包含指定索引集中索引处的提取结果中的对象。
@available(iOS 8, *)
open func objects(at indexes: IndexSet) -> [ObjectType]

// 使用获取结果中的每个对象执行指定的块，从第一个对象开始并继续到最后一个对象。
@available(iOS 8, *)
open func enumerateObjects(_ block: @escaping (ObjectType, Int, UnsafeMutablePointer<ObjCBool>) -> Void)

// 使用获取结果中的每个对象执行指定的块。
@available(iOS 8, *)
open func enumerateObjects(options opts: NSEnumerationOptions = [], using block: @escaping (ObjectType, Int, UnsafeMutablePointer<ObjCBool>) -> Void)

public struct NSEnumerationOptions : OptionSet {
    public init(rawValue: UInt)

    public static var concurrent: NSEnumerationOptions { get } // 并行遍历

    public static var reverse: NSEnumerationOptions { get } // 倒叙遍历
}

// 使用指定索引处获取结果中的对象执行指定块。
@available(iOS 8, *)
open func enumerateObjects(at s: IndexSet, options opts: NSEnumerationOptions = [], using block: @escaping (ObjectType, Int, UnsafeMutablePointer<ObjCBool>) -> Void)

// 获取mediaType类型有多少元素
@available(iOS 8, *)
open func countOfAssets(with mediaType: PHAssetMediaType) -> Int 
```

## 属性

```swift
// 获取结果中的对象数
@available(iOS 8, *)
open var count: Int { get }

// 获取结果中第一个对象
@available(iOS 8, *)
open var firstObject: ObjectType? { get }

// 获取结果中最后一个对象
@available(iOS 8, *)
open var lastObject: ObjectType? { get }
```

