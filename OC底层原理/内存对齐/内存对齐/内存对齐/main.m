//
//  main.m
//  内存对齐
//
//  Created by AngaoTu on 2022/8/13.
//

#import <Foundation/Foundation.h>
#import "objc/runtime.h"

struct Struct1 {
    double a;
    char b;
    int c;
    short d;
}struct1;

struct Struct2 {
    double a;
    int b;
    char c;
    short d;
}struct2;

struct Struct3 {
    double a;
    char b;
    int c;
    short d;
    struct Struct2 str;
}struct3;

@interface Test : NSObject

@property (nonatomic, assign) double a;
@property (nonatomic, assign) char b;
@property (nonatomic, assign) int c;
@property (nonatomic, assign) short d;

@end

@implementation Test


@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Test *test = [Test alloc];
        test.a = 10.0;
        test.b = 'a';
        test.c = 12;
        test.d = 100;
        
        NSLog(@"%lu-%lu-%lu",sizeof(struct1),sizeof(struct2), sizeof(struct3));
        NSLog(@"struct1 = %lu Test = %lu",sizeof(struct1), class_getInstanceSize([test class]));
    }
    return 0;
}
