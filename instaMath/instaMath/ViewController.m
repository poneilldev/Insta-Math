//
//  ViewController.m
//  customeCameraAV
//
//  Created by Paul O'Neill on 10/28/15.
//  Copyright © 2015 Paul O'Neill. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#include "UIImage+Resize.h"
#include "Rectangle.h"
#include "PhotoImage.h"
#import <math.h>


#define PIXELS_WIDTH 2016
#define PIXELS_HEIGHT 404
#define DARK_PIXEL_VALUE 45


@interface ViewController()

@end

@implementation ViewController

AVCaptureSession *session;
AVCaptureStillImageOutput *stillImageOutput;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)viewWillAppear:(BOOL)animated{
    session = [[AVCaptureSession alloc]init];
    [session setSessionPreset:AVCaptureSessionPresetPhoto];
    
    
    
    AVCaptureDevice *inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:&error];
    
    if ([session canAddInput:deviceInput]) {
        [session addInput:deviceInput];
    }
    
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:session];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    CALayer *rootLayer = [[self view] layer];
    [rootLayer setMasksToBounds:YES];
    CGRect frame = self.frameForCapture.frame;
    
    
    [previewLayer setFrame:frame];
    
    [rootLayer insertSublayer:previewLayer atIndex:0];
    
    stillImageOutput = [[AVCaptureStillImageOutput alloc]init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [stillImageOutput setOutputSettings:outputSettings];
    
    [session addOutput:stillImageOutput];
    
    [session startRunning];
    
}

/*********************************************************
 * TAKE PHOTO
 *********************************************************/
- (IBAction)takePhoto:(id)sender {
    
    AVCaptureConnection *videoConnection = nil;
    
    for (AVCaptureConnection *connection in stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    [stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer != NULL) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            
            UIImage *image = [UIImage imageWithData:imageData];

            //CGPoint superCenter = CGPointMake(CGRectGetMidX([UIScreen mainScreen].bounds), CGRectGetMidY([UIScreen mainScreen].bounds));
            //CGRect cropRegion = CGRectMake(image.size.height/1.8, image.size.width/2, image.size.height/12, image.size.width/2);
            CGRect cropRegion = CGRectMake(image.size.height/1.9, image.size.width/3, image.size.height/10, image.size.width);
            //self.imageView.transform = CGAffineTransformMakeRotation(M_PI_2);
            
            UIImage *newImage = [self crop:cropRegion image:image];
            
//            CGAffineTransform rotation = CGAffineTransformMakeRotation(M_PI_2);
//            
//            
//            
//            UIImageOrientation orientation = newImage.imageOrientation;
//            
            //UIImage *rotatedImage = [[UIImage alloc] initWithCGImage:newImage.CGImage scale:1.0 orientation:UIImageOrientationRight];
            //UIImage *croppedImage = [UIImage imageNamed:@"IMG_0406.JPG"];
            
            
            
            
            //UIImage *holderImage = [[UIImage alloc]initWithCGImage: croppedImage.CGImage scale:1.0 orientation:UIImageOrientationRight];
            //UIImageWriteToSavedPhotosAlbum(newImage, nil, nil, nil);
            
            // start the processing
            [self processImage:newImage];
        }
    }];
}

/*********************************************************
 * CROP IMAGE
 *********************************************************/
- (UIImage *)crop:(CGRect)rect image:(UIImage *)image{
    if (self.imageView.image.scale > 1.0f) {
        rect = CGRectMake(rect.origin.x * image.scale,
                          rect.origin.y * image.scale,
                          rect.size.width * image.scale,
                          rect.size.height * image.scale);
        
    }
    
    CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, rect);
    UIImage *result = [UIImage imageWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(imageRef);
    return result;
}

/*********************************************************
 * PROCESS IMAGE
 *********************************************************/
-(void)processImage:(UIImage *)image{
    
    // Process Image!
    CGImageRef inputCGImage = [image CGImage];
    NSUInteger width = CGImageGetWidth(inputCGImage);
    NSUInteger height = CGImageGetHeight(inputCGImage);
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    
    UInt32 * pixels;
    pixels = (UInt32 *) calloc(height * width, sizeof(UInt32));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), inputCGImage);
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    NSUInteger pixelsWide = PIXELS_WIDTH;
    NSUInteger pixelsHeight = PIXELS_HEIGHT;

    
    NSMutableArray *matrix = [[NSMutableArray alloc]init];
    // fill it up to create space
    for (int i = 0; i < PIXELS_WIDTH; i++) {
        NSNumber *intVal = [NSNumber numberWithInt:-1];
        [matrix addObject:intVal];
    }
    
                       
