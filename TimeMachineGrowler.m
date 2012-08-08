//
//  TimeMachineGrowler.m
//  TimeMachineGrowler
//
//  Created by Peter Hosey on 2009-08-23.
//  Copyright 2009 Peter Hosey. All rights reserved.
//

#import "TimeMachineGrowler.h"

#include <asl.h>
#define ASL_UNDOC_KEY_TIME_NSEC "TimeNanoSec"

@interface TimeMachineGrowler ()

- (void) pollLogDatabase:(NSTimer *)timer;

@end

@implementation TimeMachineGrowler

- init {
	if((self = [super init])) {
		[GrowlApplicationBridge setGrowlDelegate:self];

		NSWorkspace *wksp = [NSWorkspace sharedWorkspace];
		timeMachineIconData = [[wksp iconForFile:[wksp absolutePathForAppBundleWithIdentifier:@"com.apple.backup.launcher"]] TIFFRepresentation];
	}
	return self;
}
- (void) dealloc {
	if (pollTimer)
		[self stopMonitoringTheLogs];

	[GrowlApplicationBridge setGrowlDelegate:nil];
}

- (void) startMonitoringTheLogs {
	pollTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
												  target:self
												selector:@selector(pollLogDatabase:)
												userInfo:nil
												 repeats:YES];
	[pollTimer fire];
}
- (void) stopMonitoringTheLogs {
	[pollTimer invalidate];
	pollTimer = nil;
}

- (NSDate *) dateFromASLMessage:(aslmsg)msg {
	NSTimeInterval unixTime = strtod(asl_get(msg, ASL_KEY_TIME), NULL);
	const char *nanosecondsUTF8 = asl_get(msg, ASL_UNDOC_KEY_TIME_NSEC);
	if (nanosecondsUTF8) {
		NSTimeInterval unixTimeNanoseconds = strtod(nanosecondsUTF8, NULL);
		unixTime += (unixTimeNanoseconds / 1.0e9);
	}
	return [NSDate dateWithTimeIntervalSince1970:unixTime];
}

- (NSString *) stringWithTimeInterval:(NSTimeInterval)units {
	NSString *unitNames[] = {
		NSLocalizedString(@"seconds", /*comment*/ @"Unit names"),
		NSLocalizedString(@"minutes", /*comment*/ @"Unit names"),
		NSLocalizedString(@"hours", /*comment*/ @"Unit names")
	};
	NSUInteger unitNameIndex = 0UL;
	if (units >= 60.0) {
		units /= 60.0;
		++unitNameIndex;
	}
	if (units >= 60.0) {
		units /= 60.0;
		++unitNameIndex;
	}
	return [NSString localizedStringWithFormat:@"%.03f %@", units, unitNames[unitNameIndex]];
}

- (void) postBackupStartedNotification {
	//This method is as re-entrant as an emergency exit door.
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Time Machine started", /*comment*/ @"Notification title")
								description:lastEndTime ? [NSString stringWithFormat:NSLocalizedString(@"%@ since last back-up", @"Notification description format"), [self stringWithTimeInterval:[lastStartTime timeIntervalSinceDate:lastEndTime]]] : NSLocalizedString(@"Either this will be your first back-up, or your previous one was so long ago that it is no longer in the system log.", /*comment*/ @"Notification description format")
						   notificationName:@"Time Machine started"
								   iconData:timeMachineIconData
								   priority:-1
								   isSticky:NO
							   clickContext:nil];
}

- (void) pollLogDatabase:(NSTimer *)timer {
	aslmsg query = asl_new(ASL_TYPE_QUERY);
	const char *backupd_sender = "com.apple.backupd";
	asl_set_query(query, ASL_KEY_SENDER, backupd_sender, ASL_QUERY_OP_EQUAL);
	if (lastSearchTime) {
		char *lastSearchTimeUTF8 = NULL;
		asprintf(&lastSearchTimeUTF8, "%lu", (unsigned long)[lastSearchTime timeIntervalSince1970]);
		asl_set_query(query, ASL_KEY_TIME, lastSearchTimeUTF8, ASL_QUERY_OP_GREATER);
	}
	aslresponse response = asl_search(NULL, query);

	BOOL lastWasCanceled = NO;

	NSUInteger numFoundMessages = 0UL;
	NSDate *lastFoundMessageDate = nil;

	aslmsg msg;
	while ((msg = aslresponse_next(response))) {
		++numFoundMessages;
		lastFoundMessageDate = [self dateFromASLMessage:msg];

		const char *msgUTF8 = asl_get(msg, ASL_KEY_MSG);
		if (strcmp(msgUTF8, "Starting standard backup") == 0) {
			lastStartTime = lastFoundMessageDate;
			lastWasCanceled = NO;

			if (postGrowlNotifications) {
				[self postBackupStartedNotification];
			}

		} else if (strcmp(msgUTF8, "Backup completed successfully.") == 0) {
			lastEndTime = lastFoundMessageDate;
			lastWasCanceled = NO;

			if (postGrowlNotifications) {
				[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Time Machine finished", /*comment*/ @"Notification title")
											description:[NSString stringWithFormat:NSLocalizedString(@"Back-up took %@", @"Notification description format"), [self stringWithTimeInterval:[lastEndTime timeIntervalSinceDate:lastStartTime]]]
									   notificationName:@"Time Machine finished"
											   iconData:timeMachineIconData
											   priority:-1
											   isSticky:NO
										   clickContext:nil];
			}

		} else if (strcmp(msgUTF8, "Backup canceled.") == 0) {
			NSDate *date = lastFoundMessageDate;
			lastWasCanceled = YES;

			if (postGrowlNotifications) {
				[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Time Machine canceled", /*comment*/ @"Notification title")
											description:[NSString stringWithFormat:NSLocalizedString(@"Your patience lasted %@", @"Notification description format"), [self stringWithTimeInterval:[date timeIntervalSinceDate:lastStartTime]]]
									   notificationName:@"Time Machine canceled"
											   iconData:timeMachineIconData
											   priority:-1
											   isSticky:NO
										   clickContext:nil];
			}
		}
	}
	aslresponse_free(response);
	asl_free(query);

	//If a Time Machine back-up is running now, post the notification even if we are on our first run.
	if ((!postGrowlNotifications) && (!lastWasCanceled) && ((!lastEndTime) || ([lastStartTime compare:lastEndTime] == NSOrderedDescending))) {
		[self postBackupStartedNotification];
	}

	if (numFoundMessages > 0) {
		lastSearchTime = lastFoundMessageDate;
	}
	postGrowlNotifications = YES;
}

@end
