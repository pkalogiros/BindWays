//
//  Created by Pantelis Kalogiros on 26/11/15
//

#import <Foundation/Foundation.h>

@interface OneWay : NSObject

+ (void)bind:(__weak NSString *)property of:(__weak id)source to:(__weak NSString *)property of:(__weak id)parent;
+ (void)bind:(__weak NSString *)property of:(__weak id)source to:(__weak id)parent;
+ (void)unbindAll:(__weak id)source;
+ (void)unbindAll:(__weak id)source ofProperty:(NSString *)property;

@end


@interface TwoWay : NSObject

+ (void)bind:(__weak NSString *)property of:(__weak id)source to:(__weak NSString *)property of:(__weak id)parent;
+ (void)bind:(__weak NSString *)property of:(__weak id)source to:(__weak id)parent;
+ (void)unbindAll:(__weak id)source;
+ (void)unbindAll:(__weak id)source ofProperty:(NSString *)property;

@end