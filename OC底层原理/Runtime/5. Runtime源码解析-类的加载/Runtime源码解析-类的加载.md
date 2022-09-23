[toc]

# Runtime源码解析-类的加载

## 前言

- 我们在上一篇文章`_objc_init`流程分析中，得知在`_read_images`方法中，修复错误的类时，让类的地址和名称关联起来。

```c++
for (EACH_HEADER) {
    if (! mustReadClasses(hi, hasDyldRoots)) {
        // Image is sufficiently optimized that we need not call readClass()
        continue;
    }
    // 从macho中读取类列表信息
    classref_t const *classlist = _getObjc2ClassList(hi, &count);

    bool headerIsBundle = hi->isBundle();
    bool headerIsPreoptimized = hi->hasPreoptimizedClasses();

    for (i = 0; i < count; i++) {
        Class cls = (Class)classlist[i];
        Class newCls = readClass(cls, headerIsBundle, headerIsPreoptimized);

        if (newCls != cls  &&  newCls) {
            // Class was moved but not deleted. Currently this occurs 
            // only when the new class resolved a future class.
            // Non-lazily realize the class below.
            resolvedFutureClasses = (Class *)
                realloc(resolvedFutureClasses, 
                        (resolvedFutureClassCount+1) * sizeof(Class));
            resolvedFutureClasses[resolvedFutureClassCount++] = newCls;
        }
    }
}
```

- 通过`readClass`方法达到地址和名称关联起来目的。虽然该方法中有对`class`的`ro`、`rw`处理，通过断点调试可知，并没有走相关方法。
- 然后在`_read_images`流程分析时，除了此处和类相关，还在倒数第二个流程，也做了类的加载处理，让我们看一下此处操作。

## 类的加载

```c++
// Realize newly-resolved future classes, in case CF manipulates them
for (EACH_HEADER) {
    classref_t const *classlist = hi->nlclslist(&count);
    for (i = 0; i < count; i++) {
        Class cls = remapClass(classlist[i]);
        if (!cls) continue;

        addClassTableEntry(cls);

        if (cls->isSwiftStable()) {
            if (cls->swiftMetadataInitializer()) {
                _objc_fatal("Swift class %s with a metadata initializer "
                            "is not allowed to be non-lazy",
                            cls->nameForLogging());
            }
            // fixme also disallow relocatable classes
            // We can't disallow all Swift classes because of
            // classes like Swift.__EmptyArrayStorage
        }
        realizeClassWithoutSwift(cls, nil);
    }
}
```

- 根据注释提示，这里只加载非懒加载的类，就是实现了`load`方法的类。具体懒加载和非懒加载的区别，我们后面再讲述。
- 