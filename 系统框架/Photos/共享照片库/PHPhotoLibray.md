[toc]

# PHPhotoLibray

-   该对象管理整个照片应用的资产和相册集，包括存储在本地设备上资源和存储在`icloud`中的照片资源
-   主要提供一下几个服务：
    -   检索或验证用户对你的应用，访问照片内容的权限
    -   对资源或集合进行更改。比如编辑某个图片的数据、插入新的图片
    -   注册系统观察者，在照片库内容发生更改时，发送修改消息

## 方法

-   验证权限

```swift
// 返回应用对指定访问级别的用户照片库的访问权限
@available(iOS 14, *)
open class func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus

@available(iOS 8, iOS 8, *)
public enum PHAuthorizationStatus : Int {
    @available(iOS 8, *)
    case notDetermined = 0 // 用户尚未设置应用的授权状态。

    @available(iOS 8, *)
    case restricted = 1 // 此应用程序未被授权访问照片数据。

    @available(iOS 8, *)
    case denied = 2 // 用户明确拒绝此应用程序访问照片数据。

    @available(iOS 8, *)
    case authorized = 3 // 用户已授权此应用程序访问照片数据。

    @available(iOS 14, *)
    case limited = 4 // 用户授权此应用访问有限的照片库。
}

// 提示用户授予应用访问照片库的权限。
@available(iOS 14, *)
open class func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping (PHAuthorizationStatus) -> Void)
```

-   更新库

```swift
// 异步运行请求更改照片库的块
// 在任意串行队列上执行更改和完成处理程序块。如果因为更改而更新应用程序的UI，请将这部分工作放到主队列中执行。
@available(iOS 8, *)
open func performChanges(_ changeBlock: @escaping () -> Void, completionHandler: ((Bool, Error?) -> Void)? = nil)

// 同步运行一个块，请求在照片库中执行更改
// 不要从主线程调用这个方法。你的更改块以及照片代表您执行以应用其请求的更改的工作需要一些时间来执行。（照片可能需要提示用户执行更改，因此此方法可以无限期地阻止执行。）
// 如果您已经在后台队列上执行工作，导致将更改应用于照片库，请使用此方法。要从主队列请求更改，请改用方法 performChanges(_:completionHandler:)
@available(iOS 8, *)
open func performChangesAndWait(_ changeBlock: @escaping () -> Void) throws
```

-   观察库的变化

```swift
// 注册一个对象以在照片库中的对象发生变化时接收消息
@available(iOS 8, *)
open func register(_ observer: PHPhotoLibraryChangeObserver)

// 取消注册对象，使其不再接收更改消息
@available(iOS 8, *)
open func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver)

// 需要注册的类，遵守PHPhotoLibraryChangeObserver协议，然后通过下面方法拿到最新照片库修改信息
func photoLibraryDidChange(_ changeInstance: PHChange) {
	
}
```

-   观察库的可用性

```swift
// 注册一个对象以观察照片库可用性的变化
// 观察照片库可用性的变化主要与使用 macOS 和 Mac Catalyst 创建的 Mac 应用程序有关，其中照片库可能位于外部驱动器或云存储中。
@available(iOS 13, *)
open func register(_ observer: PHPhotoLibraryAvailabilityObserver)

// 从观察照片库可用性的变化中取消注册对象
@available(iOS 13, *)
open func unregisterAvailabilityObserver(_ observer: PHPhotoLibraryAvailabilityObserver)

// 需要注册的类，遵守PHPhotoLibraryAvailabilityObserver协议，然后通过下面方法拿到哪个照片库不可用
func photoLibraryDidBecomeUnavailable(_ photoLibrary: PHPhotoLibrary) {
  
}
```

## 属性

```swift
// 照片库不可用原因
// 仅在照片库不可用时，才包含有效错误
@available(iOS 13, *)
open var unavailabilityReason: Error? { get }
```

