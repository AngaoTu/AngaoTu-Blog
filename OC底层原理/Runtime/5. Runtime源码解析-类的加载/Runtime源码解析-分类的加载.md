- [Runtim源码解析-分类的加载](#runtim源码解析-分类的加载)
  - [什么是Category？](#什么是category)
    - [extension](#extension)
    - [category 与 extension 的区别](#category-与-extension-的区别)
  - [Category的实质](#category的实质)
    - [category_t 结构体](#category_t-结构体)
    - [分类如何存储在类对象中](#分类如何存储在类对象中)
  - [分类的加载](#分类的加载)
    - [分类加载的引入](#分类加载的引入)
      - [attachToClass](#attachtoclass)
      - [load_categories_nolock](#load_categories_nolock)
    - [分类和主类加载的几种情况](#分类和主类加载的几种情况)
      - [主类load+分类load](#主类load分类load)
        - [主类load+只有一个分类，分类load](#主类load只有一个分类分类load)
        - [主类load+多个分类，部分实现load方法](#主类load多个分类部分实现load方法)
      - [主类load+分类没有](#主类load分类没有)
      - [主类没有+分类load](#主类没有分类load)
        - [主类没有+只有一个分类，分类load](#主类没有只有一个分类分类load)
        - [主类没有+多个分类，超过一个分类load](#主类没有多个分类超过一个分类load)
      - [主类没有+分类没有](#主类没有分类没有)
  - [attachCategories](#attachcategories)
      - [attachLists](#attachlists)
        - [0 lists -> 1list](#0-lists---1list)
        - [1 list -> many lists](#1-list---many-lists)
        - [many lists -> many lists](#many-lists---many-lists)
  - [关联对象](#关联对象)
    - [如何关联对象](#如何关联对象)
    - [关联对象的实现原理](#关联对象的实现原理)
      - [核心对象](#核心对象)
        - [AssociationsManager](#associationsmanager)
        - [AssociationsHashMap](#associationshashmap)
        - [ObjectAssociationMap](#objectassociationmap)
        - [ObjcAssociation](#objcassociation)
    - [设置关联对象、获取关联对象流程](#设置关联对象获取关联对象流程)
      - [objc_setAssociatedObject](#objc_setassociatedobject)
      - [objc_getAssociatedObject](#objc_getassociatedobject)
      - [objc_removeAssociatedObjects](#objc_removeassociatedobjects)
# Runtim源码解析-分类的加载

## 什么是Category？

`category` 的主要作用是为已经存在的类添加方法。

可以把类的实现分开在几个不同的文件里面。这样做有几个显而易见的好处。

- 把不同的功能组织到不同的 `category` 里，减少单个文件的体积，且易于维护；
- 可以由多个开发者共同完成一个类；
- 可以按需加载想要的 `category`；
- 声明私有方法；

不过除了 `apple` 推荐的使用场景，还衍生出了` category` 的其他几个使用场景：

1. 模拟多继承（另外可以模拟多继承的还有 `protocol`）
2. 把 `framework` 的私有方法公开

### extension

- `extension` 被开发者称之为扩展、延展、匿名分类。`extension`看起来很像一个匿名的 `category`，但是`extension`和`category`几乎完全是两个东西。

- 和 `category`不同的是`extension`不但可以声明方法，还可以声明属性、成员变量。`extension` 一般用于声明私有方法，私有属性，私有成员变量。

- 使用`extension`必须有原有类的源码。`extension`声明的方法、属性和成员变量必须在类的主 `@implementation` 区间内实现，可以避免使用有名称的`category`带来的多个不必要的`implementation`段。

- `extension`很常见的用法，是用来给类添加私有的变量和方法，用于在类的内部使用。例如在 `@interface`中定义为`readonly`类型的属性，在实现中添加`extension`，将其重新定义为 `readwrite`，这样我们在类的内部就可以直接修改它的值，然而外部依然不能调用`setter`方法来修改。

### category 与 extension 的区别

`category` 和 `extension` 的区别:

- `extension`可以添加实例变量，而`category`是无法添加实例变量的。
- `extension`在编译期决议，是类的一部分，`category`则在运行期决议。`extension`在编译期和头文件里的` @interface` 以及实现文件里的 `@implement` 一起形成一个完整的类，`extension` 伴随类的产生而产生，亦随之一起消亡。
- `extension` 一般用来隐藏类的私有信息，你必须有一个类的源码才能为一个类添加 `extension`，所以你无法为系统的类比如 `NSString` 添加 `extension`，除非创建子类再添加 `extension`。而 `category` 不需要有类的源码，我们可以给系统提供的类添加 `category`。
- `extension` 和 `category` 都可以添加属性，但是 `category` 的属性不能生成成员变量和 `getter`、`setter` 方法的实现。

## Category的实质

### category_t 结构体

```objective-c
struct category_t {
    const char *name;//类的名字
    classref_t cls;//类
    struct method_list_t *instanceMethods;//实例方法列表
    struct method_list_t *classMethods;//类方法列表
    struct protocol_list_t *protocols;//协议列表
    struct property_list_t *instanceProperties;//属性列表
    struct property_list_t *_classProperties;

    method_list_t *methodsForMeta(bool isMeta) {
        if (isMeta) return classMethods;
        else return instanceMethods;
    }

    property_list_t *propertiesForMeta(bool isMeta, struct header_info *hi);
};
```

- 从源码基本可以看出我们平时使用`categroy`的方式，对象方法，类方法，协议，和属性都可以找到对应的存储方式。并且我们发现分类结构体中是不存在成员变量的，因此分类中是不允许添加成员变量的。分类中添加的属性并不会帮助我们自动生成成员变量，只会生成`get`、`set`方法的声明，需要我们自己去实现。

### 分类如何存储在类对象中

- 我们先写一个分类，看看分类到底是何方妖魔

```objective-c
#import <Foundation/Foundation.h>

@interface BFPerson : NSObject
@property (nonatomic, assign)NSInteger age;
- (void)test;
@end
@interface BFPerson (Work)
@property (nonatomic, assign) double workAge;

- (void)work;
+ (void)workIn:(NSString *)city;
- (void)test;
@end

@interface BFPerson (Study)
@property (nonatomic, copy) NSString *lesson;
@property (nonatomic, assign) NSInteger classNo;

- (void)study;
+ (void)studyLession:(NSString *)les;
- (void)test;
@end
```

- 我们再通过命令行将`BFPerson+Study.m`文件转换成`c++`文件

```objective-c
clang -rewrite-objc Person+Study.m
```

- 在分类转化为c++文件中可以看出`_category_t`结构体中，存放着类名，对象方法列表，类方法列表，协议列表，以及属性列表。

```objective-c
struct _category_t {
	const char *name;
	struct _class_t *cls;
	const struct _method_list_t *instance_methods;
	const struct _method_list_t *class_methods;
	const struct _protocol_list_t *protocols;
	const struct _prop_list_t *properties;
};
```

- 接着我们查看`_method_list_t`类型的结构体

```objective-c
static struct /*_method_list_t*/ {
	unsigned int entsize;  //内存
	unsigned int method_count; //方法数量
	struct _objc_method method_list[1]; //方法列表
} _OBJC_$_CATEGORY_INSTANCE_METHODS_BFPerson_$_Study __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	1,
	{{(struct objc_selector *)"study", "v16@0:8", (void *)_I_BFPerson_Study_study}}
};
```

上面我们发现这个结构体`_OBJC_$_CATEGORY_INSTANCE_METHODS_BFPerson_$_Study`从名称上可以看出是`INSTANCE_METHODS`对象方法，并且一一对应为上面结构体内赋值。并从赋值中找到了我们实现的对象方法`stduy`

- 接着我们发现同样的`_method_list_t`类型的类方法结构体

```objective-c
static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[1];
} _OBJC_$_CATEGORY_CLASS_METHODS_BFPerson_$_Study __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	1,
	{{(struct objc_selector *)"studyLession:", "v24@0:8@16", (void *)_C_BFPerson_Study_studyLession_}}
};
```

同上面对象方法列表一样，这个我们可以看出是类方法列表结构体`_OBJC_$_CATEGORY_CLASS_METHODS_BFPerson_$_Study`,同对象方法一样，同样可以看到我们实现的类方法`studyLession`

- 接下来是属性列表

```objective-c
static struct /*_prop_list_t*/ {
	unsigned int entsize;  // sizeof(struct _prop_t)
	unsigned int count_of_properties;
	struct _prop_t prop_list[2];
} _OBJC_$_PROP_LIST_BFPerson_$_Study __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_prop_t),
	2,
	{{"lesson","T@\"NSString\",C,N"},
	{"classNo","Tq,N"}}
};
```

属性列表结构体`_OBJC_$_PROP_LIST_BFPerson_$_Study`存储属性数量、以及属性列表，我们可以发现我们自己写的`lesson` 和`classNo`属性

- 最后我们可以看到定义了`_OBJC_$_CATEGORY_BFPerson_$_Study`结构体，并且将我们上面的结构体一一赋值

```objective-c
static struct _category_t _OBJC_$_CATEGORY_BFPerson_$_Study __attribute__ ((used, section ("__DATA,__objc_const"))) = 
{
	"BFPerson",
	0, // &OBJC_CLASS_$_BFPerson,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_INSTANCE_METHODS_BFPerson_$_Study,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_CLASS_METHODS_BFPerson_$_Study,
	0,
	(const struct _prop_list_t *)&_OBJC_$_PROP_LIST_BFPerson_$_Study,
};
//将_OBJC_$_CATEGORY_BFPerson_$_Study的cls指针指向OBJC_CLASS_$_BFPerson结构的地址
static void OBJC_CATEGORY_SETUP_$_BFPerson_$_Study(void ) {
	_OBJC_$_CATEGORY_BFPerson_$_Study.cls = &OBJC_CLASS_$_BFPerson;
}
```

我们这里可以看出，`cls`指针指向的应该是分类的主类类对象的地址

- 通过上面分析我们发现。分类源码中确实是将我们定义的对象方法，类方法，属性等都存放在`catagory_t`结构体中。
- 接下来我们在回到runtime源码查看`catagory_t`存储的方法，属性，协议等是如何存储在类对象中的。

## 分类的加载

### 分类加载的引入

`WWDC`类的优化中苹果为分类和动态添加专门分配的了一块内存`rwe`，因为`rwe`属于`dirty memory`，它是在运行时动态生成的。可以简单理解为，如果该类没有分类或者动态添加方法、属性等操作，不会产生`rwe`这块内存。

我们在`class_rw_t`中去查找相关`rwe`的源码

```c++
struct class_rw_t {
    ... //省略部分代码
    class_rw_ext_t *ext() const {
        return get_ro_or_rwe().dyn_cast<class_rw_ext_t *>(&ro_or_rw_ext);
    }

    class_rw_ext_t *extAllocIfNeeded() {
        auto v = get_ro_or_rwe();
        // 判断rwe是否存在
        if (fastpath(v.is<class_rw_ext_t *>())) {
            //如果已经有rwe直接返回地址指针
            return v.get<class_rw_ext_t *>(&ro_or_rw_ext);
        } else {
            //为rwe开辟内存并且返回地址指针
            return extAlloc(v.get<const class_ro_t *>(&ro_or_rw_ext));
        }
    }
    class_rw_ext_t *deepCopy(const class_ro_t *ro)
        return extAlloc(ro, true);
    }
    ... //省略部分代码
}
```

从源码中发现，如果我们要使用`ext`这块内存 ，肯定会调用`extAllocIfNeeded`方法。全局搜索该方法调流路径，发现有以下几处

- `attachCategories`
- `objc_class::demangledName`
- `class_setVersion`
- `addMethods_finish`
- `class_addProtocol`
- `_class_addProperty`
- `objc_duplicateClass`

通过方法名称，以及函数注释，发现大多数都和运行时有关系。通过名称发现`attachCategories`最符合我们加载分类的需求。我们具体查看该方法在何处调用。

全局搜索后，发现该方法只有两处调用

- `attachToClass`
- `load_categories_nolock`

#### attachToClass

发现全局只有`methodizeClass`方法调用了

```c++
static void methodizeClass(Class cls, Class previously)
{
   	// 省略部分代码...

    // Attach categories.
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

#if DEBUG
    // Debug: sanity-check all SELs; log method list contents
    for (const auto& meth : rw->methods()) {
        if (PrintConnecting) {
            _objc_inform("METHOD %c[%s %s]", isMeta ? '+' : '-', 
                         cls->nameForLogging(), sel_getName(meth.name()));
        }
        ASSERT(sel_registerName(sel_getName(meth.name())) == meth.name());
    }
#endif
}
```

一共有三处调用了`attachToClass`方法，经过调试发现没有走`if(previously)`里面逻辑，只调用了外面的`attachToClass`方法

搜索发现`methodizeClass`方法的`previously`，来源于`realizeClassWithoutSwift`方法，而源码中所有的`realizeClassWithoutSwift`方法，参数`previously`都为`nil`；

它的调用流程为：

`_read_images` --> `realizeClassWithoutSwift`-->`methodizeClass`-->`attachToClass`-->`attachCategories`

#### load_categories_nolock

全局搜索发现有两处调用`load_categories_nolock`方法

- `loadAllCategories`
- `_read_images`

在`_read_images`中调用，通过注释得知，启动时出现的分类，我们都会推迟到`load_images`中调用。所以我们写的分类不会在此调用，那只会在`loadAllCategories`中调用了

```c++
static void loadAllCategories() {
    mutex_locker_t lock(runtimeLock);

    for (auto *hi = FirstHeader; hi != NULL; hi = hi->getNext()) {
        load_categories_nolock(hi);
    }
}
```

`load_images`调用`loadAllCategories`，`load_images`在`dyld`中调用

```c++
void
load_images(const char *path __unused, const struct mach_header *mh)
{
    if (!didInitialAttachCategories && didCallDyldNotifyRegister) {
        didInitialAttachCategories = true;
        loadAllCategories();
    }

    // Return without taking locks if there are no +load methods here.
    if (!hasLoadMethods((const headerType *)mh)) return;

    recursive_mutex_locker_t lock(loadMethodLock);

    // Discover load methods
    {
        mutex_locker_t lock2(runtimeLock);
        prepare_load_methods((const headerType *)mh);
    }

    // Call +load methods (without runtimeLock - re-entrant)
    call_load_methods();
}
```

- `didInitialAttachCategories`默认是`false`，当执行完`loadAllCategories()`后自动将`didInitialAttachCategories`设为`true`，其实就是只调用一次`loadAllCategories()`

- 当`objc`向`dyld`完成注册回调后`didCallDyldNotifyRegister `= `true`

- `load_categories_nolock`流程：`load_images` --> `loadAllCategories` --> `load_categories_nolock` --> `attachCategories` --> `attachLists`

### 分类和主类加载的几种情况

上一篇中[Runtime源码解析-类的加载](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/Runtime/5.%20Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-%E7%B1%BB%E7%9A%84%E5%8A%A0%E8%BD%BD/Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-%E7%B1%BB%E7%9A%84%E5%8A%A0%E8%BD%BD.md) 我们讲到过懒加载类和非懒加载类。类加载时调用函数，跟是否调用`load`是有关系的。

那么接下来，针对分类和主类有没有实现`load`方法进行函数调用的测试，看一下不同情况是怎么调用到`attachCategories`的。

我们在对应流程方法中，添加打印信息

#### 主类load+分类load

##### 主类load+只有一个分类，分类load

- 非懒加载类加载流程：`map_images` --> `map_images_nolock` --> `_read_images` --> `realizeClassWithoutSwift` --> `methodizeClass` --> `attachToClass`

- 非懒加载分类加载流程：`load_images` --> `loadAllCategories` --> `load_categories_nolock` --> `attachCategories` --> `attachLists`

##### 主类load+多个分类，部分实现load方法

- 非懒加载类加载流程：`map_images` --> `map_images_nolock` --> `_read_images` --> `realizeClassWithoutSwift` --> `methodizeClass` --> `attachToClass`
- 非懒加载分类加载流程：`load_images` --> `loadAllCategories` --> `load_categories_nolock` --> `attachCategories` --> `attachLists`
- 和上面保持一致，说明不管有多少个分类，只有有一个分类实现`load`方法，都会走`load_images`方法去加载分类数据。

#### 主类load+分类没有

- `非懒加载类`还是走`map_images` --> `map_images_nolock` --> `_read_images` --> `realizeClassWithoutSwift` --> `methodizeClass` --> `attachToClass`
- 懒加载分类没有走`attachCategories`，那么分类中方法列表是什么时候加载的呢？
  - 我们去`macho`中分类的列表是没有数据的，那就说明不可能是动态时加载分类的数据，那么到底在什么时间去加载分类的数据呢
  - 我们去查找主类的`ro`中不仅有主类的方法，同时还有分类的方法。`ro`是在编译期就确定的，也就是说懒加载分类中的数据在编译期就已经合并到了主类中，而且分类的数据也是放在主类的方法前面。

#### 主类没有+分类load

##### 主类没有+只有一个分类，分类load

- 这种方式和**主类load+分类没有**一致的，分类的`load`方法强制把懒加载类，提前到非懒加载类的流程中去。
- 还是走的`map_images` --> `map_images_nolock` --> `_read_images` --> `realizeClassWithoutSwift` --> `methodizeClass` --> `attachToClass`。
- 也是在编译时把懒加载类变成了非懒加载类，然后非懒加载的分类的数据合并到了主类中。

##### 主类没有+多个分类，超过一个分类load

- 这个时候主类没有走`map_images` --> `map_images_nolock` --> `_read_images` --> `realizeClassWithoutSwift`
- 调用流程如下：
- `load_images`
  - --> `loadAllCategories` --> `load_categories_nolock`-->`addForClass`
  - -->`prepare_load_methods` -->`realizeClassWithoutSwift`-->`attachToClass` --> `attachCategories`

-  和只有一个人类时，是完全不同的调用逻辑。它是走的`load_images`流程，并在此进行了初始化类，加载分类数据

#### 主类没有+分类没有

- 这种情况下，前面加载的流程都没有走。由于主类和分类都没有实现`load`方法，所以是一个懒加载类的方式。只有在该类第一次发送消息是，才会调用类的加载流程。
- 通过断点调试发现，分类的数据也合并在主类中了。

## attachCategories

前面我们讲解了，不同的分类+主类情况，会走不同的加载流程。接下来我们需要研究一下，具体是如何把分类的数据加载到主类上去的。所以最终我们还是回到了`attachCategories`方法中来

```c++
static void
attachCategories(Class cls, const locstamped_category_t *cats_list, uint32_t cats_count,
                 int flags)
{
	// 省略部分代码
    constexpr uint32_t ATTACH_BUFSIZ = 64;
    method_list_t   *mlists[ATTACH_BUFSIZ];
    property_list_t *proplists[ATTACH_BUFSIZ];
    protocol_list_t *protolists[ATTACH_BUFSIZ];

    uint32_t mcount = 0;
    uint32_t propcount = 0;
    uint32_t protocount = 0;
    bool fromBundle = NO;
    bool isMeta = (flags & ATTACH_METACLASS);
    // 获取rwe
    auto rwe = cls->data()->extAllocIfNeeded();
	
    // 遍历所有的分类
    for (uint32_t i = 0; i < cats_count; i++) {
        auto& entry = cats_list[i];
		
        // 方法列表
        method_list_t *mlist = entry.cat->methodsForMeta(isMeta);
        if (mlist) {
            if (mcount == ATTACH_BUFSIZ) {
                prepareMethodLists(cls, mlists, mcount, NO, fromBundle, __func__);
                rwe->methods.attachLists(mlists, mcount);
                mcount = 0;
            }
            // 如果 mcount = 0，mlist存放的位置在63个位置，总共是0 ~ 63
            mlists[ATTACH_BUFSIZ - ++mcount] = mlist;
            fromBundle |= entry.hi->isBundle();
        }
	
        // 属性列表
        property_list_t *proplist =
            entry.cat->propertiesForMeta(isMeta, entry.hi);
        if (proplist) {
            if (propcount == ATTACH_BUFSIZ) {
                rwe->properties.attachLists(proplists, propcount);
                propcount = 0;
            }
            proplists[ATTACH_BUFSIZ - ++propcount] = proplist;
        }
		
        // 协议列表
        protocol_list_t *protolist = entry.cat->protocolsForMeta(isMeta);
        if (protolist) {
            if (protocount == ATTACH_BUFSIZ) {
                rwe->protocols.attachLists(protolists, protocount);
                protocount = 0;
            }
            protolists[ATTACH_BUFSIZ - ++protocount] = protolist;
        }
    }
	
    // 将分类方法添加到主类
    if (mcount > 0) {
        // 将方法进行排序
        prepareMethodLists(cls, mlists + ATTACH_BUFSIZ - mcount, mcount,
                           NO, fromBundle, __func__);
        rwe->methods.attachLists(mlists + ATTACH_BUFSIZ - mcount, mcount);
        if (flags & ATTACH_EXISTING) {
            flushCaches(cls, __func__, [](Class c){
                // constant caches have been dealt with in prepareMethodLists
                // if the class still is constant here, it's fine to keep
                return !c->cache.isConstantOptimizedCache();
            });
        }
    }
    
	// 将分类属性添加到主类属性中
    rwe->properties.attachLists(proplists + ATTACH_BUFSIZ - propcount, propcount);
	// 将分类协议添加到主类协议中
    rwe->protocols.attachLists(protolists + ATTACH_BUFSIZ - protocount, protocount);
}
```

该方法中主要做了以下几件事

1. 开辟`rwe`空间，用来存储动态添加的方法、属性、协议
2. 遍历该类所有的分类，获取到所有相关数据
3. 把获取到的分类数据，通过`attachLists`添加到类中

我们的重点就是如何把分类数据添加到主类中去的

#### attachLists

- `attachLists`是核心方法，`attachLists`作用是将分类数据加载到主类中

```c++
void attachLists(List* const * addedLists, uint32_t addedCount) {
    if (addedCount == 0) return;

    if (hasArray()) {
        // many lists -> many lists
        uint32_t oldCount = array()->count;
        uint32_t newCount = oldCount + addedCount;
        array_t *newArray = (array_t *)malloc(array_t::byteSize(newCount));
        newArray->count = newCount;
        array()->count = newCount;

        for (int i = oldCount - 1; i >= 0; i--)
            newArray->lists[i + addedCount] = array()->lists[i];
        for (unsigned i = 0; i < addedCount; i++)
            newArray->lists[i] = addedLists[i];
        free(array());
        setArray(newArray);
        validate();
    }
    else if (!list  &&  addedCount == 1) {
        // 0 lists -> 1 list
        list = addedLists[0];
        validate();
    } 
    else {
        // 1 list -> many lists
        Ptr<List> oldList = list;
        uint32_t oldCount = oldList ? 1 : 0;
        uint32_t newCount = oldCount + addedCount;
        setArray((array_t *)malloc(array_t::byteSize(newCount)));
        array()->count = newCount;
        if (oldList) array()->lists[addedCount] = oldList;
        for (unsigned i = 0; i < addedCount; i++)
            array()->lists[i] = addedLists[i];
        validate();
    }
}
```

该方法中主要分了三部分:

1. 0 lists -> 1list
2. 1 list -> many lists
3. many lists -> many lists

##### 0 lists -> 1list

- 将`addedLists[0]`的指针赋值给`list`

##### 1 list -> many lists

- 计算旧的`list`的个数
- 计算新的`list`个数 ，新的`list`个数 = 原有的`list`个数 + 新增的`list`个数
- 根据`newCount`开辟相应的内存，类型是`array_t`类型，并设置数组`setArray`
- 将原有的`list`放在数组的末尾，因为最多只有一个不需要遍历存储
- 遍历`addedLists`将遍历的数据从数组的开始位置存储

##### many lists -> many lists

1. 判断`array()`是否存在
2. 计算原有的数组中的`list`个数`array()->lists`的个数
3. 新的`newCount` = 原有的`count` + 新增的`count`
4. 根据`newCount`开辟相应的内存，类型是`array_t`类型
5. 设置新数组的个数等于`newCount`
6. 设置原有数组的个数等于`newCount`
7. 遍历原有数组中`list`将其存放在`newArray->lists`中 且是放在数组的末尾
8. 遍历`addedLists`将遍历的数据从数组的开始位置存储
9. 释放原有的`array()`
10. 设置新的`newArray`

- 通过上述有流程可得知
  - 如果只有主类的话的，一般会走`0 lists -> 1list`。方法列表中只有主类的方法
  - 如果存在分类的话，分类会加载到主类的前面。并且方法列表会变成指针数组，每一个指针都指向一个方法列表。
  - 如果有多分分类存在的话，多个分类都会添加到主类的前面，分类加载的顺序和编译顺序有关系。**先编译的先添加。**

![image.png](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/7f3b122fdbb243af83943b1d5fe8fd16~tplv-k3u1fbpfcp-zoom-in-crop-mark:3024:0:0:0.awebp)

## 关联对象

### 如何关联对象

- 使用`RunTime`给系统的类添加属性，首先需要了解对象与属性的关系。我们通过之前的学习知道，对象一开始初始化的时候其属性为`nil`，给属性赋值其实就是让属性指向一块存储内容的内存，使这个对象的属性跟这块内存产生一种关联。

- 那么如果想动态的添加属性，其实就是动态的产生某种关联就好了。而想要给系统的类添加属性，只能通过分类。

- 我们可以使用`@property`给分类添加属性

```objective-c
@property(nonatomic,strong)NSString *name;
```

> **虽然在分类中可以写@property添加属性，但是不会自动生成私有属性，也不会生成set,get方法的实现，只会生成set,get的声明，需要我们自己去实现。**

- `RunTime`提供了动态添加属性和获得属性的方法。

```objective-c
-(void)setName:(NSString *)name
{
    objc_setAssociatedObject(self, @"name",name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSString *)name
{
    return objc_getAssociatedObject(self, @"name");    
}
```

1. 动态添加属性

```objective-c
objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy);
```

参数一：**id object**: 给哪个对象添加属性，这里要给自己添加属性，用`self`。
参数二：**void \* == id key**: 属性名，根据key获取关联对象的属性的值，在`objc_getAssociatedObject`中通过次`key`获得属性的值并返回。
参数三：**id value**: 关联的值，也就是set方法传入的值给属性去保存。
参数四：**objc_AssociationPolicy policy**: 策略，属性以什么形式保存。
有以下几种

```objective-c
typedef OBJC_ENUM(uintptr_t, objc_AssociationPolicy) {
    OBJC_ASSOCIATION_ASSIGN = 0,  // 指定一个弱引用相关联的对象
    OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1, // 指定相关对象的强引用，非原子性
    OBJC_ASSOCIATION_COPY_NONATOMIC = 3,  // 指定相关的对象被复制，非原子性
    OBJC_ASSOCIATION_RETAIN = 01401,  // 指定相关对象的强引用，原子性
    OBJC_ASSOCIATION_COPY = 01403     // 指定相关的对象被复制，原子性   
};
```

2. 获得属性

```objective-c
objc_getAssociatedObject(id object, const void *key);
```

参数一：**id object** : 获取哪个对象里面的关联的属性。
参数二：**void \* == id key** : 什么属性，与**objc_setAssociatedObject**中的key相对应，即通过key值取出value。

3. 移除所有关联对象

```objective-c
- (void)removeAssociatedObjects
{
    // 移除所有关联对象
    objc_removeAssociatedObjects(self);
}
```

可以看出关联对象的使用非常简单，接下来我们来探寻关联对象的底层原理

### 关联对象的实现原理

#### 核心对象

- 实现关联对象技术的核心对象有

1. `AssociationsManager`
2. `AssociationsHashMap`
3. `ObjectAssociationMap`
4. `ObjcAssociation`
   其中`Map`同我们平时使用的字典类似。通过`key-value`一一对应存值。

首先我们来分析一下我上面提到的那几个核心对象

##### AssociationsManager

- 我们点进`AssociationsManager`查看其结构：

```c++
class AssociationsManager {
    // AssociationsManager中只有一个变量AssociationsHashMap
    static AssociationsHashMap *_map;
public:
    // 构造函数中加锁
    AssociationsManager()   { AssociationsManagerLock.lock(); }
    // 析构函数中释放锁
    ~AssociationsManager()  { AssociationsManagerLock.unlock(); }
    // 构造函数、析构函数中加锁、释放锁的操作，保证了AssociationsManager是线程安全的
    
    AssociationsHashMap &associations() {
        // AssociationsHashMap 的实现可以理解成单例对象
        if (_map == NULL)
            _map = new AssociationsHashMap();
        return *_map;
    }
};
```

##### AssociationsHashMap

- 我们来看一下`AssociationsHashMap`内部的源码

```c++
// AssociationsHashMap是字典，key是对象的disguised_ptr_t值，value是ObjectAssociationMap
class AssociationsHashMap : public unordered_map<disguised_ptr_t, ObjectAssociationMap *, DisguisedPointerHash, DisguisedPointerEqual, AssociationsHashMapAllocator> {
  public:
  void *operator new(size_t n) { return ::malloc(n); }
  void operator delete(void *ptr) { ::free(ptr); }
};
```

通过`AssociationsHashMap`内部源码我们发现`AssociationsHashMap`继承自`unordered_map`首先来看一下`unordered_map`内的源码

```c++
template <class _Key, class _Tp, class _Hash = hash<_Key>, class _Pred = equal_to<_Key>,
          class _Alloc = allocator<pair<const _Key, _Tp> > >
class _LIBCPP_TEMPLATE_VIS unordered_map
{
public:
    // types
    typedef _Key                                           key_type;
    typedef _Tp                                            mapped_type;
    typedef _Hash                                          hasher;
    typedef _Pred                                          key_equal;
    typedef _Alloc                                         allocator_type;
    typedef pair<const key_type, mapped_type>              value_type;
    typedef value_type&                                    reference;
    typedef const value_type&                              const_reference;
    static_assert((is_same<value_type, typename allocator_type::value_type>::value),
                  "Invalid allocator::value_type");
    static_assert(sizeof(__diagnose_unordered_container_requirements<_Key, _Hash, _Pred>(0)), "");

private:
    .......
}
```

从`unordered_map`源码中我们可以看出**_Key**和**_Tp**也就是前两个参数对应着`map`中的`Key`和`Value`，那么对照上面`AssociationsHashMap`内源码发现**_Key**中传入的是**disguised_ptr_t**，**_Tp**中传入的值则为**ObjectAssociationMap***。

##### ObjectAssociationMap

- 接着我们来到`ObjectAssociationMap`中

```c++
// ObjectAssociationMap是字典，key是从外面传过来的key，例如@selector(hello),value是关联对象，也就是ObjectAssociation
class ObjectAssociationMap : public std::map<void *, ObjcAssociation, ObjectPointerLess, ObjectAssociationMapAllocator> {
  public:
  void *operator new(size_t n) { return ::malloc(n); }
  void operator delete(void *ptr) { ::free(ptr); }
};
```

我们发现`ObjectAssociationMap`中同样以`key、Value`的方式存储着**ObjcAssociation**。

##### ObjcAssociation

- 接着我们来到`ObjcAssociation`中

```c++
// ObjcAssociation就是关联对象类
class ObjcAssociation {
  uintptr_t _policy;//策略
  // 值
  id _value;
  public:
  // 构造函数
  ObjcAssociation(uintptr_t policy, id value) : _policy(policy), _value(value) {}
  // 默认构造函数，参数分别为0和nil
  ObjcAssociation() : _policy(0), _value(nil) {}

  uintptr_t policy() const { return _policy; }
  id value() const { return _value; }

  bool hasValue() { return _value != nil; }
};
```

我们发现`ObjcAssociation`存储着**_policy**、**_value**，而这两个值我们可以发现正是我们调用**objc_setAssociatedObject**函数传入的值，也就是说我们在调用**objc_setAssociatedObject**函数中传入的`value和policy`这两个值最终是存储在**ObjcAssociation**中的。

- 下面我们用一张图来解释他们之间的关系

![关联对象的结构体](https://tva1.sinaimg.cn/large/006y8mN6ly1g7r9pjdlxnj31740nsafs.jpg)

- 这个结构有啥巧妙之处？
  1. 一个`objc`对象不光有一个属性需要关联时，比如说要关联`name`和`age`这两个属性，我们就以`objc`对象作为`disguised_ptr_t`，然后value是`ObjectAssociationMap`这个字典类型，在这个字典类型中，分别使用`@"name"`和`@"age"`作为`key`,传递进来的值和策略生成`ObjectAssociation`作为`value`。
  2. 如果有多个对象进行关联时，我们只需要在`AssociationHashMap`中创造更多的键值对就可以解决这个问题。
  3. **关联对象的值它不是存储在自己的实例对象的结构中，而是维护了一个全局的结构AssociationManager**

### 设置关联对象、获取关联对象流程

#### objc_setAssociatedObject

- 首先来到`runtime`源码，首先找到`objc_setAssociatedObject`函数，看一下其实现

```objective-c
// 设置关联对象的方法
void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy) {
    _object_set_associative_reference(object, (void *)key, value, policy);
}
```

我们看到其实内部调用的是`_object_set_associative_reference`函数，我们来到`_object_set_associative_reference`函数中

- `_object_set_associative_reference`函数

```objective-c
// 该方法完成了设置关联对象的操作
void _object_set_associative_reference(id object, void *key, id value, uintptr_t policy) {
    // retain the new value (if any) outside the lock.
    // 初始化空的ObjcAssociation(关联对象)
    ObjcAssociation old_association(0, nil);
    id new_value = value ? acquireValue(value, policy) : nil;
    {
        // 初始化一个manager
        AssociationsManager manager;
        AssociationsHashMap &associations(manager.associations());
        // 获取对象的DISGUISE值，作为AssociationsHashMap的key
        disguised_ptr_t disguised_object = DISGUISE(object);
        if (new_value) {
            // value有值，不为nil
            // break any existing association.
            // AssociationsHashMap::iterator 类型的迭代器
            AssociationsHashMap::iterator i = associations.find(disguised_object);
            if (i != associations.end()) {
                // secondary table exists
                // 获取到ObjectAssociationMap(key是外部传来的key，value是关联对象类ObjcAssociation)
                ObjectAssociationMap *refs = i->second;
                // ObjectAssociationMap::iterator 类型的迭代器
                ObjectAssociationMap::iterator j = refs->find(key);
                if (j != refs->end()) {
                    // 原来该key对应的有关联对象
                    // 将原关联对象的值存起来，并且赋新值
                    old_association = j->second;
                    j->second = ObjcAssociation(policy, new_value);
                } else {
                    // 无该key对应的关联对象，直接赋值即可
                    // ObjcAssociation(policy, new_value)提供了这样的构造函数
                    (*refs)[key] = ObjcAssociation(policy, new_value);
                }
            } else {
                // create the new association (first time).
                // 执行到这里，说明该对象是第一次添加关联对象
                // 初始化ObjectAssociationMap
                ObjectAssociationMap *refs = new ObjectAssociationMap;
                associations[disguised_object] = refs;
                // 赋值
                (*refs)[key] = ObjcAssociation(policy, new_value);
                // 设置该对象的有关联对象，调用的是setHasAssociatedObjects()方法
                object->setHasAssociatedObjects();
            }
        } else {
            // setting the association to nil breaks the association.
            // value无值，也就是释放一个key对应的关联对象
            AssociationsHashMap::iterator i = associations.find(disguised_object);
            if (i !=  associations.end()) {
                ObjectAssociationMap *refs = i->second;
                ObjectAssociationMap::iterator j = refs->find(key);
                if (j != refs->end()) {
                    old_association = j->second;
                    // 调用erase()方法删除对应的关联对象
                    refs->erase(j);
                }
            }
        }
    }
    // release the old value (outside of the lock).
    // 释放旧的关联对象
    if (old_association.hasValue()) ReleaseValue()(old_association);
}
```

- 首先根据我们传入的`value`经过`acquireValue`函数处理获取`new_value`。`acquireValue`函数内部其实是通过对策略的判断返回不同的值

```c++
// 根据policy的值，对value进行retain或者copy
static id acquireValue(id value, uintptr_t policy) {
    switch (policy & 0xFF) {
    case OBJC_ASSOCIATION_SETTER_RETAIN:
        return objc_retain(value);
    case OBJC_ASSOCIATION_SETTER_COPY:
        return ((id(*)(id, SEL))objc_msgSend)(value, SEL_copy);
    }
    return value;
}
```

- 之后创建`AssociationsManager manager`;以及拿到`manager`内部的`AssociationsHashMap`即**associations**。
  之后我们看到了我们传入的第一个参数`object`
  `object`经过`DISGUISE`函数被转化为了`disguised_ptr_t`类型的**disguised_object**。

```c++
typedef uintptr_t disguised_ptr_t;
inline disguised_ptr_t DISGUISE(id value) { return ~uintptr_t(value); }
inline id UNDISGUISE(disguised_ptr_t dptr) { return id(~dptr); }
```

`DISGUISE`函数其实仅仅对`object`做了位运算

#### objc_getAssociatedObject

- 接着我们来看看`objc_getAssociatedObject`函数

```c++
// 获取关联对象的方法
id objc_getAssociatedObject(id object, const void *key) {
    return _object_get_associative_reference(object, (void *)key);
}
```

- `objc_getAssociatedObject`内部调用的是`_object_get_associative_reference`

```c++
// 获取关联对象
id _object_get_associative_reference(id object, void *key) {
    id value = nil;
    uintptr_t policy = OBJC_ASSOCIATION_ASSIGN;
    {
        AssociationsManager manager;
        // 获取到manager中的AssociationsHashMap
        AssociationsHashMap &associations(manager.associations());
        // 获取对象的DISGUISE值
        disguised_ptr_t disguised_object = DISGUISE(object);
        AssociationsHashMap::iterator i = associations.find(disguised_object);
        if (i != associations.end()) {
            // 获取ObjectAssociationMap
            ObjectAssociationMap *refs = i->second;
            ObjectAssociationMap::iterator j = refs->find(key);
            if (j != refs->end()) {
                // 获取到关联对象ObjcAssociation
                ObjcAssociation &entry = j->second;
                // 获取到value
                value = entry.value();
                policy = entry.policy();
                if (policy & OBJC_ASSOCIATION_GETTER_RETAIN) {
                    objc_retain(value);
                }
            }
        }
    }
    if (value && (policy & OBJC_ASSOCIATION_GETTER_AUTORELEASE)) {
        objc_autorelease(value);
    }
    // 返回关联对像的值
    return value;
}
```

#### objc_removeAssociatedObjects

- `objc_removeAssociatedObjects`函数

```c++
// 移除对象object的所有关联对象
void objc_removeAssociatedObjects(id object) 
{
    if (object && object->hasAssociatedObjects()) {
        _object_remove_assocations(object);
    }
}
```

`objc_removeAssociatedObjects`函数内部调用的是`_object_remove_assocations`函数

```objective-c
// 移除对象object的所有关联对象
void _object_remove_assocations(id object) {
    // 声明了一个vector
    vector< ObjcAssociation,ObjcAllocator<ObjcAssociation> > elements;
    {
        AssociationsManager manager;
        AssociationsHashMap &associations(manager.associations());
        // 如果map size为空，直接返回
        if (associations.size() == 0) return;
        // 获取对象的DISGUISE值
        disguised_ptr_t disguised_object = DISGUISE(object);
        AssociationsHashMap::iterator i = associations.find(disguised_object);
        if (i != associations.end()) {
            // copy all of the associations that need to be removed.
            ObjectAssociationMap *refs = i->second;
            for (ObjectAssociationMap::iterator j = refs->begin(), end = refs->end(); j != end; ++j) {
                elements.push_back(j->second);
            }
            // remove the secondary table.
            delete refs;
            associations.erase(i);
        }
    }
    // the calls to releaseValue() happen outside of the lock.
    for_each(elements.begin(), elements.end(), ReleaseValue());
}
```

上述源码可以看出`_object_remove_assocations`函数将`object`对象向对应的所有关联对象全部删除。
