//
//  KBDUploader.m
//  KBDUploader
//
//  Created by KeyBoardDog on 07/29/2016.
//  Copyright (c) 2016 ywang. All rights reserved.
//

#import "KBDUploader.h"
#import "KBUploaderOperation.h"
#import "KBUploaderHelper.h"
#import "KBError.h"

static NSString *const kUserAgentKey = @"User-Agent";
static NSString *const kContentTypeKey = @"Content-Type";
static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kCompletedCallbackKey = @"completed";
static NSString *const kCancelCallbackKey = @"cancel";

@interface KBDUploader() <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>


@property (strong, nonatomic) NSOperationQueue *uploadQueue;
@property (weak, nonatomic) NSOperation *lastAddedOperation;
@property (assign, nonatomic) Class operationClass;
@property (strong, nonatomic) NSMutableDictionary *URLCallbacks;

// This queue is used to serialize the handling of the network responses of all the download operation in a single queue
@property (KBDispatchQueueSetterSementics, nonatomic) dispatch_queue_t barrierQueue;

// The session in which data tasks will run
@property (strong, nonatomic) NSURLSession *session;

@end

@implementation KBDUploader
+ (KBDUploader *)sharedUploader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}


- (id)init {
    if ((self = [super init])) {
        _operationClass = [KBUploaderOperation class];
        _uploadQueue = [NSOperationQueue new];
        _uploadQueue.maxConcurrentOperationCount = 6;
        
        _barrierQueue = dispatch_queue_create("com.onecat.KBUploaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        _uploadTimeout = 45.0;
        _URLCallbacks = [NSMutableDictionary new];
        
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfig.timeoutIntervalForRequest = _uploadTimeout;
        
        /**
         *  Create the session for this task
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
         *  method calls and completion handler calls.
         */
        self.session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                     delegate:self
                                                delegateQueue:nil];
    }
    return self;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
    self.session = nil;
    
    [self.uploadQueue cancelAllOperations];
    KBDispatchQueueRelease(_barrierQueue);
}


- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads {
    _uploadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}

- (NSUInteger)currentDownloadCount {
    return _uploadQueue.operationCount;
}

- (NSInteger)maxConcurrentDownloads {
    return _uploadQueue.maxConcurrentOperationCount;
}

- (void)setOperationClass:(Class)operationClass {
    _operationClass = operationClass ?: [KBUploaderOperation class];
}


- (id <KBUploaderProtocol>)uploadIUrl:(NSURL *)url
                                 data:(NSData *)data
                                 type:(KBUploaderContentType)type
                             progress:(KBUploaderProgressBlock)progressBlock
                            completed:(KBUploaderOutCompletedBlock)completedBlock
                            cancelled:(KBUploaderCancelBlock) cancelBlock {
    
    
    __block KBUploaderOperation *operation;
    __weak __typeof(self)wself = self;
    
    NSString *operationKey = [KBUploaderHelper data2md5String:data];
    
    /** 先缓存progress、completed block,然后创建operation */
    [self addProgressCallback:progressBlock completedBlock:completedBlock
                  cancelBlock:cancelBlock
                       forKey:operationKey createCallback:^{
                           NSTimeInterval timeoutInterval = wself.uploadTimeout;
                           if (timeoutInterval == 0.0) {
                               timeoutInterval = 45.0;
                           }
                           
                           NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:timeoutInterval];
                           request.HTTPShouldUsePipelining = YES;
                           [request setValue:[KBUploaderHelper userAgent] forHTTPHeaderField:kUserAgentKey];
                           [request setValue:[KBUploaderHelper contentType] forHTTPHeaderField:kContentTypeKey];
                           request.HTTPMethod = @"POST";
                           
                           operation = [[KBUploaderOperation alloc] initWithRequest:request operationKey:operationKey formData:[KBUploaderHelper constructRequestBody:data contentType:type] inSession:self.session progress:^(NSString *operationKey, CGFloat progress){
                               KBDUploader *sself = wself;
                               if (!sself) return;
                               __block NSArray *callbacksForURL;
                               dispatch_sync(sself.barrierQueue, ^{
                                   callbacksForURL = [sself.URLCallbacks[operationKey] copy];
                               });
                               for (NSDictionary *callbacks in callbacksForURL) {
                                   KBUploaderProgressBlock callback = callbacks[kProgressCallbackKey];
                                   if (callback) callback(operationKey,progress);
                               }
                           } completed:^(NSString *operationKey, BOOL finished, NSData *respObj, NSError *error){
                               
                               KBDUploader *sself = wself;
                               if (!sself) return;
                               __block NSArray *callbacksForTaskId;
                               dispatch_barrier_sync(sself.barrierQueue, ^{
                                   
                                   callbacksForTaskId = [sself.URLCallbacks[operationKey] copy];
                                   if (finished) {
                                       [sself.URLCallbacks removeObjectForKey:operationKey];
                                   }
                               });
                               for (NSDictionary *callbacks in callbacksForTaskId) {
                                   KBUploaderOutCompletedBlock callback = callbacks[kCompletedCallbackKey];
                                   if (callback) callback(operationKey, YES, respObj,type, error);
                               }
                           } cancelled:^(NSString *operationKey){
                               KBDUploader *sself = wself;
                               if (!sself) return;
                               __block NSArray *callbacksForTaskId;
                               dispatch_barrier_sync(sself.barrierQueue, ^{
                                   callbacksForTaskId = [sself.URLCallbacks[operationKey] copy];
                                   
                                   [sself.URLCallbacks removeObjectForKey:operationKey];
                                   
                               });
                               for (NSDictionary *callbacks in callbacksForTaskId) {
                                   KBUploaderCancelBlock callback = callbacks[kCancelCallbackKey];
                                   if (callback) callback(operationKey);
                               }
                               
                           }];
                           
                           [wself.uploadQueue addOperation:operation];
                           //        [wself.lastAddedOperation addDependency:operation];
                           //        wself.lastAddedOperation = operation;
                       }];
    return operation;
}

