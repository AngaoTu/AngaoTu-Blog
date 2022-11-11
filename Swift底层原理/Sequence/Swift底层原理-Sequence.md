- [Swift底层原理-Sequence与Collection](#swift底层原理-sequence与collection)
  - [Sequence](#sequence)
    - [for in本质](#for-in本质)
    - [Sequence与IteratorProtocol](#sequence与iteratorprotocol)
    - [自己定义一个遵循Sequence的结构体](#自己定义一个遵循sequence的结构体)
  - [Collection](#collection)
    - [mutableCollection](#mutablecollection)
    - [RangeReplaceableCollection](#rangereplaceablecollection)


# Swift底层原理-Sequence与Collection

-  `Sequence`协议来说，表达的是**既可以是一个有限的集合，也可以是一个无限的集合**，而它只需要提供集合中的元素和如何访问这些元素的接口即可。
- `Collection`协议是建立在`Sequence`协议之上的，**为有限的序列提供下标访问的能力**，同时增加了`count`属性，自定义索引等特性

![Snipaste_2022-02-14_00-53-21.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/6a8f5bc42dc34d088c01c1bc7b7327af~tplv-k3u1fbpfcp-zoom-in-crop-mark:4536:0:0:0.awebp?)

## Sequence

- `Sequence`作为`swift`集合类协议扩展方法，为集合提供了一系列的序列迭代能力。

### for in本质

- `Sequence`是通过`Iterator`来访问元素的。`Iterator`是一个迭代器，我们来看一段代码，如下：

```swift
let nums = [1, 2, 3, 4, 5];
for element in nums {
    print(element)
}
```

- 在`Swift`中的 `for in` 其实是一个语法糖，那么它的本质是什么呢，我们把它编译成`sil`的代码来看一下

```c++
// main
sil [ossa] @main : $@convention(c) (Int32, UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>) -> Int32 {
bb0(%0 : $Int32, %1 : $UnsafeMutablePointer<Optional<UnsafeMutablePointer<Int8>>>):
  alloc_global @$s4main4numsSaySiGvp              // id: %2
  // 省略部分代码
  %49 = alloc_stack $Array<Int>                   // users: %53, %52, %50
  store %48 to [init] %49 : $*Array<Int>          // id: %50
  %51 = witness_method $Array<Int>, #Sequence.makeIterator : <Self where Self : Sequence> (__owned Self) -> () -> Self.Iterator : $@convention(witness_method: Sequence) <τ_0_0 where τ_0_0 : Sequence> (@in τ_0_0) -> @out τ_0_0.Iterator // user: %52
  %52 = apply %51<[Int]>(%47, %49) : $@convention(witness_method: Sequence) <τ_0_0 where τ_0_0 : Sequence> (@in τ_0_0) -> @out τ_0_0.Iterator
  dealloc_stack %49 : $*Array<Int>                // id: %53
  br bb1                                          // id: %54

bb1:                                              // Preds: bb3 bb0
  %55 = alloc_stack $Optional<Int>                // users: %61, %60, %58
  %56 = begin_access [modify] [unknown] %47 : $*IndexingIterator<Array<Int>> // users: %59, %58
  %57 = witness_method $IndexingIterator<Array<Int>>, #IteratorProtocol.next : <Self where Self : IteratorProtocol> (inout Self) -> () -> Self.Element? : $@convention(witness_method: IteratorProtocol) <τ_0_0 where τ_0_0 : IteratorProtocol> (@inout τ_0_0) -> @out Optional<τ_0_0.Element> // user: %58
  %58 = apply %57<IndexingIterator<Array<Int>>>(%55, %56) : $@convention(witness_method: IteratorProtocol) <τ_0_0 where τ_0_0 : IteratorProtocol> (@inout τ_0_0) -> @out Optional<τ_0_0.Element>
  end_access %56 : $*IndexingIterator<Array<Int>> // id: %59
  %60 = load [trivial] %55 : $*Optional<Int>      // user: %62
  dealloc_stack %55 : $*Optional<Int>             // id: %61
  switch_enum %60 : $Optional<Int>, case #Optional.some!enumelt: bb3, case #Optional.none!enumelt: bb2 // id: %62
```

- 我们可以看到在`%51`行，调用了`Sequence.makeIterator`方法，创建一个`Iterator`，把数组传给迭代器。
- 在`%57`行，调用`IteratorProtocol.next`方法，将数组元素遍历出来。

### Sequence与IteratorProtocol

- 我们来`Sequence.swift`这个文件，查看`Sequence`定义

```swift
public protocol Sequence {
  // 可在协议实现后确定协议类型
  associatedtype Element

  associatedtype Iterator: IteratorProtocol where Iterator.Element == Element
  
  // 获取一个迭代器
  /// Returns an iterator over the elements of this sequence.
  __consuming func makeIterator() -> Iterator

  // 省略其他方法
}
```

- 在该协议中，最重要的就是创建了一个迭代器

- 查看一下`IteratorProtocol`定义

```swift
public protocol IteratorProtocol {
    /// The type of element traversed by the iterator.
    associatedtype Element

    mutating func next() -> Self.Element?
}
```

- 它有一个`next`方法，可以通过调用`next`方法来返回元素。
- 所以我们每次在使用 for..in 的时候，其实都是 **通过sequence创建一个迭代器，用这个集合的迭代器来遍历当前集合或者序列当中的元素**

### 自己定义一个遵循Sequence的结构体

- 自定义可迭代结构体

```swift
struct TestSequence: Sequence {
    typealias Element = Int
    typealias Iterator = TestIterator
    let count: Int
    
    // MARK: - initialization
    init(count: Int) {
        self.count = count
    }
    
    func makeIterator() -> TestIterator {
        return TestIterator(sequece: self)
    }
}

struct TestIterator: IteratorProtocol {
    typealias Element = Int
    let sequece: TestSequence
    var count = 0
    
    // MARK: - initialization
    init(sequece: TestSequence) {
        self.sequece = sequece
    }
    
    mutating func next() -> Int? {
        guard count < sequece.count else {
            return nil
        }
        count += 1
        return count
    }
}

let seq = TestSequence(count: 5)
for element in seq {
    print(element)
}
```

> 打印结果：
>
> **1**
>
> **2**
>
> **3**
>
> **4**
>
> **5**

## Collection

- `Collection`协议实现了`Sequence`协议，为有限的序列提供下标访问的能力，同时增加了`count`属性，自定义索引等特性。

- `Collection`是一个序列，其元素可以被多次遍历。通过定义`startIndex`和`endIndex`属性，表示集合起始和结束位置。

- 我们看一下`colletcion`定义

```swift
public protocol Collection: Sequence {
  // FIXME: ideally this would be in MigrationSupport.swift, but it needs
  // to be on the protocol instead of as an extension
  @available(*, deprecated/*, obsoleted: 5.0*/, message: "all index distances are now of type Int")
  typealias IndexDistance = Int  

  // FIXME: Associated type inference requires this.
  override associatedtype Element

  associatedtype Index: Comparable

  var startIndex: Index { get } 

  var endIndex: Index { get }

  // sequence协议的实现
  associatedtype Iterator = IndexingIterator<Self>

  override __consuming func makeIterator() -> Iterator

  associatedtype SubSequence: Collection = Slice<Self>
  where SubSequence.Index == Index,
        Element == SubSequence.Element,
        SubSequence.SubSequence == SubSequence

  func index(after i: Index) -> Index
   
  // 省略部分方法
}
```

-  遵循`Collection`协议，此时我们就需要实现 `startIndex`、`endIndex` 和 `index(after:)` 方法，`index(after:)` 是为了便于移动当前索引的位置。

### mutableCollection

- `mutableCollection`定义

```swift
public protocol MutableCollection: Collection
where SubSequence: MutableCollection
{
  // FIXME: Associated type inference requires these.
  override associatedtype Element
  override associatedtype Index
  override associatedtype SubSequence

  @_borrowed
  override subscript(position: Index) -> Element { get set }

  override subscript(bounds: Range<Index>) -> SubSequence { get set }

  mutating func partition(
    by belongsInSecondPartition: (Element) throws -> Bool
  ) rethrows -> Index

  mutating func swapAt(_ i: Index, _ j: Index)
  
  mutating func _withUnsafeMutableBufferPointerIfSupported<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
  ) rethrows -> R?

  mutating func withContiguousMutableStorageIfAvailable<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
  ) rethrows -> R?
}
```

- 遵循该协议，实现了下标的`setter`方法，便于在语法上直接通过下标来访问并修改这个元素的值。

### RangeReplaceableCollection

- `RangeReplaceableCollection`允许集合修改任意区间的元素

```swift
public protocol RangeReplaceableCollection: Collection
  where SubSequence: RangeReplaceableCollection {
  // FIXME: Associated type inference requires this.
  override associatedtype SubSequence

  /// Creates a new, empty collection.
  init()

  mutating func replaceSubrange<C>(
    _ subrange: Range<Index>,
    with newElements: __owned C
  ) where C: Collection, C.Element == Element

  mutating func reserveCapacity(_ n: Int)

  init(repeating repeatedValue: Element, count: Int)

  init<S: Sequence>(_ elements: S)
    where S.Element == Element

  mutating func append(_ newElement: __owned Element)

  mutating func append<S: Sequence>(contentsOf newElements: __owned S)
    where S.Element == Element

  mutating func insert(_ newElement: __owned Element, at i: Index)
 
  @discardableResult
  mutating func remove(at i: Index) -> Element

  mutating func removeSubrange(_ bounds: Range<Index>)

  mutating func _customRemoveLast() -> Element?

  mutating func _customRemoveLast(_ n: Int) -> Bool

  @discardableResult
  mutating func removeFirst() -> Element

  mutating func removeFirst(_ k: Int)

  mutating func removeAll(keepingCapacity keepCapacity: Bool /*= false*/)

  // 省略部分方法
}
```

- 除此之外还有很多针对集合的协议，比如说`BidirectionalCollection`可以向前或向后遍历集合;`RandomAccessCollection`可以任意访问集合元素等。
- 根据功能的不同划分，定义在不同的协议里面，符合借口单一原则，通过协议的组合，可以达到不同复杂度的集合。