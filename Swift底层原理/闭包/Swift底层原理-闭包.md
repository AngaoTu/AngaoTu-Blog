[toc]

# Swift底层原理-闭包

## 函数类型

- 在`Swift`中函数本身也有自己的类型，它由形式参数类型，返回类型组成。
- 函数也是一个引用类型
- 那么函数类型的本质是什么呢，我们打开源码，在`Metadata.h`文件中找到`TargetFunctionTypeMetadata`：

```c++
template <typename Runtime>
struct TargetFunctionTypeMetadata : public TargetMetadata<Runtime> {
  using StoredSize = typename Runtime::StoredSize;
  using Parameter = ConstTargetMetadataPointer<Runtime, swift::TargetMetadata>;

  TargetFunctionTypeFlags<StoredSize> Flags;

  /// The type metadata for the result type.
  ConstTargetMetadataPointer<Runtime, swift::TargetMetadata> ResultType;

  Parameter *getParameters() { return reinterpret_cast<Parameter *>(this + 1); }

  const Parameter *getParameters() const {
    return reinterpret_cast<const Parameter *>(this + 1);
  }

  Parameter getParameter(unsigned index) const {
    assert(index < getNumParameters());
    return getParameters()[index];
  }

  // 省略部分方法
}
```

- 由于`TargetFunctionTypeMetadata`继承自`TargetMetadata`，那么它必然有`Kind`
- 然后它自身又拥有`Flags`和`ResultType`，`ResultType`是返回值类型的元数据。
- 还有一个连续的空间存储的是参数列表

- 接下来我们看到`getParameters`函数

```c++
Parameter *getParameters() { return reinterpret_cast<Parameter *>(this + 1); }
```

- 这个函数通过`reinterpret_cast`将 (this + 1) 强制转换成`Parameter *`类型，然后返回的是指针类型。
- 所以这个函数返回的是一块连续的内存空间，这一块连续的内存空间存储的是`Parameter`类型的数据。



## 闭包介绍

- 闭包是一个可以**捕获上下文的常量或者变量的函数**

- 我们先看一下官方给的例子

```swift
func makeIncrementer() -> () -> Int {
    var runningTotal = 10
    func incrementer() -> Int {
        runningTotal += 1
        return runningTotal
        
    }
    return incrementer
}
```

- 这里`incrementer`作为一个闭包，显然他是一个函数，其次为了保证其执行，要捕获外部变量`runningTotal` 到内部，所以闭包的关键就有**捕获外部变量或常量** 和 **函数**

- 闭包的表现形式：
  - 全局函数是一个有名字但不会捕获任何值的闭包。
  - 嵌套函数是一个有名字并可以捕获到其封闭函数域内的值的闭包。
  - 闭包表达式是一个利用轻量级语法所写的，可以捕获其上下文中变量或常量值的匿名闭包。



## 闭包表达式

- 闭包表达式是一种利用简洁语法构建内联闭包的方式。闭包表达式提供了一些语法优化，使得撰写闭包变得简单明了。

### 定义闭包表达式

在使用闭包的时候，可以用下面的方式来定义一个闭包表达式

```Swift
{ (param type) -> (return type) in
    //do somethings
}
复制代码
```

可以看到闭包表达式是由**作用域（花括号）**、**函数类型**、**关键字in**、**函数体构成**。

### 闭包作为变量和参数

- 作为变量

```Swift
var closure: (Int) -> Int = { (a: Int) -> Int in
	return a + 100
}
```

- 作为参数

```Swift
func func3(_ someThing: @escaping (() -> Void)) {
   	
}
```

### 闭包表达式的优点

- 可以根据上下文推断出参数类型和返回值类型

- 单行表达式闭包可以通过省略`return`关键字来隐式返回单行表达式的结果

- `Swift`自动为内联闭包提供了参数名称缩写功能，你可以直接通过`$0，$1，$2`来顺序调用闭包的参数，以此类推。

- 如果你在闭包表达式中使用参数名称缩写，你可以在闭包定义中省略参数列表，并且对应参数名称缩写的类型会通过函数类型进行推断。`in`关键字也同样可以被省略，因为此时闭包表达式完全由闭包函数体构成

  

## 闭包捕获值

### 闭包捕获局部变量

- 我们先来看一个例子

```swift
func makeIncrementer() -> () -> Int {
    var runningTotal = 10
    func incrementer() -> Int {
        runningTotal += 1
        return runningTotal
        
    }
    return incrementer
}

let fn = makeIncrementer()
print(fn())
print(fn())
print(fn())

// 打印结果：
// 11
// 12
// 13
```

