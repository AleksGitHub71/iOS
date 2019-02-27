
#import "GroupCallViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>

#import "LTHPasscodeViewController.h"
#import "SVProgressHUD.h"

#import "NSString+MNZCategory.h"
#import "UIApplication+MNZCategory.h"
#import "UIImageView+MNZCategory.h"

#import "DevicePermissionsHelper.h"
#import "GroupCallCollectionViewCell.h"
#import "Helper.h"
#import "MEGACallManager.h"
#import "MEGAChatAnswerCallRequestDelegate.h"
#import "MEGAChatEnableDisableAudioRequestDelegate.h"
#import "MEGAChatEnableDisableVideoRequestDelegate.h"
#import "MEGAChatStartCallRequestDelegate.h"
#import "MEGAGroupCallPeer.h"
#import "MEGANavigationController.h"
#import "MEGASdkManager.h"

#define kSmallPeersLayout 7

@interface GroupCallViewController () <UICollectionViewDataSource, MEGAChatCallDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UIView *outgoingCallView;
@property (weak, nonatomic) IBOutlet UIView *incomingCallView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@property (weak, nonatomic) IBOutlet UIButton *enableDisableVideoButton;
@property (weak, nonatomic) IBOutlet UIButton *muteUnmuteMicrophone;
@property (weak, nonatomic) IBOutlet UIButton *enableDisableSpeaker;

@property (weak, nonatomic) IBOutlet UIView *toastView;
@property (weak, nonatomic) IBOutlet UILabel *toastLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toastTopConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *peerTalkingViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *collectionViewBottomConstraint;
@property (weak, nonatomic) IBOutlet MEGARemoteImageView *peerTalkingVideoView;
@property (weak, nonatomic) IBOutlet UIView *peerTalkingView;
@property (weak, nonatomic) IBOutlet UIImageView *peerTalkingImageView;
@property (weak, nonatomic) IBOutlet UIImageView *peerTalkingMuteView;
@property (weak, nonatomic) IBOutlet UIView *peerTalkingQualityView;

@property (weak, nonatomic) IBOutlet UIView *participantsView;
@property (weak, nonatomic) IBOutlet UILabel *participantsLabel;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *collectionActivity;

@property (weak, nonatomic) IBOutlet UIView *volumeContainerView;
@property (strong, nonatomic) MPVolumeView *mpVolumeView;

@property (strong, nonatomic) NSMutableArray<MEGAGroupCallPeer *> *peersInCall;
@property (strong, nonatomic) MEGAGroupCallPeer *localPeer;
@property (strong, nonatomic) MEGAGroupCallPeer *lastPeerTalking;

@property (strong, nonatomic) AVAudioPlayer *player;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSDate *baseDate;
@property (assign, nonatomic) NSInteger initDuration;
@property (assign, nonatomic) CGSize cellSize;

@property (nonatomic, getter=isManualMode) BOOL manualMode;
@property (assign, nonatomic) MEGAGroupCallPeer *peerManualMode;

@property (nonatomic) BOOL shouldHideAcivity;

@property UIView *navigationView;
@property UILabel *navigationTitleLabel;
@property UILabel *navigationSubtitleLabel;

@end

@implementation GroupCallViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self configureNavigation];
    [self initDataSource];
 
    if (self.callType == CallTypeIncoming) {
        [self showIncomingCall];
    } else  if (self.callType == CallTypeOutgoing) {
        [self startOutgoingCall];
    } else  if (self.callType == CallTypeActive) {
        self.call = [[MEGASdkManager sharedMEGAChatSdk] chatCallForChatId:self.chatRoom.chatId];
        if (self.call.status == MEGAChatCallStatusUserNoPresent) {
            [self joinActiveCall];
        } else {
            [self instantiatePeersInCall];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[MEGASdkManager sharedMEGAChatSdk] addChatCallDelegate:self];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didSessionRouteChange:) name:AVAudioSessionRouteChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didWirelessRoutesAvailableChange:) name:MPVolumeViewWirelessRoutesAvailableDidChangeNotification object:nil];

    //NOTE: If we open this view controller from 'MEGA' or 'VIDEO' CallKit buttons, we should update the call and configure all the UI
    if (self.call.status == MEGAChatCallStatusRingIn) {
        self.call = [[MEGASdkManager sharedMEGAChatSdk] chatCallForChatId:self.chatRoom.chatId];
        if (self.call.status == MEGAChatCallStatusInProgress) {
            [self instantiatePeersInCall];
        }
    }
    
    self.mpVolumeView = [[MPVolumeView alloc] initWithFrame:self.enableDisableSpeaker.bounds];
    self.mpVolumeView.showsVolumeSlider = NO;
    [self.mpVolumeView setRouteButtonImage:[UIImage imageNamed:@"audioSourceActive"] forState:UIControlStateNormal];
    [self.volumeContainerView addSubview:self.mpVolumeView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.callType == CallTypeActive) {
        [self shouldChangeCallLayout];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[MEGANavigationController.class]].barTintColor = UIColor.mnz_redMain;

    [[MEGASdkManager sharedMEGAChatSdk] removeChatCallDelegate:self];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self removeAllVideoListeners];
        if (self.call.numParticipants >= kSmallPeersLayout) {
            UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
            if (orientation == UIInterfaceOrientationPortrait) {
                [UIView animateWithDuration:0.3f animations:^{
                    self.peerTalkingViewHeightConstraint.constant = 400;
                    self.collectionViewBottomConstraint.constant = 100 + self.peerTalkingViewHeightConstraint.constant - self.view.frame.size.height;
                } completion:^(BOOL finished) {
                    if (finished) {
                        [self.collectionView reloadData];
                        MEGALogDebug(@"[Group Call] Reload data %s", __PRETTY_FUNCTION__);
                    }
                }];
            } else {
                [UIView animateWithDuration:0.3f animations:^{
                    self.collectionViewBottomConstraint.constant = 0;
                    self.peerTalkingViewHeightConstraint.constant = self.view.frame.size.height - 100;
                } completion:^(BOOL finished) {
                    if (finished) {
                        [self.collectionView reloadData];
                        MEGALogDebug(@"[Group Call] Reload data %s", __PRETTY_FUNCTION__);
                    }
                }];
            }
            self.collectionView.userInteractionEnabled = YES;
        } else {
            [self.collectionView reloadData];
            MEGALogDebug(@"[Group Call] Reload data %s", __PRETTY_FUNCTION__);
            self.collectionView.userInteractionEnabled = NO;
        }
        [self instantiateNavigationTitle];
    } completion:nil];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.peersInCall.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    GroupCallCollectionViewCell *cell = (GroupCallCollectionViewCell *) [self.collectionView dequeueReusableCellWithReuseIdentifier:@"GroupCallCell" forIndexPath:indexPath];
    
    MEGAGroupCallPeer *peer = [self.peersInCall objectAtIndex:indexPath.row];
    [cell configureCellForPeer:peer inChat:self.chatRoom.chatId numParticipants:self.call.numParticipants];
    
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    MEGAGroupCallPeer *peer = [self.peersInCall objectAtIndex:indexPath.row];
    GroupCallCollectionViewCell *groupCallCell = (GroupCallCollectionViewCell *)cell;
    [groupCallCell configureCellForPeer:peer inChat:self.chatRoom.chatId numParticipants:self.call.numParticipants];
    if (self.peersInCall.count >= kSmallPeersLayout && self.manualMode && [peer isEqualToPeer:self.peerManualMode]) {
        [groupCallCell showUserOnFocus];
    } else {
        [groupCallCell hideUserOnFocus];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.peersInCall.count >= kSmallPeersLayout) {
        MEGAGroupCallPeer *peer = [self.peersInCall objectAtIndex:indexPath.row];
        GroupCallCollectionViewCell *groupCallCell = (GroupCallCollectionViewCell *)cell;
        if (!groupCallCell.videoImageView.hidden) {
            if (indexPath.item + 1 == self.peersInCall.count) {
                [groupCallCell removeLocalVideoInChat:self.chatRoom.chatId];
            } else {
                [groupCallCell removeRemoteVideoForPeer:peer inChat:self.chatRoom.chatId];
            }
        }
    }
}


- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item == self.peersInCall.count - 1) {
        return;
    }
    if (self.peersInCall.count >= kSmallPeersLayout) {
        //remove border stroke of previous manual selected participant
        NSUInteger previousPeerIndex;
        if (self.manualMode) {
            previousPeerIndex = [self.peersInCall indexOfObject:[self peerForPeerId:self.peerManualMode.peerId clientId:self.peerManualMode.clientId]];
        } else {
            previousPeerIndex = [self.peersInCall indexOfObject:[self peerForPeerId:self.lastPeerTalking.peerId clientId:self.lastPeerTalking.clientId]];
        }
        GroupCallCollectionViewCell *cell = (GroupCallCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:previousPeerIndex inSection:0]];
        [cell hideUserOnFocus];
        
        MEGAGroupCallPeer *peerSelected = [self.peersInCall objectAtIndex:indexPath.item];
        if ([peerSelected isEqualToPeer:self.peerManualMode]) {
            if (self.manualMode) {
                self.lastPeerTalking = self.peerManualMode;
                self.peerManualMode = nil;
                self.manualMode = NO;
            } else {
                [self configureUserOnFocus:peerSelected manual:YES];
            }
        } else {
            [self configureUserOnFocus:peerSelected manual:NO];
        }
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    switch (self.peersInCall.count) {
        case 1:
            self.cellSize = self.collectionView.frame.size;
            break;
            
        case 2: {
            float maxWidth = MAX(self.collectionView.frame.size.height, self.collectionView.frame.size.width);
            self.cellSize = CGSizeMake(floor(maxWidth / 2), floor(maxWidth / 2));
            break;
        }
            
        case 3: {
            float maxWidth = MAX(self.collectionView.frame.size.height, self.collectionView.frame.size.width);
            self.cellSize = CGSizeMake(floor(maxWidth / 3), floor(maxWidth / 3));
            break;
        }
            
        case 4: {
            float maxWidth = MIN(self.collectionView.frame.size.height, self.collectionView.frame.size.width);
            self.cellSize = CGSizeMake(floor(maxWidth / 2), floor(maxWidth / 2));
            break;
        }
            
        case 5: case 6: {
            float maxWidth = MIN(self.collectionView.frame.size.height, self.collectionView.frame.size.width);
            if ((maxWidth / 2) * 3 < MAX(self.collectionView.frame.size.height, self.collectionView.frame.size.width)) {
                self.cellSize = CGSizeMake(floor(maxWidth / 2), floor(maxWidth / 2));
            } else {
                maxWidth = MAX(self.collectionView.frame.size.height, self.collectionView.frame.size.width);
                self.cellSize = CGSizeMake(floor(maxWidth / 3) , floor(maxWidth / 3));
            }
            break;
        }
            
        default:
            self.cellSize = CGSizeMake(60, 60);
            break;
    }
    
    return self.cellSize;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    switch (self.peersInCall.count) {
        case 1: {
            return UIEdgeInsetsMake(0, 0, 0, 0);
        }
        
        case 2: case 3: {
            UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
            if (orientation == UIInterfaceOrientationPortrait) {
                float widthInset = (self.collectionView.frame.size.width - self.cellSize.width) / 2;
                return UIEdgeInsetsMake(0, widthInset, 0, widthInset);
            } else {
                float heightInset = (self.collectionView.frame.size.height - self.cellSize.height) / 2;
                return UIEdgeInsetsMake(heightInset, 0, heightInset, 0);
            }
        }
            
        case 4: {
                float widthInset = (self.collectionView.frame.size.width - self.cellSize.width * 2) / 2;
                float heightInset = (self.collectionView.frame.size.height - self.cellSize.height * 2) / 2;
                return UIEdgeInsetsMake(heightInset, widthInset, heightInset, widthInset);
        }
        
        case 5: case 6: {
            UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
            if (orientation == UIInterfaceOrientationPortrait) {
                float widthInset = (self.collectionView.frame.size.width - self.cellSize.width * 2) / 2;
                float heightInset = (self.collectionView.frame.size.height - self.cellSize.height * 3) / 2;
                return UIEdgeInsetsMake(heightInset, widthInset, heightInset, widthInset);
            } else {
                float widthInset = (self.collectionView.frame.size.width - self.cellSize.width * 3) / 2;
                float heightInset = (self.collectionView.frame.size.height - self.cellSize.height * 2) / 2;
                return UIEdgeInsetsMake(heightInset, widthInset, heightInset, widthInset);
            }
        }
            
        default: {
            return UIEdgeInsetsMake(0, 0, 0, 0);
        }
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    switch (self.call.numParticipants) {
        case 1: case 2: case 3: case 4: case 5: case 6:
            return 0;
            
        default:
            return 8;
    }
}

#pragma mark - IBActions

- (IBAction)acceptCallWithVideo:(UIButton *)sender {
    MEGAChatAnswerCallRequestDelegate *answerCallRequestDelegate = [[MEGAChatAnswerCallRequestDelegate alloc] initWithCompletion:^(MEGAChatError *error) {
        if (error.type == MEGAChatErrorTypeOk) {
            self.enableDisableVideoButton.selected = YES;
        } else {
            [self dismissViewControllerAnimated:YES completion:^{
                if (error.type == MEGAChatErrorTooMany) {
                    [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"Error. No more participants are allowed in this group call.", @"Message show when a call cannot be established because there are too many participants in the group call")];
                }
            }];
        }
    }];
    [[MEGASdkManager sharedMEGAChatSdk] answerChatCall:self.chatRoom.chatId enableVideo:YES delegate:answerCallRequestDelegate];
}

