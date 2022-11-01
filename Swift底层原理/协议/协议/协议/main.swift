//
//  main.swift
//  协议
//
//  Created by AngaoTu on 2022/10/30.
//

import Foundation

protocol BaseProtocol {
    func test()
}

extension BaseProtocol {
    func test() {
    }
}

class TestClass: BaseProtocol {
    var x: Int = 10
    func test() {
        
    }
}


var test: BaseProtocol = TestClass()

//var test1: TestClass = TestClass()

//print("test size: \(MemoryLayout.size(ofValue: test))") // BaseProtocol size: 40
//print("test1 size: \(MemoryLayout.size(ofValue: test1))")   // TestClass size: 8
