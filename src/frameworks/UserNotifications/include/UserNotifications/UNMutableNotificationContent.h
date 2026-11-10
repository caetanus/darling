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
#import <UserNotifications/UNNotificationContent.h>

// OSXER APPKIT (notifications): value objects as Apple documents them; Darling delivers no
// notifications (see UNUserNotificationCenter.h).
@interface UNMutableNotificationContent : UNNotificationContent
@property (copy) NSString *title;
@property (copy) NSString *subtitle;
@property (copy) NSString *body;
@property (copy) NSNumber *badge;
@property (copy) UNNotificationSound *sound;
@property (copy) NSDictionary *userInfo;
@property (copy) NSString *categoryIdentifier;
@property (copy) NSString *threadIdentifier;
@property (copy) NSArray *attachments;
@property (copy) NSString *launchImageName;
@end
