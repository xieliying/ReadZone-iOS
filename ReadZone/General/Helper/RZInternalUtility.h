//
//  RZInternalUtility.h
//  ReadZone
//
//  Created by 谢立颖 on 2018/7/9.
//  Copyright © 2018年 谢立颖. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Returns a localized version of the string designated by the specified key and residing in the RZInternal.
 
 @param key The key for a string in the RZInternal.
 @param comment The comment to place above the key-value pair in the strings file.
 
 @return A localized version of the string designated by key in the RZInternal.
 */
FOUNDATION_EXPORT NSString * RZLocalizedString(NSString *key, NSString *comment);

@interface RZInternalUtility : NSObject


/**
 Return the NSBundle object for returning localized strings

 @return The NSBundle object for returning localized strings.
 */
+ (NSBundle *)tim_bundleForStrings;

@end