#define Mask8(x) ( (x) & 0xFF )
#define R(x) ( Mask8(x) )
#define G(x) ( Mask8(x >> 8 ) )
#define B(x) ( Mask8(x >> 16) )
    

    UInt32 * currentPixel = pixels;
    for (int j = PIXELS_WIDTH - 1; -1 < j; j--) {
        NSMutableArray *row = [[NSMutableArray alloc]init];
        for (int i = 0; i < PIXELS_HEIGHT; i++) {
            UInt32 color = *currentPixel;
            //printf("%3.0f ", (R(color)+G(color)+B(color))/3.0);
            float rgbVal = (R(color)+G(color)+B(color))/3.0;
            NSNumber *rgbValNum = [[NSNumber alloc]initWithFloat:rgbVal];

            [row addObject:rgbValNum];
            currentPixel++;
        }
        //printf("\n");
        [matrix replaceObjectAtIndex:j withObject:row];
        
    }
    
    //free(pixels);
    
#undef R
#undef G
#undef B
    
     //Get all characters in photo
    NSMutableArray *allChars = [self findRectangles:matrix];
    
     //Identify all characters
    NSMutableString *equation = [self identifyAllChars:allChars matrix:matrix];
    
    BOOL isAlegbra = NO;
    
    for (int i = 0; i < [equation length]; i++) {
        if ([equation characterAtIndex:i] > 94) {
            isAlegbra = YES;
            break;
        }
    }
    
    [self answer].text = equation;
    
    if (isAlegbra) {
        //[self answer].text = equation;
    } else {
        //[self solveEquation:equation];
    }
    

    
}

/*********************************************************
 * FIND SQUARES FOR EACH CHARACTER
 *********************************************************/
-(NSMutableArray *)findRectangles:(NSMutableArray *)matrix {
    
    NSMutableArray *characters = [[NSMutableArray alloc]init];

    BOOL isLeftFound = NO;
    int emptyLineCounter = 0;
    
    Rectangle *rect = [[Rectangle alloc]init];
    
    for (NSUInteger index = 0; index < matrix.count; index++) {
        NSMutableArray *colStats = [self getColumn:matrix[index] row:0];
        
        
        if ([colStats[0] integerValue] > 0 && !isLeftFound) {
            rect.left = index;
            isLeftFound = YES;
        }
        
        if ([colStats[1] integerValue] < rect.top && isLeftFound) {
            int i = [colStats[1] intValue];
            rect.top = i;
        }
        if ([colStats[2] integerValue] > rect.bottom && isLeftFound) {
            int i = [colStats[2] intValue];
            rect.bottom = i;
        }
        if (isLeftFound && [colStats[0] integerValue] == 0) {
            emptyLineCounter++;
            if (emptyLineCounter > 10) {
                rect.right = index;
                [characters addObject:rect];
                rect = [[Rectangle alloc]init];
                isLeftFound = NO;
                emptyLineCounter = 0;
            }
        }
        
        
        
    }
    
   
    
    return characters;
}

/*********************************************************
 * GET COLUMN
 *********************************************************/
-(NSMutableArray *)getColumn:(NSMutableArray *)col row:(NSUInteger)row {
    
    NSMutableArray *stats = [[NSMutableArray alloc]init];
    NSInteger top = 9999;
    NSInteger bottom = 0;
    BOOL isFirstFound = NO;
    NSUInteger darkPixelCounter = 0;
    
    for (NSInteger i = row; i < ([col count] - row); i++) {
        float value = [col[i] floatValue];
        if (value < DARK_PIXEL_VALUE && !isFirstFound) {
            top = i;
            darkPixelCounter++;
            isFirstFound = YES;
        }
        if (isFirstFound && (value < DARK_PIXEL_VALUE)) {
            bottom = i;
            darkPixelCounter++;
        }
    }
    
    
    [stats addObject:[NSNumber numberWithInteger:darkPixelCounter]];
    [stats addObject:[NSNumber numberWithInteger:top]];
    [stats addObject:[NSNumber numberWithInteger:bottom]];
    
    return stats;
}

/*********************************************************
 * IDENTIFY OPERATORS
 *********************************************************/
-(NSMutableArray *)findOperators:(NSMutableArray *)allChars {
    
    NSUInteger highestValue = 0;
    BOOL firstOne = YES;
    
    for (Rectangle *rect in allChars) {
        if (firstOne) {
            highestValue = rect.getHeight;
            rect.isOperator = NO;
            firstOne = NO;
        } else {
            if (highestValue > (rect.getHeight + 20)) {
                rect.isOperator = YES;
            } else {
                rect.isOperator = NO;
            }
        }
        
    }
    
    
    
    return allChars;
}

/*********************************************************
 * IDENTIFY OPERATOR TYPE
 *********************************************************/
