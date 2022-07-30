[toc]

# 策略模式

## 定义

- **策略模式**是一种行为设计模式， 它能让你定义一系列算法， 并将每种算法分别放入独立的类中， 而且使他们可以相互替换，让算法独立于使用它的客户而独立变化。
- 这个模式设计到三个角色：
  1. `context`上下文:持有`strategy`的引用
  2. 抽象策略：所有具体策略的通用接口， 它声明了一个上下文用于执行策略的方法。
  3. 具体策略：封装了相关的具体算法或行为。

 ## 结构

## 举例

- 此处参考《大话设计模式》中案例
- 商场最近在促销，有多种促销方案
  1. 原价出售
  2. 打折出售
  3. 满减方案，（满300百，减100）

### 算法类

- 这里可以把不同的促销方案，看作是不同的算法。这些算法目的就是返回最终消费金额，所以我们可以定一个抽象算法类

```swift
// 抽象方法类
class BaseCash {
    // 返回最终消费金额
    func acceptCash(cash: Float) -> Float {
        return 0.0
    }
}
```

- 实现不同促销方案

```swift
// 返回原价
class CashNormal: BaseCash {
    override func acceptCash(cash: Float) -> Float {
        return cash
    }
}

// 打折出售
class CashRebate: BaseCash {
    // MARK: - initialization
    init(rebate: Float) {
        self.rebate = rebate
    }
    
    
    // MARK: - Private Property
    fileprivate let rebate: Float
    
    // MARK: - Override Method
    override func acceptCash(cash: Float) -> Float {
        return rebate * cash
    }
}

// 满减出售
class CashReturn: BaseCash {
    // MARK: initialization
    init(conditionCash: Float, returnCash: Float) {
        self.conditionCash = conditionCash
        self.returnCash = returnCash
    }
    
    // MARK: - Private Property
    fileprivate let conditionCash: Float
    fileprivate let returnCash: Float
    
    // MARK: - Override
    override func acceptCash(cash: Float) -> Float {
        return cash >= conditionCash ? cash - floor(cash / conditionCash) * returnCash : cash;
    }
}
```

### 上下文类

- 上下文，维护一个`cashStrategy`对象的引用，调用对应算法，返回消费金额

```swift
class CashContext {
    // MARK: initialization
    init(cashStrategy: BaseCash) {
        self.cashStrategy = cashStrategy
    }
    
    // MARK: - Private Property
    fileprivate let cashStrategy: BaseCash
    
    // MARK: - Publish Method
    func getResult(cash: Float) -> Float {
        return cashStrategy.acceptCash(cash: cash)
    }
}
```

### 客户端

```swift
import Foundation

print("正常收费 price = \(getPrice(type: "正常收费", price: 500))")
print("满300返100 price = \(getPrice(type: "满300返100", price: 500))")
print("打8折 price = \(getPrice(type: "打8折", price: 500))")

func getPrice(type: String, price: Float) -> Float {
    var contenxt: CashContext? = nil
    switch type {
    case "正常收费":
        contenxt = CashContext(cashStrategy: CashNormal())
    case "满300返100":
        contenxt = CashContext(cashStrategy: CashReturn(conditionCash: 300, returnCash: 100))
    case "打8折":
        contenxt = CashContext(cashStrategy: CashRebate(rebate: 0.8))
    default:
        break
    }
    return contenxt?.getResult(cash: price) ?? price
}
```

## 适用场景

- 当你想使用对象中各种不同的算法变体，并希望能在运行时切换算法时，可使用策略模式。
- 当你有许多仅在执行某些行为时略有不同的相似类时， 可使用策略模式。

## 优缺点

### 优点

- 客户端可以根据场合随意切换到底要使用哪一种策略
- 将客户端与具体实现通过`Context`解耦，又可以让具体算法独立发展而不会影响其他类修改
- **开闭原则**。 你无需对上下文进行修改就能够引入新的策略。

### 缺点

-  如果你的算法极少发生改变， 那么没有任何理由引入新的类和接口。 使用该模式只会让程序过于复杂。
-  客户端必须知晓策略间的不同——它需要选择合适的策略。

