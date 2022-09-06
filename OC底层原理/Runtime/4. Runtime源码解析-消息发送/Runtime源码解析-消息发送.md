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
```

1. 通过下标`index`获取对应的bucket。`p13 = buckets + ((_cmd & mask) << (1+PTRSHIFT))`