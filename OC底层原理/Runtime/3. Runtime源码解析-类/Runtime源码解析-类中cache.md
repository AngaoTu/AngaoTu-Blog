- [Runtime源码解析-类中cache](#runtime源码解析-类中cache)
  - [cache_t](#cache_t)
  - [bucket_t](#bucket_t)
  - [insert方法](#insert方法)
    - [开辟内存](#开辟内存)
      - [首次进入，开辟内存](#首次进入开辟内存)
        - [allocateBuckets](#allocatebuckets)
        - [setBucketsAndMask](#setbucketsandmask)
        - [collect_free](#collect_free)
      - [容量小于3/4](#容量小于34)
      - [即将存满，进行扩容](#即将存满进行扩容)
    - [存储方法](#存储方法)
      - [cache_hash和cache_next](#cache_hash和cache_next)
      - [存储方法](#存储方法-1)
    - [总结](#总结)
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
4. 如果存储量小于3/4，则说明存储空间足够，接下来进行存储即可。
5. 如果存储数量即将存满，需要扩容

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

- 主要做了三件事：
  1. `allocateBuckets`开辟内存
  2. `setBucketsAndMask`设置`buckets`和`mask`
  3. `collect_free`是否释放旧的内存

##### allocateBuckets

```c++
bucket_t *cache_t::allocateBuckets(mask_t newCapacity)
{
    // Allocate one extra bucket to mark the end of the list.
    // This can't overflow mask_t because newCapacity is a power of 2.
    // 开辟对应内存
    bucket_t *newBuckets = (bucket_t *)calloc(bytesForCapacity(newCapacity), 1);

    // 在当前空间最后一位存入值
    bucket_t *end = endMarker(newBuckets, newCapacity);
#if __arm__
    // End marker's sel is 1 and imp points BEFORE the first bucket.
    // This saves an instruction in objc_msgSend.
    end->set<NotAtomic, Raw>(newBuckets, (SEL)(uintptr_t)1, (IMP)(newBuckets - 1), nil);
#else
    // End marker's sel is 1 and imp points to the first bucket.
    end->set<NotAtomic, Raw>(newBuckets, (SEL)(uintptr_t)1, (IMP)newBuckets, nil);
#endif
    
    if (PrintCaches) recordNewCache(newCapacity);

    return newBuckets;
}
```

- 该方法主要做了两件事：
  1. 通过`calloc`方法，开辟`sizeof(bucket_t) * cap`大小空间
  2. 找到当前开辟空间最后一个值，然后通过`end->set`方法，把`sel=1`，`imp=第一个桶之前的地址`存储到最后一个位置。

- 返回新创建内存空间的首地址。

##### setBucketsAndMask

```c++
void cache_t::setBucketsAndMask(struct bucket_t *newBuckets, mask_t newMask)
{
    // objc_msgSend uses mask and buckets with no locks.
    // It is safe for objc_msgSend to see new buckets but old mask.
    // (It will get a cache miss but not overrun the buckets' bounds).
    // It is unsafe for objc_msgSend to see old buckets and new mask.
    // Therefore we write new buckets, wait a lot, then write new mask.
    // objc_msgSend reads mask first, then buckets.

#ifdef __arm__
    // ensure other threads see buckets contents before buckets pointer
    mega_barrier();

    _bucketsAndMaybeMask.store((uintptr_t)newBuckets, memory_order_relaxed);

    // ensure other threads see new buckets before new mask
    mega_barrier();

    _maybeMask.store(newMask, memory_order_relaxed);
    _occupied = 0;
#elif __x86_64__ || i386
    // ensure other threads see buckets contents before buckets pointer
    _bucketsAndMaybeMask.store((uintptr_t)newBuckets, memory_order_release);

    // ensure other threads see new buckets before new mask
    _maybeMask.store(newMask, memory_order_release);
    _occupied = 0;
#else
#error Don't know how to do setBucketsAndMask on this architecture.
#endif
}
```

- `iOS`采用`arm`架构，向`_bucketsAndMaybeMask`和`_maybeMask`写入新开辟内存首地址，以及新开辟`newMask`值

##### collect_free

```c++
void cache_t::collect_free(bucket_t *data, mask_t capacity)
{
#if CONFIG_USE_CACHE_LOCK
    cacheUpdateLock.assertLocked();
#else
    runtimeLock.assertLocked();
#endif

    if (PrintCaches) recordDeadCache(capacity);

    _garbage_make_room (); // 创建垃圾回收站
    garbage_byte_size += cache_t::bytesForCapacity(capacity); // 获取开启内存大小
    garbage_refs[garbage_count++] = data; // 把需要清除地址，写进回收站中
    cache_t::collectNolock(false); // 清空数据
}
```

- 主要作用是清空数据，回收内存。

#### 容量小于3/4

```c++
else if (fastpath(newOccupied + CACHE_END_MARKER <= cache_fill_ratio(capacity))) {
    // Cache is less than 3/4 or 7/8 full. Use it as-is.
}

static inline mask_t cache_fill_ratio(mask_t capacity) {
    return capacity * 3 / 4;
}
```

- 如果需要缓存的方法所占总容量`3/4`以下，就不做任何操作，直接存储。

#### 即将存满，进行扩容

```c++
else {
    capacity = capacity ? capacity * 2 : INIT_CACHE_SIZE;
    if (capacity > MAX_CACHE_SIZE) {
        capacity = MAX_CACHE_SIZE;
    }
    reallocate(oldCapacity, capacity, true);
}

MAX_CACHE_SIZE_LOG2  = 16,
MAX_CACHE_SIZE       = (1 << MAX_CACHE_SIZE_LOG2),
```

- 如果加上当前方法，所存储的容量超过`3/4`，就进行两倍扩容。最大不容量不超过`1<<16`的大小
- 通过`reallocate`分配新的内存。

### 存储方法

- 当容量足以存放该缓存，则进入存储方法阶段

```c++
// 拿到指向第一个bucket的首地址
bucket_t *b = buckets();
mask_t m = capacity - 1;

// 通过hash求出适当的存储位置
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
} while (fastpath((i = cache_next(i, m)) != begin)); // 如果当前位置不合适，产生hash冲突，接着寻找下一个位置

bad_cache(receiver, (SEL)sel);
```

- 存储方法时，主要分为以下几个部分：
  1. 获取到存储方法缓存的首地址，也就是通过`buckets()`
  2. 然后计算出合适的存储位置，存储方法
  3. 未找到合适位置，则说明该缓存区域有问题。调用`bad_cache`方法

#### cache_hash和cache_next

- 我们看一下它是如何计算存储位置

```c++
static inline mask_t cache_hash(SEL sel, mask_t mask) 
{
    uintptr_t value = (uintptr_t)sel;
#if CONFIG_USE_PREOPT_CACHES
    value ^= value >> 7;
#endif
    return (mask_t)(value & mask);
}
```

- 通过`sel`与`mask`进行与操作，算出对应位置，接着我们需要去判断该位置是否可用。

```c++
do {
    if (fastpath(b[i].sel() == 0)) { // 如果该位置为空，则存储
        incrementOccupied();
        b[i].set<Atomic, Encoded>(b, sel, imp, cls());
        return;
    }
    if (b[i].sel() == sel) { // 如果该位置不为空，则继续循环
        return;
    }
} while (fastpath((i = cache_next(i, m)) != begin));
```

- 如果当前位置是空的，则直接存储，否则通过`cache_next`方法去寻找下一个位置，解决哈希冲突

```c++
static inline mask_t cache_next(mask_t i, mask_t mask) {
    return i ? i-1 : mask;
}
```

- 该方法中向前寻找合适的位置。

#### 存储方法

- 找到合适的位置了，可以把该方法写入缓存中。

```c++
if (fastpath(b[i].sel() == 0)) {
    incrementOccupied();
    b[i].set<Atomic, Encoded>(b, sel, imp, cls());
    return;
}
```

- 第一步需要把占用空间+1，该变量记录了当前有多少缓存的方法

```c++
void cache_t::incrementOccupied() 
{
    _occupied++;
}
```

- 接着把方法写入缓存中

```c++
template<Atomicity atomicity, IMPEncoding impEncoding>
void bucket_t::set(bucket_t *base, SEL newSel, IMP newImp, Class cls)
{
    ASSERT(_sel.load(memory_order_relaxed) == 0 ||
           _sel.load(memory_order_relaxed) == newSel);

    // 对imp进行编码
    uintptr_t newIMP = (impEncoding == Encoded
                        ? encodeImp(base, newImp, newSel, cls)
                        : (uintptr_t)newImp);

    if (atomicity == Atomic) {
        // 把编码后imp存储到bucket中_imp中。
        _imp.store(newIMP, memory_order_relaxed);
        
        // 再把sel存储到bucket中_sel中。
        if (_sel.load(memory_order_relaxed) != newSel) {
#ifdef __arm__
            mega_barrier();
            _sel.store(newSel, memory_order_relaxed);
#elif __x86_64__ || __i386__
            _sel.store(newSel, memory_order_release);
#else
#error Don't know how to do bucket_t::set on this architecture.
#endif
        }
    } else {
        _imp.store(newIMP, memory_order_relaxed);
        _sel.store(newSel, memory_order_relaxed);
    }
}
```

- 先对`imp`进行编码，然后把编码后的`imp`和`sel`，存储到`bucket`中

### 总结

- 方法缓存是存储在一块连续空间中，通过哈希的方式存储。
- 首次开辟连续内存为4，如果当前容量已经占用`3/4`，则按照原来的2倍进行扩容。扩容时，会丢弃原来缓存方法，只存储最新一次的方法。
- 空间够用的情况下，通过`cache_hash`方法计算合适的下标，如果该位置冲突了，则通过`cache_next`方法继续循环找到合适位置