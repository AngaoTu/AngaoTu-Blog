[toc]

# Runtime源码解析-类中bits

- 首先我们再看一眼`objc_class`类的定义，本篇文章研究`bits`到底存储了哪些信息

```c++
struct objc_class : objc_object {
 	// 初始化方法
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags
    // 其他方法
}
```

- 然后进入到`class_data_bits_t`结构中

```c++
struct class_data_bits_t {
    friend objc_class;

    uintptr_t bits;
	// 省略方法
}
```

- 发现该结构只存了一个8字节长的数据，然后通过查阅它的`public`方法

```c++
class_rw_t* data() const {
    return (class_rw_t *)(bits & FAST_DATA_MASK);
}
void setData(class_rw_t *newData)
{
    ASSERT(!data()  ||  (newData->flags & (RW_REALIZING | RW_FUTURE)));
    // Set during realization or construction only. No locking needed.
    // Use a store-release fence because there may be concurrent
    // readers of data and data's contents.
    uintptr_t newBits = (bits & ~FAST_DATA_MASK) | (uintptr_t)newData;
    atomic_thread_fence(memory_order_release);
    bits = newBits;
}
```

- 发现它提供了一个获取`data()`的方法，这里面应该存储了某些数据，进入返回的类型`class_rw_t`

## class_rw_t

- 首先简单浏览一下该类型

```c++
struct class_rw_t {
    // Be warned that Symbolication knows the layout of this structure.
    uint32_t flags;
    uint16_t witness;
#if SUPPORT_INDEXED_ISA
    uint16_t index;
#endif
	
    // ro_or_rw_ext 会有两种情况：
    // 1. 编译时值是 class_ro_t *
    // 2. class_rw_ext_t *，编译时的 class_ro_t * 作为 class_rw_ext_t 的 const class_ro_t *ro 成员变量保存
    explicit_atomic<uintptr_t> ro_or_rw_ext;

    Class firstSubclass;
    Class nextSiblingClass;

private:
    // 省略私有方法

public:
    // 省略部分方法
    const method_array_t methods() const {
        auto v = get_ro_or_rwe();
        if (v.is<class_rw_ext_t *>()) {
            return v.get<class_rw_ext_t *>(&ro_or_rw_ext)->methods;
        } else {
            return method_array_t{v.get<const class_ro_t *>(&ro_or_rw_ext)->baseMethods()};
        }
    }
    
    const property_array_t properties() const {
        auto v = get_ro_or_rwe();
        if (v.is<class_rw_ext_t *>()) {
            return v.get<class_rw_ext_t *>(&ro_or_rw_ext)->properties;
        } else {
            return property_array_t{v.get<const class_ro_t *>(&ro_or_rw_ext)->baseProperties};
        }
    }

    const protocol_array_t protocols() const {
        auto v = get_ro_or_rwe();
        if (v.is<class_rw_ext_t *>()) {
            return v.get<class_rw_ext_t *>(&ro_or_rw_ext)->protocols;
        } else {
            return protocol_array_t{v.get<const class_ro_t *>(&ro_or_rw_ext)->baseProtocols};
        }
    }
};
```

- 发现`class_rw_t`是一个结构体，提供了获取**属性列表**、**方法列表**、**协议列表**的方法。
- 我们先看一下`private`里面的内容:

```c++
private:
    using ro_or_rw_ext_t = objc::PointerUnion<const class_ro_t, class_rw_ext_t, PTRAUTH_STR("class_ro_t"), PTRAUTH_STR("class_rw_ext_t")>;

    const ro_or_rw_ext_t get_ro_or_rwe() const {
        return ro_or_rw_ext_t{ro_or_rw_ext};
    }

    void set_ro_or_rwe(const class_ro_t *ro) {
        ro_or_rw_ext_t{ro, &ro_or_rw_ext}.storeAt(ro_or_rw_ext, memory_order_relaxed);
    }

    void set_ro_or_rwe(class_rw_ext_t *rwe, const class_ro_t *ro) {
        // the release barrier is so that the class_rw_ext_t::ro initialization
        // is visible to lockless readers
        rwe->ro = ro;
        ro_or_rw_ext_t{rwe, &ro_or_rw_ext}.storeAt(ro_or_rw_ext, memory_order_release);
    }

    class_rw_ext_t *extAlloc(const class_ro_t *ro, bool deep = false);

```

- 使用 `using` 关键字声明一个 `ro_or_rw_ext_t` 类型为: `objc::PointerUnion<**const** class_ro_t, class_rw_ext_t)>;`

