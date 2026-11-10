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
@class UNNotificationSound;
@interface UNNotificationContent : NSObject <NSCopying, NSMutableCopying> {
@protected
    NSString *_title;
    NSString *_subtitle;
    NSString *_body;
    NSNumber *_badge;
    UNNotificationSound *_sound;
    NSDictionary *_userInfo;
    NSString *_categoryIdentifier;
    NSString *_threadIdentifier;
    NSArray *_attachments;
    NSString *_launchImageName;
}
@property (readonly, copy) NSString *title;
@property (readonly, copy) NSString *subtitle;
@property (readonly, copy) NSString *body;
@property (readonly, copy) NSNumber *badge;
@property (readonly, copy) UNNotificationSound *sound;
@property (readonly, copy) NSDictionary *userInfo;
@property (readonly, copy) NSString *categoryIdentifier;
@property (readonly, copy) NSString *threadIdentifier;
@property (readonly, copy) NSArray *attachments;
@property (readonly, copy) NSString *launchImageName;
@end