-(NSMutableString *)identifyOperatorType:(NSMutableArray *)matrix rect:(Rectangle *)rect {
    BOOL isEntireColumn = NO;
    BOOL isEntireRow = NO;
    BOOL isEntireRectangle = NO;
    BOOL isWhiteRow = NO;
    BOOL doesLeftChange = NO;
    BOOL isMinus = NO;
    BOOL isPlus = NO;
    BOOL isX = NO;
    BOOL isS = NO;
    
    NSMutableString *operator = [[NSMutableString alloc]init];
    
    isX = [self isX:matrix rect:rect];
    isS = [self isS:matrix rect:rect];
    isEntireColumn = [self isEntireColumn:matrix rect:rect];
    isEntireRow = [self isEntireRow:matrix rect:rect];
    isWhiteRow = [self isWhiteRow:matrix rect:rect];
    doesLeftChange = [self isCircle:matrix rect:rect];
    isEntireRectangle = [self isEntireRect:matrix rect:rect];
    isPlus = [self isPlus:matrix rect:rect];
    
    if (rect.getHeight < 30) {
        isMinus = YES;
    }
    
    
    if (isMinus) {
        [operator appendString:@"-"];
    } else {
        if (isWhiteRow) {
            if (doesLeftChange) {
                [operator appendString:@"/"];
            } else {
                [operator appendString:@"="];
            }
        } else if (isX) {
            [operator appendString:@"x"];
        } else if (isS) {
            [operator appendString:@"s"];
        } else if (doesLeftChange) {
            if (isPlus) {
                [operator appendString:@"+"];
            } else {
                [operator appendString:@"*"];
            }
            
        }
    }
    
    
    
    
    return operator;
}

/*********************************************************
 * IS PLUS
 *********************************************************/
-(BOOL)isPlus:(NSMutableArray *)matrix rect:(Rectangle *)rect {
    BOOL isPresent = YES;
    NSUInteger index = rect.getFirstLayer;
    NSUInteger bottomBound = rect.getFirstLayer + 5;
    int darkPixelCounter = 0;
    
    while (index < bottomBound) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                darkPixelCounter++;
            }
            if (darkPixelCounter > rect.getWidth/2) {
                isPresent = NO;
                break;
            }
        }
        if (!isPresent) {
            break;
        }
        darkPixelCounter = 0;
        index++;
    }
    
    
    
    return isPresent;
}

/*********************************************************
 * IS THIS A WHITE ROW
 *********************************************************/
-(BOOL)isWhiteRow:(NSMutableArray *)matrix rect:(Rectangle *)rect {
    BOOL isPresent = NO;
    int whitePixelCounter = 0;
    int whiteLineCounter = 0;
    NSUInteger index = rect.getFirstLayer;
    NSUInteger secLayer = rect.getSecondLayer;
    
    
    while (index < secLayer) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value > DARK_PIXEL_VALUE) {
                whitePixelCounter++;
            }
            NSUInteger width = rect.getWidth;
            NSUInteger rightBound = (width-10);
            if (whitePixelCounter > rightBound) {
                whiteLineCounter++;
            }
            
            if (whiteLineCounter > 10) {
                isPresent = YES;
                break;
            }
        }
        if (isPresent) {
            break;
        }
        
        whitePixelCounter = 0;
        index++;
    }
    
    
    
    return isPresent;
}

/*********************************************************
 * IS THIS A WHITE ROW
 *********************************************************/
-(BOOL)isWhiteRowForI:(NSMutableArray *)matrix rect:(Rectangle *)rect {
    BOOL isPresent = NO;
    int whitePixelCounter = 0;
    int whiteLineCounter = 0;
    NSUInteger index = rect.top+10;
    NSUInteger secLayer = rect.getSecondLayer;
    
    
    while (index < secLayer) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value > DARK_PIXEL_VALUE) {
                whitePixelCounter++;
            }
            NSUInteger width = rect.getWidth;
            NSUInteger rightBound = (width);
            if (whitePixelCounter == rightBound - 1) {
                whiteLineCounter++;
            }
            
            if (whiteLineCounter > 2) {
                isPresent = YES;
                break;
            }
        }
        if (isPresent) {
            break;
        }
        
        whitePixelCounter = 0;
        index++;
    }
    
    
    
    return isPresent;
}

/*********************************************************
 * IS LEFT SIDE CHANGING IN FIRST LAYER
 *********************************************************/
-(BOOL)isCircle:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    NSUInteger index = rect.top;
    NSUInteger firstLayer = rect.getSecondLayer;
    NSUInteger leftSide = 9999;
    BOOL firstTimeThrough = YES;
    
    
    while (index < firstLayer) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (firstTimeThrough) {
                    leftSide = col;
                    firstTimeThrough = NO;
                    break;
                } else if (col < leftSide - 20) {
                    isPresent = YES;
                    break;
                }
                break;
            }
            
        }
        if (isPresent) {
            break;
        }
        index++;
        
    }
    
    
    
    return isPresent;
}

/*********************************************************
 * IS ENTIRE ROW
 *********************************************************/
-(BOOL)isEntireRow:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    int darkPixelCounter = 0;
    NSUInteger index = rect.top;
    NSUInteger secLayer = rect.bottom;
    
    
    while (index < secLayer) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                darkPixelCounter++;
            }
            NSUInteger width = rect.getWidth;
            NSUInteger rightBound = (width-20);
            if (darkPixelCounter > rightBound) {
                isPresent = YES;
                break;
            }
        }
        if (isPresent) {
            break;
        }
        
        darkPixelCounter = 0;
        index++;
    }
    
    
    
    return isPresent;
}

