//
//  KBDUploaderOperation.h
//  KBDUploader
//
//  Created by KeyBoardDog on 07/29/2016.
//  Copyright (c) 2016 ywang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "KBUploaderProtocol.h"
#import "KBUploaderHelper.h"


typedef void(^KBUploaderCompletedBlock)(NSString *taskId, BOOL finished,NSData *respObj, NSError *error);
typedef void(^KBUploaderOutCompletedBlock)(NSString *taskId, BOOL finished, NSData *respObj, KBUploaderContentType type, NSError *error);
typedef void(^KBUploaderCancelBlock)(NSString *taskId);
typedef void(^KBNoParamsBlock)();
typedef void(^KBUploaderProgressBlock)(NSString *taskId, CGFloat progress);


@interface KBUploaderOperation : NSOperation<KBUploaderProtocol, NSURLSessionTaskDelegate,NSURLSessionDataDelegate>



/**
 * The request used by the operation's task.
 */
@property (strong, nonatomic, readonly) NSURLRequest *request;

/**
 * The operation's task
 */
@property (strong, nonatomic, readonly) NSURLSessionTask *dataTask;

/**
 * The response returned by the operation's connection.
 */
@property (strong, nonatomic) NSURLResponse *response;

/**
 *  Initializes a `ZSUploaderOperation` object
 *
 *  @see SDWebImageDownloaderOperation
 *
 *  @param request        the URL request
 *  @param session        the URL session in which this operation will run
 *  @param progressBlock  the block executed when a new chunk of data arrives.
 *                        @note the progress block is executed on a background queue
 *  @param completedBlock the block executed when the download is done.
 *                        @note the completed block is executed on the main queue for success. If errors are found, there is a chance the block will be executed on a background queue
 *  @param cancelBlock    the block executed if the download (operation) is cancelled
 *
 *  @return the initialized instance
 */
- (id)initWithRequest:(NSURLRequest *)request
         operationKey:(NSString *)operationKey
             formFile:(NSURL *)fileURL
            inSession:(NSURLSession *)session
             progress:(KBUploaderProgressBlock)progressBlock
            completed:(KBUploaderCompletedBlock)completedBlock
            cancelled:(KBUploaderCancelBlock)cancelBlock;

- (id)initWithRequest:(NSURLRequest *)request
         operationKey:(NSString *)operationKey
             formData:(NSData *)data
            inSession:(NSURLSession *)session
             progress:(KBUploaderProgressBlock)progressBlock
            completed:(KBUploaderCompletedBlock)completedBlock
            cancelled:(KBUploaderCancelBlock)cancelBlock;




@end
