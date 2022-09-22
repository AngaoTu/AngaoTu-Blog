[toc]

# Runtime源码解析-类的加载

## 前言

- 在app启动后，会把可执行文件加载到内存中。苹果是用过`dyld`它是一个动态链接器，用来链接库。
- 到底`dyld`做了些什么，该文章不做具体讲解。后面在进行启动分析时，具体讲解。
- 此篇文章我们着重研究类是如何加载到内存中，这里提前剧透，我们通过`libobjc`源码中`_objc_init`为入口，进行研究。

## _objc_init

```c++
void _objc_init(void)
{
    static bool initialized = false;
    if (initialized) return;
    initialized = true;
    
    // fixme defer initialization until an objc-using image is found?
    environ_init();
    tls_init();
    static_init();
    runtime_init();
    exception_init();
#if __OBJC2__
    cache_t::init();
#endif
    _imp_implementationWithBlock_init();

    _dyld_objc_notify_register(&map_images, load_images, unmap_image);

#if __OBJC2__
    didCallDyldNotifyRegister = true;
#endif
}
```

- 该方法中做了一些初始化操作
  1. `environ_init`：初始化一些环境变量
  2. `tls_init`：关于线程`key`的绑定
  3. `static_init`：运行`C++`静态构造函数
  4. `runtime_init`：`runtime`运行时环境初始化，主要是初始化`unattachedCategories`和`allocatedClasses`两张表
  5. `exception_init`：初始化`libobjc`库的异常处理系统
  6. `cache_t::init()`：初始化全局缓存
  7. `_imp_implementationWithBlock_init`：回调机制，一般情况下不会调用
  8. `_dyld_objc_notify_register`：`dyld`注册回调，这是该文章的重点，类的加载和此有关

### environ_init

```c++
void environ_init(void) 
{
    // 省略部分内容

    // Print OBJC_HELP and OBJC_PRINT_OPTIONS output.
    if (PrintHelp  ||  PrintOptions) {
        if (PrintHelp) {
            _objc_inform("Objective-C runtime debugging. Set variable=YES to enable.");
            _objc_inform("OBJC_HELP: describe available environment variables");
            if (PrintOptions) {
                _objc_inform("OBJC_HELP is set");
            }
            _objc_inform("OBJC_PRINT_OPTIONS: list which options are set");
        }
        if (PrintOptions) {
            _objc_inform("OBJC_PRINT_OPTIONS is set");
        }

        for (size_t i = 0; i < sizeof(Settings)/sizeof(Settings[0]); i++) {
            const option_t *opt = &Settings[i];            
            if (PrintHelp) _objc_inform("%s: %s", opt->env, opt->help);
            if (PrintOptions && *opt->var) _objc_inform("%s is set", opt->env);
        }
    }
}
```

- 在`PrintHelp`和`PrintOptions`任何为`true`情况下，可以打印环境变量。
- 这些环境变量会在我们进行调试时提供帮助。

### tls_init

```c++
void tls_init(void)
{
#if SUPPORT_DIRECT_THREAD_KEYS
    // 创建线程缓存池
    pthread_key_init_np(TLS_DIRECT_KEY, &_objc_pthread_destroyspecific);
#else
    _objc_pthread_key = tls_create(&_objc_pthread_destroyspecific);
#endif
}
```

- 线程`key`的绑定，已经本地线程池的初始化

### static_init

```c++
static void static_init()
{
    size_t count;
    auto inits = getLibobjcInitializers(&_mh_dylib_header, &count);
    for (size_t i = 0; i < count; i++) {
        inits[i]();
    }
    auto offsets = getLibobjcInitializerOffsets(&_mh_dylib_header, &count);
    for (size_t i = 0; i < count; i++) {
        UnsignedInitializer init(offsets[i]);
        init();
    }
}
```

- 运行系统级别的`C++`静态构造函数

### runtime_init

```c++
void runtime_init(void)
{	
    // 分类表的初始化
    objc::unattachedCategories.init(32);
    // 类表的初始化
    objc::allocatedClasses.init();
}
```

- 主要是初始化`unattachedCategories`和`allocatedClasses`两张表

### exception_init

