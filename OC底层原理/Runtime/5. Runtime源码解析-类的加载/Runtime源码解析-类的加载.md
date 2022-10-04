- [Runtime源码解析-类的加载](#runtime源码解析-类的加载)
  - [前言](#前言)
  - [类的加载](#类的加载)
    - [realizeClassWithoutSwift](#realizeclasswithoutswift)
      - [rw的初始化](#rw的初始化)
      - [初始化父类、元类](#初始化父类元类)
      - [完善当前类的信息](#完善当前类的信息)
      - [methodizeClass](#methodizeclass)
        - [rwe初始化](#rwe初始化)
        - [方法列表的排序](#方法列表的排序)
    - [总结](#总结)
  - [类的懒加载和非懒加载](#类的懒加载和非懒加载)
    - [非懒加载类](#非懒加载类)
    - [懒加载类](#懒加载类)
# Runtime源码解析-类的加载

## 前言

- 我们在上一篇文章`_objc_init`流程分析中，得知在`_read_images`方法中，修复错误的类时，让类的地址和名称关联起来。

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

- 通过`readClass`方法达到地址和名称关联起来目的。虽然该方法中有对`class`的`ro`、`rw`处理，通过断点调试可知，并没有走相关方法。
- 然后在`_read_images`流程分析时，除了此处和类相关，还在倒数第二个流程，也做了类的加载处理，让我们看一下此处操作。

## 类的加载

```c++
// Realize newly-resolved future classes, in case CF manipulates them
for (EACH_HEADER) {
    // 获取非懒加载类的集合
    classref_t const *classlist = hi->nlclslist(&count);
    for (i = 0; i < count; i++) {
        Class cls = remapClass(classlist[i]);
        if (!cls) continue;
		
        // 把类加载到内存中，在上一篇文章中分析过该方法
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
        // 初始化类
        realizeClassWithoutSwift(cls, nil);
    }
}
```

- 根据注释提示，这里只加载非懒加载的类，就是实现了`load`方法的类。具体懒加载和非懒加载的区别，我们后面再讲述。

- 该方法中主要有以下几个流程
  1. 首先获取非懒加载类的集合
  2. 把对应的类加载到内存中去
  3. 初始化类

我们分析的重点就是如何初始化类的

### realizeClassWithoutSwift

```c++
static Class realizeClassWithoutSwift(Class cls, Class previously)
{
    runtimeLock.assertLocked();

    class_rw_t *rw;
    Class supercls;
    Class metacls;

    if (!cls) return nil;
    if (cls->isRealized()) {
        validateAlreadyRealizedClass(cls);
        return cls;
    }
    ASSERT(cls == remapClass(cls));

    // fixme verify class is not in an un-dlopened part of the shared cache?
	// 获取类中ro数据，ro是在编辑阶段即确定下来的数据结构，而rw是运行时的结构，所以需要开辟rw的数据空间
    auto ro = (const class_ro_t *)cls->data();
    auto isMeta = ro->flags & RO_META;
    // 判断是否未来类
    if (ro->flags & RO_FUTURE) {
        // This was a future class. rw data is already allocated.
        rw = cls->data();
        ro = cls->data()->ro();
        ASSERT(!isMeta);
        cls->changeInfo(RW_REALIZED|RW_REALIZING, RW_FUTURE);
    } else {
        // Normal class. Allocate writeable class data.
        // 把ro数据写入到rw中去
        rw = objc::zalloc<class_rw_t>();
        rw->set_ro(ro);
        rw->flags = RW_REALIZED|RW_REALIZING|isMeta;
        cls->setData(rw);
    }

    cls->cache.initializeToEmptyOrPreoptimizedInDisguise();

#if FAST_CACHE_META
    if (isMeta) cls->cache.setBit(FAST_CACHE_META);
#endif

    // Choose an index for this class.
    // Sets cls->instancesRequireRawIsa if indexes no more indexes are available
    cls->chooseClassArrayIndex();

    if (PrintConnecting) {
        _objc_inform("CLASS: realizing class '%s'%s %p %p #%u %s%s",
                     cls->nameForLogging(), isMeta ? " (meta)" : "", 
                     (void*)cls, ro, cls->classArrayIndex(),
                     cls->isSwiftStable() ? "(swift)" : "",
                     cls->isSwiftLegacy() ? "(pre-stable swift)" : "");
    }

    // 递归初始化父类、元类
    supercls = realizeClassWithoutSwift(remapClass(cls->getSuperclass()), nil);
    metacls = realizeClassWithoutSwift(remapClass(cls->ISA()), nil);

#if SUPPORT_NONPOINTER_ISA
    if (isMeta) {
        // Metaclasses do not need any features from non pointer ISA
        // This allows for a faspath for classes in objc_retain/objc_release.
        cls->setInstancesRequireRawIsa();
    } else {
        // Disable non-pointer isa for some classes and/or platforms.
        // Set instancesRequireRawIsa.
        bool instancesRequireRawIsa = cls->instancesRequireRawIsa();
        bool rawIsaIsInherited = false;
        static bool hackedDispatch = false;

        if (DisableNonpointerIsa) {
            // Non-pointer isa disabled by environment or app SDK version
            instancesRequireRawIsa = true;
        }
        else if (!hackedDispatch  &&  0 == strcmp(ro->getName(), "OS_object"))
        {
            // hack for libdispatch et al - isa also acts as vtable pointer
            hackedDispatch = true;
            instancesRequireRawIsa = true;
        }
        else if (supercls  &&  supercls->getSuperclass()  &&
                 supercls->instancesRequireRawIsa())
        {
            // This is also propagated by addSubclass()
            // but nonpointer isa setup needs it earlier.
            // Special case: instancesRequireRawIsa does not propagate
            // from root class to root metaclass
            instancesRequireRawIsa = true;
            rawIsaIsInherited = true;
        }

        if (instancesRequireRawIsa) {
            cls->setInstancesRequireRawIsaRecursively(rawIsaIsInherited);
        }
    }
// SUPPORT_NONPOINTER_ISA
#endif

    // Update superclass and metaclass in case of remapping
    // 建立继承关系、元类继承关系
    cls->setSuperclass(supercls);
    cls->initClassIsa(metacls);

    // Reconcile instance variable offsets / layout.
    // This may reallocate class_ro_t, updating our ro variable.
    if (supercls  &&  !isMeta) reconcileInstanceVariables(cls, supercls, ro);

    // Set fastInstanceSize if it wasn't set already.
    cls->setInstanceSize(ro->instanceSize);

    // Copy some flags from ro to rw
    if (ro->flags & RO_HAS_CXX_STRUCTORS) {
        cls->setHasCxxDtor();
        if (! (ro->flags & RO_HAS_CXX_DTOR_ONLY)) {
            cls->setHasCxxCtor();
        }
    }
    
    // Propagate the associated objects forbidden flag from ro or from
    // the superclass.
    if ((ro->flags & RO_FORBIDS_ASSOCIATED_OBJECTS) ||
        (supercls && supercls->forbidsAssociatedObjects()))
    {
        rw->flags |= RW_FORBIDS_ASSOCIATED_OBJECTS;
    }

    // Connect this class to its superclass's subclass lists
    // 建立类 子类的双向链表关系
    if (supercls) {
        addSubclass(supercls, cls);
    } else {
        addRootClass(cls);
    }

    // Attach categories
    // 使当前类条理化、并且链接分类
    methodizeClass(cls, previously);

    return cls;
}
```

- 该方法主要用来对类进行初始化、类结构中`rw`数据初始化、对方法进行排序等设置
- 该方法主要有以下几个操作
  1. 通过读取`ro`数据，对`rw`进行初始化
  2. 初始化父类、元类
  3. 完善当前类的信息
  4. 对类进行条理化、分类的附着

#### rw的初始化

- 这里补充一下**干净内存**和**脏内存**的概念
  - 干净内存：在编辑时即确定的内存空间，只读，加载后不会发生改变的内存空间，包括类名称、方法、协议和实例变量的信息。`ro`属于干净内存
  - 脏内存：可读可写，由于其动态性，可以往类中添加属性、方法、协议。在运行时会发生变更的内存。`rw`属于脏内存

```c++
auto ro = (const class_ro_t *)cls->data();
auto isMeta = ro->flags & RO_META;
if (ro->flags & RO_FUTURE) {
    // This was a future class. rw data is already allocated.
    rw = cls->data();
    ro = cls->data()->ro();
    ASSERT(!isMeta);
    cls->changeInfo(RW_REALIZED|RW_REALIZING, RW_FUTURE);
} else {
    // Normal class. Allocate writeable class data.
    rw = objc::zalloc<class_rw_t>();
    rw->set_ro(ro);
    rw->flags = RW_REALIZED|RW_REALIZING|isMeta;
    cls->setData(rw);
}
```

- 从`machO`中获取的数据地址，根据`class_ro_t`格式进行强制转换，然后初始化`rw`的空间，并把`ro`的数据放入`rw`中。

#### 初始化父类、元类

```c++
// 递归初始化父类、已经元类
supercls = realizeClassWithoutSwift(remapClass(cls->getSuperclass()), nil);
metacls = realizeClassWithoutSwift(remapClass(cls->ISA()), nil);
```

- 在该方法中，通过递归调用当前方法，来完善继承链，并设置当前`类`，`父类`和`元类`的数据

#### 完善当前类的信息

```c++
// 设置该类对应的父类和元类
cls->setSuperclass(supercls);
cls->initClassIsa(metacls);

// Reconcile instance variable offsets / layout.
// This may reallocate class_ro_t, updating our ro variable.
if (supercls  &&  !isMeta) reconcileInstanceVariables(cls, supercls, ro);

// Set fastInstanceSize if it wasn't set already.
// 类实例对象的大小设置-在对象初始化的时候会用到
cls->setInstanceSize(ro->instanceSize);

// Copy some flags from ro to rw
// 设置c++函数
if (ro->flags & RO_HAS_CXX_STRUCTORS) {
    cls->setHasCxxDtor();
    if (! (ro->flags & RO_HAS_CXX_DTOR_ONLY)) {
        cls->setHasCxxCtor();
    }
}

// Propagate the associated objects forbidden flag from ro or from
// the superclass.
if ((ro->flags & RO_FORBIDS_ASSOCIATED_OBJECTS) ||
    (supercls && supercls->forbidsAssociatedObjects()))
{
    rw->flags |= RW_FORBIDS_ASSOCIATED_OBJECTS;
}

// Connect this class to its superclass's subclass lists
// 建立父类和子类双向链表关系
if (supercls) {
    addSubclass(supercls, cls);
} else {
    addRootClass(cls);
}
```

- 首先初始化当前类的父类、元类，以及一些类的属性设置，再对该类的父类和子类建立双向链表关系，保证子类能找到父类，父类也可以找到子类。

#### methodizeClass

- 接着我们需要对该类进行条理化处理、已经分类的附着。本篇文章主要讲类相关的处理，分类的附着我们放在下一篇中进行分析

```c++
static void methodizeClass(Class cls, Class previously)
{
    runtimeLock.assertLocked();
	
    // 准备一些初始化数据
    bool isMeta = cls->isMetaClass();
    auto rw = cls->data();
    auto ro = rw->ro();
    auto rwe = rw->ext();

    // Install methods and properties that the class implements itself.
    // 获取ro中方法列表
    method_list_t *list = ro->baseMethods();
    if (list) {
        // 对方法列表进行准备工作
        prepareMethodLists(cls, &list, 1, YES, isBundleClass(cls), nullptr);
        if (rwe) rwe->methods.attachLists(&list, 1);
    }

    property_list_t *proplist = ro->baseProperties;
    if (rwe && proplist) {
        rwe->properties.attachLists(&proplist, 1);
    }

    protocol_list_t *protolist = ro->baseProtocols;
    if (rwe && protolist) {
        rwe->protocols.attachLists(&protolist, 1);
    }

    // Root classes get bonus method implementations if they don't have 
    // them already. These apply before category replacements.
    if (cls->isRootMetaclass()) {
        // root metaclass
        addMethod(cls, @selector(initialize), (IMP)&objc_noop_imp, "", NO);
    }

    // Attach categories.
    // 分类的附着
    if (previously) {
        if (isMeta) {
            objc::unattachedCategories.attachToClass(cls, previously,
                                                     ATTACH_METACLASS);
        } else {
            // When a class relocates, categories with class methods
            // may be registered on the class itself rather than on
            // the metaclass. Tell attachToClass to look for those.
            objc::unattachedCategories.attachToClass(cls, previously,
                                                     ATTACH_CLASS_AND_METACLASS);
        }
    }
    objc::unattachedCategories.attachToClass(cls, cls,
                                             isMeta ? ATTACH_METACLASS : ATTACH_CLASS);
}
```

- 在该方法中，主要是针对`rwe`的初始化，方法列表的准备工作，分类的附着（放在分类的加载中讲解）

##### rwe初始化

```c++
method_list_t *list = ro->baseMethods();
if (list) {
    prepareMethodLists(cls, &list, 1, YES, isBundleClass(cls), nullptr);
    if (rwe) rwe->methods.attachLists(&list, 1);
}

property_list_t *proplist = ro->baseProperties;
if (rwe && proplist) {
    rwe->properties.attachLists(&proplist, 1);
}

protocol_list_t *protolist = ro->baseProtocols;
if (rwe && protolist) {
    rwe->protocols.attachLists(&protolist, 1);
}
```

- 通过源码调试可知，`rwe`大多数情况下会为空。所以此时针对方法、属性、协议的添加操作是不会运行的。
- 什么时候`rwe`才会存在呢？当我们对类进行类扩展操作，动态添加协议、属性等

##### 方法列表的排序

- 方法列表相比于属性列表、协议列表，多了一步`prepareMethodLists`操作

```c++
static void 
prepareMethodLists(Class cls, method_list_t **addedLists, int addedCount,
                   bool baseMethods, bool methodsFromBundle, const char *why)
{
    runtimeLock.assertLocked();

    if (addedCount == 0) return;

    // 省略部分代码...

    // Add method lists to array.
    // Reallocate un-fixed method lists.
    // The new methods are PREPENDED to the method list array.

    for (int i = 0; i < addedCount; i++) {
        method_list_t *mlist = addedLists[i];
        ASSERT(mlist);

        // Fixup selectors if necessary
        // 对方法列表进行排序
        if (!mlist->isFixedUp()) {
            fixupMethodList(mlist, methodsFromBundle, true/*sort*/);
        }
    }

    // 省略部分代码...
}
```

- 其中核心流程就是判断方法列表是否已经排序，没有则通过`fixupMethodList`方法进行排序

```c++
static void 
fixupMethodList(method_list_t *mlist, bool bundleCopy, bool sort)
{
    // 省略部分代码

    // Sort by selector address.
    // Don't try to sort small lists, as they're immutable.
    // Don't try to sort big lists of nonstandard size, as stable_sort
    // won't copy the entries properly.
    if (sort && !mlist->isSmallList() && mlist->entsize() == method_t::bigSize) {
        method_t::SortBySELAddress sorter;
        std::stable_sort(&mlist->begin()->big(), &mlist->end()->big(), sorter);
    }
    
    // 省略部分代码
}
```

- 该方法的核心就是通过`sel`的地址从高到低进行排序
- 排序的目的就是，在方法查找时可以通过二分查找法进行查找，加快查找速度。

### 总结

- `realizeClassWithoutSwift`中做了那些事
  - 初始化类，主要是构造`rw`、或`rwe`
  - 初始化类对应的父类、元类，构建父类、子类双向链表关系。
  - `ro`以及分类中的方法列表按照方法选择地址排序，目的方便后续的二分查找法
  - 以及分类的附着

## 类的懒加载和非懒加载

- 我们在前面说到，并使不是所有的类在`read_images`方法中，都会走`realizeClassWithoutSwift`方法。根据注释上面说到只有非懒加载类才会走。

### 非懒加载类

- 根据注释可知，只有实现了`load`方法的类，才是非懒加载类。
- 加载时机：`APP`启动加载类数据时就会加载
- 优点：可以提早执行`load`方法
- 注意：
  1. 苹果默认的就是懒加载，但是为了给开发者更大的灵活性，所以也有非懒加载的流程
  2. 没有必要都用非懒加载，因为可能有的类并不会立马使用，如果在`main`函数执行前就去实现，就会导致启动时间慢，又占内存。
  3. 想要在第一次调用方法前执行某些代码，可以用`initialize`来执行，而不是`load`

### 懒加载类

- 没有实现`load`方法的类，就是懒加载类。
- 加载时机：第一次调用方法的时候加载。方法列表中查找`imp`时会进行一次判断，如果没有被实现过则会进行一次实现(具体查看`lookupImpOrForward`函数)
- 优点：
  1. 把类的实现推迟到启动后，启动更快。
  2. 一些类可能不会立马使用，避免内存浪费，已经段时间内的内存暴涨。