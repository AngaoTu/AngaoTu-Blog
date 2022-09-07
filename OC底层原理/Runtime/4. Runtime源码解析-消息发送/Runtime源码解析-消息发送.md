[toc]

# Runtime源码解析-消息发送

- 在我们平时开发项目中，除了频繁的创建对象之外，用的最多的就是调用方法。本篇文章就是主要研究方法是如何调用的。

## 前言

- 在 `Objective-C `中的“方法调用”其实应该叫做消息传递
  - 我们为什么需要消息传递？
  - 在很多语言，比如 C ，调用一个方法其实就是跳到内存中的某一点并开始执行一段代码。没有任何动态的特性，因为这在编译时就决定好了。而在 `Objective-C` 中，`[object foo]` 语法并不会立即执行 `foo `这个方法的代码。它是在运行时给` object` 发送一条叫 `foo` 的消息。这个消息，也许会由 `object `来处理，也许会被转发给另一个对象，或者不予理睬假装没收到这个消息。多条不同的消息也可以对应同一个方法实现，这些都是在程序运行的时候决定的。
- 在底层中，`[receiver message]`会被翻译为 `objc_msgSend(receiver, @selector(message))`。也就是通过`objc_msgSend()`方法进行调用。

## objc_msgSend

- 在`libobjc`中，该方法是通过汇编实现的，我们可以在`objc-msg-arm64.s`找到对应的实现。

```assembly
	ENTRY _objc_msgSend
	UNWIND _objc_msgSend, NoFrame
	# 1. 判断receiver是否为nil
	cmp	p0, #0			// nil check and tagged pointer check
#if SUPPORT_TAGGED_POINTERS
	b.le	LNilOrTagged		//  (MSB tagged pointer looks negative)
#else
	b.eq	LReturnZero
#endif
	# 2. 获取isa和对应class
	ldr	p13, [x0]		// p13 = isa
	GetClassFromIsa_p16 p13, 1, x0	// p16 = class
LGetIsaDone:
	# 3. 去缓存中查找方法
	// calls imp or objc_msgSend_uncached
	CacheLookup NORMAL, _objc_msgSend, __objc_msgSend_uncached

#if SUPPORT_TAGGED_POINTERS
LNilOrTagged:
	b.eq	LReturnZero		// nil check
	GetTaggedClass
	b	LGetIsaDone
// SUPPORT_TAGGED_POINTERS
#endif

LReturnZero:
	// x0 is already zero
	mov	x1, #0
	movi	d0, #0
	movi	d1, #0
	movi	d2, #0
	movi	d3, #0
	ret

	END_ENTRY _objc_msgSend
```

- 该方法中主要有以下几个步骤
  1. 首先判断消息接收者是否为空，如果为空的话，则跳转至`LReturnZero`方法，直接退出该方法
  2. 去获取该对象的`isa`，并且通过`isa`获取对应的`class`
  3. 去缓存中查找方法

### CacheLookup 缓存查找

- 该方法需要类中`cache_t`的结构，如果对这块不够熟悉，请先阅读[Runtime源码解析-类中cache](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/Runtime/3.%20Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-%E7%B1%BB/Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-%E7%B1%BB%E4%B8%ADcache.md)
- 我们查看一下`CacheLookup`的实现