- 每次调用`fn`，但是每次打印都是不一样的，按理说`runningTotal`是一个局部变量，每次打印应该结果一致。我们通过`sil`查看一下

```c++
// makeIncrementer()
sil hidden [ossa] @$s4main15makeIncrementerSiycyF : $@convention(thin) () -> @owned @callee_guaranteed () -> Int {
bb0:
  %0 = alloc_box ${ var Int }, var, name "runningTotal" // users: %11, %8, %1
  %1 = project_box %0 : ${ var Int }, 0           // users: %9, %6
  %2 = integer_literal $Builtin.IntLiteral, 10    // user: %5
  %3 = metatype $@thin Int.Type                   // user: %5
  // function_ref Int.init(_builtinIntegerLiteral:)
  %4 = function_ref @$sSi22_builtinIntegerLiteralSiBI_tcfC : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %5
  %5 = apply %4(%2, %3) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %6
  store %5 to [trivial] %1 : $*Int                // id: %6
  // function_ref incrementer #1 () in makeIncrementer()
  %7 = function_ref @$s4main15makeIncrementerSiycyF11incrementerL_SiyF : $@convention(thin) (@guaranteed { var Int }) -> Int // user: %10
  %8 = copy_value %0 : ${ var Int }               // user: %10
  mark_function_escape %1 : $*Int                 // id: %9
  %10 = partial_apply [callee_guaranteed] %7(%8) : $@convention(thin) (@guaranteed { var Int }) -> Int // user: %12
  destroy_value %0 : ${ var Int }                 // id: %11
  return %10 : $@callee_guaranteed () -> Int      // id: %12
} // end sil function '$s4main15makeIncrementerSiycyF'
```

1. 在`%0`行，通过`alloc_box`申请了一个堆上的地址，并将地址给了`RunningTotal`，将变量存储到堆上
2. 在`%1`行，通过`project_box`从堆上取出变量
3. 在`%7`行，将取出的变量交给闭包使用。

- 通过汇编验证一下，在`makeIncrementer`方法内部调用了`swift_allocObject`方法

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h8bvj80gnaj32400tq46h.jpg)

- `swift_allocObject`方法，这个方法在干什么，在申请并分配堆空间的内存，所以实际上闭包会开辟堆空间的内存。



### 闭包捕获全局变量

- 在捕获局部变量时，会开辟堆内存空间，那么捕获全局变量说呢

```swift
var runningTotal = 10
func makeIncrementer() -> () -> Int {
    func incrementer() -> Int {
        runningTotal += 1
        return runningTotal
    }
    return incrementer
}

let fn = makeIncrementer()
print(fn())
print(fn())
print(fn())
```

- 我们通过汇编发现，在`makeIncrementer`中没有进行任何堆内存开辟操作，它直接把函数地址返回出去

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h8bvn4p5ctj31ks08iq4d.jpg)

- 接着进入`incrementer`方法中

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h8bvouhm5bj31po0u046v.jpg)

- 它是直接拿到全局变量`runningTotal`直接修改的。所以函数不会去捕获全局变量/常量，因此这种行为严格上也不叫做闭包。



## 闭包的本质

- 在我们进行闭包本质探索时，需要借助`IR`的代码进行分析，我们先来熟悉一下`IR`部分语法

### IR部分语法

- 数组：

```swift
[<elementnumber> x <elementtype>]
//example
alloca [24 x i8], align 8 24个i8都是0
alloca [4 x i32] === array
```

- 结构体：

```swift
%swift.refcounted = type { %swift.type*, i64 }

//表示形式
%T = type {<type list>} //这种和C语言的结构体类似
```

- 指针类型：

```swift
<type> *

//example
i64* //64位的整形
```

- `getelementptr` 指令：

`LLVM`中我们获取数组和结构体的成员，通过 `getelementptr` ，语法规则如下：

```swift
<result> = getelementptr <ty>, <ty>* <ptrval>{, [inrange] <ty> <idx>}*
<result> = getelementptr inbounds <ty>, <ty>* <ptrval>{, [inrange] <ty> <idx}
```

- 这里举个例子

