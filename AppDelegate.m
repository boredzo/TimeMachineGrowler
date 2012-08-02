//
//  AppDelegate.m
//  TimeMachineGrowler
//
//  Created by Peter Hosey on 2009-08-23.
//  Copyright 2009 Peter Hosey. All rights reserved.
//

#import "AppDelegate.h"

#import "TimeMachineGrowler.h"

@implementation AppDelegate

- (void) applicationWillFinishLaunching:(NSNotification *)notification {
	growler = [[TimeMachineGrowler alloc] init];
	[growler startMonitoringTheLogs];
}
- (void) applicationWillTerminate:(NSNotification *)notification {
	[growler stopMonitoringTheLogs];
}

@end
