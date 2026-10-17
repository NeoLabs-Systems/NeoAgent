// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class AppL10nDa extends AppL10n {
  AppL10nDa([String locale = 'da']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Velkommen';

  @override
  String get onboardingEyebrowCommunication => 'Kommunikation';

  @override
  String get onboardingEyebrowIntelligence => 'Intelligens';

  @override
  String get onboardingEyebrowComputer => 'Computer';

  @override
  String get onboardingEyebrowAutomation => 'Automatisering';

  @override
  String get onboardingNext => 'Næste';

  @override
  String get onboardingIntroCouldNotLoad => 'Introen kunne ikke indlæses.';

  @override
  String get onboardingModelDescription =>
      'Vælg den model, NeoAgent skal bruge som standard, eller lad den vælge automatisk.';

  @override
  String get onboardingLoadingModels => 'Indlæser modeller...';

  @override
  String get noAiModelTitle => 'Ingen AI-model er sat op endnu';

  @override
  String get noAiModelBody =>
      'Tilføj en API-nøgle fra en udbyder som OpenAI, Anthropic eller Google. NeoAgent viser derefter de modeller, du kan bruge.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent har brug for en AI-model for at svare. Tilføj en API-nøgle fra en udbyder som OpenAI, Anthropic eller Google.';

  @override
  String get noAiModelAdminHint =>
      'Som admin kan du også oprette udbydere for alle under Admin → Udbydere.';

  @override
  String get addApiKey => 'Tilføj API-nøgle';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform er tilsluttet.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Venter på, at $platform opretter forbindelse...';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Opsætningen kunne ikke gemmes: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Klar';

  @override
  String get onboardingStepRequired => 'Påkrævet';

  @override
  String get onboardingStepOptional => 'Valgfrit';

  @override
  String get onboardingStepCloudOrLocal => 'Cloud eller lokalt';

  @override
  String get onboardingStepComputer => 'Computer';

  @override
  String get onboardingStepRoutines => 'Rutiner';

  @override
  String get onboardingComputerChoiceTitle => 'Hvor skal\ndet virke?';

  @override
  String get onboardingComputerChoiceDescription => 'Du kan skifte pr session.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Privat sandkasse · altid tændt';

  @override
  String get onboardingThisComputer => 'Denne computer';

  @override
  String get onboardingThisComputerSubtitle => 'Dine filer, apps og browser';

  @override
  String get onboardingSearchApps => 'Søg i apps...';

  @override
  String get onboardingRoutinesDescription =>
      'Resultaterne ankommer i dine chats.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Resultaterne ankommer som meddelelser.';

  @override
  String get onboardingNotifications => 'Meddelelser';

  @override
  String get onboardingReadyTitle => 'Du er\nklar.';

  @override
  String get onboardingReadyDescription => 'Send din første besked.';

  @override
  String get onboardingMessageNeoagent => 'Besked NeoAgent';

  @override
  String get onboardingAskAnything => 'Spørg hvad som helst...';

  @override
  String get onboardingOpenNeoagent => 'Åbn NeoAgent';

  @override
  String get onboardingStarterTrip => 'Planlæg en weekendtur';

  @override
  String get onboardingStarterLanding => 'Byg en landingsside';

  @override
  String onboardingQuickSteps(int count) {
    return '$count hurtige trin';
  }

  @override
  String get taskNeedsEmail => 'Tilslut e-mail først';

  @override
  String get taskNeedsCalendar => 'Tilslut først en kalender';

  @override
  String get taskNeedsModel => 'Konfigurer en AI-model først';

  @override
  String get taskPromptDailyRecap =>
      'Opsummer min dag: opsummer samtalerne, det færdige arbejde og beslutninger fra i dag, og skriv derefter alt, hvad jeg skal følge op på i morgen. Hold det kort og send det til mig.';

  @override
  String get taskPromptInboxCheck =>
      'Tjek min e-mail-indbakke for beskeder, der er ankommet siden sidste kontrol. Send mig kun besked om e-mails, der haster eller har brug for et svar, med en oversigt på én linje hver. Hvis intet har brug for min opmærksomhed, så send ikke noget.';

  @override
  String get taskPromptMorningBriefing =>
      'Forbered min morgenbriefing: dagens vejr, hvor jeg er, begivenhederne i min kalender og de vigtigste åbne emner, jeg kender til. Send det som en kort, scanbar besked.';

  @override
  String get taskPromptTomorrowPrep =>
      'Se min kalender for i morgen. Fortæl mig til hvert møde, hvad det handler om, hvem der er involveret, og hvad jeg bør forberede. Hvis i morgen er tom, skal du ikke sende noget.';

  @override
  String get taskPromptNewsDigest =>
      'Søg på nettet efter dagens vigtigste nyheder om de emner, jeg interesserer mig for (brug det, du husker om mine interesser). Send mig et sammendrag af op til fem elementer med en sætning hver og et link.';

  @override
  String get taskPromptWeeklyReview =>
      'Gennemgå min uge: hvad blev gjort, hvad skred, og hvad der stadig er åbent. Foreslå de tre vigtigste ting at fokusere på i næste uge.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Tilknyt et telefonnummer, der tilhører agenten. Alle, du tillader, kan chatte med den, i direkte chats og grupper.';

  @override
  String get whatsappSelfChatDescription =>
      'Tilknyt dit eget nummer, og tal med agenten i din \"Send dig selv\"-chat. Hver anden chat og gruppe på denne konto ignoreres.';

  @override
  String get chatSendHintMac => '⌘↵ for at sende';

  @override
  String get chatSendHintOther => 'Ctrl+Enter for at sende';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Der kræves en basis-URL for dette slutpunkt.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'En ændret e-mailadresse bekræftes, før den tages i brug.';

  @override
  String get aDecisionHigherUpTheChain =>
      'En beslutning højere oppe i kæden vinder.';

  @override
  String get aDeletedAccount => 'en slettet konto';

  @override
  String get aFridayLookBackAtThe =>
      'Et fredags tilbageblik på ugen og en plan for den næste.';

  @override
  String get aKeyThatAsksForA =>
      'En nøgle, der beder om en PIN-kode eller fingeraftryk, erstatter også din tofaktorkode.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'En sprogmodel vurderede denne besked, fordi SystemOne er slukket.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'En NeoAgent-opsætningsmetadatafil overskred sin sikre størrelsesgrænse.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'En nyere webbuild er tilgængelig på serveren. Genindlæs for at hente den seneste pakke.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Et privat skrivebord med Chromium, filer, en teksteditor, terminal og Python. Dit arbejde forbliver gemt mellem sessionerne.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'En privat Linux-computer eller en Android-enhed.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'En nødvendig NeoAgent-opsætningsfil kunne ikke downloades.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'En holdkammerat sender dig et invitationslink. Når du accepterer det, vil de ';

  @override
  String get aTeammateSentYouAnInvite =>
      'en holdkammerat sendte dig et invitationslink, indtast det her for at slutte sig til deres team.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'En midlertidig download vil blive ryddet op senere.';

  @override
  String get aValueIsStored => 'En værdi er gemt.';

  @override
  String get access => 'Adgang';

  @override
  String get accessActivity => 'Adgang til aktivitet';

  @override
  String accessArg1(Object? arg1) {
    return 'Adgang: $arg1';
  }

  @override
  String get accessMode => 'Adgangstilstand';

  @override
  String get accessPermissions => 'Adgangstilladelser';

  @override
  String get accessToken => 'adgangstoken';

  @override
  String get accessToken2 => 'Adgangstoken';

  @override
  String get account => 'Konto';

  @override
  String accountArg1(Object? arg1) {
    return 'Konto #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Advarsler om kontoændringer';

  @override
  String get accountEmail => 'Konto-e-mail';

  @override
  String get accountEmailIsOffUntilThese =>
      'Konto-e-mail er slået fra, indtil disse er indstillet: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent bruger dette sprog overalt i appen. Første gang du logger ind, følger den denne enhed. Derefter gemmes valget på din konto og bruges på alle enheder.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Kunne ikke ændre sproget: $error';
  }

  @override
  String get accountLanguageTitle => 'Sprog';

  @override
  String get accountNumber => 'Kontonummer';

  @override
  String get accountSettings => 'Kontoindstillinger';

  @override
  String get accounts => 'Konti';

  @override
  String get accountsByTokensUsedAllTime =>
      'Konti efter brugte tokens, hele tiden.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'kontoers cloud-computere. Ændringer gælder efter en server ';

  @override
  String get accountsOnThisServer => 'Konti på denne server';

  @override
  String get active => 'Aktiv';

  @override
  String get activeSessions => 'Aktive sessioner';

  @override
  String get activeToday => 'Aktiv i dag';

  @override
  String get add => 'Tilføj';

  @override
  String get addAProviderCredentialFirstIts =>
      'Tilføj en udbyderlegitimationsoplysninger først. Dens modeller dukker op her én gang ';

  @override
  String get addAgent => 'Tilføj agent';

  @override
  String get addAnotherSignInMethodBefore =>
      'Tilføj en anden login-metode, før du fjerner denne.';

  @override
  String get addBinding => 'Tilføj binding';

  @override
  String get addByNameOrId => 'Tilføj ved navn eller ID';

  @override
  String get addByNameOrIdInstead => 'Tilføj ved navn eller ID i stedet';

  @override
  String get addCredentialBinding => 'Tilføj legitimationsbinding';

  @override
  String get addEntry => 'Tilføj indgang';

  @override
  String get addKey => 'Tilføj nøgle';

  @override
  String get addMcpServer => 'Tilføj MCP-server';

  @override
  String get addMemory => 'Tilføj hukommelse';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Tilføj mere længde eller en anden tegntype.';

  @override
  String get addPeopleOrGroups => 'Tilføj personer eller grupper';

  @override
  String get addSecurityKey => 'Tilføj sikkerhedsnøgle';

  @override
  String get addSomeoneOrAGroup => 'Tilføj nogen eller en gruppe';

  @override
  String get addTask => 'Tilføj opgave';

  @override
  String get addTests => 'Tilføj test';

  @override
  String get addTestsForThePartsOf =>
      'Tilføj test for de dele af dette projekt, der har mindst dækning, og kør dem derefter.';

  @override
  String get addTheirOwnKeysInSettings =>
      'tilføje deres egne nøgler i Indstillinger.';

  @override
  String get addToPrompt => 'Føj til prompt';

  @override
  String get added => 'Tilføjet';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Tilføjet $arg1 · Sidst brugt $arg2';
  }

  @override
  String get addressWithTheProvider => 'adresse hos udbyderen.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Juster højttalerlydstyrken, gennemgå standardindstillinger for hardwareknapper, og administrer denne startsession.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Juster søge- eller statusfilteret for at se flere beskedkanaler.';

  @override
  String get adjustTheSpeakerVolumeHere => 'Juster højttalerlydstyrken her.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Admin › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Administratorbevillinger, invitationslinks og ledelsesændringer vises her.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Avanceret manuel tidsplan for særlige tilfælde.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Avanceret: minut time dag måned ugedag.';

  @override
  String get againRightAway => 'igen med det samme.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent: $arg1';
  }

  @override
  String get agentCalls => 'Agent ringer';

  @override
  String get agentCommunication => 'Agent kommunikation';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Agentkommunikation: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Agenttilstand redigerer arbejdsområdet · ⌘↵ send · ⌘N ny session';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agenten holder pause og beder om din tilladelse før kørsel.';

  @override
  String get agentProfile => 'Agent profil';

  @override
  String get agentVisibleName => 'Agent-synligt navn';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agent ønsker at bruge $arg1. Tryk for at bestemme.';
  }

  @override
  String get agents => 'Agenter';

  @override
  String get aiAnswerUnreadable => 'AI-svar ulæselig';

  @override
  String get aiProviderKeys => 'AI-udbydernøgler';

  @override
  String get aiUnavailable => 'AI er ikke tilgængelig';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'advarsler og anden konto-e-mail fra.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Advarer, når en beskedforbindelse kræver brugerens opmærksomhed';

  @override
  String get all => 'Alle';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Alle agenter ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Alle $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Alle cloud-computer slots er i brug i øjeblikket. Prøv igen om et øjeblik.';

  @override
  String get allComputerSlotsAreBusy => 'Alle computerpladser er optaget';

  @override
  String get allTables => 'Alle borde';

  @override
  String get allTime => 'Hele tiden';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Alle værktøjer er tilladt - agenten kan bruge enhver kapacitet uden at spørge. ';

  @override
  String get allow => 'Tillad';

  @override
  String get allowedRunsWithoutAsking => 'Tilladt. Løber uden at spørge.';

  @override
  String get allowAll => 'Tillad alle';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Tillad \"Installer ukendte apps\" for NeoAgent, og prøv derefter opdateringen igen.';

  @override
  String get allowOnce => 'Tillad én gang';

  @override
  String get allowSender => 'Tillad afsender';

  @override
  String get allowSession => 'Tillad session';

  @override
  String get allowTheAgentToStartAn =>
      'Tillad agenten at starte et taleopkald i appen med dig.';

  @override
  String get allowedOrigins => 'Tilladte oprindelser';

  @override
  String get allowedPathPrefix => 'Tilladt stipræfiks';

  @override
  String get allowsYouCanChangeThatPer =>
      'tillader. Du kan ændre det per person senere. Links giver aldrig ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'hører allerede til en eksisterende konto';

  @override
  String get alreadyLinkedToAnotherAccount =>
      'allerede knyttet til en anden konto';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'allerede knyttet til en anden neoagent-konto';

  @override
  String get alreadyUsed => 'allerede brugt';

  @override
  String get always => 'Altid';

  @override
  String get alwaysAllow => 'Tillad altid';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '\"Tillad altid\" gemmer politikken permanent - du kan ændre den i Indstillinger.';

  @override
  String get alwaysAsk => 'Spørg altid';

  @override
  String get alwaysEngage => 'Engager dig altid';

  @override
  String get alwaysJoins => 'Er altid med';

  @override
  String get anApiKeyIsRequired => 'Der kræves en API-nøgle.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'En aftenopsummering af, hvad der skete, og hvad der skal følges op på.';

  @override
  String get anHttpOrHttpsUrlIs => 'En http eller https URL er påkrævet.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'og analyser. Holdlinks live på Team-siden.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Android APK-installation er ikke tilgængelig på denne platform.';

  @override
  String get androidApp => 'Android app';

  @override
  String get androidControl => 'Android kontrol';

  @override
  String get androidCouldNotStart => 'Android kunne ikke starte';

  @override
  String get androidNotificationReceived => 'Android-meddelelse modtaget';

  @override
  String get androidOnly => 'Kun Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Android-pakkeinstallationsprogrammet kunne ikke åbnes.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Android-skærm – tryk for at røre, træk for at stryge';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Besvarer @omtaler om problemer og pull-anmodninger';

  @override
  String get anyone => 'Enhver';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Alle på denne platform kan sende beskeder til $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Alle på denne platform kan sende beskeder til $arg1 i $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Enhver, der kan nå denne konto, kan tale med $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Alle med linket kan deltage, indtil det udløber, eller du tilbagekalder det.';

  @override
  String get apiHttpsOrigin => 'API HTTPS oprindelse';

  @override
  String get apiKey => 'API nøgle';

  @override
  String get apiKey2 => 'api nøgle';

  @override
  String get apiKey3 => 'API nøgle';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api nøgle antropisk claude openai gpt xai grok google gemini minimax nvidia nim openrouter legitimationsoplysninger';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API-nøgler og slutpunkter for AI, søge- og stemmeudbydere. De ';

  @override
  String get apiRequest => 'API-anmodning';

  @override
  String get apiYourOwnServerASelf =>
      'API -- din egen server, en selv-hostet model eller en anden ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'APK-download mislykkedes med HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Appnavn er påkrævet.';

  @override
  String get appUpdates => 'App-opdateringer';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Appopdateringer er ikke konfigureret til denne build.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Anvendte $arg1 styringsopdateringer i kø til den aktuelle kørsel.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Anvendte $arg1 styretøjsopdatering(er).';
  }

  @override
  String get apply => 'Ansøg';

  @override
  String get applyBehaviorNotes => 'Anvend adfærdsnotater';

  @override
  String get applyCoreMemory => 'Anvend kernehukommelse';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Godkendelsesanmodninger for følsomme agentværktøjer';

  @override
  String get approvalRequired => 'Godkendelse påkrævet';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Godkendelsen forbliver i din godkendte mobilsession, og hver kode udløber automatisk efter et kort tidsrum.';

  @override
  String get approveLogin => 'Godkend login';

  @override
  String get approveQrLogin => 'Godkend QR-login';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Godkend kun dette, hvis du lige har startet login på den pågældende enhed.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Godkendt login til $arg1.';
  }

  @override
  String get approvedOnly => 'Kun godkendt';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Godkendt parring til $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Godkendte personer og grupper';

  @override
  String get approvedPeopleOnly => 'Kun godkendte personer';

  @override
  String get archive => 'Arkiv';

  @override
  String get archiveAgent => 'Arkivagent?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Arkiv ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Arkiv $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Arkivere udvalgte minder?';

  @override
  String get areSharedByEveryAccountOn =>
      'deles af hver konto på denne server; konti kan stadig ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M input';
  }

  @override
  String arg12(Object? arg1) {
    return '$arg1 · ';
  }

  @override
  String arg13(Object? arg1) {
    return '\$ $arg1';
  }

  @override
  String arg1AccessNeeded(Object? arg1) {
    return '$arg1 adgang nødvendig';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 konti';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktiv';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 tilføjet. Rediger det til enhver tid for at ændre ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '\"$arg1\" og dens kørselshistorik slettes permanent. Enhver aktiv kørsel vil blive stoppet. Filer i arbejdsområdet berøres ikke.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return '$arg1 godkendelse nødvendig';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 apps aktive';
  }

  @override
  String arg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 ($arg2)';
  }

  @override
  String arg1Arg210(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 * * *';
  }

  @override
  String arg1Arg211(Object? arg1, Object? arg2) {
    return '$arg1 -> $arg2';
  }

  @override
  String arg1Arg215(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 * * 1-5';
  }

  @override
  String arg1Arg22(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2';
  }

  @override
  String arg1Arg23(Object? arg1, Object? arg2) {
    return '$arg1 $arg2';
  }

  @override
  String arg1Arg24(Object? arg1, Object? arg2) {
    return '$arg1: $arg2';
  }

  @override
  String arg1Arg25(Object? arg1, Object? arg2) {
    return '[$arg1] $arg2';
  }

  @override
  String arg1Arg26(Object? arg1, Object? arg2) {
    return '@$arg1 · $arg2';
  }

  @override
  String arg1Arg27(Object? arg1, Object? arg2) {
    return '$arg1. $arg2';
  }

  @override
  String arg1Arg28(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 ';
  }

  @override
  String arg1Arg2ActiveTools(Object? arg1, Object? arg2) {
    return '$arg1 ($arg2 aktive værktøjer)';
  }

  @override
  String arg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 • $arg2 • $arg3';
  }

  @override
  String arg1Arg2Arg310(Object? arg1, Object? arg2, Object? arg3) {
    return '### $arg1 ($arg2)\n$arg3';
  }

  @override
  String arg1Arg2Arg311(Object? arg1, Object? arg2, Object? arg3) {
    return '[$arg1][$arg2] $arg3';
  }

  @override
  String arg1Arg2Arg32(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1/$arg2 $arg3';
  }

  @override
  String arg1Arg2Arg33(Object? arg1, Object? arg2, Object? arg3) {
    return '[$arg1] [$arg2] $arg3';
  }

  @override
  String arg1Arg2Arg34(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 * * $arg3';
  }

  @override
  String arg1Arg2Arg35(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 $arg3 * *';
  }

  @override
  String arg1Arg2Arg36(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · $arg3';
  }

  @override
  String arg1Arg2Arg37(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 $arg3';
  }

  @override
  String arg1Arg2Arg39(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2, $arg3';
  }

  @override
  String arg1Arg2Arg3Arg4(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
  ) {
    return '$arg1/$arg2 $arg3:$arg4';
  }

  @override
  String arg1Arg2Arg3Arg42(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
  ) {
    return '$arg1 $arg2 $arg3 $arg4';
  }

  @override
  String arg1Arg2Arg3Arg4Arg5(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return '$arg1-$arg2-$arg3 $arg4:$arg5';
  }

  @override
  String arg1Arg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 ved $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 ændret';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 tegn';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Oprettet $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [lokal uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 matcher \"$arg3\"';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent Workspace';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 nye konti';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 kører · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 prøver';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 styretøj i kø';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 tokens';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 tokens';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 på $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 blev administrator ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 bytes';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 kanal';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 tegn';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 ryddet.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 konfigureret';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 tilsluttet. Vælg lagre og personer under Hvem kan sende beskeder.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 kerneposter.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 oprettede et invitationslink';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 desktop';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 begivenheder';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 mislykkedes';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 mislykkedes';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 fejler';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 til $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 grupper, der kun er tagget';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h siden';
  }

  @override
  String arg1HArg2M(Object? arg1, Object? arg2) {
    return '${arg1}h ${arg2}m';
  }

  @override
  String arg1HArg2Min(Object? arg1, Object? arg2) {
    return '$arg1 h $arg2 min';
  }

  @override
  String arg1Helpers(Object? arg1) {
    return '$arg1 hjælpere';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 hit ratio)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 er en admin, så kontoen kan ikke slettes ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 er blokeret på $arg2. Opdater adgangslisten for at tillade svar.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 er tilsluttet og reagerer.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 er ikke længere en administrator ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 er ikke tilgængelig på $arg2 (manglende køretidstilladelse eller afhængighed).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 tilsluttet sig under $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 bedømt af LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 nøgle$arg2 konfigureret';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return '$arg1 nøgle fjernet.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 venstre';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 venstre $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 linket';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m siden';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Sørg for, at den kører, og prøv derefter igen.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 administrerer denne konto';
  }

  @override
  String arg1Mb(Object? arg1) {
    return '$arg1 MB';
  }

  @override
  String arg1Min(Object? arg1) {
    return '$arg1 min';
  }

  @override
  String arg1MinArg2Sec(Object? arg1, Object? arg2) {
    return '$arg1 min $arg2 sek';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return '$arg1 modeller klar';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 mere';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 flere trin i kørselshistorikken';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 flyttet fra $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 skal være et endeligt tal.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 skal være en http://- eller https://-adresse.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 har brug for opmærksomhed';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent Workspace';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 nye konti i den sidste $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nye beskeder styrer denne kørsel';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 nye kørsler';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 administrerer nu denne konto.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 af 4 tilladelser tilladt. Filer er begrænset til din NeoAgent Workspace-mappe.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 af $arg2 aktiveret';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 af $arg2 grupper deltager i almindelig chat';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 af $arg2 modeller';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 af $arg2 modeller klar';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 af $arg2 sæt';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 af $arg2 værktøjer tilladt';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 på dag $arg2 på $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 svarer kun til de personer, du tilføjer nedenfor.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 svarer kun, når den er tagget';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 taler kun med personer og grupper, du godkender';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 personer eller grupper tilføjet';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 planlægning';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1 udbydere';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 klar';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 optegnelser';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 omdirigerings-URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registreret';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 svarede';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 tilbagekaldte et invitationslink';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 kører';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 kører · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 kører i den sidste $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 gemt.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 valgt';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 vist';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 forblev stille';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 styretøj $arg2 i kø';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · tryk på en node for at inspicere';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 trin';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 stoppede med at administrere $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 tokens';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 tokens i den sidste $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 værktøjer';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (utilgængelig gemt tilsidesættelse)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1 % brugt · $arg2 tilbage';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 vil gerne tale med dig.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 web';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" vil blive fjernet permanent.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 vil administrere denne konto';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 vil ikke svare på denne platform';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 vil ikke svare på $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Artefaktlagring efter bruger';

  @override
  String get askAQuestionOrStartA =>
      'Stil et spørgsmål eller start en opgave...';

  @override
  String get askBeforeClosingToBackground =>
      'Spørg før du lukker til baggrunden';

  @override
  String get askMe => 'Spørg mig';

  @override
  String get assignedAgent => 'Tildelt agent';

  @override
  String get assignedAgent2 => 'Tildelt agent';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Tildelt agent: $arg1';
  }

  @override
  String get assigneeOptional => 'Modtager (valgfrit)';

  @override
  String get assistant => 'Assistent';

  @override
  String get assistantKey131 => 'Assistent-tast 131';

  @override
  String get atLeast1 => 'Mindst 1.';

  @override
  String get atLeast1000AppliesAfterA =>
      'Mindst 1000. Gælder efter en servergenstart.';

  @override
  String get attachFiles => 'Vedhæft filer';

  @override
  String attentionArg1(Object? arg1) {
    return 'Bemærk $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'revisionslog Admin bevilling tilbagekald invitationsteamhistorik';

  @override
  String get authMethod => 'Auth metode';

  @override
  String get authServerUrl => 'Auth Server URL';

  @override
  String get authentication => 'Autentificering';

  @override
  String get authenticationFailed => 'Godkendelse mislykkedes.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Godkendelse afventer stadig. Afslut browserflowet, og prøv igen.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Godkendelse afventer stadig. Afslut browserflowet og opdater.';

  @override
  String get authenticationTimedOut => 'Godkendelsestiden udløb.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Godkendelse blev annulleret før fuldførelse.';

  @override
  String get authenticatorApp => 'Authenticator app';

  @override
  String get authenticatorCode => 'Autentificeringskode';

  @override
  String get authorOptional => 'Forfatter (valgfrit)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (første udbyder med en API-nøgle)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Auto-ruter til den bedst tilgængelige model';

  @override
  String get automaticFast => 'Automatisk (hurtig)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatisk læser rummet og holder sig normalt tilbage. Mention-only foretager ingen beslutningsopkald, før den rettes direkte.';

  @override
  String get automaticReserved => 'Automatisk, reserveret';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automatisk tilbagerulning skal prøves igen fra opsætningsskærmen.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatisk vælger en hurtig model gennem det normale modelkatalog.';

  @override
  String get automation => 'Automatisering';

  @override
  String get available => 'Tilgængelig';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Tilgængelig igen i $arg1';
  }

  @override
  String get availableAgainShortly => 'Tilgængelig igen snart';

  @override
  String get availableInTheDesktopAppFor =>
      'Tilgængelig i desktop-appen til macOS, Windows og Linux';

  @override
  String get availableToTheAgent => 'Tilgængelig for agenten';

  @override
  String get averageAllTime => 'Gennemsnit, hele tiden';

  @override
  String get avgImp => 'Gns. imp.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Gns/kør: $arg1 tokens';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Undgå gentagne tegn og åbenlyse sekvenser.';

  @override
  String get awaitingScan => 'Afventer scanning';

  @override
  String get back => 'Tilbage';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count i baggrunden';
  }

  @override
  String get backgroundTasks => 'Baggrundsopgaver';

  @override
  String get backOn => 'tilbage på.';

  @override
  String get backToChat => 'Tilbage til chat';

  @override
  String get backToFolder => 'Tilbage til mappen';

  @override
  String get backToSignIn => 'Tilbage for at logge ind';

  @override
  String get backendChannel => 'Backend kanal';

  @override
  String get backendOnThisComputer => 'Backend på denne computer';

  @override
  String get backendSync => 'Backend-synkronisering';

  @override
  String get backgroundLocationNeeded => 'Baggrundsplacering nødvendig';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Baggrundssynkronisering forbliver planlagt på Android';

  @override
  String get badState => 'Dårlig tilstand: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Basisbillede og størrelse af de virtuelle QEMU-maskiner, der kører ';

  @override
  String get baseUrlOptional => 'Basis-URL (valgfrit)';

  @override
  String get baseUrlTokenLocal => 'base url token lokal';

  @override
  String get basicAuthentication => 'Grundlæggende godkendelse';

  @override
  String get behaviorModules => 'Adfærdsmoduler';

  @override
  String get behaviorNotes => 'adfærdsnotater';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Bitwarden legitimationsmægler';

  @override
  String get bitwardenItem => 'Bitwarden vare';

  @override
  String get bitwardenServer => 'Bitwarden server';

  @override
  String get blankUsesCommon => 'Blank bruger \"almindelig\"';

  @override
  String get blankUsesTheDefaultCallback => 'Blank bruger standardtilbagekald';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Blanke værdier bruger udbyderens standardindstillinger.';

  @override
  String get block => 'Bloker';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Blokeret indgående besked fra $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'BlueBubbles-kompatibel bro';

  @override
  String get bluebubblesServerUrl => 'BlueBubbles server URL';

  @override
  String get botToken => 'Bot token';

  @override
  String get botTokenAndApprovedChats => 'Bot-token og godkendte chats';

  @override
  String get botTokenAndServerChannelAccess => 'Bottoken og server/kanaladgang';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bottoken, Events API og kanaladgang';

  @override
  String get botUserId => 'Bot bruger-id';

  @override
  String get botUsername => 'Bot brugernavn';

  @override
  String get brandName => 'Mærkenavn';

  @override
  String get braveSearch => 'Modig Søgning';

  @override
  String get breakdown => 'Opdeling:';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Bridge enhver udbyder, der kan sende og modtage webhook-nyttelast.';

  @override
  String get bringYourOwnKey => 'medbring din egen nøgle';

  @override
  String get bringYourOwnKey2 => 'Medbring din egen nøgle';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Browser, Linux-desktop, filer, terminal og Python deler én vedvarende cloud-computer.';

  @override
  String get browserLogin => 'Browser login';

  @override
  String get browserScripting => 'Browser scripting';

  @override
  String get call => 'Ring';

  @override
  String get callAgent => 'Ring til agent';

  @override
  String get callUser => 'Ring til bruger';

  @override
  String get calledByName => 'Kaldet ved navn';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Kan uddelegere opgaver til andre agenter';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Kan uddelegere til $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Kan modtage delegerede opgaver';

  @override
  String get cancel => 'Annuller';

  @override
  String get cancelTask => 'Annuller opgave';

  @override
  String candidateCountArg1(Object? arg1) {
    return 'Antal kandidater: $arg1';
  }

  @override
  String get cannotPreview => 'Kan ikke forhåndsvise';

  @override
  String get cannotReceiveDelegatedTasks =>
      'kan ikke modtage delegerede opgaver';

  @override
  String get cannotRunYet => 'kan ikke køre endnu.';

  @override
  String get capturedThePage => 'Fangede siden';

  @override
  String get category => 'Kategori';

  @override
  String chainArg1(Object? arg1) {
    return 'Kæde: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Skift opsætningstilstand';

  @override
  String get channel => 'Kanal';

  @override
  String get channelAccessToken => 'Kanaladgangstoken';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanal: $arg1$arg2 | Opdateringsversion: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Kanalbaseret social hukommelse';

  @override
  String get channels => 'Kanaler';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'Chat-id';

  @override
  String get chatMode => 'Chattilstand';

  @override
  String get chatModel => 'Chat model';

  @override
  String get checkAutomaticallyOnLaunch => 'Tjek automatisk ved lancering';

  @override
  String get checkForMessagesEveryMs => 'Tjek for beskeder hver (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Tjek automatisk efter nye beskeder';

  @override
  String get checkNow => 'Tjek nu';

  @override
  String get checkYourEmailToConfirmYour =>
      'Tjek din e-mail for at bekræfte din NeoAgent-konto, før du logger ind.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Tjekket $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Vælg en kategori, eller søg på tværs af alle indstillinger.';

  @override
  String get chooseAPerson => 'Vælg en person';

  @override
  String get chooseAProjectFolder => 'Vælg en projektmappe';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Vælg standardindstillinger for chat, agenter, reserveadfærd og smart routing.';

  @override
  String get chooseGroups => 'Vælg grupper';

  @override
  String get chooseHowMuchYouWantTo =>
      'Vælg, hvor meget du vil konfigurere nu. Begge muligheder kan ændres senere.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Vælg, hvordan denne opgave skal starte. Manuelt kører kun på Kør nu. Tidsplanen er tidsbaseret. Integration udløser brand fra tilsluttede officielle apps.';

  @override
  String get chooseOneToGetStartedNow =>
      'Vælg en for at komme i gang nu. Du kan tilføje flere senere.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Vælg live-model og stemme i Indstillinger.';

  @override
  String get chooseTheirGroup => 'Vælg deres gruppe';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Vælg, hvor denne person skal have lov til at tale med $arg1. Du kan ændre dette senere under Hvem kan besked.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Vælg hvilke grupper $arg1 skal deltage i, selv når ingen tagger den. Denne platform adskiller muligvis ikke tags fra almindelige beskeder.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Vælg hvilke modeller hver konto på denne server kan vælge og ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Vælg, hvem $arg1 taler med, og hvornår den deltager i gruppechat.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Vælg, hvem der kan nå $arg1, og gem derefter dine ændringer.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Vælg, hvem der må sende en besked til agenten med \"Hvem kan sende en besked\" på WhatsApp-kortet.';

  @override
  String get chooseYourDefaultModel => 'Vælg din\nstandardmodel.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, filer, teksteditoren og terminalen er alle tilgængelige fra Linux-skrivebordet.';

  @override
  String get claudeCode => 'Claude kode';

  @override
  String get clear => 'Ryd';

  @override
  String get clearAll => 'Ryd alle';

  @override
  String clearArg1(Object? arg1) {
    return 'Vil du slette $arg1?';
  }

  @override
  String get clearFilter => 'Ryd filter';

  @override
  String get clearFilters => 'Ryd filtre';

  @override
  String get clearSearch => 'Ryd søgning';

  @override
  String get clearView => 'Klart udsyn';

  @override
  String get cliSession => 'CLI session';

  @override
  String get clickIsNotSupportedOnThis =>
      'klik understøttes ikke på denne platform.';

  @override
  String get clickOnceToBeginCapturing =>
      'Klik én gang for at begynde at optage';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Klik, skriv og interager med desktop-apps.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Klikket på ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Klik i browseren';

  @override
  String get clientId => 'Klient-id';

  @override
  String get clientSecret => 'Klientens hemmelighed';

  @override
  String get close => 'Luk';

  @override
  String get closeJ => 'Luk (⌘J)';

  @override
  String get closeTeachMode => 'Luk Teach Mode';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Lukning af vinduet kan enten holde NeoAgent kørende i baggrunden med bakkeadgang, eller afslutte skrivebordets runtime helt.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Cloud- og selvhostede forekomster understøttes. Lokale og private netværks-URL\'er fungerer, når NeoAgent kan nå dem.';

  @override
  String get cloudComputer => 'Cloud computer';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Cloud-computer · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Cloud-computerindstillinger gemt. Genstart serveren for at anvende dem.';

  @override
  String get cloudComputerVm => 'Cloud-computer (VM)';

  @override
  String get cloudComputers => 'Cloud-computere';

  @override
  String get codeHosting => 'Kode hosting';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Kommaseparerede kanalnavne uden #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Kommasepareret, for eksempel #generelt, #hjælp';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Komma adskilt. Spørgsmålet skal have dem alle.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kommando mislykkedes ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Kommando er påkrævet.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Kommandoudgangsakkumulator er ikke aktiv.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kommando output upload mislykkedes ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Kommando output upload udeladt artefakt metadata.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Kommandooutput var allerede afsluttet.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Kommandoer og apps';

  @override
  String get commandsRunInTheSamePersistent =>
      'Kommandoer kører på den samme vedvarende computer, der bruges af det synlige skrivebord.';

  @override
  String get communityChatops => 'Community & ChatOps';

  @override
  String get completeSetup => 'Fuldfør opsætning';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Fuldfør arbejdsgangen på skrivebordet.';

  @override
  String get completed => 'Afsluttet';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Fuldstændig blokeret — agenten kan ikke bruge denne kategori.';

  @override
  String get computerShell => 'Computerskal';

  @override
  String get computerUsedByThisSession => 'Computer brugt af denne session';

  @override
  String get computerWorkspace => 'Computer arbejdsområde';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigurerbar personlig webhook-bro';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigurerbart relæ eller webhook-bro';

  @override
  String get configurableTalkWebhookBridge => 'Konfigurerbar Talk webhook-bro';

  @override
  String get configurableWebInboxBridge => 'Konfigurerbar web-indbakkebro';

  @override
  String get configurableWebhookBridge => 'Konfigurerbar webhook-bro';

  @override
  String get configurableWebhooks => 'Konfigurerbare Webhooks';

  @override
  String get configurationOrInTheEnvFile => 'Konfiguration eller i .env-filen.';

  @override
  String get configure => 'Konfigurer';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Konfigurer arbejdsområdeadfærd og modelstandarder.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Konfigureret $arg1';
  }

  @override
  String get confirmEmailChanges => 'Bekræft e-mail-ændringer';

  @override
  String get confirmNewSignUps => 'Bekræft nye tilmeldinger';

  @override
  String get confirmPassword => 'Bekræft adgangskode';

  @override
  String get confirmPassword2 => 'Bekræft adgangskode';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Bekræft din e-mail, før du logger ind. Tjek tjeneste-e-mail-beskeden fra NeoAgent.';

  @override
  String get connect => 'Forbind';

  @override
  String get connectAMessagingPlatform => 'Tilslut en\nmeddelelsesplatform.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Forbind et offentligt HTTPS Home Assistant-endepunkt med et Long-Lived Access Token. Lokale, loopback- og private netværksadresser blokeres af serveren.';

  @override
  String get connectAccount => 'Tilslut konto';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Forbind appkonti individuelt, så AI kan bruge den rigtige konto til hver officiel integration.';

  @override
  String connectArg1(Object? arg1) {
    return 'Tilslut $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Tilslut så mange konti, som du vil. Hver app kan bruge en anden konto.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Forbind kanaler, vælg, hvem $arg1 taler med, og se seneste aktivitet.';
  }

  @override
  String get connectInstance => 'Tilslut instans';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Tilslut først denne integration for at vælge en konto.';

  @override
  String get connectToThisServer => 'Opret forbindelse til denne server';

  @override
  String get connectWhatsapp => 'Tilslut WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Tilslut din Nextcloud-instans, inklusive selv-hostede servere. NeoAgent åbner Nextclouds egen login-side, så du kan logge ind med adgangskode, SSO eller 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Tilslut din selv-hostede NeoRecall-server. NeoAgent modtager skrivebeskyttet adgang til lokal søgning, hukommelser og transskriptionsbeviser, når du har godkendt OAuth-skærmen.';

  @override
  String get connected => 'Forbundet';

  @override
  String get connectedAccount => 'Tilknyttet konto';

  @override
  String connectedArg1(Object? arg1) {
    return 'Tilsluttet $arg1';
  }

  @override
  String get connectedInstance => 'Forbundet instans';

  @override
  String get connectedNeorecallUser => 'Tilsluttet NeoRecall-bruger';

  @override
  String get connectedNextcloudUser => 'Tilsluttet Nextcloud-bruger';

  @override
  String get connectedServer => 'Tilsluttet server';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Opretter forbindelse til live-stemmemodellen...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Forbindelse #$arg1';
  }

  @override
  String get connectionId => 'Forbindelses-id';

  @override
  String get connectionLooksGood => 'Forbindelsen ser godt ud.';

  @override
  String get connectionMethod => 'Tilslutningsmetode';

  @override
  String get containsTextOptional => 'Indeholder tekst (valgfrit)';

  @override
  String get content => 'Indhold';

  @override
  String contentArg1(Object? arg1) {
    return 'Indhold: $arg1';
  }

  @override
  String get contentSecurityPolicy => 'indholdssikkerhedspolitik';

  @override
  String get continue2 => 'Fortsæt';

  @override
  String get continueFullSetup => 'Fortsæt fuld opsætning';

  @override
  String get continueRun => 'Fortsæt løb';

  @override
  String get continueToSetup => 'Fortsæt til opsætning';

  @override
  String get controlSurface => 'KONTROLOVERFLADE';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Styrer adgangen til $arg1-værktøjer.';
  }

  @override
  String get conversation => 'Samtale';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Samtale-id, der bruges, når denne agent starter en chat.';

  @override
  String get cookieSetup => 'Cookie opsætning';

  @override
  String get cookiesNotConfigured => 'Cookies ikke konfigureret';

  @override
  String get copiedAsCsv => 'Kopieret som CSV';

  @override
  String get copiedDebugInfo => 'Kopierede fejlretningsoplysninger';

  @override
  String get copiedExportForTheLast5 =>
      'Kopieret eksport for de sidste 5 beskeder';

  @override
  String get copiedFullPrompt => 'Kopieret fuld prompt';

  @override
  String get copiedLogs => 'Kopierede logfiler';

  @override
  String get copiedRunId => 'Kørsels-id er kopieret';

  @override
  String get copy => 'Kopiér';

  @override
  String get copyAll => 'Kopier alle';

  @override
  String get copyCodes => 'Kopier koder';

  @override
  String get copyCsv => 'Kopiér CSV';

  @override
  String get copyDebugInfo => 'Kopiér fejlretningsoplysninger';

  @override
  String get copyLink => 'Kopiér link';

  @override
  String get copyLogs => 'Kopier logfiler';

  @override
  String get copyPrompt => 'Kopiér prompt';

  @override
  String get copyResponse => 'Kopiér svar';

  @override
  String get copyRunId => 'Kopiér køre-id';

  @override
  String get copyWebhookUrl => 'Kopiér webhook-URL';

  @override
  String get core => 'Kerne';

  @override
  String get coreMemory => 'kernehukommelse';

  @override
  String get coreServicesThisServerDependsOn =>
      'Kernetjenester denne server afhænger af.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domæne https offentlig url oprindelse';

  @override
  String get couldHelp => 'kunne hjælpe';

  @override
  String get couldNotApproveQrLogin => 'Kunne ikke godkende QR-login.';

  @override
  String get couldNotApproveQrPairing => 'Kunne ikke godkende QR-parring.';

  @override
  String get couldNotConnect => 'Kunne ikke oprette forbindelse.';

  @override
  String get couldNotCreateBinding => 'Kunne ikke oprette binding.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Kunne ikke slette din konto: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Kunne ikke afbryde Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Hjemmeassistenten kunne ikke afbrydes.';

  @override
  String get couldNotDisconnectNeorecall => 'Kunne ikke afbryde NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud => 'Kunne ikke afbryde Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Kunne ikke afbryde Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Kunne ikke eksportere dine data: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Kunne ikke indlæse beslutninger';

  @override
  String get couldNotLoadUsageData => 'Kunne ikke indlæse brugsdata.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Kunne ikke åbne Linux-indstillinger automatisk.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Kunne ikke åbne udbyderens linkside.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Kunne ikke åbne udbyderens login-side.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Kunne ikke åbne frigivelsesaktivet.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Kunne ikke åbne Trello i din browser.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Kunne ikke åbne download af arbejdsområdefil.';

  @override
  String get couldNotReadTheAndroidApp => 'Kunne ikke læse Android-apppakken.';

  @override
  String get couldNotReadTheApk => 'Kunne ikke læse APK\'en.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Kunne ikke fjerne nøglen: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Agenten kunne ikke gemmes.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Kunne ikke gemme Bitwarden-opsætningen.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Home Assistant-opsætningen kunne ikke gemmes.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Kunne ikke gemme NeoRecall-opsætningen.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Kunne ikke gemme Nextcloud-opsætningen.';

  @override
  String get couldNotSaveTrelloSetup => 'Trello-opsætningen kunne ikke gemmes.';

  @override
  String get couldNotSendConfirmationEmail =>
      'kunne ikke sende bekræftelsesmail';

  @override
  String get couldNotStart => 'Kunne ikke starte';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Opret';

  @override
  String get createAPasswordFirstToChange =>
      'Opret først en adgangskode for at ændre din konto-e-mail.';

  @override
  String get createAPasswordOrLinkAnother =>
      'oprette en adgangskode eller linke en anden udbyder, før du fjerner denne login-metode';

  @override
  String get createATaskWhileThisAgent =>
      'Opret en opgave, mens denne agent er valgt.';

  @override
  String get createLink => 'Opret link';

  @override
  String get createOrModifyFilesInYour =>
      'Opret eller rediger filer i dit arbejdsområde.';

  @override
  String get createPassword => 'Opret adgangskode';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Opret specialist-bots med separate hukommelse, indstillinger, værktøjer og kontotildelinger.';

  @override
  String get createTheFirstAccount => 'Opret den første konto';

  @override
  String get createUpdateOrDeleteSkills =>
      'Opret, opdater eller slet færdigheder.';

  @override
  String get creatingYourSkill => 'Skaber dine færdigheder...';

  @override
  String get credentialBindings => 'Legitimationsbindinger';

  @override
  String get credentialUse => 'Brug af legitimationsoplysninger';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Cron-baserede tilbagevendende kørsler og engangstidsudførelse.';

  @override
  String get cronExpression => 'Cron udtryk';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter kører forespørgslen.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Mellemrum';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Nuværende e-mail: $arg1';
  }

  @override
  String get currentPassword => 'Nuværende adgangskode';

  @override
  String get currentPasswordIsIncorrect => 'nuværende adgangskode er forkert';

  @override
  String get currentTwoStepLoginCode => 'Aktuel to-trins login-kode';

  @override
  String get customAccess => 'Brugerdefineret adgang';

  @override
  String get customCron => 'Brugerdefineret Cron';

  @override
  String get customCronMustHave5Fields => 'Custom Cron skal have 5 felter.';

  @override
  String get customEndpoint => 'tilpasset slutpunkt';

  @override
  String get customField => 'Brugerdefineret felt';

  @override
  String get customHeader => 'Brugerdefineret overskrift';

  @override
  String get customHeadersJson => 'Tilpassede overskrifter (JSON)';

  @override
  String get customOpenaiCompatible => 'Brugerdefineret OpenAI-kompatibel';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Brugerdefineret OpenAI-kompatibelt slutpunkt';

  @override
  String get customOutgoingUrl => 'Tilpasset udgående URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Dagligt';

  @override
  String get dailyRecap => 'Daglig opsummering';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'databaseforespørgsel vælg csv-skabeloner';

  @override
  String dayArg1(Object? arg1) {
    return 'Dag $arg1';
  }

  @override
  String get dayOfMonth => 'Dag i måneden';

  @override
  String get decideWhichToolsYourAgentMay =>
      'beslutte, hvilke værktøjer din agent må bruge. De ser dit navn og ';

  @override
  String get decisionHigherUpTheChainWins =>
      'beslutning højere oppe vinder kæden og viser en lås med ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Beslutninger vises her, da $arg1 læser godkendte $arg2-grupper. Kun de seneste 30 beholdes, og de nulstilles, når serveren genstarter.';
  }

  @override
  String get decline => 'Afslå';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'dybt løb · trin $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram nøgle';

  @override
  String get default2 => 'Standard';

  @override
  String get default3 => 'STANDARD';

  @override
  String defaultArg1(Object? arg1) {
    return 'Standard ($arg1)';
  }

  @override
  String get defaultConversation => 'Standard samtale';

  @override
  String get defaultForNewGroups => 'Standard for nye grupper';

  @override
  String get defaultGroupParticipation => 'Standard gruppedeltagelse';

  @override
  String get defaultNeoagentWorkspace => 'Standard NeoAgent-arbejdsområde';

  @override
  String get defaultOpenai => 'Standard (OpenAI)';

  @override
  String get defaultRateLimits => 'Standard satsgrænser';

  @override
  String get defaultRateLimitsSaved => 'Standardhastighedsgrænser gemt.';

  @override
  String get defaultRecommended => 'Standard (anbefales)';

  @override
  String get defaultRouting => 'Standard Routing';

  @override
  String get defaultSpace => 'Standardplads';

  @override
  String get delete => 'Slet';

  @override
  String get deleteAccount => 'Slet konto';

  @override
  String get deleteAccountPermanently => 'Vil du slette kontoen permanent?';

  @override
  String get deleteAnAccount => 'Slet en konto';

  @override
  String deleteArg1(Object? arg1) {
    return 'Vil du slette @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Slet ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Vil du slette $arg1 $arg2 permanent?';
  }

  @override
  String get deleteBinding => 'Slet binding';

  @override
  String get deleteCoreMemoryEntry => 'Vil du slette kernehukommelsen?';

  @override
  String get deleteForever => 'Slet for altid';

  @override
  String get deleteMcpServer => 'Vil du slette MCP-serveren?';

  @override
  String get deleteMemory => 'Vil du slette hukommelsen?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Slet sletter permanent en konto og alle dens data ';

  @override
  String get deleteRun => 'Vil du slette kørslen?';

  @override
  String get deleteRun2 => 'Slet kørsel';

  @override
  String get deleteSelectedMemories => 'Vil du slette valgte minder?';

  @override
  String get deleteSession => 'Vil du slette session?';

  @override
  String get deleteSkill => 'Vil du slette færdighed?';

  @override
  String get deleteTask => 'Vil du slette opgaven?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Slettet \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Slettet @$arg1 og alle deres data.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Sletning fjerner alle dine samtaler, minder, filer, opgaver og ';

  @override
  String get deliverableArtifactProduced => 'Leverbar artefakt produceret';

  @override
  String get deliverableCompleted => 'Levering gennemført';

  @override
  String get deliverableExecutionStarted => 'Leverbar udførelse startet';

  @override
  String get deliverableSelected => 'Leverbar valgt';

  @override
  String get deliverableValidationFailed =>
      'Validering af levering mislykkedes';

  @override
  String get deliverableValidationStarted => 'Leveringsvalidering startede';

  @override
  String get deny => 'Afvis';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Beskriv resultatet, og demonstrer det derefter på skrivebordet';

  @override
  String get describeWhatToBuildOrChange =>
      'Beskriv, hvad du skal bygge eller ændre...';

  @override
  String get description => 'Beskrivelse';

  @override
  String get desktopApp => 'Desktop app';

  @override
  String get desktopAppControlsAvailable =>
      'Desktop app kontroller tilgængelige';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Desktop capture er ikke tilgængelig på denne platform.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Desktop-kommando-output-upload annulleret.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Desktop companion-kommandoen blev annulleret.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Desktop-ledsagende forbindelse fik timeout.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Desktop-ledsagende håndtryk fik timeout.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Desktop companion er ikke tilgængelig her.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Desktop companion er sat på pause lokalt.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Håndtering af ledsagende meddelelser på skrivebordet mislykkedes: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Indstillinger for tilladelser for ledsagende computere er ikke tilgængelige på nettet.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Indstillinger for tilladelser for ledsagende computere er ikke tilgængelige på denne platform.';

  @override
  String get desktopCompanionRejected => 'Desktop companion afvist.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Skrivebordsledsagende svar mislykkedes: $arg1';
  }

  @override
  String get desktopControl => 'Desktop kontrol';

  @override
  String get desktopFailedToStart => 'Desktop kunne ikke starte';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Streaming på skrivebordet mislykkedes: $arg1';
  }

  @override
  String get destinationId => 'Destinations-id';

  @override
  String get deviceAccess => 'Enhedsadgang';

  @override
  String get deviceSettings => 'Enhedsindstillinger';

  @override
  String get devices => 'Enheder';

  @override
  String get diagnosticsSaved => 'Diagnostik gemt.';

  @override
  String get directBluebubblesImessageBridge =>
      'Direkte BlueBubbles iMessage-bro';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Direkte beskeder forbliver responsive. Tilladte grupper bruger deltagelsestilstanden nedenfor.';

  @override
  String get directoryDoesNotExist => 'Directory eksisterer ikke.';

  @override
  String get disable2fa => 'Deaktiver 2FA';

  @override
  String get disableAll => 'Deaktiver alle';

  @override
  String get discard => 'Kassér';

  @override
  String get disconnect => 'Afbryd forbindelsen';

  @override
  String get disconnectHomeAssistant => 'Afbryde Home Assistant?';

  @override
  String get disconnectNeorecall => 'Afbryde forbindelsen til NeoRecall?';

  @override
  String get disconnectNextcloud => 'Afbryd forbindelsen til Nextcloud?';

  @override
  String get disconnectPlatform => 'Afbryd platformen';

  @override
  String get disconnectTrello => 'Afbryde forbindelsen til Trello?';

  @override
  String get discoveryFailed => 'Opdagelsen mislykkedes';

  @override
  String get dismiss => 'Afvis';

  @override
  String get displayIdIsRequired => 'Display-id er påkrævet.';

  @override
  String get displayName => 'Vist navn';

  @override
  String get displayNameMustBe64Characters =>
      'Vist navn skal være på 64 tegn eller derunder.';

  @override
  String get displayNameSaved => 'Vist navn gemt.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Inkluder ikke dit brugernavn eller e-mail.';

  @override
  String get done => 'Færdig';

  @override
  String get downloadACopyOfYourData =>
      'Download en kopi af dine data. Administratorkonti kan ikke slettes ';

  @override
  String get downloadACopyOfYourData2 =>
      'Download en kopi af dine data, eller slet din konto permanent. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Download $arg1';
  }

  @override
  String get downloadUpdate => 'Download opdatering';

  @override
  String get downloadingTheNeoagentBackend => 'Downloader NeoAgent-backend';

  @override
  String get draft => 'Udkast';

  @override
  String get dragIsNotSupportedOnThis =>
      'træk er ikke understøttet på denne platform.';

  @override
  String get draggedOnTheScreen => 'Træk på skærmen';

  @override
  String get dropAnApkOrApkBundle =>
      'Slip en APK- eller APK-pakke her for at installere den';

  @override
  String get dropApkOrApksHere => 'Drop APK eller .apks her';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Holdbare instruktioner til stemme og interaktionsstil. Sikkerhed og udførelsesregler har stadig prioritet.';

  @override
  String get eGAlexSLaptop => 'f.eks. Alex\'s bærbare computer';

  @override
  String get eGMyLocalServer => 'f.eks. Min lokale server';

  @override
  String get edit => 'Rediger';

  @override
  String get editAgent => 'Rediger agent';

  @override
  String get editCoreMemoryEntry => 'Rediger Core Memory Entry';

  @override
  String get editInstructions => 'Rediger instruktioner';

  @override
  String get editMcpServer => 'Rediger MCP-server';

  @override
  String get editTask => 'Rediger opgave';

  @override
  String editedArg1(Object? arg1) {
    return 'Redigeret $arg1';
  }

  @override
  String get email => 'E-mail';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'E-mail-kontoejere om logins, der ser usædvanlige ud.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'E-mail kontoejere, når deres kontooplysninger ændres.';

  @override
  String get emailCode => 'E-mail kode';

  @override
  String get emailConfirmationRequired => 'e-mail bekræftelse påkrævet';

  @override
  String get emailIsAlreadyInUse => 'e-mail er allerede i brug';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail gemt. Hvis bekræftelse er påkrævet, skal du kontrollere den nye adresse for et NeoAgent-bekræftelseslink.';

  @override
  String get emailSettingsSaved => 'E-mail-indstillinger gemt.';

  @override
  String get emailUnverified => 'E-mail ubekræftet';

  @override
  String get empty => 'Tom';

  @override
  String get emptyFile => 'Tom fil';

  @override
  String get emptyFolder => 'Tom mappe';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Empty bruger serverstandarden ($arg1).';
  }

  @override
  String get enable2fa => 'Aktiver 2FA';

  @override
  String get enableAll => 'Aktiver alle';

  @override
  String get enableBehaviorModules => 'Aktiver adfærdsmoduler';

  @override
  String get enableOrDisableModels => 'Aktiver eller deaktiver modeller';

  @override
  String get enabled => 'Aktiveret';

  @override
  String get encryptedPrivateToYourAccount => 'Krypteret, privat til din konto';

  @override
  String get end => 'Slut';

  @override
  String get endCall => 'Afslut opkald';

  @override
  String get endVoiceCall => 'Vil du afslutte taleopkaldet?';

  @override
  String get endpoint => 'Slutpunkt';

  @override
  String get enterAPassword => 'Indtast en adgangskode.';

  @override
  String get enterAUsername => 'Indtast et brugernavn.';

  @override
  String get enterAValidEmailAddress => 'Indtast en gyldig e-mailadresse.';

  @override
  String get enterAnAddressManually => 'Indtast en adresse manuelt';

  @override
  String get enterAnApiKeyFirst => 'Indtast først en API-nøgle.';

  @override
  String get enterInviteLink => 'Indtast invitationslink';

  @override
  String get enterTheAddressOfANeoagent =>
      'Indtast adressen på en NeoAgent-server.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Indtast de detaljer, $arg1 gav dig, så $arg2 kan sende og modtage beskeder.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Indtast din 2FA- eller gendannelseskode.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Indtast din nuværende adgangskode for at ændre den.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Indtast din nuværende adgangskode for at gemme e-mail-ændringer.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Indtast dine NeoAgent-kontooplysninger.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Indtast dit brugernavn eller din konto-e-mail. NeoAgent sender et nulstillingslink, hvis det kan matche kontoen.';

  @override
  String get enterYourUsernameOrEmail =>
      'Indtast dit brugernavn eller din e-mail.';

  @override
  String entityArg1(Object? arg1) {
    return 'Enhed: $arg1';
  }

  @override
  String get environment => 'Miljø';

  @override
  String get error => 'Fejl';

  @override
  String errorArg1(Object? arg1) {
    return '\nfejl: $arg1';
  }

  @override
  String errorArg12(Object? arg1) {
    return 'Fejl: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Fejl fra den seneste log, grupperet efter besked.';

  @override
  String get errorsProblemsFailures => 'fejl problemer fejl';

  @override
  String get eventTypesCommaSeparated => 'Hændelsestyper (kommasepareret)';

  @override
  String get every15Minutes => 'Hvert 15. minut';

  @override
  String get every30Minutes => 'Hvert 30. minut';

  @override
  String get everyAccountOnThisServerLoses =>
      'Hver konto på denne server mister denne delte nøgle. Regnskaber ';

  @override
  String get everyAccountOnThisServerSecrets =>
      'hver konto på denne server. Hemmeligheder er skrivebeskyttede: forlad ';

  @override
  String get everyAccountOnThisServerUses =>
      'Hver konto på denne server bruger denne adresse til ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Hver aktiv session for denne konto slutter. De kan logge ind ';

  @override
  String get everyDay0800 => 'Hver dag · 08:00';

  @override
  String get everyDay2000 => 'Hver dag · 20:00';

  @override
  String get everyHour => 'Hver time';

  @override
  String get everyRunOnThisServerAll =>
      'Hver kørsel på denne server, hele tiden.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Ethvert følsomt værktøj kræver godkendelse, hver gang.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Hvert værktøj kører uden at spørge, undtagen dem personen ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Alle i disse grupper, kanaler eller rum kan tale med $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Alle i denne gruppe';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Alt, hvad $arg1 har slået fra for din agent, kommer ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Alt andet er slået fra.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Alt er tilgængeligt fra skrivebordet.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Alt, hvad agenten kan bruge: officielle integrationer, MCP-servere og færdigheder.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Alt, hvad du har slået fra for $arg1, kommer tilbage ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Præcise web-oprindelse tilladt at fremsætte anmodninger om krydsoprindelse, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Udfør JavaScript i din browsersession.';

  @override
  String get execution => 'Udførelse';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Udførelsesdetaljer er ikke tilgængelige for denne kørsel.';

  @override
  String get executionPlanCreated => 'Udførelsesplan oprettet.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Træn $arg1 sessioner';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[afslut $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Udløber $arg1';
  }

  @override
  String get explainThisProject => 'Forklar dette projekt';

  @override
  String exploredArg1(Object? arg1) {
    return 'Udforsket $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Udforsket $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Udforsket arbejdsområdet';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Eksport mislykkedes: $arg1';
  }

  @override
  String get exportLast5Messages => 'Eksporter de sidste 5 beskeder';

  @override
  String get exportMyData => 'Eksporter mine data';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Ekstern browserstart mislykkedes med exitkode $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Ekstern browserstart understøttes ikke på denne platform.';

  @override
  String get externalBrowserLaunchTimedOut => 'Ekstern browser start timeout.';

  @override
  String get externalMcpTools => 'Eksterne & MCP-værktøjer';

  @override
  String get extraButtons => 'Ekstra knapper';

  @override
  String get extractingTheNeoagentRuntime => 'Udpakning af NeoAgent runtime';

  @override
  String get failed => 'Mislykkedes';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Kunne ikke oprette forbindelse: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kunne ikke oprette forbindelse $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kunne ikke slette \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'kunne ikke hente';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Kunne ikke generere prompt: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Kunne ikke starte ekstern browser via url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Kunne ikke starte OAuth-flow.';

  @override
  String get failedToLoadPolicies => 'Politikker kunne ikke indlæses';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Kunne ikke gemme: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'MCP-serveren kunne ikke gemmes.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Kunne ikke gemme valg: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Kunne ikke sende meddelelse til backend: $arg1';
  }

  @override
  String get fair => 'Fair';

  @override
  String get fasterReplies => 'Hurtigere svar';

  @override
  String get fewerModelCalls => 'Færre modelopkald';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'felt tomt for at gendanne den indbyggede standard.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Filen overskrider editorgrænsen på 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Filen overskrider den understøttede størrelsesgrænse.';

  @override
  String get fileWrites => 'Fil skriver';

  @override
  String get filename => 'Filnavn';

  @override
  String get files => 'Filer';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Filer NeoAgent skriver eller redigerer i denne session vises her.';

  @override
  String get filesSavedByAllUsers => 'Filer gemt af alle brugere';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Udfyld godkendte logins eller godkend anmodninger uden at vise hemmeligheder til AI.';

  @override
  String get finalResponse => 'Endeligt svar';

  @override
  String get findAPlatform => 'Find en platform';

  @override
  String get findAndFixABug => 'Find og ret en fejl';

  @override
  String get findRecentChats => 'Find seneste chats';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'At finde den korrekte NeoAgent runtime';

  @override
  String get finish => 'Afslut';

  @override
  String get finishAtTheScheduledTime => 'Afslut til det planlagte tidspunkt';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Afslut med at logge på $arg1 i din browser, og tilslut derefter igen.';
  }

  @override
  String get flowGraph => 'Flow graf';

  @override
  String get flutterApp => 'Fladder app';

  @override
  String get focusedExecutionProfile => 'Fokuseret eksekveringsprofil';

  @override
  String get folderIdOptional => 'Mappe-id (valgfrit)';

  @override
  String get folderUnavailable => 'Mappe er ikke tilgængelig';

  @override
  String get forExampleHttpsMatrixOrg => 'For eksempel https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Til hostede eller avancerede netværksopsætninger';

  @override
  String get forLinksInEmailsBlankUses =>
      'For links i e-mails. Blank bruger serverens offentlige URL.';

  @override
  String get forgotPassword => 'Glemt adgangskode?';

  @override
  String get frameUnavailable => 'Rammen er ikke tilgængelig';

  @override
  String freshnessArg1(Object? arg1) {
    return 'friskhed: $arg1';
  }

  @override
  String get fridays1700 => 'fredage · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Fra BotFather efter du har oprettet botten.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Fra nu af bestemmer $arg1, hvilke værktøjer din agent må bruge. De ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Fra Discord Developer Portal under din bot.';

  @override
  String get fromTheLineDevelopersConsole => 'Fra LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Fra Matrix-klienten eller bot-kontoen.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Fra twitchapps.com/tmi eller din Twitch-udviklerapp.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Fuld prompt';

  @override
  String get fullSetup => 'Fuld opsætning';

  @override
  String fullTextFtsArg1(Object? arg1) {
    return 'Fuld tekst (FTS): $arg1';
  }

  @override
  String get general => 'Generelt';

  @override
  String get generalSettings => 'Generelle indstillinger';

  @override
  String get generalSettingsSaved => 'Generelle indstillinger gemt.';

  @override
  String get generateAPromptForAnotherAi =>
      'Generer en prompt for en anden AI, indsæt svaret her for at importere minder.';

  @override
  String get generatePrompt => 'Generer prompt';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Geofence-sporingsfejl: $arg1';
  }

  @override
  String get getInspired => 'Bliv inspireret';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot og OpenAI Codex';

  @override
  String get githubIssueOpened => 'GitHub-udgave åbnet';

  @override
  String get neorecallMemoryCreated => 'NeoRecall Hukommelse oprettet';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'GitHub-udgivelsestjek mislykkedes med HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'GitHub-udgivelsens nyttelast var ikke en udgivelsesliste.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'GitHub brugernavn, der åbnede problemet';

  @override
  String get globalSecurityMode => 'Global sikkerhedstilstand';

  @override
  String get gmailMessageReceived => 'Gmail-meddelelse modtaget';

  @override
  String get good => 'Godt';

  @override
  String get goodAfternoon => 'God eftermiddag';

  @override
  String get goodEvening => 'God aften';

  @override
  String get goodMorning => 'Godmorgen';

  @override
  String get goodPasswordALittleMoreLength =>
      'God adgangskode. Lidt mere længde gør den stærkere.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live bruger din OpenAI API-nøgle, Gemini Live din Google AI-nøgle. Ændringer gælder for næste opkald.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Giv Health Connect-tilladelser før synkronisering.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Gruppe, kanal eller rum';

  @override
  String get groupType => 'Gruppetype';

  @override
  String get groupsAndChannels => 'Grupper og kanaler';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grupper: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Grupper $arg1 ikke har set endnu vil følge dette.';
  }

  @override
  String get handlesDirectTasksItself => 'Varetager selv direkte opgaver';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Håndfri (snak frit, afbryd når som helst)';

  @override
  String get headerName => 'Overskriftsnavn';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Overskrifter om de emner, du holder af, filtreret efter signal.';

  @override
  String get health => 'Sundhed';

  @override
  String get healthChecks => 'Sundhedstjek';

  @override
  String get healthConnect => 'sundhed forbinde';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect er ikke tilgængelig på denne enhed.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Health Connect-synkroniseringsstatus og lagrede backend-metrics.';

  @override
  String get healthStatusIsUnavailable => 'Sundhedsstatus er ikke tilgængelig.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Sundhedssynkronisering er kun tilgængelig på Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Heart $arg1 optager';
  }

  @override
  String get heldBack => 'Holdt tilbage';

  @override
  String get helper => 'Hjælper';

  @override
  String helperArg1(Object? arg1) {
    return 'Hjælper: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'her. Tilbagekald admin med `neoagent admin tilbagekald $arg1` først.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Højere værdier gør NeoAgent mere selektiv i grupper.';

  @override
  String get highlyRecommended => 'Stærkt anbefalet';

  @override
  String get holdButton131ForTheAssistant =>
      'Hold knap 131 nede for assistenten.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Hold Ctrl+Shift+Mellemrum nede for at tale';

  @override
  String get holdToTalk => 'Hold for at tale.';

  @override
  String get holdToTalk2 => 'Hold for at tale';

  @override
  String get home => 'Hjem';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Home Assistant Long-Lived Access Token er påkrævet.';

  @override
  String get homeAssistantSetup => 'Opsætning af Home Assistant';

  @override
  String get homeAssistantUrl => 'Home Assistant URL';

  @override
  String get homeAssistantUrlIsRequired => 'Home Assistant URL er påkrævet.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Hjemmeserver-token med rumafstemning';

  @override
  String get homeserverUrl => 'Hjemmeserver URL';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'hostet tjeneste). Dine nøgler er krypteret og kan kun bruges af ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Værtsnavn på IRC-netværket, for eksempel irc.libera.chat';

  @override
  String get hourly => 'Hver time';

  @override
  String get hourlyInboxCheck => 'Indbakke check hver time';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Hvor længe er bekræftelseslinks gyldige.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Hvor ofte leder denne agent efter nye rumbeskeder.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Hvor ofte denne agent leder efter nye signalbeskeder.';

  @override
  String get howTeamsWork => 'Hvordan teams fungerer';

  @override
  String get howThisServerIsReachedPlus =>
      'Hvordan denne server nås, plus server-omfattende switches.';

  @override
  String get httpsSessionCookie => 'https session cookie';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Jeg kunne ikke fuldføre den anmodning lige nu. Prøv venligst igen om et øjeblik.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Inaktiv';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Hvis $arg1 beder om en webhook-URL, skal du indsætte denne, så meddelelser kan nå $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Hvis denne konto har en bekræftet e-mail, sender NeoAgent et link til nulstilling af adgangskode.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Hvis tjenesten kræver et token på udgående anmodninger.';

  @override
  String get ignoreGroups => 'Ignorer grupper';

  @override
  String get ignoreThisChat => 'Ignorer denne chat';

  @override
  String get ignoredChannels => 'Ignorerede kanaler';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Ignoreret forkert udformet ledsagende skrivebordsmeddelelse: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Implementer planen ovenfor.';

  @override
  String get implementThisPlan => 'Gennemfør denne plan';

  @override
  String get implicitTls => 'Implicit TLS';

  @override
  String get import => 'Importer';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Import mislykkedes: $arg1';
  }

  @override
  String get importFromComputer => 'Importer fra computer';

  @override
  String get importMemoryTransfer => 'Importere hukommelsesoverførsel?';

  @override
  String get importance => 'Betydning';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Importerede $arg1-hukommelser, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'I @${arg1}s team';
  }

  @override
  String get inBackground => 'baggrund';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Indgående og udgående kanalmeddelelser vises her.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Indgående taleopkald i appen fra NeoAgent';

  @override
  String get incomingMessages => 'Indgående beskeder';

  @override
  String get incomingNeoagentCall => 'Indgående NeoAgent-opkald';

  @override
  String get incomingNeoagentCall2 => 'INDGÅENDE NEOAGENT OPKALD';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Support til indgående webhook og udgående tilbagekald';

  @override
  String get incorporatingSteering => 'Inkorporerer styring';

  @override
  String get input => 'Input';

  @override
  String get inputMode => 'Indgangstilstand';

  @override
  String get insertATemplate => 'Indsæt en skabelon';

  @override
  String get inspect => 'Inspicere';

  @override
  String get install => 'Installer';

  @override
  String get installASignedSelfContainedRuntime =>
      'Installer en signeret, selvstændig runtime. Node.js, npm, Git og terminalkommandoer er ikke påkrævet.';

  @override
  String get installApk => 'Installer APK';

  @override
  String get installApkBundle => 'Installer APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Installer APK — klik eller slip en .apk-fil';

  @override
  String get installNeoagent => 'Installer NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Installer NeoAgent på denne computer uden en terminal, eller opret forbindelse til en, der allerede kører.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Installer nye udgivelser og vælg, hvilken kanal denne server følger.';

  @override
  String get installTheBackend => 'Installer backend';

  @override
  String get installTheCoreWithExtraOptional =>
      'Installer kernen med ekstra valgfri opsætning. AI-udbydernøgler tilføjes efterfølgende, det samme som Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Installer den sikre kerne, og opret derefter din konto. Tilføj AI-udbydernøgler bagefter.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Installeret: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Installeret: $arg1 • Sidst kontrolleret: $arg2';
  }

  @override
  String get instructions => 'Instruktioner';

  @override
  String get integration => 'Integration';

  @override
  String get integrationApps => 'Integrations-apps';

  @override
  String get integrationConnections => 'Integrationsforbindelser';

  @override
  String get integrationSettingsSaved => 'Integrationsindstillinger gemt.';

  @override
  String get integrations => 'Integrationer';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrations/oauth/callback, og registrer det samme ';

  @override
  String get interruptAi => 'Afbryd AI';

  @override
  String get invalid2fa => 'ugyldig 2fa';

  @override
  String get invalidArgumentS => 'Ugyldige argument(er): ';

  @override
  String get invalidCredentials => 'ugyldige legitimationsoplysninger';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Ugyldigt NeoAgent runtime manifest.';

  @override
  String get inviteLink => 'Invitationslink';

  @override
  String get inviteLinkReady => 'Invitationslinket er klar';

  @override
  String get inviteLinks => 'Inviter links';

  @override
  String get iphoneApp => 'iPhone app';

  @override
  String get issues => 'Problemer';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Problemer vises, når loggen indlæses.';

  @override
  String get itCanTBeUndone => 'Det kan ikke fortrydes.';

  @override
  String get itMayHaveBeenDeleted => 'Det kan være blevet slettet.';

  @override
  String get javaRuntime => 'java runtime';

  @override
  String get joinUsersManagedOnManagedId =>
      'JOIN users managed ON managed.id = d.managed_user_id\n';

  @override
  String get joinUsersManagerOnManagerId =>
      'JOIN users manager ON manager.id = d.manager_user_id\n';

  @override
  String get joinUsersUOnUId => 'JOIN users u ON u.id = r.user_id\n';

  @override
  String get joinUsersUOnUId2 => 'JOIN users u ON u.id = s.user_id\n';

  @override
  String get joinUsersUOnUId3 => 'JOIN users u ON u.id = a.user_id\n';

  @override
  String get joinUsersUOnUId4 => 'JOIN users u ON u.id = ic.user_id\n';

  @override
  String joinedArg1(Object? arg1) {
    return 'Tiltrådte $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Tilmeldt de sidste 7 dage';

  @override
  String get joiningATeam => 'At slutte sig til et hold';

  @override
  String get joiningIsOffHere => 'Tilmelding er slukket her';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON-felt, der indeholder meddelelsesteksten. Normalt tekst.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON-felt, der identificerer, hvem meddelelsen er til.';

  @override
  String get jumpToLatest => 'Hop til seneste';

  @override
  String get justNow => 'lige nu';

  @override
  String get keepNeoagentRunning => 'Holde NeoAgent kørende?';

  @override
  String get keepRunning => 'Fortsæt med at løbe';

  @override
  String get keepTaskRunning => 'Hold opgaven kørende';

  @override
  String get keepTheVaultAvailable => 'Hold boksen tilgængelig';

  @override
  String get keepThisLauncherUpToDate => 'Hold denne launcher opdateret.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Hold dette panel åbent, indtil platformen bekræfter forbindelsen.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Hold denne sessions computer synlig';

  @override
  String get keepTrackOfYourAiUsage =>
      'Hold styr på dit AI-brug. Grænser håndhæves for at sikre fair brug på tværs af platformen.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Fortsæt med at bruge dine apps normalt. NeoAgent arbejder på den samme skærm og spørger, når den har brug for ny adgang.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Holder denne enhed forbundet';

  @override
  String get key => 'Nøgle';

  @override
  String get keyIsRequired => 'Nøgle er påkrævet.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Nøgle-værdi-par, der fortsætter på tværs af samtaler.';

  @override
  String get knowledgeGraph => 'Vidensgraf';

  @override
  String get knowledgeView => 'Videnssyn';

  @override
  String get labelOnlyYouSeeIt => 'Etiket (kun du kan se det)';

  @override
  String get labelsOptional => 'Etiketter (valgfrit)';

  @override
  String get last24Hours => 'Sidste 24 timer';

  @override
  String get last7Days => 'Sidste 7 dage';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Sidste 7 dage: $arg1-tokens i $arg2-kørsler';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Sidste $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Sidste: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Sidste ikke-tom synkronisering · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Sidste kørsel: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Sidst set $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Sidste login $arg1';
  }

  @override
  String get lastSyncSummary => 'Oversigt over sidste synkronisering';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Sidst brugt: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Sidste vindue sluttede $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'senere start også slået fra.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Seneste kørsel · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Start af desktop-apps understøttes ikke på denne platform.';

  @override
  String get learnRoomNorms => 'Lær rumnormer';

  @override
  String get leave => 'Forlad';

  @override
  String get leaveARedirectUriBlankTo =>
      'Lad en omdirigerings-URI være tom for at bruge <offentlig URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Forlade $arg1\'s team?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Lad være som standard, medmindre du har tilpasset BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Lad tokenet være tomt for at beholde det aktuelt gemte token.';

  @override
  String get leftJoinAgentRunsROn =>
      'LEFT JOIN agent_runs r ON r.user_id = u.id\n';

  @override
  String get leftJoinAgentRunsROn2 =>
      'LEFT JOIN agent_runs r ON r.agent_id = a.id\n';

  @override
  String get leftJoinArtifactsAOnA =>
      'LEFT JOIN artifacts a ON a.user_id = u.id\n';

  @override
  String letArg1ManageMe(Object? arg1) {
    return 'Lad $arg1 styre mig';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Lad alle i denne gruppe tale med $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Lad det virke, mens\ndu ikke gør det.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Lad NeoAgent klikke, skrive og flytte gennem dine apps.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Lad NeoAgent forstå, hvad der er synligt på din skærm.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Lad en, du arbejder med, bestemme, hvilke værktøjer din agent må ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Lad denne person sende $arg1 en en-til-en besked.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Lad denne person tale med $arg1 her, men ikke i private chats eller andre grupper.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Lad denne person tale med $arg1 i private chats og i enhver gruppe, de deler.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Niveau $arg1/$arg2$arg3';
  }

  @override
  String lexicalArg1(Object? arg1) {
    return 'Leksisk: $arg1';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Link $arg1';
  }

  @override
  String get linkCopied => 'Linket er kopieret';

  @override
  String get linkExpiresAfter => 'Linket udløber efter';

  @override
  String get linkLifetimeHours => 'Links levetid (timer)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Linkets levetid skal være fra 1 til 8760 timer.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link gyldigt indtil $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Tilknyttede login-udbydere';

  @override
  String get linuxApp => 'Linux app';

  @override
  String listedArg1(Object? arg1) {
    return 'Opført $arg1/';
  }

  @override
  String get listening => 'At lytte';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Live eksekveringshistorik, værktøjstrin og svar.';

  @override
  String get liveModel => 'Levende model';

  @override
  String get liveModelProvider => 'Live model udbyder';

  @override
  String get liveRun => 'Live løb';

  @override
  String get liveVoice => 'Levende stemme';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Live stemmeforbindelse er ikke tilgængelig.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Live stemmeforbindelse blev lukket.';

  @override
  String get liveVoiceDefaults => 'Live stemmestandarder';

  @override
  String get liveVoiceFailed => 'Live stemme mislykkedes.';

  @override
  String get llmMemoryExportResponse => 'LLM hukommelse eksport svar';

  @override
  String get loadFailed => 'indlæsning mislykkedes';

  @override
  String get loadingExecutionDetails => 'Indlæser udførelsesdetaljer...';

  @override
  String get loadingNeoagent => 'Indlæser NeoAgent';

  @override
  String get loadingRunFlow => 'Indlæser køreflow...';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Lokale og private netværks-URL\'er understøttes, når NeoAgent-serveren kan nå dem. Lyden udsættes aldrig for NeoAgent.';

  @override
  String get localApp => 'lokal app';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Lokal backend-installation er ikke tilgængelig på denne platform.';

  @override
  String get localBaseImagePath => 'Lokal basisbilledsti';

  @override
  String get localComputerControlIsAvailableIn =>
      'Lokal computerstyring er tilgængelig i NeoAgent desktop-appen på macOS, Windows og Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Lokal computerstyring er ikke tilgængelig her.';

  @override
  String get localModelsUrl => 'lokale modellers url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Lokal NeoAgent-opdagelse er midlertidigt utilgængelig.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Lokale præferencer for NeoAgent-applikationen. Computerstyring kører altid gennem den forenede cloud-computer.';

  @override
  String get localSetup => 'LOKAL OPSÆTNING';

  @override
  String get locationCityOrPlace => 'Beliggenhed (by eller sted)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Placering er påkrævet for at udløse vejrhændelser';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'LocationService initialisering mislykkedes: $arg1';
  }

  @override
  String get logCopied => 'Log kopieret';

  @override
  String get loginPassword => 'Login adgangskode';

  @override
  String get logout => 'Log ud';

  @override
  String get logs => 'Logs';

  @override
  String get logsCopied => 'Logfiler kopieret.';

  @override
  String get logsOnThisComputer => 'Log på denne computer';

  @override
  String get longLivedAccessToken => 'Adgangstoken med lang levetid';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Langsigtet genkaldelse, struktureret fakta og vidensgraf.';

  @override
  String get lookedAtTheScreen => 'Kiggede på skærmen';

  @override
  String get lookingOnThisComputerAndYour =>
      'Søger på denne computer og dit lokale netværk...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Ser frem til morgendagens møder, så intet overrasker dig.';

  @override
  String get loopExecution => 'Løkkeudførelse';

  @override
  String get loopPaused => 'Sløjfe sat på pause';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'macOS-tilgængelighed er ikke givet til NeoAgent. Tillad det i Systemindstillinger › Privatliv og sikkerhed › Tilgængelighed.';

  @override
  String get macosApp => 'macOS app';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'macOS Screen Recording er ikke givet til NeoAgent. Tillad det i Systemindstillinger › Privatliv og sikkerhed › Skærmoptagelse, og åbn derefter NeoAgent igen.';

  @override
  String get mailServersThatNeedAPassword =>
      'Mailservere, der har brug for en adgangskode, vil nægte at sende, indtil en ny ';

  @override
  String get main => 'Hoved';

  @override
  String get makeDefault => 'Gør som standard';

  @override
  String get manage => 'Administrer';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Administrer din konto-e-mail, to-faktor-godkendelse og aktive sessioner.';

  @override
  String get managedBy => 'Administreret af';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Ledere kan have deres egne ledere (op til fire niveauer). A ';

  @override
  String get managing => 'Ledelse';

  @override
  String get manualDestination => 'Manuel destination';

  @override
  String get manualTrigger => 'Manuel udløser';

  @override
  String get masterPassword => 'Hovedadgangskode';

  @override
  String get matchThisDevice => 'Match denne enhed';

  @override
  String get matchedAgainstTitleAndBody => 'Matchet mod titel og krop';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Matcher den gamle NeoAgent MCP-flow: URL plus godkendelsesmetode.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP server';

  @override
  String get mcpServer2 => 'MCP-server';

  @override
  String get mcpServerUrl => 'MCP Server URL';

  @override
  String get mcpServers => 'MCP-servere';

  @override
  String get meantForSomeoneElse => 'Beregnet til en anden';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Målt modelpris: $arg1';
  }

  @override
  String get memories => 'Minder';

  @override
  String get memory => 'Hukommelse';

  @override
  String memoryArg1(Object? arg1) {
    return 'Hukommelse: $arg1';
  }

  @override
  String get memoryImportSync => 'synkronisering af hukommelsesimport';

  @override
  String get memoryIngestionInterval => 'Hukommelsesindtagelsesinterval';

  @override
  String get memoryIngestionIntervalMs => 'Hukommelsesindtagelsesinterval (ms)';

  @override
  String get memoryIngestionIntervalMustBeAt =>
      'Interval for hukommelsesindtagelse skal være mindst 1000 ms.';

  @override
  String get memoryInjected => 'Hukommelse indsprøjtet';

  @override
  String get mentionOrReplyOnly => 'Nævn eller svar kun';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Flettede server- og Flutter-runtime-logfiler for denne app-session.';

  @override
  String get messageBodyTemplateJson => 'Beskedtekstskabelon (JSON)';

  @override
  String get messageNeedsAccess => 'Beskeden skal have adgang';

  @override
  String get messageTextField => 'Meddelelsestekstfelt';

  @override
  String get messaging => 'Beskeder';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Messaging API push og webhook begivenheder';

  @override
  String get messagingConnectionNeedsAttention =>
      'Beskedforbindelse kræver opmærksomhed';

  @override
  String get messagingConnections => 'Beskedforbindelser';

  @override
  String get messagingDelivery => 'Levering af beskeder';

  @override
  String get messagingErrorPleaseTryAgain => 'Beskedfejl. Prøv venligst igen.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Mikrofonoptagelse stoppede uventet. Prøv igen.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Mikrofonfejl: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofonen er slået fra. Tryk for at slå lyden til.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Mikrofontilladelse er påkrævet for live stemme.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftSlackAndTheOtherIntegrations =>
      'Microsoft, Slack og de andre integrationer. De gælder for ';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimum bidragsværdi: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Mobilopsætning mislykkedes.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Mobilopsætning mislykkedes, fordi Java ikke er tilgængelig på maskinen, der kører NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Mobilopsætning mislykkedes, fordi Java ikke er tilgængelig på maskinen, der kører NeoAgent. Installer en JDK og prøv igen.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Mobilopsætning mislykkedes. Kontroller, at Android-værktøjet er installeret korrekt, og prøv igen.';

  @override
  String modeArg1(Object? arg1) {
    return 'tilstand: $arg1';
  }

  @override
  String get modeLocksWhileARunIs => 'Mode låser, mens en løbetur er aktiv.';

  @override
  String get model => 'Model';

  @override
  String modelArg1(Object? arg1) {
    return 'Model: $arg1';
  }

  @override
  String get modelAvailability => 'Model tilgængelighed';

  @override
  String get modelAvailabilitySaved => 'Modeltilgængelighed gemt.';

  @override
  String get modelForThisSession => 'Model til denne session';

  @override
  String get modelOverride => 'Modeltilsidesættelse';

  @override
  String get modelPending => 'Model afventer';

  @override
  String get modelTurn => 'Modeldrejning';

  @override
  String get modelTurnCompleted => 'Modeldrejning afsluttet';

  @override
  String get modelTurnStarted => 'Modeldrejning startet';

  @override
  String get modelVisibilityHideShowList => 'model synlighed skjul vis liste';

  @override
  String get models => 'Modeller';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modeller, adfærd, stemme og arbejdsplads';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modeller, browser, stemme, diagnostik...';

  @override
  String get modelsRouting => 'Modeller & routing';

  @override
  String get monthly => 'Månedligt';

  @override
  String get moreActions => 'Flere handlinger';

  @override
  String get morningBriefing => 'Morgen briefing';

  @override
  String get mostUsedAgents => 'Mest brugte midler';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Mest brugte modeller i den sidste $arg1.';
  }

  @override
  String get mouseKeyboard => 'Mus og tastatur';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove er ikke understøttet på denne platform.';

  @override
  String get mustBeReachableOnThePublic =>
      'Skal være tilgængelig på det offentlige internet - lokalt og ';

  @override
  String get n24Hours => '24 timer';

  @override
  String get n2faOrRecoveryCode => '2FA eller gendannelseskode';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA kræver, at SESSION_SECRET konfigureres på denne NeoAgent-implementering.';

  @override
  String get n30Days => '30 dage';

  @override
  String get n365Days => '365 dage';

  @override
  String get n4HourLimitTokens => '4-timers grænse (tokens)';

  @override
  String get n4HourUsage => '4-timers brug';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4 timers grænse $arg1';
  }

  @override
  String get n7DayUsage => '7 dages brug';

  @override
  String get n7Days => '7 dage';

  @override
  String get n90Days => '90 dage';

  @override
  String get name => 'Navn';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnavn: Ny færdighed\nbeskrivelse: Beskriv hvad denne færdighed gør\n---\nSkriv instruktionerne til denne færdighed her.\n';

  @override
  String get nameOfWhoeverMadeIt => 'navnet på den, der har lavet det.';

  @override
  String get nameOptional => 'Navn (valgfrit)';

  @override
  String get nativeAndWebhookChannels => 'Native og webhook-kanaler';

  @override
  String get naturalBubbles => 'Naturlige bobler';

  @override
  String get nearbyNeoagentServers => 'Nærliggende NeoAgent-servere';

  @override
  String get needANewAccountRegister =>
      'Har du brug for en ny konto? Tilmeld dig';

  @override
  String get needAnIdea => 'Har du brug for en idé?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Skal svare · $arg1% for at tale';
  }

  @override
  String get needsAttention => 'Har brug for opmærksomhed';

  @override
  String get needsInput => 'Har brug for input';

  @override
  String get neoagentApp => 'NeoAgent app';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent assistent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent kunne ikke kontrollere den tilgængelige backend-runtid.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent kunne ikke afslutte den lokale opsætning.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent kunne ikke afslutte den lokale opsætning. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'NeoAgent debug info';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent installerer den nyeste $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent er installeret og kører.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent er ikke installeret på denne computer.';

  @override
  String get neoagentIsReady => 'NeoAgent er klar';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent arbejder stadig på en opgave. Afslut opkaldet og få resultatet i chatten, eller annuller også opgaven.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent gør din demonstration til en tilpasningsdygtig arbejdsgang.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent venter, mens du bruger skrivebordet.';

  @override
  String get neoagentIsWorking => 'NeoAgent virker';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux computer';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT BEHØVER EN BESLUTNING';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'NeoAgent runtime downloads kræver en sikker adresse.';

  @override
  String get neoagentServerAddress => 'NeoAgent serveradresse';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'NeoAgent service-e-mail er ikke klar. Bed serveroperatøren om at kontrollere indstillingerne for e-mailmiljøet.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'NeoAgent-opsætningen kunne ikke afsluttes.';

  @override
  String get neoagentUser => 'NeoAgent bruger';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent bruger denne computer automatisk og spørger, før den bruger din skærm, mus, tastatur, filer eller kommandolinje.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent bruger din omtrentlige baggrundsplacering til at udløse geofence-påmindelser (f.eks. \"Mind mig om at købe mælk, når jeg går forbi supermarkedet\").\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent Workspace';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][stak] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall Backend URL';

  @override
  String get neorecallBackendUrlIsRequired =>
      'NeoRecall-backend-URL er påkrævet.';

  @override
  String get neorecallSetup => 'NeoRecall-opsætning';

  @override
  String get networkRequestFailed => 'netværksanmodning mislykkedes';

  @override
  String get networkWriteRequests => 'Netværk skrive anmodninger';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'tæller aldrig mod grænserne for delt brug.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Nye konti bekræfter deres e-mailadresse, før de logger ind.';

  @override
  String get newAccountsPerDay => 'Nye konti pr. dag';

  @override
  String get newChat => 'Ny chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Nye grupper forbliver stille, medmindre nogen tagger $arg1, indtil du tænder dem.';
  }

  @override
  String get newLink => 'Nyt link';

  @override
  String get newPasswordsDoNotMatch => 'Nye adgangskoder stemmer ikke overens.';

  @override
  String get newRecoveryCodes => 'Nye gendannelseskoder';

  @override
  String get newSession => 'Ny session';

  @override
  String get newSessionN => 'Ny session (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Ny session med samme opsætning';

  @override
  String get newSkill => 'Ny færdighed';

  @override
  String get newSkill2 => 'Ny færdighed';

  @override
  String get newThisWeek => 'Nyt i denne uge';

  @override
  String get newsDigest => 'Nyhedsoversigt';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Næste forsøg igen: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Nextcloud Login Flow';

  @override
  String get nextcloudSetup => 'Nextcloud-opsætning';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'Nextcloud URL';

  @override
  String get nextcloudUrlIsRequired => 'Nextcloud URL er påkrævet.';

  @override
  String get nickname => 'Kaldenavn';

  @override
  String get noAccountsConnectedYet => 'Ingen konti forbundet endnu.';

  @override
  String get noAccountsFound => 'Ingen konti fundet.';

  @override
  String get noActiveSessionsFound => 'Ingen aktive sessioner fundet.';

  @override
  String get noAgentsYet => 'Ingen agenter endnu';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Ingen AI-udbyder er konfigureret, så chat og meddelelser ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Ingen godkendelsesprompter – agent kører uden afbrydelser.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Intet $arg1-udgivelsesaktiv matchede denne platform.';
  }

  @override
  String get noArguments => '(ingen argumenter)';

  @override
  String get noAuth => 'Ingen auth';

  @override
  String get noBindingsYet => 'Ingen bindinger endnu.';

  @override
  String get noChangesYet => 'Ingen ændringer endnu';

  @override
  String get noChannelsFound => 'Ingen kanaler fundet';

  @override
  String get noCloudComputerSlotIsFree =>
      'Ingen cloud-computer slot er gratis lige nu. Prøv igen om et øjeblik.';

  @override
  String get noCoreMemoryEntriesYet => 'Ingen kernehukommelsesposter endnu.';

  @override
  String get noDescription => 'Ingen beskrivelse';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Ingen skrivebordsskærme er i øjeblikket tilgængelige.';

  @override
  String get noDetailAvailable => 'Ingen detaljer tilgængelige';

  @override
  String get noDetailedSyncSummaryYet =>
      'Ingen detaljeret synkroniseringsoversigt endnu.';

  @override
  String get noDetailsCaptured => 'Ingen detaljer fanget.';

  @override
  String get noEmailLinked => 'Ingen e-mail linket';

  @override
  String get noExternalSignInProvidersLinked =>
      'Ingen eksterne login-udbydere tilknyttet.';

  @override
  String get noGroupMessagesYet => 'Ingen gruppebeskeder endnu';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Ingen gruppespecifikke personer tilføjet endnu.';

  @override
  String get noGroupsAddedYet => 'Ingen grupper tilføjet endnu.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Ingen grupper fundet endnu. Når $arg1 ser en gruppemeddelelse, skal du bruge Find seneste chats, og de vises her.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Ingen grupper fundet endnu. Når $arg1 ser en gruppemeddelelse, skal du bruge Find seneste chats.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Ingen sundhedsdata nyttelast returneret.';

  @override
  String get noHealthSamplesStoredYet => 'Ingen helbredsprøver gemt endnu.';

  @override
  String get noHttpClientImplementationForThis =>
      'Ingen HTTP-klientimplementering for denne platform.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Der blev ikke registreret noget input eller output for dette trin.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Ingen integrationer matcher denne søgning.';

  @override
  String get noLimit => 'Ingen grænse';

  @override
  String get noLocalPasswordIsSetYet =>
      'Der er ikke angivet nogen lokal adgangskode endnu. Opret en for at aktivere login med brugernavn/adgangskode.';

  @override
  String get noLogEntries => 'Ingen logposter.';

  @override
  String get noMatchingSettings => 'Ingen matchende indstillinger';

  @override
  String get noMcpServersMatchThisSearch =>
      'Ingen MCP-servere matcher denne søgning.';

  @override
  String get noMemoryEntriesFound => 'Ingen hukommelsesposter fundet.';

  @override
  String get noMemorySync => 'Ingen hukommelsessynkronisering';

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Ingen model matcher \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Der blev ikke registreret nogen modelanmodning for denne kørsel.';

  @override
  String get noModelsDiscoveredYet => 'Ingen modeller fundet endnu';

  @override
  String get noModelsSelected => 'Ingen modeller valgt';

  @override
  String get noModelsYet => 'Ingen modeller endnu';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'ingen neoagent-konto er knyttet til denne udbyder';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Ingen NeoAgent-backend-runtime er tilgængelig for denne computer.';

  @override
  String get noNetworkConnection => 'Ingen netværksforbindelse';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Ingen netværksforbindelse. Tilslut for at fortsætte med at bruge NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Ingen netværksforbindelse. Opret forbindelse igen for at søge efter opdateringer.';

  @override
  String get noOne => 'Ingen';

  @override
  String get noOneAddedYet => 'Ingen tilføjet endnu.';

  @override
  String get noOneCanMessage => 'Ingen kan sende beskeder';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Ingen anden NeoAgent-server blev fundet. Du kan søge igen eller indtaste en adresse manuelt.';

  @override
  String get noPeopleAddedYet => 'Ingen personer tilføjet endnu.';

  @override
  String get noPlatformsMatch => 'Ingen platforme matcher';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Ingen udbydere er tilgængelige at konfigurere endnu.';

  @override
  String get noRecentChannelActivity => 'Ingen nylig kanalaktivitet';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Ingen resultater for \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Ingen kørsler i dette interval.';

  @override
  String get noRunsMatchTheseFilters => 'Ingen kørsler matcher disse filtre';

  @override
  String get noRunsYet => 'Ingen løb endnu';

  @override
  String get noRunsYet2 => 'Ingen løb endnu.';

  @override
  String get noSecurityKeyWasProvided =>
      'Der blev ikke givet nogen sikkerhedsnøgle.';

  @override
  String get noServerUrlSet => 'Ingen server-URL angivet';

  @override
  String get noSessionMatchesThatSearch => 'Ingen session matcher den søgning.';

  @override
  String get noSessionsYet => 'Ingen sessioner endnu';

  @override
  String get noSkillsMatchTheseFilters =>
      'Ingen færdigheder matcher disse filtre.';

  @override
  String get noStepsWereRecordedForThis =>
      'Der blev ikke registreret nogen trin for denne kørsel.';

  @override
  String get noSummaryAvailable => 'Ingen oversigt tilgængelig.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Ingen opgaver for $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Intet værktøj matcher \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Ingen opdatering kører';

  @override
  String get noUsageYet => 'Ingen brug endnu.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Der er endnu ingen verificeret NeoAgent-backend-runtime tilgængelig.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Ingen kan bruge det mere. Folk, der allerede er med ';

  @override
  String get none => 'Ingen';

  @override
  String get notApprovedYet => 'ikke godkendt endnu';

  @override
  String get notAuthenticated => 'ikke autentificeret';

  @override
  String get notCheckedYet => 'Ikke kontrolleret endnu';

  @override
  String get notConfigured => 'Ikke konfigureret';

  @override
  String get notConnected => 'Ikke forbundet';

  @override
  String get notConnected2 => 'Ikke forbundet';

  @override
  String get notInstalled => 'Ikke installeret';

  @override
  String get notNeeded => 'Ikke nødvendigt';

  @override
  String get notNeededEnough => 'Ikke nødvendigt nok';

  @override
  String get notNow => 'Ikke nu';

  @override
  String get notNow2 => 'Ikke nu';

  @override
  String get notSet => 'Ikke indstillet';

  @override
  String get notSetUp => 'Ikke sat op';

  @override
  String get notTheSameAsAdmin => 'Ikke det samme som admin';

  @override
  String get nothingFound => 'Intet fundet';

  @override
  String get nothingHereYet => 'Intet her endnu.';

  @override
  String get nothingHereYet2 => 'Intet her endnu';

  @override
  String get nothingMatches => 'Intet matcher';

  @override
  String get nothingStoredYet => 'Intet gemt endnu.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthAppCredentialsThatLetAccounts =>
      'OAuth-applegitimationsoplysninger, der lader konti forbinde Google, ';

  @override
  String get oauthClientId => 'OAuth-klient-id';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth klient-id hemmelig omdirigerings-api-nøgle';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth-klient-id hemmeligt omdirigering gmail-kalenderdrev';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'OAuth-lancering understøttes ikke på denne platform.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook lejer klient-id hemmelig';

  @override
  String get oauthToken => 'OAuth-token';

  @override
  String get oauthWithPkce => 'OAuth med PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'af $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'sin egen. Den vises aldrig igen efter lagring.';

  @override
  String get off => 'Fra';

  @override
  String get officialIntegration => 'Officiel integration';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Officiel integration returnerede ikke en forbindelses-URL.';

  @override
  String get on => 'Til';

  @override
  String get onASignedInAndroidDevice =>
      'På en Android-enhed, hvor du er logget ind, skal du åbne Indstillinger › Log ind og sikkerhed, scanne denne kode og godkende login.';

  @override
  String get onByDefaultForNewGroups => 'Til som standard for nye grupper';

  @override
  String get onDemand => 'On Demand';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Til for $arg1 af $arg2-grupper';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'på. De kan kun deltage igen med et nyt invitationslink.';

  @override
  String get onYourOwnTheDefault => 'På egen hånd (standard)';

  @override
  String get once => 'En gang';

  @override
  String get oneBlankToKeepWhatIs => 'en blank for at beholde det gemte.';

  @override
  String get oneIsSavedOtherChangesIn =>
      'en er reddet. Andre ændringer i denne formular gemmes også.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'En eller flere konti er udløbet. Tilslut den berørte konto igen for at gendanne værktøjsadgang.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Én runtime styrer persona, gruppeturtagning, rumhukommelse, normer, Theory of Mind og levering.';

  @override
  String get oneTimeRun => 'Engangsløb';

  @override
  String get onlyApkOrApksFilesCan =>
      'Kun .apk- eller .apks-filer kan installeres.';

  @override
  String get onlyInThisGroup => 'Kun i denne gruppe';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Kun nødvendig, hvis tjenesten beder om ekstra HTTP-headere.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Kun nødvendig, hvis du ønsker at omforme den udgående nyttelast.';

  @override
  String get onlyTheyCanChangeIt => 'Kun de kan ændre det.';

  @override
  String get open => 'Åbn';

  @override
  String get openAccountSettingsOnASigned =>
      'Åbn Indstillinger › Log ind og sikkerhed på en Android-enhed, der er logget ind, scan denne kode, og godkend login.';

  @override
  String get openComputer => 'Åbn computer';

  @override
  String get openDashboard => 'Åbn dashboard';

  @override
  String get openFolder => 'Åbn mappe...';

  @override
  String get openInWorkbench => 'Åben i arbejdsbord';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Åbn NeoAgent, og tilslut $arg1 igen for at gendanne beskeder.';
  }

  @override
  String get openTimeSettings => 'Åbn tidsindstillinger';

  @override
  String get openToAnyone => 'Åben for alle';

  @override
  String get openTrello => 'Åbn Trello';

  @override
  String get openVoiceAssistant => 'Åbn stemmeassistent';

  @override
  String get openWiFiSettings => 'Åbn Wi-Fi-indstillinger';

  @override
  String get openWithTheDefaultApp => 'Åbn med standardappen';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'openai kompatibel';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'OpenAI-kompatibelt slutpunkt (din egen server eller en anden ';

  @override
  String openedArg1(Object? arg1) {
    return 'Åbnede $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Åbning af desktop-URL\'er understøttes ikke på denne platform.';

  @override
  String get openingYourSavedDesktop => 'Åbner dit gemte skrivebord.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Åbner dit gemte skrivebord. Normale starter tager mindre end 10 sekunder.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Valgfri ekstra hemmelighed, hvis du beskytter den indgående webhook.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Valgfri tilsidesættelse, hvis webhook-URL\'en ikke er nok.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Valgfri hemmelighed til at bekræfte indgående chatbegivenheder.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Valgfri hemmelighed til at bekræfte indgående begivenheder.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Valgfri hemmelighed til at bekræfte indgående iMessage-begivenheder.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Valgfri hemmelighed til at bekræfte indgående LINE-begivenheder.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Valgfri hemmelighed til at bekræfte indgående Mattermost-begivenheder.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Valgfri hemmelighed til at bekræfte indgående Teams-begivenheder.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Valgfrit. Agenten har allerede sin egen personlighed. Alt, hvad du tilføjer om tone, er lagt oven på det, så du aldrig behøver at definere en.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Valgfrit. Når den er indstillet, bruges den i stedet for URL\'en.';

  @override
  String get orAnswerInYourOwnWords => 'Eller svar med dine egne ord';

  @override
  String get orBuildYourOwnTask => 'Eller byg din egen opgave';

  @override
  String get orContinueWith => 'eller fortsæt med';

  @override
  String get orFiles => 'eller filer.';

  @override
  String get orderByBytesDesc => 'ORDER BY bytes DESC';

  @override
  String get orderByDayDesc => 'ORDER BY day DESC';

  @override
  String get orderByIcLastConnectedAt => 'ORDER BY ic.last_connected_at DESC\n';

  @override
  String get orderByManagerUsernameManagedUsername =>
      'ORDER BY manager.username, managed.username';

  @override
  String get orderByRCreatedAtDesc => 'ORDER BY r.created_at DESC\n';

  @override
  String get orderByRunsDesc => 'ORDER BY runs DESC\n';

  @override
  String get orderBySLastSeenAt => 'ORDER BY s.last_seen_at DESC\n';

  @override
  String get originNotAllowed => 'oprindelse ikke tilladt';

  @override
  String get outgoingMessage => 'Udgående besked';

  @override
  String get outgoingWebhookUrl => 'Udgående webhook-URL';

  @override
  String get outlookEmailReceived => 'Outlook-e-mail modtaget';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Overskriv adfærdsnotater fra importen.';

  @override
  String get ownModel => 'egen model';

  @override
  String get packageName => 'Pakkenavn';

  @override
  String get pairWithQrCode => 'Par med QR-kode';

  @override
  String get password => 'Adgangskode';

  @override
  String get password2faAndActiveSessions =>
      'Adgangskode, 2FA og aktive sessioner';

  @override
  String get passwordCreated => 'Adgangskode oprettet.';

  @override
  String get passwordIsTooWeak => 'adgangskoden er for svag';

  @override
  String get passwordMin8 => 'adgangskode min 8';

  @override
  String get passwordOrApiKey => 'Adgangskode eller API-nøgle';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Adgangskodestyrke: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Adgangskoder stemmer ikke overens.';

  @override
  String get pasteAKey => 'Indsæt en nøgle.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Indsæt en ny nøgle for at erstatte $arg1';
  }

  @override
  String get pasteTheKey => 'Indsæt nøglen';

  @override
  String get pasteYourAccountToken => 'Indsæt dit kontotoken';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Indsæt din $arg1 API-nøgle nedenfor. Det er ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Stien skal forblive inde i NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Stien skal forblive inde i arbejdsområdemappen.';

  @override
  String get pauseLiveUpdates => 'Sæt liveopdateringer på pause';

  @override
  String get pauseTaskLoop => 'Sæt opgaveløkke på pause';

  @override
  String get paused => 'Pause';

  @override
  String peakArg1(Object? arg1) {
    return 'peak $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Folk i private chats';

  @override
  String get perAccountRateLimits => 'Satsgrænser pr. konto';

  @override
  String get perCategoryPermissions => 'Per-kategori tilladelser';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Tilladelsespolitikker pr. værktøj, godkendelsesporte og procesisolering til udførelse af shell.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Tilladelse påkrævet: $arg1';
  }

  @override
  String get permissionsNeeded => 'Tilladelser er nødvendige';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Tilladelser. Det kan ingen andre ændre på.';

  @override
  String get personOrChat => 'Person eller chat';

  @override
  String get personaBehaviorNotes => 'Persona adfærdsnotater';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Personligt adgangstoken til Mattermost-bot.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Personlige kanaler og direkte støtteflader.';

  @override
  String get personalSelfChat => 'Personlig selvchat';

  @override
  String get phoneNumber => 'Telefonnummer';

  @override
  String get pickARunFromTheList =>
      'Vælg en løbetur fra listen for at se dens trin.';

  @override
  String get pickARunFromTheList2 =>
      'Vælg en løbetur fra listen til venstre for at udforske dens flow.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Vælg blandt de seneste $arg1-chats, eller tilføj en person eller gruppe selv.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Vælg, hvordan $arg1 bruger denne konto.';
  }

  @override
  String get pickOneToFillInThe =>
      'Vælg en til at udfylde opgaven. Du kan justere alt bagefter.';

  @override
  String get picksUpWhereYouLeftOff => 'Fortsætter, hvor du slap';

  @override
  String get plan => 'Planlæg';

  @override
  String get planning => 'Planlægning';

  @override
  String get platform => 'Platform';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platform $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Vælg venligst en tidsplan.';

  @override
  String get pleaseEnterAFilename => 'Indtast venligst et filnavn.';

  @override
  String get pleaseEnterAKey => 'Indtast venligst en nøgle.';

  @override
  String get pleaseEnterAPrompt => 'Indtast venligst en prompt.';

  @override
  String get pleaseEnterATaskName => 'Indtast venligst et opgavenavn.';

  @override
  String get pleaseEnterTheMemoryContent => 'Indtast hukommelsesindholdet.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Indtast venligst hvornår opgaven skal køre.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Vælg venligst en konto, eller indtast et gyldigt forbindelses-id.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Peg NeoAgent på alle OpenAI-kompatible chatafslutninger ';

  @override
  String get pointTheCameraAtTheCode =>
      'Ret kameraet mod koden vist på den loggede enhed. Godkendelsen forbliver på denne telefon.';

  @override
  String get port => 'Havn';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env offentlig url trust proxy sikker implementering af cookies';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Premium automatisering med tidsplan og integrationsudløsere.';

  @override
  String get prepareQrCode => 'Forbered QR-kode';

  @override
  String get preparingNeoagent => 'Forbereder NeoAgent...';

  @override
  String get preparingNeoagent2 => 'Forbereder NeoAgent';

  @override
  String get pressAndHoldForQuickCapture => 'Tryk og hold for hurtig optagelse';

  @override
  String get pressKeysIsNotSupportedOn =>
      'tryktaster understøttes ikke på denne platform.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Trykte $arg1';
  }

  @override
  String get priceUnknown => 'Pris ukendt';

  @override
  String get primaryDisplay => 'Primær skærm';

  @override
  String get privateChat => 'Privat chat';

  @override
  String get privateChats => 'Private chats';

  @override
  String get privateChats2 => 'private chats';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Private chats: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Private chats $arg1 · grupper $arg2';
  }

  @override
  String get privateChatsOnly => 'Kun private chats';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'private netværksadresser er ikke tilladt.';

  @override
  String get profileEmailAndPersonalData => 'Profil, e-mail og personlige data';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Spørg, før NeoAgent forbliver i proceslinjen.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Prompt cache: $arg1 cachede tokens ';
  }

  @override
  String get promptCopied => 'Spørgsmål kopieret.';

  @override
  String get promptOrSchedule => 'prompt eller tidsplan.';

  @override
  String get promptToPasteIntoAnotherAi => 'Spørg om at indsætte i en anden AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Udbyderlinkning kunne ikke startes.';

  @override
  String get providerSignInCouldNotBe => 'Udbyderlogon kunne ikke startes.';

  @override
  String get providers => 'Udbydere';

  @override
  String get providersEachAccountCanStillPick =>
      'Udbydere; hver konto kan stadig vælge sin egen model i Indstillinger. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Udbydere, integrationer, tale og valgfrie funktioner kan til enhver tid fuldføres fra Indstillinger.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Offentlige emne- og pull-anmodningstråde, besvaret kun for godkendte personer.';

  @override
  String get publicUrl => 'Offentlig URL';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Offentlig URL og tilladte oprindelser';

  @override
  String get publicUrlOverride => 'Offentlig URL-tilsidesættelse';

  @override
  String get pullsTogetherTheDayAhead => 'Trækker sammen dagen forude';

  @override
  String get pushToTalk => 'Tryk for at tale';

  @override
  String get qrBasedPhoneLinking => 'QR-baseret telefonlink';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR-login fuldført, men NeoAgent kunne ikke holde sessionen. Prøv venligst igen.';

  @override
  String get qrLoginCouldNotBeStarted => 'QR-login kunne ikke startes.';

  @override
  String get qrLoginRequestHasExpired => 'qr-loginanmodningen er udløbet';

  @override
  String get qrLoginRequestWasNotFound => 'qr login anmodning blev ikke fundet';

  @override
  String get qrPairing => 'QR-parring';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'forespørgsler kører; alt hvad der skriver bliver afvist.';

  @override
  String get query => 'Forespørgsel';

  @override
  String get queryFilter => 'Forespørgsel / Filter';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'I kø som styring for den aktuelle kørsel: $arg1';
  }

  @override
  String get quickstart => 'Quickstart';

  @override
  String get quit => 'Afslut';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'regn_start, vind_alert';

  @override
  String get ranAScriptInThePage => 'Kørte et script på siden';

  @override
  String ranArg1(Object? arg1) {
    return 'Kørte $arg1';
  }

  @override
  String get rateLimits => 'Satsgrænser';

  @override
  String get readAnArtifact => 'Læs en artefakt';

  @override
  String get readAndEditFilesInsideYour =>
      'Læs og rediger filer i din NeoAgent Workspace-mappe.';

  @override
  String readArg1(Object? arg1) {
    return 'Læs $arg1';
  }

  @override
  String get readError => 'Læsefejl';

  @override
  String get readFiles => 'Læs filer';

  @override
  String get readOnly => 'Kun læse';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Læs mappen og opsummer stakken, indgangspunkter og hvordan den køres.';

  @override
  String get readThePage => 'Læs siden';

  @override
  String get readTheUiTree => 'Læs UI-træet';

  @override
  String get readWrite => 'Læs/skriv';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Læser skridt, puls, søvn, træning og vægt.';

  @override
  String get ready => 'Klar';

  @override
  String get readyForFirstTimeSetup => 'Klar til førstegangsopsætning';

  @override
  String get readyToConnect => 'Klar til at forbinde';

  @override
  String get recentChannelActivity => 'Seneste kanalaktivitet';

  @override
  String get recentChats => 'Seneste chats';

  @override
  String get recentDecisions => 'Seneste beslutninger';

  @override
  String get recentFailedRuns => 'Seneste mislykkede kørsler';

  @override
  String get recentGroupDecisions => 'Seneste gruppebeslutninger';

  @override
  String get recentRuns => 'Seneste kørsler';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'De seneste kørsler tager omkring $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Seneste serveroutput, nyeste først.';

  @override
  String get recentUsage4Hours => 'Seneste brug (4 timer)';

  @override
  String get recents => 'Seneste';

  @override
  String get recipientField => 'Modtagerfelt';

  @override
  String get reconnectOrFinishSetup => 'Gentilslut eller afslut opsætningen';

  @override
  String get reconnectingThisDevice => 'Gentilslutter denne enhed...';

  @override
  String get recurring => 'Tilbagevendende';

  @override
  String get redirectUri => 'Omdiriger URI';

  @override
  String get redoOnboarding => 'Gentag onboarding';

  @override
  String get refresh => 'Opdater';

  @override
  String get refreshCode => 'Opdater kode';

  @override
  String get refreshNow => 'Opdater nu';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Opdater Android-skærmen for at prøve igen.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Nægt at sende, medmindre forbindelsen opgraderes til TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'uanset indstillinger for hver kategori nedenfor.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Registrer $arg1 for assistentindkaldelsesflowet.';
  }

  @override
  String get registrationIsClosed => 'tilmeldingen er lukket';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registrering registrere nye konti tillader tilmelding';

  @override
  String get rejectInvalidTlsCertificates => 'Afvis ugyldige TLS-certifikater';

  @override
  String relationArg1(Object? arg1) {
    return 'Relation: $arg1';
  }

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'frigive og genstarte. Tilsluttede apps genopretter forbindelsen, når den er tilbage.';

  @override
  String get releaseChannel => 'Slip kanal';

  @override
  String get releaseCommitBranchNode => 'release commit branch node';

  @override
  String get releaseWhenYouAreDone => 'Slip når du er færdig.';

  @override
  String get reloadNow => 'Genindlæs nu';

  @override
  String get rememberThisChoice => 'Husk dette valg';

  @override
  String get remove => 'Fjern';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Vil du fjerne \"$arg1\" og dets registrerede trin fra kørselshistorikken?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Fjern \"$arg1\" fra kernehukommelsen.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Fjern $arg1 nøgle?';
  }

  @override
  String get removeEraseGdprUser => 'fjern slet gdpr-bruger';

  @override
  String get removeSmtpPassword => 'Fjern SMTP-adgangskode';

  @override
  String get removeTheSmtpPassword => 'Vil du fjerne SMTP-adgangskoden?';

  @override
  String get rename => 'Omdøb';

  @override
  String get renameSecurityKey => 'Omdøb sikkerhedsnøgle';

  @override
  String get renameSession => 'Omdøb session';

  @override
  String get repairAndRetry => 'Reparer og prøv igen';

  @override
  String get repairDesktop => 'Reparer skrivebordet';

  @override
  String get repeat => 'Gentag';

  @override
  String get repliesWhenTagged => 'Svarer når tagget';

  @override
  String get replyToAddress => 'Svar-til-adresse';

  @override
  String replyToArg1(Object? arg1) {
    return 'Svar til $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Repository skal være i formatet ejer/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Genskab den fejl, jeg beskriver, find den grundlæggende årsag og ret den med en regressionstest.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'anmodning mislykkedes med http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Forespørgsel mislykkedes med HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Anmod om tilladelser';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Anmodning til $arg1 mislykkedes, før backend svarede.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Anmodet $arg1';
  }

  @override
  String get requireStarttls => 'Kræv STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Påkrævet bag HTTPS eller en TLS-proxy. Gælder efter en server ';

  @override
  String get requiredExampleBerlinDe => 'Påkrævet. Eksempel: Berlin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Påkrævet. Format: ejer/repo';

  @override
  String get reserveAssistantHotkey => 'Reserve assistent genvejstast';

  @override
  String get reset => 'Nulstil';

  @override
  String get resetPassword => 'Nulstil adgangskode';

  @override
  String get resetView => 'Nulstil visning';

  @override
  String get responsibilities => 'Ansvar';

  @override
  String get restart => 'Genstart';

  @override
  String get restartToFinishTheUpdate =>
      ' Genstart for at afslutte opdateringen.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Gendannelse af den tidligere NeoAgent-runtime';

  @override
  String get restrictDelegationTargets => 'Begræns delegationsmål';

  @override
  String get result => 'Resultat';

  @override
  String get resultDelivery => 'Resultat levering';

  @override
  String get resultOneClickAddsOneYou =>
      'resultat. Et klik tilføjer en; du kan redigere det senere.';

  @override
  String get results => 'Resultater';

  @override
  String get retrievalInspector => 'Afhentningsinspektør';

  @override
  String get retry => 'Prøv igen';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Genanvendelig · brugt $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Gennemgå ikke-forpligtede ændringer';

  @override
  String get revoke => 'Tilbagekald';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Tilbagekald admin med \'neoagent admin tilbagekald $arg1\' først';
  }

  @override
  String get revokeThisLink => 'Vil du tilbagekalde dette link?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Rumbatchvindue: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Drej for at fortsætte';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'rækker. Tilføj en LIMIT eller en smallere WHERE-klausul for at se ';

  @override
  String get rule => 'Regel';

  @override
  String get run => 'Kørsel';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Kør vilkårlige kommandoer på din maskine eller VM.';

  @override
  String get runAt => 'Løb kl';

  @override
  String get runCompleted => 'Kørsel afsluttet';

  @override
  String get runFailed => 'Kørsel mislykkedes';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Kør git diff, gennemgå de ikke-forpligtede ændringer for fejl og stilproblemer, og opsummer, hvad du finder.';

  @override
  String get runNotFound => 'Kørsel blev ikke fundet';

  @override
  String get runNow => 'Kør nu';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Kør på indgående personlige WhatsApp-beskeder.';

  @override
  String get runQuery => 'Kør forespørgsel';

  @override
  String get runShellCommandsOrInstallApps =>
      'Kør shell-kommandoer eller installer apps på din Android-enhed.';

  @override
  String get runStarted => 'Løb startede';

  @override
  String get runStatus => 'Kør status';

  @override
  String get runStopped => 'Løb stoppet';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Kør terminalkommandoer og åbn apps eller websider.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Kør denne server: konti, opdateringer, udbydere, konfiguration ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Kør, når der kommer en matchende Gmail-besked.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Kør, når en matchende Outlook-e-mail ankommer.';

  @override
  String get runWhenANewIssueMatching =>
      'Kør, når et nyt problem, der matcher dine filtre, åbnes i et lager.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Kør, når der oprettes en ny NeoRecall-hukommelse, der matcher dine filtre.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Kør, når der kommer en notifikation på din enhed.';

  @override
  String get runWhenASlackMessageMatches =>
      'Kør, når en Slack-meddelelse matcher det valgte omfang.';

  @override
  String get runWhenATeamsChatMessage =>
      'Kør, når en Teams-chatbesked matcher det valgte omfang.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Kør, når konfigurerede vejrbegivenheder varsles for en placering.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'løbe. Mens enhver model er slukket, tilføjer modeller, som udbydere ';

  @override
  String get running => 'Kører';

  @override
  String runningArg1(Object? arg1) {
    return 'Kører $arg1';
  }

  @override
  String get runningTask => 'Løbende opgave';

  @override
  String get runningTool => 'Løbeværktøj';

  @override
  String get runs => 'Kørsler';

  @override
  String get runsEveryDayAtTheSelected =>
      'Kører hver dag på det valgte tidspunkt.';

  @override
  String get runsFourTimesPerHour => 'Kører fire gange i timen.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— kørsler, beskeder, hukommelser, integrationer, filer og ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'kørsler, beskeder, minder, integrationer, filer og sessioner. ';

  @override
  String get runsMondayThroughFriday => 'Kører mandag til fredag.';

  @override
  String get runsOnSelectedWeekdays => 'Kører på udvalgte hverdage.';

  @override
  String get runsOncePerHour => 'Kører en gang i timen.';

  @override
  String get runsOncePerMonthOnThe =>
      'Kører en gang om måneden på den valgte dag.';

  @override
  String get runsOnlyWhenYouPressRun => 'Kører kun, når du trykker på Kør nu.';

  @override
  String get runsPerDay => 'Løber om dagen';

  @override
  String get runsPerDay30Days => 'Kører om dagen (30 dage)';

  @override
  String get runsThatCompleted => 'Kørsler, der er gennemført';

  @override
  String get runsThisWeek => 'Kører i denne uge';

  @override
  String get runsToday => 'Løber i dag';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Løb, værktøjer, hukommelse, planlægning, færdigheder og MCP er alle tilgængelige her.';

  @override
  String get runsTwicePerHour => 'Kører to gange i timen.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Kørsler vil falde tilbage til den delte servernøgle for $arg1, hvis en sådan er konfigureret. Dette kan ikke fortrydes.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Kørselstid $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Køretid: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Kørselsindstillinger denne server startede med. Rediger dem under ';

  @override
  String get runtimeSetupRequired => 'Kørselsopsætning påkrævet';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Offentlig nøgle til runtime-signering skal være på 32 bytes.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Gem';

  @override
  String get saveATrelloApiKeyFor =>
      'Gem en Trello API-nøgle til denne agent, og tilslut derefter én Trello-konto sikkert. Kontotokenet gemmes på serveren og bruges kun til denne agent.';

  @override
  String get saveAccount => 'Gem konto';

  @override
  String get saveChanges => 'Gem ændringer';

  @override
  String get saveCloudComputerSettings => 'Gem cloud-computerindstillinger';

  @override
  String get saveConnect => 'Gem og tilslut';

  @override
  String get saveDefaults => 'Gem standardindstillinger';

  @override
  String get saveDiagnosticReport => 'Gem diagnostisk rapport';

  @override
  String get saveEmail => 'Gem e-mail';

  @override
  String get saveEmailSettings => 'Gem e-mail-indstillinger';

  @override
  String get saveGeneralSettings => 'Gem generelle indstillinger';

  @override
  String get saveName => 'Gem navn';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Gem NeoAgent-opsætningsdiagnostik';

  @override
  String get saveOnly => 'Kun gem';

  @override
  String get saveSetup => 'Gem opsætning';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Gem disse gendannelseskoder nu. De vil ikke blive vist igen.';

  @override
  String get savedDeliveryDestination => 'Gemt leveringsdestination';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Gemte satsgrænser for @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Scan en NeoAgent login QR';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Scan en NeoAgent-parrings-QR fra en anden enhed, og godkend den fra denne startsession.';

  @override
  String get scanLoginQr => 'Scan login QR';

  @override
  String get scanPairingQr => 'Scan parring af QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Scan QR-loginanmodninger fra enheder, der er logget ud, og godkend dem fra denne autentificerede mobilsession.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Scan for at afslutte $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone => 'Scan med NeoAgent på din telefon';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Scanner ny e-mail og pinger dig kun, når noget er vigtigt.';

  @override
  String get schedule => 'Tidsplan';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'planlagt tid. Når kørsler er målt, starter den tidligere.';

  @override
  String scoreArg1(Object? arg1) {
    return 'Score: $arg1';
  }

  @override
  String get screen => 'Skærm';

  @override
  String get screenAction => 'skærmhandling';

  @override
  String get scrollIsNotSupportedOnThis =>
      'scroll er ikke understøttet på denne platform.';

  @override
  String get scrollToBottom => 'Rul til bunden';

  @override
  String get search => 'Søg';

  @override
  String get search2 => 'Søg...';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Søg i administratorindstillinger (f.eks. SMTP, Ollama, logfiler)';

  @override
  String get searchAgain => 'Søg igen';

  @override
  String get searchByUsernameOrEmail => 'Søg på brugernavn eller e-mail';

  @override
  String get searchChannels => 'Søg efter kanaler';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Søg efter opdagede beskedkanaler, kontakter, grupper og seneste samtaler.';

  @override
  String get searchGroups => 'Søg efter grupper';

  @override
  String get searchMemory => 'Søg hukommelse';

  @override
  String get searchModelsOrProviders => 'Søg efter modeller eller udbydere';

  @override
  String get searchModelsOrProviders2 => 'Søg efter modeller eller udbydere...';

  @override
  String get searchRecentPeopleAndGroups =>
      'Søg efter seneste personer og grupper';

  @override
  String get searchSessions => 'Søg sessioner';

  @override
  String get searchSettings => 'Søgeindstillinger';

  @override
  String get searchTitleModelTriggerRunId =>
      'Søg titel, model, trigger, køre-id';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Søgeværktøjer, integrationer og færdigheder';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Søgte kode efter \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Søgte filer efter \"$arg1\"';
  }

  @override
  String get secretField => 'Hemmeligt felt';

  @override
  String get secureCookies => 'Sikre cookies';

  @override
  String get security => 'Sikkerhed';

  @override
  String get securityKey => 'Sikkerhedsnøgle';

  @override
  String get securityKeyPromptWasDismissed =>
      'Sikkerhedsnøgleprompt blev afvist.';

  @override
  String get securityKeySignInCompletedBut =>
      'Sikkerhedsnøgle-login fuldført, men NeoAgent kunne ikke beholde browsersessionen. Log venligst ind igen.';

  @override
  String get securityKeySignInCouldNot =>
      'Sikkerhedsnøglelogon kunne ikke startes.';

  @override
  String get securityKeys => 'Sikkerhedsnøgler';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Sikkerhedsnøgler er kun tilgængelige i NeoAgent-webappen.';

  @override
  String get seeAll => 'Se alle';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Se hvilken NeoAgent-server dette vindue bruger, og kør backend på denne computer.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'se dit brugernavn og disse indstillinger, aldrig dine chats, minder ';

  @override
  String get selectARun => 'Vælg en løbetur';

  @override
  String get selectASessionToSeeIts =>
      'Vælg en session for at se dens computer, filer og ændringer.';

  @override
  String get selectAll => 'Vælg alle';

  @override
  String get selectAll2 => 'Vælg alle';

  @override
  String selectArg1(Object? arg1) {
    return 'Vælg $arg1';
  }

  @override
  String get selectTrigger => 'Vælg Trigger';

  @override
  String semanticArg1(Object? arg1) {
    return 'Semantisk: $arg1';
  }

  @override
  String get send => 'Send (⌘↵)';

  @override
  String get send2 => 'Send';

  @override
  String get sendATaskFromChatAnd =>
      'Send en opgave fra chat, og dens eksekveringshistorik vises her.';

  @override
  String get sendItToATeammateWith =>
      'send det til en holdkammerat med en konto på denne server.';

  @override
  String get sendLink => 'Send link';

  @override
  String get sendPath => 'Send sti';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Send POST/PUT/DELETE-anmodninger til eksterne API\'er.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Send kun dette link til den person, det er beregnet til. Det vises én gang; ';

  @override
  String get senderAddress => 'Afsenderadresse';

  @override
  String get senderFilterOptional => 'Afsenderfilter (valgfrit)';

  @override
  String get sentSharedAttachments => 'Sendte delte vedhæftede filer.';

  @override
  String get separateAccount => 'Separat konto';

  @override
  String get server => 'Server';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Serverstandard ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Serverstandarder for taleopkald i appen. Opkald kører på en live ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'selve serveren: konti, udbydere og konfiguration.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, nick, kanal og valgfri TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'server output konsol advarsler fejl kopiere';

  @override
  String get serverProviderCredentials =>
      'Server udbyder legitimationsoplysninger';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUsageLimitsDonTApply =>
      'Serverbrugsgrænser gælder ikke for modeller, der kører på din egen nøgle.';

  @override
  String get serviceEmail => 'Service e-mail';

  @override
  String get serviceEmailIsNotConfigured =>
      'service-e-mail er ikke konfigureret';

  @override
  String get serviceEmailSmtp => 'Tjenestemail (SMTP)';

  @override
  String get sessionActions => 'Sessionshandlinger';

  @override
  String get sessions => 'Sessioner';

  @override
  String get sessions2 => 'SESSIONER';

  @override
  String get sessionsArePinnedToAFolder =>
      'Sessioner er fastgjort til en mappe og en computer. Start en til at planlægge, bygge, teste og sende herfra.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sessioner (GDPR art. 17). Administratorkonti kan ikke slettes ';

  @override
  String get sessionsLogoutRevokeForce => 'sessions logout tilbagekalde kraft';

  @override
  String get setBlockAskAllowPerTool =>
      'Indstil blok / spørg / tillad pr. værktøjskategori, eller vælg en global tilstand.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Konfigurer NeoAgent på denne computer';

  @override
  String get setUpOrConnectNeoagent => 'Konfigurer eller tilslut NeoAgent';

  @override
  String get setUrl => 'Indstil URL';

  @override
  String get settings => 'Indstillinger';

  @override
  String get settingsAndCannotBeUndone =>
      'indstillinger og kan ikke fortrydes.';

  @override
  String get settingsArea => 'Indstillingsområde';

  @override
  String get settingsAreas => 'Indstillingsområder';

  @override
  String get setup => 'Opsætning';

  @override
  String get setupDetails => 'Opsætningsdetaljer';

  @override
  String get setupRequired => 'Opsætning påkrævet';

  @override
  String get setupWasCancelled => 'Opsætningen blev annulleret.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Delte vedhæftede filer fra NeoAgent-klienten:';

  @override
  String get sharedFromAnotherApp => 'Delt fra en anden app';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Delte udbydernøgler er konfigureret på serveren. For at bruge din egen API-nøgle eller et brugerdefineret slutpunkt i stedet, skal du gå til Avanceret → Medbring din egen nøgle.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Delt med NeoAgent-chatten og dens hukommelse.';

  @override
  String get shellCommands => 'Shell kommandoer';

  @override
  String showAllArg1(Object? arg1) {
    return 'Vis alle $arg1';
  }

  @override
  String get showEarlier => 'Vis tidligere';

  @override
  String get showEveryStep => 'Vis hvert trin';

  @override
  String get showTools => 'Vis værktøjer';

  @override
  String get showWorkbenchJ => 'Vis arbejdsbord (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Viser den første $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Vist i sidebjælken. Lad stå tomt for at bruge dit brugernavn.';

  @override
  String get signIn => 'Log ind';

  @override
  String get signInCompletedButNeoagentCould =>
      'Login fuldført, men NeoAgent kunne ikke beholde browsersessionen. Log venligst ind igen. Hvis dette bliver ved med at ske, skal du tjekke indstillingerne for backend session cookie.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Login fuldført, men NeoAgent kunne ikke beholde browsersessionen. Log venligst ind igen. Hvis dette bliver ved med at ske, vil backend-session-cookien sandsynligvis ikke blive bevaret.';

  @override
  String get signInToThisNeoagentServer =>
      'Log ind på denne NeoAgent-server, før du scanner en QR-kode til parring.';

  @override
  String get signInWithAHardwareKey =>
      'Log ind med en hardwarenøgle eller adgangsnøgle i stedet for din adgangskode. ';

  @override
  String get signInWithASecurityKey => 'Log ind med en sikkerhedsnøgle';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Log ind med $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Godkend NeoAgent på din $arg1-konto. Ingen nøgle at kopiere.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Venter på $arg1. Afslut i din browser.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Indsæt $arg1-koden';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Efter du har godkendt NeoAgent, viste $arg1 en engangskode. Indsæt det her.';
  }

  @override
  String get signInCode => 'Log ind kode';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Logget ind med $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Login mislykkedes: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Log ind med den samme e-mail og hovedadgangskode, som du bruger i Bitwarden. Hovedadgangskoden og totrinskoden bruges kun til login og gemmes eller sendes aldrig til AI\'en.';

  @override
  String get signOut => 'Log ud';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Vil du logge af @$arg1 overalt?';
  }

  @override
  String get signOutEverywhere => 'Log ud overalt';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API-bro';

  @override
  String get signalCliServerUrl => 'signal-cli server URL';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Signerede @$arg1 ud af hver session.';
  }

  @override
  String get signedInDevices => 'Enheder, der er logget ind';

  @override
  String get signedInWithin24Hours => 'Logget ind inden for 24 timer';

  @override
  String get signingSecret => 'Signeringshemmelighed';

  @override
  String sinceArg1(Object? arg1) {
    return 'Siden $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'siden $arg1';
  }

  @override
  String get singleMessage => 'Enkelt besked';

  @override
  String get singleUse => 'Engangsbrug';

  @override
  String get skill => 'Færdighed';

  @override
  String get skillChanges => 'Ændringer i færdigheder';

  @override
  String get skillContent => 'Færdighedsindhold';

  @override
  String get skills => 'Færdigheder';

  @override
  String get skip => 'Spring over';

  @override
  String get skipForNow => 'Spring over for nu';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Spring denne opgave over, før den kalder modellen.';

  @override
  String get slackMessageReceived => 'Slack besked modtaget';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Søvn $arg1 sessioner';
  }

  @override
  String get smartSelector => 'smart vælger';

  @override
  String get smartSelector2 => 'Smart vælger';

  @override
  String get smartSelectorPool => 'Smart Selector Pool';

  @override
  String get smtpHost => 'SMTP vært';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp mail afsender adgangskode tls bekræftelsesmeddelelser nulstillet';

  @override
  String get smtpPassword => 'SMTP adgangskode';

  @override
  String get smtpPort => 'SMTP-port';

  @override
  String get smtpPortMustBeAWhole =>
      'SMTP-porten skal være et helt tal fra 1 til 65535.';

  @override
  String get smtpUsername => 'SMTP brugernavn';

  @override
  String get soTheRunStartsThatMuch => 'så løbet starter så meget tidligere.';

  @override
  String get socialBehaviorOff => 'Social adfærd slukket';

  @override
  String get socialIntelligence => 'social intelligens';

  @override
  String get socialIntelligence2 => 'Social intelligens';

  @override
  String get socialObservability => 'Social observerbarhed';

  @override
  String get socialReach => 'social rækkevidde';

  @override
  String get socialReach2 => 'Social rækkevidde';

  @override
  String get socialReach3 => 'Social rækkevidde';

  @override
  String get socialReachUpdated => 'Social Reach opdateret.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Sociale kilder-agenter kan læse direkte, herunder feeds, repositories, Reddit, X, videoer og cookie-understøttede markedsdata.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Noget gik galt. Prøv venligst igen.';

  @override
  String get source => 'Kilde';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Mellemrum eller chat-id, der bruges, når denne agent starter en samtale.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space webhook og app callback support';

  @override
  String get speaking => 'Taler';

  @override
  String get speechToSpeechModelUsingThe =>
      'tale-til-tale-model ved hjælp af OpenAI- eller Google-tasten under ';

  @override
  String get speechToText => 'Tale-til-tekst';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Tale-til-tekst transskriberer stemmenoter og diktering. Auto bruger OpenAI, Gemini eller Deepgram, alt efter hvad der har en API-nøgle. Stemmesvarsmodellen er chatmodellen, der besvarer stemmebeskeder.';

  @override
  String get sqlConsole => 'SQL konsol';

  @override
  String get stable => 'Stabil';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable installerer den seneste publicerede backend-udgivelse.';

  @override
  String get stackTrace => 'stak spor';

  @override
  String get standard => 'Standard';

  @override
  String get standardView => 'Standard udsigt';

  @override
  String get start => 'Start';

  @override
  String get startASessionToPlanOr =>
      'Start en session for at planlægge eller bygge med NeoAgent.';

  @override
  String get startAndroid => 'Start Android';

  @override
  String get startComputer => 'Start computeren';

  @override
  String get startFullSetup => 'Start fuld opsætning';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Start opsætning';

  @override
  String get startTalking => 'Begynd at tale';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Start først Android-telefonen, og slip derefter en .apk- eller .apks-fil her.';

  @override
  String get startTheServerLaterFromThe =>
      'Start serveren senere fra listen, når konfigurationen er gemt.';

  @override
  String get startWithARecommendedTask => 'Start med en anbefalet opgave';

  @override
  String get startingAndroid => 'Starter Android';

  @override
  String get startingYourComputer => 'Starter din computer';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Starter med xoxb-. Fra dine Slack-applegitimationsoplysninger.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting-fejl: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistik kører tokens brugere diagrammer succesrate';

  @override
  String get status => 'Status';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'status database runtime vm udbydere';

  @override
  String get statusIsNotLoadedYet => 'Status er ikke indlæst endnu.';

  @override
  String get stayManagedByYou => 'blive styret af dig.';

  @override
  String get stayOnTheCall => 'Bliv ved med at ringe';

  @override
  String get stayedQuiet => 'Forblev stille';

  @override
  String get steering => 'STYRING';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'TRIN $arg1 AF $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Trin $arg1';
  }

  @override
  String get stop => 'Stop';

  @override
  String get stop2 => 'Stop (⌘.)';

  @override
  String get stopManaging => 'Stop med at styre';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Stop med at administrere $arg1?';
  }

  @override
  String get stopRun => 'Stop løb';

  @override
  String get stopSpeaking => 'Stop med at tale';

  @override
  String get stoppedBeforeCompletion => 'Stoppet før færdiggørelse';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting-fejl: $arg1';
  }

  @override
  String get storage => 'Opbevaring';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'gemt krypteret og kun brugt til dine egne løb.';

  @override
  String get storedMetrics => 'Gemte metrics';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Gemmer kun Bitwarden-sessionsnøglen krypteret på denne server, så forbindelser overlever genstarter. Du kan låse den til enhver tid.';

  @override
  String get strong => 'Stærk';

  @override
  String get strongPassword => 'Stærk adgangskode.';

  @override
  String get subAgent => 'Underagent';

  @override
  String get subagentUpdate => 'Subagent opdatering';

  @override
  String get subagentUpdate2 => 'Subagent opdatering.';

  @override
  String get successRate => 'Succesrate';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Forslag: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Opsummer mit sidste løb';

  @override
  String get supportUrl => 'Support URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Understøttet: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Skift agent';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Symbolske links er ikke tilladt i NeoAgent Workspace-stier.';

  @override
  String get syncNow => 'Synkroniser nu';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'Systemets privatlivsindstillinger';

  @override
  String get tableInfoUsers => 'Tabelinfo (brugere)';

  @override
  String get tagsOnly => 'Kun tags';

  @override
  String get tasks => 'Opgaver';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Opgaverne kører af sig selv og sender dig besked med ';

  @override
  String get teach => 'Undervise';

  @override
  String get teachingInProgress => 'Undervisning i gang';

  @override
  String get team => 'Team';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Teamlinks gør aldrig nogen til serveradministratorer. Administratorer kører ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Teamspaces, værelser, kanaler og live-fællesskaber.';

  @override
  String get teamsMessageReceived => 'Teams besked modtaget';

  @override
  String get templates => 'Skabeloner';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Midlertidige opsætningsfiler vil blive ryddet op senere.';

  @override
  String get tenantId => 'Lejer ID';

  @override
  String get testConnection => 'Test forbindelse';

  @override
  String get testConnection2 => 'Test forbindelse';

  @override
  String get textChat => 'SMS og chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'der tilføjede deres egen nøgle, fortsæt med at bruge det.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Denne e-mail tilhører allerede en eksisterende konto. Log først ind, og tilknyt derefter Google fra kontoindstillinger.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Denne e-mail er allerede knyttet til en anden konto.';

  @override
  String get thatQrCodeIsNotA =>
      'Denne QR-kode er ikke en NeoAgent-loginanmodning.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Den QR-kode er ikke en NeoAgent-parringsanmodning.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Den sikkerhedsnøgle er allerede registreret på denne konto.';

  @override
  String get theAddress => 'Adressen';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Adressen på din BlueBubbles-server.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Den adresse, folk og OAuth-udbydere bruger til at nå ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agenten læser tidspunkter, du nævner, og kører planlagte opgaver i denne tidszone.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agenten vil spørge før hvert følsomt værktøj, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Agenten vil ignorere denne færdighed.';

  @override
  String get theAppCouldNotReachThis =>
      'Appen kunne ikke nå denne NeoAgent-implementering. Tjek din netværksforbindelse, eller bekræft, at tjenestens URL er korrekt.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Browseren blokerede en anmodning til $arg1 på grund af indholdssikkerhedspolitik.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Browseren blokerede en påkrævet anmodning på grund af indholdssikkerhedspolitik.';

  @override
  String get theCloudWorkspace => 'cloud-arbejdsområdet';

  @override
  String get theComputerCouldNotStart => 'Computeren kunne ikke starte';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Computeren har brug for mere ledig diskplads på NeoAgent-værten. Frigør noget plads, og prøv derefter igen.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Computerens runtime skal repareres. Kør NeoAgent Doctor, og prøv derefter igen.';

  @override
  String get theConnectionTestFailed => 'Forbindelsestesten mislykkedes.';

  @override
  String get theDesktopDidNotStart => 'Skrivebordet startede ikke';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Den opdagede NeoAgent returnerede ufuldstændige identitetsdata.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Den opdagede NeoAgent bruger en ikke-understøttet opsætningsprotokol.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Den opdagede tjeneste er ikke NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Den downloadede NeoAgent-runtime bestod ikke bekræftelse.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Google Chat space webhook, som denne agent skal sende til.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Installationsprogrammet er ikke længere tilgængeligt.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Det interaktive Linux-skrivebord er tilgængeligt i NeoAgent-webappen.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Introen er ikke tilgængelig på denne enhed.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Det seneste kører på alle konti.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Det seneste synkroniseringsvindue sluttede $arg1 og fandt ingen nye Health Connect-poster. Gemte metrics nedenfor kom fra tidligere synkroniseringer.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Den grafiske Linux-session kører ikke.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Live-stemmemodellen svarede ikke. Prøv igen.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Den lokale NeoAgent-kommando afsluttede med koden $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Den lokale NeoAgent-kommando fik timeout.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Den lokale NeoAgent runtime skal repareres.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Den lokale kørselstid skal repareres ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Den lokale brugerhjemmemappe er ikke tilgængelig.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Mailkontoen NeoAgent sender tilmeldingsbekræftelser, login ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Hovedagenten oprettes automatisk efter behov.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Den matchende NeoAgent-runtime mangler i denne udgivelse.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Den vigtigste indgående webhook, som denne agent skal sende til.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'De modeller, som Smart Selector ruter mellem automatisk.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'NeoAgent-backend-downloaden matchede ikke manifestet.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'NeoAgent-backend-downloaden var ufuldstændig.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'NeoAgent-backend\'en på denne computer svarer ikke på porten ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'NeoAgent-backend-runtiden kunne ikke downloades.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'NeoAgent-backend\'en tog for lang tid at svare for $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'NeoAgent-implementeringen svarede med HTTP 402 i stedet for den normale 401 for ugyldige legitimationsoplysninger. Tjek omvendt proxy, godkendelsesgateway eller betalingsrelaterede regler på den server.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'NeoAgent-implementeringen svarede med HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'NeoAgent-implementeringen svarede med HTTP 402. Tjek omvendt proxy, godkendelsesgateway eller betalingsrelaterede regler på den server.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'NeoAgent-instansen, som denne app er forbundet til.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'NeoAgent-udgivelsestjenesten returnerede ugyldige data.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'NeoAgent runtime artefaktmetadata er ugyldige.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'NeoAgent-runtime-manifestet bestod ikke signaturbekræftelse.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'NeoAgent runtime-manifestet har ingen artefakter.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'NeoAgent runtime-manifestsignaturen er ugyldig.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Den adgangskode, du angiver i BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'De mennesker, du leder, bliver hos dig.';

  @override
  String get theProviderAnswers => 'udbyderen svarer.';

  @override
  String get theQueryReturnedNoRows =>
      'Forespørgslen returnerede ingen rækker.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Den ønskede skrivebordsskærm er ikke tilgængelig.';

  @override
  String get theRest => 'resten.';

  @override
  String get theRestEndpointForYourSignal =>
      'REST-endepunktet for din signal-cli-instans.';

  @override
  String get theRunIsPausedUntilYou =>
      'Løbet er sat på pause, indtil du svarer.';

  @override
  String get theRunStartsAtTheScheduled =>
      'Løbet starter på det planlagte tidspunkt.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Runtime er et letvægts Debian Linux-skrivebord med Chromium, PCManFM, Mousepad, LXTerminal, Python, Git og standard kommandolinjeværktøjer. Dens kapacitet administreres af NeoAgent-værten.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Sikkerhedsnøgleregistreringen kunne ikke startes.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'serveren beholder kun et fingeraftryk af det.';

  @override
  String get theServerOnThisComputerIs =>
      'Serveren på denne computer kører ikke';

  @override
  String get theServerReportedNoHealthChecks =>
      'Serveren rapporterede ingen sundhedstjek.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Signaltelefonnummeret, som denne bot bruger.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Teams indgående webhook, som denne agent skal sende til.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Tofaktorudfordringen udløb. Log ind igen.';

  @override
  String get theTwoFactorCodeIsNot => 'Tofaktorkoden er ikke gyldig.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Den bekræftede runtime-pakke kunne ikke markeres som eksekverbar.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Den verificerede runtime-pakke mangler nødvendige filer.';

  @override
  String get theWebAppCouldNotReach =>
      'Webappen kunne ikke nå NeoAgent-backend.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Webappen kunne ikke nå NeoAgent-backend på $arg1. Tjek browserkonsollen og omvendt proxy/netværkskonfiguration.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'sig selv; serveroperatøren fjerner admin først med ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Disse kanaler forbliver tavse. Hvis du vil høre fra dem igen, skal du tilføje dem under Hvem kan sende beskeder til den pågældende platform.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Disse lister er valgfrie, medmindre et afsnit ovenfor er indstillet til kun godkendt.';

  @override
  String get thesePeopleAnywhere => 'Disse mennesker, hvor som helst';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Disse mennesker kan sende beskeder til $arg1 i private chats og i enhver gruppe, de deler.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Disse personer kan sende beskeder til $arg1 én-til-én. Dette lader dem ikke tale i grupper.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Disse personer kan kun sende beskeder til $arg1 i den gruppe, du har valgt.';
  }

  @override
  String get thesePeopleInOneGroup => 'Disse mennesker i én gruppe';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'disse kontakter, aldrig dine chats, minder eller filer.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Denne konto låser NeoAgent op på denne maskine.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Denne agent kan uddelegere til enhver kvalificeret modtagende agent.';

  @override
  String get thisAgentIsUsingAServer =>
      'Denne agent bruger en serverstyret Trello API-nøgle. Du behøver kun at godkende et kontotoken nedenfor.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Denne build har ikke tilladelse til at tale med denne NeoAgent-installation.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Denne kode tilhører en anden NeoAgent-server: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Dette skrivebord er tilsluttet';

  @override
  String get thisDevice => 'Denne enhed';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Denne enhed: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Denne enhed kan ikke registrere sikkerhedsnøgler. Åbn NeoAgent i en browser over HTTPS for at tilføje en.';

  @override
  String get thisDeviceUnavailable => 'Denne enhed — ikke tilgængelig';

  @override
  String get thisFileHasNoContent => 'Denne fil har intet indhold.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Dette skjuler \"$arg1\" fra routing og valg.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Denne integration understøtter i øjeblikket én tilsluttet konto pr. agent. Genåbn opsætningen for at erstatte den.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Denne integration er ikke længere tilgængelig.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Denne intro er designet til landskabsafspilning i fuld skærm.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Dette er en administreret implementering. Dens operatør ruller ud ';

  @override
  String get thisMayTakeAMoment => 'Dette kan tage et øjeblik.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Denne MCP-server er ikke længere konfigureret.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Denne hukommelse vil blive fjernet permanent.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Denne NeoAgent-build er ikke konfigureret til at bekræfte backend-kørselstider.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Dette sletter permanent alle dine data og kan ikke være det ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Dette sletter permanent kontoen og alt, hvad den ejer: ';

  @override
  String get thisPersonAnywhere => 'Denne person, hvor som helst';

  @override
  String get thisPersonInOneGroup => 'Denne person, i én gruppe';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Denne QR-loginanmodning er udløbet. Generer en ny kode, og prøv igen.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'denne qr-loginanmodning er udløbet';

  @override
  String get thisQrLoginRequestIsStill =>
      'Denne QR-loginanmodning venter stadig på godkendelse.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Denne QR-loginanmodning blev allerede brugt.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Dette fjerner Home Assistant-opsætningen og den tilsluttede instans for denne agent.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Dette fjerner NeoRecall-backend-URL\'en og alle tilsluttede NeoRecall-konti for denne agent.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Dette fjerner Nextcloud-URL\'en og alle tilsluttede Nextcloud-konti for denne agent.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Dette fjerner Trello-opsætningen og tilsluttede konti for denne agent.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Dette kræver en autentificeret session på den samme NeoAgent-server.';

  @override
  String get thisRunDidNotProduceA =>
      'Denne kørsel producerede ikke et brugervendt svar.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Denne kørsel har ingen registrerede trindata.';

  @override
  String get thisServer => 'denne server.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Denne server rapporterer ingen udbyderindstillinger.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Denne færdighed er ikke længere installeret.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Denne opgave er endnu ikke afsluttet, så den starter stadig kl ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Denne opgave kører kun, når du trykker på Kør nu.';

  @override
  String get thisWeek => 'Denne uge';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Dette vil importere svaret til $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Dette vil fjerne \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Dette vil fjerne \"$arg1\" fra serverlisten.';
  }

  @override
  String get time => 'Tid';

  @override
  String get timeZone => 'tidszone';

  @override
  String get timeZone2 => 'Tidszone';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Timeout $arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Kunne ikke vise tidszoner: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Kunne ikke læse enhedens tidszone: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Kunne ikke gemme enhedens tidszone: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'til $arg1';
  }

  @override
  String get toUseTheServerDefault => 'for at bruge serverstandarden.';

  @override
  String get today => 'I dag';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Tokenbudget for @$arg1. Lad et felt stå tomt ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Tokenbudget for hver konto uden sin egen tilsidesættelse. Efterlad en ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'token budgetgrænse 4 timers ugentlig kvote bruger';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'token budgetgrænse 4 timers ugentlig kvote globalt';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Tokenbrug er ikke tilgængeligt på denne serverversion.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Poletter, som enhver konto kan bruge på 4 timer.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokens kan enhver konto bruge om 7 dage.';

  @override
  String get tokensPerDay => 'Poletter pr. dag';

  @override
  String get tokensPerRun => 'Poletter pr. løb';

  @override
  String get tokensToday => 'Tokens i dag';

  @override
  String get tokensUsed => ' brugte poletter';

  @override
  String get tomorrowPrep => 'Forberedelse i morgen';

  @override
  String get tooManyAttempts => 'for mange forsøg';

  @override
  String get tooManySignInAttemptsPlease =>
      'For mange loginforsøg. Vent venligst og prøv igen.';

  @override
  String get tool => 'Værktøj';

  @override
  String get toolApproval => 'Værktøjsgodkendelse';

  @override
  String get toolApprovalRequired => 'Værktøjsgodkendelse påkrævet';

  @override
  String get toolCompleted => 'Værktøj færdigt';

  @override
  String get toolFailed => 'Værktøjet mislykkedes';

  @override
  String get toolPermissions => 'Værktøjstilladelser';

  @override
  String get toolStarted => 'Værktøj startet';

  @override
  String get tools => 'Værktøjer';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Værktøjer, der ikke er indbygget i NeoAgent, inklusive tilsluttede MCP-servere og udbydere af brugerdefinerede værktøj.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Tilbudte værktøjer ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Værktøjer, som den administrerede konto kan bruge';

  @override
  String get topUsers => 'Topbrugere';

  @override
  String get topUsersAndRecentRuns => 'Topbrugere og seneste kørsler';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'I alt: $arg1-tokens på tværs af $arg2-kørsler';
  }

  @override
  String get totalRuns => 'Kørsler i alt';

  @override
  String get totalTokens => 'Samlede tokens';

  @override
  String get totalUsers => 'Samlede brugere';

  @override
  String get transcript => 'Afskrift';

  @override
  String get transcript2 => 'TRANSKRIPT';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transskription mislykkedes: $arg1';
  }

  @override
  String get transfer => 'Overførsel';

  @override
  String get trelloApiKey => 'Trello API nøgle';

  @override
  String get trelloApiKeyIsRequired => 'Trello API-nøgle er påkrævet.';

  @override
  String get trelloSetup => 'Trello opsætning';

  @override
  String get triggerType => 'Trigger type';

  @override
  String get tryABroaderSearchLikeModels =>
      'Prøv en bredere søgning som modeller, browser eller stemme.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Prøv et udbydernavn, \"e-mail\", \"grænser\", \"opdatering\" eller \"logfiler\".';

  @override
  String get tryAgain => 'Prøv igen';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Prøv igen. Hvis dette bliver ved med at ske, skal du køre NeoAgent Doctor for at kontrollere computerens køretid.';

  @override
  String get tryAgainInAMoment => 'Prøv igen om et øjeblik.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Prøv igen, eller kør NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Prøv en anden søgning, tilslut en meddelelsesplatform, eller indtast et destinations-id manuelt.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Slå en gruppe til, hvis $arg1 også skal læse beskeder, der ikke mærker den.';
  }

  @override
  String get turnOffComputer => 'Sluk computeren';

  @override
  String get turnOffOnlyForAMail =>
      'Sluk kun for en mailserver med et selvsigneret certifikat.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Slå til, hvis Signal skal blive ved med at lede efter indgående chats.';

  @override
  String get turnTaking => 'tur tage';

  @override
  String get turnTakingModel => 'Turn-tag model';

  @override
  String get turnTakingOff => 'Drej-start';

  @override
  String get turnThisOffToKeepThis =>
      'Slå denne fra for at holde denne agent helt adskilt fra andre agenter.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Slukket af $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Slået fra af $arg1, som administrerer denne konto. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Slukket for dig af $arg1 - kun de kan ændre det';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Slukket for dig, så du kan ikke dele den ud';

  @override
  String get twitchChatOverIrc => 'Twitch chat over IRC';

  @override
  String get twoFactorAuthentication => 'To-faktor autentificering';

  @override
  String get twoFactorChallengeExpired => 'to-faktor udfordring udløb';

  @override
  String get twoFactorCode => 'to-faktor kode';

  @override
  String get twoFactorSignInCompletedBut =>
      'To-faktor-login fuldført, men NeoAgent kunne ikke beholde browsersessionen. Log venligst ind igen.';

  @override
  String get twoStepLoginOnlyIfEnabled => 'To-trins login (kun hvis aktiveret)';

  @override
  String get type => 'Type';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Skriv $arg1 for at bekræfte';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'type tekst er ikke understøttet på denne platform.';

  @override
  String get typedInTheBrowser => 'Indtastet i browseren';

  @override
  String get typedText => 'Indskrevet tekst';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'ude af stand til at finde en java runtime';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Kan ikke åbne tidsindstillinger på denne build.';

  @override
  String get unableToOpenWiFiSettings =>
      'Kunne ikke åbne Wi-Fi-indstillinger på denne build.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Kan ikke fortsætte den valgte skrivebordsvisning.';

  @override
  String get unclearWhoItWasFor => 'Uklart hvem det var til';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'fortrydes. Indtast dit brugernavn for at bekræfte.';

  @override
  String get unknownAccount => 'Ukendt konto';

  @override
  String get unknownAgent => 'Ukendt agent';

  @override
  String get unknownBrowser => 'Ukendt browser';

  @override
  String get unknownDevice => 'Ukendt enhed';

  @override
  String get unknownError => 'ukendt fejl';

  @override
  String get unknownLocalComputerPermission =>
      'Ukendt lokal computertilladelse.';

  @override
  String get unknownLocation => 'Ukendt placering';

  @override
  String get unknownPublishTime => 'Ukendt udgivelsestidspunkt';

  @override
  String get unknownSize => 'Ukendt størrelse';

  @override
  String get unlink => 'Fjern linket';

  @override
  String get unreadOnly => 'Kun ulæst';

  @override
  String get unsavedChanges => 'Ikke-gemte ændringer';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Ikke-understøttet desktop companion-kommando: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Ikke-understøttet metode: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Usædvanlige login-advarsler';

  @override
  String updateArg1(Object? arg1) {
    return 'Opdater $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Opdater kernehukommelsesposter fra importen.';

  @override
  String get updateNow => 'Opdater nu';

  @override
  String get updateReady => 'Opdatering klar';

  @override
  String get updateSetup => 'Opdater opsætning';

  @override
  String get updateTheAccessListToAllow =>
      'Opdater adgangslisten for at tillade svar.';

  @override
  String get updateTheServer => 'Opdatere serveren?';

  @override
  String get updateTheServer2 => 'Opdater serveren';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Opdater tidszonen automatisk fra den enhed, du bruger.';

  @override
  String updatedArg1(Object? arg1) {
    return 'opdateret $arg1';
  }

  @override
  String get updates => 'Opdateringer';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Opdateringer er ikke konfigureret til denne build.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'opdateringer, så selvopdatering og kanalændringer er slået fra her.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'opgrader opdatering frigiver nu kanalstabil beta';

  @override
  String get usageAnalytics => 'Brugsanalyse';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Brugs- og sundhedssignaler, der hjælper med at forklare den aktuelle køretidsadfærd uden først at grave gennem logfiler.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Brug nulstilles fuldstændigt i $arg1';
  }

  @override
  String get usageLeaderboard => 'brugs leaderboard';

  @override
  String get usageLimits => 'Brug & begrænsninger';

  @override
  String get usageLimits2 => 'Brug & grænser';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Brug 8+ tegn. Længere adgangssætninger fungerer godt.';

  @override
  String get useADateAndTimeFor =>
      'Brug en dato og et klokkeslæt, for eksempel 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Brug et navn, telefonnummer eller chat-id.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Brug en NeoRecall-URL, som NeoAgent-serveren kan nå. NeoAgents PUBLIC_URL skal også være tilgængelig fra denne browser til OAuth-tilbagekald.';

  @override
  String get useANewPasswordWithAt =>
      'Brug en ny adgangskode med mindst 8 tegn.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Brug en Nextcloud-URL, som NeoAgent-serveren kan nå, for eksempel https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Brug en adgangskode med mindst 8 tegn.';

  @override
  String get useASecureConnectionTls => 'Brug en sikker forbindelse (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Brug en godkendelsesapp såsom Authy, 1Password eller Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Brug mindst 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Maks. hukommelse pr. computer (MB)';

  @override
  String get maxVcpusPerComputer => 'Maks. vCPU\'er pr. computer';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Mindst $arg1. Computere bliver mindre, når værten har travlt.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Maks. hukommelse skal være mindst $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Brug mindst 8 tegn.';

  @override
  String get useDefault => 'Brug standard';

  @override
  String get useDefaultChannel => 'Brug standardkanal';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Brug standard (NeoAgent Workspace)';

  @override
  String get useFor => 'Bruges til';

  @override
  String get useManualDestination => 'Brug manuel destination';

  @override
  String get useOrDoTheSameFor =>
      'bruge, eller gør det samme for dine holdkammerater.';

  @override
  String get usePerCategorySettingsBelow =>
      'Brug indstillinger pr. kategori nedenfor.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Brug standardindstillinger ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Brug serveren på denne computer';

  @override
  String get useTheseForContextIfA =>
      'Brug disse til kontekst. Hvis en lokal URI ikke er direkte tilgængelig fra serveren, bede mig om at levere filen via et tilgængeligt arbejdsområde.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Brug dette til orkestratoragenter. Lad være med isolerede arbejdsbots, der selv skal afslutte direkte beskeder.';

  @override
  String get useTlsFromTheStartOf =>
      'Brug TLS fra starten af forbindelsen, normalt på port 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Brug din egen API-nøgle til en udbyder, eller tilslut en brugerdefineret ';

  @override
  String get usedByEveryAccountOnThis =>
      'Bruges af hver konto på denne server, der ikke har nogen nøgle ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Bruges til at bekræfte, at indkommende Slack-begivenheder er ægte.';

  @override
  String get userSummary => 'Brugeroversigt';

  @override
  String get username => 'Brugernavn';

  @override
  String get usernameOrEmail => 'Brugernavn eller e-mail';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'brugere folk søger e-mail brugernavn admin badge administreret team';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Bruger chatmodellen, der er konfigureret i Indstillinger';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Brug af den installerede NeoAgent runtime';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Ser normalt ud som @bot:matrix.org';

  @override
  String get validEmail => 'gyldig e-mail';

  @override
  String get value => 'Værdi';

  @override
  String get vaultLocked => 'Hvælving låst';

  @override
  String get vaultOperationFailed => 'Vault-handling mislykkedes.';

  @override
  String vectorRankArg1(Object? arg1) {
    return 'Vektorrangering: $arg1';
  }

  @override
  String get verification => 'Verifikation';

  @override
  String verificationArg1(Object? arg1) {
    return 'Verifikation: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'verifikation: $arg1';
  }

  @override
  String get verificationCompleted => 'Bekræftelse afsluttet.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Verifikationsstatus: $arg1';
  }

  @override
  String get verifiedTheResult => 'Bekræftet resultatet';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Bekræfter den downloadede runtime';

  @override
  String get versionAndUptime => 'Version og oppetid';

  @override
  String versionArg1(Object? arg1) {
    return 'Version $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Version $arg1 er installeret, men $arg2 kører stadig.';
  }

  @override
  String get videoLinks => 'Video links';

  @override
  String get viewDesktop => 'Se skrivebordet';

  @override
  String get viewLastRun => 'Se sidste løb';

  @override
  String get viewLogs => 'Se logfiler';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm billedhukommelse cpu qemu runtime';

  @override
  String get voice => 'Stemme';

  @override
  String get voiceAssistant => 'Stemmeassistent';

  @override
  String get voiceCall => 'STEMMEOPKALD';

  @override
  String get voiceCall2 => 'Stemmeopkald';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'taleopkald gpt-live gemini live model tale i realtid';

  @override
  String get voiceCallsRunOnALive =>
      'Stemmeopkald kører på en live tale-til-tale-model med samme persona, hukommelse og chathistorik som NeoAgent. Den svarer med det samme og giver rigtigt arbejde til den normale agent, som bliver ved med at køre i baggrunden.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'voice note tale transskription api nøgle';

  @override
  String get voiceNotesAndDictation => 'Stemmenoter og diktat';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Stemmeafspilning er ikke tilgængelig på denne enhed.';

  @override
  String get voiceReplyModel => 'Stemmesvar model';

  @override
  String get waitingForApproval => 'Venter på godkendelse: ';

  @override
  String get waitingForCode => 'Venter på kode';

  @override
  String get waitingForInput => 'Venter på input';

  @override
  String get waitingForServerOrFlutterLog =>
      'Venter på server- eller Flutter-logoutput...';

  @override
  String get waitingForTaskEvents => 'Venter på opgavebegivenheder...';

  @override
  String get waitingForYou => 'venter på dig';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Ønskede et svar fra $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Ønsker at tale med dig · ${arg1}s';
  }

  @override
  String get weak => 'Svag';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Vejr, kalender og prioriteter inden din dag starter.';

  @override
  String get weatherEvent => 'Vejrbegivenhed';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'Webbrowser';

  @override
  String get webSearchApiKey => 'websøgning API-nøgle';

  @override
  String get webhookOrRestChannelPosting => 'Webhook eller REST kanalopslag';

  @override
  String get webhookSecret => 'Webhook hemmelighed';

  @override
  String get webhookUrlCopied => 'Webhook URL kopieret';

  @override
  String get weekdays => 'Hverdage';

  @override
  String get weekdays0730 => 'Hverdage · 07:30';

  @override
  String get weekdays1800 => 'Hverdage · 18:00';

  @override
  String get weekly => 'Ugentligt';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Ugentlig grænse $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Ugentlig grænse (tokens)';

  @override
  String get weeklyReview => 'Ugentlig gennemgang';

  @override
  String get weeklyUsage => 'Ugentlig brug';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Vægt $arg1 rekorder';
  }

  @override
  String get welcomeToNeoagent => 'VELKOMMEN TIL NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Velkommen\ntil NeoAgent';

  @override
  String get whatAreYouAdding => 'Hvad tilføjer du?';

  @override
  String get whatIsOnTomorrow => 'Hvad sker der i morgen?';

  @override
  String get whatShouldNeoagentLearn => 'Hvad skal NeoAgent lære?';

  @override
  String get whatShouldWeBuild => 'Hvad skal vi bygge?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Det du og NeoAgent siger, fremgår her og i chatten.';

  @override
  String get whatsappPersonalMessageReceived =>
      'WhatsApp personlig besked modtaget';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Når du vælger kun godkendt, skal du tilføje personer eller grupper nedenfor.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Hvor denne agent skal sende svar.';

  @override
  String get whoCanMessage => 'Hvem kan sende besked';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Hvem kan sende besked på $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Hvem kan sende $arg1 en en-til-en besked.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Hvem kan tale med $arg1 i en gruppe, kanal eller rum.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'hvem administrerer denne konto slået fra: ';

  @override
  String get whoManagesWhom => 'Hvem styrer hvem';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Den, der accepterer et link, slutter sig til dit team med kun de værktøjer, det er ';

  @override
  String get wholeGroup => 'Hele gruppen';

  @override
  String get wholeGroups => 'Hele grupper';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Hvorfor $arg1 svarede eller forblev stille i $arg2-grupper.';
  }

  @override
  String get windowsApp => 'Windows app';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'Arbejdskonto';

  @override
  String get workOnAProjectWithNeoagent => 'Arbejd på et projekt med NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Arbejdsgang: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Arbejder i $arg1 på cloud-computeren. NeoAgent læser og redigerer filer der og kan køre kommandoer og en browser.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Arbejder i baggrunden: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Arbejdsområdekonfiguration og kontosikkerhed på ét sted.';

  @override
  String get workspaceFiles => 'Arbejdsområde filer';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Arbejdsrum, modeller og diagnostiske kontroller.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Arbejdsområdetilsidesættelse skal være en absolut sti.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Skrev $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttprequest fejl';

  @override
  String get yesterday => 'I går';

  @override
  String get youAreInControl => 'Du er i kontrol';

  @override
  String get youCanFollowAlongOnThe => 'Du kan følge med på skrivebordet.';

  @override
  String get youCanLeaveATeamAt =>
      'Du kan til enhver tid forlade et hold; dine egne indstillinger gælder igen.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Du kan til enhver tid forlade fra Team-siden.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Du bestemmer, hvilke værktøjer din agent må bruge, under Indstillinger › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Du administrerer ikke nogen endnu. Opret et invitationslink nedenfor og ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Du har ikke-gemte indstillinger. Hvad vil du gerne lave?';

  @override
  String get youReOnYourOwnYou =>
      'Du er alene: du bestemmer, hvilke værktøjer din agent må bruge. Hvis ';

  @override
  String get yourAccountAndUsageOnA =>
      'din konto -- og brug på en model understøttet af din egen nøgle ';

  @override
  String get yourAccountHasBeenDeleted => 'Din konto er blevet slettet.';

  @override
  String get yourAgentWillBeAllowed => 'Din agent får tilladelse til:';

  @override
  String get yourAppsAndFilesAreSaved => 'Dine apps og filer gemmes.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Dine apps og filer forbliver gemt.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Din $arg1 nøgle';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Dit assistentlag til optagelse, kontekst og handling.';

  @override
  String get yourComputerIsAsleep => 'Din computer er i dvale';

  @override
  String get yourComputerIsOff => 'Din computer er slukket';

  @override
  String get yourComputerIsReady => 'Din computer er klar';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Din nuværende adgangskode er forkert.';

  @override
  String get yourData => 'Dine data';

  @override
  String get yourDataExportWasCopiedTo =>
      'Din dataeksport blev kopieret til udklipsholderen.';

  @override
  String get yourDesktopIsReady => 'Dit skrivebord er klar';

  @override
  String get yourLinuxComputer => 'Din Linux-computer';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Din placering bliver aldrig sporet kontinuerligt eller gemt på vores servere. Vi bruger det kun lokalt til at kontrollere dine aktive opgaver.';

  @override
  String get yourManager => 'din leder';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Din Mattermost-websteds-URL, hvis du bruger REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Din session udløb eller blev ikke bevaret af browseren. Log venligst ind igen.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Din session udløb. Log venligst ind igen.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Dit brugernavn eller din adgangskode er forkert.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID, …';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Oversigt';

  @override
  String get sectionDiagnostics => 'Diagnostik';

  @override
  String get sectionVolume => 'Volumen';

  @override
  String get sectionSession => 'Session';

  @override
  String get sectionDeliverable => 'Leveres';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Den lokale runtime har ikke skrevet en logfil endnu.';

  @override
  String get thisComputer => 'Denne computer';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta installerer den nyeste prerelease-backend. Forvent ru kanter.';

  @override
  String get copiedFinalResponse => 'Kopieret endeligt svar';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Det endelige svar vises her, når kørslen er færdig.';

  @override
  String get waitingForTheFirstStep => 'Venter på det første skridt...';

  @override
  String get loadingPrompt => 'Indlæser prompt...';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Der blev ikke fanget noget endeligt svar for denne kørsel.';

  @override
  String get readyToSignIn => 'Klar til at logge ind';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Skift til \"Standard\" eller \"Spørg altid\" for at genaktivere godkendelsestjek.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Send en styreopdatering eller næste note for den aktuelle kørsel...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Ingen netværksforbindelse. NeoAgent opretter forbindelse igen, når enheden er online igen.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Anvendte den seneste styreopdatering til den aktuelle kørsel.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Forbereder den private stemmesession...';

  @override
  String get preparingYourComputer => 'Klargøring af din computer';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent er ved at downloade og forberede det sikre Linux-system. Dette sker kun første gang.';

  @override
  String get moreFreeSpaceIsNeeded => 'Der er brug for mere ledig plads';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Frigør noget diskplads på NeoAgent-værten, og prøv derefter igen. Dine eksisterende computerdata er sikre.';

  @override
  String get androidReady => 'Android klar';

  @override
  String get startingAndroid2 => 'Starter Android...';

  @override
  String get androidStopped => 'Android stoppede';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Den første start downloader Android SDK og systembilledet, hvilket kan tage flere minutter.';

  @override
  String get androidIsStopped => 'Android er stoppet';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Start det administrerede Android-miljø, når du har brug for det.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Lad NeoAgent arbejde på denne computer';

  @override
  String get firstTimeSetupIsInProgress => 'Førstegangsopsætning er i gang.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent kan bruge den adgang, du tillader.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Frigør noget host-lagerplads, og prøv igen.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Start, når du vil have NeoAgent til at hjælpe her.';

  @override
  String get systemPermissionMissing => 'Systemtilladelse mangler';

  @override
  String get connectingThisDevice => 'Tilslutning af denne enhed';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Den sikre lokale forbindelse er ved at blive etableret.';

  @override
  String get recordingYourDemonstration => 'Optager din demonstration';

  @override
  String get noErrorsInTheRecentLog => 'Ingen fejl i den seneste log.';

  @override
  String get loadingAccounts => 'Indlæser konti...';

  @override
  String get neverSignedIn => 'Aldrig logget ind';

  @override
  String get emptyUsesTheServerDefault => 'Empty bruger serverstandarden.';

  @override
  String get followTheSelectedSession => 'Følg den valgte session';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Kun plantilstand inspicerer. Skift til agenttilstand for at lade NeoAgent redigere filer.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Påkrævet for at tilføje eller ændre din konto-e-mail.';

  @override
  String get confirmNewPassword => 'Bekræft ny adgangskode';

  @override
  String get passwordChanged => 'Adgangskode ændret.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Denne anmodning er allerede blevet brugt.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Denne anmodning er udløbet. Bed den anden enhed om at generere en ny kode.';

  @override
  String get startQuickstart => 'Start Quickstart';

  @override
  String get createYourAccount => 'Opret din konto';

  @override
  String get showWorkAsSummaries => 'Vis arbejde som opsummeringer';

  @override
  String get tokensUsedByTheLatestRun => 'Tokens brugt af den seneste kørsel';

  @override
  String get listedTheWorkspaceRoot => 'Opført arbejdsområdets rod';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Ingen officielle integrationer er tilgængelige endnu.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Ingen MCP-servere konfigureret endnu. Tilføj en for at afsløre dens værktøjer.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Tilføj en MCP-server eller installer en færdighed for at komme i gang.';

  @override
  String get setUp => 'Indstil';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Lad stå tomt for at beholde den gemte værdi';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Dette fjerner adressen for hver konto på denne server.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Bare snak. Du kan afbryde når som helst. Tryk for at slå lyden fra.';

  @override
  String get tapAgainWhenYouAreDone => 'Tryk igen, når du er færdig.';

  @override
  String get workingOnATaskInTheBackground =>
      'Arbejder med en opgave i baggrunden.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Tale-til-tale med samme hukommelse, værktøjer og chathistorik som NeoAgent.';

  @override
  String get checkLink => 'Tjek link';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Din agent vil ikke få lov til nogen af de kontrollerede værktøjer.';

  @override
  String get notYoursToChange => 'Ikke din til at ændre';

  @override
  String get setByYou => 'Indstillet af dig';

  @override
  String get noTools => 'Ingen værktøj';

  @override
  String get untitledLink => 'Unavngivet link';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Stopper med at arbejde, efter at én person har indløst det.';

  @override
  String get theOperator => 'Operatøren';

  @override
  String get smartSelectorOn => 'Smart vælger tændt';

  @override
  String get startASessionToBegin => 'Start en session for at begynde';

  @override
  String get steerTheActiveRun => 'Styr den aktive kørsel...';

  @override
  String get describeWhatToPlan => 'Beskriv hvad du skal planlægge...';

  @override
  String get stopDictation => 'Stop diktering';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Meddelelser styrer den aktuelle kørsel · ⌘↵ send · ⌘. stop';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Plantilstand inspicerer kun; intet ændres, før du implementerer · ⌘↵ send';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agent redigerer arbejdsområdet. Plan kun inspektioner.';

  @override
  String get defaultModel => 'Standardmodel';

  @override
  String get openingScanner => 'Åbner scanner...';

  @override
  String get theAgentCanUseThisSkill => 'Agenten kan bruge denne færdighed.';

  @override
  String get allSelected => 'Alle udvalgte';

  @override
  String get addCoreMemoryEntry => 'Tilføj Core Memory Entry';

  @override
  String get channelId => 'Kanal-id';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'AI-oprettede og uspecificerede opgaver bruger den nuværende standard.';

  @override
  String get waitingForRunEvents => 'Venter på løbsbegivenheder...';

  @override
  String get hideSteps => 'Skjul trin';

  @override
  String get commitTheActiveLiveCapture => 'Begå den aktive live-optagelse';

  @override
  String get stopCaptureAndSubmit => 'Stop optagelsen og indsend';

  @override
  String get clickTheMicToStartSpeaking =>
      'Klik på mikrofonen for at begynde at tale';

  @override
  String get connectACustomEndpoint => 'Tilslut et tilpasset slutpunkt';

  @override
  String get hostedProvider => 'hostet udbyder.';

  @override
  String get muted => ' • dæmpet';

  @override
  String get addWhoCanMessage => 'Tilføj hvem der kan sende en besked';

  @override
  String get joinsGroupConversations => 'Deltager i gruppesamtaler';

  @override
  String get label1PersonOrGroupAdded => '1 person eller gruppe tilføjet';

  @override
  String get inProgress => 'I gang';

  @override
  String get waitingForUpdateJobOutput => 'Venter på opdateringsjoboutput...';

  @override
  String get taskTrigger => 'Opgaveudløser';

  @override
  String get bearerToken => 'Bærertegn';

  @override
  String get bearerToken2 => 'Bearer Token';

  @override
  String get notRecorded => 'Ikke optaget';

  @override
  String get sessionCookie => 'Session cookie';

  @override
  String get neverUsed => 'Aldrig brugt';

  @override
  String get linkedRecently => 'Linket for nylig';

  @override
  String get notUsedYet => 'Ikke brugt endnu';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'En eller flere konti er udløbet. Genopret forbindelse for at gendanne adgang. Hvis dette bliver ved med at ske, kan din Google Cloud OAuth-app være i testtilstand – udgiv den til produktion i Google Cloud Console for at få langtidsholdbare tokens.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault tilsluttet og tilgængelig efter genstart';

  @override
  String get vaultConnectedForThisSession =>
      'Vault tilsluttet til denne session';

  @override
  String get connectAnotherAccount => 'Tilslut en anden konto';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Indsæt erstatning Long-Lived Access Token';

  @override
  String get updateInstance => 'Opdater instans';

  @override
  String get pasteAReplacementToken => 'Indsæt et erstatningstoken';

  @override
  String get replaceAccount => 'Erstat konto';

  @override
  String get addAccount => 'Tilføj konto';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Kan uddelegere til enhver modtagende agent';

  @override
  String get canReceiveDelegatedTasks2 => 'kan modtage delegerede opgaver';

  @override
  String get noSyncYet => 'Ingen synkronisering endnu';

  @override
  String get noNewData => 'Ingen nye data';

  @override
  String get syncOnceToSeedYourBackend =>
      'Synkroniser én gang for at se din backend.';

  @override
  String get lastWindowEndIsUnknown => 'Sidste vinduesslutning er ukendt.';

  @override
  String get lastNonEmptySync => 'Sidste ikke-tom synkronisering';

  @override
  String get stopTranscribe => 'Stop og transskriber';

  @override
  String get steeringMode => 'Styretilstand';

  @override
  String get noMessageText => 'Ingen beskedtekst';

  @override
  String get reconnectingToServer => 'Genopretter forbindelse til server...';

  @override
  String get signingIn => 'Logger ind...';

  @override
  String get noGroupsFoundYet => 'Ingen grupper fundet endnu';

  @override
  String get onForNewGroupsOnly => 'Kun til for nye grupper';

  @override
  String get noGroupsInThisCategory => 'Ingen grupper i denne kategori';

  @override
  String get groupOrChannel => 'Gruppe eller kanal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Noter du skriver til dig selv starter en løbetur, og svar lander i samme chat. Tilladelseslisten gælder ikke her.';

  @override
  String get needToReply => 'Skal svare';

  @override
  String get enter2faCode => 'Indtast 2FA-kode';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Åbn din autentificeringsapp, og indtast den aktuelle NeoAgent-kode.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Har du allerede en konto? Log ind';

  @override
  String get serverOnThisComputer => 'Server på denne computer';

  @override
  String get showQrCode => 'Vis QR-kode';

  @override
  String get createAnotherNeoagentAccount => 'Opret en anden NeoAgent-konto.';

  @override
  String get canCoordinateDelegatedWork => 'Kan koordinere delegeret arbejde';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'NeoAgent runtime-arkivet kunne ikke udtrækkes.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'NeoAgent runtime-arkivet kunne ikke læses.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'NeoAgent runtime-arkivet indeholder en usikker sti.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'NeoAgent runtime-arkivet indeholder et usikkert link.';

  @override
  String get installingAppPackageOnThePhone =>
      'Installerer app-pakke på telefonen...';

  @override
  String get dragAndDropAApkOrApks =>
      'Træk og slip en .apk- eller .apks-fil her, eller klik for at gennemse.';

  @override
  String get releaseToInstallThisPackage =>
      'Slip for at installere denne pakke';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Sikkerhedsnøglen kunne ikke bruges.';

  @override
  String get connecting => 'Opretter forbindelse...';

  @override
  String get changes => 'Ændringer';

  @override
  String get runtimeReady => 'Runtime klar';

  @override
  String get saving => 'Gemmer...';

  @override
  String get earlier => 'tidligere';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'apr';

  @override
  String get monthMay => 'maj';

  @override
  String get monthJun => 'jun';

  @override
  String get monthJul => 'jul';

  @override
  String get monthAug => 'aug';

  @override
  String get monthSep => 'sep';

  @override
  String get monthOct => 'okt';

  @override
  String get monthNov => 'nov';

  @override
  String get monthDec => 'dec';

  @override
  String get steeringWord => 'Styring';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Dette skifter backend fra $arg1-kanalen til $arg2-kanalen.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return '$arg1 cookies importeret';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '${arg1}s siden';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Køstyring: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Webappen kunne ikke nå NeoAgent-backend.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Browseren blokerede en påkrævet anmodning på grund af indholdssikkerhedspolitik.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 af 4 tilladt';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Gennemfør opgaven, som du plejer.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Ændringer · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Denne enhed · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Grænse nået $arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return '$arg1 gendannelseskoder er stadig tilgængelige.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Sikkerhedsnøgle $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Aktuel session';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nSidst brugt: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Arbejder i $arg1 på denne enhed. NeoAgent læser og redigerer mappen direkte og kan køre kommandoer, åbne apps og bruge skærmen.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Arbejdede for $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Tilladt af $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1-invitationslinks fra $arg2 blev tilbagekaldt';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Tilføj de personer og grupper, $arg1 skal tale med';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Tilføj de personer og grupper, $arg1 har lov til at tale med.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Hvor $arg1 lytter';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 holder øje med disse steder for omtaler. Alle kan skrive her, så folk har stadig brug for deres egen godkendelse nedenfor.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Disse mennesker kan spørge $arg1, uanset hvor de mærker det. Roller tæller kun på de steder, der er anført ovenfor.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Kun når $arg1 er mærket';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Til for alle $arg1-grupper';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 hører stadig kun personer og grupper, du allerede har godkendt. Dette lader bare $arg1 deltage i almindelig chat der, ikke kun tags og svar.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 hører stadig kun personer og grupper, du allerede har godkendt. Dette vælger blot, hvilken af ​​disse grupper den skal tilslutte sig.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Hvis nogen tagger $arg1 eller svarer, svarer $arg1 altid. Slå dette til, hvis $arg1 også skulle ringe ind på almindelig gruppechat.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Nye grupper vil lade $arg1 deltage i almindelig chat med godkendte personer, indtil du slår dem fra.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Nye grupper vil lade $arg1 deltage i almindelig chat, indtil du slår dem fra.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Nye grupper forbliver stille, medmindre en godkendt person tagger $arg1, indtil du tænder dem.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Kun når en godkendt person tagger $arg1, medmindre du slår en gruppe til';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Kun når $arg1 er tagget, medmindre du slår en gruppe til';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 af $arg2-grupper deltager i almindelig chat med godkendte personer';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Dette godkender ikke nye mennesker. Tags og svar fra godkendte personer får altid et svar. Slå en gruppe til, hvis $arg1 også skulle deltage i almindelig chat der.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Dette godkender ikke nye mennesker. Slå en gruppe til, hvis $arg1 skal deltage i almindelig chat med personer, du allerede har godkendt.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Tags og svar får altid et svar. Slå en gruppe til, hvis $arg1 også skulle deltage i almindelig chat der.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 deltager i almindelig chat med godkendte personer';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 kan deltage i almindelig chat';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 svarer kun, når en godkendt person tagger det';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Intet ekstra er nødvendigt. Tilslut for at begynde at bruge $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Opdateres i ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Tilmeld dig med $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Ingen hukommelser knyttet til \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (standard)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Afdeling: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 slutter sig kun til de grupper og kanaler, du tilføjer nedenfor.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 er påkrævet for at lokalisere NeoAgent runtime-data.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[trunkeret forhåndsvisning, $arg1 bytes i alt]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefakt afgrænset, $arg1 bytes i alt]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' i $arg1';
  }

  @override
  String get worldNews => 'Verdensnyheder';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Løb, når nye verdensoverskrifter dukker op. Din prompt afgør, om du vil underrette dig.';

  @override
  String get newsKeywordsOptional => 'Søgeord (valgfrit)';

  @override
  String get worldNewsSetup => 'Verdensnyhedsopsætning';

  @override
  String get connectWorldNewsWithGnews =>
      'Tilføj en GNews API-nøgle (gratis plan tilgængelig på gnews.io). Det opbevares krypteret og bruges til at polle topoverskrifter for World News-udløsere.';

  @override
  String get gnewsApiKey => 'GNews API nøgle';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Indsæt erstatnings GNews API-nøgle';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Lad nøglen være tom for at beholde den aktuelt gemte nøgle.';

  @override
  String get gnewsApiKeyIsRequired => 'En GNews API-nøgle er påkrævet.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Konfigurationen af ​​World News kunne ikke gemmes.';

  @override
  String get disconnectWorldNews => 'Afbryd forbindelsen til World News';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Dette fjerner den gemte GNews API-nøgle. World News-udløsere stopper med at udløse, indtil du tilføjer en nøgle igen.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Kunne ikke afbryde forbindelsen til World News.';

  @override
  String get systemOneModels => 'SystemOne modeller';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Vælger den bedst tilgængelige SystemOne-model';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Chatmodellen træffer disse beslutninger';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Beslutningsmodeller, der foretager opkaldene bag kulisserne på en brøkdel af et sekund: gruppechat-turtagning og browsertrin. Din chatmodel skriver stadig hvert svar.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'SystemOne-modellen bestemmer, hvornår den skal tale, mens den er tændt; denne model er tilbagefaldet.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 scoret af SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne scorede denne besked direkte. Ingen sprogmodel kørte.';

  @override
  String get systemOneUnavailable => 'SystemOne er ikke tilgængelig';

  @override
  String get systemOneAdminAvailability =>
      'Beslutningsmodeller, agenter kan vælge under Indstillinger › Modeller. En model, der er slukket her, efterlader plukkeren, og agenter, der valgte den, falder tilbage til Auto. Mens enhver model er slukket, er SystemOne-modeller, som udbydere tilføjer senere, også slået fra.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Ingen SystemOne-modeller endnu. Tilføj en TypeSafe- eller OpenRouter-nøgle under Udbydere, eller træk en beslutningsmodel som f.eks. nimble i Ollama 0.35 eller nyere.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Ingen SystemOne-model er tilgængelig endnu. Tilføj en TypeSafe- eller OpenRouter-nøgle under Indstillinger › Modeller › Medbring din egen nøgle, eller træk en beslutningsmodel som f.eks. nimble i Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone system one decision modeller jev typesafe openrouter ollama tilgængelighed aktivere deaktiver';

  @override
  String get chatModels => 'Chat modeller';

  @override
  String get disabled => 'Deaktiveret';

  @override
  String get enableShown => 'Aktiver vist';

  @override
  String get disableShown => 'Deaktiver vist';

  @override
  String get expandAll => 'Udvid alle';

  @override
  String get collapseAll => 'Skjul alle sammen';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 ændringer, der ikke er gemt';
  }

  @override
  String get settingsScopeAllAgents => 'Alle agenter';

  @override
  String get settingsScopeAgent => 'Denne agent';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint =>
      'Det samme overalt, hvor du logger ind';

  @override
  String get settingsScopeAllAgentsHint => 'Deles af alle dine agenter';

  @override
  String get settingsAppliesTo => 'Gælder for';

  @override
  String get settingsSaving => 'Gemmer...';

  @override
  String get settingsSavedAutomatically => 'Ændringer gemmes automatisk';

  @override
  String get settingsSearchHint => 'Søg i alle indstillinger';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Log ind og sikkerhed';

  @override
  String get settingsPageUsage => 'Brug';

  @override
  String get settingsPagePermissions => 'Tilladelser';

  @override
  String get settingsPageComputer => 'Computer & web';

  @override
  String get settingsPageBehavior => 'Adfærd';

  @override
  String get settingsPageSystem => 'System';

  @override
  String get settingsPageProfileDescription =>
      'Dit navn og e-mail, en kopi af dine data og log ud.';

  @override
  String get settingsPageSecurityDescription =>
      'Adgangskode, to-faktor-godkendelse, sikkerhedsnøgler og hvor du er logget ind.';

  @override
  String get settingsPageUsageDescription =>
      'Dine grænser og token-forbrug samlet på ét sted.';

  @override
  String get settingsPageAgentsDescription =>
      'Opret agenter, og vælg, hvilken der svarer som standard.';

  @override
  String get settingsPagePermissionsDescription =>
      'Hvad dine agenter kan gøre uden at spørge dig først.';

  @override
  String get settingsPageComputerDescription =>
      'Den computer, dine agenter arbejder på, og de websteder, de kan læse som dig.';

  @override
  String get settingsPageModelsDescription =>
      'Hvilke modeller denne agent bruger, og de API-nøgler, der betaler for dem.';

  @override
  String get settingsPageBehaviorDescription =>
      'Hvordan denne agent taler, og hvordan den læser en gruppechat.';

  @override
  String get settingsPageVoiceDescription =>
      'Live opkald, diktering og talte svar for denne agent.';

  @override
  String get settingsPageMessagingDescription =>
      'Hvor folk kan nå denne agent, og hvordan den opfører sig i chats.';

  @override
  String get settingsPageGeneralDescription =>
      'Udseende, sprog, tidszone og hvad denne app gør i baggrunden.';

  @override
  String get settingsPageSystemDescription =>
      'Serveren, som dette vindue bruger, den på denne computer og appopdateringer.';

  @override
  String get settingsYourAgents => 'Dine agenter';

  @override
  String get settingsChatModel => 'Chat model';

  @override
  String get settingsChatModelDescription => 'Svarer på dine beskeder.';

  @override
  String get settingsSubAgentModel => 'Sub-agent model';

  @override
  String get settingsSubAgentModelDescription =>
      'Kører arbejde afleveret under en opgave.';

  @override
  String get settingsDefaultModels => 'Standard modeller';

  @override
  String get settingsDefaultModelsDescription =>
      'Bruges, når en chat eller opgave ikke vælger sin egen model.';

  @override
  String get settingsModelPool => 'Model pool';

  @override
  String get settingsApiKeysDescription =>
      'Brug dine egne nøgler eller slutpunkt til denne agent. Nøgler er krypteret og vises aldrig igen.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Finjustering';

  @override
  String get settingsFineTuningDescription =>
      'Sjældent nødvendigt. Standardindstillingerne passer til de fleste chats.';

  @override
  String get settingsShow => 'Vis';

  @override
  String get settingsHide => 'Skjul';

  @override
  String get settingsMinimumContribution => 'Minimum bidragsværdi';

  @override
  String get settingsBatchWindow => 'Rumbatchvindue';

  @override
  String get settingsBatchWindowDescription =>
      'Venter så længe for at behandle hurtige beskeder som én tur.';

  @override
  String get settingsHandsFree => 'Håndfri';

  @override
  String get settingsHandsFreeDescription =>
      'Tal frit og afbryd når som helst.';

  @override
  String get settingsPushToTalkDescription =>
      'Hold for at tale, slip for at sende.';

  @override
  String get settingsLiveVoice => 'Levende stemme';

  @override
  String get settingsChannels => 'Kanaler';

  @override
  String get settingsGroupChats => 'I gruppechat';

  @override
  String get settingsGroupChatsDescription =>
      'Hvordan denne agent opfører sig i grupper på hver kanal.';

  @override
  String get settingsGroupChatsDisabled =>
      'Slå adfærdsmoduler til i Behavior for at ændre disse.';

  @override
  String get settingsParticipationAutomatic => 'Automatisk';

  @override
  String get settingsParticipationMentionOnly => 'Nævn kun';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Læser rummet og er med, når det har noget brugbart at tilføje.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Svar kun når nævnt eller besvaret.';

  @override
  String get settingsParticipationAlwaysDescription => 'Svarer på hver besked.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Opdeler længere svar i korte beskeder, som en person ville.';

  @override
  String get settingsDeliverySingleDescription =>
      'Sender hvert svar som én besked.';

  @override
  String get settingsComputerStatus => 'Status';

  @override
  String get settingsTest => 'Test';

  @override
  String get settingsAppearance => 'Udseende';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Lyst';

  @override
  String get settingsThemeDark => 'Mørkt';

  @override
  String get settingsCloseWindow => 'Når du lukker vinduet';

  @override
  String get settingsCloseAsk => 'Spørg';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent bliver ved med at køre i baggrunden og forbliver tilgængelig.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent stopper helt.';

  @override
  String get settingsPhoneTriggers => 'Telefonudløser';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signaler, som denne telefon sender til dine agenter, så opgaver kan reagere på dem.';

  @override
  String get settingsLocationTriggers => 'Placeringsudløser';

  @override
  String get settingsLocationTriggersDescription =>
      'Tjekker din omtrentlige placering hvert par minutter i forhold til de steder, dine opgaver ser på.';

  @override
  String get settingsNotificationTriggers => 'Notifikationsudløser';

  @override
  String get settingsNotificationTriggersDescription =>
      'Videresender meddelelser fra andre apps på denne telefon til dine agenter.';

  @override
  String get settingsSetup => 'Opsætning';

  @override
  String get settingsOnboarding => 'Onboarding';

  @override
  String get settingsOnboardingDescription =>
      'Gå gennem opsætningen for første kørsel igen. Intet, du konfigurerer, går tabt.';

  @override
  String get settingsUsernameDescription =>
      'Bruges til at logge ind. Det kan ikke ændres.';

  @override
  String get settingsExport => 'Eksporter';

  @override
  String get settingsLeave => 'Log ud og slet';

  @override
  String get settingsSignOutDescription => 'Du logger kun ud på denne enhed.';

  @override
  String get settingsDeleteAccountDescription =>
      'Sletter din konto, agenter, hukommelse og indstillinger. Dette kan ikke fortrydes.';

  @override
  String get settingsTokenUsage => 'Tokenbrug';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Ingen indstilling matcher \"$query\".';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultater',
      one: '$count resultat',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Avancerede modelindstillinger';

  @override
  String get settingsAdvancedModelsDescription =>
      'Valgfrit. Fastgør en model til én slags arbejde; det tager over, når agenten bruger disse værktøjer. Alt, der er tilbage på standard, følger chatmodellen.';

  @override
  String get settingsTaskModelDefault => 'Standard';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Følger chatmodellen';

  @override
  String get settingsTaskModelCoding => 'Kodning';

  @override
  String get settingsTaskModelCodingDescription =>
      'Skrivning, redigering og fejlretning af kode.';

  @override
  String get settingsTaskModelComputerUse => 'Brug af computer';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Kører browseren og skrivebordet.';

  @override
  String get settingsTaskModelAndroidUse => 'Android brug';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Betjening af apps på en Android-enhed eller emulator.';

  @override
  String get settingsTaskModelResearch => 'Forskning';

  @override
  String get settingsTaskModelResearchDescription =>
      'Søge, læse og sammenfatte kilder.';

  @override
  String get knowledgeGraphHint =>
      'Dine mest nævnte enheder, farvet efter klynge. Linjer forbinder enheder, der vises i de samme hukommelser. Tryk på en for at se dens links og minder; træk for at panorere, knibe eller Ctrl/⌘-scroll for at zoome.';

  @override
  String get linkedEntities => 'Tilknyttede enheder';

  @override
  String get noLinkedEntities => 'Ikke knyttet til andre enheder endnu.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 nævner';
  }

  @override
  String get entityKindConcept => 'Koncept';

  @override
  String get entityKindDomain => 'Domæne';

  @override
  String get entityKindEmail => 'E-mail';

  @override
  String get entityKindLink => 'Link';

  @override
  String get entityKindFile => 'Fil';

  @override
  String get entityKindAcronym => 'Akronym';

  @override
  String get entityKindIdentifier => 'Identifikator';

  @override
  String get entityKindVersion => 'version';

  @override
  String get openFullscreen => 'Åbn fuldskærm';

  @override
  String get zoomIn => 'Zoom ind';

  @override
  String get zoomOut => 'Zoom ud';

  @override
  String get searchEntities => 'Find en enhed';

  @override
  String get incomingCall => 'Indgående opkald';

  @override
  String get answerCall => 'Svar';

  @override
  String get callMeLater => 'Ring til mig senere';

  @override
  String get callingEllipsis => 'Ringer...';

  @override
  String get reconnectingCall => 'Genopretter forbindelse';

  @override
  String get agentWorking => 'Arbejder';

  @override
  String get micMuted => 'Slået fra';

  @override
  String get speakerphone => 'Højttaler';

  @override
  String get muteMic => 'Lydløs';

  @override
  String get unmuteMic => 'Slå lyden til';

  @override
  String get releaseToSend => 'Slip for at sende';

  @override
  String get callEnded => 'Opkaldet afsluttet';

  @override
  String get openConversation => 'Åben samtale';

  @override
  String get callBack => 'Ring tilbage';

  @override
  String get letCallsReachYou => 'Lad opkald nå dig';

  @override
  String get callPermissionsIntro =>
      'Dine agenter kan ringe til dig. For at ringe som et telefonopkald, mens NeoAgent er i baggrunden, eller din telefon er låst, har den brug for disse.';

  @override
  String get showOverOtherApps => 'Vis over andre apps';

  @override
  String get showOverOtherAppsDetail =>
      'Får opkaldsskærmen op, uanset hvor du er.';

  @override
  String get fullScreenCalls => 'Fuldskærmsopkald';

  @override
  String get fullScreenCallsDetail => 'Ringer over låseskærmen.';

  @override
  String get unrestrictedBattery => 'Ubegrænset batteri';

  @override
  String get unrestrictedBatteryDetail =>
      'Holder NeoAgent forbundet, så opkald ankommer.';

  @override
  String get permissionAllowed => 'Tilladt';

  @override
  String get triggerSectionCalendar => 'Kalender';

  @override
  String get triggerSectionFiles => 'Filer og dokumenter';

  @override
  String get triggerSectionHome => 'Hjem og medier';

  @override
  String get triggerSectionDevices => 'Enheder og steder';

  @override
  String get triggerSectionTasks => 'Opgaver';

  @override
  String get messagingMemberJoined => 'Medlem tiltrådte';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Kør, når nogen tilmelder sig en Discord-server, Telegram- eller WhatsApp-gruppe, Slack-kanal eller Matrix-rum.';

  @override
  String get messagingMemberLeft => 'Medlem tilbage';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Kør, når nogen forlader en Discord-server, Telegram- eller WhatsApp-gruppe, Slack-kanal eller Matrix-rum.';

  @override
  String get messagingReactionAdded => 'Reaktion tilføjet';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Kør, når en tilladt person reagerer på en besked i en privat chat.';

  @override
  String get messagingPlatformDisconnected => 'Beskeder afbrudt';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Kør, når en beskedforbindelse stopper og har brug for dig, f.eks. efter et logout.';

  @override
  String get googleCalendarEventStarting =>
      'Google Kalender-begivenhed starter';

  @override
  String get googleCalendarEventCreated =>
      'Google Kalender-begivenhed oprettet';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Kør, når en ny begivenhed eller invitation vises.';

  @override
  String get outlookCalendarEventStarting =>
      'Outlook-kalenderbegivenhed starter';

  @override
  String get nextcloudCalendarEventStarting =>
      'Nextcloud Kalender-begivenhed starter';

  @override
  String get runMinutesBeforeEachEvent =>
      'Kør et bestemt antal minutter før hver begivenhed.';

  @override
  String get googleDriveFileAdded => 'Google Drev-fil tilføjet';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Kør, når en fil føjes til Drev eller en mappe i den.';

  @override
  String get googleSheetsRowAdded => 'Google Sheets række tilføjet';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Kør, når nye rækker vises i et ark.';

  @override
  String get onedriveFileAdded => 'OneDrive-fil tilføjet';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Kør, når en fil føjes til en OneDrive-mappe.';

  @override
  String get nextcloudFileAdded => 'Nextcloud-fil tilføjet';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Kør, når en fil føjes til en Nextcloud-mappe.';

  @override
  String get nextcloudShareReceived => 'Nextcloud-fil delt med dig';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Kør, når nogen deler en fil eller mappe med dig.';

  @override
  String get notionItemAdded => 'Begrebsdatabaseelement tilføjet';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Kør, når et element føjes til en Notion-database.';

  @override
  String get notionItemUpdated => 'Begrebsdatabaseelement opdateret';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Kør, når et element i en Notion-database ændres.';

  @override
  String get trelloCardEnteredList => 'Trello-kort tilføjet til listen';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Kør, når et kort oprettes i eller flyttes ind på en liste.';

  @override
  String get figmaCommentAdded => 'Figma kommentar tilføjet';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Kør, når nogen kommenterer en Figma-fil.';

  @override
  String get githubPrOpened => 'GitHub pull-anmodning åbnet';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Kør, når en ny pull-anmodning åbnes i et lager.';

  @override
  String get githubWorkflowRunFailed => 'Kørsel af GitHub-workflow mislykkedes';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Kør, når en GitHub Actions-kørsel mislykkes.';

  @override
  String get githubCommitPushed => 'GitHub commit skubbet';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Kør, når nye commits når en filial.';

  @override
  String get mcpServerFailed => 'MCP-server mislykkedes';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Kør, når en MCP-server, der fungerede, fejler eller skal logges på.';

  @override
  String get homeAssistantStateChanged => 'Home Assistant-tilstand ændret';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Kør, når en enhed ændrer sig, når en tilstand eller krydser en værdi.';

  @override
  String get spotifyTrackChanged => 'Spotify-nummeret er ændret';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Kør, når et andet nummer begynder at spille.';

  @override
  String get neorecallDailySummaryReady => 'NeoRecall dagsoversigt klar';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Kør, når opsummeringen af en dag er endelig.';

  @override
  String get neorecallConversationRecorded => 'NeoRecall samtale optaget';

  @override
  String get runWhenARecordedConversationEnds =>
      'Kør, når en optaget samtale slutter.';

  @override
  String get geofenceTrigger => 'Placering geofence';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Kør, når din telefon ankommer til eller forlader et sted. Har brug for lokationssporing på telefonen.';

  @override
  String get healthMetricRecorded => 'Sundhedsmåling registreret';

  @override
  String get runWhenAHealthReadingArrives =>
      'Kør, når en synkroniseret sundhedsaflæsning ankommer, eventuelt over eller under en værdi.';

  @override
  String get wearableConnectionChanged => 'Bærbar tilsluttet eller afbrudt';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Løb, når din wearable tilsluttes eller afbrydes.';

  @override
  String get taskRunFinished => 'Endnu en opgave færdig';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Kør efter en anden opgave er færdig, lykkes eller mislykkes.';

  @override
  String get appPackageOptional => 'App-pakke (valgfrit)';

  @override
  String get appPackageHelper => 'For eksempel com.whatsapp';

  @override
  String get anyPlatform => 'Enhver platform';

  @override
  String get spaceIdOptional =>
      'Server-, gruppe-, kanal- eller rum-id (valgfrit)';

  @override
  String get spaceIdHelper => 'Empty overvåger hver botten er i.';

  @override
  String get emojiOptional => 'Emoji (valgfrit)';

  @override
  String get chatIdOptional => 'Chat-id (valgfrit)';

  @override
  String get platformOptional => 'Platform (valgfrit)';

  @override
  String get platformOptionalHelper =>
      'For eksempel whatsapp. Tomme ure alle sammen.';

  @override
  String get minutesBefore => 'Minutter før';

  @override
  String get calendarIdOptional => 'Kalender-id (valgfrit)';

  @override
  String get calendarIdHelper => 'Empty bruger din primære kalender.';

  @override
  String get invitesOnly => 'Kun invitationer fra andre';

  @override
  String get nextcloudCalendarPath => 'Kalender';

  @override
  String get nextcloudCalendarPathHelper =>
      'Dens navn på Nextcloud-kalenderlisten, for eksempel personlig';

  @override
  String get folderIdOptionalHelperDrive => 'Tom overvåger hele Drive.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Empty overvåger rodmappen.';

  @override
  String get driveFolderIdOptional => 'Mappe-id (valgfrit)';

  @override
  String get spreadsheetId => 'Regneark-id';

  @override
  String get sheetRange => 'Rækkevidde';

  @override
  String get sheetRangeHelper => 'Tabellens kolonner, for eksempel Ark1!A:E';

  @override
  String get folderPathOptional => 'Mappesti (valgfrit)';

  @override
  String get folderPathHelper => 'For eksempel dokumenter';

  @override
  String get notionDatabaseId => 'Database-id';

  @override
  String get trelloListId => 'Liste-id';

  @override
  String get figmaFileKey => 'Fil nøgle';

  @override
  String get figmaFileKeyHelper => 'Fra fillinket: figma.com/file/<key>/...';

  @override
  String get githubRepository => 'Depot';

  @override
  String get workflowOptional => 'Workflow (valgfrit)';

  @override
  String get workflowHelper => 'Filnavn såsom ci.yml';

  @override
  String get branchOptional => 'Filial (valgfrit)';

  @override
  String get branchHelper => 'Tom bruger standardgrenen.';

  @override
  String get mcpServerIdOptional => 'MCP-server-id (valgfrit)';

  @override
  String get entityId => 'Enheds-id';

  @override
  String get entityIdHelper => 'For eksempel binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Måltilstand (valgfrit)';

  @override
  String get targetStateHelper => 'For eksempel på';

  @override
  String get aboveOptional => 'Ovenfor (valgfrit)';

  @override
  String get belowOptional => 'Nedenfor (valgfrit)';

  @override
  String get placeName => 'Stednavn';

  @override
  String get latitude => 'Breddegrad';

  @override
  String get longitude => 'Længdegrad';

  @override
  String get radiusMeters => 'Radius i meter';

  @override
  String get geofenceTransition => 'Hvornår';

  @override
  String get arriving => 'Ankommer';

  @override
  String get leaving => 'Forlader';

  @override
  String get healthMetric => 'Sundhedsmetrik';

  @override
  String get healthMetricHelper => 'For eksempel hjertefrekvens, skridt, vægt';

  @override
  String get wearableTransition => 'Når den bærbare';

  @override
  String get wearableConnects => 'Forbinder';

  @override
  String get wearableDisconnects => 'Afbryder forbindelsen';

  @override
  String get sourceTask => 'Efter opgave';

  @override
  String get taskOutcome => 'Udfald';

  @override
  String get anyOutcome => 'Ethvert resultat';

  @override
  String get succeeded => 'Det lykkedes';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 mangler eller er ikke gyldig.';
  }

  @override
  String get triggerSectionMessaging => 'Beskeder';

  @override
  String get triggerSectionDeveloper => 'Udvikler';

  @override
  String get triggerSectionMemory => 'Hukommelse';

  @override
  String get triggerSectionNews => 'Nyheder';

  @override
  String get triggerSectionSystem => 'System';

  @override
  String get searchTriggersHint => 'Søg i triggere, apps eller hændelser';

  @override
  String get noTriggersMatch => 'Ingen trigger matcher din søgning.';

  @override
  String get triggerAccountMissing => 'Ingen konto endnu';

  @override
  String get pickTriggerKeyboardHint => 'Enter vælger det første resultat';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 udløsere';
  }

  @override
  String get addFromSkillsSh => 'Tilføj fra skills.sh';

  @override
  String get skillsShHint =>
      'Søg ovenfor for at finde færdigheder på skills.sh, eller indsæt et skills.sh-link eller en `npx skills add`-kommando.';

  @override
  String get noSkillsShMatches =>
      'Ingen skills.sh-færdigheder matcher denne søgning.';

  @override
  String get installingSkill => 'Installerer...';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Installeret $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 installerer';
  }

  @override
  String get authVerify => 'Bekræft';

  @override
  String get authCreateAccount => 'Opret konto';

  @override
  String get authNewInviteLink => 'Nyt invitationslink';

  @override
  String get authShowPassword => 'Vis adgangskode';

  @override
  String get authHidePassword => 'Skjul adgangskode';

  @override
  String get authPasswordWillBeRejected => 'for svag, vil blive afvist';

  @override
  String get authUsernameTooShort => 'Brugernavne skal have mindst 3 tegn.';

  @override
  String get authUsernameTaken => 'Det brugernavn er allerede taget.';

  @override
  String get authSignupsClosed =>
      'Tilmeldinger er lukket på denne server. Bed administratoren om en konto.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Denne server accepterer kun log-ins over HTTPS. Åbn $arg1 i stedet.';
  }

  @override
  String get authInsecureTransport =>
      'Denne server accepterer kun log-ins over HTTPS. Opret forbindelse til den med en https://-adresse.';

  @override
  String get authAccountNotFound => 'Den konto eksisterer ikke længere.';

  @override
  String get authQrRateLimited =>
      'For mange QR-loginanmodninger. Vent et øjeblik, og opdater derefter koden.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Har du glemt din adgangskode? Bed din serveradministrator om at nulstille den i Admin → Brugere.';

  @override
  String get authChangeServer => 'Skift server';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Log ind på $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Denne adresse svarer ikke som en NeoAgent-server. Tjek URL\'en, og prøv igen.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Kunne ikke åbne en sikker (HTTPS) forbindelse til $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Kunne ikke nå $arg1 over HTTPS, og almindelig HTTP svarede heller ikke. Tjek adresse og port.';
  }

  @override
  String get adminResetPassword => 'Nulstil adgangskode';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Nulstil adgangskoden til $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Vælg en ny adgangskode til $arg1. De vil blive logget ud på hver enhed og logge ind igen med denne adgangskode.';
  }

  @override
  String get adminNewPassword => 'Ny adgangskode';

  @override
  String get adminSetPassword => 'Indstil adgangskode';

  @override
  String get authMissingFields => 'Udfyld alle obligatoriske felter.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 nulstil adgangskoden til $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Adgangskode opdateret; brugeren blev logget ud overalt.';

  @override
  String get authSignInTitle => 'Log ind på NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Scan med din telefon, eller brug din adgangskode.';

  @override
  String get authOrUsePassword => 'eller brug din adgangskode';

  @override
  String get qrLoginWaitingTitle => 'Godkend på din telefon';

  @override
  String get qrLoginWaitingBody =>
      'Din telefon scannede koden. Bekræft login der for at afslutte login.';

  @override
  String get qrLoginSigningInOn => 'Log ind på';

  @override
  String get qrLoginLocation => 'Beliggenhed';

  @override
  String get qrLoginWaitingForApproval => 'Venter på godkendelse';

  @override
  String get qrLoginCancelAndUsePassword => 'Annuller og brug en adgangskode';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Login blev afvist på din telefon. Scan den nye kode for at prøve igen.';

  @override
  String get signupKey => 'Tilmeldingsnøgle';

  @override
  String get signupKeyStepSubtitle =>
      'Nye konti på denne server kræver en tilmeldingsnøgle. Indtast den, du har fået af en administrator.';

  @override
  String get signupKeyChange => 'Skift';

  @override
  String get signupKeyRequiredError => 'Indtast din tilmeldingsnøgle.';

  @override
  String get signupKeyInvalidError =>
      'Tilmeldingsnøglen er ugyldig. Kontrollér den, og prøv igen.';

  @override
  String get signupKeyUsedError =>
      'Tilmeldingsnøglen er allerede brugt. Bed en administrator om en ny.';

  @override
  String get adminRequireSignupKey => 'Kræv en tilmeldingsnøgle';

  @override
  String get adminRequireSignupKeyHint =>
      'Nye konti kræver en engangsnøgle fra en administrator. Når den er slået fra, kan alle, der kan nå denne server, oprette en konto. Den første konto kræver aldrig en nøgle.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Nye konti kræver nu en tilmeldingsnøgle.';

  @override
  String get adminSignupOpenNotice => 'Alle kan nu oprette en konto.';

  @override
  String get signupKeys => 'Tilmeldingsnøgler';

  @override
  String get signupKeysDescription =>
      'Engangsnøgler til tilmelding, mens der kræves en nøgle. Hver nøgle opretter præcis én konto.';

  @override
  String get signupKeysNew => 'Nye nøgler';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Ubrugte · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Brugte · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Tilbagekaldte · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Alle · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Ubrugt';

  @override
  String get signupKeyStatusUsed => 'Brugt';

  @override
  String get signupKeyStatusRevoked => 'Tilbagekaldt';

  @override
  String get signupKeysExport => 'Eksportér .txt';

  @override
  String get signupKeysCopied => 'Nøgler kopieret';

  @override
  String get signupKeyCopied => 'Nøgle kopieret';

  @override
  String get signupKeysEmpty => 'Ingen nøgler på denne liste.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Oprettet $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Brugt af $arg1 den $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Brugt den $arg1 af en konto, der siden er slettet';
  }

  @override
  String get signupKeyRevokeTitle => 'Tilbagekald denne nøgle?';

  @override
  String get signupKeyRevokeMessage =>
      'Ingen vil kunne oprette en konto med den. Dette kan ikke fortrydes.';

  @override
  String get signupKeyRevoked => 'Nøgle tilbagekaldt.';

  @override
  String signupKeysShowMore(int count) {
    return 'Vis $count mere';
  }

  @override
  String get signupKeysCreateTitle => 'Opret tilmeldingsnøgler';

  @override
  String get signupKeysCount => 'Antal nøgler';

  @override
  String get signupKeysCountHelper => '1 til 500';

  @override
  String get signupKeysCountInvalid => 'Indtast et tal fra 1 til 500.';

  @override
  String get signupKeysLabel => 'Etiket (valgfri)';

  @override
  String get signupKeysLabelHint => 'f.eks. Betatestere forår';

  @override
  String signupKeysCreateAction(int count) {
    return 'Opret ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Nøgler klar: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Giv hver nøgle til én person. Ubrugte nøgler bliver på listen, så du kan kopiere eller eksportere dem igen senere.';

  @override
  String get signupKeysSaveDialogTitle => 'Gem tilmeldingsnøgler';

  @override
  String get signupKeysExported => 'Nøgler eksporteret.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor oprettede tilmeldingsnøgler ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor tilbagekaldte en tilmeldingsnøgle';
  }

  @override
  String get providerChooseUsername => 'Vælg dit brugernavn';

  @override
  String get providerChooseUsernameBody =>
      'Vælg et ledigt brugernavn for at færdiggøre din konto.';

  @override
  String get dataSharingTitle => 'Del brugsdata';

  @override
  String get dataSharingDescription =>
      'Hjælp dem, der driver denne server, med at forbedre den. Deler, hvordan du bruger NeoAgent, aldrig hvad du skriver eller gemmer.';

  @override
  String dataSharingSince(String date) {
    return 'Deler siden $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Hvad der deles';

  @override
  String get dataSharingIncluded => 'Deles';

  @override
  String get dataSharingExcluded => 'Deles aldrig';

  @override
  String get dataSharingIncludedDevice => 'Enhedstype og appversion';

  @override
  String get dataSharingIncludedLocale =>
      'Appsprog og tidszoneregion, fx Europa';

  @override
  String get dataSharingIncludedFeatures =>
      'Hvilke funktioner du har sat op, fx opgaver, skills og integrationer';

  @override
  String get dataSharingIncludedRuns =>
      'Hvilke værktøjer og modeller dine kørsler bruger, med varighed og antal tokens';

  @override
  String get dataSharingIncludedActivity =>
      'Hvornår du bruger NeoAgent, efter ugedag og time';

  @override
  String get dataSharingExcludedContent => 'Beskeder, prompts og svar';

  @override
  String get dataSharingExcludedRuns =>
      'Titler på kørsler, værktøjsinput og -resultater';

  @override
  String get dataSharingExcludedFiles =>
      'Filer, minder og alt andet, du gemmer';

  @override
  String get dataSharingExcludedIdentity =>
      'Dit navn, din e-mail, IP-adresse og placering';

  @override
  String get dataSharingExcludedAccounts =>
      'De konti, du forbinder integrationer med';

  @override
  String get dataSharingPooledNote =>
      'Administratorer ser kun totaler på tværs af alle, der deler, aldrig dig alene. Slå det fra når som helst, så falder du straks ud af totalerne.';

  @override
  String get dataSharingConfirmTitle => 'Del brugsdata?';

  @override
  String get dataSharingConfirmAction => 'Del';

  @override
  String get sharedUsageTitle => 'Delt brug';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Konti der deler brugsdata: $sharing af $total. Kun totaler, intet indhold.';
  }

  @override
  String get sharedUsageEmpty =>
      'Ingen deler brugsdata endnu. Det kan slås til under Indstillinger, Profil, Dine data.';

  @override
  String get sharedUsageRuns => 'Delte kørsler';

  @override
  String get sharedUsageAvgDuration => 'Gns. varighed';

  @override
  String get sharedUsageCompletedRuns => 'Fuldførte kørsler';

  @override
  String get sharedUsageStepsPerRun => 'Trin pr. kørsel';

  @override
  String get sharedUsageDevices => 'Enheder';

  @override
  String get sharedUsageAppVersions => 'Appversioner';

  @override
  String get sharedUsageLanguages => 'Sprog';

  @override
  String get sharedUsageRegions => 'Regioner';

  @override
  String get sharedUsageFeatures => 'Brug af funktioner';

  @override
  String get sharedUsageFeaturesDescription =>
      'Andel af de delende konti, der har sat det op.';

  @override
  String get sharedUsageTools => 'Værktøjer';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Mest kaldte værktøjer ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Kald: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Fejlet: $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Integrationer';

  @override
  String get sharedUsageMessaging => 'Beskedkanaler';

  @override
  String get sharedUsageTriggers => 'Hvordan kørsler starter';

  @override
  String get sharedUsageActivity => 'Hvornår det bruges';

  @override
  String get sharedUsageActivityDescription =>
      'Kørsler efter ugedag og time, UTC.';

  @override
  String get sharedUsageModels => 'Modelydelse';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'gns. $latency · $cached % cachet · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Konti: $count';
  }

  @override
  String get sharedUsageNoData => 'Intet i denne periode.';

  @override
  String get sharedUsageNotReported => 'Ikke indberettet endnu';

  @override
  String get sharedUsageFeatureAgents => 'Mere end én agent';

  @override
  String get sharedUsageFeatureTasks => 'Planlagte opgaver';

  @override
  String get sharedUsageFeatureSkills => 'Skills';

  @override
  String get sharedUsageFeatureMcp => 'MCP-servere';

  @override
  String get sharedUsageFeatureIntegrations => 'Integrationer';

  @override
  String get sharedUsageFeatureMessaging => 'Beskedkanaler';

  @override
  String get sharedUsageFeatureMemory => 'Hukommelse';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in datadeling telemetri enheder funktioner værktøjer modeller aktivitet';
}