```c++
void exception_init(void)
{
    old_terminate = std::set_terminate(&_objc_terminate);
}
```

- 初始化`libobjc`的异常处理系统。当应用出现`crash`，系统会发出异常信号，然后会调用`_objc_terminate`方法

```c++
static void _objc_terminate(void)
{
    if (PrintExceptions) {
        _objc_inform("EXCEPTIONS: terminating");
    }

    if (! __cxa_current_exception_type()) {
        // No current exception.
        (*old_terminate)();
    }
    else {
        // There is a current exception. Check if it's an objc exception.
        @try {
            __cxa_rethrow();
        } @catch (id e) {
            // It's an objc object. Call Foundation's handler, if any.
            (*uncaught_handler)((id)e);
            (*old_terminate)();
        } @catch (...) {
            // It's not an objc object. Continue to C++ terminate.
            (*old_terminate)();
        }
    }
}
```

- 该方法中，回调用`uncaught_handler`方法抛出异常。全局搜索该方法

```c++
objc_uncaught_exception_handler 
objc_setUncaughtExceptionHandler(objc_uncaught_exception_handler fn)
{
    objc_uncaught_exception_handler result = uncaught_handler;
    uncaught_handler = fn;
    return result;
}
```

- 在应用层可以通过调用这个方法，传入一个`fn`，这样就可以接收到底层内部异常，可以自定义处理异常消息

### cache_t::init()

```c++
void cache_t::init()
{
#if HAVE_TASK_RESTARTABLE_RANGES
    mach_msg_type_number_t count = 0;
    kern_return_t kr;

    while (objc_restartableRanges[count].location) {
        count++;
    }
	// 开启缓存
    kr = task_restartable_ranges_register(mach_task_self(),
                                          objc_restartableRanges, count);
    if (kr == KERN_SUCCESS) return;
//    _objc_fatal("task_restartable_ranges_register failed (result 0x%x: %s)",
//                kr, mach_error_string(kr));
#endif // HAVE_TASK_RESTARTABLE_RANGES
}
```

- 全局缓存初始化

### _imp_implementationWithBlock_init

```c++
void
_imp_implementationWithBlock_init(void)
{
#if TARGET_OS_OSX
    // Eagerly load libobjc-trampolines.dylib in certain processes. Some
    // programs (most notably QtWebEngineProcess used by older versions of
    // embedded Chromium) enable a highly restrictive sandbox profile which
    // blocks access to that dylib. If anything calls
    // imp_implementationWithBlock (as AppKit has started doing) then we'll
    // crash trying to load it. Loading it here sets it up before the sandbox
    // profile is enabled and blocks it.
    //
    // This fixes EA Origin (rdar://problem/50813789)
    // and Steam (rdar://problem/55286131)
    if (__progname &&
        (strcmp(__progname, "QtWebEngineProcess") == 0 ||
         strcmp(__progname, "Steam Helper") == 0)) {
        Trampolines.Initialize();
    }
#endif
}
```

- 启用初始化回调，一般初始化都是懒加载，但是对于某些进程，需要它立即进行加载

### _dyld_objc_notify_register

- 该方法在`libobjc`中没有实现，在`libdyld`中实现了

```c++
void _dyld_objc_notify_register(_dyld_objc_notify_mapped    mapped,
                                _dyld_objc_notify_init      init,
                                _dyld_objc_notify_unmapped  unmapped)
{
	dyld::registerObjCNotifiers(mapped, init, unmapped);
}
```

```c++
void registerObjCNotifiers(_dyld_objc_notify_mapped mapped, _dyld_objc_notify_init init, _dyld_objc_notify_unmapped unmapped)
{
	// record functions to call
	sNotifyObjCMapped	= mapped;
	sNotifyObjCInit		= init;
	sNotifyObjCUnmapped = unmapped;

	// call 'mapped' function with all images mapped so far
	try {
		notifyBatchPartial(dyld_image_state_bound, true, NULL, false, true);
	}
	catch (const char* msg) {
		// ignore request to abort during registration
	}

	// <rdar://problem/32209809> call 'init' function on all images already init'ed (below libSystem)
	for (std::vector<ImageLoader*>::iterator it=sAllImages.begin(); it != sAllImages.end(); it++) {
		ImageLoader* image = *it;
		if ( (image->getState() == dyld_image_state_initialized) && image->notifyObjC() ) {
			dyld3::ScopedTimer timer(DBG_DYLD_TIMING_OBJC_INIT, (uint64_t)image->machHeader(), 0, 0);
			(*sNotifyObjCInit)(image->getRealPath(), image->machHeader());
		}
	}
}
```

