//
//  ViewController.h
//  ModernKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MyTextField.h"

// Control panel in the macOS System Settings style: a sidebar of pages, each page a
// scrolling list of rounded sections. Built in code with system colors only, so it
// follows the light/dark appearance of macOS.
@interface ViewController : NSSplitViewController<MyTextFieldDelegate>

@property (strong) NSSegmentedControl *languageControl;
@property (strong) NSPopUpButton *popupInputType;
@property (strong) NSPopUpButton *popupCode;
@property (strong) NSSegmentedControl *switchModifiers;
@property (strong) MyTextField *CustomSwitchKey;
@property (strong) NSSwitch *CustomBeepSound;

@property (strong) NSSwitch *UseModernOrthography;
@property (strong) NSSwitch *CheckSpellingButton;
@property (strong) NSSwitch *RestoreIfInvalidWord;
@property (strong) NSSwitch *AllowZWJF;
@property (strong) NSSwitch *TempOffSpellChecking;
@property (strong) NSSwitch *UpperCaseFirstChar;
@property (strong) NSSwitch *FixRecommendBrowser;
@property (strong) NSSwitch *FixChromiumBrowser;
@property (strong) NSSwitch *AutoRememberSwitchKey;
@property (strong) NSSwitch *RememberTableCode;
@property (strong) NSSwitch *TempOffOpenKey;

@property (strong) NSSwitch *UseMacro;
@property (strong) NSSwitch *UseMacroInEnglishMode;
@property (strong) NSSwitch *AutoCapsMacro;
@property (strong) NSSwitch *QuickTelex;
@property (strong) NSSwitch *QuickStartConsonant;
@property (strong) NSSwitch *QuickEndConsonant;

@property (strong) NSSwitch *RunOnStartupButton;
@property (strong) NSSwitch *ShowUIButton;
@property (strong) NSSwitch *UseGrayIcon;
@property (strong) NSSwitch *ShowIconOnDock;
@property (strong) NSSwitch *SendKeyStepByStep;
@property (strong) NSSwitch *PerformLayoutCompat;

@property (strong) NSSwitch *CheckNewVersionOnStartup;
@property (strong) NSButton *CheckNewVersionButton;
@property (strong) NSTextField *VersionInfo;

-(void)fillData;
@end