- (void)addProgressCallback:(KBUploaderProgressBlock)progressBlock completedBlock:(KBUploaderOutCompletedBlock)completedBlock cancelBlock:(KBUploaderCancelBlock)cancelBlock forKey:(NSString *)taskId createCallback:(KBNoParamsBlock)createCallback {
    // The taskId will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no image or data.
    if (taskId == nil) {
        if (completedBlock != nil) {
            completedBlock(taskId, NO, nil, -1 ,[KBError errorCode:KBErrorCodeUnknow userInfo:nil]);
        }
        return;
    }
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        
        BOOL first = NO;
        
        if (!self.URLCallbacks[taskId]) {
            self.URLCallbacks[taskId] = [NSMutableArray new];
            first = YES;
        }
        
        // Handle single upload of simultaneous upload request for the same taskId
        NSMutableArray *callbacksForURL = self.URLCallbacks[taskId];
        NSMutableDictionary *callbacks = [NSMutableDictionary new];
        if (progressBlock) callbacks[kProgressCallbackKey] = [progressBlock copy];
        if (completedBlock) callbacks[kCompletedCallbackKey] = [completedBlock copy];
        if (cancelBlock) callbacks[kCancelCallbackKey] = [cancelBlock copy];
        
        [callbacksForURL addObject:callbacks];
        self.URLCallbacks[taskId] = callbacksForURL;
        
        if (first) {
            createCallback();
        }
    });
}



- (void)setSuspended:(BOOL)suspended {
    [self.uploadQueue setSuspended:suspended];
}

- (void)cancelAllDownloads {
    [self.uploadQueue cancelAllOperations];
}

#pragma mark Helper methods

- (KBUploaderOperation *)operationWithTask:(NSURLSessionTask *)task {
    KBUploaderOperation *returnOperation = nil;
    for (KBUploaderOperation *operation in self.uploadQueue.operations) {
        if (operation.dataTask.taskIdentifier == task.taskIdentifier) {
            returnOperation = operation;
            break;
        }
    }
    return returnOperation;
}

#pragma mark NSURLSessionDataDelegate

/* Sent periodically to notify the delegate of upload progress.  This
 * information is also available as properties of the task.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    
    KBUploaderOperation *uploadOperation = [self operationWithTask:task];
    [uploadOperation URLSession:session task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend ];
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
    KBUploaderOperation *uploadOperation = [self operationWithTask:task];
    [uploadOperation URLSession:session task:task didCompleteWithError:error];
    
}

@end