- (IBAction)acceptCall:(UIButton *)sender {
    MEGAChatAnswerCallRequestDelegate *answerCallRequestDelegate = [[MEGAChatAnswerCallRequestDelegate alloc] initWithCompletion:^(MEGAChatError *error) {
        if (error.type != MEGAChatErrorTypeOk) {
            [self dismissViewControllerAnimated:YES completion:^{
                if (error.type == MEGAChatErrorTooMany) {
                    [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"Error. No more participants are allowed in this group call.", @"Message show when a call cannot be established because there are too many participants in the group call")];
                }
            }];
        } else {
            self.incomingCallView.hidden = YES;
            self.outgoingCallView.hidden = NO;
        }
    }];
    [[MEGASdkManager sharedMEGAChatSdk] answerChatCall:self.chatRoom.chatId enableVideo:self.videoCall delegate:answerCallRequestDelegate];
}

- (IBAction)hangCall:(UIButton *)sender {
    [self removeAllVideoListeners];
    if (@available(iOS 10.0, *)) {
        [self.megaCallManager endCall:self.call];
    } else {
        [[MEGASdkManager sharedMEGAChatSdk] hangChatCall:self.chatRoom.chatId];
    }
}

- (IBAction)muteOrUnmuteCall:(UIButton *)sender {
    MEGAChatEnableDisableAudioRequestDelegate *enableDisableAudioRequestDelegate = [[MEGAChatEnableDisableAudioRequestDelegate alloc] initWithCompletion:^(MEGAChatError *error) {
        if (error.type == MEGAChatErrorTypeOk) {
            
            if (self.localPeer) {
                self.localPeer.audio = sender.selected;
                NSUInteger index = [self.peersInCall indexOfObject:self.localPeer];
                GroupCallCollectionViewCell *cell = (GroupCallCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
                [cell configureUserAudio:self.localPeer.audio];
                
                MEGAGroupCallPeer *previousPeerSelected = self.manualMode ? self.peerManualMode : self.lastPeerTalking;
                if ([previousPeerSelected isEqualToPeer:self.localPeer]) {
                    self.peerTalkingMuteView.hidden = self.localPeer.audio;
                }
                
                sender.selected = !sender.selected;
            }
        }
    }];
    
    if (sender.selected) {
        [[MEGASdkManager sharedMEGAChatSdk] enableAudioForChat:self.chatRoom.chatId delegate:enableDisableAudioRequestDelegate];
    } else {
        [[MEGASdkManager sharedMEGAChatSdk] disableAudioForChat:self.chatRoom.chatId delegate:enableDisableAudioRequestDelegate];
    }
}

- (IBAction)enableDisableVideo:(UIButton *)sender {
    [DevicePermissionsHelper videoPermissionWithCompletionHandler:^(BOOL granted) {
        if (granted) {
            MEGAChatEnableDisableVideoRequestDelegate *enableDisableVideoRequestDelegate = [[MEGAChatEnableDisableVideoRequestDelegate alloc] initWithCompletion:^(MEGAChatError *error) {
                if (error.type == MEGAChatErrorTypeOk) {
                    
                    MEGAGroupCallPeer *localUserVideoFlagChanged = self.localPeer;
                    
                    if (localUserVideoFlagChanged) {
                        localUserVideoFlagChanged.video = !sender.selected;
                        NSUInteger index = [self.peersInCall indexOfObject:localUserVideoFlagChanged];
                         GroupCallCollectionViewCell *cell = (GroupCallCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
                        
                        if (sender.selected) {
                            [cell removeLocalVideoInChat:self.chatRoom.chatId];
                        } else {
                            [cell addLocalVideoInChat:self.chatRoom.chatId];
                        }
                        [[UIDevice currentDevice] setProximityMonitoringEnabled:sender.selected];
                        sender.selected = !sender.selected;
                        
                        [self updateParticipants];
                    }
                } else if (error.type == MEGAChatErrorTooMany) {
                    [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"Error. No more video are allowed in this group call.", @"Message show when a call cannot be established because there are too many video activated in the group call")];
                }
            }];
            if (sender.selected) {
                [[MEGASdkManager sharedMEGAChatSdk] disableVideoForChat:self.chatRoom.chatId delegate:enableDisableVideoRequestDelegate];
            } else {
                [[MEGASdkManager sharedMEGAChatSdk] enableVideoForChat:self.chatRoom.chatId delegate:enableDisableVideoRequestDelegate];
            }
        } else {
            [DevicePermissionsHelper alertVideoPermissionWithCompletionHandler:^{
                __weak __typeof(self) weakSelf = self;
                [weakSelf hangCall:nil];
            }];
        }
    }];
}

- (IBAction)enableDisableSpeaker:(UIButton *)sender {
    if (sender.selected) {
        [self disableLoudspeaker];
    } else {
        [self enableLoudspeaker];
    }
    sender.selected = !sender.selected;
}

- (IBAction)hideCall:(UIBarButtonItem *)sender {
    [self removeAllVideoListeners];
    [[NSUserDefaults standardUserDefaults] setBool:self.localPeer.video forKey:@"groupCallLocalVideo"];
    [[NSUserDefaults standardUserDefaults] setBool:self.localPeer.audio forKey:@"groupCallLocalAudio"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableDisableSpeaker.selected forKey:@"groupCallSpeaker"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.timer invalidate];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Public

- (void)tapOnVideoCallkitWhenDeviceIsLocked {
    self.enableDisableVideoButton.selected = NO;
    [self enableDisableVideo:self.enableDisableVideoButton];
    self.call = [[MEGASdkManager sharedMEGAChatSdk] chatCallForChatId:self.chatRoom.chatId];
    self.localPeer.video = YES;
}

#pragma mark - Private

- (void)configureNavigation {
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.participantsView];

    if (@available(iOS 11.0, *)) {
        [self initNavigationTitleViews];
        [self instantiateNavigationTitle];
        [self customNavigationBarLabel];
    } else {
        [self.navigationItem setTitleView:[Helper customNavigationBarLabelWithTitle:self.chatRoom.title subtitle:AMLocalizedString(@"connecting", nil)]];
        [self.navigationItem.titleView sizeToFit];
    }
    
    [UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[MEGANavigationController.class]].barTintColor = UIColor.mnz_black151412_09;
    
    [self updateParticipants];
}

- (void)initNavigationTitleViews {
    self.navigationTitleLabel = [[UILabel alloc] init];
    self.navigationTitleLabel.font = [UIFont mnz_SFUISemiBoldWithSize:15];
    self.navigationTitleLabel.textColor = UIColor.whiteColor;
    
    self.navigationSubtitleLabel = [[UILabel alloc] init];
    self.navigationSubtitleLabel.font = [UIFont mnz_SFUIRegularWithSize:12];
    self.navigationSubtitleLabel.textColor = UIColor.mnz_grayE3E3E3;
}

- (void)instantiateNavigationTitle {
    float leftBarButtonsWidth = 24 + 44; //24 is by the margins, 44 the hide button
    
    self.navigationView = [[UIView alloc] initWithFrame:CGRectMake(0, 4, self.navigationController.navigationBar.bounds.size.width - leftBarButtonsWidth - self.participantsView.frame.size.width, 36)];
    self.navigationView.clipsToBounds = YES;
    self.navigationView.userInteractionEnabled = YES;
    [self.navigationItem setTitleView:self.navigationView];
    
    [[self.navigationView.widthAnchor constraintEqualToConstant:self.navigationItem.titleView.bounds.size.width] setActive:YES];
    [[self.navigationView.heightAnchor constraintEqualToConstant:self.navigationItem.titleView.bounds.size.height] setActive:YES];
    
    UIStackView *mainStackView = [[UIStackView alloc] init];
    mainStackView.distribution = UIStackViewDistributionEqualSpacing;
    mainStackView.alignment = UIStackViewAlignmentLeading;
    mainStackView.translatesAutoresizingMaskIntoConstraints = false;
    mainStackView.spacing = 4;
    mainStackView.axis = UILayoutConstraintAxisVertical;
    [mainStackView addArrangedSubview:self.navigationTitleLabel];
    [mainStackView addArrangedSubview:self.navigationSubtitleLabel];
    [self.navigationView addSubview:mainStackView];
    
    [[mainStackView.trailingAnchor constraintEqualToAnchor:self.navigationView.trailingAnchor] setActive:YES];
    [[mainStackView.leadingAnchor constraintEqualToAnchor:self.navigationView.leadingAnchor] setActive:YES];
    [[mainStackView.topAnchor constraintEqualToAnchor:self.navigationView.topAnchor] setActive:YES];
    [[mainStackView.bottomAnchor constraintEqualToAnchor:self.navigationView.bottomAnchor] setActive:YES];
}

- (void)customNavigationBarLabel {
    NSString *groupCallTitle = self.chatRoom.title;
    NSString *groupCallDuration;
    
    switch (self.callType) {
        case CallTypeActive:
            groupCallDuration = @"";
            break;
            
        case CallTypeOutgoing:
            groupCallDuration = AMLocalizedString(@"calling...", @"Label shown when you call someone (outgoing call), before the call starts.");
            break;
            
        case CallTypeIncoming:
            groupCallDuration = AMLocalizedString(@"connecting", nil);
            break;
            
        default:
            break;
    }
    
    if (@available(iOS 11.0, *)) {
        self.navigationTitleLabel.text = groupCallTitle;
        self.navigationSubtitleLabel.text = groupCallDuration;
    } else {
        [self.navigationItem setTitleView:[Helper customNavigationBarLabelWithTitle:groupCallTitle subtitle:groupCallDuration]];
        [self.navigationItem.titleView sizeToFit];
    }
}

- (void)configureControlsForLocalUser:(MEGAGroupCallPeer *)localUser {
    
    self.enableDisableVideoButton.selected = localUser.video;
    self.muteUnmuteMicrophone.selected = !localUser.audio;
    self.enableDisableSpeaker.selected = [[NSUserDefaults standardUserDefaults] objectForKey:@"groupCallSpeaker"] ? [[NSUserDefaults standardUserDefaults] boolForKey:@"groupCallSpeaker"] : self.videoCall;
    
    if (self.enableDisableSpeaker.selected) {
        [self enableLoudspeaker];
    } else {
        [self disableLoudspeaker];
    }
}

- (void)initDataSource {
    self.peersInCall = [NSMutableArray new];
    self.localPeer = [MEGAGroupCallPeer new];
    self.localPeer.video = [[NSUserDefaults standardUserDefaults] objectForKey:@"groupCallLocalVideo"] ? [[NSUserDefaults standardUserDefaults] boolForKey:@"groupCallLocalVideo"] : self.videoCall;
    self.localPeer.audio = [[NSUserDefaults standardUserDefaults] objectForKey:@"groupCallLocalAudio"] ? [[NSUserDefaults standardUserDefaults] boolForKey:@"groupCallLocalAudio"] : YES;
    self.localPeer.peerId = 0;
    self.localPeer.clientId = 0;
    [self.peersInCall addObject:self.localPeer];
    
    [self configureControlsForLocalUser:self.localPeer];
    
    self.peerManualMode = nil;
    self.lastPeerTalking = nil;
    self.peerTalkingVideoView.group = YES;
    
    [[UIDevice currentDevice] setProximityMonitoringEnabled:!self.localPeer.video];
}

- (void)didSessionRouteChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.volumeContainerView.hidden) { //wireless device available
            NSDictionary *interuptionDict = notification.userInfo;
            const NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
            NSLog(@"didSessionRouteChange routeChangeReason: %ld", (long)routeChangeReason);
            
            switch (routeChangeReason) {
                case AVAudioSessionRouteChangeReasonRouteConfigurationChange: //From wireless device to regular speaker
                    [self.mpVolumeView setRouteButtonImage:[UIImage imageNamed:@"speakerOff"] forState:UIControlStateNormal];
                    break;
                    
                case AVAudioSessionRouteChangeReasonCategoryChange:
                    if (self.call.status == MEGAChatCallStatusInProgress) { //From speaker to regular speaker
                        [self.mpVolumeView setRouteButtonImage:[UIImage imageNamed:@"speakerOff"] forState:UIControlStateNormal];
                    } else { //Wireless device when start a call and it was previously connected
                        [self.mpVolumeView setRouteButtonImage:[UIImage imageNamed:@"audioSourceActive"] forState:UIControlStateNormal];
                    }
                    break;
                    
                case AVAudioSessionRouteChangeReasonOverride: //From regular speaker or wireless device to speaker
                    [self.mpVolumeView setRouteButtonImage:[UIImage imageNamed:@"speakerOn"] forState:UIControlStateNormal];
                    break;
                    
                case AVAudioSessionRouteChangeReasonNewDeviceAvailable: //To a wireless device
                    [self.mpVolumeView setRouteButtonImage:[UIImage imageNamed:@"audioSourceActive"] forState:UIControlStateNormal];
                    break;
                    
                default:
                    break;
            }
        }
    });
}

