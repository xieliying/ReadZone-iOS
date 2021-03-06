//
//  TSBaseViewController.m
//  TIMServer
//
//  Created by 谢立颖 on 2018/10/31.
//  Copyright © 2018 Viomi. All rights reserved.
//

#import "TSBaseViewController.h"
#import "TSDevice.h"
#import <objc/runtime.h>

@interface TSBaseViewController ()

@end

@implementation TSBaseViewController

- (instancetype)init {
    if (self = [super init]) {
        [self configParams];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = RGB(245, 245, 245);
    
    [self addOwnViews];
    [self configOwnViews];
    [self layoutSubviewsFrame];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self layoutOnViewWillAppear];
}

- (void)configParams {
    
}

#pragma mark -
- (BOOL)hasBackgroundView {
    return NO;
}

- (void)addBackground {
    
}

- (void)configBackground {
    
}

- (void)layoutBackground {
    
}

- (void)viewWillLayoutSubviews {
    if (![self asChild]) {
        [super viewWillLayoutSubviews];
    } else {
        if (CGSizeEqualToSize(self.childSize, CGSizeZero)) {
            [super viewWillLayoutSubviews];
        } else {
            CGSize size = [self childSize];
            self.view.bounds = CGRectMake(0, 0, size.width, size.height);
        }
    }
}

- (void)layoutSubviewsFrame {
    [super layoutSubviewsFrame];
}


#pragma makr -
- (void)callImagePickerActionSheet {
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.allowsEditing = YES;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (void)addTapBlankToHideKeyboardGesture {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapBlankToHideKeyboard:)];
    tap.numberOfTapsRequired = 1;
    tap.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:tap];
}

- (void)onTapBlankToHideKeyboard:(UITapGestureRecognizer *)ges {
    if (ges.state == UIGestureRecognizerStateEnded) {
        [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
    }
}

//- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
//    
//}

//- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
//    
//    if (buttonIndex == actionSheet.cancelButtonIndex) {
//        return;
//    }
//    
//    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
//    imagePicker.delegate = self;
//    imagePicker.allowsEditing = YES;
//    if (buttonIndex == 0 && [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
//    {
//        imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
//    }
//    else if (buttonIndex == 1 && [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
//    {
//        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
//    }
//    [self presentViewController:imagePicker animated:YES completion:nil];
//}


// 添加自动布局相关的constraints
- (void)autoLayoutOwnViews
{
    // 添加自动布局相关的内容
}

@end
