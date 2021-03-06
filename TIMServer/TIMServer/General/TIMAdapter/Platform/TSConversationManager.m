//
//  TSConversationManager.m
//  TIMServer
//
//  Created by 谢立颖 on 2018/11/7.
//  Copyright © 2018 Viomi. All rights reserved.
//

#import "TSConversationManager.h"
#import "TSIMMsg.h"
#import <IMMessageExt/IMMessageExt.h>
#import "CustomElemCmd.h"
#import "TSChatHeaders.h"
#import "TSIMAConnectConversation.h"
#import "TSUserManager.h"
#import "TSIMAPlatformHeaders.h"
#import "TSManager.h"
#import "TSIMAPlatform.h"

@interface TSConversationManager () <TIMMessageListener>

@end

@implementation TSConversationChangedNotifyItem

- (instancetype)initWithType:(TSConversationChangedNotifyType)type {
    if (self = [super init]) {
        _type = type;
    }
    return self;
}

- (NSNotification *)changedNotification {
    NSNotification *notify = [NSNotification notificationWithName:[self notificaionName] object:nil];
    return notify;
}

- (NSString *)notificaionName {
    return [NSString stringWithFormat:@"TSConversationChangedNotification_%d", (int)_type];
}

@end

@implementation TSConversationManager

- (instancetype)init {
    if (self = [super init]) {
        _conversationList = [[TSSafeSetArray alloc] init];
    }
    return self;
}

- (void)releaseChattingConversation {
    [_chattingConversation releaseConversation];
    _chattingConversation = nil;
}

- (void)asyncUpdateConversationListComplete
{
    if (_refreshStyle == EIMARefresh_Wait) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self asyncConversationList];
            self->_refreshStyle = EIMARefresh_None;
        });
    } else {
        _refreshStyle = EIMARefresh_None;
        [self updateOnLocalMsgComplete];
    }
}

- (void)asyncUpdateConversationList {
    NSInteger unRead = 0;
    NSArray *conversationList = [[TIMManager sharedInstance] getConversationList];
    
    for (TIMConversation *conversation in conversationList) {
        TSConversation *conv = nil;
        if ([conversation getType] == TIM_SYSTEM) {
            continue;
        } else {
            conv = [[TSConversation alloc] initWithConversation:conversation];
        }
        
        if (conv) {
            [_conversationList addObject:conv];
        }
        
        if (_chattingConversation && [_chattingConversation isEqual:conv]) {
            [conv copyConversationInfo:_chattingConversation];
            _chattingConversation = conv;
        } else {
            if (conv) {
                unRead += [conversation getUnReadMessageNum];
            }
        }
    }
    
    [self asyncUpdateConversationListComplete];
    [[NSNotificationCenter defaultCenter] postNotificationName:kAsyncUpdateConversationListNoti object:nil];
    
    if (unRead != _unReadMsgCount) {
        self.unReadMsgCount = unRead;
    }
}

- (void)asyncConversationList {
    if (_refreshStyle == EIMARefresh_None) {
        _refreshStyle = EIMARefresh_ING;
        [self asyncUpdateConversationList];
    } else {
        _refreshStyle = EIMARefresh_Wait;
    }
    
}

- (void)asyncRefreshConversationList {
    
}

- (void)updateOnAsyncLoadContactComplete
{
    // 通知更新界面
    TSConversationChangedNotifyItem *item = [[TSConversationChangedNotifyItem alloc] initWithType:TSConversationChangedNotifyTypeSyncLocalConversation];
    if (_conversationChangedCompletion)
    {
        _conversationChangedCompletion(item);
    }
    [[NSNotificationQueue defaultQueue] enqueueNotification:[item changedNotification] postingStyle:NSPostWhenIdle];
}

- (void)updateOnLocalMsgComplete
{
    // 更新界面
    TSConversationChangedNotifyItem *item = [[TSConversationChangedNotifyItem alloc] initWithType:TSConversationChangedNotifyTypeSyncLocalConversation];
    if (_conversationChangedCompletion)
    {
        _conversationChangedCompletion(item);
    }
    [[NSNotificationQueue defaultQueue] enqueueNotification:[item changedNotification] postingStyle:NSPostWhenIdle];
}

- (TSConversation *)chatWith:(TSIMUser *)user {
    TIMConversation *conv = nil;
    if ([user isC2CType]) {
        conv = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:[user userId]];
    } else {
        conv = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:[user userId]];
    }
    
    
    self.unReadMsgCount -= [conv getUnReadMessageNum];
    
    [conv setReadMessage:nil succ:^{
        
    } fail:^(int code, NSString *msg) {
        
    }];
    
    if (conv) {
        TSConversation *temp = [[TSConversation alloc] initWithConversation:conv];
        //        NSInteger index = [_conversationList indexOfObject:temp];
        //        if (index >= 0 && index < _conversationList.count) {
        //            TSConversation *ret = [_conversationList objectAtIndex:index];
        //            _chattingConversation = ret;
        //            _chattingConversation.lastMessage = _chattingConversation.lastMessage;
        //            return ret;
        //        }
        
        for (int i=0; i<_conversationList.count; i++) {
            TSConversation *ret = [_conversationList objectAtIndex:i];
            if ([[ret.conversation getReceiver] isEqualToString:[temp.conversation getReceiver]]) {
                _chattingConversation = ret;
                _chattingConversation.lastMessage = _chattingConversation.lastMessage;
                return ret;
            }
        }
        
        _chattingConversation = temp;
        return temp;
    }
    return nil;
}