- (void)didWirelessRoutesAvailableChange:(NSNotification *)notification {
    MPVolumeView* volumeView = (MPVolumeView*)notification.object;
    if (volumeView.areWirelessRoutesAvailable) {
        self.volumeContainerView.hidden = NO;
        self.enableDisableSpeaker.hidden = YES;
    } else {
        self.enableDisableSpeaker.hidden = NO;
        self.volumeContainerView.hidden = YES;
    }
}

- (void)enableLoudspeaker {
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
}

- (void)disableLoudspeaker {
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
}

- (void)updateDuration {
    NSTimeInterval interval = ([NSDate date].timeIntervalSince1970 - self.baseDate.timeIntervalSince1970 + self.initDuration);
    if (@available(iOS 11.0, *)) {
        self.navigationSubtitleLabel.text = [NSString mnz_stringFromTimeInterval:interval];
    } else {
        self.navigationItem.titleView =  [Helper customNavigationBarLabelWithTitle:self.chatRoom.title subtitle:[NSString mnz_stringFromTimeInterval:interval]];
        [self.navigationItem.titleView sizeToFit];
    }
}

- (void)updateParticipants {
    self.participantsLabel.text = [NSString stringWithFormat:@"%tu/%tu", [self participantsWithVideo], [MEGASdkManager sharedMEGAChatSdk].getMaxVideoCallParticipants];
}

