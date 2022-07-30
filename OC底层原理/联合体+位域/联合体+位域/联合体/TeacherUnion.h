//
//  TeacherUnion.h
//  联合体+位域
//
//  Created by AngaoTu on 2022/7/30.
//

#import <Foundation/Foundation.h>

union Teacher {
    char *name; // 8
    int age; // 4
    double height; // 8
};
