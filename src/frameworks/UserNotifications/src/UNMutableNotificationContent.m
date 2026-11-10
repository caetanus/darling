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

#import <UserNotifications/UNMutableNotificationContent.h>

// OSXER APPKIT (notifications): value objects as Apple documents them; Darling delivers no
// notifications (see UNUserNotificationCenter.h).
@implementation UNMutableNotificationContent
@dynamic title, subtitle, body, badge, sound, userInfo, categoryIdentifier, threadIdentifier, attachments, launchImageName;
- (void)setTitle:(NSString *)value { value = [value copy]; [_title release]; _title = value; }
- (void)setSubtitle:(NSString *)value { value = [value copy]; [_subtitle release]; _subtitle = value; }
- (void)setBody:(NSString *)value { value = [value copy]; [_body release]; _body = value; }
- (void)setBadge:(NSNumber *)value { value = [value copy]; [_badge release]; _badge = value; }
- (void)setSound:(UNNotificationSound *)value { value = [value copy]; [_sound release]; _sound = value; }
- (void)setUserInfo:(NSDictionary *)value { value = [value copy]; [_userInfo release]; _userInfo = value; }
- (void)setCategoryIdentifier:(NSString *)value { value = [value copy]; [_categoryIdentifier release]; _categoryIdentifier = value; }
- (void)setThreadIdentifier:(NSString *)value { value = [value copy]; [_threadIdentifier release]; _threadIdentifier = value; }
- (void)setAttachments:(NSArray *)value { value = [value copy]; [_attachments release]; _attachments = value; }
- (void)setLaunchImageName:(NSString *)value { value = [value copy]; [_launchImageName release]; _launchImageName = value; }
@end
