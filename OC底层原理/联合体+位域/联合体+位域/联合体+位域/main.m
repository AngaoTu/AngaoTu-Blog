//
//  main.m
//  联合体+位域
//
//  Created by AngaoTu on 2022/7/30.
//

#import <Foundation/Foundation.h>
#import "TeacherUnion.h"
#import "StatusBitField.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // 联合体
        union Teacher teacher;
        teacher.name = "AngaoTu";
        teacher.age = 18;
        teacher.height = 175.0;

        NSLog(@"联合体大小 size = %lu", sizeof(teacher));
        NSLog(@"name 地址 = %p, age 地址 = %p, height 地址 = %p", &teacher.name, &teacher.age, &teacher.height);
        
        // 位域
        struct bits bits1;
        NSLog(@"位域的大小 size = %ld", sizeof(bits1));
    }
    return 0;
}
