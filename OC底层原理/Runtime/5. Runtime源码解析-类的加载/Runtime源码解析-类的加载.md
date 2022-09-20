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