/*********************************************************
 * IS ENTIRE RECTANGLE
 *********************************************************/
-(BOOL)isEntireRect:(NSMutableArray *)matrix rect:(Rectangle *)rect {
    BOOL isPresent = NO;
    int whitePixelCounter = 0;
    NSUInteger index = rect.top+1;
    NSUInteger secLayer = rect.top + 11;
    
    
    while (index < secLayer) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value > DARK_PIXEL_VALUE) {
                whitePixelCounter++;
            }
        }
        
        if (whitePixelCounter < 20) {
            isPresent = YES;
            break;
        } else {
            break;
        }
    }
    
    
    
    return isPresent;
}

/*********************************************************
 *********************************************************
 *********************************************************
 *********************************************************
 *************   RECOGNIZING LETTERS    ******************
 *********************************************************
 *********************************************************
 *********************************************************
 *********************************************************/

/*********************************************************
 * IS X
 *********************************************************/
-(BOOL)isX:(NSMutableArray *)matrix rect:(Rectangle *)rect {
    BOOL isPresent = NO;
    int darkPixelCounter = 0;
    int whiteLineCounter = 0;
    NSUInteger bottomBound = rect.top + (rect.getHeight/4);
    NSUInteger halfWay = rect.left + (rect.getWidth/2) - 2;
    NSUInteger rightBound = rect.right - (rect.getWidth/2) + 2;
    
    for (NSUInteger col = halfWay; col < rightBound; col++) {
        for (NSUInteger row = rect.top; row < bottomBound; row++) {
            NSUInteger value = [matrix[col][row] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                darkPixelCounter++;
                break;
            }
        }
        if (darkPixelCounter == 0) {
            whiteLineCounter++;
        }
        
        if (whiteLineCounter > 3) {
            isPresent = YES;
            break;
        }
        
        darkPixelCounter = 0;
    }
    
    
    return isPresent;
}

/*********************************************************
 * IS S
 *********************************************************/
-(BOOL)isS:(NSMutableArray *)matrix rect:(Rectangle *)rect {
    BOOL isPresent = NO;
    BOOL isRight = NO;
    int whiteLineCounter = 0;
    NSUInteger index = rect.top + (rect.getHeight/2);
    NSUInteger indexRight = rect.top + 10;
    NSUInteger bottomRight = rect.top + (rect.getHeight/2);;
    NSUInteger bottom = rect.bottom - 10;
    NSUInteger halfWay = rect.left + (rect.getWidth/3);
    NSUInteger halfWayFromRight = rect.right - (rect.getWidth/3);
    
    while (index < bottom) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col > halfWay) {
                    whiteLineCounter++;
                    break;
                }
                if (whiteLineCounter > 1) {
                    isRight = YES;
                    break;
                }
                break;
            }
        }
        if (isRight) {
            break;
        }
        index++;
    }
    
    if (isRight) {
        whiteLineCounter = 0;
        while (indexRight < bottomRight) {
            for (NSUInteger col = rect.right - 1; col > rect.left; col--) {
                NSUInteger value = [matrix[col][index] integerValue];
                if (value < DARK_PIXEL_VALUE) {
                    if (col < halfWayFromRight) {
                        whiteLineCounter++;
                    }
                    if (whiteLineCounter > 1) {
                        isPresent = YES;
                        break;
                    }
                }
            }
            if (isPresent) {
                break;
            }
        }
    }
    
    
    
    return isPresent;
}

/*********************************************************
 * IS L
 *********************************************************/
-(BOOL)isL:(NSMutableArray *)matrix rect:(Rectangle *)rect {
    BOOL isPresent = YES;
    BOOL isFirstTime = YES;
    NSUInteger index = rect.top;
    NSUInteger bottom = rect.bottom - 10;
    NSUInteger leftSide = 9999;
    
    while (index < bottom) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (isFirstTime) {
                    leftSide = col;
                    isFirstTime = NO;
                } else if (col < (leftSide - 2) || col > (leftSide + 2)){
                    isPresent = NO;
                    break;
                }
            }
        }
        if (!isPresent) {
            break;
        }
        index++;
    }
    
    
    return isPresent;
}

/*********************************************************
 * TOP RIGHT OPEN
 *********************************************************/
-(BOOL)topLeftOpen:(NSMutableArray *)matrix rect:(Rectangle*) rect {
    BOOL isPresent = YES;
    NSUInteger index = rect.top;
    NSUInteger bottom = rect.top + 10;
    NSUInteger rightBound = rect.left + (rect.getWidth/5);
    
    while (index < bottom) {
        for (NSUInteger col = rect.left; col < rightBound; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                isPresent = NO;
                break;
            }
        }
        if (!isPresent) {
            break;
        }
        index++;
    }
    
    return isPresent;
}

/*********************************************************
 * IS FIVE
 *********************************************************/
