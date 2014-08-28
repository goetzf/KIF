//
//  UITableView-KIFAdditions.m
//  KIF
//
//  Created by Hilton Campbell on 4/12/14.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "UITableView-KIFAdditions.h"
#import "UIView-KIFAdditions.h"
#import "UIApplication-KIFAdditions.h"
#import "UITouch-KIFAdditions.h"
#import "CGGeometry-KIFAdditions.h"
#import "NSError-KIFAdditions.h"

@implementation UITableView (KIFAdditions)

#define DRAG_STEP_DISTANCE 5

- (BOOL)dragCell:(UITableViewCell *)cell toIndexPath:(NSIndexPath *)indexPath error:(NSError **)error;
{
    // If section < 0, search from the end of the table.
    if (indexPath.section < 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:self.numberOfSections + indexPath.section];
    }
    
    // If row < 0, search from the end of the section.
    if (indexPath.row < 0) {
        indexPath = [NSIndexPath indexPathForRow:[self numberOfRowsInSection:indexPath.section] + indexPath.row inSection:indexPath.section];
    }
    
    CGRect cellRect = [self convertRect:cell.bounds fromCoordinateSpace:cell];
    CGFloat verticalDisplacement = CGPointCenteredInRect(cellRect).y - CGPointCenteredInRect([self rectForRowAtIndexPath: indexPath]).y;
    
    return [self dragCell:cell verticalDisplacement:-verticalDisplacement error:error withBlock:nil];
}

- (BOOL)dragCell:(UITableViewCell *)cell verticalDisplacement:(CGFloat)verticalDisplacement error:(NSError **)error withBlock:(KIFEventBlock)block
{
    UIView *sourceReorderControl = [[cell subviewsWithClassNameOrSuperClassNamePrefix:@"UITableViewCellReorderControl"] lastObject];
    if (!sourceReorderControl) {
        if (error) {
            *error = [NSError KIFErrorWithFormat:@"Failed to find reorder control for cell"];
        }
        return NO;
    }
    
    CGPoint sourcePoint = [self convertPoint:CGPointCenteredInRect(sourceReorderControl.bounds) fromView:sourceReorderControl];
    CGPoint destinationPoint = CGPointMake(sourcePoint.x, sourcePoint.y + verticalDisplacement);
    
    // Create the touch (there should only be one touch object for the whole drag)
    UITouch *touch = [[UITouch alloc] initAtPoint:sourcePoint inView:self];
    [touch setPhaseAndUpdateTimestamp:UITouchPhaseBegan];
    
    UIEvent *eventDown = [self eventWithTouch:touch];
    [[UIApplication sharedApplication] sendEvent:eventDown];
    if (block) block(eventDown);
    
    // Hold long enough to enter reordering mode
    CFRunLoopRunInMode(UIApplicationCurrentRunMode, 0.2, false);
    
    CGPoint currentLocation = sourcePoint;
    UIEvent *eventDrag;
    while (currentLocation.y < destinationPoint.y - DRAG_STEP_DISTANCE || currentLocation.y > destinationPoint.y + DRAG_STEP_DISTANCE) {
        if (currentLocation.y < destinationPoint.y) {
            currentLocation.y += DRAG_STEP_DISTANCE;
        } else {
            currentLocation.y -= DRAG_STEP_DISTANCE;
        }
        
        [touch setLocationInWindow:[self.window convertPoint:currentLocation fromView:self]];
        [touch setPhaseAndUpdateTimestamp:UITouchPhaseMoved];
        
        eventDrag = [self eventWithTouch:touch];
        [[UIApplication sharedApplication] sendEvent:eventDrag];
        
        CFRunLoopRunInMode(UIApplicationCurrentRunMode, 0.01, false);
    }
    
    // Only notify for last drag event
    if (block && eventDrag) block(eventDrag);
    
    // Hold long enough for the animations to catch up
    CFRunLoopRunInMode(UIApplicationCurrentRunMode, 0.2, false);
    
    [touch setPhaseAndUpdateTimestamp:UITouchPhaseEnded];
    
    UIEvent *eventUp = [self eventWithTouch:touch];
    [[UIApplication sharedApplication] sendEvent:eventUp];
    if (block) block(eventUp);
    
    // Dispatching the event doesn't actually update the first responder, so fake it
    if (touch.view == self && [self canBecomeFirstResponder]) {
        [self becomeFirstResponder];
    }
    return YES;
}

@end