```assembly
.macro CacheLookup Mode, Function, MissLabelDynamic, MissLabelConstant
	mov	x15, x16			// stash the original isa
LLookupStart\Function:
	// p1 = SEL, p16 = isa
#if CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16_BIG_ADDRS
	ldr	p10, [x16, #CACHE]				// p10 = mask|buckets
	lsr	p11, p10, #48			// p11 = mask
	and	p10, p10, #0xffffffffffff	// p10 = buckets
	and	w12, w1, w11			// x12 = _cmd & mask
#elif CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16 // arm64系统
	# 1. 把isa地址移动16个字节，找到其中cache_t地址
	ldr	p11, [x16, #CACHE]			// p11 = mask|buckets
#if CONFIG_USE_PREOPT_CACHES
#if __has_feature(ptrauth_calls)
	tbnz	p11, #0, LLookupPreopt\Function
	and	p10, p11, #0x0000ffffffffffff	// p10 = buckets
#else
	# 2. 获取buckets的首地址
	# p10 = _bucketsAndMaybeMask & 0x0000fffffffffffe
	and	p10, p11, #0x0000fffffffffffe	// p10 = buckets
	tbnz	p11, #0, LLookupPreopt\Function
#endif
	# 3. 获取传入_cmd的哈希值
	eor	p12, p1, p1, LSR #7
	and	p12, p12, p11, LSR #48		// x12 = (_cmd ^ (_cmd >> 7)) & mask
#else
	and	p10, p11, #0x0000ffffffffffff	// p10 = buckets
	and	p12, p1, p11, LSR #48		// x12 = _cmd & mask
#endif // CONFIG_USE_PREOPT_CACHES
#elif CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_LOW_4
	ldr	p11, [x16, #CACHE]				// p11 = mask|buckets
	and	p10, p11, #~0xf			// p10 = buckets
	and	p11, p11, #0xf			// p11 = maskShift
	mov	p12, #0xffff
	lsr	p11, p12, p11			// p11 = mask = 0xffff >> p11
	and	p12, p1, p11			// x12 = _cmd & mask
#else
#error Unsupported cache mask storage for ARM64.
#endif
	
	# 4. 去缓存中去查找方法
	add	p13, p10, p12, LSL #(1+PTRSHIFT)
						// p13 = buckets + ((_cmd & mask) << (1+PTRSHIFT))
						
						// do {
1:	ldp	p17, p9, [x13], #-BUCKET_SIZE	//     {imp, sel} = *bucket--
	cmp	p9, p1				//     if (sel != _cmd) {
	b.ne	3f				//         scan more
						//     } else {
2:	CacheHit \Mode				// hit:    call or return imp
						//     }
3:	cbz	p9, \MissLabelDynamic		//     if (sel == 0) goto Miss;
	cmp	p13, p10			// } while (bucket >= buckets)
	b.hs	1b


#if CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16_BIG_ADDRS
	add	p13, p10, w11, UXTW #(1+PTRSHIFT)
						// p13 = buckets + (mask << 1+PTRSHIFT)
#elif CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16
	add	p13, p10, p11, LSR #(48 - (1+PTRSHIFT))
						// p13 = buckets + (mask << 1+PTRSHIFT)
						// see comment about maskZeroBits
#elif CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_LOW_4
	add	p13, p10, p11, LSL #(1+PTRSHIFT)
						// p13 = buckets + (mask << 1+PTRSHIFT)
#else
#error Unsupported cache mask storage for ARM64.
#endif
	add	p12, p10, p12, LSL #(1+PTRSHIFT)
						// p12 = first probed bucket

						// do {
4:	ldp	p17, p9, [x13], #-BUCKET_SIZE	//     {imp, sel} = *bucket--
	cmp	p9, p1				//     if (sel == _cmd)
	b.eq	2b				//         goto hit
	cmp	p9, #0				// } while (sel != 0 &&
	ccmp	p13, p12, #0, ne		//     bucket > first_probed)
	b.hi	4b

# 省略部分实现

.endmacro
```

- 该方法内部主要做了一下几件事
  1. 通过`isa`指针，获取`cache_t`结构的地址
  2. 通过`cache_t`的地址，获取`buckets`的首地址
  3. 计算传入`_cmd`的哈希值，用作查询起始位置
  4. 循环遍历`buckets`，找到对应方法实现
- 这里我们主要讨论`arm64`下的实现，也就是条件判断中`CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16`

#### 1. 获取cache_t

```assembly
ldr	p11, [x16, #CACHE]			// p11 = mask|buckets
```

- 在`objc_class`结构中，`cache_t`相对首地址偏移16个字节
- 这里`x16`存储了`isa`地址，然后偏移16个字节，把得到的`cache_t`地址存储在`p11`寄存器中

#### 2. 获取buckets

```assembly
#if CONFIG_USE_PREOPT_CACHES
    #if __has_feature(ptrauth_calls) 
        tbnz	p11, #0, LLookupPreopt\Function
        and	p10, p11, #0x0000ffffffffffff	// p10 = buckets
    #else // 真机，走下面
        and	p10, p11, #0x0000fffffffffffe	// p10 = buckets
        tbnz	p11, #0, LLookupPreopt\Function
    #endif
	eor	p12, p1, p1, LSR #7
	and	p12, p12, p11, LSR #48		// x12 = (_cmd ^ (_cmd >> 7)) & mask
#else
	and	p10, p11, #0x0000ffffffffffff	// p10 = buckets
	and	p12, p1, p11, LSR #48		// x12 = _cmd & mask
#endif // CONFIG_USE_PREOPT_CACHES
```