- `_dyld_objc_notify_register`中有3个参数

  - `&map_images`：`dyld`将`image`加载到内存中会调用该函数

  - `load_images`：`dyld`初始化所有的`image`时会调用

  - `unmap_image`：将`image`移除时会调用

- 我们先看一下`sNotifyObjCMapped`方法（`&map_images`方法）在何处被调用

```c++
static void notifyBatchPartial(dyld_image_states state, bool orLater, dyld_image_state_change_handler onlyHandler, bool preflightOnly, bool onlyObjCMappedNotification)
{
	std::vector<dyld_image_state_change_handler>* handlers = stateToHandlers(state, sBatchHandlers);
	if ( (handlers != NULL) || ((state == dyld_image_state_bound) && (sNotifyObjCMapped != NULL)) ) {
		// don't use a vector because it will use malloc/free and we want notifcation to be low cost
        allImagesLock();
		dyld_image_info	infos[allImagesCount()+1];
        ImageLoader* images[allImagesCount()+1];
        ImageLoader** end = images;
        for (std::vector<ImageLoader*>::iterator it=sAllImages.begin(); it != sAllImages.end(); it++) {...}
        if ( sBundleBeingLoaded != NULL ) {...}
        const char* dontLoadReason = NULL;
		uint32_t imageCount = (uint32_t)(end-images);
		if ( imageCount != 0 ) {...}
	#if SUPPORT_ACCELERATE_TABLES
		if ( sAllCacheImagesProxy != NULL ) {...}
	#endif
        if ( imageCount != 0 ) {
			if ( !onlyObjCMappedNotification ) {...}
            if ( (onlyHandler == NULL) && ((state == dyld_image_state_bound) || (orLater && (dyld_image_state_bound > state))) && (sNotifyObjCMapped != NULL) ) {
				const char* paths[imageCount];
				const mach_header* mhs[imageCount];
				unsigned objcImageCount = 0;
                for (int i=0; i < imageCount; ++i) {...}
                if ( objcImageCount != 0 ) {
					dyld3::ScopedTimer timer(DBG_DYLD_TIMING_OBJC_MAP, 0, 0, 0);
					uint64_t t0 = mach_absolute_time();
                    // 此处被调用
					(*sNotifyObjCMapped)(objcImageCount, paths, mhs);
					uint64_t t1 = mach_absolute_time();
					ImageLoader::fgTotalObjCSetupTime += (t1-t0);
				}
            }
        }
        allImagesUnlock();
        if ( dontLoadReason != NULL )
            throw dontLoadReason;
		if ( !preflightOnly && (state == dyld_image_state_dependents_mapped) ) {...}
}
```

- `sNotifyObjCMapped`调用的地方是在`notifyBatchPartial`方法中。接着搜索`notifyBatchPartial`被谁调用，发现是在`registerObjCNotifiers`中

```c++
void registerObjCNotifiers(_dyld_objc_notify_mapped mapped, _dyld_objc_notify_init init, _dyld_objc_notify_unmapped unmapped)
{
	// record functions to call
	sNotifyObjCMapped	= mapped;
	sNotifyObjCInit		= init;
	sNotifyObjCUnmapped = unmapped;

	// call 'mapped' function with all images mapped so far
	try {
        // 该方法内部，调用sNotifyObjCMapped方法
		notifyBatchPartial(dyld_image_state_bound, true, NULL, false, true);
	}
	catch (const char* msg) {
		// ignore request to abort during registration
	}

	// <rdar://problem/32209809> call 'init' function on all images already init'ed (below libSystem)
    // 接着调用sNotifyObjCInit方法
	for (std::vector<ImageLoader*>::iterator it=sAllImages.begin(); it != sAllImages.end(); it++) {
		ImageLoader* image = *it;
		if ( (image->getState() == dyld_image_state_initialized) && image->notifyObjC() ) {
			dyld3::ScopedTimer timer(DBG_DYLD_TIMING_OBJC_INIT, (uint64_t)image->machHeader(), 0, 0);
			(*sNotifyObjCInit)(image->getRealPath(), image->machHeader());
		}
	}
}
```