-(BOOL)isFive:(NSMutableArray *)matrix rect:(Rectangle*) rect {
    BOOL isPresent = NO;
    BOOL isTopGood = NO;
    int halfWayCounter = 0;
    NSUInteger halfWayHorizontal = rect.left + (rect.getWidth/2);
    NSUInteger indexTopLeft = rect.top;
    NSUInteger bottomTop = rect.getFirstLayer;
    NSUInteger indexTop = rect.top + 5;
    //NSUInteger bottomTop = rect.top + (rect.getHeight/2) - 15;
    NSUInteger leftBound = rect.right - (rect.getWidth/2);
    NSUInteger index = rect.getSecondLayer;
    NSUInteger bottom = rect.bottom - 5;
    NSUInteger rightBound = rect.left + (rect.getWidth/1.5);
    
    
//    while (indexTopLeft < bottomTop) {
//        for (NSUInteger col = rect.left; col < rect.right; col++) {
//            NSUInteger value = [matrix[col][indexTopLeft]];
//            if (value < DARK_PIXEL_VALUE) {
//                if (col > halfWayHorizontal) {
//                    halfWayCounter++;
//                }
//                if (halfWayCounter > 6) {
//
//                }
//            }
//        }
//    }
    
    while (index < bottom) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col > rightBound) {
                    isPresent = YES;
                    break;
                }
            }
        }
        if (isPresent) {
            break;
        }
        index++;
    }
    
    while (indexTop < bottomTop) {
        for (NSUInteger col = rect.right - 1; col > rect.left; col--) {
            NSUInteger value = [matrix[col][indexTop] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col < leftBound) {
                    isTopGood = YES;
                    break;
                }
                break;
            }
        }
        if (isTopGood) {
            break;
        }
        indexTop++;
    }
    
    
    
    return (isPresent && isTopGood);
}

/*********************************************************
 * IDENTIFY ALL CHARACTERS
 *********************************************************/
-(NSMutableString *)identifyAllChars:(NSMutableArray *)allChars matrix:(NSMutableArray*) matrix {
    BOOL topBar = NO;
    BOOL isLeftBar = NO;
    BOOL isEntireColumn = NO;
    BOOL isBottomBar = NO;
    BOOL isEntireRow = NO;
    BOOL isFive = NO;
    BOOL isZero = NO;
    BOOL isThree = NO;
    BOOL isEight = NO;
    BOOL isSix = NO;
    BOOL isNine = NO;
    BOOL isWhiteSpace = NO;
    BOOL isL = NO;
    BOOL isTopLeftOpen = NO;
    
    
    
    NSMutableString *equation = [[NSMutableString alloc]init];
    
    // find operators in equation
    NSMutableArray *allCharsWithOperators = [self findOperators:allChars];
    
    for (Rectangle *rect in allCharsWithOperators) {
        if (rect.isOperator) {
            [equation appendString:[self identifyOperatorType:matrix rect:rect]];
        } else {
        
        isL = [self isL:matrix rect:rect]; // l
        isTopLeftOpen = [self topLeftOpen:matrix rect:rect];
        topBar = [self isTopBar:matrix rect:rect]; // 5,7
        isFive = [self isFive:matrix rect:rect];
        isEntireColumn = [self isEntireColumn:matrix rect:rect]; // 1,4
        isEntireRow = [self isEntireRowInSecondLayer:matrix rect:rect];
        isWhiteSpace = [self isWhiteRowForI:matrix rect:rect];
        isBottomBar = [self isBottomBar:matrix rect:rect]; // 2
        isZero = [self isZero:matrix rect:rect]; // 0
        isSix = [self isSix:matrix rect:rect]; // 6
        isNine = [self isNine:matrix rect:rect]; // 9
        isThree = [self isThree:matrix rect:rect]; // 3
        isEight = [self isEight:matrix rect:rect]; // 8
        
        
        if (isEntireColumn) {
            
            NSLog(@"Entire Column!!");
            
            if (isEntireRow) {
                if (!isTopLeftOpen) {
                    [equation appendString:@"l"];
                } else {
                    [equation appendString:@"4"];
                }
            } else {
                [equation appendString:@"1"];
            }
            
        } else if(topBar){
            
            NSLog(@"TOP BAR IS THERE!");
            isLeftBar = [self isLeftBar:matrix rect:rect];
            if (isWhiteSpace) {
                [equation appendString:@"i"];
            }else if (isBottomBar) {
                if (isThree) {
                    [equation appendString:@"3"];
                } else if (isFive){
                   [equation appendString:@"5"];
                } else if (isEight) {
                    [equation appendString:@"8"];
                } else {
                    [equation appendString:@"2"];
                }
            } else if (isSix) {
                [equation appendString:@"6"];
            } else if (isFive) {
                [equation appendString:@"5"];
            } else if (isNine) {
                [equation appendString:@"9"];
            } else if (isThree) {
                [equation appendString:@"3"];
            } else {
                if (isZero) {
                    [equation appendString:@"0"];
                } else if (!isBottomBar) {
                    [equation appendString:@"7"];
                }
            }
        } else if (isWhiteSpace) {
            [equation appendString:@"i"];
        } else if (isBottomBar) {
            if (isNine) {
                [equation appendString:@"9"];
            } else {
                [equation appendString:@"2"];
            }
        } else if (isSix) {
            [equation appendString:@"6"];
        } else if (isThree){
            [equation appendString:@"3"];
        } else if (isEight) {
            [equation appendString:@"8"];
        } else if (isNine) {
            [equation appendString:@"9"];
        } else if (isZero) {
            [equation appendString:@"0"];
        } else {
            NSLog(@"NADA");
        }
        
    }
    }

    
    return equation;
}

