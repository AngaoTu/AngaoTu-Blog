[toc]

# Runtime源码解析-类中cache

- 首先我们再看一眼`objc_class`类的定义，本篇文章主要研究`cache`。

```c++
struct objc_class : objc_object {
 	// 初始化方法
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags
    // 其他方法
}
```

- `cache`的作用根据时间局部性原理，用来存储已经被调用过的方法的`SEL`和`IMP`，提高方法的调用效率。
- 本文主要研究`cache`的结构、存储方式、查询方式(会在`send_msg`过程中，重点讲解)

## cache_t

- 我们查看一下`cache_t`的结构

```c++
struct cache_t {
private:
    explicit_atomic<uintptr_t> _bucketsAndMaybeMask;
    union {
        struct {
            explicit_atomic<mask_t>    _maybeMask;
#if __LP64__
            uint16_t                   _flags;
#endif
            uint16_t                   _occupied;
        };
        explicit_atomic<preopt_cache_t *> _originalPreoptCache;
    };
}
```

- `_bucketsAndMaybeMask`变量占8字节，通过名字得知包含`buckets`和`maybeMask`两个值
- 一个联合体，里面有一个结构体和一个变量，它们是互斥的
  - 结构体中有三个变量 `_maybeMask`，`_flags`，`_occupied`，具体代表什么意思我们后面再探究。
  - `_originalPreoptCache`会提前初始化一块缓存，这个不是重点，可以不用关注



- 由于`cache`的本质是存储调用过的方法，它应该提供插入和查询方法，接着我们去查看一下公有方法

```c++
// 获取buckets
struct bucket_t *buckets() const;

// 插入方法
void insert(SEL sel, IMP imp, id receiver);
```

- 我们首先查看一下`bucket_t`结构

## bucket_t

```c++
struct bucket_t {
private:
    // IMP-first is better for arm64e ptrauth and no worse for arm64.
    // SEL-first is better for armv7* and i386 and x86_64.
#if __arm64__ // 真机
    explicit_atomic<uintptr_t> _imp;
    explicit_atomic<SEL> _sel;
#else
    explicit_atomic<SEL> _sel;
    explicit_atomic<uintptr_t> _imp;
#endif
	
    // 省略方法
}
```

- 它主要存储了`_sel`和`_imp`。
  - `_sel`:方法的名称，也叫标识符，用来识别不同方法。
  - `_imp`:存储了方法具体实现的地址
- 这里主要是根据真机环境，还是其它环境，`_imp`和`_sel`存储位置不一样

## insert方法

- 我们通过`insert`方法来探索，`cache`是如何存储方法

```c++
void cache_t::insert(SEL sel, IMP imp, id receiver)
{
    runtimeLock.assertLocked();

    // Never cache before +initialize is done
    if (slowpath(!cls()->isInitialized())) {
        return;
    }

    if (isConstantOptimizedCache()) {
        _objc_fatal("cache_t::insert() called with a preoptimized cache for %s",
                    cls()->nameForLogging());
    }

#if DEBUG_TASK_THREADS
    return _collecting_in_critical();
#else
#if CONFIG_USE_CACHE_LOCK
    mutex_locker_t lock(cacheUpdateLock);
#endif

    ASSERT(sel != 0 && cls()->isInitialized());

    // Use the cache as-is if until we exceed our expected fill ratio.
    // 添加方法后所占用的容量
    mask_t newOccupied = occupied() + 1;
    // 目前开辟内存大小
    unsigned oldCapacity = capacity(), capacity = oldCapacity;
    
    // 根据条件开辟存储容量
    if (slowpath(isConstantEmptyCache())) {
        // Cache is read-only. Replace it.
        if (!capacity) capacity = INIT_CACHE_SIZE;
        reallocate(oldCapacity, capacity, /* freeOld */false);
    }
    else if (fastpath(newOccupied + CACHE_END_MARKER <= cache_fill_ratio(capacity))) {
        // Cache is less than 3/4 or 7/8 full. Use it as-is.
    }
#if CACHE_ALLOW_FULL_UTILIZATION
    else if (capacity <= FULL_UTILIZATION_CACHE_SIZE && newOccupied + CACHE_END_MARKER <= capacity) {
        // Allow 100% cache utilization for small buckets. Use it as-is.
    }
#endif
    else {
        capacity = capacity ? capacity * 2 : INIT_CACHE_SIZE;
        if (capacity > MAX_CACHE_SIZE) {
            capacity = MAX_CACHE_SIZE;
        }
        reallocate(oldCapacity, capacity, true);
    }
	
    // 找到合适位置存储方法
    bucket_t *b = buckets();
    mask_t m = capacity - 1;
    mask_t begin = cache_hash(sel, m);
    mask_t i = begin;

    // Scan for the first unused slot and insert there.
    // There is guaranteed to be an empty slot.
    do {
        if (fastpath(b[i].sel() == 0)) {
            incrementOccupied();
            b[i].set<Atomic, Encoded>(b, sel, imp, cls());
            return;
        }
        if (b[i].sel() == sel) {
            // The entry was added to the cache by some other thread
            // before we grabbed the cacheUpdateLock.
            return;
        }
    } while (fastpath((i = cache_next(i, m)) != begin));

    bad_cache(receiver, (SEL)sel);
#endif // !DEBUG_TASK_THREADS
}
```