- `p11 = cache_t的地址`，`cache_t`内部第一个元素是`_bucketsAndMaybeMask`。然后把`cacht_t(_bucketsAndMaybeMask) & 0x0000fffffffffffe`，就得到了`buckets`的首地址。

#### 3. 计算_cmd哈希值

```assembly
eor	p12, p1, p1, LSR #7
and	p12, p12, p11, LSR #48		// x12 = (_cmd ^ (_cmd >> 7)) & mask
```

- 其中`eor`是异或，`p1 = _cmd`。`p12 = p1^(p1 >> 7) = _cmd^(_cmd >> 7) `。这是我们在存储方法时，采用的`encode`方法。具体实现可以查看前面提到`cache`文章。这样就得到`_cmd`编码后的值
- `LSR`表示逻辑向右偏移，`p11, LSR #48`把`_bucketsAndMaybeMask`偏移48位，拿到前16位，得到`mask`的值
- `and`表示与，把编码后的`_cmd` & `mask`，就得到了需要查询方法对应的哈希值。

#### 4. 遍历查询

- 接着就可以进行查询过程

```assembly
add	p13, p10, p12, LSL #(1+PTRSHIFT)
						// p13 = buckets + ((_cmd & mask) << (1+PTRSHIFT))

# 流程1
						// do {
1:	ldp	p17, p9, [x13], #-BUCKET_SIZE	//     {imp, sel} = *bucket--
	cmp	p9, p1				//     if (sel != _cmd) {
	b.ne	3f				//         scan more
						//     } else {
# 流程2
2:	CacheHit \Mode				// hit:    call or return imp
						//     }
# 流程3
3:	cbz	p9, \MissLabelDynamic		//     if (sel == 0) goto Miss;
	cmp	p13, p10			// } while (bucket >= buckets)
	b.hs	1b


# 向前查询到首位置，没有找到合适的方法。跳转至最后一个元素，接着查询
#if CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16_BIG_ADDRS
	add	p13, p10, w11, UXTW #(1+PTRSHIFT)
						// p13 = buckets + (mask << 1+PTRSHIFT)
#elif CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16
	// mask = capacity - 1，开辟内存容量-1.找到最后一个bucket的位置
	add	p13, p10, p11, LSR #(48 - (1+PTRSHIFT))
						// p13 = buckets + (mask << 1+PTRSHIFT)
						// see comment about maskZeroBits
#elif CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_LOW_4
	add	p13, p10, p11, LSL #(1+PTRSHIFT)
						// p13 = buckets + (mask << 1+PTRSHIFT)
#else
#error Unsupported cache mask storage for ARM64.
#endif
	add	p12, p10, p12, LSL #(1+PTRSHIFT)
						// p12 = first probed bucket

# 流程4
						// do {
4:	ldp	p17, p9, [x13], #-BUCKET_SIZE	//     {imp, sel} = *bucket--
	cmp	p9, p1				//     if (sel == _cmd)
	b.eq	2b				//         goto hit
	cmp	p9, #0				// } while (sel != 0 &&
	ccmp	p13, p12, #0, ne		//     bucket > first_probed)
	b.hi	4b

# 没有找到
LLookupEnd\Function:
LLookupRecover\Function:
	b	\MissLabelDynamic
```

