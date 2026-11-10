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

// OSXER APPKIT (notifications): Darling reports notifications as not allowed.
typedef NS_ENUM(NSInteger, UNAuthorizationStatus) {
    UNAuthorizationStatusNotDetermined = 0, UNAuthorizationStatusDenied,
    UNAuthorizationStatusAuthorized, UNAuthorizationStatusProvisional,
    UNAuthorizationStatusEphemeral,
};
typedef NS_ENUM(NSInteger, UNNotificationSetting) {
    UNNotificationSettingNotSupported = 0, UNNotificationSettingDisabled, UNNotificationSettingEnabled,
};

@interface UNNotificationSettings : NSObject
@property (readonly) UNAuthorizationStatus authorizationStatus;
@property (readonly) UNNotificationSetting soundSetting;
@property (readonly) UNNotificationSetting badgeSetting;
@property (readonly) UNNotificationSetting alertSetting;
@property (readonly) UNNotificationSetting notificationCenterSetting;
@end
