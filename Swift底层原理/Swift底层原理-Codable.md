[toc]

# Swift底层原理-Codable

- `Swift` 4.0 支持了一个新的语言特性—`Codable`，其提供了一种非常简单的方式支持模型和数据之间的转换。
- `Codable`能够将程序内部的数据结构序列化成可交换数据，也能够将通用数据格式反序列化为内部使用的数据结构，大大提升对象和其表示之间互相转换的体验。

## 基本用法

### 解码

```swift
import Foundation

struct Product: Codable {
    var name: String
    var age: Int
    var description: String?
}

let json = """
{
"name": "AngaoTu",
"age": 18,
"description": "hello world"
}
""".data(using: .utf8)!

let decoder = JSONDecoder()
let product = try decoder.decode(Product.self, from: json)

print(product)
```

> 打印结果：**Product(name: "AngaoTu", age: 18, description: Optional("hello world"))**

### 编码

```swift
struct Product: Codable {
    var name: String
    var age: Int
    var description: String?
}

let product1 = Product(name: "Angao", age: 18, description: "test")
let encoder = JSONEncoder()
let data = try encoder.encode(product1)
print(String(data: data, encoding: .utf8)!)
```

> 打印结果：**{"name":"Angao","age":18,"description":"test"}**

## Codable

- `Codable`的定义如下：

```swift
typealias Codable = Decodable & Encodable
```

- 它是`Decodable`和`Encodable`协议的类型别名。当`Codable`用作类型或泛型约束时，它匹配符合这两种协议的任何类型。

```swift
/// A type that can encode itself to an external representation.
public protocol Encodable {
    func encode(to encoder: Encoder) throws
}

/// A type that can decode itself from an external representation.
public protocol Decodable {
    init(from decoder: Decoder) throws
}
```

- `Encodable` 协议要求目标模型必须提供编码方法 `func encode(from encoder: Encoder)`，从而按照指定的逻辑进行编码。
- `Decodable` 协议要求目标模型必须提供解码方法 `func init(from decoder: Decoder)`，从而按照指定的逻辑进行解码。

## Decoder

- 在上面解码的时候，初始化了一个`JSONDecoder`对象，并调用了`decode<T : Decodable>(_ type: T.Type, from data: Data)`方法。
- 我们先看一下`JSONDecoder`的定义

### JSONDecoder

```swift
open class JSONDecoder {

    /// The strategy to use for decoding `Date` values.
    public enum DateDecodingStrategy {
        case deferredToDate
        case secondsSince1970
        case millisecondsSince1970
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601
        case formatted(DateFormatter)
        case custom((_ decoder: Decoder) throws -> Date)
    }

    /// The strategy to use for decoding `Data` values.
    public enum DataDecodingStrategy {
        case deferredToData
        case base64
        case custom((_ decoder: Decoder) throws -> Data)
    }

    /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatDecodingStrategy {
        case `throw`
        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use for automatically changing the value of keys before decoding.
    public enum KeyDecodingStrategy {
        case useDefaultKeys
        case convertFromSnakeCase
        case custom((_ codingPath: [CodingKey]) -> CodingKey)
    }

    /// The strategy to use in decoding dates. Defaults to `.deferredToDate`.
    open var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy

    /// The strategy to use in decoding binary data. Defaults to `.base64`.
    open var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy

    /// The strategy to use in decoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy

    /// The strategy to use for decoding keys. Defaults to `.useDefaultKeys`.
    open var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy

    /// Contextual user-provided information for use during decoding.
    open var userInfo: [CodingUserInfoKey : Any]

    /// Set to `true` to allow parsing of JSON5. Defaults to `false`.
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    open var allowsJSON5: Bool

    /// Set to `true` to assume the data is a top level Dictionary (no surrounding "{ }" required). Defaults to `false`. Compatible with both JSON5 and non-JSON5 mode.
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    open var assumesTopLevelDictionary: Bool

    fileprivate struct _Options {
        let dateDecodingStrategy: DateDecodingStrategy
        let dataDecodingStrategy: DataDecodingStrategy
        let nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy
        let keyDecodingStrategy: KeyDecodingStrategy
        let userInfo: [CodingUserInfoKey : Any]
    }

    /// The options set on the top-level decoder.
    fileprivate var options: _Options {
        return _Options(dateDecodingStrategy: dateDecodingStrategy,
                        dataDecodingStrategy: dataDecodingStrategy,
                        nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
                        keyDecodingStrategy: keyDecodingStrategy,
                        userInfo: userInfo)
    }
    
    /// Initializes `self` with default strategies.
    public init()

    open func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable
}
```

