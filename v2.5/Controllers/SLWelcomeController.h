//
//  Slife
//
//  Created by Edison Thomaz
//  Copyright 2007-2008 Slife Labs, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SLWelcomeController : NSWindowController 
{
	IBOutlet NSView*				m_mainViewPlaceholder;
	IBOutlet NSView*				m_accessibilityView;
	IBOutlet NSView*				m_tutorialView;
}

- (void) resetViews;

- (IBAction) showPreferencesButtonClicked: (id) sender;
- (IBAction) goToTutorialButtonClicked: (id) sender;

- (IBAction) slifeTeamsLearnMoreButtonClicked: (id) sender;
- (IBAction) slifeLearnMoreButtonClicked: (id) sender;
- (IBAction) closeButtonClicked: (id) sender;

@end
