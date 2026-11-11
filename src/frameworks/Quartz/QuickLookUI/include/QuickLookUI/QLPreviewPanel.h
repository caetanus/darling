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

#import <AppKit/AppKit.h>

// OSXER APPKIT (quick look): Darling has no Quick Look generators. The panel exists and
// keeps its data source, delegate and controller like Apple's; it shows the item's title and
// says that a preview is not available.
@class QLPreviewPanel;

@protocol QLPreviewItem <NSObject>
@property (readonly) NSURL *previewItemURL;
@optional
@property (readonly) NSString *previewItemTitle;
@property (readonly) id previewItemDisplayState;
@end

@protocol QLPreviewPanelDataSource <NSObject>
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel;
- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index;
@end

@protocol QLPreviewPanelDelegate <NSWindowDelegate>
@optional
- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event;
- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item;
@end

@interface NSObject (QLPreviewPanelController)
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel;
- (void)endPreviewPanelControl:(QLPreviewPanel *)panel;
@end

@interface QLPreviewPanel : NSPanel
+ (QLPreviewPanel *)sharedPreviewPanel;
+ (BOOL)sharedPreviewPanelExists;
@property (assign) id <QLPreviewPanelDataSource> dataSource;
@property (readonly) id currentController;
@property NSInteger currentPreviewItemIndex;
@property (readonly) id <QLPreviewItem> currentPreviewItem;
@property (readonly) BOOL inFullScreenMode;
@property (readonly) BOOL isInFullScreenMode;
- (void)updateController;
- (void)reloadData;
- (void)refreshCurrentPreviewItem;
- (BOOL)enterFullScreenMode:(NSScreen *)screen withOptions:(NSDictionary *)options;
- (void)exitFullScreenModeWithOptions:(NSDictionary *)options;
@end
