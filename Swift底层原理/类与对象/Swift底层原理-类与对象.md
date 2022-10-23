[toc]

# Swift底层原理-类与对象

## 准备工作

- 该系列文章，主要通过`Swift`底层源码进行研究。
- 可以通过该网址下载`Swift`源码[Swift源码](https://github.com/apple/swift)。

## 对象的创建

- 对下面的代码进行断点调试，查看汇编

```swift
class Test {
    var age: Int = 18
    var name: String = "ssl"
}

var t = Test()
```

- 汇编结果如下

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h7acj9l5rtj31w20i6aep.jpg)

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h7acjj4hutj31sg0ieq7k.jpg)

- 最终调用底层的`swift_allocObject`方法，接下来我们具体看看该方法做了些什么。

```c++
HeapObject *swift::swift_allocObject(HeapMetadata const *metadata,
                                     size_t requiredSize,
                                     size_t requiredAlignmentMask) {
  CALL_IMPL(swift_allocObject, (metadata, requiredSize, requiredAlignmentMask));
}
```

- 该方法内部调用了`_swift_allocObject_`方法

```c++
static HeapObject *_swift_allocObject_(HeapMetadata const *metadata,
                                       size_t requiredSize,
                                       size_t requiredAlignmentMask) {
  assert(isAlignmentMask(requiredAlignmentMask));
  auto object = reinterpret_cast<HeapObject *>(
      swift_slowAlloc(requiredSize, requiredAlignmentMask));

  // NOTE: this relies on the C++17 guaranteed semantics of no null-pointer
  // check on the placement new allocator which we have observed on Windows,
  // Linux, and macOS.
  new (object) HeapObject(metadata);

  // If leak tracking is enabled, start tracking this object.
  SWIFT_LEAKS_START_TRACKING_OBJECT(object);

  SWIFT_RT_TRACK_INVOCATION(object, swift_allocObject);

  return object;
}
```

- 内部会调用`swift_slowAlloc`方法，我们看一下该方法的实现

```c++
void *swift::swift_slowAlloc(size_t size, size_t alignMask) {
  void *p;
  // This check also forces "default" alignment to use AlignedAlloc.
  if (alignMask <= MALLOC_ALIGN_MASK) {
#if defined(__APPLE__)
    p = malloc_zone_malloc(DEFAULT_ZONE(), size);
#else
    p = malloc(size);
#endif
  } else {
    size_t alignment = (alignMask == ~(size_t(0)))
                           ? _swift_MinAllocationAlignment
                           : alignMask + 1;
    p = AlignedAlloc(size, alignment);
  }
  if (!p) swift::crash("Could not allocate memory.");
  return p;
}
```

- 该方法最终会去调用`malloc`去分配内存

### 总结

- `Swift`对象创建流程
  -  `swift_allocObject` --> `_swift_allocObject_` --> `swift_slowAlloc` --> `malloc`



## 类的结构

- 我们从对象的创建流程可知，最终返回的对象类型是`HeapObject *`。可以猜测所有类都是该类型结构。我们接下来看一下类的结构

### HeapObject

```c++
#define SWIFT_HEAPOBJECT_NON_OBJC_MEMBERS       \
  InlineRefCounts refCounts

/// The Swift heap-object header.
/// This must match RefCountedStructTy in IRGen.
struct HeapObject {
    /// This is always a valid pointer to a metadata object.
    HeapMetadata const *metadata;

    SWIFT_HEAPOBJECT_NON_OBJC_MEMBERS;
	
    // 省略初始化方法
};
```

- 可以看到该结构体里面，只有两个属性。一个是`metadata`，另一个是`refCounts`，默认占用16字节。

- 通过名称可以猜到，`refCounts`是引用计数，和内存管理相关。所以为了研究类的结构，重点就放在`metadata`上面

### HeapMetadata

```c++
using HeapMetadata = TargetHeapMetadata<InProcess>;
```

- `HeapMetadata`是`TargetHeapMetadata`这个类型的别名，点击进入`TargetHeapMetadata`结构

```c++
template <typename Runtime>
struct TargetHeapMetadata : TargetMetadata<Runtime> {
  using HeaderType = TargetHeapMetadataHeader<Runtime>;

  TargetHeapMetadata() = default;
  constexpr TargetHeapMetadata(MetadataKind kind)
    : TargetMetadata<Runtime>(kind) {}
#if SWIFT_OBJC_INTEROP
  constexpr TargetHeapMetadata(TargetAnyClassMetadata<Runtime> *isa)
    : TargetMetadata<Runtime>(isa) {}
#endif
};
```

