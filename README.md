ios-local-cache-by-sqlite
=========================

ios local cache by sqlite


WHAT IS THIS?

A local cache module store by sqlite for ios, support to cache the Objects that implements NSCoding protocol, by two level index: Object category (NSString) + Object id (int)


HOW TO USE THIS?

1. init:  Get the static instance and set working directory (use nil for default location in app doucment folder): [[cacheManager instance]setWorkingDirectory:nil];

2. add new cache:
   - (void) addDataCacheForCategory:(NSString *)category byTargetId:(NSNumber *)tid forObject:(NSObject*)dataObj onCompletion:(void (^)(int result))completionBlock onError:(void (^)(NSError * err)) errorBlock;

3. update cache:
  - (void) updateDataCacheForCategory:(NSString *)category byTargetId:(NSNumber *)tid forObject:(NSObject*)dataObj forceAdd:(BOOL)fAdd onCompletion:(void (^)(int result))completionBlock onError:(void (^)(NSError * err)) errorBlock;

4. delete cache:
  - (void) deleteDataCacheForCategory:(NSString *)category byTargetId:(NSNumber *)tid onCompletion:(void (^)(int result))completionBlock onError:(void (^)(NSError * err)) errorBlock;

5. get cache: 
  - (void) getItemForCategory:(NSString *)category byTargetId:(NSNumber *)tid onCompletion:(void (^)(NSObject* obj))completionBlock onError:(void (^)(NSError * err)) errorBlock;




  

  
  
  






