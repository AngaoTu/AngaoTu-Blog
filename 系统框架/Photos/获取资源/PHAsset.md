[toc]

# PHAsset

- 照片库中图像、视频、实况图片的模型

- 主要分为两个模块：
    1. 类方法用来检索一个或多个`PHAsset`实例
    2. 资源的基本属性：创建时间、经纬度等（想要获取资源对应的照片或视频，需要通过`PHImageManager`来加载）

## 方法

```swift
// 从指定的资产集合中检索资产
@available(iOS 8, *)
open class func fetchAssets(in assetCollection: PHAssetCollection, options: PHFetchOptions?) -> PHFetchResult<PHAsset>

// 检索具有指定的本地设备特定唯一标识符的资产
@available(iOS 8, *)
open class func fetchAssets(withLocalIdentifiers identifiers: [String], options: PHFetchOptions?) -> PHFetchResult<PHAsset> // includes hidden assets by default

// 获取某个资产合集中关键资产
@available(iOS 8, *)
open class func fetchKeyAssets(in assetCollection: PHAssetCollection, options: PHFetchOptions?) -> PHFetchResult<PHAsset>?

// 检索具有指定连拍照片序列标识符的资产
// 默认情况下，返回的对象仅包含代表性资产和任何用户从连拍序列中挑选的照片。如果要检索连拍序列中的所有照片，请提供一个包含过滤谓词的对象，PHFetchResult中includeAllBurstAssets设置为true
@available(iOS 8, *)
open class func fetchAssets(withBurstIdentifier burstIdentifier: String, options: PHFetchOptions?) -> PHFetchResult<PHAsset>

// 通过检索条件来获取资源
// 默认情况下是拉取PHAssetSourceTypeUserLibrary中资源，你可以在PHFetchOptions中includeAssetSourceTypes修改拉取类别
@available(iOS 8, *)
open class func fetchAssets(with options: PHFetchOptions?) -> PHFetchResult<PHAsset>

// 通过媒体类别来获取资源
@available(iOS 8, *)
open class func fetchAssets(with mediaType: PHAssetMediaType, options: PHFetchOptions?) -> PHFetchResult<PHAsset>
```

## 属性

### 资源元数据

- mediaType

```swift
// 用来区分该asset的媒体类型
@available(iOS 8, *)
open var mediaType: PHAssetMediaType { get }

// 一共有三种媒体类型：图片、视频、语音
public enum PHAssetMediaType : Int {
    @available(iOS 8, *)
  	case unknown = 0

  	@available(iOS 8, *)
  	case image = 1

  	@available(iOS 8, *)
  	case video = 2

  	@available(iOS 8, *)
  	case audio = 3
}
```

- mediaSubtypes

```swift
// 根据图片、视频增加的子类型，更细致的分类
open var mediaSubtypes: PHAssetMediaSubtype { get }
         
public struct PHAssetMediaSubtype : OptionSet {
    public init(rawValue: UInt)

    // Photo subtypes
    @available(iOS 8, *)
    public static var photoPanorama: PHAssetMediaSubtype { get } // 全景图

    @available(iOS 8, *)
    public static var photoHDR: PHAssetMediaSubtype { get } // HDR专业相机图

    @available(iOS 9, *)
    public static var photoScreenshot: PHAssetMediaSubtype { get } // 截图

    @available(iOS 9.1, *)
    public static var photoLive: PHAssetMediaSubtype { get } // 实况图

    @available(iOS 10.2, *)
    public static var photoDepthEffect: PHAssetMediaSubtype { get } // 人像模式深度效果捕捉


    // Video subtypes
    @available(iOS 8, *)
    public static var videoStreamed: PHAssetMediaSubtype { get } // 从未存储在本地的视频资源

    @available(iOS 8, *)
    public static var videoHighFrameRate: PHAssetMediaSubtype { get } // 高帧率视频

    @available(iOS 8, *)
    public static var videoTimelapse: PHAssetMediaSubtype { get } // 延时视频
}
```

-   sourceType

```swift
// 表示资源来源类型
open var sourceType: PHAssetSourceType { get }

public struct PHAssetSourceType : OptionSet {
    public init(rawValue: UInt)

    @available(iOS 8, *)
    public static var typeUserLibrary: PHAssetSourceType { get } // 用户相册

    @available(iOS 8, *)
    public static var typeCloudShared: PHAssetSourceType { get } // icloud相册

    @available(iOS 8, *)
    public static var typeiTunesSynced: PHAssetSourceType { get } // iTunes同步
}
```

-   其他

```swift
// 像素宽
@available(iOS 8, *)
open var pixelWidth: Int { get }

// 像素高
@available(iOS 8, *)
open var pixelHeight: Int { get }

// 创建时间
@available(iOS 8, *)
open var creationDate: Date? { get }

// 修改时间
@available(iOS 8, *)
open var modificationDate: Date? { get }

// 拍摄地点
@available(iOS 8, *)
open var location: CLLocation? { get }

// 资源时长
@available(iOS 8, *)
open var duration: TimeInterval { get }

// 是否隐藏
@available(iOS 8, *)
open var isHidden: Bool { get }

// 是否喜欢
@available(iOS 8, *)
open var isFavorite: Bool { get }
```

### 显示资源

```swift
// PHAsset中playbackStyle属性，表示通过什么方式来播放该资源
@available(iOS 11, *)
open var playbackStyle: PHAsset.PlaybackStyle { get }

public enum PlaybackStyle : Int {
    @available(iOS 8, *)
    case unsupported = 0 // 未定义资源播放类型

    @available(iOS 8, *)
    case image = 1 // 展示图片

    @available(iOS 8, *)
    case imageAnimated = 2 // 展示动图

    @available(iOS 8, *)
    case livePhoto = 3 // 展示实况图

    @available(iOS 8, *)
    case video = 4 // 展示视频

    @available(iOS 8, *)
    case videoLooping = 5 // 循环展示视频
}
```

### 编辑资源

```swift
// 具体相关细节，可以产看编辑模块内容
// 编辑资源
@available(iOS 8, *)
open func canPerform(_ editOperation: PHAssetEditOperation) -> Bool
```

### 连拍资源

```swift
// burstIdentifier表示连拍的标识符
// 通过fetchAssetsWithBurstIdentifier()方法，传入burstIdentifier属性，可以获取连拍照片中的剩余的其他照片
@available(iOS 8, *)
open var burstIdentifier: String? { get }

// 用户可以在连拍的照片中做标记；此外，系统也会自动用各种试探来标记用户可能会选择的潜在代表照片
open var burstSelectionTypes: PHAssetBurstSelectionType { get }

public struct PHAssetBurstSelectionType : OptionSet {
    public init(rawValue: UInt)

    @available(iOS 8, *)
    public static var autoPick: PHAssetBurstSelectionType { get } // 表示用户可能标记的潜在资源

    @available(iOS 8, *)
    public static var userPick: PHAssetBurstSelectionType { get } // 表示用户手动标记的资源
}

// 若一个资源的representsBurst属性为true，则表示该资源是一系列连拍照片中的代表照片，
// 可以通过fetchAssetsWithBurstIdentifier()方法，传入burstIdentifier属性，获取连拍照片中的剩余的其他照片
@available(iOS 8, *)
open var representsBurst: Bool { get }
```

