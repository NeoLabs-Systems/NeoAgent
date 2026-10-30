// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Maltese (`mt`).
class AppL10nMt extends AppL10n {
  AppL10nMt([String locale = 'mt']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Merħba';

  @override
  String get onboardingEyebrowCommunication => 'Komunikazzjoni';

  @override
  String get onboardingEyebrowIntelligence => 'Intelliġenza';

  @override
  String get onboardingEyebrowComputer => 'Kompjuter';

  @override
  String get onboardingEyebrowAutomation => 'Awtomazzjoni';

  @override
  String get onboardingNext => 'Li jmiss';

  @override
  String get onboardingIntroCouldNotLoad => 'L-intro ma setgħetx titgħabba.';

  @override
  String get onboardingModelDescription =>
      'Agħżel il-mudell li NeoAgent għandu juża awtomatikament, jew ħallih jagħżel awtomatikament.';

  @override
  String get onboardingLoadingModels => 'Tagħbija mudelli...';

  @override
  String get noAiModelTitle => 'L-ebda mudell AI għadu mwaqqaf';

  @override
  String get noAiModelBody =>
      'Żid ċavetta API minn fornitur bħal OpenAI, Anthropic jew Google. NeoAgent imbagħad juri l-mudelli li tista\' tuża.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent jeħtieġ mudell AI biex iwieġeb. Żid ċavetta API minn fornitur bħal OpenAI, Anthropic jew Google.';

  @override
  String get noAiModelAdminHint =>
      'Bħala amministratur tista\' wkoll twaqqaf fornituri għal kulħadd taħt Admin → Fornituri.';

  @override
  String get addApiKey => 'Żid API key';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform huwa konness.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Nistennew li $platform jgħaqqad...';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Is-setup ma setgħetx tiġi ssejvjata: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Lest';

  @override
  String get onboardingStepRequired => 'Meħtieġa';

  @override
  String get onboardingStepOptional => 'Fakultattiv';

  @override
  String get onboardingStepCloudOrLocal => 'Cloud jew lokali';

  @override
  String get onboardingStepComputer => 'Kompjuter';

  @override
  String get onboardingStepRoutines => 'Rutini';

  @override
  String get onboardingComputerChoiceTitle => 'Fejn għandha\ntaħdem?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Tista\' taqleb għal kull sessjoni.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Sandbox privata · dejjem mixgħula';

  @override
  String get onboardingThisComputer => 'Dan il-kompjuter';

  @override
  String get onboardingThisComputerSubtitle => 'Fajls, apps u browser tiegħek';

  @override
  String get onboardingSearchApps => 'Fittex apps...';

  @override
  String get onboardingRoutinesDescription =>
      'Ir-riżultati jaslu fiċ-chats tiegħek.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Ir-riżultati jaslu bħala notifiki.';

  @override
  String get onboardingNotifications => 'Notifiki';

  @override
  String get onboardingReadyTitle => 'Kollox\nlest.';

  @override
  String get onboardingReadyDescription => 'Ibgħat l-ewwel messaġġ tiegħek.';

  @override
  String get onboardingMessageNeoagent => 'Messaġġ NeoAgent';

  @override
  String get onboardingAskAnything => 'Staqsi xi ħaġa...';

  @override
  String get onboardingOpenNeoagent => 'Iftaħ NeoAgent';

  @override
  String get onboardingStarterTrip => 'Ippjana vjaġġ ta’ tmiem il-ġimgħa';

  @override
  String get onboardingStarterLanding => 'Ibni landing page';

  @override
  String onboardingQuickSteps(int count) {
    return '$count passi ta\' malajr';
  }

  @override
  String get taskNeedsEmail => 'Qabbad l-email l-ewwel';

  @override
  String get taskNeedsCalendar => 'Qabbad kalendarju l-ewwel';

  @override
  String get taskNeedsModel => 'L-ewwel waqqaf mudell AI';

  @override
  String get taskPromptDailyRecap =>
      'Iġbor il-ġurnata tiegħi: agħmel fil-qosor il-konversazzjonijiet, ix-xogħol lest u d-deċiżjonijiet mil-lum, imbagħad elenka kull ħaġa li għandi nsegwi għada. Żommha qasira u ibgħatha lili.';

  @override
  String get taskPromptInboxCheck =>
      'Iċċekkja l-inbox tal-email tiegħi għal messaġġi li waslu mill-aħħar kontroll. Ibgħatli biss messaġġi dwar emails li huma urġenti jew li jeħtieġu tweġiba, b\'sommarju ta\' linja waħda kull wieħed. Jekk xejn ma jeħtieġ l-attenzjoni tiegħi, ibgħat xejn.';

  @override
  String get taskPromptMorningBriefing =>
      'Ipprepara l-briefing ta’ filgħodu tiegħi: it-temp tal-lum fejn inkun, l-avvenimenti fil-kalendarju tiegħi, u l-aktar oġġetti miftuħa importanti li naf dwarhom. Ibgħatha bħala messaġġ qasir u scannable.';

  @override
  String get taskPromptTomorrowPrep =>
      'Ħares lejn il-kalendarju tiegħi għal għada. Għal kull laqgħa, għidli x\'inhi, min hu involut u kull ħaġa li għandi nħejji. Jekk għada tkun vojta, ibgħat xejn.';

  @override
  String get taskPromptNewsDigest =>
      'Fittex fuq il-web l-aktar aħbarijiet importanti tal-lum dwar is-suġġetti li jimpurtahom (uża dak li tiftakar dwar l-interessi tiegħi). Ibgħatli diġest ta\' mhux aktar minn ħames oġġetti b\'sentenza waħda kull wieħed u link.';

  @override
  String get taskPromptWeeklyReview =>
      'Irrevedi l-ġimgħa tiegħi: dak li sar, dak li żelaq u dak li għadu miftuħ. Issuġġerixxi l-aktar tliet affarijiet importanti biex tiffoka fuqhom il-ġimgħa d-dieħla.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Link numru tat-telefon li jappartjeni lill-aġent. Kull persuna li tippermetti tista\' tiċċettja magħha, f\'chats u gruppi diretti.';

  @override
  String get whatsappSelfChatDescription =>
      'Link in-numru tiegħek stess u kellem lill-aġent fiċ-chat tiegħek \"Messaġġ lilek innifsek\". Kull chat u grupp ieħor fuq dan il-kont jiġu injorati.';

  @override
  String get chatSendHintMac => '⌘↵ biex tibgħat';

  @override
  String get chatSendHintOther => 'Ctrl+Enter biex tibgħat';

  @override
  String get aBaseUrlIsRequiredFor =>
      'URL bażi huwa meħtieġ għal dan l-endpoint.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Indirizz elettroniku mibdul jiġi kkonfermat qabel ma jintuża.';

  @override
  String get aDecisionHigherUpTheChain => 'Deċiżjoni ogħla fil-katina tirbaħ.';

  @override
  String get aDeletedAccount => 'kont imħassra';

  @override
  String get aFridayLookBackAtThe =>
      'Ħarsa tal-Ġimgħa lura lejn il-ġimgħa u pjan għall-oħra.';

  @override
  String get aKeyThatAsksForA =>
      'Ċavetta li titlob PIN jew marki tas-swaba\' wkoll tissostitwixxi l-kodiċi b\'żewġ fatturi tiegħek.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Mudell tal-lingwa ġġudikat dan il-messaġġ minħabba li SystemOne hija mitfija.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Fajl ta\' metadejta ta\' setup ta\' NeoAgent qabeż il-limitu ta\' daqs sikur tiegħu.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Web build aktar ġdid huwa disponibbli fuq is-server. Reload biex iġġib l-aħħar pakkett.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Desktop privat bi Chromium, fajls, editur tat-test, terminali u Python. Ix-xogħol tiegħek jibqa\' salvat bejn is-sessjonijiet.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Kompjuter Linux privat jew apparat Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Fajl tas-setup NeoAgent meħtieġ ma setax jitniżżel.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Sieħeb tat-tim jibgħatlek link tal-istedina. Ladarba inti taċċettaha, huma ';

  @override
  String get aTeammateSentYouAnInvite =>
      'sieħeb tat-tim bgħatlek link ta’ stedina, daħħalha hawn biex tingħaqad mat-tim tagħhom.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Tniżżil temporanju se jitnaddaf aktar tard.';

  @override
  String get aValueIsStored => 'Valur huwa maħżun.';

  @override
  String get access => 'Aċċess';

  @override
  String get accessActivity => 'Attività ta\' aċċess';

  @override
  String accessArg1(Object? arg1) {
    return 'Aċċess: $arg1';
  }

  @override
  String get accessMode => 'Mod ta\' aċċess';

  @override
  String get accessPermissions => 'Permessi ta\' aċċess';

  @override
  String get accessToken => 'token ta\' aċċess';

  @override
  String get accessToken2 => 'Token ta\' aċċess';

  @override
  String get account => 'Kont';

  @override
  String accountArg1(Object? arg1) {
    return 'Kont #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Twissijiet ta\' bidla fil-kont';

  @override
  String get accountEmail => 'Email tal-kont';

  @override
  String get accountEmailIsOffUntilThese =>
      'L-email tal-kont hija mitfija sakemm dawn jiġu ssettjati: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent juża din il-lingwa kullimkien fl-app. L-ewwel darba li tidħol, issegwi dan l-apparat. Wara dan, l-għażla tiġi ffrankata fuq il-kont tiegħek u tintuża fuq kull apparat.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Ma setgħetx tibdel il-lingwa: $error';
  }

  @override
  String get accountLanguageTitle => 'Lingwa';

  @override
  String get accountNumber => 'Numru tal-kont';

  @override
  String get accountSettings => 'Issettjar tal-kont';

  @override
  String get accounts => 'Kontijiet';

  @override
  String get accountsByTokensUsedAllTime =>
      'Kontijiet bit-tokens użati, il-ħin kollu.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'kompjuters cloud tal-kontijiet. Il-bidliet japplikaw wara server ';

  @override
  String get accountsOnThisServer => 'Kontijiet fuq dan is-server';

  @override
  String get active => 'Attiva';

  @override
  String get activeSessions => 'Sessjonijiet attivi';

  @override
  String get activeToday => 'Attiv illum';

  @override
  String get add => 'Żid';

  @override
  String get addAProviderCredentialFirstIts =>
      'Żid kredenzjali tal-fornitur l-ewwel. Il-mudelli tagħha jidhru hawn darba ';

  @override
  String get addAgent => 'Żid Aġent';

  @override
  String get addAnotherSignInMethodBefore =>
      'Żid metodu ieħor ta\' dħul qabel ma tneħħi dan.';

  @override
  String get addBinding => 'Żid l-irbit';

  @override
  String get addByNameOrId => 'Żid bl-isem jew l-ID';

  @override
  String get addByNameOrIdInstead => 'Żid bl-isem jew bl-ID minflok';

  @override
  String get addCredentialBinding => 'Żid l-irbit tal-kredenzjali';

  @override
  String get addEntry => 'Żid Dħul';

  @override
  String get addKey => 'Żid ċavetta';

  @override
  String get addMcpServer => 'Żid server MCP';

  @override
  String get addMemory => 'Żid Memorja';

  @override
  String get memoryReview => 'Irrevedi';

  @override
  String get memoryReviewPrompt =>
      'Irrevedi l-memorji kollha tiegħi u naddafhom: arkivja d-duplikati, il-fatti skaduti u kull ħaġa mingħajr valur dejjiemi. Imbagħad għidli fil-qosor x\'biddilt.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Żid aktar tul jew tip ta \'karattru ieħor.';

  @override
  String get addPeopleOrGroups => 'Żid nies jew gruppi';

  @override
  String get addSecurityKey => 'Żid iċ-ċavetta tas-sigurtà';

  @override
  String get addSomeoneOrAGroup => 'Żid xi ħadd jew grupp';

  @override
  String get addTask => 'Żid il-Kompitu';

  @override
  String get addTests => 'Żid it-testijiet';

  @override
  String get addTestsForThePartsOf =>
      'Żid testijiet għall-partijiet ta \'dan il-proġett li għandhom l-inqas kopertura, imbagħad mexxihom.';

  @override
  String get addTheirOwnKeysInSettings =>
      'żid iċ-ċwievet tagħhom stess fis-Settings.';

  @override
  String get addToPrompt => 'Żid mal-pront';

  @override
  String get added => 'Miżjud';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Miżjud $arg1 · $arg2 użat l-aħħar';
  }

  @override
  String get addressWithTheProvider => 'indirizz mal-fornitur.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Aġġusta l-volum tal-kelliem, irrevedi d-defaults tal-buttuna tal-hardware, u mmaniġġja din is-sessjoni tal-lanċjar.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Aġġusta t-tfittxija jew il-filtru tal-istatus biex tara aktar kanali tal-messaġġi.';

  @override
  String get adjustTheSpeakerVolumeHere => 'Aġġusta l-volum tal-kelliem hawn.';

  @override
  String get admin => 'Amministratur';

  @override
  String adminArg1(Object? arg1) {
    return 'Amministratur › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'L-għotjiet tal-amministrazzjoni, il-links tal-istedina u l-bidliet fil-ġestjoni jidhru hawn.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Skeda manwali avvanzata għal każijiet speċjali.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Avvanzat: minuta siegħa jum xahar jum tal-ġimgħa.';

  @override
  String get againRightAway => 'mill-ġdid mill-ewwel.';

  @override
  String get agent => 'Aġent';

  @override
  String agentArg1(Object? arg1) {
    return 'Aġent: $arg1';
  }

  @override
  String get agentCalls => 'Sejħiet ta\' Aġent';

  @override
  String get agentCommunication => 'Komunikazzjoni tal-aġent';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Komunikazzjoni tal-aġent: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Il-mod aġent teditja l-ispazju tax-xogħol · ⌘↵ ibgħat · ⌘N sessjoni ġdida';

  @override
  String get agentPausesAndAsksYouBefore =>
      'L-aġent jieqaf u jitlob il-permess tiegħek qabel ma jwettaq il-kompitu.';

  @override
  String get agentProfile => 'Profil tal-aġent';

  @override
  String get agentVisibleName => 'Isem viżibbli għall-aġent';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'L-aġent irid juża $arg1. Tektek biex tiddeċiedi.';
  }

  @override
  String get agents => 'Aġenti';

  @override
  String get aiAnswerUnreadable => 'It-tweġiba tal-AI ma tistax tinqara';

  @override
  String get aiProviderKeys => 'Ċwievet tal-fornitur AI';

  @override
  String get aiUnavailable => 'AI mhux disponibbli';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'twissijiet u email kont ieħor minn.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Twissijiet meta konnessjoni tal-messaġġi teħtieġ l-attenzjoni tal-utent';

  @override
  String get all => 'Kollha';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'L-aġenti kollha ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Kollha $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'L-islots kollha tal-cloud-computer bħalissa qed jintużaw. Erġa\' pprova fi ftit mument.';

  @override
  String get allComputerSlotsAreBusy =>
      'Is-slots tal-kompjuter kollha huma okkupati';

  @override
  String get allTables => 'It-tabelli kollha';

  @override
  String get allTime => 'Il-ħin kollu';

  @override
  String get allToolsAreAllowedTheAgent =>
      'L-għodda kollha huma permessi - l-aġent jista \'juża kwalunkwe kapaċità mingħajr ma jistaqsi. ';

  @override
  String get allow => 'Ħalli';

  @override
  String get allowedRunsWithoutAsking => 'Permess. Jiġri mingħajr ma jistaqsi.';

  @override
  String get allowAll => 'Ħalli kollox';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Ħalli \"Installa apps mhux magħrufa\" għal NeoAgent, imbagħad erġa\' pprova l-aġġornament.';

  @override
  String get allowOnce => 'Ħalli darba';

  @override
  String get allowSender => 'Ħalli min jibgħat';

  @override
  String get allowSession => 'Ħalli sessjoni';

  @override
  String get allowTheAgentToStartAn =>
      'Ħalli l-aġent jibda sejħa bil-vuċi fl-app miegħek.';

  @override
  String get allowedOrigins => 'Oriġini permessi';

  @override
  String get allowedPathPrefix => 'Prefiss tal-mogħdija permess';

  @override
  String get allowsYouCanChangeThatPer =>
      'jippermetti. Tista\' tbiddel dan għal kull persuna aktar tard. Links qatt ma jagħtu ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'diġà jappartjeni għal kont eżistenti';

  @override
  String get alreadyLinkedToAnotherAccount => 'diġà marbuta ma\' kont ieħor';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'diġà marbuta ma\' kont neoaġent ieħor';

  @override
  String get alreadyUsed => 'diġà użata';

  @override
  String get always => 'Dejjem';

  @override
  String get alwaysAllow => 'Dejjem ħalli';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '\"Dejjem ħalli\" ssalva l-politika b\'mod permanenti — tista\' tibdelha f\'Settings.';

  @override
  String get alwaysAsk => 'Dejjem staqsi';

  @override
  String get alwaysEngage => 'Dejjem ingaġġa';

  @override
  String get alwaysJoins => 'Dejjem jingħaqad';

  @override
  String get anApiKeyIsRequired => 'Hija meħtieġa ċavetta API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Sommarju filgħaxija ta’ dak li ġara u x’għandu jsir segwitu.';

  @override
  String get anHttpOrHttpsUrlIs => 'URL http jew https hija meħtieġa.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'u analitika. Il-links tat-tim live fuq il-paġna tat-Tim.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'L-installazzjoni ta\' Android APK mhix disponibbli fuq din il-pjattaforma.';

  @override
  String get androidApp => 'App Android';

  @override
  String get androidControl => 'Kontroll Android';

  @override
  String get androidCouldNotStart => 'Android ma setax jibda';

  @override
  String get androidNotificationReceived => 'Notifika Android Riċevuta';

  @override
  String get androidOnly => 'Android biss';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'L-installatur tal-pakkett Android ma setax jinfetaħ.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Skrin tal-Android — tektek biex tmiss, drag biex tiskja';

  @override
  String get androidSdk => 'Android SDK';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Tweġibiet @jsemmi dwar kwistjonijiet u talbiet għall-ġibda';

  @override
  String get anyone => 'Kulħadd';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Kulħadd fuq din il-pjattaforma jista’ jmessaġġa lil $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Kulħadd fuq din il-pjattaforma jista \'messaġġ $arg1 f\'$arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Kull min jista\' jilħaq dan il-kont jista\' jkellem lil $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Kull min għandu l-link jista\' jingħaqad sakemm tiskadi jew int tirrevokaha.';

  @override
  String get apiHttpsOrigin => 'Oriġini HTTPS tal-API';

  @override
  String get apiKey => 'Ċavetta API';

  @override
  String get apiKey2 => 'ċavetta api';

  @override
  String get apiKey3 => 'Ċavetta API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api key anthropic claude openai gpt xai grok google gemini minimax nvidia nim openrouter kredenzjali';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Ċwievet u endpoints tal-API għall-fornituri tal-IA, it-tfittxija u l-vuċi. Huma ';

  @override
  String get apiRequest => 'Talba API';

  @override
  String get apiYourOwnServerASelf =>
      'API -- is-server tiegħek, mudell self-hosted, jew ieħor ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'It-tniżżil tal-APK falla b\'HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'L-isem tal-app huwa meħtieġ.';

