- [Swift底层原理-协议](#swift底层原理-协议)
  - [协议的基本用法](#协议的基本用法)
    - [协议的定义](#协议的定义)
    - [协议中的属性](#协议中的属性)
    - [协议的方法](#协议的方法)
      - [类型方法](#类型方法)
      - [异变方法](#异变方法)
      - [初始化方法](#初始化方法)
    - [可选协议](#可选协议)
    - [协议的继承和组合](#协议的继承和组合)
  - [协议的底层原理](#协议的底层原理)
    - [协议的方法调度](#协议的方法调度)
      - [类实现协议](#类实现协议)
        - [静态类型为类类型](#静态类型为类类型)
        - [静态类型为协议类型](#静态类型为协议类型)
      - [结构体实现协议](#结构体实现协议)
        - [静态类型为结构体类型](#静态类型为结构体类型)
        - [静态类型为协议类型](#静态类型为协议类型-1)
    - [extention中提供方法的默认实现](#extention中提供方法的默认实现)
      - [协议中未声明方法，分类中声明并实现](#协议中未声明方法分类中声明并实现)
      - [协议中声明方法，分类中实现](#协议中声明方法分类中实现)
    - [协议的结构](#协议的结构)
      - [witness_table的结构](#witness_table的结构)
      - [Existential Container-存在容器](#existential-container-存在容器)


# Swift底层原理-协议

## 协议的基本用法

### 协议的定义

- 如若想使用协议，那么我们需要使用`protocol`关键字来申明协议。
- 协议可以用来定义方法、属性、下标的声明，协议可以被枚举、结构体、类遵守（多个协议之间用逗号隔开）。

```swift
protocol BaseProtocol {
    var x: Int {get set}
    var y: Double {get}
}

class TestClass: BaseProtocol {
    var x: Int = 0
    
    var y: Double = 0.0
}
```

### 协议中的属性

- 协议中定义属性时必须用`var`关键字。
- 在定义属性时，我们必须指定属性至少是**可读的**，即我们需要给属性添加 `{ get }` 属性，也可以是`{get set}`； 同时我们要注意 这个 `get` 并不一定指定属性就是计算属性。

```swift
protocol BaseProtocol {
    var x: Int {get set}
    var y: Double {get}
}

class TestClass: BaseProtocol {
    // 可读写计算属性
    var x: Int {
        get {
            return 10
        }
        set {
            self.x = newValue
        }
    }
    
    // 可读计算属性
    var y: Double {
        get {
            return 20
        }
    }
}

class TestClass: BaseProtocol {
    // 变量存储属性，可读写
    var x: Int = 0
    
    // 变量存储属性，可读写
    var y: Double = 0.0
}
```

- 若协议要求一个属性为**可读和可写**的，那么该属性要求不能用常量存储属性`(let)`或只读计算属性来满足。
- 若协议只要求属性为**可读的**，那么任何种类的属性都能满足这个要求，而且如果你的代码需要的话，该属性也可以是可写的。

### 协议的方法

- 写方式与正常实例和类方法的方式完全相同，但是不需要大括号和方法的主体。但在协议的定义中，方法参数不能定义默认值

```swift
protocol BaseProtocol {
    func test()
}
```

#### 类型方法

- 当协议中定义类型方法时，你总要在其之前添加`static`关键字。即使在类实现时，类型方法要求使用`class`或`static`作为关键字前缀

```swift
protocol BaseProtocol {
    static func test()
}

class TestClass: BaseProtocol {
    static func test() {
        print("test")
    }
}
```

#### 异变方法

- `mutating`只有将协议中的实例方法标记为`mutating`，才允许结构体、枚举的具体实现修改自身内存。
- 如果你在协议中标记实例方法需求为`mutating`，在为类实现该方法的时候不需要写`mutating`关键字。 `mutating`关键字只在结构体和枚举类型中需要书写。

```swift
protocol BaseProtocol {
    mutating func test()
}

class TestClass: BaseProtocol {
    func test() {
        print("test")
    }
}

struct TestStruct: BaseProtocol {
    var x = 10
    mutating func test() {
        x = 20
    }
}
```

#### 初始化方法

- 协议中定义的初始化方法，在遵循这个协议时，我们需要在实现这个初始化方法时 在`init`前加上`required`关键字，否则编译器会报错的(类的初始化 器前添加 `required` 修饰符来表明所有该类的子类都必须实现该初始化器)。

```swift
protocol BaseProtocol {
    init()
}

class TestClass: BaseProtocol {
    required init() {
        
    }
}
```

- 由于`final`的类不会有子类，如果协议初始化器实现的类使用了`final`标记，你就不需要使用`required`来修饰了。

```swift
protocol BaseProtocol {
    init()
}

final class TestClass: BaseProtocol {
    init() {
        
    }
}
```

### 可选协议

- 你可以给协议定义*可选要求*，这些要求不需要强制遵循协议的类型实现
- 可以用 `optional` 作为前缀放在协议的定义，但需要注意的是我们还需要增加 `@objc` 关键字

```swift
@objc protocol BaseProtocol {
    @objc optional func test()
}
```

- 也可用`extension`实现

```swift
protocol BaseProtocol {
    func test()
}

extension BaseProtocol {
    func test() {
        
    }
}
```

### 协议的继承和组合

- 协议可以继承一个或者多个其他协议并且可以在它继承的基础之上添加更多要求

```swift
protocol BaseProtocol {
    func test()
}

protocol BaseProtocol1 {
    
}

class TestClass: BaseProtocol, BaseProtocol1 {
}
```

- 在协议后面写上`:AnyObject`代表只有类能遵守这个协议，在协议后面写上`:class`也代表只有类能遵守这个协议。

```swift
protocol BaseProtocol: AnyObject {}
protocol BaseProtocol: class {}
```

## 协议的底层原理

### 协议的方法调度

- 在方法这篇文章中，我们知道类的方法的调度是通过虚函数表（`VTable`）查找到对应的函数进行调用的，而结构体的方法直接就是拿到函数的地址进行调用。
- 那么协议中声明的方法呢，如果类或者结构体遵守这个协议，然后实现协议方法，它是如何去查找函数的地址进行调用的呢。

#### 类实现协议

##### 静态类型为类类型

```swift
protocol BaseProtocol {
    func test(_ number: Int)
}

class TestClass: BaseProtocol {
    var x: Int?
    func test(_ number: Int) {
        x = number
    }
}

var test: TestClass = TestClass()
test.test(10)

```

- 然后把当前的`main.swift`文件编译成`main.sil`文件。编译完成后找到`main`函数，查看`test(:)`方法的调用

```c++
// main
sil [ossa] @main : $@convention(c) (Int32, UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>) -> Int32 {
bb0(%0 : $Int32, %1 : $UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>):
  alloc_global @$s4main4testAA9TestClassCvp       // id: %2
  %3 = global_addr @$s4main4testAA9TestClassCvp : $*TestClass // users: %8, %7
  %4 = metatype $@thick TestClass.Type            // user: %6
  // function_ref TestClass.__allocating_init()
  %5 = function_ref @$s4main9TestClassCACycfC : $@convention(method) (@thick TestClass.Type) -> @owned TestClass // user: %6
  %6 = apply %5(%4) : $@convention(method) (@thick TestClass.Type) -> @owned TestClass // user: %7
  store %6 to [init] %3 : $*TestClass             // id: %7
  %8 = begin_access [read] [dynamic] %3 : $*TestClass // users: %10, %9
  %9 = load [copy] %8 : $*TestClass               // users: %17, %16, %15
  end_access %8 : $*TestClass                     // id: %10
  %11 = integer_literal $Builtin.IntLiteral, 10   // user: %14
  %12 = metatype $@thin Int.Type                  // user: %14
  // function_ref Int.init(_builtinIntegerLiteral:)
  %13 = function_ref @$sSi22_builtinIntegerLiteralSiBI_tcfC : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %14
  %14 = apply %13(%11, %12) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %16
  %15 = class_method %9 : $TestClass, #TestClass.test : (TestClass) -> (Int) -> (), $@convention(method) (Int, @guaranteed TestClass) -> () // user: %16
  %16 = apply %15(%14, %9) : $@convention(method) (Int, @guaranteed TestClass) -> ()
  destroy_value %9 : $TestClass                   // id: %17
  %18 = integer_literal $Builtin.Int32, 0         // user: %19
  %19 = struct $Int32 (%18 : $Builtin.Int32)      // user: %20
  return %19 : $Int32                             // id: %20
} // end sil function 'main'
```

- 可以看到在`%15`这一行，是`class_method`类型，`class_method`类型的方法是通过`VTable`查找.
- 我们移动到该文件底部

```c++
sil_vtable TestClass {
  #TestClass.x!getter: (TestClass) -> () -> Int? : @$s4main9TestClassC1xSiSgvg	// TestClass.x.getter
  #TestClass.x!setter: (TestClass) -> (Int?) -> () : @$s4main9TestClassC1xSiSgvs	// TestClass.x.setter
  #TestClass.x!modify: (TestClass) -> () -> () : @$s4main9TestClassC1xSiSgvM	// TestClass.x.modify
  #TestClass.test: (TestClass) -> (Int) -> () : @$s4main9TestClassC4testyySiF	// TestClass.test(_:)
  #TestClass.init!allocator: (TestClass.Type) -> () -> TestClass : @$s4main9TestClassCACycfC	// TestClass.__allocating_init()
  #TestClass.deinit!deallocator: @$s4main9TestClassCfD	// TestClass.__deallocating_deinit
}
```

- 可以发现`test`方法确实存在`VTable`中。所以当静态类型是`TestClass`，通过`VTable`来调用。

##### 静态类型为协议类型

- 我们把`test`修改成协议类型

```swift
var test: BaseProtocol = TestClass()
```

- 我们查看编译后`main.sil`文件，找到`main`函数

```c++
// main
sil [ossa] @main : $@convention(c) (Int32, UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>) -> Int32 {
bb0(%0 : $Int32, %1 : $UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>):
  alloc_global @$s4main4testAA12BaseProtocol_pvp  // id: %2
  %3 = global_addr @$s4main4testAA12BaseProtocol_pvp : $*BaseProtocol // users: %9, %7
  %4 = metatype $@thick TestClass.Type            // user: %6
  // function_ref TestClass.__allocating_init()
  %5 = function_ref @$s4main9TestClassCACycfC : $@convention(method) (@thick TestClass.Type) -> @owned TestClass // user: %6
  %6 = apply %5(%4) : $@convention(method) (@thick TestClass.Type) -> @owned TestClass // user: %8
  %7 = init_existential_addr %3 : $*BaseProtocol, $TestClass // user: %8
  store %6 to [init] %7 : $*TestClass             // id: %8
  %9 = begin_access [read] [dynamic] %3 : $*BaseProtocol // users: %12, %11
  %10 = alloc_stack $BaseProtocol                 // users: %21, %20, %13, %11
  copy_addr %9 to [initialization] %10 : $*BaseProtocol // id: %11
  end_access %9 : $*BaseProtocol                  // id: %12
  %13 = open_existential_addr immutable_access %10 : $*BaseProtocol to $*@opened("39CCE43C-59EA-11ED-A979-86E79974171B") BaseProtocol // users: %19, %19, %18
  %14 = integer_literal $Builtin.IntLiteral, 10   // user: %17
  %15 = metatype $@thin Int.Type                  // user: %17
  // function_ref Int.init(_builtinIntegerLiteral:)
  %16 = function_ref @$sSi22_builtinIntegerLiteralSiBI_tcfC : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %17
  %17 = apply %16(%14, %15) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %19
  %18 = witness_method $@opened("39CCE43C-59EA-11ED-A979-86E79974171B") BaseProtocol, #BaseProtocol.test : <Self where Self : BaseProtocol> (Self) -> (Int) -> (), %13 : $*@opened("39CCE43C-59EA-11ED-A979-86E79974171B") BaseProtocol : $@convention(witness_method: BaseProtocol) <τ_0_0 where τ_0_0 : BaseProtocol> (Int, @in_guaranteed τ_0_0) -> () // type-defs: %13; user: %19
  %19 = apply %18<@opened("39CCE43C-59EA-11ED-A979-86E79974171B") BaseProtocol>(%17, %13) : $@convention(witness_method: BaseProtocol) <τ_0_0 where τ_0_0 : BaseProtocol> (Int, @in_guaranteed τ_0_0) -> () // type-defs: %13
  destroy_addr %10 : $*BaseProtocol               // id: %20
  dealloc_stack %10 : $*BaseProtocol              // id: %21
  %22 = integer_literal $Builtin.Int32, 0         // user: %23
  %23 = struct $Int32 (%22 : $Builtin.Int32)      // user: %24
  return %23 : $Int32                             // id: %24
} // end sil function 'main'
```

- 我们发现`%18`，类型编程`witness_method`类型，我们移动到该文件最后，发现了`sil_witness_table`表

```c++
sil_witness_table hidden TestClass: BaseProtocol module main {
  method #BaseProtocol.test: <Self where Self : BaseProtocol> (Self) -> (Int) -> () : @$s4main9TestClassCAA12BaseProtocolA2aDP4testyySiFTW	// protocol witness for BaseProtocol.test(_:) in conformance TestClass
}
```

- 在该表中，也定一个`test`方法，我们去查找该方法的定义

```c++
// protocol witness for BaseProtocol.test(_:) in conformance TestClass
sil private [transparent] [thunk] [ossa] @$s4main9TestClassCAA12BaseProtocolA2aDP4testyySiFTW : $@convention(witness_method: BaseProtocol) (Int, @in_guaranteed TestClass) -> () {
// %0                                             // user: %4
// %1                                             // user: %2
bb0(%0 : $Int, %1 : $*TestClass):
  %2 = load_borrow %1 : $*TestClass               // users: %6, %4, %3
  %3 = class_method %2 : $TestClass, #TestClass.test : (TestClass) -> (Int) -> (), $@convention(method) (Int, @guaranteed TestClass) -> () // user: %4
  %4 = apply %3(%0, %2) : $@convention(method) (Int, @guaranteed TestClass) -> ()
  %5 = tuple ()                                   // user: %7
  end_borrow %2 : $TestClass                      // id: %6
  return %5 : $()                                 // id: %7
} // end sil function '$s4main9TestClassCAA12BaseProtocolA2aDP4testyySiFTW'
```

- 在定义中，最终还是会去查找遵守它的类中的`VTable`进行方法的调度。



- 总结
  - 如果实例对象的静态类型就是确定的类型，那么这个协议方法通过`VTalbel`进行调度。
  - 如果实例对象的静态类型是协议类型，那么这个协议方法通过`witness_table`中对应的协议方法，然后通过协议方法去查找遵守协议的类的`VTable`进行调度。

#### 结构体实现协议

- 在上面，我们研究了遵循协议类的方法调用，下面我们研究一下结构体遵循协议后是如何调用

##### 静态类型为结构体类型

```swift
protocol BaseProtocol {
    func test()
}

struct TestStruct: BaseProtocol {
    func test() {
    }
}

var test: TestStruct = TestStruct()
test.test()
```

- 把当前的`main.swift`文件编译成`main.sil`文件。编译完成后找到`main`函数，查看`test()`方法的调用

```c++
// main
sil [ossa] @main : $@convention(c) (Int32, UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>) -> Int32 {
bb0(%0 : $Int32, %1 : $UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>):
  alloc_global @$s4main4testAA10TestStructVvp     // id: %2
  %3 = global_addr @$s4main4testAA10TestStructVvp : $*TestStruct // users: %8, %7
  %4 = metatype $@thin TestStruct.Type            // user: %6
  // function_ref TestStruct.init()
  %5 = function_ref @$s4main10TestStructVACycfC : $@convention(method) (@thin TestStruct.Type) -> TestStruct // user: %6
  %6 = apply %5(%4) : $@convention(method) (@thin TestStruct.Type) -> TestStruct // user: %7
  store %6 to [trivial] %3 : $*TestStruct         // id: %7
  %8 = begin_access [read] [dynamic] %3 : $*TestStruct // users: %10, %9
  %9 = load [trivial] %8 : $*TestStruct           // user: %12
  end_access %8 : $*TestStruct                    // id: %10
  // function_ref TestStruct.test()
  %11 = function_ref @$s4main10TestStructV4testyyF : $@convention(method) (TestStruct) -> () // user: %12
  %12 = apply %11(%9) : $@convention(method) (TestStruct) -> ()
  %13 = integer_literal $Builtin.Int32, 0         // user: %14
  %14 = struct $Int32 (%13 : $Builtin.Int32)      // user: %15
  return %14 : $Int32                             // id: %15
} // end sil function 'main'
```

- 通过`%11`可以看到，结构体调用协议方法的方式直接就是函数地址调用。

##### 静态类型为协议类型

- 我们把`test`修改成协议类型

```swift
var test: BaseProtocol = TestStruct()
```

- 查看编译后文件的`main`函数

```c++
// main
sil [ossa] @main : $@convention(c) (Int32, UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>) -> Int32 {
bb0(%0 : $Int32, %1 : $UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>):
  alloc_global @$s4main4testAA12BaseProtocol_pvp  // id: %2
  %3 = global_addr @$s4main4testAA12BaseProtocol_pvp : $*BaseProtocol // users: %9, %7
  %4 = metatype $@thin TestStruct.Type            // user: %6
  // function_ref TestStruct.init()
  %5 = function_ref @$s4main10TestStructVACycfC : $@convention(method) (@thin TestStruct.Type) -> TestStruct // user: %6
  %6 = apply %5(%4) : $@convention(method) (@thin TestStruct.Type) -> TestStruct // user: %8
  %7 = init_existential_addr %3 : $*BaseProtocol, $TestStruct // user: %8
  store %6 to [trivial] %7 : $*TestStruct         // id: %8
  %9 = begin_access [read] [dynamic] %3 : $*BaseProtocol // users: %12, %11
  %10 = alloc_stack $BaseProtocol                 // users: %17, %16, %13, %11
  copy_addr %9 to [initialization] %10 : $*BaseProtocol // id: %11
  end_access %9 : $*BaseProtocol                  // id: %12
  %13 = open_existential_addr immutable_access %10 : $*BaseProtocol to $*@opened("7CCB7D78-59EC-11ED-B59A-86E79974171B") BaseProtocol // users: %15, %15, %14
  %14 = witness_method $@opened("7CCB7D78-59EC-11ED-B59A-86E79974171B") BaseProtocol, #BaseProtocol.test : <Self where Self : BaseProtocol> (Self) -> () -> (), %13 : $*@opened("7CCB7D78-59EC-11ED-B59A-86E79974171B") BaseProtocol : $@convention(witness_method: BaseProtocol) <τ_0_0 where τ_0_0 : BaseProtocol> (@in_guaranteed τ_0_0) -> () // type-defs: %13; user: %15
  %15 = apply %14<@opened("7CCB7D78-59EC-11ED-B59A-86E79974171B") BaseProtocol>(%13) : $@convention(witness_method: BaseProtocol) <τ_0_0 where τ_0_0 : BaseProtocol> (@in_guaranteed τ_0_0) -> () // type-defs: %13
  destroy_addr %10 : $*BaseProtocol               // id: %16
  dealloc_stack %10 : $*BaseProtocol              // id: %17
  %18 = integer_literal $Builtin.Int32, 0         // user: %19
  %19 = struct $Int32 (%18 : $Builtin.Int32)      // user: %20
  return %19 : $Int32                             // id: %20
} // end sil function 'main'
```

- 通过`%14`这一行，发现它的类型变成了`witness_method`。我们查看该方法的实现

```c++
// protocol witness for BaseProtocol.test() in conformance TestStruct
sil private [transparent] [thunk] [ossa] @$s4main10TestStructVAA12BaseProtocolA2aDP4testyyFTW : $@convention(witness_method: BaseProtocol) (@in_guaranteed TestStruct) -> () {
// %0                                             // user: %1
bb0(%0 : $*TestStruct):
  %1 = load [trivial] %0 : $*TestStruct           // user: %3
  // function_ref TestStruct.test()
  %2 = function_ref @$s4main10TestStructV4testyyF : $@convention(method) (TestStruct) -> () // user: %3
  %3 = apply %2(%1) : $@convention(method) (TestStruct) -> ()
  %4 = tuple ()                                   // user: %5
  return %4 : $()                                 // id: %5
} // end sil function '$s4main10TestStructVAA12BaseProtocolA2aDP4testyyFTW'
```

- 通过`%2`可以看到，它最终还是找到了结构体中`test`方法地址直接调用

### extention中提供方法的默认实现

- 协议可以通过`extention`的方式去实现定义的方法，实现之后，遵循协议的类可以不再实现该方法。

#### 协议中未声明方法，分类中声明并实现

```swift
protocol BaseProtocol {
    
}

extension BaseProtocol {
    func test() {
        print("BaseProtocol")
    }
}

class TestClass: BaseProtocol {
    func test() {
        print("TestClass")
    }
}

var test: BaseProtocol = TestClass()
test.test()

var test1: TestClass = TestClass()
test1.test()
```

> 打印结果：
>
> **BaseProtocol**
>
> **TestClass**

- 把当前的`main.swift`文件编译成`main.sil`文件。编译完成后找到`main`函数

```c++
// main
sil [ossa] @main : $@convention(c) (Int32, UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>) -> Int32 {
bb0(%0 : $Int32, %1 : $UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>):
  alloc_global @$s4main4testAA12BaseProtocol_pvp  // id: %2
  %3 = global_addr @$s4main4testAA12BaseProtocol_pvp : $*BaseProtocol // users: %9, %7
  %4 = metatype $@thick TestClass.Type            // user: %6
  // function_ref TestClass.__allocating_init()
  %5 = function_ref @$s4main9TestClassCACycfC : $@convention(method) (@thick TestClass.Type) -> @owned TestClass // user: %6
  %6 = apply %5(%4) : $@convention(method) (@thick TestClass.Type) -> @owned TestClass // user: %8
  %7 = init_existential_addr %3 : $*BaseProtocol, $TestClass // user: %8
  store %6 to [init] %7 : $*TestClass             // id: %8
  %9 = begin_access [read] [dynamic] %3 : $*BaseProtocol // users: %12, %11
  %10 = alloc_stack $BaseProtocol                 // users: %17, %16, %13, %11
  copy_addr %9 to [initialization] %10 : $*BaseProtocol // id: %11
  end_access %9 : $*BaseProtocol                  // id: %12
  %13 = open_existential_addr immutable_access %10 : $*BaseProtocol to $*@opened("A1E0E9E8-59EE-11ED-8487-86E79974171B") BaseProtocol // users: %15, %15
  // function_ref BaseProtocol.test()
  %14 = function_ref @$s4main12BaseProtocolPAAE4testyyF : $@convention(method) <τ_0_0 where τ_0_0 : BaseProtocol> (@in_guaranteed τ_0_0) -> () // user: %15
  %15 = apply %14<@opened("A1E0E9E8-59EE-11ED-8487-86E79974171B") BaseProtocol>(%13) : $@convention(method) <τ_0_0 where τ_0_0 : BaseProtocol> (@in_guaranteed τ_0_0) -> () // type-defs: %13
  destroy_addr %10 : $*BaseProtocol               // id: %16
  dealloc_stack %10 : $*BaseProtocol              // id: %17
  alloc_global @$s4main5test1AA9TestClassCvp      // id: %18
  %19 = global_addr @$s4main5test1AA9TestClassCvp : $*TestClass // users: %24, %23
  %20 = metatype $@thick TestClass.Type           // user: %22
  // function_ref TestClass.__allocating_init()
  %21 = function_ref @$s4main9TestClassCACycfC : $@convention(method) (@thick TestClass.Type) -> @owned TestClass // user: %22
  %22 = apply %21(%20) : $@convention(method) (@thick TestClass.Type) -> @owned TestClass // user: %23
  store %22 to [init] %19 : $*TestClass           // id: %23
  %24 = begin_access [read] [dynamic] %19 : $*TestClass // users: %26, %25
  %25 = load [copy] %24 : $*TestClass             // users: %29, %28, %27
  end_access %24 : $*TestClass                    // id: %26
  %27 = class_method %25 : $TestClass, #TestClass.test : (TestClass) -> () -> (), $@convention(method) (@guaranteed TestClass) -> () // user: %28
  %28 = apply %27(%25) : $@convention(method) (@guaranteed TestClass) -> ()
  destroy_value %25 : $TestClass                  // id: %29
  %30 = integer_literal $Builtin.Int32, 0         // user: %31
  %31 = struct $Int32 (%30 : $Builtin.Int32)      // user: %32
  return %31 : $Int32                             // id: %32
} // end sil function 'main'
```

- 我们可以看到在`%14`，静态类型为协议类型，通过函数地址直接调用。
- 我们可以看到在`%21`，静态类型为类类型，则是通过`VTable`调用。

#### 协议中声明方法，分类中实现

```swift
protocol BaseProtocol {
    func test()
}

extension BaseProtocol {
    func test() {
        print("BaseProtocol")
    }
}

class TestClass: BaseProtocol {
    func test() {
        print("TestClass")
    }
}

var test: BaseProtocol = TestClass()
test.test()

var test1: TestClass = TestClass()
test1.test()
```

> 打印结果：
>
> **TestClass**
>
> **TestClass**

- 在协议中声明了函数，并且在分类中实现了该函数，会优先调用类中的方法。

### 协议的结构

- 通过上面的例子，我们发现静态类型不同，会影响函数调用，是不是会影响实例对象的结构呢？

```swift
protocol BaseProtocol {
    func test()
}

extension BaseProtocol {
    func test() {
    }
}

class TestClass: BaseProtocol {
    var x: Int = 10
    func test() {
        
    }
}


var test: BaseProtocol = TestClass()

var test1: TestClass = TestClass()

print("test size: \(MemoryLayout.size(ofValue: test))")
print("test1 size: \(MemoryLayout.size(ofValue: test1))")
```

> 打印结果：
>
> **test size: 40**
>
> **test1 size: 8**

- 我们发现静态类型不同，居然会影响内存中的大小。`test1`的8字节很好理解，是实例对象的地址。 那我们就再分析下这个40字节的内容了。

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h7q0azkas6j324i0rejxx.jpg)

- 通过内存分析我们可以看到：
  - 第一个8字节存储着实例对象的地址
  - 第二个和第三个8字节存储的是啥目前为止。
  - 第四个8字节存储的是实例对象的`metadate`
  - 最后的8字节存储的其实是`witness_table`的地址。

- 为什么说最后8字节就是`witness_table`的地址呢？打开汇编调试，找到`test`创建后`witness_table`相关的代码

![](https://tva1.sinaimg.cn/large/008vxvgGgy1h7q0vcni60j32ar0u0dlq.jpg)

- 如图所有最后8字节是`witness_table`地址。

#### witness_table的结构

- 在上面我们知道了`witness_table`在内存中存储的位置，那么这个结构是这么样的呢？

- 接下来我们就直接将当前的`main.swift`文件编译成`main.ll`文件。避免干扰，把`test1`变量和打印注释了

```c++
define i32 @main(i32 %0, i8** %1) #0 {
entry:
  %2 = bitcast i8** %1 to i8*
  // 获取TestClass的metadata
  %3 = call swiftcc %swift.metadata_response @"type metadata accessor for main.TestClass"(i64 0) #7
  %4 = extractvalue %swift.metadata_response %3, 0
  // %swift.type = type { i64 }
  // %swift.refcounted = type { %swift.type*, i64 }
  // %T4main9TestClassC = type <{ %swift.refcounted, %TSd }>
  // 创建Test实例
  %5 = call swiftcc %T4main9TestClassC* @"main.TestClass.__allocating_init() -> main.TestClass"(%swift.type* swiftself %4)
  
  // %T4main12BaseProtocolP = type { [24 x i8], %swift.type*, i8** }，%T4main12BaseProtocolP 本质上是一个结构体
  // 注意看，getelementptr为获取结构体成员，i32 0 结构体的内存地址，拿到这个结构体后将 %4 存储到这个结构体的第二个成员变量上
  // 也就是将 metadata 存储到这个结构体的第二个成员变量上，此时这个结构体的结构为：{ [24 x i8], metadata, i8** }
  store %swift.type* %4, %swift.type** getelementptr inbounds (%T4main12BaseProtocolP, %T4main12BaseProtocolP* @"main.test : main.BaseProtocol", i32 0, i32 1), align 8

  // 这一行在获取 witness table，然后将 witness table 存储到 %T4main12BaseProtocolP 这个结构体的第三个成员变量上（因为取的是 i32 2）
  // 此时 %T4main5ShapeP 的结构为：{ [24 x i8], metadata, witness_table }
  store i8** getelementptr inbounds ([2 x i8*], [2 x i8*]* @"protocol witness table for main.TestClass : main.BaseProtocol in main", i32 0, i32 0), i8*** getelementptr inbounds (%T4main12BaseProtocolP, %T4main12BaseProtocolP* @"main.test : main.BaseProtocol", i32 0, i32 2), align 8
  
  // [24 x i8] 是 24 个 Int8 数组,内存中等价 [3 x i64] 数组,等价于 %T4main5ShapeP = type { [3 x i64], %swift.type*, i8** }
  // 这里是将 %T4main5ShapeP 这个结构体强制转换成 %T4main9TestClassC，此时的结构为：{ [3 x i64], metadata, witness_table }
  // 然后把 %5 存放到 %T4main12BaseProtocolP 的第一个元素。所以最后的结构为：{ [%T4main9TestClassC*, i64, i64], metadata, witness_table },    
  store %T4main9TestClassC* %5, %T4main9TestClassC** bitcast (%T4main12BaseProtocolP* @"main.test : main.BaseProtocol" to %T4main9TestClassC**), align 8
  ret i32 0
}
```

- 接下来我们查看一下`witness_table`的内存结构

```c++
@"protocol witness table for main.TestClass : main.BaseProtocol in main" = hidden constant [2 x i8*] 
	[i8* bitcast (%swift.protocol_conformance_descriptor* @"protocol conformance descriptor for main.TestClass : main.BaseProtocol in main" to i8*), 
    i8* bitcast (void (%T4main9TestClassC**, %swift.type*, i8**)* @"protocol witness for main.BaseProtocol.test() -> () in conformance main.TestClass : main.BaseProtocol in main" to i8*)], 
	align 8
```

- 可以看到这个结构中有两个成员，第一个成员是描述信息，第二个成员是`test`协议方法地址。
- 下面我们通过源码来分析`witness_table`

```c++
template <typename Runtime>
class TargetWitnessTable {
  /// The protocol conformance descriptor from which this witness table
  /// was generated.
  ConstTargetMetadataPointer<Runtime, TargetProtocolConformanceDescriptor>
    Description;

public:
  const TargetProtocolConformanceDescriptor<Runtime> *getDescription() const {
    return Description;
  }
};
```

- 发现它内部有一个`Description`成员变量，我们查看一下它的类型

```c++
template <typename Runtime>
struct TargetProtocolConformanceDescriptor final
  : public swift::ABI::TrailingObjects<
             TargetProtocolConformanceDescriptor<Runtime>,
             TargetRelativeContextPointer<Runtime>,
             TargetGenericRequirementDescriptor<Runtime>,
             TargetResilientWitnessesHeader<Runtime>,
             TargetResilientWitness<Runtime>,
             TargetGenericWitnessTable<Runtime>> {
	// 省略部分方法

private:
  /// The protocol being conformed to.
  TargetRelativeContextPointer<Runtime, TargetProtocolDescriptor> Protocol;
  
  // Some description of the type that conforms to the protocol.
  TargetTypeReference<Runtime> TypeRef;

  /// The witness table pattern, which may also serve as the witness table.
  RelativeDirectPointer<const TargetWitnessTable<Runtime>> WitnessTablePattern;

  /// Various flags, including the kind of conformance.
  ConformanceFlags Flags;
}
```

- 它有四个成员变量，描述了`witness_table`的一些基本信息。
- 我们看`Protocol`这个成员变量，它是一个**相对类型指针**，其类型的结构为 `TargetProtocolDescriptor`

```c++
template<typename Runtime>
struct TargetProtocolDescriptor final
    : TargetContextDescriptor<Runtime>,
      swift::ABI::TrailingObjects<
        TargetProtocolDescriptor<Runtime>,
        TargetGenericRequirementDescriptor<Runtime>,
        TargetProtocolRequirement<Runtime>>
{
  // 省略部分方法
private:
  /// The name of the protocol.
  TargetRelativeDirectPointer<Runtime, const char, /*nullable*/ false> Name;

  /// The number of generic requirements in the requirement signature of the
  /// protocol.
  uint32_t NumRequirementsInSignature;

  /// The number of requirements in the protocol.
  /// If any requirements beyond MinimumWitnessTableSizeInWords are present
  /// in the witness table template, they will be not be overwritten with
  /// defaults.
  uint32_t NumRequirements;

  /// Associated type names, as a space-separated list in the same order
  /// as the requirements.
  RelativeDirectPointer<const char, /*Nullable=*/true> AssociatedTypeNames;

  // 省略部分方法
}
```

- 内部一些属性，描述了协议的名称、关联类型等一些信息

- 总结：
  - 每个遵守了协议的类，都会有自己的`PWT`，遵守的协议越多，PWT中存储的函数地址就越多
  - `PWT`的本质是一个指针数组，第一个元素存储`TargetProtocolConformanceDescriptor`，其后面存储的是连续的函数地址
  - `PWT`的数量与协议数量一致

#### Existential Container-存在容器

- `Existential container`是编译器生成的一种特殊的数据类型，用于管理遵守了相同协议的协议类型，因为这些类型的内存大小不一致，所以通过当前的`Existential Container`统一做管理
- 它遵循两个原则
  - 对于小容量的数据，直接存储在`Value Buffer` (小于等于24字节)
  - 对于大容量的数据，通过堆区分配，存储堆空间的地址
- 协议的结构就是存在容器，这个存在容器最后的两个 8 字节存储的内容是固定的，存储的是这个实例类型的元类型和协议的见证表。
- 那这前3个8字节存了什么？
  - 若对象是引用类型实例，则前8 字节是实例地址的信息
  - 若对象是值类型实例，则前24 字节是属性值信息，或者前8 字节是存放属性值的地址空间地址信息