- 在`registerObjCNotifiers`方法中，先调用`map_images`后调用`load_images`方法。
- 下面我们先看看`map_images`方法，它把给定的镜像文件，映射到内存中。

## 镜像文件的映射

- 我们通过研究`map_images`方法，来查看具体是如何进行类加载

```C++
void
map_images(unsigned count, const char * const paths[],
           const struct mach_header * const mhdrs[])
{
    mutex_locker_t lock(runtimeLock);
    return map_images_nolock(count, paths, mhdrs);
}
```

- `map_images`中调用了`map_images_nolock`，该方法比较复杂，我们简单看一下，直接找到重点，该方法主要实现如下：

```c++
void 
map_images_nolock(unsigned mhCount, const char * const mhPaths[],
                  const struct mach_header * const mhdrs[])
{
    static bool firstTime = YES;
    header_info *hList[mhCount];
    uint32_t hCount;
    size_t selrefCount = 0;

    // Perform first-time initialization if necessary.
    // This function is called before ordinary library initializers. 
    // fixme defer initialization until an objc-using image is found?
    if (firstTime) {
        preopt_init();
    }

    if (PrintImages) {
        _objc_inform("IMAGES: processing %u newly-mapped images...\n", mhCount);
    }


    // Find all images with Objective-C metadata.
    hCount = 0;

    // Count classes. Size various table based on the total.
    // 计算类的个数
    int totalClasses = 0;
    int unoptimizedTotalClasses = 0;
    {
        uint32_t i = mhCount;
        while (i--) {
            const headerType *mhdr = (const headerType *)mhdrs[i];

            auto hi = addHeader(mhdr, mhPaths[i], totalClasses, unoptimizedTotalClasses);
            if (!hi) {
                // no objc data in this entry
                continue;
            }
            
            if (mhdr->filetype == MH_EXECUTE) {
                // Size some data structures based on main executable's size
#if __OBJC2__
                // If dyld3 optimized the main executable, then there shouldn't
                // be any selrefs needed in the dynamic map so we can just init
                // to a 0 sized map
                if ( !hi->hasPreoptimizedSelectors() ) {
                  size_t count;
                  _getObjc2SelectorRefs(hi, &count);
                  selrefCount += count;
                  _getObjc2MessageRefs(hi, &count);
                  selrefCount += count;
                }
#else
                _getObjcSelectorRefs(hi, &selrefCount);
#endif
                
#if SUPPORT_GC_COMPAT
                // Halt if this is a GC app.
                if (shouldRejectGCApp(hi)) {
                    _objc_fatal_with_reason
                        (OBJC_EXIT_REASON_GC_NOT_SUPPORTED, 
                         OS_REASON_FLAG_CONSISTENT_FAILURE, 
                         "Objective-C garbage collection " 
                         "is no longer supported.");
                }
#endif
            }
            
            hList[hCount++] = hi;
            
            if (PrintImages) {
                _objc_inform("IMAGES: loading image for %s%s%s%s%s\n", 
                             hi->fname(),
                             mhdr->filetype == MH_BUNDLE ? " (bundle)" : "",
                             hi->info()->isReplacement() ? " (replacement)" : "",
                             hi->info()->hasCategoryClassProperties() ? " (has class properties)" : "",
                             hi->info()->optimizedByDyld()?" (preoptimized)":"");
            }
        }
    }

    // Perform one-time runtime initialization that must be deferred until 
    // the executable itself is found. This needs to be done before 
    // further initialization.
    // (The executable may not be present in this infoList if the 
    // executable does not contain Objective-C code but Objective-C 
    // is dynamically loaded later.
    if (firstTime) {
        sel_init(selrefCount);
        arr_init();

#if SUPPORT_GC_COMPAT
        // Reject any GC images linked to the main executable.
        // We already rejected the app itself above.
        // Images loaded after launch will be rejected by dyld.

        for (uint32_t i = 0; i < hCount; i++) {
            auto hi = hList[i];
            auto mh = hi->mhdr();
            if (mh->filetype != MH_EXECUTE  &&  shouldRejectGCImage(mh)) {
                _objc_fatal_with_reason
                    (OBJC_EXIT_REASON_GC_NOT_SUPPORTED, 
                     OS_REASON_FLAG_CONSISTENT_FAILURE, 
                     "%s requires Objective-C garbage collection "
                     "which is no longer supported.", hi->fname());
            }
        }
#endif

#if TARGET_OS_OSX
        // Disable +initialize fork safety if the app is too old (< 10.13).
        // Disable +initialize fork safety if the app has a
        //   __DATA,__objc_fork_ok section.

        for (uint32_t i = 0; i < hCount; i++) {
            auto hi = hList[i];
            auto mh = hi->mhdr();
            if (mh->filetype != MH_EXECUTE) continue;
            unsigned long size;
            if (getsectiondata(hi->mhdr(), "__DATA", "__objc_fork_ok", &size)) {
                DisableInitializeForkSafety = true;
                if (PrintInitializing) {
                    _objc_inform("INITIALIZE: disabling +initialize fork "
                                 "safety enforcement because the app has "
                                 "a __DATA,__objc_fork_ok section");
                }
            }
            break;  // assume only one MH_EXECUTE image
        }
#endif

    }
	
    // 加载镜像文件
    if (hCount > 0) {
        _read_images(hList, hCount, totalClasses, unoptimizedTotalClasses);
    }

    firstTime = NO;
    
    // Call image load funcs after everything is set up.
    // 加载完成，调用镜像加载功能
    for (auto func : loadImageFuncs) {
        for (uint32_t i = 0; i < mhCount; i++) {
            func(mhdrs[i]);
        }
    }
}
```