- 根据这个结构，我们可以看出，它主要由两部分组成
  - 一些数据类型的解码策略
  - `decode`方法

- `DataDecodingStrategy`：二进制解码策略
  - `deferredToData`：默认解码策略
  
  - `base64`：使用`base64`解码
  
  - `custom`：自定义方式解码
  
- `NonConformingFloatDecodingStrategy`：不合法浮点数的编码策略

  - `throw`

  - `convertFromString`

- `KeyDecodingStrategy`：`Key`的编码策略

  - `useDefaultKeys`

  - `convertFromSnakeCase`

  - `custom`

#### Decode方法

- `decode`方法用于将`JSON`转为指定类型，接收`T.Type`类型和`Data`数据
- 我们看一下`decode`方法做了哪些操作

```swift
open func decode<T : Decodable>(_ type: T.Type, from data: Data) throws -> T {
    let topLevel: Any
    do {
        // 对Data进行Json序列化
        topLevel = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    } catch {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given data was not valid JSON.", underlyingError: error))
    }
	
    // 创建一个内部类
    let decoder = __JSONDecoder(referencing: topLevel, options: self.options)
    // 调用unbox方法，解码
    guard let value = try decoder.unbox(topLevel, as: type) else {
        throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [], debugDescription: "The given data did not contain a top-level value."))
    }

    return value
}
```

- 该方法主要做了以下操作
  1. 使用`JSONSerialization`将`data`数据序列化为字典的`KeyValue`
  2. 调用内部类`_JSONDecoder`传入字典和编码策略返回`decoder`对象
  3. 通过`decoder`对象的`unbox`方法解码并返回`value`

- 这里重点是创建了一个`__JSONDecoder`内部类，让它来完成解码操作

### __JSONDecoder

- 我们先查看它的定义

```swift
private class __JSONDecoder : Decoder
```

- 这里`Decoder`是一个协议

#### Decoder

```swift
public protocol Decoder {
  /// The path of coding keys taken to get to this point in decoding.
  var codingPath: [CodingKey] { get }

  /// Any contextual information set by the user for decoding.
  var userInfo: [CodingUserInfoKey: Any] { get }

  func container<Key>(
    keyedBy type: Key.Type
  ) throws -> KeyedDecodingContainer<Key>

  func unkeyedContainer() throws -> UnkeyedDecodingContainer

  func singleValueContainer() throws -> SingleValueDecodingContainer
}
```

- `Decoder` 协议要求编码器必须提供 3 中类型的解码 `container`、解码路径、上下文缓存。

- 接下来让我们看一下`__JSONDecoder`的内部结构

```swift
private class __JSONDecoder : Decoder {
    // MARK: Properties

    /// The decoder's storage.
    var storage: _JSONDecodingStorage

    /// Options set on the top-level decoder.
    let options: JSONDecoder._Options

    /// The path to the current point in encoding.
    fileprivate(set) public var codingPath: [CodingKey]

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level container and options.
    init(referencing container: Any, at codingPath: [CodingKey] = [], options: JSONDecoder._Options) {
        self.storage = _JSONDecodingStorage()
        self.storage.push(container: container)
        self.codingPath = codingPath
        self.options = options
    }

    // MARK: - Decoder Methods

    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard !(self.storage.topContainer is NSNull) else {
            throw DecodingError.valueNotFound(KeyedDecodingContainer<Key>.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get keyed decoding container -- found null value instead."))
        }

        guard let topContainer = self.storage.topContainer as? [String : Any] else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: [String : Any].self, reality: self.storage.topContainer)
        }

        let container = _JSONKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedDecodingContainer(container)
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard !(self.storage.topContainer is NSNull) else {
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get unkeyed decoding container -- found null value instead."))
        }

        guard let topContainer = self.storage.topContainer as? [Any] else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: [Any].self, reality: self.storage.topContainer)
        }

        return _JSONUnkeyedDecodingContainer(referencing: self, wrapping: topContainer)
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
}
```

- 在该类中存储了一些解码需要用的信息，比如说解码策略，序列化后的`keyValue`

#### init

我们先看`decode`方法里面调用的构造器方法： `init`方法，有三个参数传入

- `container`：序列化后的`KeyValue`
- `codingPath`：`CodingKey`类型的空数组
- `options`：编码策略