```c++
struct munger_struct{
    int f1;
    int f2;
};

// munger_struct 的地址
// i64 0 取出的是 struct.munger_struct类型的指针
getelementptr inbounds %struct.munger_struct, %struct.munger_struct %1, i64 0

// munger_struct 第一个元素
// i64 0 取出的是 struct.munger_struct类型的指针
// i32 0取出的是 struct.munger_struct结构体中的第一个元素
getelementptr inbounds %struct.munger_struct, %struct.munger_struct %1, i64 0, i32 0

// munger_struct 第二个元素
// i64 0 取出的是 struct.munger_struct类型的指针
// i32 1取出的是 struct.munger_struct结构体中的第二个元素
getelementptr inbounds %struct.munger_struct, %struct.munger_struct %1, i64 0, i32 1
```

### 分析闭包

- 把下面这个例子，转换成`IR`文件

```c++
func makeIncrementer() -> () -> Int {
    var runningTotal = 10
    func incrementer() -> Int {
        runningTotal += 1
        return runningTotal
    }
    return incrementer
}

let fn = makeIncrementer()
```

#### main函数分析

- 我们先找到`main`函数

```c++
define i32 @main(i32 %0, i8** %1) #0 {
entry:
  %2 = bitcast i8** %1 to i8*
  // 调用makeIncrementer函数
  %3 = call swiftcc { i8*, %swift.refcounted* } @"$s4main15makeIncrementerSiycyF"()
  %4 = extractvalue { i8*, %swift.refcounted* } %3, 0
  %5 = extractvalue { i8*, %swift.refcounted* } %3, 1
  store i8* %4, i8** getelementptr inbounds (%swift.function, %swift.function* @"$s4main2fnSiycvp", i32 0, i32 0), align 8
  store %swift.refcounted* %5, %swift.refcounted** getelementptr inbounds (%swift.function, %swift.function* @"$s4main2fnSiycvp", i32 0, i32 1), align 8
  ret i32 0
}
```

- 在`%3`这一行，调用`makeIncrementer`函数，并且它的返回值是一个 `{ i8*, %swift.refcounted* }`，我们全局搜索一下这个结构

```c++
%swift.function = type { i8*, %swift.refcounted* }
%swift.refcounted = type { %swift.type*, i64 }
%swift.type = type { i64 }
```

- 根据`IR`语法进行分析：
  - `{ i8*, %swift.refcounted* }`是一个结构体，这个结构体包含两个成员变量，分别为 `i8*` 类型的成员和 `%swift.refcounted*` 类型的成员。
  - `%swift.refcounted*`是一个结构体指针，它的结构为`{ %swift.type*, i64 }`，这个结构体包含两个成员变量，分别为 `%swift.type*`类型的成员和`i64`类型的成员。
  - `%swift.type`是一个结构体，它的结构为 `{ i64 }`，它只包含`i64`类型的成员变量。



#### makeIncrementer函数分析

- 接下来进入该函数

```c++
define hidden swiftcc { i8*, %swift.refcounted* } @"$s4main15makeIncrementerSiycyF"() #0 {
entry:
  %runningTotal.debug = alloca %TSi*, align 8
  %0 = bitcast %TSi** %runningTotal.debug to i8*
  call void @llvm.memset.p0i8.i64(i8* align 8 %0, i8 0, i64 8, i1 false)
      
  // 调用swift_allocObject创建一个实例对象
  %1 = call noalias %swift.refcounted* @swift_allocObject(%swift.type* getelementptr inbounds (%swift.full_boxmetadata, %swift.full_boxmetadata* @metadata, i32 0, i32 2), i64 24, i64 7) #1
  %2 = bitcast %swift.refcounted* %1 to <{ %swift.refcounted, [8 x i8] }>*
  
  // 获取{ %swift.refcounted, [8 x i8] }中第二个元素[8 x i8]
  %3 = getelementptr inbounds <{ %swift.refcounted, [8 x i8] }>, <{ %swift.refcounted, [8 x i8] }>* %2, i32 0, i32 1
  %4 = bitcast [8 x i8]* %3 to %TSi*
  store %TSi* %4, %TSi** %runningTotal.debug, align 8
      
  // 取出局部变量
  %._value = getelementptr inbounds %TSi, %TSi* %4, i32 0, i32 0
  store i64 10, i64* %._value, align 8
  %5 = call %swift.refcounted* @swift_retain(%swift.refcounted* returned %1) #1
  call void @swift_release(%swift.refcounted* %1) #1

  // 插入局部变量地址
  %6 = insertvalue { i8*, %swift.refcounted* } { i8* bitcast (i64 (%swift.refcounted*)* @"$s4main15makeIncrementerSiycyF11incrementerL_SiyFTA" to i8*), %swift.refcounted* undef }, %swift.refcounted* %1, 1
  ret { i8*, %swift.refcounted* } %6
}
```