1. 通过下标`index`获取对应的bucket。`p13 = buckets + ((_cmd & mask) << (1+PTRSHIFT))`
2. 获取对应的`bucket`，然后取出`imp`和`sel`分别存放到`p17`和`p9`中，并且`bucket--`。原因是方法缓存在存储的时候，采用的是向前插入。
   1. 流程1:比较当前`bucket`的`sel`和传入的`_cmd`是否相同，
      1. 如果不同则跳转至流程3
      2. 如果相同则走流程2，`CacheHit`。
   2. 流程2: `CacheHit`：表示缓存命中，直接返回该方法
   3. 流程3：
      1. 首先判断当前`sel`是否为`nil`，如果为空，说明没有找到缓存方法，跳转至`MissLabelDynamic`，走`__objc_msgSend_uncached`流程。下面篇章具体讲解。
      2. 如果当前`sel`不是我们需要找的，则去找下一个，直到找到第一个存储位置。如果循环到第一个`bucket`都没有找到对应的方法。则跳转至最后一个元素接着向前查找
   4. 流程4:从最后一个元素，开始向前查找
      1. 如果找到了，就跳转至流程2
      2. 如果没有找到，则向前查找，直到查询到我们首次哈希计算的下标值。

3. 一直没有找到，最后走到`MissLabelDynamic`，也就是`__objc_msgSend_uncached`流程。

### __objc_msgSend_uncached

- 在上面我们会去类中的缓存查找方法的实现，如果该方法没有添加到缓存中就会调用`__objc_msgSend_uncached`方法。我们继续查看一下，没有命中缓存是如何查询方法的

```assembly
STATIC_ENTRY __objc_msgSend_uncached
UNWIND __objc_msgSend_uncached, FrameWithNoSaves

// THIS IS NOT A CALLABLE C FUNCTION
// Out-of-band p15 is the class to search

MethodTableLookup
TailCallFunctionPointer x17

END_ENTRY __objc_msgSend_uncached
```

- 里面就只有两个方法，一个是`MethodTableLookup`，另一个是`TailCallFunctionPointer`。我们先进入`TailCallFunctionPointer`实现。

```assembly
.macro TailCallFunctionPointer
	// $0 = function pointer value
	braaz	$0
.endmacro
```

- 发现它仅仅是指返回传入的地址，并跳转过去。并没有做查询操作，所以这并不是我们需要关心的方法。那我们就查看一下`MethodTableLookup`的实现

```assembly
.macro MethodTableLookup
	
	SAVE_REGS MSGSEND

	// lookUpImpOrForward(obj, sel, cls, LOOKUP_INITIALIZE | LOOKUP_RESOLVER)
	// receiver and selector already in x0 and x1
	mov	x2, x16
	mov	x3, #3
	bl	_lookUpImpOrForward

	// IMP in x0
	mov	x17, x0

	RESTORE_REGS MSGSEND

.endmacro
```

- 发现该方法中，通过`_lookUpImpOrForward`来查询到具体`imp`。我们接着全局搜索发现没有它的定义，这个时候我们去掉下划线，就发现了结果。由于汇编函数会比c++函数多一个下划线。

#### lookUpImpOrForward

```c++
NEVER_INLINE
IMP lookUpImpOrForward(id inst, SEL sel, Class cls, int behavior)
{
    const IMP forward_imp = (IMP)_objc_msgForward_impcache;
    IMP imp = nil;
    Class curClass;

    runtimeLock.assertUnlocked();

    // 判断类是否初始化
    if (slowpath(!cls->isInitialized())) {...}


    runtimeLock.lock();

 	// 1. 是否把类注册到内存中
    checkIsKnownClass(cls);
	// 2. 初始化当前类和父类
    cls = realizeAndInitializeIfNeeded_locked(inst, cls, behavior & LOOKUP_INITIALIZE);
    // runtimeLock may have been dropped but is now locked again
    runtimeLock.assertLocked();
    curClass = cls;
	
    // 3. 开始查询方法。需要先再次查找缓存，如果没找到在开始去类中查询
    for (unsigned attempts = unreasonableClassCount();;) {
        // 判断缓存中是否存在
        if (curClass->cache.isConstantOptimizedCache(/* strict */true)) {
#if CONFIG_USE_PREOPT_CACHES
            imp = cache_getImp(curClass, sel);
            if (imp) goto done_unlock;
            curClass = curClass->cache.preoptFallbackClass();
#endif
        } else {
			// 在当前类中查找方法
            method_t *meth = getMethodNoSuper_nolock(curClass, sel);
            if (meth) {
                imp = meth->imp(false);
                goto done;
            }
			
			// curClass = curClass->getSuperclass() 直到为nil走if里面的流程，不为nil走下面流程
            if (slowpath((curClass = curClass->getSuperclass()) == nil)) {
                // No implementation found, and method resolver didn't help.
                // Use forwarding.
                imp = forward_imp;
                break;
            }
        }

        // Halt if there is a cycle in the superclass chain.
        if (slowpath(--attempts == 0)) {
            _objc_fatal("Memory corruption in class list.");
        }

        // Superclass cache.
        // 去父类的缓存中查找
        imp = cache_getImp(curClass, sel);
        if (slowpath(imp == forward_imp)) {
            // Found a forward:: entry in a superclass.
            // Stop searching, but don't cache yet; call method
            // resolver for this class first.
            break;
        }
        if (fastpath(imp)) {
            // Found the method in a superclass. Cache it in this class.
            goto done;
        }
    }

    // No implementation found. Try method resolver once.
	// 4. 如果没有找到实现，调用resolveMethod_locked来去实现
    if (slowpath(behavior & LOOKUP_RESOLVER)) {
        behavior ^= LOOKUP_RESOLVER;
        return resolveMethod_locked(inst, sel, cls, behavior);
    }

 // 5. 方法找到
 done:
    if (fastpath((behavior & LOOKUP_NOCACHE) == 0)) {
#if CONFIG_USE_PREOPT_CACHES
        while (cls->cache.isConstantOptimizedCache(/* strict */true)) {
            cls = cls->cache.preoptFallbackClass();
        }
#endif
        log_and_fill_cache(cls, imp, sel, inst, curClass);
    }
 done_unlock:
    runtimeLock.unlock();
    if (slowpath((behavior & LOOKUP_NIL) && imp == forward_imp)) {
        return nil;
    }
    return imp;
}
```

