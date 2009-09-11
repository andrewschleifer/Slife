
//  Slife
//
//  Created by Edison Thomaz
//  Copyright 2007-2008 Slife Labs, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SLNetworkController : NSObject 
{
	BOOL	m_debugState;
}

- (void) logGoalsToRewards: (NSArray*) goalsArray;
- (BOOL) validateRewardsAccount;

- (void) logEventActionWithParameters: (NSDictionary*) eventParameters;
- (void) logNoteWithParameters: (NSDictionary*) eventParameters;
- (BOOL) fetchTeamActivities;
- (BOOL) validateTeamsAccount;
	
@end