/*********************************************************
 *********************************************************
 *********************************************************
 *********************************************************
 *************   RECOGNIZING NUMBERS    ******************
 *********************************************************
 *********************************************************
 *********************************************************
 *********************************************************/

/*********************************************************
 * IS THERE A TOP BAR? **5,7**
 *********************************************************/
-(BOOL)isTopBar:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    BOOL hasStarted = NO;
    int darkPixelCounter = 0;
    int darkLineCounter = 0;
    NSUInteger index = rect.top;
    NSUInteger fLayer = rect.getFirstLayer;
    
    
    while (index < fLayer) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                hasStarted = YES;
                darkPixelCounter++;
            } else if (hasStarted) {
                hasStarted = NO;
                break;
            }
            NSUInteger width = rect.getWidth;
            NSUInteger rightBound = (width/2);
            if (darkPixelCounter > rightBound) {
                darkLineCounter++;
                //darkLineCounter = 0;
                break;
            }
            if (darkLineCounter > 4) {
                isPresent = YES;
                break;
            }
        }
        if (isPresent) {
            break;
        }
        
        darkPixelCounter = 0;
        index++;
    }
    


    
    
    
    return isPresent;
}

/*********************************************************
 * IS ENTIRE COLUMN? **1,4,**
 *********************************************************/
-(BOOL)isEntireColumn:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    int darkPixelCounter = 0;
    

    for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
        for (NSUInteger row = rect.top; row < rect.bottom; row++) {
            NSUInteger value = [matrix[col][row] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                darkPixelCounter++;
            }
            
            if (darkPixelCounter > rect.getHeight-10) {
                isPresent = YES;
                break;
            }

        }
        if (isPresent) {
            break;
        }
        darkPixelCounter = 0;
        //whitePixelCounter = 0;
    }
    
    return isPresent;
}

/*********************************************************
 * IS ENTIRE ROW IN SECOND LAYER? **4**
 *********************************************************/
-(BOOL)isEntireRowInSecondLayer:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    int darkPixelCounter = 0;
    NSUInteger index = rect.getFirstLayer;
    NSUInteger secLayer = rect.getSecondLayer + 10;
    
    
    while (index < secLayer) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                darkPixelCounter++;
            }
            NSUInteger width = rect.getWidth;
            NSUInteger rightBound = (width-30);
            if (darkPixelCounter > rightBound) {
                isPresent = YES;
                break;
            }
        }
        if (isPresent) {
            break;
        }
        
        darkPixelCounter = 0;
        index++;
    }
    
    
    
    return isPresent;
}

/*********************************************************
 * IS BOTTOM BAR **1,2,**
 *********************************************************/
-(BOOL)isBottomBar:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    int darkPixelCounter = 0;
    int darkLineCounter = 0;
    NSUInteger index = rect.getSecondLayer + 20;
    NSUInteger fLayer = rect.bottom;
    
    
    while (index < fLayer) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                darkPixelCounter++;
            }
            NSUInteger width = rect.getWidth;
            NSUInteger rightBound = (width/1.3);
            if (darkPixelCounter > rightBound) {
                darkLineCounter++;
            }
            if (darkLineCounter > 12) {
                isPresent = YES;
                break;
            }
        }
        if (isPresent) {
            break;
        }
        
        darkPixelCounter = 0;
        index++;
    }
    
    
    
    
    return isPresent;
}

/*********************************************************
 * LEFT SIDE BAR? **5**
 *********************************************************/
-(BOOL)isLeftBar:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = YES;
    NSUInteger index = rect.top + 30;
    NSUInteger bottom = rect.top + (rect.getHeight/2.5);
    int darkPixelCounter = 0;
    NSUInteger rightBound = (rect.left + rect.getWidth/2);
    
    while (index < bottom) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col > rightBound) {
                    isPresent = NO;
                    break;
                }
            }
        }
        if (!isPresent) {
            break;
        }
        index++;
    }
    
    
    // Check one more time for special cases
    if (!isPresent) {
        NSUInteger bottomBound = rect.getHeight/8;
        for (NSUInteger col = rect.getFirstLayer; col < (rect.getFirstLayer + bottomBound); col++) {
            NSUInteger middle = rect.left + rect.getWidth/3;
            NSUInteger value = [matrix[middle][col] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                darkPixelCounter++;
            }
            if (darkPixelCounter > 10) {
                isPresent = YES;
                break;
            }
            
        }
    }
    
    return isPresent;
}

/*********************************************************
 * IS ZERO
 *********************************************************/