- 该方法主要做了以下几件事
  1. 判断类是否加载到内存中
  2. 对应的类和元类、以及对应的父类是否初始化完毕，为接下来有可能到父类中查询做准备
  3. 开始查询方法。需要先查找缓存，如果没找到再开始去类中查询，如果当前类没有，则去它的父类去查询，如果找到方法了，则跳转至`done`。
  4. 如果没有找到
     1. 首次的话，系统会调用`resolveMethod_locked`给你一次机会，判断是否有动态方法决议。
     2. 非首次的话，则直接返回`forward_imp`
  5. 方法找到

##### 1. 判断类是否加载到内存中

```c++
ALWAYS_INLINE
static void
checkIsKnownClass(Class cls)
{
    if (slowpath(!isKnownClass(cls))) {
        _objc_fatal("Attempt to use unknown class %p.", cls);
    }
}
```

- 通过`isKnownClass`来判断

```c++
ALWAYS_INLINE
static bool
isKnownClass(Class cls)
{
    if (fastpath(objc::dataSegmentsRanges.contains(cls->data()->witness, (uintptr_t)cls))) {
        return true;
    }
    auto &set = objc::allocatedClasses.get();
    return set.find(cls) != set.end() || dataSegmentsContain(cls);
}
```

- 通过全局`allocatedClasses`表中去判断，是否已经加载到内存中

##### 2. 初始化对应类和元类

```c++
static Class
realizeAndInitializeIfNeeded_locked(id inst, Class cls, bool initialize)
{
    runtimeLock.assertLocked();
    // 判断类是否已经实现
    if (slowpath(!cls->isRealized())) {
        cls = realizeClassMaybeSwiftAndLeaveLocked(cls, runtimeLock);
        // runtimeLock may have been dropped but is now locked again
    }
	// 判断类是否初始化
    if (slowpath(initialize && !cls->isInitialized())) {
        cls = initializeAndLeaveLocked(cls, inst, runtimeLock);
        // runtimeLock may have been dropped but is now locked again

        // If sel == initialize, class_initialize will send +initialize and
        // then the messenger will send +initialize again after this
        // procedure finishes. Of course, if this is not being called
        // from the messenger then it won't happen. 2778172
    }
    return cls;
}
```

- 通过`realizeClassMaybeSwiftAndLeaveLocked`去实现类，主要是按照`isa`和继承链去实现`bits`中的`data`数据。
- 通过`initializeAndLeaveLocked`去初始化类

##### 3. 查询方法

