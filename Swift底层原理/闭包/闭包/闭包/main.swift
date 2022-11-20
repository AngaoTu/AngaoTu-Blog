//
//  main.swift
//  闭包
//
//  Created by AngaoTu on 2022/11/20.
//

import Foundation

//func makeIncrementer() -> () -> Int {
//    var runningTotal = 10
//    func incrementer() -> Int {
//        runningTotal += 1
//        return runningTotal
//    }
//    return incrementer
//}
//
//let fn = makeIncrementer()
//print(fn())
//print(fn())
//print(fn())

//var runningTotal = 10
//func makeIncrementer() -> () -> Int {
//    func incrementer() -> Int {
//        runningTotal += 1
//        return runningTotal
//    }
//    return incrementer
//}
//
//let fn = makeIncrementer()
//print(fn())
//print(fn())
//print(fn())


//struct ClosureData<Box> {
//    /// 函数地址
//    var ptr: UnsafeRawPointer
//    /// 存储捕获堆空间地址的值
//    var object: UnsafePointer<Box>
//}
//
//struct Box<T> {
//    var heapObject: HeapObject
//    // 捕获变量/常量的值
//    var value: T
//}
//
//struct HeapObject {
//    var matedata: UnsafeRawPointer
//    var refcount: Int
//}


//class Test {
//    var age: Int = 10
//}
//
//func makeIncrementer() -> () -> Int {
//    let test = Test();
//    func incrementer() -> Int {
//        test.age += 1
//        return test.age
//    }
//    return incrementer
//}
//
//let fn = makeIncrementer()


//func makeIncrementer() -> () -> Int {
//    var runningTotal = 10
//    var runningTotal1 = 11
//    func incrementer() -> Int {
//        runningTotal += 1
//        runningTotal1 += runningTotal
//        return runningTotal1
//    }
//    return incrementer
//}
//
//let fn = makeIncrementer()
//print(fn())
//print(fn())
//print(fn())

//struct ClosureData<MutiValue> {
//    /// 函数地址
//    var ptr: UnsafeRawPointer
//    /// 存储捕获堆空间地址的值
//    var object: UnsafePointer<MutiValue>
//}
//
//struct MutiValue<T1,T2> {
//    var object: HeapObject
//    var value: UnsafePointer<Box<T1>>
//    var value1: UnsafePointer<Box<T2>>
//}
//
//struct Box<T> {
//    var object: HeapObject
//    var value: T
//}
//
//struct HeapObject {
//    var matedata: UnsafeRawPointer
//    var refcount: Int
//}


func test(closure: () -> Void) {

}

// 以下是使用尾随闭包进行函数调用
test {
    
}

// 以下是不使用尾随闭包进行函数调用
test(closure: {
    
})
