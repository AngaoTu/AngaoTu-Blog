- [Swift底层原理-内存管理](#swift底层原理-内存管理)
  - [refCounts](#refcounts)
    - [RefCounts](#refcounts-1)
    - [引用计数初始化流程](#引用计数初始化流程)
  - [强引用](#强引用)
  - [弱引用](#弱引用)
    - [swift_weakInit](#swift_weakinit)
    - [HeapObjectSideTableEntry](#heapobjectsidetableentry)
  - [无主引用](#无主引用)


# Swift底层原理-内存管理

- `Swift`语言延续了和`Objective-C`语言一样的思路进行内存管理，都是采用`引用计数`的方式来管理实例的内存空间；

- 在结构体与类中我们了解到`Swift`对象本质是一个`HeapObject`结构体指针。`HeapObject`结构中有两个成员变量，`metadata` 和 `refCounts`，`metadata` 是指向元数据对象的指针，里面存储着类的信息，比如属性信息，虚函数表等。而 `refCounts` 通过名称可以知道，它是一个引用计数信息相关的东西。接下来我们研究一下 `refCounts` 。

## refCounts

- 在源码`HeapObject.h`文件中，我们可以找到`HeapObject`结构体中关于`refCounts`的定义

```c++
#define SWIFT_HEAPOBJECT_NON_OBJC_MEMBERS       \
  InlineRefCounts refCounts

/// The Swift heap-object header.
/// This must match RefCountedStructTy in IRGen.
struct HeapObject {
  /// This is always a valid pointer to a metadata object.
  HeapMetadata const *metadata;

  SWIFT_HEAPOBJECT_NON_OBJC_MEMBERS;

  // 省略部分代码
}
```

- 我们看到 `refCounts` 的类型为 `InlineRefCounts`，在`RefCount.h`文件中找到 `InlineRefCounts` 的定义：

```c++
typedef RefCounts<InlineRefCountBits> InlineRefCounts;
```

### RefCounts

- 发现`InlineRefCounts`是一个模版类：`RefCounts`，接收一个`InlineRefCountBits`类型的范型

```c++
template <typename RefCountBits>
class RefCounts {
  std::atomic<RefCountBits> refCounts;

  // Out-of-line slow paths.

  LLVM_ATTRIBUTE_NOINLINE
  void incrementSlow(RefCountBits oldbits, uint32_t inc) SWIFT_CC(PreserveMost);

  LLVM_ATTRIBUTE_NOINLINE
  void incrementNonAtomicSlow(RefCountBits oldbits, uint32_t inc);

  LLVM_ATTRIBUTE_NOINLINE
  bool tryIncrementSlow(RefCountBits oldbits);

  LLVM_ATTRIBUTE_NOINLINE
  bool tryIncrementNonAtomicSlow(RefCountBits oldbits);

  LLVM_ATTRIBUTE_NOINLINE
  void incrementUnownedSlow(uint32_t inc);

  public:
  enum Initialized_t { Initialized };
  enum Immortal_t { Immortal };
  // 省略部分方法
}
```

- 根据`RefCounts`的定义我们发现，其实质上是在操作我们传递的泛型参数`InlineRefCountBits`
- 我们看一下`InlineRefCountBits`的定义

```c++
typedef RefCountBitsT<RefCountIsInline> InlineRefCountBits;
```

- 它也是一个模板函数，并且也有一个参数 `RefCountIsInline`，而`RefCountIsInline`其实就是`true`。我们重点看一下`RefCountBitsT`的结构

```c++
template <RefCountInlinedness refcountIsInline>
class RefCountBitsT {

  friend class RefCountBitsT<RefCountIsInline>;
  friend class RefCountBitsT<RefCountNotInline>;
  
  static const RefCountInlinedness Inlinedness = refcountIsInline;

  typedef typename RefCountBitsInt<refcountIsInline, sizeof(void*)>::Type
    BitsType;
  typedef typename RefCountBitsInt<refcountIsInline, sizeof(void*)>::SignedType
    SignedBitsType;
  typedef RefCountBitOffsets<sizeof(BitsType)>
    Offsets;

  BitsType bits;
    
  // 省略部分代码
}
```

- 在`RefCountBitsT`中，发现只有一个`bits`属性，而该属性是由`RefCountBitsInt`的`Type`属性定义的；
- 我们来看一下`RefCountBitsInt`的结构：

```c++
template <RefCountInlinedness refcountIsInline>
struct RefCountBitsInt<refcountIsInline, 8> {
  typedef uint64_t Type;
  typedef int64_t SignedType;
};
```

- 可以看到，`Type` 的类型是一个 `uint64_t` 的位域信息，**在这个 `uint64_t` 的位域信息中存储着运行生命周期的相关引用计数**。

### 引用计数初始化流程

- 我们创建一个新的实例对象时，他的引用计数是多少呢？从源码中我们找到`HeapObject`的初始化方法：

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

- 调用了`HeapObject`初始化方法

```c++
constexpr HeapObject(HeapMetadata const *newMetadata) 
    : metadata(newMetadata)
    , refCounts(InlineRefCounts::Initialized)
  { }
```

- 给`refCounts`赋值了`Initialized`，我们继续分析发现`Initialized`是一个枚举类型`Initialized_t`

```c++
enum Initialized_t { Initialized };
enum Immortal_t { Immortal };

// RefCounts must be trivially constructible to avoid ObjC++
// destruction overhead at runtime. Use RefCounts(Initialized)
// to produce an initialized instance.
RefCounts() = default;

// Refcount of a new object is 1.
constexpr RefCounts(Initialized_t)
    : refCounts(RefCountBits(0, 1)) {}
```

- 而根据注释得知，一个新的实例被创建时，传入的是`RefCountBits(0，1)`，并且我们可以看到 `refCounts` 函数的参数传的不就是前面提到`RefCountBitsT`类型参数，我们找到`RefCountBitsT`初始化方法

```c++
LLVM_ATTRIBUTE_ALWAYS_INLINE
constexpr
RefCountBitsT(uint32_t strongExtraCount, uint32_t unownedCount)
  : bits((BitsType(strongExtraCount) << Offsets::StrongExtraRefCountShift) |
	(BitsType(1)                << Offsets::PureSwiftDeallocShift) |
	(BitsType(unownedCount)     << Offsets::UnownedRefCountShift))
{ }
```

- 已知外部调用`RefCountBitsT`初始化方法，`strongExtraCount` 传 0，`unownedCount` 传 1。
- 然后我们去查看几个偏移的定义

```c++
# define shiftAfterField(name) (name##Shift + name##BitCount)

template <>
struct RefCountBitOffsets<8> {  
  static const size_t PureSwiftDeallocShift = 0;
  static const size_t PureSwiftDeallocBitCount = 1;
  static const uint64_t PureSwiftDeallocMask = maskForField(PureSwiftDealloc);

  static const size_t UnownedRefCountShift = shiftAfterField(PureSwiftDealloc);
  static const size_t UnownedRefCountBitCount = 31;
  static const uint64_t UnownedRefCountMask = maskForField(UnownedRefCount);

  static const size_t StrongExtraRefCountShift = shiftAfterField(IsDeiniting);
  static const size_t StrongExtraRefCountBitCount = 30;
  static const uint64_t StrongExtraRefCountMask = maskForField(StrongExtraRefCount);
    
    // 结果分析
  StrongExtraRefCountShift = shiftAfterField(IsDeiniting)
                           = IsDeinitingShift + IsDeinitingBitCount
                           = shiftAfterField(UnownedRefCount) + 1
                           = UnownedRefCountShift + UnownedRefCountBitCount + 1
                           = shiftAfterField(PureSwiftDealloc) + 31 + 1
                           = PureSwiftDeallocShift + PureSwiftDeallocBitCount + 31 + 1
                           = 0 + 1 + 31 + 1 = 33
}
```

- 通过上面计算得到： `Offsets::StrongExtraRefCountShift` = 33，`Offsets::PureSwiftDeallocShift` = 0，`Offsets::UnownedRefCountShift` = 1
- 知道了这三个值的之后，我们开始计算`RefCountBitsT`的初始化方法调用 `bits` 的值：

```c++
0 << 33 | 1 << 0 | 1 << 1;
0 | 1 | 2 = 3;
```

- 最终`bits`存储信息如下：

![image.png](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/3159f24e6d0f41d998953f374f98b3e6~tplv-k3u1fbpfcp-zoom-in-crop-mark:3024:0:0:0.awebp)

- 第`0`位：标识是否是永久的
- 第`1-31`位：存储无主引用
- 第`32`位：标识当前类是否正在析构
- 第`33-62`位：标识强引用
- 第`63`位：是否使用`SlowRC`

## 强引用

- 默认情况下，引用都是强引用。通过前面对`refCounts`的结构分析，得知它是存储引用计数信息的东西，在创建一个对象之后它的初始值为 `0x0000000000000003`。
- 如果我对这个实例对象进行多个引用，引用计数会增加，那这个强引用是如何添加的？

- 底层会通过调用`_swift_retain_`方法

```c++
static HeapObject *_swift_retain_(HeapObject *object) {
  SWIFT_RT_TRACK_INVOCATION(object, swift_retain);
  if (isValidPointerForNativeRetain(object))
    object->refCounts.increment(1);
  return object;
}
```

- 在进行强引用的时候，本质上是调用 `refCounts` 的 `increment` 方法，也就是引用计数 +1。我们来看一下 `increment` 的实现：

```c++
void increment(uint32_t inc = 1) {
    auto oldbits = refCounts.load(SWIFT_MEMORY_ORDER_CONSUME);

    // constant propagation will remove this in swift_retain, it should only
    // be present in swift_retain_n
    if (inc != 1 && oldbits.isImmortal(true)) {
        return;
    }

    RefCountBits newbits;
    do {
        newbits = oldbits;
        bool fast = newbits.incrementStrongExtraRefCount(inc);
        if (SWIFT_UNLIKELY(!fast)) {
            if (oldbits.isImmortal(false))
                return;
            return incrementSlow(oldbits, inc);
        }
    } while (!refCounts.compare_exchange_weak(oldbits, newbits,
                                              std::memory_order_relaxed));
}
```

- 在 `increment` 中调用了 `incrementStrongExtraRefCount`，我们再去看看`incrementStrongExtraRefCount`实现

```c++
LLVM_NODISCARD LLVM_ATTRIBUTE_ALWAYS_INLINE
    bool incrementStrongExtraRefCount(uint32_t inc) {
    // This deliberately overflows into the UseSlowRC field.
    bits += BitsType(inc) << Offsets::StrongExtraRefCountShift;
    return (SignedBitsType(bits) >= 0);
}
```

- 此时`inc`为`1`，`StrongExtraRefCountShift`根据之前的计算为`33`
- `1 << 33`为结果为`8589934592`,其对应的十六进制为`0x200000000`
- 到这里就实现了引用计数`+1`的操作

## 弱引用

- 在实际开发的过程中，我们大多使用的都是强引用，在某些场景下使用强引用，用不好的话会造成循环引用。
- 在`Swift`中我们通过关键字`weak`来表明一个弱引用；`weak`关键字的作用是在使用这个`实例`的时候并不保有此实例的引用。使用`weak`关键字修饰的引用类型数据在传递时不会使引用计数加`1`，不会对其引用的实例保持强引用，因此不会阻止`ARC`释放被引用的实例。
- 由于弱引用不会保持对实例的引用，所以当实例被释放的时候，**弱引用**仍旧引用着这个实例也是有可能。因此，`ARC`会在被引用的实例释放时，自动地将弱引用设置为`nil`。由于`弱引用`需要允许设置为`nil`，因此它一定是`可选类型`；

### swift_weakInit

- 用 `weak` 修饰之后，变量变成了一个可选项，并且，还会调用一个 `swift_weakInit` 函数

```c++
WeakReference *swift::swift_weakInit(WeakReference *ref, HeapObject *value) {
  ref->nativeInit(value);
  return ref;
}
```

- 发现用 `weak` 修饰之后，在内部会生成`WeakReference`类型的变量，并在 `swift_weakInit` 中调用 `nativeInit` 函数。

```c++
void nativeInit(HeapObject *object) {
    auto side = object ? object->refCounts.formWeakReference() : nullptr;
    nativeValue.store(WeakReferenceBits(side), std::memory_order_relaxed);
}
```

- 在`nativeInit`方法中调用了`formWeakReference()`方法，也就意味着形成了`弱引用`(形成一个散列表)：

```c++
template <>
HeapObjectSideTableEntry* RefCounts<InlineRefCountBits>::formWeakReference()
{
  auto side = allocateSideTable(true);
  if (side)
    return side->incrementWeak();
  else
    return nullptr;
}
```

- 它本质就是创建了一个散列表

```c++
template <>
HeapObjectSideTableEntry* RefCounts<InlineRefCountBits>::allocateSideTable(bool failIfDeiniting)
{
  // 去除原有的refCount，也是是64位信息
  auto oldbits = refCounts.load(SWIFT_MEMORY_ORDER_CONSUME);
  
  // Preflight failures before allocating a new side table.
  // 判断原来的 refCounts 是否有当前的引用计数
  if (oldbits.hasSideTable()) {
    // 如果有直接返回
    return oldbits.getSideTable();
  } 
  else if (failIfDeiniting && oldbits.getIsDeiniting()) {
    // 如果没有并且正在析构直接返回 nil
    return nullptr;
  }

  // Preflight passed. Allocate a side table.
  
  // 创建一个散列表
  HeapObjectSideTableEntry *side = new HeapObjectSideTableEntry(getHeapObject());
  
  auto newbits = InlineRefCountBits(side);
  
  // 对原来的散列表以及正在析构的一些处理
  do {
    if (oldbits.hasSideTable()) {
      // Already have a side table. Return it and delete ours.
      // Read before delete to streamline barriers.
      auto result = oldbits.getSideTable();
      delete side;
      return result;
    }
    else if (failIfDeiniting && oldbits.getIsDeiniting()) {
      // Already past the start of deinit. Do nothing.
      return nullptr;
    }
    
    side->initRefCounts(oldbits);
    
  } while (! refCounts.compare_exchange_weak(oldbits, newbits,
                                             std::memory_order_release,
                                             std::memory_order_relaxed));
  return side;
}
```

- 散列表的创建可以分为4步：
  1. 取出原来的 `refCounts`引用计数的信息。
  2. 判断原来的 `refCounts` 是否有散列表，如果有直接返回，如果没有并且正在析构直接返回`nil`。
  3. 创建一个散列表。
  4. 对原来的散列表以及正在析构的一些处理。

### HeapObjectSideTableEntry

- 接下来我们来看看这个散列表`HeapObjectSideTableEntry`

```c++
Storage layout:

HeapObject {
  isa
  InlineRefCounts {
    atomic<InlineRefCountBits> {
      strong RC + unowned RC + flags
      OR
      HeapObjectSideTableEntry*
    }
  }
}

HeapObjectSideTableEntry {
  SideTableRefCounts {
    object pointer
    atomic<SideTableRefCountBits> {
      strong RC + unowned RC + weak RC + flags
    }
  }   
}
```

- 可以分析出在`Swift`中本质上存在两种引用计数：
  - 如果是`强引用`，那么是`strong RC + unowned RC + flags`；
  - 如果是`弱引用`，那么是 `HeapObjectSideTableEntry`；
- 我们看一下`HeapObjectSideTableEntry`结构

```c++
class HeapObjectSideTableEntry {
  // FIXME: does object need to be atomic?
  std::atomic<HeapObject*> object;
  SideTableRefCounts refCounts;

  public:
  HeapObjectSideTableEntry(HeapObject *newObject)
    : object(newObject), refCounts()
  { }
  
  // 省略部分代码
}
```

- 可以看到，`HeapObjectSideTableEntry`中存着对象的指针，并且还有一个 `refCounts`，而 `refCounts` 的类型为`SideTableRefCounts`

```c++
typedef RefCounts<SideTableRefCountBits> SideTableRefCounts;
```

- `SideTableRefCountBits`就是继承自我们前面学过的`RefCountBitsT`的模版类

```c++
class alignas(sizeof(void*) * 2) SideTableRefCountBits : public RefCountBitsT<RefCountNotInline>
{
  uint32_t weakBits;

  public:
  LLVM_ATTRIBUTE_ALWAYS_INLINE
  SideTableRefCountBits() = default;
}
```

- 它多了一个`weakBits`成员变量。
- 所以`HeapObjectSideTableEntry`里边存储的是`64位`原有的`strong RC + unowned RC + flags`，再加上`32位`的`weak RC`；
- 当我们用 `weak` 修饰之后，这个**散列表**就会存储对象的指针和引用计数信息相关的东西。

## 无主引用

- 在`Swift`中可以通过 `unowned` 定义无主引用，`unowned` 不会产生强引用，实例销毁后仍然存储着实例的内存地址（类似于`OC`中的 `unsafe_unretained`）。需要注意的是试图在实例销毁后访问无主引用，会产生运行时错误（野指针）。
- `weak`、`unowned` 都能解决循环引用的问题，`unowned` 要比 `weak` 少一些性能消耗，那我们如何来选择 `weak` 和 `unowned` 呢?
  - 如果强引用的双方生命周期没有任何关系，使用`weak`
  - 如果其中一个对象销毁，另一个对象也跟着销毁，则使用`unowned`；

- `weak`相对于`unowned`更兼容，更安全，而`unowned`性能更高；这是因为`weak`需要操作`散列表`，而`unowned`只需要操作`64`位位域信息；在使用`unowned`的时候，要确保其修饰的属性一定有值。