- 该方法主要分为两部分：
  1. 开辟内存，用来存储方法
  2. 把方法存储在合适的位置

### 开辟内存

```c++
mask_t newOccupied = occupied() + 1;
unsigned oldCapacity = capacity(), capacity = oldCapacity;
if (slowpath(isConstantEmptyCache())) {
    // Cache is read-only. Replace it.
    if (!capacity) capacity = INIT_CACHE_SIZE;
    reallocate(oldCapacity, capacity, /* freeOld */false);
}
else if (fastpath(newOccupied + CACHE_END_MARKER <= cache_fill_ratio(capacity))) {
    // Cache is less than 3/4 or 7/8 full. Use it as-is.
}
#if CACHE_ALLOW_FULL_UTILIZATION
else if (capacity <= FULL_UTILIZATION_CACHE_SIZE && newOccupied + CACHE_END_MARKER <= capacity) {
    // Allow 100% cache utilization for small buckets. Use it as-is.
}
#endif
else {
    capacity = capacity ? capacity * 2 : INIT_CACHE_SIZE;
    if (capacity > MAX_CACHE_SIZE) {
        capacity = MAX_CACHE_SIZE;
    }
    reallocate(oldCapacity, capacity, true);
}
```

1. 首先获取当前存储的方法占用的空间。
2. 得到当前总的开辟空间。

3. 如果是首次进入，需要开辟空间
4. 如果存储数量即将存满，需要扩容
5. 其他情况，则说明存储空间足够，接下来进行存储即可。

#### 首次进入，开辟内存

- 首先我们看一下第一种情况，首次进入，缓存为空

```c++
if (slowpath(isConstantEmptyCache())) {
    // Cache is read-only. Replace it.
    if (!capacity) capacity = INIT_CACHE_SIZE;
    reallocate(oldCapacity, capacity, /* freeOld */false);
}
```

- 先设置容量为`INIT_CACHE_SIZE`。
  - `INIT_CACHE_SIZE = (1 << INIT_CACHE_SIZE_LOG2)`并且`INIT_CACHE_SIZE_LOG2 = 2`。这里也就是说把`1<<2=4`。首次需要开辟的大小为4
- 进入`reallocate`方法

```c++
void cache_t::reallocate(mask_t oldCapacity, mask_t newCapacity, bool freeOld)
{
    bucket_t *oldBuckets = buckets();
    bucket_t *newBuckets = allocateBuckets(newCapacity);

    // Cache's old contents are not propagated. 
    // This is thought to save cache memory at the cost of extra cache fills.
    // fixme re-measure this

    ASSERT(newCapacity > 0);
    ASSERT((uintptr_t)(mask_t)(newCapacity-1) == newCapacity-1);

    setBucketsAndMask(newBuckets, newCapacity - 1);
    
    if (freeOld) {
        collect_free(oldBuckets, oldCapacity);
    }
}
```



### 存储方法