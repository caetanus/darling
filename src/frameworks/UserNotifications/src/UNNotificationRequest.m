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

#import <UserNotifications/UNNotificationRequest.h>

// OSXER APPKIT (notifications): value objects as Apple documents them; Darling delivers no
// notifications (see UNUserNotificationCenter.h).
#import <UserNotifications/UNNotificationContent.h>

@implementation UNNotificationRequest { NSString *_identifier; UNNotificationContent *_content; id _trigger; }
+ (instancetype)requestWithIdentifier:(NSString *)identifier content:(UNNotificationContent *)content
                              trigger:(UNNotificationTrigger *)trigger {
    UNNotificationRequest *r = [[[self alloc] init] autorelease];
    r->_identifier = [identifier copy]; r->_content = [content copy]; r->_trigger = [(id)trigger retain];
    return r;
}
- (NSString *)identifier { return _identifier; }
- (UNNotificationContent *)content { return _content; }
- (UNNotificationTrigger *)trigger { return _trigger; }
- (id)copyWithZone:(NSZone *)zone { return [self retain]; }
- (void)dealloc { [_identifier release]; [_content release]; [_trigger release]; [super dealloc]; }
@end
