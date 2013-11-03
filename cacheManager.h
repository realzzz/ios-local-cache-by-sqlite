//
//  cacheManager.h
//  
// Copyright (c) 2013 Zhang Peng
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>
#import "CategoryMapping.h"
#import "CacheItem.h"

// default cache expire time interval
#define YEAR_INTERVAL  31536000.0


// error code
#define CM_SUCCESS                               0
#define CM_ERROR_WRONG_WORKING_DIRECTORY         1
#define CM_ERROR_CATEGORY                        2
#define CM_ERROR_TARGET_ID                       3
#define CM_ERROR_CACHE_INFO                      4
#define CM_ERROR_ITEM_EXISTS                     5
#define CM_ERROR_ITEM_NOT_EXIST                  6
#define CM_ERROR_ITEM_EXPIRED                    7


@interface cacheManager : NSObject
{
    NSString *               workingDirectory;
    BOOL                     wDLoaded;
    NSTimeInterval           expireInterval;
    NSManagedObjectContext * cacheManagedObjectCon;
}

// init
+ (cacheManager *)instance;
- (void) setWorkingDirectory: (NSString *) directory;
- (void) setCacheExpireTimeInterval:(NSTimeInterval)expire forCategory:(NSString *)category;

// API
- (void) addDataCacheForCategory:(NSString *)category byTargetId:(NSNumber *)tid forObject:(NSObject*)dataObj onCompletion:(void (^)(int result))completionBlock onError:(void (^)(NSError * err)) errorBlock;

- (void) updateDataCacheForCategory:(NSString *)category byTargetId:(NSNumber *)tid forObject:(NSObject*)dataObj forceAdd:(BOOL)fAdd onCompletion:(void (^)(int result))completionBlock onError:(void (^)(NSError * err)) errorBlock;

- (void) deleteDataCacheForCategory:(NSString *)category byTargetId:(NSNumber *)tid onCompletion:(void (^)(int result))completionBlock onError:(void (^)(NSError * err)) errorBlock;

- (void) getItemForCategory:(NSString *)category byTargetId:(NSNumber *)tid onCompletion:(void (^)(NSObject* obj))completionBlock onError:(void (^)(NSError * err)) errorBlock;

// open when you need it
// - (void) dump;


@end
