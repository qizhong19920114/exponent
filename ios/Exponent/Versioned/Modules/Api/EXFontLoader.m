// Copyright 2015-present 650 Industries. All rights reserved.

#import "EXFontLoader.h"

@import CoreGraphics;
@import CoreText;
@import Foundation;
@import UIKit;

#import <objc/runtime.h>

#import "RCTConvert.h"
#import "RCTUtils.h"

static NSMutableDictionary *EXFonts = nil;

@interface EXFont : NSObject

@property (nonatomic, assign) CGFontRef cgFont;
@property (nonatomic, strong) NSMutableDictionary *sizes;

@end

@implementation EXFont

- (instancetype) initWithCGFont:(CGFontRef )cgFont
{
  if ((self = [super init])) {
    _cgFont = cgFont;
    _sizes = [NSMutableDictionary dictionary];
  }
  return self;
}

- (UIFont *) UIFontWithSize:(CGFloat) fsize
{
  NSNumber *size = @(fsize);
  UIFont *uiFont = _sizes[size];
  if (uiFont) {
    return uiFont;
  }
  uiFont = (__bridge_transfer UIFont *)CTFontCreateWithGraphicsFont(_cgFont, fsize, NULL, NULL);
  _sizes[size] = uiFont;
  return uiFont;
}

- (void) dealloc
{
  CGFontRelease(_cgFont);
}

@end


@implementation RCTConvert (EXFontLoader)

// Will swap this with UIFont:withFamily:size:weight:style:scaleMultiplier:

+ (UIFont *)EXFont:(UIFont *)font withFamily:(id)family
                    size:(id)size weight:(id)weight style:(id)style
         scaleMultiplier:(CGFloat)scaleMultiplier
{
  if ([family hasPrefix:@"ExponentFont-"] && EXFonts) {
    NSString *suffix = [family substringFromIndex:[@"ExponentFont-" length]];
    if (EXFonts[suffix]) {
      return [EXFonts[suffix] UIFontWithSize:[self CGFloat:size] ?: 14];
    }
  }
  return [self EXFont:font withFamily:family size:size weight:weight style:style scaleMultiplier:scaleMultiplier];
}

@end


@implementation EXFontLoader

RCT_EXPORT_MODULE(ExponentFontLoader);

+ (void)initialize {
  SEL a = @selector(EXFont:withFamily:size:weight:style:scaleMultiplier:);
  SEL b = @selector(UIFont:withFamily:size:weight:style:scaleMultiplier:);
  method_exchangeImplementations(class_getClassMethod([RCTConvert class], a),
                                 class_getClassMethod([RCTConvert class], b));
}

RCT_REMAP_METHOD(loadAsync,
                 loadAsyncWithFontFamilyName:(NSString *)fontFamilyName
                 withLocalUri:(NSURL *)uri
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (EXFonts && EXFonts[fontFamilyName]) {
    reject(@"E_FONT_ALREADY_EXISTS",
           [NSString stringWithFormat:@"Font with family name '%@' already loaded", fontFamilyName],
           nil);
    return;
  }

  // TODO(nikki): make sure path is in experience's scope
  NSString *path = [uri path];
  NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
  if (!data) {
      reject(@"E_FONT_FILE_NOT_FOUND",
             [NSString stringWithFormat:@"File '%@' for font '%@' doesn't exist", path, fontFamilyName],
             nil);
      return;
  }

  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  CGFontRef font = CGFontCreateWithDataProvider(provider);
  CGDataProviderRelease(provider);
  if (!font) {
    reject(@"E_FONT_CREATION_FAILED",
           [NSString stringWithFormat:@"Could not create font from loaded data for '%@'", fontFamilyName],
           nil);
    return;
  }

  if (!EXFonts) {
    EXFonts = [NSMutableDictionary dictionary];
  }
  EXFonts[fontFamilyName] = [[EXFont alloc] initWithCGFont:font];
  resolve(nil);
}

- (dispatch_queue_t)methodQueue
{
  static dispatch_queue_t queue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    queue = dispatch_queue_create("host.exp.Exponent.FontLoader", DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

@end
