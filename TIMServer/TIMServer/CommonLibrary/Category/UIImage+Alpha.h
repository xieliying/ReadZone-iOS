//
//  UIImage+Alpha.h
//  TIMServer
//
//  Created by 谢立颖 on 2018/10/31.
//  Copyright © 2018 Viomi. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (Alpha)

- (BOOL)hasAlpha;

- (UIImage *)imageWithAlpha;

- (UIImage *)transparentBorderImage:(NSUInteger)borderSize;

@end

NS_ASSUME_NONNULL_END
