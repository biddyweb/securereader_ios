//
//  SRCFeedFetcher.m
//  SecureReader
//
//  Created by Christopher Ballinger on 11/17/14.
//  Copyright (c) 2014 Guardian Project. All rights reserved.
//

#import "SCRFeedFetcher.h"
#import "RSSAtomKit.h"
#import "SCRDatabaseManager.h"
#import "SCRItem.h"
#import "SCRFeed.h"
#import "SCRMediaItem.h"

@interface SCRFeedFetcher()
@property (nonatomic, strong) RSSAtomKit *atomKit;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong) YapDatabaseConnection *databaseConnection;


@end

@implementation SCRFeedFetcher

- (instancetype) init {
    if (self = [super init]) {
        self.callbackQueue = dispatch_queue_create("SCRFeedFetcher callback queue", 0);
    }
    return self;
}

- (instancetype) initWithReadWriteYapConnection:(YapDatabaseConnection *)connection
                           sessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration {
    if (self = [self init]) {
        self.databaseConnection = connection;
        self.atomKit = [[RSSAtomKit alloc] initWithSessionConfiguration:sessionConfiguration];
        [self registerRSSAtomKitClasses];
    }
    return self;
}

- (RSSAtomKit *)atomKit
{
    if (!_atomKit) {
        _atomKit = [[RSSAtomKit alloc] initWithSessionConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        [self registerRSSAtomKitClasses];
    }
    return _atomKit;
}

- (void)registerRSSAtomKitClasses
{
    [self.atomKit.parser registerFeedClass:[SCRFeed class]];
    [self.atomKit.parser registerItemClass:[SCRItem class]];
    [self.atomKit.parser registerMediaItemClass:[SCRMediaItem class]];
}

/**
 *  Fetches RSS feed info and items and inserts it into the database.
 *
 *  @param url rss feed url
 */
- (void) fetchFeedDataFromURL:(NSURL*)url completionQueue:(dispatch_queue_t)completionQueue completion:(void (^)(NSError *))completion {\
    
    if (!completionQueue) {
        completionQueue = dispatch_get_main_queue();
    }
    
    [self.networkOperationQueue addOperationWithBlock:^{
        
        [self.atomKit parseFeedFromURL:url completionBlock:^(RSSFeed *feed, NSArray *items, NSError *error) {
            NSLog(@"Parsed feed %@ with %lu items", feed.title, (unsigned long)items.count);
            if (error) {
                if (completion) {
                    dispatch_async(completionQueue, ^{
                        completion(error);
                    });
                }
                return;
            }
            
            if ([feed isKindOfClass:[SCRFeed class]]) {
                SCRFeed *nativeFeed = (SCRFeed*)feed;
                [self.databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                    ////// Feed Storage //////
                    SCRFeed *existingFeed = [transaction objectForKey:nativeFeed.yapKey inCollection:[[nativeFeed class] yapCollection]];
                    if (existingFeed) {
                        nativeFeed.subscribed = existingFeed.subscribed;
                    }
                    [transaction setObject:nativeFeed forKey:nativeFeed.yapKey inCollection:[[nativeFeed class] yapCollection]];
                    
                    ////// Items Storage //////
                    [items enumerateObjectsUsingBlock:^(RSSItem *item, NSUInteger idx, BOOL *stop) {
                        if ([item isKindOfClass:[SCRItem class]]) {
                            SCRItem *nativeItem = (SCRItem*)item;
                            SCRItem *existingItem = [transaction objectForKey:nativeItem.yapKey inCollection:[[nativeItem class] yapCollection]];
                            if (existingItem) {
                                nativeItem.isFavorite = existingItem.isFavorite;
                                nativeItem.isReceived = existingItem.isReceived;
                            }
                            nativeItem.feedYapKey = nativeFeed.yapKey;
                            
                            ////// Media Items storage //////
                            if ([nativeItem.mediaItems count]) {
                                NSMutableArray *mediaItemKeysArray = [NSMutableArray arrayWithCapacity:[nativeItem.mediaItems count]];
                                for (SCRMediaItem *mediaItem in nativeItem.mediaItems) {
                                    SCRMediaItem *existingMediaItem =[transaction objectForKey:mediaItem.yapKey inCollection:[SCRMediaItem yapCollection]];
                                    if (!existingMediaItem) {
                                        [transaction setObject:mediaItem forKey:mediaItem.yapKey inCollection:[SCRMediaItem yapCollection]];
                                    }
                                    [mediaItemKeysArray addObject:mediaItem.yapKey];
                                }
                                nativeItem.mediaItemsYapKeys = mediaItemKeysArray;
                            }
                            
                            
                            [transaction setObject:nativeItem forKey:nativeItem.yapKey inCollection:[[nativeItem class] yapCollection]];
                        }
                    }];
                } completionBlock:^{
                    if (completion) {
                        dispatch_async(completionQueue, ^{
                            completion(nil);
                        });
                    }
                }];
            }
        } completionQueue:self.callbackQueue];
    }];
    
}

- (void) fetchFeedsFromOPMLURL:(NSURL *)url completionBlock:(void (^)(NSArray *, NSError *))completionBlock completionQueue:(dispatch_queue_t)completionQueue{
    [self.atomKit parseFeedsFromOPMLURL:url completionBlock:completionBlock completionQueue:completionQueue];
}


@end
