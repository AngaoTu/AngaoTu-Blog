- [Runtime源码剖析-对象](#runtime源码剖析-对象)
  - [预备知识](#预备知识)
    - [Clang](#clang)
      - [什么是Clang](#什么是clang)
      - [终端编译命令](#终端编译命令)
  - [对象](#对象)
    - [对象结构](#对象结构)
    - [struct objc_object](#struct-objc_object)
    - [isa_t](#isa_t)
      - [ISA_BITFIELD](#isa_bitfield)
      - [总结](#总结)

# Runtime源码剖析-对象

## 预备知识

- 如果大家对**联合体**、位域相关知识不够熟悉的话，请参考[联合体+位域](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/%E8%81%94%E5%90%88%E4%BD%93%E4%B8%8E%E4%BD%8D%E5%9F%9F.md)

### Clang

#### 什么是Clang

> `Clang`是一个`C语言`、`C++`、`Objective-C`语言的轻量级编译器。源代码发布于`BSD`协议下。`Clang`将支持其普通`lambda`表达式、返回类型的简化处理以及更好的处理`constexpr`关键字。**`Clang`是一个有Apple主导编写，基于`LLVM`的`C/C++/Objective-C/Objective-C++`编译器**。

- 简单来说就是一个编译器，可以把我们写的`OC`代码，编译成`C++`代码。便于观察底层逻辑。

#### 终端编译命令

1. 首先需要在`main.m`文件中，创建一个`Person`类，然后在`main`函数中，创建一个对象

```objective-c
@interface Person : NSObject
@property (nonatomic, copy) NSString *name;
@end

@implementation Person

@end
    
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Person *person1 = [[Person alloc] init];
    }
    return 0;
}
```

2. 然后使用`clang`命令，把`.m`文件转换成`.cpp`文件

```c++
// 1. 通过clang命令
clang -rewrite-objc main.m -o main.cpp 

// 编译引入 UIKit的文件
// UIKit报错
clang -x objective-c -rewrite-objc -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk main.m

// 2. xcode安装的时候顺带安装了xcrun命令，xcrun命令在clang的基础上进行了一些封装，要更好用一些
// 模拟器编译
xcrun -sdk iphonesimulator clang -arch arm64 -rewrite-objc main.m -o main-arm64.cpp 
// 真机编译
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.m -o main- arm64.cpp 
```

- 执行完后，会在对应目录下生成`.cpp`文件

## 对象

### 对象结构

- 打开`.cpp`文件，我们想要知道对象的结构，于是我们先去寻找`main`方法，因为在oc中，我们在这个方法中创建了一个`Person`对象。

```c++
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        Person *person1 = ((Person *(*)(id, SEL))(void *)objc_msgSend)((id)((Person *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Person"), sel_registerName("alloc")), sel_registerName("init"));
    }
    return 0;
}
```

- 然后我们发现最终创建了一个`Person`类型的指针，引用着`Person`对象。接着我们去查询`Person`的定义

```c++
#ifndef _REWRITER_typedef_Person
#define _REWRITER_typedef_Person
typedef struct objc_object Person;
typedef struct {} _objc_exc_Person;
#endif
```

- 发现其实`Person`对象，就是一个`objc_object`类型的结构体，我们接着去查询`objc_object`的定义

```c++
typedef struct objc_class *Class;

struct objc_object {
    Class _Nonnull isa __attribute__((deprecated));
};
```

- 这个时候发现，原来它内部包含了一个`Class`类型的指针，也就是说`Person`对象内部只有一个指针。本以为我们已经接近真相了，突然发现`__attribute__((deprecated))`这个标识符，通过查询它表示该变量已经被**废弃**。也就是说其实`objc_object`内部是空的什么也没有。我们现在已经得知对象就是一个`struct objc_object`类型的结构体，现在想要知道它内部是怎么实现的。这个时候通过苹果开源的`OBJC4`源码中，去查找对应的结构。

### struct objc_object

```c++
struct objc_object {
private:
    isa_t isa;
public:
	// 此处省略方法
};
```

- 可以看到除了一些公开方法外，只有一个成员变量，类型为`isa_t`的变量

### isa_t

```c++
union isa_t {
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }

    uintptr_t bits;
private:
    Class cls;

public:
#if defined(ISA_BITFIELD)
    struct {
        ISA_BITFIELD;  // defined in isa.h
    };

    // 省略此处方法
#endif
    // 省略此处方法
};
```

- 此处`isa_t`是一个联合体，如果对这一块知识不够数序的，可以查看本文预备知识[联合体+位域](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/%E8%81%94%E5%90%88%E4%BD%93%E4%B8%8E%E4%BD%8D%E5%9F%9F.md)
- 它一共有两个成员变量`bits`和`cls`，共同占用这一段内存空间，由于它们是互斥的，同时只能使用其中一个变量
- `isa_t`中还有一个结构体，其中`ISA_BITFIELD`位域信息，表述了`bits`的每一位的信息。所以本质上`isa_t`是一个联合体位域。下面我们看一下具体位域信息

#### ISA_BITFIELD

- 点击这个宏，你发现它对应两个版本。一个是`__arm64__`（iOS真机+模拟器），一个是`__x86_64__`（macOS）。这里我们就选择`arm64`真机版本来查看

```c++
#     define ISA_MASK        0x0000000ffffffff8ULL
#     define ISA_MAGIC_MASK  0x000003f000000001ULL
#     define ISA_MAGIC_VALUE 0x000001a000000001ULL
#     define ISA_HAS_CXX_DTOR_BIT 1
#     define ISA_BITFIELD                                                      \
        uintptr_t nonpointer        : 1;                                       \
        uintptr_t has_assoc         : 1;                                       \
        uintptr_t has_cxx_dtor      : 1;                                       \
        uintptr_t shiftcls          : 33; /*MACH_VM_MAX_ADDRESS 0x1000000000*/ \
        uintptr_t magic             : 6;                                       \
        uintptr_t weakly_referenced : 1;                                       \
        uintptr_t unused            : 1;                                       \
        uintptr_t has_sidetable_rc  : 1;                                       \
        uintptr_t extra_rc          : 19
#     define RC_ONE   (1ULL<<45)
#     define RC_HALF  (1ULL<<18)
```

- 下面我们看一下具体的存储地址

![](http://ww4.sinaimg.cn/large/006y8mN6ly1g67nqwjw3aj31900u0q4r.jpg)

- 各变量的含义：
  1. `nonpointer`：表示是否对`isa`指针进行优化，`0`表示纯指针，`1`表示不止是类对象的地址，isa中包含了类信息、对象、引用计数等
  2. `has_assoc`：关联对象标志位，`0`表示未关联，`1`表示关联
  3. `has_cxx_dtor`：该对象是否`C ++` 或者`Objc`的析构器，如果有析构函数，则需要做析构逻辑，没有，则释放对象
  4. `shiftcls`：储存类指针的值，开启指针优化的情况下，在`arm64`架构中有`33`位用来存储类指针，`x86_64`架构中占`44`位
  5. `magic`：用于调试器判断当前对象是`真的对象`还是`没有初始化`的空间
  6. `weakly_referenced`：指对象是否被指向或者曾经指向一个`ARC`的弱变量，没有弱引用的对象可以更快释放
  7. `deallocating`：标志对象是否正在释放
  8. `has_sidetable_rc`：当对象引用计数大于`10`时，则需要借用该变量存储进位
  9. `hextra_rc`：表示该对象的引用计数值，实际上引用计数值减`1`，例如，如果对象的引用计数为`10`，那么`extra_rc`为`9`，如果大于`10`，就需要用到上面的`has_sidetable_rc

#### 总结

- `isa_t`分为`nonpointer`类型和非`nonpointer`。非`nonpointer`类型只是一个纯指针，`nonpointer`还包含了类的信息。什么是`nonpointer`和非`nonpointer`，参考[Non-pointer isa](<http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html>)

- `isa_t`是`联合体`+`位域`的方式存储信息的。采用这种方式的有点就是`节省大量内存`。通过位域的方式，可以在`isa`上面存储更多相关信息，内存得到充分的利用