```swift
fileprivate init(referencing container: Any, at codingPath: [CodingKey] = [], options: JSONDecoder._Options) {
    self.storage = _JSONDecodingStorage()
    self.storage.push(container: container)
    self.codingPath = codingPath
    self.options = options
}
复制代码
```

它主要工作是

- 创建内部类`_JSONDecodingStorage`
- 使用`push`方法存储要解码的数据container
- 初始化 `options` 和 `codingPath`（空数组）

#### __JSONDecodingStorage

`_JSONDecodingStorage`是一个结构体，内部有`Any`类型数组可存放任意类型，提供`push`、`popContainer`等方法，相当于一个栈容器，它是管理我们传入的`container`的。这里就把它理解为栈

#### unbox方法

- `unbox`方法用于解码操作，匹配对应的类型然后执行条件分支

```swift
func unbox<T : Decodable>(_ value: Any, as type: T.Type) throws -> T? {
    return try unbox_(value, as: type) as? T
}

func unbox_(_ value: Any, as type: Decodable.Type) throws -> Any? {
    if type == Date.self || type == NSDate.self {
        return try self.unbox(value, as: Date.self)
    } else if type == Data.self || type == NSData.self {
        return try self.unbox(value, as: Data.self)
    } else if type == URL.self || type == NSURL.self {
        guard let urlString = try self.unbox(value, as: String.self) else {
            return nil
        }

        guard let url = URL(string: urlString) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Invalid URL string."))
        }
        return url
    } else if type == Decimal.self || type == NSDecimalNumber.self {
        return try self.unbox(value, as: Decimal.self)
    } else if let stringKeyedDictType = type as? _JSONStringDictionaryDecodableMarker.Type {
        return try self.unbox(value, as: stringKeyedDictType)
    } else {
        self.storage.push(container: value)
        defer { self.storage.popContainer() }
        return try type.init(from: self)
    }
}
```

- 该方法内部调用了`unbox_`方法
  - 像`Date`、`Data`、`URL`等，会单独调用各自的`unbox`方法，因为涉及到前面说的解析策略，
  - 我们自己声明的类或者结构体，回来到最后一个分支`type.init(from: self)`

```swift
self.storage.push(container: value)
defer { self.storage.popContainer() }
return try type.init(from: self)
```

- 源码中`type.init(from:)`方法，传入的`self`，本质是`_JSONDecoder`；`type`就是我们要解析的`value`的类型
- 那么`init(from:)`即应该是我们`Decodable`协议中的`init`方法

```swift
public protocol Decodable {
    init(from decoder: Decoder) throws
}
```

- 那这里有个疑问，我们前面都是只继承了`Decodable`，好像从来没有实现过 `init(from decoder: Decoder) throws`它在哪里实现的呢？

### 继承Decodable协议的SIL分析

- 通过对`JSONDecoder`源码的分析，已经得知，除了几个特殊的类型外，最后走的都是遵守`Decodable`的`init(from:)`方法，那在`swift`的`Decodable`源码中，是没有针对 `T(from: self)` 的实现的。所以，我们通过底层的`sil`的代码去窥探 `T(from: self)` 的实现。

```c++
struct Product : Decodable & Encodable {
  @_hasStorage var name: String { get set }
  @_hasStorage var age: Int { get set }
  @_hasStorage @_hasInitialValue var description: String? { get set }
  enum CodingKeys : CodingKey {
    case name
    case age
    case description
    @_implements(Equatable, ==(_:_:)) static func __derived_enum_equals(_ a: Product.CodingKeys, _ b: Product.CodingKeys) -> Bool
    func hash(into hasher: inout Hasher)
    init?(stringValue: String)
    init?(intValue: Int)
    var hashValue: Int { get }
    var intValue: Int? { get }
    var stringValue: String { get }
  }
  func encode(to encoder: Encoder) throws
  init(from decoder: Decoder) throws
  init(name: String, age: Int, description: String? = nil)
}
```

- 我们可以看到编译器自动帮我们生成了`CodingKeys`枚举类型，并遵循`CodingKey`协议。解码过程中会通过`CodingKeys`找到对应`case`
- 自动实现`decode`解码方法：`init(from decoder: Decoder)`

- 这里我们着重看一下编译器默认给我们的实现

