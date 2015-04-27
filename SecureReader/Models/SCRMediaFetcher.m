//
//  SCRMediaFetcher.m
//  SecureReader
//
//  Created by David Chiles on 2/26/15.
//  Copyright (c) 2015 Guardian Project. All rights reserved.
//

#import "SCRMediaFetcher.h"
#import "SCRMediaItem.h"
#import "IOCipher.h"

typedef void (^SCRURLSesssionDataTaskCompletion)(NSURLSessionTask *dataTask, NSError *error);

@interface SCRURLSessionDataTaskInfo : NSObject 

@property (nonatomic, strong) SCRMediaItem *item;
@property (nonatomic, strong) NSString *localPath;
@property (nonatomic, copy) SCRURLSesssionDataTaskCompletion completion;
@property (nonatomic) NSUInteger offset;

@end

@implementation SCRURLSessionDataTaskInfo
@end

@interface SCRMediaFetcher () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSMutableDictionary *dataTaskDictionary;
@property (nonatomic, strong) IOCipher *ioCipher;

@property (nonatomic) dispatch_queue_t isolationQueue;
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation SCRMediaFetcher

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration storage:(IOCipher *)ioCipher
{
    if (self = [self init]) {
        NSString *isolationLabel = [NSString stringWithFormat:@"%@.isolation.%p", [self class], self];
        self.isolationQueue = dispatch_queue_create([isolationLabel UTF8String], 0);
        
        self.dataTaskDictionary = [[NSMutableDictionary alloc] init];
        
        self.ioCipher = ioCipher;
        
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = 1;
        
        self.urlSessionConfiguration = sessionConfiguration;
    }
    return self;
}

- (void)setUrlSessionConfiguration:(NSURLSessionConfiguration *)urlSessionConfiguration
{
    if (![self.urlSession.configuration isEqual:urlSessionConfiguration]) {
        [self invalidate];
        _urlSession = [NSURLSession sessionWithConfiguration:urlSessionConfiguration delegate:self delegateQueue:self.operationQueue];
    }
}

- (NSURLSessionConfiguration *)urlSessionConfiguration
{
    return self.urlSession.configuration;
}

- (void) invalidate {
    [self.urlSession invalidateAndCancel];
    _urlSession = nil;
}

- (dispatch_queue_t)completionQueue
{
    if (!_completionQueue) {
        return dispatch_get_main_queue();
    }
    return _completionQueue;
}


- (void)downloadMediaItem:(SCRMediaItem *)mediaItem completionBlock:(void (^)(NSError *))completion
{
    if (!completion) {
        return;
    }
    
    NSURLSessionDataTask *dataTask = [self.urlSession dataTaskWithURL:mediaItem.url];
    
    [self addDataTask:dataTask forMediaItem:mediaItem completion:^(NSURLSessionTask *task, NSError *error) {
        completion(error);
    }];
    [dataTask resume];
}

- (void)saveMediaItem:(SCRMediaItem *)mediaItem data:(NSData *)data completionBlock:(void (^)(NSError *error))completion
{
    if (!completion) {
        return;
    }
    
    dispatch_async(self.isolationQueue, ^{
        NSError *error = nil;
        [self receivedData:data forPath:mediaItem.localPath atOffset:0 error:&error];
        completion(error);
    });
}

#pragma - mark Private Methods

- (void)receivedData:(NSData *)data forPath:(NSString *)path atOffset:(NSUInteger)offset error:(NSError **)error;
{
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        NSError *err = nil;
        [self.ioCipher writeDataToFileAtPath:path data:[NSData dataWithBytesNoCopy:(void*)bytes length:byteRange.length freeWhenDone:NO] offset:(offset+byteRange.location) error:&err];
        if(err) {
            *stop = YES;
            *error = err;
        }
    }];
}

#pragma - mark dataTaskDictionary Isolatoin Methods
//Taken mostly from http://www.objc.io/issue-2/low-level-concurrency-apis.html


- (void)addDataTask:(NSURLSessionDataTask *)dataTask forMediaItem:(SCRMediaItem *)mediaItem completion:(SCRURLSesssionDataTaskCompletion)completion
{
    __block SCRURLSessionDataTaskInfo *taskInfo = [[SCRURLSessionDataTaskInfo alloc] init];
    taskInfo.item = mediaItem;
    taskInfo.localPath = mediaItem.localPath;
    taskInfo.completion = completion;
    taskInfo.offset = 0;
    
    dispatch_async(self.isolationQueue, ^{
        if (dataTask && [mediaItem.localPath length]) {
            [self.dataTaskDictionary setObject:taskInfo forKey:@(dataTask.taskIdentifier)];
        }
    });
    
    if (_delegate != nil && [_delegate respondsToSelector:@selector(mediaDownloadStarted:)])
    {
        [_delegate mediaDownloadStarted:mediaItem];
    }
}

- (SCRURLSessionDataTaskInfo *)infoForTask:(NSURLSessionTask *)task
{
    __block SCRURLSessionDataTaskInfo *dataInfo = nil;
    dispatch_sync(self.isolationQueue, ^{
        dataInfo = [self.dataTaskDictionary objectForKey:@(task.taskIdentifier)];
    });
    
    return dataInfo;
}

- (void)removeDataTask:(NSURLSessionDataTask *)dataTask
{
    dispatch_async(self.isolationQueue, ^{
        if (dataTask) {
            [self.dataTaskDictionary removeObjectForKey:@(dataTask.taskIdentifier)];
        }
    });
}

#pragma - mark NSURLSessionDataDelegate Methods

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    if([session isEqual:self.urlSession])
    {
        SCRURLSessionDataTaskInfo *info = [self infoForTask:dataTask];
        
        NSError *error = nil;
        [self receivedData:data forPath:info.localPath atOffset:info.offset error:&error];
        if (error) {
            [dataTask cancel];
            if (info.completion) {
                dispatch_async(self.completionQueue, ^{
                    info.completion(dataTask,error);
                });
            }
        }
        info.offset += [data length];
        
        if (_delegate != nil && [_delegate respondsToSelector:@selector(mediaDownloadProgress:downloaded:ofTotal:)])
        {
            [_delegate mediaDownloadProgress:info.item downloaded:info.offset ofTotal:[dataTask countOfBytesExpectedToReceive]];
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if([session isEqual:self.urlSession]) {
        SCRURLSessionDataTaskInfo *info = [self infoForTask:task];
        if (info.completion)
        {
            dispatch_async(self.completionQueue, ^{
                info.completion(task,error);
            });
        }
        if (_delegate != nil && [_delegate respondsToSelector:@selector(mediaDownloadCompleted:withError:)])
        {
            [_delegate mediaDownloadCompleted:info.item withError:error];
        }
    }
}

@end