- 根据代码可知，该类继承`TargetMetadata`
- 在这里有对 `OC` 和 `Swift` 做兼容。如果是一个纯`Swift`类，初始化传入了`MetadataKind`；如果和`OC`交互，它就传入了一个`isa`

#### MetadataKind

```c++
enum class MetadataKind : uint32_t {
#define METADATAKIND(name, value) name = value,
#define ABSTRACTMETADATAKIND(name, start, end)                                 \
  name##_Start = start, name##_End = end,
#include "MetadataKind.def"
  
  LastEnumerated = 0x7FF,
};
```

- 根据源码可以看到它是一个`uint32_t`类型，在`#include "MetadataKind.def"`文件中，可以看到它的枚举定义
- 它的具体种类如下：

| name                     | Value |
| ------------------------ | ----- |
| Class                    | 0x0   |
| Struct                   | 0x200 |
| Enum                     | 0x201 |
| Optional                 | 0x202 |
| ForeignClass             | 0x203 |
| Opaque                   | 0x300 |
| Tuple                    | 0x301 |
| Function                 | 0x302 |
| Existential              | 0x303 |
| Metatype                 | 0x304 |
| ObjCClassWrapper         | 0x305 |
| ExistentialMetatype      | 0x306 |
| HeapLocalVariable        | 0x400 |
| HeapGenericLocalVariable | 0x500 |
| ErrorObject              | 0x501 |
| LastEnumerated           | 0x7FF |

#### TargetMetadata

- 在上面我们知道 `TargetHeapMetadata` 的继承 `TargetMetadata`

```c++
TargetHeapMetadata : TargetMetadata
```

- 接下来查看一下`TargetMetadata`结构

```c++
struct TargetMetadata {
  using StoredPointer = typename Runtime::StoredPointer;

  // 省略初始化方法

private:
  /// The kind. Only valid for non-class metadata; getKind() must be used to get
  /// the kind value.
  StoredPointer Kind;
public:
  // 省略部分方法
}
```

- 可以看到 `TargetMetadata` 中有一个 `Kind` 成员变量
- 接着我们在共有方法中，找到一个`ConstTargetMetadataPointer`函数

```c++
ConstTargetMetadataPointer<Runtime, TargetTypeContextDescriptor>
  getTypeContextDescriptor() const {
    switch (getKind()) {
    case MetadataKind::Class: {
      const auto cls = static_cast<const TargetClassMetadata<Runtime> *>(this);
      if (!cls->isTypeMetadata())
        return nullptr;
      if (cls->isArtificialSubclass())
        return nullptr;
      return cls->getDescription();
    }
    case MetadataKind::Struct:
    case MetadataKind::Enum:
    case MetadataKind::Optional:
      return static_cast<const TargetValueMetadata<Runtime> *>(this)
          ->Description;
    case MetadataKind::ForeignClass:
      return static_cast<const TargetForeignClassMetadata<Runtime> *>(this)
          ->Description;
    default:
      return nullptr;
    }
  }
```

- 可以看到当`kind`是`Class`时，会将`this`强转为`TargetClassMetadata`类型。

#### TargetClassMetadata

```c++
template <typename Runtime>
struct TargetClassMetadata : public TargetAnyClassMetadata<Runtime> {
  using StoredPointer = typename Runtime::StoredPointer;
  using StoredSize = typename Runtime::StoredSize;

  TargetClassMetadata() = default;
  constexpr TargetClassMetadata(const TargetAnyClassMetadata<Runtime> &base,
             ClassFlags flags,
             ClassIVarDestroyer *ivarDestroyer,
             StoredPointer size, StoredPointer addressPoint,
             StoredPointer alignMask,
             StoredPointer classSize, StoredPointer classAddressPoint)
    : TargetAnyClassMetadata<Runtime>(base),
      Flags(flags), InstanceAddressPoint(addressPoint),
      InstanceSize(size), InstanceAlignMask(alignMask),
      Reserved(0), ClassSize(classSize), ClassAddressPoint(classAddressPoint),
      Description(nullptr), IVarDestroyer(ivarDestroyer) {}

  // The remaining fields are valid only when isTypeMetadata().
  // The Objective-C runtime knows the offsets to some of these fields.
  // Be careful when accessing them.

  /// Swift-specific class flags.
  ClassFlags Flags;

  /// The address point of instances of this type.
  uint32_t InstanceAddressPoint;

  /// The required size of instances of this type.
  /// 'InstanceAddressPoint' bytes go before the address point;
  /// 'InstanceSize - InstanceAddressPoint' bytes go after it.
  uint32_t InstanceSize;

  /// The alignment mask of the address point of instances of this type.
  uint16_t InstanceAlignMask;

  /// Reserved for runtime use.
  uint16_t Reserved;

  /// The total size of the class object, including prefix and suffix
  /// extents.
  uint32_t ClassSize;

  /// The offset of the address point within the class object.
  uint32_t ClassAddressPoint;

  // Description is by far the most likely field for a client to try
  // to access directly, so we force access to go through accessors.
private:
  /// An out-of-line Swift-specific description of the type, or null
  /// if this is an artificial subclass.  We currently provide no
  /// supported mechanism for making a non-artificial subclass
  /// dynamically.
  TargetSignedPointer<Runtime, const TargetClassDescriptor<Runtime> * __ptrauth_swift_type_descriptor> Description;

public:
  // 省略共有方法
};
```

