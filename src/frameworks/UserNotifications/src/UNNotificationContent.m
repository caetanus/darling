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

#import <UserNotifications/UNNotificationContent.h>

// OSXER APPKIT (notifications): value objects as Apple documents them; Darling delivers no
// notifications (see UNUserNotificationCenter.h).
#import <UserNotifications/UNMutableNotificationContent.h>

@implementation UNNotificationContent
- (NSString *)title { return _title; }
- (NSString *)subtitle { return _subtitle; }
- (NSString *)body { return _body; }
- (NSNumber *)badge { return _badge; }
- (UNNotificationSound *)sound { return _sound; }
- (NSDictionary *)userInfo { return _userInfo; }
- (NSString *)categoryIdentifier { return _categoryIdentifier; }
- (NSString *)threadIdentifier { return _threadIdentifier; }
- (NSArray *)attachments { return _attachments; }
- (NSString *)launchImageName { return _launchImageName; }
- (id)_copyAsClass:(Class)cls {
    UNNotificationContent *c = [[cls alloc] init];
    c->_title = [_title copy];
    c->_subtitle = [_subtitle copy];
    c->_body = [_body copy];
    c->_badge = [_badge copy];
    c->_sound = [_sound copy];
    c->_userInfo = [_userInfo copy];
    c->_categoryIdentifier = [_categoryIdentifier copy];
    c->_threadIdentifier = [_threadIdentifier copy];
    c->_attachments = [_attachments copy];
    c->_launchImageName = [_launchImageName copy];
    return c;
}
- (id)copyWithZone:(NSZone *)zone { return [self _copyAsClass:[UNNotificationContent class]]; }
- (id)mutableCopyWithZone:(NSZone *)zone { return [self _copyAsClass:[UNMutableNotificationContent class]]; }
- (void)dealloc { [_title release]; [_subtitle release]; [_body release]; [_badge release]; [_sound release]; [_userInfo release]; [_categoryIdentifier release]; [_threadIdentifier release]; [_attachments release]; [_launchImageName release]; [super dealloc]; }
@end