```c++
// Product.init(from:)
sil hidden [ossa] @$s4main7ProductV4fromACs7Decoder_p_tKcfC : $@convention(method) (@in Decoder, @thin Product.Type) -> (@owned Product, @error Error) {
// %0 "decoder"                                   // users: %82, %60, %12, %5
// %1 "$metatype"
bb0(%0 : $*Decoder, %1 : $@thin Product.Type):
  %2 = alloc_box ${ var Product }, var, name "self" // user: %3
  %3 = mark_uninitialized [rootself] %2 : ${ var Product } // users: %83, %61, %4
  %4 = project_box %3 : ${ var Product }, 0       // users: %59, %53, %40, %27, %7
  debug_value %0 : $*Decoder, let, name "decoder", argno 1, implicit, expr op_deref // id: %5
  debug_value undef : $Error, var, name "$error", argno 2 // id: %6
  %7 = struct_element_addr %4 : $*Product, #Product.description // user: %10
  // function_ref variable initialization expression of Product.description
  %8 = function_ref @$s4main7ProductV11descriptionSSSgvpfi : $@convention(thin) () -> @owned Optional<String> // user: %9
  %9 = apply %8() : $@convention(thin) () -> @owned Optional<String> // user: %10
  store %9 to [init] %7 : $*Optional<String>      // id: %10
  
  // 创建一个container变量，类型为KeyedDecodingContainer
  %11 = alloc_stack [lexical] $KeyedDecodingContainer<Product.CodingKeys>, let, name "container", implicit // users: %58, %57, %50, %79, %78, %37, %74, %73, %24, %69, %68, %16, %64
  %12 = open_existential_addr immutable_access %0 : $*Decoder to $*@opened("1F24E7D6-5FE6-11ED-B61E-86E79974171B") Decoder // users: %16, %16, %15
  %13 = metatype $@thin Product.CodingKeys.Type
  %14 = metatype $@thick Product.CodingKeys.Type  // user: %16
  
  // 获取 __JSONDecoder 的 container 方法的地址
  %15 = witness_method $@opened("1F24E7D6-5FE6-11ED-B61E-86E79974171B") Decoder, #Decoder.container : <Self where Self : Decoder><Key where Key : CodingKey> (Self) -> (Key.Type) throws -> KeyedDecodingContainer<Key>, %12 : $*@opened("1F24E7D6-5FE6-11ED-B61E-86E79974171B") Decoder : $@convention(witness_method: Decoder) <τ_0_0 where τ_0_0 : Decoder><τ_1_0 where τ_1_0 : CodingKey> (@thick τ_1_0.Type, @in_guaranteed τ_0_0) -> (@out KeyedDecodingContainer<τ_1_0>, @error Error) // type-defs: %12; user: %16
  try_apply %15<@opened("1F24E7D6-5FE6-11ED-B61E-86E79974171B") Decoder, Product.CodingKeys>(%11, %14, %12) : $@convention(witness_method: Decoder) <τ_0_0 where τ_0_0 : Decoder><τ_1_0 where τ_1_0 : CodingKey> (@thick τ_1_0.Type, @in_guaranteed τ_0_0) -> (@out KeyedDecodingContainer<τ_1_0>, @error Error), normal bb1, error bb5 // type-defs: %12; id: %16

bb1(%17 : $()):                                   // Preds: bb0
  %18 = metatype $@thin String.Type               // user: %24
  %19 = metatype $@thin Product.CodingKeys.Type

  // 分配一个 CodinggKeys 内存，将 name 的枚举值写入
  %20 = enum $Product.CodingKeys, #Product.CodingKeys.name!enumelt // user: %22
  %21 = alloc_stack $Product.CodingKeys           // users: %26, %24, %67, %22
  store %20 to [trivial] %21 : $*Product.CodingKeys // id: %22

  // 调用KeyedDecodingContainer 中的 decode(_:forKey:) 方法，即 __JSONKeyedDecodingContainer 的 decode(_:forKey:)
  // function_ref KeyedDecodingContainer.decode(_:forKey:)
  %23 = function_ref @$ss22KeyedDecodingContainerV6decode_6forKeyS2Sm_xtKF : $@convention(method) <τ_0_0 where τ_0_0 : CodingKey> (@thin String.Type, @in_guaranteed τ_0_0, @in_guaranteed KeyedDecodingContainer<τ_0_0>) -> (@owned String, @error Error) // user: %24
  try_apply %23<Product.CodingKeys>(%18, %21, %11) : $@convention(method) <τ_0_0 where τ_0_0 : CodingKey> (@thin String.Type, @in_guaranteed τ_0_0, @in_guaranteed KeyedDecodingContainer<τ_0_0>) -> (@owned String, @error Error), normal bb2, error bb6 // id: %24
```

