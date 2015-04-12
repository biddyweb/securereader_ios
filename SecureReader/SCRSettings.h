//
//  Settings.h
//  SecureReader
//
//  Created by N-Pex on 2014-10-17.
//  Copyright (c) 2014 Guardian Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCRSettings : NSObject

extern NSString * const kFontSizeAdjustmentSettingsKey;

+ (NSString *)getUiLanguage;
+ (void) setUiLanguage:(NSString *)languageCode;

+ (BOOL)downloadMedia;
+ (void)setDownloadMedia:(BOOL)downloadMedia;

+ (NSInteger) lockTimeout;

+ (float)fontSizeAdjustment;
+ (void)setFontSizeAdjustment:(float)fontSizeAdjustment;

@end