  @override
  String get appUpdates => 'Aġġornamenti tal-App';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'L-aġġornamenti tal-app mhumiex konfigurati għal din il-bini.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Applied $arg1 kju aġġornamenti tal-istering għall-ġirja attwali.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Aġġornament(i) tal-istering $arg1 applikat.';
  }

  @override
  String get apply => 'Applika';

  @override
  String get applyBehaviorNotes => 'Applika noti tal-imġieba';

  @override
  String get applyCoreMemory => 'Applika memorja tal-qalba';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Talbiet ta\' approvazzjoni għal għodda ta\' aġenti sensittivi';

  @override
  String get approvalRequired => 'Approvazzjoni meħtieġa';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'L-approvazzjoni tibqa’ ġewwa s-sessjoni mobbli awtentikata tiegħek, u kull kodiċi jiskadi awtomatikament wara tieqa qasira.';

  @override
  String get approveLogin => 'Approva l-login';

  @override
  String get approveQrLogin => 'Approva login QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Approva dan biss jekk bdejt il-login fuq dak l-apparat biss issa.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Login approvat għal $arg1.';
  }

  @override
  String get approvedOnly => 'Approvat biss';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Tqabbil approvat għal $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Nies u gruppi approvati';

  @override
  String get approvedPeopleOnly => 'Nies approvati biss';

  @override
  String get archive => 'Arkivju';

  @override
  String get archiveAgent => 'Aġent tal-arkivju?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Arkivju ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Arkivju $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Memorji magħżula fl-arkivju?';

  @override
  String get areSharedByEveryAccountOn =>
      'huma kondiviżi minn kull kont fuq dan is-server; kontijiet xorta jistgħu ';

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
    return 'Aċċess $arg1 meħtieġ';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'kontijiet $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 attiv';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 miżjud. Editjaha kwalunkwe ħin biex tibdel il- ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '“$arg1” u l-istorja tal-ġirja tiegħu se jitħassru b\'mod permanenti. Kwalunkwe ġirja attiva titwaqqaf. Fajls fl-ispazju tax-xogħol ma jintmissux.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'approvazzjoni $arg1 meħtieġa';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 apps attivi';
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
    return '$arg1 (għodod attivi $arg2)';
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
    return '$arg1 $arg2 fi $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 mibdula';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 chars';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Maħluq $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [uri lokali: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 li taqbel “$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent Spazju tax-Xogħol';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 kontijiet ġodda';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 jiġri · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · Kampjuni $arg2';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 istering fil-kju';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\ntokens $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 tokens';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 fi $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 sar amministratur ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 bytes';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'Kanal $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 chars';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 approvat.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 konfigurat';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 konnessi. Agħżel repożitorji u nies taħt Min jista\' messaġġ.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 entrati ewlenin.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 ħoloq link għall-istedina';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return 'desktop $arg1';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'Avvenimenti $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 falla';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 falla';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 ifalli';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 għal $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Gruppi $arg1 immarkati biss';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h ilu';
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
    return '$arg1 helpers';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '(proporzjon tal-hit $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 huwa amministratur, għalhekk il-kont ma jistax jitħassar ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 huwa mblukkat fuq $arg2. Aġġorna l-lista ta\' aċċess biex tippermetti tweġibiet.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 huwa konness u jwieġeb.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 m\'għadux amministratur ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 mhux disponibbli fuq $arg2 (permess runtime jew dipendenza nieqsa).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 ingħaqad taħt $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 iġġudikat minn LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 key$arg2 konfigurat';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Ċavetta $arg1 imneħħija.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 telaq';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 ħalla $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 marbuta';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m ilu';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Kun żgur li qed taħdem, imbagħad erġa\' pprova.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 jimmaniġġja dan il-kont';
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
    return '$arg1 min $arg2 taqs';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Mudelli $arg1 lesti';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 aktar';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 aktar passi fl-istorja tal-ġirja';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 imċaqlaq minn $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 għandu jkun numru finit.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 għandu jkun indirizz http:// jew https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 jeħtieġ attenzjoni';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent Workspace';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 kontijiet ġodda fl-aħħar $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · messaġġi ġodda jmexxu din il-ġirja';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 ġirjiet ġodda';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 issa jamministra dan il-kont.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 ta\' 4 permessi permessi. Il-fajls huma limitati għall-folder tiegħek NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 ta\' $arg2 attivat';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 ta \'gruppi $arg2 jingħaqdu ma\' chat ordinarju';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 tal-mudelli $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 tal-mudelli $arg2 lesti';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 ta \'$arg2 sett';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 ta \'għodod $arg2 permessi';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 fil-jum $arg2 f\'$arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 iwieġeb biss lin-nies li żżid hawn taħt.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 iwieġeb biss meta ttikkettat';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 jitkellem biss ma\' nies u gruppi li tapprova';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 nies jew gruppi miżjuda';
  }

  @override
  String arg1Planning(Object? arg1) {
    return 'Ippjanar $arg1';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'fornituri $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 lest';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'rekords $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 indirizz mill-ġdid URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 irreġistrat';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 wieġeb';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 irrevokat link ta\' stedina';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 runs';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 runs · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 jibda fl-aħħar $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 salvat.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 taqs';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 magħżula';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 muri';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 baqa kwiet';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 istering $arg2 fil-kju';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · tektek node biex tispezzjona';
  }

  @override
  String arg1Steps(Object? arg1) {
    return 'passi $arg1';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 waqaf jimmaniġġja $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 tokens';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 tokens fl-aħħar $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Għodod $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (override ssejvjat mhux disponibbli)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% użat · $arg2 fadal';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 trid titkellem miegħek.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 web';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" se titneħħa b\'mod permanenti.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 se jamministra dan il-kont';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 mhux se jwieġeb fuq din il-pjattaforma';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 mhux se jwieġeb lil $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Ħażna ta\' artifact mill-utent';

  @override
  String get askAQuestionOrStartA => 'Saqsi mistoqsija jew ibda kompitu...';

  @override
  String get askBeforeClosingToBackground =>
      'Staqsi qabel ma tagħlaq għall-isfond';

  @override
  String get askMe => 'Staqsini';

  @override
  String get assignedAgent => 'Aġent assenjat';

  @override
  String get assignedAgent2 => 'Aġent Assenjat';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Aġent assenjat: $arg1';
  }

  @override
  String get assigneeOptional => 'Assenjatur (mhux obbligatorju)';

  @override
  String get assistant => 'Assistent';

  @override
  String get assistantKey131 => 'Assistent ċavetta 131';

  @override
  String get atLeast1 => 'Mill-inqas 1.';

  @override
  String get attachFiles => 'Ehmeż fajls';

  @override
  String attentionArg1(Object? arg1) {
    return 'Attenzjoni $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'reġistru tal-verifika admin għotja revoke invite tim istorja';

  @override
  String get authMethod => 'Metodu Awth';

  @override
  String get authServerUrl => 'Awth Server URL';

  @override
  String get authentication => 'Awtentikazzjoni';

  @override
  String get authenticationFailed => 'L-awtentikazzjoni falliet.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'L-awtentikazzjoni għadha pendenti. Lesti l-fluss tal-browser u erġa\' pprova.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'L-awtentikazzjoni għadha pendenti. Lesti l-fluss tal-browser u aġġorna.';

  @override
  String get authenticationTimedOut => 'Awtentikazzjoni skaduta.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'L-awtentikazzjoni ġiet ikkanċellata qabel it-tlestija.';

  @override
  String get authenticatorApp => 'App awtentikatur';

  @override
  String get authenticatorCode => 'Kodiċi awtentikatur';

  @override
  String get authorOptional => 'Awtur (mhux obbligatorju)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (l-ewwel fornitur b\'ċavetta API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Awto-rotot għall-aħjar mudell disponibbli';

  @override
  String get automaticFast => 'Awtomatiku (veloċi)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Awtomatiku jaqra l-kamra u normalment iżomm lura. Mention-only ma tagħmel l-ebda sejħa għal deċiżjoni sakemm tiġi indirizzata direttament.';

  @override
  String get automaticReserved => 'Awtomatiku, riservat';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'It-tkeċċija awtomatika teħtieġ terġa\' tipprova mill-iskrin tas-setup.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Awtomatiku jagħżel mudell mgħaġġel permezz tal-katalgu tal-mudell normali.';

  @override
  String get automation => 'Awtomazzjoni';

  @override
  String get available => 'Disponibbli';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Disponibbli għal darb\'oħra f\'$arg1';
  }

  @override
  String get availableAgainShortly => 'Disponibbli mill-ġdid dalwaqt';

  @override
  String get availableInTheDesktopAppFor =>
      'Disponibbli fl-app tad-desktop għal macOS, Windows u Linux';

  @override
  String get availableToTheAgent => 'Disponibbli għall-aġent';

  @override
  String get averageAllTime => 'Medja, il-ħin kollu';

  @override
  String get avgImp => 'Imp medja.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Medja/run: tokens $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Evita karattri ripetuti u sekwenzi ovvji.';

  @override
  String get awaitingScan => 'Nistennew scan';

  @override
  String get back => 'Lura';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count fl-isfond';
  }

  @override
  String get backgroundTasks => 'Ħidmiet ta\' sfond';

  @override
  String get backOn => 'lura fuq.';

  @override
  String get backToChat => 'Lura għaċ-chat';

  @override
  String get backToFolder => 'Lura għall-folder';

  @override
  String get backToSignIn => 'Lura biex tidħol';

  @override
  String get backendChannel => 'Kanal ta\' backend';

  @override
  String get backendOnThisComputer => 'Backend fuq dan il-kompjuter';

  @override
  String get backendSync => 'Sinkronizzazzjoni tal-backend';

  @override
  String get backgroundLocationNeeded => 'Post ta\' Sfond Meħtieġa';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Is-sinkronizzazzjoni tal-isfond tibqa\' skedata fuq Android';

  @override
  String get badState => 'Stat ħażin: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Immaġini bażi u daqs tal-magni virtwali QEMU li jaħdmu ';

  @override
  String get baseUrlOptional => 'URL bażi (mhux obbligatorju)';

  @override
  String get baseUrlTokenLocal => 'bażi url token lokali';

  @override
  String get basicAuthentication => 'Awtentikazzjoni bażika';

  @override
  String get behaviorModules => 'Moduli tal-Imġieba';

  @override
  String get behaviorNotes => 'noti tal-imġieba';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Broker tal-kredenzjali Bitwarden';

  @override
  String get bitwardenItem => 'Oġġett Bitwarden';

  @override
  String get bitwardenServer => 'Server Bitwarden';

  @override
  String get blankUsesCommon => 'Blank juża \"komuni\"';

  @override
  String get blankUsesTheDefaultCallback => 'Blank juża r-callback default';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Valuri vojta jużaw in-nuqqasijiet tal-fornitur.';

  @override
  String get block => 'Blokk';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Messaġġ deħlin imblukkat minn $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Pont kompatibbli mal-BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'URL tas-server tal-BlueBubbles';

  @override
  String get botToken => 'Token tal-bot';

  @override
  String get botTokenAndApprovedChats => 'Token tal-bot u chats approvati';

  @override
  String get botTokenAndServerChannelAccess =>
      'Token tal-bot u aċċess għal server/kanal';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bot token, Events API, u aċċess għall-kanal';

  @override
  String get botUserId => 'ID tal-utent tal-bot';

  @override
  String get botUsername => 'Isem tal-utent tal-bot';

  @override
  String get brandName => 'Isem tad-ditta';

  @override
  String get braveSearch => 'Fittex Brave';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Tgħaqqad kwalunkwe fornitur li jista\' jpoġġi u jirċievi payloads tal-webhook.';

  @override
  String get bringYourOwnKey => 'ġib iċ-ċavetta tiegħek';

  @override
  String get bringYourOwnKey2 => 'Ġib iċ-ċavetta tiegħek';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Il-browser, id-desktop tal-Linux, il-fajls, it-terminal, u Python jaqsmu kompjuter sħab wieħed persistenti.';

  @override
  String get browserLogin => 'Login tal-browser';

  @override
  String get browserScripting => 'Browser Scripting';

  @override
  String get call => 'Ċempel';

  @override
  String get callAgent => 'Sejħa aġent';

  @override
  String get callUser => 'Sejħa lill-Utent';

  @override
  String get calledByName => 'Imsejjaħ bl-isem';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Jista\' jiddelega kompiti lil aġenti oħra';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Jista\' jiddelega lil $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Jista\' jirċievi kompiti delegati';

  @override
  String get cancel => 'Ikkanċella';

  @override
  String get cancelTask => 'Ikkanċella kompitu';

  @override
  String get cannotPreview => 'Ma tistax tipprevedi';

  @override
  String get cannotReceiveDelegatedTasks =>
      'ma jistax jirċievi kompiti delegati';

  @override
  String get cannotRunYet => 'għadha ma tistax taħdem.';

  @override
  String get capturedThePage => 'Inqabad il-paġna';

  @override
  String get category => 'Kategorija';

  @override
  String chainArg1(Object? arg1) {
    return 'Katina: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Ibdel il-mod tas-setup';

  @override
  String get channel => 'Kanal';

  @override
  String get channelAccessToken => 'Token ta\' aċċess għall-kanal';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanal: $arg1$arg2 | Verżjoni tal-Aġġornament: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory =>
      'Memorja soċjali b\'ambitu ta\' kanal';

  @override
  String get channels => 'Kanali';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'ID taċ-chat';

  @override
  String get chatMode => 'Modalità chat';

  @override
  String get chatModel => 'Chat Mudell';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Iċċekkja awtomatikament mat-tnedija';

  @override
  String get checkForMessagesEveryMs => 'Iċċekkja għal messaġġi kull (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Iċċekkja għal messaġġi ġodda awtomatikament';

  @override
  String get checkNow => 'Iċċekkja issa';

  @override
  String get checkYourEmailToConfirmYour =>
      'Iċċekkja l-email tiegħek biex tikkonferma l-kont NeoAgent tiegħek qabel ma tidħol.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Iċċekkjat $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Agħżel kategorija jew fittex fis-settings kollha.';

  @override
  String get chooseAPerson => 'Agħżel persuna';

  @override
  String get chooseAProjectFolder => 'Agħżel folder tal-proġett';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Agħżel defaults għaċ-chat, l-aġenti, l-imġieba fallback, u r-rotot intelliġenti.';

  @override
  String get chooseGroups => 'Agħżel gruppi';

  @override
  String get chooseHowMuchYouWantTo =>
      'Agħżel kemm trid tikkonfigura issa. Iż-żewġ għażliet jistgħu jinbidlu aktar tard.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Agħżel kif għandu jibda dan il-kompitu. Il-manwal jaħdem biss fuq Run Now. L-iskeda hija bbażata fuq il-ħin. L-integrazzjoni tikkawża n-nar minn apps uffiċjali konnessi.';

  @override
  String get chooseOneToGetStartedNow =>
      'Agħżel waħda biex tibda issa. Tista \'żżid aktar aktar tard.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Agħżel il-mudell u l-vuċi ħajjin fis-Settings.';

  @override
  String get chooseTheirGroup => 'Agħżel il-grupp tagħhom';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Agħżel fejn din il-persuna għandha titħalla titkellem ma\' $arg1. Tista\' tibdel dan aktar tard taħt Min jista\' messaġġ.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Agħżel liema gruppi $arg1 għandhom jingħaqdu anke meta ħadd ma jimmarkah. Din il-pjattaforma tista\' ma tagħrafx it-tags minn messaġġi regolari.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Agħżel liema mudelli kull kont fuq dan is-server jista \'jagħżel u ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Agħżel lil min $arg1 titkellem, u meta jingħaqad ma\' chats tal-grupp.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Agħżel min jista \'jilħaq $arg1, imbagħad issalva l-bidliet tiegħek.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Agħżel lil min jista\' jibgħat messaġġ lill-aġent b\'\"Min jista\' jibgħat messaġġ\" fuq il-karta WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Agħżel il-mudell\ndefault tiegħek.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Il-kromju, il-fajls, l-editur tat-test u t-terminal huma kollha disponibbli mid-desktop tal-Linux.';

  @override
  String get claudeCode => 'Kodiċi Claude';

  @override
  String get clear => 'Ħassar';

  @override
  String get clearAll => 'Ċara kollox';

  @override
  String clearArg1(Object? arg1) {
    return 'Ċara $arg1?';
  }

  @override
  String get clearFilter => 'Filtru ċar';

  @override
  String get clearFilters => 'Filtri ċari';

  @override
  String get clearSearch => 'Tiftix ċar';

  @override
  String get clearView => 'Veduta ċara';

  @override
  String get cliSession => 'Sessjoni CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'ikklikkja mhix appoġġjata fuq din il-pjattaforma.';

  @override
  String get clickOnceToBeginCapturing => 'Ikklikkja darba biex tibda taqbad';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Ikklikkja, ittajpja, u jinteraġixxi ma\' apps tad-desktop.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Ikklikkjat fuq ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Ikklikkjat fil-browser';

  @override
  String get clientId => 'ID tal-Klijent';

  @override
  String get clientSecret => 'Sigriet tal-klijent';

  @override
  String get close => 'Agħlaq';

  @override
  String get closeJ => 'Agħlaq (⌘J)';

  @override
  String get closeTeachMode => 'Agħlaq il-Modalità Tagħlim';

  @override
  String get closingTheWindowCanEitherKeep =>
      'L-għeluq tat-tieqa jista\' jew iżomm lil NeoAgent jaħdem fl-isfond b\'aċċess għat-trej, jew iħalli kompletament ir-runtime tad-desktop.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Cloud u istanzi self-hosted huma appoġġjati. L-URLs tan-netwerk lokali u privati ​​jaħdmu meta NeoAgent jista\' jilħaqhom.';

  @override
  String get cloudComputer => 'Cloud kompjuter';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Cloud kompjuter · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Is-settings tal-kompjuter tal-cloud ssejvjati. Ibda mill-ġdid is-server biex tapplikahom.';

  @override
  String get cloudComputerVm => 'Cloud Computer (VM)';

  @override
  String get cloudComputers => 'Kompjuters tas-sħab';

  @override
  String get codeHosting => 'Kodiċi Hosting';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Ismijiet ta\' kanali separati b\'virgola, mingħajr il-#.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Separati bil-virgola, pereżempju #ġenerali, #għajnuna';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Virgola separata. Il-kwistjoni għandu jkollha kollha kemm huma.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kmand falla ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Il-kmand huwa meħtieġ.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'L-akkumulatur tal-output tal-kmand mhuwiex attiv.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'L-upload tal-output tal-kmand falla ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'L-output tal-kmand itella\' metadata tal-artifatti barra.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'L-output tal-kmand kien diġà ffinalizzat.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Kmandi u apps';

  @override
  String get commandsRunInTheSamePersistent =>
      'Kmandi jimxu fl-istess kompjuter persistenti użat mid-desktop viżibbli.';

  @override
  String get communityChatops => 'Komunità & ChatOps';

  @override
  String get completeSetup => 'Imla Setup';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Imla l-fluss tax-xogħol fuq id-desktop.';

  @override
  String get completed => 'Imlesta';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Imblukkat kompletament — l-aġent ma jistax juża din il-kategorija.';

  @override
  String get computerShell => 'Qoxra tal-kompjuter';

  @override
  String get computerUsedByThisSession => 'Kompjuter użat minn din is-sessjoni';

  @override
  String get computerWorkspace => 'Spazju tax-xogħol tal-kompjuter';

  @override
  String get configurablePersonalWebhookBridge =>
      'Webhook bridge personali konfigurabbli';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Relay konfigurabbli jew pont tal-webhook';

  @override
  String get configurableTalkWebhookBridge => 'Konfigurabbli Talk webhook pont';

  @override
  String get configurableWebInboxBridge => 'Pont tal-inbox web konfigurabbli';

  @override
  String get configurableWebhookBridge => 'Pont webhook konfigurabbli';

  @override
  String get configurableWebhooks => 'Webhooks Konfigurabbli';

  @override
  String get configurationOrInTheEnvFile =>
      'Konfigurazzjoni jew fil-fajl .env.';

  @override
  String get configure => 'Ikkonfigura';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Ikkonfigura l-imġiba tal-ispazju tax-xogħol u d-defaults tal-mudell.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Konfigurat $arg1';
  }

  @override
  String get confirmEmailChanges => 'Ikkonferma l-bidliet fl-email';

  @override
  String get confirmNewSignUps => 'Ikkonferma reġistrazzjonijiet ġodda';

  @override
  String get confirmPassword => 'Ikkonferma l-password';

  @override
  String get confirmPassword2 => 'Ikkonferma l-Password';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Ikkonferma l-email tiegħek qabel ma tidħol. Iċċekkja l-messaġġ elettroniku tas-servizz minn NeoAgent.';

  @override
  String get connect => 'Qabbad';

  @override
  String get connectAMessagingPlatform => 'Qabbad pjattaforma\ntal-messaġġi.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Qabbad endpoint pubbliku ta\' HTTPS Home Assistant b\'Token ta\' Aċċess ta\' Ħajja twila. L-indirizzi tan-netwerk lokali, loopback u privati ​​huma mblukkati mis-server.';

  @override
  String get connectAccount => 'Qabbad il-Kont';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Qabbad il-kontijiet tal-app individwalment sabiex l-AI tkun tista\' tuża l-kont it-tajjeb għal kull integrazzjoni uffiċjali.';

  @override
  String connectArg1(Object? arg1) {
    return 'Qabbad $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Qabbad kemm trid kontijiet. Kull app tista\' tuża kont differenti.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Qabbad il-kanali, agħżel ma\' min jitkellem $arg1, u ara l-attività riċenti.';
  }

  @override
  String get connectInstance => 'Qabbad Istanza';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Qabbad din l-integrazzjoni l-ewwel biex tagħżel kont.';

  @override
  String get connectToThisServer => 'Qabbad ma\' dan is-server';

  @override
  String get connectWhatsapp => 'Qabbad WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Ikkonnettja l-istanza Nextcloud tiegħek, inklużi servers self-hosted. NeoAgent jiftaħ il-paġna tal-login ta\' Nextcloud stess sabiex tkun tista\' tidħol b\'password, SSO, jew 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Qabbad is-server NeoRecall awto-ospitat tiegħek. NeoAgent jirċievi aċċess għall-qari biss għal tfittxija lokali, memorji, u evidenza tat-traskrizzjoni wara li tapprova l-iskrin OAuth.';

  @override
  String get connected => 'Konnessi';

  @override
  String get connectedAccount => 'Kont Konness';

  @override
  String connectedArg1(Object? arg1) {
    return 'Konnessi $arg1';
  }

  @override
  String get connectedInstance => 'Istanza Konnessa';

  @override
  String get connectedNeorecallUser => 'Utent NeoRecall Konness';

  @override
  String get connectedNextcloudUser => 'Utent Nextcloud Konness';

  @override
  String get connectedServer => 'Server konness';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Konnessjoni mal-mudell tal-vuċi live...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Konnessjoni #$arg1';
  }

  @override
  String get connectionId => 'ID tal-konnessjoni';

  @override
  String get connectionLooksGood => 'Konnessjoni tidher tajba.';

  @override
  String get connectionMethod => 'Metodu ta\' Konnessjoni';

  @override
  String get containsTextOptional => 'Fih it-Test (mhux obbligatorju)';

  @override
  String get content => 'Kontenut';

  @override
  String get contentSecurityPolicy => 'politika tas-sigurtà tal-kontenut';

  @override
  String get continue2 => 'Kompli';

  @override
  String get continueFullSetup => 'Kompli setup sħiħ';

  @override
  String get continueRun => 'Kompli run';

  @override
  String get continueToSetup => 'Kompli s-setup';

  @override
  String get controlSurface => 'WIĊĊ TAL-KONTROLL';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Jikkontrolla l-aċċess għall-għodod $arg1.';
  }

  @override
  String get conversation => 'Konversazzjoni';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID tal-konversazzjoni użata meta dan l-aġent jibda chat.';

  @override
  String get cookieSetup => 'Setup tal-cookies';

  @override
  String get cookiesNotConfigured => 'Cookies mhux konfigurati';

  @override
  String get copiedAsCsv => 'Ikkupjat bħala CSV';

  @override
  String get copiedDebugInfo => 'Informazzjoni tad-debug ikkupjata';

  @override
  String get copiedExportForTheLast5 =>
      'Esportazzjoni kkupjata għall-aħħar 5 messaġġi';

  @override
  String get copiedFullPrompt => 'Ikkupjat sħiħ fil-pront';

  @override
  String get copiedLogs => 'Zkuk ikkupjati';

  @override
  String get copiedRunId => 'ID tal-ġirja kkupjata';

  @override
  String get copy => 'Kopja';

  @override
  String get copyAll => 'Ikkopja kollha';

  @override
  String get copyCodes => 'Ikkopja kodiċijiet';

  @override
  String get copyCsv => 'Ikkopja CSV';

  @override
  String get copyDebugInfo => 'Ikkopja l-informazzjoni tad-debug';

  @override
  String get copyLink => 'Ikkopja l-link';

  @override
  String get copyLogs => 'Ikkopja zkuk';

  @override
  String get copyPrompt => 'Kopja Prompt';

  @override
  String get copyResponse => 'Ikkopja tweġiba';

  @override
  String get copyRunId => 'Ikkopja l-ID tal-ġirja';

  @override
  String get copyWebhookUrl => 'Ikkopja l-URL tal-webhook';

  @override
  String get core => 'Qalba';

  @override
  String get coreMemory => 'memorja tal-qalba';

  @override
  String get coreServicesThisServerDependsOn =>
      'Servizzi ewlenin dan is-server jiddependi fuqhom.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domain https oriġini url pubbliku';

  @override
  String get couldHelp => 'Jista \'jgħin';

  @override
  String get couldNotApproveQrLogin => 'Ma setax japprova l-login tal-QR.';

  @override
  String get couldNotApproveQrPairing =>
      'Ma setgħetx tapprova t-tqabbil tal-QR.';

  @override
  String get couldNotConnect => 'Ma setgħetx tikkonnettja.';

  @override
  String get couldNotCreateBinding => 'Ma setgħetx toħloq vinkolanti.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Ma setgħetx tħassar il-kont tiegħek: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Ma setax jiskonnettja Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Ma setgħetx tiskonnettja l-Assistent tad-Dar.';

  @override
  String get couldNotDisconnectNeorecall =>
      'Ma setgħetx tiskonnettja NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Ma setgħetx tiskonnettja Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Ma setax jiskonnettja Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Ma setgħetx tesporta d-dejta tiegħek: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Ma setgħetx tagħbija deċiżjonijiet';

  @override
  String get couldNotLoadUsageData => 'Ma setgħetx tagħbija data dwar l-użu.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Ma setgħetx tiftaħ is-settings tal-Linux awtomatikament.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Ma setgħetx tiftaħ il-paġna li tgħaqqad il-fornitur.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Ma setgħetx tiftaħ il-paġna ta\' dħul tal-fornitur.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Ma setgħetx tiftaħ l-assi tar-rilaxx.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Ma setgħetx tiftaħ Trello fil-browser tiegħek.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Ma setgħetx tiftaħ it-tniżżil tal-fajl tal-ispazju tax-xogħol.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Ma setgħetx taqra l-pakkett tal-app Android.';

  @override
  String get couldNotReadTheApk => 'Ma setax jaqra l-APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Ma setgħetx tneħħi ċ-ċavetta: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Ma setax isalva l-aġent.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Ma setgħetx tissejvja s-setup ta\' Bitwarden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Ma setgħetx tissejvja s-setup tal-Assistent tad-Dar.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Ma setgħetx issalva s-setup ta\' NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Ma setgħetx tissejvja s-setup ta\' Nextcloud.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Ma setgħetx issalva s-setup ta\' Trello.';

  @override
  String get couldNotSendConfirmationEmail =>
      'ma setgħetx tibgħat email ta\' konferma';

  @override
  String get couldNotStart => 'Ma setgħetx tibda';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Oħloq';

  @override
  String get createAPasswordFirstToChange =>
      'Oħloq password l-ewwel biex tibdel l-email tal-kont tiegħek.';

  @override
  String get createAPasswordOrLinkAnother =>
      'oħloq password jew għaqqad fornitur ieħor qabel ma tneħħi dan il-metodu ta\' dħul';

  @override
  String get createATaskWhileThisAgent =>
      'Oħloq kompitu waqt li jintgħażel dan l-aġent.';

  @override
  String get createLink => 'Oħloq link';

  @override
  String get createOrModifyFilesInYour =>
      'Oħloq jew immodifika fajls fl-ispazju tax-xogħol tiegħek.';

  @override
  String get createPassword => 'Oħloq password';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Oħloq bots speċjalizzati b\'memorja, settings, għodod, u assenjazzjonijiet tal-kontijiet separati.';

  @override
  String get createTheFirstAccount => 'Oħloq l-ewwel kont';

  @override
  String get createUpdateOrDeleteSkills =>
      'Oħloq, aġġorna jew ħassar il-ħiliet.';

  @override
  String get creatingYourSkill => 'Il-ħolqien tal-ħila tiegħek...';

  @override
  String get credentialBindings => 'Irbit ta\' kredenzjali';

  @override
  String get credentialUse => 'Użu tal-Kredenzjali';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Tiġrijiet rikorrenti bbażati fuq Cron u eżekuzzjoni f\'ħin ta\' darba.';

  @override
  String get cronExpression => 'Cron espressjoni';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter imexxi l-mistoqsija.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Spazju';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Email kurrenti: $arg1';
  }

  @override
  String get currentPassword => 'Password kurrenti';

  @override
  String get currentPasswordIsIncorrect => 'password attwali mhix korretta';

  @override
  String get currentTwoStepLoginCode =>
      'Kodiċi attwali tal-login f\'żewġ stadji';

  @override
  String get customAccess => 'Aċċess apposta';

  @override
  String get customCron => 'Custom Cron';

  @override
  String get customCronMustHave5Fields => 'Custom Cron għandu jkollu 5 oqsma.';

  @override
  String get customEndpoint => 'endpoint tad-dwana';

  @override
  String get customField => 'Qasam tad-dwana';

  @override
  String get customHeader => 'Header tad-dwana';

  @override
  String get customHeadersJson => 'Intestaturi personalizzati (JSON)';

  @override
  String get customOpenaiCompatible => 'Custom OpenAI-kompatibbli';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Endpoint custom kompatibbli mal-OpenAI';

  @override
  String get customOutgoingUrl => 'URL tal-ħruġ personalizzat';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Kuljum';

  @override
  String get dailyRecap => 'Rikap ta \'kuljum';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'mistoqsija tad-database tagħżel mudelli csv';

  @override
  String dayArg1(Object? arg1) {
    return 'Jum $arg1';
  }

  @override
  String get dayOfMonth => 'Jum tax-xahar';

  @override
  String get decideWhichToolsYourAgentMay =>
      'jiddeċiedi liema għodod jista\' juża l-aġent tiegħek. Jaraw ismek u ';

  @override
  String get decisionHigherUpTheChainWins =>
      'deċiżjoni ogħla fil-katina tirbaħ u turi lock mal- ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Id-deċiżjonijiet jidhru hawn hekk kif $arg1 jaqra gruppi $arg2 approvati. Jinżammu biss l-aħħar 30, u reset meta s-server jerġa \'jibda.';
  }

  @override
  String get decline => 'Tnaqqis';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'ġirja fil-fond · pass $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram ċavetta';

  @override
  String get default2 => 'Default';

  @override
  String get default3 => 'DEFAULT';

  @override
  String defaultArg1(Object? arg1) {
    return 'Default ($arg1)';
  }

  @override
  String get defaultConversation => 'Konverżazzjoni default';

  @override
  String get defaultForNewGroups => 'Default għal gruppi ġodda';

  @override
  String get defaultGroupParticipation => 'Parteċipazzjoni tal-grupp default';

  @override
  String get defaultNeoagentWorkspace => 'NeoAgent Workspace default';

  @override
  String get defaultOpenai => 'Default (OpenAI)';

  @override
  String get defaultRateLimits => 'Limiti tar-rata default';

  @override
  String get defaultRateLimitsSaved => 'Limiti tar-rata default salvati.';

  @override
  String get defaultRecommended => 'Default (rakkomandat)';

  @override
  String get defaultRouting => 'Rotot Default';

  @override
  String get defaultSpace => 'Spazju default';

  @override
  String get delete => 'Ħassar';

  @override
  String get deleteAccount => 'Ħassar kont';

  @override
  String get deleteAccountPermanently => 'Ħassar kont b\'mod permanenti?';

  @override
  String get deleteAnAccount => 'Ħassar kont';

  @override
  String deleteArg1(Object? arg1) {
    return 'Ħassar @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Ħassar ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Ħassar $arg1 $arg2 b\'mod permanenti?';
  }

  @override
  String get deleteBinding => 'Ħassar l-irbit';

  @override
  String get deleteCoreMemoryEntry => 'Ħassar id-dħul tal-memorja ewlenija?';

  @override
  String get deleteForever => 'Ħassar għal dejjem';

  @override
  String get deleteMcpServer => 'Ħassar server MCP?';

  @override
  String get deleteMemory => 'Ħassar il-memorja?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Ħassar iħassar b\'mod permanenti kont u d-dejta kollha tiegħu ';

  @override
  String get deleteRun => 'Ħassar run?';

  @override
  String get deleteRun2 => 'Ħassar run';

  @override
  String get deleteSelectedMemories => 'Tħassar memorji magħżula?';

  @override
  String get deleteSession => 'Tħassar is-sessjoni?';

  @override
  String get deleteSkill => 'Ħassar il-ħila?';

  @override
  String get deleteTask => 'Ħassar kompitu?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Imħassar \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Imħassar @$arg1 u d-dejta kollha tagħhom.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'It-tħassir ineħħi l-konversazzjonijiet, il-memorji, il-fajls, il-kompiti kollha tiegħek u ';

  @override
  String get deliverableArtifactProduced =>
      'Artifatt li jista\' jitwassal prodott';

  @override
  String get deliverableCompleted => 'Konsenjabbli komplut';

  @override
  String get deliverableExecutionStarted =>
      'Bdiet l-eżekuzzjoni li tista\' titwassal';

  @override
  String get deliverableSelected => 'Konsenjabbli magħżula';

  @override
  String get deliverableValidationFailed =>
      'Il-validazzjoni li tista\' titwassal falliet';

  @override
  String get deliverableValidationStarted =>
      'Inbdiet il-validazzjoni li tista\' titwassal';

  @override
  String get deny => 'Tiċħad';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Iddeskrivi r-riżultat, imbagħad urih fuq id-desktop';

  @override
  String get describeWhatToBuildOrChange =>
      'Iddeskrivi x\'għandek tibni jew tibdel...';

  @override
  String get description => 'Deskrizzjoni';

  @override
  String get desktopApp => 'App tad-desktop';

  @override
  String get desktopAppControlsAvailable =>
      'Kontrolli tal-app tad-desktop disponibbli';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Il-qbid tad-desktop mhuwiex disponibbli fuq din il-pjattaforma.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Upload tal-output tal-kmand tad-desktop ikkanċellat.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Il-kmand tal-kumpann tad-desktop ġie kkanċellat.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Konnessjoni tal-kumpann tad-desktop skaduta.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Il-handshake tal-kumpann tad-desktop skada.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Il-kumpann tad-desktop mhuwiex disponibbli hawn.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Il-kumpann tad-desktop jitwaqqaf lokalment.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'L-immaniġġjar tal-messaġġ ta\' ħbieb tad-desktop falla: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Is-settings tal-permessi tal-kumpann tad-desktop mhumiex disponibbli fuq il-web.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Is-settings tal-permessi tal-kumpann tad-desktop mhumiex disponibbli fuq din il-pjattaforma.';

  @override
  String get desktopCompanionRejected => 'Kumpann tad-desktop miċħud.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Ir-risposta ta\' ħbieb tad-desktop falliet: $arg1';
  }

  @override
  String get desktopControl => 'Kontroll tad-Desktop';

  @override
  String get desktopFailedToStart => 'Id-desktop naqas milli jibda';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Il-qbid tal-fluss tad-desktop falla: $arg1';
  }

  @override
  String get destinationId => 'ID tad-Destinazzjoni';

  @override
  String get deviceAccess => 'Aċċess għall-apparat';

  @override
  String get deviceSettings => 'Settings tal-Apparat';

  @override
  String get devices => 'Apparati';

  @override
  String get diagnosticsSaved => 'Dijanjostiċi salvati.';

  @override
  String get directBluebubblesImessageBridge =>
      'BlueBubbles dirett iMessage pont';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Il-messaġġi diretti jibqgħu jirrispondu. Gruppi permessi jużaw il-mod ta \'parteċipazzjoni hawn taħt.';

  @override
  String get directoryDoesNotExist => 'Direttorju ma jeżistix.';

  @override
  String get disable2fa => 'Itfi 2FA';

  @override
  String get disableAll => 'Itfi kollox';

  @override
  String get discard => 'Armi';

  @override
  String get disconnect => 'Skonnettja';

  @override
  String get disconnectHomeAssistant => 'Skonnettja l-Assistent tad-Dar?';

  @override
  String get disconnectNeorecall => 'Skonnettja NeoRecall?';

  @override
  String get disconnectNextcloud => 'Skonnettja Nextcloud?';

  @override
  String get disconnectPlatform => 'Skonnettja l-pjattaforma';

  @override
  String get disconnectTrello => 'Skonnettja Trello?';

  @override
  String get discoveryFailed => 'L-iskoperta falliet';

  @override
  String get dismiss => 'Tkeċċi';

  @override
  String get displayIdIsRequired => 'Id-displej hija meħtieġa.';

  @override
  String get displayName => 'Isem tal-wiri';

  @override
  String get displayNameMustBe64Characters =>
      'L-isem tal-wiri għandu jkun ta\' 64 karattru jew inqas.';

  @override
  String get displayNameSaved => 'Isem tal-wiri salvat.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Tinkludix l-isem tal-utent jew l-email tiegħek.';

  @override
  String get done => 'Magħmul';

  @override
  String get downloadACopyOfYourData =>
      'Niżżel kopja tad-dejta tiegħek. Il-kontijiet tal-amministrazzjoni ma jistgħux iħassru ';

  @override
  String get downloadACopyOfYourData2 =>
      'Niżżel kopja tad-dejta tiegħek, jew ħassar il-kont tiegħek b\'mod permanenti. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Niżżel $arg1';
  }

  @override
  String get downloadUpdate => 'Niżżel l-aġġornament';

  @override
  String get downloadingTheNeoagentBackend => 'Niżżel il-backend NeoAgent';

  @override
  String get draft => 'Abbozz';

  @override
  String get dragIsNotSupportedOnThis =>
      'drag mhix appoġġjata fuq din il-pjattaforma.';

  @override
  String get draggedOnTheScreen => 'Mkaxkra fuq l-iskrin';

  @override
  String get dropAnApkOrApkBundle =>
      'Waqqa\' pakkett APK jew APK hawn biex tinstallah';

  @override
  String get dropApkOrApksHere => 'Drop APK jew .apks Hawnhekk';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Istruzzjonijiet dejjiema għall-vuċi u l-istil ta \'interazzjoni. Ir-regoli tas-sikurezza u tal-eżekuzzjoni għadhom jieħdu prijorità.';

  @override
  String get eGAlexSLaptop => 'eż. Il-laptop ta’ Alex';

  @override
  String get eGMyLocalServer => 'eż. Is-server lokali tiegħi';

  @override
  String get edit => 'Editja';

  @override
  String get editAgent => 'Editja aġent';

  @override
  String get editCoreMemoryEntry => 'Edit Core Memory Dħul';

  @override
  String get editInstructions => 'Editja l-istruzzjonijiet';

  @override
  String get editMcpServer => 'Editja MCP Server';

  @override
  String get editTask => 'Editja l-Kompitu';

  @override
  String editedArg1(Object? arg1) {
    return 'Editjat $arg1';
  }

  @override
  String get email => 'Email';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Is-sidien tal-kontijiet tal-email dwar id-dħul li jidher mhux tas-soltu.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Is-sidien tal-kont tal-email meta jinbidlu d-dettalji tal-kont tagħhom.';

  @override
  String get emailCode => 'Kodiċi tal-posta elettronika';

  @override
  String get emailConfirmationRequired => 'konferma bl-email meħtieġa';

  @override
  String get emailIsAlreadyInUse => 'l-email diġà qed tintuża';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'Email salvata. Jekk tkun meħtieġa konferma, iċċekkja l-indirizz il-ġdid għal link ta\' konferma NeoAgent.';

  @override
  String get emailSettingsSaved => 'Issettjar tal-email issejvjat.';

  @override
  String get emailUnverified => 'Email mhux verifikata';

  @override
  String get empty => 'Vojta';

  @override
  String get emptyFile => 'Fajl vojt';

  @override
  String get emptyFolder => 'Fowlder vojt';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Vojt juża s-server default ($arg1).';
  }

  @override
  String get enable2fa => 'Ippermetti 2FA';

  @override
  String get enableAll => 'Ippermetti kollha';

  @override
  String get enableBehaviorModules => 'Ippermetti moduli tal-imġieba';

  @override
  String get enableOrDisableModels => 'Attiva jew iddiżattiva mudelli';

  @override
  String get enabled => 'Ippermettiet';

  @override
  String get encryptedPrivateToYourAccount =>
      'Encrypted, privat għall-kont tiegħek';

  @override
  String get end => 'Tmiem';

  @override
  String get endCall => 'Tmiem is-sejħa';

  @override
  String get endVoiceCall => 'Ttemm is-sejħa bil-vuċi?';

  @override
  String get endpoint => 'Endpoint';

  @override
  String get enterAPassword => 'Daħħal password.';

  @override
  String get enterAUsername => 'Daħħal username.';

  @override
  String get enterAValidEmailAddress => 'Daħħal indirizz elettroniku validu.';

  @override
  String get enterAnAddressManually => 'Daħħal indirizz manwalment';

  @override
  String get enterAnApiKeyFirst => 'Daħħal ċavetta API l-ewwel.';

  @override
  String get enterInviteLink => 'Daħħal il-link tal-istedina';

  @override
  String get enterTheAddressOfANeoagent =>
      'Daħħal l-indirizz ta\' server NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Daħħal id-dettalji li $arg1 tak sabiex $arg2 ikun jista\' jibgħat u jirċievi messaġġi.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Daħħal il-kodiċi 2FA jew ta \'rkupru tiegħek.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Daħħal il-password attwali tiegħek biex tibdelha.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Daħħal il-password attwali tiegħek biex issalva l-bidliet fl-email.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Daħħal id-dettalji tal-kont NeoAgent tiegħek.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Daħħal l-isem tal-utent jew l-email tal-kont tiegħek. NeoAgent jibgħat link ta\' reset jekk jista\' jaqbel mal-kont.';

  @override
  String get enterYourUsernameOrEmail =>
      'Daħħal l-isem tal-utent jew l-email tiegħek.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entità: $arg1';
  }

  @override
  String get environment => 'Ambjent';

  @override
  String get error => 'Żball';

  @override
  String errorArg1(Object? arg1) {
    return '\nżball: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Żbalji mill-ġurnal reċenti, miġbura skont il-messaġġ.';

  @override
  String get errorsProblemsFailures => 'żbalji problemi fallimenti';

  @override
  String get eventTypesCommaSeparated =>
      'Tipi ta\' Avvenimenti (separati bil-virgola)';

  @override
  String get every15Minutes => 'Kull 15-il minuta';

  @override
  String get every30Minutes => 'Kull 30 minuta';

  @override
  String get everyAccountOnThisServerLoses =>
      'Kull kont fuq dan is-server jitlef din iċ-ċavetta kondiviża. Kontijiet ';

  @override
  String get everyAccountOnThisServerUses =>
      'Kull kont fuq dan is-server juża dan l-indirizz għal ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Kull sessjoni attiva għal dan il-kont tispiċċa. Jistgħu jiffirmaw ';

  @override
  String get everyDay0800 => 'Kull jum · 08:00';

  @override
  String get everyDay2000 => 'Kuljum · 20:00';

  @override
  String get everyHour => 'Kull siegħa';

  @override
  String get everyRunOnThisServerAll =>
      'Kull ġirja fuq dan is-server, il-ħin kollu.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Kull għodda sensittiva teħtieġ approvazzjoni, kull darba.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Kull għodda taħdem mingħajr ma tistaqsi, ħlief dawk il-persuna ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Kulħadd f\'dawn il-gruppi, kanali, jew kmamar jista \'jitkellem ma\' $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Kulħadd f\'dan il-grupp';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Jiġi kollox $arg1 mitfi għall-aġent tiegħek ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Kollox ieħor huwa mitfi.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Kollox huwa disponibbli mid-desktop.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Dak kollu li l-aġent jista \'juża: integrazzjonijiet uffiċjali, servers MCP, u ħiliet.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Dak kollu li tfiet għal $arg1 jiġi lura ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Oriġini eżatti tal-web permessi li jagħmlu talbiet trans-oriġini, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Eżegwixxi JavaScript ġewwa s-sessjoni tal-browser tiegħek.';

  @override
  String get execution => 'Eżekuzzjoni';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Id-dettalji tal-eżekuzzjoni mhumiex disponibbli għal din il-ġirja.';

  @override
  String get executionPlanCreated => 'Pjan ta\' eżekuzzjoni maħluq.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Eżerċizzju $arg1 sessjonijiet';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[ħruġ minn $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Tiskadi $arg1';
  }

  @override
  String get explainThisProject => 'Spjega dan il-proġett';

  @override
  String exploredArg1(Object? arg1) {
    return 'Esplorat $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Esplorat $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Esplora l-ispazju tax-xogħol';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'L-esportazzjoni falliet: $arg1';
  }

  @override
  String get exportLast5Messages => 'Esporta l-aħħar 5 messaġġi';

  @override
  String get exportMyData => 'Esporta d-dejta tiegħi';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'It-tnedija tal-browser estern falliet bil-kodiċi tal-ħruġ $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'It-tnedija esterna tal-browser mhix appoġġata fuq din il-pjattaforma.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'It-tnedija tal-browser estern skadiet.';

  @override
  String get externalMcpTools => 'Għodod Esterni u MCP';

  @override
  String get extraButtons => 'Buttuni Extra';

  @override
  String get extractingTheNeoagentRuntime =>
      'L-estrazzjoni tar-runtime NeoAgent';

  @override
  String get failed => 'Falliet';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Naqas milli jikkonnettja: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Naqas milli jikkonnettja $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Naqas milli tħassar \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'naqas milli jġib';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Naqas milli jiġġenera fil-pront: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Naqas milli tniedi browser estern permezz ta\' url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Naqas milli tniedi l-fluss OAuth.';

  @override
  String get failedToLoadPolicies => 'Naqas milli jgħabbi l-politiki';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Naqas milli jiffranka: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Naqas milli ssalva server MCP.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Naqas milli tissejvja l-għażla: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Naqset milli tibgħat notifika lill-backend: $arg1';
  }

  @override
  String get fair => 'Ġust';

  @override
  String get fasterReplies => 'Risposti aktar mgħaġġla';

  @override
  String get fewerModelCalls => 'Inqas telefonati mudell';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'qasam vojt biex jirrestawra l-inadempjenza inkorporata.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Il-fajl jaqbeż il-limitu ta\' editur ta\' 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Il-fajl jaqbeż il-limitu ta\' daqs appoġġjat.';

  @override
  String get fileWrites => 'File Jikteb';

  @override
  String get filename => 'Isem tal-fajl';

  @override
  String get files => 'Fajls';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Fajls li NeoAgent jikteb jew editjar f\'din is-sessjoni jidhru hawn.';

  @override
  String get filesSavedByAllUsers => 'Fajls salvati mill-utenti kollha';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Imla logins approvati jew awtentika talbiet mingħajr ma turi sigrieti lill-AI.';

  @override
  String get finalResponse => 'Rispons Finali';

  @override
  String get findAPlatform => 'Sib pjattaforma';

  @override
  String get findAndFixABug => 'Sib u waħħal bug';

  @override
  String get findRecentChats => 'Sib chats riċenti';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Sib il-runtime NeoAgent korrett';

  @override
  String get finish => 'Temm';

  @override
  String get finishAtTheScheduledTime => 'Tispiċċa fil-ħin skedat';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Ittemm idħol ma\' $arg1 fil-browser tiegħek, imbagħad erġa\' qabbad.';
  }

  @override
  String get flowGraph => 'Grafika tal-fluss';

  @override
  String get flutterApp => 'App flutter';

  @override
  String get focusedExecutionProfile => 'Profil ta\' eżekuzzjoni ffukat';

  @override
  String get folderIdOptional => 'ID tal-folder (mhux obbligatorju)';

  @override
  String get folderUnavailable => 'Folder mhux disponibbli';

  @override
  String get forExampleHttpsMatrixOrg => 'Per eżempju https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Għal setups tan-netwerk ospitati jew avvanzati';

  @override
  String get forLinksInEmailsBlankUses =>
      'Għal links fl-emails. Blank juża l-URL pubbliku tas-server.';

  @override
  String get forgotPassword => 'Insejt il-password?';

  @override
  String get frameUnavailable => 'Il-qafas mhux disponibbli';

  @override
  String freshnessArg1(Object? arg1) {
    return 'freskezza: $arg1';
  }

  @override
  String get fridays1700 => 'Il-Ġimgħa · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Minn BotFather wara li toħloq il-bot.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Minn issa \'l quddiem $arg1 jiddeċiedi liema għodod jista\' juża l-aġent tiegħek. Huma ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Mill-Portal tal-Iżviluppaturi Discord, taħt il-bot tiegħek.';

  @override
  String get fromTheLineDevelopersConsole => 'Mill-LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Mill-kont tal-klijent jew bot tal-Matrix.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Minn twitchapps.com/tmi jew l-app tiegħek għall-iżviluppatur Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Sħiħ fil-pront';

  @override
  String get fullSetup => 'Setup sħiħ';

  @override
  String get general => 'Ġenerali';

  @override
  String get generalSettings => 'Settings ġenerali';

  @override
  String get generalSettingsSaved => 'Issettjar ġenerali ssejvjat.';

  @override
  String get generateAPromptForAnotherAi =>
      'Iġġenera pront għal AI oħra, waħħal ir-rispons hawn biex timporta memorji.';

  @override
  String get generatePrompt => 'Iġġenera Prompt';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Żball tat-traċċar tal-ġeofence: $arg1';
  }

  @override
  String get getInspired => 'Ikseb ispirat';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot u OpenAI Codex';

  @override
  String get githubIssueOpened => 'Kwistjoni GitHub Miftuħa';

  @override
  String get neorecallMemoryCreated => 'Memorja NeoRecall Maħluqa';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Il-kontroll tar-rilaxx ta\' GitHub falla b\'HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'It-tagħbija ta \'rilaxx ta\' GitHub ma kinitx lista ta \'rilaxx.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'L-isem tal-utent GitHub li fetaħ il-kwistjoni';

  @override
  String get globalSecurityMode => 'Mod ta \'sigurtà globali';

  @override
  String get gmailMessageReceived => 'Messaġġ tal-Gmail Riċevut';

  @override
  String get good => 'Tajjeb';

  @override
  String get goodAfternoon => 'Wara nofsinhar it-tajjeb';

  @override
  String get goodEvening => 'Il-lejla t-tajba';

  @override
  String get goodMorning => 'L-għodwa t-tajba';

  @override
  String get goodPasswordALittleMoreLength =>
      'Password tajba. Ftit aktar tul jagħmilha aktar b\'saħħitha.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live juża ċ-ċavetta OpenAI API tiegħek, Gemini Live ċavetta Google AI tiegħek. Il-bidliet japplikaw għas-sejħa li jmiss.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Agħti permessi Health Connect qabel is-sinkronizzazzjoni.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grupp, kanal, jew kamra';

  @override
  String get groupType => 'Tip ta\' grupp';

  @override
  String get groupsAndChannels => 'Gruppi u kanali';

  @override
  String groupsArg1(Object? arg1) {
    return 'Gruppi: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Gruppi $arg1 għadhom ma rawx se jsegwu dan.';
  }

  @override
  String get handlesDirectTasksItself => 'Mankijiet kompiti diretti innifsu';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Idejn ħielsa (tkellem liberament, interrompi ghaċ)';

  @override
  String get headerName => 'Isem tal-header';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Titoli ewlenin dwar is-suġġetti li jimpurtak minnhom, iffiltrati għal sinjal.';

  @override
  String get health => 'Saħħa';

  @override
  String get healthChecks => 'Kontrolli tas-saħħa';

  @override
  String get healthConnect => 'saħħa konnessjoni';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect mhix disponibbli fuq dan l-apparat.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Istatus tas-sinkronizzazzjoni tas-Saħħa Connect u metriċi backend maħżuna.';

  @override
  String get healthStatusIsUnavailable =>
      'L-istatus tas-saħħa mhuwiex disponibbli.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Is-sinkronizzazzjoni tas-saħħa hija disponibbli biss fuq Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Qalb rekords $arg1';
  }

  @override
  String get heldBack => 'Miżmum lura';

  @override
  String get helper => 'Helper';

  @override
  String helperArg1(Object? arg1) {
    return 'Helper: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'hawn. Irrevoka l-amministratur b\'\'neoagent admin revoke $arg1\' l-ewwel.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Valuri ogħla jagħmlu lil NeoAgent aktar selettiv fi gruppi.';

  @override
  String get highlyRecommended => 'Rakkomandat ħafna';

  @override
  String get holdButton131ForTheAssistant =>
      'Żomm il-buttuna 131 għall-assistent.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Żomm Ctrl+Shift+Spazju biex titkellem';

  @override
  String get holdToTalk => 'Żomm biex titkellem.';

  @override
  String get holdToTalk2 => 'Żomm biex titkellem';

  @override
  String get home => 'Dar';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Token ta\' Aċċess ta\' Ħajja twila għall-Assistent tad-Dar huwa meħtieġ.';

  @override
  String get homeAssistantSetup => 'Setup tal-Assistent tad-Dar';

  @override
  String get homeAssistantUrl => 'URL tal-Assistent tad-Dar';

  @override
  String get homeAssistantUrlIsRequired =>
      'Il-URL tal-Assistent tad-Dar huwa meħtieġ.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Homeserver token bil-votazzjoni tal-kamra';

  @override
  String get homeserverUrl => 'URL tas-homeserver';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'servizz ospitat). Iċ-ċwievet tiegħek huma encrypted u jistgħu jintużaw biss minn ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'L-isem tal-ospitant tan-netwerk IRC, pereżempju irc.libera.chat';

  @override
  String get hourly => 'Kull siegħa';

  @override
  String get hourlyInboxCheck => 'Iċċekkja inbox kull siegħa';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Kemm idum il-links ta\' konferma jibqgħu validi.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Kemm-il darba dan l-aġent ifittex messaġġi ġodda fil-kamra.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Kemm-il darba dan l-aġent ifittex messaġġi ġodda tas-Sinjal.';

  @override
  String get howTeamsWork => 'Kif jaħdmu t-timijiet';

  @override
  String get howThisServerIsReachedPlus =>
      'Kif jintlaħaq dan is-server, flimkien ma\' swiċċijiet madwar is-server.';

  @override
  String get httpsSessionCookie => 'Cookie tas-sessjoni https';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Ma stajtx inlesti dik it-talba bħalissa. Jekk jogħġbok erġa\' pprova fi ftit mument.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Idle';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Jekk $arg1 jitlob URL tal-webhook, waħħal dan sabiex il-messaġġi jkunu jistgħu jaslu lil $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Jekk dak il-kont ikollu email ikkonfermata, NeoAgent jibgħat link għall-issettjar tal-password.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Jekk is-servizz jeħtieġ token fuq talbiet ħerġin.';

  @override
  String get ignoreGroups => 'Injora Gruppi';

  @override
  String get ignoreThisChat => 'Injora dan iċ-chat';

  @override
  String get ignoredChannels => 'Kanali injorati';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Messaġġ anëillari tad-desktop malformat injorat: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Implimenta l-pjan t\'hawn fuq.';

  @override
  String get implementThisPlan => 'Implimenta dan il-pjan';

  @override
  String get implicitTls => 'TLS impliċitu';

  @override
  String get import => 'Importazzjoni';

  @override
  String importFailedArg1(Object? arg1) {
    return 'L-importazzjoni falliet: $arg1';
  }

  @override
  String get importFromComputer => 'Importazzjoni mill-kompjuter';

  @override
  String get importMemoryTransfer =>
      'Trasferiment tal-memorja tal-importazzjoni?';

  @override
  String get importance => 'Importanza';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Memorji $arg1 importati, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'Fit-tim ta’ @$arg1';
  }

  @override
  String get inBackground => 'isfond';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Messaġġi tal-kanal deħlin u ħerġin se jidhru hawn.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Sejħiet tal-vuċi deħlin fl-app minn NeoAgent';

  @override
  String get incomingMessages => 'Messaġġi deħlin';

  @override
  String get incomingNeoagentCall => 'Sejħa NeoAgent deħlin';

  @override
  String get incomingNeoagentCall2 => 'SEJĦA NEOAGENT DĦUL';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Webhook deħlin u appoġġ għal callback ħerġin';

  @override
  String get incorporatingSteering => 'Jinkorporaw l-istering';

  @override
  String get input => 'Input';

  @override
  String get inputMode => 'Mod tad-dħul';

  @override
  String get insertATemplate => 'Daħħal mudell';

  @override
  String get install => 'Installa';

  @override
  String get installASignedSelfContainedRuntime =>
      'Installa runtime ffirmat u awtonomu. Node.js, npm, Git, u kmandi tat-terminal mhumiex meħtieġa.';

  @override
  String get installApk => 'Installa APK';

  @override
  String get installApkBundle => 'Installa APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Installa APK — ikklikkja jew qiegħed fajl .apk';

  @override
  String get installNeoagent => 'Installa NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Installa NeoAgent fuq dan il-kompjuter mingħajr terminal, jew qabbad ma\' wieħed li diġà qed jaħdem.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Installa ħarġiet ġodda u agħżel liema kanal isegwi dan is-server.';

  @override
  String get installTheBackend => 'Installa l-backend';

  @override
  String get installTheCoreWithExtraOptional =>
      'Installa l-qalba b\'setup mhux obbligatorju. Iċ-ċwievet tal-fornitur tal-AI huma miżjuda wara, l-istess bħal Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Installa l-qalba sigura, imbagħad oħloq il-kont tiegħek. Żid iċ-ċwievet tal-fornitur tal-AI wara.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Installat: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Installat: $arg1 • Iċċekkjat l-aħħar: $arg2';
  }

  @override
  String get instructions => 'Istruzzjonijiet';

  @override
  String get integration => 'Integrazzjoni';

  @override
  String get integrationConnections => 'Konnessjonijiet ta \'integrazzjoni';

  @override
  String get integrationSettingsSaved =>
      'Issettjar ta\' integrazzjoni salvati.';

  @override
  String get integrations => 'Integrazzjonijiet';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrazzjonijiet/oauth/callback, u jirreġistraw l-istess ';

  @override
  String get interruptAi => 'Interrompi l-AI';

  @override
  String get invalid2fa => 'invalidu 2fa';

  @override
  String get invalidArgumentS => 'Argument(i) invalidu(i): ';

  @override
  String get invalidCredentials => 'kredenzjali invalidi';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Manifest runtime NeoAgent invalidu.';

  @override
  String get inviteLink => 'Stieden link';

  @override
  String get inviteLinkReady => 'Stieden link lest';

  @override
  String get inviteLinks => 'Stieden links';

  @override
  String get iphoneApp => 'app iPhone';

  @override
  String get issues => 'Kwistjonijiet';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Il-kwistjonijiet jidhru ladarba l-log tagħbijiet.';

  @override
  String get itCanTBeUndone => 'Ma jistax jitneħħa.';

  @override
  String get itMayHaveBeenDeleted => 'Jista\' jkun ġie mħassar.';

  @override
  String get javaRuntime => 'runtime java';

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
    return 'Ingħaqad ma\' $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Insieħeb fl-aħħar 7 ijiem';

  @override
  String get joiningATeam => 'Jingħaqad ma \'tim';

  @override
  String get joiningIsOffHere => 'Is-sħubija hija off hawn';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Qasam JSON li fih it-test tal-messaġġ. Normalment test.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Qasam JSON li jidentifika għal min hu l-messaġġ.';

  @override
  String get jumpToLatest => 'Aqbeż għall-aktar tard';

  @override
  String get justNow => 'biss issa';

  @override
  String get keepNeoagentRunning => 'Żomm NeoAgent jaħdem?';

  @override
  String get keepRunning => 'Kompli għaddej';

  @override
  String get keepTaskRunning => 'Żomm il-kompitu għaddej';

  @override
  String get keepTheVaultAvailable => 'Żomm il-kaxxa-forti disponibbli';

  @override
  String get keepThisLauncherUpToDate => 'Żomm dan il-lanċjar aġġornat.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Żomm dan il-pannell miftuħ sakemm il-pjattaforma tikkonferma l-konnessjoni.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Żomm il-kompjuter ta\' din is-sessjoni viżibbli';

  @override
  String get keepTrackOfYourAiUsage =>
      'Żomm kont tal-użu tal-AI tiegħek. Il-limiti huma infurzati biex jiġi żgurat użu ġust madwar il-pjattaforma.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Ibqa\' uża l-apps tiegħek b\'mod normali. NeoAgent jaħdem fuq l-istess skrin u jistaqsi kull meta jkollu bżonn aċċess ġdid.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Inżommu dan l-apparat konness';

  @override
  String get key => 'Ewlenin';

  @override
  String get keyIsRequired => 'Iċ-ċavetta hija meħtieġa.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Pari ewlenin-valur li jippersistu matul konversazzjonijiet.';

  @override
  String get knowledgeGraph => 'Grafika tal-Għarfien';

  @override
  String get knowledgeView => 'Veduta tal-għarfien';

  @override
  String get labelOnlyYouSeeIt => 'Tikketta (tarah biss int)';

  @override
  String get labelsOptional => 'Tikketti (mhux obbligatorju)';

  @override
  String get last24Hours => 'L-aħħar 24 siegħa';

  @override
  String get last7Days => 'L-aħħar 7 ijiem';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'L-aħħar 7 ijiem: tokens $arg1 f\'ġirjiet $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'L-aħħar $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'L-aħħar: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'L-aħħar sinkronizzazzjoni mhux vojta · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'L-aħħar ġirja: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Dehru l-aħħar $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'L-aħħar dħul $arg1';
  }

  @override
  String get lastSyncSummary => 'L-aħħar Sommarju tas-Sinkronizzazzjoni';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'L-aħħar użat: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'L-aħħar tieqa ntemmet $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'aktar tard tibda mitfija wkoll.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'L-aħħar ġirja · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'It-tnedija ta\' apps tad-desktop mhix appoġġjata fuq din il-pjattaforma.';

  @override
  String get learnRoomNorms => 'Tgħallem in-normi tal-kamra';

  @override
  String get leave => 'Ħalli';

  @override
  String get leaveARedirectUriBlankTo =>
      'Ħalli Redirect URI vojt biex tuża <public URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Tħalli lit-tim ta’ $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Ħalli bħala default sakemm ma tkunx personalizzat BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Ħalli t-token vojt biex iżżomm it-token maħżun bħalissa.';

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
    return 'Ħalli $arg1 jimmaniġġjani';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Ħalli lil kulħadd f\'dan il-grupp jitkellem ma\' $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Ħalliha taħdem waqt\nli ma tagħmilx.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Ħalli lil NeoAgent tikklikkja, ittajpja u timxi fl-apps tiegħek.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Ħalli lil NeoAgent jifhem x\'inhu viżibbli fuq l-iskrin tiegħek.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Ħalli lil xi ħadd li taħdem miegħu jiddeċiedi liema għodod jista\' l-aġent tiegħek ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Ħalli lil din il-persuna tibgħat lil $arg1 messaġġ wieħed għal wieħed.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Ħalli lil din il-persuna titkellem ma\' $arg1 hawn, iżda mhux f\'chats privati ​​jew gruppi oħra.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Ħalli lil din il-persuna titkellem ma\' $arg1 f\'chats privati ​​u fi kwalunkwe grupp li jaqsam.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Livell $arg1/$arg2$arg3';
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
  String get linkCopied => 'Link ikkupjat';

  @override
  String get linkExpiresAfter => 'Il-link tiskadi wara';

  @override
  String get linkLifetimeHours => 'Ħajja tal-link (sigħat)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Il-ħajja tal-link għandha tkun minn 1 sa 8760 siegħa.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link valida sa $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Fornituri ta\' dħul konnessi';

  @override
  String get linuxApp => 'App Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Elenkat $arg1/';
  }

  @override
  String get listening => 'Smigħ';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Storja ta \'eżekuzzjoni diretta, passi tal-għodda, u tweġibiet.';

  @override
  String get liveModel => 'Mudell ħaj';

  @override
  String get liveModelProvider => 'Fornitur tal-mudell ħaj';

  @override
  String get liveRun => 'Live run';

  @override
  String get liveVoice => 'Vuċi ħaj';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Il-konnessjoni tal-vuċi diretta mhix disponibbli.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Il-konnessjoni tal-vuċi live ġiet magħluqa.';

  @override
  String get liveVoiceDefaults => 'Defaults tal-vuċi ħajjin';

  @override
  String get liveVoiceFailed => 'Il-vuċi live falliet.';

  @override
  String get llmMemoryExportResponse =>
      'Rispons għall-esportazzjoni tal-memorja LLM';

  @override
  String get loadFailed => 'tagħbija falliet';

  @override
  String get loadingExecutionDetails =>
      'Tagħbija d-dettalji tal-eżekuzzjoni...';

  @override
  String get loadingNeoagent => 'Tagħbija NeoAgent';

  @override
  String get loadingRunFlow => 'Tagħbija tal-fluss tal-ġirja...';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'L-URLs tan-netwerk lokali u privati huma appoġġjati meta s-server NeoAgent jista\' jilħaqhom. L-awdjo qatt ma huwa espost għal NeoAgent.';

  @override
  String get localApp => 'app lokali';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'L-installazzjoni backend lokali mhix disponibbli fuq din il-pjattaforma.';

  @override
  String get localBaseImagePath => 'Mogħdija tal-immaġni bażi lokali';

  @override
  String get localComputerControlIsAvailableIn =>
      'Il-kontroll lokali tal-kompjuter huwa disponibbli fl-app desktop NeoAgent fuq macOS, Windows u Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Il-kontroll lokali tal-kompjuter mhuwiex disponibbli hawn.';

  @override
  String get localModelsUrl => 'mudelli lokali url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'L-iskoperta ta\' NeoAgent lokali mhix disponibbli temporanjament.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Preferenzi lokali għall-applikazzjoni NeoAgent. Il-kontroll tal-kompjuter dejjem jgħaddi mill-kompjuter cloud unifikat.';

  @override
  String get localSetup => 'SETUP LOKALI';

  @override
  String get locationCityOrPlace => 'Post (belt jew post)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Il-post huwa meħtieġ għal avveniment tat-temp li jqajjem';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'L-inizjalizzazzjoni tas-Servizz Location falla: $arg1';
  }

  @override
  String get logCopied => 'Log ikkupjat';

  @override
  String get loginPassword => 'Login password';

  @override
  String get logout => 'Logout';

  @override
  String get logs => 'Zkuk';

  @override
  String get logsCopied => 'Zkuk kkupjati.';

  @override
  String get logsOnThisComputer => 'Zkuk fuq dan il-kompjuter';

  @override
  String get longLivedAccessToken => 'Token ta\' Aċċess għal ħajja twila';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Tifkir fit-tul, fatti strutturati, u graff tal-għarfien.';

  @override
  String get lookedAtTheScreen => 'Ħares lejn l-iskrin';

  @override
  String get lookingOnThisComputerAndYour =>
      'Qed tfittex fuq dan il-kompjuter u n-netwerk lokali tiegħek...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Tħares \'il quddiem lejn il-laqgħat ta\' għada biex xejn ma jissorprendik.';

  @override
  String get loopExecution => 'Eżekuzzjoni loop';

  @override
  String get loopPaused => 'Loop waqaf';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'Aċċessibilità macOS mhix mogħtija lil NeoAgent. Ħallih f\'Settings tas-Sistema › Privatezza u Sigurtà › Aċċessibilità.';

  @override
  String get macosApp => 'app macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'MacOS Screen Recording ma jingħatax lil NeoAgent. Ħallih f\'Settings tas-Sistema › Privatezza u Sigurtà › Reġistrazzjoni tal-Iskrin, imbagħad iftaħ mill-ġdid NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Is-servers tal-posta li jeħtieġu password se jirrifjutaw li jibagħtu sakemm tkun ġdida ';

  @override
  String get main => 'Prinċipali';

  @override
  String get makeDefault => 'Agħmel default';

  @override
  String get manage => 'Immaniġġja';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Immaniġġja l-email tal-kont tiegħek, awtentikazzjoni b\'żewġ fatturi, u sessjonijiet attivi.';

  @override
  String get managedBy => 'Immexxi minn';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Il-maniġers jista\' jkollhom maniġers tagħhom stess (sa erba\' livelli). A ';

  @override
  String get managing => 'Ġestjoni';

  @override
  String get manualDestination => 'Destinazzjoni manwali';

  @override
  String get manualTrigger => 'Trigger Manwal';

  @override
  String get masterPassword => 'Password prinċipali';

  @override
  String get matchThisDevice => 'Qabbel dan l-apparat';

  @override
  String get matchedAgainstTitleAndBody => 'Imqabbla mat-titlu u l-korp';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Taqbel mal-fluss NeoAgent MCP l-antik: URL flimkien mal-metodu awth.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'server MCP';

  @override
  String get mcpServer2 => 'MCP Server';

  @override
  String get mcpServerUrl => 'URL tas-Server MCP';

  @override
  String get mcpServers => 'servers MCP';

  @override
  String get meantForSomeoneElse => 'Maħsub għal xi ħadd ieħor';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Spiża tal-mudell imkejjel: $arg1';
  }

  @override
  String get memories => 'Memorji';

  @override
  String get memory => 'Memorja';

  @override
  String memoryArg1(Object? arg1) {
    return 'Memorja: $arg1';
  }

  @override
  String get memoryInjected => 'Memorja injettata';

  @override
  String get mentionOrReplyOnly => 'Semmi jew irrispondi biss';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Server magħquda u zkuk tar-runtime Flutter għal din is-sessjoni tal-app.';

  @override
  String get messageBodyTemplateJson => 'Mudell tal-korp tal-messaġġ (JSON)';

  @override
  String get messageNeedsAccess => 'Il-messaġġ jeħtieġ aċċess';

  @override
  String get messageTextField => 'Qasam tat-test tal-messaġġ';

  @override
  String get messaging => 'Messaġġi';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Avvenimenti push u webhook tal-API tal-messaġġi';

  @override
  String get messagingConnectionNeedsAttention =>
      'Il-konnessjoni tal-messaġġi teħtieġ attenzjoni';

  @override
  String get messagingConnections => 'Konnessjonijiet ta\' Messaġġi';

  @override
  String get messagingDelivery => 'Kunsinna ta\' messaġġi';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Żball tal-messaġġi. Jekk jogħġbok erġa\' pprova.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Il-qbid tal-mikrofonu waqaf bla mistenni. Erġa\' pprova.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Żball tal-mikrofonu: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofonu siekta. Tektek biex tneħħi l-mute.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Il-permess tal-mikrofonu huwa meħtieġ għal vuċi diretta.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Timijiet tal-Microsoft';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Valur tal-kontribuzzjoni minima: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Is-setup tal-mowbajl falla.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Is-setup tal-mowbajl falla minħabba li Java mhux disponibbli fuq il-magna li taħdem NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Is-setup tal-mowbajl falla minħabba li Java mhux disponibbli fuq il-magna li taħdem NeoAgent. Installa JDK u erġa\' pprova.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Is-setup tal-mowbajl falla. Iċċekkja li l-għodda Android hija installata b\'mod korrett u erġa\' pprova.';

  @override
  String modeArg1(Object? arg1) {
    return 'modalità: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Il-mod tissakkar waqt li ġirja tkun attiva.';

  @override
  String get model => 'Mudell';

  @override
  String modelArg1(Object? arg1) {
    return 'Mudell: $arg1';
  }

  @override
  String get modelAvailability => 'Disponibbiltà tal-mudell';

  @override
  String get autoEnableNewModels => 'Ippermetti awtomatikament mudelli ġodda';

  @override
  String get autoEnableNewModelsHint =>
      'Meta jkun mitfi, mudelli miżjuda aktar tard minn fornitur jibqgħu diżattivati sakemm inti tattivahom.';

  @override
  String get modelAvailabilitySaved => 'Disponibbiltà tal-mudell salvata.';

  @override
  String get modelForThisSession => 'Mudell għal din is-sessjoni';

  @override
  String get modelOverride => 'Mudell Override';

  @override
  String get modelPending => 'Mudell pendenti';

  @override
  String get modelTurn => 'Dawra tal-mudell';

  @override
  String get modelTurnCompleted => 'Dawra tal-mudell lesta';

  @override
  String get modelTurnStarted => 'Dawra tal-mudell bdiet';

  @override
  String get modelVisibilityHideShowList =>
      'viżibilità tal-mudell jaħbu lista juru';

  @override
  String get models => 'Mudelli';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Mudelli, imġieba, vuċi, u spazju tax-xogħol';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Mudelli, browser, vuċi, dijanjostika...';

  @override
  String get modelsRouting => 'Mudelli u rotta';

  @override
  String get monthly => 'Kull xahar';

  @override
  String get moreActions => 'Aktar azzjonijiet';

  @override
  String get morningBriefing => 'Briefing ta’ filgħodu';

  @override
  String get mostUsedAgents => 'L-aktar aġenti użati';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Mudelli l-aktar użati fl-aħħar $arg1.';
  }

  @override
  String get mouseKeyboard => 'Ġurdien u tastiera';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove mhux appoġġjat fuq din il-pjattaforma.';

  @override
  String get mustBeReachableOnThePublic =>
      'Għandhom ikunu aċċessibbli fuq l-internet pubbliku - lokali u ';

  @override
  String get n24Hours => '24 siegħa';

  @override
  String get n2faOrRecoveryCode => '2FA jew kodiċi ta \'rkupru';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA teħtieġ li SESSION_SECRET tiġi kkonfigurata fuq din l-iskjerament ta\' NeoAgent.';

  @override
  String get n30Days => '30 jum';

  @override
  String get n365Days => '365 jum';

  @override
  String get n4HourLimitTokens => 'Limitu ta\' 4 sigħat (tokens)';

  @override
  String get n4HourUsage => 'Użu ta \'4 sigħat';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4h limitu $arg1';
  }

  @override
  String get n7DayUsage => 'Użu ta \'7 ijiem';

  @override
  String get n7Days => '7 ijiem';

  @override
  String get n90Days => '90 jum';

  @override
  String get name => 'Isem';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nisem: Ħila Ġdida\ndeskrizzjoni: Iddeskrivi x\'tagħmel din il-ħila\n---\nIkteb l-istruzzjonijiet għal din is-sengħa hawn.\n';

  @override
  String get nameOfWhoeverMadeIt => 'isem min ghamilha.';

  @override
  String get nameOptional => 'Isem (mhux obbligatorju)';

  @override
  String get nativeAndWebhookChannels => 'Kanali indiġeni u webhook';

  @override
  String get naturalBubbles => 'Bżieżaq naturali';

  @override
  String get nearbyNeoagentServers => 'Servers NeoAgent fil-qrib';

  @override
  String get needANewAccountRegister => 'Għandek bżonn kont ġdid? Irreġistra';

  @override
  String get needAnIdea => 'Għandek bżonn idea?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Ħtieġa li twieġeb · $arg1% biex titkellem';
  }

  @override
  String get needsAttention => 'Jeħtieġ attenzjoni';

  @override
  String get needsInput => 'Jeħtieġ input';

  @override
  String get neoagentApp => 'App NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'Assistent NeoAgent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent ma setax jiċċekkja r-runtime backend disponibbli.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent ma setax itemm is-setup lokali.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent ma setax itemm is-setup lokali. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Informazzjoni dwar id-debug ta\' NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'Installatur tad-Desktop NeoAgent';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent jinstalla l-aħħar $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent huwa installat u qed jaħdem.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent mhuwiex installat fuq dan il-kompjuter.';

  @override
  String get neoagentIsReady => 'NeoAgent huwa lest';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent għadu jaħdem fuq kompitu. Ittemm is-sejħa u ikseb ir-riżultat fiċ-chat, jew ikkanċella l-kompitu wkoll.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent qed ibiddel id-dimostrazzjoni tiegħek fi fluss tax-xogħol adattabbli.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent qed jistenna waqt li tuża d-desktop.';

  @override
  String get neoagentIsWorking => 'NeoAgent qed jaħdem';

  @override
  String get neoagentLinuxComputer => 'NeoAgent kompjuter Linux';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT GĦANDU BŻONN DEĊIŻJONI';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'It-tniżżil ta\' runtime ta\' NeoAgent jeħtieġ indirizz sigur.';

  @override
  String get neoagentServerAddress => 'Indirizz tas-server NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'L-email tas-servizz NeoAgent mhix lesta. Staqsi lill-operatur tas-server biex jiċċekkja s-settings tal-ambjent tal-email.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Is-setup ta\' NeoAgent ma setgħetx tintemm.';

  @override
  String get neoagentUser => 'Utent NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent juża dan il-kompjuter awtomatikament u jistaqsi qabel ma juża l-iskrin, il-maws, it-tastiera, il-fajls jew il-linja tal-kmand tiegħek.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent juża l-post approssimattiv tiegħek fl-isfond biex iqajjem tfakkiriet tal-ġeofence (eż. \"Fakkruni biex nixtri l-ħalib meta ngħaddi mis-supermarket\").\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent Workspace';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][munzell] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall Backend URL';

  @override
  String get neorecallBackendUrlIsRequired =>
      'NeoRecall backend URL huwa meħtieġ.';

  @override
  String get neorecallSetup => 'Setup ta\' NeoRecall';

  @override
  String get networkRequestFailed => 'it-talba għan-netwerk falliet';

  @override
  String get networkWriteRequests => 'Talbiet tal-Kitba tan-Netwerk';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'qatt ma jgħodd mal-limiti tal-użu kondiviż.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Kontijiet ġodda jikkonfermaw l-indirizz elettroniku tagħhom qabel ma jidħlu.';

  @override
  String get newAccountsPerDay => 'Kontijiet ġodda kuljum';

  @override
  String get newChat => 'Chat ġdid';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Gruppi ġodda jibqgħu kwieti sakemm xi ħadd ma jittajjar $arg1, sakemm tixgħelhom.';
  }

  @override
  String get newLink => 'Link ġdid';

  @override
  String get newPasswordsDoNotMatch => 'Il-passwords ġodda ma jaqblux.';

  @override
  String get newRecoveryCodes => 'Kodiċi ta\' rkupru ġodda';

  @override
  String get newSession => 'Sessjoni ġdida';

  @override
  String get newSessionN => 'Sessjoni ġdida (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Sessjoni ġdida bl-istess setup';

  @override
  String get newSkill => 'Ħila ġdida';

  @override
  String get newSkill2 => 'Ħila Ġdida';

  @override
  String get newThisWeek => 'Ġdid din il-ġimgħa';

  @override
  String get newsDigest => 'Diġest tal-aħbarijiet';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Ipprova mill-ġdid li jmiss: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Nextcloud Login Flow';

  @override
  String get nextcloudSetup => 'Nextcloud Setup';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'URL Nextcloud';

  @override
  String get nextcloudUrlIsRequired => 'Nextcloud URL huwa meħtieġ.';

  @override
  String get nickname => 'Laqam';

  @override
  String get noAccountsConnectedYet => 'S\'issa l-ebda kont konness.';

  @override
  String get noAccountsFound => 'Ma nstab l-ebda kont.';

  @override
  String get noActiveSessionsFound => 'Ma nstabet l-ebda sessjoni attiva.';

  @override
  String get noAgentsYet => 'Għadu l-ebda aġenti';

  @override
  String get noAiProviderIsConfiguredSo =>
      'L-ebda fornitur AI mhu kkonfigurat, għalhekk chat u messaġġi ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'L-ebda approvazzjoni ma tħeġġeġ - l-aġent jaħdem mingħajr interruzzjoni.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'L-ebda assi ta\' rilaxx $arg1 ma qabbel ma\' din il-pjattaforma.';
  }

  @override
  String get noArguments => '(l-ebda argumenti)';

  @override
  String get noAuth => 'L-ebda awtorizzazzjoni';

  @override
  String get noBindingsYet => 'Għadu l-ebda rbit.';

  @override
  String get noChangesYet => 'Għadu l-ebda tibdil';

  @override
  String get noChannelsFound => 'Ma nstab l-ebda kanal';

  @override
  String get noCloudComputerSlotIsFree =>
      'L-ebda slot ta\' cloud-computer mhu b\'xejn bħalissa. Erġa\' pprova fi ftit mument.';

  @override
  String get noCoreMemoryEntriesYet =>
      'S\'issa l-ebda entrati tal-memorja ċentrali.';

  @override
  String get noDescription => 'L-ebda deskrizzjoni';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'L-ebda display tad-desktop mhu disponibbli bħalissa.';

  @override
  String get noDetailAvailable => 'Ebda dettall disponibbli';

  @override
  String get noDetailedSyncSummaryYet =>
      'S\'issa l-ebda sommarju dettaljat tas-sinkronizzazzjoni.';

  @override
  String get noDetailsCaptured => 'Ebda dettalji maqbuda.';

  @override
  String get noEmailLinked => 'Ebda email marbuta';

  @override
  String get noExternalSignInProvidersLinked =>
      'Ebda fornituri esterni ta\' sign-in ma huma konnessi.';

  @override
  String get noGroupMessagesYet => 'Għadu l-ebda messaġġ tal-grupp';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'L-ebda nies speċifiċi għall-grupp għadhom ma ġew miżjuda.';

  @override
  String get noGroupsAddedYet => 'L-ebda grupp għadu ma ġie miżjud.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Għadu ma nstab l-ebda grupp. Wara li $arg1 jara messaġġ tal-grupp, uża Sib chats riċenti u dawn jidhru hawn.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Għadu ma nstab l-ebda grupp. Wara li $arg1 jara messaġġ tal-grupp, uża Sib chats riċenti.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'L-ebda tagħbija tad-dejta tas-saħħa ma ġiet ritornata.';

  @override
  String get noHealthSamplesStoredYet =>
      'S\'issa ma nħażen l-ebda kampjun tas-saħħa.';

  @override
  String get noHttpClientImplementationForThis =>
      'L-ebda implimentazzjoni tal-klijent HTTP għal din il-pjattaforma.';

  @override
  String get noInputOrOutputWasRecorded =>
      'L-ebda input jew output ma ġie rreġistrat għal dan il-pass.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'L-ebda integrazzjoni ma taqbel ma\' din it-tfittxija.';

  @override
  String get noLimit => 'L-ebda limitu';

  @override
  String get noLocalPasswordIsSetYet =>
      'L-ebda password lokali għadha ma ġiet stabbilita. Oħloq waħda biex tippermetti l-utent/il-password sign-in.';

  @override
  String get noLogEntries => 'L-ebda daħliet fil-log.';

  @override
  String get noMatchingSettings => 'Ebda settings li jaqblu';

  @override
  String get noMcpServersMatchThisSearch =>
      'Ebda servers MCP ma jaqblu ma\' din it-tfittxija.';

  @override
  String get noMemoryEntriesFound => 'Ma nstabet l-ebda dħul tal-memorja.';

  @override
  String get noMemorySync => 'L-ebda sinkronizzazzjoni tal-memorja';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Jaqra darba waħda l-posta importanti u mibgħuta tal-aħħar 12-il xahar, biex l-aġent ikun jaf il-kuntatti u l-proġetti tiegħek.';

  @override
  String get emailMemory => 'Memorja tal-email';

  @override
  String get importNow => 'Importa issa';

  @override
  String get importOnConnect =>
      'Importa posta tal-passat meta tikkonnettja kont';

  @override
  String get sweepStarting => 'Qed jitħejja…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Qed jaqra l-emails · $done minn $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Qed jaqra l-emails · $count misjuba';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Qed jitgħallem mill-emails · $done minn $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'L-aħħar importazzjoni: $emails emails · $memories memorji ġodda';
  }

  @override
  String get sweepNothingNew => 'M\'hemmx emails ġodda x\'jiġu importati';

  @override
  String sweepFailed(String error) {
    return 'L-importazzjoni falliet: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'L-ebda mudell ma jaqbel ma\' \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Ma ġiet irreġistrata l-ebda talba mudell għal din il-ġirja.';

  @override
  String get noModelsDiscoveredYet => 'S\'issa ma nstab l-ebda mudelli';

  @override
  String get noModelsSelected => 'Ebda mudelli magħżula';

  @override
  String get noModelsYet => 'Għadu l-ebda mudelli';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'l-ebda kont neoagent mhu marbut ma\' dan il-fornitur';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'L-ebda runtime backend NeoAgent mhu disponibbli għal dan il-kompjuter.';

  @override
  String get noNetworkConnection => 'Ebda konnessjoni tan-netwerk';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Ebda konnessjoni tan-netwerk. Qabbad biex tkompli tuża NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Ebda konnessjoni tan-netwerk. Erġa\' qabbad biex tiċċekkja għal aġġornamenti.';

  @override
  String get noOne => 'Ħadd';

  @override
  String get noOneAddedYet => 'Ħadd għadu ma żied.';

  @override
  String get noOneCanMessage => 'Ħadd ma jista \'messaġġ';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Ma nstab l-ebda server NeoAgent ieħor. Tista\' terġa\' tfittex jew iddaħħal indirizz manwalment.';

  @override
  String get noPeopleAddedYet => 'L-ebda nies għadhom miżjuda.';

  @override
  String get noPlatformsMatch => 'L-ebda pjattaformi ma jaqblu';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'S\'issa l-ebda fornitur ma huwa disponibbli biex jiġi kkonfigurat.';

  @override
  String get noRecentChannelActivity => 'L-ebda attività tal-kanal riċenti';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Ebda riżultat għal \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Ebda runs f\'din il-medda.';

  @override
  String get noRunsMatchTheseFilters =>
      'L-ebda ġirja ma taqbel ma\' dawn il-filtri';

  @override
  String get noRunsYet => 'L-ebda ġirja għadha';

  @override
  String get noRunsYet2 => 'L-ebda ġirja għadha.';

  @override
  String get noSecurityKeyWasProvided =>
      'L-ebda ċavetta tas-sigurtà ma ġiet ipprovduta.';

  @override
  String get noServerUrlSet => 'L-ebda URL tas-server ma ssettjat';

  @override
  String get noSessionMatchesThatSearch =>
      'L-ebda sessjoni ma taqbel ma\' dik it-tfittxija.';

  @override
  String get noSessionsYet => 'Għadu l-ebda sessjoni';

  @override
  String get noSkillsMatchTheseFilters =>
      'L-ebda ħiliet ma jaqblu ma\' dawn il-filtri.';

  @override
  String get noStepsWereRecordedForThis =>
      'L-ebda passi ma ġew irreġistrati għal din il-ġirja.';

  @override
  String get noSummaryAvailable => 'Ebda sommarju disponibbli.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Ebda kompiti għal $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'L-ebda għodda ma taqbel \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Ebda aġġornament għaddej';

  @override
  String get noUsageYet => 'Għadu l-ebda użu.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'L-ebda runtime ta\' backend NeoAgent ivverifikat għadu disponibbli.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Ħadd ma jista\' jużaha aktar. Nies li diġà ngħaqdu ';

  @override
  String get none => 'Xejn';

  @override
  String get notApprovedYet => 'għadu mhux approvat';

  @override
  String get notAuthenticated => 'mhux awtentikati';

  @override
  String get notCheckedYet => 'Għadu mhux iċċekkjat';

  @override
  String get notConfigured => 'Mhux ikkonfigurat';

  @override
  String get notConnected => 'Mhux konnessi';

  @override
  String get notConnected2 => 'Mhux Konnessi';

  @override
  String get notInstalled => 'Mhux installat';

  @override
  String get notNeeded => 'Mhux meħtieġ';

  @override
  String get notNeededEnough => 'Mhux meħtieġ biżżejjed';

  @override
  String get notNow => 'Mhux issa';

  @override
  String get notNow2 => 'Mhux Issa';

  @override
  String get notSet => 'Mhux issettjat';

  @override
  String get notSetUp => 'Mhux imwaqqaf';

  @override
  String get notTheSameAsAdmin => 'Mhux l-istess bħal admin';

  @override
  String get nothingFound => 'Xejn misjub';

  @override
  String get nothingHereYet => 'S\'issa xejn hawn.';

  @override
  String get nothingHereYet2 => 'S\'issa xejn hawn';

  @override
  String get nothingMatches => 'Xejn jaqbel';

  @override
  String get nothingStoredYet => 'S\'issa xejn maħżun.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Nozzjoni, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'ID tal-Klijent OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth client id sigriet redirect api key';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth client id sigriet redirect gmail calendar drive';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'It-tnedija ta\' OAuth mhix appoġġata fuq din il-pjattaforma.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook kerrej klijent id sigriet';

  @override
  String get oauthToken => 'OAuth token';

  @override
  String get oauthWithPkce => 'OAuth ma PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'ta\' $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'tagħha stess. Qatt ma jerġa\' jintwera wara li jiġi salvat.';

  @override
  String get off => 'Mitfi';

  @override
  String get officialIntegration => 'Integrazzjoni uffiċjali';

  @override
  String get officialIntegrationDidNotReturnA =>
      'L-integrazzjoni uffiċjali ma rritornatx URL tal-konnessjoni.';

  @override
  String get on => 'Mixgħul';

  @override
  String get onASignedInAndroidDevice =>
      'Fuq apparat Android iffirmat, iftaħ Settings › Idħol u sigurtà, skennja dan il-kodiċi, u approva l-login.';

  @override
  String get onByDefaultForNewGroups =>
      'Ixgħel awtomatikament għal gruppi ġodda';

  @override
  String get onDemand => 'Fuq Talba';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Fuq għal $arg1 ta \'gruppi $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'fuq. Jistgħu jerġgħu jingħaqdu biss b\'rabta ġdida ta\' stedina.';

  @override
  String get onYourOwnTheDefault => 'Waħdek (id-default)';

  @override
  String get once => 'Darba';

  @override
  String get oneIsSavedOtherChangesIn =>
      'wieħed jiġi salvat. Bidliet oħra f\'din il-formola huma salvati wkoll.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Kont wieħed jew aktar skada. Erġa\' qabbad il-kont affettwat biex tirrestawra l-aċċess għall-għodda.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Runtime wieħed jikkontrolla l-persuna, it-teħid tad-dawran tal-grupp, il-memorja tal-kamra, in-normi, it-Teorija tal-Moħħ, u l-kunsinna.';

  @override
  String get oneTimeRun => 'Ġirja ta\' darba';

  @override
  String get onlyApkOrApksFilesCan =>
      'Jistgħu jiġu installati biss fajls .apk jew .apks.';

  @override
  String get onlyInThisGroup => 'F\'dan il-grupp biss';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Huwa meħtieġ biss jekk is-servizz jitlob għal headers HTTP żejda.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Huwa meħtieġ biss jekk trid issawwar mill-ġdid it-tagħbija li toħroġ.';

  @override
  String get onlyTheyCanChangeIt => 'Huma biss jistgħu jibdluha.';

  @override
  String get open => 'Miftuħa';

  @override
  String get openAccountSettingsOnASigned =>
      'Iftaħ Settings › Idħol u sigurtà fuq apparat Android iffirmat, skennja dan il-kodiċi, u approva l-login.';

  @override
  String get openComputer => 'Kompjuter miftuħ';

  @override
  String get openDashboard => 'Iftaħ dashboard';

  @override
  String get openFolder => 'Iftaħ folder...';

  @override
  String get openInWorkbench => 'Iftaħ fil-bank tax-xogħol';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Iftaħ NeoAgent u erġa\' qabbad $arg1 biex tirrestawra l-messaġġi.';
  }

  @override
  String get openTimeSettings => 'Iftaħ l-issettjar tal-ħin';

  @override
  String get openToAnyone => 'Miftuħ għal kulħadd';

  @override
  String get openTrello => 'Iftaħ Trello';

  @override
  String get openVoiceAssistant => 'Assistent tal-vuċi miftuħa';

  @override
  String get openWiFiSettings => 'Iftaħ is-settings tal-Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Iftaħ bl-app default';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'openai kompatibbli';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Endpoint kompatibbli mal-OpenAI (is-server tiegħek stess, jew ieħor ';

  @override
  String openedArg1(Object? arg1) {
    return 'Infetaħ $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Il-ftuħ tal-URLs tad-desktop mhuwiex appoġġjat fuq din il-pjattaforma.';

  @override
  String get openingYourSavedDesktop => 'Ftuħ id-desktop salvat tiegħek.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Ftuħ id-desktop salvat tiegħek. Il-bidu normali jieħu inqas minn 10 sekondi.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Sigriet addizzjonali mhux obbligatorju jekk tipproteġi l-webhook deħlin.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Iċċekkja fakultattiva jekk il-URL tal-webhook ma jkunx biżżejjed.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Sigriet fakultattiv biex tivverifika l-avvenimenti taċ-Chat deħlin.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Sigriet fakultattiv biex tivverifika l-avvenimenti li jkunu deħlin.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Sigriet fakultattiv biex tivverifika l-avvenimenti iMessage deħlin.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Sigriet mhux obbligatorju biex tivverifika l-avvenimenti LINE deħlin.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Sigriet fakultattiv biex tivverifika l-avvenimenti ta\' Mattermost li deħlin.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Sigriet fakultattiv biex tivverifika l-avvenimenti tat-Timijiet li jkunu deħlin.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Fakultattiv. L-aġent diġà għandu l-personalità tiegħu stess. Kull ħaġa li żżid dwar it-ton hija f\'saffi fuqu, sabiex qatt ma jkollok tiddefinixxi waħda.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Fakultattiv. Meta ssettjat, jintuża minflok il-URL.';

  @override
  String get orAnswerInYourOwnWords => 'Jew wieġeb fi kliemek';

  @override
  String get orBuildYourOwnTask => 'Jew ibni l-kompitu tiegħek stess';

  @override
  String get orContinueWith => 'jew kompli bih';

  @override
  String get orFiles => 'jew fajls.';

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
  String get originNotAllowed => 'oriġini mhux permessa';

  @override
  String get outgoingMessage => 'Messaġġ ħierġa';

  @override
  String get outgoingWebhookUrl => 'URL tal-webhook li joħroġ';

  @override
  String get outlookEmailReceived => 'Email Outlook Riċevut';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Ikteb fuq l-imġiba noti mill-importazzjoni.';

  @override
  String get ownModel => 'mudell proprju';

  @override
  String get packageName => 'Isem tal-pakkett';

  @override
  String get pairWithQrCode => 'Par mal-kodiċi QR';

  @override
  String get password => 'Password';

  @override
  String get password2faAndActiveSessions =>
      'Password, 2FA, u sessjonijiet attivi';

  @override
  String get passwordCreated => 'Password maħluqa.';

  @override
  String get passwordIsTooWeak => 'password hija dgħajfa wisq';

  @override
  String get passwordMin8 => 'password min 8';

  @override
  String get passwordOrApiKey => 'Password jew API key';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Saħħa tal-password: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Il-passwords ma jaqblux.';

  @override
  String get pasteAKey => 'Paste ċavetta.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Paste ċavetta ġdida biex tissostitwixxi $arg1';
  }

  @override
  String get pasteTheKey => 'Paste ċ-ċavetta';

  @override
  String get pasteYourAccountToken => 'Paste token tal-kont tiegħek';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Paste ċ-ċavetta API $arg1 tiegħek hawn taħt. Huwa ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'It-triq trid tibqa\' ġewwa NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'It-triq trid tibqa\' ġewwa l-folder tal-ispazju tax-xogħol.';

  @override
  String get pauseLiveUpdates => 'Waqqaf l-aġġornamenti ħajjin';

  @override
  String get pauseTaskLoop => 'Waqqaf il-linja tal-kompitu';

  @override
  String get paused => 'Waqfa qasira';

  @override
  String peakArg1(Object? arg1) {
    return 'quċċata $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Nies f\'chats privati';

  @override
  String get perAccountRateLimits => 'Limiti tar-rata għal kull kont';

  @override
  String get perCategoryPermissions => 'Permessi għal kull kategorija';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Politiki ta \'permessi għal kull għodda, gradi ta\' approvazzjoni, u iżolament tal-proċess għall-eżekuzzjoni tal-qoxra.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Permess meħtieġ: $arg1';
  }

  @override
  String get permissionsNeeded => 'Permessi meħtieġa';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Permessi. Ħadd ieħor ma jista’ jbiddel dan.';

  @override
  String get personOrChat => 'Persuna jew chat';

  @override
  String get personaBehaviorNotes => 'Noti tal-imġieba tal-persona';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Token ta\' aċċess personali għall-bot Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Kanali personali u uċuħ ta \'appoġġ dirett.';

  @override
  String get personalSelfChat => 'Awto-chat personali';

  @override
  String get phoneNumber => 'Numru tat-telefon';

  @override
  String get pickARunFromTheList =>
      'Agħżel ġirja mil-lista biex tara l-passi tagħha.';

  @override
  String get pickARunFromTheList2 =>
      'Agħżel ġirja mil-lista fuq ix-xellug biex tesplora l-fluss tagħha.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Agħżel minn $arg1 chats reċenti, jew żid persuna jew grupp lilek innifsek.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Agħżel kif $arg1 juża dan il-kont.';
  }

  @override
  String get pickOneToFillInThe =>
      'Agħżel waħda biex timla l-kompitu. Tista\' ttejjeb kollox wara.';

  @override
  String get picksUpWhereYouLeftOff => 'Jiġbor fejn ħallejt';

  @override
  String get plan => 'Pjan';

  @override
  String get planning => 'Ippjanar';

  @override
  String get platform => 'Pjattaforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Pjattaforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Jekk jogħġbok agħżel skeda.';

  @override
  String get pleaseEnterAFilename => 'Jekk jogħġbok daħħal isem tal-fajl.';

  @override
  String get pleaseEnterAKey => 'Jekk jogħġbok daħħal ċavetta.';

  @override
  String get pleaseEnterAPrompt => 'Jekk jogħġbok daħħal fil-pront.';

  @override
  String get pleaseEnterATaskName => 'Jekk jogħġbok daħħal isem tal-kompitu.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Jekk jogħġbok daħħal il-kontenut tal-memorja.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Jekk jogħġbok daħħal meta l-kompitu għandu jibda.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Jekk jogħġbok agħżel kont jew daħħal ID ta\' konnessjoni valida.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Ippunta NeoAgent fi kwalunkwe Tlestija ta\' Chat kompatibbli ma\' OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Ippunta l-kamera lejn il-kodiċi muri fuq l-apparat iffirmat. L-approvazzjoni tibqa\' fuq dan it-telefon.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env public url trust proxy secure cookies deployment';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Awtomazzjoni premium bi skeda u integrazzjoni li jqanqal.';

  @override
  String get prepareQrCode => 'Ipprepara kodiċi QR';

  @override
  String get preparingNeoagent => 'Nipprepara NeoAgent...';

  @override
  String get preparingNeoagent2 => 'Nipprepara NeoAgent';

  @override
  String get pressAndHoldForQuickCapture => 'Agħfas u żomm għal qbid malajr';

  @override
  String get pressKeysIsNotSupportedOn =>
      'istampa ċwievet mhix appoġġjata fuq din il-pjattaforma.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Ippressat $arg1';
  }

  @override
  String get priceUnknown => 'Prezz mhux magħruf';

  @override
  String get primaryDisplay => 'Wirja Primarja';

  @override
  String get privateChat => 'Chat privat';

  @override
  String get privateChats => 'Chats privati';

  @override
  String get privateChats2 => 'chats privati';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Chats privati: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Chats privati $arg1 · gruppi $arg2';
  }

  @override
  String get privateChatsOnly => 'Chats privati biss';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'indirizzi tan-netwerk privati mhumiex permessi.';

  @override
  String get profileEmailAndPersonalData => 'Profil, email, u data personali';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Prompt qabel NeoAgent jibqa residenti fit-trej tas-sistema.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Cache fil-pront: $arg1 tokens cached ';
  }

  @override
  String get promptCopied => 'Prompt ikkupjat.';

  @override
  String get promptOrSchedule => 'fil-pront jew skeda.';

  @override
  String get promptToPasteIntoAnotherAi => 'Prompt biex tippejstja f\'AI oħra';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Ir-rabta tal-fornitur ma setgħetx tinbeda.';

  @override
  String get providerSignInCouldNotBe =>
      'Id-dħul tal-fornitur ma setax jinbeda.';

  @override
  String get providers => 'Fornituri';

  @override
  String get providersEachAccountCanStillPick =>
      'Fornituri; kull kont xorta jista \'jagħżel il-mudell tiegħu stess fis-Settings. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Fornituri, integrazzjonijiet, vuċi, u kapaċitajiet fakultattivi jistgħu jitlestew minn Settings fi kwalunkwe ħin.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Ħjut pubbliċi tal-ħruġ u tal-ġibda, imwieġba biss għal nies approvati.';

  @override
  String get publicUrl => 'URL pubbliku';

  @override
  String get publicUrlAndAllowedOrigins => 'URL pubbliku u oriġini permessi';

  @override
  String get publicUrlOverride => 'Sostituzzjoni tal-URL pubbliku';

  @override
  String get pullsTogetherTheDayAhead => 'Jiġbed flimkien il-ġurnata li ġejja';

  @override
  String get pushToTalk => 'Imbotta biex titkellem';

  @override
  String get qrBasedPhoneLinking => 'Kollegament tat-telefon ibbażat fuq QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR login tlesta, iżda NeoAgent ma setax iżomm is-sessjoni. Jekk jogħġbok erġa\' pprova.';

  @override
  String get qrLoginCouldNotBeStarted => 'QR login ma setax jinbeda.';

  @override
  String get qrLoginRequestHasExpired => 'It-talba tal-login tal-qr skadiet';

  @override
  String get qrLoginRequestWasNotFound => 'Qr login talba ma nstabitx';

  @override
  String get qrPairing => 'QR Pairing';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'mistoqsijiet jitmexxew; kull ħaġa li tikteb tiġi miċħuda.';

  @override
  String get queryFilter => 'Mistoqsija / Iffiltra';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Fil-kju bħala istering għall-ġirja kurrenti: $arg1';
  }

  @override
  String get quickstart => 'Quickstart';

  @override
  String get quit => 'Nieqaf';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, wind_alert';

  @override
  String get ranAScriptInThePage => 'Mexxa script fil-paġna';

  @override
  String ranArg1(Object? arg1) {
    return 'Dam $arg1';
  }

  @override
  String get rateLimits => 'Limiti tar-rata';

  @override
  String get readAnArtifact => 'Aqra artifact';

  @override
  String get readAndEditFilesInsideYour =>
      'Aqra u editja l-fajls fil-folder tiegħek NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Aqra $arg1';
  }

  @override
  String get readError => 'Aqra żball';

  @override
  String get readFiles => 'Aqra l-fajls';

  @override
  String get readOnly => 'Aqra Biss';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Aqra l-folder u ġabar fil-qosor il-munzell, il-punti tad-dħul u kif tħaddem.';

  @override
  String get readThePage => 'Aqra l-paġna';

  @override
  String get readTheUiTree => 'Aqra s-siġra UI';

  @override
  String get readWrite => 'Aqra / Ikteb';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Jaqra passi, rata tal-qalb, irqad, eżerċizzju, u piż.';

  @override
  String get ready => 'Lest';

  @override
  String get readyForFirstTimeSetup => 'Lest għal setup għall-ewwel darba';

  @override
  String get readyToConnect => 'Lest biex jgħaqqad';

  @override
  String get recentChannelActivity => 'Attività Reċenti tal-Kanal';

  @override
  String get recentChats => 'Chats riċenti';

  @override
  String get recentDecisions => 'Deċiżjonijiet riċenti';

  @override
  String get recentFailedRuns => 'Runs falluti riċenti';

  @override
  String get recentGroupDecisions => 'Deċiżjonijiet riċenti tal-grupp';

  @override
  String get recentRuns => 'Ġirjiet riċenti';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Il-ġirjiet riċenti jieħdu madwar $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Output riċenti tas-server, l-aktar ġdid l-ewwel.';

  @override
  String get recentUsage4Hours => 'Użu Riċenti (4 Sigħat)';

  @override
  String get recents => 'Riċenti';

  @override
  String get recipientField => 'Il-qasam tar-riċevitur';

  @override
  String get reconnectOrFinishSetup => 'Erġa\' qabbad jew spiċċa s-setup';

  @override
  String get reconnectingThisDevice =>
      'Qiegħed jerġa\' jgħaqqad dan l-apparat...';

  @override
  String get recurring => 'Rikorrenti';

  @override
  String get redirectUri => 'URI mill-ġdid';

  @override
  String get redoOnboarding => 'Erġa\' jagħmel l-imbark';

  @override
  String get refresh => 'Aġġorna';

  @override
  String get refreshCode => 'Aġġorna l-kodiċi';

  @override
  String get refreshNow => 'Aġġorna issa';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Aġġorna l-iskrin tal-Android biex terġa\' tipprova.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Irrifjuta li tibgħat sakemm il-konnessjoni ma tittejjeb għal TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'irrispettivament mis-settings għal kull kategorija hawn taħt.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Irreġistra $arg1 għall-fluss ta \'taħrika tal-assistent.';
  }

  @override
  String get registrationIsClosed => 'ir-reġistrazzjoni hija magħluqa';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'reġistrazzjoni reġistru kontijiet ġodda jippermettu signup';

  @override
  String get rejectInvalidTlsCertificates =>
      'Irrifjuta ċertifikati TLS invalidi';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'rilaxx u jerġa \'jibda. Apps konnessi jerġgħu jikkonnettjaw ladarba tkun lura.';

  @override
  String get releaseChannel => 'Kanal tar-rilaxx';

  @override
  String get releaseCommitBranchNode => 'rilaxx node tal-fergħa tal-kommit';

  @override
  String get releaseWhenYouAreDone => 'Eħles meta tkun lest.';

  @override
  String get reloadNow => 'Reload issa';

  @override
  String get rememberThisChoice => 'Ftakar din l-għażla';

  @override
  String get remove => 'Neħħi';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Neħħi \"$arg1\" u l-passi rreġistrati tagħha mill-istorja tal-ġirja?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Neħħi \"$arg1\" mill-memorja ewlenija.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Neħħi ċ-ċavetta $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'neħħi ħassar l-utent tal-gdpr';

  @override
  String get removeSmtpPassword => 'Neħħi l-password SMTP';

  @override
  String get removeTheSmtpPassword => 'Neħħi l-password SMTP?';

  @override
  String get rename => 'Semmi mill-ġdid';

  @override
  String get renameSecurityKey => 'Semmi mill-ġdid iċ-ċavetta tas-sigurtà';

  @override
  String get renameSession => 'Semmi mill-ġdid';

  @override
  String get repairAndRetry => 'Tiswija u erġa\' pprova';

  @override
  String get repairDesktop => 'Tiswija desktop';

  @override
  String get repeat => 'Irrepeti';

  @override
  String get repliesWhenTagged => 'Risposti meta tagged';

  @override
  String get replyToAddress => 'Irrispondi-To address';

  @override
  String replyToArg1(Object? arg1) {
    return 'Irrispondi għal $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Ir-repożitorju għandu jkun fil-format sid/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Irriproduċi l-bug li niddeskrivi, sib il-kawża ewlenija u waħħalha b\'test ta \'rigressjoni.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'it-talba falliet b\'http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'It-talba falliet b\'HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Itlob il-permessi';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'It-talba lil $arg1 falliet qabel ma wieġeb il-backend.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return '$arg1 mitluba';
  }

  @override
  String get requireStarttls => 'Jeħtieġ STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Meħtieġa wara HTTPS jew proxy TLS. Japplika wara server ';

  @override
  String get requiredExampleBerlinDe => 'Meħtieġa. Eżempju: Berlin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Meħtieġa. Format: sid/repo';

  @override
  String get reserveAssistantHotkey => 'Riżerva hotkey assistent';

  @override
  String get reset => 'Irrisettja';

  @override
  String get resetPassword => 'Irrisettja l-password';

  @override
  String get resetView => 'Irrisettja l-vista';

  @override
  String get responsibilities => 'Responsabbiltajiet';

  @override
  String get restart => 'Ibda mill-ġdid';

  @override
  String get restartToFinishTheUpdate =>
      ' Ibda mill-ġdid biex jintemm l-aġġornament.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Ir-restawr tal-runtime NeoAgent preċedenti';

  @override
  String get restrictDelegationTargets => 'Irrestrinġi l-miri tad-delega';

  @override
  String get result => 'Riżultat';

  @override
  String get resultDelivery => 'Kunsinna tar-Riżultati';

  @override
  String get resultOneClickAddsOneYou =>
      'riżultat. Klikk waħda żżid waħda; tista teditjaha aktar tard.';

  @override
  String get results => 'Riżultati';

  @override
  String get retry => 'Ipprova mill-ġdid';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Jintuża mill-ġdid · użat $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Irrevedi bidliet mhux impenjati';

  @override
  String get revoke => 'Revoka';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Irrevoka l-amministratur b\'\'neoagent admin revoke $arg1\' l-ewwel';
  }

  @override
  String get revokeThisLink => 'Irrevoka din il-link?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Tieqa tal-lott tal-kamra: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Dawwar biex tkompli';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'ringieli. Żid LIMIT jew klawżola WHERE idjaq biex tara ';

  @override
  String get rule => 'Regola';

  @override
  String get run => 'Eżekuzzjoni';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Mexxi kmandi arbitrarji fuq il-magna jew il-VM tiegħek.';

  @override
  String get runAt => 'Mexxi Fuq';

  @override
  String get runCompleted => 'Mexxi mitmuma';

  @override
  String get runFailed => 'Run falliet';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Mexxi git diff, irrevedi l-bidliet mhux impenjati għal bugs u kwistjonijiet ta \'stil, u somma dak li ssib.';

  @override
  String get runNotFound => 'Mexxi ma nstabx';

  @override
  String get runNow => 'Esegwixxi issa';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Mexxi fuq messaġġi WhatsApp personali deħlin.';

  @override
  String get runQuery => 'Mexxi mistoqsija';

  @override
  String get runShellCommandsOrInstallApps =>
      'Mexxi kmandi tal-qoxra jew installa apps fuq it-tagħmir Android tiegħek.';

  @override
  String get runStarted => 'Il-ġirja bdiet';

  @override
  String get runStatus => 'Mexxi l-istatus';

  @override
  String get runStopped => 'Run waqfet';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Mexxi l-kmandi tat-terminal u tiftaħ apps jew paġni tal-web.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Mexxi dan is-server: kontijiet, aġġornamenti, fornituri, konfigurazzjoni ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Mexxi meta jasal messaġġ tal-Gmail li jaqbel.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Mexxi meta tasal email ta\' Outlook li taqbel.';

  @override
  String get runWhenANewIssueMatching =>
      'Mexxi meta tinfetaħ kwistjoni ġdida li taqbel mal-filtri tiegħek f\'repożitorju.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Mexxi meta tinħoloq memorja NeoRecall ġdida li taqbel mal-filtri tiegħek.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Mexxi meta tasal notifika fuq it-tagħmir tiegħek.';

  @override
  String get runWhenASlackMessageMatches =>
      'Mexxi meta messaġġ Slack jaqbel mal-ambitu magħżul.';

  @override
  String get runWhenATeamsChatMessage =>
      'Mexxi meta messaġġ taċ-chat tat-Timijiet jaqbel mal-ambitu magħżul.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Mexxi meta l-avvenimenti tat-temp konfigurati jkunu mbassra għal post.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'run. Filwaqt li kull mudell huwa mitfi, mudelli li l-fornituri jżidu ';

  @override
  String get running => 'Għaddej';

  @override
  String runningArg1(Object? arg1) {
    return 'Running $arg1';
  }

  @override
  String get runningTask => 'Kompitu tat-tmexxija';

  @override
  String get runningTool => 'Għodda tal-ġiri';

  @override
  String get runs => 'Eżekuzzjonijiet';

  @override
  String get runsEveryDayAtTheSelected => 'Tmexxi kuljum fil-ħin magħżul.';

  @override
  String get runsFourTimesPerHour => 'Runs erba \'darbiet fis-siegħa.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— ġirjiet, messaġġi, memorji, integrazzjonijiet, fajls u ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'runs, messaġġi, memorji, integrazzjonijiet, fajls u sessjonijiet. ';

  @override
  String get runsMondayThroughFriday => 'It-Tnejn sal-Ġimgħa.';

  @override
  String get runsOnSelectedWeekdays => 'Timxi fuq ġranet tal-ġimgħa magħżula.';

  @override
  String get runsOncePerHour => 'Jiġi darba fis-siegħa.';

  @override
  String get runsOncePerMonthOnThe => 'Tmexxi darba fix-xahar fil-jum magħżul.';

  @override
  String get runsOnlyWhenYouPressRun => 'Jiġi biss meta tagħfas Run Now.';

  @override
  String get runsPerDay => 'Runs kuljum';

  @override
  String get runsPerDay30Days => 'Runs kuljum (30 jum)';

  @override
  String get runsThatCompleted => 'Runs li kompletati';

  @override
  String get runsThisWeek => 'Runs din il-ġimgħa';

  @override
  String get runsToday => 'Jiġri llum';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Runs, għodod, memorja, skedar, ħiliet, u MCP huma kollha disponibbli hawn.';

  @override
  String get runsTwicePerHour => 'Runs darbtejn fis-siegħa.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Il-ġirjiet se jaqgħu lura għaċ-ċavetta tas-server kondiviża għal $arg1, jekk wieħed ikun ikkonfigurat. Dan ma jistax jitneħħa.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Runtime $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Runtime: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Is-settings tar-runtime dan is-server beda bihom. Editjahom taħt ';

  @override
  String get runtimeSetupRequired => 'Setup ta\' runtime meħtieġ';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Iċ-ċavetta pubblika tal-iffirmar tar-runtime għandha tkun 32 bytes.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Ħlief';

  @override
  String get saveATrelloApiKeyFor =>
      'Issejvja ċavetta Trello API għal dan l-aġent, imbagħad qabbad kont wieħed Trello b\'mod sigur. It-token tal-kont jinħażen fuq is-server u jintuża biss għal dan l-aġent.';

  @override
  String get saveAccount => 'Ħlief kont';

  @override
  String get saveChanges => 'Issejvja l-bidliet';

  @override
  String get saveCloudComputerSettings =>
      'Issejvja s-settings tal-kompjuter tas-sħab';

  @override
  String get saveConnect => 'Ħlief u Qabbad';

  @override
  String get saveDefaults => 'Ħlief defaults';

  @override
  String get saveDiagnosticReport => 'Ħlief rapport dijanjostiku';

  @override
  String get saveEmail => 'Issejvja l-email';

  @override
  String get saveEmailSettings => 'Issejvja s-settings tal-email';

  @override
  String get saveGeneralSettings => 'Issejvja s-settings ġenerali';

  @override
  String get saveName => 'Issejvja l-isem';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Issejvja d-dijanjostiċi tas-setup NeoAgent';

  @override
  String get saveOnly => 'Ħlief Biss';

  @override
  String get saveSetup => 'Ħlief Setup';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Issejvja dawn il-kodiċijiet ta \'rkupru issa. Mhux se jerġgħu jintwerew.';

  @override
  String get savedDeliveryDestination => 'Destinazzjoni tal-kunsinna salvata';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Limiti tar-rata salvati għal @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Skennja QR tal-login ta\' NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Skennja NeoAgent li jgħaqqad QR minn apparat ieħor u approvah minn din is-sessjoni tal-lanċjar.';

  @override
  String get scanLoginQr => 'Skennja login QR';

  @override
  String get scanPairingQr => 'Skennja tqabbil QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Skennja t-talbiet tal-login tal-QR minn apparati li ġew iffirmati u approvahom minn din is-sessjoni mobbli awtentikata.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Skennja biex tispiċċa $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Skennja ma\' NeoAgent fuq it-telefon tiegħek';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Skennja email ġdid u jagħtik ping biss meta xi ħaġa tkun importanti.';

  @override
  String get schedule => 'Skeda';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'ħin skedat. Ladarba jitkejlu l-ġirjiet, dan jibda qabel.';

  @override
  String get screen => 'Skrin';

  @override
  String get screenAction => 'azzjoni fuq l-iskrin';

  @override
  String get scrollIsNotSupportedOnThis =>
      'iscroll mhuwiex appoġġjat fuq din il-pjattaforma.';

  @override
  String get scrollToBottom => 'Skrollja għall-qiegħ';

  @override
  String get search => 'Fittex';

  @override
  String get search2 => 'Fittex...';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Fittex is-settings tal-amministratur (eż. SMTP, Ollama, zkuk)';

  @override
  String get searchAgain => 'Erġa\' fittex';

  @override
  String get searchByUsernameOrEmail => 'Fittex bl-isem tal-utent jew bl-email';

  @override
  String get searchChannels => 'Fittex kanali';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Fittex skoperti kanali ta \'messaġġi, kuntatti, gruppi, u konversazzjonijiet riċenti.';

  @override
  String get searchGroups => 'Fittex gruppi';

  @override
  String get searchMemory => 'Fittex memorja';

  @override
  String get searchModelsOrProviders => 'Fittex mudelli jew fornituri';

  @override
  String get searchModelsOrProviders2 => 'Fittex mudelli jew fornituri...';

  @override
  String get searchRecentPeopleAndGroups => 'Fittex nies u gruppi riċenti';

  @override
  String get searchSessions => 'Sessjonijiet ta\' tfittxija';

  @override
  String get searchSettings => 'Fittex settings';

  @override
  String get searchTitleModelTriggerRunId =>
      'Fittex titolu, mudell, grillu, run ID';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Fittex għodod, integrazzjoni, u ħiliet';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Kodiċi mfittxija għal \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Fajls imfittxija għal \"$arg1\"';
  }

  @override
  String get secretField => 'Qasam sigriet';

  @override
  String get secureCookies => 'Cookies siguri';

  @override
  String get security => 'Sigurtà';

  @override
  String get securityKey => 'Ċavetta tas-sigurtà';

  @override
  String get securityKeyPromptWasDismissed =>
      'Il-pront taċ-ċavetta tas-sigurtà ġiet miċħuda.';

  @override
  String get securityKeySignInCompletedBut =>
      'Id-dħul taċ-ċavetta tas-sigurtà tlesta, iżda NeoAgent ma setax iżomm is-sessjoni tal-browser. Jekk jogħġbok idħol mill-ġdid.';

  @override
  String get securityKeySignInCouldNot =>
      'Id-dħul taċ-ċavetta tas-sigurtà ma setax jinbeda.';

  @override
  String get securityKeys => 'Ċwievet tas-sigurtà';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Iċ-ċwievet tas-sigurtà huma disponibbli biss fl-app web NeoAgent.';

  @override
  String get seeAll => 'Ara kollha';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Ara liema server NeoAgent tuża din it-tieqa, u ħaddem il-backend fuq dan il-kompjuter.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'ara l-isem tal-utent tiegħek u dawn is-settings, qatt iċ-chats, il-memorji tiegħek ';

  @override
  String get selectARun => 'Agħżel ġirja';

  @override
  String get selectASessionToSeeIts =>
      'Agħżel sessjoni biex tara l-kompjuter, il-fajls u l-bidliet tagħha.';

  @override
  String get selectAll => 'Agħżel kollha';

  @override
  String get selectAll2 => 'Agħżel Kollha';

  @override
  String selectArg1(Object? arg1) {
    return 'Agħżel $arg1';
  }

  @override
  String get selectTrigger => 'Agħżel Trigger';

  @override
  String get send => 'Ibgħat (⌘↵)';

  @override
  String get send2 => 'Ibgħat';

  @override
  String get sendATaskFromChatAnd =>
      'Ibgħat kompitu miċ-chat u l-istorja tal-eżekuzzjoni tagħha tidher hawn.';

  @override
  String get sendItToATeammateWith =>
      'ibgħatha lil sieħbu b\'kont fuq dan is-server.';

  @override
  String get sendLink => 'Ibgħat link';

  @override
  String get sendPath => 'Ibgħat mogħdija';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Ibgħat talbiet POST/PUT/DELETE lil APIs esterni.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Ibgħat din il-link biss lill-persuna li għaliha hija maħsuba. Jiġi muri darba; ';

  @override
  String get senderAddress => 'Indirizz tal-mittent';

  @override
  String get senderFilterOptional => 'Filtru mittenti (mhux obbligatorju)';

  @override
  String get sentSharedAttachments => 'Mibgħuta attachments kondiviżi.';

  @override
  String get separateAccount => 'Kont separat';

  @override
  String get server => 'Server';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Server default ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Server defaults għal sejħiet bil-vuċi fl-app. Sejħiet jimxu fuq live ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'server innifsu: kontijiet, fornituri u konfigurazzjoni.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, laqa, kanal, u TLS fakultattiv';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'server output console twissijiet żbalji kopja';

  @override
  String get serverProviderCredentials => 'Kredenzjali tal-fornitur tas-server';

  @override
  String get serverUrl => 'URL tas-server';

  @override
  String get serverUsageLimitsDonTApply =>
      'Il-limiti tal-użu tas-server ma japplikawx għal mudelli li jaħdmu fuq iċ-ċavetta tiegħek stess.';

  @override
  String get serviceEmail => 'Email tas-servizz';

  @override
  String get serviceEmailIsNotConfigured =>
      'email tas-servizz mhux ikkonfigurat';

  @override
  String get serviceEmailSmtp => 'Email tas-servizz (SMTP)';

  @override
  String get sessionActions => 'Azzjonijiet tas-sessjoni';

  @override
  String get sessions => 'Sessjonijiet';

  @override
  String get sessions2 => 'SESSJONIJIET';

  @override
  String get sessionsArePinnedToAFolder =>
      'Is-sessjonijiet huma pinnjati ma \'folder u kompjuter. Ibda waħda biex tippjana, tibni, tittestja u tbgħat minn hawn.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sessjonijiet (GDPR Art. 17). Il-kontijiet tal-amministrazzjoni ma jistgħux jitħassru ';

  @override
  String get sessionsLogoutRevokeForce =>
      'sessjonijiet logout jirrevokaw forza';

  @override
  String get setBlockAskAllowPerTool =>
      'Issettja blokk / staqsi / jippermettu għal kull kategorija ta \'għodda, jew agħżel modalità globali.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Stabbilixxi NeoAgent fuq dan il-kompjuter';

  @override
  String get setUpOrConnectNeoagent => 'Twaqqaf jew qabbad NeoAgent';

  @override
  String get setUrl => 'Issettja l-URL';

  @override
  String get settings => 'Settings';

  @override
  String get settingsAndCannotBeUndone => 'settings u ma jistax jitneħħa.';

  @override
  String get settingsArea => 'Żona tas-settings';

  @override
  String get settingsAreas => 'Żoni ta\' settings';

  @override
  String get setup => 'Setup';

  @override
  String get setupDetails => 'Dettalji tas-setup';

  @override
  String get setupRequired => 'Setup Meħtieġa';

  @override
  String get setupWasCancelled => 'Is-setup ġie kkanċellat.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Annessi kondiviżi mill-klijent NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Maqsuma minn app oħra';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Iċ-ċwievet tal-fornitur kondiviżi huma kkonfigurati fuq is-server. Biex tuża ċ-ċavetta API tiegħek stess jew endpoint personalizzat minflok, mur Avvanzata → Ġib iċ-ċavetta tiegħek stess.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Maqsuma maċ-chat NeoAgent u l-memorja tiegħu.';

  @override
  String get shellCommands => 'Kmandi tal-qoxra';

  @override
  String showAllArg1(Object? arg1) {
    return 'Uri kollha $arg1';
  }

  @override
  String get showEarlier => 'Uri qabel';

  @override
  String get showEveryStep => 'Uri kull pass';

  @override
  String get showTools => 'Uri għodod';

  @override
  String get showWorkbenchJ => 'Uri bank tax-xogħol (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Li juri l-ewwel $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Jintwera fil-sidebar. Ħalli vojt biex tuża l-isem tal-utent tiegħek.';

  @override
  String get signIn => 'Idħol';

  @override
  String get signInCompletedButNeoagentCould =>
      'Id-dħul tlesta, iżda NeoAgent ma setax iżomm is-sessjoni tal-browser. Jekk jogħġbok idħol mill-ġdid. Jekk dan ikompli jiġri, iċċekkja s-settings tal-cookie tas-sessjoni backend.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Id-dħul tlesta, iżda NeoAgent ma setax iżomm is-sessjoni tal-browser. Jekk jogħġbok idħol mill-ġdid. Jekk dan ikompli jiġri, il-cookie tas-sessjoni backend x\'aktarx ma tinżammx.';

  @override
  String get signInToThisNeoagentServer =>
      'Idħol f\'dan is-server NeoAgent qabel tiskennja kodiċi QR ta\' tqabbil.';

  @override
  String get signInWithAHardwareKey =>
      'Idħol b\'ċavetta tal-ħardwer jew passkey minflok il-password tiegħek. ';

  @override
  String get signInWithASecurityKey => 'Idħol b\'ċavetta tas-sigurtà';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Idħol ma\' $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Approva NeoAgent fil-kont $arg1 tiegħek. L-ebda ċavetta biex tikkopja.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Stennija għal $arg1. Lesti fil-browser tiegħek.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Paste l-kodiċi $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Wara li approvajt NeoAgent, $arg1 wera kodiċi ta \'darba. Pasteha hawn.';
  }

  @override
  String get signInCode => 'Kodiċi ta\' dħul';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Iffirmat ma\' $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Id-dħul falla: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Idħol bl-istess email u password prinċipali li tuża f\'Bitwarden. Il-password prinċipali u l-kodiċi f\'żewġ stadji jintużaw biss għall-utent u qatt ma jinħażnu jew jintbagħtu lill-AI.';

  @override
  String get signOut => 'Iffirma';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Iffirma @$arg1 kullimkien?';
  }

  @override
  String get signOutEverywhere => 'Iffirma kullimkien';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API pont';

  @override
  String get signalCliServerUrl => 'URL tas-server signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Iffirmat @$arg1 minn kull sessjoni.';
  }

  @override
  String get signedInDevices => 'Apparat iffirmat';

  @override
  String get signedInWithin24Hours => 'Iffirmat fi żmien 24 siegħa';

  @override
  String get signingSecret => 'Iffirmar sigriet';

  @override
  String sinceArg1(Object? arg1) {
    return 'Peress $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'peress $arg1';
  }

  @override
  String get singleMessage => 'Messaġġ wieħed';

  @override
  String get singleUse => 'Użu wieħed';

  @override
  String get skill => 'Ħila';

  @override
  String get skillChanges => 'Bidliet fil-Ħiliet';

  @override
  String get skillContent => 'Kontenut tal-Ħiliet';

  @override
  String get skills => 'Ħiliet';

  @override
  String get skip => 'Aqbeż';

  @override
  String get skipForNow => 'Aqbeż għalissa';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Aqbeż dan il-kompitu qabel ma jsejjaħ il-mudell.';

  @override
  String get slackMessageReceived => 'Messaġġ Slack Riċevut';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Sleep $arg1 sessjonijiet';
  }

  @override
  String get smartSelector => 'selettur intelliġenti';

  @override
  String get smartSelector2 => 'Selettur intelliġenti';

  @override
  String get smartSelectorPool => 'Pool Selettur Intelliġenti';

  @override
  String get smtpHost => 'Ospitanti SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp mail sender password tls konferma notifiki reset';

  @override
  String get smtpPassword => 'Password SMTP';

  @override
  String get smtpPort => 'Port SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'Il-port SMTP għandu jkun numru sħiħ minn 1 sa 65535.';

  @override
  String get smtpUsername => 'Isem tal-utent SMTP';

  @override
  String get soTheRunStartsThatMuch => 'hekk il-ġirja tibda li ħafna qabel.';

  @override
  String get socialBehaviorOff => 'Imġieba soċjali off';

  @override
  String get socialIntelligence => 'intelliġenza soċjali';

  @override
  String get socialIntelligence2 => 'Intelliġenza soċjali';

  @override
  String get socialObservability => 'Osservabbiltà soċjali';

  @override
  String get socialReach => 'firxa soċjali';

  @override
  String get socialReach2 => 'Laqgħa soċjali';

  @override
  String get socialReach3 => 'Reach Soċjali';

  @override
  String get socialReachUpdated => 'Social Reach aġġornat.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'L-aġenti tas-sorsi soċjali jistgħu jaqraw direttament, inklużi għalf, repożitorji, Reddit, X, vidjows, u data tas-suq sostnuta minn cookie.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Xi ħaġa marret ħażin. Jekk jogħġbok erġa\' pprova.';

  @override
  String get source => 'Sors';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Spazju jew chat ID użat meta dan l-aġent jibda konversazzjoni.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Appoġġ għall-webhook tal-ispazju u callback tal-app';

  @override
  String get speaking => 'Taħdit';

  @override
  String get speechToSpeechModelUsingThe =>
      'mudell ta \'diskors għal diskors bl-użu taċ-ċavetta OpenAI jew Google taħt ';

  @override
  String get speechToText => 'Diskors għal test';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Speech-to-test jittraskrivi noti tal-vuċi u dettatura. Auto juża OpenAI, Gemini jew Deepgram, liema minnhom għandu ċavetta API. Il-mudell tat-tweġiba tal-vuċi huwa l-mudell taċ-chat li jwieġeb in-noti tal-vuċi.';

  @override
  String get sqlConsole => 'SQL console';

  @override
  String get stable => 'Stabbli';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stabbli jinstalla l-aħħar rilaxx backend ippubblikat.';

  @override
  String get stackTrace => 'traċċa munzell';

  @override
  String get standard => 'Standard';

  @override
  String get standardView => 'Veduta standard';

  @override
  String get start => 'Ibda';

  @override
  String get startASessionToPlanOr =>
      'Ibda sessjoni biex tippjana jew tibni b\'NeoAgent.';

  @override
  String get startAndroid => 'Ibda Android';

  @override
  String get startComputer => 'Ibda l-kompjuter';

  @override
  String get startFullSetup => 'Ibda setup sħiħ';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Ibda s-setup';

  @override
  String get startTalking => 'Ibda tkellem';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Ibda t-telefon Android l-ewwel, imbagħad waqqa \'fajl .apk jew .apks hawn.';

  @override
  String get startTheServerLaterFromThe =>
      'Ibda s-server aktar tard mil-lista ladarba l-konfigurazzjoni tiġi ssejvjata.';

  @override
  String get startWithARecommendedTask => 'Ibda b\'kompitu rakkomandat';

  @override
  String get startingAndroid => 'Jibda Android';

  @override
  String get startingYourComputer => 'Tibda l-kompjuter tiegħek';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Jibda b\'xoxb-. Mill-kredenzjali tal-app Slack tiegħek.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting Żball: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'stats runs tokens utenti charts rata ta \'suċċess';

  @override
  String get status => 'Status';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'status database runtime fornituri vm';

  @override
  String get statusIsNotLoadedYet => 'L-istatus għadu mhux mgħobbi.';

  @override
  String get stayManagedByYou => 'tibqa mmexxija minnek.';

  @override
  String get stayOnTheCall => 'Ibqa \'fuq is-sejħa';

  @override
  String get stayedQuiet => 'Bqajt kwiet';

  @override
  String get steering => 'TIMMANU';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'PASS $arg1 TA\' $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Passi $arg1';
  }

  @override
  String get stop => 'Waqqaf';

  @override
  String get stop2 => 'Waqqaf (⌘.)';

  @override
  String get stopManaging => 'Waqqaf il-ġestjoni';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Tieqaf timmaniġġja $arg1?';
  }

  @override
  String get stopRun => 'Stop run';

  @override
  String get stopSpeaking => 'Tieqaf titkellem';

  @override
  String get stoppedBeforeCompletion => 'Waqfet qabel it-tlestija';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting Żball: $arg1';
  }

  @override
  String get storage => 'Ħażna';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'maħżuna kriptata u użata biss għall-ġirjiet tiegħek.';

  @override
  String get storedMetrics => 'Metriċi Maħżuna';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Jaħżen biss iċ-ċavetta tas-sessjoni Bitwarden encrypted fuq dan is-server, sabiex il-konnessjonijiet jibqgħu ħajjin. Tista\' tissakkarha fi kwalunkwe ħin.';

  @override
  String get strong => 'Qawwija';

  @override
  String get strongPassword => 'Password b\'saħħitha.';

  @override
  String get subAgent => 'Sotto-aġent';

  @override
  String get subagentUpdate => 'Aġġornament tas-subaġent';

  @override
  String get subagentUpdate2 => 'Aġġornament tas-subaġent.';

  @override
  String get successRate => 'Rata ta\' suċċess';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Suġġerimenti: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Fil-qosor l-aħħar ġirja tiegħi';

  @override
  String get supportUrl => 'Appoġġ URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Appoġġjati: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Aġent tal-iswiċċ';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Ir-rabtiet simboliċi mhumiex permessi fil-mogħdijiet ta\' NeoAgent Workspace.';

  @override
  String get syncNow => 'Issinkronizza issa';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'Issettjar tal-privatezza tas-sistema';

  @override
  String get tableInfoUsers => 'Informazzjoni fuq it-tabella (utenti)';

  @override
  String get tagsOnly => 'Tikketti biss';

  @override
  String get tasks => 'Kompiti';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Kompiti jimxu waħedhom u l-messaġġ inti bil- ';

  @override
  String get teach => 'Jgħallmu';

  @override
  String get teachingInProgress => 'Tagħlim għaddej';

  @override
  String get team => 'Tim';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Il-links tat-tim qatt ma jagħmlu lil ħadd admin tas-server. L-amministraturi jmexxu l- ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Spazji tat-tim, kmamar, kanali, u komunitajiet ħajjin.';

  @override
  String get teamsMessageReceived => 'Messaġġ tat-Timijiet Riċevut';

  @override
  String get templates => 'Mudelli';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Fajls tas-setup temporanji se jitnaddfu aktar tard.';

  @override
  String get tenantId => 'ID tal-kerrej';

  @override
  String get testConnection => 'Konnessjoni tat-test';

  @override
  String get testConnection2 => 'Konnessjoni tat-Test';

  @override
  String get textChat => 'Test u Chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'li żiedu ċ-ċavetta tagħhom stess jibqgħu jużawha.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Dik l-email diġà tappartjeni għal kont eżistenti. Idħol l-ewwel, imbagħad għaqqad lil Google mis-settings tal-kont.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Dik l-email diġà hija marbuta ma\' kont ieħor.';

  @override
  String get thatQrCodeIsNotA =>
      'Dak il-kodiċi QR mhuwiex talba għall-login ta\' NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Dak il-kodiċi QR mhuwiex talba ta\' pairing NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Dik iċ-ċavetta tas-sigurtà hija diġà rreġistrata fuq dan il-kont.';

  @override
  String get theAddress => 'L-indirizz';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'L-indirizz tas-server BlueBubbles tiegħek.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'L-indirizz li n-nies u l-fornituri OAuth jużaw biex jilħqu ';

  @override
  String get theAgentReadsTimesYouMention =>
      'L-aġent jaqra l-ħinijiet li ssemmi, u jmexxi kompiti skedati, f\'din iż-żona tal-ħin.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'L-aġent jistaqsi qabel kull għodda sensittiva, ';

  @override
  String get theAgentWillIgnoreThisSkill => 'L-aġent se jinjora din il-ħila.';

  @override
  String get theAppCouldNotReachThis =>
      'L-app ma setgħetx tilħaq dan l-iskjerament ta\' NeoAgent. Iċċekkja l-konnessjoni tan-netwerk tiegħek jew ikkonferma li l-URL tas-servizz huwa korrett.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Il-browser imblokka talba lil $arg1 minħabba l-Politika tas-Sigurtà tal-Kontenut.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Il-browser imblokka talba meħtieġa minħabba l-Politika tas-Sigurtà tal-Kontenut.';

  @override
  String get theCloudWorkspace => 'l-ispazju tax-xogħol tas-sħab';

  @override
  String get theComputerCouldNotStart => 'Il-kompjuter ma setax jibda';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Il-kompjuter jeħtieġ aktar spazju ħieles fuq id-diska fuq il-host NeoAgent. Eħles ftit spazju, imbagħad erġa\' pprova.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Ir-runtime tal-kompjuter jeħtieġ tiswija. Mexxi NeoAgent Doctor, imbagħad erġa\' pprova.';

  @override
  String get theConnectionTestFailed => 'It-test tal-konnessjoni falla.';

  @override
  String get theDesktopDidNotStart => 'Id-desktop ma bediex';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'In-NeoAgent skopert irritorna dejta tal-identità mhux kompluta.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'In-NeoAgent skopert juża protokoll ta\' setup mhux appoġġjat.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Is-servizz skopert mhuwiex NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Ir-runtime NeoAgent imniżżel ma għaddax mill-verifika.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Il-webhook tal-ispazju tal-Google Chat li dan l-aġent għandu jippubblika fih.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'L-installatur m\'għadux disponibbli.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Id-desktop interattiv tal-Linux huwa disponibbli fl-app web NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'L-introduzzjoni mhix disponibbli fuq dan l-apparat.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'L-aħħar runs madwar kull kont.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'L-aħħar tieqa tas-sinkronizzazzjoni ntemmet $arg1 u ma sabet l-ebda rekord ġdid ta’ Health Connect. Il-metriċi maħżuna hawn taħt ġew minn sinkronizzazzjonijiet preċedenti.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Is-sessjoni grafika Linux mhix qed taħdem.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Il-mudell tal-vuċi ħaj ma weġibx. Erġa\' pprova.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Il-kmand NeoAgent lokali ħareġ bil-kodiċi $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Il-kmand NeoAgent lokali skada l-ħin.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Ir-runtime NeoAgent lokali jeħtieġ tiswija.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Ir-runtime lokali jeħtieġ tiswija ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Id-direttorju tad-dar tal-utent lokali mhuwiex disponibbli.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Il-kont tal-posta NeoAgent jibgħat konfermi ta \'reġistrazzjoni, sign-in ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'L-aġent prinċipali jinħoloq awtomatikament meta jkun meħtieġ.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Ir-runtime ta\' NeoAgent li jaqbel huwa nieqes minn din ir-rilaxx.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Il-webhook deħlin ta\' Mattermost li dan l-aġent għandu jippubblika fih.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Il-mudelli s-Smart Selector imur bejniethom awtomatikament.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'It-tniżżil tal-backend ta\' NeoAgent ma kienx jaqbel mal-manifest tiegħu.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'It-tniżżil ta\' backend ta\' NeoAgent ma kienx komplut.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Il-backend NeoAgent fuq dan il-kompjuter mhux qed iwieġeb fuq il-port ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Ir-runtime backend NeoAgent ma setax jitniżżel.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Il-backend NeoAgent dam wisq biex iwieġeb għal $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'L-iskjerament NeoAgent wieġeb b\'HTTP 402 minflok l-401 normali għal kredenzjali invalidi. Iċċekkja reverse-proxy, awth gateway, jew regoli relatati mal-ħlas fuq dak is-server.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'L-iskjerament NeoAgent wieġeb b\'HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'L-iskjerament ta\' NeoAgent wieġeb b\'HTTP 402. Iċċekkja r-regoli reverse-proxy, awth gateway, jew relatati mal-ħlas fuq dak is-server.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'L-istanza NeoAgent din l-app hija konnessa magħha.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Is-servizz tar-rilaxx NeoAgent irritorna data invalida.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Il-metadata tal-artifact runtime ta\' NeoAgent hija invalida.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Il-manifest runtime NeoAgent ma għaddax il-verifika tal-firma.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Il-manifest runtime NeoAgent m\'għandux artifacts.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Il-firma tal-manifest ta\' runtime ta\' NeoAgent mhijiex valida.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Il-password li ssettjajt fil-BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'In-nies li timmaniġġja jibqgħu miegħek.';

  @override
  String get theProviderAnswers => 'il-fornitur iwieġeb.';

  @override
  String get theQueryReturnedNoRows =>
      'Il-mistoqsija ma rritornat l-ebda ringieli.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Il-wiri tad-desktop mitlub mhuwiex disponibbli.';

  @override
  String get theRest => 'il-bqija.';

  @override
  String get theRestEndpointForYourSignal =>
      'L-endpoint REST għall-istanza ta\' signal-cli tiegħek.';

  @override
  String get theRunIsPausedUntilYou => 'Il-ġirja titwaqqaf sakemm twieġeb.';

  @override
  String get theRunStartsAtTheScheduled => 'Il-ġirja tibda fil-ħin skedat.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Ir-runtime huwa desktop Debian Linux ħafif bi Chromium, PCManFM, Mousepad, LXTerminal, Python, Git, u għodod standard tal-linja tal-kmand. Il-kapaċità tagħha hija ġestita mill-host NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Ir-reġistrazzjoni taċ-ċavetta tas-sigurtà ma setgħetx tinbeda.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'is-server iżomm biss marki tas-swaba\' minnu.';

  @override
  String get theServerOnThisComputerIs =>
      'Is-server fuq dan il-kompjuter mhux qed jaħdem';

  @override
  String get theServerReportedNoHealthChecks =>
      'Is-server ma rrapporta l-ebda kontrolli tas-saħħa.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'In-numru tat-telefon tas-Sinjal li juża dan il-bot.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Il-webhook deħlin tat-Timijiet li dan l-aġent għandu jippubblika fih.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'L-isfida taż-żewġ fatturi skadiet. Idħol mill-ġdid.';

  @override
  String get theTwoFactorCodeIsNot =>
      'Il-kodiċi b\'żewġ fatturi mhuwiex validu.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Il-pakkett runtime verifikat ma setax jiġi mmarkat eżekutibbli.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Il-pakkett runtime ivverifikat huwa nieqes il-fajls meħtieġa.';

  @override
  String get theWebAppCouldNotReach =>
      'L-app tal-web ma setgħetx tilħaq il-backend NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'L-app tal-web ma setgħetx tilħaq il-backend NeoAgent f\'$arg1. Iċċekkja l-console tal-browser u l-konfigurazzjoni tar-reverse-proxy/netwerk.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'infushom; l-operatur server tneħħi admin l-ewwel bil ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Dawn il-kanali jibqgħu siekta. Biex terġa’ tisma’ mingħandhom, żidhom taħt Min jista’ messaġġ għal dik il-pjattaforma.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Dawn il-listi huma fakultattivi sakemm taqsima ta\' hawn fuq ma tkunx issettjata bħala approvata biss.';

  @override
  String get thesePeopleAnywhere => 'Dawn in-nies, kullimkien';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Dawn in-nies jistgħu messaġġi lil $arg1 f\'chats privati u fi kwalunkwe grupp li jaqsmu.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Dawn in-nies jistgħu messaġġ $arg1 one-to-one. Dan ma jħallihomx jitkellmu fi gruppi.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Dawn in-nies jistgħu biss messaġġ $arg1 fil-grupp li għażilt.';
  }

  @override
  String get thesePeopleInOneGroup => 'Dawn in-nies, fi grupp wieħed';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'dawn swiċċijiet, qatt chats tiegħek, memorji jew fajls.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Dan il-kont se jiftaħ NeoAgent fuq din il-magna.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Dan l-aġent jista’ jiddelega lil kwalunkwe aġent eliġibbli li jirċievi.';

  @override
  String get thisAgentIsUsingAServer =>
      'Dan l-aġent qed juża ċavetta API Trello ġestita minn server. Għandek bżonn biss tawtorizza token tal-kont hawn taħt.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Din il-bini mhux permess li titkellem ma \'dan l-iskjerament ta\' NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Dan il-kodiċi jappartjeni għal server NeoAgent differenti: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Dan id-desktop huwa konness';

  @override
  String get thisDevice => 'Dan l-apparat';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Dan l-apparat: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Dan l-apparat ma jistax jirreġistra ċwievet tas-sigurtà. Iftaħ NeoAgent fi browser fuq HTTPS biex iżżid wieħed.';

  @override
  String get thisDeviceUnavailable => 'Dan l-apparat — mhux disponibbli';

  @override
  String get thisFileHasNoContent => 'Dan il-fajl m\'għandux kontenut.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Dan jaħbi \"$arg1\" mir-rotta u l-għażla.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Din l-integrazzjoni bħalissa tappoġġja kont konness wieħed għal kull aġent. Erġa\' tiftaħ is-setup biex tissostitwiha.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Din l-integrazzjoni m\'għadhiex disponibbli.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Din l-introduzzjoni hija mfassla għal daqq ta\' pajsaġġ fuq skrin sħiħ.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Din hija skjerament ġestit. L-operatur tiegħu joħroġ ';

  @override
  String get thisMayTakeAMoment => 'Dan jista \'jieħu mument.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Dan is-server MCP m\'għadux konfigurat.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Din il-memorja se titneħħa b\'mod permanenti.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Din il-bini NeoAgent mhix ikkonfigurata biex tivverifika l-runtimes ta\' backend.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Dan iħassar b\'mod permanenti d-dejta kollha tiegħek u ma jistax ikun ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Dan iħassar b\'mod permanenti l-kont u dak kollu li għandu: ';

  @override
  String get thisPersonAnywhere => 'Din il-persuna, kullimkien';

  @override
  String get thisPersonInOneGroup => 'Din il-persuna, fi grupp wieħed';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Din it-talba ta\' login tal-QR skadiet. Iġġenera kodiċi ġdid u erġa\' pprova.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'din it-talba ta\' login tal-qr skadiet';

  @override
  String get thisQrLoginRequestIsStill =>
      'Din it-talba ta\' login tal-QR għadha qed tistenna l-approvazzjoni.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Din it-talba għall-login tal-QR kienet diġà użata.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Dan ineħħi s-setup tal-Assistent tad-Dar u l-istanza konnessa għal dan l-aġent.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Dan ineħħi l-URL backend NeoRecall u l-kontijiet NeoRecall kollha konnessi għal dan l-aġent.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Dan ineħħi l-URL Nextcloud u l-kontijiet Nextcloud kollha konnessi għal dan l-aġent.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Dan ineħħi s-setup Trello u l-kontijiet konnessi għal dan l-aġent.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Dan jeħtieġ sessjoni awtentikata fuq l-istess server NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Din il-ġirja ma pproduċietx rispons li jiffaċċja l-utent.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Din il-ġirja m\'għandha l-ebda dejta tal-pass irreġistrata.';

  @override
  String get thisServer => 'dan is-server.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Dan is-server ma jirrapporta ebda settings tal-fornitur.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Din il-ħila m\'għadhiex installata.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Dan il-kompitu għadu ma tlestiex, għalhekk għadu jibda fil- ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Dan il-kompitu jibda biss meta tagħfas Run Now.';

  @override
  String get thisWeek => 'Din il-ġimgħa';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Dan se jimporta r-rispons f\'$arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Dan se jneħħi \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Dan se jneħħi \"$arg1\" mil-lista tas-server.';
  }

  @override
  String get time => 'Ħin';

  @override
  String get timeZone => 'żona tal-ħin';

  @override
  String get timeZone2 => 'Żona tal-ħin';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Timed out$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Ma setgħetx telenka ż-żoni tal-ħin: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Ma setgħetx taqra ż-żona tal-ħin tal-apparat: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Ma setgħetx tissejvja ż-żona tal-ħin tal-apparat: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'għal $arg1';
  }

  @override
  String get toUseTheServerDefault => 'biex tuża s-server default.';

  @override
  String get today => 'Illum';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Baġit tat-token għal @$arg1. Ħalli qasam vojt ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Baġit tat-token għal kull kont mingħajr l-override tiegħu stess. Ħalli a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'limitu tal-baġit token 4 sigħat utent tal-kwota fil-ġimgħa';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'limitu tal-baġit token 4 sigħat kwota fil-ġimgħa globali';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'L-użu tat-tokens mhux disponibbli fuq din il-verżjoni tas-server.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokens kwalunkwe kont jista\' juża f\'4 sigħat.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokens kwalunkwe kont jista\' juża f\'7 ijiem.';

  @override
  String get tokensPerDay => 'Tokens kuljum';

  @override
  String get tokensPerRun => 'Tokens għal kull ġirja';

  @override
  String get tokensToday => 'Tokens illum';

  @override
  String get tokensUsed => ' tokens użati';

  @override
  String get tomorrowPrep => 'Għada l-preparazzjoni';

  @override
  String get tooManyAttempts => 'tentattivi wisq';

  @override
  String get tooManySignInAttemptsPlease =>
      'Wisq tentattivi ta\' dħul. Jekk jogħġbok stenna u erġa\' pprova.';

  @override
  String get tool => 'Għodda';

  @override
  String get toolApproval => 'Approvazzjoni tal-Għodda';

  @override
  String get toolApprovalRequired => 'Approvazzjoni tal-għodda meħtieġa';

  @override
  String get toolCompleted => 'Għodda kompluta';

  @override
  String get toolFailed => 'L-għodda falliet';

  @override
  String get toolPermissions => 'Permessi tal-Għodda';

  @override
  String get toolStarted => 'Għodda bdiet';

  @override
  String get tools => 'Għodda';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Għodod mhux mibnija f\'NeoAgent, inklużi servers MCP konnessi u fornituri ta\' għodda apposta.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Għodod offruti ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Għodod li l-kont immaniġġjat jista\' juża';

  @override
  String get topUsers => 'L-aqwa utenti';

  @override
  String get topUsersAndRecentRuns => 'L-aqwa utenti u ġirjiet riċenti';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Total: $arg1 tokens madwar $arg2 runs';
  }

  @override
  String get totalRuns => 'Ġirjiet totali';

  @override
  String get totalTokens => 'Tokens totali';

  @override
  String get totalUsers => 'Utenti totali';

  @override
  String get transcript => 'Traskrizzjoni';

  @override
  String get transcript2 => 'TRASCRIPT';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'It-traskrizzjoni falliet: $arg1';
  }

  @override
  String get transfer => 'Trasferiment';

  @override
  String get trelloApiKey => 'Trello API Key';

  @override
  String get trelloApiKeyIsRequired => 'Trello API Key hija meħtieġa.';

  @override
  String get trelloSetup => 'Setup ta\' Trello';

  @override
  String get triggerType => 'Tip ta\' Trigger';

  @override
  String get tryABroaderSearchLikeModels =>
      'Ipprova tfittxija usa\' bħal mudelli, browser, jew vuċi.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Ipprova isem tal-fornitur, \"email\", \"limiti\", \"aġġornament\" jew \"logs\".';

  @override
  String get tryAgain => 'Erġa\' pprova';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Erġa\' pprova. Jekk dan ikompli jiġri, ħaddem NeoAgent Doctor biex tiċċekkja r-runtime tal-kompjuter.';

  @override
  String get tryAgainInAMoment => 'Erġa\' pprova fi ftit mument.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Erġa\' pprova jew ħaddem NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Ipprova tfittxija oħra, qabbad pjattaforma tal-messaġġi, jew daħħal ID tad-destinazzjoni manwalment.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Ixgħel grupp jekk $arg1 għandu wkoll jaqra messaġġi li ma jittikkettawx.';
  }

  @override
  String get turnOffComputer => 'Itfi l-kompjuter';

  @override
  String get turnOffOnlyForAMail =>
      'Itfi biss għal server tal-posta b\'ċertifikat iffirmat minnu nnifsu.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Ixgħel jekk Signal għandu jkompli jfittex chats deħlin.';

  @override
  String get turnTaking => 'tieħu dawra';

  @override
  String get turnTakingModel => 'Mudell li jieħu d-dawran';

  @override
  String get turnTakingOff => 'Dawwar it-tluq';

  @override
  String get turnThisOffToKeepThis =>
      'Itfih biex iżżomm dan l-aġent kompletament separat minn aġenti oħra.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Mitfi minn $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Mitfi minn $arg1, li jamministra dan il-kont. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Mitfi għalik minn $arg1 — huma biss jistgħu jibdluh';
  }

  @override
  String get turnedOffForYouSoYou => 'Mitfi għalik, sabiex ma tistax tqassmu';

  @override
  String get twitchChatOverIrc => 'Twitch chat fuq IRC';

  @override
  String get twoFactorAuthentication => 'Awtentikazzjoni b\'żewġ fatturi';

  @override
  String get twoFactorChallengeExpired => 'sfida b\'żewġ fatturi skadiet';

  @override
  String get twoFactorCode => 'kodiċi b\'żewġ fatturi';

  @override
  String get twoFactorSignInCompletedBut =>
      'Id-dħul b\'żewġ fatturi tlesta, iżda NeoAgent ma setax iżomm is-sessjoni tal-browser. Jekk jogħġbok idħol mill-ġdid.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Login f\'żewġ passi (jekk attivat biss)';

  @override
  String get type => 'Tip';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Ittajpja $arg1 biex tikkonferma';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'it-test tat-tip mhuwiex appoġġjat fuq din il-pjattaforma.';

  @override
  String get typedInTheBrowser => 'Ittajpjat fil-browser';

  @override
  String get typedText => 'Test ittajpjat';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime => 'ma tistax issib runtime java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Ma tistax tiftaħ is-settings tal-ħin fuq din il-bini.';

  @override
  String get unableToOpenWiFiSettings =>
      'Ma tistax tiftaħ is-settings tal-Wi-Fi fuq din il-bini.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Ma tistax tippersisti l-wiri tad-desktop magħżul.';

  @override
  String get unclearWhoItWasFor => 'Mhux ċar għal min kien';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'jitneħħa. Ittajpja l-isem tal-utent tiegħek biex tikkonferma.';

  @override
  String get unknownAccount => 'Kont mhux magħruf';

  @override
  String get unknownAgent => 'Aġent mhux magħruf';

  @override
  String get unknownBrowser => 'Browser mhux magħruf';

  @override
  String get unknownDevice => 'Apparat mhux magħruf';

  @override
  String get unknownError => 'żball mhux magħruf';

  @override
  String get unknownLocalComputerPermission =>
      'Permess tal-kompjuter lokali mhux magħruf.';

  @override
  String get unknownLocation => 'Post mhux magħruf';

  @override
  String get unknownPublishTime => 'Ħin tal-pubblikazzjoni mhux magħruf';

  @override
  String get unknownSize => 'Daqs mhux magħruf';

  @override
  String get unlink => 'Unlink';

  @override
  String get unreadOnly => 'Mhux moqrija Biss';

  @override
  String get unsavedChanges => 'Bidliet mhux salvati';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Kmand tal-kumpann tad-desktop mhux appoġġjat: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Metodu mhux appoġġjat: $arg1';
  }

  @override
  String get unusualSignInAlerts =>
      'Twissijiet ta\' reġistrazzjoni mhux tas-soltu';

  @override
  String updateArg1(Object? arg1) {
    return 'Aġġorna $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Aġġorna l-entrati tal-memorja tal-qalba mill-importazzjoni.';

  @override
  String get updateNow => 'Aġġorna issa';

  @override
  String get updateReady => 'Aġġornament lest';

  @override
  String get updateSetup => 'Aġġorna Setup';

  @override
  String get updateTheAccessListToAllow =>
      'Aġġorna l-lista ta\' aċċess biex tippermetti tweġibiet.';

  @override
  String get updateTheServer => 'Taġġorna s-server?';

  @override
  String get updateTheServer2 => 'Aġġorna s-server';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Aġġorna ż-żona tal-ħin awtomatikament mill-apparat li qed tuża.';

  @override
  String updatedArg1(Object? arg1) {
    return 'aġġornata $arg1';
  }

  @override
  String get updates => 'Aġġornamenti';

  @override
  String get updatesAreNotConfiguredForThis =>
      'L-aġġornamenti mhumiex konfigurati għal din il-bini.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'aġġornamenti, għalhekk l-awto-aġġornament u l-bidliet fil-kanal huma off hawn.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'upgrade update issa rilaxx kanal beta stabbli';

  @override
  String get usageAnalytics => 'Analitika tal-użu';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Sinjali tal-użu u tas-saħħa li jgħinu jispjegaw l-imġieba attwali tar-runtime mingħajr ma jħaffru zkuk l-ewwel.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'L-użu mill-ġdid għal kollox f\'$arg1';
  }

  @override
  String get usageLeaderboard => 'leaderboard tal-użu';

  @override
  String get usageLimits => 'Użu & Limiti';

  @override
  String get usageLimits2 => 'Użu u limiti';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Uża 8+ karattri. Passphrases itwal jaħdmu tajjeb.';

  @override
  String get useADateAndTimeFor =>
      'Uża data u ħin, pereżempju 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Uża isem, numru tat-telefon, jew chat ID.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Uża URL NeoRecall li s-server NeoAgent jista\' jilħaq. PUBLIC_URL ta\' NeoAgent irid ikun jista\' jintlaħaq ukoll minn dan il-browser għar-callback OAuth.';

  @override
  String get useANewPasswordWithAt =>
      'Uża password ġdida b\'mill-inqas 8 karattri.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Uża URL Nextcloud li jista\' jilħaq is-server NeoAgent, pereżempju https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Uża password b\'mill-inqas 8 karattri.';

  @override
  String get useASecureConnectionTls => 'Uża konnessjoni sigura (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Uża app awtentikatur bħal Authy, 1Password, jew Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Uża mill-inqas vCPU 1.';

  @override
  String get maxMemoryPerComputerMb =>
      'Memorja massima għal kull kompjuter (MB)';

  @override
  String get maxVcpusPerComputer => 'Max vCPUs għal kull kompjuter';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Mill-inqas $arg1. Kompjuters jiksbu inqas meta l-host ikun okkupat.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Il-memorja massima għandha tkun mill-inqas $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Uża mill-inqas 8 karattri.';

  @override
  String get useDefault => 'Uża default';

  @override
  String get useDefaultChannel => 'Uża kanal default';

  @override
  String get useDefaultNeoagentWorkspace => 'Uża default (NeoAgent Workspace)';

  @override
  String get useFor => 'Uża għal';

  @override
  String get useManualDestination => 'Uża destinazzjoni manwali';

  @override
  String get useOrDoTheSameFor => 'uża, jew tagħmel l-istess għal sħabek.';

  @override
  String get usePerCategorySettingsBelow =>
      'Uża s-settings għal kull kategorija hawn taħt.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Uża Settings default ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Uża s-server fuq dan il-kompjuter';

  @override
  String get useTheseForContextIfA =>
      'Uża dawn għall-kuntest. Jekk URI lokali ma jkunx aċċessibbli direttament mis-server, staqsini biex nipprovdi l-fajl permezz ta\' spazju tax-xogħol aċċessibbli.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Uża dan għall-aġenti tal-orkestratur. Ħalli barra għal bots tax-xogħol iżolati li għandhom jispiċċaw messaġġi diretti huma stess.';

  @override
  String get useTlsFromTheStartOf =>
      'Uża TLS mill-bidu tal-konnessjoni, ġeneralment fuq il-port 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Uża ċ-ċavetta API tiegħek stess għal fornitur, jew qabbad custom ';

  @override
  String get usedByEveryAccountOnThis =>
      'Użat minn kull kont fuq dan is-server li m\'għandux ċavetta ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Użat biex jivverifika li l-avvenimenti Slack deħlin huma ġenwini.';

  @override
  String get userSummary => 'Sommarju tal-utent';

  @override
  String get username => 'Isem tal-utent';

  @override
  String get usernameOrEmail => 'Username jew email';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'utenti nies ifittxu email username admin badge tim amministrat';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Juża l-mudell taċ-chat konfigurat fis-Settings';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Bl-użu tal-runtime NeoAgent installat';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Normalment jidher bħal @bot:matrix.org';

  @override
  String get validEmail => 'email validu';

  @override
  String get value => 'Valur';

  @override
  String get vaultLocked => 'Vault msakkra';

  @override
  String get vaultOperationFailed => 'L-operazzjoni tal-kaxxa-forti falliet.';

  @override
  String get verification => 'Verifika';

  @override
  String verificationArg1(Object? arg1) {
    return 'Verifika: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'verifika: $arg1';
  }

  @override
  String get verificationCompleted => 'Verifika mitmuma.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Status tal-verifika: $arg1';
  }

  @override
  String get verifiedTheResult => 'Ivverifika r-riżultat';

  @override
  String get verifyingTheDownloadedRuntime => 'Verifika tar-runtime imniżżla';

  @override
  String get versionAndUptime => 'Verżjoni u uptime';

  @override
  String versionArg1(Object? arg1) {
    return 'Verżjoni $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Il-verżjoni $arg1 hija installata, iżda $arg2 għadu għaddej.';
  }

  @override
  String get videoLinks => 'Links tal-vidjo';

  @override
  String get viewDesktop => 'Ara d-desktop';

  @override
  String get viewLastRun => 'Ara l-aħħar ġirja';

  @override
  String get viewLogs => 'Ara zkuk';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm immaġini memorja cpu qemu runtime';

  @override
  String get voice => 'Leħen';

  @override
  String get voiceAssistant => 'Assistent tal-vuċi';

  @override
  String get voiceCall => 'SEJĦA VUĊI';

  @override
  String get voiceCall2 => 'Sejħa bil-vuċi';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'sejħa bil-vuċi gpt-live gemini live mudell diskors realtime';

  @override
  String get voiceCallsRunOnALive =>
      'Is-sejħiet bil-vuċi jimxu fuq mudell ta\' diskors għal diskors dirett bl-istess persuna, memorja u storja ta\' chat bħal NeoAgent. Twieġeb minnufih u jagħti xogħol reali lill-aġent normali, li jibqa’ jaħdem fl-isfond.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'vuċi nota diskors traskrizzjoni api key';

  @override
  String get voiceNotesAndDictation => 'Noti tal-vuċi u dettatura';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Id-daqq tal-vuċi mhux disponibbli fuq dan it-tagħmir.';

  @override
  String get voiceReplyModel => 'Mudell ta\' tweġiba bil-vuċi';

  @override
  String get waitingForApproval => 'Stennija għall-approvazzjoni: ';

  @override
  String get waitingForCode => 'Stennija għall-kodiċi';

  @override
  String get waitingForInput => 'Stennija għall-input';

  @override
  String get waitingForServerOrFlutterLog =>
      'Stennija għal server jew output log Flutter...';

  @override
  String get waitingForTaskEvents =>
      'Stennija għall-avvenimenti tal-kompiti...';

  @override
  String get waitingForYou => 'għalikom';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Xtaqt tweġiba minn $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Irid jitkellem miegħek · ${arg1}s';
  }

  @override
  String get weak => 'Dgħajjef';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'It-temp, il-kalendarju u l-prijoritajiet qabel tibda l-ġurnata tiegħek.';

  @override
  String get weatherEvent => 'Avveniment tat-Temp';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'Web browser';

  @override
  String get webSearchApiKey => 'web search api key';

  @override
  String get webhookOrRestChannelPosting =>
      'Webhook jew istazzjonar tal-kanal REST';

  @override
  String get webhookSecret => 'Webhook sigriet';

  @override
  String get webhookUrlCopied => 'URL tal-Webhook ikkupjat';

  @override
  String get weekdays => 'Ġranet tal-ġimgħa';

  @override
  String get weekdays0730 => 'Ġranet tal-ġimgħa · 07:30';

  @override
  String get weekdays1800 => 'Ġranet tal-ġimgħa · 18:00';

  @override
  String get weekly => 'Kull ġimgħa';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Limitu ta\' kull ġimgħa $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Limitu ta\' kull ġimgħa (tokens)';

  @override
  String get weeklyReview => 'Reviżjoni ta\' kull ġimgħa';

  @override
  String get weeklyUsage => 'Użu ta \'kull ġimgħa';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Reġistri tal-piż $arg1';
  }

  @override
  String get welcomeToNeoagent => 'JILQGĦU LIL NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Merħba għal\nNeoAgent';

  @override
  String get whatAreYouAdding => 'X\'qed iżżid?';

  @override
  String get whatIsOnTomorrow => 'X\'inhu għada?';

  @override
  String get whatShouldNeoagentLearn => 'X\'għandu jitgħallem NeoAgent?';

  @override
  String get whatShouldWeBuild => 'X\'għandna nibnu?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Dak li inti u NeoAgent tgħid jidher hawn u fiċ-chat.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Messaġġ Personali WhatsApp Riċevut';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Meta tagħżel approvat biss, żid nies jew gruppi hawn taħt.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Fejn dan l-aġent għandu jibgħat tweġibiet.';

  @override
  String get whoCanMessage => 'Min jista’ messaġġ';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Min jista\' jibgħat messaġġ fuq $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Min jista’ jibgħat lil $arg1 messaġġ wieħed għal wieħed.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Min jista\' jkellem lil $arg1 fi grupp, kanal, jew kamra.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'min jamministra dan il-kont mitfi: ';

  @override
  String get whoManagesWhom => 'Min jamministra lil min';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Min jaċċetta link jingħaqad mat-tim tiegħek bl-għodda tiegħu biss ';

  @override
  String get wholeGroup => 'Grupp kollu';

  @override
  String get wholeGroups => 'Gruppi sħaħ';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Għaliex $arg1 wieġeb jew qagħad kwiet fi gruppi $arg2.';
  }

  @override
  String get windowsApp => 'App tal-Windows';

  @override
  String get windowsNt => 'twieqi nt';

  @override
  String get workAccount => 'Kont tax-xogħol';

  @override
  String get workOnAProjectWithNeoagent => 'Aħdem fuq proġett ma\' NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Fluss tax-xogħol: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Xogħol f\'$arg1 fuq il-kompjuter tas-sħab. NeoAgent jaqra u jeditja fajls hemmhekk u jista \'jmexxi kmandi u browser.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Ħidma fl-isfond: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Konfigurazzjoni tal-ispazju tax-xogħol u sigurtà tal-kont f\'post wieħed.';

  @override
  String get workspaceFiles => 'Fajls tal-ispazju tax-xogħol';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Spazju tax-xogħol, mudelli, u kontrolli dijanjostiċi.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Is-sostituzzjoni tal-ispazju tax-xogħol għandha tkun triq assoluta.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Kiteb $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttprequest żball';

  @override
  String get yesterday => 'Ilbieraħ';

  @override
  String get youAreInControl => 'Inti fil-kontroll';

  @override
  String get youCanFollowAlongOnThe => 'Tista\' ssegwi fuq id-desktop.';

  @override
  String get youCanLeaveATeamAt =>
      'Tista\' tħalli tim fi kwalunkwe ħin; is-settings tiegħek jerġgħu japplikaw.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Tista\' titlaq fi kwalunkwe ħin mill-paġna tat-Tim.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Inti tiddeċiedi liema għodod jista\' juża l-aġent tiegħek, taħt Settings › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Għadek ma tmexxi lil ħadd. Oħloq link għall-istedina hawn taħt u ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Għandek settings mhux salvati. X\'tixtieq tagħmel?';

  @override
  String get youReOnYourOwnYou =>
      'Int waħdek: inti tiddeċiedi liema għodod jista\' juża l-aġent tiegħek. Jekk ';

  @override
  String get yourAccountAndUsageOnA =>
      'il-kont tiegħek -- u l-użu fuq mudell appoġġjat minn ċavetta tiegħek stess ';

  @override
  String get yourAccountHasBeenDeleted => 'Il-kont tiegħek tħassar.';

  @override
  String get yourAgentWillBeAllowed => 'L-aġent tiegħek se jkun permess:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'L-apps u l-fajls tiegħek jiġu ssejvjati.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'L-apps u l-fajls tiegħek jibqgħu salvati.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Iċ-ċavetta $arg1 tiegħek';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Is-saff tal-assistent tiegħek għall-qbid, il-kuntest u l-azzjoni.';

  @override
  String get yourComputerIsAsleep => 'Il-kompjuter tiegħek rieqed';

  @override
  String get yourComputerIsOff => 'Il-kompjuter tiegħek huwa mitfi';

  @override
  String get yourComputerIsReady => 'Il-kompjuter tiegħek huwa lest';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Il-password attwali tiegħek mhix korretta.';

  @override
  String get yourData => 'Id-dejta tiegħek';

  @override
  String get yourDataExportWasCopiedTo =>
      'L-esportazzjoni tad-dejta tiegħek ġiet ikkupjata fil-clipboard.';

  @override
  String get yourDesktopIsReady => 'Id-desktop tiegħek huwa lest';

  @override
  String get yourLinuxComputer => 'Il-kompjuter Linux tiegħek';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Il-lokalità tiegħek qatt ma tiġi segwita kontinwament jew maħżuna fuq is-servers tagħna. Aħna nużawha biss lokalment biex niċċekkjaw mal-kompiti attivi tiegħek.';

  @override
  String get yourManager => 'il-maniġer tiegħek';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Il-URL tas-sit Mattermost tiegħek, jekk tuża l-API REST.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Is-sessjoni tiegħek skadiet jew ma nżammitx mill-browser. Jekk jogħġbok idħol mill-ġdid.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Is-sessjoni tiegħek skadiet. Jekk jogħġbok idħol mill-ġdid.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'L-isem tal-utent jew il-password tiegħek mhumiex korretti.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,...';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personali';

  @override
  String get sectionOverview => 'Ħarsa ġenerali';

  @override
  String get sectionDiagnostics => 'Dijanjostiċi';

  @override
  String get sectionVolume => 'Volum';

  @override
  String get sectionSession => 'Sessjoni';

  @override
  String get sectionDeliverable => 'Konsenjabbli';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Ir-runtime lokali għadu ma kitebx log file.';

  @override
  String get thisComputer => 'Dan il-kompjuter';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Il-beta tinstalla l-backend ta\' prerelease l-aktar ġdid. Jistennew truf mhux maħduma.';

  @override
  String get copiedFinalResponse => 'Risposta finali kkupjata';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Ir-rispons finali jidher hawn meta tispiċċa l-ġirja.';

  @override
  String get waitingForTheFirstStep => 'Nistennew l-ewwel pass...';

  @override
  String get loadingPrompt => 'Tagħbija fil-pront...';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Ma nqabad l-ebda tweġiba finali għal din il-ġirja.';

  @override
  String get readyToSignIn => 'Lest biex tidħol';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Aqleb għal \"Default\" jew \"Dejjem staqsi\" biex terġa \'tippermetti l-kontrolli tal-approvazzjoni.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Ibgħat aġġornament tal-isteering jew nota li jmiss għall-ġirja attwali...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Ebda konnessjoni tan-netwerk. NeoAgent jerġa \'jikkonnettja meta l-apparat jerġa\' jkun online.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Applika l-aħħar aġġornament tal-istering għall-ġirja attwali.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Nipprepara s-sessjoni tal-vuċi privata...';

  @override
  String get preparingYourComputer => 'Tħejjija tal-kompjuter tiegħek';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent qed iniżżel u jħejji s-sistema Linux sigura. Dan jiġri biss l-ewwel darba.';

  @override
  String get moreFreeSpaceIsNeeded => 'Huwa meħtieġ aktar spazju ħieles';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Eħles ftit spazju fuq id-diska fuq il-host NeoAgent, imbagħad erġa\' pprova. Id-dejta eżistenti tal-kompjuter tiegħek hija sigura.';

  @override
  String get androidReady => 'Android lest';

  @override
  String get startingAndroid2 => 'Nibda Android...';

  @override
  String get androidStopped => 'Android waqaf';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'L-ewwel bidu jniżżel l-Android SDK u l-immaġni tas-sistema, li jistgħu jieħdu diversi minuti.';

  @override
  String get androidIsStopped => 'Android jitwaqqaf';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Ibda l-ambjent Android ġestit meta jkollok bżonnha.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Ħalli lil NeoAgent jaħdem fuq dan il-kompjuter';

  @override
  String get firstTimeSetupIsInProgress => 'Setup għall-ewwel darba qed isir.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent jista\' juża l-aċċess li tippermetti.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Eħles xi ħażna ospitanti u erġa\' pprova.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Ibda meta trid li NeoAgent jgħin hawn.';

  @override
  String get systemPermissionMissing => 'Permess tas-sistema nieqes';

  @override
  String get connectingThisDevice => 'Tqabbad dan l-apparat';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Il-konnessjoni lokali sigura qed tiġi stabbilita.';

  @override
  String get recordingYourDemonstration =>
      'Tirreġistra d-dimostrazzjoni tiegħek';

  @override
  String get noErrorsInTheRecentLog => 'Ebda żbalji fil-ġurnal reċenti.';

  @override
  String get loadingAccounts => 'Qiegħed il-kontijiet...';

  @override
  String get neverSignedIn => 'Qatt ma ffirmat';

  @override
  String get emptyUsesTheServerDefault => 'Vojt juża s-server default.';

  @override
  String get followTheSelectedSession => 'Segwi s-sessjoni magħżula';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Il-modalità tal-pjan tispezzjona biss. Aqleb għall-modalità Aġent biex tħalli lil NeoAgent jeditja l-fajls.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Meħtieġa biex iżżid jew tbiddel l-email tal-kont tiegħek.';

  @override
  String get confirmNewPassword => 'Ikkonferma password ġdida';

  @override
  String get passwordChanged => 'Password mibdula.';

  @override
  String get thisRequestHasAlreadyBeenUsed => 'Din it-talba diġà ntużat.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Din it-talba skadiet. Staqsi lill-apparat l-ieħor biex jiġġenera kodiċi ġdid.';

  @override
  String get startQuickstart => 'Ibda Quickstart';

  @override
  String get createYourAccount => 'Oħloq il-kont tiegħek';

  @override
  String get showWorkAsSummaries => 'Uri x-xogħol bħala sommarji';

  @override
  String get tokensUsedByTheLatestRun => 'Tokens użati mill-aħħar run';

  @override
  String get listedTheWorkspaceRoot => 'Elenkat l-għerq tal-ispazju tax-xogħol';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'L-ebda integrazzjoni uffiċjali għadha disponibbli.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'S\'issa m\'hemmx servers MCP konfigurati. Żid waħda biex tesponi l-għodda tagħha.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Żid server MCP jew installa ħila biex tibda.';

  @override
  String get setUp => 'Imwaqqaf';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Ħalli vojt biex iżżomm il-valur maħżun';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Dan ineħħi l-indirizz għal kull kont fuq dan is-server.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Tkellem biss. Tista\' tinterrompi fi kwalunkwe ħin. Tektek biex tismut.';

  @override
  String get tapAgainWhenYouAreDone => 'Tektek mill-ġdid meta tkun lest.';

  @override
  String get workingOnATaskInTheBackground =>
      'Ħidma fuq biċċa xogħol fl-isfond.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Speech-to-speech bl-istess memorja, għodod u storja taċ-chat bħal NeoAgent.';

  @override
  String get checkLink => 'Iċċekkja l-link';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'L-aġent tiegħek mhux se jkun permess ebda għodda kkontrollata.';

  @override
  String get notYoursToChange => 'Mhux tiegħek biex tbiddel';

  @override
  String get setByYou => 'Issettjat minnek';

  @override
  String get noTools => 'Ebda għodda';

  @override
  String get untitledLink => 'Link bla titolu';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Jieqaf jaħdem wara li persuna waħda tifdiha.';

  @override
  String get theOperator => 'L-operatur';

  @override
  String get smartSelectorOn => 'Selettur intelliġenti mixgħul';

  @override
  String get startASessionToBegin => 'Ibda sessjoni biex tibda';

  @override
  String get steerTheActiveRun => 'Imexxi l-ġirja attiva...';

  @override
  String get describeWhatToPlan => 'Iddeskrivi x\'għandek tippjana...';

  @override
  String get stopDictation => 'Waqqaf id-dettatura';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Il-messaġġi jmexxu l-ġirja kurrenti · ⌘↵ ibgħat · ⌘. waqqaf';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Il-modalità tal-pjan tispezzjona biss; xejn ma jinbidel sakemm timplimenta · ⌘↵ ibgħat';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'L-aġent jeditja l-ispazju tax-xogħol. Pjan biss jispezzjona.';

  @override
  String get defaultModel => 'Mudell default';

  @override
  String get openingScanner => 'Iftaħ l-iskaner...';

  @override
  String get theAgentCanUseThisSkill => 'L-aġent jista \'juża din il-ħila.';

  @override
  String get allSelected => 'Kollha Magħżula';

  @override
  String get addCoreMemoryEntry => 'Żid Dħul tal-Memorja Core';

  @override
  String get channelId => 'ID tal-kanal';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Ħidmiet maħluqa mill-AI u mhux speċifikati jużaw l-inadempjenza attwali.';

  @override
  String get waitingForRunEvents => 'Nistennew l-avvenimenti tal-ġiri...';

  @override
  String get hideSteps => 'Aħbi l-passi';

  @override
  String get commitTheActiveLiveCapture => 'Kommetti l-qbid attiv attiv';

  @override
  String get stopCaptureAndSubmit => 'Waqqaf il-qbid u ssottometti';

  @override
  String get clickTheMicToStartSpeaking =>
      'Ikklikkja l-mikrofon biex tibda titkellem';

  @override
  String get connectACustomEndpoint => 'Qabbad endpoint personalizzat';

  @override
  String get hostedProvider => 'fornitur ospitat.';

  @override
  String get muted => ' • siekta';

  @override
  String get addWhoCanMessage => 'Żid min jista \'messaġġ';

  @override
  String get joinsGroupConversations =>
      'Jingħaqad ma\' konversazzjonijiet tal-grupp';

  @override
  String get label1PersonOrGroupAdded => '1 persuna jew grupp miżjud';

  @override
  String get inProgress => 'Fil-progress';

  @override
  String get waitingForUpdateJobOutput =>
      'Stennija għall-aġġornament tal-output tax-xogħol...';

  @override
  String get taskTrigger => 'Task trigger';

  @override
  String get bearerToken => 'Token tal-bearer';

  @override
  String get bearerToken2 => 'Token tal-Bearer';

  @override
  String get notRecorded => 'Mhux irreġistrat';

  @override
  String get sessionCookie => 'Cookie tas-sessjoni';

  @override
  String get neverUsed => 'Qatt użat';

  @override
  String get linkedRecently => 'Marbuta reċentement';

  @override
  String get notUsedYet => 'Għadu mhux użat';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Kont wieħed jew aktar skada. Erġa\' qabbad biex tirrestawra l-aċċess. Jekk dan ikompli jiġri, l-app tiegħek Google Cloud OAuth tista\' tkun fil-modalità Testing — ippubblikaha fil-Produzzjoni f\'Google Cloud Console biex tikseb tokens li jservu fit-tul.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault konness u disponibbli wara l-bidu mill-ġdid';

  @override
  String get vaultConnectedForThisSession =>
      'Vault konness għal din is-sessjoni';

  @override
  String get connectAnotherAccount => 'Qabbad Kont Ieħor';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Token ta\' Aċċess ta\' ħajja twila ta\' sostituzzjoni tal-pejst';

  @override
  String get updateInstance => 'Aġġorna l-Istanza';

  @override
  String get pasteAReplacementToken => 'Paste token ta\' sostituzzjoni';

  @override
  String get replaceAccount => 'Ibdel il-Kont';

  @override
  String get addAccount => 'Żid Kont';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Jista\' jiddelega lil kwalunkwe aġent li jirċievi';

  @override
  String get canReceiveDelegatedTasks2 => 'jistgħu jirċievu kompiti delegati';

  @override
  String get noSyncYet => 'S\'issa m\'hemmx sinkronizzazzjoni';

  @override
  String get noNewData => 'Ebda data ġdida';

  @override
  String get syncOnceToSeedYourBackend =>
      'Issinkronizza darba biex żerriegħa backend tiegħek.';

  @override
  String get lastWindowEndIsUnknown => 'L-aħħar tarf tat-tieqa mhux magħruf.';

  @override
  String get lastNonEmptySync => 'L-aħħar sinkronizzazzjoni mhux vojta';

  @override
  String get stopTranscribe => 'Waqqaf u traskrivi';

  @override
  String get steeringMode => 'Mod ta\' l-istering';

  @override
  String get noMessageText => 'Ebda test ta\' messaġġ';

  @override
  String get reconnectingToServer => 'Qiegħed jerġa\' jgħaqqad mas-server...';

  @override
  String get signingIn => 'Iffirmar...';

  @override
  String get noGroupsFoundYet => 'Għadu ma nstab l-ebda grupp';

  @override
  String get onForNewGroupsOnly => 'On għal gruppi ġodda biss';

  @override
  String get noGroupsInThisCategory => 'L-ebda grupp f\'din il-kategorija';

  @override
  String get groupOrChannel => 'Grupp jew kanal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'In-noti li tikteb lilek innifsek tibda ġirja, u twieġeb tinżel fl-istess chat. Il-lista ta\' permessi ma tapplikax hawn.';

  @override
  String get needToReply => 'Ħtieġa li twieġeb';

  @override
  String get enter2faCode => 'Daħħal il-kodiċi 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Iftaħ l-app awtentikatur tiegħek u daħħal il-kodiċi attwali NeoAgent.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Diġà għandek kont? Idħol';

  @override
  String get serverOnThisComputer => 'Server fuq dan il-kompjuter';

  @override
  String get showQrCode => 'Uri kodiċi QR';

  @override
  String get createAnotherNeoagentAccount => 'Oħloq kont ieħor NeoAgent.';

  @override
  String get canCoordinateDelegatedWork =>
      'Jista\' jikkoordina xogħol iddelegat';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'L-arkivju runtime NeoAgent ma setax jiġi estratt.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'L-arkivju runtime NeoAgent ma setax jinqara.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'L-arkivju runtime NeoAgent fih mogħdija mhux sikura.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'L-arkivju runtime NeoAgent fih link mhux sikur.';

  @override
  String get installingAppPackageOnThePhone =>
      'L-installazzjoni tal-pakkett tal-app fuq it-telefon...';

  @override
  String get dragAndDropAApkOrApks =>
      'Iddreggja u qiegħed fajl .apk jew .apks hawn, jew ikklikkja biex tfittex.';

  @override
  String get releaseToInstallThisPackage =>
      'Eħles biex tinstalla dan il-pakkett';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Iċ-ċavetta tas-sigurtà ma setgħetx tintuża.';

  @override
  String get connecting => 'Konnessjoni...';

  @override
  String get changes => 'Bidliet';

  @override
  String get runtimeReady => 'Runtime lest';

  @override
  String get saving => 'Iffrankar...';

  @override
  String get earlier => 'Aktar kmieni';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Frar';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'Mejju';

  @override
  String get monthJun => 'Ġunju';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Awissu';

  @override
  String get monthSep => 'Settembru';

  @override
  String get monthOct => 'Ottubru';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Diċembru';

  @override
  String get steeringWord => 'Tmexxija';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Dan jaqleb il-backend mill-kanal $arg1 għall-kanal $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Cookies $arg1 importati';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '${arg1}s ilu';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Tmexxija fil-kju: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'L-app tal-web ma setgħetx tilħaq il-backend NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Il-browser imblokka talba meħtieġa minħabba l-Politika tas-Sigurtà tal-Kontenut.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 ta\' 4 permessi';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Aħdem permezz tal-kompitu kif inti normalment.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Bidliet · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Dan l-apparat · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limitu milħuq$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Il-kodiċijiet ta \'rkupru $arg1 għadhom disponibbli.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Ċavetta tas-sigurtà $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Sessjoni kurrenti';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nL-aħħar użat: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Ħidma f\'$arg1 fuq dan l-apparat. NeoAgent jaqra u jeditja l-folder direttament u jista \'jmexxi kmandi, jiftaħ apps u juża l-iskrin.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Ħadem għal $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Permess minn $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Il-links tal-istedina $arg1 minn $arg2 ġew revokati';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Żid in-nies u l-gruppi li $arg1 għandu jkellem';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Żid in-nies u l-gruppi $arg1 huwa permess li jitkellem.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Fejn $arg1 jisma';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 jara dawn il-postijiet għall-aċċenn. Kulħadd jista’ jpoġġi hawn, u għalhekk in-nies xorta għandhom bżonn l-approvazzjoni tagħhom hawn taħt.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Dawn in-nies jistgħu jistaqsu lil $arg1 kull fejn jimmarkawh. Ir-rwoli jgħoddu biss fil-postijiet elenkati hawn fuq.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Biss meta $arg1 ikun ittikkettat';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Mixgħul għall-gruppi kollha $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 għadu jisma\' biss nies u gruppi li diġà approvajt. Dan biss iħalli lil $arg1 jingħaqad ma \'chat ordinarju hemmhekk, mhux biss tikketti u tweġibiet.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 għadu jisma\' biss nies u gruppi li diġà approvajt. Dan jagħżel biss liema minn dawk il-gruppi għandu jingħaqad.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Jekk xi ħadd jimmarka lil $arg1 jew iwieġeb, $arg1 dejjem iwieġeb. Ixgħel dan jekk $arg1 għandu wkoll jiċċaqlaq fuq chat tal-grupp ordinarju.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Gruppi ġodda se jħallu lil $arg1 jingħaqad ma\' chat ordinarju ma\' nies approvati, sakemm itfihom.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Gruppi ġodda se jħallu lil $arg1 jingħaqad ma\' chat ordinarju sakemm itfihom.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Gruppi ġodda jibqgħu kwieti sakemm persuna approvata ma tikkettjax $arg1, sakemm tixgħelhom.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Biss meta persuna approvata tikkettja $arg1, sakemm ma tixgħel grupp';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Biss meta $arg1 jiġi mmarkat, sakemm ma tixgħel grupp';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 ta\' gruppi $arg2 jingħaqdu ma\' chat ordinarju ma\' nies approvati';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Dan ma japprovax nies ġodda. Tikketti u tweġibiet minn nies approvati dejjem jiksbu tweġiba. Ixgħel grupp jekk $arg1 għandu wkoll jingħaqad ma\' chat ordinarju hemmhekk.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Dan ma japprovax nies ġodda. Ixgħel grupp jekk $arg1 għandu jingħaqad ma\' chat ordinarju ma\' nies li diġà approvajt.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Tikketti u tweġibiet dejjem jiksbu tweġiba. Ixgħel grupp jekk $arg1 għandu wkoll jingħaqad ma\' chat ordinarju hemmhekk.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 jingħaqad ma\' chat ordinarju ma\' nies approvati';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 jista\' jingħaqad ma\' chat ordinarju';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 iwieġeb biss meta persuna approvata timmarkaha';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'M\'hemm bżonn xejn żejjed. Qabbad biex tibda tuża $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Aġġorna f\'${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Irreġistra ma\' $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Ebda memorji marbuta ma\' \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (default)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Fergħa: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 jingħaqad biss mal-gruppi u l-kanali li żżid hawn taħt.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 huwa meħtieġ biex tiġi lokalizzata d-dejta tar-runtime ta\' NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[previżjoni maqtugħa, $arg1 bytes totali]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artifact bounded, $arg1 bytes totali]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' fi $arg1';
  }

  @override
  String get worldNews => 'Aħbarijiet Dinjija';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Mexxi meta jidhru aħbarijiet tad-dinja ġodda. Il-pront tiegħek jiddeċiedi jekk jinnotifikakx.';

  @override
  String get newsKeywordsOptional => 'Kliem ewlieni (mhux obbligatorju)';

  @override
  String get worldNewsSetup => 'Setup tal-Aħbarijiet Dinjija';

  @override
  String get connectWorldNewsWithGnews =>
      'Żid GNews API key (pjan b\'xejn disponibbli fuq gnews.io). Huwa maħżun kriptat u użat biex jivvota l-aqwa aħbarijiet għal triggers tal-Aħbarijiet Dinjija.';

  @override
  String get gnewsApiKey => 'GNews API key';

  @override
  String get pasteReplacementGnewsApiKey => 'Paste sostituzzjoni GNews API key';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Ħalli ċ-ċavetta vojta biex iżżomm iċ-ċavetta maħżuna bħalissa.';

  @override
  String get gnewsApiKeyIsRequired => 'Hija meħtieġa ċavetta GNews API.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Ma setgħetx issalva s-setup tal-Aħbarijiet Dinjija.';

  @override
  String get disconnectWorldNews => 'Skonnettja Aħbarijiet Dinjija';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Dan ineħħi ċ-ċavetta GNews API maħżuna. L-iskatturi tal-Aħbarijiet Dinjija se jieqfu jisparaw sakemm terġa\' żżid ċavetta.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Ma setgħetx tiskonnettja World News.';

  @override
  String get systemOneModels => 'Mudelli SystemOne';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Jagħżel l-aħjar mudell SystemOne disponibbli';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Il-mudell taċ-chat jieħu dawn id-deċiżjonijiet';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Mudelli ta’ deċiżjoni li jagħmlu s-sejħiet ta’ wara l-kwinti fi frazzjoni ta’ sekonda: teħid ta’ dawra ta’ chat-grupp u passi tal-browser. Il-mudell taċ-chat tiegħek għadu jikteb kull tweġiba.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Il-mudell SystemOne jiddeċiedi meta jitkellem waqt li jkun mixgħul; dan il-mudell huwa r-riżerva.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 skurjat minn SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne skorja dan il-messaġġ direttament. L-ebda mudell tal-lingwa ma dam.';

  @override
  String get systemOneUnavailable => 'SystemOne mhux disponibbli';

  @override
  String get systemOneAdminAvailability =>
      'L-aġenti tal-mudelli tad-deċiżjonijiet jistgħu jagħżlu taħt Settings › Mudelli. Mudell mitfi hawn iħalli dak il-picker, u l-aġenti li għażlu jaqgħu lura għal Auto. Filwaqt li kwalunkwe mudell huwa mitfi, mudelli SystemOne li l-fornituri jżidu aktar tard jibdew mitfija wkoll.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Għadu l-ebda mudell SystemOne. Żid ċavetta TypeSafe jew OpenRouter taħt Fornituri, jew iġbed mudell ta \'deċiżjoni bħal nimble f\'Ollama 0.35 jew aktar tard.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'L-ebda mudell SystemOne għadu disponibbli. Żid ċavetta TypeSafe jew OpenRouter taħt Settings › Mudelli › Ġib iċ-ċavetta tiegħek stess, jew iġbed mudell ta\' deċiżjoni bħal nimble f\'Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone sistema deċiżjoni waħda mudelli jev typesafe openrouter ollama disponibbiltà jippermettu tiddiżattiva';

  @override
  String get chatModels => 'Mudelli ta\' chat';

  @override
  String get disabled => 'Diżattivat';

  @override
  String get enableShown => 'Ippermetti muri';

  @override
  String get disableShown => 'Itfi murija';

  @override
  String get expandAll => 'Jespandu kollha';

  @override
  String get collapseAll => 'Kollass kollox';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 bidliet mhux salvati';
  }

  @override
  String get settingsScopeAllAgents => 'L-aġenti kollha';

  @override
  String get settingsScopeAgent => 'Dan l-aġent';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint => 'L-istess kull fejn tidħol';

  @override
  String get settingsScopeAllAgentsHint => 'Maqsuma mill-aġenti kollha tiegħek';

  @override
  String get settingsAppliesTo => 'Japplika għal';

  @override
  String get settingsSaving => 'Insalva...';

  @override
  String get settingsSavedAutomatically =>
      'Il-bidliet jiffrankaw awtomatikament';

  @override
  String get settingsSearchHint => 'Fittex is-settings kollha';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Id-dħul u s-sigurtà';

  @override
  String get settingsPageUsage => 'Użu';

  @override
  String get settingsPagePermissions => 'Permessi';

  @override
  String get settingsPageComputer => 'Kompjuter u web';

  @override
  String get settingsPageBehavior => 'Imġieba';

  @override
  String get settingsPageSystem => 'Sistema';

  @override
  String get settingsPagePlatforms => 'Pjattaformi';

  @override
  String get settingsPageProfileDescription =>
      'Ismek u l-email, kopja tad-data tiegħek, u l-iffirmar.';

  @override
  String get settingsPageSecurityDescription =>
      'Password, awtentikazzjoni b\'żewġ fatturi, ċwievet tas-sigurtà u fejn int iddaħħal.';

  @override
  String get settingsPageUsageDescription =>
      'Il-limiti u t-token tiegħek jonfqu, kollha f\'post wieħed.';

  @override
  String get settingsPageAgentsDescription =>
      'Oħloq aġenti u agħżel liema wieħed iwieġeb awtomatikament.';

  @override
  String get settingsPagePermissionsDescription =>
      'X\'jistgħu jagħmlu l-aġenti tiegħek mingħajr ma jistaqsuk l-ewwel.';

  @override
  String get settingsPageComputerDescription =>
      'Il-kompjuter li jaħdmu fuqu l-aġenti tiegħek u s-siti li jistgħu jaqraw kif inti.';

  @override
  String get settingsPageModelsDescription =>
      'Liema mudelli juża dan l-aġent, u ċ-ċwievet API li jħallsu għalihom.';

  @override
  String get settingsPageBehaviorDescription =>
      'Kif jitkellem dan l-aġent u kif jaqra chat tal-grupp.';

  @override
  String get settingsPageVoiceDescription =>
      'Sejħiet diretti, dettatura u tweġibiet mitkellma għal dan l-aġent.';

  @override
  String get settingsPageMessagingDescription =>
      'Fejn in-nies jistgħu jilħqu dan l-aġent u kif iġib ruħu fiċ-chats.';

  @override
  String get settingsPageGeneralDescription =>
      'Id-dehra, il-lingwa, iż-żona tal-ħin u x\'tagħmel din l-app fl-isfond.';

  @override
  String get settingsPageSystemDescription =>
      'Is-server li tuża din it-tieqa, dak fuq dan il-kompjuter, u l-aġġornamenti tal-app.';

  @override
  String get settingsYourAgents => 'L-aġenti tiegħek';

  @override
  String get settingsChatModel => 'Mudell taċ-chat';

  @override
  String get settingsChatModelDescription => 'Iwieġeb il-messaġġi tiegħek.';

  @override
  String get settingsSubAgentModel => 'Mudell tas-sotto-aġent';

  @override
  String get settingsSubAgentModelDescription =>
      'Imexxi x-xogħol mogħti waqt kompitu.';

  @override
  String get settingsDefaultModels => 'Mudelli default';

  @override
  String get settingsDefaultModelsDescription =>
      'Użat kull meta chat jew kompitu ma jagħżelx il-mudell tiegħu stess.';

  @override
  String get settingsModelPool => 'Mudell pool';

  @override
  String get settingsApiKeysDescription =>
      'Uża ċ-ċwievet jew l-endpoint tiegħek stess għal dan l-aġent. Iċ-ċwievet huma encrypted u qatt ma jerġgħu jintwerew.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Irfinar';

  @override
  String get settingsFineTuningDescription =>
      'Rari meħtieġa. In-nuqqasijiet jaqdu l-biċċa l-kbira taċ-chats.';

  @override
  String get settingsShow => 'Uri';

  @override
  String get settingsHide => 'Aħbi';

  @override
  String get settingsMinimumContribution => 'Valur minimu ta\' kontribuzzjoni';

  @override
  String get settingsBatchWindow => 'Tieqa tal-lott tal-kamra';

  @override
  String get settingsBatchWindowDescription =>
      'Jistenna dan it-tul biex jittratta messaġġi rapidi bħala dawra waħda.';

  @override
  String get settingsHandsFree => 'Idejn ħielsa';

  @override
  String get settingsHandsFreeDescription =>
      'Tkellem liberament u interrompi fi kwalunkwe ħin.';

  @override
  String get settingsPushToTalkDescription =>
      'Żomm biex tkellem, rilaxx biex tibgħat.';

  @override
  String get settingsLiveVoice => 'Vuċi ħaj';

  @override
  String get settingsChannels => 'Kanali';

  @override
  String get settingsGroupChats => 'Fi chats tal-grupp';

  @override
  String get settingsGroupChatsDescription =>
      'Kif iġib ruħu dan l-aġent fi gruppi fuq kull kanal.';

  @override
  String get settingsGroupChatsDisabled =>
      'Ixgħel il-moduli tal-imġieba fl-Imġieba biex tbiddel dawn.';

  @override
  String get settingsParticipationAutomatic => 'Awtomatiku';

  @override
  String get settingsParticipationMentionOnly => 'Semmi biss';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Jaqra l-kamra u jingħaqad meta jkollu xi ħaġa utli x\'iżżid.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Tweġibiet biss meta msemmija jew imwieġba.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Risposti għal kull messaġġ.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Taqsam tweġibiet itwal f\'messaġġi qosra, kif tagħmel persuna.';

  @override
  String get settingsDeliverySingleDescription =>
      'Tibgħat kull tweġiba bħala messaġġ wieħed.';

  @override
  String get settingsComputerStatus => 'Status';

  @override
  String get settingsTest => 'Test';

  @override
  String get settingsAppearance => 'Dehra';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Ċara';

  @override
  String get settingsThemeDark => 'Skura';

  @override
  String get settingsCloseWindow => 'Meta tagħlaq it-tieqa';

  @override
  String get settingsCloseAsk => 'Staqsi';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent jibqa\' jaħdem fl-isfond u jibqa\' jintlaħaq.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent jieqaf kompletament.';

  @override
  String get settingsPhoneTriggers => 'Telefon jqajjem';

  @override
  String get settingsPhoneTriggersDescription =>
      'Sinjali li dan it-telefon jibgħat lill-aġenti tiegħek sabiex il-kompiti jkunu jistgħu jirreaġixxu għalihom.';

  @override
  String get settingsLocationTriggers => 'Post iqajjem';

  @override
  String get settingsLocationTriggersDescription =>
      'Iċċekkja l-post approssimattiv tiegħek kull ftit minuti mal-postijiet li jaraw il-kompiti tiegħek.';

  @override
  String get settingsNotificationTriggers => 'In-notifika tiskatta';

  @override
  String get settingsNotificationTriggersDescription =>
      'Tgħaddi notifiki minn apps oħra fuq dan it-telefon lill-aġenti tiegħek.';

  @override
  String get settingsSetup => 'Setup';

  @override
  String get settingsOnboarding => 'Abbord';

  @override
  String get settingsOnboardingDescription =>
      'Erġa\' jimxi permezz tas-setup tal-ewwel ġirja. Xejn inti waqqaf huwa mitluf.';

  @override
  String get settingsUsernameDescription =>
      'Użat biex tidħol. Ma tistax tinbidel.';

  @override
  String get settingsExport => 'Esportazzjoni';

  @override
  String get settingsLeave => 'Iffirma u ħassar';

  @override
  String get settingsSignOutDescription => 'Jiċċekkjak fuq dan l-apparat biss.';

  @override
  String get settingsDeleteAccountDescription =>
      'Tħassar il-kont, l-aġenti, il-memorja u s-settings tiegħek. Dan ma jistax jitneħħa.';

  @override
  String get settingsTokenUsage => 'Użu tat-tokens';

  @override
  String settingsSearchNoMatch(String query) {
    return 'L-ebda setting ma jaqbilx “$query”.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count riżultati',
      one: '$count riżultat',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Settings avvanzati tal-mudell';

  @override
  String get settingsAdvancedModelsDescription =>
      'Fakultattiv. Pin mudell għal tip wieħed ta \'xogħol; tieħu f\'idejha kull meta l-aġent juża dawk l-għodda. Kull ħaġa li titħalla awtomatikament isegwi l-mudell taċ-chat.';

  @override
  String get settingsTaskModelDefault => 'Default';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Isegwi l-mudell taċ-chat';

  @override
  String get settingsTaskModelCoding => 'Kodifikazzjoni';

  @override
  String get settingsTaskModelCodingDescription =>
      'Kitba, editjar u debugging kodiċi.';

  @override
  String get settingsTaskModelComputerUse => 'Użu tal-kompjuter';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Sewqan tal-browser u tad-desktop.';

  @override
  String get settingsTaskModelAndroidUse => 'Użu Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Jopera apps fuq apparat jew emulatur Android.';

  @override
  String get settingsTaskModelResearch => 'Riċerka';

  @override
  String get settingsTaskModelResearchDescription =>
      'Tiftix, qari u sommarju tas-sorsi.';

  @override
  String get knowledgeGraphHint =>
      'L-entitajiet l-aktar imsemmija tiegħek, ikkuluriti skond il-cluster. Linji jgħaqqdu entitajiet li jidhru fl-istess memorji. Tektek wieħed biex tara r-rabtiet u l-memorji tiegħu; drag biex pan, oqros jew Ctrl/⌘-iscroll biex iżum.';

  @override
  String get linkedEntities => 'Entitajiet konnessi';

  @override
  String get noLinkedEntities => 'Għadu mhux marbut ma\' entitajiet oħra.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 isemmi';
  }

  @override
  String get entityKindConcept => 'Kunċett';

  @override
  String get entityKindDomain => 'Dominju';

  @override
  String get entityKindEmail => 'Email';

  @override
  String get entityKindLink => 'Link';

  @override
  String get entityKindFile => 'Fajl';

  @override
  String get entityKindAcronym => 'Akronimu';

  @override
  String get entityKindIdentifier => 'Identifikatur';

  @override
  String get entityKindVersion => 'Verżjoni';

  @override
  String get openFullscreen => 'Iftaħ fullscreen';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get searchEntities => 'Sib entità';

  @override
  String get incomingCall => 'Sejħa deħlin';

  @override
  String get answerCall => 'Tweġiba';

  @override
  String get callMeLater => 'Ċempilli aktar tard';

  @override
  String get callingEllipsis => 'Insejħu...';

  @override
  String get reconnectingCall => 'Tqabbad mill-ġdid';

  @override
  String get agentWorking => 'Ħidma';

  @override
  String get micMuted => 'Siekta';

  @override
  String get speakerphone => 'Speaker';

  @override
  String get muteMic => 'Mute';

  @override
  String get unmuteMic => 'Iċċekkja';

  @override
  String get releaseToSend => 'Rilaxx biex tibgħat';

  @override
  String get callEnded => 'Sejħa ntemmet';

  @override
  String get openConversation => 'Konverżazzjoni miftuħa';

  @override
  String get callBack => 'Ċempel lura';

  @override
  String get letCallsReachYou => 'Ħalli s-sejħiet jasluk';

  @override
  String get callPermissionsIntro =>
      'L-aġenti tiegħek jistgħu jċempluk. Biex iċempel bħal telefonata waqt li NeoAgent ikun fl-isfond jew it-telefon tiegħek ikun imsakkar, jeħtieġ dawn.';

  @override
  String get showOverOtherApps => 'Uri fuq apps oħra';

  @override
  String get showOverOtherAppsDetail =>
      'Ġib l-iskrin tat-telefonata fejn tkun.';

  @override
  String get fullScreenCalls => 'Sejħiet fuq skrin sħiħ';

  @override
  String get fullScreenCallsDetail => 'Ċrieki fuq l-iskrin tal-lock.';

  @override
  String get unrestrictedBattery => 'Batterija mhux ristretta';

  @override
  String get unrestrictedBatteryDetail =>
      'Iżomm NeoAgent konness sabiex is-sejħiet jaslu.';

  @override
  String get permissionAllowed => 'Permess';

  @override
  String get triggerSectionCalendar => 'Kalendarju';

  @override
  String get triggerSectionFiles => 'Fajls u dokumenti';

  @override
  String get triggerSectionHome => 'Dar u midja';

  @override
  String get triggerSectionDevices => 'Apparati u postijiet';

  @override
  String get triggerSectionTasks => 'Kompiti';

  @override
  String get messagingMemberJoined => 'Membru ingħaqad';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Mexxi meta xi ħadd jingħaqad ma\' server Discord, grupp Telegram jew WhatsApp, kanal Slack, jew kamra Matrix.';

  @override
  String get messagingMemberLeft => 'Membru telaq';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Mexxi meta xi ħadd iħalli server Discord, Telegram jew grupp WhatsApp, kanal Slack, jew kamra Matrix.';

  @override
  String get messagingReactionAdded => 'Reazzjoni miżjuda';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Mexxi meta persuna permessa tirreaġixxi għal messaġġ f\'chat privat.';

  @override
  String get messagingPlatformDisconnected => 'Messaġġi skonnettjati';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Mexxi meta konnessjoni ta\' messaġġi tieqaf u teħtieġek, bħal wara d-logout.';

  @override
  String get googleCalendarEventStarting =>
      'Jibda l-avveniment tal-Google Calendar';

  @override
  String get googleCalendarEventCreated =>
      'Maħluq avveniment tal-Google Calendar';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Mexxi meta tidher avveniment jew stedina ġdida.';

  @override
  String get outlookCalendarEventStarting =>
      'Avveniment tal-Kalendarju tal-Outlook jibda';

  @override
  String get nextcloudCalendarEventStarting =>
      'Jibda l-avveniment tal-Kalendarju Nextcloud';

  @override
  String get runMinutesBeforeEachEvent =>
      'Mexxi numru stabbilit ta\' minuti qabel kull avveniment.';

  @override
  String get googleDriveFileAdded => 'Miżjud fajl Google Drive';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Mexxi meta fajl jiżdied ma\' Drive jew folder fih.';

  @override
  String get googleSheetsRowAdded => 'Miżjud ir-ringiela ta\' Google Sheets';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Mexxi meta ringieli ġodda jidhru f\'folja.';

  @override
  String get onedriveFileAdded => 'Miżjud fajl OneDrive';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Mexxi meta fajl jiżdied ma\' folder ta\' OneDrive.';

  @override
  String get nextcloudFileAdded => 'Miżjud fajl Nextcloud';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Mexxi meta fajl jiġi miżjud ma \'folder Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Fajl Nextcloud maqsum miegħek';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Mexxi meta xi ħadd jaqsam fajl jew folder miegħek.';

  @override
  String get notionItemAdded => 'Oġġett tad-database tal-kunċetti miżjud';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Mexxi meta oġġett jiġi miżjud ma \'database Notion.';

  @override
  String get notionItemUpdated => 'Oġġett tad-database tal-kunċetti aġġornat';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Mexxi meta oġġett f\'database Notion jinbidel.';

  @override
  String get trelloCardEnteredList => 'Karta Trello miżjuda mal-lista';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Mexxi meta karta tinħoloq jew titmexxa f\'lista.';

  @override
  String get figmaCommentAdded => 'Kumment Figma miżjud';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Mexxi meta xi ħadd jikkummenta fuq fajl Figma.';

  @override
  String get githubPrOpened => 'It-talba tal-ġibda tal-GitHub infetħet';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Mexxi meta tinfetaħ talba ġdida tal-ġibda f\'repożitorju.';

  @override
  String get githubWorkflowRunFailed =>
      'It-tmexxija tal-fluss tax-xogħol GitHub falliet';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Mexxi meta tħaddim ta\' GitHub Actions jonqos.';

  @override
  String get githubCommitPushed => 'GitHub impenn imbuttat';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Mexxi meta kommessi ġodda jilħqu fergħa.';

  @override
  String get mcpServerFailed => 'Is-server MCP falla';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Mexxi meta server MCP li kien qed jaħdem jonqos jew jeħtieġ li tidħol.';

  @override
  String get homeAssistantStateChanged =>
      'L-istat tal-Assistent tad-Dar inbidel';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Mexxi meta entità tinbidel, tilħaq stat, jew taqsam valur.';

  @override
  String get spotifyTrackChanged => 'Il-binarju ta\' Spotify inbidel';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Mexxi meta tibda tindaqq track differenti.';

  @override
  String get neorecallDailySummaryReady =>
      'NeoRecall sommarju ta\' kuljum lest';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Mexxi meta s-sommarju ta\' jum ikun finali.';

  @override
  String get neorecallConversationRecorded =>
      'Konverżazzjoni NeoRecall irreġistrata';

  @override
  String get runWhenARecordedConversationEnds =>
      'Mexxi meta tispiċċa konverżazzjoni rreġistrata.';

  @override
  String get geofenceTrigger => 'Ġeofence tal-post';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Mexxi meta t-telefown tiegħek jasal jew iħalli post. Jeħtieġ traċċar tal-post fuq it-telefon.';

  @override
  String get healthMetricRecorded => 'Metrika tas-saħħa rreġistrata';

  @override
  String get runWhenAHealthReadingArrives =>
      'Mexxi meta jasal qari tas-saħħa sinkronizzat, b\'għażla \'l fuq jew taħt valur.';

  @override
  String get wearableConnectionChanged =>
      'Li jintlibes konness jew skonnettjat';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Mexxi meta l-ilbies tiegħek jgħaqqad jew jiskonnettja.';

  @override
  String get taskRunFinished => 'Kompitu ieħor lest';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Mexxi wara li kompitu ieħor jispiċċa, jirnexxi jew ifalli.';

  @override
  String get appPackageOptional => 'Pakkett tal-app (mhux obbligatorju)';

  @override
  String get appPackageHelper => 'Per eżempju com.whatsapp';

  @override
  String get anyPlatform => 'Kwalunkwe pjattaforma';

  @override
  String get spaceIdOptional =>
      'Server, grupp, kanal, jew ID tal-kamra (mhux obbligatorju)';

  @override
  String get spaceIdHelper => 'Arloġġi vojta kull wieħed fih il-bot.';

  @override
  String get emojiOptional => 'Emoji (mhux obbligatorju)';

  @override
  String get chatIdOptional => 'Chat ID (mhux obbligatorju)';

  @override
  String get platformOptional => 'Pjattaforma (mhux obbligatorja)';

  @override
  String get platformOptionalHelper =>
      'Per eżempju whatsapp. Arloġġi vojta kollha.';

  @override
  String get minutesBefore => 'Minuti qabel';

  @override
  String get calendarIdOptional => 'ID tal-kalendarju (mhux obbligatorju)';

  @override
  String get calendarIdHelper => 'Vojta juża l-kalendarju primarju tiegħek.';

  @override
  String get invitesOnly => 'Stediniet biss minn ħaddieħor';

  @override
  String get nextcloudCalendarPath => 'Kalendarju';

  @override
  String get nextcloudCalendarPathHelper =>
      'Isem fil-lista tal-kalendarju Nextcloud, pereżempju personali';

  @override
  String get folderIdOptionalHelperDrive => 'Arloġġi vojta kollha ta\' Drive.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Vojt jara l-fowlder tal-għeruq.';

  @override
  String get driveFolderIdOptional => 'ID tal-folder (mhux obbligatorju)';

  @override
  String get spreadsheetId => 'ID tal-ispreadsheet';

  @override
  String get sheetRange => 'Firxa';

  @override
  String get sheetRangeHelper =>
      'Il-kolonni tat-tabella, pereżempju Sheet1!A:E';

  @override
  String get folderPathOptional => 'Mogħdija tal-folder (mhux obbligatorja)';

  @override
  String get folderPathHelper => 'Per eżempju Dokumenti';

  @override
  String get notionDatabaseId => 'ID tad-database';

  @override
  String get trelloListId => 'Lista ID';

  @override
  String get figmaFileKey => 'Ċavetta tal-fajl';

  @override
  String get figmaFileKeyHelper =>
      'Mill-link tal-fajl: figma.com/file/<key>/...';

  @override
  String get githubRepository => 'Repożitorju';

  @override
  String get workflowOptional => 'Fluss tax-xogħol (mhux obbligatorju)';

  @override
  String get workflowHelper => 'Isem tal-fajl bħal ci.yml';

  @override
  String get branchOptional => 'Fergħa (mhux obbligatorja)';

  @override
  String get branchHelper => 'Vojt juża l-fergħa default.';

  @override
  String get mcpServerIdOptional => 'ID tas-server MCP (mhux obbligatorju)';

  @override
  String get entityId => 'ID tal-Entità';

  @override
  String get entityIdHelper => 'Per eżempju binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Stat fil-mira (mhux obbligatorju)';

  @override
  String get targetStateHelper => 'Per eżempju fuq';

  @override
  String get aboveOptional => 'Fuq (mhux obbligatorju)';

  @override
  String get belowOptional => 'Hawn taħt (mhux obbligatorju)';

  @override
  String get placeName => 'Isem tal-post';

  @override
  String get latitude => 'Latitudni';

  @override
  String get longitude => 'Lonġitudni';

  @override
  String get radiusMeters => 'Raġġ f\'metri';

  @override
  String get geofenceTransition => 'Meta';

  @override
  String get arriving => 'Wasal';

  @override
  String get leaving => 'Nitilqu';

  @override
  String get healthMetric => 'Metrika tas-saħħa';

  @override
  String get healthMetricHelper => 'Per eżempju heart_rate, passi, piż';

  @override
  String get wearableTransition => 'Meta l-wearable';

  @override
  String get wearableConnects => 'Tgħaqqad';

  @override
  String get wearableDisconnects => 'Skonnettja';

  @override
  String get sourceTask => 'Wara l-kompitu';

  @override
  String get taskOutcome => 'Riżultat';

  @override
  String get anyOutcome => 'Kwalunkwe riżultat';

  @override
  String get succeeded => 'Irnexxielu';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 huwa nieqes jew mhux validu.';
  }

  @override
  String get triggerSectionMessaging => 'Messaġġi';

  @override
  String get triggerSectionDeveloper => 'Żviluppatur';

  @override
  String get triggerSectionMemory => 'Memorja';

  @override
  String get triggerSectionNews => 'Aħbarijiet';

  @override
  String get triggerSectionSystem => 'Sistema';

  @override
  String get searchTriggersHint => 'Fittex triggers, apps, jew avvenimenti';

  @override
  String get noTriggersMatch =>
      'L-ebda trigger ma jaqbel mat-tfittxija tiegħek.';

  @override
  String get triggerAccountMissing => 'Għadu l-ebda kont';

  @override
  String get pickTriggerKeyboardHint => 'Enter jagħżel l-ewwel riżultat';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 iqanqal';
  }

  @override
  String get addFromSkillsSh => 'Żid minn skills.sh';

  @override
  String get skillsShHint =>
      'Fittex hawn fuq biex issib ħiliet fuq skills.sh, jew waħħal link ta\' skills.sh jew kmand \"npx skills add\".';

  @override
  String get noSkillsShMatches =>
      'L-ebda ħiliet skills.sh ma jaqblu ma\' din it-tfittxija.';

  @override
  String get installingSkill => 'Qed jinstalla...';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Installat $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 jinstalla';
  }

  @override
  String get authVerify => 'Ivverifika';

  @override
  String get authCreateAccount => 'Oħloq kont';

  @override
  String get authNewInviteLink => 'Link ġdid għall-istedina';

  @override
  String get authShowPassword => 'Uri password';

  @override
  String get authHidePassword => 'Aħbi l-password';

  @override
  String get authPasswordWillBeRejected => 'dgħajjef wisq, se jiġi miċħud';

  @override
  String get authUsernameTooShort =>
      'L-ismijiet tal-utenti jeħtieġu mill-inqas 3 karattri.';

  @override
  String get authUsernameTaken => 'Dak l-isem tal-utent diġà ttieħed.';

  @override
  String get authSignupsClosed =>
      'Ir-reġistrazzjonijiet huma magħluqa fuq dan is-server. Staqsi lill-amministratur għal kont.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Dan is-server jaċċetta biss sign-ins fuq HTTPS. Iftaħ $arg1 minflok.';
  }

  @override
  String get authInsecureTransport =>
      'Dan is-server jaċċetta biss sign-ins fuq HTTPS. Qabbad magħha b\'indirizz https://.';

  @override
  String get authAccountNotFound => 'Dak il-kont m\'għadux jeżisti.';

  @override
  String get authQrRateLimited =>
      'Wisq talbiet ta\' QR sign-in. Stenna ftit, imbagħad aġġorna l-kodiċi.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Insejt il-password tiegħek? Staqsi lill-amministratur tas-server tiegħek biex jerġa \'jissettjah f\'Admin → Utenti.';

  @override
  String get authChangeServer => 'Ibdel is-server';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Jidħol f\'$arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Dan l-indirizz ma jwieġeb bħal server NeoAgent. Iċċekkja l-URL u erġa\' pprova.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Ma setgħetx tiftaħ konnessjoni sigura (HTTPS) għal $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Ma setax jilħaq $arg1 fuq HTTPS, u HTTP sempliċi lanqas ma wieġeb. Iċċekkja l-indirizz u l-port.';
  }

  @override
  String get adminResetPassword => 'Irrisettja l-password';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Irrisettja l-password għal $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Agħżel password ġdida għal $arg1. Jiġu ffirmati fuq kull apparat u jerġgħu jidħlu b\'din il-password.';
  }

  @override
  String get adminNewPassword => 'Password ġdida';

  @override
  String get adminSetPassword => 'Issettja l-password';

  @override
  String get authMissingFields => 'Imla kull qasam meħtieġ.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 reset il-password ta \'$arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Password aġġornata; l-utent kien iffirmat kullimkien.';

  @override
  String get authSignInTitle => 'Idħol f\'NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Skennja bit-telefon tiegħek, jew uża l-password tiegħek.';

  @override
  String get authOrUsePassword => 'jew uża l-password tiegħek';

  @override
  String get qrLoginWaitingTitle => 'Approva fuq it-telefon tiegħek';

  @override
  String get qrLoginWaitingBody =>
      'It-telefon tiegħek skennja l-kodiċi. Ikkonferma l-login hemm biex tispiċċa tidħol.';

  @override
  String get qrLoginSigningInOn => 'Iffirmar fuq';

  @override
  String get qrLoginLocation => 'Post';

  @override
  String get qrLoginWaitingForApproval => 'Stennija għall-approvazzjoni';

  @override
  String get qrLoginCancelAndUsePassword => 'Ikkanċella u uża password';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Il-login ġie rrifjutat fuq it-telefon tiegħek. Skennja l-kodiċi l-ġdid biex terġa\' tipprova.';

  @override
  String get signupKey => 'Ċavetta tar-reġistrazzjoni';

  @override
  String get signupKeyStepSubtitle =>
      'Kontijiet ġodda fuq dan is-server jeħtieġu ċavetta tar-reġistrazzjoni. Daħħal iċ-ċavetta li rċevejt mingħand amministratur.';

  @override
  String get signupKeyChange => 'Ibdel';

  @override
  String get signupKeyRequiredError =>
      'Daħħal iċ-ċavetta tar-reġistrazzjoni tiegħek.';

  @override
  String get signupKeyInvalidError =>
      'Dik iċ-ċavetta tar-reġistrazzjoni mhix valida. Iċċekkjaha u erġa\' pprova.';

  @override
  String get signupKeyUsedError =>
      'Dik iċ-ċavetta tar-reġistrazzjoni diġà ntużat. Itlob waħda ġdida lil amministratur.';

  @override
  String get adminRequireSignupKey => 'Eħtieġ ċavetta tar-reġistrazzjoni';

  @override
  String get adminRequireSignupKeyHint =>
      'Kontijiet ġodda jeħtieġu ċavetta għal darba waħda mingħand amministratur. Meta jkun mitfi, kulmin jilħaq dan is-server jista\' jirreġistra. L-ewwel kont qatt ma jeħtieġ ċavetta.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Kontijiet ġodda issa jeħtieġu ċavetta tar-reġistrazzjoni.';

  @override
  String get adminSignupOpenNotice => 'Issa kulħadd jista\' jirreġistra.';

  @override
  String get signupKeys => 'Ċwievet tar-reġistrazzjoni';

  @override
  String get signupKeysDescription =>
      'Ċwievet għal darba waħda biex tirreġistra sakemm tkun meħtieġa ċavetta. Kull ċavetta toħloq eżattament kont wieħed.';

  @override
  String get signupKeysNew => 'Ċwievet ġodda';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Mhux użati · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Użati · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Revokati · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Kollha · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Mhux użata';

  @override
  String get signupKeyStatusUsed => 'Użata';

  @override
  String get signupKeyStatusRevoked => 'Revokata';

  @override
  String get signupKeysExport => 'Esporta .txt';

  @override
  String get signupKeysCopied => 'Iċ-ċwievet ġew ikkupjati';

  @override
  String get signupKeyCopied => 'Iċ-ċavetta ġiet ikkupjata';

  @override
  String get signupKeysEmpty => 'M\'hemmx ċwievet f\'din il-lista.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Maħluqa fl-$arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Użata minn $arg1 fl-$arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Użata fl-$arg1 minn kont li minn dakinhar tħassar';
  }

  @override
  String get signupKeyRevokeTitle => 'Tirrevoka din iċ-ċavetta?';

  @override
  String get signupKeyRevokeMessage =>
      'Ħadd ma jkun jista\' jirreġistra biha. Dan ma jistax jitreġġa\' lura.';

  @override
  String get signupKeyRevoked => 'Iċ-ċavetta ġiet revokata.';

  @override
  String signupKeysShowMore(int count) {
    return 'Uri $count oħra';
  }

  @override
  String get signupKeysCreateTitle => 'Oħloq ċwievet tar-reġistrazzjoni';

  @override
  String get signupKeysCount => 'Numru ta\' ċwievet';

  @override
  String get signupKeysCountHelper => 'Minn 1 sa 500';

  @override
  String get signupKeysCountInvalid => 'Daħħal numru minn 1 sa 500.';

  @override
  String get signupKeysLabel => 'Tikketta (mhux obbligatorja)';

  @override
  String get signupKeysLabelHint => 'eż. Testers beta tar-rebbiegħa';

  @override
  String signupKeysCreateAction(int count) {
    return 'Oħloq ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Ċwievet lesti: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Agħti kull ċavetta lil persuna waħda biss. Iċ-ċwievet mhux użati jibqgħu fil-lista, biex tkun tista\' terġa\' tikkopjahom jew tesportahom aktar tard.';

  @override
  String get signupKeysSaveDialogTitle =>
      'Issejvja ċ-ċwievet tar-reġistrazzjoni';

  @override
  String get signupKeysExported => 'Iċ-ċwievet ġew esportati.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor ħoloq ċwievet tar-reġistrazzjoni ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor irrevoka ċavetta tar-reġistrazzjoni';
  }

  @override
  String get providerChooseUsername => 'Agħżel l-isem tal-utent tiegħek';

  @override
  String get providerChooseUsernameBody =>
      'Agħżel isem tal-utent disponibbli biex tlesti l-ħolqien tal-kont tiegħek.';

  @override
  String get dataSharingTitle => 'Aqsam id-dejta tal-użu';

  @override
  String get dataSharingDescription =>
      'Għin lil min imexxi dan is-server itejbu. Jaqsam kif tuża NeoAgent, qatt dak li tikteb jew taħżen.';

  @override
  String dataSharingSince(String date) {
    return 'Qed jinqasam minn $date.';
  }

  @override
  String get dataSharingWhatsShared => 'X\'jinqasam';

  @override
  String get dataSharingIncluded => 'Jinqasam';

  @override
  String get dataSharingExcluded => 'Qatt ma jinqasam';

  @override
  String get dataSharingIncludedDevice =>
      'It-tip ta\' apparat u l-verżjoni tal-app';

  @override
  String get dataSharingIncludedLocale =>
      'Il-lingwa tal-app u r-reġjun taż-żona tal-ħin, bħall-Ewropa';

  @override
  String get dataSharingIncludedFeatures =>
      'Liema funzjonijiet issettjajt, bħal kompiti, skills u integrazzjonijiet';

  @override
  String get dataSharingIncludedRuns =>
      'Liema għodod u mudelli jużaw il-ġirjiet tiegħek, bil-ħinijiet u l-għadd ta\' tokens';

  @override
  String get dataSharingIncludedActivity =>
      'Meta tuża NeoAgent, skont il-jum tal-ġimgħa u s-siegħa';

  @override
  String get dataSharingExcludedContent => 'Messaġġi, prompts u tweġibiet';

  @override
  String get dataSharingExcludedRuns =>
      'Titli tal-ġirjiet, input u riżultati tal-għodod';

  @override
  String get dataSharingExcludedFiles =>
      'Fajls, memorji u kull ħaġa oħra li taħżen';

  @override
  String get dataSharingExcludedIdentity =>
      'Ismek, l-email, l-indirizz IP u l-post tiegħek';

  @override
  String get dataSharingExcludedAccounts =>
      'Il-kontijiet li magħhom tqabbad l-integrazzjonijiet';

  @override
  String get dataSharingPooledNote =>
      'L-amministraturi jaraw biss totali ta\' kull min jaqsam, qatt lilek waħdek. Itfih meta trid u toħroġ mit-totali minnufih.';

  @override
  String get dataSharingConfirmTitle => 'Taqsam id-dejta tal-użu?';

  @override
  String get dataSharingConfirmAction => 'Aqsam';

  @override
  String get sharedUsageTitle => 'Użu maqsum';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Kontijiet li jaqsmu d-dejta tal-użu: $sharing minn $total. Totali biss, l-ebda kontenut.';
  }

  @override
  String get sharedUsageEmpty =>
      'Għadu ħadd ma jaqsam dejta tal-użu. Jista\' jinxtegħel minn Settings, Profil, Id-dejta tiegħek.';

  @override
  String get sharedUsageRuns => 'Ġirjiet maqsuma';

  @override
  String get sharedUsageAvgDuration => 'Tul medju';

  @override
  String get sharedUsageCompletedRuns => 'Ġirjiet lesti';

  @override
  String get sharedUsageStepsPerRun => 'Passi għal kull ġirja';

  @override
  String get sharedUsageDevices => 'Apparati';

  @override
  String get sharedUsageAppVersions => 'Verżjonijiet tal-app';

  @override
  String get sharedUsageLanguages => 'Lingwi';

  @override
  String get sharedUsageRegions => 'Reġjuni';

  @override
  String get sharedUsageFeatures => 'Użu tal-funzjonijiet';

  @override
  String get sharedUsageFeaturesDescription =>
      'Is-sehem tal-kontijiet li jaqsmu li ssettjawha.';

  @override
  String get sharedUsageTools => 'Għodod';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'L-aktar għodod imsejħa ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Sejħiet: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Fallew: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Integrazzjonijiet';

  @override
  String get sharedUsageMessaging => 'Kanali tal-messaġġi';

  @override
  String get sharedUsageTriggers => 'Kif jibdew il-ġirjiet';

  @override
  String get sharedUsageActivity => 'Meta jintuża';

  @override
  String get sharedUsageActivityDescription =>
      'Ġirjiet skont il-jum tal-ġimgħa u s-siegħa, UTC.';

  @override
  String get sharedUsageModels => 'Prestazzjoni tal-mudelli';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'medja $latency · $cached% mill-cache · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Kontijiet: $count';
  }

  @override
  String get sharedUsageNoData => 'Xejn f\'dan il-perjodu.';

  @override
  String get sharedUsageNotReported => 'Għadu mhux irrappurtat';

  @override
  String get sharedUsageFeatureAgents => 'Aktar minn aġent wieħed';

  @override
  String get sharedUsageFeatureTasks => 'Kompiti skedati';

  @override
  String get sharedUsageFeatureSkills => 'Skills';

  @override
  String get sharedUsageFeatureMcp => 'Servers MCP';

  @override
  String get sharedUsageFeatureIntegrations => 'Integrazzjonijiet';

  @override
  String get sharedUsageFeatureMessaging => 'Kanali tal-messaġġi';

  @override
  String get sharedUsageFeatureMemory => 'Memorja';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in qsim tad-dejta telemetrija apparati funzjonijiet għodod mudelli attività';

  @override
  String get yourOAuthApp => 'L-app OAuth tiegħek';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'L-app OAuth tiegħek ta’ $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Dan is-server m’għandux app globali ta’ $provider, għalhekk tikkonnettja b’app OAuth li tirreġistra int stess. Is-sigriet tal-klijent jinħażen ikkriptat u qatt ma jerġa’ jintwera.';
  }

  @override
  String get oauthAppStepCreate => '1. Oħloq l-app';

  @override
  String get openDeveloperConsole => 'Iftaħ il-konsol tal-iżviluppatur';

  @override
  String get oauthAppStepCallback => '2. Irreġistra dan il-URL tal-callback';

  @override
  String get callbackUrlCopied => 'URL tal-callback ikkupjat';

  @override
  String get oauthAppScopes => 'Scopes li għandhom jiġu permessi';

  @override
  String get scopesCopied => 'Scopes ikkupjati';

  @override
  String get oauthAppStepCredentials => '3. Waħħal il-kredenzjali tal-app';

  @override
  String get couldNotSaveOAuthApp => 'Ma setgħetx tiġi ssejvjata l-app OAuth.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Tneħħi l-app tiegħek ta’ $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'Il-kontijiet konnessi jibqgħu fil-lista iżda ma jibqgħux jaħdmu sakemm iżżid app mill-ġdid.';

  @override
  String get globalIntegrationConfiguration =>
      'Konfigurazzjoni globali tal-integrazzjonijiet';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Apps OAuth fakultattivi għas-server kollu. Meta integrazzjoni jkollha waħda, kull kont jużaha u ma jistax iżid tiegħu. Ħalli integrazzjoni mhux issettjata u kull utent iwaqqaf l-app tiegħu. Is-sigrieti huma għall-kitba biss: ħallih vojt biex iżżomm il-valur maħżun.';

  @override
  String get globalStatus => 'Globali';

  @override
  String get perUserStatus => 'Għal kull utent';

  @override
  String get phoneSyncGuidance =>
      'Aqsam il-kalendarji u l-kuntatti ta’ dan it-telefon mal-aġent tiegħek. Jaħdem ma’ kull kont li diġà jinsab fuq it-telefon.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Iftaħ NeoAgent fuq it-telefon u ixgħel il-qsim hemmhekk. L-aġent imbagħad jara l-kalendarji u l-kuntatti tal-kontijiet kollha fuq dak it-telefon.';

  @override
  String get manageOnThisPhone => 'Immaniġġja fuq dan it-telefon';

  @override
  String get setUpOnThisPhone => 'Waqqaf fuq dan it-telefon';

  @override
  String get setUpOnPhone => 'Waqqaf fuq it-telefon tiegħek';

  @override
  String emailConnectedArg1(String email) {
    return '$email konness';
  }

  @override
  String get couldNotConnectEmail => 'Dan il-kont ma setax jiġi konness.';

  @override
  String get emailSetupTitle => 'Qabbad l-email u l-kalendarju';

  @override
  String get emailChecking => 'Qed tiġi ċċekkjata l-kaxxa postali…';

  @override
  String get emailSetupIntro =>
      'Uża password tal-app mill-fornitur tal-email. Mingħajr konsol tal-iżviluppatur, lest f’ftit minuti.';

  @override
  String emailOpenArg1(String provider) {
    return 'Iftaħ $provider';
  }

  @override
  String get emailStepServers => '1. Daħħal is-servers';

  @override
  String get emailStepPassword => '1. Oħloq password tal-app';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Iftaħ il-passwords tal-app ta’ $provider';
  }

  @override
  String get emailStepSignIn => '2. Idħol';

  @override
  String get appPassword => 'Password tal-app';

  @override
  String get appPasswordHelper =>
      'L-ispazji ma jimpurtawx. NeoAgent jaħżinha kriptata.';

  @override
  String get emailUsernameOptional => 'Isem l-utent, jekk mhux l-email tiegħek';

  @override
  String get emailIncludeCalendar => 'Inkludi l-kalendarju';

  @override
  String get emailIncludeContacts => 'Inkludi l-kuntatti';

  @override
  String get imapServer => 'Server IMAP';

  @override
  String get smtpServer => 'Server SMTP';

  @override
  String get caldavUrlOptional => 'URL CalDAV (mhux obbligatorju)';

  @override
  String get carddavUrlOptional => 'URL CardDAV (mhux obbligatorju)';

  @override
  String get alternativeEmail =>
      'Qabbad il-kaxxa postali b’password tal-app, jew il-kalendarju bil-link iCal tiegħu. Lest f’ftit minuti.';

  @override
  String get alternativePhone =>
      'Aqsam il-kalendarju u l-kuntatti li diġà għandek fuq it-telefon permezz tal-app NeoAgent.';

  @override
  String get alternativePhoneElsewhere =>
      'Aqsam il-kalendarju u l-kuntatti li diġà għandek fuq it-telefon. Waqqafha fl-app NeoAgent fuq it-telefon.';

  @override
  String get skipTheDeveloperConsole => 'Mingħajr il-konsol tal-iżviluppatur';

  @override
  String get phoneSyncPromptTitle =>
      'Tħalli lill-aġent jara l-kalendarju tiegħek?';

  @override
  String get phoneSyncPromptBody =>
      'Aqsam il-kalendarji u l-kuntatti ta’ dan it-telefon biex l-aġent jippjana madwar jumek. Tista’ tibdel dan meta trid f’Għodod › Integrazzjonijiet.';

  @override
  String get phoneSyncTitle => 'Aqsam il-kalendarju u l-kuntatti tat-telefon';

  @override
  String get phoneSyncIntro =>
      'L-aġent jara l-kalendarji u l-kuntatti tal-kontijiet kollha fuq dan it-telefon. Mingħajr konsol tal-iżviluppatur u mingħajr dħul ieħor.';

  @override
  String get phoneSyncPointAccounts =>
      'Jaħdem mal-kontijiet Google, Outlook, iCloud u Exchange fuq dan it-telefon.';

  @override
  String get phoneSyncPointPrivate =>
      'Maqsum biss mas-server NeoAgent tiegħek, li jaħżinhom kriptati.';

  @override
  String get phoneSyncPointWrites =>
      'L-avvenimenti li jżid l-aġent joħloqhom dan it-telefon u jissinkronizzaw bħas-soltu.';

  @override
  String get phoneSyncCalendarHint =>
      'Avvenimenti minn 30 jum ilu sa 90 jum ’il quddiem';

  @override
  String get phoneSyncContacts => 'Kuntatti';

  @override
  String get phoneSyncContactsHint =>
      'Ismijiet, indirizzi tal-email u numri tat-telefon';

  @override
  String get phoneSyncOtherAgent =>
      'Dan it-telefon qed jaqsam ma’ aġent ieħor. Jekk taqsam hawn jgħaddi għal dan l-aġent.';

  @override
  String get phoneSyncDenied =>
      'NeoAgent għad m’għandux aċċess. Ippermettih fis-Settings u erġa’ lura.';

  @override
  String get openPhoneSettings => 'Iftaħ is-Settings';

  @override
  String get phoneSyncShare => 'Aqsam ma’ NeoAgent';

  @override
  String get phoneSyncStop => 'Waqqaf il-qsim';

  @override
  String get phoneSyncWaiting => 'Qed nistennew l-ewwel sinkronizzazzjoni…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'L-aħħar sinkronizzazzjoni $time';
  }

  @override
  String get calendarLink => 'Link tal-kalendarju';

  @override
  String get calendarLinkHelper =>
      'L-indirizz iCal tal-kalendarju. Kull min għandu jista’ jaqra l-kalendarju, għalhekk żommu privat.';

  @override
  String get calendarLinkName => 'Isem (mhux obbligatorju)';

  @override
  String get calendarLinkAdded => 'Il-kalendarju żdied';

  @override
  String get toolsApps => 'Apps';

  @override
  String get reconnect => 'Erġa\' qabbad';

  @override
  String get reconnectNeeded => 'Jeħtieġ jerġa\' jitqabbad';

  @override
  String get mixedAccess => 'Aċċess imħallat';

  @override
  String disconnectAccountTitle(String account) {
    return 'Tiskonnettja $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'L-aġent jitlef l-aċċess għal $apps permezz ta\' dan il-kont.';
  }

  @override
  String get neoRouterServerDescription =>
      'Qabbad in-NeoRouter tiegħek darba u kull kont hawn jużah għax-xogħol mixgħul hawn taħt.';

  @override
  String get neoRouterUserDescription =>
      'Uża l-kont NeoRouter tiegħek għax-xogħol mixgħul hawn taħt minflok il-fornituri ta\' dan is-server.';

  @override
  String get neoRouterAddress => 'Indirizz tan-NeoRouter';

  @override
  String get neoRouterConnect => 'Qabbad in-NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Approva lil NeoAgent fin-NeoRouter. Juri l-kodiċi $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Iftaħ mill-ġdid';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Imqabbad ma\' $arg1';
  }

  @override
  String get neoRouterUnreachable => 'In-NeoRouter mhux disponibbli bħalissa.';

  @override
  String get neoRouterDisconnect => 'Aqta\'';

  @override
  String get neoRouterDisconnectBody =>
      'NeoAgent jieqaf juża dan in-NeoRouter. Biex tirtira wkoll iċ-ċavetta, revokaha fin-NeoRouter taħt Ċwievet API.';

  @override
  String get neoRouterServerInUse =>
      'Dan is-server diġà juża NeoRouter għal kulħadd. Qabbad il-kont NeoRouter tiegħek għall-mudelli u l-baġit tiegħek.';

  @override
  String get neoRouterConnected => 'In-NeoRouter huwa mqabbad.';

  @override
  String get neoRouterRoleChat => 'Chat u għarfien tal-istampi';

  @override
  String get neoRouterRoleSystemOne => 'Deċiżjonijiet System One';

  @override
  String get neoRouterRoleTranscription => 'Diskors għal test';

  @override
  String get neoRouterRoleLive => 'Vuċi diretta';

  @override
  String get neoRouterRoleEmbeddings => 'Tfittxija fil-memorja';

  @override
  String get neoRouterRoleImages => 'Ħolqien ta\' stampi';

  @override
  String get neoRouterRoleSearch => 'Tfittxija fuq il-web';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'Disponibbli fin-NeoRouter tiegħek: $arg1';
  }

  @override
  String get neoRouterNoModels => 'Għad m\'hemm xejn fin-NeoRouter tiegħek.';

  @override
  String get neoRouterPicksModels =>
      'NeoRouter jagħżel il-mudell għal kull talba, għalhekk din l-għażla ma tintużax.';

  @override
  String neoRouterNotAllowedArg1(Object? arg1) {
    return '$arg1 fin-NeoRouter tiegħek, iżda ċ-ċavetta ta\' NeoAgent għadha ma tistax tużahom (pereżempju dawk bi ħlas). Ippermettihom għal NeoAgent taħt Ċwievet API fin-NeoRouter.';
  }

  @override
  String get neoRouterNoDecisionModels =>
      'Jeħtieġ mudelli tad-deċiżjoni bħal Jev. Il-klassifikaturi tas-sigurtà ma jistgħux iwieġbu dawn il-mistoqsijiet.';

  @override
  String get voiceLiveNoProvider =>
      'L-ebda fornitur tal-vuċi diretta mhu mwaqqaf. Żid ċavetta ta\' OpenAI jew Google AI, jew qabbad NeoRouter, taħt Mudelli → Ġib iċ-ċavetta tiegħek.';

  @override
  String get voiceSttAutoNeoRouter =>
      'Awtomatiku (NeoRouter jagħżel il-mudell)';

  @override
  String get voiceNotOffered => 'M\'għadux offrut, agħżel ieħor';
}
