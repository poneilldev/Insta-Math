//
//  Rectangle.m
//  customeCameraAV
//
//  Created by Paul O'Neill on 11/30/15.
//  Copyright © 2015 Paul O'Neill. All rights reserved.
//

#import "Rectangle.h"

@implementation Rectangle

-(id)init {
    self = [super init];
    if (self) {
        _top = 9999;
        _bottom = 0;
        _right = 0;
        _left = 0;
        
    }
    return self;
}

-(NSUInteger)getFirstLayer{
    
    NSUInteger result = (_bottom - _top)/3;
    
    return result+_top;
}

-(NSUInteger)getSecondLayer {
    
    NSUInteger result = (2*(_bottom - _top)/3);
    return result+_top;
}

-(NSUInteger)getThirdLayer {
    return _bottom;
}

-(NSUInteger)getWidth {
    return (_right - _left);
}

-(NSUInteger)getHeight {
    return (_bottom - _top);
}

@end