- 这里可以简单理解为一个指针联合体，系统只为其分配一个指针的内存空间，一次只能保存 `class_ro_t` 指针或者 `class_rw_ext_t` 指针
- 接着我们看一下`public`里面的主要方法，它大致分为下面几类
  1. 获取`class_rw_ext_t`或者`class_ro_t`
  2. 获取**方法列表**、**属性列表**、**协议列表**



### ro_or_rw_ext_t

- 这里使用`using`关键字申明了`ro_or_rw_ext_t`类型，它的具体类型是一个`PointerUnion`模版类

```c++
template <class T1, class T2, typename Auth1, typename Auth2>
class PointerUnion {
    // 仅有一个成员变量 _value
    uintptr_t _value;

    static_assert(alignof(T1) >= 2, "alignment requirement");
    static_assert(alignof(T2) >= 2, "alignment requirement");

    struct IsPT1 {
      static const uintptr_t Num = 0;
    };
    struct IsPT2 {
      static const uintptr_t Num = 1;
    };
    template <typename T> struct UNION_DOESNT_CONTAIN_TYPE {};

    uintptr_t getPointer() const {
        return _value & ~1;
    }
    uintptr_t getTag() const {
        return _value & 1;
    }

public:
    explicit PointerUnion(const std::atomic<uintptr_t> &raw)
    : _value(raw.load(std::memory_order_relaxed))
    { }
    PointerUnion(T1 *t, const void *address) {
        _value = (uintptr_t)Auth1::sign(t, address);
    }
    PointerUnion(T2 *t, const void *address) {
        _value = (uintptr_t)Auth2::sign(t, address) | 1;
    }

    void storeAt(std::atomic<uintptr_t> &raw, std::memory_order order) const {
        raw.store(_value, order);
    }

    template <typename T>
    bool is() const {
        using Ty = typename PointerUnionTypeSelector<T1 *, T, IsPT1,
            PointerUnionTypeSelector<T2 *, T, IsPT2,
            UNION_DOESNT_CONTAIN_TYPE<T>>>::Return;
        return getTag() == Ty::Num;
    }

    template <typename T> T get(const void *address) const {
        ASSERT(is<T>() && "Invalid accessor called");
        using AuthT = typename PointerUnionTypeSelector<T1 *, T, Auth1,
            PointerUnionTypeSelector<T2 *, T, Auth2,
            UNION_DOESNT_CONTAIN_TYPE<T>>>::Return;

        return AuthT::auth((T)getPointer(), address);
    }

    template <typename T> T dyn_cast(const void *address) const {
      if (is<T>())
        return get<T>(address);
      return T();
    }
};
```

- 在定义时`using ro_or_rw_ext_t = objc::PointerUnion<const class_ro_t, class_rw_ext_t>;`对应到模版类中`T1:const class_ro_t`类型，`T2:class_rw_ext_t`类型

#### 成员变量

- 只有有一个成员变量 `_value`
- 这里可以理解为只能保存 `const class_ro_t` 或 `class_rw_ext_t`  

#### 方法

##### 初始化方法

```c++
explicit PointerUnion(const std::atomic<uintptr_t> &raw)
    : _value(raw.load(std::memory_order_relaxed))
    { }

// 初始化T1
PointerUnion(T1 *t, const void *address) {
    _value = (uintptr_t)Auth1::sign(t, address);
}
// 初始化T2，把_value最后一位设置为1
PointerUnion(T2 *t, const void *address) {
    _value = (uintptr_t)Auth2::sign(t, address) | 1;
}
```

- 这里初始化时，不同类型，通过最后一位来区分

##### 存取方法

```c++
// 根据指定的 order 以原子方式把 raw 保存到 _value 中
void storeAt(std::atomic<uintptr_t> &raw, std::memory_order order) const {
    raw.store(_value, order);
}


// 获取指针 class_ro_t 或者 class_rw_ext_t 指针
template <typename T> T get(const void *address) const {
    ASSERT(is<T>() && "Invalid accessor called");
    using AuthT = typename PointerUnionTypeSelector<T1 *, T, Auth1,
    PointerUnionTypeSelector<T2 *, T, Auth2,
    UNION_DOESNT_CONTAIN_TYPE<T>>>::Return;

    return AuthT::auth((T)getPointer(), address);
}

// get 函数中如果当前 _value 类型和 T 不匹配的话，强制转换会返回错误类型的指针
// dyn_cast 则始终都返回 T 类型的指针
template <typename T> T dyn_cast(const void *address) const {
    if (is<T>())
        return get<T>(address);
    return T();
}
```