- 在`%1`行，调用`swift_allocObject`，创建一个实例，它返回的是一个`HeapObject *`的结构体指针。

- 在`%2`行，把实力对象强转成`{ %swift.refcounted, [8 x i8] }`，所以`%swift.refcounted*`指向实例对象

- 在`%3`行，取出`{ %swift.refcounted, [8 x i8] }`中第二个元素`[8 x i8]`，然后把外部捕获的局部变量存在着里面。
- 在`%6`行，通过`insertvalue`函数，先把`incrementer`函数地址赋值给第一个参数，然后将前面创建的堆空间地址赋值给第二个变量



### 闭包结构还愿

- 通过上面分析，闭包的本质就是 `{ i8*, %swift.refcounted* }` 这样的结构体，`i8*` 存储的是函数的地址，`%swift.refcounted*`存储的是一个 `{ %swift.refcounted, [8 x i8] }`结构体。
- `{ %swift.refcounted, [8 x i8] }`这个结构里，`%swift.refcounted`执行一个`HeapObject *` 对象，然后`[8 x i8]` 存储我们捕获的值

- 所以最终闭包结构如下

```swift
struct ClosureData<Box> {
    /// 函数地址
    var ptr: UnsafeRawPointer
    /// 存储捕获堆空间地址的值
    var object: UnsafePointer<Box>
}

struct Box<T> {
    var heapObject: HeapObject
    // 捕获变量/常量的值
    var value: T
}

struct HeapObject {
    var matedata: UnsafeRawPointer
    var refcount: Int
}
```



### 闭包捕获引用类型

- 把下面例子转换成`IR`代码

```swift
define hidden swiftcc { i8*, %swift.refcounted* } @"$s4main15makeIncrementerSiycyF"() #0 {
entry:
  %test.debug = alloca %T4main4TestC*, align 8
  %0 = bitcast %T4main4TestC** %test.debug to i8*
  call void @llvm.memset.p0i8.i64(i8* align 8 %0, i8 0, i64 8, i1 false)
  %1 = call swiftcc %swift.metadata_response @"$s4main4TestCMa"(i64 0) #7
  %2 = extractvalue %swift.metadata_response %1, 0
  %3 = call swiftcc %T4main4TestC* @"$s4main4TestCACycfC"(%swift.type* swiftself %2)
  store %T4main4TestC* %3, %T4main4TestC** %test.debug, align 8
  %4 = bitcast %T4main4TestC* %3 to %swift.refcounted*
  // 对实例对象引用计数+1
  %5 = call %swift.refcounted* @swift_retain(%swift.refcounted* returned %4) #3
  
  // 将实例对象转换成 %swift.refcounted*类型，并存储到%6中
  %6 = bitcast %T4main4TestC* %3 to %swift.refcounted*
  call void bitcast (void (%swift.refcounted*)* @swift_release to void (%T4main4TestC*)*)(%T4main4TestC* %3) #3
  %7 = insertvalue { i8*, %swift.refcounted* } { i8* bitcast (i64 (%swift.refcounted*)* @"$s4main15makeIncrementerSiycyF11incrementerL_SiyFTA" to i8*), %swift.refcounted* undef }, %swift.refcounted* %6, 1
  ret { i8*, %swift.refcounted* } %7
}
```

- 在捕获引用类型时候，其实也不需要捕获实例对象，因为它已经在堆区了，就不需要再去创建一个堆空间的实例包裹它了
- 只需要将它的地址存储到闭包的结构中，操作实例对象的引用计数+1



### 闭包捕获多个值

- 将下面例子转换成`IR`代码

```swift
func makeIncrementer() -> () -> Int {
    var runningTotal = 10
    var runningTotal1 = 11
    func incrementer() -> Int {
        runningTotal += 1
        runningTotal1 += runningTotal
        return runningTotal1
    }
    return incrementer
}

let fn = makeIncrementer()
print(fn())
print(fn())
print(fn())

// 打印结果
// 22
// 34
// 47
```

- `IR`中`makeIncrementer`代码如下

