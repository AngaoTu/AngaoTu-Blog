- [Swift底层原理-Mirror](#swift底层原理-mirror)
  - [Mirror简介](#mirror简介)
  - [Mirror简单使用](#mirror简单使用)
  - [Mirror源码](#mirror源码)
    - [初始化](#初始化)
      - [_getNormalizedType](#_getnormalizedtype)
      - [ReflectionMirrorImpl](#reflectionmirrorimpl)
      - [StructImpl](#structimpl)
    - [Description](#description)
      - [TargetStructMetadata](#targetstructmetadata)
      - [TargetValueMetadata](#targetvaluemetadata)
      - [TargetStructDescriptor](#targetstructdescriptor)
      - [TargetValueTypeDescriptor](#targetvaluetypedescriptor)
      - [TargetTypeContextDescriptor](#targettypecontextdescriptor)
      - [TargetContextDescriptor](#targetcontextdescriptor)
      - [总结](#总结)
    - [Mirror获取数据](#mirror获取数据)
      - [type](#type)
      - [cout](#cout)
      - [属性名和属性值](#属性名和属性值)
        - [childMetadata](#childmetadata)
          - [getFieldAt](#getfieldat)
        - [childOffset](#childoffset)
  - [总结](#总结-1)


# Swift底层原理-Mirror

- 反射：是指可以动态获取类型、成员信息，在运行时可以调用方法、属性等行为的特性。
- 对于一个纯swift类来说，并不支持直接像`OC runtime`那样的操作,但是`swift`标准库依旧提供了反射机制，用来访问成员信息，即`Mirror`

- 在使⽤`OC`开发时很少强调其反射概念，因为`OC`的`Runtime`要⽐其他语⾔中的反射强⼤的多。但是`Swift`是⼀⻔类型 安全的语⾔，不⽀持我们像`OC`那样直接操作，它的标准库仍然提供了反射机制来让我们访问成员信息。

## Mirror简介

- `Mirror`是`Swift`中的反射机制的实现，它的本质是一个结构体。

```c++
public struct Mirror {

    /// The static type of the subject being reflected.
    ///
    /// This type may differ from the subject's dynamic type when this mirror
    /// is the `superclassMirror` of another mirror.
    public let subjectType: Any.Type

    /// A collection of `Child` elements describing the structure of the
    /// reflected subject.
	// public typealias Children = AnyCollection<Mirror.Child>
    /*
	public enum DisplayStyle : Sendable {
        case `struct`
        case `class`
        case `enum`
        case tuple
        case optional
        case collection
        case dictionary
        case set
	}
    */
    public let children: Mirror.Children

    /// A suggested display style for the reflected subject.
    public let displayStyle: Mirror.DisplayStyle?
	
	/// A mirror of the subject's superclass, if one exists.
    public var superclassMirror: Mirror? { get }
    
    // 省略部分方法
}
```

- `subjectType`：表示类型，被反射主体的类型
- `children`：子元素集合
- `displayStyle`：显示类型，基本类型为`nil` 
- `superclassMirror`：父类反射， 没有父类为`nil`

## Mirror简单使用

- 我们通过`Mirror`打印对象的属性名称和值

```c++
class Test {
    var age: Int = 18
    var name: String = "ssl"
}

var t = Test()

var mirror = Mirror(reflecting: t.self)
print("对象类型：\(mirror.subjectType)")
print("对象属性个数：\(mirror.children.count)")
print("对象的属性及属性值")
for child in mirror.children {
    print("\(child.label!)---\(child.value)")
}
```

- 打印结果

```c++
对象类型：Test
对象属性个数：2
对象的属性及属性值
age---18
name---ssl
```



## Mirror源码

- 为什么通过`Mirror`就可以获得对象的属性信息？我们通过源码来探索它做了哪些事情

- 在源码中找到`Mirror.swift`，快速定位到`Mirror`的初始化方法，如下：

```c++
public init(reflecting subject: Any) {
    if case let customized as CustomReflectable = subject {
        self = customized.customMirror
    } else {
        self = Mirror(internalReflecting: subject)
    }
}
```

- 在初始化函数中判断`subject`是否遵守`CustomReflectable`协议，遵守协议的实例，直接调用`customMirror`属性。
- 如果没有遵守该协议，则走默认初始化流程`Mirror(internalReflecting: subject)`。

### 初始化

```c++
internal init(internalReflecting subject: Any,
              subjectType: Any.Type? = nil,
              customAncestor: Mirror? = nil)
{
    // 1. 判断实例对象的类型，如果为nil，则通过_getNormalizedType去获取
    let subjectType = subjectType ?? _getNormalizedType(subject, type: type(of: subject))
    
    // 2. 获取成员变量
    let childCount = _getChildCount(subject, type: subjectType)
    let children = (0 ..< childCount).lazy.map({
      getChild(of: subject, type: subjectType, index: $0)
    })
    self.children = Children(children)
    
	// 3. 获取父类的Mirror
    self._makeSuperclassMirror = {
      guard let subjectClass = subjectType as? AnyClass,
            let superclass = _getSuperclass(subjectClass) else {
        return nil
      }
      
      // Handle custom ancestors. If we've hit the custom ancestor's subject type,
      // or descendants are suppressed, return it. Otherwise continue reflecting.
      if let customAncestor = customAncestor {
        if superclass == customAncestor.subjectType {
          return customAncestor
        }
        if customAncestor._defaultDescendantRepresentation == .suppressed {
          return customAncestor
        }
      }
      return Mirror(internalReflecting: subject,
                    subjectType: superclass,
                    customAncestor: customAncestor)
    }
    
    // 4. 设置 displayStyle
    let rawDisplayStyle = _getDisplayStyle(subject)
    switch UnicodeScalar(Int(rawDisplayStyle)) {
    case "c": self.displayStyle = .class
    case "e": self.displayStyle = .enum
    case "s": self.displayStyle = .struct
    case "t": self.displayStyle = .tuple
    case "\0": self.displayStyle = nil
    default: preconditionFailure("Unknown raw display style '\(rawDisplayStyle)'")
    }
    
    // 5. 设置 subjectType 和 _defaultDescendantRepresentation
    self.subjectType = subjectType
    self._defaultDescendantRepresentation = .generated
  }
}
```

- 在该方法中，主要做了一下几件事：
  1. 获取`subjectType`，如果传入的有值就使用传入的值，否则就通过`_getNormalizedType`函数去获取
  2. 通过`_getChildCount`获取`childCount`，然后获取`children`，注意这里是懒加载的
  3. 针对父类`SuperclassMirror`处理
  4. 最后会获取并解析显示的样式，并设置`Mirror`一些其他属性。

#### _getNormalizedType

- 我们首先看一下，是如果获取实例对象的类型

```c++
@_silgen_name("swift_reflectionMirror_normalizedType")
internal func _getNormalizedType<T>(_: T, type: Any.Type) -> Any.Type
```

- 函数上面使用了一个编译字段 `@_silgen_name`，这个是`Swift`的一个隐藏符号，作⽤是**将某个 C/C++ 函数直接映射为 Swift 函数**。也就是我们在调用 `_getNormalizedType` 函数的时候，本质上是在调用 `swift_reflectionMirror_normalizedType` 函数。

```c++
const Metadata *swift_reflectionMirror_normalizedType(OpaqueValue *value,
                                                      const Metadata *type,
                                                      const Metadata *T) {
  return call(value, T, type, [](ReflectionMirrorImpl *impl) { return impl->type; });
}
```

```c++
template<typename F>
auto call(OpaqueValue *passedValue, const Metadata *T, const Metadata *passedType,
          const F &f) -> decltype(f(nullptr))
{
  const Metadata *type;
  OpaqueValue *value;
  std::tie(type, value) = unwrapExistential(T, passedValue);
  
  if (passedType != nullptr) {
    type = passedType;
  }
  
  // 这里是类似swift的闭包
  // 非类类型的调用
  auto call = [&](ReflectionMirrorImpl *impl) {
    impl->type = type;
    impl->value = value;
    auto result = f(impl);
    return result;
  };
  
  // 类类型的调用
  auto callClass = [&] {
    if (passedType == nullptr) {
      // Get the runtime type of the object.
      const void *obj = *reinterpret_cast<const void * const *>(value);
      auto isa = _swift_getClass(obj);

      // Look through artificial subclasses.
      while (isa->isTypeMetadata() && isa->isArtificialSubclass()) {
        isa = isa->Superclass;
      }
      passedType = isa;
    }

  #if SWIFT_OBJC_INTEROP
    // If this is a pure ObjC class, reflect it using ObjC's runtime facilities.
    // ForeignClass (e.g. CF classes) manifests as a NULL class object.
    auto *classObject = passedType->getClassObject();
    if (classObject == nullptr || !classObject->isTypeMetadata()) {
      ObjCClassImpl impl;
      return call(&impl);
    }
  #endif

    // Otherwise, use the native Swift facilities.
    ClassImpl impl;
    return call(&impl);
  };
  
  // 通过传入类型的kind来判断，返回不同类型imp
  switch (type->getKind()) {
    case MetadataKind::Tuple: {
      TupleImpl impl;
      return call(&impl);
    }

    case MetadataKind::Struct: {
      StructImpl impl;
      return call(&impl);
    }
    

    case MetadataKind::Enum:
    case MetadataKind::Optional: {
      EnumImpl impl;
      return call(&impl);
    }
      
    case MetadataKind::ObjCClassWrapper:
    case MetadataKind::ForeignClass:
    case MetadataKind::Class: {
      return callClass();
    }

    case MetadataKind::Metatype:
    case MetadataKind::ExistentialMetatype: {
      MetatypeImpl impl;
      return call(&impl);
    }

    case MetadataKind::Opaque: {
#if SWIFT_OBJC_INTEROP
      // If this is the AnyObject type, use the dynamic type of the
      // object reference.
      if (type == &METADATA_SYM(BO).base) {
        return callClass();
      }
#endif
      // If this is the Builtin.NativeObject type, and the heap object is a
      // class instance, use the dynamic type of the object reference.
      if (type == &METADATA_SYM(Bo).base) {
        const HeapObject *obj
          = *reinterpret_cast<const HeapObject * const*>(value);
        if (obj->metadata->getKind() == MetadataKind::Class) {
          return callClass();
        }
      }
      LLVM_FALLTHROUGH;
    }

    /// TODO: Implement specialized mirror witnesses for all kinds.
    default:
      break;

    // Types can't have these kinds.
    case MetadataKind::HeapLocalVariable:
    case MetadataKind::HeapGenericLocalVariable:
    case MetadataKind::ErrorObject:
      swift::crash("Swift mirror lookup failure");
    }

    // If we have an unknown kind of type, or a type without special handling,
    // treat it as opaque.
    OpaqueImpl impl;
    return call(&impl);
}
```

- 该方法比较长，但是逻辑比较清晰。主要做了两件事：
  1. 根据 `kind` 来判断实例的类型，从而拿到不同类型对应的 `impl`
  2. 如果类型不是类类型，则调用非类的 `call(&impl)`；类是调用 `callClass`。

- 最终通过闭包返回一个`ReflectionMirrorImpl`类型的成员变量出去。

#### ReflectionMirrorImpl

`ReflectionMirrorImpl`有以下6个子类：

- `TupleImpl`元组的反射
- `StructImpl`结构体的反射
- `EnumImpl`枚举的反射
- `ClassImpl`类的反射
- `MetatypeImpl`元数据的反射
- `OpaqueImpl`不透明类型的反射



- 我们首先看一下`ReflectionMirrorImpl`结构

```c++
struct ReflectionMirrorImpl {
  const Metadata *type;
  OpaqueValue *value;
  
  virtual char displayStyle() = 0;
  virtual intptr_t count() = 0;
  virtual intptr_t childOffset(intptr_t index) = 0;
  virtual const FieldType childMetadata(intptr_t index,
                                        const char **outName,
                                        void (**outFreeFunc)(const char *)) = 0;
  virtual AnyReturn subscript(intptr_t index, const char **outName,
                              void (**outFreeFunc)(const char *)) = 0;
  virtual const char *enumCaseName() { return nullptr; }

#if SWIFT_OBJC_INTEROP
  virtual id quickLookObject() { return nil; }
#endif
  
  // For class types, traverse through superclasses when providing field
  // information. The base implementations call through to their local-only
  // counterparts.
  virtual intptr_t recursiveCount() {
    return count();
  }
  virtual intptr_t recursiveChildOffset(intptr_t index) {
    return childOffset(index);
  }
  virtual const FieldType recursiveChildMetadata(intptr_t index,
                                                 const char **outName,
                                                 void (**outFreeFunc)(const char *))
  {
    return childMetadata(index, outName, outFreeFunc);
  }

  virtual ~ReflectionMirrorImpl() {}
};
```

- 里面包含了`metedata`、`count`等一些信息。这里也可以理解，上面`swift_reflectionMirror_normalizedType`方法中，最终在`call`函数的闭包中返回了`imp->type`，把类型信息返回出去了
- 这里我们以结构体子类为例子，查看它源码

#### StructImpl

```c++
struct StructImpl : ReflectionMirrorImpl {
  // 是否支持反射
  bool isReflectable() {
    const auto *Struct = static_cast<const StructMetadata *>(type);
    const auto &Description = Struct->getDescription();
    return Description->isReflectable();
  }
  
  // 表明是一个结构体
  char displayStyle() {
    return 's';
  }
  
  // 属性个数
  intptr_t count() {
    if (!isReflectable()) {
      return 0;
    }

    auto *Struct = static_cast<const StructMetadata *>(type);
    return Struct->getDescription()->NumFields;
  }

  // 属性偏移值
  intptr_t childOffset(intptr_t i) {
    auto *Struct = static_cast<const StructMetadata *>(type);

    if (i < 0 || (size_t)i > Struct->getDescription()->NumFields)
      swift::crash("Swift mirror subscript bounds check failure");

    // Load the offset from its respective vector.
    return Struct->getFieldOffsets()[i];
  }

  // 属性的信息
  const FieldType childMetadata(intptr_t i, const char **outName,
                                void (**outFreeFunc)(const char *)) {
    StringRef name;
    FieldType fieldInfo;
    std::tie(name, fieldInfo) = getFieldAt(type, i);
    assert(!fieldInfo.isIndirect() && "indirect struct fields not implemented");
    
    *outName = name.data();
    *outFreeFunc = nullptr;
    
    return fieldInfo;
  }

  AnyReturn subscript(intptr_t i, const char **outName,
                      void (**outFreeFunc)(const char *)) {
    auto fieldInfo = childMetadata(i, outName, outFreeFunc);

    auto *bytes = reinterpret_cast<char*>(value);
    auto fieldOffset = childOffset(i);
    auto *fieldData = reinterpret_cast<OpaqueValue *>(bytes + fieldOffset);

    return copyFieldContents(fieldData, fieldInfo);
  }
};
```

- 在该结构内提供了获取属性、属性信息等一些方法
- 但是这些方法内部，都是通过`StructMetadata`的`getDescription`方法来获取对应的一些信息

### Description

- 在`StructImpl`中我们看到很多关于`Description`的代码，看来这个`Description`存储着很多信息，在获取`Description`的时候是从`StructMetadata`通过`getDescription()`方法获取到。
- 这里我们还是以研究结构体的`metadata`为例子

```c++
using StructMetadata = TargetStructMetadata<InProcess>;
```

- `StructMetadata`是`TargetStructMetadata`的别名

#### TargetStructMetadata

```c++
template <typename Runtime>
struct TargetStructMetadata : public TargetValueMetadata<Runtime> {
  using StoredPointer = typename Runtime::StoredPointer;
  using TargetValueMetadata<Runtime>::TargetValueMetadata;

  const TargetStructDescriptor<Runtime> *getDescription() const {
    return llvm::cast<TargetStructDescriptor<Runtime>>(this->Description);
  }

  // The first trailing field of struct metadata is always the generic
  // argument array.

  /// Get a pointer to the field offset vector, if present, or null.
  const uint32_t *getFieldOffsets() const {
    auto offset = getDescription()->FieldOffsetVectorOffset;
    if (offset == 0)
      return nullptr;
    auto asWords = reinterpret_cast<const void * const*>(this);
    return reinterpret_cast<const uint32_t *>(asWords + offset);
  }

  bool isCanonicalStaticallySpecializedGenericMetadata() const {
    auto *description = getDescription();
    if (!description->isGeneric())
      return false;

    auto *trailingFlags = getTrailingFlags();
    if (trailingFlags == nullptr)
      return false;

    return trailingFlags->isCanonicalStaticSpecialization();
  }

  const MetadataTrailingFlags *getTrailingFlags() const {
    auto description = getDescription();
    auto flags = description->getFullGenericContextHeader()
                     .DefaultInstantiationPattern->PatternFlags;
    if (!flags.hasTrailingFlags())
      return nullptr;
    auto fieldOffset = description->FieldOffsetVectorOffset;
    auto offset =
        fieldOffset +
        // Pad to the nearest pointer.
        ((description->NumFields * sizeof(uint32_t) + sizeof(void *) - 1) /
         sizeof(void *));
    auto asWords = reinterpret_cast<const void *const *>(this);
    return reinterpret_cast<const MetadataTrailingFlags *>(asWords + offset);
  }

  static constexpr int32_t getGenericArgumentOffset() {
    return sizeof(TargetStructMetadata<Runtime>) / sizeof(StoredPointer);
  }

  static bool classof(const TargetMetadata<Runtime> *metadata) {
    return metadata->getKind() == MetadataKind::Struct;
  }
};
```

- 我们在第一个方法可以看到，`TargetStructDescriptor`类型的`Description`
- 在本类没有属性相关，我们去它的父类`TargetValueMetadata`查看一下

#### TargetValueMetadata

```c++
template <typename Runtime>
struct TargetValueMetadata : public TargetMetadata<Runtime> {
  using StoredPointer = typename Runtime::StoredPointer;
  TargetValueMetadata(MetadataKind Kind,
                      const TargetTypeContextDescriptor<Runtime> *description)
      : TargetMetadata<Runtime>(Kind), Description(description) {}

  /// An out-of-line description of the type.
  TargetSignedPointer<Runtime, const TargetValueTypeDescriptor<Runtime> * __ptrauth_swift_type_descriptor> Description;

  static bool classof(const TargetMetadata<Runtime> *metadata) {
    return metadata->getKind() == MetadataKind::Struct
      || metadata->getKind() == MetadataKind::Enum
      || metadata->getKind() == MetadataKind::Optional;
  }

  ConstTargetMetadataPointer<Runtime, TargetValueTypeDescriptor>
  getDescription() const {
    return Description;
  }

  typename Runtime::StoredSignedPointer
  getDescriptionAsSignedPointer() const {
    return Description;
  }
};
```

- 这里我们便找到了`Description`属性，它的类型是`TargetValueTypeDescriptor`，应该是`TargetStructDescriptor`的父类。
- `getDescription()`方法，在`TargetStructMetadata`是重写的这个方法

#### TargetStructDescriptor

- 跳转到`TargetStructDescriptor`中后，我们可以看到

```c++
template <typename Runtime>
class TargetStructDescriptor final
    : public TargetValueTypeDescriptor<Runtime>,
      public TrailingGenericContextObjects<TargetStructDescriptor<Runtime>,
                            TargetTypeGenericContextDescriptorHeader,
                            /*additional trailing objects*/
                            TargetForeignMetadataInitialization<Runtime>,
                            TargetSingletonMetadataInitialization<Runtime>> {
  // 省略部分方法

public:
  using TrailingGenericContextObjects::getGenericContext;
  using TrailingGenericContextObjects::getGenericContextHeader;
  using TrailingGenericContextObjects::getFullGenericContextHeader;
  using TrailingGenericContextObjects::getGenericParams;

  /// The number of stored properties in the struct.
  /// If there is a field offset vector, this is its length.
  uint32_t NumFields;
  /// The offset of the field offset vector for this struct's stored
  /// properties in its metadata, if any. 0 means there is no field offset
  /// vector.
  uint32_t FieldOffsetVectorOffset;
  
  // 省略部分方法
};
```

- `TargetValueTypeDescriptor`是它的父类，也就是说不同类型`description`都继承于`TargetValueTypeDescriptor`
- 在该结构中发现两个属性
  - `NumFields`主要表示结构体中属性的个数，如果只有一个字段偏移量则表示偏移量的长度
  - `FieldOffsetVectorOffset`表示这个结构体元数据中存储的属性的字段偏移向量的偏移量，如果是0则表示没有

#### TargetValueTypeDescriptor

```c++
template <typename Runtime>
class TargetValueTypeDescriptor
    : public TargetTypeContextDescriptor<Runtime> {
public:
  static bool classof(const TargetContextDescriptor<Runtime> *cd) {
    return cd->getKind() == ContextDescriptorKind::Struct ||
           cd->getKind() == ContextDescriptorKind::Enum;
  }
};
```

- 该类并没有太多信息，我们继续查看父类

#### TargetTypeContextDescriptor

```c++
template <typename Runtime>
class TargetTypeContextDescriptor
    : public TargetContextDescriptor<Runtime> {
public:
  /// The name of the type.
  TargetRelativeDirectPointer<Runtime, const char, /*nullable*/ false> Name;

  /// A pointer to the metadata access function for this type.
  ///
  /// The function type here is a stand-in. You should use getAccessFunction()
  /// to wrap the function pointer in an accessor that uses the proper calling
  /// convention for a given number of arguments.
  TargetRelativeDirectPointer<Runtime, MetadataResponse(...),
                              /*Nullable*/ true> AccessFunctionPtr;
  
  /// A pointer to the field descriptor for the type, if any.
  TargetRelativeDirectPointer<Runtime, const reflection::FieldDescriptor,
                              /*nullable*/ true> Fields;
      
  bool isReflectable() const { return (bool)Fields; }

  // 省略部分方法
};
```

- 我们可以得到该类继承自`TargetContextDescriptor`
- 有`Name`、`AccessFunctionPtr`、`Fields`三个属性
  - 其中`name`就是类型的名称
  - `AccessFunctionPtr`是该类型元数据访问函数的指针
  - `Fields`是一个指向该类型的字段描述符的指针

#### TargetContextDescriptor

```c++
template<typename Runtime>
struct TargetContextDescriptor {
  /// Flags describing the context, including its kind and format version.
  ContextDescriptorFlags Flags;
  
  /// The parent context, or null if this is a top-level context.
  TargetRelativeContextPointer<Runtime> Parent;

  // 省略部分方法
};

```

- 它是`descriptors`的基类
- 有两个属性，分别是`Flags`和`Parent`
  - 其中`Flags`是描述上下文的标志，包括它的种类和格式版本。
  - `Parent`是记录父类上下文的，如果是顶级则为null

#### 总结

- 至此，我们就对结构体的`Description`的层级结构基本就理清楚了，现总结如下：

![image.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/406133c696e443a1acc8c74a053b9583~tplv-k3u1fbpfcp-zoom-in-crop-mark:4536:0:0:0.image?)

### Mirror获取数据

- 到此我们对`Description`分析基本很透彻了，那么我们就回到最开始的初始化，看看`Mirror`都是怎样从`Description`取出相应的值的。

- 在初始化方法中，主要干了一下几件事：
  1. 获取`subjectType`，如果传入的有值就使用传入的值，否则就通过`_getNormalizedType`函数去获取
  2. 通过`_getChildCount`获取`childCount`，然后获取`children`，注意这里是懒加载的
  3. 针对父类`SuperclassMirror`处理
  4. 最后会获取并解析显示的样式，并设置`Mirror`一些其他属性。

#### type

```c++
let subjectType = subjectType ?? _getNormalizedType(subject, type: type(of: subject))
```

```c++
@_silgen_name("swift_reflectionMirror_normalizedType")
internal func _getNormalizedType<T>(_: T, type: Any.Type) -> Any.Type
    
SWIFT_CC(swift) SWIFT_RUNTIME_STDLIB_API
const Metadata *swift_reflectionMirror_normalizedType(OpaqueValue *value,
                                                      const Metadata *type,
                                                      const Metadata *T) {
  return call(value, T, type, [](ReflectionMirrorImpl *impl) { return impl->type; });
}
```

- 假设现在是结构体类型，此时的`impl`就是个`StructImpl`类型，所以这里的`type`是`StructImpl`父类`ReflectionMirrorImpl`的属性`type`。

#### cout

```c++
let childCount = _getChildCount(subject, type: subjectType)
```

```c++
@_silgen_name("swift_reflectionMirror_count")
internal func _getChildCount<T>(_: T, type: Any.Type) -> Int
```

- 实际调用`swift_reflectionMirror_count`方法

```c++
SWIFT_CC(swift) SWIFT_RUNTIME_STDLIB_API
intptr_t swift_reflectionMirror_count(OpaqueValue *value,
                                      const Metadata *type,
                                      const Metadata *T) {
  return call(value, T, type, [](ReflectionMirrorImpl *impl) {
    return impl->count();
  });
}
```

- 仍然以结构体为例，此时的`impl`为`StructImpl`，内部的`count()`函数：

```c++
intptr_t count() {
    if (!isReflectable()) {
        return 0;
    }

    auto *Struct = static_cast<const StructMetadata *>(type);
    return Struct->getDescription()->NumFields;
}
```

- 这里的`Struct`就是个`TargetStructMetadata`类型
- 通过`getDescription()`函数获取到一个`TargetStructDescriptor`类型的`Description`
- 然后取`NumFields`的值就是我们要的`count`。

#### 属性名和属性值

```c++
let children = (0 ..< childCount).lazy.map({
    getChild(of: subject, type: subjectType, index: $0)
})
self.children = Children(children)
```

- 通过`getChild`方式去获取所有属性

```c++
internal func getChild<T>(of value: T, type: Any.Type, index: Int) -> (label: String?, value: Any) {
  var nameC: UnsafePointer<CChar>? = nil
  var freeFunc: NameFreeFunc? = nil
  
  let value = _getChild(of: value, type: type, index: index, outName: &nameC, outFreeFunc: &freeFunc)
  
  let name = nameC.flatMap({ String(validatingUTF8: $0) })
  freeFunc?(nameC)
  return (name, value)
}
```

- 内部调用了`_getChild`方法

```c++
@_silgen_name("swift_reflectionMirror_subscript")
internal func _getChild<T>(
  of: T,
  type: Any.Type,
  index: Int,
  outName: UnsafeMutablePointer<UnsafePointer<CChar>?>,
  outFreeFunc: UnsafeMutablePointer<NameFreeFunc?>
) -> Any
```

```c++
SWIFT_CC(swift) SWIFT_RUNTIME_STDLIB_API
AnyReturn swift_reflectionMirror_subscript(OpaqueValue *value, const Metadata *type,
                                           intptr_t index,
                                           const char **outName,
                                           void (**outFreeFunc)(const char *),
                                           const Metadata *T) {
  return call(value, T, type, [&](ReflectionMirrorImpl *impl) {
    return impl->subscript(index, outName, outFreeFunc);
  });
}
```

- 这里我们可以看到是调用了`impl`的`subscript`函数，同样以结构体为例，我们在`StructImpl`中找到该函数，源码如下：

```c++
AnyReturn subscript(intptr_t i, const char **outName,
                      void (**outFreeFunc)(const char *)) {
    auto fieldInfo = childMetadata(i, outName, outFreeFunc);

    auto *bytes = reinterpret_cast<char*>(value);
    auto fieldOffset = childOffset(i);
    auto *fieldData = reinterpret_cast<OpaqueValue *>(bytes + fieldOffset);

    return copyFieldContents(fieldData, fieldInfo);
}
```

- 先通过`childMetadata`获取到`fieldInfo`，其实这里就是获取`FieldType`，也就是属性名
- 通过`childOffset`函数和`index`获取到对于的偏移量，最后根据内存偏移去到属性值。

##### childMetadata

```c++
const FieldType childMetadata(intptr_t i, const char **outName,
                                void (**outFreeFunc)(const char *)) {
    StringRef name;
    FieldType fieldInfo;
    std::tie(name, fieldInfo) = getFieldAt(type, i);
    assert(!fieldInfo.isIndirect() && "indirect struct fields not implemented");

    *outName = name.data();
    *outFreeFunc = nullptr;

    return fieldInfo;
}
```

- 通过调用`getFieldAt`函数获取属性名称

###### getFieldAt

```c++
static std::pair<StringRef /*name*/, FieldType /*fieldInfo*/>
getFieldAt(const Metadata *base, unsigned index) {
  using namespace reflection;
  
  // If we failed to find the field descriptor metadata for the type, fall
  // back to returning an empty tuple as a standin.
  auto failedToFindMetadata = [&]() -> std::pair<StringRef, FieldType> {
    auto typeName = swift_getTypeName(base, /*qualified*/ true);
    missing_reflection_metadata_warning(
      "warning: the Swift runtime found no field metadata for "
      "type '%*s' that claims to be reflectable. Its fields will show up as "
      "'unknown' in Mirrors\n",
      (int)typeName.length, typeName.data);
    return {"unknown", FieldType(&METADATA_SYM(EMPTY_TUPLE_MANGLING))};
  };
  
  // 获取元类型中的描述符，如果没有返回null，否则返回Descriptor
  auto *baseDesc = base->getTypeContextDescriptor();
  if (!baseDesc)
    return failedToFindMetadata();
  
  // 通过调用get方法，内部是base+offset，通过相对偏移拿到fields地址
  auto *fields = baseDesc->Fields.get();
  if (!fields)
    return failedToFindMetadata();
  
  // 从数组中通过下标拿到对应的字段
  auto &field = fields->getFields()[index];
  // 拿到字段名称
  auto name = field.getFieldName();

  // Enum cases don't always have types.
  if (!field.hasMangledTypeName())
    return {name, FieldType::untypedEnumCase(field.isIndirectCase())};

  auto typeName = field.getMangledTypeName();

  SubstGenericParametersFromMetadata substitutions(base);
  auto typeInfo = swift_getTypeByMangledName(MetadataState::Complete,
   typeName,
   substitutions.getGenericArgs(),
   [&substitutions](unsigned depth, unsigned index) {
     return substitutions.getMetadata(depth, index);
   },
   [&substitutions](const Metadata *type, unsigned index) {
     return substitutions.getWitnessTable(type, index);
   });

  // If demangling the type failed, pretend it's an empty type instead with
  // a log message.
  if (!typeInfo.getMetadata()) {
    typeInfo = TypeInfo({&METADATA_SYM(EMPTY_TUPLE_MANGLING),
                         MetadataState::Complete}, {});
    missing_reflection_metadata_warning(
      "warning: the Swift runtime was unable to demangle the type "
      "of field '%*s'. the mangled type name is '%*s'. this field will "
      "show up as an empty tuple in Mirrors\n",
      (int)name.size(), name.data(),
      (int)typeName.size(), typeName.data());
  }

  auto fieldType = FieldType(typeInfo.getMetadata());
  fieldType.setIndirect(field.isIndirectCase());
  fieldType.setReferenceOwnership(typeInfo.getReferenceOwnership());
  return {name, fieldType};
}
```

- 在该方法中，主要做了以下几件事：
  1. 通过`getTypeContextDescriptor`获取`baseDesc`，也就是我们说的`Description`
  2. 通过`Fields.get()`获取到`fields`
  3. 通过`getFields()[index]`或取对应的`field`
  4. 通过`getFieldName()`函数获取到属性名称

##### childOffset

- 分析完属性名的获取，看一下偏移量是如何获取的

```c++
intptr_t childOffset(intptr_t i) {
    auto *Struct = static_cast<const StructMetadata *>(type);

    if (i < 0 || (size_t)i > Struct->getDescription()->NumFields)
        swift::crash("Swift mirror subscript bounds check failure");

    // Load the offset from its respective vector.
    return Struct->getFieldOffsets()[i];
}
```

- 调用`TargetStructMetadata`中的`getFieldOffsets`函数源码如下：

```c++
const uint32_t *getFieldOffsets() const {
    auto offset = getDescription()->FieldOffsetVectorOffset;
    if (offset == 0)
        return nullptr;
    auto asWords = reinterpret_cast<const void * const*>(this);
    return reinterpret_cast<const uint32_t *>(asWords + offset);
}
```

- 我们可以看到这里通过获取`Description`中的属性，这里使用的属性是`FieldOffsetVectorOffset`。

- 获取到偏移值后通过内存偏移即可获取到属性值。

## 总结

至此我们对`Mirror`的原理基本探索完毕了，现在总结一下：

1. `Mirror`通过初始化方法返回一个`Mirror`实例
2. 这个实例对象根据传入对象的类型去对应的`Metadata`中找到`Description`
3. 在`Description`可以获取`name`也就是属性的名称
4. 通过内存偏移获取到属性值
5. 还可以通过`numFields`获取属性的个数