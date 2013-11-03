//
//  cacheManager.m
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

#import "cacheManager.h"

@implementation cacheManager

static cacheManager * g_cacheManagerInstance = NULL;

+ (cacheManager *)instance
{
    if(g_cacheManagerInstance == NULL)
    {
        g_cacheManagerInstance = [[self alloc]init];
    }
    return g_cacheManagerInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        workingDirectory = nil;
        wDLoaded = NO;
    }
    
    return self;
}

- (void) loadFromDirectory
{
    // Initialization code here.
    
    NSString * cdbPath = [workingDirectory stringByAppendingPathComponent:@"cache.sqlite"];
    
    NSURL *storeUrl = [NSURL fileURLWithPath:cdbPath];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"dataCache" ofType:@"momd"];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
    NSPersistentStoreCoordinator * persC = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    
    NSError *error = nil;
    NSMutableDictionary *optionDic = [[NSMutableDictionary alloc]init];
    if (![persC addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:optionDic error:&error])
    {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        return;
    }
    
    cacheManagedObjectCon = [[NSManagedObjectContext alloc] init];
    [cacheManagedObjectCon setPersistentStoreCoordinator:persC];
    
    // loading success
    wDLoaded = YES;
}

#pragma mark private API

- (int) getCategoryExpireInterval: (NSString *)category
{
    NSString * predictStr = [NSString stringWithFormat:@"category = %@",category];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CategoryMapping" inManagedObjectContext:cacheManagedObjectCon]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predictStr];
    [fetchRequest setPredicate:predicate];
    
    NSError * error = nil;
    NSArray *fetchedItems = [cacheManagedObjectCon executeFetchRequest:fetchRequest error:&error];
    
    NSTimeInterval resultInt = YEAR_INTERVAL;
    
    if (error == nil) {
        if ([fetchedItems count] > 0) {
            CategoryMapping * resultMapping = [fetchedItems objectAtIndex:0];
            resultInt = resultMapping.expire.integerValue;
        }
    }
    
    return resultInt;
}

- (int) getCategoryId: (NSString *)category expireby:(NSTimeInterval *)expire
{
    // first see if it already exist
    
    NSString * predictStr = [NSString stringWithFormat:@"category like [cd] '%@'",category];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CategoryMapping" inManagedObjectContext:cacheManagedObjectCon]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predictStr];
    [fetchRequest setPredicate:predicate];
    
    NSError * error = nil;
    NSArray *fetchedItems = [cacheManagedObjectCon executeFetchRequest:fetchRequest error:&error];
    
    int resultId = -1;
    if (expire != nil) {
        *expire = YEAR_INTERVAL;
    }
    
    if (error == nil) {
        if ([fetchedItems count] > 0) {
            CategoryMapping * resultMapping = [fetchedItems objectAtIndex:0];
            resultId = resultMapping.cid.integerValue;
            if (expire != nil) {
                *expire = resultMapping.expire.doubleValue;
            }
        }
        else
        {
            // if not get a new one and insert
            int nextid = [self getNextCategoryId];
            CategoryMapping * newMapping =  [NSEntityDescription insertNewObjectForEntityForName:@"CategoryMapping" inManagedObjectContext:cacheManagedObjectCon];
            newMapping.category = category;
            newMapping.cid = [NSNumber numberWithInt:nextid];
            newMapping.expire = [NSNumber numberWithInt:YEAR_INTERVAL];
            [cacheManagedObjectCon insertObject:newMapping];
            [self save];
            resultId = nextid;
        }
    }
    
    return resultId;
}

- (int) getNextCategoryId
{
    NSDate *nDate = [NSDate date];
    int testid = [nDate timeIntervalSince1970];
    BOOL idConflicted = YES;
    
    while (idConflicted) {
        NSString * predictStr = [NSString stringWithFormat:@"cid = %d",testid];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"CategoryMapping" inManagedObjectContext:cacheManagedObjectCon]];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:predictStr];
        [fetchRequest setPredicate:predicate];
        
        NSError * error = nil;
        NSArray *fetchedItems = [cacheManagedObjectCon executeFetchRequest:fetchRequest error:&error];
        
        // it's fine to have error here
        if ([fetchedItems count] > 0) {
            testid = testid +1;
        }
        else
        {
            idConflicted = NO;
        }
    }
    
    return testid;
}

