#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>
#import <GLKit/GLKit.h>
#import <CoreMotion/CoreMotion.h>
#import "CameraPreview.h"
#define TMP_IMAGE_PREFIX @"cpcp_capture_"

@implementation CameraPreview
@synthesize x, y, z, orientation, camera_x, camera_y,camera_width, camera_height;

// defaults to 100 msec
#define kAccelerometerInterval 1000
// g constant: -9.81 m/s^2
#define kGravitationalConstant -9.81

-(void) pluginInitialize{
    // start as transparent
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor clearColor];
}

- (void) startCamera:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (!self.motionManager)
    {
        self.motionManager = [[CMMotionManager alloc] init];
    }

    if ([self.motionManager isAccelerometerAvailable] == YES) {
        // Assign the update interval to the motion manager and start updates
        [self.motionManager setAccelerometerUpdateInterval:kAccelerometerInterval/1000];  // expected in seconds
        __weak __typeof__(self) weakSelf = self;
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            weakSelf.x = accelerometerData.acceleration.x;
            weakSelf.y = accelerometerData.acceleration.y;
            weakSelf.z = accelerometerData.acceleration.z;
            [weakSelf calculateDeviceOrientation];
        }];
    }

    if (self.sessionManager != nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera already started!"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    if (command.arguments.count > 3) {

        CGFloat x = (CGFloat)[command.arguments[0] floatValue] + self.webView.frame.origin.x;
        CGFloat y = (CGFloat)[command.arguments[1] floatValue] + self.webView.frame.origin.y;
        CGFloat width = (CGFloat)[command.arguments[2] floatValue];
        CGFloat height = (CGFloat)[command.arguments[3] floatValue];
        NSString *defaultCamera = command.arguments[4];
        BOOL tapToTakePicture = (BOOL)[command.arguments[5] boolValue];
        BOOL dragEnabled = (BOOL)[command.arguments[6] boolValue];
        BOOL toBack = (BOOL)[command.arguments[7] boolValue];
        CGFloat alpha = (CGFloat)[command.arguments[8] floatValue];
        BOOL tapToFocus = (BOOL) [command.arguments[9] boolValue];
        BOOL disableExifHeaderStripping = (BOOL) [command.arguments[10] boolValue]; // ignore Android only
        self.storeToFile = (BOOL) [command.arguments[11] boolValue];

        // Create the session manager
        self.sessionManager = [[CameraSessionManager alloc] init];

        // render controller setup
        self.cameraRenderController = [[CameraRenderController alloc] init];
        self.cameraRenderController.dragEnabled = dragEnabled;
        self.cameraRenderController.tapToTakePicture = tapToTakePicture;
        self.cameraRenderController.tapToFocus = tapToFocus;
        self.cameraRenderController.sessionManager = self.sessionManager;

        self.camera_x = x;
        self.camera_y = y;
        self.camera_width = width;
        self.camera_height = height;

        self.cameraRenderController.view.frame = CGRectMake(x, y, width, height);
        self.cameraRenderController.delegate = self;

        [self.viewController addChildViewController:self.cameraRenderController];

        if (toBack) {
            // display the camera below the webview

            // make transparent
            self.webView.opaque = NO;
            self.webView.backgroundColor = [UIColor clearColor];

            [self.webView.superview addSubview:self.cameraRenderController.view];
            [self.webView.superview bringSubviewToFront:self.webView];
        } else {
            self.cameraRenderController.view.alpha = alpha;
            [self.webView.superview insertSubview:self.cameraRenderController.view aboveSubview:self.webView];
        }

        // start location manager to receive first location
        if (!self.locationManager){
            self.locationManager = [[CLLocationManager alloc] init];
        }

        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;

        // request location (ios8+)
        if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
            NSAssert([[[NSBundle mainBundle] infoDictionary] valueForKey:@"NSLocationWhenInUseUsageDescription"],
                     @"For iOS 8 and above, your app must have a value for NSLocationWhenInUseUsageDescription in its Info.plist");
            [self.locationManager requestWhenInUseAuthorization];
        }

        [self.locationManager startUpdatingLocation];

        // Setup session
        self.sessionManager.delegate = self.cameraRenderController;

        [self.sessionManager setupSession:defaultCamera completion:^(BOOL started) {

            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];

        }];

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid number of parameters"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) stopCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"stopCamera");
    CDVPluginResult *pluginResult;

    [self.locationManager stopUpdatingLocation];

    if(self.sessionManager != nil) {
        [self.cameraRenderController.view removeFromSuperview];
        [self.cameraRenderController removeFromParentViewController];

        self.cameraRenderController = nil;
        self.sessionManager = nil;

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) hideCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"hideCamera");
    CDVPluginResult *pluginResult;

    if (self.cameraRenderController != nil) {
        [self.cameraRenderController.view setHidden:YES];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) showCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"showCamera");
    CDVPluginResult *pluginResult;

    if (self.cameraRenderController != nil) {
        [self.cameraRenderController.view setHidden:NO];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) switchCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"switchCamera");
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        [self.sessionManager switchCamera:^(BOOL switched) {

            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];

        }];

    } else {

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) getSupportedFocusModes:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * focusModes = [self.sessionManager getFocusModes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:focusModes];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getFocusMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSString * focusMode = [self.sessionManager getFocusMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:focusMode];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setFocusMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    NSString * focusMode = [command.arguments objectAtIndex:0];
    if (self.sessionManager != nil) {
        [self.sessionManager setFocusMode:focusMode];
        NSString * focusMode = [self.sessionManager getFocusMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:focusMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedFlashModes:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * flashModes = [self.sessionManager getFlashModes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:flashModes];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getFlashMode:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSInteger flashMode = [self.sessionManager getFlashMode];
        NSString * sFlashMode;
        if (flashMode == 0) {
            sFlashMode = @"off";
        } else if (flashMode == 1) {
            sFlashMode = @"on";
        } else if (flashMode == 2) {
            sFlashMode = @"auto";
        } else {
            sFlashMode = @"unsupported";
        }
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:sFlashMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setFlashMode:(CDVInvokedUrlCommand*)command {
    NSLog(@"Flash Mode");
    NSString *errMsg;
    CDVPluginResult *pluginResult;

    NSString *flashMode = [command.arguments objectAtIndex:0];

    if (self.sessionManager != nil) {
        if ([flashMode isEqual: @"off"]) {
            [self.sessionManager setFlashMode:AVCaptureFlashModeOff];
        } else if ([flashMode isEqual: @"on"]) {
            [self.sessionManager setFlashMode:AVCaptureFlashModeOn];
        } else if ([flashMode isEqual: @"auto"]) {
            [self.sessionManager setFlashMode:AVCaptureFlashModeAuto];
        } else if ([flashMode isEqual: @"torch"]) {
            [self.sessionManager setTorchMode];
        } else {
            errMsg = @"Flash Mode not supported";
        }
    } else {
        errMsg = @"Session not started";
    }

    if (errMsg) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setZoom:(CDVInvokedUrlCommand*)command {
    NSLog(@"Zoom");
    CDVPluginResult *pluginResult;

    CGFloat desiredZoomFactor = [[command.arguments objectAtIndex:0] floatValue];

    if (self.sessionManager != nil) {
        [self.sessionManager setZoom:desiredZoomFactor];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getZoom:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        CGFloat zoom = [self.sessionManager getZoom];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:zoom ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getHorizontalFOV:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        float fov = [self.sessionManager getHorizontalFOV];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:fov ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getMaxZoom:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        CGFloat maxZoom = [self.sessionManager getMaxZoom];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:maxZoom ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureModes:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * exposureModes = [self.sessionManager getExposureModes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:exposureModes];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSString * exposureMode = [self.sessionManager getExposureMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:exposureMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setExposureMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    NSString * exposureMode = [command.arguments objectAtIndex:0];
    if (self.sessionManager != nil) {
        [self.sessionManager setExposureMode:exposureMode];
        NSString * exposureMode = [self.sessionManager getExposureMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:exposureMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedWhiteBalanceModes:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * whiteBalanceModes = [self.sessionManager getSupportedWhiteBalanceModes];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:whiteBalanceModes ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getWhiteBalanceMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSString * whiteBalanceMode = [self.sessionManager getWhiteBalanceMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:whiteBalanceMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setWhiteBalanceMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    NSString * whiteBalanceMode = [command.arguments objectAtIndex:0];
    if (self.sessionManager != nil) {
        [self.sessionManager setWhiteBalanceMode:whiteBalanceMode];
        NSString * wbMode = [self.sessionManager getWhiteBalanceMode];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:wbMode ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureCompensationRange:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        NSArray * exposureRange = [self.sessionManager getExposureCompensationRange];
        NSMutableDictionary *dimensions = [[NSMutableDictionary alloc] init];
        [dimensions setValue:exposureRange[0] forKey:@"min"];
        [dimensions setValue:exposureRange[1] forKey:@"max"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dimensions];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureCompensation:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        CGFloat exposureCompensation = [self.sessionManager getExposureCompensation];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:exposureCompensation ];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setExposureCompensation:(CDVInvokedUrlCommand*)command {
    NSLog(@"Zoom");
    CDVPluginResult *pluginResult;

    CGFloat exposureCompensation = [[command.arguments objectAtIndex:0] floatValue];

    if (self.sessionManager != nil) {
        [self.sessionManager setExposureCompensation:exposureCompensation];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:exposureCompensation];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) takePicture:(CDVInvokedUrlCommand*)command {
    NSLog(@"takePicture");

    CDVPluginResult *pluginResult;

    if (self.cameraRenderController != NULL) {
        self.onPictureTakenHandlerId = command.callbackId;

        CGFloat width = (CGFloat)[command.arguments[0] floatValue];
        CGFloat height = (CGFloat)[command.arguments[1] floatValue];
        CGFloat quality = (CGFloat)[command.arguments[2] floatValue] / 100.0f;

        [self invokeTakePicture:width withHeight:height withQuality:quality];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) takeSnapshot:(CDVInvokedUrlCommand*)command {
    NSLog(@"takeSnapshot");
    CDVPluginResult *pluginResult;
    if (self.cameraRenderController != NULL && self.cameraRenderController.view != NULL) {
        CGFloat quality = (CGFloat)[command.arguments[0] floatValue] / 100.0f;
        dispatch_async(self.sessionManager.sessionQueue, ^{
            UIImage *image = ((GLKView*)self.cameraRenderController.view).snapshot;
            NSString *base64Image = [self getBase64Image:image.CGImage withQuality:quality];
            NSMutableArray *params = [[NSMutableArray alloc] init];
            [params addObject:base64Image];
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:params];
            [pluginResult setKeepCallbackAsBool:true];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        });
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}


-(void) setColorEffect:(CDVInvokedUrlCommand*)command {
    NSLog(@"setColorEffect");
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    NSString *filterName = command.arguments[0];

    if(self.sessionManager != nil){
        if ([filterName isEqual: @"none"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                [self.sessionManager setCiFilter:nil];
            });
        } else if ([filterName isEqual: @"mono"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                CIFilter *filter = [CIFilter filterWithName:@"CIColorMonochrome"];
                [filter setDefaults];
                [self.sessionManager setCiFilter:filter];
            });
        } else if ([filterName isEqual: @"negative"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
                [filter setDefaults];
                [self.sessionManager setCiFilter:filter];
            });
        } else if ([filterName isEqual: @"posterize"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                CIFilter *filter = [CIFilter filterWithName:@"CIColorPosterize"];
                [filter setDefaults];
                [self.sessionManager setCiFilter:filter];
            });
        } else if ([filterName isEqual: @"sepia"]) {
            dispatch_async(self.sessionManager.sessionQueue, ^{
                CIFilter *filter = [CIFilter filterWithName:@"CISepiaTone"];
                [filter setDefaults];
                [self.sessionManager setCiFilter:filter];
            });
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Filter not found"];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setPreviewSize: (CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager == nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    if (command.arguments.count > 1) {
        CGFloat width = (CGFloat)[command.arguments[0] floatValue];
        CGFloat height = (CGFloat)[command.arguments[1] floatValue];

        self.cameraRenderController.view.frame = CGRectMake(0, 0, width, height);

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid number of parameters"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedPictureSizes:(CDVInvokedUrlCommand*)command {
    NSLog(@"getSupportedPictureSizes");
    CDVPluginResult *pluginResult;

    if(self.sessionManager != nil){
        NSArray *formats = self.sessionManager.getDeviceFormats;
        NSMutableArray *jsonFormats = [NSMutableArray new];
        int lastWidth = 0;
        int lastHeight = 0;
        for (AVCaptureDeviceFormat *format in formats) {
            CMVideoDimensions dim = format.highResolutionStillImageDimensions;
            if (dim.width!=lastWidth && dim.height != lastHeight) {
                NSMutableDictionary *dimensions = [[NSMutableDictionary alloc] init];
                NSNumber *width = [NSNumber numberWithInt:dim.width];
                NSNumber *height = [NSNumber numberWithInt:dim.height];
                [dimensions setValue:width forKey:@"width"];
                [dimensions setValue:height forKey:@"height"];
                [jsonFormats addObject:dimensions];
                lastWidth = dim.width;
                lastHeight = dim.height;
            }
        }
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:jsonFormats];

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *)getBase64Image:(CGImageRef)imageRef withQuality:(CGFloat) quality {
    NSString *base64Image = nil;

    @try {
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        NSData *imageData = UIImageJPEGRepresentation(image, quality);
        base64Image = [imageData base64EncodedStringWithOptions:0];
    }
    @catch (NSException *exception) {
        NSLog(@"error while get base64Image: %@", [exception reason]);
    }

    return base64Image;
}

- (void) tapToFocus:(CDVInvokedUrlCommand*)command {
    NSLog(@"tapToFocus");
    CDVPluginResult *pluginResult;

    CGFloat xPoint = [[command.arguments objectAtIndex:0] floatValue];
    CGFloat yPoint = [[command.arguments objectAtIndex:1] floatValue];

    if (self.sessionManager != nil) {
        [self.sessionManager tapToFocus:xPoint yPoint:yPoint];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (double)radiansFromUIImageOrientation:(UIImageOrientation)orientation {
    double radians;

    switch (self.orientation) {
        case UIDeviceOrientationPortrait:
            radians = M_PI_2;
            break;
        case UIDeviceOrientationLandscapeLeft:
            radians = 0.f;
            break;
        case UIDeviceOrientationLandscapeRight:
            radians = M_PI;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            radians = -M_PI_2;
            break;
    }

    return radians;
}

-(CGImageRef) CGImageRotated:(CGImageRef) originalCGImage withRadians:(double) radians {
    CGSize imageSize = CGSizeMake(CGImageGetWidth(originalCGImage), CGImageGetHeight(originalCGImage));
    CGSize rotatedSize;
    if (radians == M_PI_2 || radians == -M_PI_2) {
        rotatedSize = CGSizeMake(imageSize.height, imageSize.width);
    } else {
        rotatedSize = imageSize;
    }

    double rotatedCenterX = rotatedSize.width / 2.f;
    double rotatedCenterY = rotatedSize.height / 2.f;

    UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, 1.f);
    CGContextRef rotatedContext = UIGraphicsGetCurrentContext();
    if (radians == 0.f || radians == M_PI) { // 0 or 180 degrees
        CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
        if (radians == 0.0f) {
            CGContextScaleCTM(rotatedContext, 1.f, -1.f);
        } else {
            CGContextScaleCTM(rotatedContext, -1.f, 1.f);
        }
        CGContextTranslateCTM(rotatedContext, -rotatedCenterX, -rotatedCenterY);
    } else if (radians == M_PI_2 || radians == -M_PI_2) { // +/- 90 degrees
        CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
        CGContextRotateCTM(rotatedContext, radians);
        CGContextScaleCTM(rotatedContext, 1.f, -1.f);
        CGContextTranslateCTM(rotatedContext, -rotatedCenterY, -rotatedCenterX);
    }

    CGRect drawingRect = CGRectMake(0.f, 0.f, imageSize.width, imageSize.height);
    CGContextDrawImage(rotatedContext, drawingRect, originalCGImage);
    CGImageRef rotatedCGImage = CGBitmapContextCreateImage(rotatedContext);

    UIGraphicsEndImageContext();

    return rotatedCGImage;
}

- (void) invokeTapToFocus:(CGPoint)point {
    [self.sessionManager tapToFocus:point.x yPoint:point.y];
}

- (void) invokeTakePicture {
    [self invokeTakePicture:0.0 withHeight:0.0 withQuality:0.85];
}

- (void) invokeTakePictureOnFocus {
    // the sessionManager will call onFocus, as soon as the camera is done with focussing.
    [self.sessionManager takePictureOnFocus];
}

- (void) invokeTakePicture:(CGFloat) width withHeight:(CGFloat) height withQuality:(CGFloat) quality{
    AVCaptureConnection *connection = [self.sessionManager.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [self.sessionManager.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef sampleBuffer, NSError *error) {

        NSLog(@"Done creating still image");

        if (error) {
            NSLog(@"%@", error);
        } else {

            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sampleBuffer];
            UIImage *capturedImage  = [[UIImage alloc] initWithData:imageData];

            CIImage *capturedCImage;
            //image resize

            if(width > 0 && height > 0){
                CGFloat scaleHeight = width/capturedImage.size.height;
                CGFloat scaleWidth = height/capturedImage.size.width;
                CGFloat scale = scaleHeight > scaleWidth ? scaleWidth : scaleHeight;

                CIFilter *resizeFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
                [resizeFilter setValue:[[CIImage alloc] initWithCGImage:[capturedImage CGImage]] forKey:kCIInputImageKey];
                [resizeFilter setValue:[NSNumber numberWithFloat:1.0f] forKey:@"inputAspectRatio"];
                [resizeFilter setValue:[NSNumber numberWithFloat:scale] forKey:@"inputScale"];
                capturedCImage = [resizeFilter outputImage];
            }else{
                capturedCImage = [[CIImage alloc] initWithCGImage:[capturedImage CGImage]];
            }

            CIImage *imageToFilter;
            CIImage *finalCImage;

            //fix front mirroring
            if (self.sessionManager.defaultCamera == AVCaptureDevicePositionFront) {
                CGAffineTransform matrix = CGAffineTransformTranslate(CGAffineTransformMakeScale(1, -1), 0, capturedCImage.extent.size.height);
                imageToFilter = [capturedCImage imageByApplyingTransform:matrix];
            } else {
                imageToFilter = capturedCImage;
            }

            CIFilter *filter = [self.sessionManager ciFilter];
            if (filter != nil) {
                [self.sessionManager.filterLock lock];
                [filter setValue:imageToFilter forKey:kCIInputImageKey];
                finalCImage = [filter outputImage];
                [self.sessionManager.filterLock unlock];
            } else {
                finalCImage = imageToFilter;
            }

            CGImageRef finalImage = [self.cameraRenderController.ciContext createCGImage:finalCImage fromRect:finalCImage.extent];
            UIImage *resultImage = [UIImage imageWithCGImage:finalImage];

            double radians = [self radiansFromUIImageOrientation:resultImage.imageOrientation];
            CGImageRef resultFinalImage = [self CGImageRotated:finalImage withRadians:radians];

            CGImageRelease(finalImage); // release CGImageRef to remove memory leaks

            CDVPluginResult *pluginResult;

            if (self.storeToFile) {
                NSData *data = UIImageJPEGRepresentation([UIImage imageWithCGImage:resultFinalImage], (CGFloat) quality);
                CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) data, NULL);

                //get all the metadata in the image
                NSDictionary *metadata = (NSDictionary *) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));

                //make the metadata dictionary mutable so we can add properties to it
                NSMutableDictionary *metadataAsMutable = [metadata mutableCopy];

                NSMutableDictionary *EXIFDictionary = [[metadataAsMutable objectForKey:(NSString *)kCGImagePropertyExifDictionary]mutableCopy];
                NSMutableDictionary *GPSDictionary = [[metadataAsMutable objectForKey:(NSString *)kCGImagePropertyGPSDictionary]mutableCopy];
                if(!EXIFDictionary) {
                    //if the image does not have an EXIF dictionary (not all images do), then create one for us to use
                    EXIFDictionary = [NSMutableDictionary dictionary];
                }

                if(!GPSDictionary) {
                    GPSDictionary = [NSMutableDictionary dictionary];
                }

                //Setup GPS
                CLLocationDegrees latitude = self.locationManager.location.coordinate.latitude;
                CLLocationDegrees longitude = self.locationManager.location.coordinate.longitude;
                NSString *latitudeRef = @"N";
                NSString *longitudeRef = @"E";

                if(latitude < 0.0) {
                    latitude *= -1.0f;
                    latitudeRef = @"S";
                }

                if(longitude < 0.0) {
                    longitude *= -1.0f;
                    longitudeRef = @"W";
                }

                NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:timeInterval];

                NSDateFormatter *dateTimeformatter=[[NSDateFormatter alloc]init];
                [dateTimeformatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];

                NSDateFormatter *dateformatter=[[NSDateFormatter alloc]init];
                [dateformatter setDateFormat:@"yyyy:MM:dd"];

                NSDateFormatter *timeformatter=[[NSDateFormatter alloc]init];
                [timeformatter setDateFormat:@"HH:mm:ss.SS"];

                NSString *dateTimeString=[dateTimeformatter stringFromDate:date];
                NSString *dateString=[dateformatter stringFromDate:date];
                NSString *timeString=[timeformatter stringFromDate:date];

                [GPSDictionary setObject:[timeformatter stringFromDate:date] forKey:(NSString*)kCGImagePropertyGPSTimeStamp];
                [GPSDictionary setObject:[dateformatter stringFromDate:date] forKey:(NSString*)kCGImagePropertyGPSDateStamp];

                if(latitude != 0 && longitude != 0){
                  [GPSDictionary setValue:[NSNumber numberWithFloat:latitude] forKey:(NSString*)kCGImagePropertyGPSLatitude];
                  [GPSDictionary setValue:[NSNumber numberWithFloat:longitude] forKey:(NSString*)kCGImagePropertyGPSLongitude];
                  [GPSDictionary setValue:latitudeRef forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
                  [GPSDictionary setValue:longitudeRef forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
                  [GPSDictionary setValue:[NSNumber numberWithFloat:self.locationManager.location.altitude] forKey:(NSString*)kCGImagePropertyGPSAltitude];
                }

                [EXIFDictionary setValue:dateTimeString forKey:(NSString*)kCGImagePropertyExifDateTimeOriginal];

                //add our modified EXIF data back into the image’s metadata
                [metadataAsMutable setObject:EXIFDictionary forKey:(NSString *)kCGImagePropertyExifDictionary];
                [metadataAsMutable setObject:GPSDictionary forKey:(NSString *)kCGImagePropertyGPSDictionary];

                CFStringRef UTI = CGImageSourceGetType(source); //this is the type of image (e.g., public.jpeg)

                //this will be the data CGImageDestinationRef will write into
                NSMutableData *dest_data = [NSMutableData data];
                CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1, NULL);

                if(!destination) {
                    NSLog(@"***Could not create image destination ***");
                }

                //add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
                CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadataAsMutable);

                //tell the destination to write the image data and metadata into our data object.
                //It will return false if something goes wrong
                BOOL success = NO;
                success = CGImageDestinationFinalize(destination);

                if(!success) {
                    NSLog(@"***Could not create data from image destination ***");
                }

                NSString* filePath = [self getTempFilePath:@"jpg"];

                //cleanup
                CFRelease(destination);
                CFRelease(source);

                NSError *err;

                if (![dest_data writeToFile:filePath options:NSAtomicWrite error:&err]) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[err localizedDescription]];
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[NSURL fileURLWithPath:filePath] absoluteString]];
                }
            } else {
                NSMutableArray *params = [[NSMutableArray alloc] init];
                NSString *base64Image = [self getBase64Image:resultFinalImage withQuality:quality];
                [params addObject:base64Image];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:params];
            }

            CGImageRelease(resultFinalImage); // release CGImageRef to remove memory leaks

            [pluginResult setKeepCallbackAsBool:true];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
        }
    }];
}