- 该方法主要做了以下几件事：
  - `preopt_init`：初始化相关环境
  - 计算类的个数
  - `_read_images`：加载镜像文件
  - `loadImageFuncs`：调用镜像加载功能
- 这里最核心的就是，镜像文件是如何被加载的，所以我们进入`_read_images`方法。该方法内部代码比较复杂，有点无从下手。如果要一点点读很容易陷入细节。发现苹果开发提供了`log`日志。所以我们先大致看一下该方法做了哪些事。

### _read_images

```c++
void _read_images(header_info **hList, uint32_t hCount, int totalClasses, int unoptimizedTotalClasses)
{
    // 省略部分代码
    #define EACH_HEADER \
    hIndex = 0;         \
    hIndex < hCount && (hi = hList[hIndex]); \
    hIndex++
	
    // 首次进行初始化
    if (!doneOnce) {...}
    
    // Fix up @selector references
    // 修复编译阶段混乱的@selector
    static size_t UnfixedSelectors;
    {...}
    ts.log("IMAGE TIMES: fix up selector references");

    
	// 修复错误的类
    bool hasDyldRoots = dyld_shared_cache_some_image_overridden();
    for (EACH_HEADER) {...}
    ts.log("IMAGE TIMES: discover classes");
    
    // 重新映射一些类
    if (!noClassesRemapped()) {...}
    ts.log("IMAGE TIMES: remap classes");
    
    
#if SUPPORT_FIXUP
	// 修复一些消息
    for (EACH_HEADER) {...}
    ts.log("IMAGE TIMES: fix up objc_msgSend_fixup");
#endif
    
    // 读取类中协议 readProtocol
    for (EACH_HEADER) {...}
    ts.log("IMAGE TIMES: discover protocols");
    
    // 修复没有加载的协议
    for (EACH_HEADER) {...}
    ts.log("IMAGE TIMES: fix up @protocol references");
    
    // 分类的处理
    if (didInitialAttachCategories) {...}
    ts.log("IMAGE TIMES: discover categories");

    // 类的加载处理
    for (EACH_HEADER) {...}
    ts.log("IMAGE TIMES: realize non-lazy classes");
    
    // 处理一些不需要的类
    if (resolvedFutureClasses) {...}
    ts.log("IMAGE TIMES: realize future classes");
	
    // 省略部分代码
#undef EACH_HEADER
}
```