- (NSInteger)participantsWithVideo {
    NSInteger videos = 0;
    for (MEGAGroupCallPeer *peer in self.peersInCall) {
        if (peer.video == CallPeerVideoOn) {
            videos = videos + 1;
        }
    }
    return videos;
}

- (void)shouldChangeCallLayout {
    if (self.call.numParticipants < kSmallPeersLayout) {
        self.manualMode = NO;
        self.peerManualMode = nil;
        if (!self.peerTalkingView.hidden) {
            [self removeAllVideoListeners];
            NSUInteger previousPeerIndex = [self.peersInCall indexOfObject:self.lastPeerTalking];
            GroupCallCollectionViewCell *cell = (GroupCallCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:previousPeerIndex inSection:0]];
            [cell hideUserOnFocus];
            self.peerTalkingView.hidden = YES;
            [UIView animateWithDuration:0.3f animations:^{
                self.peerTalkingViewHeightConstraint.constant = 0;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.3f animations:^{
                    self.collectionViewBottomConstraint.constant = 0;
                    self.collectionView.userInteractionEnabled = NO;
                } completion:^(BOOL finished) {
                    [self.collectionView reloadData];
                    MEGALogDebug(@"[Group Call] Reload data %s", __PRETTY_FUNCTION__);
                    [self hideSpinner];
                }];
            }];
        }
    } else {
        if (self.peerTalkingView.hidden) {
            [self removeAllVideoListeners];
            MEGAGroupCallPeer *firstPeer = [self.peersInCall objectAtIndex:0];
            [self configureUserOnFocus:firstPeer manual:NO];
            [self.peerTalkingImageView mnz_setImageForUserHandle:firstPeer.peerId name:firstPeer.name];
            self.peerTalkingView.hidden = NO;
            UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
            if (orientation == UIInterfaceOrientationPortrait) {
                [UIView animateWithDuration:0.3f animations:^{
                    self.peerTalkingViewHeightConstraint.constant = self.collectionView.frame.size.width;
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:0.3f animations:^{
                        self.collectionViewBottomConstraint.constant = 80 - self.collectionView.frame.size.height;
                        self.collectionView.userInteractionEnabled = YES;
                    } completion:^(BOOL finished) {
                        [self.collectionView reloadData];
                        MEGALogDebug(@"[Group Call] Reload data %s", __PRETTY_FUNCTION__);
                    }];
                }];
            } else {
                [UIView animateWithDuration:0.3f animations:^{
                    self.peerTalkingViewHeightConstraint.constant =  self.collectionView.frame.size.height - 80;
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:0.3f animations:^{
                        self.collectionViewBottomConstraint.constant = 0;
                        self.collectionView.userInteractionEnabled = YES;
                    } completion:^(BOOL finished) {
                        [self.collectionView reloadData];
                        MEGALogDebug(@"[Group Call] Reload data %s", __PRETTY_FUNCTION__);
                    }];
                }];
            }
            
        }
    }
    if (self.shouldHideAcivity) {
        [self hideSpinner];
    }
}

- (void)removeAllVideoListeners {
    for (GroupCallCollectionViewCell *cell in self.collectionView.visibleCells) {
        if (!cell.videoImageView.hidden) {
            NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
            MEGAGroupCallPeer *peer = [self.peersInCall objectAtIndex:indexPath.item];
            if (peer.peerId != 0) {
                [cell removeRemoteVideoForPeer:peer inChat:self.chatRoom.chatId];
            } else {
                [cell removeLocalVideoInChat:self.chatRoom.chatId];
            }
        }
    }
    
    MEGAGroupCallPeer *previousPeerSelected = self.manualMode ? self.peerManualMode : self.lastPeerTalking;
    if (!self.peerTalkingVideoView.hidden && previousPeerSelected) {
        [[MEGASdkManager sharedMEGAChatSdk] removeChatRemoteVideo:self.chatRoom.chatId peerId:previousPeerSelected.peerId cliendId:previousPeerSelected.clientId delegate:self.peerTalkingVideoView];
        MEGALogDebug(@"[Group Call] Remove user focused remote video %p for peer %llu in client %llu --> %s", self.peerTalkingVideoView, previousPeerSelected.peerId, previousPeerSelected.clientId, __PRETTY_FUNCTION__);
    }
}

- (void)showOrHideControls {
    [UIView animateWithDuration:0.3f animations:^{
        if (self.outgoingCallView.alpha != 1.0f) {
            [self.outgoingCallView setAlpha:1.0f];
            [UIView animateWithDuration:0.25 animations:^{
                [self setNeedsStatusBarAppearanceUpdate];
            }];
        } else {
            [self.outgoingCallView setAlpha:0.0f];
            [UIView animateWithDuration:0.25 animations:^{
                [self setNeedsStatusBarAppearanceUpdate];
            }];
        }
        
        [self.view layoutIfNeeded];
    }];
}

- (void)enablePasscodeIfNeeded {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"presentPasscodeLater"] && [LTHPasscodeViewController doesPasscodeExist]) {
        [[LTHPasscodeViewController sharedUser] showLockScreenOver:UIApplication.mnz_visibleViewController.view
                                                     withAnimation:YES
                                                        withLogout:NO
                                                    andLogoutTitle:nil];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"presentPasscodeLater"];
    }
    [[LTHPasscodeViewController sharedUser] enablePasscodeWhenApplicationEntersBackground];
}

- (void)showToastMessage:(NSString *)message color:(NSString *)color {
    self.toastTopConstraint.constant = -22;
    self.toastLabel.text = message;
    self.toastView.backgroundColor = [UIColor colorFromHexString:color];
    self.toastView.hidden = NO;
    
    [UIView animateWithDuration:.25 animations:^{
        self.toastTopConstraint.constant = 0;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.toastView.hidden = YES;
            self.toastTopConstraint.constant = -22;
            self.toastLabel.text = @"";
        });
    }];
}

- (void)initDurationTimer {
    self.initDuration = (NSInteger)self.call.duration;
    self.timer = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(updateDuration) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    self.baseDate = [NSDate date];
}

- (void)initShowHideControls {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //Add Tap to hide/show controls
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showOrHideControls)];
        tapGestureRecognizer.numberOfTapsRequired = 1;
        tapGestureRecognizer.cancelsTouchesInView = NO;
        tapGestureRecognizer.delegate = self;
        [self.view addGestureRecognizer:tapGestureRecognizer];
        
        [self showOrHideControls];
    });
}

