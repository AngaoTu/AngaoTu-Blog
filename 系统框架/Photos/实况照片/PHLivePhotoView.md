[toc]

# PHLivePhotoView

-   一种显示实况照片的视图——这张图片还包含了拍摄前和拍摄后瞬间的动作和声音。
-   在iOS中，你可以使用`PHPickerViewController`或`PHAsset`和`PHImageManager`类从`Photos`库中获取`LivePhoto`对象，或者从从`Photos`库导出的资源中创建一个。
-   默认情况下，`LivePhotoView`使用它自己的手势识别器，允许用户播放`LivePhoto`的动作和声音内容，与在照片应用程序中看到的交互和视觉效果相同。要定制这个手势识别器——例如，为了在你的应用程序的视图层次结构中正确处理事件，将它安装到不同的视图中——使用`playbackGestureRecognizer`属性。
-   要简单地动画视图以提示图片是`LivePhoto`，使用`PHLivePhotoViewPlaybackStyle`的`startPlayback(with:)`方法。

## 属性

```swift
// 视图中显示的实况图片
@available(iOS 9.1, *)
open var livePhoto: PHLivePhoto?

// 是否播放实况照片中的音频内容
// 默认值为false，表示视图会随其 Live Photo 的运动内容一起播放音频内容
@available(iOS 9.1, *)
open var isMuted: Bool

// 控制视图中实时照片播放的手势识别器
@available(iOS 9.1, *)
open var playbackGestureRecognizer: UIGestureRecognizer { get }
```

## 方法

```swift
// 返回指定LivePhoto选项的图标
// 默认情况下，此方法返回适合用作模板图像的纯色图像，您可以对其进行着色，以便在特定背景下显示。(使用UIImage类来创建模板图像。)当您计划将图标覆盖在动画的Live Photo内容上时，添加overContent选项以获得一个提供额外背景对比度的图像(不适合模板使用)。
@available(iOS 9.1, *)
open class func livePhotoBadgeImage(options badgeOptions: PHLivePhotoBadgeOptions = []) -> UIImage

public struct PHLivePhotoBadgeOptions : OptionSet {
    public init(rawValue: UInt)

    @available(iOS 9.1, *)
    public static var overContent: PHLivePhotoBadgeOptions { get } // 使该图像可以直接显示在Live Photo的内容上

    @available(iOS 9.1, *)
    public static var liveOff: PHLivePhotoBadgeOptions { get } // 表示Live Photo已经关闭，将被当作静态图片处理(例如，用于共享)
}

// 开始在视图中播放实况照片内容
// 通常，应用程序不需要直接控制播放，因为 Live Photo 视图提供交互式播放控制。仅当适合非交互式播放时才使用此方法 - 例如，为内容短暂设置动画以指示视图包含实时照片而不是静止图像。
@available(iOS 9.1, *)
open func startPlayback(with playbackStyle: PHLivePhotoViewPlaybackStyle)

@available(iOS 9.1, iOS 9.1, *)
public enum PHLivePhotoViewPlaybackStyle : Int {

    @available(iOS 9.1, *)
    case undefined = 0 // 无法使用

    @available(iOS 9.1, *)
    case full = 1 // 回放 Live Photo 的整个运动和声音内容，包括开始和结束时的过渡效果

    @available(iOS 9.1, *)
    case hint = 2 // 仅播放 Live Photo 运动内容的一小部分，没有声音。
}

// 停止播放实况照片
@available(iOS 9.1, *)
open func stopPlayback()
```

