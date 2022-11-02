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
