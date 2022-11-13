//
//  main.swift
//  属性
//
//  Created by AngaoTu on 2022/11/13.
//

import Foundation

//class Test {
//    var a: Int = 0
//    var b: Int {
//        set {
//            self.a = newValue
//        }
//        get {
//            return 10
//        }
//    }
//}
//
//
//let test = Test()
//test.b = 20

//class Test {
//    lazy var a: Int = 20
//}

//class Test {
//    var a: Int = 10 {
//        willSet {
//            print("new value = \(newValue)")
//        }
//        didSet {
//            print("old value = \(oldValue)")
//        }
//    }
//}

//class Test {
//    static var a: Int = 10
//}


class Test {
    static let share: Test = Test();
    
    private init() {
        
    }
}
