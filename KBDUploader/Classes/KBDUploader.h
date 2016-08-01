//
//  KBDUploader.h
//  KBDUploader
//
//  Created by KeyBoardDog on 07/29/2016.
//  Copyright (c) 2016 ywang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KBUploaderOperation.h"
#import "KBUploaderHelper.h"

#if OS_OBJECT_USE_OBJC
#undef KBDispatchQueueRelease
#undef KBDispatchQueueSetterSementics
#define KBDispatchQueueRelease(q)
#define KBDispatchQueueSetterSementics strong
#else
#undef KBDispatchQueueRelease
#undef KBDispatchQueueSetterSementics
#define KBDispatchQueueRelease(q) (dispatch_release(q))
#define KBDispatchQueueSetterSementics assign
#endif

@interface KBDUploader : NSObject
@property (assign, nonatomic) NSInteger maxConcurrentUploads;
/**
 * Shows the current amount of uploads that still need to be uploaded
 */
@property (readonly, nonatomic) NSUInteger currentUploadCount;


/**
 *  The timeout value (in seconds) for the upload operation. Default: 30.0.
 */
@property (assign, nonatomic) NSTimeInterval uploadTimeout;


/**
 *  Singleton method, returns the shared instance
 *
 *  @return global shared instance of downloader class
 */
+(KBDUploader *) sharedUploader;



/**
 * Creates a ZSUploader async uploader instance with a given URL
 *
 * The delegate will be informed when the image is finish uploaded or an error has happen.
 *
 * @see SDWebImageDownloaderDelegate
 *
 * @param url            The URL to the image to uploaded
 * @param progressBlock  A block called repeatedly while the image is uploading
 * @param completedBlock A block called once the download is completed.
 *
 * @return A cancellable ZSUploaderOperation
 */
- (id <KBUploaderProtocol>)uploadIUrl:(NSURL *)url
                              data:(NSData *)data
                              type:(KBUploaderContentType)type
                          progress:(KBUploaderProgressBlock)progressBlock
                         completed:(KBUploaderOutCompletedBlock)completedBlock
                         cancelled:(KBUploaderCancelBlock) cancelBlock;


/**
 * Sets a subclass of `ZSUploaderOperation` as the default
 * `NSOperation` to be used each time ZSUpload constructs a request
 * operation to upload an image.
 *
 * @param operationClass The subclass of `KBUploaderOperation` to set
 *        as default. Passing `nil` will revert to `KBUploaderOperation`.
 */
- (void)setOperationClass:(Class)operationClass;


/**
 * Sets the upload queue suspension state
 */
- (void)setSuspended:(BOOL)suspended;

/**
 * Cancels all upload operations in the queue
 */
- (void)cancelAllDownloads;



@end
