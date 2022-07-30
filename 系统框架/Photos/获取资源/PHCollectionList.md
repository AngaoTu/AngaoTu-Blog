[toc]

# PHCollectionList

-   包含照片资产集合的组，例如 Moments、Years 或用户创建的相册文件夹(如果不好理解，可以类比为二维数组)
-   在`Photos`框架中，集合对象（包括资产集合）不直接引用其成员对象，也没有其他对象直接引用集合对象。要检索集合列表的成员，请使用`PHCollection`类方法

## 方法

```swift
// 获取包含该PHCollection的资产集合
@available(iOS 8, *)
open class func fetchCollectionListsContaining(_ collection: PHCollection, options: PHFetchOptions?) -> PHFetchResult<PHCollectionList>

// 通过PHCollection的标识符，获取对应的资源集合
@available(iOS 8, *)
open class func fetchCollectionLists(withLocalIdentifiers identifiers: [String], options: PHFetchOptions?) -> PHFetchResult<PHCollectionList>

// 通过CollectionList的type和subtype来获取资源集合
@available(iOS 8, *)
open class func fetchCollectionLists(with collectionListType: PHCollectionListType, subtype: PHCollectionListSubtype, options: PHFetchOptions?) -> PHFetchResult<PHCollectionList>

// 通过PHCollections创建临时PHCollectionList集合
@available(iOS 8, *)
open class func transientCollectionList(with collections: [PHCollection], title: String?) -> PHCollectionList

// 通过PHFetchResult<PHCollection>创建临时PHCollectionList集合
@available(iOS 8, *)
open class func transientCollectionList(withCollectionsFetchResult fetchResult: PHFetchResult<PHCollection>, title: String?) -> PHCollectionList
```

## 属性

```swift
// 集合列表的type
@available(iOS 8, *)
open var collectionListType: PHCollectionListType { get }

@available(iOS 8, iOS 8, *)
public enum PHCollectionListType : Int {

    @available(iOS, introduced: 8, deprecated: 13, message: "Will be removed in a future release")
    case momentList = 1 // 包含了PHAssetCollectionTypeMoment类型的资源集合的列表

    @available(iOS 8, *)
    case folder = 2 // 包含了PHAssetCollectionTypeAlbum类型或PHAssetCollectionTypeSmartAlbum类型的资源集合的列表

    @available(iOS 8, *)
    case smartFolder = 3 // 同步到设备的智能文件夹的列表
}

// 集合列表的subType
@available(iOS 8, *)
open var collectionListSubtype: PHCollectionListSubtype { get }

@available(iOS 8, iOS 8, *)
public enum PHCollectionListSubtype : Int {
    // PHCollectionListTypeMomentList subtypes
    @available(iOS, introduced: 8, deprecated: 13, message: "Will be removed in a future release")
    case momentListCluster = 1 // 时刻
    @available(iOS, introduced: 8, deprecated: 13, message: "Will be removed in a future release")
    case momentListYear = 2 // 年度

    // PHCollectionListTypeFolder subtypes
    @available(iOS 8, *)
    case regularFolder = 100 // 包含了其他文件夹或者相薄的文件夹

    // PHCollectionListTypeSmartFolder subtypes
    @available(iOS 8, *)
    case smartFolderEvents = 200 // 包含了一个或多个从iPhone同步的事件的智能文件夹

    @available(iOS 8, *)
    case smartFolderFaces = 201 // 包含了一个或多个从iPhone同步的面孔（人物）的智能文件夹

    // Used for fetching if you don't care about the exact subtype
    @available(iOS 8, *)
    case any = 9223372036854775807 // 如果你不关心子类型是什
}

// 开始时间
@available(iOS 8, *)
open var startDate: Date? { get }

// 结束时间
@available(iOS 8, *)
open var endDate: Date? { get }

// 定位集合
@available(iOS 8, *)
open var localizedLocationNames: [String] { get }
```

