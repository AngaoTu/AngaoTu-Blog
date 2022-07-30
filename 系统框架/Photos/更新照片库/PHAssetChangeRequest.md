[toc]

# PHAssetChangeRequest

-   运用于照片库`performChanges`中，创建、删除、修改照片
-   

## 属性

```swift
// 变更请求创建的资产的占位符对象
/*
	1. 可以使用-localIdentifier在变更块完成后获取新创建的资产
	2. 它也可以直接添加到当前更改块中的集合中
*/
@available(iOS 8, *)
open var placeholderForCreatedAsset: PHObjectPlaceholder? { get }

// 创建时间
@available(iOS 8, *)
open var creationDate: Date?

// 地点
@available(iOS 8, *)
open var location: CLLocation?

// 是否喜欢
@available(iOS 8, *)
open var isFavorite: Bool

// 是否隐藏
@available(iOS 8, *)
open var isHidden: Bool
```



## 方法

```swift
// 通过UIImage创建新Asset
@available(iOS 8, *)
open class func creationRequestForAsset(from image: UIImage) -> Self

// 通过照片file创建新Asset
@available(iOS 8, *)
open class func creationRequestForAssetFromImage(atFileURL fileURL: URL) -> Self?

// 通过视频file创建新Asset
@available(iOS 8, *)
open class func creationRequestForAssetFromVideo(atFileURL fileURL: URL) -> Self?

// 删除Assets
@available(iOS 8, *)
open class func deleteAssets(_ assets: NSFastEnumeration)

// 请求恢复对资产内容所做的任何编辑
@available(iOS 8, *)
open func revertAssetContentToOriginal()

// 通过Asset初始化一个PHAssetChangeRequest
@available(iOS 8, *)
public convenience init(for asset: PHAsset)
```

