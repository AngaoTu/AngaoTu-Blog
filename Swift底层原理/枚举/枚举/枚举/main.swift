//
//  main.swift
//  枚举
//
//  Created by AngaoTu on 2022/10/25.
//

import Foundation

//enum Season {
//    case spring
//    case summer
//    case autumn
//    case winter
//}
//
//var season: Season = .spring

//enum Season: Int {
//    case spring
//    case summer
//    case autumn = 5
//    case winter
//}
//
//print(Season.spring.rawValue)
//print(Season.summer.rawValue)
//print(Season.autumn.rawValue)
//print(Season.winter.rawValue)

//enum Season {
//    case spring(month: Int)
//    case summer(startMonth: Int, endMonth: Int)
//}
//
//var sping: Season = Season.spring(month: 1)
//
//switch sping {
//case .spring(let month):
//    print(month)
//case .summer(let startMonth, let endMonth):
//    print(startMonth, endMonth)
//}


//enum Season {
//    case spring(Int)
//    case summer
//    case autumn
//    case winter
//}
//
//print(MemoryLayout<Season>.size)
//print(MemoryLayout<Season>.stride)
//
//
//enum Season1 {
//    case spring(Bool)
//    case summer(Bool)
//    case autumn(Bool)
//    case winter(Bool)
//}
//
//enum Season2 {
//    case spring(Int)
//    case summer(Int)
//    case autumn(Int)
//    case winter(Int)
//}
//
//enum Season3 {
//    case spring(Bool)
//    case summer(Int)
//    case autumn
//    case winter
//}
//
//enum Season4 {
//    case spring(Int, Int, Int)
//    case summer
//    case autumn
//    case winter
//}
//
//print(MemoryLayout<Season1>.size)
//print(MemoryLayout<Season2>.size)
//print(MemoryLayout<Season3>.size)
//print(MemoryLayout<Season4>.size)


//enum Season {
//    case season
//}
//
//print(MemoryLayout<Season>.size)


enum Season: Int {
    case spring, summer, autumn , winter

    var rawValue: Int {
        get {
            switch self {
                case .spring:
                    return 10
                case .summer:
                    return 20
                case .autumn:
                    return 30
                case .winter:
                    return 40
            }
        }
    }
}
