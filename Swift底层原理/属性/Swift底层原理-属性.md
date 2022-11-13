- [Swift底层原理-属性](#swift底层原理-属性)
  - [存储属性](#存储属性)
  - [计算属性](#计算属性)
    - [sil文件中声明](#sil文件中声明)
    - [getter/setter实现](#gettersetter实现)
  - [延迟属性](#延迟属性)
  - [属性观察器](#属性观察器)
  - [类型属性](#类型属性)
    - [单例的实现](#单例的实现)


# Swift底层原理-属性

## 存储属性

- 存储属性是一个作为特定类和结构体实例一部分的常量或变量。
- 存储属性要么是变量存储属性 (由 `var` 关键字引入)要么是常量存储属性(由 `let` 关键字引入)。
- 在类中有一个原则：**当类实例被构造完成时，必须保证类中所有的属性都构造或者初始化完成**。

```swift
class Test {
    let a: Int = 10
    var b: Int = 0
}
```

- 生成对应`sil`文件

```c++
class Test {
  @_hasStorage @_hasInitialValue final let a: Int { get }
  @_hasStorage @_hasInitialValue var b: Int { get set }
  @objc deinit
  init()
}
```

- 存储属性在编译的时候，编译器默认会合成`get/set`方式，而我们访问/赋值 存储属性的时候，实际上就是调用`get/set`。
- `let`声明的属性默认不会提供`setter`

## 计算属性

- 类、结构体和枚举也能够定义计算属性，**计算属性并不存储值**，他们提供 `getter` 和 `setter` 来修改和获取值。
- 对于存储属性来说可以是常量或变量，但计算属性必须定义为变量。
- 于此同时我们定义计算属性时候必须包含类型，因为编译器需要知道返回值是什么。

```swift
class Test {
    var a: Int = 0
    var b: Int {
        set {
            self.a = newValue
        }
        get {
            return 10
        }
    }
}

let test = Test()
test.b = 20
```

### sil文件中声明

- 我们先看一下`Test`类在`sil`文件中如何声明

```c++
class Test {
  @_hasStorage @_hasInitialValue var a: Int { get set }
  var b: Int { get set }
  @objc deinit
  init()
}
```

- `a`和`b`虽然后面都有`{ get set }`，但是前面修饰符有区别，`a`有`@_hasStorage`，`b`没有。说明`a`是一个可存储的值，`b`没有存储，只有`getter`和`setter`方法。

### getter/setter实现

- 我们查看一下`b`的`getter`和`setter`实现

```c++
// Test.b.setter
sil hidden [ossa] @$s4main4TestC1bSivs : $@convention(method) (Int, @guaranteed Test) -> () {
// %0 "newValue"                                  // users: %5, %2
// %1 "self"                                      // users: %5, %4, %3
bb0(%0 : $Int, %1 : @guaranteed $Test):
  debug_value %0 : $Int, let, name "newValue", argno 1, implicit // id: %2
  debug_value %1 : $Test, let, name "self", argno 2, implicit // id: %3
  %4 = class_method %1 : $Test, #Test.a!setter : (Test) -> (Int) -> (), $@convention(method) (Int, @guaranteed Test) -> () // user: %5
  %5 = apply %4(%0, %1) : $@convention(method) (Int, @guaranteed Test) -> ()
  %6 = tuple ()                                   // user: %7
  return %6 : $()                                 // id: %7
} // end sil function '$s4main4TestC1bSivs'
```

- 可以看到在`setter`中，首先生成一个名为 `newValue` 的常量，并且会把外部传进来的值赋值给 `newValue`。
- 然后调用`setter`方法，把`newValue`作为参数传递给`setter`方法

```c++
// Test.b.getter
sil hidden [ossa] @$s4main4TestC1bSivg : $@convention(method) (@guaranteed Test) -> Int {
// %0 "self"                                      // user: %1
bb0(%0 : @guaranteed $Test):
  debug_value %0 : $Test, let, name "self", argno 1, implicit // id: %1
  %2 = integer_literal $Builtin.IntLiteral, 10    // user: %5
  %3 = metatype $@thin Int.Type                   // user: %5
  // function_ref Int.init(_builtinIntegerLiteral:)
  %4 = function_ref @$sSi22_builtinIntegerLiteralSiBI_tcfC : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %5
  %5 = apply %4(%2, %3) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %6
  return %5 : $Int                                // id: %6
} // end sil function '$s4main4TestC1bSivg'
```

- 从观察`b`属性的`setter`和`getter`中，并未发现有相关的存储变量。所以其实，计算属性根本不会有存储在实例的成员变量，那也就意味着计算属性不占内存。

## 延迟属性

- 使用 `lazy` 可以定义一个延迟存储属性，在第一次用到属性的时候才会进行初始化。
- `lazy` 属性必须是 `var`，不能是 `let`，因为 `let` 必须在实例的初始化方法完成之前就拥有值。
- 如果多条线程同时第一次访问 `lazy` 属性，无法保证属性只被初始化 1 次。

```swift
class Test {
    lazy var a: Int = 20
}
```

- 我们先看一下`Test`类在`sil`文件中如何声明

```c++
class Test {
  lazy var a: Int { get set }
  @_hasStorage @_hasInitialValue final var $__lazy_storage_$_a: Int? { get set }
  @objc deinit
  init()
}
```

- 存储属性在添加了 `lazy` 修饰后，除了拥有存储属性的特性之外，在底层的`sil`代码还生成了一行代码。
- 这行代码拥有 `final` 修饰符，说明 `lazy` 修饰的属性不能被重写。并且，它是一个可选项。拥有可选项就意味着，其实在初始的时候是有值的，只是这个值是一个`nil`。

- 我们来看它的`getter`实现

```c++
// Test.a.getter
sil hidden [lazy_getter] [noinline] [ossa] @$s4main4TestC1aSivg : $@convention(method) (@guaranteed Test) -> Int {
// %0 "self"                                      // users: %16, %2, %1
bb0(%0 : @guaranteed $Test):
  debug_value %0 : $Test, let, name "self", argno 1, implicit // id: %1
  %2 = ref_element_addr %0 : $Test, #Test.$__lazy_storage_$_a // user: %3
  %3 = begin_access [read] [dynamic] %2 : $*Optional<Int> // users: %5, %4
  %4 = load [trivial] %3 : $*Optional<Int>        // user: %6
  end_access %3 : $*Optional<Int>                 // id: %5
  switch_enum %4 : $Optional<Int>, case #Optional.some!enumelt: bb1, case #Optional.none!enumelt: bb2 // id: %6

// %7                                             // users: %9, %8
bb1(%7 : $Int):                                   // Preds: bb0
  debug_value %7 : $Int, let, name "tmp1", implicit // id: %8
  br bb3(%7 : $Int)                               // id: %9

bb2:                                              // Preds: bb0
  %10 = integer_literal $Builtin.IntLiteral, 20   // user: %13
  %11 = metatype $@thin Int.Type                  // user: %13
  // function_ref Int.init(_builtinIntegerLiteral:)
  %12 = function_ref @$sSi22_builtinIntegerLiteralSiBI_tcfC : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %13
  %13 = apply %12(%10, %11) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // users: %20, %15, %14
  debug_value %13 : $Int, let, name "tmp2", implicit // id: %14
  %15 = enum $Optional<Int>, #Optional.some!enumelt, %13 : $Int // user: %18
  %16 = ref_element_addr %0 : $Test, #Test.$__lazy_storage_$_a // user: %17
  %17 = begin_access [modify] [dynamic] %16 : $*Optional<Int> // users: %19, %18
  assign %15 to %17 : $*Optional<Int>             // id: %18
  end_access %17 : $*Optional<Int>                // id: %19
  br bb3(%13 : $Int)                              // id: %20

// %21                                            // user: %22
bb3(%21 : $Int):                                  // Preds: bb2 bb1
  return %21 : $Int                               // id: %22
} // end sil function '$s4main4TestC1aSivg'
```

- 这部分代码有`bb0`、`bb1`、`bb2`、`bb3`几部分组成，我们先看`bb0`，特别是这一行

```c++
switch_enum %4 : $Optional<Int>, case #Optional.some!enumelt: bb1, case #Optional.none!enumelt: bb2 // id: %6
```

- 它根据判断可选属性是否有值，如果有值，走 `bb1`，否则走 `bb2`。
- `bb1`中因为已经有值了，直接调用`bb3`返回出去
- 如果没有值，调用`bb2`模块

```c++
// function_ref Int.init(_builtinIntegerLiteral:)
  %12 = function_ref @$sSi22_builtinIntegerLiteralSiBI_tcfC : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // user: %13
  %13 = apply %12(%10, %11) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int // users: %20, %15, %14
```

- 调用`Int.init(_builtinIntegerLiteral:)`方法，去创建一个值，最后调用`bb3`模块返回回去。

## 属性观察器

- 属性观察者会用来观察属性值的变化， `willSet` 当属性将被改变调用，即使这个值与原有的值相同，而 `didSet` 在属性已经改变之后调用。
- 在初始化器中设置属性值不会触发 `willSet` 和 `didSet`。在属性定义时设置初始值也不会触发 `willSet` 和 `didSet`。

```swift
class Test {
    var a: Int = 10 {
        willSet {
            print("new value = \(newValue)")
        }
        didSet {
            print("old value = \(oldValue)")
        }
    }
}
```

- 我们生成`sil`的代码之后，先来看一下`Test`中`a`的`setter`：

```c++
// Test.a.setter
sil hidden [ossa] @$s4main4TestC1aSivs : $@convention(method) (Int, @guaranteed Test) -> () {
// %0 "value"                                     // users: %13, %10, %2
// %1 "self"                                      // users: %16, %11, %10, %4, %3
bb0(%0 : $Int, %1 : @guaranteed $Test):
  debug_value %0 : $Int, let, name "value", argno 1, implicit // id: %2
  debug_value %1 : $Test, let, name "self", argno 2, implicit // id: %3
  %4 = ref_element_addr %1 : $Test, #Test.a       // user: %5
  %5 = begin_access [read] [dynamic] %4 : $*Int   // users: %7, %6
  %6 = load [trivial] %5 : $*Int                  // users: %16, %8
  end_access %5 : $*Int                           // id: %7
  debug_value %6 : $Int, let, name "tmp", implicit // id: %8
  // function_ref Test.a.willset
  %9 = function_ref @$s4main4TestC1aSivw : $@convention(method) (Int, @guaranteed Test) -> () // user: %10
  %10 = apply %9(%0, %1) : $@convention(method) (Int, @guaranteed Test) -> ()
  %11 = ref_element_addr %1 : $Test, #Test.a      // user: %12
  %12 = begin_access [modify] [dynamic] %11 : $*Int // users: %14, %13
  assign %0 to %12 : $*Int                        // id: %13
  end_access %12 : $*Int                          // id: %14
  // function_ref Test.a.didset
  %15 = function_ref @$s4main4TestC1aSivW : $@convention(method) (Int, @guaranteed Test) -> () // user: %16
  %16 = apply %15(%6, %1) : $@convention(method) (Int, @guaranteed Test) -> ()
  %17 = tuple ()                                  // user: %18
  return %17 : $()                                // id: %18
} // end sil function '$s4main4TestC1aSivs'
```

- 我们可以看到在`setter`方法，用 `willset` 和 `didset` 方法。这两个方法拥有两个参数，第一个参数对应的应该是 `newValue` 和 `oldValue`。

```c++
// function_ref Test.a.willset
%9 = function_ref @$s4main4TestC1aSivw : $@convention(method) (Int, @guaranteed Test) -> () // user: %10
%10 = apply %9(%0, %1) : $@convention(method) (Int, @guaranteed Test) -> ()
```

- 在`%9`行，找到了`willset`方法，然后调用该方法

```c++
// function_ref Test.a.didset
%15 = function_ref @$s4main4TestC1aSivW : $@convention(method) (Int, @guaranteed Test) -> () // user: %16
%16 = apply %15(%6, %1) : $@convention(method) (Int, @guaranteed Test) -> ()
```

- 在`%9`行，找到了`didset`方法，然后调用该方法

## 类型属性

- 严格来说，属性可以分为**实例属性**和**类型属性**。
- 整个程序运行过程中，就只有1份内存（类似于全局变量）
- 不同于存储实例属性，你必须给存储类型属性设定初始值，因为类型没有像实例那样的 `init` 初始化器来初始化存储属性。
- 存储类型属性默认就是 `lazy` ，会在第一次使用的时候才初始化，就算被多个线程同时访问，保证只会初始化一次。
- 存储类型属性可以是 `let`。

```swift
class Test {
    static var a: Int = 10
}
```

- 生成`sil`文件

```c++
class Test {
  @_hasStorage @_hasInitialValue static var a: Int { get set }
  @objc deinit
  init()
}

// one-time initialization token for a
sil_global private @$s4main4TestC1a_Wz : $Builtin.Word

// static Test.a
sil_global hidden @$s4main4TestC1aSivpZ : $Int
```

- `a`变量变成了全局变量
- 我们看一下该变量的初始化方法

```c++
// Test.a.unsafeMutableAddressor
sil hidden [global_init] [ossa] @$s4main4TestC1aSivau : $@convention(thin) () -> Builtin.RawPointer {
bb0:
  %0 = global_addr @$s4main4TestC1a_Wz : $*Builtin.Word // user: %1
  %1 = address_to_pointer %0 : $*Builtin.Word to $Builtin.RawPointer // user: %3
  // function_ref one-time initialization function for a
  %2 = function_ref @$s4main4TestC1a_WZ : $@convention(c) () -> () // user: %3
  %3 = builtin "once"(%1 : $Builtin.RawPointer, %2 : $@convention(c) () -> ()) : $()
  %4 = global_addr @$s4main4TestC1aSivpZ : $*Int  // user: %5
  %5 = address_to_pointer %4 : $*Int to $Builtin.RawPointer // user: %6
  return %5 : $Builtin.RawPointer                 // id: %6
} // end sil function '$s4main4TestC1aSivau'
```

- 我们发现它调用了`builtin "once"`来创建对象，然而在源码中就是 `swift_once` 的调用，打开`swift`源码，找到 `swift_once` 的实现：

```c++
void swift::swift_once(swift_once_t *predicate, void (*fn)(void *),
                       void *context) {
#ifdef SWIFT_STDLIB_SINGLE_THREADED_RUNTIME
  if (! *predicate) {
    *predicate = true;
    fn(context);
  }
#elif defined(__APPLE__)
  dispatch_once_f(predicate, context, fn);
#elif defined(__CYGWIN__)
  _swift_once_f(predicate, context, fn);
#else
  std::call_once(*predicate, [fn, context]() { fn(context); });
#endif
}
```

- 源码中调用了`dispatch_once_f`也就是`GCD`的实现。

### 单例的实现

- 所以在`swift`中单例的实现可以通过`static`

```swift
class Test {
    static let share: Test = Test();
    
    private init() {
        
    }
}
```

