- [Runtime源码解析-类](#runtime源码解析-类)
  - [类](#类)
    - [objc_class](#objc_class)
  - [元类](#元类)
    - [元类](#元类-1)
    - [isa关系链](#isa关系链)

# Runtime源码解析-类

- 在前面我们探究对象、以及`alloc`流程时，发现了`isa_t`和类之间有关联，那我们先具体探究一下类的结构。

## 类

### objc_class

```objective-c
struct objc_class : objc_object {
    // 省略初始化方法
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags
	
  	// 省略其他方法
}
```

- 从继承关系我们就会发现，原来`objc_class`是继承于`objc_object`。
  - 那就是说**类其实也是一个对象**
  - 还说明类实例化后也会包含`isa`这样一个成员

![](http://ww3.sinaimg.cn/large/006y8mN6ly1g67ls7mk1uj30nf07dwen.jpg)

- 我们在看看它的成员变量
  1. 第一个变量`superclass`:指向他的父类
  2. 第二个变量`cache`:这里面存储的方法缓存，这个知识点我会在下一篇文章中仔细剖析
  3. 第三个变量`bits`：存储对象的方法、属性、协议等信息，这个知识点我会在下一篇文章中仔细剖析。[Runtime源码解析-类中bits](https://github.com/AngaoTu/AngaoTu-Blog/blob/main/OC%E5%BA%95%E5%B1%82%E5%8E%9F%E7%90%86/Runtime/3.%20Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-%E7%B1%BB/Runtime%E6%BA%90%E7%A0%81%E8%A7%A3%E6%9E%90-%E7%B1%BB%E4%B8%ADbits.md)
- 这个时候就会有一个疑问？
  - 既然类继承对象，它也有一个`isa `，前面我们说了这个成员的作用是记录类的信息的，那么我们类也拥有这个成员，那它也应该来记录一些信息，那它记得的是什么信息呢？这个时候我们需要引进一个概念**元类**

## 元类

### 元类

- 元类的定义：元类是`Class`对象的类，类的`isa`会指向其元类

- 根类的定义：根类是所有对象的父类（除了特殊情况），它没有父类，一般情况下就是指NSObject

- 为什么会定义元类这个类？

  > 方法的调用机制：
  >
  > - 因为在 `Objective-C `中，对象的方法并**没有存储于对象的结构体中**（如果每一个对象都保存了自己能执行的方法，那么对内存的占用有极大的影响）。
  >
  > - 当**实例方法**被调用时，它要通过自己持有的 `isa` 来查找对应的类，然后在这里的 `class_data_bits_t` 结构体中查找对应方法的实现。同时，每一个 `objc_class` 也有一个**指向自己的父类的指针** `super_class` 用来查找继承的方法。

  - 既然类中存储的是实例方法，每个对象需要调用实例方法都来类里寻找即可，那么如果一个类需要调用类方法的时候，我们是如何查找并调用的呢？
    - 这个时候就需要引入**元类**来保证无论是类还是对象都能**通过相同的机制查找方法的实现**。

- 引入元类这个概念后，这样就达到了使类方法和实例方法的调用机制相同的目的：

  - 实例方法调用时，通过对象的 `isa` 在类中获取方法的实现
  - 类方法调用时，通过类的 `isa` 在元类中获取方法的实现

### isa关系链

- 下面这张图介绍了对象、类与元类之间的关系

![](http://ww4.sinaimg.cn/large/006y8mN6ly1g67ml59sgdj30px0r5abj.jpg)

- `isa`关系：
  1. 对象的`isa`指向类，类的`isa`指向元类
  2. 元类的`isa`指向根元类
  3. 根元类的`isa`指向根元类自己
- 继承关系：
  1. 继承关系不包括对象，只是类、元类之间的关系
  2. 所有的类都继承自`NSObject`
  3. `NSObject`元类继承自`NSObject`类，`NSObject`类继承自`nil`

- 总结：
  - `元类`是系统编译器自动创建的，和用户没关系
  - 对象的`isa`指向**类**，类对象的`isa`指向**元类**
  - **元类**用来存储类信息，所有的类方法都存储在元类中