- (void)onNewMessage:(NSArray *)msgs {
    
    for (TIMMessage *msg in msgs) {
        TSIMMsg *imMsg = [TSIMMsg msgWithMsg:msg];
        TIMConversation *conv = [msg getConversation];
        
        if ([imMsg isSystemMsg]) {
            return;
        }
        
        BOOL updateSucc = NO;
        
        for (int i = 0; i < [_conversationList count]; i++) {
            TSConversation *imaconv = [_conversationList objectAtIndex:i];
            NSString *imaconvReceiver = [imaconv receiver];
            //            if (imaconv.type == [conv getType] && [imaconvReceiver isEqualToString:[conv getReceiver]]) {
            if ([imaconvReceiver isEqualToString:[conv getReceiver]]) {
                
                
                if (!_chattingConversation) {
                    
                    /* _chattingConversation 还不存在的话，说明还没进入到留言板界面，此时需要在这里发送收到新消息的通知 */
                    [[NSNotificationCenter defaultCenter] postNotificationName:TIMNewMsgNotification object:nil userInfo:@{TIMNewMsgStatusUserInfoKey : @(YES)}];
                } else {
                    // 发送收到新消息的通知
                    [[NSNotificationCenter defaultCenter] postNotificationName:TIMNewMsgNotification object:nil userInfo:@{TIMNewMsgStatusUserInfoKey : @(YES)}];

                    if (imaconv == _chattingConversation) {
                        
                        //如果是c2c会话，则更新“对方正在输入...”状态
                        BOOL isInputStatus = NO;
                        
                        if (!msg.isSelf) {
                            
                            if (_chattingConversation.type == TIM_C2C) {
                                
                                // 过滤掉聊天输入状态的消息
                                int elemCount = [imMsg.msg elemCount];
                                for (int i = 0; i < elemCount; i++) {
                                    TIMElem *elem = [msg getElem:i];
                                    CustomElemCmd *elemCmd = [self isOnlineMsg:elem];
                                    
                                    if (elemCmd) {
                                        isInputStatus = YES;
                                        //                                    [[NSNotificationCenter defaultCenter] postNotificationName:kUserInputStatus object:elemCmd];
                                    }
                                }
                            }
                            
                            if (!isInputStatus) {
                                imaconv.lastMessage = imMsg;
                                [_chattingConversation onReceiveNewMessage:imMsg];
                                
                                /* _chattingConversation 存在的情况下，说明已经在留言板的界面中了，此时在这里发送收到新消息的通知 */
                                [[NSNotificationCenter defaultCenter] postNotificationName:TIMNewMsgNotification object:nil userInfo:@{TIMNewMsgStatusUserInfoKey : @(YES)}];
                            }
                        }
                    } else {
                        TIMElem *elem = [msg getElem:0];
                        CustomElemCmd *elemCmd = [self isOnlineMsg:elem];
                        if (!elemCmd) {
                            imaconv.lastMessage = imMsg;
                            
                            if (![imMsg isMineMsg]) {
                                self.unReadMsgCount ++;
                            }
                            
                            [self updateOnChat:imaconv moveFromIndex:i];
                        }
                    }
                }
                
                updateSucc = YES;
                break;
            }
        }
        
        if (!updateSucc && _refreshStyle == EIMARefresh_None) {
            
        }
    }
}

- (CustomElemCmd *)isOnlineMsg:(TIMElem *) elem
{
    if ([elem isKindOfClass:[TIMCustomElem class]])
    {
        CustomElemCmd *elemCmd = [CustomElemCmd parseCustom:(TIMCustomElem *)elem];
        if (elemCmd)
        {
            return elemCmd;
        }
    }
    return nil;
}

- (void)updateOnChat:(TSConversation *)conv moveFromIndex:(NSUInteger)index {
    
}

@end


@implementation TSConversationManager (Protected)

- (void)onConnect
{
    // 删除
    TSIMAConnectConversation *conv = [[TSIMAConnectConversation alloc] init];
    NSInteger index = [_conversationList indexOfObject:conv];
    if (index >= 0 && index < [_conversationList count])
    {
        [_conversationList removeObject:conv];
        [self updateOnDelete:conv atIndex:index];
    }
}

- (void)onDisConnect
{
    // 插入一个网络断开的fake conversation
    TSIMAConnectConversation *conv = [[TSIMAConnectConversation alloc] init];
    NSInteger index = [_conversationList indexOfObject:conv];
    if (!(index >= 0 && index < [_conversationList count]))
    {
        [_conversationList insertObject:conv atIndex:0];
        [self updateOnNewConversation:conv];
    }
}

