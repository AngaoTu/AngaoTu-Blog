[toc]

# Runtime源码解析-类中bits

- 首先我们再看一眼`objc_class`类的定义，本篇文章研究`bits`到底存储了哪些信息

```objective-c
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

```objective-c
struct class_data_bits_t {
    friend objc_class;

    uintptr_t bits;
	// 省略方法
}
```

- 发现该结构只存了一个8字节长的数据，然后通过查阅它的`public`方法

```objective-c
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

```objective-c
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

```objective-c
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

### ro_or_rw_ext_t



## 属性



## 方法