- 这里面代码比较长，我们直接看重点，它其实做了3件事
  1. 在`%11`行，创建了一个`Container`:`KeyedDecodingContainer`
  2. 在`%15`行，从协议目击表中，调用`Decoder`协议的`container`方法
  3. 在`%23`行，通过`container`的`decode(_:forKey:)`方法来进行解码操作。

#### KeyedDecodingContainer

- `KeyedDecodingContainer<K>`是一个结构体，遵循`KeyedDecodingContainerProtocol`协议。有一个条件限制，`K`必须遵循`CodingKey`协议。
- 结构体内定义各种类型的解码方法，会根据不同类型匹配到对应的`decode`方法

```swift
public struct KeyedDecodingContainer<K: CodingKey> :
  KeyedDecodingContainerProtocol
{
  public typealias Key = K

  /// The container for the concrete decoder.
  internal var _box: _KeyedDecodingContainerBase

  /// Creates a new instance with the given container.
  ///
  /// - parameter container: The container to hold.
  public init<Container: KeyedDecodingContainerProtocol>(
    _ container: Container
  ) where Container.Key == Key {
    _box = _KeyedDecodingContainerBox(container)
  }

  /// The path of coding keys taken to get to this point in decoding.
  public var codingPath: [CodingKey] {
    return _box.codingPath
  }

  public var allKeys: [Key] {
    return _box.allKeys as! [Key]
  }

  public func contains(_ key: Key) -> Bool {
    return _box.contains(key)
  }

  public func decodeNil(forKey key: Key) throws -> Bool {
    return try _box.decodeNil(forKey: key)
  }

  public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    return try _box.decode(Bool.self, forKey: key)
  }


  public func decode(_ type: String.Type, forKey key: Key) throws -> String {
    return try _box.decode(String.self, forKey: key)
  }

  public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    return try _box.decode(Double.self, forKey: key)
  }

  public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    return try _box.decode(Float.self, forKey: key)
  }
  
  public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    return try _box.decode(Int.self, forKey: key)
  }
  
  // 省略剩下方法
}
```

- `KeyedDecodingContainer`定义了很多`decode`和`decodeIfPresent`的解析方法，其中`decodeIfPresent`是用在可选值身上的

#### Decoder协议的container方法

- 这里传入的`decoder`是我们内部类`__JSONDecoder`，知道 `_JSONDecoder`遵守 `Decoder`协议，调用它的`container`方法

```swift
public protocol Decoder {
    /// The path of coding keys taken to get to this point in decoding.
    var codingPath: [CodingKey] { get }

    /// Any contextual information set by the user for decoding.
    var userInfo: [CodingUserInfoKey : Any] { get }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey

    func unkeyedContainer() throws -> UnkeyedDecodingContainer

    func singleValueContainer() throws -> SingleValueDecodingContainer
}
```

- 我们查看一下`__JSONDecoder`中，该协议的实现

```swift
public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
    guard !(self.storage.topContainer is NSNull) else {
        throw DecodingError.valueNotFound(KeyedDecodingContainer<Key>.self,
                                          DecodingError.Context(codingPath: self.codingPath,
                                                                debugDescription: "Cannot get keyed decoding container -- found null value instead."))
    }

    guard let topContainer = self.storage.topContainer as? [String : Any] else {
        throw DecodingError._typeMismatch(at: self.codingPath, expectation: [String : Any].self, reality: self.storage.topContainer)
    }

    let container = _JSONKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
    return KeyedDecodingContainer(container)
}
```

- 这里的返回值就是`KeyedDecodingContainer`类型对象。

- 所以到这里，`Product.init(from:)`第一件事我们已经完成了，手动实现如下

```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    ......
}
```



#### container的decode(_:forKey:)方法

- 在`KeyedDecodingContainer`中根据类别定义了很多`decode`方法,我们随便选择一个类型的`decode`方法分析

```swift
public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    return try _box.decode(Int.self, forKey: key)
}
```

- 核心方法是`_box.decode()`方法
- 这里的`_box`是初始化方法中传入进来的`_JSONKeyedDecodingContainer`，所以上面这句话就是在调用`_JSONKeyedDecodingContainer`的`decode`方法

```swift
/// The container for the concrete decoder.
internal var _box: _KeyedDecodingContainerBase

/// Creates a new instance with the given container.
///
/// - parameter container: The container to hold.
public init<Container: KeyedDecodingContainerProtocol>(
    _ container: Container
) where Container.Key == Key {
    _box = _KeyedDecodingContainerBox(container)
}

let container = _JSONKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
```

- 那么我们看一下`_JSONKeyedDecodingContainer`结构

##### _JSONKeyedDecodingContainer