- 该方法通过`log`信息得知主要做了以下几件事：
  1. 第一次进入一些初始化操作
  2. 修复预编译阶段`@selector`的错误
  3. 修复错误的类
  4. 重新映射一些类
  5. 修复一些消息
  6. 读取类中协议 `readProtocol`
  7. 修复没有加载的协议
  8. 分类的处理
  9. 类的加载处理
  10. 处理一些不需要的类
- 下面我们逐步分析

#### 1. 第一次进入一些初始化操作

```c++
if (!doneOnce) {
    doneOnce = YES; // 加载一次后，不会再调用
    launchTime = YES;

    // 省略一下代码

    // namedClasses
    // Preoptimized classes don't go in this table.
    // 4/3 is NXMapTable's load factor
    int namedClassesSize = 
        (isPreoptimized() ? unoptimizedTotalClasses : totalClasses) * 4 / 3;
	// 创建哈希表，存放所有的类
    gdb_objc_realized_classes =
        NXCreateMapTable(NXStrValueMapPrototype, namedClassesSize);

    ts.log("IMAGE TIMES: first time tasks");
}
```

- 加载一次后`doneOnce`=`YES`，下次就不会在进入判断。
- 第一次进来主要创建表`gdb_objc_realized_classes`，表里用来存放所有的类

#### 2. 修复预编译阶段`@selector`的错误

```c++
static size_t UnfixedSelectors;
{
    mutex_locker_t lock(selLock);
    for (EACH_HEADER) {
        if (hi->hasPreoptimizedSelectors()) continue;

        bool isBundle = hi->isBundle();
        // 从macho文件中获取方法名列表
        SEL *sels = _getObjc2SelectorRefs(hi, &count);
        UnfixedSelectors += count;
        for (i = 0; i < count; i++) {
            const char *name = sel_cname(sels[i]);
            SEL sel = sel_registerNameNoLock(name, isBundle);
            if (sels[i] != sel) {
                sels[i] = sel;
            }
        }
    }
}
```

- 因为不同类中可能相同的方法，但是虽然是相同的方法但是地址不同，对那些混乱的方法进行修复。因为方法是存放在类中，每个类中的位置是不一样的，所以方法的地址也就不一样

#### 3. 修复错误的类

```c++
for (EACH_HEADER) {
    if (! mustReadClasses(hi, hasDyldRoots)) {
        // Image is sufficiently optimized that we need not call readClass()
        continue;
    }
    
	// 从macho中读取类列表信息
    classref_t const *classlist = _getObjc2ClassList(hi, &count);

    bool headerIsBundle = hi->isBundle();
    bool headerIsPreoptimized = hi->hasPreoptimizedClasses();

    for (i = 0; i < count; i++) {
        Class cls = (Class)classlist[i];
        Class newCls = readClass(cls, headerIsBundle, headerIsPreoptimized);

        if (newCls != cls  &&  newCls) {
            // Class was moved but not deleted. Currently this occurs 
            // only when the new class resolved a future class.
            // Non-lazily realize the class below.
            resolvedFutureClasses = (Class *)
                realloc(resolvedFutureClasses, 
                        (resolvedFutureClassCount+1) * sizeof(Class));
            resolvedFutureClasses[resolvedFutureClassCount++] = newCls;
        }
    }
}
```

- `_getObjc2ClassList `从`可执行文件machO`中获取类列表，对类进行处理
- 在`newClass`处，添加断点