-(BOOL)isZero:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    BOOL isLeftHalf = YES;
    BOOL isRightHalf = YES;
    int whiteLineCounter = 0;
    NSUInteger index = rect.getFirstLayer;
    NSUInteger indexRight = rect.getFirstLayer;
    NSUInteger bottom = rect.bottom - 20;
    NSUInteger secondHalf = rect.bottom - ((rect.getHeight/2) + 10);
    NSUInteger middle = rect.left + (rect.getWidth/2);
    

    BOOL isFirstTime = YES;
    
    
    while (index < bottom) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col > middle) {
                    whiteLineCounter++;
                }
                if (whiteLineCounter > 3) {
                    isLeftHalf = NO;
                    break;
                }
                break;
            }

    }
        if (!isLeftHalf) {
            break;
        }
        index++;

    }
    
    whiteLineCounter = 0;
    
    if (isLeftHalf) {
        while (indexRight < bottom) {
            for (NSUInteger col = rect.right - 1; col > rect.left; col--) {
                NSUInteger value = [matrix[col][indexRight] integerValue];
                if (value < DARK_PIXEL_VALUE) {
                    if (col < middle) {
                        whiteLineCounter++;
                    }
                    if (whiteLineCounter > 3) {
                        isRightHalf = NO;
                        break;
                    }
                    break;
                }
            }
            if (!isRightHalf) {
                break;
            }
            indexRight++;
        }
    }
    
    if (isRightHalf && isLeftHalf) {
        isPresent = YES;
    }
    
    
    return isPresent;
}

/*********************************************************
 * IS THREE
 *********************************************************/
-(BOOL)isThree:(NSMutableArray*)matrix rect:(Rectangle*)rect {

    BOOL isPresent = NO;
    BOOL isTopPresent = NO;
    BOOL isBottomPresent = NO;
    int whiteLineCounter = 0;
    NSUInteger index = rect.top;
    NSUInteger index2 = rect.getSecondLayer;
    NSUInteger indexRight = rect.getFirstLayer;
    NSUInteger halfwayVertical = rect.top + (rect.getHeight/2);
    NSUInteger bottom = rect.bottom;
    NSUInteger bottomRight = rect.bottom - (10);
    NSUInteger thirdWay = rect.right - (rect.getWidth/1.5);
    
    while (index < halfwayVertical) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col > thirdWay) {
                    whiteLineCounter++;
                }
                if (whiteLineCounter > 5) {
                    isTopPresent = YES;
                    break;
                }
                break;
            }
        }
        if (isTopPresent) {
            break;
        }
        index++;
    }
    
    whiteLineCounter = 0;
    
    if (isTopPresent) {
        while (index2 < bottom) {
            for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
                NSUInteger value = [matrix[col][index] integerValue];
                if (value < DARK_PIXEL_VALUE) {
                    if (col > thirdWay) {
                        whiteLineCounter++;
                    }
                    if (whiteLineCounter > 5) {
                        isBottomPresent = YES;
                        break;
                    }
                    break;
                }
            }
            if (isBottomPresent) {
                break;
            }
            index2++;
        }
    }

    
    whiteLineCounter = 0;
    
    if (isTopPresent && isBottomPresent) {
        isPresent = YES;
        while (indexRight < bottomRight) {
            for (NSUInteger col = rect.right - 1; col > rect.left; col--) {
                NSUInteger value = [matrix[col][indexRight] integerValue];
                if (value < DARK_PIXEL_VALUE) {
                    if (col < (rect.left + rect.getWidth/2)) {
                        isPresent = NO;
                        break;
                    }
                    break;
                }
            }
            if (!isPresent) {
                break;
            }
            indexRight++;
        }
    }
    
    
    
    return isPresent;
}

/*********************************************************
 * IS EIGHT
 *********************************************************/
-(BOOL)isEight:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    NSUInteger index = rect.top;
    NSUInteger bottom = rect.getSecondLayer;
    NSUInteger halfWay = rect.left + (rect.getWidth/2);
    NSUInteger leftSide = 9999;
    BOOL didGoBackDown = NO;
    BOOL firstTimeThrough = YES;
    
    while (index < bottom) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col > halfWay) {
                    return false;
                } else if (col < leftSide) {
                    leftSide = col;
                    break;
                } else if (!firstTimeThrough) {
                    if (col > leftSide + 10) {
                        didGoBackDown = YES;
                        break;
                    }
                }
                firstTimeThrough = NO;
                break;
            }
        }
        index++;
    }
    
    if (didGoBackDown) {
        isPresent = YES;
    }
    
    
    return isPresent;
}

/*********************************************************
 * IS SIX
 *********************************************************/