```c++
define hidden swiftcc { i8*, %swift.refcounted* } @"$s4main15makeIncrementerSiycyF"() #0 {
entry:
  %runningTotal.debug = alloca %TSi*, align 8
  %0 = bitcast %TSi** %runningTotal.debug to i8*
  call void @llvm.memset.p0i8.i64(i8* align 8 %0, i8 0, i64 8, i1 false)
  %runningTotal1.debug = alloca %TSi*, align 8
  %1 = bitcast %TSi** %runningTotal1.debug to i8*
  call void @llvm.memset.p0i8.i64(i8* align 8 %1, i8 0, i64 8, i1 false)

  // 第一次调用swift_allocObject
  %2 = call noalias %swift.refcounted* @swift_allocObject(%swift.type* getelementptr inbounds (%swift.full_boxmetadata, %swift.full_boxmetadata* @metadata, i32 0, i32 2), i64 24, i64 7) #2
  %3 = bitcast %swift.refcounted* %2 to <{ %swift.refcounted, [8 x i8] }>*
  %4 = getelementptr inbounds <{ %swift.refcounted, [8 x i8] }>, <{ %swift.refcounted, [8 x i8] }>* %3, i32 0, i32 1
  %5 = bitcast [8 x i8]* %4 to %TSi*
  store %TSi* %5, %TSi** %runningTotal.debug, align 8
  %._value = getelementptr inbounds %TSi, %TSi* %5, i32 0, i32 0
  store i64 10, i64* %._value, align 8
      
  // 第二次调用swift_allocObject
  %6 = call noalias %swift.refcounted* @swift_allocObject(%swift.type* getelementptr inbounds (%swift.full_boxmetadata, %swift.full_boxmetadata* @metadata, i32 0, i32 2), i64 24, i64 7) #2
  %7 = bitcast %swift.refcounted* %6 to <{ %swift.refcounted, [8 x i8] }>*
  %8 = getelementptr inbounds <{ %swift.refcounted, [8 x i8] }>, <{ %swift.refcounted, [8 x i8] }>* %7, i32 0, i32 1
  %9 = bitcast [8 x i8]* %8 to %TSi*
  store %TSi* %9, %TSi** %runningTotal1.debug, align 8
  %._value1 = getelementptr inbounds %TSi, %TSi* %9, i32 0, i32 0
  store i64 11, i64* %._value1, align 8
  %10 = call %swift.refcounted* @swift_retain(%swift.refcounted* returned %2) #2
  %11 = call %swift.refcounted* @swift_retain(%swift.refcounted* returned %6) #2
      
  // 第三次调用swift_allocObject
  %12 = call noalias %swift.refcounted* @swift_allocObject(%swift.type* getelementptr inbounds (%swift.full_boxmetadata, %swift.full_boxmetadata* @metadata.4, i32 0, i32 2), i64 32, i64 7) #2
  %13 = bitcast %swift.refcounted* %12 to <{ %swift.refcounted, %swift.refcounted*, %swift.refcounted* }>*
  // 将第一个变量堆空间，存储在%13中第二个元素位置
  %14 = getelementptr inbounds <{ %swift.refcounted, %swift.refcounted*, %swift.refcounted* }>, <{ %swift.refcounted, %swift.refcounted*, %swift.refcounted* }>* %13, i32 0, i32 1
  store %swift.refcounted* %2, %swift.refcounted** %14, align 8
  // 将第二个变量堆空间，存储在%13中第三个元素位置
  %15 = getelementptr inbounds <{ %swift.refcounted, %swift.refcounted*, %swift.refcounted* }>, <{ %swift.refcounted, %swift.refcounted*, %swift.refcounted* }>* %13, i32 0, i32 2
  store %swift.refcounted* %6, %swift.refcounted** %15, align 8
  call void @swift_release(%swift.refcounted* %6) #2
  call void @swift_release(%swift.refcounted* %2) #2
  %16 = insertvalue { i8*, %swift.refcounted* } { i8* bitcast (i64 (%swift.refcounted*)* @"$s4main15makeIncrementerSiycyF11incrementerL_SiyFTA" to i8*), %swift.refcounted* undef }, %swift.refcounted* %12, 1
  ret { i8*, %swift.refcounted* } %16
}
```

- 可以看到，调用了多次`swift_allocObject`，第一次和第二次调用为了分别存储`runningTotal`和`runningTotal1`
- 第三次`swift_allocObject`返回的实例对象，被强转至`{ %swift.refcounted, %swift.refcounted*, %swift.refcounted* }`类型
- 然后在此之后分别调用了两次`getelementptr`方法，把前两次创建的实例对象的地址，存在该结构中的第二个元素、第三个元素位置
- 然后在返回时，把函数地址，和第三次分配的实例对象一起返回出去



- 根据上面分析，最终闭包结果如下：

