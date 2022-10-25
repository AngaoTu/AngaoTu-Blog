- [Swift底层原理-枚举](#swift底层原理-枚举)
  - [枚举基本用法](#枚举基本用法)
  - [原始值](#原始值)
  - [隐式原始值](#隐式原始值)
    - [String类型](#string类型)
    - [Int类型](#int类型)
  - [关联值](#关联值)
  - [关联值和原始值的区别](#关联值和原始值的区别)
  - [枚举内存大小](#枚举内存大小)
    - [无关联值的枚举](#无关联值的枚举)
    - [只有一个关联值的枚举](#只有一个关联值的枚举)
    - [多个关联值的枚举](#多个关联值的枚举)
    - [特殊情况](#特殊情况)
# Swift底层原理-枚举

## 枚举基本用法

- 在`Swift`中可以通过`enum` 关键字来声明一个枚举，如下：

```swift
enum Season {
    case spring
    case summer
    case autumn
    case winter
}

var season: Season = .spring
```



## 原始值

- 枚举的`原始值`特性可以将`枚举值`与另一个`数据类型`进行绑定
- 在`Swift`中的枚举则更加灵活，并且不需要给枚举中的每一个成员都提供值，如果要为枚举成员提供值，那么这个值可以是**字符串**，**字符**或者**浮点类型**等等；

```swift
enum Season: String {
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"
}

var season: Season = .spring
print(season.rawValue)
```

> 打印结果：**spring**

- 在枚举 `Season` 的后面加上 `:` 并指定具体的类型，这个时候枚举的原始值默认就是指定的类型。我们可以通过`rawValue`拿到枚举成员的原始值。

## 隐式原始值

- 如果枚举的原始值类型是 `Int`、`String`，`Swift`会自动分配原始值，隐式 `RawValue` 分配是建立在 `Swift` 的类型推断机制上的。

### String类型

- 例如枚举`Season`可以如下定义

```swift
enum Season: String {
    case spring
    case summer
    case autumn
    case winter
}

print(Season.spring.rawValue) // spring
print(Season.summer.rawValue) // summer
print(Season.autumn.rawValue) // autumn
print(Season.winter.rawValue) // winter
```

- 默认将原始值设置为枚举值一样

### Int类型

- 如果枚举Seacon定义为如下

```swift
enum Season: Int {
    case spring
    case summer
    case autumn
    case winter
}

print(Season.spring.rawValue) // 0
print(Season.summer.rawValue) // 1
print(Season.autumn.rawValue) // 2
print(Season.winter.rawValue) // 3
```

- 枚举的原始值是 `Int` 类型的，自动分配的原始值从第一个成员开始，下标从 0 计算，依次 +1
- 如果假设把`autumn`指定为5，那么从`autumn`开始，下标从5开始计算，依次+1

```swift
enum Season: Int {
    case spring
    case summer
    case autumn = 5
    case winter
}

print(Season.spring.rawValue) // 0
print(Season.summer.rawValue) // 1
print(Season.autumn.rawValue) // 5
print(Season.winter.rawValue) // 6
```

## 关联值

- `Swift`中枚举值可以跟其他类型关联起来存储在一起，从而来表达更复杂的案例。

```c++
enum Season {
    case spring(month: Int)
    case summer(startMonth: Int, endMonth: Int)
}
```

- 我们可以在枚举值后面跟上你需要的一些参数，比如说`summer`关联了起始月份和中止月份两个参数

```swift
var sping: Season = Season.spring(month: 1)
switch sping {
case .spring(let month):
    print(month)
case .summer(let startMonth, let endMonth):
    print(startMonth, endMonth)
}
```

- 在使用 `switch` 的时候，我们可以在 `case` 的后面加上 `let` 或者 `var` ，将枚举的关联值取出或者修改。

## 关联值和原始值的区别

- 枚举的关联值和原始值在本质上的区别就是，**关联值占用枚举的内存，而原始值不占用枚举的内存**。

- 并且 **rawValue 本质上是一个计算属性**。举个例子，`rawValue`的实现大概应该是这样子的：

```swift
enum Season: Int {
    case spring, summer, autumn , winter

    var rawValue: Int {
        get {
            switch self {
                case .spring:
                    return 10
                case .summer:
                    return 20
                case .autumn:
                    return 30
                case .winter:
                    return 40
            }
        }
    }
}
```

## 枚举内存大小

- 接下来我们探讨一下枚举的内存大小，探讨的过程中分三种情况：第一种是无关联值的枚举；第二种是只有一个关联值的枚举；第三种是有多个关联值的枚举。

### 无关联值的枚举

```swift
enum Season {
    case spring
    case summer
    case autumn
    case winter
}

print(MemoryLayout<Season>.size) // 1
print(MemoryLayout<Season>.stride) // 1
```

- 通过打印，当前枚举的内存大小为1个字节。无关联值的枚举默认是以一个字节的方式去存储，1个字节可以存储256个`case`。如果超出这个现实，枚举会升级成2个字节去存储。

### 只有一个关联值的枚举

```c++
enum Season {
    case spring(Bool)
    case summer
    case autumn
    case winter
}

print(MemoryLayout<Season>.size) // 1
print(MemoryLayout<Season>.stride) // 1
```

- 当枚举的关联值为`Bool`类型时，枚举只占 1 个字节。对于`Bool`类型来说，它本身是 1 个字节的大小，但实际上它只需要 1 位来存储`Bool`值，而且由于此时的枚举是以`UInt8`的方式进行存储，在这 8 位当中，有 1 位是用来存储`Bool`值的，余下的 7 位才是用来存储`case`的，那此时这个枚举最多只能有 128 个`case`。



- 当枚举的关联值为`int`类型时

```swift
enum Season {
    case spring(Int)
    case summer
    case autumn
    case winter
}

print(MemoryLayout<Season>.size) // 9
print(MemoryLayout<Season>.stride) // 16
```

- 当枚举的关联值为`Int`类型时，枚举占用 9 个字节。对于`Int`类型来说，其实系统是没有办法推算当前负载所要使用的位数，这个时候我们就需要额外开辟内存空间来存储我们的`case`值。

### 多个关联值的枚举

```swift
enum Season1 {
    case spring(Bool)
    case summer(Bool)
    case autumn(Bool)
    case winter(Bool)
}

enum Season2 {
    case spring(Int)
    case summer(Int)
    case autumn(Int)
    case winter(Int)
}

enum Season3 {
    case spring(Bool)
    case summer(Int)
    case autumn
    case winter
}

enum Season4 {
    case spring(Int, Int, Int)
    case summer
    case autumn
    case winter
}

print(MemoryLayout<Season1>.size) // 1
print(MemoryLayout<Season2>.size) // 9
print(MemoryLayout<Season3>.size) // 9
print(MemoryLayout<Season4>.size) // 25
```

- 如果枚举中多个成员有关联值，且最大的关联值类型大于 1 个字节（8 位）的时候，此时枚举的大小为：最大关联值的大小 + 1。

### 特殊情况

```swift
enum Season {
    case season
}

print(MemoryLayout<Season>.size)  // 0
```

- 对于当前的`Season`只有一个`case`，此时不需要用任何东⻄来去区分当前的`case`，所以当我们打印当前的`Season`大小是 0。