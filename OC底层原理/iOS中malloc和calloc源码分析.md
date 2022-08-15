- [iOS中malloc和calloc源码分析](#ios中malloc和calloc源码分析)
	- [calloc](#calloc)
		- [1. calloc](#1-calloc)
		- [2. _malloc_zone_calloc](#2-_malloc_zone_calloc)
		- [3. default_zone_calloc](#3-default_zone_calloc)
		- [4. nano_calloc](#4-nano_calloc)
		- [5. _nano_malloc_check_clear](#5-_nano_malloc_check_clear)
			- [segregated_size_to_fit](#segregated_size_to_fit)
			- [OSAtomicDequeue或者segregated_next_block](#osatomicdequeue或者segregated_next_block)
			- [memset(ptr, 0, slot_bytes)](#memsetptr-0-slot_bytes)
	- [malloc](#malloc)
		- [1. malloc](#1-malloc)
		- [2. _malloc_zone_malloc](#2-_malloc_zone_malloc)
		- [3. default_zone_malloc](#3-default_zone_malloc)
		- [4. nano_malloc](#4-nano_malloc)
	- [总结](#总结)
# iOS中malloc和calloc源码分析

## calloc

- 我们知道在`iOS`创建对象的`alloc`方法中，最终通过调用`calloc`方法来开辟内存。如果这里具体流程不够清楚的话，可以参考[Runtime源码分析-alloc](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/Runtime/1.%20Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-alloc/Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-alloc.md)
- 那么`calloc`具体是如何实现的呢？由于在`objc4`中没有提供该方法，我们通过`libmalloc-317.40.8`代码去研究。

### 1. calloc

- 首先进入`calloc`方法

```objective-c
void *
calloc(size_t num_items, size_t size)
{
	return _malloc_zone_calloc(default_zone, num_items, size, MZ_POSIX);
}
```

- 内部调用了`_malloc_zone_calloc()`方法

### 2. _malloc_zone_calloc

```objective-c
MALLOC_NOINLINE
static void *
_malloc_zone_calloc(malloc_zone_t *zone, size_t num_items, size_t size,
		malloc_zone_options_t mzo)
{
	MALLOC_TRACE(TRACE_calloc | DBG_FUNC_START, (uintptr_t)zone, num_items, size, 0);

	void *ptr;
	if (malloc_check_start) {
		internal_check();
	}
    // ptr指针指向一块内存
	ptr = zone->calloc(zone, num_items, size);

	if (os_unlikely(malloc_logger)) {
		malloc_logger(MALLOC_LOG_TYPE_ALLOCATE | MALLOC_LOG_TYPE_HAS_ZONE | MALLOC_LOG_TYPE_CLEARED, (uintptr_t)zone,
				(uintptr_t)(num_items * size), 0, (uintptr_t)ptr, 0);
	}

	MALLOC_TRACE(TRACE_calloc | DBG_FUNC_END, (uintptr_t)zone, num_items, size, (uintptr_t)ptr);
	if (os_unlikely(ptr == NULL)) {
		malloc_set_errno_fast(mzo, ENOMEM);
	}
	return ptr;
}
```

- 该方法中最终返回结果是一个指针，所以最重要的是13行。它创建了一块内存，并让`ptr`指向它。

- 这个时候，我们点击`zone->calloc`跳转对应的实现，发现点不进去。这个时候才用汇编方式，看到该方法最终跳转至`default_zone_calloc`方法

### 3. default_zone_calloc

```objective-c
static void *
default_zone_calloc(malloc_zone_t *zone, size_t num_items, size_t size)
{
	zone = runtime_default_zone();
	
	return zone->calloc(zone, num_items, size);
}
```

- 该方法内部调用 `zone->calloc`方法，仍然点不进去。再次使用汇编方法，发现该方法跳转至`nano_calloc`

### 4. nano_calloc

```objective-c
static void *
nano_calloc(nanozone_t *nanozone, size_t num_items, size_t size)
{
	size_t total_bytes;

	if (calloc_get_size(num_items, size, 0, &total_bytes)) {
		return NULL;
	}

	if (total_bytes <= NANO_MAX_SIZE) {
		void *p = _nano_malloc_check_clear(nanozone, total_bytes, 1);
		if (p) {
			return p;
		} else {
			/* FALLTHROUGH to helper zone */
		}
	}
	malloc_zone_t *zone = (malloc_zone_t *)(nanozone->helper_zone);
	return zone->calloc(zone, 1, total_bytes);
}
```

- 此处我们还是先看返回值，发现有三处返回。第一处直接返回`NULL`，这肯定不是我们需要的答案，直接忽略。剩下两处，无法确定。这个时候通过断点调试，发现一般情况走的是`_nano_malloc_check_clear`方法

### 5. _nano_malloc_check_clear

```objective-c
static void *
_nano_malloc_check_clear(nanozone_t *nanozone, size_t size, boolean_t cleared_requested)
{
	MALLOC_TRACE(TRACE_nano_malloc, (uintptr_t)nanozone, size, cleared_requested, 0);

	void *ptr;
	size_t slot_key;
    // 1. 计算合适的内存大小
	size_t slot_bytes = segregated_size_to_fit(nanozone, size, &slot_key); // Note slot_key is set here
	mag_index_t mag_index = nano_mag_index(nanozone);

	nano_meta_admin_t pMeta = &(nanozone->meta_data[mag_index][slot_key]);

    // 2. 开辟一片内存，并让ptr指针指向这块内存
	ptr = OSAtomicDequeue(&(pMeta->slot_LIFO), offsetof(struct chained_block_s, next));
	if (ptr) {
		unsigned debug_flags = nanozone->debug_flags;
#if NANO_FREE_DEQUEUE_DILIGENCE
		size_t gotSize;
		nano_blk_addr_t p; // the compiler holds this in a register

		p.addr = (uint64_t)ptr; // Begin the dissection of ptr
		if (NANOZONE_SIGNATURE != p.fields.nano_signature) {
			malloc_zone_error(debug_flags, true,
					"Invalid signature for pointer %p dequeued from free list\n",
					ptr);
		}

		if (mag_index != p.fields.nano_mag_index) {
			malloc_zone_error(debug_flags, true,
					"Mismatched magazine for pointer %p dequeued from free list\n",
					ptr);
		}

		gotSize = _nano_vet_and_size_of_free(nanozone, ptr);
		if (0 == gotSize) {
			malloc_zone_error(debug_flags, true,
					"Invalid pointer %p dequeued from free list\n", ptr);
		}
		if (gotSize != slot_bytes) {
			malloc_zone_error(debug_flags, true,
					"Mismatched size for pointer %p dequeued from free list\n",
					ptr);
		}

		if (!_nano_block_has_canary_value(nanozone, ptr)) {
			malloc_zone_error(debug_flags, true,
					"Heap corruption detected, free list canary is damaged for %p\n"
					"*** Incorrect guard value: %lu\n", ptr,
					((chained_block_t)ptr)->double_free_guard);
		}

#if defined(DEBUG)
		void *next = (void *)(((chained_block_t)ptr)->next);
		if (next) {
			p.addr = (uint64_t)next; // Begin the dissection of next
			if (NANOZONE_SIGNATURE != p.fields.nano_signature) {
				malloc_zone_error(debug_flags, true,
						"Invalid next signature for pointer %p dequeued from free "
						"list, next = %p\n", ptr, "next");
			}

			if (mag_index != p.fields.nano_mag_index) {
				malloc_zone_error(debug_flags, true,
						"Mismatched next magazine for pointer %p dequeued from "
						"free list, next = %p\n", ptr, next);
			}

			gotSize = _nano_vet_and_size_of_free(nanozone, next);
			if (0 == gotSize) {
				malloc_zone_error(debug_flags, true,
						"Invalid next for pointer %p dequeued from free list, "
						"next = %p\n", ptr, next);
			}
			if (gotSize != slot_bytes) {
				malloc_zone_error(debug_flags, true,
						"Mismatched next size for pointer %p dequeued from free "
						"list, next = %p\n", ptr, next);
			}
		}
#endif /* DEBUG */
#endif /* NANO_FREE_DEQUEUE_DILIGENCE */

		((chained_block_t)ptr)->double_free_guard = 0;
		((chained_block_t)ptr)->next = NULL; // clear out next pointer to protect free list
	} else {
        // 如果ptr指针为空，则去去找下一块合适内存
		ptr = segregated_next_block(nanozone, pMeta, slot_bytes, mag_index);
	}
	
    // 3. 是否给内存进行初始化
	if (cleared_requested && ptr) {
		memset(ptr, 0, slot_bytes); // TODO: Needs a memory barrier after memset to ensure zeroes land first?
	}
	return ptr;
}
```

- 该方法中，它主要干了三件事：
  1. `segregated_size_to_fit`：计算需要开辟的内存大小
  2. `OSAtomicDequeue`或者`segregated_next_block`：开辟内存
  3. `memset(ptr, 0, slot_bytes);`：是否进行初始化

#### segregated_size_to_fit

```objective-c
static MALLOC_INLINE size_t
segregated_size_to_fit(nanozone_t *nanozone, size_t size, size_t *pKey)
{
	size_t k, slot_bytes;

	if (0 == size) {
		size = NANO_REGIME_QUANTA_SIZE; // Historical behavior
	}
    // 内存按照16字节对齐
    // k = (size + 16 - 1) >> 4 右移4位
	k = (size + NANO_REGIME_QUANTA_SIZE - 1) >> SHIFT_NANO_QUANTUM; // round up and shift for number of quanta
    // slot_bytes = k << 4 左移4位
	slot_bytes = k << SHIFT_NANO_QUANTUM;							// multiply by power of two quanta size
	*pKey = k - 1;													// Zero-based!

	return slot_bytes;
}
```

- 这里主要是内存对齐算法，算法流程是：
  1. 当前size + 15，左移4位
  2. 再把上面的值，右移4位
- 具体计算过程如下：假设`size`为8字节
  1. `(size + NANO_REGIME_QUANTA_SIZE - 1)` = 8 + 15 = 23，用二进制表示：0001 0111
  2. `k >> SHIFT_NANO_QUANTUM`，用二进制表示：0000 0001
  3. `k << SHIFT_NANO_QUANTUM`，用二进制表示：0001 0000
  4. 最终结果是16字节，实现了按照16字节对齐。

#### OSAtomicDequeue或者segregated_next_block

- 首先会通过`OSAtomicDequeue`方法来开辟内存
  - 如果开辟成功，则返回内存首地址给`ptr`。然后对ptr进行一系列的验证
  - 如果开辟失败，则通过`segregated_next_block`方法进行再次尝试开辟

```objective-c
static MALLOC_INLINE void *
segregated_next_block(nanozone_t *nanozone, nano_meta_admin_t pMeta, size_t slot_bytes, unsigned int mag_index)
{
	while (1) {
        // 当前这块pMeta可用内存结束地址
		uintptr_t theLimit = pMeta->slot_limit_addr; // Capture the slot limit that bounds slot_bump_addr right now
		uintptr_t b = OSAtomicAdd64Barrier(slot_bytes, (volatile int64_t *)&(pMeta->slot_bump_addr));
        // 减去添加的偏移量，获取当前可以获取的地址
		b -= slot_bytes; 

		if (b < theLimit) {   // Did we stay within the bound of the present slot allocation?
            // 如果地址还在范围之内，则返回地址
			return (void *)b; 
		} else {
            // pMeta这块内存已经用完了
			if (pMeta->slot_exhausted) {
				pMeta->slot_bump_addr = theLimit;
				return 0;				 // We're toast
			} else {
				// One thread will grow the heap, others will see its been grown and retry allocation
				_malloc_lock_lock(&nanozone->band_resupply_lock[mag_index]);
				// 由于多线程，这里再次进行检查是否用完
				if (pMeta->slot_exhausted) {
					_malloc_lock_unlock(&nanozone->band_resupply_lock[mag_index]);
					return 0; // Toast
				} else if (b < pMeta->slot_limit_addr) {
                    // 如果小于最大限制地址，当重新申请一个新的band后，重新尝试while
					_malloc_lock_unlock(&nanozone->band_resupply_lock[mag_index]);
					continue; 
				} else if (segregated_band_grow(nanozone, pMeta, slot_bytes, mag_index)) {
                    // 申请新的band成功，重新尝试while
					_malloc_lock_unlock(&nanozone->band_resupply_lock[mag_index]);
					continue; 
				} else {
					pMeta->slot_exhausted = TRUE;
					pMeta->slot_bump_addr = theLimit;
					_malloc_lock_unlock(&nanozone->band_resupply_lock[mag_index]);
					return 0;
				}
			}
		}
	}
}
```

- 该方法里面主要是去堆上获取一块合适的内存。

#### memset(ptr, 0, slot_bytes)

- 根据传入`cleared_requested`参数，来决定是否给内存初始化为0

## malloc

- 在底层中，除了常用的`alloc`方法之外，还有`malloc`也经常使用。我们看一下实现，发现具体有什么区别。

### 1. malloc

```objective-c
void *
malloc(size_t size)
{
	return _malloc_zone_malloc(default_zone, size, MZ_POSIX);
}
```

- 内部调用了`_malloc_zone_malloc()`方法

### 2. _malloc_zone_malloc

```objc
MALLOC_NOINLINE
static void *
_malloc_zone_malloc(malloc_zone_t *zone, size_t size, malloc_zone_options_t mzo)
{
	MALLOC_TRACE(TRACE_malloc | DBG_FUNC_START, (uintptr_t)zone, size, 0, 0);

	void *ptr = NULL;

	if (malloc_check_start) {
		internal_check();
	}
	if (size > MALLOC_ABSOLUTE_MAX_SIZE) {
		goto out;
	}

	ptr = zone->malloc(zone, size);		// if lite zone is passed in then we still call the lite methods

	if (os_unlikely(malloc_logger)) {
		malloc_logger(MALLOC_LOG_TYPE_ALLOCATE | MALLOC_LOG_TYPE_HAS_ZONE, (uintptr_t)zone, (uintptr_t)size, 0, (uintptr_t)ptr, 0);
	}

	MALLOC_TRACE(TRACE_malloc | DBG_FUNC_END, (uintptr_t)zone, size, (uintptr_t)ptr, 0);
out:
	if (os_unlikely(ptr == NULL)) {
		malloc_set_errno_fast(mzo, ENOMEM);
	}
	return ptr;
}
```

- 该方法中最终返回结果是一个指针，所以最重要的是16行。它创建了一块内存，并让`ptr`指向它。
- 这个时候点击它的实现，发现也跳转不进去。这个时候还是使用汇编手段，可以得知它调用`default_zone_malloc`方法

### 3. default_zone_malloc

```objc
static void *
default_zone_malloc(malloc_zone_t *zone, size_t size)
{
	zone = runtime_default_zone();
	
	return zone->malloc(zone, size);
}
```

- 该方法调用`zone->malloc`方法，仍然点不进去，继续查看汇编。发现调用了`nano_malloc`方法

### 4. nano_malloc

```objective-c
static void *
nano_malloc(nanozone_t *nanozone, size_t size)
{
	if (size <= NANO_MAX_SIZE) {
		void *p = _nano_malloc_check_clear(nanozone, size, 0);
		if (p) {
			return p;
		} else {
			/* FALLTHROUGH to helper zone */
		}
	}

	malloc_zone_t *zone = (malloc_zone_t *)(nanozone->helper_zone);
	return zone->malloc(zone, size);
}
```

- 这里有两处返回值，通过断点调试得知一般走`_nano_malloc_check_clear`方法
- 看到这个方法有没有一丝丝熟悉？原来它开辟内存调用的方法和`calloc`调用的是同一个方法。此处仔细对比发现，虽然是调用同一个方法，但是参数穿的不同

```objc
// calloc中
void *p = _nano_malloc_check_clear(nanozone, total_bytes, 1);
// malloc中
void *p = _nano_malloc_check_clear(nanozone, size, 0);

static void *
_nano_malloc_check_clear(nanozone_t *nanozone, size_t size, boolean_t cleared_requested)
```

- 发现`cleared_requested`这个参数传的不同。`calloc`是1，`malloc`是0。那个这个参数有什么作用？
- 我们进入这个方法，发现以下实现

```objc
if (cleared_requested && ptr) {
    memset(ptr, 0, slot_bytes);
}
```

- 原来是对开辟的内存进行初始化。`calloc`会对它初始化，`malloc`不会对它初始化

## 总结

- 我们最终可以得出以下结论

1. `malloc`和`calloc`其实底层都调用的同一套开辟内存方法
2. 不同在于，`calloc`在开辟完内存会进行初始化，`malloc`不会进行初始化，则是原始脏数据。如果需要使用`malloc`这块内存，还需要我们手动初始化