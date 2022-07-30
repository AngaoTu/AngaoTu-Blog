[toc]

# PHChange

-   对照片库中发生的更改的描述
-   想要获取照片库的变更
    -   你需要`PHPhotoLibrary.shared().register(self)`注册观察者
    -   然后在`PHPhotoLibraryChangeObserver`协议中，调用`photoLibraryDidChange(_ changeInstance: PHChange)`方法，这里会通过`PHChange`类来携带此次变更
    -   你需要知道更多变更信息，这里采用`PHObjectChangeDetails`和`PHFetchResultChangeDetails`两个类，来解析此次变更更细致信息

## 方法

```swift
// 这里需要注意，我们需要传入变更前的集合或者PHobject，
// 调用changeDetails(for:)或changeDetails(for:)方法，传递一个你之前获取的资产或集合对象，或者一个包含几个这样的对象的获取结果。
// 生成的PHObjectChangeDetails或PHFetchResultChangeDetails对象描述了自上次获取后对象或获取结果发生的任何变化。

// 返回指定资产或集合的详细更改信息
public func changeDetails<T>(for object: T) -> PHObjectChangeDetails<T>? where T : PHObject

// 返回PHFetchResult结果的详细更改信息
public func changeDetails<T>(for fetchResult: PHFetchResult<T>) -> PHFetchResultChangeDetails<T>? where T : PHObject
```

