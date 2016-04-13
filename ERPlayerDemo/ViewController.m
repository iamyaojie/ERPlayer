//
//  ViewController.m
//  ERPlayer
//
//  Created by 王耀杰 on 16/4/5.
//  Copyright © 2016年 Erma. All rights reserved.
//

#import "ViewController.h"
#import "ERPlayer.h"

#define SCREENW [UIScreen mainScreen].bounds.size.width
#define SCREENH [UIScreen mainScreen].bounds.size.height

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ERPlayer *player = [ERPlayer new];
    player.frame = CGRectMake(0, 100, SCREENW, SCREENW / 16 * 9  + 40);
    
    NSURL *viedoUrl = [[NSBundle mainBundle] URLForResource:@"Cupid_高清.mp4" withExtension:nil];
    [player setViedoUrl:viedoUrl];
    [self.view addSubview:player];
    
    
}

@end
