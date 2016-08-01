//
//  KBUploaderOperation.m
//  KBDUploader
//
//  Created by KeyBoardDog on 07/29/2016.
//  Copyright (c) 2016 ywang. All rights reserved.
//

#import "KBUploaderOperation.h"

@interface KBUploaderOperation ()

@property (copy, nonatomic) KBUploaderProgressBlock progressBlock;
@property (copy, nonatomic) KBUploaderCompletedBlock completedBlock;
@property (copy, nonatomic) KBUploaderCancelBlock cancelBlock;
@property (strong, nonatomic) NSURL *fileURL;
@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) NSString *operationKey;

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
// This is weak because it is injected by whoever manages this session. If this gets nil-ed out, we won't be able to run
// the task associated with this operation
@property (weak, nonatomic) NSURLSession *unownedSession;
// This is set if we're using not using an injected NSURLSession. We're responsible of invalidating this one
@property (strong, nonatomic) NSURLSession *ownedSession;

@property (strong, nonatomic, readwrite) NSURLSessionTask *dataTask;

@property (strong, atomic) NSThread *thread;

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@end


@implementation KBUploaderOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

- (id)initWithRequest:(NSURLRequest *)request
         operationKey:(NSString *)operationKey
             formFile:(NSURL *)fileURL
            inSession:(NSURLSession *)session
             progress:(KBUploaderProgressBlock)progressBlock
            completed:(KBUploaderCompletedBlock)completedBlock
            cancelled:(KBUploaderCancelBlock)cancelBlock {
    
    return [self initWithRequest:request
                    operationKey:operationKey
                        fromFile:fileURL
                        fromData:nil
                       inSession:session
                        progress:progressBlock
                       completed:completedBlock
                       cancelled:cancelBlock];
    
}

- (id)initWithRequest:(NSURLRequest *)request
         operationKey:(NSString *)operationKey
             formData:(NSData *)data
            inSession:(NSURLSession *)session
             progress:(KBUploaderProgressBlock)progressBlock
            completed:(KBUploaderCompletedBlock)completedBlock
            cancelled:(KBUploaderCancelBlock)cancelBlock {
    
    return [self initWithRequest:request
                    operationKey:operationKey
                        fromFile:nil
                        fromData:data
                       inSession:session
                        progress:progressBlock
                       completed:completedBlock
                       cancelled:cancelBlock];
}

- (id)initWithRequest:(NSURLRequest *)request
         operationKey:(NSString *)operationKey
             fromFile:(NSURL *)fileURL
             fromData:(NSData *)data
            inSession:(NSURLSession *)session
             progress:(KBUploaderProgressBlock)progressBlock
            completed:(KBUploaderCompletedBlock)completedBlock
            cancelled:(KBUploaderCancelBlock)cancelBlock {
    if ((self = [super init])) {
        _request = request;
        _progressBlock = [progressBlock copy];
        _completedBlock = [completedBlock copy];
        _cancelBlock = [cancelBlock copy];
        _operationKey = operationKey;
        _fileURL = fileURL;
        _data = data;
        _unownedSession = session;
        _executing = NO;
        _finished = NO;
    }
    return self;
}

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }
        
#if TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
        if (hasApplication) {
            __weak __typeof__ (self) wself = self;
            UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong __typeof (wself) sself = wself;
                
                if (sself) {
                    [sself cancel];
                    
                    [app endBackgroundTask:sself.backgroundTaskId];
                    sself.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
        }
#endif
        NSURLSession *session = self.unownedSession;
        if (!self.unownedSession) {
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 15;
            
            /**
             *  Create the session for this task
             *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
             *  method calls and completion handler calls.
             */
            self.ownedSession = [NSURLSession sessionWithConfiguration:sessionConfig
                                                              delegate:self
                                                         delegateQueue:nil];
            session = self.ownedSession;
        }
        
        __weak __typeof__ (self) wself = self;
        if (self.fileURL) {
            self.dataTask = [session uploadTaskWithRequest:self.request fromFile:self.fileURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                wself.completedBlock(wself.operationKey, YES, data, nil);
                
                [wself done];
            }];
        } else if (self.data) {
            self.dataTask = [session uploadTaskWithRequest:self.request fromData:self.data completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                wself.completedBlock(wself.operationKey, YES, data, nil);
                [wself done];
            }];
        }
        self.executing = YES;
        self.thread = [NSThread currentThread];
    }
    
    [self.dataTask resume];
    
    
#if TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
#endif
}

- (void)cancel {
    @synchronized (self) {
        if (self.thread) {
            [self performSelector:@selector(cancelInternalAndStop) onThread:self.thread withObject:nil waitUntilDone:NO];
        }
        else {
            [self cancelInternal];
        }
    }
}

- (void)cancelInternalAndStop {
    if (self.isFinished) return;
    [self cancelInternal];
}

- (void)cancelInternal {
    if (self.isFinished) return;
    [super cancel];
    if (self.cancelBlock) self.cancelBlock(self.operationKey);
    
    if (self.dataTask) {
        [self.dataTask cancel];
        /*
         状态栏提示网络通信....
         dispatch_async(dispatch_get_main_queue(), ^{
         [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStopNotification object:self];
         });
         */
        // As we cancelled the connection, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }
    
    [self reset];
}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)reset {
    self.cancelBlock = nil;
    self.completedBlock = nil;
    self.progressBlock = nil;
    self.dataTask = nil;
    self.thread = nil;
    if (self.ownedSession) {
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

#pragma mark NSURLSessionDataDelegate

/* Sent periodically to notify the delegate of upload progress.  This
 * information is also available as properties of the task.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    
    KBUploaderProgressBlock progressBlock = self.progressBlock;
    if (progressBlock) {
        progressBlock(self.operationKey, totalBytesSent * 1.0 / totalBytesExpectedToSend);
    }
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    self.completedBlock(self.operationKey, NO, nil, nil);
    [self done];
}


@end
