//
//  main.m
//  对象的本质
//
//  Created by AngaoTu on 2022/7/30.
//

#import <Foundation/Foundation.h>

@interface Person : NSObject
@property (nonatomic, copy) NSString *name;
@end

@implementation Person

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Person *person1 = [[Person alloc] init];
    }
    return 0;
}
