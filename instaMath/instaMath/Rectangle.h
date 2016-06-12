//
//  Rectangle.h
//  customeCameraAV
//
//  Created by Paul O'Neill on 11/30/15.
//  Copyright © 2015 Paul O'Neill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Rectangle : NSObject

    @property NSUInteger left;
    @property NSUInteger right;
    @property NSUInteger bottom;
    @property NSUInteger top;
    @property BOOL isOperator;
    @property BOOL isVar;





-(NSUInteger)getFirstLayer;
-(NSUInteger)getSecondLayer;
-(NSUInteger)getThirdLayer;
-(NSUInteger)getWidth;
-(NSUInteger)getHeight;

@end
