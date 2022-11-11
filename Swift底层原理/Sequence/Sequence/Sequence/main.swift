//
//  main.swift
//  Sequence
//
//  Created by AngaoTu on 2022/11/11.
//

import Foundation

//let nums = [1, 2, 3, 4, 5];
//for element in nums {
//    print(element)
//}

struct TestSequence: Sequence {
    typealias Element = Int
    typealias Iterator = TestIterator
    let count: Int
    
    // MARK: - initialization
    init(count: Int) {
        self.count = count
    }
    
    func makeIterator() -> TestIterator {
        return TestIterator(sequece: self)
    }
}

struct TestIterator: IteratorProtocol {
    typealias Element = Int
    let sequece: TestSequence
    var count = 0
    
    // MARK: - initialization
    init(sequece: TestSequence) {
        self.sequece = sequece
    }
    
    mutating func next() -> Int? {
        guard count < sequece.count else {
            return nil
        }
        count += 1
        return count
    }
}

let seq = TestSequence(count: 5)
for element in seq {
    print(element)
}
