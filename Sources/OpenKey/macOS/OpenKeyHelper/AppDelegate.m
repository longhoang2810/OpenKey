//
//  AppDelegate.m
//  OpenKeyHelper
//
//  Created by Tuyen on 2/1/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    //runningApplications holds NSRunningApplication objects, so the old containsObject: with a
    //bundle id string never matched
    if ([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.tuyenmai.openkey"].count == 0) {
        NSString* path = [[NSBundle mainBundle] bundlePath];
        for (int i = 0; i < 4; i++)
            path = [path stringByDeletingLastPathComponent];
        [[NSWorkspace sharedWorkspace] launchApplication:path];
    }
    //its only job is done; it used to stay running for the whole session
    [NSApp terminate:nil];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
