[toc]

# PHAssetCollection

-   照片资源分组的表示，例如用户创建的相册或智能相册
-   在`Photos`框架中，集合对象（包括资产集合）不直接引用其成员对象，也没有其他对象直接引用集合对象。要检索资产集合的成员，请使用`PHAsset`类方法

## 方法

```swift
// 通过PHAssetCollection的localIdentidier来检索PHAssetCollection
@available(iOS 8, *)
open class func fetchAssetCollections(withLocalIdentifiers identifiers: [String], options: PHFetchOptions?) -> PHFetchResult<PHAssetCollection>

// 通过PHAssetCollection的type和subType来获取PHAssetCollection
// 如果想要获取该type下所有集合，subType设置为.any
@available(iOS 8, *)
open class func fetchAssetCollections(with type: PHAssetCollectionType, subtype: PHAssetCollectionSubtype, options: PHFetchOptions?) -> PHFetchResult<PHAssetCollection>

// 通过PHAsset获取包含该资源的集合
// 只支持Albums和Moments
@available(iOS 8, *)
open class func fetchAssetCollectionsContaining(_ asset: PHAsset, with type: PHAssetCollectionType, options: PHFetchOptions?) -> PHFetchResult<PHAssetCollection>

// 临时资产合集只会存在内存中，不会存在磁盘中
// 通过PHAsset集合生成临时的PHAssetCollection
@available(iOS 8, *)
open class func transientAssetCollection(with assets: [PHAsset], title: String?) -> PHAssetCollection

// 通过PHFetchResult结果生成临时的PHAssetCollection
@available(iOS 8, *)
open class func transientAssetCollection(withAssetFetchResult fetchResult: PHFetchResult<PHAsset>, title: String?) -> PHAssetCollection
```

## 属性

```swift
// 集合类型
open var assetCollectionType: PHAssetCollectionType { get }

public enum PHAssetCollectionType : Int {
		@available(iOS 8, *)
  	case album = 1

  	@available(iOS 8, *)
  	case smartAlbum = 2

  	@available(iOS, introduced: 8, deprecated: 13, message: "Will be removed in a future release")
  	case moment = 3
}

// 集合子类型
open var assetCollectionSubtype: PHAssetCollectionSubtype { get }

public enum PHAssetCollectionSubtype : Int {
    // PHAssetCollectionTypeAlbum regular subtypes
    case albumRegular = 2 // 用户自己在Photos app中建立的相册
    case albumSyncedEvent = 3 // 已废弃；使用 iTunes 从 Photos 照片库或者 iPhoto 照片库同步过来的事件。然而，在iTunes 12 以及iOS 9.0 beta4上，选用该类型没法获取同步的事件相册，而必须使用AlbumSyncedAlbum。
    case albumSyncedFaces = 4 // 使用 iTunes 从 Photos 照片库或者 iPhoto 照片库同步的人物相册。
    case albumSyncedAlbum = 5 // 从iPhoto同步到设备的相册
    case albumImported = 6 // 从相机或外部存储导入的相册

    // PHAssetCollectionTypeAlbum shared subtypes
    case albumMyPhotoStream = 100 // 用户的 iCloud 照片流
    case albumCloudShared = 101 // 用户使用iCloud共享的相册

    // PHAssetCollectionTypeSmartAlbum subtypes
    case smartAlbumGeneric = 200 // 非特殊类型的相册，从macOS Photos app同步过来的相册
    case smartAlbumPanoramas = 201 // 相机拍摄的全景照片
    case smartAlbumVideos = 202 // 相机拍摄的视频
    case smartAlbumFavorites = 203 // 收藏的照片、视频的相册
    case smartAlbumTimelapses = 204 // 延时视频的相册
    case smartAlbumAllHidden = 205 // 包含隐藏照片、视频的相册
    case smartAlbumRecentlyAdded = 206 // 相机近期拍摄的照片、视频的相册
    case smartAlbumBursts = 207 // 连拍模式拍摄的照片
    case smartAlbumSlomoVideos = 208 // Slomo是slow motion的缩写，高速摄影慢动作解析（iOS设备以120帧拍摄）的相册
    case smartAlbumUserLibrary = 209 // 相机相册，包含相机拍摄的所有照片、视频，使用其他应用保存的照片、视频
    case smartAlbumSelfPortraits = 210 // 包含了所有使用前置摄像头拍摄的资源的智能相册——自拍
    case smartAlbumScreenshots = 211 // 包含了所有使用屏幕截图的资源的智能相册——屏幕快照
    case smartAlbumDepthEffect = 212 // 包含了所有兼容设备上使用景深效果拍摄的资源的智能相册
    case smartAlbumLivePhotos = 213 // 包含了所有Live Photo的智能相册——Live Photo
    case smartAlbumAnimated = 214 // 动态图片gif
    case smartAlbumLongExposures = 215 // 所有开启长曝光的实况图片
    case smartAlbumUnableToUpload = 216

    // Used for fetching, if you don't care about the exact subtype
    @available(iOS 8, *)
    case any = 9223372036854775807 // 包含所有类型
}

// 资源估算数量
// 这只是估算数量，真实数量以返回结果为准。如果不能快速返回，则返回NSNotFound
open var estimatedAssetCount: Int { get }

// 开始时间
@available(iOS 8, *)
open var startDate: Date? { get }

// 结束时间
@available(iOS 8, *)
open var endDate: Date? { get }

// 定位位置
@available(iOS 8, *)
open var approximateLocation: CLLocation? { get }

// 定位的位置名称
@available(iOS 8, *)
open var localizedLocationNames: [String] { get }
```

