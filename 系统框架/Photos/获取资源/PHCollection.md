[toc]

# PHCollection

- 照片资产集合或集合列表的抽象超类。
- 不直接创建或使用此类的实例。相反，使用它的两个具体子类
  - PHAssetCollection：一个对象表示照片或视频资产，如相册，那一刻，或共享照片流的集合。
  - PHCollectionList：一个对象表示一个包含其他集合的集合，例如包含相册的文件夹。

## 方法

```swift
// 返回集合是否支持指定的编辑操作
@available(iOS 8, *)
open func canPerform(_ anOperation: PHCollectionEditOperation) -> Bool

// 从指定的集合列表中检索集合
@available(iOS 8, *)
open class func fetchCollections(in collectionList: PHCollectionList, options: PHFetchOptions?) -> PHFetchResult<PHCollection>

// 获取用户创建的相册或文件夹
@available(iOS 8, *)
open class func fetchTopLevelUserCollections(with options: PHFetchOptions?) -> PHFetchResult<PHCollection>
```

## 属性

```swift
// 能否包含Assets
open var canContainAssets: Bool { get }

// 能否包含集合
open var canContainCollections: Bool { get }

// 标题
open var localizedTitle: String? { get }
```