```swift
private struct _JSONKeyedDecodingContainer<K : CodingKey> : KeyedDecodingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the decoder we're reading from.
    private let decoder: __JSONDecoder

    /// A reference to the container we're reading from.
    private let container: [String : Any]

    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var codingPath: [CodingKey]

    // MARK: - Initialization

    /// Initializes `self` by referencing the given decoder and container.
    init(referencing decoder: __JSONDecoder, wrapping container: [String : Any]) {
        self.decoder = decoder
        switch decoder.options.keyDecodingStrategy {
        case .useDefaultKeys:
            self.container = container
        case .convertFromSnakeCase:
            // Convert the snake case keys in the container to camel case.
            // If we hit a duplicate key after conversion, then we'll use the first one we saw. Effectively an undefined behavior with JSON dictionaries.
            self.container = Dictionary(container.map {
                key, value in (JSONDecoder.KeyDecodingStrategy._convertFromSnakeCase(key), value)
            }, uniquingKeysWith: { (first, _) in first })
        case .custom(let converter):
            self.container = Dictionary(container.map {
                key, value in (converter(decoder.codingPath + [_JSONKey(stringValue: key, intValue: nil)]).stringValue, value)
            }, uniquingKeysWith: { (first, _) in first })
        }
        self.codingPath = decoder.codingPath
    }

    // MARK: - KeyedDecodingContainerProtocol Methods

    public var allKeys: [Key] {
        return self.container.keys.compactMap { Key(stringValue: $0) }
    }

    public func contains(_ key: Key) -> Bool {
        return self.container[key.stringValue] != nil
    }

    private func _errorDescription(of key: CodingKey) -> String {
        switch decoder.options.keyDecodingStrategy {
        case .convertFromSnakeCase:
            // In this case we can attempt to recover the original value by reversing the transform
            let original = key.stringValue
            let converted = JSONEncoder.KeyEncodingStrategy._convertToSnakeCase(original)
            let roundtrip = JSONDecoder.KeyDecodingStrategy._convertFromSnakeCase(converted)
            if converted == original {
                return "\(key) (\"\(original)\")"
            } else if roundtrip == original {
                return "\(key) (\"\(original)\"), converted to \(converted)"
            } else {
                return "\(key) (\"\(original)\"), with divergent representation \(roundtrip), converted to \(converted)"
            }
        default:
            // Otherwise, just report the converted string
            return "\(key) (\"\(key.stringValue)\")"
        }
    }
    
    public func decodeNil(forKey key: Key) throws -> Bool {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(_errorDescription(of: key))."))
        }

        return entry is NSNull
    }

    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(_errorDescription(of: key))."))
        }

        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try self.decoder.unbox(entry, as: Bool.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }

        return value
    }

    // 省略部分方法
}
```

- 我们可以看到它也按照不同类别调用不同的`decode`方法，随便找一个方法

```swift
public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    guard let entry = self.container[key.stringValue] else {
        throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(_errorDescription(of: key))."))
    }

    self.decoder.codingPath.append(key)
    defer { self.decoder.codingPath.removeLast() }

    guard let value = try self.decoder.unbox(entry, as: Bool.self) else {
        throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
    }

    return value
}
```

- 核心方法是`self.decoder.unbox(entry, as: Bool.self)`，这里的`self.decoder`就是我们上面传进来的`_JSONDecoder`，转了一圈，最后还是调用的是`_JSONDecoder`的`unbox`方法

- 最后我们可以基本的出`Product.init(from:)`的实现

```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .nickname)
    age = try container.decode(Int.self, forKey: .age)
}
```

### 解码容器

- 我们在`Decoder`协议中知道，一共提供了三种`Container`:`KeyedDecodingContainer`,`UnkeyedDecodingContainer`,`SingleValueDecodingContainer`

- `KeyedDecodingContainer` 类似于字典，键值对容器，键值是强类型。
- `UnkeyedDecodingContainer` 类似于数组，连续值容器，没有键值。
- `SingleValueDecodingContainer` 基础数据类型容器。

### 解码流程总结

![image.png](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/7953c21ef1ed4ca5aaee37d53edab0ed~tplv-k3u1fbpfcp-zoom-in-crop-mark:4536:0:0:0.image?)

## Encoder

- `Encodable` 协议要求目标模型必须提供编码方法 `func encode(from encoder: Encoder)`，从而按照指定的逻辑进行编码。

