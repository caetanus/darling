/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <QuickLookUI/QLPreviewPanel.h>

static QLPreviewPanel *sharedPanel;

@implementation QLPreviewPanel {
    id _dataSource, _controller;
    NSInteger _index;
    NSTextField *_label;
}

+ (QLPreviewPanel *)sharedPreviewPanel
{
    if (!sharedPanel) {
        sharedPanel = [[QLPreviewPanel alloc] initWithContentRect:NSMakeRect(200, 200, 480, 360)
            styleMask:NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSUtilityWindowMask
            backing:NSBackingStoreBuffered defer:YES];
        [sharedPanel setTitle:@"Quick Look"];
        [sharedPanel setHidesOnDeactivate:YES];
        sharedPanel->_label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 160, 440, 40)];
        [sharedPanel->_label setEditable:NO]; [sharedPanel->_label setBordered:NO];
        [sharedPanel->_label setDrawsBackground:NO]; [sharedPanel->_label setAlignment:NSCenterTextAlignment];
        [sharedPanel->_label setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin];
        [[sharedPanel contentView] addSubview:sharedPanel->_label];
    }
    return sharedPanel;
}

+ (BOOL)sharedPreviewPanelExists { return sharedPanel != nil; }

- (id)dataSource { return _dataSource; }
- (void)setDataSource:(id)source { _dataSource = source; [self reloadData]; }
- (id)currentController { return _controller; }

// Apple's rule: the first object of the key window's responder chain (then the app delegate)
// that accepts control becomes the controller.
- (void)updateController
{
    id candidate = nil;
    for (NSResponder *r = [[NSApp keyWindow] firstResponder]; r; r = [r nextResponder])
        if ([r respondsToSelector:@selector(acceptsPreviewPanelControl:)] && [r acceptsPreviewPanelControl:self]) {
            candidate = r; break;
        }
    if (!candidate) {
        id d = [NSApp delegate];
        if ([d respondsToSelector:@selector(acceptsPreviewPanelControl:)] && [d acceptsPreviewPanelControl:self]) candidate = d;
    }
    if (candidate == _controller) return;
    if ([_controller respondsToSelector:@selector(endPreviewPanelControl:)]) [_controller endPreviewPanelControl:self];
    _controller = candidate;
    if ([_controller respondsToSelector:@selector(beginPreviewPanelControl:)]) [_controller beginPreviewPanelControl:self];
}

- (void)makeKeyAndOrderFront:(id)sender { [self updateController]; [self reloadData]; [super makeKeyAndOrderFront:sender]; }
- (void)orderOut:(id)sender
{
    [super orderOut:sender];
    if ([_controller respondsToSelector:@selector(endPreviewPanelControl:)]) [_controller endPreviewPanelControl:self];
    _controller = nil;
}

- (NSInteger)_count { return [_dataSource respondsToSelector:@selector(numberOfPreviewItemsInPreviewPanel:)] ? [_dataSource numberOfPreviewItemsInPreviewPanel:self] : 0; }
- (NSInteger)currentPreviewItemIndex { return _index; }
- (void)setCurrentPreviewItemIndex:(NSInteger)index { _index = index; [self refreshCurrentPreviewItem]; }
- (id)currentPreviewItem
{
    NSInteger count = [self _count];
    if (_index < 0 || _index >= count) return nil;
    return [_dataSource previewPanel:self previewItemAtIndex:_index];
}
- (void)reloadData
{
    NSInteger count = [self _count];
    if (_index >= count) _index = count ? count - 1 : 0;
    [self refreshCurrentPreviewItem];
}
- (void)refreshCurrentPreviewItem
{
    id item = [self currentPreviewItem];
    NSString *title = [item respondsToSelector:@selector(previewItemTitle)] ? [item previewItemTitle] : nil;
    if (!title) title = [[[item previewItemURL] path] lastPathComponent];
    [_label setStringValue:title ? [NSString stringWithFormat:@"%@\nPreview not available", title] : @""];
}
- (BOOL)inFullScreenMode { return NO; }
- (BOOL)isInFullScreenMode { return NO; }
- (BOOL)enterFullScreenMode:(NSScreen *)screen withOptions:(NSDictionary *)options { return NO; }
- (void)exitFullScreenModeWithOptions:(NSDictionary *)options {}
@end
