[toc]

# Swift底层原理-Sequence与Collection

-  `Sequence`协议来说，表达的是**既可以是一个有限的集合，也可以是一个无限的集合**，而它只需要提供集合中的元素和如何访问这些元素的接口即可。
- `Collection`协议是建立在`Sequence`协议之上的，**为有限的序列提供下标访问的能力**，同时增加了`count`属性，自定义索引等特性

![Snipaste_2022-02-14_00-53-21.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/6a8f5bc42dc34d088c01c1bc7b7327af~tplv-k3u1fbpfcp-zoom-in-crop-mark:4536:0:0:0.awebp?)

## Sequence

- `Sequence`作为`swift`集合类协议扩展方法，为集合提供了一系列的序列迭代能力。

#### for in本质

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



## Collection