![](https://tva1.sinaimg.cn/large/e6c9d24egy1h6fhyq5uz1j22fk0buacu.jpg)

- `cls`指向的是一块地址，`newCls`此时还没有赋值，系统随机给我分配一块脏地址。接着再走一步

![](https://tva1.sinaimg.cn/large/e6c9d24egy1h6fhzaxi7hj22fu0fojvd.jpg)

- 图片显示，此时`newCls`和`cls`指向同一块地址。我们看一下`readClass`具体做了什么

```c++
Class readClass(Class cls, bool headerIsBundle, bool headerIsPreoptimized)
{
    // 获取类名
    const char *mangledName = cls->nonlazyMangledName();
    if (missingWeakSuperclass(cls)) { ... }
    cls->fixupBackwardDeployingStableSwift();
    Class replacing = nil;

    if (mangledName != nullptr) { ... }

    if (headerIsPreoptimized  &&  !replacing) {
        ASSERT(mangledName == nullptr || getClassExceptSomeSwift(mangledName));
    } else {
        if (mangledName) { 
        	//some Swift generic classes can lazily generate their names
            // 将类名和地址关联起来
            addNamedClass(cls, mangledName, replacing);
        } else {
            Class meta = cls->ISA();
            const class_ro_t *metaRO = meta->bits.safe_ro();
            ASSERT(metaRO->getNonMetaclass() && "Metaclass with lazy name must have a pointer to the corresponding nonmetaclass.");
            ASSERT(metaRO->getNonMetaclass() == cls && "Metaclass nonmetaclass pointer must equal the original class.");
        }
        // 将关联的类插入到另一张哈希表中
        addClassTableEntry(cls);
    }
    // for future reference: shared cache never contains MH_BUNDLEs
    if (headerIsBundle) { ... }
    return cls;
}
```

1. 通过`cls->nonlazyMangledName()`获取类名

2. `addNamedClass`把类名和地址关联起来

3. `addClassTableEntry`将关联后的类，插入到一张哈希表中

##### addNamedClass

- 我们看一下`addNamedClass`是如何关联起来的

```c++
static void addNamedClass(Class cls, const char *name, Class replacing = nil)
{
    runtimeLock.assertLocked();
    Class old;
    if ((old = getClassExceptSomeSwift(name))  &&  old != replacing) {
        inform_duplicate(name, old, cls);

        // getMaybeUnrealizedNonMetaClass uses name lookups.
        // Classes not found by name lookup must be in the
        // secondary meta->nonmeta table.
        addNonMetaClass(cls);
    } else {
        NXMapInsert(gdb_objc_realized_classes, name, cls);
    }
    ASSERT(!(cls->data()->flags & RO_META));
}
```

- 根据提示可知，更新`gdb_objc_realized_classes`哈希表，`key`是`name`，`value`是`cls`。

##### addClassTableEntry

```c++
static void
addClassTableEntry(Class cls, bool addMeta = true)
{
    runtimeLock.assertLocked();

    // This class is allowed to be a known class via the shared cache or via
    // data segments, but it is not allowed to be in the dynamic table already.
    auto &set = objc::allocatedClasses.get();

    ASSERT(set.find(cls) == set.end());

    if (!isKnownClass(cls))
        set.insert(cls);
    if (addMeta)
        addClassTableEntry(cls->ISA(), false);
}
```

- `allocatedClasses`在`_objc_init`中`runtime_init`运行时环境初始化，里面主要是`unattachedCategories`和`allocatedClasses`两张表。此处是把`cls`插入`allocatedClasses`表中
- 如果`addMeta` = `true` 将元类添加`allocatedClasses`表中。

#### 4. 重新映射一些类

```c++
// Fix up remapped classes
// Class list and nonlazy class list remain unremapped.
// Class refs and super refs are remapped for message dispatching.

if (!noClassesRemapped()) {
    for (EACH_HEADER) {
        Class *classrefs = _getObjc2ClassRefs(hi, &count);
        for (i = 0; i < count; i++) {
            remapClassRef(&classrefs[i]);
        }
        // fixme why doesn't test future1 catch the absence of this?
        classrefs = _getObjc2SuperRefs(hi, &count);
        for (i = 0; i < count; i++) {
            remapClassRef(&classrefs[i]);
        }
    }
}
```

- 主要是将未映射的`Class`和`Super Class`进行重新映射：

  - `_getObjc2ClassRefs`用来获取`MachO`中静态段`__objc_classrefs`，即获取`类的引用`;

  - `_getObjc2SuperRefs`用来获取`MachO`中静态段`__objc_superrefs`，即获取`父类的引用`;

#### 5. 修复一些消息

```c++
#if SUPPORT_FIXUP
    // Fix up old objc_msgSend_fixup call sites
    for (EACH_HEADER) {
        message_ref_t *refs = _getObjc2MessageRefs(hi, &count);
        if (count == 0) continue;

        if (PrintVtables) {
            _objc_inform("VTABLES: repairing %zu unsupported vtable dispatch "
                         "call sites in %s", count, hi->fname());
        }
        for (i = 0; i < count; i++) {
            fixupMessageRef(refs+i);
        }
    }

    ts.log("IMAGE TIMES: fix up objc_msgSend_fixup");
#endif
```

- 通过`_getObjc2MessageRefs`：获取`MachO`的静态段`__objc_msgrefs`
- `fixupMessageRef`：将函数指针进行注册，并且对于需要特定指针进行修复

#### 6. 读取类中协议 readProtocol

```c++
// Discover protocols. Fix up protocol refs.
for (EACH_HEADER) {
    extern objc_class OBJC_CLASS_$_Protocol;
    Class cls = (Class)&OBJC_CLASS_$_Protocol;
    ASSERT(cls);
    NXMapTable *protocol_map = protocols();
    bool isPreoptimized = hi->hasPreoptimizedProtocols();

    if (launchTime && isPreoptimized) {
        if (PrintProtocols) {
            _objc_inform("PROTOCOLS: Skipping reading protocols in image: %s",
                         hi->fname());
        }
        continue;
    }

    bool isBundle = hi->isBundle();

    protocol_t * const *protolist = _getObjc2ProtocolList(hi, &count);
    for (i = 0; i < count; i++) {
        readProtocol(protolist[i], cls, protocol_map, 
                     isPreoptimized, isBundle);
    }
}
```

- `Class cls = (Class)&OBJC_CLASS_$_Protocol;`：查找`cls = Protocol`类
- `NXMapTable *protocol_map = protocols();`：创建协议的哈希表
- 通过`_getObjc2ProtocolList(hi, &count);`获取到`MachO中`的静态段`__objc_protolist`协议列表
- `readProtocol`：通过该方法把协议添加到`protocol_map`中

#### 7. 修复没有加载的协议

```c++
for (EACH_HEADER) {
    // At launch time, we know preoptimized image refs are pointing at the
    // shared cache definition of a protocol.  We can skip the check on
    // launch, but have to visit @protocol refs for shared cache images
    // loaded later.
    if (launchTime && hi->isPreoptimized())
        continue;
    protocol_t **protolist = _getObjc2ProtocolRefs(hi, &count);
    for (i = 0; i < count; i++) {
        remapProtocolRef(&protolist[i]);
    }
}
```

- `_getObjc2ProtocolRefs`:获取到`MachO`的静态段 `__objc_protorefs`
- `remapProtocolRef`:比较当前协议和协议列表中的同一个内存地址的协议是否相同，如果不同则替换

#### 8. 分类的处理

```c++
if (didInitialAttachCategories) {
    for (EACH_HEADER) {
        load_categories_nolock(hi);
    }
}
```

- 主要用来处理分类，我们在分类加载篇章详细介绍

#### 9. 类的加载处理

```c++
for (EACH_HEADER) {
    classref_t const *classlist = hi->nlclslist(&count);
    for (i = 0; i < count; i++) {
        Class cls = remapClass(classlist[i]);
        if (!cls) continue;

        addClassTableEntry(cls);

        if (cls->isSwiftStable()) {
            if (cls->swiftMetadataInitializer()) {
                _objc_fatal("Swift class %s with a metadata initializer "
                            "is not allowed to be non-lazy",
                            cls->nameForLogging());
            }
            // fixme also disallow relocatable classes
            // We can't disallow all Swift classes because of
            // classes like Swift.__EmptyArrayStorage
        }
        realizeClassWithoutSwift(cls, nil);
    }
}
```

- 主要处理主类，我们在类的加载篇章详细介绍

#### 10. 处理一些不需要的类

```c++
if (resolvedFutureClasses) {
    for (i = 0; i < resolvedFutureClassCount; i++) {
        Class cls = resolvedFutureClasses[i];
        if (cls->isSwiftStable()) {
            _objc_fatal("Swift class is not allowed to be future");
        }
        realizeClassWithoutSwift(cls, nil);
        cls->setInstancesRequireRawIsaRecursively(false/*inherited*/);
    }
    free(resolvedFutureClasses);
}
```

- 处理被删除，或者移动后的类（未来类）