```swift
public protocol Encodable {

    /// Encodes this value into the given encoder.
    ///
    /// If the value fails to encode anything, `encoder` will encode an empty
    /// keyed container in its place.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    func encode(to encoder: Encoder) throws
}
```

- 在编码时，我们需要创建一个`JSONEncoder`对象，通过调用它的`encode`方法

### JSONEncoder

```swift
@_objcRuntimeName(_TtC10Foundation13__JSONEncoder)
open class JSONEncoder {
    // MARK: Options

    /// The formatting of the output JSON data.
    public struct OutputFormatting : OptionSet {
        /// The format's default value.
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let prettyPrinted = OutputFormatting(rawValue: 1 << 0)

        @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)

        @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
        public static let withoutEscapingSlashes = OutputFormatting(rawValue: 1 << 3)
    }

    /// The strategy to use for encoding `Date` values.
    public enum DateEncodingStrategy {
        case deferredToDate
        case secondsSince1970
        case millisecondsSince1970
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601
        case formatted(DateFormatter)
        case custom((Date, Encoder) throws -> Void)
    }

    /// The strategy to use for encoding `Data` values.
    public enum DataEncodingStrategy {
        case deferredToData
        case base64
        case custom((Data, Encoder) throws -> Void)
    }

    /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatEncodingStrategy {
        case `throw`
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use for automatically changing the value of keys before encoding.
    public enum KeyEncodingStrategy {
        /// Use the keys specified by each type. This is the default strategy.
        case useDefaultKeys
        
        case convertToSnakeCase
    
        case custom((_ codingPath: [CodingKey]) -> CodingKey)
        
        fileprivate static func _convertToSnakeCase(_ stringKey: String) -> String {...}
    }

    /// The output format to produce. Defaults to `[]`.
    open var outputFormatting: OutputFormatting = []

    /// The strategy to use in encoding dates. Defaults to `.deferredToDate`.
    open var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate

    /// The strategy to use in encoding binary data. Defaults to `.base64`.
    open var dataEncodingStrategy: DataEncodingStrategy = .base64

    /// The strategy to use in encoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw

    /// The strategy to use for encoding keys. Defaults to `.useDefaultKeys`.
    open var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys
    
    /// Contextual user-provided information for use during encoding.
    open var userInfo: [CodingUserInfoKey : Any] = [:]

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    fileprivate struct _Options {
        let dateEncodingStrategy: DateEncodingStrategy
        let dataEncodingStrategy: DataEncodingStrategy
        let nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy
        let keyEncodingStrategy: KeyEncodingStrategy
        let userInfo: [CodingUserInfoKey : Any]
    }

    /// The options set on the top-level encoder.
    fileprivate var options: _Options {
        return _Options(dateEncodingStrategy: dateEncodingStrategy,
                        dataEncodingStrategy: dataEncodingStrategy,
                        nonConformingFloatEncodingStrategy: nonConformingFloatEncodingStrategy,
                        keyEncodingStrategy: keyEncodingStrategy,
                        userInfo: userInfo)
    }

    // MARK: - Constructing a JSON Encoder

    /// Initializes `self` with default strategies.
    public init() {}


    open func encode<T : Encodable>(_ value: T) throws -> Data {
        let encoder = __JSONEncoder(options: self.options)

        guard let topLevel = try encoder.box_(value) else {
            throw EncodingError.invalidValue(value, 
                                             EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values."))
        }

        let writingOptions = JSONSerialization.WritingOptions(rawValue: self.outputFormatting.rawValue).union(.fragmentsAllowed)
        do {
           return try JSONSerialization.data(withJSONObject: topLevel, options: writingOptions)
        } catch {
            throw EncodingError.invalidValue(value, 
                                             EncodingError.Context(codingPath: [], debugDescription: "Unable to encode the given top-level value to JSON.", underlyingError: error))
        }
    }
}
```

- 根据这个结构，我们可以看出它和`JSONEncoder`一样，它主要由两部分组成
  - 一些数据类型的编码策略
  - `encode`方法

#### Encode方法

- `encode`方法用于将指定类型转为`JSON`，接收`T.Type`类型

```swift
open func encode<T : Encodable>(_ value: T) throws -> Data {
    let encoder = __JSONEncoder(options: self.options)

    guard let topLevel = try encoder.box_(value) else {
        throw EncodingError.invalidValue(value, 
                                         EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values."))
    }

    let writingOptions = JSONSerialization.WritingOptions(rawValue: self.outputFormatting.rawValue).union(.fragmentsAllowed)
    do {
        return try JSONSerialization.data(withJSONObject: topLevel, options: writingOptions)
    } catch {
        throw EncodingError.invalidValue(value, 
                                         EncodingError.Context(codingPath: [], debugDescription: "Unable to encode the given top-level value to JSON.", underlyingError: error))
    }
}
```

