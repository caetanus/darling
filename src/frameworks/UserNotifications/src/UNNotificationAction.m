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

#import <UserNotifications/UNNotificationAction.h>

// OSXER APPKIT (notifications): value objects as Apple documents them; Darling delivers no
// notifications (see UNUserNotificationCenter.h).
@implementation UNNotificationAction { NSString *_identifier, *_title; UNNotificationActionOptions _options; }
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title
                             options:(UNNotificationActionOptions)options {
    UNNotificationAction *a = [[[self alloc] init] autorelease];
    a->_identifier = [identifier copy]; a->_title = [title copy]; a->_options = options;
    return a;
}
- (NSString *)identifier { return _identifier; }
- (NSString *)title { return _title; }
- (UNNotificationActionOptions)options { return _options; }
- (id)copyWithZone:(NSZone *)zone { return [self retain]; }
- (void)dealloc { [_identifier release]; [_title release]; [super dealloc]; }
@end
