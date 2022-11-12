- [Swift底层原理-方法调度](#swift底层原理-方法调度)
  - [结构体方法](#结构体方法)
    - [extension中方法调用](#extension中方法调用)
  - [类方法](#类方法)
    - [函数表](#函数表)
    - [函数表在类中位置](#函数表在类中位置)
    - [extension中方法调用](#extension中方法调用-1)
  - [修饰函数的关键字](#修饰函数的关键字)
  - [总结](#总结)


# Swift底层原理-方法调度

- 我们知道，在`OC`中方法的调用是通过`objc_msgSend`来发送消息的；那么在`Swift`中，方法的调用时如何实现的呢？
- 而且在`swift`中不仅仅只有类可以定义方法，结构体也可以定义方法。下面就让我们分别研究一下他们的方法调用

## 结构体方法

- 我们通过汇编来查看一下，调用结构体的方法时，是如何调用的

```swift
struct Test {
    func test() {
        
    }
    
    func test1() {
        
    }
}

let test = Test()
test.test()
test.test1()
```

- 打下断点，进入汇编代码：

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h82fadvnoyj31qa0eydjm.jpg)

- 可以发现，在`Swift`中，调用一个结构体的方法是**直接拿到函数的地址直接调用**，包括初始化方法。
- `Swift`是一门静态语言，许多东西在编译器就已经确定了，所以才可以直接拿到函数的地址进行调用，这个调用的形式也可以称作`静态派发`。
- 这个函数地址在编译器决定，并存储在`__text`段中，也就是代码段中

### extension中方法调用

- 给`Test`添加一个`extension`，创建一个`test3`方法：

```swift
extension Test {
    func test3() {
        
    }
}
```

- 通过汇编查看

![- ](https://tva1.sinaimg.cn/large/008vxvgGgy1h82g0k4tdvj31ow0bkq61.jpg)

- `struct`的`extension`的方法依然是直接调用(**静态派发**)

## 类方法

- 前面我们已经了解了`Swift`结构体的方法调用，那么`Swift`的类呢

```swift
class Test {
    func test() {
        
    }
    
    func test1() {
        
    }
}

let test = Test()
test.test()
test.test1()
```

- 开启汇编调试

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h82gego0hvj31qi0scgtd.jpg)

- 在看汇编代码前，可以简单的认识几个汇编指令，就可以大致了解以上汇编内容

  - `mov`：将某一寄存器的值复制到另一寄存器（只能用于寄存器与寄存器或者寄存器与常量之间传值，不能用于内存地址），如

  ```c++
  mov x1, x0    将寄存器x0的值符知道寄存器x1中
  ```

  - `ldr`：将内存中的值读取到寄存器中，如:

  ```c++
  ldr x0, [x1, x2] 将寄存器x1和寄存器x2的值相加作为地址，取改地址的值放入寄存器x0中
  ```

  - `bl`、`blr`：跳转到某地址（有返回）
  - `x`代表寄存器，`x0`用来存放函数计算结果

- 在第8行，`mov x20， x0`，`x0`里面存放的是`test`对象
- 在第14行，`ldr  x8, [x20]`，把`test`对象首地址，也就是`metedata`放在`x8`中。

- 然后通过对`metedate`的偏移，拿到函数的地址。

- 总结：`swift`中函数调用分为了3个步骤
  1. 找到`metadata`
  2. 确定函数地址（`metadata` + 偏移量）
  3. 执行函数

- 那么这些函数地址存放在哪里呢？

### 函数表

- 我们生成`sil`文件，看一下编译时做了哪些操作

- 来到`sil`文件底部

```c++
sil_vtable Test {
  #Test.test: (Test) -> () -> () : @$s4main4TestC4testyyF	// Test.test()
  #Test.test1: (Test) -> () -> () : @$s4main4TestC5test1yyF	// Test.test1()
  #Test.init!allocator: (Test.Type) -> () -> Test : @$s4main4TestCACycfC	// Test.__allocating_init()
  #Test.deinit!deallocator: @$s4main4TestCfD	// Test.__deallocating_deinit
}
```

- 通过`sil`可以发现，`Test`的三个方法都是存放在`sil_vtable`中的，他就是类的函数表；

- 函数表用来存储类中的方法，存储方式类似于数组，方法连续存放在函数表中。

### 函数表在类中位置

- 在上一篇文章结构体与类中，我们把`Swift`类的本质挖掘出来了，它里面有一个 `metadata`

```c++
struct Metadata {
    var kind: Int
    var superClass: Any.Type
    var cacheData: (Int, Int)
    var data: Int
    var classFlags: Int32
    var instanceAddressPoint: UInt32
    var instanceSize: UInt32
    var instanceAlignmentMask: UInt16
    var reserved: UInt16
    var classSize: UInt32
    var classAddressPoint: UInt32
    var typeDescriptor: UnsafeMutableRawPointer
    var iVarDestroyer: UnsafeRawPointer
}
```

- 在此结构中我们需要注意这样一个`typeDescriptor`属性，不管是`Class`，`Struct`还是`Enum`都有自己的`Descriptor`
- 我们从源码中找到`Description`定义，发现它是`TargetClassDescriptor` 类型的类

```c++
template <typename Runtime>
class TargetClassDescriptor final
    : public TargetTypeContextDescriptor<Runtime>,
      public TrailingGenericContextObjects<TargetClassDescriptor<Runtime>,
                              TargetTypeGenericContextDescriptorHeader,
                              /*additional trailing objects:*/
                              TargetResilientSuperclass<Runtime>,
                              TargetForeignMetadataInitialization<Runtime>,
                              TargetSingletonMetadataInitialization<Runtime>,
                              TargetVTableDescriptorHeader<Runtime>,
                              TargetMethodDescriptor<Runtime>,
                              TargetOverrideTableHeader<Runtime>,
                              TargetMethodOverrideDescriptor<Runtime>,
                              TargetObjCResilientClassStubInfo<Runtime>> {
	// 省略具体实现
}
```

- 根据继承关系慢慢对比，对比出来的结果，`TargetClassDescriptor`里面的属性如下

```c++
class TargetClassDescriptor {
    ContextDescriptorFlags Flags;
    TargetRelativeContextPointer<Runtime> Parent;
    TargetRelativeDirectPointer<Runtime, const char, /*nullable*/ false> Name;
    TargetRelativeDirectPointer<Runtime, MetadataResponse(...),
                              /*Nullable*/ true> AccessFunctionPtr;
    TargetRelativeDirectPointer<Runtime, const reflection::FieldDescriptor,
                              /*nullable*/ true> Fields;
    TargetRelativeDirectPointer<Runtime, const char> SuperclassType;
    uint32_t MetadataNegativeSizeInWords;
    uint32_t MetadataPositiveSizeInWords;
    uint32_t NumImmediateMembers;
    uint32_t NumFields;
    uint32_t FieldOffsetVectorOffset;
}
```

- 在其中并没有`vtable`相关的属性，我们想法是找到这个类的初始化方法，里面肯定有关于属性的初始化流程。然后找到`ClassContextDescriptorBuilder`这样一个类，内容的描述建立者，这个类就是创建 `Descriptor` 的类。

```c++
class ClassContextDescriptorBuilder
    : public TypeContextDescriptorBuilderBase<ClassContextDescriptorBuilder,
                                              ClassDecl>,
      public SILVTableVisitor<ClassContextDescriptorBuilder>
  {
    using super = TypeContextDescriptorBuilderBase;
  
    ClassDecl *getType() {
      return cast<ClassDecl>(Type);
    }

    // Non-null unless the type is foreign.
    ClassMetadataLayout *MetadataLayout = nullptr;

    Optional<TypeEntityReference> ResilientSuperClassRef;

    SILVTable *VTable;
    bool Resilient;

    SmallVector<SILDeclRef, 8> VTableEntries;
    SmallVector<std::pair<SILDeclRef, SILDeclRef>, 8> OverrideTableEntries;

  public:
    ClassContextDescriptorBuilder(IRGenModule &IGM, ClassDecl *Type,
                                  RequireMetadata_t requireMetadata)
      : super(IGM, Type, requireMetadata),
        VTable(IGM.getSILModule().lookUpVTable(getType())),
        Resilient(IGM.hasResilientMetadata(Type, ResilienceExpansion::Minimal)) {

      if (getType()->isForeign()) return;

      MetadataLayout = &IGM.getClassMetadataLayout(Type);

      if (auto superclassDecl = getType()->getSuperclassDecl()) {
        if (MetadataLayout && MetadataLayout->hasResilientSuperclass())
          ResilientSuperClassRef = IGM.getTypeEntityReference(superclassDecl);
      }

      addVTableEntries(getType());
    }

    void addMethod(SILDeclRef fn) {
      VTableEntries.push_back(fn);
    }

    void addMethodOverride(SILDeclRef baseRef, SILDeclRef declRef) {
      OverrideTableEntries.emplace_back(baseRef, declRef);
    }

    void layout() {
      super::layout();
      addVTable();
      addOverrideTable();
      addObjCResilientClassStubInfo();
    }
          
	// 省略部分方法
}
```

- 在类中找到 `layout` 这个方法：

```c++
void layout() {
    super::layout();
    addVTable();
    addOverrideTable();
    addObjCResilientClassStubInfo();
}
```

- 在这里调用了`addVTable`方法

```c++
void addVTable() {
    if (VTableEntries.empty())
        return;

    // Only emit a method lookup function if the class is resilient
    // and has a non-empty vtable.
    if (IGM.hasResilientMetadata(getType(), ResilienceExpansion::Minimal))
        IGM.emitMethodLookupFunction(getType());

    auto offset = MetadataLayout->hasResilientSuperclass()
        ? MetadataLayout->getRelativeVTableOffset()
        : MetadataLayout->getStaticVTableOffset();
    B.addInt32(offset / IGM.getPointerSize());
    B.addInt32(VTableEntries.size());

    for (auto fn : VTableEntries)
        emitMethodDescriptor(fn);
}
```

- 在该函数中，首先拿到当前`descriptor`的内存偏移，这个偏移量是 `TargetClassDescriptor` 这个结构中的成员变量所有内存大小之和，并且在最后还拿到了 `VTableEntries.size()`。
- 然后在这个偏移位置开始添加方法。
- 总结：虚函数表的内存地址，是 `TargetClassDescriptor` 中的最后一个成员变量，添加方法的形式是追加到数组的末尾。所以这个虚函数表是按顺序连续存储类的方法的指针。

### extension中方法调用

- 在原有`Test`类基础上添加`extension`，并添加`test2`方法

```swift
extension Test {
    func test2() {
        
    }
}
```

- 通过汇编查看

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h82gw101i2j31qo0m4n2t.jpg)

- 我们发现它并没有获取`metedata`，进行偏移的方式来获取函数地址，而是通过地址直接进行调用，也就是采用静态派发方式。
- 这里方法为什么没有添加到函数表中呢？
  - 一方面是类是可以继承的，如果给父类添加`extension`方法，继承该类的所有子类都可以调用这些方法。并且每个子类都有自己的函数表，所以这个时候方法存储就成为问题。
- 所以为了解决这个问题，直接把 `extension` 独立于虚函数表之外，采用静态调用的方式。在程序进行编译的时候，函数的地址就已经知道了。

## 修饰函数的关键字

- `final`： 添加了`final`关键字的函数无法被写， 使用静态派发， 不会在`vtable`中出现， 且对`objc`运行时不可见。 如果在实际开发过程中，属性、方法、类不需要被重载的时候，可以添加`final`关键字。

- `dynamic`： 函数均可添加`dynamic`关键字，为非`objc`类和值类型的函数赋予动态性，但派发方式还是函数表派发。

- `@objc`： 该关键字可以将`swift`函数暴露给`Objc`运行时， 依旧是函数表派发。

- `@objc + dynamic`： 消息发送的方式。

## 总结

- `Swift`中的方法调用分为**静态派发**和**动态派发**两种
- 值类型中的方法就是**静态派发**
- 引用类型中的方法就是**动态派发**，其中函数的调度是通过`V-Table函数表`来进行调度的

| 类型         | 调度方式   | extension |
| ------------ | ---------- | --------- |
| 值类型       | 静态派发   | 静态派发  |
| 类           | 函数表派发 | 静态派发  |
| NSObject子类 | 函数表派发 | 静态派发  |
