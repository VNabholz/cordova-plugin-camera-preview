#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>

#import "CameraSessionManager.h"
#import "CameraRenderController.h"


@interface CameraPreview : CDVPlugin <TakePictureDelegate, FocusDelegate, CLLocationManagerDelegate>

- (void) startCamera:(CDVInvokedUrlCommand*)command;
- (void) stopCamera:(CDVInvokedUrlCommand*)command;
- (void) showCamera:(CDVInvokedUrlCommand*)command;
- (void) hideCamera:(CDVInvokedUrlCommand*)command;
- (void) getFocusMode:(CDVInvokedUrlCommand*)command;
- (void) setFocusMode:(CDVInvokedUrlCommand*)command;
- (void) getFlashMode:(CDVInvokedUrlCommand*)command;
- (void) setFlashMode:(CDVInvokedUrlCommand*)command;
- (void) setZoom:(CDVInvokedUrlCommand*)command;
- (void) getZoom:(CDVInvokedUrlCommand*)command;
- (void) getHorizontalFOV:(CDVInvokedUrlCommand*)command;
- (void) getMaxZoom:(CDVInvokedUrlCommand*)command;
- (void) getExposureModes:(CDVInvokedUrlCommand*)command;
- (void) getExposureMode:(CDVInvokedUrlCommand*)command;
- (void) setExposureMode:(CDVInvokedUrlCommand*)command;
- (void) getExposureCompensation:(CDVInvokedUrlCommand*)command;
- (void) setExposureCompensation:(CDVInvokedUrlCommand*)command;
- (void) getExposureCompensationRange:(CDVInvokedUrlCommand*)command;
- (void) setPreviewSize: (CDVInvokedUrlCommand*)command;
- (void) switchCamera:(CDVInvokedUrlCommand*)command;
- (void) takePicture:(CDVInvokedUrlCommand*)command;
- (void) takeSnapshot:(CDVInvokedUrlCommand*)command;
- (void) setColorEffect:(CDVInvokedUrlCommand*)command;
- (void) getSupportedPictureSizes:(CDVInvokedUrlCommand*)command;
- (void) getSupportedFlashModes:(CDVInvokedUrlCommand*)command;
- (void) getSupportedFocusModes:(CDVInvokedUrlCommand*)command;
- (void) tapToFocus:(CDVInvokedUrlCommand*)command;
- (void) getSupportedWhiteBalanceModes:(CDVInvokedUrlCommand*)command;
- (void) getWhiteBalanceMode:(CDVInvokedUrlCommand*)command;
- (void) setWhiteBalanceMode:(CDVInvokedUrlCommand*)command;
- (void) invokeTakePicture:(CGFloat) width withHeight:(CGFloat) height withQuality:(CGFloat) quality;
- (void) invokeTakePicture;
- (void) invokeTapToFocus:(CGPoint) point;
- (void) saveImageToGallery:(CDVInvokedUrlCommand*)command;

- (void)enterBackgroundNotification:(NSNotification *)notification;
- (void)enterForegroundNotification:(NSNotification *)notification;
- (void) startMotionManager;

@property (nonatomic) CameraSessionManager *sessionManager;
@property (nonatomic) CameraRenderController *cameraRenderController;
@property (nonatomic) NSString *onPictureTakenHandlerId;
@property (nonatomic) BOOL storeToFile;
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (nonatomic) double x;
@property (nonatomic) double y;
@property (nonatomic) double z;
@property (nonatomic) int orientation;
@property (nonatomic) int camera_x;
@property (nonatomic) int camera_y;
@property (nonatomic) int camera_width;
@property (nonatomic) int camera_height;
@property (nonatomic) CLLocationDegrees latitude;
@property (nonatomic) CLLocationDegrees longitude;
@property (nonatomic) float altitude;
@property (nonatomic) NSString *latitudeRef;
@property (nonatomic) NSString *longitudeRef;
@end
