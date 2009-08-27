//
//  TimeMachineGrowler.h
//  TimeMachineGrowler
//
//  Created by Peter Hosey on 2009-08-23.
//  Copyright 2009 Peter Hosey. All rights reserved.
//

@interface TimeMachineGrowler : NSObject <GrowlApplicationBridgeDelegate>
{
	NSTimer *pollTimer;
	NSDate *lastSearchTime, *lastStartTime, *lastEndTime;
	NSData *timeMachineIconData;
	BOOL postGrowlNotifications;
}

- (void) startMonitoringTheLogs;
- (void) stopMonitoringTheLogs;

@end
