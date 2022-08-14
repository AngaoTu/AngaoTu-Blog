//
//  ViewController.m
//  alloc流程分析
//
//  Created by AngaoTu on 2022/8/14.
//

#import "ViewController.h"

@interface Test : NSObject

@end

@implementation Test

@end

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    Test *test = [Test alloc];
}


@end