- (NSString*)getTempDirectoryPath
{
    NSString* tmpPath = [NSTemporaryDirectory()stringByStandardizingPath];
    return tmpPath;
}

- (NSString*)getTempFilePath:(NSString*)extension
{
    NSString* tmpPath = [self getTempDirectoryPath];
    NSFileManager* fileMgr = [[NSFileManager alloc] init]; // recommended by Apple (vs [NSFileManager defaultManager]) to be threadsafe
    NSString* filePath;

    // generate unique file name
    int i = 1;
    do {
        filePath = [NSString stringWithFormat:@"%@/%@%04d.%@", tmpPath, TMP_IMAGE_PREFIX, i++, extension];
    } while ([fileMgr fileExistsAtPath:filePath]);

    return filePath;
}

- (void)calculateDeviceOrientation
{
    // Create an acceleration object
    float magnitude = self.x * self.x + self.y * self.y;
    int tempOrientRounded = 0;
    int orientation = 0;

    // Don't trust the angle if the magnitude is small compared to the y value
    if (magnitude * 4 >= self.z * self.z) {
        float OneEightyOverPi = 57.29577957855f;
        float angle = (float) atan2(-self.y, self.x) * OneEightyOverPi;
        orientation = 90 - (int) round(angle);
        // normalize to 0 - 359 range

        while (orientation >= 360) {
            orientation -= 360;
        }

        while (orientation < 0) {
            orientation += 360;
        }
    }

    if (orientation == -1) {//basically flat
        tempOrientRounded = UIDeviceOrientationPortrait;
    } else if (orientation <= 45 || orientation > 315) { // round to 0
        tempOrientRounded = UIDeviceOrientationPortrait;
    } else if (orientation > 45 && orientation <= 135) { // round to 90
        tempOrientRounded = UIDeviceOrientationLandscapeRight;
    } else if (orientation > 135 && orientation <= 225) { // round to 180
        tempOrientRounded = UIDeviceOrientationPortraitUpsideDown;
    } else if (orientation > 225 && orientation <= 315) { // round to 270
        tempOrientRounded = UIDeviceOrientationLandscapeLeft;
    }

    if (orientation != -1 && self.orientation != tempOrientRounded) {
        //Orientation changed, handle the change here
        if(self.orientation == 0 && (tempOrientRounded == UIDeviceOrientationLandscapeRight || tempOrientRounded == UIDeviceOrientationLandscapeLeft)){
            // calculate the first orientation! to set the device offset.
            self.cameraRenderController.view.frame = CGRectMake(self.camera_x, self.camera_y + 20, self.camera_width, self.camera_height);
        }

        self.orientation = tempOrientRounded;
    }
}

- (void) saveImageToGallery:(CDVInvokedUrlCommand*)command {
   CDVPluginResult *pluginResult;
   NSString * filePath = [command.arguments objectAtIndex:0];

   @try {
     UIImageWriteToSavedPhotosAlbum([UIImage imageWithContentsOfFile:filePath], nil, nil, nil);
     pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"true" ];
   }
   @catch (NSException *exception) {
     pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
   }

   [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