- (BOOL) stateCheck:(NSString *)category byTargetId:(NSNumber *)tid forObject:(NSObject*)dataObj onError:(void (^)(NSError * err)) errorBlock
{
    BOOL pass = NO;
    
    if (!wDLoaded) {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"cache Manager has not set working folder or fail to load from working folder" forKey:NSLocalizedDescriptionKey];
        NSError * error = [NSError errorWithDomain:@"cacheManager" code:CM_ERROR_WRONG_WORKING_DIRECTORY userInfo:details];
        errorBlock(error);
    }
    else if (![category isKindOfClass:[NSString class]] || [category length] == 0 ) {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"the category must be string and not empty" forKey:NSLocalizedDescriptionKey];
        NSError * error = [NSError errorWithDomain:@"cacheManager" code:CM_ERROR_CATEGORY userInfo:details];
        errorBlock(error);
    }
    else if (![tid isKindOfClass:[NSNumber class]]) {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"the target id must be number" forKey:NSLocalizedDescriptionKey];
        NSError * error = [NSError errorWithDomain:@"cacheManager" code:CM_ERROR_TARGET_ID userInfo:details];
        errorBlock(error);
    }
    else if (![dataObj conformsToProtocol:@protocol(NSCoding)]) {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"the cache data must confirm to protocol NSCoding" forKey:NSLocalizedDescriptionKey];
        NSError * error = [NSError errorWithDomain:@"cacheManager" code:CM_ERROR_CACHE_INFO userInfo:details];
        errorBlock(error);
    }
    else
    {
        pass = YES;
    }
    
    return pass;
}

- (CacheItem *) getCacheItemByCategory: (int) cateid ofTarget:(NSNumber *)tid
{
    NSString * predictStr = [NSString stringWithFormat:@"category = %d and tid = %@",cateid, tid];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CacheItem" inManagedObjectContext:cacheManagedObjectCon]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predictStr];
    [fetchRequest setPredicate:predicate];
    
    NSError * error = nil;
    CacheItem * targetItem = nil;
    NSArray *fetchedItems = [cacheManagedObjectCon executeFetchRequest:fetchRequest error:&error];
    
    if (error == nil && [fetchedItems count]>0) {
        targetItem = [fetchedItems objectAtIndex:0];
    }
    
    return  targetItem;
}

- (void) save
{
    [cacheManagedObjectCon processPendingChanges];
    NSError *error;
    [cacheManagedObjectCon save:&error];
}

#pragma mark public API

- (void) setWorkingDirectory: (NSString *) directory
{
    if (directory == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        workingDirectory = [paths objectAtIndex:0];
    }
    else
    {
        BOOL isDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:directory isDirectory:&isDirectory] && isDirectory) {
            workingDirectory = directory;
        }
        else
        {
            NSLog(@"error - setting wrong working directory");
        }
    }
    
    if (workingDirectory != nil) {
        [self loadFromDirectory];
    }
}

- (void) setCacheExpireTimeInterval:(NSTimeInterval)expire forCategory:(NSString *)category
{
    NSString * predictStr = [NSString stringWithFormat:@"category like [cd] '%@'",category];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CategoryMapping" inManagedObjectContext:cacheManagedObjectCon]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predictStr];
    [fetchRequest setPredicate:predicate];
    
    NSError * error = nil;
    NSArray *fetchedItems = [cacheManagedObjectCon executeFetchRequest:fetchRequest error:&error];
    
    if (error == nil && [fetchedItems count]>0) {
        CategoryMapping * targetCategoryMapping = [fetchedItems objectAtIndex:0];;
        if (targetCategoryMapping != nil) {
            targetCategoryMapping.expire = [NSNumber numberWithDouble:expire];
            [cacheManagedObjectCon refreshObject:targetCategoryMapping mergeChanges:YES];
            [self save];
        }
    }
}

- (void) addDataCacheForCategory:(NSString *)category byTargetId:(NSNumber *)tid forObject:(NSObject*)dataObj onCompletion:(void (^)(int result))completionBlock onError:(void (^)(NSError * err)) errorBlock
{
    if (![self stateCheck:category byTargetId:tid forObject:dataObj onError:errorBlock]) {
        return;
    }
    
    NSTimeInterval cateExpire = YEAR_INTERVAL;
    int cateId = [self getCategoryId:category expireby:&cateExpire];
    
    CacheItem * existingItem = [self getCacheItemByCategory:cateId ofTarget:tid];
    if (existingItem != nil) {
        // add is not supposed to do update
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"the target item already exists" forKey:NSLocalizedDescriptionKey];
        NSError * error = [NSError errorWithDomain:@"cacheManager" code:CM_ERROR_ITEM_EXISTS userInfo:details];
        errorBlock(error);
    }
    else {
        CacheItem * newItem = [NSEntityDescription insertNewObjectForEntityForName:@"CacheItem" inManagedObjectContext:cacheManagedObjectCon];
        newItem.category = [NSNumber numberWithInt:cateId];
        newItem.tid = tid;
        newItem.objdata = [NSKeyedArchiver archivedDataWithRootObject:dataObj];
        newItem.lastupdate = [NSDate date];
        [cacheManagedObjectCon insertObject:newItem];
        [self save];
        completionBlock(CM_SUCCESS);
    }
}