```c++
for (unsigned attempts = unreasonableClassCount();;) {
    // 如果存在共享缓存，则先去缓存中查找
    if (curClass->cache.isConstantOptimizedCache(/* strict */true)) {
        #if CONFIG_USE_PREOPT_CACHES
        imp = cache_getImp(curClass, sel);
        if (imp) goto done_unlock;
        curClass = curClass->cache.preoptFallbackClass();
        #endif
    } else {
        // curClass method list.
        method_t *meth = getMethodNoSuper_nolock(curClass, sel);
        if (meth) {
            imp = meth->imp(false);
            goto done;
        }

        if (slowpath((curClass = curClass->getSuperclass()) == nil)) {
            // No implementation found, and method resolver didn't help.
            // Use forwarding.
            imp = forward_imp;
            break;
        }
    }

    // Halt if there is a cycle in the superclass chain.
    if (slowpath(--attempts == 0)) {
        _objc_fatal("Memory corruption in class list.");
    }

    // Superclass cache.
    imp = cache_getImp(curClass, sel);
    if (slowpath(imp == forward_imp)) {
        // Found a forward:: entry in a superclass.
        // Stop searching, but don't cache yet; call method
        // resolver for this class first.
        break;
    }
    if (fastpath(imp)) {
        // Found the method in a superclass. Cache it in this class.
        goto done;
    }
}
```

1. 先判断是否有共享缓存，如果存在先去缓存中查找，然后再去列表中查询

```c++
// curClass method list.
method_t *meth = getMethodNoSuper_nolock(curClass, sel);
if (meth) {
    imp = meth->imp(false);
    goto done;
}

if (slowpath((curClass = curClass->getSuperclass()) == nil)) {
    // No implementation found, and method resolver didn't help.
    // Use forwarding.
    imp = forward_imp;
    break;
}
```

2. 先在当前类中去查询，如果查询到了，则直接跳转至`done`。如果没有查到，则设置`curClass = curClass->getSuperclass()`进入到父类中。我们看一下`getMethodNoSuper_nolock`是如何查询的

###### getMethodNoSuper_nolock

```c++
static method_t *
getMethodNoSuper_nolock(Class cls, SEL sel)
{
    runtimeLock.assertLocked();

    ASSERT(cls->isRealized());

    auto const methods = cls->data()->methods();
    for (auto mlists = methods.beginLists(),
              end = methods.endLists();
         mlists != end;
         ++mlists)
    {
        
        method_t *m = search_method_list_inline(*mlists, sel);
        if (m) return m;
    }

    return nil;
}
```

- 通过`cls`去获取`methods`列表。这个列表是一个二维数组，如果对这一块不够了解，可以查看这篇文章[Runtime源码解析-类中bits](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/Runtime/3.%20Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-%E7%B1%BB/Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-%E7%B1%BB%E4%B8%ADbits.md)。然后我们去遍历这个二维数组，通过`search_method_list_inline`方法去查询每一个一维数组中方法。

```c++
ALWAYS_INLINE static method_t *
search_method_list_inline(const method_list_t *mlist, SEL sel)
{
    int methodListIsFixedUp = mlist->isFixedUp();
    int methodListHasExpectedSize = mlist->isExpectedSize();
    
    if (fastpath(methodListIsFixedUp && methodListHasExpectedSize)) {
        return findMethodInSortedMethodList(sel, mlist);
    } else {
        // Linear search of unsorted method list
        if (auto *m = findMethodInUnsortedMethodList(sel, mlist))
            return m;
    }

    return nil;
}
```

- 一般情况下，都会走`findMethodInSortedMethodList`方法

```c++
template<class getNameFunc>
ALWAYS_INLINE static method_t *
findMethodInSortedMethodList(SEL key, const method_list_t *list, const getNameFunc &getName)
{
    ASSERT(list);
	
    // 第一个方法位置
    auto first = list->begin();
    auto base = first;
    decltype(first) probe;

    uintptr_t keyValue = (uintptr_t)key;
    uint32_t count;
    // count = 数组的个数
    // count >>= 1 等价于 count = count / 2;
    for (count = list->count; count != 0; count >>= 1) {
        // 获取当前偏移值
        probe = base + (count >> 1);
        
        uintptr_t probeValue = (uintptr_t)getName(probe);
        
        // 如果相等，匹配成功
        if (keyValue == probeValue) {
            // `probe` is a match.
            // Rewind looking for the *first* occurrence of this value.
            // This is required for correct category overrides.
            while (probe > first && keyValue == (uintptr_t)getName((probe - 1))) {
                probe--;
            }
            return &*probe;
        }
        
        if (keyValue > probeValue) {
            base = probe + 1;
            count--;
        }
    }
    
    return nil;
}
```