- 这个流程刚好与`Decoder`是相反的
  - 创建内部类`_JSONEncoder`
  - 调用`box_`方法包装成字典类型
  - 使用`JSONSerialization`序列化为`Data`数据

### __JSONEncoder

- 我们看一下它的定义

```swift
fileprivate class _JSONEncoder : Encoder
```

- 这里`Encoder`是一个协议

#### Encoder

```swift
public protocol Encoder {

    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] { get }

    /// Any contextual information set by the user for encoding.
    var userInfo: [CodingUserInfoKey : Any] { get }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey

    func unkeyedContainer() -> UnkeyedEncodingContainer

    func singleValueContainer() -> SingleValueEncodingContainer
}
```

- `Encoder` 协议要求解码器必须提供 3 中类型的编码 `container`、解码路径、上下文缓存。

- 接下来让我们看一下`__JSONEncoder`的内部结构

```swift
fileprivate class _JSONEncoder : Encoder {
    fileprivate var storage: _JSONEncodingStorage

    fileprivate let options: JSONEncoder._Options

    public var codingPath: [CodingKey]

    public var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }

    fileprivate init(options: JSONEncoder._Options, codingPath: [CodingKey] = []) {
        self.options = options
        self.storage = _JSONEncodingStorage()
        self.codingPath = codingPath
    }

    fileprivate var canEncodeNewValue: Bool {
        return self.storage.count == self.codingPath.count
    }

    public func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
        let topContainer: NSMutableDictionary
        if self.canEncodeNewValue {
            topContainer = self.storage.pushKeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableDictionary else {
                preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
            }

            topContainer = container
        }

        let container = _JSONKeyedEncodingContainer<Key>(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        let topContainer: NSMutableArray
        if self.canEncodeNewValue {
            topContainer = self.storage.pushUnkeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableArray else {
                preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }

            topContainer = container
        }

        return _JSONUnkeyedEncodingContainer(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }

}
```

- 它里面的初始化方法、以及存储的属性与`__JSONDecoder`类似，这里省略分析过程，读者可以自已对照分析。我们直接进入最直接的`box`方法

#### box方法

```swift
func box(_ value: Encodable) throws -> NSObject {
    return try self.box_(value) ?? NSDictionary()
}

func box_(_ value: Encodable) throws -> NSObject? {
    // Disambiguation between variable and function is required due to
    // issue tracked at: https://bugs.swift.org/browse/SR-1846
    let type = Swift.type(of: value)
    if type == Date.self || type == NSDate.self {
        // Respect Date encoding strategy
        return try self.box((value as! Date))
    } else if type == Data.self || type == NSData.self {
        // Respect Data encoding strategy
        return try self.box((value as! Data))
    } else if type == URL.self || type == NSURL.self {
        // Encode URLs as single strings.
        return self.box((value as! URL).absoluteString)
    } else if type == Decimal.self || type == NSDecimalNumber.self {
        // JSONSerialization can natively handle NSDecimalNumber.
        return (value as! NSDecimalNumber)
    } else if value is _JSONStringDictionaryEncodableMarker {
        return try self.box(value as! [String : Encodable])
    }

    // The value should request a container from the __JSONEncoder.
    let depth = self.storage.count
    do {
        try value.encode(to: self)
    } catch {
        // If the value pushed a container before throwing, pop it back off to restore state.
        if self.storage.count > depth {
            let _ = self.storage.popContainer()
        }

        throw error
    }

    // The top container should be a new container.
    guard self.storage.count > depth else {
        return nil
    }

    return self.storage.popContainer()
}
```

- `box_`方法，根据`value`的不同类型，调用不同的代码分支，将`value`包装成对应的数据类型。
- 如果`value`不是上述定义的数据类型，最终会调用`value.encode(to: self)`方法，传入的`self`就是`_JSONEncoder`

- 一样这里我们没有提供自定义类的`encode`实现，还是通过编译器自动帮我们实现了。具体分析和解码编译成sil文件一致，感兴趣读者可以自行研究。

## 总结

- 这里分析比较粗略，如果你已经了解解码过程，这个过程通过类比非常简单可以明白。

![image.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/c551eedf5fe845c7b3ca06405d9a5ded~tplv-k3u1fbpfcp-zoom-in-crop-mark:4536:0:0:0.image?)

