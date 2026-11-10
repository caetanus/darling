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

#import <UserNotifications/UNNotificationCategory.h>

// OSXER APPKIT (notifications): value objects as Apple documents them; Darling delivers no
// notifications (see UNUserNotificationCenter.h).
@implementation UNNotificationCategory {
    NSString *_identifier; NSArray *_actions, *_intentIdentifiers; UNNotificationCategoryOptions _options;
}
+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray *)actions
                     intentIdentifiers:(NSArray *)intentIdentifiers options:(UNNotificationCategoryOptions)options {
    UNNotificationCategory *c = [[[self alloc] init] autorelease];
    c->_identifier = [identifier copy]; c->_actions = [actions copy] ?: [@[] retain];
    c->_intentIdentifiers = [intentIdentifiers copy] ?: [@[] retain]; c->_options = options;
    return c;
}
- (NSString *)identifier { return _identifier; }
- (NSArray *)actions { return _actions; }
- (NSArray *)intentIdentifiers { return _intentIdentifiers; }
- (UNNotificationCategoryOptions)options { return _options; }
- (id)copyWithZone:(NSZone *)zone { return [self retain]; }
- (void)dealloc { [_identifier release]; [_actions release]; [_intentIdentifiers release]; [super dealloc]; }
@end