##### 类型判断

```c++
// 定义结构体 IsPT1，内部仅有一个静态不可变 uintptr_t 类型的值为 0 的 Num。
//（用于 _value 的类型判断, 表示此时是 class_ro_t *）
struct IsPT1 {
    static const uintptr_t Num = 0;
};

// 定义结构体 IsPT2，内部仅有一个静态不可变 uintptr_t 类型的值为 1 的 Num。
//（用于 _value 的类型判断，表示此时是 class_rw_ext_t *）
struct IsPT2 {
    static const uintptr_t Num = 1;
};

// 来判断_value类型
template <typename T>
bool is() const {
    using Ty = typename PointerUnionTypeSelector<T1 *, T, IsPT1,
    PointerUnionTypeSelector<T2 *, T, IsPT2,
    UNION_DOESNT_CONTAIN_TYPE<T>>>::Return;
    return getTag() == Ty::Num;
}
```

- 通过`is()`方法来判断，`ro_or_rw_ext` 当前是 `class_rw_ext_t` 还是 `class_ro_t` 

### 公有方法

#### 获取class_rw_ext_t

```c++
// 从 ro_or_rw_ext 中取得 class_rw_ext_t 指针
class_rw_ext_t *ext() const {
    return get_ro_or_rwe().dyn_cast<class_rw_ext_t *>(&ro_or_rw_ext);
}

/*
由 class_ro_t 构建一个 class_rw_ext_t。
	如果 ro_or_rw_ext 已经是 class_rw_ext_t 指针了，则直接返回，
	如果 ro_or_rw_ext 是 class_ro_t 指针的话，根据 class_ro_t 的值构建 class_rw_ext_t 并把它的地址赋值给 class_rw_t 的 ro_or_rw_ext，
*/
class_rw_ext_t *extAllocIfNeeded() {
    auto v = get_ro_or_rwe();
    if (fastpath(v.is<class_rw_ext_t *>())) {
        // 直接返回 class_rw_ext_t 指针
        return v.get<class_rw_ext_t *>(&ro_or_rw_ext);
    } else {
        // 构建 class_rw_ext_t 
        return extAlloc(v.get<const class_ro_t *>(&ro_or_rw_ext));
    }
}

class_rw_ext_t *deepCopy(const class_ro_t *ro) {
    return extAlloc(ro, true);
}
```

#### 获取/设置class_ro_t

```c++
// 从 ro_or_rw_ext 中取得 class_ro_t 指针，
const class_ro_t *ro() const {
    auto v = get_ro_or_rwe();
    if (slowpath(v.is<class_rw_ext_t *>())) {
        // 如果此时是 class_rw_ext_t 指针，则返回它的 ro
        return v.get<class_rw_ext_t *>(&ro_or_rw_ext)->ro;
    }
    
    // 如果此时是 class_ro_t，则直接返回
    return v.get<const class_ro_t *>(&ro_or_rw_ext);
}

// 设置ro
void set_ro(const class_ro_t *ro) {
    auto v = get_ro_or_rwe();
    if (v.is<class_rw_ext_t *>()) {
        // 如果 ro_or_rw_ext 中保存的是 class_rw_ext_t 指针，则把 ro 赋值给 class_rw_ext_t 的 const class_ro_t *ro。
        v.get<class_rw_ext_t *>(&ro_or_rw_ext)->ro = ro;
    } else {
       // 如果 ro_or_rw_ext 中保存的是 class_ro_t *ro 的话，直接入参 ro 保存到 ro_or_rw_ext 中。
        set_ro_or_rwe(ro);
    }
}
```

#### 方法、属性、协议列表

```c++
/*
方法列表获取
	1. class_rw_ext_t 的 method_array_t methods
	2. class_ro_t 的 method_list_t * baseMethodList 构建的 method_array_t
*/
const method_array_t methods() const {
    auto v = get_ro_or_rwe();
    if (v.is<class_rw_ext_t *>()) {
        return v.get<class_rw_ext_t *>(&ro_or_rw_ext)->methods;
    } else {
        return method_array_t{v.get<const class_ro_t *>(&ro_or_rw_ext)->baseMethods()};
    }
}

// 属性列表获取（同上）
const property_array_t properties() const {
    auto v = get_ro_or_rwe();
    if (v.is<class_rw_ext_t *>()) {
        return v.get<class_rw_ext_t *>(&ro_or_rw_ext)->properties;
    } else {
        return property_array_t{v.get<const class_ro_t *>(&ro_or_rw_ext)->baseProperties};
    }
}

// 协议列表获取（同上）
const protocol_array_t protocols() const {
    auto v = get_ro_or_rwe();
    if (v.is<class_rw_ext_t *>()) {
        return v.get<class_rw_ext_t *>(&ro_or_rw_ext)->protocols;
    } else {
        return protocol_array_t{v.get<const class_ro_t *>(&ro_or_rw_ext)->baseProtocols};
    }
}
```