- 通过源码可知，该类继承`TargetAnyClassMetadata`
- 有很多成员变量，初始化大小，类大小等一些属性

#### TargetAnyClassMetadata

```c++
template <typename Runtime>
struct TargetAnyClassMetadata : public TargetHeapMetadata<Runtime> {
  using StoredPointer = typename Runtime::StoredPointer;
  using StoredSize = typename Runtime::StoredSize;

#if SWIFT_OBJC_INTEROP
  constexpr TargetAnyClassMetadata(TargetAnyClassMetadata<Runtime> *isa,
                                   TargetClassMetadata<Runtime> *superclass)
    : TargetHeapMetadata<Runtime>(isa),
      Superclass(superclass),
      CacheData{nullptr, nullptr},
      Data(SWIFT_CLASS_IS_SWIFT_MASK) {}
#endif

  constexpr TargetAnyClassMetadata(TargetClassMetadata<Runtime> *superclass)
    : TargetHeapMetadata<Runtime>(MetadataKind::Class),
      Superclass(superclass),
      CacheData{nullptr, nullptr},
      Data(SWIFT_CLASS_IS_SWIFT_MASK) {}

#if SWIFT_OBJC_INTEROP
  // Allow setting the metadata kind to a class ISA on class metadata.
  using TargetMetadata<Runtime>::getClassISA;
  using TargetMetadata<Runtime>::setClassISA;
#endif

  // Note that ObjC classes does not have a metadata header.

  /// The metadata for the superclass.  This is null for the root class.
  ConstTargetMetadataPointer<Runtime, swift::TargetClassMetadata> Superclass;

  // TODO: remove the CacheData and Data fields in non-ObjC-interop builds.

  /// The cache data is used for certain dynamic lookups; it is owned
  /// by the runtime and generally needs to interoperate with
  /// Objective-C's use.
  TargetPointer<Runtime, void> CacheData[2];

  /// The data pointer is used for out-of-line metadata and is
  /// generally opaque, except that the compiler sets the low bit in
  /// order to indicate that this is a Swift metatype and therefore
  /// that the type metadata header is present.
  StoredSize Data;
  
  static constexpr StoredPointer offsetToData() {
    return offsetof(TargetAnyClassMetadata, Data);
  }

  /// Is this object a valid swift type metadata?  That is, can it be
  /// safely downcast to ClassMetadata?
  bool isTypeMetadata() const {
    return (Data & SWIFT_CLASS_IS_SWIFT_MASK);
  }
  /// A different perspective on the same bit
  bool isPureObjC() const {
    return !isTypeMetadata();
  }
};
```

- `TargetAnyClassMetadata`的结构中有`Superclass`，`CacheData[2]`，`Data`等属性，和`OC`中的类结构很类似

- 继承自`TargetHeapMetadata`，这也证明类本身也是对象。
- 综上所属，当`metadata`的`kind`为`Class`时，有如下继承链:

![img](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/ec94549555894dc8830d6e7609432b08~tplv-k3u1fbpfcp-zoom-in-crop-mark:4536:0:0:0.image)

- `Class`在内存结构由 `TargetClassMetadata`属性 + `TargetAnyClassMetaData`属性 + `TargetMetaData`属性构成，所以得出的`metadata`的数据结构体如下：

```c++
struct Metadata {
    var kind: Int
    var superClass: Any.Type
    var cacheData: (Int, Int)
    var data: Int
    var classFlags: Int32
    var instanceAddressPoint: UInt32
    var instanceSize: UInt32
    var instanceAlignmentMask: UInt16
    var reserved: UInt16
    var classSize: UInt32
    var classAddressPoint: UInt32
    var typeDescriptor: UnsafeMutableRawPointer
    var iVarDestroyer: UnsafeRawPointer
}
```