- 通过二分查找的方式，来查询方法列表中的方法。如果没有找到这返回`nil`

3. 如果当前类没有找到，则把`curClass = curClass->getSuperclass()`更新为当前类的父类

```c++
// Halt if there is a cycle in the superclass chain.
if (slowpath(--attempts == 0)) {
    _objc_fatal("Memory corruption in class list.");
}

// 先去父类的缓存中查找
imp = cache_getImp(curClass, sel);
if (slowpath(imp == forward_imp)) {
    // Found a forward:: entry in a superclass.
    // Stop searching, but don't cache yet; call method
    // resolver for this class first.
    break;
}

// 在缓存中找到实现
if (fastpath(imp)) {
    // Found the method in a superclass. Cache it in this class.
    goto done;
}
```

- 先去父类的缓存中查找，如果没有找到，就进入下一次循环。去父类的方法列表中去查找
- 如果在缓存中找到，则跳转至`done`

##### 4. 方法未找到

- 如果上面的查找流程未能找到，则说明当前类和父类确实没有该方法，则进入动态决议过程

```c++
if (slowpath(behavior & LOOKUP_RESOLVER)) {
    behavior ^= LOOKUP_RESOLVER;
    return resolveMethod_locked(inst, sel, cls, behavior);
}
```

- 这方法我们再下一节具体讲解

##### 5. 方法找到

```c++
 done:
    if (fastpath((behavior & LOOKUP_NOCACHE) == 0)) {
#if CONFIG_USE_PREOPT_CACHES
        while (cls->cache.isConstantOptimizedCache(/* strict */true)) {
            cls = cls->cache.preoptFallbackClass();
        }
#endif
        log_and_fill_cache(cls, imp, sel, inst, curClass);
    }
```

- 如果方法找到了，我们会调用`log_and_fill_cache`方法，把它插入到类对应的缓存中

```c++
static void
log_and_fill_cache(Class cls, IMP imp, SEL sel, id receiver, Class implementer)
{
#if SUPPORT_MESSAGE_LOGGING
    if (slowpath(objcMsgLogEnabled && implementer)) {
        bool cacheIt = logMessageSend(implementer->isMetaClass(), 
                                      cls->nameForLogging(),
                                      implementer->nameForLogging(), 
                                      sel);
        if (!cacheIt) return;
    }
#endif
    cls->cache.insert(sel, imp, receiver);
}
```

- 该方法内部调用了`cls->cache.insert(sel, imp, receiver);`，这就我们在讲类的缓存时，着重讲解了如何插入的。这里我们也就明白了，方法是合适插入到缓存中的。

## resolveMethod_locked

- 我们在上面`lookUpImpOrForward`方法中，去类的方法列表，以及它对应的父类直达根类去查找对应方法的实现。如果找到了就直接返回，找不到的话就会进入到`resolveMethod_locked`流程。

```c++
static NEVER_INLINE IMP
resolveMethod_locked(id inst, SEL sel, Class cls, int behavior)
{
    runtimeLock.assertLocked();
    ASSERT(cls->isRealized());

    runtimeLock.unlock();
	
    // 判断是否是元类
    if (! cls->isMetaClass()) {
        // try [cls resolveInstanceMethod:sel]
        resolveInstanceMethod(inst, sel, cls);
    } 
    else { // 如果是元类，说明调用类方法
        // try [nonMetaClass resolveClassMethod:sel]
        // and [cls resolveInstanceMethod:sel]
        resolveClassMethod(inst, sel, cls);
        if (!lookUpImpOrNilTryCache(inst, sel, cls)) {
            resolveInstanceMethod(inst, sel, cls);
        }
    }

    // chances are that calling the resolver have populated the cache
    // so attempt using it
    return lookUpImpOrForwardTryCache(inst, sel, cls, behavior);
}
```

- 根据是否是元类，调用不同的动态方法决议

### 对象方法动态决议



### 类方法动态决议