## class_rw_ext_t

- 前面我们一直说`class_rw_t`结构中有一个`ro_or_rw_ext`变量，它可以是`class_rw_ext_t`类型指针。我们具体看一下它的结构

```c++
struct class_rw_ext_t {
    DECLARE_AUTHED_PTR_TEMPLATE(class_ro_t)
    // 指向class_ro_t的指针
    class_ro_t_authed_ptr<const class_ro_t> ro;
    // 方法列表
    method_array_t methods;
    // 属性列表
    property_array_t properties;
    // 协议列表
    protocol_array_t protocols;
    // 所属的类名
    char *demangledName;
    // 版本号
    uint32_t version;
};
```

- 可以看到该类中存储了方法、属性、协议列表，是可以动态扩展的列表。
- 以及指向`class_ro_t`的指针

## class_ro_t

- 查看一下`class_ro_t`结构

```c++
struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
#ifdef __LP64__
    uint32_t reserved;
#endif

    union {
        const uint8_t * ivarLayout;
        Class nonMetaclass;
    };
	
    // 类名
    explicit_atomic<const char *> name;
    // 实例方法列表
    WrappedPtr<method_list_t, method_list_t::Ptrauth> baseMethods;
    // 协议列表
    protocol_list_t * baseProtocols;
    // 成员变量列表
    const ivar_list_t * ivars;

    const uint8_t * weakIvarLayout;
    // 属性列表
    property_list_t *baseProperties;

    // 省略方法
};
```

- 它有基础方法列表、基础协议列表、成员变量列表、基础属性列表，这些内容都是编译器确定的。它是可读的，不可修改。
- 至于分类所加载的数据、已经关联对象都存储在`class_rw_ext_t`中

## 总结

- 看完上面内容是不是有一下疑惑？
  1. 为什么`ro_or_rw_ext` 会有两种类型，`class_rw_ext_t`或者`class_ro_t`类型?
  2. 为什么`class_rw_ext_t`和`class_ro_t`都有方法、属性、协议列表，那为什么还需要两个结构存储？有什么区别

- 下面我们一一解答一下上面问题

### 1. 为什么`ro_or_rw_ext` 会有两种类型，`class_rw_ext_t`或者`class_ro_t`类型?

1. 如果没有在运行时，对该类的方法、属性、协议等进行动态添加，则 `ro_or_rw_ext`是`class_ro_t`指针。`class_ro_t`是在编译期确定的。

