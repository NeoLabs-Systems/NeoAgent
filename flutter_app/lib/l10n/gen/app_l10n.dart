import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_de.dart';
import 'app_l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @aBaseUrlIsRequiredFor.
  ///
  /// In en, this message translates to:
  /// **'A base URL is required for this endpoint.'**
  String get aBaseUrlIsRequiredFor;

  /// No description provided for @aChangedEmailAddressIsConfirmed.
  ///
  /// In en, this message translates to:
  /// **'A changed email address is confirmed before it is used.'**
  String get aChangedEmailAddressIsConfirmed;

  /// No description provided for @aDecisionHigherUpTheChain.
  ///
  /// In en, this message translates to:
  /// **'A decision higher up the chain wins.'**
  String get aDecisionHigherUpTheChain;

  /// No description provided for @aDeletedAccount.
  ///
  /// In en, this message translates to:
  /// **'a deleted account'**
  String get aDeletedAccount;

  /// No description provided for @aFractionOfASecondRouting.
  ///
  /// In en, this message translates to:
  /// **'a fraction of a second: routing, tool and skill choice, memory '**
  String get aFractionOfASecondRouting;

  /// No description provided for @aFridayLookBackAtThe.
  ///
  /// In en, this message translates to:
  /// **'A Friday look back at the week and a plan for the next.'**
  String get aFridayLookBackAtThe;

  /// No description provided for @aKeyThatAsksForA.
  ///
  /// In en, this message translates to:
  /// **'A key that asks for a PIN or fingerprint also replaces your two-factor code.'**
  String get aKeyThatAsksForA;

  /// No description provided for @aLanguageModelJudgedThisMessage.
  ///
  /// In en, this message translates to:
  /// **'A language model judged this message because JEV is off.'**
  String get aLanguageModelJudgedThisMessage;

  /// No description provided for @aNeoagentSetupMetadataFileExceeded.
  ///
  /// In en, this message translates to:
  /// **'A NeoAgent setup metadata file exceeded its safe size limit.'**
  String get aNeoagentSetupMetadataFileExceeded;

  /// No description provided for @aNewerWebBuildIsAvailable.
  ///
  /// In en, this message translates to:
  /// **'A newer web build is available on the server. Reload to fetch the latest bundle.'**
  String get aNewerWebBuildIsAvailable;

  /// No description provided for @aPlanSIdCanT.
  ///
  /// In en, this message translates to:
  /// **'A plan’s ID can’t change.'**
  String get aPlanSIdCanT;

  /// No description provided for @aPrivateDesktopWithChromiumFiles.
  ///
  /// In en, this message translates to:
  /// **'A private desktop with Chromium, files, a text editor, terminal and Python. Your work stays saved between sessions.'**
  String get aPrivateDesktopWithChromiumFiles;

  /// No description provided for @aPrivateLinuxComputerOrAn.
  ///
  /// In en, this message translates to:
  /// **'A private Linux computer or an Android device.'**
  String get aPrivateLinuxComputerOrAn;

  /// No description provided for @aRequiredNeoagentSetupFileCould.
  ///
  /// In en, this message translates to:
  /// **'A required NeoAgent setup file could not be downloaded.'**
  String get aRequiredNeoagentSetupFileCould;

  /// No description provided for @aTeammateSendsYouAnInvite.
  ///
  /// In en, this message translates to:
  /// **'A teammate sends you an invite link. Once you accept it, they '**
  String get aTeammateSendsYouAnInvite;

  /// No description provided for @aTeammateSentYouAnInvite.
  ///
  /// In en, this message translates to:
  /// **'a teammate sent you an invite link, enter it here to join their team.'**
  String get aTeammateSentYouAnInvite;

  /// No description provided for @aTemporaryDownloadWillBeCleaned.
  ///
  /// In en, this message translates to:
  /// **'A temporary download will be cleaned up later.'**
  String get aTemporaryDownloadWillBeCleaned;

  /// No description provided for @aValueIsStored.
  ///
  /// In en, this message translates to:
  /// **'A value is stored.'**
  String get aValueIsStored;

  /// No description provided for @aboutUseWhatYouRememberAbout.
  ///
  /// In en, this message translates to:
  /// **'about (use what you remember about my interests). Send me a digest '**
  String get aboutUseWhatYouRememberAbout;

  /// No description provided for @access.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get access;

  /// No description provided for @accessActivity.
  ///
  /// In en, this message translates to:
  /// **'Access activity'**
  String get accessActivity;

  /// No description provided for @accessArg1.
  ///
  /// In en, this message translates to:
  /// **'Access: {arg1}'**
  String accessArg1(Object? arg1);

  /// No description provided for @accessMode.
  ///
  /// In en, this message translates to:
  /// **'Access mode'**
  String get accessMode;

  /// No description provided for @accessPermissions.
  ///
  /// In en, this message translates to:
  /// **'Access permissions'**
  String get accessPermissions;

  /// No description provided for @accessToken.
  ///
  /// In en, this message translates to:
  /// **'access token'**
  String get accessToken;

  /// No description provided for @accessToken2.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get accessToken2;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @accountArg1.
  ///
  /// In en, this message translates to:
  /// **'Account #{arg1}'**
  String accountArg1(Object? arg1);

  /// No description provided for @accountChangeAlerts.
  ///
  /// In en, this message translates to:
  /// **'Account change alerts'**
  String get accountChangeAlerts;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Account email'**
  String get accountEmail;

  /// No description provided for @accountEmailIsOffUntilThese.
  ///
  /// In en, this message translates to:
  /// **'Account email is off until these are set: '**
  String get accountEmailIsOffUntilThese;

  /// No description provided for @accountLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent uses this language everywhere in the app. The first time you sign in, it follows this device. After that, the choice is saved on your account and used on every device.'**
  String get accountLanguageDescription;

  /// No description provided for @accountLanguageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the language: {error}'**
  String accountLanguageFailed(Object? error);

  /// No description provided for @accountLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguageTitle;

  /// No description provided for @accountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get accountNumber;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettings;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @accountsByTokensUsedAllTime.
  ///
  /// In en, this message translates to:
  /// **'Accounts by tokens used, all time.'**
  String get accountsByTokensUsedAllTime;

  /// No description provided for @accountsCloudComputersChangesApplyAfter.
  ///
  /// In en, this message translates to:
  /// **'accounts’ cloud computers. Changes apply after a server '**
  String get accountsCloudComputersChangesApplyAfter;

  /// No description provided for @accountsOnThisServer.
  ///
  /// In en, this message translates to:
  /// **'Accounts on this server'**
  String get accountsOnThisServer;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @activeSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get activeSessions;

  /// No description provided for @activeToday.
  ///
  /// In en, this message translates to:
  /// **'Active today'**
  String get activeToday;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAProviderCredentialFirstIts.
  ///
  /// In en, this message translates to:
  /// **'Add a provider credential first. Its models show up here once '**
  String get addAProviderCredentialFirstIts;

  /// No description provided for @addAgent.
  ///
  /// In en, this message translates to:
  /// **'Add Agent'**
  String get addAgent;

  /// No description provided for @addAnotherSignInMethodBefore.
  ///
  /// In en, this message translates to:
  /// **'Add another sign-in method before removing this one.'**
  String get addAnotherSignInMethodBefore;

  /// No description provided for @addBinding.
  ///
  /// In en, this message translates to:
  /// **'Add binding'**
  String get addBinding;

  /// No description provided for @addByNameOrId.
  ///
  /// In en, this message translates to:
  /// **'Add by name or ID'**
  String get addByNameOrId;

  /// No description provided for @addByNameOrIdInstead.
  ///
  /// In en, this message translates to:
  /// **'Add by name or ID instead'**
  String get addByNameOrIdInstead;

  /// No description provided for @addCredentialBinding.
  ///
  /// In en, this message translates to:
  /// **'Add credential binding'**
  String get addCredentialBinding;

  /// No description provided for @addEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get addEntry;

  /// No description provided for @addKey.
  ///
  /// In en, this message translates to:
  /// **'Add key'**
  String get addKey;

  /// No description provided for @addMcpServer.
  ///
  /// In en, this message translates to:
  /// **'Add MCP server'**
  String get addMcpServer;

  /// No description provided for @addMemory.
  ///
  /// In en, this message translates to:
  /// **'Add Memory'**
  String get addMemory;

  /// No description provided for @addMoreLengthOrAnotherCharacter.
  ///
  /// In en, this message translates to:
  /// **'Add more length or another character type.'**
  String get addMoreLengthOrAnotherCharacter;

  /// No description provided for @addPeopleOrGroups.
  ///
  /// In en, this message translates to:
  /// **'Add people or groups'**
  String get addPeopleOrGroups;

  /// No description provided for @addSecurityKey.
  ///
  /// In en, this message translates to:
  /// **'Add security key'**
  String get addSecurityKey;

  /// No description provided for @addSomeoneOrAGroup.
  ///
  /// In en, this message translates to:
  /// **'Add someone or a group'**
  String get addSomeoneOrAGroup;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTask;

  /// No description provided for @addTests.
  ///
  /// In en, this message translates to:
  /// **'Add tests'**
  String get addTests;

  /// No description provided for @addTestsForThePartsOf.
  ///
  /// In en, this message translates to:
  /// **'Add tests for the parts of this project that have the least coverage, then run them.'**
  String get addTestsForThePartsOf;

  /// No description provided for @addTheirOwnKeysInSettings.
  ///
  /// In en, this message translates to:
  /// **'add their own keys in Settings.'**
  String get addTheirOwnKeysInSettings;

  /// No description provided for @addToPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add to prompt'**
  String get addToPrompt;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @addedArg1LastUsedArg2.
  ///
  /// In en, this message translates to:
  /// **'Added {arg1} · Last used {arg2}'**
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2);

  /// No description provided for @addressWithTheProvider.
  ///
  /// In en, this message translates to:
  /// **'address with the provider.'**
  String get addressWithTheProvider;

  /// No description provided for @adjustSpeakerVolumeReviewHardwareButton.
  ///
  /// In en, this message translates to:
  /// **'Adjust speaker volume, review hardware button defaults, and manage this launcher session.'**
  String get adjustSpeakerVolumeReviewHardwareButton;

  /// No description provided for @adjustTheSearchOrStatusFilter.
  ///
  /// In en, this message translates to:
  /// **'Adjust the search or status filter to see more messaging channels.'**
  String get adjustTheSearchOrStatusFilter;

  /// No description provided for @adjustTheSpeakerVolumeHere.
  ///
  /// In en, this message translates to:
  /// **'Adjust the speaker volume here.'**
  String get adjustTheSpeakerVolumeHere;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @adminArg1.
  ///
  /// In en, this message translates to:
  /// **'Admin › {arg1}'**
  String adminArg1(Object? arg1);

  /// No description provided for @adminGrantsInviteLinksAndManagement.
  ///
  /// In en, this message translates to:
  /// **'Admin grants, invite links and management changes show up here.'**
  String get adminGrantsInviteLinksAndManagement;

  /// No description provided for @advancedManualScheduleForSpecialCases.
  ///
  /// In en, this message translates to:
  /// **'Advanced manual schedule for special cases.'**
  String get advancedManualScheduleForSpecialCases;

  /// No description provided for @advancedMinuteHourDayMonthWeekday.
  ///
  /// In en, this message translates to:
  /// **'Advanced: minute hour day month weekday.'**
  String get advancedMinuteHourDayMonthWeekday;

  /// No description provided for @againRightAway.
  ///
  /// In en, this message translates to:
  /// **'again right away.'**
  String get againRightAway;

  /// No description provided for @agent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agent;

  /// No description provided for @agentArg1.
  ///
  /// In en, this message translates to:
  /// **'Agent: {arg1}'**
  String agentArg1(Object? arg1);

  /// No description provided for @agentCalls.
  ///
  /// In en, this message translates to:
  /// **'Agent Calls'**
  String get agentCalls;

  /// No description provided for @agentCommunication.
  ///
  /// In en, this message translates to:
  /// **'Agent communication'**
  String get agentCommunication;

  /// No description provided for @agentCommunicationArg1.
  ///
  /// In en, this message translates to:
  /// **'Agent communication: {arg1}.'**
  String agentCommunicationArg1(Object? arg1);

  /// No description provided for @agentModeEditsTheWorkspaceSend.
  ///
  /// In en, this message translates to:
  /// **'Agent mode edits the workspace · ⌘↵ send · ⌘N new session'**
  String get agentModeEditsTheWorkspaceSend;

  /// No description provided for @agentPausesAndAsksYouBefore.
  ///
  /// In en, this message translates to:
  /// **'Agent pauses and asks you before running.'**
  String get agentPausesAndAsksYouBefore;

  /// No description provided for @agentProfile.
  ///
  /// In en, this message translates to:
  /// **'Agent profile'**
  String get agentProfile;

  /// No description provided for @agentRuns7d.
  ///
  /// In en, this message translates to:
  /// **'Agent runs (7d)'**
  String get agentRuns7d;

  /// No description provided for @agentVisibleName.
  ///
  /// In en, this message translates to:
  /// **'Agent-visible name'**
  String get agentVisibleName;

  /// No description provided for @agentWantsToUseArg1Tap.
  ///
  /// In en, this message translates to:
  /// **'Agent wants to use {arg1}. Tap to decide.'**
  String agentWantsToUseArg1Tap(Object? arg1);

  /// No description provided for @agents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agents;

  /// No description provided for @aiAnswerUnreadable.
  ///
  /// In en, this message translates to:
  /// **'AI answer unreadable'**
  String get aiAnswerUnreadable;

  /// No description provided for @aiProviderKeys.
  ///
  /// In en, this message translates to:
  /// **'AI provider keys'**
  String get aiProviderKeys;

  /// No description provided for @aiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI unavailable'**
  String get aiUnavailable;

  /// No description provided for @alertsAndOtherAccountEmailFrom.
  ///
  /// In en, this message translates to:
  /// **'alerts and other account email from.'**
  String get alertsAndOtherAccountEmailFrom;

  /// No description provided for @alertsWhenAMessagingConnectionNeeds.
  ///
  /// In en, this message translates to:
  /// **'Alerts when a messaging connection needs user attention'**
  String get alertsWhenAMessagingConnectionNeeds;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allAgentsArg1.
  ///
  /// In en, this message translates to:
  /// **'All agents ({arg1})'**
  String allAgentsArg1(Object? arg1);

  /// No description provided for @allArg1.
  ///
  /// In en, this message translates to:
  /// **'All {arg1}'**
  String allArg1(Object? arg1);

  /// No description provided for @allCloudComputerSlotsAreCurrently.
  ///
  /// In en, this message translates to:
  /// **'All cloud-computer slots are currently in use. Try again in a moment.'**
  String get allCloudComputerSlotsAreCurrently;

  /// No description provided for @allComputerSlotsAreBusy.
  ///
  /// In en, this message translates to:
  /// **'All computer slots are busy'**
  String get allComputerSlotsAreBusy;

  /// No description provided for @allTables.
  ///
  /// In en, this message translates to:
  /// **'All tables'**
  String get allTables;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @allToolsAreAllowedTheAgent.
  ///
  /// In en, this message translates to:
  /// **'All tools are allowed — the agent can use any capability without asking. '**
  String get allToolsAreAllowedTheAgent;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @allowAll.
  ///
  /// In en, this message translates to:
  /// **'Allow all'**
  String get allowAll;

  /// No description provided for @allowInstallUnknownAppsForNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Allow \"Install unknown apps\" for NeoAgent, then retry the update.'**
  String get allowInstallUnknownAppsForNeoagent;

  /// No description provided for @allowNewSignUps.
  ///
  /// In en, this message translates to:
  /// **'Allow new sign-ups'**
  String get allowNewSignUps;

  /// No description provided for @allowOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get allowOnce;

  /// No description provided for @allowSender.
  ///
  /// In en, this message translates to:
  /// **'Allow sender'**
  String get allowSender;

  /// No description provided for @allowSession.
  ///
  /// In en, this message translates to:
  /// **'Allow session'**
  String get allowSession;

  /// No description provided for @allowTheAgentToStartAn.
  ///
  /// In en, this message translates to:
  /// **'Allow the agent to start an in-app voice call with you.'**
  String get allowTheAgentToStartAn;

  /// No description provided for @allowedForThisRunWillAsk.
  ///
  /// In en, this message translates to:
  /// **'Allowed for this run — will ask again next session.'**
  String get allowedForThisRunWillAsk;

  /// No description provided for @allowedModels.
  ///
  /// In en, this message translates to:
  /// **'Allowed models'**
  String get allowedModels;

  /// No description provided for @allowedOrigins.
  ///
  /// In en, this message translates to:
  /// **'Allowed origins'**
  String get allowedOrigins;

  /// No description provided for @allowedPathPrefix.
  ///
  /// In en, this message translates to:
  /// **'Allowed path prefix'**
  String get allowedPathPrefix;

  /// No description provided for @allowsYouCanChangeThatPer.
  ///
  /// In en, this message translates to:
  /// **'allows. You can change that per person later. Links never grant '**
  String get allowsYouCanChangeThatPer;

  /// No description provided for @alreadyBelongsToAnExistingAccount.
  ///
  /// In en, this message translates to:
  /// **'already belongs to an existing account'**
  String get alreadyBelongsToAnExistingAccount;

  /// No description provided for @alreadyLinkedToAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'already linked to another account'**
  String get alreadyLinkedToAnotherAccount;

  /// No description provided for @alreadyLinkedToAnotherNeoagentAccount.
  ///
  /// In en, this message translates to:
  /// **'already linked to another neoagent account'**
  String get alreadyLinkedToAnotherNeoagentAccount;

  /// No description provided for @alreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'already used'**
  String get alreadyUsed;

  /// No description provided for @always.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get always;

  /// No description provided for @alwaysAllow.
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get alwaysAllow;

  /// No description provided for @alwaysAllowSavesThePolicyPermanently.
  ///
  /// In en, this message translates to:
  /// **'\"Always allow\" saves the policy permanently — you can change it in Settings.'**
  String get alwaysAllowSavesThePolicyPermanently;

  /// No description provided for @alwaysAsk.
  ///
  /// In en, this message translates to:
  /// **'Always ask'**
  String get alwaysAsk;

  /// No description provided for @alwaysEngage.
  ///
  /// In en, this message translates to:
  /// **'Always engage'**
  String get alwaysEngage;

  /// No description provided for @alwaysJoins.
  ///
  /// In en, this message translates to:
  /// **'Always joins'**
  String get alwaysJoins;

  /// No description provided for @anApiKeyIsRequired.
  ///
  /// In en, this message translates to:
  /// **'An API key is required.'**
  String get anApiKeyIsRequired;

  /// No description provided for @anEveningSummaryOfWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'An evening summary of what happened and what to follow up on.'**
  String get anEveningSummaryOfWhatHappened;

  /// No description provided for @anHttpOrHttpsUrlIs.
  ///
  /// In en, this message translates to:
  /// **'An http or https URL is required.'**
  String get anHttpOrHttpsUrlIs;

  /// No description provided for @andBillingTeamLinksLiveOn.
  ///
  /// In en, this message translates to:
  /// **'and billing. Team links live on the Team page.'**
  String get andBillingTeamLinksLiveOn;

  /// No description provided for @andBrowserSteps.
  ///
  /// In en, this message translates to:
  /// **'and browser steps. '**
  String get andBrowserSteps;

  /// No description provided for @andBrowserStepsYourChatModel.
  ///
  /// In en, this message translates to:
  /// **'and browser steps. Your chat model still writes every '**
  String get andBrowserStepsYourChatModel;

  /// No description provided for @andSExpiresAtDatetimeNow.
  ///
  /// In en, this message translates to:
  /// **'  AND s.expires_at > datetime(\'\'now\'\')\n'**
  String get andSExpiresAtDatetimeNow;

  /// No description provided for @androidApkInstallIsUnavailableOn.
  ///
  /// In en, this message translates to:
  /// **'Android APK install is unavailable on this platform.'**
  String get androidApkInstallIsUnavailableOn;

  /// No description provided for @androidApp.
  ///
  /// In en, this message translates to:
  /// **'Android app'**
  String get androidApp;

  /// No description provided for @androidControl.
  ///
  /// In en, this message translates to:
  /// **'Android Control'**
  String get androidControl;

  /// No description provided for @androidCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Android could not start'**
  String get androidCouldNotStart;

  /// No description provided for @androidNotificationReceived.
  ///
  /// In en, this message translates to:
  /// **'Android Notification Received'**
  String get androidNotificationReceived;

  /// No description provided for @androidOnly.
  ///
  /// In en, this message translates to:
  /// **'Android only'**
  String get androidOnly;

  /// No description provided for @androidPackageInstallerCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'Android package installer could not be opened.'**
  String get androidPackageInstallerCouldNotBe;

  /// No description provided for @androidScreenTapToTouchDrag.
  ///
  /// In en, this message translates to:
  /// **'Android screen — tap to touch, drag to swipe'**
  String get androidScreenTapToTouchDrag;

  /// No description provided for @androidSdk.
  ///
  /// In en, this message translates to:
  /// **'android sdk'**
  String get androidSdk;

  /// No description provided for @answersMentionsOnIssuesAndPull.
  ///
  /// In en, this message translates to:
  /// **'Answers @mentions on issues and pull requests'**
  String get answersMentionsOnIssuesAndPull;

  /// No description provided for @anyone.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get anyone;

  /// No description provided for @anyoneOnThisPlatformCanMessage.
  ///
  /// In en, this message translates to:
  /// **'Anyone on this platform can message {arg1}'**
  String anyoneOnThisPlatformCanMessage(Object? arg1);

  /// No description provided for @anyoneOnThisPlatformCanMessage2.
  ///
  /// In en, this message translates to:
  /// **'Anyone on this platform can message {arg1} in {arg2}.'**
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2);

  /// No description provided for @anyoneWhoCanReachThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Anyone who can reach this account can talk to {arg1}.'**
  String anyoneWhoCanReachThisAccount(Object? arg1);

  /// No description provided for @anyoneWithTheLinkCanJoin.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the link can join until it expires or you revoke it.'**
  String get anyoneWithTheLinkCanJoin;

  /// No description provided for @anyoneYouAllowCanChatWith.
  ///
  /// In en, this message translates to:
  /// **'Anyone you allow can chat with it, in direct chats and groups.'**
  String get anyoneYouAllowCanChatWith;

  /// No description provided for @apiHttpsOrigin.
  ///
  /// In en, this message translates to:
  /// **'API HTTPS origin'**
  String get apiHttpsOrigin;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKey;

  /// No description provided for @apiKey2.
  ///
  /// In en, this message translates to:
  /// **'api key'**
  String get apiKey2;

  /// No description provided for @apiKey3.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey3;

  /// No description provided for @apiKeyAnthropicClaudeOpenaiGpt.
  ///
  /// In en, this message translates to:
  /// **'api key anthropic claude openai gpt xai grok google gemini minimax nvidia nim openrouter credentials'**
  String get apiKeyAnthropicClaudeOpenaiGpt;

  /// No description provided for @apiKeysAndEndpointsForAi.
  ///
  /// In en, this message translates to:
  /// **'API keys and endpoints for AI, search and voice providers. They '**
  String get apiKeysAndEndpointsForAi;

  /// No description provided for @apiRequest.
  ///
  /// In en, this message translates to:
  /// **'API request'**
  String get apiRequest;

  /// No description provided for @apiYourOwnServerASelf.
  ///
  /// In en, this message translates to:
  /// **'API -- your own server, a self-hosted model, or another '**
  String get apiYourOwnServerASelf;

  /// No description provided for @apkDownloadFailedWithHttpArg1.
  ///
  /// In en, this message translates to:
  /// **'APK download failed with HTTP {arg1}.'**
  String apkDownloadFailedWithHttpArg1(Object? arg1);

  /// No description provided for @appNameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'App name is required.'**
  String get appNameIsRequired;

  /// No description provided for @appUpdates.
  ///
  /// In en, this message translates to:
  /// **'App Updates'**
  String get appUpdates;

  /// No description provided for @appUpdatesAreNotConfiguredFor.
  ///
  /// In en, this message translates to:
  /// **'App updates are not configured for this build.'**
  String get appUpdatesAreNotConfiguredFor;

  /// No description provided for @appliedArg1QueuedSteeringUpdatesTo.
  ///
  /// In en, this message translates to:
  /// **'Applied {arg1} queued steering updates to the current run.'**
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1);

  /// No description provided for @appliedArg1SteeringUpdateS.
  ///
  /// In en, this message translates to:
  /// **'Applied {arg1} steering update(s).'**
  String appliedArg1SteeringUpdateS(Object? arg1);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @applyBehaviorNotes.
  ///
  /// In en, this message translates to:
  /// **'Apply behavior notes'**
  String get applyBehaviorNotes;

  /// No description provided for @applyCoreMemory.
  ///
  /// In en, this message translates to:
  /// **'Apply core memory'**
  String get applyCoreMemory;

  /// No description provided for @approvalRequestsForSensitiveAgentTools.
  ///
  /// In en, this message translates to:
  /// **'Approval requests for sensitive agent tools'**
  String get approvalRequestsForSensitiveAgentTools;

  /// No description provided for @approvalRequired.
  ///
  /// In en, this message translates to:
  /// **'Approval required'**
  String get approvalRequired;

  /// No description provided for @approvalStaysInsideYourAuthenticatedMobile.
  ///
  /// In en, this message translates to:
  /// **'Approval stays inside your authenticated mobile session, and each code expires automatically after a short window.'**
  String get approvalStaysInsideYourAuthenticatedMobile;

  /// No description provided for @approveLogin.
  ///
  /// In en, this message translates to:
  /// **'Approve login'**
  String get approveLogin;

  /// No description provided for @approveQrLogin.
  ///
  /// In en, this message translates to:
  /// **'Approve QR login'**
  String get approveQrLogin;

  /// No description provided for @approveThisOnlyIfYouStarted.
  ///
  /// In en, this message translates to:
  /// **'Approve this only if you started the login on that device just now.'**
  String get approveThisOnlyIfYouStarted;

  /// No description provided for @approvedLoginForArg1.
  ///
  /// In en, this message translates to:
  /// **'Approved login for {arg1}.'**
  String approvedLoginForArg1(Object? arg1);

  /// No description provided for @approvedOnly.
  ///
  /// In en, this message translates to:
  /// **'Approved only'**
  String get approvedOnly;

  /// No description provided for @approvedPairingForArg1.
  ///
  /// In en, this message translates to:
  /// **'Approved pairing for {arg1}.'**
  String approvedPairingForArg1(Object? arg1);

  /// No description provided for @approvedPeopleAndGroups.
  ///
  /// In en, this message translates to:
  /// **'Approved people and groups'**
  String get approvedPeopleAndGroups;

  /// No description provided for @approvedPeopleOnly.
  ///
  /// In en, this message translates to:
  /// **'Approved people only'**
  String get approvedPeopleOnly;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @archiveAgent.
  ///
  /// In en, this message translates to:
  /// **'Archive agent?'**
  String get archiveAgent;

  /// No description provided for @archiveArg1.
  ///
  /// In en, this message translates to:
  /// **'Archive ({arg1})'**
  String archiveArg1(Object? arg1);

  /// No description provided for @archiveArg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'Archive {arg1} {arg2}?'**
  String archiveArg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @archiveSelectedMemories.
  ///
  /// In en, this message translates to:
  /// **'Archive selected memories?'**
  String get archiveSelectedMemories;

  /// No description provided for @areSharedByEveryAccountOn.
  ///
  /// In en, this message translates to:
  /// **'are shared by every account on this server; accounts can still '**
  String get areSharedByEveryAccountOn;

  /// No description provided for @arg1.
  ///
  /// In en, this message translates to:
  /// **'=== {arg1} ===\n'**
  String arg1(Object? arg1);

  /// No description provided for @arg11mInput.
  ///
  /// In en, this message translates to:
  /// **'\${arg1} / 1M input'**
  String arg11mInput(Object? arg1);

  /// No description provided for @arg12.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · '**
  String arg12(Object? arg1);

  /// No description provided for @arg13.
  ///
  /// In en, this message translates to:
  /// **'\$ {arg1}'**
  String arg13(Object? arg1);

  /// No description provided for @arg1AccessNeeded.
  ///
  /// In en, this message translates to:
  /// **'{arg1} access needed'**
  String arg1AccessNeeded(Object? arg1);

  /// No description provided for @arg1Accounts.
  ///
  /// In en, this message translates to:
  /// **'{arg1} accounts'**
  String arg1Accounts(Object? arg1);

  /// No description provided for @arg1Active.
  ///
  /// In en, this message translates to:
  /// **'{arg1} active'**
  String arg1Active(Object? arg1);

  /// No description provided for @arg1AddedEditItAnyTime.
  ///
  /// In en, this message translates to:
  /// **'{arg1} added. Edit it any time to change the '**
  String arg1AddedEditItAnyTime(Object? arg1);

  /// No description provided for @arg1AndItsRunHistoryWill.
  ///
  /// In en, this message translates to:
  /// **'“{arg1}” and its run history will be permanently deleted. Any active run will be stopped. Files in the workspace are not touched.'**
  String arg1AndItsRunHistoryWill(Object? arg1);

  /// No description provided for @arg1ApprovalNeeded.
  ///
  /// In en, this message translates to:
  /// **'{arg1} approval needed'**
  String arg1ApprovalNeeded(Object? arg1);

  /// No description provided for @arg1AppsActive.
  ///
  /// In en, this message translates to:
  /// **'{arg1} apps active'**
  String arg1AppsActive(Object? arg1);

  /// No description provided for @arg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} ({arg2})'**
  String arg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg210.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} * * *'**
  String arg1Arg210(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg211.
  ///
  /// In en, this message translates to:
  /// **'{arg1} -> {arg2}'**
  String arg1Arg211(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg215.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} * * 1-5'**
  String arg1Arg215(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg22.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · {arg2}'**
  String arg1Arg22(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg23.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2}'**
  String arg1Arg23(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg24.
  ///
  /// In en, this message translates to:
  /// **'{arg1}: {arg2}'**
  String arg1Arg24(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg25.
  ///
  /// In en, this message translates to:
  /// **'[{arg1}] {arg2}'**
  String arg1Arg25(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg26.
  ///
  /// In en, this message translates to:
  /// **'@{arg1} · {arg2}'**
  String arg1Arg26(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg27.
  ///
  /// In en, this message translates to:
  /// **'{arg1}. {arg2}'**
  String arg1Arg27(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg28.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} '**
  String arg1Arg28(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg29.
  ///
  /// In en, this message translates to:
  /// **'{arg1} / {arg2}'**
  String arg1Arg29(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2ActiveTools.
  ///
  /// In en, this message translates to:
  /// **'{arg1} ({arg2} active tools)'**
  String arg1Arg2ActiveTools(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2Arg3.
  ///
  /// In en, this message translates to:
  /// **'{arg1} • {arg2} • {arg3}'**
  String arg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg310.
  ///
  /// In en, this message translates to:
  /// **'### {arg1} ({arg2})\n{arg3}'**
  String arg1Arg2Arg310(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg311.
  ///
  /// In en, this message translates to:
  /// **'[{arg1}][{arg2}] {arg3}'**
  String arg1Arg2Arg311(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg32.
  ///
  /// In en, this message translates to:
  /// **'{arg1}/{arg2} {arg3}'**
  String arg1Arg2Arg32(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg33.
  ///
  /// In en, this message translates to:
  /// **'[{arg1}] [{arg2}] {arg3}'**
  String arg1Arg2Arg33(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg34.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} * * {arg3}'**
  String arg1Arg2Arg34(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg35.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} {arg3} * *'**
  String arg1Arg2Arg35(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg36.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · {arg2} · {arg3}'**
  String arg1Arg2Arg36(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg37.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} {arg3}'**
  String arg1Arg2Arg37(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg38.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · {arg2} {arg3}'**
  String arg1Arg2Arg38(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg39.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2}, {arg3}'**
  String arg1Arg2Arg39(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Arg3Arg4.
  ///
  /// In en, this message translates to:
  /// **'{arg1}/{arg2} {arg3}:{arg4}'**
  String arg1Arg2Arg3Arg4(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
  );

  /// No description provided for @arg1Arg2Arg3Arg42.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} {arg3} {arg4}'**
  String arg1Arg2Arg3Arg42(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
  );

  /// No description provided for @arg1Arg2Arg3Arg4Arg5.
  ///
  /// In en, this message translates to:
  /// **'{arg1}-{arg2}-{arg3} {arg4}:{arg5}'**
  String arg1Arg2Arg3Arg4Arg5(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  );

  /// No description provided for @arg1Arg2AtArg3.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} at {arg3}'**
  String arg1Arg2AtArg3(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Changed.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} changed'**
  String arg1Arg2Changed(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2Chars.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · {arg2} chars'**
  String arg1Arg2Chars(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2CreatedArg3.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · {arg2} · Created {arg3}'**
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2LocalUriArg3.
  ///
  /// In en, this message translates to:
  /// **'- {arg1} ({arg2}) [local uri: {arg3}]'**
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2MatchingArg3.
  ///
  /// In en, this message translates to:
  /// **'{arg1} {arg2} matching “{arg3}”'**
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2NeoagentWorkspace.
  ///
  /// In en, this message translates to:
  /// **'{arg1}{arg2}NeoAgent Workspace'**
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2NewAccounts.
  ///
  /// In en, this message translates to:
  /// **'{arg1}\n{arg2} new accounts'**
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2OfArg3.
  ///
  /// In en, this message translates to:
  /// **'{arg1}–{arg2} of {arg3}'**
  String arg1Arg2OfArg3(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1Arg2Runs.
  ///
  /// In en, this message translates to:
  /// **'{arg1}\n{arg2} runs · '**
  String arg1Arg2Runs(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2S.
  ///
  /// In en, this message translates to:
  /// **'{arg1} ({arg2}s)'**
  String arg1Arg2S(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2Samples.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · {arg2} samples'**
  String arg1Arg2Samples(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2SteeringQueued.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · {arg2} steering queued'**
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2Tokens.
  ///
  /// In en, this message translates to:
  /// **'{arg1}\n{arg2} tokens'**
  String arg1Arg2Tokens(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2Tokens2.
  ///
  /// In en, this message translates to:
  /// **'{arg1}: {arg2} tokens'**
  String arg1Arg2Tokens2(Object? arg1, Object? arg2);

  /// No description provided for @arg1Arg2Tokens3.
  ///
  /// In en, this message translates to:
  /// **'{arg1} / {arg2} tokens'**
  String arg1Arg2Tokens3(Object? arg1, Object? arg2);

  /// No description provided for @arg1AtArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} at {arg2}'**
  String arg1AtArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1B.
  ///
  /// In en, this message translates to:
  /// **'{arg1} B'**
  String arg1B(Object? arg1);

  /// No description provided for @arg1BecameAnAdminArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} became an admin ({arg2})'**
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1Bytes.
  ///
  /// In en, this message translates to:
  /// **'{arg1} bytes'**
  String arg1Bytes(Object? arg1);

  /// No description provided for @arg1Channel.
  ///
  /// In en, this message translates to:
  /// **'{arg1} channel'**
  String arg1Channel(Object? arg1);

  /// No description provided for @arg1Chars.
  ///
  /// In en, this message translates to:
  /// **'{arg1} chars'**
  String arg1Chars(Object? arg1);

  /// No description provided for @arg1Cleared.
  ///
  /// In en, this message translates to:
  /// **'{arg1} cleared.'**
  String arg1Cleared(Object? arg1);

  /// No description provided for @arg1Configured.
  ///
  /// In en, this message translates to:
  /// **'{arg1} configured'**
  String arg1Configured(Object? arg1);

  /// No description provided for @arg1ConnectedChooseRepositoriesAndPeople.
  ///
  /// In en, this message translates to:
  /// **'{arg1} connected. Choose repositories and people under Who can message.'**
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1);

  /// No description provided for @arg1CoreEntries.
  ///
  /// In en, this message translates to:
  /// **'{arg1} core entries.'**
  String arg1CoreEntries(Object? arg1);

  /// No description provided for @arg1CreatedAnInviteLink.
  ///
  /// In en, this message translates to:
  /// **'{arg1} created an invite link'**
  String arg1CreatedAnInviteLink(Object? arg1);

  /// No description provided for @arg1Deactivated.
  ///
  /// In en, this message translates to:
  /// **'{arg1} deactivated.'**
  String arg1Deactivated(Object? arg1);

  /// No description provided for @arg1Default.
  ///
  /// In en, this message translates to:
  /// **'{arg1}: default'**
  String arg1Default(Object? arg1);

  /// No description provided for @arg1Desktop.
  ///
  /// In en, this message translates to:
  /// **'{arg1} desktop'**
  String arg1Desktop(Object? arg1);

  /// No description provided for @arg1Entries.
  ///
  /// In en, this message translates to:
  /// **'{arg1} entries'**
  String arg1Entries(Object? arg1);

  /// No description provided for @arg1Events.
  ///
  /// In en, this message translates to:
  /// **'{arg1} events'**
  String arg1Events(Object? arg1);

  /// No description provided for @arg1Failed.
  ///
  /// In en, this message translates to:
  /// **' · {arg1} failed'**
  String arg1Failed(Object? arg1);

  /// No description provided for @arg1Failed2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} failed'**
  String arg1Failed2(Object? arg1);

  /// No description provided for @arg1Failing.
  ///
  /// In en, this message translates to:
  /// **'{arg1} failing'**
  String arg1Failing(Object? arg1);

  /// No description provided for @arg1FeatureArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} feature{arg2}'**
  String arg1FeatureArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1ForArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} for {arg2}'**
  String arg1ForArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1Forever.
  ///
  /// In en, this message translates to:
  /// **'{arg1} forever'**
  String arg1Forever(Object? arg1);

  /// No description provided for @arg1Gb.
  ///
  /// In en, this message translates to:
  /// **'{arg1} GB'**
  String arg1Gb(Object? arg1);

  /// No description provided for @arg1GroupsTaggedOnly.
  ///
  /// In en, this message translates to:
  /// **'{arg1} groups tagged-only'**
  String arg1GroupsTaggedOnly(Object? arg1);

  /// No description provided for @arg1HAgo.
  ///
  /// In en, this message translates to:
  /// **'{arg1}h ago'**
  String arg1HAgo(Object? arg1);

  /// No description provided for @arg1HArg2M.
  ///
  /// In en, this message translates to:
  /// **'{arg1}h {arg2}m'**
  String arg1HArg2M(Object? arg1, Object? arg2);

  /// No description provided for @arg1HArg2Min.
  ///
  /// In en, this message translates to:
  /// **'{arg1} h {arg2} min'**
  String arg1HArg2Min(Object? arg1, Object? arg2);

  /// No description provided for @arg1Helpers.
  ///
  /// In en, this message translates to:
  /// **'{arg1} helpers'**
  String arg1Helpers(Object? arg1);

  /// No description provided for @arg1HitRatio.
  ///
  /// In en, this message translates to:
  /// **'({arg1} hit ratio)'**
  String arg1HitRatio(Object? arg1);

  /// No description provided for @arg1IsAnAdminSoThe.
  ///
  /// In en, this message translates to:
  /// **'@{arg1} is an admin, so the account can’t be deleted '**
  String arg1IsAnAdminSoThe(Object? arg1);

  /// No description provided for @arg1IsBlockedOnArg2Update.
  ///
  /// In en, this message translates to:
  /// **'{arg1} is blocked on {arg2}. Update the access list to allow replies.'**
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2);

  /// No description provided for @arg1IsConnectedAndResponding.
  ///
  /// In en, this message translates to:
  /// **'{arg1} is connected and responding.'**
  String arg1IsConnectedAndResponding(Object? arg1);

  /// No description provided for @arg1IsNoLongerAnAdmin.
  ///
  /// In en, this message translates to:
  /// **'{arg1} is no longer an admin ({arg2})'**
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2);

  /// No description provided for @arg1IsNotAvailableOnArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} is not available on {arg2} (missing runtime permission or dependency).'**
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1JoinedUnderArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} joined under {arg2}'**
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1JudgedByLlm.
  ///
  /// In en, this message translates to:
  /// **'{arg1} judged by LLM'**
  String arg1JudgedByLlm(Object? arg1);

  /// No description provided for @arg1Kb.
  ///
  /// In en, this message translates to:
  /// **'{arg1} KB'**
  String arg1Kb(Object? arg1);

  /// No description provided for @arg1KeyArg2Configured.
  ///
  /// In en, this message translates to:
  /// **'{arg1} key{arg2} configured'**
  String arg1KeyArg2Configured(Object? arg1, Object? arg2);

  /// No description provided for @arg1KeyRemoved.
  ///
  /// In en, this message translates to:
  /// **'{arg1} key removed.'**
  String arg1KeyRemoved(Object? arg1);

  /// No description provided for @arg1Left.
  ///
  /// In en, this message translates to:
  /// **'{arg1} left'**
  String arg1Left(Object? arg1);

  /// No description provided for @arg1LeftArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} left {arg2}'**
  String arg1LeftArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1Linked.
  ///
  /// In en, this message translates to:
  /// **'{arg1} linked'**
  String arg1Linked(Object? arg1);

  /// No description provided for @arg1MAgo.
  ///
  /// In en, this message translates to:
  /// **'{arg1}m ago'**
  String arg1MAgo(Object? arg1);

  /// No description provided for @arg1MArg2S.
  ///
  /// In en, this message translates to:
  /// **'{arg1}m {arg2}s'**
  String arg1MArg2S(Object? arg1, Object? arg2);

  /// No description provided for @arg1MakeSureItIsRunning.
  ///
  /// In en, this message translates to:
  /// **'{arg1}. Make sure it is running, then try again.'**
  String arg1MakeSureItIsRunning(Object? arg1);

  /// No description provided for @arg1ManagesThisAccount.
  ///
  /// In en, this message translates to:
  /// **'{arg1} manages this account'**
  String arg1ManagesThisAccount(Object? arg1);

  /// No description provided for @arg1Mb.
  ///
  /// In en, this message translates to:
  /// **'{arg1} MB'**
  String arg1Mb(Object? arg1);

  /// No description provided for @arg1Min.
  ///
  /// In en, this message translates to:
  /// **'{arg1} min'**
  String arg1Min(Object? arg1);

  /// No description provided for @arg1MinArg2Sec.
  ///
  /// In en, this message translates to:
  /// **'{arg1} min {arg2} sec'**
  String arg1MinArg2Sec(Object? arg1, Object? arg2);

  /// No description provided for @arg1ModelArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} model{arg2}'**
  String arg1ModelArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1ModelsReady.
  ///
  /// In en, this message translates to:
  /// **'{arg1} models ready'**
  String arg1ModelsReady(Object? arg1);

  /// No description provided for @arg1More.
  ///
  /// In en, this message translates to:
  /// **'+{arg1} more'**
  String arg1More(Object? arg1);

  /// No description provided for @arg1MoreStepsInRunHistory.
  ///
  /// In en, this message translates to:
  /// **'{arg1} more steps in run history'**
  String arg1MoreStepsInRunHistory(Object? arg1);

  /// No description provided for @arg1MovedFromArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} moved from {arg2} '**
  String arg1MovedFromArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1Ms.
  ///
  /// In en, this message translates to:
  /// **'{arg1} ms'**
  String arg1Ms(Object? arg1);

  /// No description provided for @arg1MustBeAFiniteNumber.
  ///
  /// In en, this message translates to:
  /// **'{arg1} must be a finite number.'**
  String arg1MustBeAFiniteNumber(Object? arg1);

  /// No description provided for @arg1MustBeAnHttpOr.
  ///
  /// In en, this message translates to:
  /// **'{arg1} must be an http:// or https:// address.'**
  String arg1MustBeAnHttpOr(Object? arg1);

  /// No description provided for @arg1NeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'{arg1} needs attention'**
  String arg1NeedsAttention(Object? arg1);

  /// No description provided for @arg1NeoagentWorkspace.
  ///
  /// In en, this message translates to:
  /// **'{arg1}/NeoAgent Workspace'**
  String arg1NeoagentWorkspace(Object? arg1);

  /// No description provided for @arg1NewAccountsInTheLast.
  ///
  /// In en, this message translates to:
  /// **'{arg1} new accounts in the last {arg2}.'**
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2);

  /// No description provided for @arg1NewMessagesSteerThisRun.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · new messages steer this run'**
  String arg1NewMessagesSteerThisRun(Object? arg1);

  /// No description provided for @arg1NewRuns.
  ///
  /// In en, this message translates to:
  /// **'{arg1} new runs'**
  String arg1NewRuns(Object? arg1);

  /// No description provided for @arg1NowManagesThisAccount.
  ///
  /// In en, this message translates to:
  /// **'{arg1} now manages this account.'**
  String arg1NowManagesThisAccount(Object? arg1);

  /// No description provided for @arg1Of4PermissionsAllowedFiles.
  ///
  /// In en, this message translates to:
  /// **'{arg1} of 4 permissions allowed. Files are limited to your NeoAgent Workspace folder.'**
  String arg1Of4PermissionsAllowedFiles(Object? arg1);

  /// No description provided for @arg1OfArg2Enabled.
  ///
  /// In en, this message translates to:
  /// **'{arg1} of {arg2} enabled'**
  String arg1OfArg2Enabled(Object? arg1, Object? arg2);

  /// No description provided for @arg1OfArg2GroupsJoinOrdinary.
  ///
  /// In en, this message translates to:
  /// **'{arg1} of {arg2} groups join ordinary chat'**
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2);

  /// No description provided for @arg1OfArg2Models.
  ///
  /// In en, this message translates to:
  /// **'{arg1} of {arg2} models'**
  String arg1OfArg2Models(Object? arg1, Object? arg2);

  /// No description provided for @arg1OfArg2ModelsReady.
  ///
  /// In en, this message translates to:
  /// **'{arg1} of {arg2} models ready'**
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2);

  /// No description provided for @arg1OfArg2Set.
  ///
  /// In en, this message translates to:
  /// **'{arg1} of {arg2} set'**
  String arg1OfArg2Set(Object? arg1, Object? arg2);

  /// No description provided for @arg1OfArg2ToolsAllowed.
  ///
  /// In en, this message translates to:
  /// **'{arg1} of {arg2} tools allowed'**
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2);

  /// No description provided for @arg1Ok.
  ///
  /// In en, this message translates to:
  /// **'{arg1}: OK'**
  String arg1Ok(Object? arg1);

  /// No description provided for @arg1OnDayArg2AtArg3.
  ///
  /// In en, this message translates to:
  /// **'{arg1} on day {arg2} at {arg3}'**
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @arg1OnlyRepliesToThePeople.
  ///
  /// In en, this message translates to:
  /// **'{arg1} only replies to the people you add below.'**
  String arg1OnlyRepliesToThePeople(Object? arg1);

  /// No description provided for @arg1OnlyRepliesWhenTagged.
  ///
  /// In en, this message translates to:
  /// **'{arg1} only replies when tagged'**
  String arg1OnlyRepliesWhenTagged(Object? arg1);

  /// No description provided for @arg1OnlyTalksToPeopleAnd.
  ///
  /// In en, this message translates to:
  /// **'{arg1} only talks to people and groups you approve'**
  String arg1OnlyTalksToPeopleAnd(Object? arg1);

  /// No description provided for @arg1PeopleOrGroupsAdded.
  ///
  /// In en, this message translates to:
  /// **'{arg1} people or groups added'**
  String arg1PeopleOrGroupsAdded(Object? arg1);

  /// No description provided for @arg1Planning.
  ///
  /// In en, this message translates to:
  /// **'{arg1} planning'**
  String arg1Planning(Object? arg1);

  /// No description provided for @arg1Providers.
  ///
  /// In en, this message translates to:
  /// **'{arg1} providers'**
  String arg1Providers(Object? arg1);

  /// No description provided for @arg1Ready.
  ///
  /// In en, this message translates to:
  /// **'{arg1} ready'**
  String arg1Ready(Object? arg1);

  /// No description provided for @arg1Records.
  ///
  /// In en, this message translates to:
  /// **'{arg1} records'**
  String arg1Records(Object? arg1);

  /// No description provided for @arg1RedirectUri.
  ///
  /// In en, this message translates to:
  /// **'{arg1} redirect URI'**
  String arg1RedirectUri(Object? arg1);

  /// No description provided for @arg1Registered.
  ///
  /// In en, this message translates to:
  /// **'{arg1} registered'**
  String arg1Registered(Object? arg1);

  /// No description provided for @arg1Replied.
  ///
  /// In en, this message translates to:
  /// **'{arg1} replied'**
  String arg1Replied(Object? arg1);

  /// No description provided for @arg1RevokedAnInviteLink.
  ///
  /// In en, this message translates to:
  /// **'{arg1} revoked an invite link'**
  String arg1RevokedAnInviteLink(Object? arg1);

  /// No description provided for @arg1Runs.
  ///
  /// In en, this message translates to:
  /// **'{arg1} runs'**
  String arg1Runs(Object? arg1);

  /// No description provided for @arg1RunsArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} runs · {arg2}'**
  String arg1RunsArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1RunsInTheLastArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} runs in the last {arg2}.'**
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1Saved.
  ///
  /// In en, this message translates to:
  /// **'{arg1} saved.'**
  String arg1Saved(Object? arg1);

  /// No description provided for @arg1ScoredByJev.
  ///
  /// In en, this message translates to:
  /// **'{arg1} scored by JEV'**
  String arg1ScoredByJev(Object? arg1);

  /// No description provided for @arg1Sec.
  ///
  /// In en, this message translates to:
  /// **'{arg1} sec'**
  String arg1Sec(Object? arg1);

  /// No description provided for @arg1Selected.
  ///
  /// In en, this message translates to:
  /// **'{arg1} selected'**
  String arg1Selected(Object? arg1);

  /// No description provided for @arg1Shown.
  ///
  /// In en, this message translates to:
  /// **'{arg1} shown'**
  String arg1Shown(Object? arg1);

  /// No description provided for @arg1StayedQuiet.
  ///
  /// In en, this message translates to:
  /// **'{arg1} stayed quiet'**
  String arg1StayedQuiet(Object? arg1);

  /// No description provided for @arg1SteeringArg2Queued.
  ///
  /// In en, this message translates to:
  /// **'{arg1} steering {arg2} queued'**
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2);

  /// No description provided for @arg1StepArg2TapANode.
  ///
  /// In en, this message translates to:
  /// **'{arg1} step{arg2} · tap a node to inspect'**
  String arg1StepArg2TapANode(Object? arg1, Object? arg2);

  /// No description provided for @arg1Steps.
  ///
  /// In en, this message translates to:
  /// **'{arg1} steps'**
  String arg1Steps(Object? arg1);

  /// No description provided for @arg1StoppedManagingArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} stopped managing {arg2}'**
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1TalksToTheDeviceOn.
  ///
  /// In en, this message translates to:
  /// **'{arg1} talks to the device on your local network (port 4403 by default). Chat stays on the channel you pick above.'**
  String arg1TalksToTheDeviceOn(Object? arg1);

  /// No description provided for @arg1Tokens.
  ///
  /// In en, this message translates to:
  /// **'{arg1} tokens'**
  String arg1Tokens(Object? arg1);

  /// No description provided for @arg1TokensInTheLastArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} tokens in the last {arg2}.'**
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2);

  /// No description provided for @arg1Tools.
  ///
  /// In en, this message translates to:
  /// **'{arg1} tools'**
  String arg1Tools(Object? arg1);

  /// No description provided for @arg1UnavailableSavedOverride.
  ///
  /// In en, this message translates to:
  /// **'{arg1} (unavailable saved override)'**
  String arg1UnavailableSavedOverride(Object? arg1);

  /// No description provided for @arg1UsedArg2Remaining.
  ///
  /// In en, this message translates to:
  /// **'{arg1}% used · {arg2} remaining'**
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2);

  /// No description provided for @arg1WantsToTalkWithYou.
  ///
  /// In en, this message translates to:
  /// **'{arg1} wants to talk with you.'**
  String arg1WantsToTalkWithYou(Object? arg1);

  /// No description provided for @arg1Web.
  ///
  /// In en, this message translates to:
  /// **'{arg1} web'**
  String arg1Web(Object? arg1);

  /// No description provided for @arg1WillBeRemovedPermanently.
  ///
  /// In en, this message translates to:
  /// **'\"{arg1}\" will be removed permanently.'**
  String arg1WillBeRemovedPermanently(Object? arg1);

  /// No description provided for @arg1WillManageThisAccount.
  ///
  /// In en, this message translates to:
  /// **'{arg1} will manage this account'**
  String arg1WillManageThisAccount(Object? arg1);

  /// No description provided for @arg1WillNotReplyOnThis.
  ///
  /// In en, this message translates to:
  /// **'{arg1} will not reply on this platform'**
  String arg1WillNotReplyOnThis(Object? arg1);

  /// No description provided for @arg1WillNotReplyToArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} will not reply to {arg2}.'**
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2);

  /// No description provided for @artifactStorageByUser.
  ///
  /// In en, this message translates to:
  /// **'Artifact storage by user'**
  String get artifactStorageByUser;

  /// No description provided for @askAQuestionOrStartA.
  ///
  /// In en, this message translates to:
  /// **'Ask a question or start a task...'**
  String get askAQuestionOrStartA;

  /// No description provided for @askBeforeClosingToBackground.
  ///
  /// In en, this message translates to:
  /// **'Ask before closing to background'**
  String get askBeforeClosingToBackground;

  /// No description provided for @askMe.
  ///
  /// In en, this message translates to:
  /// **'Ask me'**
  String get askMe;

  /// No description provided for @assignAPlanToAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Assign a plan to an account'**
  String get assignAPlanToAnAccount;

  /// No description provided for @assignPlan.
  ///
  /// In en, this message translates to:
  /// **'Assign plan'**
  String get assignPlan;

  /// No description provided for @assignedAgent.
  ///
  /// In en, this message translates to:
  /// **'Assigned agent'**
  String get assignedAgent;

  /// No description provided for @assignedAgent2.
  ///
  /// In en, this message translates to:
  /// **'Assigned Agent'**
  String get assignedAgent2;

  /// No description provided for @assignedAgentArg1.
  ///
  /// In en, this message translates to:
  /// **'Assigned agent: {arg1}'**
  String assignedAgentArg1(Object? arg1);

  /// No description provided for @assignedArg1.
  ///
  /// In en, this message translates to:
  /// **'Assigned {arg1}.'**
  String assignedArg1(Object? arg1);

  /// No description provided for @assigneeOptional.
  ///
  /// In en, this message translates to:
  /// **'Assignee (optional)'**
  String get assigneeOptional;

  /// No description provided for @assistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistant;

  /// No description provided for @assistantKey131.
  ///
  /// In en, this message translates to:
  /// **'Assistant key 131'**
  String get assistantKey131;

  /// No description provided for @atLeast1.
  ///
  /// In en, this message translates to:
  /// **'At least 1.'**
  String get atLeast1;

  /// No description provided for @atLeast1000AppliesAfterA.
  ///
  /// In en, this message translates to:
  /// **'At least 1000. Applies after a server restart.'**
  String get atLeast1000AppliesAfterA;

  /// No description provided for @atLeast512.
  ///
  /// In en, this message translates to:
  /// **'At least 512.'**
  String get atLeast512;

  /// No description provided for @attachFiles.
  ///
  /// In en, this message translates to:
  /// **'Attach files'**
  String get attachFiles;

  /// No description provided for @attentionArg1.
  ///
  /// In en, this message translates to:
  /// **'Attention {arg1}'**
  String attentionArg1(Object? arg1);

  /// No description provided for @auditLogAdminGrantRevokeInvite.
  ///
  /// In en, this message translates to:
  /// **'audit log admin grant revoke invite team history'**
  String get auditLogAdminGrantRevokeInvite;

  /// No description provided for @authMethod.
  ///
  /// In en, this message translates to:
  /// **'Auth Method'**
  String get authMethod;

  /// No description provided for @authServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Auth Server URL'**
  String get authServerUrl;

  /// No description provided for @authentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get authentication;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed.'**
  String get authenticationFailed;

  /// No description provided for @authenticationIsStillPendingFinishThe.
  ///
  /// In en, this message translates to:
  /// **'Authentication is still pending. Finish the browser flow and try again.'**
  String get authenticationIsStillPendingFinishThe;

  /// No description provided for @authenticationIsStillPendingFinishThe2.
  ///
  /// In en, this message translates to:
  /// **'Authentication is still pending. Finish the browser flow and refresh.'**
  String get authenticationIsStillPendingFinishThe2;

  /// No description provided for @authenticationTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Authentication timed out.'**
  String get authenticationTimedOut;

  /// No description provided for @authenticationWasCanceledBeforeCompletion.
  ///
  /// In en, this message translates to:
  /// **'Authentication was canceled before completion.'**
  String get authenticationWasCanceledBeforeCompletion;

  /// No description provided for @authenticatorApp.
  ///
  /// In en, this message translates to:
  /// **'Authenticator app'**
  String get authenticatorApp;

  /// No description provided for @authenticatorCode.
  ///
  /// In en, this message translates to:
  /// **'Authenticator code'**
  String get authenticatorCode;

  /// No description provided for @authorOptional.
  ///
  /// In en, this message translates to:
  /// **'Author (optional)'**
  String get authorOptional;

  /// No description provided for @autoFirstProviderWithAnApi.
  ///
  /// In en, this message translates to:
  /// **'Auto (first provider with an API key)'**
  String get autoFirstProviderWithAnApi;

  /// No description provided for @autoRoutesToTheBestAvailable.
  ///
  /// In en, this message translates to:
  /// **'Auto-routes to the best available model'**
  String get autoRoutesToTheBestAvailable;

  /// No description provided for @automaticFast.
  ///
  /// In en, this message translates to:
  /// **'Automatic (fast)'**
  String get automaticFast;

  /// No description provided for @automaticReadsTheRoomAndNormally.
  ///
  /// In en, this message translates to:
  /// **'Automatic reads the room and normally holds back. Mention-only makes no decision call until directly addressed.'**
  String get automaticReadsTheRoomAndNormally;

  /// No description provided for @automaticReserved.
  ///
  /// In en, this message translates to:
  /// **'Automatic, reserved'**
  String get automaticReserved;

  /// No description provided for @automaticRollbackNeedsARetryFrom.
  ///
  /// In en, this message translates to:
  /// **'Automatic rollback needs a retry from the setup screen.'**
  String get automaticRollbackNeedsARetryFrom;

  /// No description provided for @automaticSelectsAFastModelThrough.
  ///
  /// In en, this message translates to:
  /// **'Automatic selects a fast model through the normal model catalog.'**
  String get automaticSelectsAFastModelThrough;

  /// No description provided for @automaticallyChooseTheBestEnabledModel.
  ///
  /// In en, this message translates to:
  /// **'Automatically choose the best enabled model for each task type.'**
  String get automaticallyChooseTheBestEnabledModel;

  /// No description provided for @automation.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get automation;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @availableAgainInArg1.
  ///
  /// In en, this message translates to:
  /// **'Available again in {arg1}'**
  String availableAgainInArg1(Object? arg1);

  /// No description provided for @availableAgainShortly.
  ///
  /// In en, this message translates to:
  /// **'Available again shortly'**
  String get availableAgainShortly;

  /// No description provided for @availableInTheDesktopAppFor.
  ///
  /// In en, this message translates to:
  /// **'Available in the desktop app for macOS, Windows and Linux'**
  String get availableInTheDesktopAppFor;

  /// No description provided for @availableToTheAgent.
  ///
  /// In en, this message translates to:
  /// **'Available to the agent'**
  String get availableToTheAgent;

  /// No description provided for @averageAllTime.
  ///
  /// In en, this message translates to:
  /// **'Average, all time'**
  String get averageAllTime;

  /// No description provided for @avgImp.
  ///
  /// In en, this message translates to:
  /// **'Avg imp.'**
  String get avgImp;

  /// No description provided for @avgRunArg1Tokens.
  ///
  /// In en, this message translates to:
  /// **'Avg/run: {arg1} tokens'**
  String avgRunArg1Tokens(Object? arg1);

  /// No description provided for @avoidRepeatedCharactersAndObviousSequences.
  ///
  /// In en, this message translates to:
  /// **'Avoid repeated characters and obvious sequences.'**
  String get avoidRepeatedCharactersAndObviousSequences;

  /// No description provided for @awaitingScan.
  ///
  /// In en, this message translates to:
  /// **'Awaiting scan'**
  String get awaitingScan;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backgroundTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in the background'**
  String backgroundTaskCount(Object? count);

  /// No description provided for @backgroundTasks.
  ///
  /// In en, this message translates to:
  /// **'Background tasks'**
  String get backgroundTasks;

  /// No description provided for @backOn.
  ///
  /// In en, this message translates to:
  /// **'back on.'**
  String get backOn;

  /// No description provided for @backToChat.
  ///
  /// In en, this message translates to:
  /// **'Back to chat'**
  String get backToChat;

  /// No description provided for @backToFolder.
  ///
  /// In en, this message translates to:
  /// **'Back to folder'**
  String get backToFolder;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @backendChannel.
  ///
  /// In en, this message translates to:
  /// **'Backend channel'**
  String get backendChannel;

  /// No description provided for @backendOnThisComputer.
  ///
  /// In en, this message translates to:
  /// **'Backend on this computer'**
  String get backendOnThisComputer;

  /// No description provided for @backendSync.
  ///
  /// In en, this message translates to:
  /// **'Backend sync'**
  String get backendSync;

  /// No description provided for @backgroundLocationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Background Location Needed'**
  String get backgroundLocationNeeded;

  /// No description provided for @backgroundSyncStaysScheduledOnAndroid.
  ///
  /// In en, this message translates to:
  /// **'Background sync stays scheduled on Android'**
  String get backgroundSyncStaysScheduledOnAndroid;

  /// No description provided for @badState.
  ///
  /// In en, this message translates to:
  /// **'Bad state: '**
  String get badState;

  /// No description provided for @baseImageAndSizeOfThe.
  ///
  /// In en, this message translates to:
  /// **'Base image and size of the QEMU virtual machines that run '**
  String get baseImageAndSizeOfThe;

  /// No description provided for @baseImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Base image URL'**
  String get baseImageUrl;

  /// No description provided for @baseUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Base URL (optional)'**
  String get baseUrlOptional;

  /// No description provided for @baseUrlTokenLocal.
  ///
  /// In en, this message translates to:
  /// **'base url token local'**
  String get baseUrlTokenLocal;

  /// No description provided for @basicAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Basic authentication'**
  String get basicAuthentication;

  /// No description provided for @behaviorModules.
  ///
  /// In en, this message translates to:
  /// **'Behavior Modules'**
  String get behaviorModules;

  /// No description provided for @behaviorNotes.
  ///
  /// In en, this message translates to:
  /// **'behavior notes'**
  String get behaviorNotes;

  /// No description provided for @beta.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get beta;

  /// No description provided for @billedThroughStripeSoItCan.
  ///
  /// In en, this message translates to:
  /// **'Billed through Stripe, so it can’t be canceled here.'**
  String get billedThroughStripeSoItCan;

  /// No description provided for @billing.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billing;

  /// No description provided for @billingEnabled.
  ///
  /// In en, this message translates to:
  /// **'Billing enabled'**
  String get billingEnabled;

  /// No description provided for @billingHistory.
  ///
  /// In en, this message translates to:
  /// **'Billing history'**
  String get billingHistory;

  /// No description provided for @billingInterval.
  ///
  /// In en, this message translates to:
  /// **'Billing interval'**
  String get billingInterval;

  /// No description provided for @billingIsOff.
  ///
  /// In en, this message translates to:
  /// **'Billing is off'**
  String get billingIsOff;

  /// No description provided for @billingIsTurnedOffButStill.
  ///
  /// In en, this message translates to:
  /// **'Billing is turned off but still running. Restart the '**
  String get billingIsTurnedOffButStill;

  /// No description provided for @billingIsTurnedOnButNot.
  ///
  /// In en, this message translates to:
  /// **'Billing is turned on but not running yet. Restart the '**
  String get billingIsTurnedOnButNot;

  /// No description provided for @billingSetupSaved.
  ///
  /// In en, this message translates to:
  /// **'Billing setup saved.'**
  String get billingSetupSaved;

  /// No description provided for @billingStripeKeysWebhookSecretTrial.
  ///
  /// In en, this message translates to:
  /// **'billing stripe keys webhook secret trial enable'**
  String get billingStripeKeysWebhookSecretTrial;

  /// No description provided for @billingSubscription.
  ///
  /// In en, this message translates to:
  /// **'Billing & subscription'**
  String get billingSubscription;

  /// No description provided for @bitwardenCredentialBroker.
  ///
  /// In en, this message translates to:
  /// **'Bitwarden credential broker'**
  String get bitwardenCredentialBroker;

  /// No description provided for @bitwardenItem.
  ///
  /// In en, this message translates to:
  /// **'Bitwarden item'**
  String get bitwardenItem;

  /// No description provided for @bitwardenServer.
  ///
  /// In en, this message translates to:
  /// **'Bitwarden server'**
  String get bitwardenServer;

  /// No description provided for @blankUsesCommon.
  ///
  /// In en, this message translates to:
  /// **'Blank uses \"common\"'**
  String get blankUsesCommon;

  /// No description provided for @blankUsesTheDefaultCallback.
  ///
  /// In en, this message translates to:
  /// **'Blank uses the default callback'**
  String get blankUsesTheDefaultCallback;

  /// No description provided for @blankUsesTheServerDefault.
  ///
  /// In en, this message translates to:
  /// **'Blank uses the server default.'**
  String get blankUsesTheServerDefault;

  /// No description provided for @blankValuesUseTheProviderDefaults.
  ///
  /// In en, this message translates to:
  /// **'Blank values use the provider defaults.'**
  String get blankValuesUseTheProviderDefaults;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @blockedIncomingMessageFromArg1.
  ///
  /// In en, this message translates to:
  /// **'Blocked incoming message from {arg1}.'**
  String blockedIncomingMessageFromArg1(Object? arg1);

  /// No description provided for @bluebubblesCompatibleBridge.
  ///
  /// In en, this message translates to:
  /// **'BlueBubbles-compatible bridge'**
  String get bluebubblesCompatibleBridge;

  /// No description provided for @bluebubblesServerUrl.
  ///
  /// In en, this message translates to:
  /// **'BlueBubbles server URL'**
  String get bluebubblesServerUrl;

  /// No description provided for @botToken.
  ///
  /// In en, this message translates to:
  /// **'Bot token'**
  String get botToken;

  /// No description provided for @botTokenAndApprovedChats.
  ///
  /// In en, this message translates to:
  /// **'Bot token and approved chats'**
  String get botTokenAndApprovedChats;

  /// No description provided for @botTokenAndServerChannelAccess.
  ///
  /// In en, this message translates to:
  /// **'Bot token and server/channel access'**
  String get botTokenAndServerChannelAccess;

  /// No description provided for @botTokenEventsApiAndChannel.
  ///
  /// In en, this message translates to:
  /// **'Bot token, Events API, and channel access'**
  String get botTokenEventsApiAndChannel;

  /// No description provided for @botUserId.
  ///
  /// In en, this message translates to:
  /// **'Bot user ID'**
  String get botUserId;

  /// No description provided for @botUsername.
  ///
  /// In en, this message translates to:
  /// **'Bot username'**
  String get botUsername;

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'Brand name'**
  String get brandName;

  /// No description provided for @braveSearch.
  ///
  /// In en, this message translates to:
  /// **'Brave Search'**
  String get braveSearch;

  /// No description provided for @breakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown:'**
  String get breakdown;

  /// No description provided for @bridgeAnyProviderThatCanPost.
  ///
  /// In en, this message translates to:
  /// **'Bridge any provider that can post and receive webhook payloads.'**
  String get bridgeAnyProviderThatCanPost;

  /// No description provided for @bringYourOwnKey.
  ///
  /// In en, this message translates to:
  /// **'bring your own key'**
  String get bringYourOwnKey;

  /// No description provided for @bringYourOwnKey2.
  ///
  /// In en, this message translates to:
  /// **'Bring your own key'**
  String get bringYourOwnKey2;

  /// No description provided for @browserLinuxDesktopFilesTerminalAnd.
  ///
  /// In en, this message translates to:
  /// **'Browser, Linux desktop, files, terminal, and Python share one persistent cloud computer.'**
  String get browserLinuxDesktopFilesTerminalAnd;

  /// No description provided for @browserLogin.
  ///
  /// In en, this message translates to:
  /// **'Browser login'**
  String get browserLogin;

  /// No description provided for @browserScripting.
  ///
  /// In en, this message translates to:
  /// **'Browser Scripting'**
  String get browserScripting;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @callAgent.
  ///
  /// In en, this message translates to:
  /// **'Call agent'**
  String get callAgent;

  /// No description provided for @callUser.
  ///
  /// In en, this message translates to:
  /// **'Call User'**
  String get callUser;

  /// No description provided for @calledByName.
  ///
  /// In en, this message translates to:
  /// **'Called by name'**
  String get calledByName;

  /// No description provided for @canDelegateTasksToOtherAgents.
  ///
  /// In en, this message translates to:
  /// **'Can delegate tasks to other agents'**
  String get canDelegateTasksToOtherAgents;

  /// No description provided for @canDelegateToArg1.
  ///
  /// In en, this message translates to:
  /// **'Can delegate to {arg1}'**
  String canDelegateToArg1(Object? arg1);

  /// No description provided for @canReceiveDelegatedTasks.
  ///
  /// In en, this message translates to:
  /// **'Can receive delegated tasks'**
  String get canReceiveDelegatedTasks;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cancelSubscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get cancelSubscription;

  /// No description provided for @cancelTask.
  ///
  /// In en, this message translates to:
  /// **'Cancel task'**
  String get cancelTask;

  /// No description provided for @cancelsAtPeriodEnd.
  ///
  /// In en, this message translates to:
  /// **'Cancels at period end'**
  String get cancelsAtPeriodEnd;

  /// No description provided for @candidateCountArg1.
  ///
  /// In en, this message translates to:
  /// **'Candidate Count: {arg1}'**
  String candidateCountArg1(Object? arg1);

  /// No description provided for @cannotPreview.
  ///
  /// In en, this message translates to:
  /// **'Cannot preview'**
  String get cannotPreview;

  /// No description provided for @cannotReceiveDelegatedTasks.
  ///
  /// In en, this message translates to:
  /// **'cannot receive delegated tasks'**
  String get cannotReceiveDelegatedTasks;

  /// No description provided for @cannotRunYet.
  ///
  /// In en, this message translates to:
  /// **'cannot run yet.'**
  String get cannotRunYet;

  /// No description provided for @capturedThePage.
  ///
  /// In en, this message translates to:
  /// **'Captured the page'**
  String get capturedThePage;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @chainArg1.
  ///
  /// In en, this message translates to:
  /// **'Chain: {arg1}. '**
  String chainArg1(Object? arg1);

  /// No description provided for @changePlan.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get changePlan;

  /// No description provided for @changeSetupMode.
  ///
  /// In en, this message translates to:
  /// **'Change setup mode'**
  String get changeSetupMode;

  /// No description provided for @channel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channel;

  /// No description provided for @channelAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Channel access token'**
  String get channelAccessToken;

  /// No description provided for @channelArg1Arg2UpdateVersionArg3.
  ///
  /// In en, this message translates to:
  /// **'Channel: {arg1}{arg2} | Update Version: {arg3}{arg4}{arg5}'**
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  );

  /// No description provided for @channelNumber.
  ///
  /// In en, this message translates to:
  /// **'Channel number'**
  String get channelNumber;

  /// No description provided for @channelScopedSocialMemory.
  ///
  /// In en, this message translates to:
  /// **'Channel-scoped social memory'**
  String get channelScopedSocialMemory;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @chatId.
  ///
  /// In en, this message translates to:
  /// **'Chat ID'**
  String get chatId;

  /// No description provided for @chatMode.
  ///
  /// In en, this message translates to:
  /// **'Chat mode'**
  String get chatMode;

  /// No description provided for @chatModel.
  ///
  /// In en, this message translates to:
  /// **'Chat Model'**
  String get chatModel;

  /// No description provided for @checkAutomaticallyOnLaunch.
  ///
  /// In en, this message translates to:
  /// **'Check automatically on launch'**
  String get checkAutomaticallyOnLaunch;

  /// No description provided for @checkForMessagesEveryMs.
  ///
  /// In en, this message translates to:
  /// **'Check for messages every (ms)'**
  String get checkForMessagesEveryMs;

  /// No description provided for @checkForNewMessagesAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Check for new messages automatically'**
  String get checkForNewMessagesAutomatically;

  /// No description provided for @checkMyEmailInboxForMessages.
  ///
  /// In en, this message translates to:
  /// **'Check my email inbox for messages that arrived since the last check. '**
  String get checkMyEmailInboxForMessages;

  /// No description provided for @checkNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get checkNow;

  /// No description provided for @checkYourEmailToConfirmYour.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm your NeoAgent account before signing in.'**
  String get checkYourEmailToConfirmYour;

  /// No description provided for @checkedArg1.
  ///
  /// In en, this message translates to:
  /// **'Checked {arg1}'**
  String checkedArg1(Object? arg1);

  /// No description provided for @chooseACategoryOrSearchAcross.
  ///
  /// In en, this message translates to:
  /// **'Choose a category or search across all settings.'**
  String get chooseACategoryOrSearchAcross;

  /// No description provided for @chooseAPerson.
  ///
  /// In en, this message translates to:
  /// **'Choose a person'**
  String get chooseAPerson;

  /// No description provided for @chooseAPlanToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan to get started.'**
  String get chooseAPlanToGetStarted;

  /// No description provided for @chooseAProjectFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a project folder'**
  String get chooseAProjectFolder;

  /// No description provided for @chooseArg1.
  ///
  /// In en, this message translates to:
  /// **'Choose {arg1}'**
  String chooseArg1(Object? arg1);

  /// No description provided for @chooseDefaultsForChatAgentsFallback.
  ///
  /// In en, this message translates to:
  /// **'Choose defaults for chat, agents, fallback behavior, and smart routing.'**
  String get chooseDefaultsForChatAgentsFallback;

  /// No description provided for @chooseGroups.
  ///
  /// In en, this message translates to:
  /// **'Choose groups'**
  String get chooseGroups;

  /// No description provided for @chooseHowMuchYouWantTo.
  ///
  /// In en, this message translates to:
  /// **'Choose how much you want to configure now. Both options can be changed later.'**
  String get chooseHowMuchYouWantTo;

  /// No description provided for @chooseHowThisTaskShouldStart.
  ///
  /// In en, this message translates to:
  /// **'Choose how this task should start. Manual runs only on Run Now. Schedule is time-based. Integration triggers fire from connected official apps.'**
  String get chooseHowThisTaskShouldStart;

  /// No description provided for @chooseOneToGetStartedNow.
  ///
  /// In en, this message translates to:
  /// **'Choose one to get started now. You can add more later.'**
  String get chooseOneToGetStartedNow;

  /// No description provided for @chooseTheLiveModelAndVoice.
  ///
  /// In en, this message translates to:
  /// **'Choose the live model and voice in Settings.'**
  String get chooseTheLiveModelAndVoice;

  /// No description provided for @chooseTheirGroup.
  ///
  /// In en, this message translates to:
  /// **'Choose their group'**
  String get chooseTheirGroup;

  /// No description provided for @chooseWhereThisPersonShouldBe.
  ///
  /// In en, this message translates to:
  /// **'Choose where this person should be allowed to talk to {arg1}. You can change this later under Who can message.'**
  String chooseWhereThisPersonShouldBe(Object? arg1);

  /// No description provided for @chooseWhichGroupsArg1ShouldJoin.
  ///
  /// In en, this message translates to:
  /// **'Choose which groups {arg1} should join even when nobody tags it. This platform may not tell tags apart from regular messages.'**
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1);

  /// No description provided for @chooseWhichModelsEveryAccountOn.
  ///
  /// In en, this message translates to:
  /// **'Choose which models every account on this server can pick and '**
  String get chooseWhichModelsEveryAccountOn;

  /// No description provided for @chooseWhoArg1TalksToAnd.
  ///
  /// In en, this message translates to:
  /// **'Choose who {arg1} talks to, and when it joins group chats.'**
  String chooseWhoArg1TalksToAnd(Object? arg1);

  /// No description provided for @chooseWhoCanReachArg1Then.
  ///
  /// In en, this message translates to:
  /// **'Choose who can reach {arg1}, then save your changes.'**
  String chooseWhoCanReachArg1Then(Object? arg1);

  /// No description provided for @chooseWhoMayMessageTheAgent.
  ///
  /// In en, this message translates to:
  /// **'Choose who may message the agent with \"Who can message\" on the WhatsApp card.'**
  String get chooseWhoMayMessageTheAgent;

  /// No description provided for @chooseYourDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Choose your\ndefault model.'**
  String get chooseYourDefaultModel;

  /// No description provided for @chromiumFilesTheTextEditorAnd.
  ///
  /// In en, this message translates to:
  /// **'Chromium, files, the text editor and terminal are all available from the Linux desktop.'**
  String get chromiumFilesTheTextEditorAnd;

  /// No description provided for @claudeCode.
  ///
  /// In en, this message translates to:
  /// **'Claude Code'**
  String get claudeCode;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @clearArg1.
  ///
  /// In en, this message translates to:
  /// **'Clear {arg1}?'**
  String clearArg1(Object? arg1);

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get clearFilter;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @clearView.
  ///
  /// In en, this message translates to:
  /// **'Clear view'**
  String get clearView;

  /// No description provided for @cliSession.
  ///
  /// In en, this message translates to:
  /// **'CLI session'**
  String get cliSession;

  /// No description provided for @clickIsNotSupportedOnThis.
  ///
  /// In en, this message translates to:
  /// **'click is not supported on this platform.'**
  String get clickIsNotSupportedOnThis;

  /// No description provided for @clickOnceToBeginCapturing.
  ///
  /// In en, this message translates to:
  /// **'Click once to begin capturing'**
  String get clickOnceToBeginCapturing;

  /// No description provided for @clickTypeAndInteractWithDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click, type, and interact with desktop apps.'**
  String get clickTypeAndInteractWithDesktop;

  /// No description provided for @clickedAtArg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'Clicked at ({arg1}, {arg2})'**
  String clickedAtArg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @clickedInTheBrowser.
  ///
  /// In en, this message translates to:
  /// **'Clicked in the browser'**
  String get clickedInTheBrowser;

  /// No description provided for @clientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get clientId;

  /// No description provided for @clientSecret.
  ///
  /// In en, this message translates to:
  /// **'Client secret'**
  String get clientSecret;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closeJ.
  ///
  /// In en, this message translates to:
  /// **'Close (⌘J)'**
  String get closeJ;

  /// No description provided for @closeTeachMode.
  ///
  /// In en, this message translates to:
  /// **'Close Teach Mode'**
  String get closeTeachMode;

  /// No description provided for @closingTheWindowCanEitherKeep.
  ///
  /// In en, this message translates to:
  /// **'Closing the window can either keep NeoAgent running in the background with tray access, or fully quit the desktop runtime.'**
  String get closingTheWindowCanEitherKeep;

  /// No description provided for @cloudAndSelfHostedInstancesAre.
  ///
  /// In en, this message translates to:
  /// **'Cloud and self-hosted instances are supported. Local and private-network URLs work when NeoAgent can reach them.'**
  String get cloudAndSelfHostedInstancesAre;

  /// No description provided for @cloudComputer.
  ///
  /// In en, this message translates to:
  /// **'Cloud computer'**
  String get cloudComputer;

  /// No description provided for @cloudComputerArg1.
  ///
  /// In en, this message translates to:
  /// **'Cloud computer · {arg1}'**
  String cloudComputerArg1(Object? arg1);

  /// No description provided for @cloudComputerSettingsSavedRestartThe.
  ///
  /// In en, this message translates to:
  /// **'Cloud computer settings saved. Restart the server to apply them.'**
  String get cloudComputerSettingsSavedRestartThe;

  /// No description provided for @cloudComputerVm.
  ///
  /// In en, this message translates to:
  /// **'Cloud computer (VM)'**
  String get cloudComputerVm;

  /// No description provided for @cloudComputers.
  ///
  /// In en, this message translates to:
  /// **'Cloud computers'**
  String get cloudComputers;

  /// No description provided for @codeHosting.
  ///
  /// In en, this message translates to:
  /// **'Code Hosting'**
  String get codeHosting;

  /// No description provided for @commaSeparatedChannelNamesWithoutThe.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated channel names, without the #.'**
  String get commaSeparatedChannelNamesWithoutThe;

  /// No description provided for @commaSeparatedForExampleGeneralHelp.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated, for example #general, #help'**
  String get commaSeparatedForExampleGeneralHelp;

  /// No description provided for @commaSeparatedTheIssueMustHave.
  ///
  /// In en, this message translates to:
  /// **'Comma separated. The issue must have all of them.'**
  String get commaSeparatedTheIssueMustHave;

  /// No description provided for @commandFailedArg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'Command failed ({arg1}): {arg2}'**
  String commandFailedArg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @commandIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Command is required.'**
  String get commandIsRequired;

  /// No description provided for @commandOutputAccumulatorIsNotActive.
  ///
  /// In en, this message translates to:
  /// **'Command output accumulator is not active.'**
  String get commandOutputAccumulatorIsNotActive;

  /// No description provided for @commandOutputUploadFailedArg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'Command output upload failed ({arg1}): {arg2}'**
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @commandOutputUploadOmittedArtifactMetadata.
  ///
  /// In en, this message translates to:
  /// **'Command output upload omitted artifact metadata.'**
  String get commandOutputUploadOmittedArtifactMetadata;

  /// No description provided for @commandOutputWasAlreadyFinalized.
  ///
  /// In en, this message translates to:
  /// **'Command output was already finalized.'**
  String get commandOutputWasAlreadyFinalized;

  /// No description provided for @commandVXdotoolDevNull2.
  ///
  /// In en, this message translates to:
  /// **'command -v xdotool >/dev/null 2>&1'**
  String get commandVXdotoolDevNull2;

  /// No description provided for @commandsApps.
  ///
  /// In en, this message translates to:
  /// **'Commands & apps'**
  String get commandsApps;

  /// No description provided for @commandsRunInTheSamePersistent.
  ///
  /// In en, this message translates to:
  /// **'Commands run in the same persistent computer used by the visible desktop.'**
  String get commandsRunInTheSamePersistent;

  /// No description provided for @commasOrLeaveBlankForEvery.
  ///
  /// In en, this message translates to:
  /// **'commas, or leave blank for every model.'**
  String get commasOrLeaveBlankForEvery;

  /// No description provided for @communityChatops.
  ///
  /// In en, this message translates to:
  /// **'Community & ChatOps'**
  String get communityChatops;

  /// No description provided for @completeSetup.
  ///
  /// In en, this message translates to:
  /// **'Complete Setup'**
  String get completeSetup;

  /// No description provided for @completeTheWorkflowOnTheDesktop.
  ///
  /// In en, this message translates to:
  /// **'Complete the workflow on the desktop.'**
  String get completeTheWorkflowOnTheDesktop;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @completelyBlockedTheAgentCannotUse.
  ///
  /// In en, this message translates to:
  /// **'Completely blocked — the agent cannot use this category.'**
  String get completelyBlockedTheAgentCannotUse;

  /// No description provided for @computerShell.
  ///
  /// In en, this message translates to:
  /// **'Computer shell'**
  String get computerShell;

  /// No description provided for @computerUsedByThisSession.
  ///
  /// In en, this message translates to:
  /// **'Computer used by this session'**
  String get computerUsedByThisSession;

  /// No description provided for @computerWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Computer workspace'**
  String get computerWorkspace;

  /// No description provided for @configurablePersonalWebhookBridge.
  ///
  /// In en, this message translates to:
  /// **'Configurable personal webhook bridge'**
  String get configurablePersonalWebhookBridge;

  /// No description provided for @configurableRelayOrWebhookBridge.
  ///
  /// In en, this message translates to:
  /// **'Configurable relay or webhook bridge'**
  String get configurableRelayOrWebhookBridge;

  /// No description provided for @configurableTalkWebhookBridge.
  ///
  /// In en, this message translates to:
  /// **'Configurable Talk webhook bridge'**
  String get configurableTalkWebhookBridge;

  /// No description provided for @configurableWebInboxBridge.
  ///
  /// In en, this message translates to:
  /// **'Configurable web inbox bridge'**
  String get configurableWebInboxBridge;

  /// No description provided for @configurableWebhookBridge.
  ///
  /// In en, this message translates to:
  /// **'Configurable webhook bridge'**
  String get configurableWebhookBridge;

  /// No description provided for @configurableWebhooks.
  ///
  /// In en, this message translates to:
  /// **'Configurable Webhooks'**
  String get configurableWebhooks;

  /// No description provided for @configurationOrInTheEnvFile.
  ///
  /// In en, this message translates to:
  /// **'Configuration or in the .env file.'**
  String get configurationOrInTheEnvFile;

  /// No description provided for @configure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get configure;

  /// No description provided for @configureWorkspaceBehaviorAndModelDefaults.
  ///
  /// In en, this message translates to:
  /// **'Configure workspace behavior and model defaults.'**
  String get configureWorkspaceBehaviorAndModelDefaults;

  /// No description provided for @configuredArg1.
  ///
  /// In en, this message translates to:
  /// **'Configured {arg1}'**
  String configuredArg1(Object? arg1);

  /// No description provided for @confirmEmailChanges.
  ///
  /// In en, this message translates to:
  /// **'Confirm email changes'**
  String get confirmEmailChanges;

  /// No description provided for @confirmNewSignUps.
  ///
  /// In en, this message translates to:
  /// **'Confirm new sign-ups'**
  String get confirmNewSignUps;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @confirmPassword2.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword2;

  /// No description provided for @confirmYourEmailBeforeSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email before signing in. Check the service email message from NeoAgent.'**
  String get confirmYourEmailBeforeSigningIn;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connectAMessagingPlatform.
  ///
  /// In en, this message translates to:
  /// **'Connect a\nmessaging platform.'**
  String get connectAMessagingPlatform;

  /// No description provided for @connectAPublicHttpsHomeAssistant.
  ///
  /// In en, this message translates to:
  /// **'Connect a public HTTPS Home Assistant endpoint with a Long-Lived Access Token. Local, loopback, and private network addresses are blocked by the server.'**
  String get connectAPublicHttpsHomeAssistant;

  /// No description provided for @connectAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect Account'**
  String get connectAccount;

  /// No description provided for @connectAppAccountsIndividuallySoThe.
  ///
  /// In en, this message translates to:
  /// **'Connect app accounts individually so the AI can use the right account for each official integration.'**
  String get connectAppAccountsIndividuallySoThe;

  /// No description provided for @connectArg1.
  ///
  /// In en, this message translates to:
  /// **'Connect {arg1}'**
  String connectArg1(Object? arg1);

  /// No description provided for @connectAsManyAccountsAsYou.
  ///
  /// In en, this message translates to:
  /// **'Connect as many accounts as you want. Each app can use a different account.'**
  String get connectAsManyAccountsAsYou;

  /// No description provided for @connectChannelsChooseWhoArg1Talks.
  ///
  /// In en, this message translates to:
  /// **'Connect channels, choose who {arg1} talks to, and watch recent activity.'**
  String connectChannelsChooseWhoArg1Talks(Object? arg1);

  /// No description provided for @connectInstance.
  ///
  /// In en, this message translates to:
  /// **'Connect Instance'**
  String get connectInstance;

  /// No description provided for @connectThisIntegrationFirstToPick.
  ///
  /// In en, this message translates to:
  /// **'Connect this integration first to pick an account.'**
  String get connectThisIntegrationFirstToPick;

  /// No description provided for @connectToThisServer.
  ///
  /// In en, this message translates to:
  /// **'Connect to this server'**
  String get connectToThisServer;

  /// No description provided for @connectWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Connect WhatsApp'**
  String get connectWhatsapp;

  /// No description provided for @connectYourNextcloudInstanceIncludingSelf.
  ///
  /// In en, this message translates to:
  /// **'Connect your Nextcloud instance, including self-hosted servers. NeoAgent opens Nextcloud\'\'s own login page so you can sign in with password, SSO, or 2FA.'**
  String get connectYourNextcloudInstanceIncludingSelf;

  /// No description provided for @connectYourSelfHostedNeorecallServer.
  ///
  /// In en, this message translates to:
  /// **'Connect your self-hosted NeoRecall server. NeoAgent receives read-only access to local search, memories, and transcript evidence after you approve the OAuth screen.'**
  String get connectYourSelfHostedNeorecallServer;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connectedAccount.
  ///
  /// In en, this message translates to:
  /// **'Connected Account'**
  String get connectedAccount;

  /// No description provided for @connectedArg1.
  ///
  /// In en, this message translates to:
  /// **'Connected {arg1}'**
  String connectedArg1(Object? arg1);

  /// No description provided for @connectedInstance.
  ///
  /// In en, this message translates to:
  /// **'Connected Instance'**
  String get connectedInstance;

  /// No description provided for @connectedNeorecallUser.
  ///
  /// In en, this message translates to:
  /// **'Connected NeoRecall User'**
  String get connectedNeorecallUser;

  /// No description provided for @connectedNextcloudUser.
  ///
  /// In en, this message translates to:
  /// **'Connected Nextcloud User'**
  String get connectedNextcloudUser;

  /// No description provided for @connectedServer.
  ///
  /// In en, this message translates to:
  /// **'Connected server'**
  String get connectedServer;

  /// No description provided for @connectingToTheLiveVoiceModel.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the live voice model...'**
  String get connectingToTheLiveVoiceModel;

  /// No description provided for @connectionArg1.
  ///
  /// In en, this message translates to:
  /// **'Connection #{arg1}'**
  String connectionArg1(Object? arg1);

  /// No description provided for @connectionId.
  ///
  /// In en, this message translates to:
  /// **'Connection ID'**
  String get connectionId;

  /// No description provided for @connectionLooksGood.
  ///
  /// In en, this message translates to:
  /// **'Connection looks good.'**
  String get connectionLooksGood;

  /// No description provided for @connectionMethod.
  ///
  /// In en, this message translates to:
  /// **'Connection Method'**
  String get connectionMethod;

  /// No description provided for @containsTextOptional.
  ///
  /// In en, this message translates to:
  /// **'Contains Text (optional)'**
  String get containsTextOptional;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @contentArg1.
  ///
  /// In en, this message translates to:
  /// **'Content: {arg1}'**
  String contentArg1(Object? arg1);

  /// No description provided for @contentSecurityPolicy.
  ///
  /// In en, this message translates to:
  /// **'content security policy'**
  String get contentSecurityPolicy;

  /// No description provided for @continue2.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue2;

  /// No description provided for @continueFullSetup.
  ///
  /// In en, this message translates to:
  /// **'Continue full setup'**
  String get continueFullSetup;

  /// No description provided for @continueRun.
  ///
  /// In en, this message translates to:
  /// **'Continue run'**
  String get continueRun;

  /// No description provided for @continueToSetup.
  ///
  /// In en, this message translates to:
  /// **'Continue to setup'**
  String get continueToSetup;

  /// No description provided for @controlSurface.
  ///
  /// In en, this message translates to:
  /// **'CONTROL SURFACE'**
  String get controlSurface;

  /// No description provided for @controlsAccessToArg1Tools.
  ///
  /// In en, this message translates to:
  /// **'Controls access to {arg1} tools.'**
  String controlsAccessToArg1Tools(Object? arg1);

  /// No description provided for @conversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get conversation;

  /// No description provided for @conversationIdUsedWhenThisAgent.
  ///
  /// In en, this message translates to:
  /// **'Conversation ID used when this agent starts a chat.'**
  String get conversationIdUsedWhenThisAgent;

  /// No description provided for @cookieSetup.
  ///
  /// In en, this message translates to:
  /// **'Cookie setup'**
  String get cookieSetup;

  /// No description provided for @cookiesNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Cookies not configured'**
  String get cookiesNotConfigured;

  /// No description provided for @copiedAsCsv.
  ///
  /// In en, this message translates to:
  /// **'Copied as CSV'**
  String get copiedAsCsv;

  /// No description provided for @copiedDebugInfo.
  ///
  /// In en, this message translates to:
  /// **'Copied debug info'**
  String get copiedDebugInfo;

  /// No description provided for @copiedExportForTheLast5.
  ///
  /// In en, this message translates to:
  /// **'Copied export for the last 5 messages'**
  String get copiedExportForTheLast5;

  /// No description provided for @copiedFullPrompt.
  ///
  /// In en, this message translates to:
  /// **'Copied full prompt'**
  String get copiedFullPrompt;

  /// No description provided for @copiedLogs.
  ///
  /// In en, this message translates to:
  /// **'Copied logs'**
  String get copiedLogs;

  /// No description provided for @copiedRunId.
  ///
  /// In en, this message translates to:
  /// **'Copied run ID'**
  String get copiedRunId;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copyAll;

  /// No description provided for @copyCodes.
  ///
  /// In en, this message translates to:
  /// **'Copy codes'**
  String get copyCodes;

  /// No description provided for @copyCsv.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV'**
  String get copyCsv;

  /// No description provided for @copyDebugInfo.
  ///
  /// In en, this message translates to:
  /// **'Copy debug info'**
  String get copyDebugInfo;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @copyLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy logs'**
  String get copyLogs;

  /// No description provided for @copyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Copy Prompt'**
  String get copyPrompt;

  /// No description provided for @copyResponse.
  ///
  /// In en, this message translates to:
  /// **'Copy response'**
  String get copyResponse;

  /// No description provided for @copyRunId.
  ///
  /// In en, this message translates to:
  /// **'Copy run ID'**
  String get copyRunId;

  /// No description provided for @copyWebhookUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy webhook URL'**
  String get copyWebhookUrl;

  /// No description provided for @core.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get core;

  /// No description provided for @coreMemory.
  ///
  /// In en, this message translates to:
  /// **'core memory'**
  String get coreMemory;

  /// No description provided for @coreServicesThisServerDependsOn.
  ///
  /// In en, this message translates to:
  /// **'Core services this server depends on.'**
  String get coreServicesThisServerDependsOn;

  /// No description provided for @corsDomainHttpsPublicUrlOrigins.
  ///
  /// In en, this message translates to:
  /// **'cors domain https public url origins'**
  String get corsDomainHttpsPublicUrlOrigins;

  /// No description provided for @couldHelp.
  ///
  /// In en, this message translates to:
  /// **'Could help'**
  String get couldHelp;

  /// No description provided for @couldNotApproveQrLogin.
  ///
  /// In en, this message translates to:
  /// **'Could not approve QR login.'**
  String get couldNotApproveQrLogin;

  /// No description provided for @couldNotApproveQrPairing.
  ///
  /// In en, this message translates to:
  /// **'Could not approve QR pairing.'**
  String get couldNotApproveQrPairing;

  /// No description provided for @couldNotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect.'**
  String get couldNotConnect;

  /// No description provided for @couldNotCreateBinding.
  ///
  /// In en, this message translates to:
  /// **'Could not create binding.'**
  String get couldNotCreateBinding;

  /// No description provided for @couldNotDeleteYourAccountArg1.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account: {arg1}'**
  String couldNotDeleteYourAccountArg1(Object? arg1);

  /// No description provided for @couldNotDisconnectBitwarden.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect Bitwarden.'**
  String get couldNotDisconnectBitwarden;

  /// No description provided for @couldNotDisconnectHomeAssistant.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect Home Assistant.'**
  String get couldNotDisconnectHomeAssistant;

  /// No description provided for @couldNotDisconnectNeorecall.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect NeoRecall.'**
  String get couldNotDisconnectNeorecall;

  /// No description provided for @couldNotDisconnectNextcloud.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect Nextcloud.'**
  String get couldNotDisconnectNextcloud;

  /// No description provided for @couldNotDisconnectTrello.
  ///
  /// In en, this message translates to:
  /// **'Could not disconnect Trello.'**
  String get couldNotDisconnectTrello;

  /// No description provided for @couldNotExportYourDataArg1.
  ///
  /// In en, this message translates to:
  /// **'Could not export your data: {arg1}'**
  String couldNotExportYourDataArg1(Object? arg1);

  /// No description provided for @couldNotLoadDecisions.
  ///
  /// In en, this message translates to:
  /// **'Could not load decisions'**
  String get couldNotLoadDecisions;

  /// No description provided for @couldNotLoadUsageData.
  ///
  /// In en, this message translates to:
  /// **'Could not load usage data.'**
  String get couldNotLoadUsageData;

  /// No description provided for @couldNotOpenLinuxSettingsAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Could not open Linux settings automatically.{arg1}'**
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1);

  /// No description provided for @couldNotOpenTheProviderLinking.
  ///
  /// In en, this message translates to:
  /// **'Could not open the provider linking page.'**
  String get couldNotOpenTheProviderLinking;

  /// No description provided for @couldNotOpenTheProviderSign.
  ///
  /// In en, this message translates to:
  /// **'Could not open the provider sign-in page.'**
  String get couldNotOpenTheProviderSign;

  /// No description provided for @couldNotOpenTheReleaseAsset.
  ///
  /// In en, this message translates to:
  /// **'Could not open the release asset.'**
  String get couldNotOpenTheReleaseAsset;

  /// No description provided for @couldNotOpenTrelloInYour.
  ///
  /// In en, this message translates to:
  /// **'Could not open Trello in your browser.'**
  String get couldNotOpenTrelloInYour;

  /// No description provided for @couldNotOpenWorkspaceFileDownload.
  ///
  /// In en, this message translates to:
  /// **'Could not open workspace file download.'**
  String get couldNotOpenWorkspaceFileDownload;

  /// No description provided for @couldNotReadTheAndroidApp.
  ///
  /// In en, this message translates to:
  /// **'Could not read the Android app package.'**
  String get couldNotReadTheAndroidApp;

  /// No description provided for @couldNotReadTheApk.
  ///
  /// In en, this message translates to:
  /// **'Could not read the APK.'**
  String get couldNotReadTheApk;

  /// No description provided for @couldNotRemoveKeyArg1.
  ///
  /// In en, this message translates to:
  /// **'Could not remove key: {arg1}'**
  String couldNotRemoveKeyArg1(Object? arg1);

  /// No description provided for @couldNotSaveAgent.
  ///
  /// In en, this message translates to:
  /// **'Could not save agent.'**
  String get couldNotSaveAgent;

  /// No description provided for @couldNotSaveBitwardenSetup.
  ///
  /// In en, this message translates to:
  /// **'Could not save Bitwarden setup.'**
  String get couldNotSaveBitwardenSetup;

  /// No description provided for @couldNotSaveHomeAssistantSetup.
  ///
  /// In en, this message translates to:
  /// **'Could not save Home Assistant setup.'**
  String get couldNotSaveHomeAssistantSetup;

  /// No description provided for @couldNotSaveNeorecallSetup.
  ///
  /// In en, this message translates to:
  /// **'Could not save NeoRecall setup.'**
  String get couldNotSaveNeorecallSetup;

  /// No description provided for @couldNotSaveNextcloudSetup.
  ///
  /// In en, this message translates to:
  /// **'Could not save Nextcloud setup.'**
  String get couldNotSaveNextcloudSetup;

  /// No description provided for @couldNotSaveTrelloSetup.
  ///
  /// In en, this message translates to:
  /// **'Could not save Trello setup.'**
  String get couldNotSaveTrelloSetup;

  /// No description provided for @couldNotSendConfirmationEmail.
  ///
  /// In en, this message translates to:
  /// **'could not send confirmation email'**
  String get couldNotSendConfirmationEmail;

  /// No description provided for @couldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Could not start'**
  String get couldNotStart;

  /// No description provided for @couldNotStartCheckoutCheckStripe.
  ///
  /// In en, this message translates to:
  /// **'Could not start checkout. Check Stripe configuration.'**
  String get couldNotStartCheckoutCheckStripe;

  /// No description provided for @countAIdAsFiles.
  ///
  /// In en, this message translates to:
  /// **'       COUNT(a.id) AS files,\n'**
  String get countAIdAsFiles;

  /// No description provided for @countAsRuns.
  ///
  /// In en, this message translates to:
  /// **'       COUNT(*) AS runs,\n'**
  String get countAsRuns;

  /// No description provided for @countDistinctRIdAsRuns.
  ///
  /// In en, this message translates to:
  /// **'       COUNT(DISTINCT r.id) AS runs,\n'**
  String get countDistinctRIdAsRuns;

  /// No description provided for @countRIdAsRuns.
  ///
  /// In en, this message translates to:
  /// **'       COUNT(r.id) AS runs\n'**
  String get countRIdAsRuns;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createAPasswordFirstToChange.
  ///
  /// In en, this message translates to:
  /// **'Create a password first to change your account email.'**
  String get createAPasswordFirstToChange;

  /// No description provided for @createAPasswordOrLinkAnother.
  ///
  /// In en, this message translates to:
  /// **'create a password or link another provider before removing this sign-in method'**
  String get createAPasswordOrLinkAnother;

  /// No description provided for @createATaskWhileThisAgent.
  ///
  /// In en, this message translates to:
  /// **'Create a task while this agent is selected.'**
  String get createATaskWhileThisAgent;

  /// No description provided for @createLink.
  ///
  /// In en, this message translates to:
  /// **'Create link'**
  String get createLink;

  /// No description provided for @createOrModifyFilesInYour.
  ///
  /// In en, this message translates to:
  /// **'Create or modify files in your workspace.'**
  String get createOrModifyFilesInYour;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create password'**
  String get createPassword;

  /// No description provided for @createSpecialistBotsWithSeparateMemory.
  ///
  /// In en, this message translates to:
  /// **'Create specialist bots with separate memory, settings, tools, and account assignments.'**
  String get createSpecialistBotsWithSeparateMemory;

  /// No description provided for @createTheFirstAccount.
  ///
  /// In en, this message translates to:
  /// **'Create the first account'**
  String get createTheFirstAccount;

  /// No description provided for @createUpdateOrDeleteSkills.
  ///
  /// In en, this message translates to:
  /// **'Create, update, or delete skills.'**
  String get createUpdateOrDeleteSkills;

  /// No description provided for @creatingYourSkill.
  ///
  /// In en, this message translates to:
  /// **'Creating your skill…'**
  String get creatingYourSkill;

  /// No description provided for @credentialBindings.
  ///
  /// In en, this message translates to:
  /// **'Credential bindings'**
  String get credentialBindings;

  /// No description provided for @credentialUse.
  ///
  /// In en, this message translates to:
  /// **'Credential Use'**
  String get credentialUse;

  /// No description provided for @cronBasedRecurringRunsAndOne.
  ///
  /// In en, this message translates to:
  /// **'Cron-based recurring runs and one-time timed execution.'**
  String get cronBasedRecurringRunsAndOne;

  /// No description provided for @cronExpression.
  ///
  /// In en, this message translates to:
  /// **'Cron expression'**
  String get cronExpression;

  /// No description provided for @ctrlEnterRunsTheQuery.
  ///
  /// In en, this message translates to:
  /// **'Ctrl/⌘ + Enter runs the query.'**
  String get ctrlEnterRunsTheQuery;

  /// No description provided for @ctrlShiftSpace.
  ///
  /// In en, this message translates to:
  /// **'Ctrl + Shift + Space'**
  String get ctrlShiftSpace;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @currencyMustBeA3Letter.
  ///
  /// In en, this message translates to:
  /// **'Currency must be a 3-letter code such as usd.'**
  String get currencyMustBeA3Letter;

  /// No description provided for @currentEmailArg1.
  ///
  /// In en, this message translates to:
  /// **'Current email: {arg1}'**
  String currentEmailArg1(Object? arg1);

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @currentPasswordIsIncorrect.
  ///
  /// In en, this message translates to:
  /// **'current password is incorrect'**
  String get currentPasswordIsIncorrect;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get currentPlan;

  /// No description provided for @currentPlan2.
  ///
  /// In en, this message translates to:
  /// **'CURRENT PLAN'**
  String get currentPlan2;

  /// No description provided for @currentTwoStepLoginCode.
  ///
  /// In en, this message translates to:
  /// **'Current two-step login code'**
  String get currentTwoStepLoginCode;

  /// No description provided for @customAccess.
  ///
  /// In en, this message translates to:
  /// **'Custom access'**
  String get customAccess;

  /// No description provided for @customCron.
  ///
  /// In en, this message translates to:
  /// **'Custom Cron'**
  String get customCron;

  /// No description provided for @customCronMustHave5Fields.
  ///
  /// In en, this message translates to:
  /// **'Custom Cron must have 5 fields.'**
  String get customCronMustHave5Fields;

  /// No description provided for @customEndpoint.
  ///
  /// In en, this message translates to:
  /// **'custom endpoint'**
  String get customEndpoint;

  /// No description provided for @customField.
  ///
  /// In en, this message translates to:
  /// **'Custom field'**
  String get customField;

  /// No description provided for @customHeader.
  ///
  /// In en, this message translates to:
  /// **'Custom header'**
  String get customHeader;

  /// No description provided for @customHeadersJson.
  ///
  /// In en, this message translates to:
  /// **'Custom headers (JSON)'**
  String get customHeadersJson;

  /// No description provided for @customOpenaiCompatible.
  ///
  /// In en, this message translates to:
  /// **'Custom OpenAI-compatible'**
  String get customOpenaiCompatible;

  /// No description provided for @customOpenaiCompatibleEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Custom OpenAI-compatible endpoint'**
  String get customOpenaiCompatibleEndpoint;

  /// No description provided for @customOutgoingUrl.
  ///
  /// In en, this message translates to:
  /// **'Custom outgoing URL'**
  String get customOutgoingUrl;

  /// No description provided for @customersOverridePlanStatusCanceledTrialing.
  ///
  /// In en, this message translates to:
  /// **'customers override plan status canceled trialing'**
  String get customersOverridePlanStatusCanceledTrialing;

  /// No description provided for @dAllowedPermissionsJsonAsAllowed.
  ///
  /// In en, this message translates to:
  /// **'       d.allowed_permissions_json AS allowed,\n'**
  String get dAllowedPermissionsJsonAsAllowed;

  /// No description provided for @dCreatedAtAsSince.
  ///
  /// In en, this message translates to:
  /// **'       d.created_at AS since\n'**
  String get dCreatedAtAsSince;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @dailyRecap.
  ///
  /// In en, this message translates to:
  /// **'Daily recap'**
  String get dailyRecap;

  /// No description provided for @databaseQuerySelectCsvTemplates.
  ///
  /// In en, this message translates to:
  /// **'database query select csv templates'**
  String get databaseQuerySelectCsvTemplates;

  /// No description provided for @dayArg1.
  ///
  /// In en, this message translates to:
  /// **'Day {arg1}'**
  String dayArg1(Object? arg1);

  /// No description provided for @dayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get dayOfMonth;

  /// No description provided for @deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// No description provided for @deactivateArg1.
  ///
  /// In en, this message translates to:
  /// **'Deactivate {arg1}?'**
  String deactivateArg1(Object? arg1);

  /// No description provided for @decideWhichToolsYourAgentMay.
  ///
  /// In en, this message translates to:
  /// **'decide which tools your agent may use. They see your name and '**
  String get decideWhichToolsYourAgentMay;

  /// No description provided for @decisionHigherUpTheChainWins.
  ///
  /// In en, this message translates to:
  /// **'decision higher up the chain wins and shows a lock with the '**
  String get decisionHigherUpTheChainWins;

  /// No description provided for @decisionsFromTodayThenListAnything.
  ///
  /// In en, this message translates to:
  /// **'decisions from today, then list anything I should follow up on '**
  String get decisionsFromTodayThenListAnything;

  /// No description provided for @decisionsShowUpHereAsArg1.
  ///
  /// In en, this message translates to:
  /// **'Decisions show up here as {arg1} reads approved {arg2} groups. Only the latest 30 are kept, and they reset when the server restarts.'**
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2);

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @deepRunStepArg1.
  ///
  /// In en, this message translates to:
  /// **'deep run · step {arg1}'**
  String deepRunStepArg1(Object? arg1);

  /// No description provided for @deepgramKey.
  ///
  /// In en, this message translates to:
  /// **'Deepgram key'**
  String get deepgramKey;

  /// No description provided for @default2.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get default2;

  /// No description provided for @default3.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get default3;

  /// No description provided for @defaultArg1.
  ///
  /// In en, this message translates to:
  /// **'Default ({arg1})'**
  String defaultArg1(Object? arg1);

  /// No description provided for @defaultConversation.
  ///
  /// In en, this message translates to:
  /// **'Default conversation'**
  String get defaultConversation;

  /// No description provided for @defaultForNewGroups.
  ///
  /// In en, this message translates to:
  /// **'Default for new groups'**
  String get defaultForNewGroups;

  /// No description provided for @defaultGroupParticipation.
  ///
  /// In en, this message translates to:
  /// **'Default group participation'**
  String get defaultGroupParticipation;

  /// No description provided for @defaultNeoagentWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Default NeoAgent Workspace'**
  String get defaultNeoagentWorkspace;

  /// No description provided for @defaultOpenai.
  ///
  /// In en, this message translates to:
  /// **'Default (OpenAI)'**
  String get defaultOpenai;

  /// No description provided for @defaultRateLimits.
  ///
  /// In en, this message translates to:
  /// **'Default rate limits'**
  String get defaultRateLimits;

  /// No description provided for @defaultRateLimitsSaved.
  ///
  /// In en, this message translates to:
  /// **'Default rate limits saved.'**
  String get defaultRateLimitsSaved;

  /// No description provided for @defaultRecommended.
  ///
  /// In en, this message translates to:
  /// **'Default (recommended)'**
  String get defaultRecommended;

  /// No description provided for @defaultRouting.
  ///
  /// In en, this message translates to:
  /// **'Default Routing'**
  String get defaultRouting;

  /// No description provided for @defaultSpace.
  ///
  /// In en, this message translates to:
  /// **'Default space'**
  String get defaultSpace;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountPermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete account permanently?'**
  String get deleteAccountPermanently;

  /// No description provided for @deleteAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete an account'**
  String get deleteAnAccount;

  /// No description provided for @deleteArg1.
  ///
  /// In en, this message translates to:
  /// **'Delete @{arg1}?'**
  String deleteArg1(Object? arg1);

  /// No description provided for @deleteArg12.
  ///
  /// In en, this message translates to:
  /// **'Delete ({arg1})'**
  String deleteArg12(Object? arg1);

  /// No description provided for @deleteArg1Arg2Permanently.
  ///
  /// In en, this message translates to:
  /// **'Delete {arg1} {arg2} permanently?'**
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2);

  /// No description provided for @deleteBinding.
  ///
  /// In en, this message translates to:
  /// **'Delete binding'**
  String get deleteBinding;

  /// No description provided for @deleteCoreMemoryEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete core memory entry?'**
  String get deleteCoreMemoryEntry;

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @deleteMcpServer.
  ///
  /// In en, this message translates to:
  /// **'Delete MCP server?'**
  String get deleteMcpServer;

  /// No description provided for @deleteMemory.
  ///
  /// In en, this message translates to:
  /// **'Delete memory?'**
  String get deleteMemory;

  /// No description provided for @deletePermanentlyErasesAnAccountAnd.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently erases an account and all of its data '**
  String get deletePermanentlyErasesAnAccountAnd;

  /// No description provided for @deleteRun.
  ///
  /// In en, this message translates to:
  /// **'Delete run?'**
  String get deleteRun;

  /// No description provided for @deleteRun2.
  ///
  /// In en, this message translates to:
  /// **'Delete run'**
  String get deleteRun2;

  /// No description provided for @deleteSelectedMemories.
  ///
  /// In en, this message translates to:
  /// **'Delete selected memories?'**
  String get deleteSelectedMemories;

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete session?'**
  String get deleteSession;

  /// No description provided for @deleteSkill.
  ///
  /// In en, this message translates to:
  /// **'Delete skill?'**
  String get deleteSkill;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get deleteTask;

  /// No description provided for @deletedArg1.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{arg1}\".'**
  String deletedArg1(Object? arg1);

  /// No description provided for @deletedArg1AndAllOfTheir.
  ///
  /// In en, this message translates to:
  /// **'Deleted @{arg1} and all of their data.'**
  String deletedArg1AndAllOfTheir(Object? arg1);

  /// No description provided for @deletionRemovesAllYourConversationsMemories.
  ///
  /// In en, this message translates to:
  /// **'Deletion removes all your conversations, memories, files, tasks and '**
  String get deletionRemovesAllYourConversationsMemories;

  /// No description provided for @deliverableArtifactProduced.
  ///
  /// In en, this message translates to:
  /// **'Deliverable artifact produced'**
  String get deliverableArtifactProduced;

  /// No description provided for @deliverableCompleted.
  ///
  /// In en, this message translates to:
  /// **'Deliverable completed'**
  String get deliverableCompleted;

  /// No description provided for @deliverableExecutionStarted.
  ///
  /// In en, this message translates to:
  /// **'Deliverable execution started'**
  String get deliverableExecutionStarted;

  /// No description provided for @deliverableSelected.
  ///
  /// In en, this message translates to:
  /// **'Deliverable selected'**
  String get deliverableSelected;

  /// No description provided for @deliverableValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Deliverable validation failed'**
  String get deliverableValidationFailed;

  /// No description provided for @deliverableValidationStarted.
  ///
  /// In en, this message translates to:
  /// **'Deliverable validation started'**
  String get deliverableValidationStarted;

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// No description provided for @describeTheOutcomeThenDemonstrateIt.
  ///
  /// In en, this message translates to:
  /// **'Describe the outcome, then demonstrate it on the desktop'**
  String get describeTheOutcomeThenDemonstrateIt;

  /// No description provided for @describeWhatToBuildOrChange.
  ///
  /// In en, this message translates to:
  /// **'Describe what to build or change…'**
  String get describeWhatToBuildOrChange;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @desktopApp.
  ///
  /// In en, this message translates to:
  /// **'Desktop app'**
  String get desktopApp;

  /// No description provided for @desktopAppControlsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Desktop app controls available'**
  String get desktopAppControlsAvailable;

  /// No description provided for @desktopCaptureIsNotAvailableOn.
  ///
  /// In en, this message translates to:
  /// **'Desktop capture is not available on this platform.'**
  String get desktopCaptureIsNotAvailableOn;

  /// No description provided for @desktopCommandOutputUploadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Desktop command output upload cancelled.'**
  String get desktopCommandOutputUploadCancelled;

  /// No description provided for @desktopCompanionCommandWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion command was cancelled.'**
  String get desktopCompanionCommandWasCancelled;

  /// No description provided for @desktopCompanionConnectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion connection timed out.'**
  String get desktopCompanionConnectionTimedOut;

  /// No description provided for @desktopCompanionHandshakeTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion handshake timed out.'**
  String get desktopCompanionHandshakeTimedOut;

  /// No description provided for @desktopCompanionIsNotAvailableHere.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion is not available here.'**
  String get desktopCompanionIsNotAvailableHere;

  /// No description provided for @desktopCompanionIsPausedLocally.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion is paused locally.'**
  String get desktopCompanionIsPausedLocally;

  /// No description provided for @desktopCompanionMessageHandlingFailedArg1.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion message handling failed: {arg1}'**
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1);

  /// No description provided for @desktopCompanionPermissionSettingsAreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion permission settings are unavailable on web.'**
  String get desktopCompanionPermissionSettingsAreUnavailable;

  /// No description provided for @desktopCompanionPermissionSettingsAreUnavailable2.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion permission settings are unavailable on this platform.'**
  String get desktopCompanionPermissionSettingsAreUnavailable2;

  /// No description provided for @desktopCompanionRejected.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion rejected.'**
  String get desktopCompanionRejected;

  /// No description provided for @desktopCompanionResponseFailedArg1.
  ///
  /// In en, this message translates to:
  /// **'Desktop companion response failed: {arg1}'**
  String desktopCompanionResponseFailedArg1(Object? arg1);

  /// No description provided for @desktopControl.
  ///
  /// In en, this message translates to:
  /// **'Desktop Control'**
  String get desktopControl;

  /// No description provided for @desktopFailedToStart.
  ///
  /// In en, this message translates to:
  /// **'Desktop failed to start'**
  String get desktopFailedToStart;

  /// No description provided for @desktopStreamCaptureFailedArg1.
  ///
  /// In en, this message translates to:
  /// **'Desktop stream capture failed: {arg1}'**
  String desktopStreamCaptureFailedArg1(Object? arg1);

  /// No description provided for @desktopToFinishTheJob.
  ///
  /// In en, this message translates to:
  /// **'desktop to finish the job.'**
  String get desktopToFinishTheJob;

  /// No description provided for @destinationId.
  ///
  /// In en, this message translates to:
  /// **'Destination ID'**
  String get destinationId;

  /// No description provided for @detail.
  ///
  /// In en, this message translates to:
  /// **'DETAIL'**
  String get detail;

  /// No description provided for @deviceAccess.
  ///
  /// In en, this message translates to:
  /// **'Device access'**
  String get deviceAccess;

  /// No description provided for @deviceIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Device IP address'**
  String get deviceIpAddress;

  /// No description provided for @deviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Device Settings'**
  String get deviceSettings;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @diagnosticsSaved.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics saved.'**
  String get diagnosticsSaved;

  /// No description provided for @directBluebubblesImessageBridge.
  ///
  /// In en, this message translates to:
  /// **'Direct BlueBubbles iMessage bridge'**
  String get directBluebubblesImessageBridge;

  /// No description provided for @directMessagesRemainResponsiveAllowlistedGroups.
  ///
  /// In en, this message translates to:
  /// **'Direct messages remain responsive. Allowlisted groups use the participation mode below.'**
  String get directMessagesRemainResponsiveAllowlistedGroups;

  /// No description provided for @directoryDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Directory does not exist.'**
  String get directoryDoesNotExist;

  /// No description provided for @disable2fa.
  ///
  /// In en, this message translates to:
  /// **'Disable 2FA'**
  String get disable2fa;

  /// No description provided for @disableAll.
  ///
  /// In en, this message translates to:
  /// **'Disable all'**
  String get disableAll;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @disconnectHomeAssistant.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Home Assistant?'**
  String get disconnectHomeAssistant;

  /// No description provided for @disconnectNeorecall.
  ///
  /// In en, this message translates to:
  /// **'Disconnect NeoRecall?'**
  String get disconnectNeorecall;

  /// No description provided for @disconnectNextcloud.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Nextcloud?'**
  String get disconnectNextcloud;

  /// No description provided for @disconnectPlatform.
  ///
  /// In en, this message translates to:
  /// **'Disconnect platform'**
  String get disconnectPlatform;

  /// No description provided for @disconnectTrello.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Trello?'**
  String get disconnectTrello;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @discoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Discovery failed'**
  String get discoveryFailed;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @displayIdIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Display ID is required.'**
  String get displayIdIsRequired;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @displayNameMustBe64Characters.
  ///
  /// In en, this message translates to:
  /// **'Display name must be 64 characters or fewer.'**
  String get displayNameMustBe64Characters;

  /// No description provided for @displayNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Display name saved.'**
  String get displayNameSaved;

  /// No description provided for @doNotIncludeYourUsernameOr.
  ///
  /// In en, this message translates to:
  /// **'Do not include your username or email.'**
  String get doNotIncludeYourUsernameOr;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @downloadACopyOfYourData.
  ///
  /// In en, this message translates to:
  /// **'Download a copy of your data. Admin accounts can’t delete '**
  String get downloadACopyOfYourData;

  /// No description provided for @downloadACopyOfYourData2.
  ///
  /// In en, this message translates to:
  /// **'Download a copy of your data, or permanently delete your account. '**
  String get downloadACopyOfYourData2;

  /// No description provided for @downloadArg1.
  ///
  /// In en, this message translates to:
  /// **'Download {arg1}'**
  String downloadArg1(Object? arg1);

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get downloadUpdate;

  /// No description provided for @downloadingTheNeoagentBackend.
  ///
  /// In en, this message translates to:
  /// **'Downloading the NeoAgent backend'**
  String get downloadingTheNeoagentBackend;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @dragIsNotSupportedOnThis.
  ///
  /// In en, this message translates to:
  /// **'drag is not supported on this platform.'**
  String get dragIsNotSupportedOnThis;

  /// No description provided for @draggedOnTheScreen.
  ///
  /// In en, this message translates to:
  /// **'Dragged on the screen'**
  String get draggedOnTheScreen;

  /// No description provided for @dropAnApkOrApkBundle.
  ///
  /// In en, this message translates to:
  /// **'Drop an APK or APK bundle here to install it'**
  String get dropAnApkOrApkBundle;

  /// No description provided for @dropApkOrApksHere.
  ///
  /// In en, this message translates to:
  /// **'Drop APK or .apks Here'**
  String get dropApkOrApksHere;

  /// No description provided for @durableInstructionsForVoiceAndInteraction.
  ///
  /// In en, this message translates to:
  /// **'Durable instructions for voice and interaction style. Safety and execution rules still take priority.'**
  String get durableInstructionsForVoiceAndInteraction;

  /// No description provided for @eGAlexSLaptop.
  ///
  /// In en, this message translates to:
  /// **'e.g. Alex’s laptop'**
  String get eGAlexSLaptop;

  /// No description provided for @eGMyLocalServer.
  ///
  /// In en, this message translates to:
  /// **'e.g. My local server'**
  String get eGMyLocalServer;

  /// No description provided for @eachAgentDecides.
  ///
  /// In en, this message translates to:
  /// **'Each agent decides'**
  String get eachAgentDecides;

  /// No description provided for @eachAgentNowDecidesInIts.
  ///
  /// In en, this message translates to:
  /// **'Each agent now decides in its own settings.'**
  String get eachAgentNowDecidesInIts;

  /// No description provided for @eachAgentSwitchesJevOnUnder.
  ///
  /// In en, this message translates to:
  /// **'Each agent switches Jev on under Settings › Models. It '**
  String get eachAgentSwitchesJevOnUnder;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editAgent.
  ///
  /// In en, this message translates to:
  /// **'Edit Agent'**
  String get editAgent;

  /// No description provided for @editArg1.
  ///
  /// In en, this message translates to:
  /// **'Edit {arg1}'**
  String editArg1(Object? arg1);

  /// No description provided for @editCoreMemoryEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit Core Memory Entry'**
  String get editCoreMemoryEntry;

  /// No description provided for @editInstructions.
  ///
  /// In en, this message translates to:
  /// **'Edit instructions'**
  String get editInstructions;

  /// No description provided for @editMcpServer.
  ///
  /// In en, this message translates to:
  /// **'Edit MCP Server'**
  String get editMcpServer;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// No description provided for @editedArg1.
  ///
  /// In en, this message translates to:
  /// **'Edited {arg1}'**
  String editedArg1(Object? arg1);

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailAccountOwnersAboutSignIns.
  ///
  /// In en, this message translates to:
  /// **'Email account owners about sign-ins that look unusual.'**
  String get emailAccountOwnersAboutSignIns;

  /// No description provided for @emailAccountOwnersWhenTheirAccount.
  ///
  /// In en, this message translates to:
  /// **'Email account owners when their account details change.'**
  String get emailAccountOwnersWhenTheirAccount;

  /// No description provided for @emailCode.
  ///
  /// In en, this message translates to:
  /// **'Email code'**
  String get emailCode;

  /// No description provided for @emailConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'email confirmation required'**
  String get emailConfirmationRequired;

  /// No description provided for @emailIsAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'email is already in use'**
  String get emailIsAlreadyInUse;

  /// No description provided for @emailSavedIfConfirmationIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Email saved. If confirmation is required, check the new address for a NeoAgent confirmation link.'**
  String get emailSavedIfConfirmationIsRequired;

  /// No description provided for @emailSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Email settings saved.'**
  String get emailSettingsSaved;

  /// No description provided for @emailUnverified.
  ///
  /// In en, this message translates to:
  /// **'Email unverified'**
  String get emailUnverified;

  /// No description provided for @emailsAiActionsTasksAndRun.
  ///
  /// In en, this message translates to:
  /// **'Emails, AI actions, tasks and run activity in one chronological feed.'**
  String get emailsAiActionsTasksAndRun;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// No description provided for @emptyFile.
  ///
  /// In en, this message translates to:
  /// **'Empty file'**
  String get emptyFile;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Empty folder'**
  String get emptyFolder;

  /// No description provided for @emptyUsesTheServerDefaultArg1.
  ///
  /// In en, this message translates to:
  /// **'Empty uses the server default ({arg1}).'**
  String emptyUsesTheServerDefaultArg1(Object? arg1);

  /// No description provided for @enable2fa.
  ///
  /// In en, this message translates to:
  /// **'Enable 2FA'**
  String get enable2fa;

  /// No description provided for @enableAll.
  ///
  /// In en, this message translates to:
  /// **'Enable all'**
  String get enableAll;

  /// No description provided for @enableBehaviorModules.
  ///
  /// In en, this message translates to:
  /// **'Enable behavior modules'**
  String get enableBehaviorModules;

  /// No description provided for @enableOrDisableModels.
  ///
  /// In en, this message translates to:
  /// **'Enable or disable models'**
  String get enableOrDisableModels;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @encryptedPrivateToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Encrypted, private to your account'**
  String get encryptedPrivateToYourAccount;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @endCall.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get endCall;

  /// No description provided for @endVoiceCall.
  ///
  /// In en, this message translates to:
  /// **'End voice call?'**
  String get endVoiceCall;

  /// No description provided for @endpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get endpoint;

  /// No description provided for @enterAPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a password.'**
  String get enterAPassword;

  /// No description provided for @enterAUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter a username.'**
  String get enterAUsername;

  /// No description provided for @enterAValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get enterAValidEmailAddress;

  /// No description provided for @enterAnAddressManually.
  ///
  /// In en, this message translates to:
  /// **'Enter an address manually'**
  String get enterAnAddressManually;

  /// No description provided for @enterAnApiKeyFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter an API key first.'**
  String get enterAnApiKeyFirst;

  /// No description provided for @enterInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Enter invite link'**
  String get enterInviteLink;

  /// No description provided for @enterTheAddressOfANeoagent.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of a NeoAgent server.'**
  String get enterTheAddressOfANeoagent;

  /// No description provided for @enterTheDetailsArg1GaveYou.
  ///
  /// In en, this message translates to:
  /// **'Enter the details {arg1} gave you so {arg2} can send and receive messages.'**
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2);

  /// No description provided for @enterYour2faOrRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your 2FA or recovery code.'**
  String get enterYour2faOrRecoveryCode;

  /// No description provided for @enterYourCurrentPasswordToChange.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password to change it.'**
  String get enterYourCurrentPasswordToChange;

  /// No description provided for @enterYourCurrentPasswordToSave.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password to save email changes.'**
  String get enterYourCurrentPasswordToSave;

  /// No description provided for @enterYourNeoagentAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter your NeoAgent account details.'**
  String get enterYourNeoagentAccountDetails;

  /// No description provided for @enterYourUsernameOrAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your username or account email. NeoAgent will send a reset link if it can match the account.'**
  String get enterYourUsernameOrAccountEmail;

  /// No description provided for @enterYourUsernameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your username or email.'**
  String get enterYourUsernameOrEmail;

  /// No description provided for @entityArg1.
  ///
  /// In en, this message translates to:
  /// **'Entity: {arg1}'**
  String entityArg1(Object? arg1);

  /// No description provided for @environment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environment;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorArg1.
  ///
  /// In en, this message translates to:
  /// **'\nerror: {arg1}'**
  String errorArg1(Object? arg1);

  /// No description provided for @errorArg12.
  ///
  /// In en, this message translates to:
  /// **'Error: {arg1}'**
  String errorArg12(Object? arg1);

  /// No description provided for @errorsFromTheRecentLogGrouped.
  ///
  /// In en, this message translates to:
  /// **'Errors from the recent log, grouped by message.'**
  String get errorsFromTheRecentLogGrouped;

  /// No description provided for @errorsProblemsFailures.
  ///
  /// In en, this message translates to:
  /// **'errors problems failures'**
  String get errorsProblemsFailures;

  /// No description provided for @eventDetail.
  ///
  /// In en, this message translates to:
  /// **'Event detail'**
  String get eventDetail;

  /// No description provided for @eventTypesCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Event Types (comma separated)'**
  String get eventTypesCommaSeparated;

  /// No description provided for @every15Minutes.
  ///
  /// In en, this message translates to:
  /// **'Every 15 minutes'**
  String get every15Minutes;

  /// No description provided for @every30Minutes.
  ///
  /// In en, this message translates to:
  /// **'Every 30 minutes'**
  String get every30Minutes;

  /// No description provided for @everyAccountOnThisServerLoses.
  ///
  /// In en, this message translates to:
  /// **'Every account on this server loses this shared key. Accounts '**
  String get everyAccountOnThisServerLoses;

  /// No description provided for @everyAccountOnThisServerSecrets.
  ///
  /// In en, this message translates to:
  /// **'every account on this server. Secrets are write-only: leave '**
  String get everyAccountOnThisServerSecrets;

  /// No description provided for @everyAccountOnThisServerUses.
  ///
  /// In en, this message translates to:
  /// **'Every account on this server uses this address for '**
  String get everyAccountOnThisServerUses;

  /// No description provided for @everyAccountSSubscriptionMostRecently.
  ///
  /// In en, this message translates to:
  /// **'Every account’s subscription, most recently changed first. '**
  String get everyAccountSSubscriptionMostRecently;

  /// No description provided for @everyActiveSessionForThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Every active session for this account ends. They can sign in '**
  String get everyActiveSessionForThisAccount;

  /// No description provided for @everyAgentUsesJevAgentsCan.
  ///
  /// In en, this message translates to:
  /// **'Every agent uses Jev. Agents can no longer switch it off '**
  String get everyAgentUsesJevAgentsCan;

  /// No description provided for @everyDay0800.
  ///
  /// In en, this message translates to:
  /// **'Every day · 08:00'**
  String get everyDay0800;

  /// No description provided for @everyDay2000.
  ///
  /// In en, this message translates to:
  /// **'Every day · 20:00'**
  String get everyDay2000;

  /// No description provided for @everyHour.
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get everyHour;

  /// No description provided for @everyModel.
  ///
  /// In en, this message translates to:
  /// **'every model.'**
  String get everyModel;

  /// No description provided for @everyRunOnThisServerAll.
  ///
  /// In en, this message translates to:
  /// **'Every run on this server, all time.'**
  String get everyRunOnThisServerAll;

  /// No description provided for @everySensitiveToolRequiresApprovalEvery.
  ///
  /// In en, this message translates to:
  /// **'Every sensitive tool requires approval, every time.'**
  String get everySensitiveToolRequiresApprovalEvery;

  /// No description provided for @everySessionGetsAPrivateCloud.
  ///
  /// In en, this message translates to:
  /// **'Every session gets a private cloud computer, so NeoAgent can do '**
  String get everySessionGetsAPrivateCloud;

  /// No description provided for @everyToolRunsWithoutAskingExcept.
  ///
  /// In en, this message translates to:
  /// **'Every tool runs without asking, except the ones the person '**
  String get everyToolRunsWithoutAskingExcept;

  /// No description provided for @everyoneInTheseGroupsChannelsOr.
  ///
  /// In en, this message translates to:
  /// **'Everyone in these groups, channels, or rooms can talk to {arg1}.'**
  String everyoneInTheseGroupsChannelsOr(Object? arg1);

  /// No description provided for @everyoneInThisGroup.
  ///
  /// In en, this message translates to:
  /// **'Everyone in this group'**
  String get everyoneInThisGroup;

  /// No description provided for @everythingArg1TurnedOffForYour.
  ///
  /// In en, this message translates to:
  /// **'Everything {arg1} turned off for your agent comes '**
  String everythingArg1TurnedOffForYour(Object? arg1);

  /// No description provided for @everythingElseIsTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Everything else is turned off.'**
  String get everythingElseIsTurnedOff;

  /// No description provided for @everythingIsAvailableFromTheDesktop.
  ///
  /// In en, this message translates to:
  /// **'Everything is available from the desktop.'**
  String get everythingIsAvailableFromTheDesktop;

  /// No description provided for @everythingTheAgentCanUseOfficial.
  ///
  /// In en, this message translates to:
  /// **'Everything the agent can use: official integrations, MCP servers, and skills.'**
  String get everythingTheAgentCanUseOfficial;

  /// No description provided for @everythingYouTurnedOffForArg1.
  ///
  /// In en, this message translates to:
  /// **'Everything you turned off for {arg1} comes back '**
  String everythingYouTurnedOffForArg1(Object? arg1);

  /// No description provided for @exactWebOriginsAllowedToMake.
  ///
  /// In en, this message translates to:
  /// **'Exact web origins allowed to make cross-origin requests, '**
  String get exactWebOriginsAllowedToMake;

  /// No description provided for @executeJavascriptInsideYourBrowserSession.
  ///
  /// In en, this message translates to:
  /// **'Execute JavaScript inside your browser session.'**
  String get executeJavascriptInsideYourBrowserSession;

  /// No description provided for @execution.
  ///
  /// In en, this message translates to:
  /// **'Execution'**
  String get execution;

  /// No description provided for @executionDetailsAreUnavailableForThis.
  ///
  /// In en, this message translates to:
  /// **'Execution details are unavailable for this run.'**
  String get executionDetailsAreUnavailableForThis;

  /// No description provided for @executionPlanCreated.
  ///
  /// In en, this message translates to:
  /// **'Execution plan created.'**
  String get executionPlanCreated;

  /// No description provided for @exerciseArg1Sessions.
  ///
  /// In en, this message translates to:
  /// **'Exercise {arg1} sessions'**
  String exerciseArg1Sessions(Object? arg1);

  /// No description provided for @existingSubscribersKeepAccessUntilTheir.
  ///
  /// In en, this message translates to:
  /// **'existing subscribers keep access until their period ends.'**
  String get existingSubscribersKeepAccessUntilTheir;

  /// No description provided for @exitArg1.
  ///
  /// In en, this message translates to:
  /// **'[exit {arg1}]'**
  String exitArg1(Object? arg1);

  /// No description provided for @expiresArg1.
  ///
  /// In en, this message translates to:
  /// **'Expires {arg1}'**
  String expiresArg1(Object? arg1);

  /// No description provided for @explainThisProject.
  ///
  /// In en, this message translates to:
  /// **'Explain this project'**
  String get explainThisProject;

  /// No description provided for @exploredArg1.
  ///
  /// In en, this message translates to:
  /// **'Explored {arg1}'**
  String exploredArg1(Object? arg1);

  /// No description provided for @exploredArg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'Explored {arg1}{arg2}'**
  String exploredArg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @exploredTheWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Explored the workspace'**
  String get exploredTheWorkspace;

  /// No description provided for @exportAll.
  ///
  /// In en, this message translates to:
  /// **'Export all'**
  String get exportAll;

  /// No description provided for @exportFailedArg1.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {arg1}'**
  String exportFailedArg1(Object? arg1);

  /// No description provided for @exportLast5Messages.
  ///
  /// In en, this message translates to:
  /// **'Export last 5 messages'**
  String get exportLast5Messages;

  /// No description provided for @exportMyData.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get exportMyData;

  /// No description provided for @externalBrowserLaunchFailedWithExit.
  ///
  /// In en, this message translates to:
  /// **'External browser launch failed with exit code {arg1}.'**
  String externalBrowserLaunchFailedWithExit(Object? arg1);

  /// No description provided for @externalBrowserLaunchIsNotSupported.
  ///
  /// In en, this message translates to:
  /// **'External browser launch is not supported on this platform.'**
  String get externalBrowserLaunchIsNotSupported;

  /// No description provided for @externalBrowserLaunchTimedOut.
  ///
  /// In en, this message translates to:
  /// **'External browser launch timed out.'**
  String get externalBrowserLaunchTimedOut;

  /// No description provided for @externalMcpTools.
  ///
  /// In en, this message translates to:
  /// **'External & MCP Tools'**
  String get externalMcpTools;

  /// No description provided for @extraButtons.
  ///
  /// In en, this message translates to:
  /// **'Extra Buttons'**
  String get extraButtons;

  /// No description provided for @extractingTheNeoagentRuntime.
  ///
  /// In en, this message translates to:
  /// **'Extracting the NeoAgent runtime'**
  String get extractingTheNeoagentRuntime;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @failedToConnectArg1.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect: {arg1}'**
  String failedToConnectArg1(Object? arg1);

  /// No description provided for @failedToConnectArg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect {arg1}: {arg2}'**
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @failedToDeleteArg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete \"{arg1}\": {arg2}'**
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @failedToDismissOnboardingArg1.
  ///
  /// In en, this message translates to:
  /// **'Failed to dismiss onboarding: {arg1}'**
  String failedToDismissOnboardingArg1(Object? arg1);

  /// No description provided for @failedToFetch.
  ///
  /// In en, this message translates to:
  /// **'failed to fetch'**
  String get failedToFetch;

  /// No description provided for @failedToGeneratePromptArg1.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate prompt: {arg1}'**
  String failedToGeneratePromptArg1(Object? arg1);

  /// No description provided for @failedToLaunchExternalBrowserVia.
  ///
  /// In en, this message translates to:
  /// **'Failed to launch external browser via url_launcher.'**
  String get failedToLaunchExternalBrowserVia;

  /// No description provided for @failedToLaunchOauthFlow.
  ///
  /// In en, this message translates to:
  /// **'Failed to launch OAuth flow.'**
  String get failedToLaunchOauthFlow;

  /// No description provided for @failedToLoadPolicies.
  ///
  /// In en, this message translates to:
  /// **'Failed to load policies'**
  String get failedToLoadPolicies;

  /// No description provided for @failedToSaveArg1.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {arg1}'**
  String failedToSaveArg1(Object? arg1);

  /// No description provided for @failedToSaveMcpServer.
  ///
  /// In en, this message translates to:
  /// **'Failed to save MCP server.'**
  String get failedToSaveMcpServer;

  /// No description provided for @failedToSaveSelectionArg1.
  ///
  /// In en, this message translates to:
  /// **'Failed to save selection: {arg1}'**
  String failedToSaveSelectionArg1(Object? arg1);

  /// No description provided for @failedToSendNotificationToBackend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send notification to backend: {arg1}'**
  String failedToSendNotificationToBackend(Object? arg1);

  /// No description provided for @fair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get fair;

  /// No description provided for @fasterReplies.
  ///
  /// In en, this message translates to:
  /// **'Faster replies'**
  String get fasterReplies;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @fewerModelCalls.
  ///
  /// In en, this message translates to:
  /// **'Fewer model calls'**
  String get fewerModelCalls;

  /// No description provided for @fieldEmptyToRestoreTheBuilt.
  ///
  /// In en, this message translates to:
  /// **'field empty to restore the built-in default.'**
  String get fieldEmptyToRestoreTheBuilt;

  /// No description provided for @fileExceedsThe1MibEditor.
  ///
  /// In en, this message translates to:
  /// **'File exceeds the 1 MiB editor limit.'**
  String get fileExceedsThe1MibEditor;

  /// No description provided for @fileExceedsTheSupportedSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'File exceeds the supported size limit.'**
  String get fileExceedsTheSupportedSizeLimit;

  /// No description provided for @fileWrites.
  ///
  /// In en, this message translates to:
  /// **'File Writes'**
  String get fileWrites;

  /// No description provided for @filename.
  ///
  /// In en, this message translates to:
  /// **'Filename'**
  String get filename;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @filesNeoagentWritesOrEditsIn.
  ///
  /// In en, this message translates to:
  /// **'Files NeoAgent writes or edits in this session show up here.'**
  String get filesNeoagentWritesOrEditsIn;

  /// No description provided for @filesSavedByAllUsers.
  ///
  /// In en, this message translates to:
  /// **'Files saved by all users'**
  String get filesSavedByAllUsers;

  /// No description provided for @fillApprovedLoginsOrAuthenticateRequests.
  ///
  /// In en, this message translates to:
  /// **'Fill approved logins or authenticate requests without showing secrets to the AI.'**
  String get fillApprovedLoginsOrAuthenticateRequests;

  /// No description provided for @finalResponse.
  ///
  /// In en, this message translates to:
  /// **'Final Response'**
  String get finalResponse;

  /// No description provided for @findAPlatform.
  ///
  /// In en, this message translates to:
  /// **'Find a platform'**
  String get findAPlatform;

  /// No description provided for @findAndFixABug.
  ///
  /// In en, this message translates to:
  /// **'Find and fix a bug'**
  String get findAndFixABug;

  /// No description provided for @findRecentChats.
  ///
  /// In en, this message translates to:
  /// **'Find recent chats'**
  String get findRecentChats;

  /// No description provided for @findTheseLaterInTasks.
  ///
  /// In en, this message translates to:
  /// **'find these later in Tasks.'**
  String get findTheseLaterInTasks;

  /// No description provided for @findingTheCorrectNeoagentRuntime.
  ///
  /// In en, this message translates to:
  /// **'Finding the correct NeoAgent runtime'**
  String get findingTheCorrectNeoagentRuntime;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @finishAtTheScheduledTime.
  ///
  /// In en, this message translates to:
  /// **'Finish at the scheduled time'**
  String get finishAtTheScheduledTime;

  /// No description provided for @finishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get finishSetup;

  /// No description provided for @finishSigningInToArg1In.
  ///
  /// In en, this message translates to:
  /// **'Finish signing in to {arg1} in your browser, then connect again.'**
  String finishSigningInToArg1In(Object? arg1);

  /// No description provided for @flowGraph.
  ///
  /// In en, this message translates to:
  /// **'Flow graph'**
  String get flowGraph;

  /// No description provided for @flutterApp.
  ///
  /// In en, this message translates to:
  /// **'Flutter app'**
  String get flutterApp;

  /// No description provided for @focusedExecutionProfile.
  ///
  /// In en, this message translates to:
  /// **'Focused execution profile'**
  String get focusedExecutionProfile;

  /// No description provided for @folderIdOptional.
  ///
  /// In en, this message translates to:
  /// **'Folder ID (optional)'**
  String get folderIdOptional;

  /// No description provided for @folderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Folder unavailable'**
  String get folderUnavailable;

  /// No description provided for @forExampleHttpsMatrixOrg.
  ///
  /// In en, this message translates to:
  /// **'For example https://matrix.org'**
  String get forExampleHttpsMatrixOrg;

  /// No description provided for @forHostedOrAdvancedNetworkSetups.
  ///
  /// In en, this message translates to:
  /// **'For hosted or advanced network setups'**
  String get forHostedOrAdvancedNetworkSetups;

  /// No description provided for @forLinksInEmailsBlankUses.
  ///
  /// In en, this message translates to:
  /// **'For links in emails. Blank uses the server public URL.'**
  String get forLinksInEmailsBlankUses;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @frameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Frame unavailable'**
  String get frameUnavailable;

  /// No description provided for @freeTrialDays.
  ///
  /// In en, this message translates to:
  /// **'Free trial (days)'**
  String get freeTrialDays;

  /// No description provided for @freeTrialMustBeAWhole.
  ///
  /// In en, this message translates to:
  /// **'Free trial must be a whole number of days (0 or more).'**
  String get freeTrialMustBeAWhole;

  /// No description provided for @freshnessArg1.
  ///
  /// In en, this message translates to:
  /// **'freshness: {arg1}'**
  String freshnessArg1(Object? arg1);

  /// No description provided for @fridays1700.
  ///
  /// In en, this message translates to:
  /// **'Fridays · 17:00'**
  String get fridays1700;

  /// No description provided for @fromAgentRuns.
  ///
  /// In en, this message translates to:
  /// **'FROM agent_runs\n'**
  String get fromAgentRuns;

  /// No description provided for @fromAgentRunsR.
  ///
  /// In en, this message translates to:
  /// **'FROM agent_runs r\n'**
  String get fromAgentRunsR;

  /// No description provided for @fromAgentsA.
  ///
  /// In en, this message translates to:
  /// **'FROM agents a\n'**
  String get fromAgentsA;

  /// No description provided for @fromBotfatherAfterYouCreateThe.
  ///
  /// In en, this message translates to:
  /// **'From BotFather after you create the bot.'**
  String get fromBotfatherAfterYouCreateThe;

  /// No description provided for @fromIntegrationConnectionsIc.
  ///
  /// In en, this message translates to:
  /// **'FROM integration_connections ic\n'**
  String get fromIntegrationConnectionsIc;

  /// No description provided for @fromNowOnArg1DecidesWhich.
  ///
  /// In en, this message translates to:
  /// **'From now on {arg1} decides which tools your agent may use. They '**
  String fromNowOnArg1DecidesWhich(Object? arg1);

  /// No description provided for @fromTheDiscordDeveloperPortalUnder.
  ///
  /// In en, this message translates to:
  /// **'From the Discord Developer Portal, under your bot.'**
  String get fromTheDiscordDeveloperPortalUnder;

  /// No description provided for @fromTheLineDevelopersConsole.
  ///
  /// In en, this message translates to:
  /// **'From the LINE Developers Console.'**
  String get fromTheLineDevelopersConsole;

  /// No description provided for @fromTheMatrixClientOrBot.
  ///
  /// In en, this message translates to:
  /// **'From the Matrix client or bot account.'**
  String get fromTheMatrixClientOrBot;

  /// No description provided for @fromTwitchappsComTmiOrYour.
  ///
  /// In en, this message translates to:
  /// **'From twitchapps.com/tmi or your Twitch developer app.'**
  String get fromTwitchappsComTmiOrYour;

  /// No description provided for @fromUserDelegationsD.
  ///
  /// In en, this message translates to:
  /// **'FROM user_delegations d\n'**
  String get fromUserDelegationsD;

  /// No description provided for @fromUserSessionsS.
  ///
  /// In en, this message translates to:
  /// **'FROM user_sessions s\n'**
  String get fromUserSessionsS;

  /// No description provided for @fromUsersU.
  ///
  /// In en, this message translates to:
  /// **'FROM users u\n'**
  String get fromUsersU;

  /// No description provided for @fullPrompt.
  ///
  /// In en, this message translates to:
  /// **'Full prompt'**
  String get fullPrompt;

  /// No description provided for @fullSetup.
  ///
  /// In en, this message translates to:
  /// **'Full setup'**
  String get fullSetup;

  /// No description provided for @fullTextFtsArg1.
  ///
  /// In en, this message translates to:
  /// **'Full Text (FTS): {arg1}'**
  String fullTextFtsArg1(Object? arg1);

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General settings'**
  String get generalSettings;

  /// No description provided for @generalSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'General settings saved.'**
  String get generalSettingsSaved;

  /// No description provided for @generateAPromptForAnotherAi.
  ///
  /// In en, this message translates to:
  /// **'Generate a prompt for another AI, paste the response here to import memories.'**
  String get generateAPromptForAnotherAi;

  /// No description provided for @generatePrompt.
  ///
  /// In en, this message translates to:
  /// **'Generate Prompt'**
  String get generatePrompt;

  /// No description provided for @geofenceTrackingErrorArg1.
  ///
  /// In en, this message translates to:
  /// **'Geofence tracking error: {arg1}'**
  String geofenceTrackingErrorArg1(Object? arg1);

  /// No description provided for @getInspired.
  ///
  /// In en, this message translates to:
  /// **'Get inspired'**
  String get getInspired;

  /// No description provided for @gitCloneRepoNpmTest.
  ///
  /// In en, this message translates to:
  /// **'git clone repo && npm test'**
  String get gitCloneRepoNpmTest;

  /// No description provided for @githubCopilot.
  ///
  /// In en, this message translates to:
  /// **'GitHub Copilot'**
  String get githubCopilot;

  /// No description provided for @githubCopilotAndOpenaiCodex.
  ///
  /// In en, this message translates to:
  /// **'GitHub Copilot and OpenAI Codex'**
  String get githubCopilotAndOpenaiCodex;

  /// No description provided for @githubIssueOpened.
  ///
  /// In en, this message translates to:
  /// **'GitHub Issue Opened'**
  String get githubIssueOpened;

  /// No description provided for @githubReleaseCheckFailedWithHttp.
  ///
  /// In en, this message translates to:
  /// **'GitHub release check failed with HTTP {arg1}.'**
  String githubReleaseCheckFailedWithHttp(Object? arg1);

  /// No description provided for @githubReleasePayloadWasNotA.
  ///
  /// In en, this message translates to:
  /// **'GitHub release payload was not a release list.'**
  String get githubReleasePayloadWasNotA;

  /// No description provided for @githubUsernameThatOpenedTheIssue.
  ///
  /// In en, this message translates to:
  /// **'GitHub username that opened the issue'**
  String get githubUsernameThatOpenedTheIssue;

  /// No description provided for @giveThePlanAName.
  ///
  /// In en, this message translates to:
  /// **'Give the plan a name.'**
  String get giveThePlanAName;

  /// No description provided for @globalSecurityMode.
  ///
  /// In en, this message translates to:
  /// **'Global security mode'**
  String get globalSecurityMode;

  /// No description provided for @gmailMessageReceived.
  ///
  /// In en, this message translates to:
  /// **'Gmail Message Received'**
  String get gmailMessageReceived;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodPasswordALittleMoreLength.
  ///
  /// In en, this message translates to:
  /// **'Good password. A little more length makes it stronger.'**
  String get goodPasswordALittleMoreLength;

  /// No description provided for @googleChat.
  ///
  /// In en, this message translates to:
  /// **'Google Chat'**
  String get googleChat;

  /// No description provided for @googleWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Google Workspace'**
  String get googleWorkspace;

  /// No description provided for @gptLiveUsesYourOpenaiApi.
  ///
  /// In en, this message translates to:
  /// **'GPT-Live uses your OpenAI API key, Gemini Live your Google AI key. Changes apply to the next call.'**
  String get gptLiveUsesYourOpenaiApi;

  /// No description provided for @grantHealthConnectPermissionsBeforeSyncing.
  ///
  /// In en, this message translates to:
  /// **'Grant Health Connect permissions before syncing.'**
  String get grantHealthConnectPermissionsBeforeSyncing;

  /// No description provided for @groupByAId.
  ///
  /// In en, this message translates to:
  /// **'GROUP BY a.id\n'**
  String get groupByAId;

  /// No description provided for @groupByDay.
  ///
  /// In en, this message translates to:
  /// **'GROUP BY day\n'**
  String get groupByDay;

  /// No description provided for @groupByUId.
  ///
  /// In en, this message translates to:
  /// **'GROUP BY u.id\n'**
  String get groupByUId;

  /// No description provided for @groupChannelOrRoom.
  ///
  /// In en, this message translates to:
  /// **'Group, channel, or room'**
  String get groupChannelOrRoom;

  /// No description provided for @groupChatTurnTakingResearchSources.
  ///
  /// In en, this message translates to:
  /// **'group-chat turn-taking, research sources, answer checks, '**
  String get groupChatTurnTakingResearchSources;

  /// No description provided for @groupType.
  ///
  /// In en, this message translates to:
  /// **'Group type'**
  String get groupType;

  /// No description provided for @groupsAndChannels.
  ///
  /// In en, this message translates to:
  /// **'Groups and channels'**
  String get groupsAndChannels;

  /// No description provided for @groupsArg1.
  ///
  /// In en, this message translates to:
  /// **'Groups: {arg1}'**
  String groupsArg1(Object? arg1);

  /// No description provided for @groupsArg1HasNotSeenYet.
  ///
  /// In en, this message translates to:
  /// **'Groups {arg1} has not seen yet will follow this.'**
  String groupsArg1HasNotSeenYet(Object? arg1);

  /// No description provided for @handlesDirectTasksItself.
  ///
  /// In en, this message translates to:
  /// **'Handles direct tasks itself'**
  String get handlesDirectTasksItself;

  /// No description provided for @handsFreeTalkFreelyInterruptAnytime.
  ///
  /// In en, this message translates to:
  /// **'Hands-free (talk freely, interrupt anytime)'**
  String get handsFreeTalkFreelyInterruptAnytime;

  /// No description provided for @hardwareBridges.
  ///
  /// In en, this message translates to:
  /// **'Hardware Bridges'**
  String get hardwareBridges;

  /// No description provided for @headerName.
  ///
  /// In en, this message translates to:
  /// **'Header name'**
  String get headerName;

  /// No description provided for @headlinesOnTheTopicsYouCare.
  ///
  /// In en, this message translates to:
  /// **'Headlines on the topics you care about, filtered for signal.'**
  String get headlinesOnTheTopicsYouCare;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @healthChecks.
  ///
  /// In en, this message translates to:
  /// **'Health checks'**
  String get healthChecks;

  /// No description provided for @healthConnect.
  ///
  /// In en, this message translates to:
  /// **'health connect'**
  String get healthConnect;

  /// No description provided for @healthConnectIsNotAvailableOn.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is not available on this device.'**
  String get healthConnectIsNotAvailableOn;

  /// No description provided for @healthConnectSyncStatusAndStored.
  ///
  /// In en, this message translates to:
  /// **'Health Connect sync status and stored backend metrics.'**
  String get healthConnectSyncStatusAndStored;

  /// No description provided for @healthStatusIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Health status is unavailable.'**
  String get healthStatusIsUnavailable;

  /// No description provided for @healthSyncIsAvailableOnAndroid.
  ///
  /// In en, this message translates to:
  /// **'Health sync is available on Android only.'**
  String get healthSyncIsAvailableOnAndroid;

  /// No description provided for @heartArg1Records.
  ///
  /// In en, this message translates to:
  /// **'Heart {arg1} records'**
  String heartArg1Records(Object? arg1);

  /// No description provided for @heldBack.
  ///
  /// In en, this message translates to:
  /// **'Held back'**
  String get heldBack;

  /// No description provided for @helper.
  ///
  /// In en, this message translates to:
  /// **'Helper'**
  String get helper;

  /// No description provided for @helperArg1.
  ///
  /// In en, this message translates to:
  /// **'Helper: {arg1}'**
  String helperArg1(Object? arg1);

  /// No description provided for @hereRevokeAdminWithNeoagentAdmin.
  ///
  /// In en, this message translates to:
  /// **'here. Revoke admin with `neoagent admin revoke {arg1}` first.'**
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1);

  /// No description provided for @hereSecretsAreWriteOnlyLeave.
  ///
  /// In en, this message translates to:
  /// **'here. Secrets are write-only: leave one blank to keep it.'**
  String get hereSecretsAreWriteOnlyLeave;

  /// No description provided for @higherValuesMakeNeoagentMoreSelective.
  ///
  /// In en, this message translates to:
  /// **'Higher values make NeoAgent more selective in groups.'**
  String get higherValuesMakeNeoagentMoreSelective;

  /// No description provided for @highlyRecommended.
  ///
  /// In en, this message translates to:
  /// **'Highly recommended'**
  String get highlyRecommended;

  /// No description provided for @holdButton131ForTheAssistant.
  ///
  /// In en, this message translates to:
  /// **'Hold button 131 for the assistant.'**
  String get holdButton131ForTheAssistant;

  /// No description provided for @holdCtrlShiftSpaceToTalk.
  ///
  /// In en, this message translates to:
  /// **'Hold Ctrl+Shift+Space to talk'**
  String get holdCtrlShiftSpaceToTalk;

  /// No description provided for @holdToTalk.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk.'**
  String get holdToTalk;

  /// No description provided for @holdToTalk2.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get holdToTalk2;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @homeAssistantLongLivedAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant Long-Lived Access Token is required.'**
  String get homeAssistantLongLivedAccessToken;

  /// No description provided for @homeAssistantSetup.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant Setup'**
  String get homeAssistantSetup;

  /// No description provided for @homeAssistantUrl.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant URL'**
  String get homeAssistantUrl;

  /// No description provided for @homeAssistantUrlIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant URL is required.'**
  String get homeAssistantUrlIsRequired;

  /// No description provided for @homeserverTokenWithRoomPolling.
  ///
  /// In en, this message translates to:
  /// **'Homeserver token with room polling'**
  String get homeserverTokenWithRoomPolling;

  /// No description provided for @homeserverUrl.
  ///
  /// In en, this message translates to:
  /// **'Homeserver URL'**
  String get homeserverUrl;

  /// No description provided for @hostedServiceYourKeysAreEncrypted.
  ///
  /// In en, this message translates to:
  /// **'hosted service). Your keys are encrypted and only usable by '**
  String get hostedServiceYourKeysAreEncrypted;

  /// No description provided for @hostnameOfTheIrcNetworkFor.
  ///
  /// In en, this message translates to:
  /// **'Hostname of the IRC network, for example irc.libera.chat'**
  String get hostnameOfTheIrcNetworkFor;

  /// No description provided for @hourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get hourly;

  /// No description provided for @hourlyInboxCheck.
  ///
  /// In en, this message translates to:
  /// **'Hourly inbox check'**
  String get hourlyInboxCheck;

  /// No description provided for @howLongConfirmationLinksStayValid.
  ///
  /// In en, this message translates to:
  /// **'How long confirmation links stay valid.'**
  String get howLongConfirmationLinksStayValid;

  /// No description provided for @howOftenThisAgentLooksFor.
  ///
  /// In en, this message translates to:
  /// **'How often this agent looks for new room messages.'**
  String get howOftenThisAgentLooksFor;

  /// No description provided for @howOftenThisAgentLooksFor2.
  ///
  /// In en, this message translates to:
  /// **'How often this agent looks for new Signal messages.'**
  String get howOftenThisAgentLooksFor2;

  /// No description provided for @howTeamsWork.
  ///
  /// In en, this message translates to:
  /// **'How teams work'**
  String get howTeamsWork;

  /// No description provided for @howThisServerIsReachedPlus.
  ///
  /// In en, this message translates to:
  /// **'How this server is reached, plus server-wide switches.'**
  String get howThisServerIsReachedPlus;

  /// No description provided for @httpsSessionCookie.
  ///
  /// In en, this message translates to:
  /// **'https session cookie'**
  String get httpsSessionCookie;

  /// No description provided for @iCouldNotCompleteThatRequest.
  ///
  /// In en, this message translates to:
  /// **'I could not complete that request right now. Please try again in a moment.'**
  String get iCouldNotCompleteThatRequest;

  /// No description provided for @icStatusIcAccountEmailIc.
  ///
  /// In en, this message translates to:
  /// **'       ic.status, ic.account_email, ic.last_connected_at\n'**
  String get icStatusIcAccountEmailIc;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @ifArg1AsksForAWebhook.
  ///
  /// In en, this message translates to:
  /// **'If {arg1} asks for a webhook URL, paste this so messages can reach {arg2}.'**
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2);

  /// No description provided for @ifThatAccountHasAConfirmed.
  ///
  /// In en, this message translates to:
  /// **'If that account has a confirmed email, NeoAgent will send a password reset link.'**
  String get ifThatAccountHasAConfirmed;

  /// No description provided for @ifTheServiceRequiresAToken.
  ///
  /// In en, this message translates to:
  /// **'If the service requires a token on outgoing requests.'**
  String get ifTheServiceRequiresAToken;

  /// No description provided for @ignoreGroups.
  ///
  /// In en, this message translates to:
  /// **'Ignore Groups'**
  String get ignoreGroups;

  /// No description provided for @ignoreThisChat.
  ///
  /// In en, this message translates to:
  /// **'Ignore this chat'**
  String get ignoreThisChat;

  /// No description provided for @ignoredChannels.
  ///
  /// In en, this message translates to:
  /// **'Ignored Channels'**
  String get ignoredChannels;

  /// No description provided for @ignoredMalformedDesktopCompanionMessageArg1.
  ///
  /// In en, this message translates to:
  /// **'Ignored malformed desktop companion message: {arg1}'**
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1);

  /// No description provided for @impArg1.
  ///
  /// In en, this message translates to:
  /// **'Imp {arg1}'**
  String impArg1(Object? arg1);

  /// No description provided for @implementThePlanAbove.
  ///
  /// In en, this message translates to:
  /// **'Implement the plan above.'**
  String get implementThePlanAbove;

  /// No description provided for @implementThisPlan.
  ///
  /// In en, this message translates to:
  /// **'Implement this plan'**
  String get implementThisPlan;

  /// No description provided for @implicitTls.
  ///
  /// In en, this message translates to:
  /// **'Implicit TLS'**
  String get implicitTls;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @importFailedArg1.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {arg1}'**
  String importFailedArg1(Object? arg1);

  /// No description provided for @importFromComputer.
  ///
  /// In en, this message translates to:
  /// **'Import from computer'**
  String get importFromComputer;

  /// No description provided for @importMemoryTransfer.
  ///
  /// In en, this message translates to:
  /// **'Import memory transfer?'**
  String get importMemoryTransfer;

  /// No description provided for @importance.
  ///
  /// In en, this message translates to:
  /// **'Importance'**
  String get importance;

  /// No description provided for @importedArg1Memories.
  ///
  /// In en, this message translates to:
  /// **'Imported {arg1} memories, '**
  String importedArg1Memories(Object? arg1);

  /// No description provided for @inArg1STeam.
  ///
  /// In en, this message translates to:
  /// **'In @{arg1}’s team'**
  String inArg1STeam(Object? arg1);

  /// No description provided for @inBackground.
  ///
  /// In en, this message translates to:
  /// **'background'**
  String get inBackground;

  /// No description provided for @inTheirSettings.
  ///
  /// In en, this message translates to:
  /// **'in their settings.'**
  String get inTheirSettings;

  /// No description provided for @incomingAndOutgoingChannelMessagesWill.
  ///
  /// In en, this message translates to:
  /// **'Incoming and outgoing channel messages will appear here.'**
  String get incomingAndOutgoingChannelMessagesWill;

  /// No description provided for @incomingInAppVoiceCallsFrom.
  ///
  /// In en, this message translates to:
  /// **'Incoming in-app voice calls from NeoAgent'**
  String get incomingInAppVoiceCallsFrom;

  /// No description provided for @incomingMessages.
  ///
  /// In en, this message translates to:
  /// **'Incoming messages'**
  String get incomingMessages;

  /// No description provided for @incomingNeoagentCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming NeoAgent call'**
  String get incomingNeoagentCall;

  /// No description provided for @incomingNeoagentCall2.
  ///
  /// In en, this message translates to:
  /// **'INCOMING NEOAGENT CALL'**
  String get incomingNeoagentCall2;

  /// No description provided for @incomingWebhookAndOutgoingCallbackSupport.
  ///
  /// In en, this message translates to:
  /// **'Incoming webhook and outgoing callback support'**
  String get incomingWebhookAndOutgoingCallbackSupport;

  /// No description provided for @incorporatingSteering.
  ///
  /// In en, this message translates to:
  /// **'Incorporating steering'**
  String get incorporatingSteering;

  /// No description provided for @input.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get input;

  /// No description provided for @inputMode.
  ///
  /// In en, this message translates to:
  /// **'Input mode'**
  String get inputMode;

  /// No description provided for @insertATemplate.
  ///
  /// In en, this message translates to:
  /// **'Insert a template'**
  String get insertATemplate;

  /// No description provided for @inspect.
  ///
  /// In en, this message translates to:
  /// **'Inspect'**
  String get inspect;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @installASignedSelfContainedRuntime.
  ///
  /// In en, this message translates to:
  /// **'Install a signed, self-contained runtime. Node.js, npm, Git, and terminal commands are not required.'**
  String get installASignedSelfContainedRuntime;

  /// No description provided for @installApk.
  ///
  /// In en, this message translates to:
  /// **'Install APK'**
  String get installApk;

  /// No description provided for @installApkBundle.
  ///
  /// In en, this message translates to:
  /// **'Install APK / Bundle'**
  String get installApkBundle;

  /// No description provided for @installApkClickOrDropA.
  ///
  /// In en, this message translates to:
  /// **'Install APK — click or drop a .apk file'**
  String get installApkClickOrDropA;

  /// No description provided for @installNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Install NeoAgent'**
  String get installNeoagent;

  /// No description provided for @installNeoagentOnThisComputerWithout.
  ///
  /// In en, this message translates to:
  /// **'Install NeoAgent on this computer without a terminal, or connect to one that is already running.'**
  String get installNeoagentOnThisComputerWithout;

  /// No description provided for @installNewReleasesAndChooseWhich.
  ///
  /// In en, this message translates to:
  /// **'Install new releases and choose which channel this server follows.'**
  String get installNewReleasesAndChooseWhich;

  /// No description provided for @installTheBackend.
  ///
  /// In en, this message translates to:
  /// **'Install the backend'**
  String get installTheBackend;

  /// No description provided for @installTheCoreWithExtraOptional.
  ///
  /// In en, this message translates to:
  /// **'Install the core with extra optional setup. AI provider keys are added afterwards, same as Quickstart.'**
  String get installTheCoreWithExtraOptional;

  /// No description provided for @installTheSecureCoreThenCreate.
  ///
  /// In en, this message translates to:
  /// **'Install the secure core, then create your account. Add AI provider keys afterwards.'**
  String get installTheSecureCoreThenCreate;

  /// No description provided for @installedArg1.
  ///
  /// In en, this message translates to:
  /// **' | Installed: {arg1}'**
  String installedArg1(Object? arg1);

  /// No description provided for @installedArg1LastCheckedArg2.
  ///
  /// In en, this message translates to:
  /// **'Installed: {arg1} • Last checked: {arg2}'**
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2);

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @integration.
  ///
  /// In en, this message translates to:
  /// **'Integration'**
  String get integration;

  /// No description provided for @integrationApps.
  ///
  /// In en, this message translates to:
  /// **'Integration apps'**
  String get integrationApps;

  /// No description provided for @integrationConnections.
  ///
  /// In en, this message translates to:
  /// **'Integration connections'**
  String get integrationConnections;

  /// No description provided for @integrationSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Integration settings saved.'**
  String get integrationSettingsSaved;

  /// No description provided for @integrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrations;

  /// No description provided for @integrationsOauthCallbackAndRegisterThat.
  ///
  /// In en, this message translates to:
  /// **'integrations/oauth/callback, and register that same '**
  String get integrationsOauthCallbackAndRegisterThat;

  /// No description provided for @interruptAi.
  ///
  /// In en, this message translates to:
  /// **'Interrupt AI'**
  String get interruptAi;

  /// No description provided for @invalid2fa.
  ///
  /// In en, this message translates to:
  /// **'invalid 2fa'**
  String get invalid2fa;

  /// No description provided for @invalidArgumentS.
  ///
  /// In en, this message translates to:
  /// **'Invalid argument(s): '**
  String get invalidArgumentS;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'invalid credentials'**
  String get invalidCredentials;

  /// No description provided for @invalidNeoagentRuntimeManifest.
  ///
  /// In en, this message translates to:
  /// **'Invalid NeoAgent runtime manifest.'**
  String get invalidNeoagentRuntimeManifest;

  /// No description provided for @inviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteLink;

  /// No description provided for @inviteLinkReady.
  ///
  /// In en, this message translates to:
  /// **'Invite link ready'**
  String get inviteLinkReady;

  /// No description provided for @inviteLinks.
  ///
  /// In en, this message translates to:
  /// **'Invite links'**
  String get inviteLinks;

  /// No description provided for @iphoneApp.
  ///
  /// In en, this message translates to:
  /// **'iPhone app'**
  String get iphoneApp;

  /// No description provided for @isAboutWhoIsInvolvedAnd.
  ///
  /// In en, this message translates to:
  /// **'is about, who is involved and anything I should prepare. If tomorrow '**
  String get isAboutWhoIsInvolvedAnd;

  /// No description provided for @isEmptyDoNotSendAnything.
  ///
  /// In en, this message translates to:
  /// **'is empty, do not send anything.'**
  String get isEmptyDoNotSendAnything;

  /// No description provided for @issues.
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get issues;

  /// No description provided for @issuesAppearOnceTheLogLoads.
  ///
  /// In en, this message translates to:
  /// **'Issues appear once the log loads.'**
  String get issuesAppearOnceTheLogLoads;

  /// No description provided for @itCanTBeUndone.
  ///
  /// In en, this message translates to:
  /// **'It can’t be undone.'**
  String get itCanTBeUndone;

  /// No description provided for @itCutsWaitingAndModelCost.
  ///
  /// In en, this message translates to:
  /// **'It cuts waiting and model cost; every reply is still written by '**
  String get itCutsWaitingAndModelCost;

  /// No description provided for @itMayHaveBeenDeleted.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted.'**
  String get itMayHaveBeenDeleted;

  /// No description provided for @javaRuntime.
  ///
  /// In en, this message translates to:
  /// **'java runtime'**
  String get javaRuntime;

  /// No description provided for @jevDecisions.
  ///
  /// In en, this message translates to:
  /// **'Jev decisions'**
  String get jevDecisions;

  /// No description provided for @jevIsADecisionModelThat.
  ///
  /// In en, this message translates to:
  /// **'Jev is a decision model that makes the behind-the-scenes calls in '**
  String get jevIsADecisionModelThat;

  /// No description provided for @jevIsOffForEveryAgent.
  ///
  /// In en, this message translates to:
  /// **'Jev is off for every agent, and its switch is hidden in '**
  String get jevIsOffForEveryAgent;

  /// No description provided for @jevIsOffOnThisServer.
  ///
  /// In en, this message translates to:
  /// **'Jev is off on this server.'**
  String get jevIsOffOnThisServer;

  /// No description provided for @jevIsOnForEveryAgent.
  ///
  /// In en, this message translates to:
  /// **'Jev is on for every agent.'**
  String get jevIsOnForEveryAgent;

  /// No description provided for @jevScoredThisMessageDirectlyNo.
  ///
  /// In en, this message translates to:
  /// **'JEV scored this message directly. No language model ran.'**
  String get jevScoredThisMessageDirectlyNo;

  /// No description provided for @jevTypesafeDecisionModelOpenrouterRouting.
  ///
  /// In en, this message translates to:
  /// **'jev typesafe decision model openrouter routing fast cheaper recommended'**
  String get jevTypesafeDecisionModelOpenrouterRouting;

  /// No description provided for @jevUnavailable.
  ///
  /// In en, this message translates to:
  /// **'JEV unavailable'**
  String get jevUnavailable;

  /// No description provided for @joinUsersManagedOnManagedId.
  ///
  /// In en, this message translates to:
  /// **'JOIN users managed ON managed.id = d.managed_user_id\n'**
  String get joinUsersManagedOnManagedId;

  /// No description provided for @joinUsersManagerOnManagerId.
  ///
  /// In en, this message translates to:
  /// **'JOIN users manager ON manager.id = d.manager_user_id\n'**
  String get joinUsersManagerOnManagerId;

  /// No description provided for @joinUsersUOnUId.
  ///
  /// In en, this message translates to:
  /// **'JOIN users u ON u.id = r.user_id\n'**
  String get joinUsersUOnUId;

  /// No description provided for @joinUsersUOnUId2.
  ///
  /// In en, this message translates to:
  /// **'JOIN users u ON u.id = s.user_id\n'**
  String get joinUsersUOnUId2;

  /// No description provided for @joinUsersUOnUId3.
  ///
  /// In en, this message translates to:
  /// **'JOIN users u ON u.id = a.user_id\n'**
  String get joinUsersUOnUId3;

  /// No description provided for @joinUsersUOnUId4.
  ///
  /// In en, this message translates to:
  /// **'JOIN users u ON u.id = ic.user_id\n'**
  String get joinUsersUOnUId4;

  /// No description provided for @joinedArg1.
  ///
  /// In en, this message translates to:
  /// **'Joined {arg1}'**
  String joinedArg1(Object? arg1);

  /// No description provided for @joinedInTheLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Joined in the last 7 days'**
  String get joinedInTheLast7Days;

  /// No description provided for @joiningATeam.
  ///
  /// In en, this message translates to:
  /// **'Joining a team'**
  String get joiningATeam;

  /// No description provided for @joiningIsOffHere.
  ///
  /// In en, this message translates to:
  /// **'Joining is off here'**
  String get joiningIsOffHere;

  /// No description provided for @jsonFieldThatContainsTheMessage.
  ///
  /// In en, this message translates to:
  /// **'JSON field that contains the message text. Usually text.'**
  String get jsonFieldThatContainsTheMessage;

  /// No description provided for @jsonFieldThatIdentifiesWhoThe.
  ///
  /// In en, this message translates to:
  /// **'JSON field that identifies who the message is for.'**
  String get jsonFieldThatIdentifiesWhoThe;

  /// No description provided for @jumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get jumpToLatest;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @keepNeoagentRunning.
  ///
  /// In en, this message translates to:
  /// **'Keep NeoAgent running?'**
  String get keepNeoagentRunning;

  /// No description provided for @keepPlan.
  ///
  /// In en, this message translates to:
  /// **'Keep plan'**
  String get keepPlan;

  /// No description provided for @keepRunning.
  ///
  /// In en, this message translates to:
  /// **'Keep running'**
  String get keepRunning;

  /// No description provided for @keepTaskRunning.
  ///
  /// In en, this message translates to:
  /// **'Keep task running'**
  String get keepTaskRunning;

  /// No description provided for @keepTheVaultAvailable.
  ///
  /// In en, this message translates to:
  /// **'Keep the vault available'**
  String get keepTheVaultAvailable;

  /// No description provided for @keepThisLauncherUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Keep this launcher up to date.'**
  String get keepThisLauncherUpToDate;

  /// No description provided for @keepThisPanelOpenUntilThe.
  ///
  /// In en, this message translates to:
  /// **'Keep this panel open until the platform confirms the connection.'**
  String get keepThisPanelOpenUntilThe;

  /// No description provided for @keepThisSessionSComputerVisible.
  ///
  /// In en, this message translates to:
  /// **'Keep this session\'\'s computer visible'**
  String get keepThisSessionSComputerVisible;

  /// No description provided for @keepTrackOfYourAiUsage.
  ///
  /// In en, this message translates to:
  /// **'Keep track of your AI usage. Limits are enforced to ensure fair usage across the platform.'**
  String get keepTrackOfYourAiUsage;

  /// No description provided for @keepUsingYourAppsNormallyNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Keep using your apps normally. NeoAgent works on the same screen and asks whenever it needs new access.\n\n'**
  String get keepUsingYourAppsNormallyNeoagent;

  /// No description provided for @keepingThisDeviceConnected.
  ///
  /// In en, this message translates to:
  /// **'Keeping this device connected'**
  String get keepingThisDeviceConnected;

  /// No description provided for @key.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get key;

  /// No description provided for @keyIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Key is required.'**
  String get keyIsRequired;

  /// No description provided for @keyValuePairsThatPersistAcross.
  ///
  /// In en, this message translates to:
  /// **'Key-value pairs that persist across conversations.'**
  String get keyValuePairsThatPersistAcross;

  /// No description provided for @kind.
  ///
  /// In en, this message translates to:
  /// **'KIND'**
  String get kind;

  /// No description provided for @knowledgeGraph.
  ///
  /// In en, this message translates to:
  /// **'Knowledge Graph'**
  String get knowledgeGraph;

  /// No description provided for @knowledgeView.
  ///
  /// In en, this message translates to:
  /// **'Knowledge view'**
  String get knowledgeView;

  /// No description provided for @labelOnlyYouSeeIt.
  ///
  /// In en, this message translates to:
  /// **'Label (only you see it)'**
  String get labelOnlyYouSeeIt;

  /// No description provided for @labelsOptional.
  ///
  /// In en, this message translates to:
  /// **'Labels (optional)'**
  String get labelsOptional;

  /// No description provided for @last24Hours.
  ///
  /// In en, this message translates to:
  /// **'Last 24 hours'**
  String get last24Hours;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get last7Days;

  /// No description provided for @last7DaysArg1TokensIn.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days: {arg1} tokens in {arg2} runs'**
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2);

  /// No description provided for @lastArg1.
  ///
  /// In en, this message translates to:
  /// **'Last {arg1}'**
  String lastArg1(Object? arg1);

  /// No description provided for @lastArg12.
  ///
  /// In en, this message translates to:
  /// **'Last: {arg1}'**
  String lastArg12(Object? arg1);

  /// No description provided for @lastNonEmptySyncArg1.
  ///
  /// In en, this message translates to:
  /// **'Last non-empty sync · {arg1}'**
  String lastNonEmptySyncArg1(Object? arg1);

  /// No description provided for @lastRunArg1.
  ///
  /// In en, this message translates to:
  /// **'Last run: {arg1}'**
  String lastRunArg1(Object? arg1);

  /// No description provided for @lastSeenArg1.
  ///
  /// In en, this message translates to:
  /// **'Last seen {arg1}'**
  String lastSeenArg1(Object? arg1);

  /// No description provided for @lastSignInArg1.
  ///
  /// In en, this message translates to:
  /// **'Last sign-in {arg1}'**
  String lastSignInArg1(Object? arg1);

  /// No description provided for @lastSyncSummary.
  ///
  /// In en, this message translates to:
  /// **'Last Sync Summary'**
  String get lastSyncSummary;

  /// No description provided for @lastUsedArg1.
  ///
  /// In en, this message translates to:
  /// **'Last used: {arg1}'**
  String lastUsedArg1(Object? arg1);

  /// No description provided for @lastWindowEndedArg1.
  ///
  /// In en, this message translates to:
  /// **'Last window ended {arg1}'**
  String lastWindowEndedArg1(Object? arg1);

  /// No description provided for @laterStartSwitchedOffToo.
  ///
  /// In en, this message translates to:
  /// **'later start switched off too.'**
  String get laterStartSwitchedOffToo;

  /// No description provided for @latestRunArg1.
  ///
  /// In en, this message translates to:
  /// **'Latest run · {arg1}'**
  String latestRunArg1(Object? arg1);

  /// No description provided for @launchingDesktopAppsIsNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Launching desktop apps is not supported on this platform.'**
  String get launchingDesktopAppsIsNotSupported;

  /// No description provided for @learnRoomNorms.
  ///
  /// In en, this message translates to:
  /// **'Learn room norms'**
  String get learnRoomNorms;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @leaveARedirectUriBlankTo.
  ///
  /// In en, this message translates to:
  /// **'Leave a Redirect URI blank to use <public URL>/api/'**
  String get leaveARedirectUriBlankTo;

  /// No description provided for @leaveArg1STeam.
  ///
  /// In en, this message translates to:
  /// **'Leave {arg1}’s team?'**
  String leaveArg1STeam(Object? arg1);

  /// No description provided for @leaveAsTheDefaultUnlessYou.
  ///
  /// In en, this message translates to:
  /// **'Leave as the default unless you customized BlueBubbles.'**
  String get leaveAsTheDefaultUnlessYou;

  /// No description provided for @leaveTheTokenEmptyToKeep.
  ///
  /// In en, this message translates to:
  /// **'Leave the token empty to keep the currently stored token.'**
  String get leaveTheTokenEmptyToKeep;

  /// No description provided for @leftJoinAgentRunsROn.
  ///
  /// In en, this message translates to:
  /// **'LEFT JOIN agent_runs r ON r.user_id = u.id\n'**
  String get leftJoinAgentRunsROn;

  /// No description provided for @leftJoinAgentRunsROn2.
  ///
  /// In en, this message translates to:
  /// **'LEFT JOIN agent_runs r ON r.agent_id = a.id\n'**
  String get leftJoinAgentRunsROn2;

  /// No description provided for @leftJoinArtifactsAOnA.
  ///
  /// In en, this message translates to:
  /// **'LEFT JOIN artifacts a ON a.user_id = u.id\n'**
  String get leftJoinArtifactsAOnA;

  /// No description provided for @letAccountsConnectMeshtasticRadios.
  ///
  /// In en, this message translates to:
  /// **'Let accounts connect Meshtastic radios.'**
  String get letAccountsConnectMeshtasticRadios;

  /// No description provided for @letArg1ManageMe.
  ///
  /// In en, this message translates to:
  /// **'Let {arg1} manage me'**
  String letArg1ManageMe(Object? arg1);

  /// No description provided for @letEveryoneInThisGroupTalk.
  ///
  /// In en, this message translates to:
  /// **'Let everyone in this group talk to {arg1}.'**
  String letEveryoneInThisGroupTalk(Object? arg1);

  /// No description provided for @letItWorkWhileYouDon.
  ///
  /// In en, this message translates to:
  /// **'Let it work\nwhile you don\'\'t.'**
  String get letItWorkWhileYouDon;

  /// No description provided for @letNeoagentClickTypeAndMove.
  ///
  /// In en, this message translates to:
  /// **'Let NeoAgent click, type and move through your apps.'**
  String get letNeoagentClickTypeAndMove;

  /// No description provided for @letNeoagentUnderstandWhatIsVisible.
  ///
  /// In en, this message translates to:
  /// **'Let NeoAgent understand what is visible on your screen.'**
  String get letNeoagentUnderstandWhatIsVisible;

  /// No description provided for @letSomeoneYouWorkWithDecide.
  ///
  /// In en, this message translates to:
  /// **'Let someone you work with decide which tools your agent may '**
  String get letSomeoneYouWorkWithDecide;

  /// No description provided for @letThisPersonSendArg1A.
  ///
  /// In en, this message translates to:
  /// **'Let this person send {arg1} a one-to-one message.'**
  String letThisPersonSendArg1A(Object? arg1);

  /// No description provided for @letThisPersonTalkToArg1.
  ///
  /// In en, this message translates to:
  /// **'Let this person talk to {arg1} here, but not in private chats or other groups.'**
  String letThisPersonTalkToArg1(Object? arg1);

  /// No description provided for @letThisPersonTalkToArg12.
  ///
  /// In en, this message translates to:
  /// **'Let this person talk to {arg1} in private chats and in any group they share.'**
  String letThisPersonTalkToArg12(Object? arg1);

  /// No description provided for @levelArg1Arg2Arg3.
  ///
  /// In en, this message translates to:
  /// **'Level {arg1}/{arg2}{arg3}'**
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3);

  /// No description provided for @lexicalArg1.
  ///
  /// In en, this message translates to:
  /// **'Lexical: {arg1}'**
  String lexicalArg1(Object? arg1);

  /// No description provided for @limit20.
  ///
  /// In en, this message translates to:
  /// **'LIMIT 20'**
  String get limit20;

  /// No description provided for @limit50.
  ///
  /// In en, this message translates to:
  /// **'LIMIT 50'**
  String get limit50;

  /// No description provided for @linkAPhoneNumberThatBelongs.
  ///
  /// In en, this message translates to:
  /// **'Link a phone number that belongs to the agent. '**
  String get linkAPhoneNumberThatBelongs;

  /// No description provided for @linkArg1.
  ///
  /// In en, this message translates to:
  /// **'Link {arg1}'**
  String linkArg1(Object? arg1);

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @linkExpiresAfter.
  ///
  /// In en, this message translates to:
  /// **'Link expires after'**
  String get linkExpiresAfter;

  /// No description provided for @linkLifetimeHours.
  ///
  /// In en, this message translates to:
  /// **'Link lifetime (hours)'**
  String get linkLifetimeHours;

  /// No description provided for @linkLifetimeMustBeFrom1.
  ///
  /// In en, this message translates to:
  /// **'Link lifetime must be from 1 to 8760 hours.'**
  String get linkLifetimeMustBeFrom1;

  /// No description provided for @linkValidUntilArg1.
  ///
  /// In en, this message translates to:
  /// **'Link valid until {arg1}.'**
  String linkValidUntilArg1(Object? arg1);

  /// No description provided for @linkYourOwnNumberAndTalk.
  ///
  /// In en, this message translates to:
  /// **'Link your own number and talk to the agent in your '**
  String get linkYourOwnNumberAndTalk;

  /// No description provided for @linkedSignInProviders.
  ///
  /// In en, this message translates to:
  /// **'Linked sign-in providers'**
  String get linkedSignInProviders;

  /// No description provided for @linuxApp.
  ///
  /// In en, this message translates to:
  /// **'Linux app'**
  String get linuxApp;

  /// No description provided for @listedArg1.
  ///
  /// In en, this message translates to:
  /// **'Listed {arg1}/'**
  String listedArg1(Object? arg1);

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get listening;

  /// No description provided for @liveExecutionHistoryToolStepsAnd.
  ///
  /// In en, this message translates to:
  /// **'Live execution history, tool steps, and responses.'**
  String get liveExecutionHistoryToolStepsAnd;

  /// No description provided for @liveModel.
  ///
  /// In en, this message translates to:
  /// **'Live model'**
  String get liveModel;

  /// No description provided for @liveModelProvider.
  ///
  /// In en, this message translates to:
  /// **'Live model provider'**
  String get liveModelProvider;

  /// No description provided for @liveRun.
  ///
  /// In en, this message translates to:
  /// **'Live run'**
  String get liveRun;

  /// No description provided for @liveVoice.
  ///
  /// In en, this message translates to:
  /// **'Live voice'**
  String get liveVoice;

  /// No description provided for @liveVoiceConnectionIsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Live voice connection is not available.'**
  String get liveVoiceConnectionIsNotAvailable;

  /// No description provided for @liveVoiceConnectionWasClosed.
  ///
  /// In en, this message translates to:
  /// **'Live voice connection was closed.'**
  String get liveVoiceConnectionWasClosed;

  /// No description provided for @liveVoiceDefaults.
  ///
  /// In en, this message translates to:
  /// **'Live voice defaults'**
  String get liveVoiceDefaults;

  /// No description provided for @liveVoiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Live voice failed.'**
  String get liveVoiceFailed;

  /// No description provided for @llmMemoryExportResponse.
  ///
  /// In en, this message translates to:
  /// **'LLM memory export response'**
  String get llmMemoryExportResponse;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'load failed'**
  String get loadFailed;

  /// No description provided for @loadingExecutionDetails.
  ///
  /// In en, this message translates to:
  /// **'Loading execution details...'**
  String get loadingExecutionDetails;

  /// No description provided for @loadingNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Loading NeoAgent'**
  String get loadingNeoagent;

  /// No description provided for @loadingRunFlow.
  ///
  /// In en, this message translates to:
  /// **'Loading run flow…'**
  String get loadingRunFlow;

  /// No description provided for @localAndPrivateNetworkUrlsAre.
  ///
  /// In en, this message translates to:
  /// **'Local and private-network URLs are supported when the NeoAgent server can reach them. Audio is never exposed to NeoAgent.'**
  String get localAndPrivateNetworkUrlsAre;

  /// No description provided for @localApp.
  ///
  /// In en, this message translates to:
  /// **'local app'**
  String get localApp;

  /// No description provided for @localBackendInstallationIsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Local backend installation is not available on this platform.'**
  String get localBackendInstallationIsNotAvailable;

  /// No description provided for @localBaseImagePath.
  ///
  /// In en, this message translates to:
  /// **'Local base image path'**
  String get localBaseImagePath;

  /// No description provided for @localComputerControlIsAvailableIn.
  ///
  /// In en, this message translates to:
  /// **'Local computer control is available in the NeoAgent desktop app on macOS, Windows and Linux.'**
  String get localComputerControlIsAvailableIn;

  /// No description provided for @localComputerControlIsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Local computer control is not available here.'**
  String get localComputerControlIsNotAvailable;

  /// No description provided for @localDeviceBridgesAndTcpConnected.
  ///
  /// In en, this message translates to:
  /// **'Local device bridges and TCP-connected integrations.'**
  String get localDeviceBridgesAndTcpConnected;

  /// No description provided for @localModelsUrl.
  ///
  /// In en, this message translates to:
  /// **'local models url'**
  String get localModelsUrl;

  /// No description provided for @localNeoagentDiscoveryIsTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Local NeoAgent discovery is temporarily unavailable.'**
  String get localNeoagentDiscoveryIsTemporarilyUnavailable;

  /// No description provided for @localPreferencesForTheNeoagentApplication.
  ///
  /// In en, this message translates to:
  /// **'Local preferences for the NeoAgent application. Computer control always runs through the unified cloud computer.'**
  String get localPreferencesForTheNeoagentApplication;

  /// No description provided for @localSetup.
  ///
  /// In en, this message translates to:
  /// **'LOCAL SETUP'**
  String get localSetup;

  /// No description provided for @locationCityOrPlace.
  ///
  /// In en, this message translates to:
  /// **'Location (city or place)'**
  String get locationCityOrPlace;

  /// No description provided for @locationIsRequiredForWeatherEvent.
  ///
  /// In en, this message translates to:
  /// **'Location is required for weather event triggers'**
  String get locationIsRequiredForWeatherEvent;

  /// No description provided for @locationserviceInitializationFailedArg1.
  ///
  /// In en, this message translates to:
  /// **'LocationService initialization failed: {arg1}'**
  String locationserviceInitializationFailedArg1(Object? arg1);

  /// No description provided for @logCopied.
  ///
  /// In en, this message translates to:
  /// **'Log copied'**
  String get logCopied;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Login password'**
  String get loginPassword;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @logsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied.'**
  String get logsCopied;

  /// No description provided for @logsOnThisComputer.
  ///
  /// In en, this message translates to:
  /// **'Logs on this computer'**
  String get logsOnThisComputer;

  /// No description provided for @longLivedAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Long-Lived Access Token'**
  String get longLivedAccessToken;

  /// No description provided for @longTermRecallStructuredFactsAnd.
  ///
  /// In en, this message translates to:
  /// **'Long-term recall, structured facts, and knowledge graph.'**
  String get longTermRecallStructuredFactsAnd;

  /// No description provided for @lookAtMyCalendarForTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Look at my calendar for tomorrow. For each meeting, tell me what it '**
  String get lookAtMyCalendarForTomorrow;

  /// No description provided for @lookedAtTheScreen.
  ///
  /// In en, this message translates to:
  /// **'Looked at the screen'**
  String get lookedAtTheScreen;

  /// No description provided for @lookingOnThisComputerAndYour.
  ///
  /// In en, this message translates to:
  /// **'Looking on this computer and your local network…'**
  String get lookingOnThisComputerAndYour;

  /// No description provided for @looksAheadAtTomorrowSMeetings.
  ///
  /// In en, this message translates to:
  /// **'Looks ahead at tomorrow\'\'s meetings so nothing surprises you.'**
  String get looksAheadAtTomorrowSMeetings;

  /// No description provided for @loopExecution.
  ///
  /// In en, this message translates to:
  /// **'Loop execution'**
  String get loopExecution;

  /// No description provided for @loopPaused.
  ///
  /// In en, this message translates to:
  /// **'Loop paused'**
  String get loopPaused;

  /// No description provided for @lowerNumbersAreListedFirst.
  ///
  /// In en, this message translates to:
  /// **'Lower numbers are listed first.'**
  String get lowerNumbersAreListedFirst;

  /// No description provided for @macOsX.
  ///
  /// In en, this message translates to:
  /// **'mac os x'**
  String get macOsX;

  /// No description provided for @macosAccessibilityIsNotGrantedTo.
  ///
  /// In en, this message translates to:
  /// **'macOS Accessibility is not granted to NeoAgent. Allow it in System Settings › Privacy & Security › Accessibility.'**
  String get macosAccessibilityIsNotGrantedTo;

  /// No description provided for @macosApp.
  ///
  /// In en, this message translates to:
  /// **'macOS app'**
  String get macosApp;

  /// No description provided for @macosScreenRecordingIsNotGranted.
  ///
  /// In en, this message translates to:
  /// **'macOS Screen Recording is not granted to NeoAgent. Allow it in System Settings › Privacy & Security › Screen Recording, then reopen NeoAgent.'**
  String get macosScreenRecordingIsNotGranted;

  /// No description provided for @mailServersThatNeedAPassword.
  ///
  /// In en, this message translates to:
  /// **'Mail servers that need a password will refuse to send until a new '**
  String get mailServersThatNeedAPassword;

  /// No description provided for @main.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get main;

  /// No description provided for @makeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get makeDefault;

  /// No description provided for @makesTheBehindTheScenesCalls.
  ///
  /// In en, this message translates to:
  /// **'Makes the behind-the-scenes calls in a fraction of a '**
  String get makesTheBehindTheScenesCalls;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @managePayment.
  ///
  /// In en, this message translates to:
  /// **'Manage payment'**
  String get managePayment;

  /// No description provided for @manageViaStripeCustomerPortal.
  ///
  /// In en, this message translates to:
  /// **'Manage via Stripe Customer Portal'**
  String get manageViaStripeCustomerPortal;

  /// No description provided for @manageYourAccountEmailTwoFactor.
  ///
  /// In en, this message translates to:
  /// **'Manage your account email, two-factor authentication, and active sessions.'**
  String get manageYourAccountEmailTwoFactor;

  /// No description provided for @manageYourPlanTrackUsageUpdate.
  ///
  /// In en, this message translates to:
  /// **'Manage your plan, track usage, update payment, and review invoices.'**
  String get manageYourPlanTrackUsageUpdate;

  /// No description provided for @manageYourPlanTrackUsageUpdate2.
  ///
  /// In en, this message translates to:
  /// **'Manage your plan, track usage, update payment, and review invoices — all in one place.'**
  String get manageYourPlanTrackUsageUpdate2;

  /// No description provided for @managedBy.
  ///
  /// In en, this message translates to:
  /// **'Managed by'**
  String get managedBy;

  /// No description provided for @managerUsernameAsManagedBy.
  ///
  /// In en, this message translates to:
  /// **'       manager.username AS managed_by,\n'**
  String get managerUsernameAsManagedBy;

  /// No description provided for @managersCanHaveManagersOfTheir.
  ///
  /// In en, this message translates to:
  /// **'Managers can have managers of their own (up to four levels). A '**
  String get managersCanHaveManagersOfTheir;

  /// No description provided for @managing.
  ///
  /// In en, this message translates to:
  /// **'Managing'**
  String get managing;

  /// No description provided for @manualDestination.
  ///
  /// In en, this message translates to:
  /// **'Manual destination'**
  String get manualDestination;

  /// No description provided for @manualRouting.
  ///
  /// In en, this message translates to:
  /// **'Manual routing'**
  String get manualRouting;

  /// No description provided for @manualTrigger.
  ///
  /// In en, this message translates to:
  /// **'Manual Trigger'**
  String get manualTrigger;

  /// No description provided for @masterPassword.
  ///
  /// In en, this message translates to:
  /// **'Master password'**
  String get masterPassword;

  /// No description provided for @matchThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Match this device'**
  String get matchThisDevice;

  /// No description provided for @matchedAgainstTitleAndBody.
  ///
  /// In en, this message translates to:
  /// **'Matched against title and body'**
  String get matchedAgainstTitleAndBody;

  /// No description provided for @matchesTheOldNeoagentMcpFlow.
  ///
  /// In en, this message translates to:
  /// **'Matches the old NeoAgent MCP flow: URL plus auth method.'**
  String get matchesTheOldNeoagentMcpFlow;

  /// No description provided for @mcp.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get mcp;

  /// No description provided for @mcpServer.
  ///
  /// In en, this message translates to:
  /// **'MCP server'**
  String get mcpServer;

  /// No description provided for @mcpServer2.
  ///
  /// In en, this message translates to:
  /// **'MCP Server'**
  String get mcpServer2;

  /// No description provided for @mcpServerUrl.
  ///
  /// In en, this message translates to:
  /// **'MCP Server URL'**
  String get mcpServerUrl;

  /// No description provided for @mcpServers.
  ///
  /// In en, this message translates to:
  /// **'MCP servers'**
  String get mcpServers;

  /// No description provided for @meantForSomeoneElse.
  ///
  /// In en, this message translates to:
  /// **'Meant for someone else'**
  String get meantForSomeoneElse;

  /// No description provided for @measuredModelCostArg1.
  ///
  /// In en, this message translates to:
  /// **'Measured model cost: {arg1}'**
  String measuredModelCostArg1(Object? arg1);

  /// No description provided for @memories.
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get memories;

  /// No description provided for @memory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memory;

  /// No description provided for @memoryArg1.
  ///
  /// In en, this message translates to:
  /// **'Memory: {arg1}'**
  String memoryArg1(Object? arg1);

  /// No description provided for @memoryImportSync.
  ///
  /// In en, this message translates to:
  /// **'memory import sync'**
  String get memoryImportSync;

  /// No description provided for @memoryIngestionInterval.
  ///
  /// In en, this message translates to:
  /// **'Memory ingestion interval'**
  String get memoryIngestionInterval;

  /// No description provided for @memoryIngestionIntervalMs.
  ///
  /// In en, this message translates to:
  /// **'Memory ingestion interval (ms)'**
  String get memoryIngestionIntervalMs;

  /// No description provided for @memoryIngestionIntervalMustBeAt.
  ///
  /// In en, this message translates to:
  /// **'Memory ingestion interval must be at least 1000 ms.'**
  String get memoryIngestionIntervalMustBeAt;

  /// No description provided for @memoryInjected.
  ///
  /// In en, this message translates to:
  /// **'Memory injected'**
  String get memoryInjected;

  /// No description provided for @memoryMb.
  ///
  /// In en, this message translates to:
  /// **'Memory (MB)'**
  String get memoryMb;

  /// No description provided for @memoryMustBeAtLeast512.
  ///
  /// In en, this message translates to:
  /// **'Memory must be at least 512 MB.'**
  String get memoryMustBeAtLeast512;

  /// No description provided for @mentionOrReplyOnly.
  ///
  /// In en, this message translates to:
  /// **'Mention or reply only'**
  String get mentionOrReplyOnly;

  /// No description provided for @mergedServerAndFlutterRuntimeLogs.
  ///
  /// In en, this message translates to:
  /// **'Merged server and Flutter runtime logs for this app session.'**
  String get mergedServerAndFlutterRuntimeLogs;

  /// No description provided for @meshRadioMessaging.
  ///
  /// In en, this message translates to:
  /// **'mesh radio messaging'**
  String get meshRadioMessaging;

  /// No description provided for @messageBodyTemplateJson.
  ///
  /// In en, this message translates to:
  /// **'Message body template (JSON)'**
  String get messageBodyTemplateJson;

  /// No description provided for @messageNeedsAccess.
  ///
  /// In en, this message translates to:
  /// **'Message needs access'**
  String get messageNeedsAccess;

  /// No description provided for @messageTextField.
  ///
  /// In en, this message translates to:
  /// **'Message text field'**
  String get messageTextField;

  /// No description provided for @messageYouWithTheResultAdd.
  ///
  /// In en, this message translates to:
  /// **'message you with the result. Add one to start, or skip and '**
  String get messageYouWithTheResultAdd;

  /// No description provided for @messageYourselfChatEveryOtherChat.
  ///
  /// In en, this message translates to:
  /// **'\"Message yourself\" chat. Every other chat and group on '**
  String get messageYourselfChatEveryOtherChat;

  /// No description provided for @messaging.
  ///
  /// In en, this message translates to:
  /// **'Messaging'**
  String get messaging;

  /// No description provided for @messagingApiPushAndWebhookEvents.
  ///
  /// In en, this message translates to:
  /// **'Messaging API push and webhook events'**
  String get messagingApiPushAndWebhookEvents;

  /// No description provided for @messagingConnectionNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Messaging connection needs attention'**
  String get messagingConnectionNeedsAttention;

  /// No description provided for @messagingConnections.
  ///
  /// In en, this message translates to:
  /// **'Messaging Connections'**
  String get messagingConnections;

  /// No description provided for @messagingDelivery.
  ///
  /// In en, this message translates to:
  /// **'Messaging delivery'**
  String get messagingDelivery;

  /// No description provided for @messagingErrorPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Messaging error. Please try again.'**
  String get messagingErrorPleaseTryAgain;

  /// No description provided for @microphoneCaptureStoppedUnexpectedlyTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Microphone capture stopped unexpectedly. Try again.'**
  String get microphoneCaptureStoppedUnexpectedlyTryAgain;

  /// No description provided for @microphoneErrorArg1.
  ///
  /// In en, this message translates to:
  /// **'Microphone error: {arg1}'**
  String microphoneErrorArg1(Object? arg1);

  /// No description provided for @microphoneMutedTapToUnmute.
  ///
  /// In en, this message translates to:
  /// **'Microphone muted. Tap to unmute.'**
  String get microphoneMutedTapToUnmute;

  /// No description provided for @microphonePermissionIsRequiredForLive.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for live voice.'**
  String get microphonePermissionIsRequiredForLive;

  /// No description provided for @microsoft365.
  ///
  /// In en, this message translates to:
  /// **'Microsoft 365'**
  String get microsoft365;

  /// No description provided for @microsoftSlackAndTheOtherIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Microsoft, Slack and the other integrations. They apply to '**
  String get microsoftSlackAndTheOtherIntegrations;

  /// No description provided for @microsoftTeams.
  ///
  /// In en, this message translates to:
  /// **'Microsoft Teams'**
  String get microsoftTeams;

  /// No description provided for @minimumContributionValueArg1.
  ///
  /// In en, this message translates to:
  /// **'Minimum contribution value: {arg1}'**
  String minimumContributionValueArg1(Object? arg1);

  /// No description provided for @mobileSetupFailedArg1.
  ///
  /// In en, this message translates to:
  /// **'Mobile setup failed.\n\n{arg1}'**
  String mobileSetupFailedArg1(Object? arg1);

  /// No description provided for @mobileSetupFailedBecauseJavaIs.
  ///
  /// In en, this message translates to:
  /// **'Mobile setup failed because Java is not available on the machine running NeoAgent.\n\n{arg1}'**
  String mobileSetupFailedBecauseJavaIs(Object? arg1);

  /// No description provided for @mobileSetupFailedBecauseJavaIs2.
  ///
  /// In en, this message translates to:
  /// **'Mobile setup failed because Java is not available on the machine running NeoAgent. Install a JDK and try again.'**
  String get mobileSetupFailedBecauseJavaIs2;

  /// No description provided for @mobileSetupFailedCheckThatAndroid.
  ///
  /// In en, this message translates to:
  /// **'Mobile setup failed. Check that Android tooling is installed correctly and try again.'**
  String get mobileSetupFailedCheckThatAndroid;

  /// No description provided for @modeArg1.
  ///
  /// In en, this message translates to:
  /// **'mode: {arg1}'**
  String modeArg1(Object? arg1);

  /// No description provided for @modeLocksWhileARunIs.
  ///
  /// In en, this message translates to:
  /// **'Mode locks while a run is active.'**
  String get modeLocksWhileARunIs;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @modelArg1.
  ///
  /// In en, this message translates to:
  /// **'Model: {arg1}'**
  String modelArg1(Object? arg1);

  /// No description provided for @modelAvailability.
  ///
  /// In en, this message translates to:
  /// **'Model availability'**
  String get modelAvailability;

  /// No description provided for @modelAvailabilitySaved.
  ///
  /// In en, this message translates to:
  /// **'Model availability saved.'**
  String get modelAvailabilitySaved;

  /// No description provided for @modelForThisSession.
  ///
  /// In en, this message translates to:
  /// **'Model for this session'**
  String get modelForThisSession;

  /// No description provided for @modelIds.
  ///
  /// In en, this message translates to:
  /// **'Model IDs'**
  String get modelIds;

  /// No description provided for @modelOverride.
  ///
  /// In en, this message translates to:
  /// **'Model Override'**
  String get modelOverride;

  /// No description provided for @modelPending.
  ///
  /// In en, this message translates to:
  /// **'Model pending'**
  String get modelPending;

  /// No description provided for @modelTurn.
  ///
  /// In en, this message translates to:
  /// **'Model turn'**
  String get modelTurn;

  /// No description provided for @modelTurnCompleted.
  ///
  /// In en, this message translates to:
  /// **'Model turn completed'**
  String get modelTurnCompleted;

  /// No description provided for @modelTurnStarted.
  ///
  /// In en, this message translates to:
  /// **'Model turn started'**
  String get modelTurnStarted;

  /// No description provided for @modelVisibilityHideShowList.
  ///
  /// In en, this message translates to:
  /// **'model visibility hide show list'**
  String get modelVisibilityHideShowList;

  /// No description provided for @models.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get models;

  /// No description provided for @modelsBehaviorVoiceAndWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Models, behavior, voice, and workspace'**
  String get modelsBehaviorVoiceAndWorkspace;

  /// No description provided for @modelsBrowserVoiceDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Models, browser, voice, diagnostics...'**
  String get modelsBrowserVoiceDiagnostics;

  /// No description provided for @modelsRouting.
  ///
  /// In en, this message translates to:
  /// **'Models & routing'**
  String get modelsRouting;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @morningBriefing.
  ///
  /// In en, this message translates to:
  /// **'Morning briefing'**
  String get morningBriefing;

  /// No description provided for @mostUsedAgents.
  ///
  /// In en, this message translates to:
  /// **'Most used agents'**
  String get mostUsedAgents;

  /// No description provided for @mostUsedModelsInTheLast.
  ///
  /// In en, this message translates to:
  /// **'Most used models in the last {arg1}.'**
  String mostUsedModelsInTheLast(Object? arg1);

  /// No description provided for @mouseKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Mouse & keyboard'**
  String get mouseKeyboard;

  /// No description provided for @mousemoveIsNotSupportedOnThis.
  ///
  /// In en, this message translates to:
  /// **'mouseMove is not supported on this platform.'**
  String get mousemoveIsNotSupportedOnThis;

  /// No description provided for @mustBeReachableOnThePublic.
  ///
  /// In en, this message translates to:
  /// **'Must be reachable on the public internet -- local and '**
  String get mustBeReachableOnThePublic;

  /// No description provided for @n0TurnsTrialsOff.
  ///
  /// In en, this message translates to:
  /// **'0 turns trials off.'**
  String get n0TurnsTrialsOff;

  /// No description provided for @n24Hours.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get n24Hours;

  /// No description provided for @n2faOrRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'2FA or recovery code'**
  String get n2faOrRecoveryCode;

  /// No description provided for @n2faRequiresSessionSecretToBe.
  ///
  /// In en, this message translates to:
  /// **'2FA requires SESSION_SECRET to be configured on this NeoAgent deployment.'**
  String get n2faRequiresSessionSecretToBe;

  /// No description provided for @n30Days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get n30Days;

  /// No description provided for @n365Days.
  ///
  /// In en, this message translates to:
  /// **'365 days'**
  String get n365Days;

  /// No description provided for @n42Passing.
  ///
  /// In en, this message translates to:
  /// **'✓ 42 passing'**
  String get n42Passing;

  /// No description provided for @n4HourLimitTokens.
  ///
  /// In en, this message translates to:
  /// **'4-hour limit (tokens)'**
  String get n4HourLimitTokens;

  /// No description provided for @n4HourTokenLimit.
  ///
  /// In en, this message translates to:
  /// **'4-hour token limit'**
  String get n4HourTokenLimit;

  /// No description provided for @n4HourUsage.
  ///
  /// In en, this message translates to:
  /// **'4-hour usage'**
  String get n4HourUsage;

  /// No description provided for @n4hLimitArg1.
  ///
  /// In en, this message translates to:
  /// **'4h limit {arg1}'**
  String n4hLimitArg1(Object? arg1);

  /// No description provided for @n4hTokenWindow.
  ///
  /// In en, this message translates to:
  /// **'4h token window'**
  String get n4hTokenWindow;

  /// No description provided for @n7DayUsage.
  ///
  /// In en, this message translates to:
  /// **'7-day usage'**
  String get n7DayUsage;

  /// No description provided for @n7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get n7Days;

  /// No description provided for @n90Days.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get n90Days;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameNewSkillDescriptionDescribeWhat.
  ///
  /// In en, this message translates to:
  /// **'---\nname: New Skill\ndescription: Describe what this skill does\n---\nWrite the instructions for this skill here.\n'**
  String get nameNewSkillDescriptionDescribeWhat;

  /// No description provided for @nameOfWhoeverMadeIt.
  ///
  /// In en, this message translates to:
  /// **'name of whoever made it.'**
  String get nameOfWhoeverMadeIt;

  /// No description provided for @nameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptional;

  /// No description provided for @nativeAndWebhookChannels.
  ///
  /// In en, this message translates to:
  /// **'Native and webhook channels'**
  String get nativeAndWebhookChannels;

  /// No description provided for @naturalBubbles.
  ///
  /// In en, this message translates to:
  /// **'Natural bubbles'**
  String get naturalBubbles;

  /// No description provided for @nearbyNeoagentServers.
  ///
  /// In en, this message translates to:
  /// **'Nearby NeoAgent servers'**
  String get nearbyNeoagentServers;

  /// No description provided for @needANewAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'Need a new account? Register'**
  String get needANewAccountRegister;

  /// No description provided for @needAnIdea.
  ///
  /// In en, this message translates to:
  /// **'Need an idea?'**
  String get needAnIdea;

  /// No description provided for @needToReplyArg1ToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Need to reply · {arg1}% to speak'**
  String needToReplyArg1ToSpeak(Object? arg1);

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @needsInput.
  ///
  /// In en, this message translates to:
  /// **'Needs input'**
  String get needsInput;

  /// No description provided for @neoagentApp.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent app'**
  String get neoagentApp;

  /// No description provided for @neoagentArg1.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent, {arg1}'**
  String neoagentArg1(Object? arg1);

  /// No description provided for @neoagentAssistant.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent Assistant'**
  String get neoagentAssistant;

  /// No description provided for @neoagentCouldNotCheckTheAvailable.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent could not check the available backend runtime.'**
  String get neoagentCouldNotCheckTheAvailable;

  /// No description provided for @neoagentCouldNotFinishTheLocal.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent could not finish the local setup.'**
  String get neoagentCouldNotFinishTheLocal;

  /// No description provided for @neoagentCouldNotFinishTheLocal2.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent could not finish the local setup. {arg1}'**
  String neoagentCouldNotFinishTheLocal2(Object? arg1);

  /// No description provided for @neoagentDebugInfo.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent debug info'**
  String get neoagentDebugInfo;

  /// No description provided for @neoagentDesktopInstaller.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent Desktop Installer'**
  String get neoagentDesktopInstaller;

  /// No description provided for @neoagentFlutterUpdater.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent Flutter Updater'**
  String get neoagentFlutterUpdater;

  /// No description provided for @neoagentHasItsOwnComputer.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent has its\nown computer.'**
  String get neoagentHasItsOwnComputer;

  /// No description provided for @neoagentInstallsTheLatestArg1.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent installs the latest {arg1} '**
  String neoagentInstallsTheLatestArg1(Object? arg1);

  /// No description provided for @neoagentIsInstalledAndRunning.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent is installed and running.'**
  String get neoagentIsInstalledAndRunning;

  /// No description provided for @neoagentIsNotInstalledOnThis.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent is not installed on this computer.'**
  String get neoagentIsNotInstalledOnThis;

  /// No description provided for @neoagentIsReady.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent is ready'**
  String get neoagentIsReady;

  /// No description provided for @neoagentIsStillWorkingOnA.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent is still working on a task. End the call and get the result in chat, or cancel the task too.'**
  String get neoagentIsStillWorkingOnA;

  /// No description provided for @neoagentIsTurningYourDemonstrationInto.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent is turning your demonstration into an adaptable workflow.'**
  String get neoagentIsTurningYourDemonstrationInto;

  /// No description provided for @neoagentIsWaitingWhileYouUse.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent is waiting while you use the desktop.'**
  String get neoagentIsWaitingWhileYouUse;

  /// No description provided for @neoagentIsWorking.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent is working'**
  String get neoagentIsWorking;

  /// No description provided for @neoagentLinuxComputer.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent Linux computer'**
  String get neoagentLinuxComputer;

  /// No description provided for @neoagentNeedsADecision.
  ///
  /// In en, this message translates to:
  /// **'NEOAGENT NEEDS A DECISION'**
  String get neoagentNeedsADecision;

  /// No description provided for @neoagentNoReplyExampleCom.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent <no-reply@example.com>'**
  String get neoagentNoReplyExampleCom;

  /// No description provided for @neoagentRuntimeDownloadsRequireASecure.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent runtime downloads require a secure address.'**
  String get neoagentRuntimeDownloadsRequireASecure;

  /// No description provided for @neoagentServerAddress.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent server address'**
  String get neoagentServerAddress;

  /// No description provided for @neoagentServiceEmailIsNotReady.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent service email is not ready. Ask the server operator to check the email environment settings.'**
  String get neoagentServiceEmailIsNotReady;

  /// No description provided for @neoagentSetupCouldNotFinish.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent setup could not finish.'**
  String get neoagentSetupCouldNotFinish;

  /// No description provided for @neoagentUser.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent User'**
  String get neoagentUser;

  /// No description provided for @neoagentUsesThisComputerAutomaticallyAnd.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent uses this computer automatically and asks before it uses your screen, mouse, keyboard, files or command line.'**
  String get neoagentUsesThisComputerAutomaticallyAnd;

  /// No description provided for @neoagentUsesYourApproximateBackgroundLocation.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent uses your approximate background location to trigger geofence reminders (e.g. \"Remind me to buy milk when I walk past the supermarket\").\n\n'**
  String get neoagentUsesYourApproximateBackgroundLocation;

  /// No description provided for @neoagentWorkspace.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent Workspace'**
  String get neoagentWorkspace;

  /// No description provided for @neodiagArg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'[NeoDiag][{arg1}] {arg2}'**
  String neodiagArg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @neodiagArg1StackArg2.
  ///
  /// In en, this message translates to:
  /// **'[NeoDiag][{arg1}][stack] {arg2}'**
  String neodiagArg1StackArg2(Object? arg1, Object? arg2);

  /// No description provided for @neorecallBackendUrl.
  ///
  /// In en, this message translates to:
  /// **'NeoRecall Backend URL'**
  String get neorecallBackendUrl;

  /// No description provided for @neorecallBackendUrlIsRequired.
  ///
  /// In en, this message translates to:
  /// **'NeoRecall backend URL is required.'**
  String get neorecallBackendUrlIsRequired;

  /// No description provided for @neorecallSetup.
  ///
  /// In en, this message translates to:
  /// **'NeoRecall Setup'**
  String get neorecallSetup;

  /// No description provided for @networkRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'network request failed'**
  String get networkRequestFailed;

  /// No description provided for @networkWriteRequests.
  ///
  /// In en, this message translates to:
  /// **'Network Write Requests'**
  String get networkWriteRequests;

  /// No description provided for @neverCountsAgainstTheSharedUsage.
  ///
  /// In en, this message translates to:
  /// **'never counts against the shared usage limits.'**
  String get neverCountsAgainstTheSharedUsage;

  /// No description provided for @newAccountsConfirmTheirEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'New accounts confirm their email address before signing in.'**
  String get newAccountsConfirmTheirEmailAddress;

  /// No description provided for @newAccountsPerDay.
  ///
  /// In en, this message translates to:
  /// **'New accounts per day'**
  String get newAccountsPerDay;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @newGroupsStayQuietUnlessSomeone.
  ///
  /// In en, this message translates to:
  /// **'New groups stay quiet unless someone tags {arg1}, until you turn them on.'**
  String newGroupsStayQuietUnlessSomeone(Object? arg1);

  /// No description provided for @newLink.
  ///
  /// In en, this message translates to:
  /// **'New link'**
  String get newLink;

  /// No description provided for @newPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'New passwords do not match.'**
  String get newPasswordsDoNotMatch;

  /// No description provided for @newPlan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get newPlan;

  /// No description provided for @newRecoveryCodes.
  ///
  /// In en, this message translates to:
  /// **'New recovery codes'**
  String get newRecoveryCodes;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// No description provided for @newSessionN.
  ///
  /// In en, this message translates to:
  /// **'New session (⌘N)'**
  String get newSessionN;

  /// No description provided for @newSessionWithSameSetup.
  ///
  /// In en, this message translates to:
  /// **'New session with same setup'**
  String get newSessionWithSameSetup;

  /// No description provided for @newSkill.
  ///
  /// In en, this message translates to:
  /// **'New skill'**
  String get newSkill;

  /// No description provided for @newSkill2.
  ///
  /// In en, this message translates to:
  /// **'New Skill'**
  String get newSkill2;

  /// No description provided for @newThisWeek.
  ///
  /// In en, this message translates to:
  /// **'New this week'**
  String get newThisWeek;

  /// No description provided for @newsDigest.
  ///
  /// In en, this message translates to:
  /// **'News digest'**
  String get newsDigest;

  /// No description provided for @nextEvent.
  ///
  /// In en, this message translates to:
  /// **'Next event'**
  String get nextEvent;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @nextRetryArg1.
  ///
  /// In en, this message translates to:
  /// **'Next retry: {arg1}'**
  String nextRetryArg1(Object? arg1);

  /// No description provided for @nextcloudLoginFlow.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud Login Flow'**
  String get nextcloudLoginFlow;

  /// No description provided for @nextcloudSetup.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud Setup'**
  String get nextcloudSetup;

  /// No description provided for @nextcloudTalk.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud Talk'**
  String get nextcloudTalk;

  /// No description provided for @nextcloudUrl.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud URL'**
  String get nextcloudUrl;

  /// No description provided for @nextcloudUrlIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud URL is required.'**
  String get nextcloudUrlIsRequired;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @noAccountsConnectedYet.
  ///
  /// In en, this message translates to:
  /// **'No accounts connected yet.'**
  String get noAccountsConnectedYet;

  /// No description provided for @noAccountsFound.
  ///
  /// In en, this message translates to:
  /// **'No accounts found.'**
  String get noAccountsFound;

  /// No description provided for @noActivePlansYetCreateOne.
  ///
  /// In en, this message translates to:
  /// **'No active plans yet. Create one in the Billing tab.'**
  String get noActivePlansYetCreateOne;

  /// No description provided for @noActiveSessionsFound.
  ///
  /// In en, this message translates to:
  /// **'No active sessions found.'**
  String get noActiveSessionsFound;

  /// No description provided for @noActiveSubscription.
  ///
  /// In en, this message translates to:
  /// **'No active subscription'**
  String get noActiveSubscription;

  /// No description provided for @noAgentsYet.
  ///
  /// In en, this message translates to:
  /// **'No agents yet'**
  String get noAgentsYet;

  /// No description provided for @noAiProviderIsConfiguredSo.
  ///
  /// In en, this message translates to:
  /// **'No AI provider is configured, so chat and messaging '**
  String get noAiProviderIsConfiguredSo;

  /// No description provided for @noApprovalPromptsAgentRunsWithout.
  ///
  /// In en, this message translates to:
  /// **'No approval prompts — agent runs without interruption.'**
  String get noApprovalPromptsAgentRunsWithout;

  /// No description provided for @noArg1ReleaseAssetMatchedThis.
  ///
  /// In en, this message translates to:
  /// **'No {arg1} release asset matched this platform.'**
  String noArg1ReleaseAssetMatchedThis(Object? arg1);

  /// No description provided for @noArg1Subscriptions.
  ///
  /// In en, this message translates to:
  /// **'No {arg1} subscriptions.'**
  String noArg1Subscriptions(Object? arg1);

  /// No description provided for @noArguments.
  ///
  /// In en, this message translates to:
  /// **'(no arguments)'**
  String get noArguments;

  /// No description provided for @noAuth.
  ///
  /// In en, this message translates to:
  /// **'No auth'**
  String get noAuth;

  /// No description provided for @noAvailableModelsYetCheckBack.
  ///
  /// In en, this message translates to:
  /// **'No available models yet.\nCheck back once a provider is configured.'**
  String get noAvailableModelsYetCheckBack;

  /// No description provided for @noBindingsYet.
  ///
  /// In en, this message translates to:
  /// **'No bindings yet.'**
  String get noBindingsYet;

  /// No description provided for @noChangesYet.
  ///
  /// In en, this message translates to:
  /// **'No changes yet'**
  String get noChangesYet;

  /// No description provided for @noChannelsFound.
  ///
  /// In en, this message translates to:
  /// **'No channels found'**
  String get noChannelsFound;

  /// No description provided for @noCloudComputerSlotIsFree.
  ///
  /// In en, this message translates to:
  /// **'No cloud-computer slot is free right now. Try again in a moment.'**
  String get noCloudComputerSlotIsFree;

  /// No description provided for @noCoreMemoryEntriesYet.
  ///
  /// In en, this message translates to:
  /// **'No core memory entries yet.'**
  String get noCoreMemoryEntriesYet;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noDescription;

  /// No description provided for @noDesktopDisplaysAreCurrentlyAvailable.
  ///
  /// In en, this message translates to:
  /// **'No desktop displays are currently available.'**
  String get noDesktopDisplaysAreCurrentlyAvailable;

  /// No description provided for @noDetailAvailable.
  ///
  /// In en, this message translates to:
  /// **'No detail available'**
  String get noDetailAvailable;

  /// No description provided for @noDetailedSyncSummaryYet.
  ///
  /// In en, this message translates to:
  /// **'No detailed sync summary yet.'**
  String get noDetailedSyncSummaryYet;

  /// No description provided for @noDetailsCaptured.
  ///
  /// In en, this message translates to:
  /// **'No details captured.'**
  String get noDetailsCaptured;

  /// No description provided for @noEmailLinked.
  ///
  /// In en, this message translates to:
  /// **'No email linked'**
  String get noEmailLinked;

  /// No description provided for @noExternalSignInProvidersLinked.
  ///
  /// In en, this message translates to:
  /// **'No external sign-in providers linked.'**
  String get noExternalSignInProvidersLinked;

  /// No description provided for @noGroupMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No group messages yet'**
  String get noGroupMessagesYet;

  /// No description provided for @noGroupSpecificPeopleAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No group-specific people added yet.'**
  String get noGroupSpecificPeopleAddedYet;

  /// No description provided for @noGroupsAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No groups added yet.'**
  String get noGroupsAddedYet;

  /// No description provided for @noGroupsFoundYetAfterArg1.
  ///
  /// In en, this message translates to:
  /// **'No groups found yet. After {arg1} sees a group message, use Find recent chats and they will show up here.'**
  String noGroupsFoundYetAfterArg1(Object? arg1);

  /// No description provided for @noGroupsFoundYetAfterArg12.
  ///
  /// In en, this message translates to:
  /// **'No groups found yet. After {arg1} sees a group message, use Find recent chats.'**
  String noGroupsFoundYetAfterArg12(Object? arg1);

  /// No description provided for @noHealthDataPayloadReturned.
  ///
  /// In en, this message translates to:
  /// **'No health data payload returned.'**
  String get noHealthDataPayloadReturned;

  /// No description provided for @noHealthSamplesStoredYet.
  ///
  /// In en, this message translates to:
  /// **'No health samples stored yet.'**
  String get noHealthSamplesStoredYet;

  /// No description provided for @noHttpClientImplementationForThis.
  ///
  /// In en, this message translates to:
  /// **'No HTTP client implementation for this platform.'**
  String get noHttpClientImplementationForThis;

  /// No description provided for @noInputOrOutputWasRecorded.
  ///
  /// In en, this message translates to:
  /// **'No input or output was recorded for this step.'**
  String get noInputOrOutputWasRecorded;

  /// No description provided for @noIntegrationsMatchThisSearch.
  ///
  /// In en, this message translates to:
  /// **'No integrations match this search.'**
  String get noIntegrationsMatchThisSearch;

  /// No description provided for @noInvoicesYet.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet.'**
  String get noInvoicesYet;

  /// No description provided for @noLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get noLimit;

  /// No description provided for @noLocalPasswordIsSetYet.
  ///
  /// In en, this message translates to:
  /// **'No local password is set yet. Create one to enable username/password sign-in.'**
  String get noLocalPasswordIsSetYet;

  /// No description provided for @noLogEntries.
  ///
  /// In en, this message translates to:
  /// **'No log entries.'**
  String get noLogEntries;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @noMatchingSettings.
  ///
  /// In en, this message translates to:
  /// **'No matching settings'**
  String get noMatchingSettings;

  /// No description provided for @noMcpServersMatchThisSearch.
  ///
  /// In en, this message translates to:
  /// **'No MCP servers match this search.'**
  String get noMcpServersMatchThisSearch;

  /// No description provided for @noMemoryEntriesFound.
  ///
  /// In en, this message translates to:
  /// **'No memory entries found.'**
  String get noMemoryEntriesFound;

  /// No description provided for @noMemorySync.
  ///
  /// In en, this message translates to:
  /// **'No memory sync'**
  String get noMemorySync;

  /// No description provided for @noModelMatchesArg1.
  ///
  /// In en, this message translates to:
  /// **'No model matches \"{arg1}\".'**
  String noModelMatchesArg1(Object? arg1);

  /// No description provided for @noModelRequestWasRecordedFor.
  ///
  /// In en, this message translates to:
  /// **'No model request was recorded for this run.'**
  String get noModelRequestWasRecordedFor;

  /// No description provided for @noModelsAreAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'No models are available yet.'**
  String get noModelsAreAvailableYet;

  /// No description provided for @noModelsDiscoveredYet.
  ///
  /// In en, this message translates to:
  /// **'No models discovered yet'**
  String get noModelsDiscoveredYet;

  /// No description provided for @noModelsSelected.
  ///
  /// In en, this message translates to:
  /// **'No models selected'**
  String get noModelsSelected;

  /// No description provided for @noModelsYet.
  ///
  /// In en, this message translates to:
  /// **'No models yet'**
  String get noModelsYet;

  /// No description provided for @noNeoagentAccountIsLinkedTo.
  ///
  /// In en, this message translates to:
  /// **'no neoagent account is linked to this provider'**
  String get noNeoagentAccountIsLinkedTo;

  /// No description provided for @noNeoagentBackendRuntimeIsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No NeoAgent backend runtime is available for this computer.'**
  String get noNeoagentBackendRuntimeIsAvailable;

  /// No description provided for @noNetworkConnection.
  ///
  /// In en, this message translates to:
  /// **'No network connection'**
  String get noNetworkConnection;

  /// No description provided for @noNetworkConnectionConnectToKeep.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Connect to keep using NeoAgent.'**
  String get noNetworkConnectionConnectToKeep;

  /// No description provided for @noNetworkConnectionReconnectToCheck.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Reconnect to check for updates.'**
  String get noNetworkConnectionReconnectToCheck;

  /// No description provided for @noOne.
  ///
  /// In en, this message translates to:
  /// **'No one'**
  String get noOne;

  /// No description provided for @noOneAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No one added yet.'**
  String get noOneAddedYet;

  /// No description provided for @noOneCanMessage.
  ///
  /// In en, this message translates to:
  /// **'No one can message'**
  String get noOneCanMessage;

  /// No description provided for @noOtherNeoagentServerWasFound.
  ///
  /// In en, this message translates to:
  /// **'No other NeoAgent server was found. You can search again or enter an address manually.'**
  String get noOtherNeoagentServerWasFound;

  /// No description provided for @noPeopleAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No people added yet.'**
  String get noPeopleAddedYet;

  /// No description provided for @noPlansConfiguredYet.
  ///
  /// In en, this message translates to:
  /// **'No plans configured yet.'**
  String get noPlansConfiguredYet;

  /// No description provided for @noPlansYet.
  ///
  /// In en, this message translates to:
  /// **'No plans yet.'**
  String get noPlansYet;

  /// No description provided for @noPlatformsMatch.
  ///
  /// In en, this message translates to:
  /// **'No platforms match'**
  String get noPlatformsMatch;

  /// No description provided for @noProvidersAreAvailableToConfigure.
  ///
  /// In en, this message translates to:
  /// **'No providers are available to configure yet.'**
  String get noProvidersAreAvailableToConfigure;

  /// No description provided for @noRecentChannelActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent channel activity'**
  String get noRecentChannelActivity;

  /// No description provided for @noResultsForArg1.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{arg1}\"'**
  String noResultsForArg1(Object? arg1);

  /// No description provided for @noRunsInThisRange.
  ///
  /// In en, this message translates to:
  /// **'No runs in this range.'**
  String get noRunsInThisRange;

  /// No description provided for @noRunsMatchTheseFilters.
  ///
  /// In en, this message translates to:
  /// **'No runs match these filters'**
  String get noRunsMatchTheseFilters;

  /// No description provided for @noRunsYet.
  ///
  /// In en, this message translates to:
  /// **'No runs yet'**
  String get noRunsYet;

  /// No description provided for @noRunsYet2.
  ///
  /// In en, this message translates to:
  /// **'No runs yet.'**
  String get noRunsYet2;

  /// No description provided for @noSecurityKeyWasProvided.
  ///
  /// In en, this message translates to:
  /// **'No security key was provided.'**
  String get noSecurityKeyWasProvided;

  /// No description provided for @noServerOpenrouterKeyYetAdd.
  ///
  /// In en, this message translates to:
  /// **'No server OpenRouter key yet. Add one under Providers, '**
  String get noServerOpenrouterKeyYetAdd;

  /// No description provided for @noServerUrlSet.
  ///
  /// In en, this message translates to:
  /// **'No server URL set'**
  String get noServerUrlSet;

  /// No description provided for @noSessionMatchesThatSearch.
  ///
  /// In en, this message translates to:
  /// **'No session matches that search.'**
  String get noSessionMatchesThatSearch;

  /// No description provided for @noSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessionsYet;

  /// No description provided for @noSkillsMatchTheseFilters.
  ///
  /// In en, this message translates to:
  /// **'No skills match these filters.'**
  String get noSkillsMatchTheseFilters;

  /// No description provided for @noStepsWereRecordedForThis.
  ///
  /// In en, this message translates to:
  /// **'No steps were recorded for this run.'**
  String get noStepsWereRecordedForThis;

  /// No description provided for @noStoreSkillsMatchThisSearch.
  ///
  /// In en, this message translates to:
  /// **'No store skills match this search.'**
  String get noStoreSkillsMatchThisSearch;

  /// No description provided for @noSubscription.
  ///
  /// In en, this message translates to:
  /// **'No subscription.'**
  String get noSubscription;

  /// No description provided for @noSummary.
  ///
  /// In en, this message translates to:
  /// **'No summary'**
  String get noSummary;

  /// No description provided for @noSummaryAvailable.
  ///
  /// In en, this message translates to:
  /// **'No summary available.'**
  String get noSummaryAvailable;

  /// No description provided for @noTasksForArg1.
  ///
  /// In en, this message translates to:
  /// **'No tasks for {arg1}'**
  String noTasksForArg1(Object? arg1);

  /// No description provided for @noTimelineActivityYetForThe.
  ///
  /// In en, this message translates to:
  /// **'No timeline activity yet for the selected filters.'**
  String get noTimelineActivityYetForThe;

  /// No description provided for @noToolMatchesArg1.
  ///
  /// In en, this message translates to:
  /// **'No tool matches \"{arg1}\".'**
  String noToolMatchesArg1(Object? arg1);

  /// No description provided for @noUpdateRunning.
  ///
  /// In en, this message translates to:
  /// **'No update running'**
  String get noUpdateRunning;

  /// No description provided for @noUsageYet.
  ///
  /// In en, this message translates to:
  /// **'No usage yet.'**
  String get noUsageYet;

  /// No description provided for @noVerifiedNeoagentBackendRuntimeIs.
  ///
  /// In en, this message translates to:
  /// **'No verified NeoAgent backend runtime is available yet.'**
  String get noVerifiedNeoagentBackendRuntimeIs;

  /// No description provided for @nobodyCanUseItAnyMore.
  ///
  /// In en, this message translates to:
  /// **'Nobody can use it any more. People who already joined '**
  String get nobodyCanUseItAnyMore;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @notApprovedYet.
  ///
  /// In en, this message translates to:
  /// **'not approved yet'**
  String get notApprovedYet;

  /// No description provided for @notAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'not authenticated'**
  String get notAuthenticated;

  /// No description provided for @notCheckedYet.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get notCheckedYet;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get notConfigured;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @notConnected2.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get notConnected2;

  /// No description provided for @notInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get notInstalled;

  /// No description provided for @notNeeded.
  ///
  /// In en, this message translates to:
  /// **'Not needed'**
  String get notNeeded;

  /// No description provided for @notNeededEnough.
  ///
  /// In en, this message translates to:
  /// **'Not needed enough'**
  String get notNeededEnough;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @notNow2.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow2;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @notSetUp.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get notSetUp;

  /// No description provided for @notTheSameAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Not the same as admin'**
  String get notTheSameAsAdmin;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get nothingHereYet;

  /// No description provided for @nothingHereYet2.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet2;

  /// No description provided for @nothingMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches'**
  String get nothingMatches;

  /// No description provided for @nothingStoredYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing stored yet.'**
  String get nothingStoredYet;

  /// No description provided for @notionSlackFigmaGithubSpotifyTrello.
  ///
  /// In en, this message translates to:
  /// **'Notion, Slack, Figma, GitHub, Spotify, Trello'**
  String get notionSlackFigmaGithubSpotifyTrello;

  /// No description provided for @nvidiaNim.
  ///
  /// In en, this message translates to:
  /// **'NVIDIA NIM'**
  String get nvidiaNim;

  /// No description provided for @oauthAppCredentialsThatLetAccounts.
  ///
  /// In en, this message translates to:
  /// **'OAuth app credentials that let accounts connect Google, '**
  String get oauthAppCredentialsThatLetAccounts;

  /// No description provided for @oauthClientId.
  ///
  /// In en, this message translates to:
  /// **'OAuth Client ID'**
  String get oauthClientId;

  /// No description provided for @oauthClientIdSecretRedirectApi.
  ///
  /// In en, this message translates to:
  /// **'oauth client id secret redirect api key'**
  String get oauthClientIdSecretRedirectApi;

  /// No description provided for @oauthClientIdSecretRedirectGmail.
  ///
  /// In en, this message translates to:
  /// **'oauth client id secret redirect gmail calendar drive'**
  String get oauthClientIdSecretRedirectGmail;

  /// No description provided for @oauthLaunchIsNotSupportedOn.
  ///
  /// In en, this message translates to:
  /// **'OAuth launch is not supported on this platform.'**
  String get oauthLaunchIsNotSupportedOn;

  /// No description provided for @oauthOutlookTenantClientIdSecret.
  ///
  /// In en, this message translates to:
  /// **'oauth outlook tenant client id secret'**
  String get oauthOutlookTenantClientIdSecret;

  /// No description provided for @oauthToken.
  ///
  /// In en, this message translates to:
  /// **'OAuth token'**
  String get oauthToken;

  /// No description provided for @oauthWithPkce.
  ///
  /// In en, this message translates to:
  /// **'OAuth with PKCE'**
  String get oauthWithPkce;

  /// No description provided for @ofArg1.
  ///
  /// In en, this message translates to:
  /// **'of {arg1}'**
  String ofArg1(Object? arg1);

  /// No description provided for @ofItsOwnItIsNever.
  ///
  /// In en, this message translates to:
  /// **'of its own. It is never shown again after saving.'**
  String get ofItsOwnItIsNever;

  /// No description provided for @ofUpToFiveItemsWith.
  ///
  /// In en, this message translates to:
  /// **'of up to five items with one sentence each and a link.'**
  String get ofUpToFiveItemsWith;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @offTakesEffectAfterAServer.
  ///
  /// In en, this message translates to:
  /// **'off takes effect after a server restart.'**
  String get offTakesEffectAfterAServer;

  /// No description provided for @offerSubscriptionPlansThroughStripeTurning.
  ///
  /// In en, this message translates to:
  /// **'Offer subscription plans through Stripe. Turning this on or '**
  String get offerSubscriptionPlansThroughStripeTurning;

  /// No description provided for @offeredToPeopleChoosingAPlan.
  ///
  /// In en, this message translates to:
  /// **'Offered to people choosing a plan.'**
  String get offeredToPeopleChoosingAPlan;

  /// No description provided for @officialIntegration.
  ///
  /// In en, this message translates to:
  /// **'Official integration'**
  String get officialIntegration;

  /// No description provided for @officialIntegrationDidNotReturnA.
  ///
  /// In en, this message translates to:
  /// **'Official integration did not return a connection URL.'**
  String get officialIntegrationDidNotReturnA;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @onASignedInAndroidDevice.
  ///
  /// In en, this message translates to:
  /// **'On a signed-in Android device, open Account settings, scan this code, and approve the login.'**
  String get onASignedInAndroidDevice;

  /// No description provided for @onAndTheServerHasRestarted.
  ///
  /// In en, this message translates to:
  /// **'on and the server has restarted.'**
  String get onAndTheServerHasRestarted;

  /// No description provided for @onByDefaultForNewGroups.
  ///
  /// In en, this message translates to:
  /// **'On by default for new groups'**
  String get onByDefaultForNewGroups;

  /// No description provided for @onDemand.
  ///
  /// In en, this message translates to:
  /// **'On Demand'**
  String get onDemand;

  /// No description provided for @onForArg1OfArg2Groups.
  ///
  /// In en, this message translates to:
  /// **'On for {arg1} of {arg2} groups'**
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2);

  /// No description provided for @onForEveryone.
  ///
  /// In en, this message translates to:
  /// **'On for everyone'**
  String get onForEveryone;

  /// No description provided for @onMyCalendarAndTheMost.
  ///
  /// In en, this message translates to:
  /// **'on my calendar, and the most important open items I know about. '**
  String get onMyCalendarAndTheMost;

  /// No description provided for @onTheyCanJoinAgainOnly.
  ///
  /// In en, this message translates to:
  /// **'on. They can join again only with a new invite link.'**
  String get onTheyCanJoinAgainOnly;

  /// No description provided for @onYourOwnTheDefault.
  ///
  /// In en, this message translates to:
  /// **'On your own (the default)'**
  String get onYourOwnTheDefault;

  /// No description provided for @once.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get once;

  /// No description provided for @oneBlankToKeepWhatIs.
  ///
  /// In en, this message translates to:
  /// **'one blank to keep what is stored.'**
  String get oneBlankToKeepWhatIs;

  /// No description provided for @oneIsSavedOtherChangesIn.
  ///
  /// In en, this message translates to:
  /// **'one is saved. Other changes in this form are saved too.'**
  String get oneIsSavedOtherChangesIn;

  /// No description provided for @oneLineSummaryEachIfNothing.
  ///
  /// In en, this message translates to:
  /// **'one-line summary each. If nothing needs my attention, do not send '**
  String get oneLineSummaryEachIfNothing;

  /// No description provided for @oneOrMoreAccountsExpiredReconnect.
  ///
  /// In en, this message translates to:
  /// **'One or more accounts expired. Reconnect the affected account to restore tool access.'**
  String get oneOrMoreAccountsExpiredReconnect;

  /// No description provided for @onePerLineShownOnThe.
  ///
  /// In en, this message translates to:
  /// **'One per line, shown on the pricing page.'**
  String get onePerLineShownOnThe;

  /// No description provided for @oneRegister.
  ///
  /// In en, this message translates to:
  /// **'one register.'**
  String get oneRegister;

  /// No description provided for @oneRuntimeControlsPersonaGroupTurn.
  ///
  /// In en, this message translates to:
  /// **'One runtime controls persona, group turn-taking, room memory, norms, Theory of Mind, and delivery.'**
  String get oneRuntimeControlsPersonaGroupTurn;

  /// No description provided for @oneTimeFree.
  ///
  /// In en, this message translates to:
  /// **'One-time / free'**
  String get oneTimeFree;

  /// No description provided for @oneTimeRun.
  ///
  /// In en, this message translates to:
  /// **'One-time run'**
  String get oneTimeRun;

  /// No description provided for @onlyApkOrApksFilesCan.
  ///
  /// In en, this message translates to:
  /// **'Only .apk or .apks files can be installed.'**
  String get onlyApkOrApksFilesCan;

  /// No description provided for @onlyInThisGroup.
  ///
  /// In en, this message translates to:
  /// **'Only in this group'**
  String get onlyInThisGroup;

  /// No description provided for @onlyMessageMeAboutEmailsThat.
  ///
  /// In en, this message translates to:
  /// **'Only message me about emails that are urgent or need a reply, with a '**
  String get onlyMessageMeAboutEmailsThat;

  /// No description provided for @onlyNeededIfTheServiceAsks.
  ///
  /// In en, this message translates to:
  /// **'Only needed if the service asks for extra HTTP headers.'**
  String get onlyNeededIfTheServiceAsks;

  /// No description provided for @onlyNeededIfYouWantTo.
  ///
  /// In en, this message translates to:
  /// **'Only needed if you want to reshape the outgoing payload.'**
  String get onlyNeededIfYouWantTo;

  /// No description provided for @onlyTheyCanChangeIt.
  ///
  /// In en, this message translates to:
  /// **'Only they can change it.'**
  String get onlyTheyCanChangeIt;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @openAccountSettingsOnASigned.
  ///
  /// In en, this message translates to:
  /// **'Open Account settings on a signed-in Android device, scan this code, and approve the login.'**
  String get openAccountSettingsOnASigned;

  /// No description provided for @openBrowserCheckingDocs.
  ///
  /// In en, this message translates to:
  /// **'open browser → checking docs'**
  String get openBrowserCheckingDocs;

  /// No description provided for @openComputer.
  ///
  /// In en, this message translates to:
  /// **'Open computer'**
  String get openComputer;

  /// No description provided for @openDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open dashboard'**
  String get openDashboard;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder…'**
  String get openFolder;

  /// No description provided for @openInWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Open in workbench'**
  String get openInWorkbench;

  /// No description provided for @openLinkedRun.
  ///
  /// In en, this message translates to:
  /// **'Open linked run'**
  String get openLinkedRun;

  /// No description provided for @openNeoagentAndReconnectArg1To.
  ///
  /// In en, this message translates to:
  /// **'Open NeoAgent and reconnect {arg1} to restore messaging.'**
  String openNeoagentAndReconnectArg1To(Object? arg1);

  /// No description provided for @openRun.
  ///
  /// In en, this message translates to:
  /// **'Open run'**
  String get openRun;

  /// No description provided for @openTheComputerTabNextTo.
  ///
  /// In en, this message translates to:
  /// **'Open the Computer tab next to any session to see the screen '**
  String get openTheComputerTabNextTo;

  /// No description provided for @openTimeSettings.
  ///
  /// In en, this message translates to:
  /// **'Open time settings'**
  String get openTimeSettings;

  /// No description provided for @openToAnyone.
  ///
  /// In en, this message translates to:
  /// **'Open to anyone'**
  String get openToAnyone;

  /// No description provided for @openTrello.
  ///
  /// In en, this message translates to:
  /// **'Open Trello'**
  String get openTrello;

  /// No description provided for @openVoiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Open voice assistant'**
  String get openVoiceAssistant;

  /// No description provided for @openWiFiSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Wi-Fi settings'**
  String get openWiFiSettings;

  /// No description provided for @openWithTheDefaultApp.
  ///
  /// In en, this message translates to:
  /// **'Open with the default app'**
  String get openWithTheDefaultApp;

  /// No description provided for @openaiCodex.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Codex'**
  String get openaiCodex;

  /// No description provided for @openaiCompatible.
  ///
  /// In en, this message translates to:
  /// **'openai compatible'**
  String get openaiCompatible;

  /// No description provided for @openaiCompatibleEndpointYourOwnServer.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible endpoint (your own server, or another '**
  String get openaiCompatibleEndpointYourOwnServer;

  /// No description provided for @openedArg1.
  ///
  /// In en, this message translates to:
  /// **'Opened {arg1}'**
  String openedArg1(Object? arg1);

  /// No description provided for @openingDesktopUrlsIsNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Opening desktop URLs is not supported on this platform.'**
  String get openingDesktopUrlsIsNotSupported;

  /// No description provided for @openingYourSavedDesktop.
  ///
  /// In en, this message translates to:
  /// **'Opening your saved desktop.'**
  String get openingYourSavedDesktop;

  /// No description provided for @openingYourSavedDesktopNormalStarts.
  ///
  /// In en, this message translates to:
  /// **'Opening your saved desktop. Normal starts take less than 10 seconds.'**
  String get openingYourSavedDesktopNormalStarts;

  /// No description provided for @optionalExtraSecretIfYouProtect.
  ///
  /// In en, this message translates to:
  /// **'Optional extra secret if you protect the inbound webhook.'**
  String get optionalExtraSecretIfYouProtect;

  /// No description provided for @optionalOverrideIfTheWebhookUrl.
  ///
  /// In en, this message translates to:
  /// **'Optional override if the webhook URL is not enough.'**
  String get optionalOverrideIfTheWebhookUrl;

  /// No description provided for @optionalSecretToVerifyIncomingChat.
  ///
  /// In en, this message translates to:
  /// **'Optional secret to verify incoming Chat events.'**
  String get optionalSecretToVerifyIncomingChat;

  /// No description provided for @optionalSecretToVerifyIncomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Optional secret to verify incoming events.'**
  String get optionalSecretToVerifyIncomingEvents;

  /// No description provided for @optionalSecretToVerifyIncomingImessage.
  ///
  /// In en, this message translates to:
  /// **'Optional secret to verify incoming iMessage events.'**
  String get optionalSecretToVerifyIncomingImessage;

  /// No description provided for @optionalSecretToVerifyIncomingLine.
  ///
  /// In en, this message translates to:
  /// **'Optional secret to verify incoming LINE events.'**
  String get optionalSecretToVerifyIncomingLine;

  /// No description provided for @optionalSecretToVerifyIncomingMattermost.
  ///
  /// In en, this message translates to:
  /// **'Optional secret to verify incoming Mattermost events.'**
  String get optionalSecretToVerifyIncomingMattermost;

  /// No description provided for @optionalSecretToVerifyIncomingTeams.
  ///
  /// In en, this message translates to:
  /// **'Optional secret to verify incoming Teams events.'**
  String get optionalSecretToVerifyIncomingTeams;

  /// No description provided for @optionalTheAgentAlreadyHasIts.
  ///
  /// In en, this message translates to:
  /// **'Optional. The agent already has its own personality. Anything you add about tone is layered on top of it, so you never have to define one.'**
  String get optionalTheAgentAlreadyHasIts;

  /// No description provided for @optionalWhenSetItIsUsed.
  ///
  /// In en, this message translates to:
  /// **'Optional. When set, it is used instead of the URL.'**
  String get optionalWhenSetItIsUsed;

  /// No description provided for @orAgentsCanUseTheirOwn.
  ///
  /// In en, this message translates to:
  /// **'or agents can use their own key under Advanced › Bring '**
  String get orAgentsCanUseTheirOwn;

  /// No description provided for @orAnswerInYourOwnWords.
  ///
  /// In en, this message translates to:
  /// **'Or answer in your own words'**
  String get orAnswerInYourOwnWords;

  /// No description provided for @orBuildYourOwnTask.
  ///
  /// In en, this message translates to:
  /// **'Or build your own task'**
  String get orBuildYourOwnTask;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// No description provided for @orFiles.
  ///
  /// In en, this message translates to:
  /// **'or files.'**
  String get orFiles;

  /// No description provided for @orderByBytesDesc.
  ///
  /// In en, this message translates to:
  /// **'ORDER BY bytes DESC'**
  String get orderByBytesDesc;

  /// No description provided for @orderByDayDesc.
  ///
  /// In en, this message translates to:
  /// **'ORDER BY day DESC'**
  String get orderByDayDesc;

  /// No description provided for @orderByIcLastConnectedAt.
  ///
  /// In en, this message translates to:
  /// **'ORDER BY ic.last_connected_at DESC\n'**
  String get orderByIcLastConnectedAt;

  /// No description provided for @orderByManagerUsernameManagedUsername.
  ///
  /// In en, this message translates to:
  /// **'ORDER BY manager.username, managed.username'**
  String get orderByManagerUsernameManagedUsername;

  /// No description provided for @orderByRCreatedAtDesc.
  ///
  /// In en, this message translates to:
  /// **'ORDER BY r.created_at DESC\n'**
  String get orderByRCreatedAtDesc;

  /// No description provided for @orderByRunsDesc.
  ///
  /// In en, this message translates to:
  /// **'ORDER BY runs DESC\n'**
  String get orderByRunsDesc;

  /// No description provided for @orderBySLastSeenAt.
  ///
  /// In en, this message translates to:
  /// **'ORDER BY s.last_seen_at DESC\n'**
  String get orderBySLastSeenAt;

  /// No description provided for @originNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'origin not allowed'**
  String get originNotAllowed;

  /// No description provided for @outgoingMessage.
  ///
  /// In en, this message translates to:
  /// **'Outgoing message'**
  String get outgoingMessage;

  /// No description provided for @outgoingWebhookUrl.
  ///
  /// In en, this message translates to:
  /// **'Outgoing webhook URL'**
  String get outgoingWebhookUrl;

  /// No description provided for @outlookEmailReceived.
  ///
  /// In en, this message translates to:
  /// **'Outlook Email Received'**
  String get outlookEmailReceived;

  /// No description provided for @overrideAssignsAPlanWithoutGoing.
  ///
  /// In en, this message translates to:
  /// **'Override assigns a plan without going through Stripe.'**
  String get overrideAssignsAPlanWithoutGoing;

  /// No description provided for @overridePlan.
  ///
  /// In en, this message translates to:
  /// **'Override plan'**
  String get overridePlan;

  /// No description provided for @overwriteBehaviorNotesFromTheImport.
  ///
  /// In en, this message translates to:
  /// **'Overwrite behavior notes from the import.'**
  String get overwriteBehaviorNotesFromTheImport;

  /// No description provided for @ownModel.
  ///
  /// In en, this message translates to:
  /// **'own model'**
  String get ownModel;

  /// No description provided for @packageName.
  ///
  /// In en, this message translates to:
  /// **'Package name'**
  String get packageName;

  /// No description provided for @pairWithQrCode.
  ///
  /// In en, this message translates to:
  /// **'Pair with QR code'**
  String get pairWithQrCode;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @password2faAndActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Password, 2FA, and active sessions'**
  String get password2faAndActiveSessions;

  /// No description provided for @passwordCreated.
  ///
  /// In en, this message translates to:
  /// **'Password created.'**
  String get passwordCreated;

  /// No description provided for @passwordIsTooWeak.
  ///
  /// In en, this message translates to:
  /// **'password is too weak'**
  String get passwordIsTooWeak;

  /// No description provided for @passwordMin8.
  ///
  /// In en, this message translates to:
  /// **'password min 8'**
  String get passwordMin8;

  /// No description provided for @passwordOrApiKey.
  ///
  /// In en, this message translates to:
  /// **'Password or API key'**
  String get passwordOrApiKey;

  /// No description provided for @passwordStrengthArg1.
  ///
  /// In en, this message translates to:
  /// **'Password strength: {arg1}'**
  String passwordStrengthArg1(Object? arg1);

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @pastDue.
  ///
  /// In en, this message translates to:
  /// **'Past due'**
  String get pastDue;

  /// No description provided for @pasteAKey.
  ///
  /// In en, this message translates to:
  /// **'Paste a key.'**
  String get pasteAKey;

  /// No description provided for @pasteANewKeyToReplace.
  ///
  /// In en, this message translates to:
  /// **'Paste a new key to replace {arg1}'**
  String pasteANewKeyToReplace(Object? arg1);

  /// No description provided for @pasteTheKey.
  ///
  /// In en, this message translates to:
  /// **'Paste the key'**
  String get pasteTheKey;

  /// No description provided for @pasteYourAccountToken.
  ///
  /// In en, this message translates to:
  /// **'Paste your account token'**
  String get pasteYourAccountToken;

  /// No description provided for @pasteYourArg1ApiKeyBelow.
  ///
  /// In en, this message translates to:
  /// **'Paste your {arg1} API key below. It\'\'s '**
  String pasteYourArg1ApiKeyBelow(Object? arg1);

  /// No description provided for @pathMustStayInsideNeoagentWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Path must stay inside NeoAgent Workspace.'**
  String get pathMustStayInsideNeoagentWorkspace;

  /// No description provided for @pathMustStayInsideTheWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Path must stay inside the workspace folder.'**
  String get pathMustStayInsideTheWorkspace;

  /// No description provided for @pauseLiveUpdates.
  ///
  /// In en, this message translates to:
  /// **'Pause live updates'**
  String get pauseLiveUpdates;

  /// No description provided for @pauseTaskLoop.
  ///
  /// In en, this message translates to:
  /// **'Pause task loop'**
  String get pauseTaskLoop;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @peakArg1.
  ///
  /// In en, this message translates to:
  /// **'peak {arg1}'**
  String peakArg1(Object? arg1);

  /// No description provided for @peopleInPrivateChats.
  ///
  /// In en, this message translates to:
  /// **'People in private chats'**
  String get peopleInPrivateChats;

  /// No description provided for @perAccountRateLimits.
  ///
  /// In en, this message translates to:
  /// **'Per-account rate limits'**
  String get perAccountRateLimits;

  /// No description provided for @perCategoryPermissions.
  ///
  /// In en, this message translates to:
  /// **'Per-category permissions'**
  String get perCategoryPermissions;

  /// No description provided for @perToolPermissionPoliciesApprovalGates.
  ///
  /// In en, this message translates to:
  /// **'Per-tool permission policies, approval gates, and process isolation for shell execution.'**
  String get perToolPermissionPoliciesApprovalGates;

  /// No description provided for @periodEndsArg1.
  ///
  /// In en, this message translates to:
  /// **'Period ends {arg1}'**
  String periodEndsArg1(Object? arg1);

  /// No description provided for @permanentlyAllowedNeverAsksAgain.
  ///
  /// In en, this message translates to:
  /// **'Permanently allowed — never asks again.'**
  String get permanentlyAllowedNeverAsksAgain;

  /// No description provided for @permissionRequiredArg1.
  ///
  /// In en, this message translates to:
  /// **'Permission required: {arg1}'**
  String permissionRequiredArg1(Object? arg1);

  /// No description provided for @permissionsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Permissions needed'**
  String get permissionsNeeded;

  /// No description provided for @permissionsToolPermissionsNobodyElseCan.
  ///
  /// In en, this message translates to:
  /// **'Permissions › Tool Permissions. Nobody else can change that.'**
  String get permissionsToolPermissionsNobodyElseCan;

  /// No description provided for @personOrChat.
  ///
  /// In en, this message translates to:
  /// **'Person or chat'**
  String get personOrChat;

  /// No description provided for @personaBehaviorNotes.
  ///
  /// In en, this message translates to:
  /// **'Persona behavior notes'**
  String get personaBehaviorNotes;

  /// No description provided for @personalAccessTokenForTheMattermost.
  ///
  /// In en, this message translates to:
  /// **'Personal access token for the Mattermost bot.'**
  String get personalAccessTokenForTheMattermost;

  /// No description provided for @personalChannelsAndDirectSupportSurfaces.
  ///
  /// In en, this message translates to:
  /// **'Personal channels and direct support surfaces.'**
  String get personalChannelsAndDirectSupportSurfaces;

  /// No description provided for @personalSelfChat.
  ///
  /// In en, this message translates to:
  /// **'Personal self-chat'**
  String get personalSelfChat;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @pickARunFromTheList.
  ///
  /// In en, this message translates to:
  /// **'Pick a run from the list to see its steps.'**
  String get pickARunFromTheList;

  /// No description provided for @pickARunFromTheList2.
  ///
  /// In en, this message translates to:
  /// **'Pick a run from the list on the left to explore its flow.'**
  String get pickARunFromTheList2;

  /// No description provided for @pickFromRecentArg1ChatsOr.
  ///
  /// In en, this message translates to:
  /// **'Pick from recent {arg1} chats, or add a person or group yourself.'**
  String pickFromRecentArg1ChatsOr(Object? arg1);

  /// No description provided for @pickHowArg1UsesThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Pick how {arg1} uses this account.'**
  String pickHowArg1UsesThisAccount(Object? arg1);

  /// No description provided for @pickOneToFillInThe.
  ///
  /// In en, this message translates to:
  /// **'Pick one to fill in the task. You can tweak everything afterwards.'**
  String get pickOneToFillInThe;

  /// No description provided for @pickTheModelNeoagentShouldUse.
  ///
  /// In en, this message translates to:
  /// **'Pick the model NeoAgent should use by default. Providers are configured on the server.'**
  String get pickTheModelNeoagentShouldUse;

  /// No description provided for @picksUpWhereYouLeftOff.
  ///
  /// In en, this message translates to:
  /// **'Picks up where you left off'**
  String get picksUpWhereYouLeftOff;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @planForArg1APlanAssigned.
  ///
  /// In en, this message translates to:
  /// **'Plan for @{arg1}. A plan assigned here '**
  String planForArg1APlanAssigned(Object? arg1);

  /// No description provided for @planId.
  ///
  /// In en, this message translates to:
  /// **'Plan ID'**
  String get planId;

  /// No description provided for @planIdMayOnlyUseLetters.
  ///
  /// In en, this message translates to:
  /// **'Plan ID may only use letters, numbers, underscores and hyphens.'**
  String get planIdMayOnlyUseLetters;

  /// No description provided for @planUsageAndAllowanceDetails.
  ///
  /// In en, this message translates to:
  /// **'Plan usage and allowance details'**
  String get planUsageAndAllowanceDetails;

  /// No description provided for @planning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get planning;

  /// No description provided for @plans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plans;

  /// No description provided for @plansAndSubscriptionsShowUpHere.
  ///
  /// In en, this message translates to:
  /// **'Plans and subscriptions show up here once billing is turned '**
  String get plansAndSubscriptionsShowUpHere;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @platformArg1Arg2.
  ///
  /// In en, this message translates to:
  /// **'Platform {arg1}{arg2}'**
  String platformArg1Arg2(Object? arg1, Object? arg2);

  /// No description provided for @pleaseChooseASchedule.
  ///
  /// In en, this message translates to:
  /// **'Please choose a schedule.'**
  String get pleaseChooseASchedule;

  /// No description provided for @pleaseEnterAFilename.
  ///
  /// In en, this message translates to:
  /// **'Please enter a filename.'**
  String get pleaseEnterAFilename;

  /// No description provided for @pleaseEnterAKey.
  ///
  /// In en, this message translates to:
  /// **'Please enter a key.'**
  String get pleaseEnterAKey;

  /// No description provided for @pleaseEnterAPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter a prompt.'**
  String get pleaseEnterAPrompt;

  /// No description provided for @pleaseEnterATaskName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a task name.'**
  String get pleaseEnterATaskName;

  /// No description provided for @pleaseEnterTheMemoryContent.
  ///
  /// In en, this message translates to:
  /// **'Please enter the memory content.'**
  String get pleaseEnterTheMemoryContent;

  /// No description provided for @pleaseEnterWhenTheTaskShould.
  ///
  /// In en, this message translates to:
  /// **'Please enter when the task should run.'**
  String get pleaseEnterWhenTheTaskShould;

  /// No description provided for @pleaseSelectAnAccountOrEnter.
  ///
  /// In en, this message translates to:
  /// **'Please select an account or enter a valid connection ID.'**
  String get pleaseSelectAnAccountOrEnter;

  /// No description provided for @pointNeoagentAtAnyOpenaiCompatible.
  ///
  /// In en, this message translates to:
  /// **'Point NeoAgent at any OpenAI-compatible Chat Completions '**
  String get pointNeoagentAtAnyOpenaiCompatible;

  /// No description provided for @pointTheCameraAtTheCode.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the code shown on the signed-out device. Approval stays on this phone.'**
  String get pointTheCameraAtTheCode;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @portNodeEnvPublicUrlTrust.
  ///
  /// In en, this message translates to:
  /// **'port node_env public url trust proxy secure cookies deployment'**
  String get portNodeEnvPublicUrlTrust;

  /// No description provided for @premiumAutomationWithScheduleAndIntegration.
  ///
  /// In en, this message translates to:
  /// **'Premium automation with schedule and integration triggers.'**
  String get premiumAutomationWithScheduleAndIntegration;

  /// No description provided for @prepareMyMorningBriefingTodayS.
  ///
  /// In en, this message translates to:
  /// **'Prepare my morning briefing: today\'\'s weather where I am, the events '**
  String get prepareMyMorningBriefingTodayS;

  /// No description provided for @prepareQrCode.
  ///
  /// In en, this message translates to:
  /// **'Prepare QR code'**
  String get prepareQrCode;

  /// No description provided for @preparingNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Preparing NeoAgent…'**
  String get preparingNeoagent;

  /// No description provided for @preparingNeoagent2.
  ///
  /// In en, this message translates to:
  /// **'Preparing NeoAgent'**
  String get preparingNeoagent2;

  /// No description provided for @pressAndHoldForQuickCapture.
  ///
  /// In en, this message translates to:
  /// **'Press and hold for quick capture'**
  String get pressAndHoldForQuickCapture;

  /// No description provided for @pressKeysIsNotSupportedOn.
  ///
  /// In en, this message translates to:
  /// **'press keys is not supported on this platform.'**
  String get pressKeysIsNotSupportedOn;

  /// No description provided for @pressedArg1.
  ///
  /// In en, this message translates to:
  /// **'Pressed {arg1}'**
  String pressedArg1(Object? arg1);

  /// No description provided for @previousEvent.
  ///
  /// In en, this message translates to:
  /// **'Previous event'**
  String get previousEvent;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @priceInCents.
  ///
  /// In en, this message translates to:
  /// **'Price in cents'**
  String get priceInCents;

  /// No description provided for @priceMustBeAWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Price must be a whole number of cents (0 or more).'**
  String get priceMustBeAWholeNumber;

  /// No description provided for @priceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Price unknown'**
  String get priceUnknown;

  /// No description provided for @pricingPriceSubscriptionTiersCreateEdit.
  ///
  /// In en, this message translates to:
  /// **'pricing price subscription tiers create edit'**
  String get pricingPriceSubscriptionTiersCreateEdit;

  /// No description provided for @primaryDisplay.
  ///
  /// In en, this message translates to:
  /// **'Primary Display'**
  String get primaryDisplay;

  /// No description provided for @privateAndIsolated.
  ///
  /// In en, this message translates to:
  /// **'Private and isolated'**
  String get privateAndIsolated;

  /// No description provided for @privateChat.
  ///
  /// In en, this message translates to:
  /// **'Private chat'**
  String get privateChat;

  /// No description provided for @privateChats.
  ///
  /// In en, this message translates to:
  /// **'Private chats'**
  String get privateChats;

  /// No description provided for @privateChats2.
  ///
  /// In en, this message translates to:
  /// **'private chats'**
  String get privateChats2;

  /// No description provided for @privateChatsArg1.
  ///
  /// In en, this message translates to:
  /// **'Private chats: {arg1}'**
  String privateChatsArg1(Object? arg1);

  /// No description provided for @privateChatsArg1GroupsArg2.
  ///
  /// In en, this message translates to:
  /// **'Private chats {arg1} · groups {arg2}'**
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2);

  /// No description provided for @privateChatsOnly.
  ///
  /// In en, this message translates to:
  /// **'Private chats only'**
  String get privateChatsOnly;

  /// No description provided for @privateNetworkAddressesArenTAllowed.
  ///
  /// In en, this message translates to:
  /// **'private network addresses aren\'\'t allowed.'**
  String get privateNetworkAddressesArenTAllowed;

  /// No description provided for @profileEmailAndPersonalData.
  ///
  /// In en, this message translates to:
  /// **'Profile, email, and personal data'**
  String get profileEmailAndPersonalData;

  /// No description provided for @promptBeforeNeoagentStaysResidentIn.
  ///
  /// In en, this message translates to:
  /// **'Prompt before NeoAgent stays resident in the system tray.'**
  String get promptBeforeNeoagentStaysResidentIn;

  /// No description provided for @promptCacheArg1CachedTokens.
  ///
  /// In en, this message translates to:
  /// **'Prompt cache: {arg1} cached tokens '**
  String promptCacheArg1CachedTokens(Object? arg1);

  /// No description provided for @promptCopied.
  ///
  /// In en, this message translates to:
  /// **'Prompt copied.'**
  String get promptCopied;

  /// No description provided for @promptOrSchedule.
  ///
  /// In en, this message translates to:
  /// **'prompt or schedule.'**
  String get promptOrSchedule;

  /// No description provided for @promptToPasteIntoAnotherAi.
  ///
  /// In en, this message translates to:
  /// **'Prompt to paste into another AI'**
  String get promptToPasteIntoAnotherAi;

  /// No description provided for @providerLinkingCouldNotBeStarted.
  ///
  /// In en, this message translates to:
  /// **'Provider linking could not be started.'**
  String get providerLinkingCouldNotBeStarted;

  /// No description provided for @providerSignInCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'Provider sign-in could not be started.'**
  String get providerSignInCouldNotBe;

  /// No description provided for @providers.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get providers;

  /// No description provided for @providersEachAccountCanStillPick.
  ///
  /// In en, this message translates to:
  /// **'Providers; each account can still pick its own model in Settings. '**
  String get providersEachAccountCanStillPick;

  /// No description provided for @providersIntegrationsVoiceAndOptionalCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Providers, integrations, voice, and optional capabilities can be completed from Settings at any time.'**
  String get providersIntegrationsVoiceAndOptionalCapabilities;

  /// No description provided for @publicIssueAndPullRequestThreads.
  ///
  /// In en, this message translates to:
  /// **'Public issue and pull request threads, answered only for approved people.'**
  String get publicIssueAndPullRequestThreads;

  /// No description provided for @publicUrl.
  ///
  /// In en, this message translates to:
  /// **'Public URL'**
  String get publicUrl;

  /// No description provided for @publicUrlAndAllowedOrigins.
  ///
  /// In en, this message translates to:
  /// **'Public URL and allowed origins'**
  String get publicUrlAndAllowedOrigins;

  /// No description provided for @publicUrlApiBillingWebhookAnd.
  ///
  /// In en, this message translates to:
  /// **'<public URL>/api/billing/webhook and paste its signing secret '**
  String get publicUrlApiBillingWebhookAnd;

  /// No description provided for @publicUrlOverride.
  ///
  /// In en, this message translates to:
  /// **'Public URL override'**
  String get publicUrlOverride;

  /// No description provided for @publishableKey.
  ///
  /// In en, this message translates to:
  /// **'Publishable key'**
  String get publishableKey;

  /// No description provided for @pullsTogetherTheDayAhead.
  ///
  /// In en, this message translates to:
  /// **'Pulls together the day ahead'**
  String get pullsTogetherTheDayAhead;

  /// No description provided for @pushToTalk.
  ///
  /// In en, this message translates to:
  /// **'Push-to-talk'**
  String get pushToTalk;

  /// No description provided for @qrBasedPhoneLinking.
  ///
  /// In en, this message translates to:
  /// **'QR-based phone linking'**
  String get qrBasedPhoneLinking;

  /// No description provided for @qrLoginCompletedButNeoagentCould.
  ///
  /// In en, this message translates to:
  /// **'QR login completed, but NeoAgent could not keep the session. Please try again.'**
  String get qrLoginCompletedButNeoagentCould;

  /// No description provided for @qrLoginCouldNotBeStarted.
  ///
  /// In en, this message translates to:
  /// **'QR login could not be started.'**
  String get qrLoginCouldNotBeStarted;

  /// No description provided for @qrLoginRequestHasExpired.
  ///
  /// In en, this message translates to:
  /// **'qr login request has expired'**
  String get qrLoginRequestHasExpired;

  /// No description provided for @qrLoginRequestWasNotFound.
  ///
  /// In en, this message translates to:
  /// **'qr login request was not found'**
  String get qrLoginRequestWasNotFound;

  /// No description provided for @qrPairing.
  ///
  /// In en, this message translates to:
  /// **'QR Pairing'**
  String get qrPairing;

  /// No description provided for @queriesRunAnythingThatWritesIs.
  ///
  /// In en, this message translates to:
  /// **'queries run; anything that writes is rejected.'**
  String get queriesRunAnythingThatWritesIs;

  /// No description provided for @query.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get query;

  /// No description provided for @queryFilter.
  ///
  /// In en, this message translates to:
  /// **'Query / Filter'**
  String get queryFilter;

  /// No description provided for @queuedAsSteeringForTheCurrent.
  ///
  /// In en, this message translates to:
  /// **'Queued as steering for the current run: {arg1}'**
  String queuedAsSteeringForTheCurrent(Object? arg1);

  /// No description provided for @quickstart.
  ///
  /// In en, this message translates to:
  /// **'Quickstart'**
  String get quickstart;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @rErrorRCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'       r.error, r.created_at\n'**
  String get rErrorRCreatedAt;

  /// No description provided for @rainStartWindAlert.
  ///
  /// In en, this message translates to:
  /// **'rain_start, wind_alert'**
  String get rainStartWindAlert;

  /// No description provided for @ranAScriptInThePage.
  ///
  /// In en, this message translates to:
  /// **'Ran a script in the page'**
  String get ranAScriptInThePage;

  /// No description provided for @ranArg1.
  ///
  /// In en, this message translates to:
  /// **'Ran {arg1}'**
  String ranArg1(Object? arg1);

  /// No description provided for @rankingGroupChatTurnTakingResearch.
  ///
  /// In en, this message translates to:
  /// **'ranking, group-chat turn-taking, research sources, answer checks, '**
  String get rankingGroupChatTurnTakingResearch;

  /// No description provided for @rateLimits.
  ///
  /// In en, this message translates to:
  /// **'Rate limits'**
  String get rateLimits;

  /// No description provided for @readAnArtifact.
  ///
  /// In en, this message translates to:
  /// **'Read an artifact'**
  String get readAnArtifact;

  /// No description provided for @readAndEditFilesInsideYour.
  ///
  /// In en, this message translates to:
  /// **'Read and edit files inside your NeoAgent Workspace folder.'**
  String get readAndEditFilesInsideYour;

  /// No description provided for @readArg1.
  ///
  /// In en, this message translates to:
  /// **'Read {arg1}'**
  String readArg1(Object? arg1);

  /// No description provided for @readError.
  ///
  /// In en, this message translates to:
  /// **'Read error'**
  String get readError;

  /// No description provided for @readFiles.
  ///
  /// In en, this message translates to:
  /// **'Read files'**
  String get readFiles;

  /// No description provided for @readOnly.
  ///
  /// In en, this message translates to:
  /// **'Read Only'**
  String get readOnly;

  /// No description provided for @readTheFolderAndSummarizeThe.
  ///
  /// In en, this message translates to:
  /// **'Read the folder and summarize the stack, entry points and how to run it.'**
  String get readTheFolderAndSummarizeThe;

  /// No description provided for @readThePage.
  ///
  /// In en, this message translates to:
  /// **'Read the page'**
  String get readThePage;

  /// No description provided for @readTheUiTree.
  ///
  /// In en, this message translates to:
  /// **'Read the UI tree'**
  String get readTheUiTree;

  /// No description provided for @readWrite.
  ///
  /// In en, this message translates to:
  /// **'Read / Write'**
  String get readWrite;

  /// No description provided for @readsStepsHeartRateSleepExercise.
  ///
  /// In en, this message translates to:
  /// **'Reads steps, heart rate, sleep, exercise, and weight.'**
  String get readsStepsHeartRateSleepExercise;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @readyForFirstTimeSetup.
  ///
  /// In en, this message translates to:
  /// **'Ready for first-time setup'**
  String get readyForFirstTimeSetup;

  /// No description provided for @readyToConnect.
  ///
  /// In en, this message translates to:
  /// **'Ready to connect'**
  String get readyToConnect;

  /// No description provided for @realWorkInsteadOfJustTalking.
  ///
  /// In en, this message translates to:
  /// **'real work instead of just talking about it.'**
  String get realWorkInsteadOfJustTalking;

  /// No description provided for @recapMyDaySummarizeTheConversations.
  ///
  /// In en, this message translates to:
  /// **'Recap my day: summarize the conversations, finished work and '**
  String get recapMyDaySummarizeTheConversations;

  /// No description provided for @recentChannelActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Channel Activity'**
  String get recentChannelActivity;

  /// No description provided for @recentChats.
  ///
  /// In en, this message translates to:
  /// **'Recent chats'**
  String get recentChats;

  /// No description provided for @recentDecisions.
  ///
  /// In en, this message translates to:
  /// **'Recent decisions'**
  String get recentDecisions;

  /// No description provided for @recentFailedRuns.
  ///
  /// In en, this message translates to:
  /// **'Recent failed runs'**
  String get recentFailedRuns;

  /// No description provided for @recentGroupDecisions.
  ///
  /// In en, this message translates to:
  /// **'Recent group decisions'**
  String get recentGroupDecisions;

  /// No description provided for @recentRuns.
  ///
  /// In en, this message translates to:
  /// **'Recent runs'**
  String get recentRuns;

  /// No description provided for @recentRunsTakeAboutArg1.
  ///
  /// In en, this message translates to:
  /// **'Recent runs take about {arg1}, '**
  String recentRunsTakeAboutArg1(Object? arg1);

  /// No description provided for @recentServerOutputNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Recent server output, newest first.'**
  String get recentServerOutputNewestFirst;

  /// No description provided for @recentUsage4Hours.
  ///
  /// In en, this message translates to:
  /// **'Recent Usage (4 Hours)'**
  String get recentUsage4Hours;

  /// No description provided for @recents.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get recents;

  /// No description provided for @recipientField.
  ///
  /// In en, this message translates to:
  /// **'Recipient field'**
  String get recipientField;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED'**
  String get recommended;

  /// No description provided for @reconnectOrFinishSetup.
  ///
  /// In en, this message translates to:
  /// **'Reconnect or finish setup'**
  String get reconnectOrFinishSetup;

  /// No description provided for @reconnectingThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting this device…'**
  String get reconnectingThisDevice;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @redirectUri.
  ///
  /// In en, this message translates to:
  /// **'Redirect URI'**
  String get redirectUri;

  /// No description provided for @redoOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Redo onboarding'**
  String get redoOnboarding;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshCode.
  ///
  /// In en, this message translates to:
  /// **'Refresh code'**
  String get refreshCode;

  /// No description provided for @refreshNow.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get refreshNow;

  /// No description provided for @refreshTheAndroidScreenToTry.
  ///
  /// In en, this message translates to:
  /// **'Refresh the Android screen to try again.'**
  String get refreshTheAndroidScreenToTry;

  /// No description provided for @refuseToSendUnlessTheConnection.
  ///
  /// In en, this message translates to:
  /// **'Refuse to send unless the connection upgrades to TLS.'**
  String get refuseToSendUnlessTheConnection;

  /// No description provided for @regardlessOfPerCategorySettingsBelow.
  ///
  /// In en, this message translates to:
  /// **'regardless of per-category settings below.'**
  String get regardlessOfPerCategorySettingsBelow;

  /// No description provided for @registerArg1ForTheAssistantSummon.
  ///
  /// In en, this message translates to:
  /// **'Register {arg1} for the assistant summon flow.'**
  String registerArg1ForTheAssistantSummon(Object? arg1);

  /// No description provided for @registrationIsClosed.
  ///
  /// In en, this message translates to:
  /// **'registration is closed'**
  String get registrationIsClosed;

  /// No description provided for @registrationRegisterNewAccountsAllowSignup.
  ///
  /// In en, this message translates to:
  /// **'registration register new accounts allow signup'**
  String get registrationRegisterNewAccountsAllowSignup;

  /// No description provided for @rejectInvalidTlsCertificates.
  ///
  /// In en, this message translates to:
  /// **'Reject invalid TLS certificates'**
  String get rejectInvalidTlsCertificates;

  /// No description provided for @relationArg1.
  ///
  /// In en, this message translates to:
  /// **'Relation: {arg1}'**
  String relationArg1(Object? arg1);

  /// No description provided for @releaseAndRestartsConnectedAppsReconnect.
  ///
  /// In en, this message translates to:
  /// **'release and restarts. Connected apps reconnect once it is back.'**
  String get releaseAndRestartsConnectedAppsReconnect;

  /// No description provided for @releaseChannel.
  ///
  /// In en, this message translates to:
  /// **'Release channel'**
  String get releaseChannel;

  /// No description provided for @releaseCommitBranchNode.
  ///
  /// In en, this message translates to:
  /// **'release commit branch node'**
  String get releaseCommitBranchNode;

  /// No description provided for @releaseWhenYouAreDone.
  ///
  /// In en, this message translates to:
  /// **'Release when you are done.'**
  String get releaseWhenYouAreDone;

  /// No description provided for @reloadNow.
  ///
  /// In en, this message translates to:
  /// **'Reload now'**
  String get reloadNow;

  /// No description provided for @rememberThisChoice.
  ///
  /// In en, this message translates to:
  /// **'Remember this choice'**
  String get rememberThisChoice;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeArg1AndItsRecordedSteps.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{arg1}\" and its recorded steps from the run history?'**
  String removeArg1AndItsRecordedSteps(Object? arg1);

  /// No description provided for @removeArg1FromCoreMemory.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{arg1}\" from core memory.'**
  String removeArg1FromCoreMemory(Object? arg1);

  /// No description provided for @removeArg1Key.
  ///
  /// In en, this message translates to:
  /// **'Remove {arg1} key?'**
  String removeArg1Key(Object? arg1);

  /// No description provided for @removeEraseGdprUser.
  ///
  /// In en, this message translates to:
  /// **'remove erase gdpr user'**
  String get removeEraseGdprUser;

  /// No description provided for @removeSmtpPassword.
  ///
  /// In en, this message translates to:
  /// **'Remove SMTP password'**
  String get removeSmtpPassword;

  /// No description provided for @removeTheSmtpPassword.
  ///
  /// In en, this message translates to:
  /// **'Remove the SMTP password?'**
  String get removeTheSmtpPassword;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameSecurityKey.
  ///
  /// In en, this message translates to:
  /// **'Rename security key'**
  String get renameSecurityKey;

  /// No description provided for @renameSession.
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get renameSession;

  /// No description provided for @repairAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Repair and retry'**
  String get repairAndRetry;

  /// No description provided for @repairDesktop.
  ///
  /// In en, this message translates to:
  /// **'Repair desktop'**
  String get repairDesktop;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @repliesWhenTagged.
  ///
  /// In en, this message translates to:
  /// **'Replies when tagged'**
  String get repliesWhenTagged;

  /// No description provided for @replyToAddress.
  ///
  /// In en, this message translates to:
  /// **'Reply-To address'**
  String get replyToAddress;

  /// No description provided for @replyToArg1.
  ///
  /// In en, this message translates to:
  /// **'Reply to {arg1}'**
  String replyToArg1(Object? arg1);

  /// No description provided for @repositoryMustBeInTheFormat.
  ///
  /// In en, this message translates to:
  /// **'Repository must be in the format owner/repo.'**
  String get repositoryMustBeInTheFormat;

  /// No description provided for @reproduceTheBugIDescribeFind.
  ///
  /// In en, this message translates to:
  /// **'Reproduce the bug I describe, find the root cause and fix it with a regression test.'**
  String get reproduceTheBugIDescribeFind;

  /// No description provided for @requestFailedWithHttpArg1.
  ///
  /// In en, this message translates to:
  /// **'request failed with http {arg1}'**
  String requestFailedWithHttpArg1(Object? arg1);

  /// No description provided for @requestFailedWithHttpArg12.
  ///
  /// In en, this message translates to:
  /// **'Request failed with HTTP {arg1}'**
  String requestFailedWithHttpArg12(Object? arg1);

  /// No description provided for @requestPermissions.
  ///
  /// In en, this message translates to:
  /// **'Request permissions'**
  String get requestPermissions;

  /// No description provided for @requestToArg1FailedBeforeThe.
  ///
  /// In en, this message translates to:
  /// **'Request to {arg1} failed before the backend responded.'**
  String requestToArg1FailedBeforeThe(Object? arg1);

  /// No description provided for @requestedArg1.
  ///
  /// In en, this message translates to:
  /// **'Requested {arg1}'**
  String requestedArg1(Object? arg1);

  /// No description provided for @requireStarttls.
  ///
  /// In en, this message translates to:
  /// **'Require STARTTLS'**
  String get requireStarttls;

  /// No description provided for @requiredBehindHttpsOrATls.
  ///
  /// In en, this message translates to:
  /// **'Required behind HTTPS or a TLS proxy. Applies after a server '**
  String get requiredBehindHttpsOrATls;

  /// No description provided for @requiredExampleBerlinDe.
  ///
  /// In en, this message translates to:
  /// **'Required. Example: Berlin, DE'**
  String get requiredExampleBerlinDe;

  /// No description provided for @requiredFormatOwnerRepo.
  ///
  /// In en, this message translates to:
  /// **'Required. Format: owner/repo'**
  String get requiredFormatOwnerRepo;

  /// No description provided for @reserveAssistantHotkey.
  ///
  /// In en, this message translates to:
  /// **'Reserve assistant hotkey'**
  String get reserveAssistantHotkey;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @resetView.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get resetView;

  /// No description provided for @resetsArg1.
  ///
  /// In en, this message translates to:
  /// **'Resets {arg1}'**
  String resetsArg1(Object? arg1);

  /// No description provided for @responsibilities.
  ///
  /// In en, this message translates to:
  /// **'Responsibilities'**
  String get responsibilities;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @restartToFinishTheUpdate.
  ///
  /// In en, this message translates to:
  /// **' Restart to finish the update.'**
  String get restartToFinishTheUpdate;

  /// No description provided for @restoringThePreviousNeoagentRuntime.
  ///
  /// In en, this message translates to:
  /// **'Restoring the previous NeoAgent runtime'**
  String get restoringThePreviousNeoagentRuntime;

  /// No description provided for @restrictDelegationTargets.
  ///
  /// In en, this message translates to:
  /// **'Restrict delegation targets'**
  String get restrictDelegationTargets;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

  /// No description provided for @resultDelivery.
  ///
  /// In en, this message translates to:
  /// **'Result Delivery'**
  String get resultDelivery;

  /// No description provided for @resultOneClickAddsOneYou.
  ///
  /// In en, this message translates to:
  /// **'result. One click adds one; you can edit it later.'**
  String get resultOneClickAddsOneYou;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @retrievalInspector.
  ///
  /// In en, this message translates to:
  /// **'Retrieval Inspector'**
  String get retrievalInspector;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @reusableUsedArg1.
  ///
  /// In en, this message translates to:
  /// **'Reusable · used {arg1}×'**
  String reusableUsedArg1(Object? arg1);

  /// No description provided for @reviewMyWeekWhatGotDone.
  ///
  /// In en, this message translates to:
  /// **'Review my week: what got done, what slipped and what is still open. '**
  String get reviewMyWeekWhatGotDone;

  /// No description provided for @reviewUncommittedChanges.
  ///
  /// In en, this message translates to:
  /// **'Review uncommitted changes'**
  String get reviewUncommittedChanges;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @revokeAdminWithNeoagentAdminRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke admin with `neoagent admin revoke {arg1}` first'**
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1);

  /// No description provided for @revokeThisLink.
  ///
  /// In en, this message translates to:
  /// **'Revoke this link?'**
  String get revokeThisLink;

  /// No description provided for @roomBatchWindowArg1Ms.
  ///
  /// In en, this message translates to:
  /// **'Room batch window: {arg1} ms'**
  String roomBatchWindowArg1Ms(Object? arg1);

  /// No description provided for @rotateToContinue.
  ///
  /// In en, this message translates to:
  /// **'Rotate to continue'**
  String get rotateToContinue;

  /// No description provided for @roundSumAByteSize1048576.
  ///
  /// In en, this message translates to:
  /// **'       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n'**
  String get roundSumAByteSize1048576;

  /// No description provided for @rowsAddALimitOrA.
  ///
  /// In en, this message translates to:
  /// **'rows. Add a LIMIT or a narrower WHERE clause to see '**
  String get rowsAddALimitOrA;

  /// No description provided for @rule.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get rule;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @run2.
  ///
  /// In en, this message translates to:
  /// **'RUN'**
  String get run2;

  /// No description provided for @runArbitraryCommandsOnYourMachine.
  ///
  /// In en, this message translates to:
  /// **'Run arbitrary commands on your machine or VM.'**
  String get runArbitraryCommandsOnYourMachine;

  /// No description provided for @runAt.
  ///
  /// In en, this message translates to:
  /// **'Run At'**
  String get runAt;

  /// No description provided for @runCompleted.
  ///
  /// In en, this message translates to:
  /// **'Run completed'**
  String get runCompleted;

  /// No description provided for @runFailed.
  ///
  /// In en, this message translates to:
  /// **'Run failed'**
  String get runFailed;

  /// No description provided for @runGitDiffReviewTheUncommitted.
  ///
  /// In en, this message translates to:
  /// **'Run git diff, review the uncommitted changes for bugs and style issues, and summarize what you find.'**
  String get runGitDiffReviewTheUncommitted;

  /// No description provided for @runLink.
  ///
  /// In en, this message translates to:
  /// **'RUN LINK'**
  String get runLink;

  /// No description provided for @runLinked.
  ///
  /// In en, this message translates to:
  /// **'Run linked'**
  String get runLinked;

  /// No description provided for @runNotFound.
  ///
  /// In en, this message translates to:
  /// **'Run not found'**
  String get runNotFound;

  /// No description provided for @runNow.
  ///
  /// In en, this message translates to:
  /// **'Run Now'**
  String get runNow;

  /// No description provided for @runOnInboundPersonalWhatsappMessages.
  ///
  /// In en, this message translates to:
  /// **'Run on inbound personal WhatsApp messages.'**
  String get runOnInboundPersonalWhatsappMessages;

  /// No description provided for @runQuery.
  ///
  /// In en, this message translates to:
  /// **'Run query'**
  String get runQuery;

  /// No description provided for @runShellCommandsOrInstallApps.
  ///
  /// In en, this message translates to:
  /// **'Run shell commands or install apps on your Android device.'**
  String get runShellCommandsOrInstallApps;

  /// No description provided for @runStarted.
  ///
  /// In en, this message translates to:
  /// **'Run started'**
  String get runStarted;

  /// No description provided for @runStatus.
  ///
  /// In en, this message translates to:
  /// **'Run status'**
  String get runStatus;

  /// No description provided for @runStopped.
  ///
  /// In en, this message translates to:
  /// **'Run stopped'**
  String get runStopped;

  /// No description provided for @runTerminalCommandsAndOpenApps.
  ///
  /// In en, this message translates to:
  /// **'Run terminal commands and open apps or web pages.'**
  String get runTerminalCommandsAndOpenApps;

  /// No description provided for @runThisServerAccountsUpdatesProviders.
  ///
  /// In en, this message translates to:
  /// **'Run this server: accounts, updates, providers, configuration '**
  String get runThisServerAccountsUpdatesProviders;

  /// No description provided for @runWhenAMatchingGmailMessage.
  ///
  /// In en, this message translates to:
  /// **'Run when a matching Gmail message arrives.'**
  String get runWhenAMatchingGmailMessage;

  /// No description provided for @runWhenAMatchingOutlookEmail.
  ///
  /// In en, this message translates to:
  /// **'Run when a matching Outlook email arrives.'**
  String get runWhenAMatchingOutlookEmail;

  /// No description provided for @runWhenANewIssueMatching.
  ///
  /// In en, this message translates to:
  /// **'Run when a new issue matching your filters is opened in a repository.'**
  String get runWhenANewIssueMatching;

  /// No description provided for @runWhenANotificationArrivesOn.
  ///
  /// In en, this message translates to:
  /// **'Run when a notification arrives on your device.'**
  String get runWhenANotificationArrivesOn;

  /// No description provided for @runWhenASlackMessageMatches.
  ///
  /// In en, this message translates to:
  /// **'Run when a Slack message matches the selected scope.'**
  String get runWhenASlackMessageMatches;

  /// No description provided for @runWhenATeamsChatMessage.
  ///
  /// In en, this message translates to:
  /// **'Run when a Teams chat message matches the selected scope.'**
  String get runWhenATeamsChatMessage;

  /// No description provided for @runWhenConfiguredWeatherEventsAre.
  ///
  /// In en, this message translates to:
  /// **'Run when configured weather events are forecast for a location.'**
  String get runWhenConfiguredWeatherEventsAre;

  /// No description provided for @runWhileAnyModelIsSwitched.
  ///
  /// In en, this message translates to:
  /// **'run. While any model is switched off, models that providers add '**
  String get runWhileAnyModelIsSwitched;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @runningArg1.
  ///
  /// In en, this message translates to:
  /// **'Running {arg1}'**
  String runningArg1(Object? arg1);

  /// No description provided for @runningTask.
  ///
  /// In en, this message translates to:
  /// **'Running task'**
  String get runningTask;

  /// No description provided for @runningTool.
  ///
  /// In en, this message translates to:
  /// **'Running tool'**
  String get runningTool;

  /// No description provided for @runs.
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get runs;

  /// No description provided for @runsCommandsBrowsesTheWebAnd.
  ///
  /// In en, this message translates to:
  /// **'Runs commands, browses the web and edits files on a real Linux '**
  String get runsCommandsBrowsesTheWebAnd;

  /// No description provided for @runsEveryDayAtTheSelected.
  ///
  /// In en, this message translates to:
  /// **'Runs every day at the selected time.'**
  String get runsEveryDayAtTheSelected;

  /// No description provided for @runsFourTimesPerHour.
  ///
  /// In en, this message translates to:
  /// **'Runs four times per hour.'**
  String get runsFourTimesPerHour;

  /// No description provided for @runsMessagesMemoriesIntegrationsFilesAnd.
  ///
  /// In en, this message translates to:
  /// **'— runs, messages, memories, integrations, files and '**
  String get runsMessagesMemoriesIntegrationsFilesAnd;

  /// No description provided for @runsMessagesMemoriesIntegrationsFilesAnd2.
  ///
  /// In en, this message translates to:
  /// **'runs, messages, memories, integrations, files and sessions. '**
  String get runsMessagesMemoriesIntegrationsFilesAnd2;

  /// No description provided for @runsMondayThroughFriday.
  ///
  /// In en, this message translates to:
  /// **'Runs Monday through Friday.'**
  String get runsMondayThroughFriday;

  /// No description provided for @runsOnSelectedWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Runs on selected weekdays.'**
  String get runsOnSelectedWeekdays;

  /// No description provided for @runsOncePerHour.
  ///
  /// In en, this message translates to:
  /// **'Runs once per hour.'**
  String get runsOncePerHour;

  /// No description provided for @runsOncePerMonthOnThe.
  ///
  /// In en, this message translates to:
  /// **'Runs once per month on the selected day.'**
  String get runsOncePerMonthOnThe;

  /// No description provided for @runsOnlyWhenYouPressRun.
  ///
  /// In en, this message translates to:
  /// **'Runs only when you press Run Now.'**
  String get runsOnlyWhenYouPressRun;

  /// No description provided for @runsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Runs per day'**
  String get runsPerDay;

  /// No description provided for @runsPerDay30Days.
  ///
  /// In en, this message translates to:
  /// **'Runs per day (30 days)'**
  String get runsPerDay30Days;

  /// No description provided for @runsThatCompleted.
  ///
  /// In en, this message translates to:
  /// **'Runs that completed'**
  String get runsThatCompleted;

  /// No description provided for @runsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Runs this week'**
  String get runsThisWeek;

  /// No description provided for @runsToday.
  ///
  /// In en, this message translates to:
  /// **'Runs today'**
  String get runsToday;

  /// No description provided for @runsToolsMemorySchedulingSkillsAnd.
  ///
  /// In en, this message translates to:
  /// **'Runs, tools, memory, scheduling, skills, and MCP are all available here.'**
  String get runsToolsMemorySchedulingSkillsAnd;

  /// No description provided for @runsTwicePerHour.
  ///
  /// In en, this message translates to:
  /// **'Runs twice per hour.'**
  String get runsTwicePerHour;

  /// No description provided for @runsWillFallBackToThe.
  ///
  /// In en, this message translates to:
  /// **'Runs will fall back to the shared server key for {arg1}, if one is configured. This can\'\'t be undone.'**
  String runsWillFallBackToThe(Object? arg1);

  /// No description provided for @runtimeArg1.
  ///
  /// In en, this message translates to:
  /// **'Runtime {arg1}'**
  String runtimeArg1(Object? arg1);

  /// No description provided for @runtimeArg12.
  ///
  /// In en, this message translates to:
  /// **' | Runtime: {arg1}'**
  String runtimeArg12(Object? arg1);

  /// No description provided for @runtimeSettingsThisServerStartedWith.
  ///
  /// In en, this message translates to:
  /// **'Runtime settings this server started with. Edit them under '**
  String get runtimeSettingsThisServerStartedWith;

  /// No description provided for @runtimeSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Runtime setup required'**
  String get runtimeSetupRequired;

  /// No description provided for @runtimeSigningPublicKeyMustBe.
  ///
  /// In en, this message translates to:
  /// **'Runtime signing public key must be 32 bytes.'**
  String get runtimeSigningPublicKeyMustBe;

  /// No description provided for @sUserAgentSCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'       s.user_agent, s.created_at, s.last_seen_at\n'**
  String get sUserAgentSCreatedAt;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveATrelloApiKeyFor.
  ///
  /// In en, this message translates to:
  /// **'Save a Trello API key for this agent, then connect one Trello account securely. The account token is stored on the server and used only for this agent.'**
  String get saveATrelloApiKeyFor;

  /// No description provided for @saveAccount.
  ///
  /// In en, this message translates to:
  /// **'Save account'**
  String get saveAccount;

  /// No description provided for @saveBillingSetup.
  ///
  /// In en, this message translates to:
  /// **'Save billing setup'**
  String get saveBillingSetup;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @saveCloudComputerSettings.
  ///
  /// In en, this message translates to:
  /// **'Save cloud computer settings'**
  String get saveCloudComputerSettings;

  /// No description provided for @saveConnect.
  ///
  /// In en, this message translates to:
  /// **'Save & Connect'**
  String get saveConnect;

  /// No description provided for @saveDefaults.
  ///
  /// In en, this message translates to:
  /// **'Save defaults'**
  String get saveDefaults;

  /// No description provided for @saveDiagnosticReport.
  ///
  /// In en, this message translates to:
  /// **'Save diagnostic report'**
  String get saveDiagnosticReport;

  /// No description provided for @saveEmail.
  ///
  /// In en, this message translates to:
  /// **'Save email'**
  String get saveEmail;

  /// No description provided for @saveEmailSettings.
  ///
  /// In en, this message translates to:
  /// **'Save email settings'**
  String get saveEmailSettings;

  /// No description provided for @saveGeneralSettings.
  ///
  /// In en, this message translates to:
  /// **'Save general settings'**
  String get saveGeneralSettings;

  /// No description provided for @saveName.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get saveName;

  /// No description provided for @saveNeoagentSetupDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Save NeoAgent setup diagnostics'**
  String get saveNeoagentSetupDiagnostics;

  /// No description provided for @saveOnly.
  ///
  /// In en, this message translates to:
  /// **'Save Only'**
  String get saveOnly;

  /// No description provided for @savePlan.
  ///
  /// In en, this message translates to:
  /// **'Save plan'**
  String get savePlan;

  /// No description provided for @saveSetup.
  ///
  /// In en, this message translates to:
  /// **'Save Setup'**
  String get saveSetup;

  /// No description provided for @saveTheseRecoveryCodesNowThey.
  ///
  /// In en, this message translates to:
  /// **'Save these recovery codes now. They will not be shown again.'**
  String get saveTheseRecoveryCodesNowThey;

  /// No description provided for @saveUpToArg1Yearly.
  ///
  /// In en, this message translates to:
  /// **'Save up to {arg1}% yearly'**
  String saveUpToArg1Yearly(Object? arg1);

  /// No description provided for @savedDeliveryDestination.
  ///
  /// In en, this message translates to:
  /// **'Saved delivery destination'**
  String get savedDeliveryDestination;

  /// No description provided for @savedRateLimitsForArg1.
  ///
  /// In en, this message translates to:
  /// **'Saved rate limits for @{arg1}.'**
  String savedRateLimitsForArg1(Object? arg1);

  /// No description provided for @scanANeoagentLoginQr.
  ///
  /// In en, this message translates to:
  /// **'Scan a NeoAgent login QR'**
  String get scanANeoagentLoginQr;

  /// No description provided for @scanANeoagentPairingQrFrom.
  ///
  /// In en, this message translates to:
  /// **'Scan a NeoAgent pairing QR from another device and approve it from this launcher session.'**
  String get scanANeoagentPairingQrFrom;

  /// No description provided for @scanLoginQr.
  ///
  /// In en, this message translates to:
  /// **'Scan login QR'**
  String get scanLoginQr;

  /// No description provided for @scanPairingQr.
  ///
  /// In en, this message translates to:
  /// **'Scan pairing QR'**
  String get scanPairingQr;

  /// No description provided for @scanQrLoginRequestsFromSigned.
  ///
  /// In en, this message translates to:
  /// **'Scan QR login requests from signed-out devices and approve them from this authenticated mobile session.'**
  String get scanQrLoginRequestsFromSigned;

  /// No description provided for @scanToFinishArg1.
  ///
  /// In en, this message translates to:
  /// **'Scan to finish {arg1}'**
  String scanToFinishArg1(Object? arg1);

  /// No description provided for @scanWithNeoagentOnYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Scan with NeoAgent on your phone'**
  String get scanWithNeoagentOnYourPhone;

  /// No description provided for @scansNewEmailAndOnlyPings.
  ///
  /// In en, this message translates to:
  /// **'Scans new email and only pings you when something matters.'**
  String get scansNewEmailAndOnlyPings;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @scheduledTimeOnceRunsAreMeasured.
  ///
  /// In en, this message translates to:
  /// **'scheduled time. Once runs are measured it will start earlier.'**
  String get scheduledTimeOnceRunsAreMeasured;

  /// No description provided for @scoreArg1.
  ///
  /// In en, this message translates to:
  /// **'Score: {arg1}'**
  String scoreArg1(Object? arg1);

  /// No description provided for @screen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get screen;

  /// No description provided for @screenAction.
  ///
  /// In en, this message translates to:
  /// **'screen action'**
  String get screenAction;

  /// No description provided for @scrollIsNotSupportedOnThis.
  ///
  /// In en, this message translates to:
  /// **'scroll is not supported on this platform.'**
  String get scrollIsNotSupportedOnThis;

  /// No description provided for @scrollToBottom.
  ///
  /// In en, this message translates to:
  /// **'Scroll to bottom'**
  String get scrollToBottom;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @search2.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get search2;

  /// No description provided for @searchAdminSettingsEGStripe.
  ///
  /// In en, this message translates to:
  /// **'Search admin settings (e.g. Stripe, SMTP, Ollama, logs)'**
  String get searchAdminSettingsEGStripe;

  /// No description provided for @searchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get searchAgain;

  /// No description provided for @searchByUsernameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search by username or email'**
  String get searchByUsernameOrEmail;

  /// No description provided for @searchChannels.
  ///
  /// In en, this message translates to:
  /// **'Search channels'**
  String get searchChannels;

  /// No description provided for @searchDiscoveredMessagingChannelsContactsGroups.
  ///
  /// In en, this message translates to:
  /// **'Search discovered messaging channels, contacts, groups, and recent conversations.'**
  String get searchDiscoveredMessagingChannelsContactsGroups;

  /// No description provided for @searchGroups.
  ///
  /// In en, this message translates to:
  /// **'Search groups'**
  String get searchGroups;

  /// No description provided for @searchMemory.
  ///
  /// In en, this message translates to:
  /// **'Search memory'**
  String get searchMemory;

  /// No description provided for @searchModels.
  ///
  /// In en, this message translates to:
  /// **'Search models'**
  String get searchModels;

  /// No description provided for @searchModelsOrProviders.
  ///
  /// In en, this message translates to:
  /// **'Search models or providers'**
  String get searchModelsOrProviders;

  /// No description provided for @searchModelsOrProviders2.
  ///
  /// In en, this message translates to:
  /// **'Search models or providers…'**
  String get searchModelsOrProviders2;

  /// No description provided for @searchRecentPeopleAndGroups.
  ///
  /// In en, this message translates to:
  /// **'Search recent people and groups'**
  String get searchRecentPeopleAndGroups;

  /// No description provided for @searchSessions.
  ///
  /// In en, this message translates to:
  /// **'Search sessions'**
  String get searchSessions;

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get searchSettings;

  /// No description provided for @searchTheWebForTodayS.
  ///
  /// In en, this message translates to:
  /// **'Search the web for today\'\'s most important news on the topics I care '**
  String get searchTheWebForTodayS;

  /// No description provided for @searchTitleModelTriggerRunId.
  ///
  /// In en, this message translates to:
  /// **'Search title, model, trigger, run ID'**
  String get searchTitleModelTriggerRunId;

  /// No description provided for @searchToolsIntegrationsAndSkills.
  ///
  /// In en, this message translates to:
  /// **'Search tools, integrations, and skills'**
  String get searchToolsIntegrationsAndSkills;

  /// No description provided for @searchedCodeForArg1.
  ///
  /// In en, this message translates to:
  /// **'Searched code for \"{arg1}\"'**
  String searchedCodeForArg1(Object? arg1);

  /// No description provided for @searchedFilesForArg1.
  ///
  /// In en, this message translates to:
  /// **'Searched files for \"{arg1}\"'**
  String searchedFilesForArg1(Object? arg1);

  /// No description provided for @secondRoutingToolAndSkillChoice.
  ///
  /// In en, this message translates to:
  /// **'second: routing, tool and skill choice, memory ranking, '**
  String get secondRoutingToolAndSkillChoice;

  /// No description provided for @secretField.
  ///
  /// In en, this message translates to:
  /// **'Secret field'**
  String get secretField;

  /// No description provided for @secretKey.
  ///
  /// In en, this message translates to:
  /// **'Secret key'**
  String get secretKey;

  /// No description provided for @secureCookies.
  ///
  /// In en, this message translates to:
  /// **'Secure cookies'**
  String get secureCookies;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @securityKey.
  ///
  /// In en, this message translates to:
  /// **'Security key'**
  String get securityKey;

  /// No description provided for @securityKeyPromptWasDismissed.
  ///
  /// In en, this message translates to:
  /// **'Security key prompt was dismissed.'**
  String get securityKeyPromptWasDismissed;

  /// No description provided for @securityKeySignInCompletedBut.
  ///
  /// In en, this message translates to:
  /// **'Security key sign-in completed, but NeoAgent could not keep the browser session. Please sign in again.'**
  String get securityKeySignInCompletedBut;

  /// No description provided for @securityKeySignInCouldNot.
  ///
  /// In en, this message translates to:
  /// **'Security key sign-in could not be started.'**
  String get securityKeySignInCouldNot;

  /// No description provided for @securityKeys.
  ///
  /// In en, this message translates to:
  /// **'Security keys'**
  String get securityKeys;

  /// No description provided for @securityKeysAreOnlyAvailableIn.
  ///
  /// In en, this message translates to:
  /// **'Security keys are only available in the NeoAgent web app.'**
  String get securityKeysAreOnlyAvailableIn;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @seeWhichNeoagentServerThisWindow.
  ///
  /// In en, this message translates to:
  /// **'See which NeoAgent server this window uses, and run the backend on this computer.'**
  String get seeWhichNeoagentServerThisWindow;

  /// No description provided for @seeYourUsernameAndTheseSettings.
  ///
  /// In en, this message translates to:
  /// **'see your username and these settings, never your chats, memories '**
  String get seeYourUsernameAndTheseSettings;

  /// No description provided for @selectARun.
  ///
  /// In en, this message translates to:
  /// **'Select a run'**
  String get selectARun;

  /// No description provided for @selectASessionToSeeIts.
  ///
  /// In en, this message translates to:
  /// **'Select a session to see its computer, files and changes.'**
  String get selectASessionToSeeIts;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @selectAll2.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll2;

  /// No description provided for @selectAnEventFromTheFeed.
  ///
  /// In en, this message translates to:
  /// **'Select an event from the feed.'**
  String get selectAnEventFromTheFeed;

  /// No description provided for @selectArg1.
  ///
  /// In en, this message translates to:
  /// **'Select {arg1}'**
  String selectArg1(Object? arg1);

  /// No description provided for @selectTrigger.
  ///
  /// In en, this message translates to:
  /// **'Select Trigger'**
  String get selectTrigger;

  /// No description provided for @semanticArg1.
  ///
  /// In en, this message translates to:
  /// **'Semantic: {arg1}'**
  String semanticArg1(Object? arg1);

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send (⌘↵)'**
  String get send;

  /// No description provided for @send2.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send2;

  /// No description provided for @sendATaskFromChatAnd.
  ///
  /// In en, this message translates to:
  /// **'Send a task from chat and its execution history will show up here.'**
  String get sendATaskFromChatAnd;

  /// No description provided for @sendItAsAShortScannable.
  ///
  /// In en, this message translates to:
  /// **'Send it as a short, scannable message.'**
  String get sendItAsAShortScannable;

  /// No description provided for @sendItToATeammateWith.
  ///
  /// In en, this message translates to:
  /// **'send it to a teammate with an account on this server.'**
  String get sendItToATeammateWith;

  /// No description provided for @sendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendLink;

  /// No description provided for @sendPath.
  ///
  /// In en, this message translates to:
  /// **'Send path'**
  String get sendPath;

  /// No description provided for @sendPostPutDeleteRequestsTo.
  ///
  /// In en, this message translates to:
  /// **'Send POST / PUT / DELETE requests to external APIs.'**
  String get sendPostPutDeleteRequestsTo;

  /// No description provided for @sendThisLinkOnlyToThe.
  ///
  /// In en, this message translates to:
  /// **'Send this link only to the person it’s meant for. It is shown once; '**
  String get sendThisLinkOnlyToThe;

  /// No description provided for @senderAddress.
  ///
  /// In en, this message translates to:
  /// **'Sender address'**
  String get senderAddress;

  /// No description provided for @senderFilterOptional.
  ///
  /// In en, this message translates to:
  /// **'Sender Filter (optional)'**
  String get senderFilterOptional;

  /// No description provided for @sentSharedAttachments.
  ///
  /// In en, this message translates to:
  /// **'Sent shared attachments.'**
  String get sentSharedAttachments;

  /// No description provided for @separateAccount.
  ///
  /// In en, this message translates to:
  /// **'Separate account'**
  String get separateAccount;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @serverDefaultArg1.
  ///
  /// In en, this message translates to:
  /// **'Server default ({arg1})'**
  String serverDefaultArg1(Object? arg1);

  /// No description provided for @serverDefaultsForInAppVoice.
  ///
  /// In en, this message translates to:
  /// **'Server defaults for in-app voice calls. Calls run on a live '**
  String get serverDefaultsForInAppVoice;

  /// No description provided for @serverItselfAccountsProvidersAndConfiguration.
  ///
  /// In en, this message translates to:
  /// **'server itself: accounts, providers and configuration.'**
  String get serverItselfAccountsProvidersAndConfiguration;

  /// No description provided for @serverNickChannelAndOptionalTls.
  ///
  /// In en, this message translates to:
  /// **'Server, nick, channel, and optional TLS'**
  String get serverNickChannelAndOptionalTls;

  /// No description provided for @serverOutputConsoleWarningsErrorsCopy.
  ///
  /// In en, this message translates to:
  /// **'server output console warnings errors copy'**
  String get serverOutputConsoleWarningsErrorsCopy;

  /// No description provided for @serverProviderCredentials.
  ///
  /// In en, this message translates to:
  /// **'Server provider credentials'**
  String get serverProviderCredentials;

  /// No description provided for @serverToStopIt.
  ///
  /// In en, this message translates to:
  /// **'server to stop it.'**
  String get serverToStopIt;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @serverUsageLimitsDonTApply.
  ///
  /// In en, this message translates to:
  /// **'Server usage limits don\'\'t apply to models running on your own key.'**
  String get serverUsageLimitsDonTApply;

  /// No description provided for @serverWithNoAccountsYetAlways.
  ///
  /// In en, this message translates to:
  /// **'server with no accounts yet always lets the first '**
  String get serverWithNoAccountsYetAlways;

  /// No description provided for @serviceEmail.
  ///
  /// In en, this message translates to:
  /// **'Service email'**
  String get serviceEmail;

  /// No description provided for @serviceEmailIsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'service email is not configured'**
  String get serviceEmailIsNotConfigured;

  /// No description provided for @serviceEmailSmtp.
  ///
  /// In en, this message translates to:
  /// **'Service email (SMTP)'**
  String get serviceEmailSmtp;

  /// No description provided for @sessionActions.
  ///
  /// In en, this message translates to:
  /// **'Session actions'**
  String get sessionActions;

  /// No description provided for @sessionToThisDeviceWhenYou.
  ///
  /// In en, this message translates to:
  /// **'session to This device when you want it to work locally.'**
  String get sessionToThisDeviceWhenYou;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @sessions2.
  ///
  /// In en, this message translates to:
  /// **'SESSIONS'**
  String get sessions2;

  /// No description provided for @sessionsArePinnedToAFolder.
  ///
  /// In en, this message translates to:
  /// **'Sessions are pinned to a folder and a computer. Start one to plan, build, test and ship from here.'**
  String get sessionsArePinnedToAFolder;

  /// No description provided for @sessionsGdprArt17AdminAccounts.
  ///
  /// In en, this message translates to:
  /// **'sessions (GDPR Art. 17). Admin accounts can’t be deleted '**
  String get sessionsGdprArt17AdminAccounts;

  /// No description provided for @sessionsLogoutRevokeForce.
  ///
  /// In en, this message translates to:
  /// **'sessions logout revoke force'**
  String get sessionsLogoutRevokeForce;

  /// No description provided for @setBlockAskAllowPerTool.
  ///
  /// In en, this message translates to:
  /// **'Set block / ask / allow per tool category, or pick a global mode.'**
  String get setBlockAskAllowPerTool;

  /// No description provided for @setUpNeoagentOnThisComputer.
  ///
  /// In en, this message translates to:
  /// **'Set up NeoAgent on this computer'**
  String get setUpNeoagentOnThisComputer;

  /// No description provided for @setUpOrConnectNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Set up or connect NeoAgent'**
  String get setUpOrConnectNeoagent;

  /// No description provided for @setUpYourWorkspaceInA.
  ///
  /// In en, this message translates to:
  /// **'Set up your workspace in a few steps and start using NeoAgent immediately.'**
  String get setUpYourWorkspaceInA;

  /// No description provided for @setUrl.
  ///
  /// In en, this message translates to:
  /// **'Set URL'**
  String get setUrl;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsAndCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'settings and cannot be undone.'**
  String get settingsAndCannotBeUndone;

  /// No description provided for @settingsArea.
  ///
  /// In en, this message translates to:
  /// **'Settings area'**
  String get settingsArea;

  /// No description provided for @settingsAreas.
  ///
  /// In en, this message translates to:
  /// **'Settings areas'**
  String get settingsAreas;

  /// No description provided for @setup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get setup;

  /// No description provided for @setupDetails.
  ///
  /// In en, this message translates to:
  /// **'Setup details'**
  String get setupDetails;

  /// No description provided for @setupRequired.
  ///
  /// In en, this message translates to:
  /// **'Setup Required'**
  String get setupRequired;

  /// No description provided for @setupWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'Setup was cancelled.'**
  String get setupWasCancelled;

  /// No description provided for @sharedAttachmentsFromTheNeoagentClient.
  ///
  /// In en, this message translates to:
  /// **'Shared attachments from the NeoAgent client:'**
  String get sharedAttachmentsFromTheNeoagentClient;

  /// No description provided for @sharedFromAnotherApp.
  ///
  /// In en, this message translates to:
  /// **'Shared from another app'**
  String get sharedFromAnotherApp;

  /// No description provided for @sharedProviderKeysAreConfiguredOn.
  ///
  /// In en, this message translates to:
  /// **'Shared provider keys are configured on the server. To use your own API key or a custom endpoint instead, go to Advanced → Bring your own key.'**
  String get sharedProviderKeysAreConfiguredOn;

  /// No description provided for @sharedWithTheNeoagentChatAnd.
  ///
  /// In en, this message translates to:
  /// **'Shared with the NeoAgent chat and its memory.'**
  String get sharedWithTheNeoagentChatAnd;

  /// No description provided for @sharperToolChoice.
  ///
  /// In en, this message translates to:
  /// **'Sharper tool choice'**
  String get sharperToolChoice;

  /// No description provided for @shellCommands.
  ///
  /// In en, this message translates to:
  /// **'Shell Commands'**
  String get shellCommands;

  /// No description provided for @showAllArg1.
  ///
  /// In en, this message translates to:
  /// **'Show all {arg1}'**
  String showAllArg1(Object? arg1);

  /// No description provided for @showEarlier.
  ///
  /// In en, this message translates to:
  /// **'Show earlier'**
  String get showEarlier;

  /// No description provided for @showEveryStep.
  ///
  /// In en, this message translates to:
  /// **'Show every step'**
  String get showEveryStep;

  /// No description provided for @showTools.
  ///
  /// In en, this message translates to:
  /// **'Show tools'**
  String get showTools;

  /// No description provided for @showWorkbenchJ.
  ///
  /// In en, this message translates to:
  /// **'Show workbench (⌘J)'**
  String get showWorkbenchJ;

  /// No description provided for @showingTheFirstArg1.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {arg1} '**
  String showingTheFirstArg1(Object? arg1);

  /// No description provided for @shownInTheSidebarLeaveBlank.
  ///
  /// In en, this message translates to:
  /// **'Shown in the sidebar. Leave blank to use your username.'**
  String get shownInTheSidebarLeaveBlank;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInCompletedButNeoagentCould.
  ///
  /// In en, this message translates to:
  /// **'Sign-in completed, but NeoAgent could not keep the browser session. Please sign in again. If this keeps happening, check backend session cookie settings.'**
  String get signInCompletedButNeoagentCould;

  /// No description provided for @signInCompletedButNeoagentCould2.
  ///
  /// In en, this message translates to:
  /// **'Sign-in completed, but NeoAgent could not keep the browser session. Please sign in again. If this keeps happening, the backend session cookie is likely not being retained.'**
  String get signInCompletedButNeoagentCould2;

  /// No description provided for @signInToThisNeoagentServer.
  ///
  /// In en, this message translates to:
  /// **'Sign in to this NeoAgent server before scanning a pairing QR code.'**
  String get signInToThisNeoagentServer;

  /// No description provided for @signInWithAHardwareKey.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a hardware key or passkey instead of your password. '**
  String get signInWithAHardwareKey;

  /// No description provided for @signInWithASecurityKey.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a security key'**
  String get signInWithASecurityKey;

  /// No description provided for @signInWithArg1.
  ///
  /// In en, this message translates to:
  /// **'Sign in with {arg1}'**
  String signInWithArg1(Object? arg1);

  /// No description provided for @signInWithTheSameEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with the same email and master password you use in Bitwarden. The master password and two-step code are used only for sign-in and are never stored or sent to the AI.'**
  String get signInWithTheSameEmail;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutArg1Everywhere.
  ///
  /// In en, this message translates to:
  /// **'Sign out @{arg1} everywhere?'**
  String signOutArg1Everywhere(Object? arg1);

  /// No description provided for @signOutEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere'**
  String get signOutEverywhere;

  /// No description provided for @signUpIsClosed.
  ///
  /// In en, this message translates to:
  /// **'Sign-up is closed.'**
  String get signUpIsClosed;

  /// No description provided for @signalCliRestApiBridge.
  ///
  /// In en, this message translates to:
  /// **'signal-cli REST API bridge'**
  String get signalCliRestApiBridge;

  /// No description provided for @signalCliServerUrl.
  ///
  /// In en, this message translates to:
  /// **'signal-cli server URL'**
  String get signalCliServerUrl;

  /// No description provided for @signedArg1OutOfEverySession.
  ///
  /// In en, this message translates to:
  /// **'Signed @{arg1} out of every session.'**
  String signedArg1OutOfEverySession(Object? arg1);

  /// No description provided for @signedInDevices.
  ///
  /// In en, this message translates to:
  /// **'Signed-in devices'**
  String get signedInDevices;

  /// No description provided for @signedInWithin24Hours.
  ///
  /// In en, this message translates to:
  /// **'Signed in within 24 hours'**
  String get signedInWithin24Hours;

  /// No description provided for @signingSecret.
  ///
  /// In en, this message translates to:
  /// **'Signing secret'**
  String get signingSecret;

  /// No description provided for @sinceArg1.
  ///
  /// In en, this message translates to:
  /// **'Since {arg1}'**
  String sinceArg1(Object? arg1);

  /// No description provided for @sinceArg12.
  ///
  /// In en, this message translates to:
  /// **'since {arg1}'**
  String sinceArg12(Object? arg1);

  /// No description provided for @singleMessage.
  ///
  /// In en, this message translates to:
  /// **'Single message'**
  String get singleMessage;

  /// No description provided for @singleUse.
  ///
  /// In en, this message translates to:
  /// **'Single use'**
  String get singleUse;

  /// No description provided for @skill.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get skill;

  /// No description provided for @skillChanges.
  ///
  /// In en, this message translates to:
  /// **'Skill Changes'**
  String get skillChanges;

  /// No description provided for @skillContent.
  ///
  /// In en, this message translates to:
  /// **'Skill Content'**
  String get skillContent;

  /// No description provided for @skills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skills;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @skipThisTaskBeforeItCalls.
  ///
  /// In en, this message translates to:
  /// **'Skip this task before it calls the model.'**
  String get skipThisTaskBeforeItCalls;

  /// No description provided for @skipsStripeCheckout.
  ///
  /// In en, this message translates to:
  /// **'skips Stripe checkout.'**
  String get skipsStripeCheckout;

  /// No description provided for @slackMessageReceived.
  ///
  /// In en, this message translates to:
  /// **'Slack Message Received'**
  String get slackMessageReceived;

  /// No description provided for @sleepArg1Sessions.
  ///
  /// In en, this message translates to:
  /// **'Sleep {arg1} sessions'**
  String sleepArg1Sessions(Object? arg1);

  /// No description provided for @smallestCurrencyUnit1900Is19.
  ///
  /// In en, this message translates to:
  /// **'Smallest currency unit: 1900 is 19.00.'**
  String get smallestCurrencyUnit1900Is19;

  /// No description provided for @smartModelSelection.
  ///
  /// In en, this message translates to:
  /// **'Smart model selection'**
  String get smartModelSelection;

  /// No description provided for @smartSelector.
  ///
  /// In en, this message translates to:
  /// **'smart selector'**
  String get smartSelector;

  /// No description provided for @smartSelector2.
  ///
  /// In en, this message translates to:
  /// **'Smart Selector'**
  String get smartSelector2;

  /// No description provided for @smartSelectorPool.
  ///
  /// In en, this message translates to:
  /// **'Smart Selector Pool'**
  String get smartSelectorPool;

  /// No description provided for @smtpHost.
  ///
  /// In en, this message translates to:
  /// **'SMTP host'**
  String get smtpHost;

  /// No description provided for @smtpMailSenderPasswordTlsConfirmation.
  ///
  /// In en, this message translates to:
  /// **'smtp mail sender password tls confirmation notifications reset'**
  String get smtpMailSenderPasswordTlsConfirmation;

  /// No description provided for @smtpPassword.
  ///
  /// In en, this message translates to:
  /// **'SMTP password'**
  String get smtpPassword;

  /// No description provided for @smtpPort.
  ///
  /// In en, this message translates to:
  /// **'SMTP port'**
  String get smtpPort;

  /// No description provided for @smtpPortMustBeAWhole.
  ///
  /// In en, this message translates to:
  /// **'SMTP port must be a whole number from 1 to 65535.'**
  String get smtpPortMustBeAWhole;

  /// No description provided for @smtpUsername.
  ///
  /// In en, this message translates to:
  /// **'SMTP username'**
  String get smtpUsername;

  /// No description provided for @soTheRunStartsThatMuch.
  ///
  /// In en, this message translates to:
  /// **'so the run starts that much earlier.'**
  String get soTheRunStartsThatMuch;

  /// No description provided for @socialBehaviorOff.
  ///
  /// In en, this message translates to:
  /// **'Social behavior off'**
  String get socialBehaviorOff;

  /// No description provided for @socialIntelligence.
  ///
  /// In en, this message translates to:
  /// **'social intelligence'**
  String get socialIntelligence;

  /// No description provided for @socialIntelligence2.
  ///
  /// In en, this message translates to:
  /// **'Social intelligence'**
  String get socialIntelligence2;

  /// No description provided for @socialObservability.
  ///
  /// In en, this message translates to:
  /// **'Social observability'**
  String get socialObservability;

  /// No description provided for @socialReach.
  ///
  /// In en, this message translates to:
  /// **'social reach'**
  String get socialReach;

  /// No description provided for @socialReach2.
  ///
  /// In en, this message translates to:
  /// **'Social reach'**
  String get socialReach2;

  /// No description provided for @socialReach3.
  ///
  /// In en, this message translates to:
  /// **'Social Reach'**
  String get socialReach3;

  /// No description provided for @socialReachUpdated.
  ///
  /// In en, this message translates to:
  /// **'Social Reach updated.'**
  String get socialReachUpdated;

  /// No description provided for @socialSourcesAgentsCanReadDirectly.
  ///
  /// In en, this message translates to:
  /// **'Social sources agents can read directly, including feeds, repositories, Reddit, X, videos, and cookie-backed market data.'**
  String get socialSourcesAgentsCanReadDirectly;

  /// No description provided for @somethingWentWrongPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrongPleaseTryAgain;

  /// No description provided for @sortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get sortOrder;

  /// No description provided for @sortOrderMustBeAWhole.
  ///
  /// In en, this message translates to:
  /// **'Sort order must be a whole number.'**
  String get sortOrderMustBeAWhole;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @source2.
  ///
  /// In en, this message translates to:
  /// **'SOURCE'**
  String get source2;

  /// No description provided for @spaceOrChatIdUsedWhen.
  ///
  /// In en, this message translates to:
  /// **'Space or chat ID used when this agent starts a conversation.'**
  String get spaceOrChatIdUsedWhen;

  /// No description provided for @spaceWebhookAndAppCallbackSupport.
  ///
  /// In en, this message translates to:
  /// **'Space webhook and app callback support'**
  String get spaceWebhookAndAppCallbackSupport;

  /// No description provided for @speaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get speaking;

  /// No description provided for @speechToSpeechModelUsingThe.
  ///
  /// In en, this message translates to:
  /// **'speech-to-speech model using the OpenAI or Google key under '**
  String get speechToSpeechModelUsingThe;

  /// No description provided for @speechToText.
  ///
  /// In en, this message translates to:
  /// **'Speech-to-text'**
  String get speechToText;

  /// No description provided for @speechToTextTranscribesVoiceNotes.
  ///
  /// In en, this message translates to:
  /// **'Speech-to-text transcribes voice notes and dictation. Auto uses OpenAI, Gemini or Deepgram, whichever has an API key. The voice reply model is the chat model that answers voice notes.'**
  String get speechToTextTranscribesVoiceNotes;

  /// No description provided for @sqlConsole.
  ///
  /// In en, this message translates to:
  /// **'SQL console'**
  String get sqlConsole;

  /// No description provided for @stable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get stable;

  /// No description provided for @stableInstallsTheLatestPublishedBackend.
  ///
  /// In en, this message translates to:
  /// **'Stable installs the latest published backend release.'**
  String get stableInstallsTheLatestPublishedBackend;

  /// No description provided for @stackTrace.
  ///
  /// In en, this message translates to:
  /// **'stack trace'**
  String get stackTrace;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @standardView.
  ///
  /// In en, this message translates to:
  /// **'Standard view'**
  String get standardView;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @startASessionToPlanOr.
  ///
  /// In en, this message translates to:
  /// **'Start a session to plan or build with NeoAgent.'**
  String get startASessionToPlanOr;

  /// No description provided for @startAndroid.
  ///
  /// In en, this message translates to:
  /// **'Start Android'**
  String get startAndroid;

  /// No description provided for @startComputer.
  ///
  /// In en, this message translates to:
  /// **'Start computer'**
  String get startComputer;

  /// No description provided for @startFullSetup.
  ///
  /// In en, this message translates to:
  /// **'Start full setup'**
  String get startFullSetup;

  /// No description provided for @startProcessFilepathArg1.
  ///
  /// In en, this message translates to:
  /// **'Start-Process -FilePath {arg1}'**
  String startProcessFilepathArg1(Object? arg1);

  /// No description provided for @startSetup.
  ///
  /// In en, this message translates to:
  /// **'Start setup'**
  String get startSetup;

  /// No description provided for @startTalking.
  ///
  /// In en, this message translates to:
  /// **'Start talking'**
  String get startTalking;

  /// No description provided for @startTheAndroidPhoneFirstThen.
  ///
  /// In en, this message translates to:
  /// **'Start the Android phone first, then drop a .apk or .apks file here.'**
  String get startTheAndroidPhoneFirstThen;

  /// No description provided for @startTheServerLaterFromThe.
  ///
  /// In en, this message translates to:
  /// **'Start the server later from the list once the config is saved.'**
  String get startTheServerLaterFromThe;

  /// No description provided for @startWithARecommendedTask.
  ///
  /// In en, this message translates to:
  /// **'Start with a recommended task'**
  String get startWithARecommendedTask;

  /// No description provided for @startingAndroid.
  ///
  /// In en, this message translates to:
  /// **'Starting Android'**
  String get startingAndroid;

  /// No description provided for @startingYourComputer.
  ///
  /// In en, this message translates to:
  /// **'Starting your computer'**
  String get startingYourComputer;

  /// No description provided for @startsOff.
  ///
  /// In en, this message translates to:
  /// **'starts off.'**
  String get startsOff;

  /// No description provided for @startsWithXoxbFromYourSlack.
  ///
  /// In en, this message translates to:
  /// **'Starts with xoxb-. From your Slack app credentials.'**
  String get startsWithXoxbFromYourSlack;

  /// No description provided for @starttelecomcallroutingErrorArg1.
  ///
  /// In en, this message translates to:
  /// **'startTelecomCallRouting Error: {arg1}'**
  String starttelecomcallroutingErrorArg1(Object? arg1);

  /// No description provided for @statsRunsTokensUsersChartsSuccess.
  ///
  /// In en, this message translates to:
  /// **'stats runs tokens users charts success rate'**
  String get statsRunsTokensUsersChartsSuccess;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @status2.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get status2;

  /// No description provided for @statusDatabaseRuntimeVmProviders.
  ///
  /// In en, this message translates to:
  /// **'status database runtime vm providers'**
  String get statusDatabaseRuntimeVmProviders;

  /// No description provided for @statusIsNotLoadedYet.
  ///
  /// In en, this message translates to:
  /// **'Status is not loaded yet.'**
  String get statusIsNotLoadedYet;

  /// No description provided for @stayManagedByYou.
  ///
  /// In en, this message translates to:
  /// **'stay managed by you.'**
  String get stayManagedByYou;

  /// No description provided for @stayOnTheCall.
  ///
  /// In en, this message translates to:
  /// **'Stay on the call'**
  String get stayOnTheCall;

  /// No description provided for @stayedQuiet.
  ///
  /// In en, this message translates to:
  /// **'Stayed quiet'**
  String get stayedQuiet;

  /// No description provided for @steering.
  ///
  /// In en, this message translates to:
  /// **'STEERING'**
  String get steering;

  /// No description provided for @stepArg1OfArg2.
  ///
  /// In en, this message translates to:
  /// **'STEP {arg1} OF {arg2}'**
  String stepArg1OfArg2(Object? arg1, Object? arg2);

  /// No description provided for @stepsArg1.
  ///
  /// In en, this message translates to:
  /// **'Steps {arg1}'**
  String stepsArg1(Object? arg1);

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stop2.
  ///
  /// In en, this message translates to:
  /// **'Stop (⌘.)'**
  String get stop2;

  /// No description provided for @stopManaging.
  ///
  /// In en, this message translates to:
  /// **'Stop managing'**
  String get stopManaging;

  /// No description provided for @stopManagingArg1.
  ///
  /// In en, this message translates to:
  /// **'Stop managing {arg1}?'**
  String stopManagingArg1(Object? arg1);

  /// No description provided for @stopRun.
  ///
  /// In en, this message translates to:
  /// **'Stop run'**
  String get stopRun;

  /// No description provided for @stopSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Stop speaking'**
  String get stopSpeaking;

  /// No description provided for @stoppedBeforeCompletion.
  ///
  /// In en, this message translates to:
  /// **'Stopped before completion'**
  String get stoppedBeforeCompletion;

  /// No description provided for @stoptelecomcallroutingErrorArg1.
  ///
  /// In en, this message translates to:
  /// **'stopTelecomCallRouting Error: {arg1}'**
  String stoptelecomcallroutingErrorArg1(Object? arg1);

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @storeSkill.
  ///
  /// In en, this message translates to:
  /// **'Store skill'**
  String get storeSkill;

  /// No description provided for @storedArg1.
  ///
  /// In en, this message translates to:
  /// **'Stored: {arg1}'**
  String storedArg1(Object? arg1);

  /// No description provided for @storedEncryptedAndOnlyUsedFor.
  ///
  /// In en, this message translates to:
  /// **'stored encrypted and only used for your own runs.'**
  String get storedEncryptedAndOnlyUsedFor;

  /// No description provided for @storedMetrics.
  ///
  /// In en, this message translates to:
  /// **'Stored Metrics'**
  String get storedMetrics;

  /// No description provided for @storesOnlyTheBitwardenSessionKey.
  ///
  /// In en, this message translates to:
  /// **'Stores only the Bitwarden session key encrypted on this server, so connections survive restarts. You can lock it at any time.'**
  String get storesOnlyTheBitwardenSessionKey;

  /// No description provided for @stripeBilling.
  ///
  /// In en, this message translates to:
  /// **'Stripe billing'**
  String get stripeBilling;

  /// No description provided for @stripeKeysForPaidPlansPoint.
  ///
  /// In en, this message translates to:
  /// **'Stripe keys for paid plans. Point a Stripe webhook at '**
  String get stripeKeysForPaidPlansPoint;

  /// No description provided for @stripePriceId.
  ///
  /// In en, this message translates to:
  /// **'Stripe price ID'**
  String get stripePriceId;

  /// No description provided for @stripeSetup.
  ///
  /// In en, this message translates to:
  /// **'Stripe setup'**
  String get stripeSetup;

  /// No description provided for @strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strong;

  /// No description provided for @strongPassword.
  ///
  /// In en, this message translates to:
  /// **'Strong password.'**
  String get strongPassword;

  /// No description provided for @subAgent.
  ///
  /// In en, this message translates to:
  /// **'Sub-agent'**
  String get subAgent;

  /// No description provided for @subagentUpdate.
  ///
  /// In en, this message translates to:
  /// **'Subagent update'**
  String get subagentUpdate;

  /// No description provided for @subagentUpdate2.
  ///
  /// In en, this message translates to:
  /// **'Subagent update.'**
  String get subagentUpdate2;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @subscriptionBillingOverrideComp.
  ///
  /// In en, this message translates to:
  /// **'subscription billing override comp'**
  String get subscriptionBillingOverrideComp;

  /// No description provided for @subscriptionCanceled.
  ///
  /// In en, this message translates to:
  /// **'Subscription canceled.'**
  String get subscriptionCanceled;

  /// No description provided for @subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptions;

  /// No description provided for @successRate.
  ///
  /// In en, this message translates to:
  /// **'Success rate'**
  String get successRate;

  /// No description provided for @suggestTheThreeMostImportantThings.
  ///
  /// In en, this message translates to:
  /// **'Suggest the three most important things to focus on next week.'**
  String get suggestTheThreeMostImportantThings;

  /// No description provided for @suggestionsArg1.
  ///
  /// In en, this message translates to:
  /// **'Suggestions: {arg1}'**
  String suggestionsArg1(Object? arg1);

  /// No description provided for @sumAByteSizeAsBytes.
  ///
  /// In en, this message translates to:
  /// **'       SUM(a.byte_size) AS bytes,\n'**
  String get sumAByteSizeAsBytes;

  /// No description provided for @summariseMyLastRun.
  ///
  /// In en, this message translates to:
  /// **'Summarise my last run'**
  String get summariseMyLastRun;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'SUMMARY'**
  String get summary;

  /// No description provided for @supportUrl.
  ///
  /// In en, this message translates to:
  /// **'Support URL'**
  String get supportUrl;

  /// No description provided for @supportedRainStartSnowStartWind.
  ///
  /// In en, this message translates to:
  /// **'Supported: rain_start, snow_start, wind_alert, temperature_above, temperature_below'**
  String get supportedRainStartSnowStartWind;

  /// No description provided for @switchAgent.
  ///
  /// In en, this message translates to:
  /// **'Switch agent'**
  String get switchAgent;

  /// No description provided for @symbolicLinksAreNotAllowedIn.
  ///
  /// In en, this message translates to:
  /// **'Symbolic links are not allowed in NeoAgent Workspace paths.'**
  String get symbolicLinksAreNotAllowedIn;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @synologyChat.
  ///
  /// In en, this message translates to:
  /// **'Synology Chat'**
  String get synologyChat;

  /// No description provided for @systemPrivacySettings.
  ///
  /// In en, this message translates to:
  /// **'System privacy settings'**
  String get systemPrivacySettings;

  /// No description provided for @tableInfoUsers.
  ///
  /// In en, this message translates to:
  /// **'Table info (users)'**
  String get tableInfoUsers;

  /// No description provided for @tagsOnly.
  ///
  /// In en, this message translates to:
  /// **'Tags only'**
  String get tagsOnly;

  /// No description provided for @tapAnEntityToFilterMemories.
  ///
  /// In en, this message translates to:
  /// **'Tap an entity to filter memories by it.'**
  String get tapAnEntityToFilterMemories;

  /// No description provided for @task.
  ///
  /// In en, this message translates to:
  /// **'TASK'**
  String get task;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @tasksRunOnAScheduleOr.
  ///
  /// In en, this message translates to:
  /// **'Tasks run on a schedule or when something happens, then '**
  String get tasksRunOnAScheduleOr;

  /// No description provided for @tasksRunOnTheirOwnAnd.
  ///
  /// In en, this message translates to:
  /// **'Tasks run on their own and message you with the '**
  String get tasksRunOnTheirOwnAnd;

  /// No description provided for @tcpBridgeToALocalDevice.
  ///
  /// In en, this message translates to:
  /// **'TCP bridge to a local device channel'**
  String get tcpBridgeToALocalDevice;

  /// No description provided for @teach.
  ///
  /// In en, this message translates to:
  /// **'Teach'**
  String get teach;

  /// No description provided for @teachingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Teaching in progress'**
  String get teachingInProgress;

  /// No description provided for @team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// No description provided for @teamLinksNeverMakeAnyoneA.
  ///
  /// In en, this message translates to:
  /// **'Team links never make anyone a server admin. Admins run the '**
  String get teamLinksNeverMakeAnyoneA;

  /// No description provided for @teamSpacesRoomsChannelsAndLive.
  ///
  /// In en, this message translates to:
  /// **'Team spaces, rooms, channels, and live communities.'**
  String get teamSpacesRoomsChannelsAndLive;

  /// No description provided for @teamsMessageReceived.
  ///
  /// In en, this message translates to:
  /// **'Teams Message Received'**
  String get teamsMessageReceived;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @temporarySetupFilesWillBeCleaned.
  ///
  /// In en, this message translates to:
  /// **'Temporary setup files will be cleaned up later.'**
  String get temporarySetupFilesWillBeCleaned;

  /// No description provided for @tenantId.
  ///
  /// In en, this message translates to:
  /// **'Tenant ID'**
  String get tenantId;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @testConnection2.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection2;

  /// No description provided for @textChat.
  ///
  /// In en, this message translates to:
  /// **'Text & Chat'**
  String get textChat;

  /// No description provided for @thatAddedTheirOwnKeyKeep.
  ///
  /// In en, this message translates to:
  /// **'that added their own key keep using it.'**
  String get thatAddedTheirOwnKeyKeep;

  /// No description provided for @thatEmailAlreadyBelongsToAn.
  ///
  /// In en, this message translates to:
  /// **'That email already belongs to an existing account. Sign in first, then link Google from account settings.'**
  String get thatEmailAlreadyBelongsToAn;

  /// No description provided for @thatEmailIsAlreadyLinkedTo.
  ///
  /// In en, this message translates to:
  /// **'That email is already linked to another account.'**
  String get thatEmailIsAlreadyLinkedTo;

  /// No description provided for @thatGoogleAccountIsAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'That Google account is already linked to a different NeoAgent account.'**
  String get thatGoogleAccountIsAlreadyLinked;

  /// No description provided for @thatQrCodeIsNotA.
  ///
  /// In en, this message translates to:
  /// **'That QR code is not a NeoAgent login request.'**
  String get thatQrCodeIsNotA;

  /// No description provided for @thatQrCodeIsNotA2.
  ///
  /// In en, this message translates to:
  /// **'That QR code is not a NeoAgent pairing request.'**
  String get thatQrCodeIsNotA2;

  /// No description provided for @thatSecurityKeyIsAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'That security key is already registered on this account.'**
  String get thatSecurityKeyIsAlreadyRegistered;

  /// No description provided for @theAddress.
  ///
  /// In en, this message translates to:
  /// **'The address'**
  String get theAddress;

  /// No description provided for @theAddressOfYourBluebubblesServer.
  ///
  /// In en, this message translates to:
  /// **'The address of your BlueBubbles server.'**
  String get theAddressOfYourBluebubblesServer;

  /// No description provided for @theAddressPeopleAndOauthProviders.
  ///
  /// In en, this message translates to:
  /// **'The address people and OAuth providers use to reach '**
  String get theAddressPeopleAndOauthProviders;

  /// No description provided for @theAgentReadsTimesYouMention.
  ///
  /// In en, this message translates to:
  /// **'The agent reads times you mention, and runs scheduled tasks, in this time zone.'**
  String get theAgentReadsTimesYouMention;

  /// No description provided for @theAgentSChatModelJev.
  ///
  /// In en, this message translates to:
  /// **'the agent\'\'s chat model. Jev runs through OpenRouter.'**
  String get theAgentSChatModelJev;

  /// No description provided for @theAgentWillAskBeforeEvery.
  ///
  /// In en, this message translates to:
  /// **'The agent will ask before every sensitive tool, '**
  String get theAgentWillAskBeforeEvery;

  /// No description provided for @theAgentWillIgnoreThisSkill.
  ///
  /// In en, this message translates to:
  /// **'The agent will ignore this skill.'**
  String get theAgentWillIgnoreThisSkill;

  /// No description provided for @theAppCouldNotReachThis.
  ///
  /// In en, this message translates to:
  /// **'The app could not reach this NeoAgent deployment. Check your network connection or confirm the service URL is correct.'**
  String get theAppCouldNotReachThis;

  /// No description provided for @theBrowserBlockedARequestTo.
  ///
  /// In en, this message translates to:
  /// **'The browser blocked a request to {arg1} because of Content Security Policy.'**
  String theBrowserBlockedARequestTo(Object? arg1);

  /// No description provided for @theBrowserBlockedARequiredRequest.
  ///
  /// In en, this message translates to:
  /// **'The browser blocked a required request because of Content Security Policy.'**
  String get theBrowserBlockedARequiredRequest;

  /// No description provided for @theCloudComputerIsSandboxedFrom.
  ///
  /// In en, this message translates to:
  /// **'The cloud computer is sandboxed from your devices. Switch a '**
  String get theCloudComputerIsSandboxedFrom;

  /// No description provided for @theCloudWorkspace.
  ///
  /// In en, this message translates to:
  /// **'the cloud workspace'**
  String get theCloudWorkspace;

  /// No description provided for @theComputerCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'The computer could not start'**
  String get theComputerCouldNotStart;

  /// No description provided for @theComputerNeedsMoreFreeDisk.
  ///
  /// In en, this message translates to:
  /// **'The computer needs more free disk space on the NeoAgent host. Free some space, then try again.'**
  String get theComputerNeedsMoreFreeDisk;

  /// No description provided for @theComputerRuntimeNeedsRepairRun.
  ///
  /// In en, this message translates to:
  /// **'The computer runtime needs repair. Run NeoAgent Doctor, then try again.'**
  String get theComputerRuntimeNeedsRepairRun;

  /// No description provided for @theConnectionTestFailed.
  ///
  /// In en, this message translates to:
  /// **'The connection test failed.'**
  String get theConnectionTestFailed;

  /// No description provided for @theDesktopDidNotStart.
  ///
  /// In en, this message translates to:
  /// **'The desktop did not start'**
  String get theDesktopDidNotStart;

  /// No description provided for @theDiscoveredNeoagentReturnedIncompleteIdentity.
  ///
  /// In en, this message translates to:
  /// **'The discovered NeoAgent returned incomplete identity data.'**
  String get theDiscoveredNeoagentReturnedIncompleteIdentity;

  /// No description provided for @theDiscoveredNeoagentUsesAnUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The discovered NeoAgent uses an unsupported setup protocol.'**
  String get theDiscoveredNeoagentUsesAnUnsupported;

  /// No description provided for @theDiscoveredServiceIsNotNeoagent.
  ///
  /// In en, this message translates to:
  /// **'The discovered service is not NeoAgent.'**
  String get theDiscoveredServiceIsNotNeoagent;

  /// No description provided for @theDownloadedNeoagentRuntimeDidNot.
  ///
  /// In en, this message translates to:
  /// **'The downloaded NeoAgent runtime did not pass verification.'**
  String get theDownloadedNeoagentRuntimeDidNot;

  /// No description provided for @theGoogleChatSpaceWebhookThis.
  ///
  /// In en, this message translates to:
  /// **'The Google Chat space webhook this agent should post to.'**
  String get theGoogleChatSpaceWebhookThis;

  /// No description provided for @theInstallerIsNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'The installer is no longer available.'**
  String get theInstallerIsNoLongerAvailable;

  /// No description provided for @theInteractiveLinuxDesktopIsAvailable.
  ///
  /// In en, this message translates to:
  /// **'The interactive Linux desktop is available in the NeoAgent web app.'**
  String get theInteractiveLinuxDesktopIsAvailable;

  /// No description provided for @theIntroIsNotAvailableOn.
  ///
  /// In en, this message translates to:
  /// **'The intro is not available on this device.'**
  String get theIntroIsNotAvailableOn;

  /// No description provided for @theLatestRunsAcrossEveryAccount.
  ///
  /// In en, this message translates to:
  /// **'The latest runs across every account.'**
  String get theLatestRunsAcrossEveryAccount;

  /// No description provided for @theLatestSyncWindowEndedArg1.
  ///
  /// In en, this message translates to:
  /// **'The latest sync window ended {arg1} and did not find any new Health Connect records. Stored metrics below came from earlier syncs.'**
  String theLatestSyncWindowEndedArg1(Object? arg1);

  /// No description provided for @theLinuxGraphicalSessionIsNot.
  ///
  /// In en, this message translates to:
  /// **'The Linux graphical session is not running.'**
  String get theLinuxGraphicalSessionIsNot;

  /// No description provided for @theLiveVoiceModelDidNot.
  ///
  /// In en, this message translates to:
  /// **'The live voice model did not answer. Try again.'**
  String get theLiveVoiceModelDidNot;

  /// No description provided for @theLocalIpOfTheMeshtastic.
  ///
  /// In en, this message translates to:
  /// **'The local IP of the Meshtastic device.'**
  String get theLocalIpOfTheMeshtastic;

  /// No description provided for @theLocalNeoagentCommandExitedWith.
  ///
  /// In en, this message translates to:
  /// **'The local NeoAgent command exited with code {arg1}.'**
  String theLocalNeoagentCommandExitedWith(Object? arg1);

  /// No description provided for @theLocalNeoagentCommandTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The local NeoAgent command timed out.'**
  String get theLocalNeoagentCommandTimedOut;

  /// No description provided for @theLocalNeoagentRuntimeNeedsRepair.
  ///
  /// In en, this message translates to:
  /// **'The local NeoAgent runtime needs repair.'**
  String get theLocalNeoagentRuntimeNeedsRepair;

  /// No description provided for @theLocalRuntimeNeedsRepairArg1.
  ///
  /// In en, this message translates to:
  /// **'The local runtime needs repair ({arg1}).'**
  String theLocalRuntimeNeedsRepairArg1(Object? arg1);

  /// No description provided for @theLocalUserHomeDirectoryIs.
  ///
  /// In en, this message translates to:
  /// **'The local user home directory is unavailable.'**
  String get theLocalUserHomeDirectoryIs;

  /// No description provided for @theMailAccountNeoagentSendsSign.
  ///
  /// In en, this message translates to:
  /// **'The mail account NeoAgent sends sign-up confirmations, sign-in '**
  String get theMailAccountNeoagentSendsSign;

  /// No description provided for @theMainAgentIsCreatedAutomatically.
  ///
  /// In en, this message translates to:
  /// **'The main agent is created automatically when needed.'**
  String get theMainAgentIsCreatedAutomatically;

  /// No description provided for @theMatchingNeoagentRuntimeIsMissing.
  ///
  /// In en, this message translates to:
  /// **'The matching NeoAgent runtime is missing from this release.'**
  String get theMatchingNeoagentRuntimeIsMissing;

  /// No description provided for @theMattermostIncomingWebhookThisAgent.
  ///
  /// In en, this message translates to:
  /// **'The Mattermost incoming webhook this agent should post to.'**
  String get theMattermostIncomingWebhookThisAgent;

  /// No description provided for @theModelListCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'The model list could not be loaded. Enter model IDs separated by '**
  String get theModelListCouldNotBe;

  /// No description provided for @theModelsTheSmartSelectorRoutes.
  ///
  /// In en, this message translates to:
  /// **'The models the Smart Selector routes between automatically.'**
  String get theModelsTheSmartSelectorRoutes;

  /// No description provided for @theNeoagentBackendDownloadDidNot.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent backend download did not match its manifest.'**
  String get theNeoagentBackendDownloadDidNot;

  /// No description provided for @theNeoagentBackendDownloadWasIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent backend download was incomplete.'**
  String get theNeoagentBackendDownloadWasIncomplete;

  /// No description provided for @theNeoagentBackendOnThisComputer.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent backend on this computer is not answering on port '**
  String get theNeoagentBackendOnThisComputer;

  /// No description provided for @theNeoagentBackendRuntimeCouldNot.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent backend runtime could not be downloaded.'**
  String get theNeoagentBackendRuntimeCouldNot;

  /// No description provided for @theNeoagentBackendTookTooLong.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent backend took too long to respond for {arg1}.'**
  String theNeoagentBackendTookTooLong(Object? arg1);

  /// No description provided for @theNeoagentDeploymentRespondedWithHttp.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent deployment responded with HTTP 402 instead of the normal 401 for invalid credentials. Check reverse-proxy, auth gateway, or payment-related rules on that server.'**
  String get theNeoagentDeploymentRespondedWithHttp;

  /// No description provided for @theNeoagentDeploymentRespondedWithHttp2.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent deployment responded with HTTP 402.\n\n{arg1}'**
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1);

  /// No description provided for @theNeoagentDeploymentRespondedWithHttp3.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent deployment responded with HTTP 402. Check reverse-proxy, auth gateway, or payment-related rules on that server.'**
  String get theNeoagentDeploymentRespondedWithHttp3;

  /// No description provided for @theNeoagentInstanceThisAppIs.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent instance this app is connected to.'**
  String get theNeoagentInstanceThisAppIs;

  /// No description provided for @theNeoagentReleaseServiceReturnedInvalid.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent release service returned invalid data.'**
  String get theNeoagentReleaseServiceReturnedInvalid;

  /// No description provided for @theNeoagentRuntimeArtifactMetadataIs.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent runtime artifact metadata is invalid.'**
  String get theNeoagentRuntimeArtifactMetadataIs;

  /// No description provided for @theNeoagentRuntimeManifestDidNot.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent runtime manifest did not pass signature verification.'**
  String get theNeoagentRuntimeManifestDidNot;

  /// No description provided for @theNeoagentRuntimeManifestHasNo.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent runtime manifest has no artifacts.'**
  String get theNeoagentRuntimeManifestHasNo;

  /// No description provided for @theNeoagentRuntimeManifestSignatureIs.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent runtime manifest signature is invalid.'**
  String get theNeoagentRuntimeManifestSignatureIs;

  /// No description provided for @thePasswordYouSetInBluebubbles.
  ///
  /// In en, this message translates to:
  /// **'The password you set in BlueBubbles.'**
  String get thePasswordYouSetInBluebubbles;

  /// No description provided for @thePeopleYouManageStayWith.
  ///
  /// In en, this message translates to:
  /// **'The people you manage stay with you.'**
  String get thePeopleYouManageStayWith;

  /// No description provided for @thePlanStopsBeingOfferedIt.
  ///
  /// In en, this message translates to:
  /// **'The plan stops being offered. It is kept, not erased, and '**
  String get thePlanStopsBeingOfferedIt;

  /// No description provided for @theProviderAnswers.
  ///
  /// In en, this message translates to:
  /// **'the provider answers.'**
  String get theProviderAnswers;

  /// No description provided for @theQueryReturnedNoRows.
  ///
  /// In en, this message translates to:
  /// **'The query returned no rows.'**
  String get theQueryReturnedNoRows;

  /// No description provided for @theRequestedDesktopDisplayIsNot.
  ///
  /// In en, this message translates to:
  /// **'The requested desktop display is not available.'**
  String get theRequestedDesktopDisplayIsNot;

  /// No description provided for @theRest.
  ///
  /// In en, this message translates to:
  /// **'the rest.'**
  String get theRest;

  /// No description provided for @theRestEndpointForYourSignal.
  ///
  /// In en, this message translates to:
  /// **'The REST endpoint for your signal-cli instance.'**
  String get theRestEndpointForYourSignal;

  /// No description provided for @theRunIsPausedUntilYou.
  ///
  /// In en, this message translates to:
  /// **'The run is paused until you answer.'**
  String get theRunIsPausedUntilYou;

  /// No description provided for @theRunStartsAtTheScheduled.
  ///
  /// In en, this message translates to:
  /// **'The run starts at the scheduled time.'**
  String get theRunStartsAtTheScheduled;

  /// No description provided for @theRuntimeIsALightweightDebian.
  ///
  /// In en, this message translates to:
  /// **'The runtime is a lightweight Debian Linux desktop with Chromium, PCManFM, Mousepad, LXTerminal, Python, Git, and standard command-line tools. Its capacity is managed by the NeoAgent host.'**
  String get theRuntimeIsALightweightDebian;

  /// No description provided for @theSecurityKeyRegistrationCouldNot.
  ///
  /// In en, this message translates to:
  /// **'The security key registration could not be started.'**
  String get theSecurityKeyRegistrationCouldNot;

  /// No description provided for @theServerKeepsOnlyAFingerprint.
  ///
  /// In en, this message translates to:
  /// **'the server keeps only a fingerprint of it.'**
  String get theServerKeepsOnlyAFingerprint;

  /// No description provided for @theServerOnThisComputerIs.
  ///
  /// In en, this message translates to:
  /// **'The server on this computer is not running'**
  String get theServerOnThisComputerIs;

  /// No description provided for @theServerReportedNoHealthChecks.
  ///
  /// In en, this message translates to:
  /// **'The server reported no health checks.'**
  String get theServerReportedNoHealthChecks;

  /// No description provided for @theSignalPhoneNumberThisBot.
  ///
  /// In en, this message translates to:
  /// **'The Signal phone number this bot uses.'**
  String get theSignalPhoneNumberThisBot;

  /// No description provided for @theSubscriptionPlansPeopleCanChoose.
  ///
  /// In en, this message translates to:
  /// **'The subscription plans people can choose from.'**
  String get theSubscriptionPlansPeopleCanChoose;

  /// No description provided for @theTeamsIncomingWebhookThisAgent.
  ///
  /// In en, this message translates to:
  /// **'The Teams incoming webhook this agent should post to.'**
  String get theTeamsIncomingWebhookThisAgent;

  /// No description provided for @theTwoFactorChallengeExpiredSign.
  ///
  /// In en, this message translates to:
  /// **'The two-factor challenge expired. Sign in again.'**
  String get theTwoFactorChallengeExpiredSign;

  /// No description provided for @theTwoFactorCodeIsNot.
  ///
  /// In en, this message translates to:
  /// **'The two-factor code is not valid.'**
  String get theTwoFactorCodeIsNot;

  /// No description provided for @theVerifiedRuntimePackageCouldNot.
  ///
  /// In en, this message translates to:
  /// **'The verified runtime package could not be marked executable.'**
  String get theVerifiedRuntimePackageCouldNot;

  /// No description provided for @theVerifiedRuntimePackageIsMissing.
  ///
  /// In en, this message translates to:
  /// **'The verified runtime package is missing required files.'**
  String get theVerifiedRuntimePackageIsMissing;

  /// No description provided for @theWebAppCouldNotReach.
  ///
  /// In en, this message translates to:
  /// **'The web app could not reach the NeoAgent backend.'**
  String get theWebAppCouldNotReach;

  /// No description provided for @theWebAppCouldNotReach2.
  ///
  /// In en, this message translates to:
  /// **'The web app could not reach the NeoAgent backend at {arg1}. Check the browser console and reverse-proxy/network configuration.'**
  String theWebAppCouldNotReach2(Object? arg1);

  /// No description provided for @theirSettings.
  ///
  /// In en, this message translates to:
  /// **'their settings.'**
  String get theirSettings;

  /// No description provided for @themselvesTheServerOperatorRemovesAdmin.
  ///
  /// In en, this message translates to:
  /// **'themselves; the server operator removes admin first with '**
  String get themselvesTheServerOperatorRemovesAdmin;

  /// No description provided for @theseChannelsStaySilentToHear.
  ///
  /// In en, this message translates to:
  /// **'These channels stay silent. To hear from them again, add them under Who can message for that platform.'**
  String get theseChannelsStaySilentToHear;

  /// No description provided for @theseListsAreOptionalUnlessA.
  ///
  /// In en, this message translates to:
  /// **'These lists are optional unless a section above is set to approved only.'**
  String get theseListsAreOptionalUnlessA;

  /// No description provided for @thesePeopleAnywhere.
  ///
  /// In en, this message translates to:
  /// **'These people, anywhere'**
  String get thesePeopleAnywhere;

  /// No description provided for @thesePeopleCanMessageArg1In.
  ///
  /// In en, this message translates to:
  /// **'These people can message {arg1} in private chats and in any group they share.'**
  String thesePeopleCanMessageArg1In(Object? arg1);

  /// No description provided for @thesePeopleCanMessageArg1One.
  ///
  /// In en, this message translates to:
  /// **'These people can message {arg1} one-to-one. This does not let them speak in groups.'**
  String thesePeopleCanMessageArg1One(Object? arg1);

  /// No description provided for @thesePeopleCanOnlyMessageArg1.
  ///
  /// In en, this message translates to:
  /// **'These people can only message {arg1} in the group you picked.'**
  String thesePeopleCanOnlyMessageArg1(Object? arg1);

  /// No description provided for @thesePeopleInOneGroup.
  ///
  /// In en, this message translates to:
  /// **'These people, in one group'**
  String get thesePeopleInOneGroup;

  /// No description provided for @theseSwitchesNeverYourChatsMemories.
  ///
  /// In en, this message translates to:
  /// **'these switches, never your chats, memories or files.'**
  String get theseSwitchesNeverYourChatsMemories;

  /// No description provided for @thisAccountIsIgnored.
  ///
  /// In en, this message translates to:
  /// **'this account is ignored.'**
  String get thisAccountIsIgnored;

  /// No description provided for @thisAccountWillUnlockNeoagentOn.
  ///
  /// In en, this message translates to:
  /// **'This account will unlock NeoAgent on this machine.'**
  String get thisAccountWillUnlockNeoagentOn;

  /// No description provided for @thisAgentCanDelegateToAny.
  ///
  /// In en, this message translates to:
  /// **'This agent can delegate to any eligible receiving agent.'**
  String get thisAgentCanDelegateToAny;

  /// No description provided for @thisAgentIsUsingAServer.
  ///
  /// In en, this message translates to:
  /// **'This agent is using a server-managed Trello API key. You only need to authorize an account token below.'**
  String get thisAgentIsUsingAServer;

  /// No description provided for @thisBuildIsNotAllowedTo.
  ///
  /// In en, this message translates to:
  /// **'This build is not allowed to talk to this NeoAgent deployment.'**
  String get thisBuildIsNotAllowedTo;

  /// No description provided for @thisCodeBelongsToADifferent.
  ///
  /// In en, this message translates to:
  /// **'This code belongs to a different NeoAgent server: {arg1}'**
  String thisCodeBelongsToADifferent(Object? arg1);

  /// No description provided for @thisDesktopIsConnected.
  ///
  /// In en, this message translates to:
  /// **'This desktop is connected'**
  String get thisDesktopIsConnected;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @thisDeviceArg1.
  ///
  /// In en, this message translates to:
  /// **'This device: {arg1}'**
  String thisDeviceArg1(Object? arg1);

  /// No description provided for @thisDeviceCannotRegisterSecurityKeys.
  ///
  /// In en, this message translates to:
  /// **'This device cannot register security keys. Open NeoAgent in a browser over HTTPS to add one.'**
  String get thisDeviceCannotRegisterSecurityKeys;

  /// No description provided for @thisDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device — unavailable'**
  String get thisDeviceUnavailable;

  /// No description provided for @thisFileHasNoContent.
  ///
  /// In en, this message translates to:
  /// **'This file has no content.'**
  String get thisFileHasNoContent;

  /// No description provided for @thisGoogleAccountIsNotLinked.
  ///
  /// In en, this message translates to:
  /// **'This Google account is not linked yet. Use provider registration first, or sign in normally and link it from account settings.'**
  String get thisGoogleAccountIsNotLinked;

  /// No description provided for @thisHidesArg1FromRoutingAnd.
  ///
  /// In en, this message translates to:
  /// **'This hides \"{arg1}\" from routing and selection.'**
  String thisHidesArg1FromRoutingAnd(Object? arg1);

  /// No description provided for @thisIntegrationCurrentlySupportsOneConnected.
  ///
  /// In en, this message translates to:
  /// **'This integration currently supports one connected account per agent. Re-open setup to replace it.'**
  String get thisIntegrationCurrentlySupportsOneConnected;

  /// No description provided for @thisIntegrationIsNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This integration is no longer available.'**
  String get thisIntegrationIsNoLongerAvailable;

  /// No description provided for @thisIntroIsDesignedForFull.
  ///
  /// In en, this message translates to:
  /// **'This intro is designed for full-screen landscape playback.'**
  String get thisIntroIsDesignedForFull;

  /// No description provided for @thisIsAManagedDeploymentIts.
  ///
  /// In en, this message translates to:
  /// **'This is a managed deployment. Its operator rolls out '**
  String get thisIsAManagedDeploymentIts;

  /// No description provided for @thisMayTakeAMoment.
  ///
  /// In en, this message translates to:
  /// **'This may take a moment.'**
  String get thisMayTakeAMoment;

  /// No description provided for @thisMcpServerIsNoLonger.
  ///
  /// In en, this message translates to:
  /// **'This MCP server is no longer configured.'**
  String get thisMcpServerIsNoLonger;

  /// No description provided for @thisMemoryWillBeRemovedPermanently.
  ///
  /// In en, this message translates to:
  /// **'This memory will be removed permanently.'**
  String get thisMemoryWillBeRemovedPermanently;

  /// No description provided for @thisNeoagentBuildIsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'This NeoAgent build is not configured to verify backend runtimes.'**
  String get thisNeoagentBuildIsNotConfigured;

  /// No description provided for @thisPermanentlyErasesAllOfYour.
  ///
  /// In en, this message translates to:
  /// **'This permanently erases all of your data and cannot be '**
  String get thisPermanentlyErasesAllOfYour;

  /// No description provided for @thisPermanentlyErasesTheAccountAnd.
  ///
  /// In en, this message translates to:
  /// **'This permanently erases the account and everything it owns: '**
  String get thisPermanentlyErasesTheAccountAnd;

  /// No description provided for @thisPersonAnywhere.
  ///
  /// In en, this message translates to:
  /// **'This person, anywhere'**
  String get thisPersonAnywhere;

  /// No description provided for @thisPersonInOneGroup.
  ///
  /// In en, this message translates to:
  /// **'This person, in one group'**
  String get thisPersonInOneGroup;

  /// No description provided for @thisQrLoginRequestExpiredGenerate.
  ///
  /// In en, this message translates to:
  /// **'This QR login request expired. Generate a new code and try again.'**
  String get thisQrLoginRequestExpiredGenerate;

  /// No description provided for @thisQrLoginRequestHasExpired.
  ///
  /// In en, this message translates to:
  /// **'this qr login request has expired'**
  String get thisQrLoginRequestHasExpired;

  /// No description provided for @thisQrLoginRequestIsStill.
  ///
  /// In en, this message translates to:
  /// **'This QR login request is still waiting for approval.'**
  String get thisQrLoginRequestIsStill;

  /// No description provided for @thisQrLoginRequestWasAlready.
  ///
  /// In en, this message translates to:
  /// **'This QR login request was already used.'**
  String get thisQrLoginRequestWasAlready;

  /// No description provided for @thisRemovesTheHomeAssistantSetup.
  ///
  /// In en, this message translates to:
  /// **'This removes the Home Assistant setup and connected instance for this agent.'**
  String get thisRemovesTheHomeAssistantSetup;

  /// No description provided for @thisRemovesTheNeorecallBackendUrl.
  ///
  /// In en, this message translates to:
  /// **'This removes the NeoRecall backend URL and all connected NeoRecall accounts for this agent.'**
  String get thisRemovesTheNeorecallBackendUrl;

  /// No description provided for @thisRemovesTheNextcloudUrlAnd.
  ///
  /// In en, this message translates to:
  /// **'This removes the Nextcloud URL and all connected Nextcloud accounts for this agent.'**
  String get thisRemovesTheNextcloudUrlAnd;

  /// No description provided for @thisRemovesTheTrelloSetupAnd.
  ///
  /// In en, this message translates to:
  /// **'This removes the Trello setup and connected accounts for this agent.'**
  String get thisRemovesTheTrelloSetupAnd;

  /// No description provided for @thisRequiresAnAuthenticatedSessionOn.
  ///
  /// In en, this message translates to:
  /// **'This requires an authenticated session on the same NeoAgent server.'**
  String get thisRequiresAnAuthenticatedSessionOn;

  /// No description provided for @thisRunDidNotProduceA.
  ///
  /// In en, this message translates to:
  /// **'This run did not produce a user-facing response.'**
  String get thisRunDidNotProduceA;

  /// No description provided for @thisRunHasNoRecordedStep.
  ///
  /// In en, this message translates to:
  /// **'This run has no recorded step data.'**
  String get thisRunHasNoRecordedStep;

  /// No description provided for @thisServer.
  ///
  /// In en, this message translates to:
  /// **'this server.'**
  String get thisServer;

  /// No description provided for @thisServerIsAlreadySetUp.
  ///
  /// In en, this message translates to:
  /// **'This server is already set up. Sign in with an existing account.'**
  String get thisServerIsAlreadySetUp;

  /// No description provided for @thisServerReportsNoProviderSettings.
  ///
  /// In en, this message translates to:
  /// **'This server reports no provider settings.'**
  String get thisServerReportsNoProviderSettings;

  /// No description provided for @thisSkillIsNoLongerIn.
  ///
  /// In en, this message translates to:
  /// **'This skill is no longer in the store.'**
  String get thisSkillIsNoLongerIn;

  /// No description provided for @thisSkillIsNoLongerInstalled.
  ///
  /// In en, this message translates to:
  /// **'This skill is no longer installed.'**
  String get thisSkillIsNoLongerInstalled;

  /// No description provided for @thisTaskHasNoCompletedRun.
  ///
  /// In en, this message translates to:
  /// **'This task has no completed run yet, so it still starts at the '**
  String get thisTaskHasNoCompletedRun;

  /// No description provided for @thisTaskWillOnlyRunWhen.
  ///
  /// In en, this message translates to:
  /// **'This task will only run when you press Run Now.'**
  String get thisTaskWillOnlyRunWhen;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @thisWillImportTheResponseInto.
  ///
  /// In en, this message translates to:
  /// **'This will import the response into {arg1}.'**
  String thisWillImportTheResponseInto(Object? arg1);

  /// No description provided for @thisWillRemoveArg1.
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{arg1}\".'**
  String thisWillRemoveArg1(Object? arg1);

  /// No description provided for @thisWillRemoveArg1FromThe.
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{arg1}\" from the server list.'**
  String thisWillRemoveArg1FromThe(Object? arg1);

  /// No description provided for @tickTheModelsThisPlanMay.
  ///
  /// In en, this message translates to:
  /// **'Tick the models this plan may use. Leave all unticked to allow '**
  String get tickTheModelsThisPlanMay;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @time2.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get time2;

  /// No description provided for @timeZone.
  ///
  /// In en, this message translates to:
  /// **'time zone'**
  String get timeZone;

  /// No description provided for @timeZone2.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timeZone2;

  /// No description provided for @timedOutArg1.
  ///
  /// In en, this message translates to:
  /// **'Timed out{arg1}'**
  String timedOutArg1(Object? arg1);

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @timelineFeed.
  ///
  /// In en, this message translates to:
  /// **'Timeline feed'**
  String get timelineFeed;

  /// No description provided for @timezoneCouldNotListTimeZones.
  ///
  /// In en, this message translates to:
  /// **'[TimeZone] Could not list time zones: {arg1}'**
  String timezoneCouldNotListTimeZones(Object? arg1);

  /// No description provided for @timezoneCouldNotReadTheDevice.
  ///
  /// In en, this message translates to:
  /// **'[TimeZone] Could not read the device time zone: {arg1}'**
  String timezoneCouldNotReadTheDevice(Object? arg1);

  /// No description provided for @timezoneCouldNotSaveTheDevice.
  ///
  /// In en, this message translates to:
  /// **'[TimeZone] Could not save the device time zone: {arg1}'**
  String timezoneCouldNotSaveTheDevice(Object? arg1);

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'TITLE'**
  String get title;

  /// No description provided for @toArg1.
  ///
  /// In en, this message translates to:
  /// **'to {arg1}'**
  String toArg1(Object? arg1);

  /// No description provided for @toUseTheServerDefault.
  ///
  /// In en, this message translates to:
  /// **'to use the server default.'**
  String get toUseTheServerDefault;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tokenBudgetForArg1LeaveA.
  ///
  /// In en, this message translates to:
  /// **'Token budget for @{arg1}. Leave a field empty '**
  String tokenBudgetForArg1LeaveA(Object? arg1);

  /// No description provided for @tokenBudgetForEveryAccountWithout.
  ///
  /// In en, this message translates to:
  /// **'Token budget for every account without its own override. Leave a '**
  String get tokenBudgetForEveryAccountWithout;

  /// No description provided for @tokenBudgetLimit4HourWeekly.
  ///
  /// In en, this message translates to:
  /// **'token budget limit 4 hour weekly quota user'**
  String get tokenBudgetLimit4HourWeekly;

  /// No description provided for @tokenBudgetLimit4HourWeekly2.
  ///
  /// In en, this message translates to:
  /// **'token budget limit 4 hour weekly quota global'**
  String get tokenBudgetLimit4HourWeekly2;

  /// No description provided for @tokenLimitsMustBeWholeNumbers.
  ///
  /// In en, this message translates to:
  /// **'Token limits must be whole numbers, or blank for the default.'**
  String get tokenLimitsMustBeWholeNumbers;

  /// No description provided for @tokenUsageUnavailableOnThisServer.
  ///
  /// In en, this message translates to:
  /// **'Token usage unavailable on this server version.'**
  String get tokenUsageUnavailableOnThisServer;

  /// No description provided for @tokensAnyAccountMayUseIn.
  ///
  /// In en, this message translates to:
  /// **'Tokens any account may use in 4 hours.'**
  String get tokensAnyAccountMayUseIn;

  /// No description provided for @tokensAnyAccountMayUseIn2.
  ///
  /// In en, this message translates to:
  /// **'Tokens any account may use in 7 days.'**
  String get tokensAnyAccountMayUseIn2;

  /// No description provided for @tokensPerDay.
  ///
  /// In en, this message translates to:
  /// **'Tokens per day'**
  String get tokensPerDay;

  /// No description provided for @tokensPerRun.
  ///
  /// In en, this message translates to:
  /// **'Tokens per run'**
  String get tokensPerRun;

  /// No description provided for @tokensToday.
  ///
  /// In en, this message translates to:
  /// **'Tokens today'**
  String get tokensToday;

  /// No description provided for @tokensUsed.
  ///
  /// In en, this message translates to:
  /// **' tokens used'**
  String get tokensUsed;

  /// No description provided for @tomorrowKeepItShortAndSend.
  ///
  /// In en, this message translates to:
  /// **'tomorrow. Keep it short and send it to me.'**
  String get tomorrowKeepItShortAndSend;

  /// No description provided for @tomorrowPrep.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow prep'**
  String get tomorrowPrep;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'too many attempts'**
  String get tooManyAttempts;

  /// No description provided for @tooManySignInAttemptsPlease.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-in attempts. Please wait and try again.'**
  String get tooManySignInAttemptsPlease;

  /// No description provided for @tool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get tool;

  /// No description provided for @toolApproval.
  ///
  /// In en, this message translates to:
  /// **'Tool Approval'**
  String get toolApproval;

  /// No description provided for @toolApprovalRequired.
  ///
  /// In en, this message translates to:
  /// **'Tool approval required'**
  String get toolApprovalRequired;

  /// No description provided for @toolCompleted.
  ///
  /// In en, this message translates to:
  /// **'Tool completed'**
  String get toolCompleted;

  /// No description provided for @toolFailed.
  ///
  /// In en, this message translates to:
  /// **'Tool failed'**
  String get toolFailed;

  /// No description provided for @toolPermissions.
  ///
  /// In en, this message translates to:
  /// **'Tool Permissions'**
  String get toolPermissions;

  /// No description provided for @toolStarted.
  ///
  /// In en, this message translates to:
  /// **'Tool started'**
  String get toolStarted;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @toolsNotBuiltIntoNeoagentIncluding.
  ///
  /// In en, this message translates to:
  /// **'Tools not built into NeoAgent, including connected MCP servers and custom tool providers.'**
  String get toolsNotBuiltIntoNeoagentIncluding;

  /// No description provided for @toolsOfferedArg1.
  ///
  /// In en, this message translates to:
  /// **'Tools offered ({arg1})'**
  String toolsOfferedArg1(Object? arg1);

  /// No description provided for @toolsTheManagedAccountMayUse.
  ///
  /// In en, this message translates to:
  /// **'Tools the managed account may use'**
  String get toolsTheManagedAccountMayUse;

  /// No description provided for @topUsers.
  ///
  /// In en, this message translates to:
  /// **'Top users'**
  String get topUsers;

  /// No description provided for @topUsersAndRecentRuns.
  ///
  /// In en, this message translates to:
  /// **'Top users and recent runs'**
  String get topUsersAndRecentRuns;

  /// No description provided for @totalArg1TokensAcrossArg2Runs.
  ///
  /// In en, this message translates to:
  /// **'Total: {arg1} tokens across {arg2} runs'**
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2);

  /// No description provided for @totalRuns.
  ///
  /// In en, this message translates to:
  /// **'Total runs'**
  String get totalRuns;

  /// No description provided for @totalTokens.
  ///
  /// In en, this message translates to:
  /// **'Total tokens'**
  String get totalTokens;

  /// No description provided for @totalUsers.
  ///
  /// In en, this message translates to:
  /// **'Total users'**
  String get totalUsers;

  /// No description provided for @transcript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcript;

  /// No description provided for @transcript2.
  ///
  /// In en, this message translates to:
  /// **'TRANSCRIPT'**
  String get transcript2;

  /// No description provided for @transcriptionFailedArg1.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed: {arg1}'**
  String transcriptionFailedArg1(Object? arg1);

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @trelloApiKey.
  ///
  /// In en, this message translates to:
  /// **'Trello API Key'**
  String get trelloApiKey;

  /// No description provided for @trelloApiKeyIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Trello API Key is required.'**
  String get trelloApiKeyIsRequired;

  /// No description provided for @trelloSetup.
  ///
  /// In en, this message translates to:
  /// **'Trello Setup'**
  String get trelloSetup;

  /// No description provided for @triggerType.
  ///
  /// In en, this message translates to:
  /// **'Trigger Type'**
  String get triggerType;

  /// No description provided for @tryABroaderSearchLikeModels.
  ///
  /// In en, this message translates to:
  /// **'Try a broader search like models, browser, or voice.'**
  String get tryABroaderSearchLikeModels;

  /// No description provided for @tryAProviderNameEmailLimits.
  ///
  /// In en, this message translates to:
  /// **'Try a provider name, “email”, “limits”, “update” or “logs”.'**
  String get tryAProviderNameEmailLimits;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @tryAgainIfThisKeepsHappening.
  ///
  /// In en, this message translates to:
  /// **'Try again. If this keeps happening, run NeoAgent Doctor to check the computer runtime.'**
  String get tryAgainIfThisKeepsHappening;

  /// No description provided for @tryAgainInAMoment.
  ///
  /// In en, this message translates to:
  /// **'Try again in a moment.'**
  String get tryAgainInAMoment;

  /// No description provided for @tryAgainOrRunNeoagentDoctor.
  ///
  /// In en, this message translates to:
  /// **'Try again or run NeoAgent Doctor.'**
  String get tryAgainOrRunNeoagentDoctor;

  /// No description provided for @tryAnotherSearchConnectAMessaging.
  ///
  /// In en, this message translates to:
  /// **'Try another search, connect a messaging platform, or enter a destination ID manually.'**
  String get tryAnotherSearchConnectAMessaging;

  /// No description provided for @turnAGroupOnIfArg1.
  ///
  /// In en, this message translates to:
  /// **'Turn a group on if {arg1} should also read messages that do not tag it.'**
  String turnAGroupOnIfArg1(Object? arg1);

  /// No description provided for @turnOffComputer.
  ///
  /// In en, this message translates to:
  /// **'Turn off computer'**
  String get turnOffComputer;

  /// No description provided for @turnOffOnlyForAMail.
  ///
  /// In en, this message translates to:
  /// **'Turn off only for a mail server with a self-signed certificate.'**
  String get turnOffOnlyForAMail;

  /// No description provided for @turnOnIfSignalShouldKeep.
  ///
  /// In en, this message translates to:
  /// **'Turn on if Signal should keep looking for incoming chats.'**
  String get turnOnIfSignalShouldKeep;

  /// No description provided for @turnTaking.
  ///
  /// In en, this message translates to:
  /// **'turn taking'**
  String get turnTaking;

  /// No description provided for @turnTakingModel.
  ///
  /// In en, this message translates to:
  /// **'Turn-taking model'**
  String get turnTakingModel;

  /// No description provided for @turnTakingOff.
  ///
  /// In en, this message translates to:
  /// **'Turn-taking off'**
  String get turnTakingOff;

  /// No description provided for @turnThisOffToKeepThis.
  ///
  /// In en, this message translates to:
  /// **'Turn this off to keep this agent fully separate from other agents.'**
  String get turnThisOffToKeepThis;

  /// No description provided for @turnedOffByArg1.
  ///
  /// In en, this message translates to:
  /// **'Turned off by {arg1}'**
  String turnedOffByArg1(Object? arg1);

  /// No description provided for @turnedOffByArg1WhoManages.
  ///
  /// In en, this message translates to:
  /// **'Turned off by {arg1}, who manages this account. '**
  String turnedOffByArg1WhoManages(Object? arg1);

  /// No description provided for @turnedOffForYouByArg1.
  ///
  /// In en, this message translates to:
  /// **'Turned off for you by {arg1} — only they can change it'**
  String turnedOffForYouByArg1(Object? arg1);

  /// No description provided for @turnedOffForYouSoYou.
  ///
  /// In en, this message translates to:
  /// **'Turned off for you, so you can’t hand it out'**
  String get turnedOffForYouSoYou;

  /// No description provided for @turnedOnForEveryAgentBy.
  ///
  /// In en, this message translates to:
  /// **'Turned on for every agent by your server admin.'**
  String get turnedOnForEveryAgentBy;

  /// No description provided for @twitchChatOverIrc.
  ///
  /// In en, this message translates to:
  /// **'Twitch chat over IRC'**
  String get twitchChatOverIrc;

  /// No description provided for @twoFactorAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twoFactorAuthentication;

  /// No description provided for @twoFactorChallengeExpired.
  ///
  /// In en, this message translates to:
  /// **'two-factor challenge expired'**
  String get twoFactorChallengeExpired;

  /// No description provided for @twoFactorCode.
  ///
  /// In en, this message translates to:
  /// **'two-factor code'**
  String get twoFactorCode;

  /// No description provided for @twoFactorSignInCompletedBut.
  ///
  /// In en, this message translates to:
  /// **'Two-factor sign-in completed, but NeoAgent could not keep the browser session. Please sign in again.'**
  String get twoFactorSignInCompletedBut;

  /// No description provided for @twoStepLoginOnlyIfEnabled.
  ///
  /// In en, this message translates to:
  /// **'Two-step login (only if enabled)'**
  String get twoStepLoginOnlyIfEnabled;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @typeArg1ToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {arg1} to confirm'**
  String typeArg1ToConfirm(Object? arg1);

  /// No description provided for @typeTextIsNotSupportedOn.
  ///
  /// In en, this message translates to:
  /// **'type text is not supported on this platform.'**
  String get typeTextIsNotSupportedOn;

  /// No description provided for @typedInTheBrowser.
  ///
  /// In en, this message translates to:
  /// **'Typed in the browser'**
  String get typedInTheBrowser;

  /// No description provided for @typedText.
  ///
  /// In en, this message translates to:
  /// **'Typed text'**
  String get typedText;

  /// No description provided for @uCreatedAtULastLogin.
  ///
  /// In en, this message translates to:
  /// **'       u.created_at, u.last_login,\n'**
  String get uCreatedAtULastLogin;

  /// No description provided for @unableToLocateAJavaRuntime.
  ///
  /// In en, this message translates to:
  /// **'unable to locate a java runtime'**
  String get unableToLocateAJavaRuntime;

  /// No description provided for @unableToOpenTimeSettingsOn.
  ///
  /// In en, this message translates to:
  /// **'Unable to open time settings on this build.'**
  String get unableToOpenTimeSettingsOn;

  /// No description provided for @unableToOpenWiFiSettings.
  ///
  /// In en, this message translates to:
  /// **'Unable to open Wi-Fi settings on this build.'**
  String get unableToOpenWiFiSettings;

  /// No description provided for @unableToPersistTheSelectedDesktop.
  ///
  /// In en, this message translates to:
  /// **'Unable to persist the selected desktop display.'**
  String get unableToPersistTheSelectedDesktop;

  /// No description provided for @unclearWhoItWasFor.
  ///
  /// In en, this message translates to:
  /// **'Unclear who it was for'**
  String get unclearWhoItWasFor;

  /// No description provided for @undoneTypeYourUsernameToConfirm.
  ///
  /// In en, this message translates to:
  /// **'undone. Type your username to confirm.'**
  String get undoneTypeYourUsernameToConfirm;

  /// No description provided for @unknownAccount.
  ///
  /// In en, this message translates to:
  /// **'Unknown account'**
  String get unknownAccount;

  /// No description provided for @unknownAgent.
  ///
  /// In en, this message translates to:
  /// **'Unknown agent'**
  String get unknownAgent;

  /// No description provided for @unknownBrowser.
  ///
  /// In en, this message translates to:
  /// **'Unknown browser'**
  String get unknownBrowser;

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get unknownDevice;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'unknown error'**
  String get unknownError;

  /// No description provided for @unknownLocalComputerPermission.
  ///
  /// In en, this message translates to:
  /// **'Unknown local computer permission.'**
  String get unknownLocalComputerPermission;

  /// No description provided for @unknownLocation.
  ///
  /// In en, this message translates to:
  /// **'Unknown location'**
  String get unknownLocation;

  /// No description provided for @unknownPlan.
  ///
  /// In en, this message translates to:
  /// **'Unknown plan'**
  String get unknownPlan;

  /// No description provided for @unknownPublishTime.
  ///
  /// In en, this message translates to:
  /// **'Unknown publish time'**
  String get unknownPublishTime;

  /// No description provided for @unknownSize.
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get unknownSize;

  /// No description provided for @unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// No description provided for @unreadOnly.
  ///
  /// In en, this message translates to:
  /// **'Unread Only'**
  String get unreadOnly;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @unsupportedDesktopCompanionCommandArg1.
  ///
  /// In en, this message translates to:
  /// **'Unsupported desktop companion command: {arg1}'**
  String unsupportedDesktopCompanionCommandArg1(Object? arg1);

  /// No description provided for @unsupportedMethodArg1.
  ///
  /// In en, this message translates to:
  /// **'Unsupported method: {arg1}'**
  String unsupportedMethodArg1(Object? arg1);

  /// No description provided for @untitledRunEvent.
  ///
  /// In en, this message translates to:
  /// **'Untitled run event'**
  String get untitledRunEvent;

  /// No description provided for @unusualSignInAlerts.
  ///
  /// In en, this message translates to:
  /// **'Unusual sign-in alerts'**
  String get unusualSignInAlerts;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateArg1.
  ///
  /// In en, this message translates to:
  /// **'Update {arg1}'**
  String updateArg1(Object? arg1);

  /// No description provided for @updateCoreMemoryEntriesFromThe.
  ///
  /// In en, this message translates to:
  /// **'Update core memory entries from the import.'**
  String get updateCoreMemoryEntriesFromThe;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'Update ready'**
  String get updateReady;

  /// No description provided for @updateSetup.
  ///
  /// In en, this message translates to:
  /// **'Update Setup'**
  String get updateSetup;

  /// No description provided for @updateTheAccessListToAllow.
  ///
  /// In en, this message translates to:
  /// **'Update the access list to allow replies.'**
  String get updateTheAccessListToAllow;

  /// No description provided for @updateTheServer.
  ///
  /// In en, this message translates to:
  /// **'Update the server?'**
  String get updateTheServer;

  /// No description provided for @updateTheServer2.
  ///
  /// In en, this message translates to:
  /// **'Update the server'**
  String get updateTheServer2;

  /// No description provided for @updateTheTimeZoneAutomaticallyFrom.
  ///
  /// In en, this message translates to:
  /// **'Update the time zone automatically from the device you are using.'**
  String get updateTheTimeZoneAutomaticallyFrom;

  /// No description provided for @updatedArg1.
  ///
  /// In en, this message translates to:
  /// **'updated {arg1}'**
  String updatedArg1(Object? arg1);

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @updatesAreNotConfiguredForThis.
  ///
  /// In en, this message translates to:
  /// **'Updates are not configured for this build.'**
  String get updatesAreNotConfiguredForThis;

  /// No description provided for @updatesSoSelfUpdateAndChannel.
  ///
  /// In en, this message translates to:
  /// **'updates, so self-update and channel changes are off here.'**
  String get updatesSoSelfUpdateAndChannel;

  /// No description provided for @upgradeUpdateNowReleaseChannelStable.
  ///
  /// In en, this message translates to:
  /// **'upgrade update now release channel stable beta'**
  String get upgradeUpdateNowReleaseChannelStable;

  /// No description provided for @usageAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Usage analytics'**
  String get usageAnalytics;

  /// No description provided for @usageAndHealthSignalsThatHelp.
  ///
  /// In en, this message translates to:
  /// **'Usage and health signals that help explain current runtime behavior without digging through logs first.'**
  String get usageAndHealthSignalsThatHelp;

  /// No description provided for @usageFullyResetsInArg1.
  ///
  /// In en, this message translates to:
  /// **'Usage fully resets in {arg1}'**
  String usageFullyResetsInArg1(Object? arg1);

  /// No description provided for @usageLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'usage leaderboard'**
  String get usageLeaderboard;

  /// No description provided for @usageLimits.
  ///
  /// In en, this message translates to:
  /// **'Usage & Limits'**
  String get usageLimits;

  /// No description provided for @usageLimits2.
  ///
  /// In en, this message translates to:
  /// **'Usage & limits'**
  String get usageLimits2;

  /// No description provided for @usageThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'Usage this period'**
  String get usageThisPeriod;

  /// No description provided for @use8CharactersLongerPassphrasesWork.
  ///
  /// In en, this message translates to:
  /// **'Use 8+ characters. Longer passphrases work well.'**
  String get use8CharactersLongerPassphrasesWork;

  /// No description provided for @useADateAndTimeFor.
  ///
  /// In en, this message translates to:
  /// **'Use a date and time, for example 2026-07-03T09:00:00.'**
  String get useADateAndTimeFor;

  /// No description provided for @useANamePhoneNumberOr.
  ///
  /// In en, this message translates to:
  /// **'Use a name, phone number, or chat ID.'**
  String get useANamePhoneNumberOr;

  /// No description provided for @useANeorecallUrlTheNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Use a NeoRecall URL the NeoAgent server can reach. NeoAgent\'\'s PUBLIC_URL must also be reachable from this browser for the OAuth callback.'**
  String get useANeorecallUrlTheNeoagent;

  /// No description provided for @useANewPasswordWithAt.
  ///
  /// In en, this message translates to:
  /// **'Use a new password with at least 8 characters.'**
  String get useANewPasswordWithAt;

  /// No description provided for @useANextcloudUrlTheNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Use a Nextcloud URL the NeoAgent server can reach, for example https://cloud.example.com.'**
  String get useANextcloudUrlTheNeoagent;

  /// No description provided for @useAPasswordWithAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Use a password with at least 8 characters.'**
  String get useAPasswordWithAtLeast;

  /// No description provided for @useASecureConnectionTls.
  ///
  /// In en, this message translates to:
  /// **'Use a secure connection (TLS)'**
  String get useASecureConnectionTls;

  /// No description provided for @useAnAuthenticatorAppSuchAs.
  ///
  /// In en, this message translates to:
  /// **'Use an authenticator app such as Authy, 1Password, or Google Authenticator.'**
  String get useAnAuthenticatorAppSuchAs;

  /// No description provided for @useAtLeast1Vcpu.
  ///
  /// In en, this message translates to:
  /// **'Use at least 1 vCPU.'**
  String get useAtLeast1Vcpu;

  /// No description provided for @useAtLeast8Characters.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get useAtLeast8Characters;

  /// No description provided for @useDefault.
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get useDefault;

  /// No description provided for @useDefaultChannel.
  ///
  /// In en, this message translates to:
  /// **'Use default channel'**
  String get useDefaultChannel;

  /// No description provided for @useDefaultNeoagentWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Use default (NeoAgent Workspace)'**
  String get useDefaultNeoagentWorkspace;

  /// No description provided for @useFor.
  ///
  /// In en, this message translates to:
  /// **'Use for'**
  String get useFor;

  /// No description provided for @useManualDestination.
  ///
  /// In en, this message translates to:
  /// **'Use manual destination'**
  String get useManualDestination;

  /// No description provided for @useOrDoTheSameFor.
  ///
  /// In en, this message translates to:
  /// **'use, or do the same for your teammates.'**
  String get useOrDoTheSameFor;

  /// No description provided for @usePerCategorySettingsBelow.
  ///
  /// In en, this message translates to:
  /// **'Use per-category settings below.'**
  String get usePerCategorySettingsBelow;

  /// No description provided for @useSettingsDefaultArg1.
  ///
  /// In en, this message translates to:
  /// **'Use Settings default ({arg1})'**
  String useSettingsDefaultArg1(Object? arg1);

  /// No description provided for @useTheServerOnThisComputer.
  ///
  /// In en, this message translates to:
  /// **'Use the server on this computer'**
  String get useTheServerOnThisComputer;

  /// No description provided for @useTheseForContextIfA.
  ///
  /// In en, this message translates to:
  /// **'Use these for context. If a local URI is not directly accessible from the server, ask me to provide the file through an accessible workspace.'**
  String get useTheseForContextIfA;

  /// No description provided for @useThisForOrchestratorAgentsLeave.
  ///
  /// In en, this message translates to:
  /// **'Use this for orchestrator agents. Leave off for isolated work bots that should finish direct messages themselves.'**
  String get useThisForOrchestratorAgentsLeave;

  /// No description provided for @useTlsFromTheStartOf.
  ///
  /// In en, this message translates to:
  /// **'Use TLS from the start of the connection, usually on port 465.'**
  String get useTlsFromTheStartOf;

  /// No description provided for @useYourOwnApiKeyFor.
  ///
  /// In en, this message translates to:
  /// **'Use your own API key for a provider, or connect a custom '**
  String get useYourOwnApiKeyFor;

  /// No description provided for @usedByEveryAccountOnThis.
  ///
  /// In en, this message translates to:
  /// **'Used by every account on this server that has no key '**
  String get usedByEveryAccountOnThis;

  /// No description provided for @usedToVerifyThatIncomingSlack.
  ///
  /// In en, this message translates to:
  /// **'Used to verify that incoming Slack events are genuine.'**
  String get usedToVerifyThatIncomingSlack;

  /// No description provided for @userSummary.
  ///
  /// In en, this message translates to:
  /// **'User summary'**
  String get userSummary;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @usernameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get usernameOrEmail;

  /// No description provided for @usersPeopleSearchEmailUsernameAdmin.
  ///
  /// In en, this message translates to:
  /// **'users people search email username admin badge managed team'**
  String get usersPeopleSearchEmailUsernameAdmin;

  /// No description provided for @usesTheChatModelConfiguredIn.
  ///
  /// In en, this message translates to:
  /// **'Uses the chat model configured in Settings'**
  String get usesTheChatModelConfiguredIn;

  /// No description provided for @usingTheInstalledNeoagentRuntime.
  ///
  /// In en, this message translates to:
  /// **'Using the installed NeoAgent runtime'**
  String get usingTheInstalledNeoagentRuntime;

  /// No description provided for @usually0ForThePrimaryChannel.
  ///
  /// In en, this message translates to:
  /// **'Usually 0 for the primary channel.'**
  String get usually0ForThePrimaryChannel;

  /// No description provided for @usuallyLooksLikeBotMatrixOrg.
  ///
  /// In en, this message translates to:
  /// **'Usually looks like @bot:matrix.org'**
  String get usuallyLooksLikeBotMatrixOrg;

  /// No description provided for @validEmail.
  ///
  /// In en, this message translates to:
  /// **'valid email'**
  String get validEmail;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @vaultLocked.
  ///
  /// In en, this message translates to:
  /// **'Vault locked'**
  String get vaultLocked;

  /// No description provided for @vaultOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Vault operation failed.'**
  String get vaultOperationFailed;

  /// No description provided for @vectorRankArg1.
  ///
  /// In en, this message translates to:
  /// **'Vector Rank: {arg1}'**
  String vectorRankArg1(Object? arg1);

  /// No description provided for @verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get verification;

  /// No description provided for @verificationArg1.
  ///
  /// In en, this message translates to:
  /// **'Verification: {arg1}'**
  String verificationArg1(Object? arg1);

  /// No description provided for @verificationArg12.
  ///
  /// In en, this message translates to:
  /// **'verification: {arg1}'**
  String verificationArg12(Object? arg1);

  /// No description provided for @verificationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Verification completed.'**
  String get verificationCompleted;

  /// No description provided for @verificationStatusArg1.
  ///
  /// In en, this message translates to:
  /// **'Verification status: {arg1}'**
  String verificationStatusArg1(Object? arg1);

  /// No description provided for @verifiedTheResult.
  ///
  /// In en, this message translates to:
  /// **'Verified the result'**
  String get verifiedTheResult;

  /// No description provided for @verifyingTheDownloadedRuntime.
  ///
  /// In en, this message translates to:
  /// **'Verifying the downloaded runtime'**
  String get verifyingTheDownloadedRuntime;

  /// No description provided for @versionAndUptime.
  ///
  /// In en, this message translates to:
  /// **'Version and uptime'**
  String get versionAndUptime;

  /// No description provided for @versionArg1.
  ///
  /// In en, this message translates to:
  /// **'Version {arg1}'**
  String versionArg1(Object? arg1);

  /// No description provided for @versionArg1IsInstalledButArg2.
  ///
  /// In en, this message translates to:
  /// **'Version {arg1} is installed, but {arg2} is still running.'**
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2);

  /// No description provided for @videoLinks.
  ///
  /// In en, this message translates to:
  /// **'Video links'**
  String get videoLinks;

  /// No description provided for @viewDesktop.
  ///
  /// In en, this message translates to:
  /// **'View desktop'**
  String get viewDesktop;

  /// No description provided for @viewLastRun.
  ///
  /// In en, this message translates to:
  /// **'View last run'**
  String get viewLastRun;

  /// No description provided for @viewLogs.
  ///
  /// In en, this message translates to:
  /// **'View logs'**
  String get viewLogs;

  /// No description provided for @viewPlans.
  ///
  /// In en, this message translates to:
  /// **'View plans'**
  String get viewPlans;

  /// No description provided for @vmImageMemoryCpuQemuRuntime.
  ///
  /// In en, this message translates to:
  /// **'vm image memory cpu qemu runtime'**
  String get vmImageMemoryCpuQemuRuntime;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @voiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Voice assistant'**
  String get voiceAssistant;

  /// No description provided for @voiceCall.
  ///
  /// In en, this message translates to:
  /// **'VOICE CALL'**
  String get voiceCall;

  /// No description provided for @voiceCall2.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get voiceCall2;

  /// No description provided for @voiceCallGptLiveGeminiLive.
  ///
  /// In en, this message translates to:
  /// **'voice call gpt-live gemini live model speech realtime'**
  String get voiceCallGptLiveGeminiLive;

  /// No description provided for @voiceCallsRunOnALive.
  ///
  /// In en, this message translates to:
  /// **'Voice calls run on a live speech-to-speech model with the same persona, memory and chat history as NeoAgent. It answers right away and hands real work to the normal agent, which keeps running in the background.'**
  String get voiceCallsRunOnALive;

  /// No description provided for @voiceNoteSpeechTranscriptionApiKey.
  ///
  /// In en, this message translates to:
  /// **'voice note speech transcription api key'**
  String get voiceNoteSpeechTranscriptionApiKey;

  /// No description provided for @voiceNotesAndDictation.
  ///
  /// In en, this message translates to:
  /// **'Voice notes and dictation'**
  String get voiceNotesAndDictation;

  /// No description provided for @voicePlaybackIsUnavailableOnThis.
  ///
  /// In en, this message translates to:
  /// **'Voice playback is unavailable on this device.'**
  String get voicePlaybackIsUnavailableOnThis;

  /// No description provided for @voiceReplyModel.
  ///
  /// In en, this message translates to:
  /// **'Voice reply model'**
  String get voiceReplyModel;

  /// No description provided for @waitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval: '**
  String get waitingForApproval;

  /// No description provided for @waitingForCode.
  ///
  /// In en, this message translates to:
  /// **'Waiting for code'**
  String get waitingForCode;

  /// No description provided for @waitingForInput.
  ///
  /// In en, this message translates to:
  /// **'Waiting for input'**
  String get waitingForInput;

  /// No description provided for @waitingForServerOrFlutterLog.
  ///
  /// In en, this message translates to:
  /// **'Waiting for server or Flutter log output…'**
  String get waitingForServerOrFlutterLog;

  /// No description provided for @waitingForTaskEvents.
  ///
  /// In en, this message translates to:
  /// **'Waiting for task events...'**
  String get waitingForTaskEvents;

  /// No description provided for @waitingForYou.
  ///
  /// In en, this message translates to:
  /// **'waiting for you'**
  String get waitingForYou;

  /// No description provided for @wantedAReplyFromArg1.
  ///
  /// In en, this message translates to:
  /// **'Wanted a reply from {arg1}'**
  String wantedAReplyFromArg1(Object? arg1);

  /// No description provided for @wantsToTalkWithYouArg1.
  ///
  /// In en, this message translates to:
  /// **'Wants to talk with you · {arg1}s'**
  String wantsToTalkWithYouArg1(Object? arg1);

  /// No description provided for @watchItLive.
  ///
  /// In en, this message translates to:
  /// **'Watch it live'**
  String get watchItLive;

  /// No description provided for @weak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get weak;

  /// No description provided for @weatherCalendarAndPrioritiesBeforeYour.
  ///
  /// In en, this message translates to:
  /// **'Weather, calendar and priorities before your day starts.'**
  String get weatherCalendarAndPrioritiesBeforeYour;

  /// No description provided for @weatherEvent.
  ///
  /// In en, this message translates to:
  /// **'Weather Event'**
  String get weatherEvent;

  /// No description provided for @web.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get web;

  /// No description provided for @webBrowser.
  ///
  /// In en, this message translates to:
  /// **'Web browser'**
  String get webBrowser;

  /// No description provided for @webSearchApiKey.
  ///
  /// In en, this message translates to:
  /// **'web search api key'**
  String get webSearchApiKey;

  /// No description provided for @webhookOrRestChannelPosting.
  ///
  /// In en, this message translates to:
  /// **'Webhook or REST channel posting'**
  String get webhookOrRestChannelPosting;

  /// No description provided for @webhookSecret.
  ///
  /// In en, this message translates to:
  /// **'Webhook secret'**
  String get webhookSecret;

  /// No description provided for @webhookSigningSecret.
  ///
  /// In en, this message translates to:
  /// **'Webhook signing secret'**
  String get webhookSigningSecret;

  /// No description provided for @webhookUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Webhook URL copied'**
  String get webhookUrlCopied;

  /// No description provided for @weekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get weekdays;

  /// No description provided for @weekdays0730.
  ///
  /// In en, this message translates to:
  /// **'Weekdays · 07:30'**
  String get weekdays0730;

  /// No description provided for @weekdays1800.
  ///
  /// In en, this message translates to:
  /// **'Weekdays · 18:00'**
  String get weekdays1800;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @weeklyLimitArg1.
  ///
  /// In en, this message translates to:
  /// **'Weekly limit {arg1}'**
  String weeklyLimitArg1(Object? arg1);

  /// No description provided for @weeklyLimitTokens.
  ///
  /// In en, this message translates to:
  /// **'Weekly limit (tokens)'**
  String get weeklyLimitTokens;

  /// No description provided for @weeklyReview.
  ///
  /// In en, this message translates to:
  /// **'Weekly review'**
  String get weeklyReview;

  /// No description provided for @weeklyTokenLimit.
  ///
  /// In en, this message translates to:
  /// **'Weekly token limit'**
  String get weeklyTokenLimit;

  /// No description provided for @weeklyTokens.
  ///
  /// In en, this message translates to:
  /// **'Weekly tokens'**
  String get weeklyTokens;

  /// No description provided for @weeklyUsage.
  ///
  /// In en, this message translates to:
  /// **'Weekly Usage'**
  String get weeklyUsage;

  /// No description provided for @weightArg1Records.
  ///
  /// In en, this message translates to:
  /// **'Weight {arg1} records'**
  String weightArg1Records(Object? arg1);

  /// No description provided for @welcomeToNeoagent.
  ///
  /// In en, this message translates to:
  /// **'WELCOME TO NEOAGENT'**
  String get welcomeToNeoagent;

  /// No description provided for @welcomeToNeoagent2.
  ///
  /// In en, this message translates to:
  /// **'Welcome to\nNeoAgent'**
  String get welcomeToNeoagent2;

  /// No description provided for @whatAreYouAdding.
  ///
  /// In en, this message translates to:
  /// **'What are you adding?'**
  String get whatAreYouAdding;

  /// No description provided for @whatIsOnTomorrow.
  ///
  /// In en, this message translates to:
  /// **'What is on tomorrow?'**
  String get whatIsOnTomorrow;

  /// No description provided for @whatShouldNeoagentLearn.
  ///
  /// In en, this message translates to:
  /// **'What should NeoAgent learn?'**
  String get whatShouldNeoagentLearn;

  /// No description provided for @whatShouldWeBuild.
  ///
  /// In en, this message translates to:
  /// **'What should we build?'**
  String get whatShouldWeBuild;

  /// No description provided for @whatYouAndNeoagentSayAppears.
  ///
  /// In en, this message translates to:
  /// **'What you and NeoAgent say appears here and in the chat.'**
  String get whatYouAndNeoagentSayAppears;

  /// No description provided for @whatsappPersonalMessageReceived.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Personal Message Received'**
  String get whatsappPersonalMessageReceived;

  /// No description provided for @whenOffOnlyExistingAccountsCan.
  ///
  /// In en, this message translates to:
  /// **'When off, only existing accounts can sign in. A '**
  String get whenOffOnlyExistingAccountsCan;

  /// No description provided for @whenYouChooseApprovedOnlyAdd.
  ///
  /// In en, this message translates to:
  /// **'When you choose approved only, add people or groups below.'**
  String get whenYouChooseApprovedOnlyAdd;

  /// No description provided for @whereCreatedAtDatetimeNow30.
  ///
  /// In en, this message translates to:
  /// **'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n'**
  String get whereCreatedAtDatetimeNow30;

  /// No description provided for @whereRStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'WHERE r.status = \'\'failed\'\'\n'**
  String get whereRStatusFailed;

  /// No description provided for @whereSRevokedAtIsNull.
  ///
  /// In en, this message translates to:
  /// **'WHERE s.revoked_at IS NULL\n'**
  String get whereSRevokedAtIsNull;

  /// No description provided for @whereThisAgentShouldSendReplies.
  ///
  /// In en, this message translates to:
  /// **'Where this agent should send replies.'**
  String get whereThisAgentShouldSendReplies;

  /// No description provided for @whileItWorks.
  ///
  /// In en, this message translates to:
  /// **'while it works.'**
  String get whileItWorks;

  /// No description provided for @whoCanMessage.
  ///
  /// In en, this message translates to:
  /// **'Who can message'**
  String get whoCanMessage;

  /// No description provided for @whoCanMessageOnArg1.
  ///
  /// In en, this message translates to:
  /// **'Who can message on {arg1}'**
  String whoCanMessageOnArg1(Object? arg1);

  /// No description provided for @whoCanSendArg1AOne.
  ///
  /// In en, this message translates to:
  /// **'Who can send {arg1} a one-to-one message.'**
  String whoCanSendArg1AOne(Object? arg1);

  /// No description provided for @whoCanTalkToArg1In.
  ///
  /// In en, this message translates to:
  /// **'Who can talk to {arg1} in a group, channel, or room.'**
  String whoCanTalkToArg1In(Object? arg1);

  /// No description provided for @whoManagesThisAccountTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'who manages this account turned off: '**
  String get whoManagesThisAccountTurnedOff;

  /// No description provided for @whoManagesWhom.
  ///
  /// In en, this message translates to:
  /// **'Who manages whom'**
  String get whoManagesWhom;

  /// No description provided for @whoeverAcceptsALinkJoinsYour.
  ///
  /// In en, this message translates to:
  /// **'Whoever accepts a link joins your team with only the tools it '**
  String get whoeverAcceptsALinkJoinsYour;

  /// No description provided for @wholeGroup.
  ///
  /// In en, this message translates to:
  /// **'Whole group'**
  String get wholeGroup;

  /// No description provided for @wholeGroups.
  ///
  /// In en, this message translates to:
  /// **'Whole groups'**
  String get wholeGroups;

  /// No description provided for @whyArg1RepliedOrStayedQuiet.
  ///
  /// In en, this message translates to:
  /// **'Why {arg1} replied or stayed quiet in {arg2} groups.'**
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2);

  /// No description provided for @windowsApp.
  ///
  /// In en, this message translates to:
  /// **'Windows app'**
  String get windowsApp;

  /// No description provided for @windowsNt.
  ///
  /// In en, this message translates to:
  /// **'windows nt'**
  String get windowsNt;

  /// No description provided for @workAccount.
  ///
  /// In en, this message translates to:
  /// **'Work account'**
  String get workAccount;

  /// No description provided for @workOnAProjectWithNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Work on a project with NeoAgent'**
  String get workOnAProjectWithNeoagent;

  /// No description provided for @workflowArg1.
  ///
  /// In en, this message translates to:
  /// **'Workflow: {arg1}'**
  String workflowArg1(Object? arg1);

  /// No description provided for @workingInArg1OnTheCloud.
  ///
  /// In en, this message translates to:
  /// **'Working in {arg1} on the cloud computer. NeoAgent reads and edits files there and can run commands and a browser.'**
  String workingInArg1OnTheCloud(Object? arg1);

  /// No description provided for @workingInTheBackgroundArg1.
  ///
  /// In en, this message translates to:
  /// **'Working in the background: {arg1}'**
  String workingInTheBackgroundArg1(Object? arg1);

  /// No description provided for @worksLikeYouWould.
  ///
  /// In en, this message translates to:
  /// **'Works like you would'**
  String get worksLikeYouWould;

  /// No description provided for @workspaceConfigurationAndAccountSecurityIn.
  ///
  /// In en, this message translates to:
  /// **'Workspace configuration and account security in one place.'**
  String get workspaceConfigurationAndAccountSecurityIn;

  /// No description provided for @workspaceFiles.
  ///
  /// In en, this message translates to:
  /// **'Workspace files'**
  String get workspaceFiles;

  /// No description provided for @workspaceModelsAndDiagnosticsControls.
  ///
  /// In en, this message translates to:
  /// **'Workspace, models, and diagnostics controls.'**
  String get workspaceModelsAndDiagnosticsControls;

  /// No description provided for @workspaceOverrideMustBeAnAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Workspace override must be an absolute path.'**
  String get workspaceOverrideMustBeAnAbsolute;

  /// No description provided for @wroteArg1.
  ///
  /// In en, this message translates to:
  /// **'Wrote {arg1}'**
  String wroteArg1(Object? arg1);

  /// No description provided for @xaiOauth.
  ///
  /// In en, this message translates to:
  /// **'xAI (OAuth)'**
  String get xaiOauth;

  /// No description provided for @xmlhttprequestError.
  ///
  /// In en, this message translates to:
  /// **'xmlhttprequest error'**
  String get xmlhttprequestError;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @youAreInControl.
  ///
  /// In en, this message translates to:
  /// **'You are in control'**
  String get youAreInControl;

  /// No description provided for @youCanFollowAlongOnThe.
  ///
  /// In en, this message translates to:
  /// **'You can follow along on the desktop.'**
  String get youCanFollowAlongOnThe;

  /// No description provided for @youCanLeaveATeamAt.
  ///
  /// In en, this message translates to:
  /// **'You can leave a team at any time; your own settings apply again.'**
  String get youCanLeaveATeamAt;

  /// No description provided for @youCanLeaveAtAnyTime.
  ///
  /// In en, this message translates to:
  /// **'You can leave at any time from the Team page.'**
  String get youCanLeaveAtAnyTime;

  /// No description provided for @youDecideWhichToolsYourAgent.
  ///
  /// In en, this message translates to:
  /// **'You decide which tools your agent may use, under Settings › '**
  String get youDecideWhichToolsYourAgent;

  /// No description provided for @youDonTManageAnyoneYet.
  ///
  /// In en, this message translates to:
  /// **'You don’t manage anyone yet. Create an invite link below and '**
  String get youDonTManageAnyoneYet;

  /// No description provided for @youHaveUnsavedSettingsWhatWould.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved settings. What would you like to do?'**
  String get youHaveUnsavedSettingsWhatWould;

  /// No description provided for @youReOnYourOwnYou.
  ///
  /// In en, this message translates to:
  /// **'You’re on your own: you decide which tools your agent may use. If '**
  String get youReOnYourOwnYou;

  /// No description provided for @yourAccountAndUsageOnA.
  ///
  /// In en, this message translates to:
  /// **'your account -- and usage on a model backed by your own key '**
  String get yourAccountAndUsageOnA;

  /// No description provided for @yourAccountHasBeenDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get yourAccountHasBeenDeleted;

  /// No description provided for @yourAgentWillBeAllowed.
  ///
  /// In en, this message translates to:
  /// **'Your agent will be allowed:'**
  String get yourAgentWillBeAllowed;

  /// No description provided for @yourAppsAndFilesAreSaved.
  ///
  /// In en, this message translates to:
  /// **'Your apps and files are saved.'**
  String get yourAppsAndFilesAreSaved;

  /// No description provided for @yourAppsAndFilesRemainSaved.
  ///
  /// In en, this message translates to:
  /// **'Your apps and files remain saved.'**
  String get yourAppsAndFilesRemainSaved;

  /// No description provided for @yourArg1Key.
  ///
  /// In en, this message translates to:
  /// **'Your {arg1} key'**
  String yourArg1Key(Object? arg1);

  /// No description provided for @yourAssistantLayerForCaptureContext.
  ///
  /// In en, this message translates to:
  /// **'Your assistant layer for capture, context, and action.'**
  String get yourAssistantLayerForCaptureContext;

  /// No description provided for @yourComputerIsAsleep.
  ///
  /// In en, this message translates to:
  /// **'Your computer is asleep'**
  String get yourComputerIsAsleep;

  /// No description provided for @yourComputerIsOff.
  ///
  /// In en, this message translates to:
  /// **'Your computer is off'**
  String get yourComputerIsOff;

  /// No description provided for @yourComputerIsReady.
  ///
  /// In en, this message translates to:
  /// **'Your computer is ready'**
  String get yourComputerIsReady;

  /// No description provided for @yourCurrentPasswordIsIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Your current password is incorrect.'**
  String get yourCurrentPasswordIsIncorrect;

  /// No description provided for @yourData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get yourData;

  /// No description provided for @yourDataExportWasCopiedTo.
  ///
  /// In en, this message translates to:
  /// **'Your data export was copied to the clipboard.'**
  String get yourDataExportWasCopiedTo;

  /// No description provided for @yourDesktopIsReady.
  ///
  /// In en, this message translates to:
  /// **'Your desktop is ready'**
  String get yourDesktopIsReady;

  /// No description provided for @yourLinuxComputer.
  ///
  /// In en, this message translates to:
  /// **'Your Linux computer'**
  String get yourLinuxComputer;

  /// No description provided for @yourLocationIsNeverTrackedContinuously.
  ///
  /// In en, this message translates to:
  /// **'Your location is never tracked continuously or stored on our servers. We only use it locally to check against your active tasks.'**
  String get yourLocationIsNeverTrackedContinuously;

  /// No description provided for @yourManager.
  ///
  /// In en, this message translates to:
  /// **'your manager'**
  String get yourManager;

  /// No description provided for @yourMattermostSiteUrlIfYou.
  ///
  /// In en, this message translates to:
  /// **'Your Mattermost site URL, if you use the REST API.'**
  String get yourMattermostSiteUrlIfYou;

  /// No description provided for @yourOwnKey.
  ///
  /// In en, this message translates to:
  /// **'your own key.'**
  String get yourOwnKey;

  /// No description provided for @yourSessionExpiredOrWasNot.
  ///
  /// In en, this message translates to:
  /// **'Your session expired or was not retained by the browser. Please sign in again.'**
  String get yourSessionExpiredOrWasNot;

  /// No description provided for @yourSessionExpiredPleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get yourSessionExpiredPleaseSignIn;

  /// No description provided for @yourSubscriptionWillRemainActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Your subscription will remain active until the end of the billing period.'**
  String get yourSubscriptionWillRemainActiveUntil;

  /// No description provided for @yourUsernameOrPasswordIsIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Your username or password is incorrect.'**
  String get yourUsernameOrPasswordIsIncorrect;

  /// No description provided for @yubikeyMacbookTouchId.
  ///
  /// In en, this message translates to:
  /// **'YubiKey, MacBook Touch ID, …'**
  String get yubikeyMacbookTouchId;

  /// No description provided for @yubikeyOtp.
  ///
  /// In en, this message translates to:
  /// **'YubiKey OTP'**
  String get yubikeyOtp;

  /// No description provided for @zaloPersonal.
  ///
  /// In en, this message translates to:
  /// **'Zalo Personal'**
  String get zaloPersonal;

  /// No description provided for @sectionOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get sectionOverview;

  /// No description provided for @sectionDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get sectionDiagnostics;

  /// No description provided for @sectionVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get sectionVolume;

  /// No description provided for @sectionSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sectionSession;

  /// No description provided for @sectionDeliverable.
  ///
  /// In en, this message translates to:
  /// **'Deliverable'**
  String get sectionDeliverable;

  /// No description provided for @theLocalRuntimeHasNotWrittenA.
  ///
  /// In en, this message translates to:
  /// **'The local runtime has not written a log file yet.'**
  String get theLocalRuntimeHasNotWrittenA;

  /// No description provided for @thisComputer.
  ///
  /// In en, this message translates to:
  /// **'This computer'**
  String get thisComputer;

  /// No description provided for @betaInstallsTheNewestPrereleaseBackendExpect.
  ///
  /// In en, this message translates to:
  /// **'Beta installs the newest prerelease backend. Expect rough edges.'**
  String get betaInstallsTheNewestPrereleaseBackendExpect;

  /// No description provided for @copiedFinalResponse.
  ///
  /// In en, this message translates to:
  /// **'Copied final response'**
  String get copiedFinalResponse;

  /// No description provided for @theFinalResponseAppearsHereWhenThe.
  ///
  /// In en, this message translates to:
  /// **'The final response appears here when the run finishes.'**
  String get theFinalResponseAppearsHereWhenThe;

  /// No description provided for @waitingForTheFirstStep.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first step…'**
  String get waitingForTheFirstStep;

  /// No description provided for @loadingPrompt.
  ///
  /// In en, this message translates to:
  /// **'Loading prompt…'**
  String get loadingPrompt;

  /// No description provided for @noFinalResponseWasCapturedForThis.
  ///
  /// In en, this message translates to:
  /// **'No final response was captured for this run.'**
  String get noFinalResponseWasCapturedForThis;

  /// No description provided for @readyToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Ready to sign in'**
  String get readyToSignIn;

  /// No description provided for @switchToDefaultOrAlwaysAskTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to \"Default\" or \"Always ask\" to re-enable approval checks.'**
  String get switchToDefaultOrAlwaysAskTo;

  /// No description provided for @sendASteeringUpdateOrNextUp.
  ///
  /// In en, this message translates to:
  /// **'Send a steering update or next-up note for the current run...'**
  String get sendASteeringUpdateOrNextUp;

  /// No description provided for @noNetworkConnectionNeoagentWillReconnectWhen.
  ///
  /// In en, this message translates to:
  /// **'No network connection. NeoAgent will reconnect when the device is back online.'**
  String get noNetworkConnectionNeoagentWillReconnectWhen;

  /// No description provided for @appliedTheLatestSteeringUpdateToThe.
  ///
  /// In en, this message translates to:
  /// **'Applied the latest steering update to the current run.'**
  String get appliedTheLatestSteeringUpdateToThe;

  /// No description provided for @preparingThePrivateVoiceSession.
  ///
  /// In en, this message translates to:
  /// **'Preparing the private voice session…'**
  String get preparingThePrivateVoiceSession;

  /// No description provided for @preparingYourComputer.
  ///
  /// In en, this message translates to:
  /// **'Preparing your computer'**
  String get preparingYourComputer;

  /// No description provided for @neoagentIsDownloadingAndPreparingTheSecure.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent is downloading and preparing the secure Linux system. This only happens the first time.'**
  String get neoagentIsDownloadingAndPreparingTheSecure;

  /// No description provided for @moreFreeSpaceIsNeeded.
  ///
  /// In en, this message translates to:
  /// **'More free space is needed'**
  String get moreFreeSpaceIsNeeded;

  /// No description provided for @freeSomeDiskSpaceOnTheNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Free some disk space on the NeoAgent host, then try again. Your existing computer data is safe.'**
  String get freeSomeDiskSpaceOnTheNeoagent;

  /// No description provided for @androidReady.
  ///
  /// In en, this message translates to:
  /// **'Android ready'**
  String get androidReady;

  /// No description provided for @startingAndroid2.
  ///
  /// In en, this message translates to:
  /// **'Starting Android…'**
  String get startingAndroid2;

  /// No description provided for @androidStopped.
  ///
  /// In en, this message translates to:
  /// **'Android stopped'**
  String get androidStopped;

  /// No description provided for @theFirstStartDownloadsTheAndroidSdk.
  ///
  /// In en, this message translates to:
  /// **'The first start downloads the Android SDK and system image, which can take several minutes.'**
  String get theFirstStartDownloadsTheAndroidSdk;

  /// No description provided for @androidIsStopped.
  ///
  /// In en, this message translates to:
  /// **'Android is stopped'**
  String get androidIsStopped;

  /// No description provided for @startTheManagedAndroidEnvironmentWhenYou.
  ///
  /// In en, this message translates to:
  /// **'Start the managed Android environment when you need it.'**
  String get startTheManagedAndroidEnvironmentWhenYou;

  /// No description provided for @letNeoagentWorkOnThisComputer.
  ///
  /// In en, this message translates to:
  /// **'Let NeoAgent work on this computer'**
  String get letNeoagentWorkOnThisComputer;

  /// No description provided for @firstTimeSetupIsInProgress.
  ///
  /// In en, this message translates to:
  /// **'First-time setup is in progress.'**
  String get firstTimeSetupIsInProgress;

  /// No description provided for @neoagentCanUseTheAccessYouAllow.
  ///
  /// In en, this message translates to:
  /// **'NeoAgent can use the access you allow.'**
  String get neoagentCanUseTheAccessYouAllow;

  /// No description provided for @freeSomeHostStorageAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Free some host storage and try again.'**
  String get freeSomeHostStorageAndTryAgain;

  /// No description provided for @startWhenYouWantNeoagentToHelp.
  ///
  /// In en, this message translates to:
  /// **'Start when you want NeoAgent to help here.'**
  String get startWhenYouWantNeoagentToHelp;

  /// No description provided for @systemPermissionMissing.
  ///
  /// In en, this message translates to:
  /// **'System permission missing'**
  String get systemPermissionMissing;

  /// No description provided for @connectingThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Connecting this device'**
  String get connectingThisDevice;

  /// No description provided for @theSecureLocalConnectionIsBeingEstablished.
  ///
  /// In en, this message translates to:
  /// **'The secure local connection is being established.'**
  String get theSecureLocalConnectionIsBeingEstablished;

  /// No description provided for @recordingYourDemonstration.
  ///
  /// In en, this message translates to:
  /// **'Recording your demonstration'**
  String get recordingYourDemonstration;

  /// No description provided for @noErrorsInTheRecentLog.
  ///
  /// In en, this message translates to:
  /// **'No errors in the recent log.'**
  String get noErrorsInTheRecentLog;

  /// No description provided for @loadingAccounts.
  ///
  /// In en, this message translates to:
  /// **'Loading accounts…'**
  String get loadingAccounts;

  /// No description provided for @neverSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Never signed in'**
  String get neverSignedIn;

  /// No description provided for @emptyUsesTheServerDefault.
  ///
  /// In en, this message translates to:
  /// **'Empty uses the server default.'**
  String get emptyUsesTheServerDefault;

  /// No description provided for @followTheSelectedSession.
  ///
  /// In en, this message translates to:
  /// **'Follow the selected session'**
  String get followTheSelectedSession;

  /// No description provided for @planModeInspectsOnlySwitchToAgent.
  ///
  /// In en, this message translates to:
  /// **'Plan mode inspects only. Switch to Agent mode to let NeoAgent edit files.'**
  String get planModeInspectsOnlySwitchToAgent;

  /// No description provided for @requiredToAddOrChangeYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Required to add or change your account email.'**
  String get requiredToAddOrChangeYourAccount;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get passwordChanged;

  /// No description provided for @thisRequestHasAlreadyBeenUsed.
  ///
  /// In en, this message translates to:
  /// **'This request has already been used.'**
  String get thisRequestHasAlreadyBeenUsed;

  /// No description provided for @thisRequestHasExpiredAskTheOther.
  ///
  /// In en, this message translates to:
  /// **'This request has expired. Ask the other device to generate a new code.'**
  String get thisRequestHasExpiredAskTheOther;

  /// No description provided for @startQuickstart.
  ///
  /// In en, this message translates to:
  /// **'Start Quickstart'**
  String get startQuickstart;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @showWorkAsSummaries.
  ///
  /// In en, this message translates to:
  /// **'Show work as summaries'**
  String get showWorkAsSummaries;

  /// No description provided for @tokensUsedByTheLatestRun.
  ///
  /// In en, this message translates to:
  /// **'Tokens used by the latest run'**
  String get tokensUsedByTheLatestRun;

  /// No description provided for @listedTheWorkspaceRoot.
  ///
  /// In en, this message translates to:
  /// **'Listed the workspace root'**
  String get listedTheWorkspaceRoot;

  /// No description provided for @noOfficialIntegrationsAreAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'No official integrations are available yet.'**
  String get noOfficialIntegrationsAreAvailableYet;

  /// No description provided for @noMcpServersConfiguredYetAddOne.
  ///
  /// In en, this message translates to:
  /// **'No MCP servers configured yet. Add one to expose its tools.'**
  String get noMcpServersConfiguredYetAddOne;

  /// No description provided for @addAnMcpServerOrInstallA.
  ///
  /// In en, this message translates to:
  /// **'Add an MCP server or install a skill to get started.'**
  String get addAnMcpServerOrInstallA;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setUp;

  /// No description provided for @leaveBlankToKeepTheStoredValue.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the stored value'**
  String get leaveBlankToKeepTheStoredValue;

  /// No description provided for @thisRemovesTheAddressForEveryAccount.
  ///
  /// In en, this message translates to:
  /// **'This removes the address for every account on this server.'**
  String get thisRemovesTheAddressForEveryAccount;

  /// No description provided for @allModels.
  ///
  /// In en, this message translates to:
  /// **'All models'**
  String get allModels;

  /// No description provided for @optionalAndPermanentBlankGeneratesOne.
  ///
  /// In en, this message translates to:
  /// **'Optional and permanent. Blank generates one.'**
  String get optionalAndPermanentBlankGeneratesOne;

  /// No description provided for @noSubscriptionsYet.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet.'**
  String get noSubscriptionsYet;

  /// No description provided for @justTalkYouCanInterruptAtAny.
  ///
  /// In en, this message translates to:
  /// **'Just talk. You can interrupt at any time. Tap to mute.'**
  String get justTalkYouCanInterruptAtAny;

  /// No description provided for @tapAgainWhenYouAreDone.
  ///
  /// In en, this message translates to:
  /// **'Tap again when you are done.'**
  String get tapAgainWhenYouAreDone;

  /// No description provided for @workingOnATaskInTheBackground.
  ///
  /// In en, this message translates to:
  /// **'Working on a task in the background.'**
  String get workingOnATaskInTheBackground;

  /// No description provided for @speechToSpeechWithTheSameMemory.
  ///
  /// In en, this message translates to:
  /// **'Speech-to-speech with the same memory, tools and chat history as NeoAgent.'**
  String get speechToSpeechWithTheSameMemory;

  /// No description provided for @checkLink.
  ///
  /// In en, this message translates to:
  /// **'Check link'**
  String get checkLink;

  /// No description provided for @yourAgentWillNotBeAllowedAny.
  ///
  /// In en, this message translates to:
  /// **'Your agent will not be allowed any of the controlled tools.'**
  String get yourAgentWillNotBeAllowedAny;

  /// No description provided for @notYoursToChange.
  ///
  /// In en, this message translates to:
  /// **'Not yours to change'**
  String get notYoursToChange;

  /// No description provided for @setByYou.
  ///
  /// In en, this message translates to:
  /// **'Set by you'**
  String get setByYou;

  /// No description provided for @noTools.
  ///
  /// In en, this message translates to:
  /// **'No tools'**
  String get noTools;

  /// No description provided for @untitledLink.
  ///
  /// In en, this message translates to:
  /// **'Untitled link'**
  String get untitledLink;

  /// No description provided for @stopsWorkingAfterOnePersonRedeemsIt.
  ///
  /// In en, this message translates to:
  /// **'Stops working after one person redeems it.'**
  String get stopsWorkingAfterOnePersonRedeemsIt;

  /// No description provided for @theOperator.
  ///
  /// In en, this message translates to:
  /// **'The operator'**
  String get theOperator;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @smartSelectorOn.
  ///
  /// In en, this message translates to:
  /// **'Smart selector on'**
  String get smartSelectorOn;

  /// No description provided for @jevDecidesWhenToSpeakWhileIt.
  ///
  /// In en, this message translates to:
  /// **'Jev decides when to speak while it is on; this model is the fallback.'**
  String get jevDecidesWhenToSpeakWhileIt;

  /// No description provided for @startASessionToBegin.
  ///
  /// In en, this message translates to:
  /// **'Start a session to begin'**
  String get startASessionToBegin;

  /// No description provided for @steerTheActiveRun.
  ///
  /// In en, this message translates to:
  /// **'Steer the active run…'**
  String get steerTheActiveRun;

  /// No description provided for @describeWhatToPlan.
  ///
  /// In en, this message translates to:
  /// **'Describe what to plan…'**
  String get describeWhatToPlan;

  /// No description provided for @stopDictation.
  ///
  /// In en, this message translates to:
  /// **'Stop dictation'**
  String get stopDictation;

  /// No description provided for @messagesSteerTheCurrentRunSendStop.
  ///
  /// In en, this message translates to:
  /// **'Messages steer the current run · ⌘↵ send · ⌘. stop'**
  String get messagesSteerTheCurrentRunSendStop;

  /// No description provided for @planModeInspectsOnlyNothingIsChanged.
  ///
  /// In en, this message translates to:
  /// **'Plan mode inspects only; nothing is changed until you implement · ⌘↵ send'**
  String get planModeInspectsOnlyNothingIsChanged;

  /// No description provided for @agentEditsTheWorkspacePlanOnlyInspects.
  ///
  /// In en, this message translates to:
  /// **'Agent edits the workspace. Plan only inspects.'**
  String get agentEditsTheWorkspacePlanOnlyInspects;

  /// No description provided for @defaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get defaultModel;

  /// No description provided for @openingScanner.
  ///
  /// In en, this message translates to:
  /// **'Opening scanner...'**
  String get openingScanner;

  /// No description provided for @theAgentCanUseThisSkill.
  ///
  /// In en, this message translates to:
  /// **'The agent can use this skill.'**
  String get theAgentCanUseThisSkill;

  /// No description provided for @allSelected.
  ///
  /// In en, this message translates to:
  /// **'All Selected'**
  String get allSelected;

  /// No description provided for @addCoreMemoryEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Core Memory Entry'**
  String get addCoreMemoryEntry;

  /// No description provided for @channelId.
  ///
  /// In en, this message translates to:
  /// **'Channel ID'**
  String get channelId;

  /// No description provided for @aiCreatedAndUnspecifiedTasksUseThe.
  ///
  /// In en, this message translates to:
  /// **'AI-created and unspecified tasks use the current default.'**
  String get aiCreatedAndUnspecifiedTasksUseThe;

  /// No description provided for @waitingForRunEvents.
  ///
  /// In en, this message translates to:
  /// **'Waiting for run events...'**
  String get waitingForRunEvents;

  /// No description provided for @hideSteps.
  ///
  /// In en, this message translates to:
  /// **'Hide steps'**
  String get hideSteps;

  /// No description provided for @commitTheActiveLiveCapture.
  ///
  /// In en, this message translates to:
  /// **'Commit the active live capture'**
  String get commitTheActiveLiveCapture;

  /// No description provided for @stopCaptureAndSubmit.
  ///
  /// In en, this message translates to:
  /// **'Stop capture and submit'**
  String get stopCaptureAndSubmit;

  /// No description provided for @clickTheMicToStartSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Click the mic to start speaking'**
  String get clickTheMicToStartSpeaking;

  /// No description provided for @connectACustomEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Connect a custom endpoint'**
  String get connectACustomEndpoint;

  /// No description provided for @hostedProvider.
  ///
  /// In en, this message translates to:
  /// **'hosted provider.'**
  String get hostedProvider;

  /// No description provided for @serverToStartIt.
  ///
  /// In en, this message translates to:
  /// **'server to start it.'**
  String get serverToStartIt;

  /// No description provided for @muted.
  ///
  /// In en, this message translates to:
  /// **' • muted'**
  String get muted;

  /// No description provided for @addWhoCanMessage.
  ///
  /// In en, this message translates to:
  /// **'Add who can message'**
  String get addWhoCanMessage;

  /// No description provided for @joinsGroupConversations.
  ///
  /// In en, this message translates to:
  /// **'Joins group conversations'**
  String get joinsGroupConversations;

  /// No description provided for @label1PersonOrGroupAdded.
  ///
  /// In en, this message translates to:
  /// **'1 person or group added'**
  String get label1PersonOrGroupAdded;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @waitingForUpdateJobOutput.
  ///
  /// In en, this message translates to:
  /// **'Waiting for update job output…'**
  String get waitingForUpdateJobOutput;

  /// No description provided for @taskTrigger.
  ///
  /// In en, this message translates to:
  /// **'Task trigger'**
  String get taskTrigger;

  /// No description provided for @bearerToken.
  ///
  /// In en, this message translates to:
  /// **'Bearer token'**
  String get bearerToken;

  /// No description provided for @bearerToken2.
  ///
  /// In en, this message translates to:
  /// **'Bearer Token'**
  String get bearerToken2;

  /// No description provided for @notRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get notRecorded;

  /// No description provided for @sessionCookie.
  ///
  /// In en, this message translates to:
  /// **'Session cookie'**
  String get sessionCookie;

  /// No description provided for @neverUsed.
  ///
  /// In en, this message translates to:
  /// **'Never used'**
  String get neverUsed;

  /// No description provided for @linkedRecently.
  ///
  /// In en, this message translates to:
  /// **'Linked recently'**
  String get linkedRecently;

  /// No description provided for @notUsedYet.
  ///
  /// In en, this message translates to:
  /// **'Not used yet'**
  String get notUsedYet;

  /// No description provided for @oneOrMoreAccountsExpiredReconnectTo.
  ///
  /// In en, this message translates to:
  /// **'One or more accounts expired. Reconnect to restore access. If this keeps happening, your Google Cloud OAuth app may be in Testing mode — publish it to Production in Google Cloud Console to get long-lived tokens.'**
  String get oneOrMoreAccountsExpiredReconnectTo;

  /// No description provided for @vaultConnectedAndAvailableAfterRestart.
  ///
  /// In en, this message translates to:
  /// **'Vault connected and available after restart'**
  String get vaultConnectedAndAvailableAfterRestart;

  /// No description provided for @vaultConnectedForThisSession.
  ///
  /// In en, this message translates to:
  /// **'Vault connected for this session'**
  String get vaultConnectedForThisSession;

  /// No description provided for @connectAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect Another Account'**
  String get connectAnotherAccount;

  /// No description provided for @pasteReplacementLongLivedAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Paste replacement Long-Lived Access Token'**
  String get pasteReplacementLongLivedAccessToken;

  /// No description provided for @updateInstance.
  ///
  /// In en, this message translates to:
  /// **'Update Instance'**
  String get updateInstance;

  /// No description provided for @pasteAReplacementToken.
  ///
  /// In en, this message translates to:
  /// **'Paste a replacement token'**
  String get pasteAReplacementToken;

  /// No description provided for @replaceAccount.
  ///
  /// In en, this message translates to:
  /// **'Replace Account'**
  String get replaceAccount;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// No description provided for @canDelegateToAnyReceivingAgent.
  ///
  /// In en, this message translates to:
  /// **'Can delegate to any receiving agent'**
  String get canDelegateToAnyReceivingAgent;

  /// No description provided for @canReceiveDelegatedTasks2.
  ///
  /// In en, this message translates to:
  /// **'can receive delegated tasks'**
  String get canReceiveDelegatedTasks2;

  /// No description provided for @noSyncYet.
  ///
  /// In en, this message translates to:
  /// **'No sync yet'**
  String get noSyncYet;

  /// No description provided for @noNewData.
  ///
  /// In en, this message translates to:
  /// **'No new data'**
  String get noNewData;

  /// No description provided for @syncOnceToSeedYourBackend.
  ///
  /// In en, this message translates to:
  /// **'Sync once to seed your backend.'**
  String get syncOnceToSeedYourBackend;

  /// No description provided for @lastWindowEndIsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Last window end is unknown.'**
  String get lastWindowEndIsUnknown;

  /// No description provided for @lastNonEmptySync.
  ///
  /// In en, this message translates to:
  /// **'Last non-empty sync'**
  String get lastNonEmptySync;

  /// No description provided for @stopTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Stop & transcribe'**
  String get stopTranscribe;

  /// No description provided for @steeringMode.
  ///
  /// In en, this message translates to:
  /// **'Steering mode'**
  String get steeringMode;

  /// No description provided for @noMessageText.
  ///
  /// In en, this message translates to:
  /// **'No message text'**
  String get noMessageText;

  /// No description provided for @reconnectingToServer.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to server…'**
  String get reconnectingToServer;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @noGroupsFoundYet.
  ///
  /// In en, this message translates to:
  /// **'No groups found yet'**
  String get noGroupsFoundYet;

  /// No description provided for @onForNewGroupsOnly.
  ///
  /// In en, this message translates to:
  /// **'On for new groups only'**
  String get onForNewGroupsOnly;

  /// No description provided for @noGroupsInThisCategory.
  ///
  /// In en, this message translates to:
  /// **'No groups in this category'**
  String get noGroupsInThisCategory;

  /// No description provided for @groupOrChannel.
  ///
  /// In en, this message translates to:
  /// **'Group or channel'**
  String get groupOrChannel;

  /// No description provided for @notesYouWriteToYourselfStartA.
  ///
  /// In en, this message translates to:
  /// **'Notes you write to yourself start a run, and replies land in the same chat. The allowlist does not apply here.'**
  String get notesYouWriteToYourselfStartA;

  /// No description provided for @needToReply.
  ///
  /// In en, this message translates to:
  /// **'Need to reply'**
  String get needToReply;

  /// No description provided for @enter2faCode.
  ///
  /// In en, this message translates to:
  /// **'Enter 2FA code'**
  String get enter2faCode;

  /// No description provided for @openYourAuthenticatorAppAndEnterThe.
  ///
  /// In en, this message translates to:
  /// **'Open your authenticator app and enter the current NeoAgent code.'**
  String get openYourAuthenticatorAppAndEnterThe;

  /// No description provided for @alreadyHaveAnAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAnAccountSignIn;

  /// No description provided for @serverOnThisComputer.
  ///
  /// In en, this message translates to:
  /// **'Server on this computer'**
  String get serverOnThisComputer;

  /// No description provided for @showQrCode.
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get showQrCode;

  /// No description provided for @createAnotherNeoagentAccount.
  ///
  /// In en, this message translates to:
  /// **'Create another NeoAgent account.'**
  String get createAnotherNeoagentAccount;

  /// No description provided for @canCoordinateDelegatedWork.
  ///
  /// In en, this message translates to:
  /// **'Can coordinate delegated work'**
  String get canCoordinateDelegatedWork;

  /// No description provided for @theNeoagentRuntimeArchiveCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent runtime archive could not be extracted.'**
  String get theNeoagentRuntimeArchiveCouldNotBe;

  /// No description provided for @theNeoagentRuntimeArchiveCouldNotBe2.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent runtime archive could not be read.'**
  String get theNeoagentRuntimeArchiveCouldNotBe2;

  /// No description provided for @theNeoagentRuntimeArchiveContainsAnUnsafe.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent runtime archive contains an unsafe path.'**
  String get theNeoagentRuntimeArchiveContainsAnUnsafe;

  /// No description provided for @theNeoagentRuntimeArchiveContainsAnUnsafe2.
  ///
  /// In en, this message translates to:
  /// **'The NeoAgent runtime archive contains an unsafe link.'**
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2;

  /// No description provided for @installingAppPackageOnThePhone.
  ///
  /// In en, this message translates to:
  /// **'Installing app package on the phone...'**
  String get installingAppPackageOnThePhone;

  /// No description provided for @dragAndDropAApkOrApks.
  ///
  /// In en, this message translates to:
  /// **'Drag and drop a .apk or .apks file here, or click to browse.'**
  String get dragAndDropAApkOrApks;

  /// No description provided for @releaseToInstallThisPackage.
  ///
  /// In en, this message translates to:
  /// **'Release to install this package'**
  String get releaseToInstallThisPackage;

  /// No description provided for @theSecurityKeyCouldNotBeUsed.
  ///
  /// In en, this message translates to:
  /// **'The security key could not be used.'**
  String get theSecurityKeyCouldNotBeUsed;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @changes.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get changes;

  /// No description provided for @runtimeReady.
  ///
  /// In en, this message translates to:
  /// **'Runtime ready'**
  String get runtimeReady;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @steeringWord.
  ///
  /// In en, this message translates to:
  /// **'Steering'**
  String get steeringWord;

  /// No description provided for @thisSwitchesTheBackendFromTheArg1.
  ///
  /// In en, this message translates to:
  /// **'This switches the backend from the {arg1} channel to the {arg2} channel.'**
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2);

  /// No description provided for @arg1CookiesImported.
  ///
  /// In en, this message translates to:
  /// **'{arg1} cookies imported'**
  String arg1CookiesImported(Object? arg1);

  /// No description provided for @arg1SAgo.
  ///
  /// In en, this message translates to:
  /// **'{arg1}s ago'**
  String arg1SAgo(Object? arg1);

  /// No description provided for @queuedSteeringArg1.
  ///
  /// In en, this message translates to:
  /// **'Queued steering: {arg1}'**
  String queuedSteeringArg1(Object? arg1);

  /// No description provided for @theWebAppCouldNotReachThe.
  ///
  /// In en, this message translates to:
  /// **'The web app could not reach the NeoAgent backend.\n\n{arg1}'**
  String theWebAppCouldNotReachThe(Object? arg1);

  /// No description provided for @theBrowserBlockedARequiredRequestBecause.
  ///
  /// In en, this message translates to:
  /// **'The browser blocked a required request because of Content Security Policy.\n\n{arg1}'**
  String theBrowserBlockedARequiredRequestBecause(Object? arg1);

  /// No description provided for @arg1Of4Allowed.
  ///
  /// In en, this message translates to:
  /// **'{arg1} of 4 allowed'**
  String arg1Of4Allowed(Object? arg1);

  /// No description provided for @arg1WorkThroughTheTaskAsYou.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · Work through the task as you normally would.'**
  String arg1WorkThroughTheTaskAsYou(Object? arg1);

  /// No description provided for @changesArg1.
  ///
  /// In en, this message translates to:
  /// **'Changes · {arg1}'**
  String changesArg1(Object? arg1);

  /// No description provided for @thisDeviceArg12.
  ///
  /// In en, this message translates to:
  /// **'This device · {arg1}'**
  String thisDeviceArg12(Object? arg1);

  /// No description provided for @limitReachedArg1.
  ///
  /// In en, this message translates to:
  /// **'Limit reached{arg1}'**
  String limitReachedArg1(Object? arg1);

  /// No description provided for @arg1RecoveryCodesAreStillAvailable.
  ///
  /// In en, this message translates to:
  /// **'{arg1} recovery codes are still available.'**
  String arg1RecoveryCodesAreStillAvailable(Object? arg1);

  /// No description provided for @securityKeyArg1.
  ///
  /// In en, this message translates to:
  /// **'Security key {arg1}'**
  String securityKeyArg1(Object? arg1);

  /// No description provided for @arg1CurrentSession.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · Current session'**
  String arg1CurrentSession(Object? arg1);

  /// No description provided for @arg1LastUsedArg2.
  ///
  /// In en, this message translates to:
  /// **'{arg1}\nLast used: {arg2}'**
  String arg1LastUsedArg2(Object? arg1, Object? arg2);

  /// No description provided for @workingInArg1OnThisDeviceNeoagent.
  ///
  /// In en, this message translates to:
  /// **'Working in {arg1} on this device. NeoAgent reads and edits the folder directly and can run commands, open apps and use the screen.'**
  String workingInArg1OnThisDeviceNeoagent(Object? arg1);

  /// No description provided for @workedForArg1.
  ///
  /// In en, this message translates to:
  /// **'Worked for {arg1}'**
  String workedForArg1(Object? arg1);

  /// No description provided for @allowedByArg1.
  ///
  /// In en, this message translates to:
  /// **'Allowed by {arg1}'**
  String allowedByArg1(Object? arg1);

  /// No description provided for @arg1InviteLinksFromArg2WereRevoked.
  ///
  /// In en, this message translates to:
  /// **'{arg1} invite links from {arg2} were revoked'**
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2);

  /// No description provided for @trialEndsArg1.
  ///
  /// In en, this message translates to:
  /// **'Trial ends {arg1}'**
  String trialEndsArg1(Object? arg1);

  /// No description provided for @cancelsAtEndOfPeriodArg1.
  ///
  /// In en, this message translates to:
  /// **'Cancels at end of period · {arg1}'**
  String cancelsAtEndOfPeriodArg1(Object? arg1);

  /// No description provided for @renewsArg1.
  ///
  /// In en, this message translates to:
  /// **'Renews {arg1}'**
  String renewsArg1(Object? arg1);

  /// No description provided for @addThePeopleAndGroupsArg1Should.
  ///
  /// In en, this message translates to:
  /// **'Add the people and groups {arg1} should talk to'**
  String addThePeopleAndGroupsArg1Should(Object? arg1);

  /// No description provided for @addThePeopleAndGroupsArg1Is.
  ///
  /// In en, this message translates to:
  /// **'Add the people and groups {arg1} is allowed to talk to.'**
  String addThePeopleAndGroupsArg1Is(Object? arg1);

  /// No description provided for @whereArg1Listens.
  ///
  /// In en, this message translates to:
  /// **'Where {arg1} listens'**
  String whereArg1Listens(Object? arg1);

  /// No description provided for @arg1WatchesThesePlacesForMentionsAnyone.
  ///
  /// In en, this message translates to:
  /// **'{arg1} watches these places for mentions. Anyone can post here, so people still need their own approval below.'**
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1);

  /// No description provided for @thesePeopleCanAskArg1WhereverThey.
  ///
  /// In en, this message translates to:
  /// **'These people can ask {arg1} wherever they tag it. Roles count only in the places listed above.'**
  String thesePeopleCanAskArg1WhereverThey(Object? arg1);

  /// No description provided for @onlyWhenArg1IsTagged.
  ///
  /// In en, this message translates to:
  /// **'Only when {arg1} is tagged'**
  String onlyWhenArg1IsTagged(Object? arg1);

  /// No description provided for @onForAllArg1Groups.
  ///
  /// In en, this message translates to:
  /// **'On for all {arg1} groups'**
  String onForAllArg1Groups(Object? arg1);

  /// No description provided for @arg1StillOnlyHearsPeopleAndGroups.
  ///
  /// In en, this message translates to:
  /// **'{arg1} still only hears people and groups you already approved. This just lets {arg1} join ordinary chat there, not only tags and replies.'**
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1);

  /// No description provided for @arg1StillOnlyHearsPeopleAndGroups2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} still only hears people and groups you already approved. This just chooses which of those groups it should join.'**
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1);

  /// No description provided for @ifSomeoneTagsArg1OrRepliesArg1.
  ///
  /// In en, this message translates to:
  /// **'If someone tags {arg1} or replies, {arg1} always answers. Turn this on if {arg1} should also chime in on ordinary group chat.'**
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1);

  /// No description provided for @newGroupsWillLetArg1JoinOrdinary.
  ///
  /// In en, this message translates to:
  /// **'New groups will let {arg1} join ordinary chat with approved people, until you turn them off.'**
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1);

  /// No description provided for @newGroupsWillLetArg1JoinOrdinary2.
  ///
  /// In en, this message translates to:
  /// **'New groups will let {arg1} join ordinary chat until you turn them off.'**
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1);

  /// No description provided for @newGroupsStayQuietUnlessAnApproved.
  ///
  /// In en, this message translates to:
  /// **'New groups stay quiet unless an approved person tags {arg1}, until you turn them on.'**
  String newGroupsStayQuietUnlessAnApproved(Object? arg1);

  /// No description provided for @onlyWhenAnApprovedPersonTagsArg1.
  ///
  /// In en, this message translates to:
  /// **'Only when an approved person tags {arg1}, unless you turn a group on'**
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1);

  /// No description provided for @onlyWhenArg1IsTaggedUnlessYou.
  ///
  /// In en, this message translates to:
  /// **'Only when {arg1} is tagged, unless you turn a group on'**
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1);

  /// No description provided for @arg1OfArg2GroupsJoinOrdinaryChat.
  ///
  /// In en, this message translates to:
  /// **'{arg1} of {arg2} groups join ordinary chat with approved people'**
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2);

  /// No description provided for @thisDoesNotApproveNewPeopleTags.
  ///
  /// In en, this message translates to:
  /// **'This does not approve new people. Tags and replies from approved people always get a response. Turn a group on if {arg1} should also join ordinary chat there.'**
  String thisDoesNotApproveNewPeopleTags(Object? arg1);

  /// No description provided for @thisDoesNotApproveNewPeopleTurn.
  ///
  /// In en, this message translates to:
  /// **'This does not approve new people. Turn a group on if {arg1} should join ordinary chat with people you already approved.'**
  String thisDoesNotApproveNewPeopleTurn(Object? arg1);

  /// No description provided for @tagsAndRepliesAlwaysGetAResponse.
  ///
  /// In en, this message translates to:
  /// **'Tags and replies always get a response. Turn a group on if {arg1} should also join ordinary chat there.'**
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1);

  /// No description provided for @arg1JoinsOrdinaryChatWithApprovedPeople.
  ///
  /// In en, this message translates to:
  /// **'{arg1} joins ordinary chat with approved people'**
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1);

  /// No description provided for @arg1CanJoinOrdinaryChat.
  ///
  /// In en, this message translates to:
  /// **'{arg1} can join ordinary chat'**
  String arg1CanJoinOrdinaryChat(Object? arg1);

  /// No description provided for @arg1OnlyRepliesWhenAnApprovedPerson.
  ///
  /// In en, this message translates to:
  /// **'{arg1} only replies when an approved person tags it'**
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1);

  /// No description provided for @nothingExtraIsNeededConnectToStart.
  ///
  /// In en, this message translates to:
  /// **'Nothing extra is needed. Connect to start using {arg1}.'**
  String nothingExtraIsNeededConnectToStart(Object? arg1);

  /// No description provided for @refreshesInArg1S.
  ///
  /// In en, this message translates to:
  /// **'Refreshes in {arg1}s'**
  String refreshesInArg1S(Object? arg1);

  /// No description provided for @registerWithArg1.
  ///
  /// In en, this message translates to:
  /// **'Register with {arg1}'**
  String registerWithArg1(Object? arg1);

  /// No description provided for @noMemoriesLinkedToArg1.
  ///
  /// In en, this message translates to:
  /// **'No memories linked to \"{arg1}\".'**
  String noMemoriesLinkedToArg1(Object? arg1);

  /// No description provided for @arg1Default2.
  ///
  /// In en, this message translates to:
  /// **'{arg1} (default)'**
  String arg1Default2(Object? arg1);

  /// No description provided for @branchArg1.
  ///
  /// In en, this message translates to:
  /// **' | Branch: {arg1}'**
  String branchArg1(Object? arg1);

  /// No description provided for @arg1OnlyJoinsTheGroupsAndChannels.
  ///
  /// In en, this message translates to:
  /// **'{arg1} only joins the groups and channels you add below.'**
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1);

  /// No description provided for @arg1IsRequiredToLocateNeoagentRuntime.
  ///
  /// In en, this message translates to:
  /// **'{arg1} is required to locate NeoAgent runtime data.'**
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1);

  /// No description provided for @truncatedPreviewArg1BytesTotal.
  ///
  /// In en, this message translates to:
  /// **'...[truncated preview, {arg1} bytes total]'**
  String truncatedPreviewArg1BytesTotal(Object? arg1);

  /// No description provided for @artifactBoundedArg1BytesTotal.
  ///
  /// In en, this message translates to:
  /// **'\n...[artifact bounded, {arg1} bytes total]...\n'**
  String artifactBoundedArg1BytesTotal(Object? arg1);

  /// No description provided for @userArg1.
  ///
  /// In en, this message translates to:
  /// **'User #{arg1}'**
  String userArg1(Object? arg1);

  /// No description provided for @inArg1.
  ///
  /// In en, this message translates to:
  /// **' in {arg1}'**
  String inArg1(Object? arg1);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppL10nDe();
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
