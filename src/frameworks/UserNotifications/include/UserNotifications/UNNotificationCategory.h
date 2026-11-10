/*
 This file is part of Darling.

 Copyright (C) 2021 Lubos Dolezel

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

#include <Foundation/Foundation.h>

// OSXER APPKIT (notifications): value objects as Apple documents them; Darling delivers no
// notifications (see UNUserNotificationCenter.h).
typedef NS_OPTIONS(NSUInteger, UNNotificationCategoryOptions) {
    UNNotificationCategoryOptionCustomDismissAction = 1 << 0,
    UNNotificationCategoryOptionAllowInCarPlay = 1 << 1,
    UNNotificationCategoryOptionHiddenPreviewsShowTitle = 1 << 2,
    UNNotificationCategoryOptionHiddenPreviewsShowSubtitle = 1 << 3,
};
@interface UNNotificationCategory : NSObject <NSCopying>
+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray *)actions
                     intentIdentifiers:(NSArray *)intentIdentifiers options:(UNNotificationCategoryOptions)options;
@property (readonly, copy) NSString *identifier;
@property (readonly, copy) NSArray *actions;
@property (readonly, copy) NSArray *intentIdentifiers;
@property (readonly) UNNotificationCategoryOptions options;
@end