```swift
struct ClosureData<MutiValue> {
    /// 函数地址
    var ptr: UnsafeRawPointer
    /// 存储捕获堆空间地址的值
    var object: UnsafePointer<MutiValue>
}

struct MutiValue<T1,T2> {
    var object: HeapObject
    var value: UnsafePointer<Box<T1>>
    var value1: UnsafePointer<Box<T2>>
}

struct Box<T> {
    var object: HeapObject
    var value: T
}

struct HeapObject {
    var matedata: UnsafeRawPointer
    var refcount: Int
}
```

- 根据以上的分析，捕获单个值和多个值的区别就在于：
  - 单个值中，`ClosureData`内存储的堆空间地址直接就是这个值所在的堆空间。
  - 而对于捕获多个值，`ClosureData`内存储的堆空间地址会变成一个可以存储很多个捕获值的结构。

- 简单来说，从原来直接指向单个实例对象，变成指向一片连续内存空间，内存空间中存储着指向变量的地址



## 多种不同类型闭包

### 尾随闭包

- 如果你需要将一个很长的闭包表达式作为最后一个参数传递给函数，可以使用尾随闭包来增强函数的可读性。尾随闭包是一个书写在函数括号之后的闭包表达式，函数支持将其作为最后一个参数调用。在使用尾随闭包时，你不用写出它的参数标签：

```swift
func test(closure: () -> Void) {

}

// 以下是使用尾随闭包进行函数调用
test {
    
}

// 以下是不使用尾随闭包进行函数调用
test(closure: {
    
})
```



### 逃逸闭包

- 当一个闭包作为参数传到一个函数中，但是这个闭包在函数返回之后才被执行，我们称该闭包从函数中逃逸。当你定义接受闭包作为参数的函数时，你可以在参数名之前标注`@escaping`，用来指明这个闭包是允许“逃逸”出这个函数的。

- 逃逸闭包存在的可能情况：

  - 当闭包被当作属性存储，导致函数完成时闭包生命周期被延长。

  - 当闭包异步执行，导致函数完成时闭包生命周期被延长。

  - 可选类型的闭包默认是逃逸闭包。

- 逃逸闭包所需的条件：

  - 作为函数的参数传递。

  - 当前闭包在函数内部异步执行或者被存储。

  - 函数结束，闭包被调用，闭包的生命周期未结束。



- 逃逸闭包 vs 非逃逸闭包 区别

- 非逃逸闭包：一个接受闭包作为参数的函数，闭包是在这个函数结束前内被调用，即可以理解为`闭包是在函数作用域结束前被调用`
  - 1、`不会产生循环引用`，因为闭包的作用域在函数作用域内，在函数执行完成后，就会释放闭包捕获的所有对象
  - 2、针对非逃逸闭包，`编译器会做优化`：省略内存管理调用
  - 3、非逃逸闭包捕获的上下文`保存在栈上`，而不是堆上
- 逃逸闭包：一个接受闭包作为参数的函数，逃逸闭包可能会在函数返回之后才被调用，即`闭包逃离了函数的作用域`
  - 1、`可能会产生循环引用`，因为逃逸闭包中需要`显式的引用self`（猜测其原因是为了`提醒`开发者，这里可能会出现循环引用了），而`self`可能是持有闭包变量的（与`OC`中`block`的的循环引用类似）
  - 2、一般用于异步函数的返回，例如网络请求
- 使用建议：如果没有特别需要，开发中使用`非逃逸闭包是有利于内存优化`的，所以苹果把闭包区分为两种，`特殊情况时再使用逃逸闭包`



### 自动闭包

- 自动闭包是一种自动创建的闭包，用于包装传递给函数作为参数的表达式。这种闭包不接受任何参数，当它被调用的时候，会返回被包装在其中的表达式的值。这种便利语法让你能够省略闭包的花括号，用一个普通的表达式来代替显式的闭包。



## 总结

- 一个闭包能够`从上下文中捕获已经定义的常量/变量`，即使其作用域不存在了，闭包仍然`能够在其函数体内引用、修改`
  - 1、每次`修改捕获值`：本质修改的是`堆区中的value值`
  - 2、每次`重新执行当前函数`，会重新`创建新的内存空间`
- 捕获值原理：本质是在堆区开辟内存空间，并将捕获值存储到这个存空间
- 闭包是一个引用类型（本质是`函数地址传递`），底层结构为：`闭包 = 函数地址 + 捕获变量的地址`
- 函数也是引用类型（本质是`结构体`，其中保存了函数的地址）