- [Runtime源码解析-alloc](#runtime源码解析-alloc)
  - [前言](#前言)
  - [alloc](#alloc)
    - [通过汇编查看调用流程](#通过汇编查看调用流程)
    - [1. objc_alloc方法](#1-objc_alloc方法)
    - [2. callAlloc方法](#2-callalloc方法)
      - [首次进入](#首次进入)
      - [非首次进入](#非首次进入)
      - [LLVM优化](#llvm优化)
    - [3. _objc_rootAllocWithZone方法](#3-_objc_rootallocwithzone方法)
    - [4. _class_createInstanceFromZone方法](#4-_class_createinstancefromzone方法)
      - [instanceSize：计算内存大小](#instancesize计算内存大小)
        - [fastInstanceSize](#fastinstancesize)
        - [alignedInstanceSize](#alignedinstancesize)
      - [malloc/calloc：开辟内存](#malloccalloc开辟内存)
      - [initInstanceIsa/initIsa：内存和类关联](#initinstanceisainitisa内存和类关联)
    - [总结](#总结)
  - [init](#init)
  - [new](#new)
# Runtime源码解析-alloc

## 前言

- 从这篇文章开始，我们进行`OC`底层研究。主要研究方向包括了：对象和类的具体实现，属性、方法、协议等是如何存储的，方法是如何调用，类和`category`是如何加载，`weak`是如何实现的等等一些问题
- 本系列博客所用的是818.2版本的`objc4`源码(目前最新版)

## alloc

- 在我们`iOS`的开发过程中，使用最频繁的就是`alloc`一个对象，那`alloc`到底做了些什么？那就让我们从`alloc`开始，开启`oc`的底层研究之路。
- 首先我们创建一个`Test`类

```objective-c
@interface Test : NSObject

@end

@implementation Test

@end

- (void)viewDidLoad {
    [super viewDidLoad];
    
    Test *test = [Test alloc];
}
```

- 一般习惯性我们会点击`alloc`的实现，发现进去只能看到声明，看不到具体实现。由于我们写的都是高级语言，最终都会编译成汇编。所以我们可以通过汇编来查看具体调用。

### 通过汇编查看调用流程

- 首先通过`Debug` -> `Debug Workflow` -> `Always Show Disassembly`，打开汇编
- 然后在`Test *test1 = [Test alloc];`添加断点。

![](https://tva1.sinaimg.cn/large/e6c9d24egy1h569reakilj21re0sen55.jpg)

- 运行起来后，我们发现`alloc`调用的是`objc_alloc`方法。然后按住`control`键+`step into`，执行到`objc_alloc`里面去了

![](https://tva1.sinaimg.cn/large/e6c9d24egy1h569su8n2kj21om0d2783.jpg)

- 发现直接进入`libobjc.A.dylib`中，调用了`_objc_rootAllocWithZone`方法。既然知道方法在lib库中，这个时候我们就进入到`objc4`源码中。

### 1. objc_alloc方法

```objective-c
id
objc_alloc(Class cls)
{
    return callAlloc(cls, true/*checkNil*/, false/*allocWithZone*/);
}
```

- 内部调用了`callAlloc`方法

### 2. callAlloc方法

```objective-c
static ALWAYS_INLINE id
callAlloc(Class cls, bool checkNil, bool allocWithZone=false)
{
#if __OBJC2__ // 判断是否是否objc2.0版本，目前所采用都是2.0版本
    if (slowpath(checkNil && !cls)) return nil;
    if (fastpath(!cls->ISA()->hasCustomAWZ())) {
        return _objc_rootAllocWithZone(cls, nil);
    }
#endif

    // No shortcuts available.
    if (allocWithZone) {
        return ((id(*)(id, SEL, struct _NSZone *))objc_msgSend)(cls, @selector(allocWithZone:), nil);
    }
    return ((id(*)(id, SEL))objc_msgSend)(cls, @selector(alloc));
}

```

- 首先遇到两个宏判断

```objective-c
#define fastpath(x) (__builtin_expect(bool(x), 1)) // fastpath(x):x很可能为真 
#define slowpath(x) (__builtin_expect(bool(x), 0)) // slowpath(x):x很可能为假，为真的概率很小 
```

- 作用是告诉编译器可能的结果，可以优化编译器的速度。
- 通过编译调试可知
  - 首次进入`callAlloc`方法，会调用`((id(*)(id, SEL))objc_msgSend)(cls, @selector(alloc));`方法。
    - 这里`objc_msgSend`是iOS中消息转发机制，最终会调用`alloc`这个方法
  - 第二次进入，会走`_objc_rootAllocWithZone`方法。

#### 首次进入

- 会接着进入`alloc`方法

```objective-c
+ (id)alloc {
    return _objc_rootAlloc(self);
}
```

- 进入`_objc_rootAlloc`方法

```objective-c
id
_objc_rootAlloc(Class cls)
{
    return callAlloc(cls, false/*checkNil*/, true/*allocWithZone*/);
}
```

- 再次进入`callAlloc`方法

#### 非首次进入

- 会直接进入`_objc_rootAllocWithZone`方法

#### LLVM优化

- 这里为什么会走两次`callAlloc`方法？为什么`alloc`方法需要先调用`objc_alloc`然后再调用`alloc`。
- 这里是苹果在LLVM中做了操作，会给`alloc`方法，添加一个`hook`方法`objc_alloc`。让每第一次走到`alloc`方法，都先走到`object_alloc`方法。只有走过这个方法后，再去调用真正的`alloc`方法。
- 苹果在`objc_alloc`方法做一些额外操作，比如`ARC`相关，类型转换等，方便苹果做一些监控，以及优化。

### 3. _objc_rootAllocWithZone方法

```objective-c
NEVER_INLINE
id
_objc_rootAllocWithZone(Class cls, malloc_zone_t *zone __unused)
{
    // allocWithZone under __OBJC2__ ignores the zone parameter
    return _class_createInstanceFromZone(cls, 0, nil,
                                         OBJECT_CONSTRUCT_CALL_BADALLOC);
}
```

- 内部调用`_class_createInstanceFromZone`方法

### 4. _class_createInstanceFromZone方法

```objective-c
static ALWAYS_INLINE id
_class_createInstanceFromZone(Class cls, size_t extraBytes, void *zone,
                              int construct_flags = OBJECT_CONSTRUCT_NONE,
                              bool cxxConstruct = true,
                              size_t *outAllocatedSize = nil)
{
    ASSERT(cls->isRealized());

    // Read class's info bits all at once for performance
    bool hasCxxCtor = cxxConstruct && cls->hasCxxCtor();
    bool hasCxxDtor = cls->hasCxxDtor();
    bool fast = cls->canAllocNonpointer();
    size_t size;
	
    // 1. 计算需要初始化的大小
    size = cls->instanceSize(extraBytes);
    if (outAllocatedSize) *outAllocatedSize = size;

    // 2. 开辟对应大小的内存空间
    id obj;
    if (zone) {
        obj = (id)malloc_zone_calloc((malloc_zone_t *)zone, 1, size);
    } else {
        obj = (id)calloc(1, size);
    }
    if (slowpath(!obj)) {
        if (construct_flags & OBJECT_CONSTRUCT_CALL_BADALLOC) {
            return _objc_callBadAllocHandler(cls);
        }
        return nil;
    }
	
    // 3. 把开辟的内存和类关联起来
    if (!zone && fast) {
        obj->initInstanceIsa(cls, hasCxxDtor);
    } else {
        // Use raw pointer isa on the assumption that they might be
        // doing something weird with the zone or RR.
        obj->initIsa(cls);
    }

    if (fastpath(!hasCxxCtor)) {
        return obj;
    }

    construct_flags |= OBJECT_CONSTRUCT_FREE_ONFAILURE;
    return object_cxxConstructFromClass(obj, cls, construct_flags);
}
```

- 这个方法是最重要的方法，从实现中可以得知，它主要干了三件事：

	1. `cls->instanceSize(extraBytes);`：计算内存大小
	1. `(id)malloc_zone_calloc((malloc_zone_t *)zone, 1, size);`或者`(id)calloc(1, size)`：开辟内存，返回地址指针
	1. `obj->initInstanceIsa(cls, hasCxxDtor);`或者`obj->initIsa(cls);`：把内存和类关联起来

#### instanceSize：计算内存大小

```objective-c
inline size_t instanceSize(size_t extraBytes) const {
    // 是否通过缓存，快速计算大小
    if (fastpath(cache.hasFastInstanceSize(extraBytes))) {
        return cache.fastInstanceSize(extraBytes);
    }
	
    // 没有缓存，计算大小
    size_t size = alignedInstanceSize() + extraBytes;
    // CF requires all objects be at least 16 bytes.
    if (size < 16) size = 16;  
    return size;
}
```

- 进入后首先判断缓存中是否允许快速计算大小

##### fastInstanceSize

- 如果缓存存在，则通过缓存去计算大小，进入`fastInstanceSize`方法

```objective-c
size_t fastInstanceSize(size_t extra) const
{
    ASSERT(hasFastInstanceSize(extra));

    if (__builtin_constant_p(extra) && extra == 0) {
        return _flags & FAST_CACHE_ALLOC_MASK16;
    } else {
        size_t size = _flags & FAST_CACHE_ALLOC_MASK;
        // remove the FAST_CACHE_ALLOC_DELTA16 that was added
        // by setFastInstanceSize
        // 删除由setFastInstanceSize添加的FAST_CACHE_ALLOC_DELTA16 8个字节
        // 进行16字节对齐
        return align16(size + extra - FAST_CACHE_ALLOC_DELTA16);
    }
}
```

- 这里的`size`是通过`_flags & FAST_CACHE_ALLOC_MASK`计算得到的。这里需要我们了解类的具体结构，这里可以简单理解为一个类中成员变量的大小
- 通过16字节，进行内存对齐。如果这里不了解内存对齐知识，请看[内存对齐](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/%E5%86%85%E5%AD%98%E5%AF%B9%E9%BD%90/%E5%86%85%E5%AD%98%E5%AF%B9%E9%BD%90.md)

```objective-c
static inline size_t align16(size_t x) {
    return (x + size_t(15)) & ~size_t(15);
}
```

- 该方法的作用就是16字节对齐，对一个数以16倍数进行向上取整

##### alignedInstanceSize

- 如果没有缓存，则进入`alignedInstanceSize`方法

```objective-c
// Class's ivar size rounded up to a pointer-size boundary.
uint32_t alignedInstanceSize() const {
    return word_align(unalignedInstanceSize());
}
```

1. 我们需要获取未内存对齐大小`unalignedInstanceSize()`

```objective-c
// May be unaligned depending on class's ivars.
// 可以根据类的成员变量进行对齐。
uint32_t unalignedInstanceSize() const {
    ASSERT(isRealized());
    return data()->ro()->instanceSize;
}
```

- 该方法内部是获取类的成员变量大小

2. 对获取到的内存大小，进行对齐

```objective-c
#define WORD_MASK 7UL
static inline uint32_t word_align(uint32_t x) {
    return (x + WORD_MASK) & ~WORD_MASK;
}
```

- 此处采用的是8字节对齐，也就是说对象中成员变量按照8字节对齐。

#### malloc/calloc：开辟内存

- 通过调用可知`void *zone`传入的是0，所有这里会调用`calloc`方法

- 首先通过`instanceSize`计算出内存大小，然后向系统申请对应大小，返回给`obj`
- `calloc`具体底层实现，可阅读[iOS中calloc和malloc源码分析](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/iOS%E4%B8%ADmalloc%E5%92%8Ccalloc%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90.md)

#### initInstanceIsa/initIsa：内存和类关联

- 通过调用可知`void *zone`传入的是0，并且现在是支持`Nonpointer`类型`isa`，所以会调用`initInstanceIsa`方法

```objective-c
inline void 
objc_object::initInstanceIsa(Class cls, bool hasCxxDtor)
{
    ASSERT(!cls->instancesRequireRawIsa());
    ASSERT(hasCxxDtor == cls->hasCxxDtor());

    initIsa(cls, true, hasCxxDtor);
}
```

- 内部调用了`initIsa`方法，具体流程，我们会在`isa`这一章节讲解。可参考[Runtime源码剖析-对象](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/Runtime/2.%20Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-%E5%AF%B9%E8%B1%A1/Runtime%E6%BA%90%E7%A0%81%E5%89%96%E6%9E%90-%E5%AF%B9%E8%B1%A1.md)初始化`isa`章节。

![](https://tva1.sinaimg.cn/large/e6c9d24egy1h56d9ooewmj22d00tyteb.jpg)

- 在初始化后，我们打印`obj`对象，发现`po`出了它对应的类型。说明`initInstanceIsa`方法，把内存和类关联起来。

### 总结

- `alloc`核心方法是`_class_createInstanceFromZone`
- `alloc` 的核心作用就是开辟内存，通过`isa`指针与类进行关联

## init

- 在开发过程中，我们通常把`alloc`和`init`放在一起使用。`[[NSObject alloc] init]`
- 那具体init做了些什么操作。

```objective-c
- (id)init {
    return _objc_rootInit(self);
}

id
_objc_rootInit(id obj)
{
    // In practice, it will be hard to rely on this function.
    // Many classes do not properly chain -init calls.
    return obj;
}
```

- 在源码中是直接返回了`obj`对象本身
- `init`方法更多的是提供给我们一个抽象接口，可以让我们在子类中重写它，达到自定义效果。

## new

- 我们开发中，会发现有时候会直接调用`new`，而不是`alloc init`。

```objective-c
+ (id)new {
    return [callAlloc(self, false/*checkNil*/) init];
}
```

- 直接调用了`callAlloc`函数，并且调用`init`函数。所以可以得出`new`等价`[alloc init]`
- 一般不建议使用`new`。原因是有时候会重写`init`方法，类似于`initWithXXX`。使用`new`方法，无法调用到自定义的初始化方法