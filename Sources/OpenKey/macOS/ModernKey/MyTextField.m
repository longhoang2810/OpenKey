//
//  MyTextField.m
//  OpenKey
//
//  Created by Tuyen on 7/30/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import "MyTextField.h"
#include <Carbon/Carbon.h>

//the hotkey field that is recording, if any
static __weak MyTextField* _recordingField;

//OpenKey's tap must not convert or act on keys typed into a hotkey field, or the field records
//the synthetic output instead (W became keycode 0 'Æ') and the current hotkey cannot be recorded
bool IsRecordingHotKey(void) {
    MyTextField* field = _recordingField;
    return field && field.currentEditor && field.window.isKeyWindow && NSApp.isActive;
}

@implementation MyTextField {
    id eventMonitor;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (BOOL)becomeFirstResponder {
    BOOL okToChange = [super becomeFirstResponder];
    if (okToChange) {
        [self setKeyboardFocusRingNeedsDisplayInRect: [self bounds]];
        _recordingField = self;
        
        if (!eventMonitor) {
            eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *event) {
                self.LastKeyCode = event.keyCode;
                //the label is one ASCII byte; ignore modifiers so Option+Z records 'z', not 'Ω'
                NSString* chars = event.charactersIgnoringModifiers.lowercaseString;
                unichar chr = chars.length > 0 ? [chars characterAtIndex:0] : 0;
                self.LastKeyChar = chr > 0x20 && chr < 0x7F ? chr : '?';
                return event;
            } ];
            
        }
    }
    return okToChange;
}

-(void) textDidEndEditing:(NSNotification *)notification {
    [NSEvent removeMonitor:eventMonitor];
    eventMonitor = nil;
    if (_recordingField == self)
        _recordingField = nil;
}

- (void)textDidChange:(NSNotification *)notification {
    if (self.LastKeyCode == kVK_Space) {
        [self setStringValue:@"Space"];
        [self.Parent onMyTextFieldKeyChange:kVK_Space character:kVK_Space];
    } else if (self.LastKeyCode == kVK_Delete || self.LastKeyCode == kVK_ForwardDelete) {
        [self setStringValue:@""];
        [self.Parent onMyTextFieldKeyChange:0xFE character:0xFE];
    } else {
        [self setStringValue:@""];
        [self.Parent onMyTextFieldKeyChange:self.LastKeyCode character:self.LastKeyChar];
        [self setStringValue:[NSString stringWithFormat:@"%c", self.LastKeyChar]];
    }
}

-(void)setTextByChar:(unsigned short)chr {
    if (chr == kVK_Space) {
        [self setStringValue:@"Space"];
    } else if (chr == 0xFE) {
        [self setStringValue:@""];
    } else {
        NSString* str = [NSString stringWithFormat:@"%c", chr];
        [self setStringValue:str];
    }
}
@end