- (void)playCallingSound {
    if (@available(iOS 10.0, *)) {} else {
        NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:@"incoming_voice_video_call" ofType:@"mp3"];
        NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
        
        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
        self.player.numberOfLoops = -1; //Infinite
        
        [self.player play];
    }
}

- (MEGAGroupCallPeer *)peerForSession:(MEGAChatSession *)session {
    for (MEGAGroupCallPeer *peer in self.peersInCall) {
        if (peer.peerId == session.peerId && peer.clientId == session.clientId) {
            return peer;
        }
    }
    return nil;
}

- (MEGAGroupCallPeer *)peerForPeerId:(uint64_t)peerId clientId:(uint64_t)clientId {
    for (int i = 0; i < self.peersInCall.count; i++) {
        MEGAGroupCallPeer *peer = self.peersInCall[i];
        if (peerId == peer.peerId && clientId == peer.clientId) {
            return peer;
        }
    }
    return nil;
}

- (void)deleteActiveCallFlags {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"groupCallLocalVideo"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"groupCallLocalAudio"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"groupCallSpeaker"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)configureInitialUI {
    if (!self.timer.isValid) {
        [self.player stop];
        [self initDurationTimer];
        [self initShowHideControls];
        [self updateParticipants];
    }
}

- (void)instantiatePeersInCall {
    for (int i = 0; i < self.call.sessionsPeerId.size; i ++) {
        uint64_t peerId = [self.call.sessionsPeerId megaHandleAtIndex:i];
        uint64_t clientId = [self.call.sessionsClientId megaHandleAtIndex:i];
        MEGAChatSession *chatSession = [self.call sessionForPeer:peerId clientId:clientId];
        MEGAGroupCallPeer *remoteUser = [[MEGAGroupCallPeer alloc] initWithSession:chatSession];
        [self.peersInCall insertObject:remoteUser atIndex:0];
    }
    if (self.call.numParticipants >= kSmallPeersLayout) {
        [self showSpinner];
        self.shouldHideAcivity = YES;
        [self configureUserOnFocus:[self.peersInCall objectAtIndex:0] manual:NO];
    }
    self.incomingCallView.hidden = YES;
    [self initDurationTimer];
    [self initShowHideControls];
    [self updateParticipants];
    [self.collectionView reloadData];
    MEGALogDebug(@"[Group Call] Reload data %s", __PRETTY_FUNCTION__);
}

- (void)joinActiveCall {
    __weak __typeof(self) weakSelf = self;
    
    [self deleteActiveCallFlags];
    
    MEGAChatStartCallRequestDelegate *startCallRequestDelegate = [[MEGAChatStartCallRequestDelegate alloc] initWithCompletion:^(MEGAChatError *error) {
        if (error.type) {
            [weakSelf dismissViewControllerAnimated:YES completion:^{
                if (error.type == MEGAChatErrorTooMany) {
                    [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"Error. No more participants are allowed in this group call.", @"Message show when a call cannot be established because there are too many participants in the group call")];
                }
            }];
        } else {
            [self initDataSource];
            weakSelf.call = [[MEGASdkManager sharedMEGAChatSdk] chatCallForChatId:weakSelf.chatRoom.chatId];
            weakSelf.incomingCallView.hidden = YES;
            if (self.call.numParticipants >= kSmallPeersLayout) {
                [self showSpinner];
                [self configureUserOnFocus:[self.peersInCall objectAtIndex:0] manual:NO];
            }
            [self initDurationTimer];
            [self initShowHideControls];
            [self updateParticipants];
        }
    }];
    
    [[MEGASdkManager sharedMEGAChatSdk] startChatCall:self.chatRoom.chatId enableVideo:self.videoCall delegate:startCallRequestDelegate];
}

- (void)startOutgoingCall {
    __weak __typeof(self) weakSelf = self;
    
    MEGAChatStartCallRequestDelegate *startCallRequestDelegate = [[MEGAChatStartCallRequestDelegate alloc] initWithCompletion:^(MEGAChatError *error) {
        if (error.type) {
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        } else {
            weakSelf.call = [[MEGASdkManager sharedMEGAChatSdk] chatCallForChatId:weakSelf.chatRoom.chatId];
            weakSelf.incomingCallView.hidden = YES;
            
            if (@available(iOS 10.0, *)) {
                NSUUID *uuid = [[NSUUID alloc] init];
                weakSelf.call.uuid = uuid;
                [weakSelf.megaCallManager addCall:weakSelf.call];
                
                uint64_t peerHandle = [weakSelf.chatRoom peerHandleAtIndex:0];
                NSString *peerEmail = [weakSelf.chatRoom peerEmailByHandle:peerHandle];
                [weakSelf.megaCallManager startCall:weakSelf.call email:peerEmail];
            }
            
            [self.collectionView reloadData];
            MEGALogDebug(@"[Group Call] Reload data %s", __PRETTY_FUNCTION__);
            [self playCallingSound];
        }
    }];
    
    [[MEGASdkManager sharedMEGAChatSdk] startChatCall:self.chatRoom.chatId enableVideo:self.videoCall delegate:startCallRequestDelegate];
}

- (void)showIncomingCall {
    self.outgoingCallView.hidden = YES;
    if (@available(iOS 10.0, *)) {
        [self acceptCall:nil];
    } else {
        _call = [[MEGASdkManager sharedMEGAChatSdk] chatCallForChatId:self.chatRoom.chatId];
    }
    [self playCallingSound];
}

- (void)configureUserOnFocus:(MEGAGroupCallPeer *)peerSelected manual:(BOOL)manual {
    //if previous manual selected participant has video, remove it
    MEGAGroupCallPeer *previousPeerSelected = self.manualMode ? self.peerManualMode : self.lastPeerTalking;
    if (previousPeerSelected && !self.peerTalkingVideoView.hidden) {
        [[MEGASdkManager sharedMEGAChatSdk] removeChatRemoteVideo:self.chatRoom.chatId peerId:previousPeerSelected.peerId cliendId:previousPeerSelected.clientId delegate:self.peerTalkingVideoView];
        MEGALogDebug(@"[Group Call] Remove user focused remote video %p for peer %llu in client %llu --> %s", self.peerTalkingVideoView, previousPeerSelected.peerId, previousPeerSelected.clientId, __PRETTY_FUNCTION__);
    }
    
    self.manualMode = manual;
    
    //show border stroke of manual selected participant
    if (self.manualMode) {
        self.peerManualMode = peerSelected;
        NSUInteger peerIndex = [self.peersInCall indexOfObject:[self peerForPeerId:self.peerManualMode.peerId clientId:self.peerManualMode.clientId]];
        GroupCallCollectionViewCell *cell = (GroupCallCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:peerIndex inSection:0]];
        [cell showUserOnFocus];
    }
    
    //configure large view for manual selected participant
    MEGAChatSession *chatSessionManualMode = [self.call sessionForPeer:self.peerManualMode.peerId clientId:self.peerManualMode.clientId];
    if (chatSessionManualMode.hasVideo) {
        [[MEGASdkManager sharedMEGAChatSdk] addChatRemoteVideo:self.chatRoom.chatId peerId:chatSessionManualMode.peerId cliendId:chatSessionManualMode.clientId  delegate:self.peerTalkingVideoView];
        MEGALogDebug(@"[Group Call] Add user focused remote video %p for peer %llu in client %llu --> %s", self.peerTalkingVideoView, chatSessionManualMode.peerId, chatSessionManualMode.clientId, __PRETTY_FUNCTION__);
        self.peerTalkingVideoView.hidden = NO;
        self.peerTalkingImageView.hidden = YES;
    } else {
        [self.peerTalkingImageView mnz_setImageForUserHandle:self.peerManualMode.peerId name:self.peerManualMode.name];
        self.peerTalkingVideoView.hidden = YES;
        self.peerTalkingImageView.hidden = NO;
    }
    self.peerTalkingMuteView.hidden = chatSessionManualMode.hasAudio;
    self.peerTalkingQualityView.hidden = chatSessionManualMode.networkQuality < 2;
}