-(BOOL)isSix:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    
    NSUInteger index = rect.top;
    NSUInteger bottom = rect.bottom;
    NSUInteger thirdWay = rect.getFirstLayer;
    NSUInteger halfWay = rect.right - (rect.getWidth/2);
    int overHalfWayCounter = 0;
    
    
    while (index < thirdWay) {
        for (NSUInteger col = rect.right - 1; col > rect.left; col--) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col < halfWay) {
                    overHalfWayCounter++;
                }
                if (overHalfWayCounter > 4) {
                    isPresent = YES;
                    break;
                }
                break;
            }
        }
        if (isPresent) {
            break;
        }
        index++;
    }
    
    if (isPresent) {
        while (index < bottom) {
            for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
                NSUInteger value = [matrix[col][index] integerValue];
                if (value < DARK_PIXEL_VALUE) {
                    if (col > halfWay) {
                        isPresent = NO;
                        break;
                    }
                    break;
            }
        }
        if (!isPresent) {
            break;
        }
            index++;
    }
}
    
    
    return isPresent;
}

/*********************************************************
 * IS NINE
 *********************************************************/
-(BOOL)isNine:(NSMutableArray*)matrix rect:(Rectangle*)rect {
    BOOL isPresent = NO;
    BOOL isTopGood = YES;
    NSUInteger index = rect.getSecondLayer;
    NSUInteger topIndex = rect.top + 10;
    NSUInteger bottomTop = rect.getFirstLayer;
    NSUInteger bottom = rect.bottom;
    NSUInteger halfWay = rect.left + (rect.getWidth/2);
    
    
    while (topIndex < bottomTop) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][topIndex] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col > halfWay) {
                    isTopGood = NO;
                    break;
                }
                break;
            }
        }
        if (!isTopGood) {
            break;
        }
        topIndex++;
    }
    
    if (isTopGood) {
    
    while (index < bottom) {
        for (NSUInteger col = rect.left; col < rect.right - 1; col++) {
            NSUInteger value = [matrix[col][index] integerValue];
            if (value < DARK_PIXEL_VALUE) {
                if (col > halfWay) {
                    isPresent = YES;
                    break;
                }
                break;
            }
        }
        if (isPresent) {
            break;
        }
        index++;
    }
    }
    

    
    return isPresent;
}

/*********************************************************
*********************************************************
*********************************************************
*********************************************************
*************OPERATOR LOGIC AND SOLVING******************
*********************************************************
*********************************************************
*********************************************************
*********************************************************/


/*********************************************************
 * IS PLUS
 *********************************************************/
-(NSMutableString*)isPlus:(NSMutableString*)equation value:(char)value {
    
    NSArray *foo = [equation componentsSeparatedByString: @"+"];
    int sum = 0;
    for (int i = 0; i < [foo count]; i++) {
        sum += [[foo objectAtIndex:i] intValue];
    }
    
    [equation appendFormat:@" = %d", sum];
    
    return equation;
}

/*********************************************************
 * IS MINUS
 *********************************************************/
-(NSMutableString*)isMinus:(NSMutableString*)equation value:(char)value {
    
    NSArray *foo = [equation componentsSeparatedByString: @"-"];
    int sum = 0;
    for (int i = 0; i < [foo count]; i++) {
        sum -= [[foo objectAtIndex:i] intValue];
    }
    
    [equation appendFormat:@" = %d", sum];
    
    return equation;
}

/*********************************************************
 * IS DIVISION
 *********************************************************/
-(NSMutableString*)isDivision:(NSMutableString*)equation value:(char)value {
    
    NSArray *foo = [equation componentsSeparatedByString: @"/"];
    float sum = 0;
    for (int i = 0; i < [foo count]; i++) {
        sum /= [[foo objectAtIndex:i] intValue];
    }
    
    [equation appendFormat:@" = %f", sum];
    
    return equation;
}

/*********************************************************
 * IS MULTIPLICATION
 *********************************************************/
-(NSMutableString*)isMultiplication:(NSMutableString*)equation value:(char)value {
    
    NSArray *foo = [equation componentsSeparatedByString: @"*"];
    float sum = 0;
    for (int i = 0; i < [foo count]; i++) {
        sum += [[foo objectAtIndex:i] intValue];
    }
    
    [equation appendFormat:@" = %f", sum];
    
    return equation;
}

/*********************************************************
 * SOLVE EQUATION
 *********************************************************/
-(void)solveEquation:(NSMutableString *)equation {

//    for (int c = 0; c < [equation length]; c++) {
//        char value = [equation characterAtIndex:c];
//        if ((int)value < 64) {
//            if (!operatorFound) {
//                switch (value) {
//                    case 43:
//                        ans = [self isPlus:equation value:value];
//                        break;
//                        
//                    case 45:
//                        ans = [self isMinus:equation value:value];
//                        break;
//                        
//                    case 42:
//                        ans = [self isMultiplication:equation value:value];
//                        break;
//                        
//                    case 47:
//                        ans = [self isDivision:equation value:value];
//                        
//                        
//                    default:
//                        break;
//                }
//            }
//            
//        }
//    }
    
    NSExpression *exp = [NSExpression expressionWithFormat:equation];
    NSNumber *result = [exp expressionValueWithObject:nil context:nil];
    
    [equation appendFormat:@" = %@", [result stringValue]];
    
    [self answer].text = equation;
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
