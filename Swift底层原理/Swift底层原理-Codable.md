[toc]

# Swift底层原理-Codable

- `Swift` 4.0 支持了一个新的语言特性—`Codable`，其提供了一种非常简单的方式支持模型和数据之间的转换。
- `Codable`能够将程序内部的数据结构序列化成可交换数据，也能够将通用数据格式反序列化为内部使用的数据结构，大大提升对象和其表示之间互相转换的体验。

## 基本用法

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