//
//  main.swift
//  Codable
//
//  Created by AngaoTu on 2022/11/8.
//

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


let product1 = Product(name: "Angao", age: 18, description: "test")
let encoder = JSONEncoder()
let data = try encoder.encode(product1)
print(String(data: data, encoding: .utf8)!)