- (void)updateOnChat:(TSConversation *)conv moveFromIndex:(NSUInteger)index
{
    NSInteger toindex = [self insertPosition];
    
    if (index != toindex)
    {
        [_conversationList removeObjectAtIndex:index];
        
        [_conversationList insertObject:conv atIndex:toindex];
        
        
        // 更新界面
        TSConversationChangedNotifyItem *item = [[TSConversationChangedNotifyItem alloc] initWithType:TSConversationChangedNotifyTypeBecomeActiveTop];
        item.conversation = conv;
        item.index = index;
        item.toIndex = toindex;
        
        if (_conversationChangedCompletion)
        {
            _conversationChangedCompletion(item);
        }
        
        [[NSNotificationQueue defaultQueue] enqueueNotification:[item changedNotification] postingStyle:NSPostWhenIdle];
    }
    
    
}

- (void)updateOnDelete:(TSConversation *)conv atIndex:(NSUInteger)index
{
    // 更新界面
    TSConversationChangedNotifyItem *item = [[TSConversationChangedNotifyItem alloc] initWithType:TSConversationChangedNotifyTypeDeleteConversation];
    item.conversation = conv;
    item.index = index;
    if (_conversationChangedCompletion)
    {
        _conversationChangedCompletion(item);
    }
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[item changedNotification] postingStyle:NSPostWhenIdle];
}

- (void)updateOnAsyncLoadContactComplete
{
    // 通知更新界面
    TSConversationChangedNotifyItem *item = [[TSConversationChangedNotifyItem alloc] initWithType:TSConversationChangedNotifyTypeSyncLocalConversation];
    if (_conversationChangedCompletion)
    {
        _conversationChangedCompletion(item);
    }
    [[NSNotificationQueue defaultQueue] enqueueNotification:[item changedNotification] postingStyle:NSPostWhenIdle];
}

- (void)updateOnLocalMsgComplete
{
    // 更新界面
    TSConversationChangedNotifyItem *item = [[TSConversationChangedNotifyItem alloc] initWithType:TSConversationChangedNotifyTypeSyncLocalConversation];
    if (_conversationChangedCompletion)
    {
        _conversationChangedCompletion(item);
    }
    [[NSNotificationQueue defaultQueue] enqueueNotification:[item changedNotification] postingStyle:NSPostWhenIdle];
}


- (void)updateOnLastMessageChanged:(TSConversation *)conv
{
    if ([_chattingConversation isEqual:conv])
    {
        NSInteger index = [_conversationList indexOfObject:conv];
        NSInteger toindex = [self insertPosition];
        if (index > 0 && index < [_conversationList count])
        {
            [_conversationList removeObject:conv];
            [_conversationList insertObject:conv atIndex:toindex];
            [self updateOnChat:conv moveFromIndex:index toIndex:toindex];
        }
        else if (index < 0 || index > [_conversationList count])
        {
            [_conversationList insertObject:conv atIndex:[self insertPosition]];
            [self updateOnNewConversation:conv];
        }
        else
        {
            // index == 0 不作处理
        }
    }
}

- (void)updateOnChat:(TSConversation *)conv moveFromIndex:(NSUInteger)index toIndex:(NSInteger)toIdx
{
    // 更新界面
    TSConversationChangedNotifyItem *item = [[TSConversationChangedNotifyItem alloc] initWithType:TSConversationChangedNotifyTypeBecomeActiveTop];
    item.conversation = conv;
    item.index = index;
    item.toIndex = toIdx;
    
    if (_conversationChangedCompletion)
    {
        _conversationChangedCompletion(item);
    }
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[item changedNotification] postingStyle:NSPostWhenIdle];
}

- (void)updateOnNewConversation:(TSConversation *)conv
{
    // 更新界面
    TSConversationChangedNotifyItem *item = [[TSConversationChangedNotifyItem alloc] initWithType:TSConversationChangedNotifyTypeNewConversation];
    item.conversation = conv;
    item.index = [_conversationList indexOfObject:conv];
    
    if (_conversationChangedCompletion)
    {
        _conversationChangedCompletion(item);
    }
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[item changedNotification] postingStyle:NSPostWhenIdle];
}

- (void)updateOnConversationChanged:(TSConversation *)conv
{
    TSConversationChangedNotifyItem *item = [[TSConversationChangedNotifyItem alloc] initWithType:TSConversationChangedNotifyTypeConversationChanged];
    item.conversation = conv;
    item.index = [_conversationList indexOfObject:conv];
    
    if (_conversationChangedCompletion)
    {
        _conversationChangedCompletion(item);
    }
    [[NSNotificationQueue defaultQueue] enqueueNotification:[item changedNotification] postingStyle:NSPostWhenIdle];
}

- (NSInteger)insertPosition
{
    TSIMAPlatform *mp = [TSIMAPlatform sharedInstance];
    if (!mp.isConnected)
    {
        return 1;
    }
    return 0;
}

@end
