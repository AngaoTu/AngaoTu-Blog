[toc]

# Photos介绍

## 前言

- 本文将详细介绍`Photos`框架中所包含的每个类的作用，梳理相关类互相持有、继承等一些关系，介绍每个类中的属性以及方法的使用场景。
- 本文需要读者对该类有一定的了解，我不会具体讲解这个类是如何配合使用的。该文的目的是让你对这个框架从整体、到细节都有一个清楚的认知，所以我采用先宏观展示整个框架各个类之间的关系，接着我们微观的去了解每个类的作用，含有哪些属性与方法等。

## 概述

- `Photos`是**App**用来管理图片和视频资源的框架，并且包括了**iCloud**上的图片以及实时照片。

![](https://docs-assets.developer.apple.com/published/3459c84072/a27985f6-1ee8-4116-98c7-9199674be2df.png)

## 主要功能

### 1. 监控图片库资源变化

- 通过`PHPhotoLibrary`注册变化通知，当用户的照片库元数据发生改变时，照片库则会通知`App`，用户的照片库已经改变。
- 在通知过程中使用`PHChange`类，它包含了变更照片对象的相关信息。

### 2. 资源/资源集合的管理

- 在`Photos`框架中有如下几种实体
  - `PHAsset`：图片或视频
  - `PHAssetCollection`：相册或时刻记录
  - `PHCollectionList`：文件夹集合
- `Photos`框架可以在不同的层次对资源进行管理，管理对象可以是单个图片，也可以是相册等。

### 3. 获取资源

>  根据指定过滤条件，来获取图片、图片集合

- `PHFetchOptions`：根据该条件来过滤、排序获取结果
- `PHFetchResult`：获取的照片/照片集合结果

### 4. 加载和缓存资源

- 使用`PHImageManager`获取照片、视频或实况图片资产，并且该框架会自动合成照片，并缓存这些照片。
- 还可以在大批量情况下使用`PHCachingImageManager`实现预加载。

### 5. 资源的编辑

- 通过`PHAssetChangeRequest`可以记录创建、删除、修改照片内容的请求，然后通过`PHPhotoLibrary`来执行针对图片的编辑请求。
- 并且支持在不同的`App`中修改同样的照片

## 所有类

### 共享照片库

- `PHPhotoLibrary`：管理对用户照片库的访问和更改。

### 检索Asset

- `PHObject`：照片模型对象(`Asset/PHAssetCollection`)的抽象基类。

- `PHAsset`：照片库中照片或视频，包含`iCloud`的照片或视频。
- `PHCollection`：照片资产集合和集合列表的抽象基类。
  - `PHAssetCollection`：照片或视频集合（照片`App`中的相薄）。
  - `PHCollectionList`：包含照片集合的组。

- `PHFetchResult`：通过照片检索方法返回的结果集。

- `PHFetchOptions`：在你获取照片或照片集合时，影响照片返回结果的过滤、排序选项。

### 加载Asset

- `PHImageManager`：加载PHAsset的管理器。
  - `PHCachingImageManager`：针对批量预加载Assets进行优化。
- `PHImageRequestOptions`：影响通过`PHImageManager`请求图片资源的结果
- `PHVideoRequestOptions`：影响通过`PHImageManager`请求视频资源的结果。
- `PHLivePhotoRequestOptions`：影响通过`PHImageManager`请求实况图资源的结果。

### 实况图片

- `PHLivePhoto`：表示实况图片。
- `PHLivePhotoView`：显示实况照片视图。

### Asset资源管理

- `PHAssetResource`：`PHAssetResource`是`PHAsset`对象关联的基础数据。
- `PHAssetCreationRequest`：`PHPhotoLibrary`闭包中将一个新照片或视频添加到照片库中。
- `PHAssetResourceCreationOptions`：影响通过`PHAssetCreationRequest`创建新照片的一组选项。
- `PHAssetResourceManager`：照片底层数据资源管理器。
- `PHAssetResourceRequestOptions`：影响通过`PHAssetResourceManager`请求的`Assets`结果。

### Asset编辑

- `PHChangeRequest`：照片库更改请求的抽象基类。
  - `PHAssetChangeRequest`：`PHPhotoLibrary`闭包中创建、删除或修改`PHAsset`对象。
  - `PHAssetCollectionChangeRequest`：`PHPhotoLibrary`闭包中创建、删除和修改`PHAssetCollection`对象。
  - `PHCollectionListChangeRequest`：`PHPhotoLibrary`闭包中创建、删除或修改PHCollectionList对象。
- `PHAdjustmentData`：当用户修改照片或视频后，`Photos`会使用`PHAdjustmentData`记录照片的修改时间。
- `PHObjectPlaceholder`：创建的照片或者集合的只读代理。
- `PHContentEditingInput`：输入`PHAsset`的修改。
- `PHContentEditingInputRequestOptions`：使用`PHContentEditingInputRequestOptions`描述`PHContentEditingInput`。
- `PHContentEditingOutput`：读取`PHAsset`的修改。

### 照片库资源变化

- `PHChange`：当资产和集合发生改变的通知对象。
- `PHObjectChangeDetails`：记录`PHObject`变化状态。
- `PHFetchResultChangeDetails`：记录两次相同检索的差异。