- (void)showSpinner {
    [self.collectionActivity startAnimating];
    self.collectionView.alpha = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.collectionActivity.animating) {
            MEGALogDebug(@"GROUPCALL forcing hide spinner");
            [self hideSpinner];
            [self.collectionView reloadData];
            MEGALogDebug(@"[Group Call] Reload data %s", __PRETTY_FUNCTION__);
        }
    });
}

- (void)hideSpinner {
    [self.collectionActivity stopAnimating];
    self.collectionView.alpha = 1;
}

#pragma mark - MEGAChatCallDelegate

- (void)onChatCallUpdate:(MEGAChatSdk *)api call:(MEGAChatCall *)call {
    MEGALogDebug(@"onChatCallUpdate %@", call);
    
    if (self.call.callId == call.callId) {
        self.call = call;
    } else {
        return;
    }
    
    switch (call.status) {
            
        case MEGAChatCallStatusInProgress: {
            
            if ([call hasChangedForType:MEGAChatCallChangeTypeRemoteAVFlags]) {

                MEGAChatSession *chatSessionWithAVFlags = [call sessionForPeer:call.peerSessionStatusChange clientId:call.clientSessionStatusChange];
                
                MEGAGroupCallPeer *peerAVFlagsChanged = [self peerForSession:chatSessionWithAVFlags];

                if (peerAVFlagsChanged) {
                    NSUInteger index = [self.peersInCall indexOfObject:peerAVFlagsChanged];
                    GroupCallCollectionViewCell *cell = (GroupCallCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
                    
                    if (peerAVFlagsChanged.video != chatSessionWithAVFlags.hasVideo) {
                        peerAVFlagsChanged.video = chatSessionWithAVFlags.hasVideo;
                        if (peerAVFlagsChanged.video) {
                            if (cell.videoImageView.hidden) {
                                [cell addRemoteVideoForPeer:peerAVFlagsChanged inChat:self.chatRoom.chatId];
                            }
                        } else {
                            if (!cell.videoImageView.hidden) {
                                [cell removeRemoteVideoForPeer:peerAVFlagsChanged inChat:self.chatRoom.chatId];
                            }
                        }
                        if (self.manualMode && [self.peerManualMode isEqualToPeer:peerAVFlagsChanged]) {
                            if (peerAVFlagsChanged.video) {
                                [[MEGASdkManager sharedMEGAChatSdk] addChatRemoteVideo:self.chatRoom.chatId peerId:peerAVFlagsChanged.peerId cliendId:peerAVFlagsChanged.clientId delegate:self.peerTalkingVideoView];
                                MEGALogDebug(@"[Group Call] Add user focused remote video %p for peer %llu in client %llu --> %s", self.peerTalkingVideoView, peerAVFlagsChanged.peerId, peerAVFlagsChanged.clientId, __PRETTY_FUNCTION__);
                                self.peerTalkingVideoView.hidden = NO;
                                self.peerTalkingImageView.hidden = YES;
                            } else {
                                [self.peerTalkingImageView mnz_setImageForUserHandle:peerAVFlagsChanged.peerId name:peerAVFlagsChanged.name];
                                self.peerTalkingVideoView.hidden = YES;
                                self.peerTalkingImageView.hidden = NO;
                            }
                            self.peerTalkingMuteView.hidden = peerAVFlagsChanged.audio;
                            self.peerTalkingQualityView.hidden = peerAVFlagsChanged.networkQuality < 2;
                        }
                        [self updateParticipants];
                    }
                    
                    if (peerAVFlagsChanged.audio != chatSessionWithAVFlags.hasAudio) {
                        peerAVFlagsChanged.audio = chatSessionWithAVFlags.hasAudio;
                        [cell configureUserAudio:peerAVFlagsChanged.audio];
                        MEGAGroupCallPeer *previousPeerSelected = self.manualMode ? self.peerManualMode : self.lastPeerTalking;
                        if ([previousPeerSelected isEqualToPeer:[self peerForSession:chatSessionWithAVFlags]]) {
                            self.peerTalkingMuteView.hidden = peerAVFlagsChanged.audio;
                        }
                    }
                } else {
                    MEGALogDebug(@"GROUPCALL session changed AV flags for remote peer %llu not found", chatSessionWithAVFlags.peerId);
                }
            }
            
            if ([call hasChangedForType:MEGAChatCallChangeTypeAudioLevel] && call.numParticipants >= kSmallPeersLayout && !self.isManualMode) {
                MEGAChatSession *chatSessionWithAudioLevel = [call sessionForPeer:call.peerSessionStatusChange clientId:call.clientSessionStatusChange];
                
                if (chatSessionWithAudioLevel.audioDetected) {
                    if (self.lastPeerTalking.peerId != chatSessionWithAudioLevel.peerId) {
                        if (!self.peerTalkingVideoView.hidden) {
                            [[MEGASdkManager sharedMEGAChatSdk] removeChatRemoteVideo:self.chatRoom.chatId peerId:self.lastPeerTalking.peerId cliendId:self.lastPeerTalking.clientId delegate:self.peerTalkingVideoView];
                            MEGALogDebug(@"[Group Call] Remove user focused remote video %p for peer %llu in client %llu --> %s", self.peerTalkingVideoView, chatSessionWithAudioLevel.peerId, chatSessionWithAudioLevel.clientId, __PRETTY_FUNCTION__);
                        }
                        
                        if (chatSessionWithAudioLevel.hasVideo) {
                            [[MEGASdkManager sharedMEGAChatSdk] addChatRemoteVideo:self.chatRoom.chatId peerId:chatSessionWithAudioLevel.peerId cliendId:chatSessionWithAudioLevel.clientId delegate:self.peerTalkingVideoView];
                            MEGALogDebug(@"[Group Call] Add user focused remote video %p for peer %llu in client %llu --> %s", self.peerTalkingVideoView, chatSessionWithAudioLevel.peerId, chatSessionWithAudioLevel.clientId, __PRETTY_FUNCTION__);
                            self.peerTalkingVideoView.hidden = NO;
                            self.peerTalkingImageView.hidden = YES;
                        } else {
                            [self.peerTalkingImageView mnz_setImageForUserHandle:chatSessionWithAudioLevel.peerId name:[self.chatRoom peerFullnameByHandle:chatSessionWithAudioLevel.peerId]];
                            self.peerTalkingVideoView.hidden = YES;
                            self.peerTalkingImageView.hidden = NO;
                        }
                        self.lastPeerTalking = [[MEGAGroupCallPeer alloc] initWithSession:chatSessionWithAudioLevel];
                    }
                    
                    self.peerTalkingMuteView.hidden = chatSessionWithAudioLevel.hasAudio;
                    self.peerTalkingQualityView.hidden = chatSessionWithAudioLevel.networkQuality < 2;
                }
            }
            
            if ([call hasChangedForType:MEGAChatCallChangeTypeNetworkQuality]) {
                
                MEGAChatSession *chatSessionWithNetworkQuality = [call sessionForPeer:call.peerSessionStatusChange clientId:call.clientSessionStatusChange];
                
                MEGAGroupCallPeer *peerNetworkQuality = [self peerForSession:chatSessionWithNetworkQuality];
                
                if (peerNetworkQuality) {
                    peerNetworkQuality.networkQuality = chatSessionWithNetworkQuality.networkQuality;
                    NSUInteger index = [self.peersInCall indexOfObject:peerNetworkQuality];
                    GroupCallCollectionViewCell *cell = (GroupCallCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
                    
                    [cell networkQualityChangedForPeer:peerNetworkQuality];
                } else {
                    MEGALogDebug(@"GROUPCALL session network quality changed for peer %llu not found", chatSessionWithNetworkQuality.peerId);
                }
                
                if (chatSessionWithNetworkQuality.networkQuality < 2) {
                    [self showToastMessage:AMLocalizedString(@"Poor conection.", @"Message to inform the local user is having a bad quality network with someone in the current group call") color:@"#FFBF00"];
                }
            }
            
            if ([call hasChangedForType:MEGAChatCallChangeTypeSessionStatus]) {
                MEGAChatSession *chatSession = [call sessionForPeer:call.peerSessionStatusChange clientId:call.clientSessionStatusChange];
                MEGALogDebug(@"GROUPCALLACTIVITY MEGAChatCallChangeTypeSessionStatus with call participants: %tu and session status: %tu", call.numParticipants, chatSession.status);
                switch (chatSession.status) {
                    case MEGAChatSessionStatusInitial: {
                        [self configureInitialUI];
                        
                        if (self.peersInCall.count == 6) {
                            [self hideSpinner];
                        }
                        MEGAGroupCallPeer *remoteUser = [[MEGAGroupCallPeer alloc] initWithSession:chatSession];
                        remoteUser.video = CallPeerVideoUnknown;
                        remoteUser.audio = CallPeerAudioUnknown;
                        remoteUser.name = [self.chatRoom peerFullnameByHandle:chatSession.peerId];

                        [self.peersInCall insertObject:remoteUser atIndex:0];
                        
                        [self.collectionView insertItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:0 inSection:0]]];
                        
                        [self showToastMessage:[NSString stringWithFormat:AMLocalizedString(@"%@ joined the call.", @"Message to inform the local user that someone has joined the current group call"), [self.chatRoom peerFullnameByHandle:chatSession.peerId]] color:@"#00BFA5"];
                        [self updateParticipants];
                        
                        break;
                    }
                        
                    case MEGAChatSessionStatusInProgress: {
                        self.outgoingCallView.hidden = NO;
                        self.incomingCallView.hidden = YES;
                        break;
                    }
                        
                    case MEGAChatSessionStatusDestroyed: {
                        
                        MEGAGroupCallPeer *peerDestroyed = [self peerForSession:chatSession];
                        
                        if (peerDestroyed) {
                            if (self.peersInCall.count == 7) {
                                [self showSpinner];
                            }
                            
                            NSUInteger index = [self.peersInCall indexOfObject:peerDestroyed];
                            GroupCallCollectionViewCell *cell = (GroupCallCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
                            if (!cell.videoImageView.hidden) {
                                [cell removeRemoteVideoForPeer:peerDestroyed inChat:self.chatRoom.chatId];
                            }
                            
                            [self.peersInCall removeObject:peerDestroyed];
                            [self.collectionView deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:index inSection:0]]];
                            
                            if (self.call.numParticipants >= kSmallPeersLayout) {
                                MEGAGroupCallPeer *focusedPeer = self.manualMode ? self.peerManualMode : self.lastPeerTalking;
                                if ([focusedPeer isEqualToPeer:peerDestroyed]) {
                                    [self configureUserOnFocus:[self.peersInCall objectAtIndex:0] manual:NO];
                                }
                            }
                            
                            [self showToastMessage:[NSString stringWithFormat:AMLocalizedString(@"%@ left the call.", @"Message to inform the local user that someone has left the current group call"), [self.chatRoom peerFullnameByHandle:chatSession.peerId]] color:@"#00BFA5"];
                            [self updateParticipants];
                        } else {
                            MEGALogDebug(@"GROUPCALL session destroyed for peer %llu not found", chatSession.peerId);
                        }
                        break;
                    }
                        
                    case MEGAChatSessionStatusInvalid:
                        MEGALogDebug(@"MEGAChatSessionStatusInvalid");
                        break;
                }
            }
            
            if ([call hasChangedForType:MEGAChatCallChangeTypeCallComposition]) {
                MEGALogDebug(@"GROUPCALLACTIVITY MEGAChatCallChangeTypeCallComposition with call participants: %tu and peers in call: %tu", call.numParticipants, self.peersInCall.count);
                if (call.numParticipants == 7 && self.peersInCall.count == 6) {
                    [self showSpinner];
                }
                [self shouldChangeCallLayout];
            }
            
            break;
        }
    
        case MEGAChatCallStatusTerminatingUserParticipation:
        case MEGAChatCallStatusDestroyed: {
            self.incomingCallView.userInteractionEnabled = NO;
            
            [self.timer invalidate];

            [self.player stop];
            
            NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:@"hang_out" ofType:@"mp3"];
            NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
            self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
            
            [self.player play];
            
            [self deleteActiveCallFlags];
            
            [self dismissViewControllerAnimated:YES completion:^{
                [self enablePasscodeIfNeeded];
            }];
            break;
        }
                        
        default:
            break;
    }
}

#pragma mark - UITapGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    
    if (touch.view.class == UIButton.class) {
        return NO;
    }
    
    if ((CGRectContainsPoint(self.collectionView.frame, [touch locationInView:self.view]) && self.call.numParticipants >= kSmallPeersLayout)) {
        return NO;
    }
    
    return YES;
}

@end