- (void) updateDataCacheForCategory:(NSString *)category byTargetId:(NSNumber *)tid forObject:(NSObject*)dataObj forceAdd:(BOOL)fAdd onCompletion:(void (^)(int result))completionBlock onError:(void (^)(NSError * err)) errorBlock
{
    if (![self stateCheck:category byTargetId:tid forObject:dataObj onError:errorBlock]) {
        return;
    }
    
    NSTimeInterval cateExpire = YEAR_INTERVAL;
    int cateId = [self getCategoryId:category expireby:&cateExpire];
    
    CacheItem * existingItem = [self getCacheItemByCategory:cateId ofTarget:tid];
    if (existingItem != nil) {
        existingItem.objdata = [NSKeyedArchiver archivedDataWithRootObject:dataObj];
        existingItem.lastupdate = [NSDate date];
        [cacheManagedObjectCon refreshObject:existingItem mergeChanges:YES];
        [self save];
        completionBlock(CM_SUCCESS);
    }
    else{
        if (fAdd) {
            [self addDataCacheForCategory:category byTargetId:tid forObject:dataObj onCompletion:completionBlock onError:errorBlock];
        }
        else
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"the update item not exist" forKey:NSLocalizedDescriptionKey];
            NSError * error = [NSError errorWithDomain:@"cacheManager" code:CM_ERROR_ITEM_NOT_EXIST userInfo:details];
            errorBlock(error);
        }
        
    }
}

- (void) deleteDataCacheForCategory:(NSString *)category byTargetId:(NSNumber *)tid onCompletion:(void (^)(int result))completionBlock onError:(void (^)(NSError * err)) errorBlock
{
    if (![self stateCheck:category byTargetId:tid forObject:@"" onError:errorBlock]) {
        return;
    }
    
    NSTimeInterval cateExpire = YEAR_INTERVAL;
    int cateId = [self getCategoryId:category expireby:&cateExpire];
    
    CacheItem * existingItem = [self getCacheItemByCategory:cateId ofTarget:tid];
    if (existingItem != nil) {
        [cacheManagedObjectCon deleteObject:existingItem];
        [self save];
        completionBlock(CM_SUCCESS);
    }
    else{
        // update is not supposed to do add
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"the update item not exist" forKey:NSLocalizedDescriptionKey];
        NSError * error = [NSError errorWithDomain:@"cacheManager" code:CM_ERROR_ITEM_NOT_EXIST userInfo:details];
        errorBlock(error);
    }
}

- (void) getItemForCategory:(NSString *)category byTargetId:(NSNumber *)tid onCompletion:(void (^)(NSObject * obj))completionBlock onError:(void (^)(NSError * err)) errorBlock
{
    if (![self stateCheck:category byTargetId:tid forObject:@"" onError:errorBlock]) {
        return;
    }
    
    NSTimeInterval cateExpire = YEAR_INTERVAL;
    int cateId = [self getCategoryId:category expireby:&cateExpire];
    
    CacheItem * existingItem = [self getCacheItemByCategory:cateId ofTarget:tid];
    if (existingItem != nil) {
        NSTimeInterval deltaInterval = [[NSDate date] timeIntervalSince1970] - [existingItem.lastupdate timeIntervalSince1970];
        if (deltaInterval > cateExpire) {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"the target item expired" forKey:NSLocalizedDescriptionKey];
            NSError * error = [NSError errorWithDomain:@"cacheManager" code:CM_ERROR_ITEM_EXPIRED userInfo:details];
            errorBlock(error);
        }
        else{
            NSObject * oriDataObj = [NSKeyedUnarchiver unarchiveObjectWithData:existingItem.objdata];
            completionBlock(oriDataObj);
        }
    }
    else{
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"the target item not exist" forKey:NSLocalizedDescriptionKey];
        NSError * error = [NSError errorWithDomain:@"cacheManager" code:CM_ERROR_ITEM_NOT_EXIST userInfo:details];
        errorBlock(error);
    }
}

/*
- (void) dump
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CategoryMapping" inManagedObjectContext:cacheManagedObjectCon]];
    
    NSError * error = nil;
    NSArray *fetchedItems = [cacheManagedObjectCon executeFetchRequest:fetchRequest error:&error];
    
    for (int i=0; i<[fetchedItems count]; i++) {
        NSLog(@"%@", [fetchedItems objectAtIndex:i]);
    }
    
    fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CacheItem" inManagedObjectContext:cacheManagedObjectCon]];
    
    fetchedItems = [cacheManagedObjectCon executeFetchRequest:fetchRequest error:&error];
    
    for (int i=0; i<[fetchedItems count]; i++) {
        NSLog(@"%@", [fetchedItems objectAtIndex:i]);
    }
}
 */

@end