![](https://tva1.sinaimg.cn/large/e6c9d24egy1h5i4x9jpi4j21jg0u0jux.jpg)

- `class_rw_t`中成员变量`ro_or_rw_ext`直接指向`class_ro_t`，省去`class_rw_ext_t`结构体的数据，减少内存消耗。

2. 如果在运行时，动态的添加了方法、属性、协议等，`ro_or_rw_ext`是`class_rw_ext_t`指针。

![](https://tva1.sinaimg.cn/large/e6c9d24egy1h5i53agzs3j22540kowhn.jpg)

- `class_rw_t`中成员变量`ro_or_rw_ext`直接指向`class_rw_ext_t`，`class_rw_ext_t`的成员变量`ro`指向`class_ro_t`

### 2. 数据区别？

- `class_rw_ext_t`中存储列表使用是一个继承自`list_array_tt`的结构，可以理解为一个二维数组，数组中存的是列表。
- `class_ro_t`中存储列表使用的是一个普通数组。
- 为什么会存储结构不同？在运行时动态添加方法时，会直接在`list_array_tt`类型的二维数组中，把整个分类列表插入进去。

## 获取列表

- `class_rw_t`最主要的作用就是存储了**方法、属性、协议列表**，以及提供了如何获取相关列表。
- 下面我们主要研究一下如何获取相关列表，在开始之前，我们需要了解它们的存储方式是如何？

- 以方法列表为例

```c++
const method_array_t methods() const {
    auto v = get_ro_or_rwe();
    if (v.is<class_rw_ext_t *>()) {
        return v.get<class_rw_ext_t *>(&ro_or_rw_ext)->methods;
    } else {
        return method_array_t{v.get<const class_ro_t *>(&ro_or_rw_ext)->baseMethods()};
    }
}
```

- 该函数返回了一个`method_array_t`类型结构

```c++
class method_array_t : 
    public list_array_tt<method_t, method_list_t, method_list_t_authed_ptr>
```

- 发现该结构继承于`list_array_tt`结构，所以我们首先看看这个结构，它是如何存储的。

### list_array_tt

```c++
template <typename Element, typename List, template<typename> class Ptr>
class list_array_tt {
    struct array_t {...};
protected:
    class iterator {...};
private:
    union {
        Ptr<List> list;
        uintptr_t arrayAndFlag;
    };

    bool hasArray() const {
        return arrayAndFlag & 1;
    }

    array_t *array() const {
        return (array_t *)(arrayAndFlag & ~1);
    }

    void setArray(array_t *array) {
        arrayAndFlag = (uintptr_t)array | 1;
    }

    void validate() {
        for (auto cursor = beginLists(), end = endLists(); cursor != end; cursor++)
            cursor->validate();
    }
}
```

- 我们发现`list_array_tt`是一个模版类
  - `typename Element`：基础元数据类型（例如: `method_t`）
  - `typename List`：元数据的列表类型（例如: `method_list_t`）
- 它内部的成员变量是一个联合体：
  - 一个单独的列表
  - 一个数组，数组中都是指针，每个指针分别指向一个列表 
  - 可以理解为一维数组和二维数组的区别。
- 除此之外，还有两个内部类

#### array_t

```c++
struct array_t {
    uint32_t count; // count 是 lists 数组中 List * 的数量
    Ptr<List> lists[0]; // 指针数组，每个元素指向一个列表

    static size_t byteSize(uint32_t count) {
        return sizeof(array_t) + count*sizeof(lists[0]);
    }
    size_t byteSize() {
        return byteSize(count);
    }
};
```

- 这里`array_t`是一个二维数据结构，里面含有基本的一些数据元素。

#### iterator

- 它是一个迭代器，用来遍历`array_t`结构中的二维数组

### entsize_list_tt

- 还是通过上面获取方法列表的例子

```c++
class method_array_t : 
    public list_array_tt<method_t, method_list_t, method_list_t_authed_ptr>
```

- 我们发现第二个参数传的是`method_list_t`类型，进入它的结构

```c++
struct method_list_t : entsize_list_tt<method_t, method_list_t, 0xffff0003, method_t::pointer_modifier>
```

- 发现它继承于`entsize_list_tt`结构，我们看一下这个结构有何作用。

```c++
template <typename Element, typename List, uint32_t FlagMask, typename PointerModifier = PointerModifierNop>
struct entsize_list_tt {
    uint32_t entsizeAndFlags;
    // entsize_list_tt 的容量
    uint32_t count;

	// 元素的大小（entry 的大小）
    uint32_t entsize() const {
        return entsizeAndFlags & ~FlagMask;
    }
    uint32_t flags() const {
        return entsizeAndFlags & FlagMask;
    }
	
    // 获取对应下标元素
    Element& getOrEnd(uint32_t i) const { 
        ASSERT(i <= count);
        return *PointerModifier::modify(*this, (Element *)((uint8_t *)this + sizeof(*this) + i*entsize()));
    }
    Element& get(uint32_t i) const { 
        ASSERT(i < count);
        return getOrEnd(i);
    }

    size_t byteSize() const {
        return byteSize(entsize(), count);
    }
    
    static size_t byteSize(uint32_t entsize, uint32_t count) {
        return sizeof(entsize_list_tt) + count*entsize;
    }
	
    // 迭代器，用来遍历数组
    struct iterator;
    const iterator begin() const { 
        return iterator(*static_cast<const List*>(this), 0); 
    }
    iterator begin() { 
        return iterator(*static_cast<const List*>(this), 0); 
    }
    const iterator end() const { 
        return iterator(*static_cast<const List*>(this), count); 
    }
    iterator end() { 
        return iterator(*static_cast<const List*>(this), count); 
    }
    
    struct iterator {...};
}
```

- `entsize_list_tt`其实就是一个数组，用来存储编译完成后类的属性，提供了遍历和访问方法。



### 方法列表



### 属性列表

### 协议列表