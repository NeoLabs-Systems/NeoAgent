// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Latvian (`lv`).
class AppL10nLv extends AppL10n {
  AppL10nLv([String locale = 'lv']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Laipni lūdzam';

  @override
  String get onboardingEyebrowCommunication => 'Komunikācija';

  @override
  String get onboardingEyebrowIntelligence => 'Intelekts';

  @override
  String get onboardingEyebrowComputer => 'Dators';

  @override
  String get onboardingEyebrowAutomation => 'Automatizācija';

  @override
  String get onboardingNext => 'Tālāk';

  @override
  String get onboardingIntroCouldNotLoad => 'Ievadu nevarēja ielādēt.';

  @override
  String get onboardingModelDescription =>
      'Izvēlieties modeli, kas NeoAgent jāizmanto pēc noklusējuma, vai ļaujiet tam izvēlēties automātiski.';

  @override
  String get onboardingLoadingModels => 'Notiek modeļu ielāde…';

  @override
  String get noAiModelTitle =>
      'Neviens mākslīgā intelekta modelis vēl nav iestatīts';

  @override
  String get noAiModelBody =>
      'Pievienojiet API atslēgu no pakalpojumu sniedzēja, piemēram, OpenAI, Anthropic vai Google. Pēc tam NeoAgent parāda modeļus, kurus varat izmantot.';

  @override
  String get noAiModelChatBody =>
      'Lai atbildētu, NeoAgent ir nepieciešams AI modelis. Pievienojiet API atslēgu no pakalpojumu sniedzēja, piemēram, OpenAI, Anthropic vai Google.';

  @override
  String get noAiModelAdminHint =>
      'Kā administrators varat arī iestatīt pakalpojumu sniedzējus ikvienam sadaļā Administrēšana → Pakalpojumu sniedzēji.';

  @override
  String get addApiKey => 'Pievienojiet API atslēgu';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform ir pievienots.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Gaida $platform savienojuma izveidi…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Iestatījumu nevarēja saglabāt: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Gatavs';

  @override
  String get onboardingStepRequired => 'Obligāti';

  @override
  String get onboardingStepOptional => 'Pēc izvēles';

  @override
  String get onboardingStepCloudOrLocal => 'Mākonis vai lokāls';

  @override
  String get onboardingStepComputer => 'Dators';

  @override
  String get onboardingStepRoutines => 'Rutīnas';

  @override
  String get onboardingComputerChoiceTitle => 'Kur tam vajadzētu\ndarboties?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Varat pārslēgties katrā sesijā.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Privātā smilšu kaste · vienmēr ieslēgta';

  @override
  String get onboardingThisComputer => 'Šis dators';

  @override
  String get onboardingThisComputerSubtitle =>
      'Jūsu faili, lietotnes un pārlūkprogramma';

  @override
  String get onboardingSearchApps => 'Meklēt lietotnes…';

  @override
  String get onboardingRoutinesDescription =>
      'Rezultāti tiek parādīti jūsu tērzēšanā.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Rezultāti tiek saņemti kā paziņojumi.';

  @override
  String get onboardingNotifications => 'Paziņojumi';

  @override
  String get onboardingReadyTitle => 'Viss ir\ngatavs.';

  @override
  String get onboardingReadyDescription => 'Nosūtiet savu pirmo ziņojumu.';

  @override
  String get onboardingMessageNeoagent => 'Ziņojums NeoAgent';

  @override
  String get onboardingAskAnything => 'Jautājiet jebko…';

  @override
  String get onboardingOpenNeoagent => 'Atveriet NeoAgent';

  @override
  String get onboardingStarterTrip => 'Plānojiet nedēļas nogales ceļojumu';

  @override
  String get onboardingStarterLanding => 'Izveidojiet galveno lapu';

  @override
  String onboardingQuickSteps(int count) {
    return '$count ātrie soļi';
  }

  @override
  String get taskNeedsEmail => 'Vispirms pievienojiet e-pastu';

  @override
  String get taskNeedsCalendar => 'Vispirms pievienojiet kalendāru';

  @override
  String get taskNeedsModel => 'Vispirms iestatiet AI modeli';

  @override
  String get taskPromptDailyRecap =>
      'Rezumējiet manu dienu: apkopojiet šodien notikušās sarunas, pabeigtos darbus un lēmumus, pēc tam uzskaitiet visu, kas man būtu jāturpina rīt. Saīsiniet to un nosūtiet to man.';

  @override
  String get taskPromptInboxCheck =>
      'Pārbaudiet manu e-pasta iesūtni, vai nav ziņojumu, kas saņemti kopš pēdējās pārbaudes. Sūtiet man ziņojumus tikai par steidzamiem e-pasta ziņojumiem vai uz kuriem ir jāatbild, katram pievienojot vienas rindiņas kopsavilkumu. Ja nekam nav vajadzīga mana uzmanība, nesūtiet neko.';

  @override
  String get taskPromptMorningBriefing =>
      'Sagatavojiet manu rīta instruktāžu: šodienas laikapstākļi, kur es atrodos, notikumi manā kalendārā un svarīgākie atvērtie vienumi, par kuriem es zinu. Nosūtiet to kā īsu, skenējamu ziņojumu.';

  @override
  String get taskPromptTomorrowPrep =>
      'Paskaties manā rītdienas kalendārā. Katrā sanāksmē pastāstiet man, par ko tā ir, kas ir iesaistīts un kas man būtu jāsagatavo. Ja rītdiena ir tukša, nesūtiet neko.';

  @override
  String get taskPromptNewsDigest =>
      'Meklējiet tīmeklī šodienas svarīgākās ziņas par man rūpīgām tēmām (izmantojiet to, ko atceraties par manām interesēm). Nosūtiet man īssavilkumu ar līdz pieciem vienumiem ar vienu teikumu katrā un saiti.';

  @override
  String get taskPromptWeeklyReview =>
      'Pārskatiet manu nedēļu: kas ir paveikts, kas paslīdēja un kas vēl ir atklāts. Iesakiet trīs svarīgākās lietas, kurām nākamnedēļ koncentrēties.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Saistiet tālruņa numuru, kas pieder aģentam. Ikviens, kam atļaujat, var tērzēt ar to tiešajās tērzētavās un grupās.';

  @override
  String get whatsappSelfChatDescription =>
      'Saistiet savu numuru un sarunājieties ar aģentu tērzētavā “Ziņojums pats”. Visas pārējās tērzēšanas sarunas un grupas šajā kontā tiek ignorētas.';

  @override
  String get chatSendHintMac => '⌘↵ nosūtīt';

  @override
  String get chatSendHintOther => 'Ctrl+Enter, lai nosūtītu';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Šim galapunktam ir nepieciešams pamata URL.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Mainītā e-pasta adrese tiek apstiprināta pirms tās izmantošanas.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Uzvar lēmums, kas atrodas augstāk ķēdē.';

  @override
  String get aDeletedAccount => 'dzēsts konts';

  @override
  String get aFridayLookBackAtThe =>
      'Piektdienas atskats uz nedēļu un plāns nākamajai.';

  @override
  String get aKeyThatAsksForA =>
      'Atslēga, kas prasa ievadīt PIN vai pirkstu nospiedumu, arī aizstāj jūsu divu faktoru kodu.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Valodas modelis novērtēja šo ziņojumu, jo SystemOne ir izslēgta.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'NeoAgent iestatīšanas metadatu fails pārsniedza drošā izmēra ierobežojumu.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Serverī ir pieejama jaunāka tīmekļa versija. Atkārtoti ielādējiet, lai iegūtu jaunāko komplektu.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Privāta darbvirsma ar Chromium, failiem, teksta redaktoru, termināli un Python. Jūsu darbs tiek saglabāts starp sesijām.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Privāts Linux dators vai Android ierīce.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Nevarēja lejupielādēt nepieciešamo NeoAgent iestatīšanas failu.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Komandas biedrs nosūta jums uzaicinājuma saiti. Kad jūs to pieņemat, viņi ';

  @override
  String get aTeammateSentYouAnInvite =>
      'komandas biedrs nosūtīja jums uzaicinājuma saiti, ievadiet to šeit, lai pievienotos viņu komandai.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Pagaidu lejupielāde tiks dzēsta vēlāk.';

  @override
  String get aValueIsStored => 'Vērtība tiek saglabāta.';

  @override
  String get access => 'Piekļuve';

  @override
  String get accessActivity => 'Piekļuves darbība';

  @override
  String accessArg1(Object? arg1) {
    return 'Piekļuve: $arg1';
  }

  @override
  String get accessMode => 'Piekļuves režīms';

  @override
  String get accessPermissions => 'Piekļuves atļaujas';

  @override
  String get accessToken => 'piekļuves marķieris';

  @override
  String get accessToken2 => 'Piekļuves pilnvara';

  @override
  String get account => 'Konts';

  @override
  String accountArg1(Object? arg1) {
    return 'Konts #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Brīdinājumi par konta maiņu';

  @override
  String get accountEmail => 'Konta e-pasts';

  @override
  String get accountEmailIsOffUntilThese =>
      'Konta e-pasts ir izslēgts, kamēr nav iestatīti: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent izmanto šo valodu visur lietotnē. Pirmo reizi pierakstoties, tas seko šai ierīcei. Pēc tam izvēle tiek saglabāta jūsu kontā un tiek izmantota katrā ierīcē.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Nevarēja mainīt valodu: $error';
  }

  @override
  String get accountLanguageTitle => 'Valoda';

  @override
  String get accountNumber => 'Konta numurs';

  @override
  String get accountSettings => 'Konta iestatījumi';

  @override
  String get accounts => 'Konti';

  @override
  String get accountsByTokensUsedAllTime =>
      'Konti pēc izmantotajiem marķieriem, visu laiku.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'kontu mākoņdatoriem. Izmaiņas tiek piemērotas pēc servera ';

  @override
  String get accountsOnThisServer => 'Konti šajā serverī';

  @override
  String get active => 'Aktīvs';

  @override
  String get activeSessions => 'Aktīvās sesijas';

  @override
  String get activeToday => 'Aktīvs šodien';

  @override
  String get add => 'Pievienot';

  @override
  String get addAProviderCredentialFirstIts =>
      'Vispirms pievienojiet pakalpojumu sniedzēja akreditācijas datus. Tās modeļi šeit parādās vienreiz ';

  @override
  String get addAgent => 'Pievienot aģentu';

  @override
  String get addAnotherSignInMethodBefore =>
      'Pirms šīs metodes noņemšanas pievienojiet citu pierakstīšanās metodi.';

  @override
  String get addBinding => 'Pievienojiet iesiešanu';

  @override
  String get addByNameOrId => 'Pievienojiet pēc vārda vai ID';

  @override
  String get addByNameOrIdInstead => 'Pievienojiet pēc vārda vai ID';

  @override
  String get addCredentialBinding =>
      'Pievienojiet akreditācijas datu saistīšanu';

  @override
  String get addEntry => 'Pievienot ierakstu';

  @override
  String get addKey => 'Pievienot atslēgu';

  @override
  String get addMcpServer => 'Pievienojiet MCP serveri';

  @override
  String get addMemory => 'Pievienot atmiņu';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Pievienojiet vairāk garuma vai cita veida rakstzīmes.';

  @override
  String get addPeopleOrGroups => 'Pievienojiet personas vai grupas';

  @override
  String get addSecurityKey => 'Pievienojiet drošības atslēgu';

  @override
  String get addSomeoneOrAGroup => 'Pievienojiet kādu personu vai grupu';

  @override
  String get addTask => 'Pievienot uzdevumu';

  @override
  String get addTests => 'Pievienojiet testus';

  @override
  String get addTestsForThePartsOf =>
      'Pievienojiet testus tām šī projekta daļām, kurām ir vismazākais pārklājums, un pēc tam palaidiet tās.';

  @override
  String get addTheirOwnKeysInSettings =>
      'Iestatījumos pievienojiet savas atslēgas.';

  @override
  String get addToPrompt => 'Pievienot uzvednei';

  @override
  String get added => 'Pievienots';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Pievienots $arg1 · Pēdējo reizi lietots $arg2';
  }

  @override
  String get addressWithTheProvider => 'adrese ar pakalpojumu sniedzēju.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Pielāgojiet skaļruņu skaļumu, pārskatiet aparatūras pogu noklusējuma iestatījumus un pārvaldiet šo palaišanas sesiju.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Pielāgojiet meklēšanas vai statusa filtru, lai redzētu vairāk ziņojumapmaiņas kanālu.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Šeit noregulējiet skaļruņu skaļumu.';

  @override
  String get admin => 'Administrators';

  @override
  String adminArg1(Object? arg1) {
    return 'Administrators › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Šeit tiek rādītas administratora dotācijas, uzaicinājumu saites un pārvaldības izmaiņas.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Uzlabots manuāls grafiks īpašiem gadījumiem.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Papildu: minūtes stunda diena mēnesis darba diena.';

  @override
  String get againRightAway => 'uzreiz atkal.';

  @override
  String get agent => 'Aģents';

  @override
  String agentArg1(Object? arg1) {
    return 'Aģents: $arg1';
  }

  @override
  String get agentCalls => 'Aģenta zvani';

  @override
  String get agentCommunication => 'Aģentu komunikācija';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Aģenta komunikācija: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Aģenta režīms rediģē darbvietu · ⌘↵ nosūtīt · ⌘N jauna sesija';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Aģents apstājas un pirms izpildes lūdz tavu atļauju.';

  @override
  String get agentProfile => 'Aģenta profils';

  @override
  String get agentVisibleName => 'Aģentam redzamais vārds';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Aģents vēlas izmantot $arg1. Pieskarieties, lai izlemtu.';
  }

  @override
  String get agents => 'Aģenti';

  @override
  String get aiAnswerUnreadable => 'AI atbilde nav nolasāma';

  @override
  String get aiProviderKeys => 'AI nodrošinātāja atslēgas';

  @override
  String get aiUnavailable => 'AI nav pieejams';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'brīdinājumi un citi konta e-pasta ziņojumi no.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Brīdina, kad ziņojumapmaiņas savienojumam nepieciešama lietotāja uzmanība';

  @override
  String get all => 'Visi';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Visi aģenti ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Visi $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Pašlaik tiek izmantoti visi mākoņdatoru sloti. Pēc brīža mēģiniet vēlreiz.';

  @override
  String get allComputerSlotsAreBusy => 'Visi datoru sloti ir aizņemti';

  @override
  String get allTables => 'Visi galdi';

  @override
  String get allTime => 'Visu laiku';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Visi rīki ir atļauti — aģents var izmantot jebkuru iespēju bez prasīšanas. ';

  @override
  String get allow => 'Atļaut';

  @override
  String get allowedRunsWithoutAsking => 'Atļauts. Skrien bez prasīšanas.';

  @override
  String get allowAll => 'Atļaut visu';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Atļaujiet NeoAgent “Instalēt nezināmas lietotnes” un pēc tam mēģiniet vēlreiz atjaunināt.';

  @override
  String get allowOnce => 'Atļaut vienu reizi';

  @override
  String get allowSender => 'Atļaut sūtītāju';

  @override
  String get allowSession => 'Atļaut sesiju';

  @override
  String get allowTheAgentToStartAn =>
      'Ļaujiet aģentam sākt ar jums balss zvanu lietotnē.';

  @override
  String get allowedOrigins => 'Atļautā izcelsme';

  @override
  String get allowedPathPrefix => 'Atļautais ceļa prefikss';

  @override
  String get allowsYouCanChangeThatPer =>
      'ļauj. Vēlāk varat to mainīt katrai personai. Saites nekad nepiešķir ';

  @override
  String get alreadyBelongsToAnExistingAccount => 'jau pieder esošam kontam';

  @override
  String get alreadyLinkedToAnotherAccount => 'jau ir saistīts ar citu kontu';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'jau ir saistīts ar citu neoagent kontu';

  @override
  String get alreadyUsed => 'jau lietots';

  @override
  String get always => 'Vienmēr';

  @override
  String get alwaysAllow => 'Vienmēr atļaut';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      'Izmantojot opciju Vienmēr atļaut, politika tiek saglabāta neatgriezeniski — to varat mainīt sadaļā Iestatījumi.';

  @override
  String get alwaysAsk => 'Vienmēr jautājiet';

  @override
  String get alwaysEngage => 'Vienmēr iesaistieties';

  @override
  String get alwaysJoins => 'Vienmēr pievienojas';

  @override
  String get anApiKeyIsRequired => 'Nepieciešama API atslēga.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Vakara kopsavilkums par notikušo un turpmākajiem pasākumiem.';

  @override
  String get anHttpOrHttpsUrlIs => 'Nepieciešams http vai https URL.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'un analītika. Komandas saites ir pieejamas komandas lapā.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Android APK instalēšana šajā platformā nav pieejama.';

  @override
  String get androidApp => 'Android lietotne';

  @override
  String get androidControl => 'Android vadība';

  @override
  String get androidCouldNotStart => 'Android nevarēja startēt';

  @override
  String get androidNotificationReceived => 'Saņemts Android paziņojums';

  @override
  String get androidOnly => 'Tikai Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Android pakotnes instalētāju nevarēja atvērt.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Android ekrāns — pieskarieties, lai pieskarties, velciet, lai velciet';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Atbildes @minions par problēmām un izvilkšanas pieprasījumiem';

  @override
  String get anyone => 'Jebkurš';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Ikviens šajā platformā var nosūtīt ziņojumu $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Ikviens šajā platformā var ziņot par $arg1, izmantojot $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Ikviens, kurš var sasniegt šo kontu, var runāt ar $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Ikviens, kam ir saite, var pievienoties, līdz beidzas tās derīguma termiņš vai jūs to atsaucat.';

  @override
  String get apiHttpsOrigin => 'API HTTPS izcelsme';

  @override
  String get apiKey => 'API atslēga';

  @override
  String get apiKey2 => 'api atslēga';

  @override
  String get apiKey3 => 'API atslēga';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api key anthropic claude openai gpt xai grok google gemini minimax nvidia nim openrouter akreditācijas dati';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API atslēgas un galapunkti AI, meklēšanas un balss pakalpojumu sniedzējiem. Viņi ';

  @override
  String get apiRequest => 'API pieprasījums';

  @override
  String get apiYourOwnServerASelf =>
      'API — jūsu serveris, pašmitināts modelis vai cits ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'APK lejupielāde neizdevās, izmantojot HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Nepieciešams lietotnes nosaukums.';

  @override
  String get appUpdates => 'Lietotņu atjauninājumi';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Šai būvei nav konfigurēti lietotņu atjauninājumi.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Pašreizējā skrējienā tika lietoti $arg1 rindas vadības atjauninājumi.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Lietots $arg1 stūres atjauninājums(-i).';
  }

  @override
  String get apply => 'Pieteikties';

  @override
  String get applyBehaviorNotes => 'Lietojiet uzvedības piezīmes';

  @override
  String get applyCoreMemory => 'Izmantojiet galveno atmiņu';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Sensitīvu aģentu rīku apstiprināšanas pieprasījumi';

  @override
  String get approvalRequired => 'Nepieciešams apstiprinājums';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Apstiprinājums paliek jūsu autentificētajā mobilajā sesijā, un katra koda derīguma termiņš beidzas automātiski pēc īsa laika.';

  @override
  String get approveLogin => 'Apstipriniet pieteikšanos';

  @override
  String get approveQrLogin => 'Apstipriniet QR pieteikšanos';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Apstipriniet to tikai tad, ja tikko sākāt pieteikšanos šajā ierīcē.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Apstiprināta $arg1 pieteikšanās.';
  }

  @override
  String get approvedOnly => 'Tikai apstiprināts';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Apstiprināta savienošana pārī $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Apstiprinātas personas un grupas';

  @override
  String get approvedPeopleOnly => 'Tikai apstiprinātas personas';

  @override
  String get archive => 'Arhīvs';

  @override
  String get archiveAgent => 'Arhīva aģents?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Arhīvs ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Arhivēt $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Vai arhivēt atlasītās atmiņas?';

  @override
  String get areSharedByEveryAccountOn =>
      'tiek koplietoti katram kontam šajā serverī; konti joprojām var ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M ieeja';
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
    return 'Nepieciešama piekļuve $arg1';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 konti';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktīvs';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 pievienots. Rediģējiet to jebkurā laikā, lai mainītu ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '“$arg1” un tā darbības vēsture tiks neatgriezeniski dzēsta. Jebkurš aktīvs skrējiens tiks apturēts. Faili darbvietā netiek aizskarti.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Nepieciešams $arg1 apstiprinājums';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 lietotnes ir aktīvas';
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
    return '$arg1 ($arg2 aktīvie rīki)';
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
    return '$arg1 $arg2 un $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 mainīts';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 rakstzīmes';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Izveidots $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [vietējais uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 atbilst “$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent darbvieta';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 jauni konti';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 darbojas ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 paraugi';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 stūrēšana rindā';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 žetoni';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 žetoni';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 un $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 kļuva par administratoru ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 baiti';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 kanāls';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 rakstzīmes';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 notīrīts.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 konfigurēts';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 pievienots. Izvēlieties krātuves un personas sadaļā Kas var ziņot.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 pamata ieraksti.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 izveidoja ielūguma saiti';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 galddators';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 notikumi';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 neizdevās';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 neizdevās';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 neizdodas';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 priekš $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 grupas, kas atzīmētas tikai';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return 'Pirms ${arg1}h';
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
    return '$arg1 palīgi';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 trāpījuma koeficients)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 ir administrators, tāpēc kontu nevar izdzēst ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 ir bloķēts $arg2. Atjauniniet piekļuves sarakstu, lai atļautu atbildes.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 ir pievienots un reaģē.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 vairs nav administrators ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 nav pieejams $arg2 (trūkst izpildlaika atļaujas vai atkarības).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 ir pievienots zem $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 vērtē LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 atslēga$arg2 ir konfigurēta';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return '$arg1 atslēga noņemta.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 pa kreisi';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 pa kreisi $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 ir saistīts';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return 'Pirms ${arg1}m';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Pārliecinieties, vai tas darbojas, un pēc tam mēģiniet vēlreiz.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 pārvalda šo kontu';
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
    return '$arg1 modeļi gatavi';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 vairāk';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 vairāk soļu skrējiena vēsturē';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 pārvietots no $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 ir jābūt ierobežotam skaitlim.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 ir jābūt http:// vai https:// adresei.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 ir jāpievērš uzmanība';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent darbvieta';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 jauni konti pēdējā $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · Jauni ziņojumi vada šo darbību';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 jauni braucieni';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 tagad pārvalda šo kontu.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 ir atļautas 4 atļaujas. Faili ir pieejami tikai jūsu NeoAgent Workspace mapē.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 no $arg2 ir iespējots';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 no $arg2 grupām pievienojas parastai tērzēšanai';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 no $arg2 modeļiem';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 no $arg2 modeļiem ir gatavs';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 no $arg2 komplekta';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 no $arg2 instrumentiem atļauts';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: Labi';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 dienā $arg2 pie $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 atbild tikai tām personām, kuras pievienojat tālāk.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 atbild tikai tad, ja ir atzīmēts';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 runā tikai ar personām un grupām, kuras esat apstiprinājis';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Pievienoti $arg1 cilvēki vai grupas';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 plānošana';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1 pakalpojumu sniedzēji';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 gatavs';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 ieraksti';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 novirzīšanas URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 reģistrēts';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 atbildēja';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 atsauca uzaicinājuma saiti';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 darbojas';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 darbojas · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 darbojas pēdējā $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 saglabāts.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return 'Atlasīts $arg1';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Parādīts $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 klusēja';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 stūre $arg2 rindā';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 solis$arg2 · pieskarieties mezglam, lai pārbaudītu';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 soļi';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 pārtrauca pārvaldīt $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 žetoni';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 marķieri pēdējā $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 instrumenti';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (nav pieejama saglabātā ignorēšana)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% izmantots · $arg2 atlikums';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 vēlas ar jums runāt.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 tīmeklis';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" tiks neatgriezeniski noņemts.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 pārvaldīs šo kontu';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 neatbildēs šajā platformā';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 neatbildēs uz $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Lietotāja artefaktu glabāšana';

  @override
  String get askAQuestionOrStartA =>
      'Uzdodiet jautājumu vai sāciet uzdevumu...';

  @override
  String get askBeforeClosingToBackground => 'Jautājiet pirms fona aizvēršanas';

  @override
  String get askMe => 'Pajautā man';

  @override
  String get assignedAgent => 'Piešķirtais aģents';

  @override
  String get assignedAgent2 => 'Piešķirtais aģents';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Piešķirtais aģents: $arg1';
  }

  @override
  String get assigneeOptional => 'Uzdevuma saņēmējs (neobligāti)';

  @override
  String get assistant => 'Asistents';

  @override
  String get assistantKey131 => 'Asistenta atslēga 131';

  @override
  String get atLeast1 => 'Vismaz 1.';

  @override
  String get atLeast1000AppliesAfterA =>
      'Vismaz 1000. Attiecas pēc servera restartēšanas.';

  @override
  String get attachFiles => 'Pievienojiet failus';

  @override
  String attentionArg1(Object? arg1) {
    return 'Uzmanību $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'audita žurnāls admin piešķirt atsaukt uzaicinājumu komandas vēsture';

  @override
  String get authMethod => 'Auth metode';

  @override
  String get authServerUrl => 'Auth servera URL';

  @override
  String get authentication => 'Autentifikācija';

  @override
  String get authenticationFailed => 'Autentifikācija neizdevās.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Autentifikācija joprojām tiek gaidīta. Pabeidziet pārlūkprogrammas darbību un mēģiniet vēlreiz.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Autentifikācija joprojām tiek gaidīta. Pabeidziet pārlūkprogrammas plūsmu un atsvaidziniet.';

  @override
  String get authenticationTimedOut => 'Autentifikācijas noildze.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Autentifikācija tika atcelta pirms pabeigšanas.';

  @override
  String get authenticatorApp => 'Autentifikatora lietotne';

  @override
  String get authenticatorCode => 'Autentifikatora kods';

  @override
  String get authorOptional => 'Autors (pēc izvēles)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Automātiski (pirmais nodrošinātājs ar API atslēgu)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automātiski maršruti uz labāko pieejamo modeli';

  @override
  String get automaticFast => 'Automātiski (ātri)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automātiski nolasa telpu un parasti aiztur. Tikai pieminēšana nepieprasa lēmuma pieņemšanu, kamēr tas nav tieši uzrunāts.';

  @override
  String get automaticReserved => 'Automātiski, rezervēti';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automātiskajai atgriešanai iestatīšanas ekrānā ir jāmēģina vēlreiz.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automātiski atlasa ātru modeli, izmantojot parasto modeļu katalogu.';

  @override
  String get automation => 'Automatizācija';

  @override
  String get available => 'Pieejams';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Atkal pieejams $arg1 formātā';
  }

  @override
  String get availableAgainShortly => 'Drīzumā atkal pieejams';

  @override
  String get availableInTheDesktopAppFor =>
      'Pieejams darbvirsmas lietotnē MacOS, Windows un Linux';

  @override
  String get availableToTheAgent => 'Pieejams aģentam';

  @override
  String get averageAllTime => 'Vidēji, visu laiku';

  @override
  String get avgImp => 'Vid. sean.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Vid./skrējiens: $arg1 marķieri';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Izvairieties no atkārtotām rakstzīmēm un acīmredzamām secībām.';

  @override
  String get awaitingScan => 'Gaida skenēšanu';

  @override
  String get back => 'Atpakaļ';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count fonā';
  }

  @override
  String get backgroundTasks => 'Fona uzdevumi';

  @override
  String get backOn => 'atpakaļ ieslēgts.';

  @override
  String get backToChat => 'Atpakaļ uz tērzēšanu';

  @override
  String get backToFolder => 'Atpakaļ uz mapi';

  @override
  String get backToSignIn => 'Atgriezties, lai pierakstītos';

  @override
  String get backendChannel => 'Aizmugurējais kanāls';

  @override
  String get backendOnThisComputer => 'Aizmugursistēma šajā datorā';

  @override
  String get backendSync => 'Aizmugursistēmas sinhronizācija';

  @override
  String get backgroundLocationNeeded => 'Nepieciešama fona atrašanās vieta';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Fona sinhronizācija operētājsistēmā Android paliek ieplānota';

  @override
  String get badState => 'Slikts stāvoklis: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Darbojošo QEMU virtuālo mašīnu bāzes attēls un izmērs ';

  @override
  String get baseUrlOptional => 'Pamata URL (neobligāti)';

  @override
  String get baseUrlTokenLocal => 'bāzes url pilnvaras vietējais';

  @override
  String get basicAuthentication => 'Pamata autentifikācija';

  @override
  String get behaviorModules => 'Uzvedības moduļi';

  @override
  String get behaviorNotes => 'uzvedības piezīmes';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Bitwarden akreditācijas brokeris';

  @override
  String get bitwardenItem => 'Bitwarden vienums';

  @override
  String get bitwardenServer => 'Bitwarden serveris';

  @override
  String get blankUsesCommon => 'Tukšs lieto \"parasti\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Tukšs izmanto noklusējuma atzvanīšanu';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Tukšās vērtības izmanto nodrošinātāja noklusējuma iestatījumus.';

  @override
  String get block => 'Bloķēt';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Bloķēts ienākošais ziņojums no $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Ar BlueBubbles saderīgs tilts';

  @override
  String get bluebubblesServerUrl => 'BlueBubbles servera URL';

  @override
  String get botToken => 'Bota marķieris';

  @override
  String get botTokenAndApprovedChats =>
      'Bota marķieris un apstiprinātas tērzēšanas sarunas';

  @override
  String get botTokenAndServerChannelAccess =>
      'Bota marķieris un piekļuve serverim/kanālam';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bota marķieris, notikumu API un piekļuve kanālam';

  @override
  String get botUserId => 'Bota lietotāja ID';

  @override
  String get botUsername => 'Bota lietotājvārds';

  @override
  String get brandName => 'Zīmola nosaukums';

  @override
  String get braveSearch => 'Drosmīga meklēšana';

  @override
  String get breakdown => 'Sadalījums:';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Pārvietojiet jebkuru pakalpojumu sniedzēju, kas var izlikt un saņemt tīmekļa aizķeres lietderīgās slodzes.';

  @override
  String get bringYourOwnKey => 'paņem līdzi savu atslēgu';

  @override
  String get bringYourOwnKey2 => 'Paņemiet līdzi savu atslēgu';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Pārlūkprogrammai, Linux darbvirsmai, failiem, terminālim un Python ir viens pastāvīgs mākoņa dators.';

  @override
  String get browserLogin => 'Pieteikšanās pārlūkprogrammā';

  @override
  String get browserScripting => 'Pārlūka skriptēšana';

  @override
  String get call => 'Zvaniet';

  @override
  String get callAgent => 'Zvanīt aģentam';

  @override
  String get callUser => 'Zvanīt lietotājam';

  @override
  String get calledByName => 'Sauc vārdā';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Var deleģēt uzdevumus citiem aģentiem';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Var deleģēt $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Var saņemt deleģētos uzdevumus';

  @override
  String get cancel => 'Atcelt';

  @override
  String get cancelTask => 'Atcelt uzdevumu';

  @override
  String candidateCountArg1(Object? arg1) {
    return 'Kandidātu skaits: $arg1';
  }

  @override
  String get cannotPreview => 'Nevar priekšskatīt';

  @override
  String get cannotReceiveDelegatedTasks => 'nevar saņemt deleģētos uzdevumus';

  @override
  String get cannotRunYet => 'vēl nevar skriet.';

  @override
  String get capturedThePage => 'Uztvēra lapu';

  @override
  String get category => 'Kategorija';

  @override
  String chainArg1(Object? arg1) {
    return 'Ķēde: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Mainiet iestatīšanas režīmu';

  @override
  String get channel => 'Kanāls';

  @override
  String get channelAccessToken => 'Kanāla piekļuves pilnvara';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanāls: $arg1$arg2 | Atjauninātā versija: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Kanālu aptveroša sociālā atmiņa';

  @override
  String get channels => 'Kanāli';

  @override
  String get chat => 'Tērzēšana';

  @override
  String get chatId => 'Tērzēšanas ID';

  @override
  String get chatMode => 'Tērzēšanas režīms';

  @override
  String get chatModel => 'Tērzēšanas modelis';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Pārbaudiet automātiski palaišanas laikā';

  @override
  String get checkForMessagesEveryMs => 'Pārbaudīt ziņojumus ik pēc (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Automātiski pārbaudiet, vai nav jaunu ziņojumu';

  @override
  String get checkNow => 'Pārbaudiet tūlīt';

  @override
  String get checkYourEmailToConfirmYour =>
      'Pirms pierakstīšanās pārbaudiet savu e-pastu, lai apstiprinātu savu NeoAgent kontu.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Pārbaudīts $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Izvēlieties kategoriju vai meklējiet visos iestatījumos.';

  @override
  String get chooseAPerson => 'Izvēlieties personu';

  @override
  String get chooseAProjectFolder => 'Izvēlieties projekta mapi';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Izvēlieties noklusējuma iestatījumus tērzēšanai, aģentiem, atkāpšanās darbībām un viedajai maršrutēšanai.';

  @override
  String get chooseGroups => 'Izvēlieties grupas';

  @override
  String get chooseHowMuchYouWantTo =>
      'Izvēlieties, cik daudz vēlaties konfigurēt tagad. Abas opcijas var mainīt vēlāk.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Izvēlieties, kā šis uzdevums jāsāk. Manuāli darbojas tikai palaist tūlīt. Grafiks ir balstīts uz laiku. Integrācija aktivizē pievienoto oficiālo lietotņu darbību.';

  @override
  String get chooseOneToGetStartedNow =>
      'Izvēlieties vienu, lai sāktu tūlīt. Vēlāk varat pievienot vairāk.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Iestatījumos izvēlieties tiešraides modeli un balsi.';

  @override
  String get chooseTheirGroup => 'Izvēlieties viņu grupu';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Izvēlieties, kur šai personai jāļauj runāt ar $arg1. Vēlāk varat to mainīt sadaļā Kas var ziņot.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Izvēlieties, kurām grupām $arg1 jāpievienojas pat tad, ja neviens to nav atzīmējis. Šī platforma var neatšķirt tagus no parastajiem ziņojumiem.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Izvēlieties, kurus modeļus katrs šī servera konts var izvēlēties un ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Izvēlieties, ar ko $arg1 sarunājas un kad tas pievienojas grupas tērzēšanai.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Izvēlieties, kas var sasniegt $arg1, un pēc tam saglabājiet izmaiņas.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Izvēlieties, kas var nosūtīt aģentam ziņojumu WhatsApp kartē ar uzrakstu \"Kas var sūtīt\".';

  @override
  String get chooseYourDefaultModel => 'Izvēlieties savu\nnoklusējuma modeli.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, faili, teksta redaktors un terminālis ir pieejami no Linux darbvirsmas.';

  @override
  String get claudeCode => 'Klods Kods';

  @override
  String get clear => 'Notīrīt';

  @override
  String get clearAll => 'Notīrīt visu';

  @override
  String clearArg1(Object? arg1) {
    return 'Notīrīt $arg1?';
  }

  @override
  String get clearFilter => 'Notīrīt filtru';

  @override
  String get clearFilters => 'Notīrīt filtrus';

  @override
  String get clearSearch => 'Notīrīt meklēšanu';

  @override
  String get clearView => 'Skaidrs skats';

  @override
  String get cliSession => 'CLI sesija';

  @override
  String get clickIsNotSupportedOnThis =>
      'klikšķis šajā platformā netiek atbalstīts.';

  @override
  String get clickOnceToBeginCapturing =>
      'Noklikšķiniet vienreiz, lai sāktu uzņemšanu';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Noklikšķiniet, ierakstiet un mijiedarbojieties ar darbvirsmas programmām.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Noklikšķināts pie ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Noklikšķināja pārlūkprogrammā';

  @override
  String get clientId => 'Klienta ID';

  @override
  String get clientSecret => 'Klienta noslēpums';

  @override
  String get close => 'Aizvērt';

  @override
  String get closeJ => 'Aizvērt (⌘J)';

  @override
  String get closeTeachMode => 'Aizvērt mācību režīmu';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Aizverot logu, programma NeoAgent var turpināt darboties fonā ar piekļuvi teknei vai pilnībā aizvērt darbvirsmas izpildlaiku.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Tiek atbalstītas mākoņdatošanas un pašmitinātās instances. Vietējie un privātā tīkla vietrāži URL darbojas, kad NeoAgent var tos sasniegt.';

  @override
  String get cloudComputer => 'Mākoņdators';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Mākoņdators · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Mākoņdatora iestatījumi ir saglabāti. Restartējiet serveri, lai tos lietotu.';

  @override
  String get cloudComputerVm => 'Mākoņdators (VM)';

  @override
  String get cloudComputers => 'Mākoņdatori';

  @override
  String get codeHosting => 'Kodu mitināšana';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Ar komatu atdalīti kanālu nosaukumi bez #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Atdalīts ar komatu, piemēram, #vispārīgi, #palīdzība';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Atdalīts ar komatu. Jautājumam ir jābūt visiem tiem.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Komanda neizdevās ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Nepieciešama komanda.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Komandu izvades akumulators nav aktīvs.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Komandas izvades augšupielāde neizdevās ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Komandas izvades augšupielāde ir izlaisti artefakta metadati.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Komandas izvade jau ir pabeigta.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Komandas un lietotnes';

  @override
  String get commandsRunInTheSamePersistent =>
      'Komandas tiek izpildītas tajā pašā pastāvīgā datorā, ko izmanto redzamā darbvirsma.';

  @override
  String get communityChatops => 'Kopiena un ChatOps';

  @override
  String get completeSetup => 'Pabeigt iestatīšanu';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Pabeidziet darbplūsmu darbvirsmā.';

  @override
  String get completed => 'Pabeigts';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Pilnīgi bloķēts — aģents nevar izmantot šo kategoriju.';

  @override
  String get computerShell => 'Datora apvalks';

  @override
  String get computerUsedByThisSession => 'Šajā sesijā izmantotais dators';

  @override
  String get computerWorkspace => 'Datora darba vieta';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigurējams personīgais tīmekļa aizķeres tilts';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigurējams relejs vai tīmekļa aizķeres tilts';

  @override
  String get configurableTalkWebhookBridge =>
      'Konfigurējams Talk tīmekļa aizķeres tilts';

  @override
  String get configurableWebInboxBridge =>
      'Konfigurējams tīmekļa iesūtnes tilts';

  @override
  String get configurableWebhookBridge =>
      'Konfigurējams tīmekļa aizķeres tilts';

  @override
  String get configurableWebhooks => 'Konfigurējamas tīmekļa aizķeres';

  @override
  String get configurationOrInTheEnvFile => 'konfigurācijā vai .env failā.';

  @override
  String get configure => 'Konfigurēt';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Konfigurējiet darbvietas uzvedību un modeļa noklusējuma iestatījumus.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Konfigurēts $arg1';
  }

  @override
  String get confirmEmailChanges => 'Apstipriniet e-pasta izmaiņas';

  @override
  String get confirmNewSignUps => 'Apstipriniet jaunas reģistrācijas';

  @override
  String get confirmPassword => 'Apstipriniet paroli';

  @override
  String get confirmPassword2 => 'Apstipriniet paroli';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Pirms pierakstīšanās apstipriniet savu e-pastu. Pārbaudiet pakalpojuma NeoAgent e-pasta ziņojumu.';

  @override
  String get connect => 'Savienot';

  @override
  String get connectAMessagingPlatform =>
      'Pievienojiet\nziņojumapmaiņas platformu.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Pievienojiet publisku HTTPS mājas palīga galapunktu, izmantojot ilgstošas ​​​​piekļuves pilnvaras. Serveris bloķē lokālā, atpakaļcilpas un privātā tīkla adreses.';

  @override
  String get connectAccount => 'Pievienojiet kontu';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Savienojiet lietotņu kontus atsevišķi, lai AI varētu izmantot pareizo kontu katrai oficiālajai integrācijai.';

  @override
  String connectArg1(Object? arg1) {
    return 'Pievienojiet $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Pievienojiet tik daudz kontu, cik vēlaties. Katra lietotne var izmantot citu kontu.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Savienojiet kanālus, izvēlieties, ar ko $arg1 sarunājas, un skatieties pēdējās darbības.';
  }

  @override
  String get connectInstance => 'Savienojuma instance';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Vispirms pievienojiet šo integrāciju, lai izvēlētos kontu.';

  @override
  String get connectToThisServer => 'Izveidojiet savienojumu ar šo serveri';

  @override
  String get connectWhatsapp => 'Pievienojiet WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Pievienojiet savu Nextcloud instanci, tostarp pašmitinātos serverus. NeoAgent atver Nextcloud paša pieteikšanās lapu, lai jūs varētu pierakstīties, izmantojot paroli, SSO vai 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Pievienojiet savu paša mitināto NeoRecall serveri. Pēc OAuth ekrāna apstiprināšanas NeoAgent saņem tikai lasīšanas piekļuvi vietējai meklēšanai, atmiņām un transkripcijas pierādījumiem.';

  @override
  String get connected => 'Savienots';

  @override
  String get connectedAccount => 'Savienotais konts';

  @override
  String connectedArg1(Object? arg1) {
    return 'Savienots $arg1';
  }

  @override
  String get connectedInstance => 'Savienotā instance';

  @override
  String get connectedNeorecallUser => 'Savienots NeoRecall lietotājs';

  @override
  String get connectedNextcloudUser => 'Pievienots Nextcloud lietotājs';

  @override
  String get connectedServer => 'Savienots serveris';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Notiek savienojuma izveide ar tiešraides balss modeli...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Savienojums #$arg1';
  }

  @override
  String get connectionId => 'Savienojuma ID';

  @override
  String get connectionLooksGood => 'Savienojums izskatās labi.';

  @override
  String get connectionMethod => 'Savienojuma metode';

  @override
  String get containsTextOptional => 'Satur tekstu (pēc izvēles)';

  @override
  String get content => 'Saturs';

  @override
  String contentArg1(Object? arg1) {
    return 'Sastāvs: $arg1';
  }

  @override
  String get contentSecurityPolicy => 'satura drošības politika';

  @override
  String get continue2 => 'Turpināt';

  @override
  String get continueFullSetup => 'Turpiniet pilnu iestatīšanu';

  @override
  String get continueRun => 'Turpiniet skriet';

  @override
  String get continueToSetup => 'Turpiniet iestatīšanu';

  @override
  String get controlSurface => 'KONTROLES VIRSMA';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Kontrolē piekļuvi $arg1 rīkiem.';
  }

  @override
  String get conversation => 'Saruna';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Sarunas ID, kas tiek izmantots, kad šis aģents sāk tērzēšanu.';

  @override
  String get cookieSetup => 'Sīkfailu iestatīšana';

  @override
  String get cookiesNotConfigured => 'Sīkfaili nav konfigurēti';

  @override
  String get copiedAsCsv => 'Kopēts kā CSV';

  @override
  String get copiedDebugInfo => 'Kopēta atkļūdošanas informācija';

  @override
  String get copiedExportForTheLast5 =>
      'Nokopēts eksports pēdējiem 5 ziņojumiem';

  @override
  String get copiedFullPrompt => 'Nokopēta pilna uzvedne';

  @override
  String get copiedLogs => 'Kopēti žurnāli';

  @override
  String get copiedRunId => 'Kopēts palaišanas ID';

  @override
  String get copy => 'Kopēt';

  @override
  String get copyAll => 'Kopēt visu';

  @override
  String get copyCodes => 'Kopēt kodus';

  @override
  String get copyCsv => 'Kopēt CSV';

  @override
  String get copyDebugInfo => 'Kopēt atkļūdošanas informāciju';

  @override
  String get copyLink => 'Kopēt saiti';

  @override
  String get copyLogs => 'Kopēt žurnālus';

  @override
  String get copyPrompt => 'Kopēt uzvedni';

  @override
  String get copyResponse => 'Kopēt atbildi';

  @override
  String get copyRunId => 'Kopēt palaišanas ID';

  @override
  String get copyWebhookUrl => 'Kopēt tīmekļa aizķeres URL';

  @override
  String get core => 'Kodols';

  @override
  String get coreMemory => 'galvenā atmiņa';

  @override
  String get coreServicesThisServerDependsOn =>
      'Pamatpakalpojumi, no kuriem ir atkarīgs šis serveris.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domēna https publiskā URL izcelsme';

  @override
  String get couldHelp => 'Varētu palīdzēt';

  @override
  String get couldNotApproveQrLogin => 'Nevarēja apstiprināt QR pieteikšanos.';

  @override
  String get couldNotApproveQrPairing =>
      'Nevarēja apstiprināt QR savienošanu pārī.';

  @override
  String get couldNotConnect => 'Nevarēja izveidot savienojumu.';

  @override
  String get couldNotCreateBinding => 'Nevarēja izveidot iesiešanu.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Nevarēja izdzēst jūsu kontu: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Nevarēja atvienot Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Nevarēja atvienot mājas palīgu.';

  @override
  String get couldNotDisconnectNeorecall => 'Nevarēja atvienot NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud => 'Nevarēja atvienot Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Nevarēja atvienot Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Nevarēja eksportēt jūsu datus: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Nevarēja ielādēt lēmumus';

  @override
  String get couldNotLoadUsageData => 'Nevarēja ielādēt lietošanas datus.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Nevarēja automātiski atvērt Linux iestatījumus.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Nevarēja atvērt pakalpojumu sniedzēja saistīšanas lapu.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Nevarēja atvērt pakalpojumu sniedzēja pierakstīšanās lapu.';

  @override
  String get couldNotOpenTheReleaseAsset => 'Nevarēja atvērt laidiena īpašumu.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Nevarēja atvērt Trello jūsu pārlūkprogrammā.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Nevarēja atvērt darbvietas faila lejupielādi.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Nevarēja nolasīt Android lietotnes pakotni.';

  @override
  String get couldNotReadTheApk => 'Nevarēja nolasīt APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Nevarēja noņemt atslēgu: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Nevarēja saglabāt aģentu.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Nevarēja saglabāt Bitwarden iestatījumus.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Nevarēja saglabāt mājas palīga iestatījumus.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Nevarēja saglabāt NeoRecall iestatījumus.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nevarēja saglabāt Nextcloud iestatīšanu.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Nevarēja saglabāt Trello iestatījumus.';

  @override
  String get couldNotSendConfirmationEmail =>
      'nevarēja nosūtīt apstiprinājuma e-pastu';

  @override
  String get couldNotStart => 'Nevarēja sākt';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Izveidot';

  @override
  String get createAPasswordFirstToChange =>
      'Vispirms izveidojiet paroli, lai mainītu konta e-pastu.';

  @override
  String get createAPasswordOrLinkAnother =>
      'pirms šīs pierakstīšanās metodes noņemšanas izveidojiet paroli vai izveidojiet saiti ar citu pakalpojumu sniedzēju';

  @override
  String get createATaskWhileThisAgent =>
      'Izveidojiet uzdevumu, kamēr ir atlasīts šis aģents.';

  @override
  String get createLink => 'Izveidot saiti';

  @override
  String get createOrModifyFilesInYour =>
      'Izveidojiet vai modificējiet failus savā darbvietā.';

  @override
  String get createPassword => 'Izveidojiet paroli';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Izveidojiet speciālistus ar atsevišķu atmiņu, iestatījumiem, rīkiem un konta uzdevumiem.';

  @override
  String get createTheFirstAccount => 'Izveidojiet pirmo kontu';

  @override
  String get createUpdateOrDeleteSkills =>
      'Izveidojiet, atjauniniet vai dzēsiet prasmes.';

  @override
  String get creatingYourSkill => 'Jūsu prasmes veidošana…';

  @override
  String get credentialBindings => 'Akreditācijas datu stiprinājumi';

  @override
  String get credentialUse => 'Akreditācijas datu izmantošana';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Uz Cron balstītas atkārtotas darbības un vienreizēja laika izpilde.';

  @override
  String get cronExpression => 'Krona izteiksme';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘+Enter izpilda vaicājumu.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + atstarpe';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Pašreizējais e-pasts: $arg1';
  }

  @override
  String get currentPassword => 'Pašreizējā parole';

  @override
  String get currentPasswordIsIncorrect => 'pašreizējā parole ir nepareiza';

  @override
  String get currentTwoStepLoginCode =>
      'Pašreizējais divpakāpju pieteikšanās kods';

  @override
  String get customAccess => 'Pielāgota piekļuve';

  @override
  String get customCron => 'Pielāgots Cron';

  @override
  String get customCronMustHave5Fields => 'Custom Cron ir jābūt 5 laukiem.';

  @override
  String get customEndpoint => 'pielāgots galapunkts';

  @override
  String get customField => 'Pielāgots lauks';

  @override
  String get customHeader => 'Pielāgota galvene';

  @override
  String get customHeadersJson => 'Pielāgotas galvenes (JSON)';

  @override
  String get customOpenaiCompatible => 'Pielāgota ar OpenAI saderīga';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Pielāgots ar OpenAI saderīgs galapunkts';

  @override
  String get customOutgoingUrl => 'Pielāgots izejošais URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Ikdienas';

  @override
  String get dailyRecap => 'Dienas kopsavilkums';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'datu bāzes vaicājumā atlasiet csv veidnes';

  @override
  String dayArg1(Object? arg1) {
    return 'Diena $arg1';
  }

  @override
  String get dayOfMonth => 'Mēneša diena';

  @override
  String get decideWhichToolsYourAgentMay =>
      'izlemiet, kādus rīkus jūsu aģents var izmantot. Viņi redz tavu vārdu un ';

  @override
  String get decisionHigherUpTheChainWins =>
      'lēmums augstāk ķēde uzvar un parāda slēdzeni ar ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Šeit tiek parādīti lēmumi, jo $arg1 nolasa apstiprinātās $arg2 grupas. Tiek saglabāti tikai jaunākie 30, un tie tiek atiestatīti, kad serveris restartējas.';
  }

  @override
  String get decline => 'Noraidīt';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'dziļais skrējiens · solis $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram atslēga';

  @override
  String get default2 => 'Noklusējums';

  @override
  String get default3 => 'NOKLUSĒJUMS';

  @override
  String defaultArg1(Object? arg1) {
    return 'Noklusējums ($arg1)';
  }

  @override
  String get defaultConversation => 'Noklusējuma saruna';

  @override
  String get defaultForNewGroups => 'Noklusējums jaunām grupām';

  @override
  String get defaultGroupParticipation => 'Noklusējuma grupas dalība';

  @override
  String get defaultNeoagentWorkspace => 'Noklusējuma NeoAgent darbvieta';

  @override
  String get defaultOpenai => 'Noklusējums (OpenAI)';

  @override
  String get defaultRateLimits => 'Noklusējuma likmes ierobežojumi';

  @override
  String get defaultRateLimitsSaved =>
      'Noklusējuma ātruma ierobežojumi ir saglabāti.';

  @override
  String get defaultRecommended => 'Noklusējums (ieteicams)';

  @override
  String get defaultRouting => 'Noklusējuma maršrutēšana';

  @override
  String get defaultSpace => 'Noklusējuma vieta';

  @override
  String get delete => 'Dzēst';

  @override
  String get deleteAccount => 'Dzēst kontu';

  @override
  String get deleteAccountPermanently => 'Vai neatgriezeniski dzēst kontu?';

  @override
  String get deleteAnAccount => 'Dzēst kontu';

  @override
  String deleteArg1(Object? arg1) {
    return 'Vai dzēst @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Dzēst ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Vai neatgriezeniski dzēst $arg1 $arg2?';
  }

  @override
  String get deleteBinding => 'Dzēst iesiešanu';

  @override
  String get deleteCoreMemoryEntry => 'Vai dzēst pamata atmiņas ierakstu?';

  @override
  String get deleteForever => 'Dzēst uz visiem laikiem';

  @override
  String get deleteMcpServer => 'Vai dzēst MCP serveri?';

  @override
  String get deleteMemory => 'Vai dzēst atmiņu?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Dzēst neatgriezeniski dzēš kontu un visus tā datus ';

  @override
  String get deleteRun => 'Vai dzēst palaišanu?';

  @override
  String get deleteRun2 => 'Dzēst palaišanu';

  @override
  String get deleteSelectedMemories => 'Vai dzēst atlasītās atmiņas?';

  @override
  String get deleteSession => 'Vai dzēst sesiju?';

  @override
  String get deleteSkill => 'Vai dzēst prasmi?';

  @override
  String get deleteTask => 'Vai dzēst uzdevumu?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Svītrots \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Izdzēsts @$arg1 un visi viņu dati.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Dzēšana noņem visas jūsu sarunas, atmiņas, failus, uzdevumus un ';

  @override
  String get deliverableArtifactProduced => 'Izgatavots piegādājams artefakts';

  @override
  String get deliverableCompleted => 'Piegāde pabeigta';

  @override
  String get deliverableExecutionStarted => 'Sākta piegādes izpilde';

  @override
  String get deliverableSelected => 'Atlasīts piegādes veids';

  @override
  String get deliverableValidationFailed => 'Piegādājamā validācija neizdevās';

  @override
  String get deliverableValidationStarted => 'Sākta piegādes apstiprināšana';

  @override
  String get deny => 'Noliegt';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Aprakstiet rezultātu un pēc tam demonstrējiet to uz darbvirsmas';

  @override
  String get describeWhatToBuildOrChange => 'Aprakstiet, ko būvēt vai mainīt…';

  @override
  String get description => 'Apraksts';

  @override
  String get desktopApp => 'Darbvirsmas lietotne';

  @override
  String get desktopAppControlsAvailable =>
      'Pieejamas darbvirsmas lietotņu vadīklas';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Darbvirsmas uztveršana šajā platformā nav pieejama.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Darbvirsmas komandas izvades augšupielāde ir atcelta.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Darbvirsmas pavadošā komanda tika atcelta.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Darbvirsmas pavadošā savienojuma noildze.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Darbvirsmas pavadošā rokasspiediena noildze.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Darbvirsmas pavadonis šeit nav pieejams.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Darbvirsmas pavadonis ir lokāli apturēts.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Darbvirsmas pavadošo ziņojumu apstrāde neizdevās: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Darbvirsmas pavadoņu atļauju iestatījumi tīmeklī nav pieejami.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Darbvirsmas pavadoņu atļauju iestatījumi šajā platformā nav pieejami.';

  @override
  String get desktopCompanionRejected => 'Darbvirsmas pavadonis noraidīts.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Darbvirsmas pavadošā atbilde neizdevās: $arg1';
  }

  @override
  String get desktopControl => 'Darbvirsmas vadība';

  @override
  String get desktopFailedToStart => 'Darbvirsmu neizdevās startēt';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Darbvirsmas straumes uztveršana neizdevās: $arg1';
  }

  @override
  String get destinationId => 'Galamērķa ID';

  @override
  String get deviceAccess => 'Ierīces piekļuve';

  @override
  String get deviceSettings => 'Ierīces iestatījumi';

  @override
  String get devices => 'Ierīces';

  @override
  String get diagnosticsSaved => 'Diagnostika saglabāta.';

  @override
  String get directBluebubblesImessageBridge =>
      'Tiešais BlueBubbles iMessage tilts';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Tiešie ziņojumi paliek atsaucīgi. Atļautās grupas izmanto tālāk norādīto dalības režīmu.';

  @override
  String get directoryDoesNotExist => 'Direktorija nepastāv.';

  @override
  String get disable2fa => 'Atspējot 2FA';

  @override
  String get disableAll => 'Atspējot visu';

  @override
  String get discard => 'Izmest';

  @override
  String get disconnect => 'Atvienot';

  @override
  String get disconnectHomeAssistant => 'Atvienot mājas palīgu?';

  @override
  String get disconnectNeorecall => 'Vai atvienot NeoRecall?';

  @override
  String get disconnectNextcloud => 'Vai atvienot Nextcloud?';

  @override
  String get disconnectPlatform => 'Atvienojiet platformu';

  @override
  String get disconnectTrello => 'Vai atvienot Trello?';

  @override
  String get discoveryFailed => 'Atklāšana neizdevās';

  @override
  String get dismiss => 'Atlaist';

  @override
  String get displayIdIsRequired => 'Nepieciešams displeja ID.';

  @override
  String get displayName => 'Parādāmais vārds';

  @override
  String get displayNameMustBe64Characters =>
      'Parādāmajam nosaukumam ir jābūt 64 vai mazāk rakstzīmēm.';

  @override
  String get displayNameSaved => 'Parādāmais vārds ir saglabāts.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Neiekļaujiet savu lietotājvārdu vai e-pasta adresi.';

  @override
  String get done => 'Gatavs';

  @override
  String get downloadACopyOfYourData =>
      'Lejupielādējiet savu datu kopiju. Administratora kontus nevar izdzēst ';

  @override
  String get downloadACopyOfYourData2 =>
      'Lejupielādējiet savu datu kopiju vai neatgriezeniski dzēsiet savu kontu. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Lejupielādēt $arg1';
  }

  @override
  String get downloadUpdate => 'Lejupielādēt atjauninājumu';

  @override
  String get downloadingTheNeoagentBackend =>
      'Notiek NeoAgent aizmugursistēmas lejupielāde';

  @override
  String get draft => 'Melnraksts';

  @override
  String get dragIsNotSupportedOnThis =>
      'vilkšana šajā platformā netiek atbalstīta.';

  @override
  String get draggedOnTheScreen => 'Velkot uz ekrāna';

  @override
  String get dropAnApkOrApkBundle =>
      'Nometiet šeit APK vai APK komplektu, lai to instalētu';

  @override
  String get dropApkOrApksHere => 'Nometiet šeit APK vai .apks';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Izturīgas balss un mijiedarbības stila instrukcijas. Drošības un izpildes noteikumi joprojām ir prioritāte.';

  @override
  String get eGAlexSLaptop => 'piem. Aleksa klēpjdators';

  @override
  String get eGMyLocalServer => 'piem. Mans vietējais serveris';

  @override
  String get edit => 'Rediģēt';

  @override
  String get editAgent => 'Rediģēt aģentu';

  @override
  String get editCoreMemoryEntry => 'Rediģēt galvenās atmiņas ierakstu';

  @override
  String get editInstructions => 'Rediģēt instrukcijas';

  @override
  String get editMcpServer => 'Rediģēt MCP serveri';

  @override
  String get editTask => 'Rediģēt uzdevumu';

  @override
  String editedArg1(Object? arg1) {
    return 'Rediģēts $arg1';
  }

  @override
  String get email => 'E-pasts';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'E-pasta kontu īpašniekiem par pierakstīšanos, kas izskatās neparasti.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Nosūtiet e-pasta ziņojumu kontu īpašniekiem, kad mainās viņu konta informācija.';

  @override
  String get emailCode => 'E-pasta kods';

  @override
  String get emailConfirmationRequired => 'nepieciešams e-pasta apstiprinājums';

  @override
  String get emailIsAlreadyInUse => 'e-pasts jau tiek izmantots';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-pasts saglabāts. Ja ir nepieciešams apstiprinājums, pārbaudiet jauno adresi, lai atrastu NeoAgent apstiprinājuma saiti.';

  @override
  String get emailSettingsSaved => 'E-pasta iestatījumi saglabāti.';

  @override
  String get emailUnverified => 'E-pasts nav apstiprināts';

  @override
  String get empty => 'Tukšs';

  @override
  String get emptyFile => 'Tukšs fails';

  @override
  String get emptyFolder => 'Tukša mape';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Tukšs izmanto servera noklusējuma iestatījumu ($arg1).';
  }

  @override
  String get enable2fa => 'Iespējot 2FA';

  @override
  String get enableAll => 'Iespējot visu';

  @override
  String get enableBehaviorModules => 'Iespējot uzvedības moduļus';

  @override
  String get enableOrDisableModels => 'Iespējot vai atspējot modeļus';

  @override
  String get enabled => 'Iespējots';

  @override
  String get encryptedPrivateToYourAccount => 'Šifrēts, privāts jūsu kontam';

  @override
  String get end => 'Beigas';

  @override
  String get endCall => 'Beigt zvanu';

  @override
  String get endVoiceCall => 'Vai beigt balss zvanu?';

  @override
  String get endpoint => 'Galapunkts';

  @override
  String get enterAPassword => 'Ievadiet paroli.';

  @override
  String get enterAUsername => 'Ievadiet lietotājvārdu.';

  @override
  String get enterAValidEmailAddress => 'Ievadiet derīgu e-pasta adresi.';

  @override
  String get enterAnAddressManually => 'Ievadiet adresi manuāli';

  @override
  String get enterAnApiKeyFirst => 'Vispirms ievadiet API atslēgu.';

  @override
  String get enterInviteLink => 'Ievadiet uzaicinājuma saiti';

  @override
  String get enterTheAddressOfANeoagent => 'Ievadiet NeoAgent servera adresi.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Ievadiet $arg1 sniegto informāciju, lai $arg2 varētu nosūtīt un saņemt ziņas.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Ievadiet savu 2FA vai atkopšanas kodu.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Ievadiet savu pašreizējo paroli, lai to mainītu.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Ievadiet savu pašreizējo paroli, lai saglabātu e-pasta izmaiņas.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Ievadiet sava NeoAgent konta informāciju.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Ievadiet savu lietotājvārdu vai konta e-pastu. NeoAgent nosūtīs atiestatīšanas saiti, ja tā var atbilst kontam.';

  @override
  String get enterYourUsernameOrEmail =>
      'Ievadiet savu lietotājvārdu vai e-pastu.';

  @override
  String entityArg1(Object? arg1) {
    return 'Uzņēmums: $arg1';
  }

  @override
  String get environment => 'Vide';

  @override
  String get error => 'Kļūda';

  @override
  String errorArg1(Object? arg1) {
    return '\nkļūda: $arg1';
  }

  @override
  String errorArg12(Object? arg1) {
    return 'Kļūda: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Kļūdas no nesenā žurnāla, grupētas pēc ziņojuma.';

  @override
  String get errorsProblemsFailures => 'kļūdas problēmas neveiksmes';

  @override
  String get eventTypesCommaSeparated => 'Pasākumu veidi (atdalīti ar komatu)';

  @override
  String get every15Minutes => 'Ik pēc 15 minūtēm';

  @override
  String get every30Minutes => 'Ik pēc 30 minūtēm';

  @override
  String get everyAccountOnThisServerLoses =>
      'Katrs konts šajā serverī zaudē šo koplietoto atslēgu. Konti ';

  @override
  String get everyAccountOnThisServerSecrets =>
      'katrs konts šajā serverī. Noslēpumus var rakstīt tikai: atstājiet ';

  @override
  String get everyAccountOnThisServerUses =>
      'Katrs konts šajā serverī izmanto šo adresi ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Katra šī konta aktīvā sesija beidzas. Viņi var pierakstīties ';

  @override
  String get everyDay0800 => 'Katru dienu · 08:00';

  @override
  String get everyDay2000 => 'Katru dienu · 20:00';

  @override
  String get everyHour => 'Katru stundu';

  @override
  String get everyRunOnThisServerAll => 'Katru reizi šajā serverī, visu laiku.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Katram jutīgam rīkam ir nepieciešams apstiprinājums katru reizi.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Katrs rīks darbojas bez prasīšanas, izņemot tos, ko izmanto persona ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Ikviens šo grupu, kanālu vai telpu dalībnieks var runāt ar $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Visi šajā grupā';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Viss, kas $arg1 ir izslēgts jūsu aģentam, nāk ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Viss pārējais ir izslēgts.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Viss ir pieejams no darbvirsmas.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Viss, ko aģents var izmantot: oficiālās integrācijas, MCP serveri un prasmes.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Viss, ko izslēdzāt $arg1, atgriežas ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Precīza tīmekļa izcelsme ļauj veikt vairāku izcelsmju pieprasījumus, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Izpildiet JavaScript pārlūkprogrammas sesijā.';

  @override
  String get execution => 'Izpilde';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Izpildes informācija šim palaišanai nav pieejama.';

  @override
  String get executionPlanCreated => 'Izpildes plāns izveidots.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Vingrinājumu $arg1 sesijas';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[iziet no $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Beidzas $arg1';
  }

  @override
  String get explainThisProject => 'Izskaidrojiet šo projektu';

  @override
  String exploredArg1(Object? arg1) {
    return 'Izpētīts $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Izpētīts $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Izpētīja darbvietu';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Eksportēšana neizdevās: $arg1';
  }

  @override
  String get exportLast5Messages => 'Eksportēt pēdējos 5 ziņojumus';

  @override
  String get exportMyData => 'Eksportēt manus datus';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Ārējās pārlūkprogrammas palaišana neizdevās ar izejas kodu $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Ārējās pārlūkprogrammas palaišana šajā platformā netiek atbalstīta.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Ārējās pārlūkprogrammas palaišanas noildze.';

  @override
  String get externalMcpTools => 'Ārējie un MCP rīki';

  @override
  String get extraButtons => 'Papildu pogas';

  @override
  String get extractingTheNeoagentRuntime => 'NeoAgent izpildlaika izvilkšana';

  @override
  String get failed => 'Neizdevās';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Neizdevās izveidot savienojumu: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Neizdevās izveidot savienojumu $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Neizdevās izdzēst \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'neizdevās atnest';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Neizdevās ģenerēt uzvedni: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Neizdevās palaist ārējo pārlūkprogrammu, izmantojot url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Neizdevās palaist OAuth plūsmu.';

  @override
  String get failedToLoadPolicies => 'Neizdevās ielādēt politikas';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Neizdevās saglabāt: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Neizdevās saglabāt MCP serveri.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Neizdevās saglabāt atlasi: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Neizdevās nosūtīt paziņojumu aizmugursistēmai: $arg1';
  }

  @override
  String get fair => 'Godīgi';

  @override
  String get fasterReplies => 'Ātrākas atbildes';

  @override
  String get fewerModelCalls => 'Mazāk modeļu zvanu';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'lauks ir tukšs, lai atjaunotu iebūvēto noklusējuma vērtību.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Fails pārsniedz 1 MiB redaktora ierobežojumu.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Fails pārsniedz atbalstīto lieluma ierobežojumu.';

  @override
  String get fileWrites => 'Fails raksta';

  @override
  String get filename => 'Faila nosaukums';

  @override
  String get files => 'Faili';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Šeit tiek parādīti faili, ko NeoAgent raksta vai rediģē šajā sesijā.';

  @override
  String get filesSavedByAllUsers => 'Visu lietotāju saglabātie faili';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Aizpildiet apstiprinātos pieteikšanās datus vai autentificējiet pieprasījumus, neparādot AI noslēpumus.';

  @override
  String get finalResponse => 'Galīgā atbilde';

  @override
  String get findAPlatform => 'Atrodiet platformu';

  @override
  String get findAndFixABug => 'Atrodiet un izlabojiet kļūdu';

  @override
  String get findRecentChats => 'Atrodiet jaunākās tērzēšanas sarunas';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Pareizā NeoAgent izpildlaika atrašana';

  @override
  String get finish => 'Pabeigt';

  @override
  String get finishAtTheScheduledTime => 'Pabeidziet plānotajā laikā';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Pabeidziet pierakstīšanos pakalpojumā $arg1 savā pārlūkprogrammā un pēc tam vēlreiz izveidojiet savienojumu.';
  }

  @override
  String get flowGraph => 'Plūsmas grafiks';

  @override
  String get flutterApp => 'Lietotne Flutter';

  @override
  String get focusedExecutionProfile => 'Koncentrēts izpildes profils';

  @override
  String get folderIdOptional => 'Mapes ID (pēc izvēles)';

  @override
  String get folderUnavailable => 'Mape nav pieejama';

  @override
  String get forExampleHttpsMatrixOrg => 'Piemēram, https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Mitinātiem vai uzlabotiem tīkla iestatījumiem';

  @override
  String get forLinksInEmailsBlankUses =>
      'Par saitēm e-pastos. Blank izmanto servera publisko URL.';

  @override
  String get forgotPassword => 'Aizmirsāt paroli?';

  @override
  String get frameUnavailable => 'Rāmis nav pieejams';

  @override
  String freshnessArg1(Object? arg1) {
    return 'svaigums: $arg1';
  }

  @override
  String get fridays1700 => 'Piektdienās · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'No BotFather pēc robota izveides.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'No šī brīža $arg1 izlemj, kādus rīkus jūsu aģents drīkst izmantot. Viņi ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'No Discord izstrādātāju portāla, kas atrodas zem jūsu robotprogrammatūras.';

  @override
  String get fromTheLineDevelopersConsole => 'No LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot => 'No Matrix klienta vai robota konta.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'No vietnes twitchapps.com/tmi vai jūsu Twitch izstrādātāja lietotnes.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Pilna uzvedne';

  @override
  String get fullSetup => 'Pilna iestatīšana';

  @override
  String fullTextFtsArg1(Object? arg1) {
    return 'Pilns teksts (FTS): $arg1';
  }

  @override
  String get general => 'Ģenerālis';

  @override
  String get generalSettings => 'Vispārīgi iestatījumi';

  @override
  String get generalSettingsSaved => 'Vispārīgie iestatījumi ir saglabāti.';

  @override
  String get generateAPromptForAnotherAi =>
      'Ģenerējiet uzvedni citam AI, ielīmējiet atbildi šeit, lai importētu atmiņas.';

  @override
  String get generatePrompt => 'Ģenerēt uzvedni';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Ģeožoga izsekošanas kļūda: $arg1';
  }

  @override
  String get getInspired => 'Gūstiet iedvesmu';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot un OpenAI Codex';

  @override
  String get githubIssueOpened => 'Atvērta GitHub problēma';

  @override
  String get neorecallMemoryCreated => 'NeoRecall atmiņa izveidota';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'GitHub izlaišanas pārbaude neizdevās, izmantojot HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'GitHub laidiena derīgā slodze nebija laidienu saraksts.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'GitHub lietotājvārds, kas atklāja problēmu';

  @override
  String get globalSecurityMode => 'Globālais drošības režīms';

  @override
  String get gmailMessageReceived => 'Gmail ziņa saņemta';

  @override
  String get good => 'Labi';

  @override
  String get goodAfternoon => 'Laba pēcpusdiena';

  @override
  String get goodEvening => 'Labvakar';

  @override
  String get goodMorning => 'Labrīt';

  @override
  String get goodPasswordALittleMoreLength =>
      'Laba parole. Nedaudz lielāks garums padara to stiprāku.';

  @override
  String get googleChat => 'Google tērzēšana';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live izmanto jūsu OpenAI API atslēgu, bet Gemini Live jūsu Google AI atslēgu. Izmaiņas attiecas uz nākamo zvanu.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Pirms sinhronizēšanas piešķiriet Health Connect atļaujas.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grupa, kanāls vai telpa';

  @override
  String get groupType => 'Grupas veids';

  @override
  String get groupsAndChannels => 'Grupas un kanāli';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grupas: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Grupas $arg1, kuras vēl nav redzējušas, sekos tam.';
  }

  @override
  String get handlesDirectTasksItself =>
      'Pats tiek galā ar tiešajiem uzdevumiem';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Brīvroku režīms (runājiet brīvi, pārtrauciet jebkurā laikā)';

  @override
  String get headerName => 'Virsraksta nosaukums';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Virsraksti par jums svarīgām tēmām, filtrēti pēc signāla.';

  @override
  String get health => 'Veselība';

  @override
  String get healthChecks => 'Veselības pārbaudes';

  @override
  String get healthConnect => 'veselība savienot';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect nav pieejams šajā ierīcē.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Health Connect sinhronizācijas statuss un saglabātie aizmugursistēmas rādītāji.';

  @override
  String get healthStatusIsUnavailable => 'Veselības stāvoklis nav pieejams.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Veselības sinhronizācija ir pieejama tikai operētājsistēmā Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Sirds $arg1 ieraksti';
  }

  @override
  String get heldBack => 'Atturējās';

  @override
  String get helper => 'Palīgs';

  @override
  String helperArg1(Object? arg1) {
    return 'Palīgs: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'šeit. Vispirms atsaukt administratoru ar “neoagent admin revoke $arg1”.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Augstākas vērtības padara NeoAgent selektīvāku grupās.';

  @override
  String get highlyRecommended => 'Ļoti ieteicams';

  @override
  String get holdButton131ForTheAssistant => 'Turiet asistenta pogu 131.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Lai runātu, turiet nospiestu taustiņu kombināciju Ctrl+Shift+Space';

  @override
  String get holdToTalk => 'Turiet, lai runātu.';

  @override
  String get holdToTalk2 => 'Turiet, lai runātu';

  @override
  String get home => 'Sākums';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Nepieciešams mājas palīga ilgstošas ​​piekļuves marķieris.';

  @override
  String get homeAssistantSetup => 'Mājas palīga iestatīšana';

  @override
  String get homeAssistantUrl => 'Mājas palīga URL';

  @override
  String get homeAssistantUrlIsRequired => 'Nepieciešams mājas palīga URL.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Mājas servera pilnvara ar telpas aptauju';

  @override
  String get homeserverUrl => 'Mājas servera URL';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'mitināts pakalpojums). Jūsu atslēgas ir šifrētas, un tās var izmantot tikai ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'IRC tīkla resursdatora nosaukums, piemēram, irc.libera.chat';

  @override
  String get hourly => 'Stundu';

  @override
  String get hourlyInboxCheck => 'Stundu iesūtnes pārbaude';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Cik ilgi apstiprinājuma saites paliek spēkā.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Cik bieži šis aģents meklē jaunus telpas ziņojumus.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Cik bieži šis aģents meklē jaunus signāla ziņojumus.';

  @override
  String get howTeamsWork => 'Kā komandas strādā';

  @override
  String get howThisServerIsReachedPlus =>
      'Kā tiek sasniegts šis serveris, kā arī servera mēroga slēdži.';

  @override
  String get httpsSessionCookie => 'https sesijas sīkfails';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Es nevarēju šobrīd izpildīt šo pieprasījumu. Lūdzu, pēc brīža mēģiniet vēlreiz.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Dīkstāvē';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Ja $arg1 pieprasa tīmekļa aizķeres URL, ielīmējiet to, lai ziņojumi varētu sasniegt $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Ja šim kontam ir apstiprināts e-pasts, NeoAgent nosūtīs paroles atiestatīšanas saiti.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Ja pakalpojumam ir nepieciešams marķieris izejošajiem pieprasījumiem.';

  @override
  String get ignoreGroups => 'Ignorēt grupas';

  @override
  String get ignoreThisChat => 'Ignorēt šo tērzēšanu';

  @override
  String get ignoredChannels => 'Ignorētie kanāli';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Ignorēts nepareizi veidots darbvirsmas pavadošais ziņojums: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Īstenojiet iepriekš minēto plānu.';

  @override
  String get implementThisPlan => 'Īstenojiet šo plānu';

  @override
  String get implicitTls => 'Netiešs TLS';

  @override
  String get import => 'Importēt';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Importēšana neizdevās: $arg1';
  }

  @override
  String get importFromComputer => 'Importēt no datora';

  @override
  String get importMemoryTransfer => 'Vai importēt atmiņas pārsūtīšanu?';

  @override
  String get importance => 'Svarīgums';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Importētas $arg1 atmiņas, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return '@$arg1 komandā';
  }

  @override
  String get inBackground => 'fons';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Šeit tiks parādīti ienākošo un izejošo kanālu ziņojumi.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Ienākošie balss zvani lietotnē no NeoAgent';

  @override
  String get incomingMessages => 'Ienākošās ziņas';

  @override
  String get incomingNeoagentCall => 'Ienākošais NeoAgent zvans';

  @override
  String get incomingNeoagentCall2 => 'IENĀKŠAIS NEOAGENT ZVANS';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Ienākošo tīmekļa aizķeres un izejošo atzvanīšanas atbalsts';

  @override
  String get incorporatingSteering => 'Ietver stūrēšanu';

  @override
  String get input => 'Ievade';

  @override
  String get inputMode => 'Ievades režīms';

  @override
  String get insertATemplate => 'Ievietojiet veidni';

  @override
  String get inspect => 'Pārbaudīt';

  @override
  String get install => 'Instalējiet';

  @override
  String get installASignedSelfContainedRuntime =>
      'Instalējiet parakstītu, autonomu izpildlaiku. Node.js, npm, Git un termināļa komandas nav nepieciešamas.';

  @override
  String get installApk => 'Instalējiet APK';

  @override
  String get installApkBundle => 'Instalējiet APK/paku';

  @override
  String get installApkClickOrDropA =>
      'Instalējiet APK — noklikšķiniet uz .apk faila vai nometiet to';

  @override
  String get installNeoagent => 'Instalējiet NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Instalējiet NeoAgent šajā datorā bez termināļa vai izveidojiet savienojumu ar tādu, kas jau darbojas.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Instalējiet jaunus izdevumus un izvēlieties kanālu, kuram seko šis serveris.';

  @override
  String get installTheBackend => 'Instalējiet aizmuguri';

  @override
  String get installTheCoreWithExtraOptional =>
      'Instalējiet kodolu ar papildu izvēles iestatīšanu. AI nodrošinātāja atslēgas tiek pievienotas pēc tam, tāpat kā Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Instalējiet drošo kodolu un pēc tam izveidojiet savu kontu. Pēc tam pievienojiet AI nodrošinātāja atslēgas.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Uzstādīts: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Uzstādīts: $arg1 • Pēdējā pārbaude: $arg2';
  }

  @override
  String get instructions => 'Norādījumi';

  @override
  String get integration => 'Integrācija';

  @override
  String get integrationApps => 'Integrācijas lietotnes';

  @override
  String get integrationConnections => 'Integrācijas savienojumi';

  @override
  String get integrationSettingsSaved =>
      'Integrācijas iestatījumi ir saglabāti.';

  @override
  String get integrations => 'Integrācijas';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrations/oauth/callback un reģistrējiet to pašu ';

  @override
  String get interruptAi => 'Pārtraukt AI';

  @override
  String get invalid2fa => 'nederīgs 2fa';

  @override
  String get invalidArgumentS => 'Nederīgs(-i) arguments(-i): ';

  @override
  String get invalidCredentials => 'nederīgi akreditācijas dati';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Nederīgs NeoAgent izpildlaika manifests.';

  @override
  String get inviteLink => 'Uzaicinājuma saite';

  @override
  String get inviteLinkReady => 'Uzaicinājuma saite ir gatava';

  @override
  String get inviteLinks => 'Uzaicinājuma saites';

  @override
  String get iphoneApp => 'iPhone lietotne';

  @override
  String get issues => 'problēmas';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Tiklīdz žurnāls tiek ielādēts, parādās problēmas.';

  @override
  String get itCanTBeUndone => 'To nevar atsaukt.';

  @override
  String get itMayHaveBeenDeleted => 'Iespējams, tas ir izdzēsts.';

  @override
  String get javaRuntime => 'java izpildlaiks';

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
    return 'Pievienojās $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Pievienojies pēdējo 7 dienu laikā';

  @override
  String get joiningATeam => 'Pievienošanās komandai';

  @override
  String get joiningIsOffHere => 'Pievienošanās šeit ir izslēgta';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON lauks, kurā ir ziņojuma teksts. Parasti teksts.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON lauks, kas identificē, kam ziņojums ir paredzēts.';

  @override
  String get jumpToLatest => 'Pāriet uz jaunāko';

  @override
  String get justNow => 'tikai tagad';

  @override
  String get keepNeoagentRunning => 'Vai turpināt darboties NeoAgent?';

  @override
  String get keepRunning => 'Turpini skriet';

  @override
  String get keepTaskRunning => 'Turpiniet darboties';

  @override
  String get keepTheVaultAvailable => 'Saglabājiet glabātuvi pieejamu';

  @override
  String get keepThisLauncherUpToDate => 'Atjauniniet šo palaišanas programmu.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Turiet šo paneli atvērtu, līdz platforma apstiprina savienojumu.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Saglabājiet šīs sesijas datoru redzamu';

  @override
  String get keepTrackOfYourAiUsage =>
      'Sekojiet savam AI lietojumam. Ierobežojumi tiek piemēroti, lai nodrošinātu godīgu izmantošanu visā platformā.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Turpiniet lietot savas lietotnes kā parasti. NeoAgent darbojas tajā pašā ekrānā un jautā ikreiz, kad tai nepieciešama jauna piekļuve.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Notiek šīs ierīces pievienošana';

  @override
  String get key => 'Atslēga';

  @override
  String get keyIsRequired => 'Nepieciešama atslēga.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Atslēgas vērtību pāri, kas saglabājas sarunās.';

  @override
  String get knowledgeGraph => 'Zināšanu grafiks';

  @override
  String get knowledgeView => 'Zināšanu skats';

  @override
  String get labelOnlyYouSeeIt => 'Etiķete (to redzat tikai jūs)';

  @override
  String get labelsOptional => 'Etiķetes (pēc izvēles)';

  @override
  String get last24Hours => 'Pēdējās 24 stundas';

  @override
  String get last7Days => 'Pēdējās 7 dienas';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Pēdējās 7 dienas: darbojas $arg1 marķieri $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Pēdējais $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Pēdējais: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Pēdējā sinhronizācija, kas nav tukša · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Pēdējais skrējiens: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Pēdējo reizi redzēts $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Pēdējā pierakstīšanās $arg1';
  }

  @override
  String get lastSyncSummary => 'Pēdējās sinhronizācijas kopsavilkums';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Pēdējoreiz lietots: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Pēdējais logs beidzās $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'vēlāk arī starts izslēgts.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Pēdējais skrējiens · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Darbvirsmas lietotņu palaišana šajā platformā netiek atbalstīta.';

  @override
  String get learnRoomNorms => 'Uzziniet telpu normas';

  @override
  String get leave => 'Aiziet';

  @override
  String get leaveARedirectUriBlankTo =>
      'Atstājiet novirzīšanas URI tukšu, lai izmantotu <publisko URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Vai pamest $arg1 komandu?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Atstājiet kā noklusējumu, ja vien neesat pielāgojis BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Atstājiet marķieri tukšu, lai saglabātu pašlaik saglabāto marķieri.';

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
    return 'Ļaujiet $arg1 mani pārvaldīt';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Ļaujiet ikvienam šajā grupā runāt ar $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Ļaujiet tai\ndarboties, kamēr ne.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Ļaujiet NeoAgent noklikšķināt, rakstīt un pārvietoties savās lietotnēs.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Ļaujiet NeoAgent saprast, kas ir redzams jūsu ekrānā.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Ļaujiet kādam, ar kuru strādājat, izlemt, kādus rīkus drīkst izmantot jūsu aģents ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Ļaujiet šai personai nosūtīt $arg1 individuālu ziņojumu.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Ļaujiet šai personai runāt ar $arg1 šeit, bet ne privātās tērzēšanas sarunās vai citās grupās.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Ļaujiet šai personai runāt ar $arg1 privātās tērzētavās un jebkurā grupā, ko tā koplieto.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Līmenis $arg1/$arg2$arg3';
  }

  @override
  String lexicalArg1(Object? arg1) {
    return 'Leksiskā: $arg1';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Saite $arg1';
  }

  @override
  String get linkCopied => 'Saite nokopēta';

  @override
  String get linkExpiresAfter => 'Saite beidzas pēc';

  @override
  String get linkLifetimeHours => 'Saites kalpošanas laiks (stundas)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Saites kalpošanas laikam ir jābūt no 1 līdz 8760 stundām.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Saite derīga līdz $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Saistītie pierakstīšanās nodrošinātāji';

  @override
  String get linuxApp => 'Linux lietotne';

  @override
  String listedArg1(Object? arg1) {
    return 'Sarakstā iekļauts $arg1/';
  }

  @override
  String get listening => 'Klausīšanās';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Tiešsaistes izpildes vēsture, rīku darbības un atbildes.';

  @override
  String get liveModel => 'Dzīvais modelis';

  @override
  String get liveModelProvider => 'Tiešraides modeļu nodrošinātājs';

  @override
  String get liveRun => 'Tiešraides skrējiens';

  @override
  String get liveVoice => 'Dzīvā balss';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Tiešraides balss savienojums nav pieejams.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Tiešraides balss savienojums tika aizvērts.';

  @override
  String get liveVoiceDefaults => 'Tiešās balss noklusējuma iestatījumi';

  @override
  String get liveVoiceFailed => 'Tiešraides balss neizdevās.';

  @override
  String get llmMemoryExportResponse => 'LLM atmiņas eksporta atbilde';

  @override
  String get loadFailed => 'ielāde neizdevās';

  @override
  String get loadingExecutionDetails =>
      'Notiek izpildes informācijas ielāde...';

  @override
  String get loadingNeoagent => 'Notiek NeoAgent ielāde';

  @override
  String get loadingRunFlow => 'Notiek darbības plūsmas ielāde…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Vietējie un privātā tīkla URL tiek atbalstīti, ja NeoAgent serveris var tos sasniegt. Audio nekad netiek pakļauts NeoAgent iedarbībai.';

  @override
  String get localApp => 'vietējā lietotne';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Vietējā aizmugursistēmas instalēšana šajā platformā nav pieejama.';

  @override
  String get localBaseImagePath => 'Vietējā pamata attēla ceļš';

  @override
  String get localComputerControlIsAvailableIn =>
      'Vietējā datora vadība ir pieejama darbvirsmas lietotnē NeoAgent operētājsistēmās macOS, Windows un Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Vietējā datora vadība šeit nav pieejama.';

  @override
  String get localModelsUrl => 'vietējo modeļu url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Vietējā NeoAgent atklāšana īslaicīgi nav pieejama.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Vietējās preferences lietojumprogrammai NeoAgent. Datorvadība vienmēr darbojas caur vienoto mākoņdatoru.';

  @override
  String get localSetup => 'LOKĀLĀ IESTATĪŠANA';

  @override
  String get locationCityOrPlace => 'Atrašanās vieta (pilsēta vai vieta)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Lai aktivizētu laikapstākļu notikumus, ir nepieciešama atrašanās vieta';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Vietas pakalpojuma inicializācija neizdevās: $arg1';
  }

  @override
  String get logCopied => 'Žurnāls nokopēts';

  @override
  String get loginPassword => 'Pieteikšanās parole';

  @override
  String get logout => 'Atteikties';

  @override
  String get logs => 'Baļķi';

  @override
  String get logsCopied => 'Žurnāli nokopēti.';

  @override
  String get logsOnThisComputer => 'Reģistrējas šajā datorā';

  @override
  String get longLivedAccessToken => 'Ilgmūžīgs piekļuves marķieris';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Ilgtermiņa atsaukšana, strukturēti fakti un zināšanu grafiks.';

  @override
  String get lookedAtTheScreen => 'Paskatījās uz ekrānu';

  @override
  String get lookingOnThisComputerAndYour =>
      'Notiek šī datora un vietējā tīkla skatīšanās...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Skatās uz rītdienas sanāksmēm, tāpēc nekas jūs nepārsteidz.';

  @override
  String get loopExecution => 'Cilpas izpilde';

  @override
  String get loopPaused => 'Cilpa apturēta';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'MacOS pieejamība netiek piešķirta NeoAgent. Atļaujiet to sadaļā Sistēmas iestatījumi › Privātums un drošība › Pieejamība.';

  @override
  String get macosApp => 'macOS lietotne';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'MacOS ekrāna ierakstīšana netiek piešķirta NeoAgent. Atļaujiet to sadaļā Sistēmas iestatījumi › Privātums un drošība › Ekrāna ierakstīšana, pēc tam atkārtoti atveriet NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Pasta serveri, kuriem nepieciešama parole, atsakās sūtīt līdz jaunai ';

  @override
  String get main => 'Galvenā';

  @override
  String get makeDefault => 'Padarīt noklusējumu';

  @override
  String get manage => 'Pārvaldīt';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Pārvaldiet sava konta e-pastu, divu faktoru autentifikāciju un aktīvās sesijas.';

  @override
  String get managedBy => 'Pārvalda';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Vadītājiem var būt savi vadītāji (līdz četriem līmeņiem). A ';

  @override
  String get managing => 'Pārvaldīšana';

  @override
  String get manualDestination => 'Manuālais galamērķis';

  @override
  String get manualTrigger => 'Manuālais trigeris';

  @override
  String get masterPassword => 'Galvenā parole';

  @override
  String get matchThisDevice => 'Saskaņojiet šo ierīci';

  @override
  String get matchedAgainstTitleAndBody => 'Atbilst nosaukumam un pamattekstam';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Atbilst vecajai NeoAgent MCP plūsmai: URL un autentifikācijas metode.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP serveris';

  @override
  String get mcpServer2 => 'MCP serveris';

  @override
  String get mcpServerUrl => 'MCP servera URL';

  @override
  String get mcpServers => 'MCP serveri';

  @override
  String get meantForSomeoneElse => 'Domāts kādam citam';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Izmērītā modeļa cena: $arg1';
  }

  @override
  String get memories => 'Atmiņas';

  @override
  String get memory => 'Atmiņa';

  @override
  String memoryArg1(Object? arg1) {
    return 'Atmiņa: $arg1';
  }

  @override
  String get memoryImportSync => 'atmiņas importa sinhronizācija';

  @override
  String get memoryIngestionInterval => 'Atmiņas uzņemšanas intervāls';

  @override
  String get memoryIngestionIntervalMs => 'Atmiņas uzņemšanas intervāls (ms)';

  @override
  String get memoryIngestionIntervalMustBeAt =>
      'Atmiņas ievades intervālam ir jābūt vismaz 1000 ms.';

  @override
  String get memoryInjected => 'Atmiņa ievadīta';

  @override
  String get mentionOrReplyOnly => 'Tikai pieminēt vai atbildēt';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Šai lietotnes sesijai ir apvienoti servera un Flutter izpildlaika žurnāli.';

  @override
  String get messageBodyTemplateJson => 'Ziņojuma pamatteksta veidne (JSON)';

  @override
  String get messageNeedsAccess => 'Ziņojumam ir nepieciešama piekļuve';

  @override
  String get messageTextField => 'Ziņas teksta lauks';

  @override
  String get messaging => 'Ziņapmaiņa';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Ziņojumapmaiņas API push un tīmekļa aizķeres notikumi';

  @override
  String get messagingConnectionNeedsAttention =>
      'Ziņapmaiņas savienojumam jāpievērš uzmanība';

  @override
  String get messagingConnections => 'Ziņapmaiņas savienojumi';

  @override
  String get messagingDelivery => 'Ziņapmaiņas piegāde';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Ziņapmaiņas kļūda. Lūdzu, mēģiniet vēlreiz.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Mikrofona uztveršana negaidīti tika pārtraukta. Mēģiniet vēlreiz.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Mikrofona kļūda: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofons izslēgts. Pieskarieties, lai ieslēgtu skaņu.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Tiešraides balsij ir nepieciešama mikrofona atļauja.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftSlackAndTheOtherIntegrations =>
      'Microsoft, Slack un citas integrācijas. Tie attiecas uz ';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimālā iemaksas vērtība: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Mobilā iestatīšana neizdevās.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Mobilā iestatīšana neizdevās, jo Java nav pieejama ierīcē, kurā darbojas NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Mobilā iestatīšana neizdevās, jo Java nav pieejama ierīcē, kurā darbojas NeoAgent. Instalējiet JDK un mēģiniet vēlreiz.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Mobilā iestatīšana neizdevās. Pārbaudiet, vai Android rīki ir instalēti pareizi, un mēģiniet vēlreiz.';

  @override
  String modeArg1(Object? arg1) {
    return 'režīms: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Režīms tiek bloķēts, kamēr ir aktīvs skrējiens.';

  @override
  String get model => 'Modelis';

  @override
  String modelArg1(Object? arg1) {
    return 'Modelis: $arg1';
  }

  @override
  String get modelAvailability => 'Modeļa pieejamība';

  @override
  String get modelAvailabilitySaved => 'Modeļa pieejamība saglabāta.';

  @override
  String get modelForThisSession => 'Šīs sesijas modelis';

  @override
  String get modelOverride => 'Modeļa ignorēšana';

  @override
  String get modelPending => 'Modelis gaida';

  @override
  String get modelTurn => 'Modeļa pagrieziens';

  @override
  String get modelTurnCompleted => 'Modeļa pagrieziens pabeigts';

  @override
  String get modelTurnStarted => 'Sākās modeļu pagrieziens';

  @override
  String get modelVisibilityHideShowList =>
      'modeļa redzamība slēpt rādīt sarakstu';

  @override
  String get models => 'Modeļi';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modeļi, uzvedība, balss un darbvieta';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modeļi, pārlūkprogramma, balss, diagnostika...';

  @override
  String get modelsRouting => 'Modeļi un maršrutēšana';

  @override
  String get monthly => 'Ikmēneša';

  @override
  String get moreActions => 'Vairāk darbību';

  @override
  String get morningBriefing => 'Rīta instruktāža';

  @override
  String get mostUsedAgents => 'Visbiežāk izmantotie aģenti';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Visbiežāk izmantotie modeļi pēdējā $arg1.';
  }

  @override
  String get mouseKeyboard => 'Pele un tastatūra';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'MouseMove šajā platformā netiek atbalstīts.';

  @override
  String get mustBeReachableOnThePublic =>
      'Jābūt sasniedzamam publiskajā internetā — vietējā un ';

  @override
  String get n24Hours => '24 stundas';

  @override
  String get n2faOrRecoveryCode => '2FA vai atkopšanas kods';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA šajā NeoAgent izvietošanā ir jākonfigurē SESSION_SECRET.';

  @override
  String get n30Days => '30 dienas';

  @override
  String get n365Days => '365 dienas';

  @override
  String get n4HourLimitTokens => '4 stundu ierobežojums (žetoni)';

  @override
  String get n4HourUsage => '4 stundu lietošana';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4h ierobežojums $arg1';
  }

  @override
  String get n7DayUsage => '7 dienu lietošana';

  @override
  String get n7Days => '7 dienas';

  @override
  String get n90Days => '90 dienas';

  @override
  String get name => 'Vārds';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnosaukums: Jauna prasme\napraksts: Aprakstiet, ko šī prasme dara\n---\nUzrakstiet šīs prasmes norādījumus šeit.\n';

  @override
  String get nameOfWhoeverMadeIt => 'tā autora vārds.';

  @override
  String get nameOptional => 'Vārds (neobligāti)';

  @override
  String get nativeAndWebhookChannels => 'Vietējie un tīmekļa aizķeres kanāli';

  @override
  String get naturalBubbles => 'Dabīgie burbuļi';

  @override
  String get nearbyNeoagentServers => 'Netālu atrodas NeoAgent serveri';

  @override
  String get needANewAccountRegister =>
      'Nepieciešams jauns konts? Reģistrēties';

  @override
  String get needAnIdea => 'Nepieciešama ideja?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Nepieciešams atbildēt · $arg1%, lai runātu';
  }

  @override
  String get needsAttention => 'Nepieciešama uzmanība';

  @override
  String get needsInput => 'Nepieciešama ievade';

  @override
  String get neoagentApp => 'NeoAgent lietotne';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent palīgs';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent nevarēja pārbaudīt pieejamo aizmugursistēmas izpildlaiku.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent nevarēja pabeigt vietējo iestatīšanu.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent nevarēja pabeigt vietējo iestatīšanu. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'NeoAgent atkļūdošanas informācija';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter atjauninātājs';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent instalē jaunāko $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent ir instalēts un darbojas.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent šajā datorā nav instalēts.';

  @override
  String get neoagentIsReady => 'NeoAgent ir gatavs';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent joprojām strādā pie uzdevuma. Pabeidziet zvanu un saņemiet rezultātu tērzēšanā vai arī atceliet uzdevumu.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent pārvērš jūsu demonstrāciju par pielāgojamu darbplūsmu.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent gaida, kamēr izmantojat darbvirsmu.';

  @override
  String get neoagentIsWorking => 'NeoAgent strādā';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux dators';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT NEPIECIEŠAMS LĒMUMS';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'NeoAgent izpildlaika lejupielādēm ir nepieciešama droša adrese.';

  @override
  String get neoagentServerAddress => 'NeoAgent servera adrese';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'NeoAgent pakalpojuma e-pasts nav gatavs. Lūdziet servera operatoram pārbaudīt e-pasta vides iestatījumus.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'NeoAgent iestatīšanu nevarēja pabeigt.';

  @override
  String get neoagentUser => 'NeoAgent lietotājs';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent izmanto šo datoru automātiski un jautā, pirms tas izmanto jūsu ekrānu, peli, tastatūru, failus vai komandrindu.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent izmanto jūsu aptuveno atrašanās vietu fonā, lai aktivizētu atgādinājumus par ģeožogu (piemēram, \"Atgādināt man nopirkt pienu, kad eju garām lielveikalam\").\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent darbvieta';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][steck] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall aizmugursistēmas URL';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Nepieciešams NeoRecall aizmugursistēmas URL.';

  @override
  String get neorecallSetup => 'NeoRecall iestatīšana';

  @override
  String get networkRequestFailed => 'tīkla pieprasījums neizdevās';

  @override
  String get networkWriteRequests => 'Tīkla rakstīšanas pieprasījumi';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'nekad netiek ieskaitīts koplietošanas limitos.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Jaunie konti pirms pierakstīšanās apstiprina savu e-pasta adresi.';

  @override
  String get newAccountsPerDay => 'Jauni konti dienā';

  @override
  String get newChat => 'Jauna tērzēšana';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Jaunās grupas paliek klusas, ja vien kāds neatzīmē $arg1, līdz tās ieslēdzat.';
  }

  @override
  String get newLink => 'Jauna saite';

  @override
  String get newPasswordsDoNotMatch => 'Jaunās paroles nesakrīt.';

  @override
  String get newRecoveryCodes => 'Jauni atkopšanas kodi';

  @override
  String get newSession => 'Jauna sesija';

  @override
  String get newSessionN => 'Jauna sesija (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Jauna sesija ar tādu pašu iestatījumu';

  @override
  String get newSkill => 'Jauna prasme';

  @override
  String get newSkill2 => 'Jauna prasme';

  @override
  String get newThisWeek => 'Jaunums šonedēļ';

  @override
  String get newsDigest => 'Ziņu apkopojums';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Nākamais mēģinājums: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Nextcloud pieteikšanās plūsma';

  @override
  String get nextcloudSetup => 'Nextcloud iestatīšana';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'Nextcloud URL';

  @override
  String get nextcloudUrlIsRequired => 'Nepieciešams Nextcloud URL.';

  @override
  String get nickname => 'Segvārds';

  @override
  String get noAccountsConnectedYet => 'Vēl nav pievienots neviens konts.';

  @override
  String get noAccountsFound => 'Nav atrasts neviens konts.';

  @override
  String get noActiveSessionsFound => 'Nav atrasta neviena aktīva sesija.';

  @override
  String get noAgentsYet => 'Vēl nav aģentu';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Nav konfigurēts neviens AI nodrošinātājs, tāpēc tērzējiet un sūtiet ziņojumus ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Nav apstiprinājuma uzvedņu — aģents darbojas bez pārtraukuma.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Šai platformai neatbilst neviens $arg1 izlaišanas līdzeklis.';
  }

  @override
  String get noArguments => '(nav argumentu)';

  @override
  String get noAuth => 'Nav autorizācijas';

  @override
  String get noBindingsYet => 'Vēl nav saišu.';

  @override
  String get noChangesYet => 'Izmaiņu vēl nav';

  @override
  String get noChannelsFound => 'Nav atrasts neviens kanāls';

  @override
  String get noCloudComputerSlotIsFree =>
      'Pašlaik nav brīva neviena mākoņdatora slota. Pēc brīža mēģiniet vēlreiz.';

  @override
  String get noCoreMemoryEntriesYet => 'Vēl nav pamata atmiņas ierakstu.';

  @override
  String get noDescription => 'Nav apraksta';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Pašlaik nav pieejams neviens darbvirsmas displejs.';

  @override
  String get noDetailAvailable => 'Sīkāka informācija nav pieejama';

  @override
  String get noDetailedSyncSummaryYet =>
      'Pagaidām nav detalizēta sinhronizācijas kopsavilkuma.';

  @override
  String get noDetailsCaptured => 'Nav tvertas detaļas.';

  @override
  String get noEmailLinked => 'E-pasts nav saistīts';

  @override
  String get noExternalSignInProvidersLinked =>
      'Nav piesaistīti ārējie pierakstīšanās nodrošinātāji.';

  @override
  String get noGroupMessagesYet => 'Vēl nav nevienas grupas ziņas';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Vēl nav pievienota neviena grupai noteikta persona.';

  @override
  String get noGroupsAddedYet => 'Vēl nav pievienota neviena grupa.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Vēl nav atrasta neviena grupa. Kad $arg1 redz grupas ziņojumu, izmantojiet Atrast nesenās tērzēšanas sarunas, un tās tiks parādītas šeit.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Vēl nav atrasta neviena grupa. Kad $arg1 redz grupas ziņojumu, izmantojiet Atrast nesenās tērzēšanas sarunas.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Nav atgriezta veselības datu slodze.';

  @override
  String get noHealthSamplesStoredYet =>
      'Vēl nav saglabāts neviens veselības paraugs.';

  @override
  String get noHttpClientImplementationForThis =>
      'Nav HTTP klienta ieviešanas šai platformai.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Šajā darbībā netika reģistrēta neviena ievade vai izvade.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Šim meklējumam neatbilst neviena integrācija.';

  @override
  String get noLimit => 'Nav ierobežojumu';

  @override
  String get noLocalPasswordIsSetYet =>
      'Vēl nav iestatīta vietējā parole. Izveidojiet to, lai iespējotu pierakstīšanos ar lietotājvārdu/paroli.';

  @override
  String get noLogEntries => 'Nav žurnāla ierakstu.';

  @override
  String get noMatchingSettings => 'Nav atbilstošu iestatījumu';

  @override
  String get noMcpServersMatchThisSearch =>
      'Šim meklējumam neatbilst neviens MCP serveris.';

  @override
  String get noMemoryEntriesFound => 'Atmiņas ieraksti nav atrasti.';

  @override
  String get noMemorySync => 'Nav atmiņas sinhronizācijas';

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Neviens modelis neatbilst \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Šim braucienam netika reģistrēts neviens modeļa pieprasījums.';

  @override
  String get noModelsDiscoveredYet => 'Vēl nav atklāts neviens modelis';

  @override
  String get noModelsSelected => 'Nav atlasīts neviens modelis';

  @override
  String get noModelsYet => 'Vēl nav modeļu';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'ar šo pakalpojumu sniedzēju nav saistīts neviens neoagent konts';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Šim datoram nav pieejams neviens NeoAgent aizmugursistēmas izpildlaiks.';

  @override
  String get noNetworkConnection => 'Nav tīkla savienojuma';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Nav tīkla savienojuma. Izveidojiet savienojumu, lai turpinātu lietot NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Nav tīkla savienojuma. Atkārtoti izveidojiet savienojumu, lai pārbaudītu atjauninājumus.';

  @override
  String get noOne => 'Neviens';

  @override
  String get noOneAddedYet => 'Neviens vēl nav pievienots.';

  @override
  String get noOneCanMessage => 'Neviens nevar nosūtīt ziņojumu';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Cits NeoAgent serveris netika atrasts. Varat meklēt vēlreiz vai ievadīt adresi manuāli.';

  @override
  String get noPeopleAddedYet => 'Vēl nav pievienota neviena persona.';

  @override
  String get noPlatformsMatch => 'Neviena platforma neatbilst';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Vēl nav pieejams neviens pakalpojumu sniedzējs, ko konfigurēt.';

  @override
  String get noRecentChannelActivity => 'Nav pēdējās darbības kanālā';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Nav rezultātu vaicājumam \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Šajā diapazonā nav skrējienu.';

  @override
  String get noRunsMatchTheseFilters =>
      'Neviens skrējiens neatbilst šiem filtriem';

  @override
  String get noRunsYet => 'Vēl nav skrējienu';

  @override
  String get noRunsYet2 => 'Vēl nav skrējienu.';

  @override
  String get noSecurityKeyWasProvided => 'Drošības atslēga netika sniegta.';

  @override
  String get noServerUrlSet => 'Nav iestatīts servera URL';

  @override
  String get noSessionMatchesThatSearch =>
      'Neviena sesija neatbilst šim meklēšanas vaicājumam.';

  @override
  String get noSessionsYet => 'Vēl nav sesiju';

  @override
  String get noSkillsMatchTheseFilters =>
      'Neviena prasme neatbilst šiem filtriem.';

  @override
  String get noStepsWereRecordedForThis =>
      'Šim skrējienam netika reģistrēts neviens solis.';

  @override
  String get noSummaryAvailable => 'Nav pieejams kopsavilkums.';

  @override
  String noTasksForArg1(Object? arg1) {
    return '$arg1 nav uzdevumu';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Neviens rīks neatbilst \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Atjauninājums nedarbojas';

  @override
  String get noUsageYet => 'Vēl nav lietots.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Vēl nav pieejams neviens apstiprināts NeoAgent aizmugursistēmas izpildlaiks.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Neviens to vairs nevar izmantot. Cilvēki, kuri jau ir pievienojušies ';

  @override
  String get none => 'Nav';

  @override
  String get notApprovedYet => 'vēl nav apstiprināts';

  @override
  String get notAuthenticated => 'nav autentificēts';

  @override
  String get notCheckedYet => 'Vēl nav pārbaudīts';

  @override
  String get notConfigured => 'Nav konfigurēts';

  @override
  String get notConnected => 'Nav savienots';

  @override
  String get notConnected2 => 'Nav izveidots savienojums';

  @override
  String get notInstalled => 'Nav instalēts';

  @override
  String get notNeeded => 'Nav vajadzīgs';

  @override
  String get notNeededEnough => 'Nepietiekami vajadzīgs';

  @override
  String get notNow => 'Ne tagad';

  @override
  String get notNow2 => 'Ne tagad';

  @override
  String get notSet => 'Nav iestatīts';

  @override
  String get notSetUp => 'Nav iestatīts';

  @override
  String get notTheSameAsAdmin => 'Nav tas pats, kas admins';

  @override
  String get nothingFound => 'Nekas netika atrasts';

  @override
  String get nothingHereYet => 'Šeit vēl nekas nav.';

  @override
  String get nothingHereYet2 => 'Šeit vēl nekas nav';

  @override
  String get nothingMatches => 'Nekas neatbilst';

  @override
  String get nothingStoredYet => 'Vēl nekas nav saglabāts.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthAppCredentialsThatLetAccounts =>
      'OAuth lietotnes akreditācijas dati, kas ļauj kontiem izveidot savienojumu ar Google, ';

  @override
  String get oauthClientId => 'OAuth klienta ID';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth klienta ID slepenā novirzīšanas api atslēga';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth klienta ID slepenais novirzīšanas Gmail kalendāra disks';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'OAuth palaišana šajā platformā netiek atbalstīta.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook nomnieka klienta ID noslēpums';

  @override
  String get oauthToken => 'OAuth pilnvara';

  @override
  String get oauthWithPkce => 'OAuth ar PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'no $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'savējo. Pēc saglabāšanas tas vairs netiek rādīts.';

  @override
  String get off => 'Izslēgts';

  @override
  String get officialIntegration => 'Oficiālā integrācija';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Oficiālā integrācija neatgrieza savienojuma URL.';

  @override
  String get on => 'Ieslēgts';

  @override
  String get onASignedInAndroidDevice =>
      'Android ierīcē, kurā esat pierakstījies, atveriet sadaļu Iestatījumi › Pierakstīšanās un drošība, skenējiet šo kodu un apstipriniet pieteikšanos.';

  @override
  String get onByDefaultForNewGroups =>
      'Ieslēgts pēc noklusējuma jaunām grupām';

  @override
  String get onDemand => 'Pēc pieprasījuma';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Ieslēgts $arg1 no $arg2 grupām';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'ieslēgts. Viņi var atkal pievienoties, tikai izmantojot jaunu uzaicinājuma saiti.';

  @override
  String get onYourOwnTheDefault => 'Viens pats (noklusējums)';

  @override
  String get once => 'Vienreiz';

  @override
  String get oneBlankToKeepWhatIs =>
      'viena tukša, lai saglabātu to, kas tiek glabāts.';

  @override
  String get oneIsSavedOtherChangesIn =>
      'viens ir izglābts. Tiek saglabātas arī citas izmaiņas šajā veidlapā.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Vienam vai vairākiem kontiem ir beidzies derīguma termiņš. Atkārtoti pievienojiet ietekmēto kontu, lai atjaunotu piekļuvi rīkam.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Viens izpildlaiks kontrolē personu, grupu gājienu uzņemšanu, telpas atmiņu, normas, prāta teoriju un piegādi.';

  @override
  String get oneTimeRun => 'Vienreizējs skrējiens';

  @override
  String get onlyApkOrApksFilesCan =>
      'Var instalēt tikai .apk vai .apks failus.';

  @override
  String get onlyInThisGroup => 'Tikai šajā grupā';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Nepieciešams tikai tad, ja pakalpojums pieprasa papildu HTTP galvenes.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Nepieciešams tikai tad, ja vēlaties pārveidot izejošo lietderīgo slodzi.';

  @override
  String get onlyTheyCanChangeIt => 'Tikai viņi to var mainīt.';

  @override
  String get open => 'Atvērt';

  @override
  String get openAccountSettingsOnASigned =>
      'Atveriet Iestatījumi › Pierakstīšanās un drošība Android ierīcē, kurā esat pierakstījies, skenējiet šo kodu un apstipriniet pieteikšanos.';

  @override
  String get openComputer => 'Atveriet datoru';

  @override
  String get openDashboard => 'Atveriet informācijas paneli';

  @override
  String get openFolder => 'Atvērt mapi…';

  @override
  String get openInWorkbench => 'Atvērts darbagaldā';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Atveriet NeoAgent un atkārtoti pievienojiet $arg1, lai atjaunotu ziņojumapmaiņu.';
  }

  @override
  String get openTimeSettings => 'Atvērt laika iestatījumus';

  @override
  String get openToAnyone => 'Atvērts ikvienam';

  @override
  String get openTrello => 'Atveriet Trello';

  @override
  String get openVoiceAssistant => 'Atveriet balss palīgu';

  @override
  String get openWiFiSettings => 'Atveriet Wi-Fi iestatījumus';

  @override
  String get openWithTheDefaultApp => 'Atveriet ar noklusējuma lietotni';

  @override
  String get openaiCodex => 'OpenAI kodekss';

  @override
  String get openaiCompatible => 'openai saderīgs';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Ar OpenAI saderīgs galapunkts (jūsu serveris vai cits ';

  @override
  String openedArg1(Object? arg1) {
    return 'Atvērts $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Darbvirsmas vietrāžu URL atvēršana šajā platformā netiek atbalstīta.';

  @override
  String get openingYourSavedDesktop => 'Saglabātās darbvirsmas atvēršana.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Saglabātās darbvirsmas atvēršana. Parasta iedarbināšana aizņem mazāk nekā 10 sekundes.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Izvēles papildu noslēpums, ja aizsargājat ienākošo tīmekļa aizķeri.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Neobligāta ignorēšana, ja nepietiek ar tīmekļa aizķeres URL.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Izvēles noslēpums, lai pārbaudītu ienākošos tērzēšanas notikumus.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Izvēles noslēpums, lai pārbaudītu ienākošos notikumus.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Izvēles noslēpums, lai pārbaudītu ienākošos iMessage notikumus.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Izvēles noslēpums, lai pārbaudītu ienākošos LINE notikumus.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Izvēles noslēpums, lai pārbaudītu ienākošos Mattermost notikumus.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Izvēles noslēpums, lai pārbaudītu ienākošos Teams notikumus.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Pēc izvēles. Aģentam jau ir sava personība. Viss, ko pievienojat par toni, tiek uzklāts virs tā, tāpēc jums tas nekad nav jādefinē.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Pēc izvēles. Kad tas ir iestatīts, tas tiek izmantots URL vietā.';

  @override
  String get orAnswerInYourOwnWords => 'Vai arī atbildiet saviem vārdiem';

  @override
  String get orBuildYourOwnTask => 'Vai arī izveidojiet savu uzdevumu';

  @override
  String get orContinueWith => 'vai turpināt ar';

  @override
  String get orFiles => 'vai faili.';

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
  String get originNotAllowed => 'izcelsme nav atļauta';

  @override
  String get outgoingMessage => 'Izejošā ziņa';

  @override
  String get outgoingWebhookUrl => 'Izejošais tīmekļa aizķeres URL';

  @override
  String get outlookEmailReceived => 'Saņemts Outlook e-pasts';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Pārrakstīt uzvedības piezīmes no importēšanas.';

  @override
  String get ownModel => 'savs modelis';

  @override
  String get packageName => 'Pakas nosaukums';

  @override
  String get pairWithQrCode => 'Savienojiet pārī ar QR kodu';

  @override
  String get password => 'Parole';

  @override
  String get password2faAndActiveSessions => 'Parole, 2FA un aktīvās sesijas';

  @override
  String get passwordCreated => 'Parole izveidota.';

  @override
  String get passwordIsTooWeak => 'parole ir pārāk vāja';

  @override
  String get passwordMin8 => 'parole vismaz 8';

  @override
  String get passwordOrApiKey => 'Parole vai API atslēga';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Paroles stiprums: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Paroles nesakrīt.';

  @override
  String get pasteAKey => 'Ielīmējiet atslēgu.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Ielīmējiet jaunu atslēgu, lai aizstātu $arg1';
  }

  @override
  String get pasteTheKey => 'Ielīmējiet atslēgu';

  @override
  String get pasteYourAccountToken => 'Ielīmējiet sava konta pilnvaru';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Tālāk ielīmējiet savu $arg1 API atslēgu. Tas ir ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Ceļam jāpaliek NeoAgent darbvietā.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Ceļam jāpaliek darbvietas mapē.';

  @override
  String get pauseLiveUpdates => 'Pārtraukt tiešraides atjauninājumus';

  @override
  String get pauseTaskLoop => 'Pauzēt uzdevumu cilpu';

  @override
  String get paused => 'Pauzēts';

  @override
  String peakArg1(Object? arg1) {
    return 'maksimums $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Personas privātajā tērzēšanā';

  @override
  String get perAccountRateLimits => 'Likmes ierobežojumi vienam kontam';

  @override
  String get perCategoryPermissions => 'Atļaujas pa kategorijām';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Katra rīka atļauju politikas, apstiprināšanas vārti un procesa izolācija čaulas izpildei.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Nepieciešama atļauja: $arg1';
  }

  @override
  String get permissionsNeeded => 'Nepieciešamas atļaujas';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Atļaujas. Neviens cits to nevar mainīt.';

  @override
  String get personOrChat => 'Persona vai tērzēšana';

  @override
  String get personaBehaviorNotes => 'Personas uzvedības piezīmes';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Personiskās piekļuves marķieris Mattermost robotam.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Personīgie kanāli un tiešā atbalsta virsmas.';

  @override
  String get personalSelfChat => 'Personīga paštērzēšana';

  @override
  String get phoneNumber => 'Tālruņa numurs';

  @override
  String get pickARunFromTheList =>
      'Izvēlieties skrējienu no saraksta, lai skatītu tā soļus.';

  @override
  String get pickARunFromTheList2 =>
      'Kreisajā pusē esošajā sarakstā izvēlieties skrējienu, lai izpētītu tā plūsmu.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Izvēlieties kādu no nesenajām $arg1 tērzēšanas sarunām vai pievienojiet personu vai grupu pats.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Izvēlieties, kā $arg1 izmanto šo kontu.';
  }

  @override
  String get pickOneToFillInThe =>
      'Izvēlieties vienu, lai aizpildītu uzdevumu. Pēc tam visu var pielāgot.';

  @override
  String get picksUpWhereYouLeftOff => 'Atsāk no vietas, kur pārtraucāt';

  @override
  String get plan => 'Plāns';

  @override
  String get planning => 'Plānošana';

  @override
  String get platform => 'Platforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Lūdzu, izvēlieties grafiku.';

  @override
  String get pleaseEnterAFilename => 'Lūdzu, ievadiet faila nosaukumu.';

  @override
  String get pleaseEnterAKey => 'Lūdzu, ievadiet atslēgu.';

  @override
  String get pleaseEnterAPrompt => 'Lūdzu, ievadiet uzvedni.';

  @override
  String get pleaseEnterATaskName => 'Lūdzu, ievadiet uzdevuma nosaukumu.';

  @override
  String get pleaseEnterTheMemoryContent => 'Lūdzu, ievadiet atmiņas saturu.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Lūdzu, ievadiet uzdevuma izpildes laiku.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Lūdzu, atlasiet kontu vai ievadiet derīgu savienojuma ID.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Norādiet NeoAgent jebkurā ar OpenAI saderīgo tērzēšanas pabeigšanu ';

  @override
  String get pointTheCameraAtTheCode =>
      'Pavērsiet kameru pret kodu, kas parādīts ierīcē, kurā esat izrakstījies. Apstiprinājums paliek šajā tālrunī.';

  @override
  String get port => 'Osta';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'porta node_env publiskā url uzticības starpniekservera drošu sīkfailu izvietošana';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Augstākās kvalitātes automatizācija ar grafiku un integrācijas aktivizētājiem.';

  @override
  String get prepareQrCode => 'Sagatavojiet QR kodu';

  @override
  String get preparingNeoagent => 'Notiek NeoAgent sagatavošana…';

  @override
  String get preparingNeoagent2 => 'NeoAgent sagatavošana';

  @override
  String get pressAndHoldForQuickCapture =>
      'Nospiediet un turiet, lai ātri uzņemtu';

  @override
  String get pressKeysIsNotSupportedOn =>
      'taustiņu nospiešana šajā platformā netiek atbalstīta.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Nospiests $arg1';
  }

  @override
  String get priceUnknown => 'Cena nav zināma';

  @override
  String get primaryDisplay => 'Primārais displejs';

  @override
  String get privateChat => 'Privātā tērzēšana';

  @override
  String get privateChats => 'Privātas tērzēšanas sarunas';

  @override
  String get privateChats2 => 'privātās tērzēšanas';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Privātās tērzēšanas sarunas: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Privātās tērzēšanas $arg1 · grupas $arg2';
  }

  @override
  String get privateChatsOnly => 'Tikai privātas tērzēšanas';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'privātā tīkla adreses nav atļautas.';

  @override
  String get profileEmailAndPersonalData => 'Profils, e-pasts un personas dati';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Uzvedne, pirms NeoAgent paliek sistēmas teknē.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Uzvednes kešatmiņa: $arg1 kešatmiņas marķieri ';
  }

  @override
  String get promptCopied => 'Uzvedne ir nokopēta.';

  @override
  String get promptOrSchedule => 'uzvedne vai grafiks.';

  @override
  String get promptToPasteIntoAnotherAi => 'Uzvedne ielīmēt citā AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Pakalpojumu sniedzēja saistīšanu nevarēja sākt.';

  @override
  String get providerSignInCouldNotBe =>
      'Pakalpojumu sniedzēja pierakstīšanos nevarēja sākt.';

  @override
  String get providers => 'Pakalpojumu sniedzēji';

  @override
  String get providersEachAccountCanStillPick =>
      'Pakalpojumu sniedzēji; katrs konts joprojām var izvēlēties savu modeli sadaļā Iestatījumi. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Pakalpojumu sniedzējus, integrācijas, balss un papildu iespējas jebkurā laikā var pabeigt sadaļā Iestatījumi.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Publiski izdot un izvilkt pieprasījumu pavedieni, uz kuriem atbildēts tikai apstiprinātām personām.';

  @override
  String get publicUrl => 'Publisks URL';

  @override
  String get publicUrlAndAllowedOrigins => 'Publisks URL un atļautie avoti';

  @override
  String get publicUrlOverride => 'Publiskā URL ignorēšana';

  @override
  String get pullsTogetherTheDayAhead => 'Savelk kopā dienu uz priekšu';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'Tālruņa saistīšana, pamatojoties uz QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR pieteikšanās ir pabeigta, taču NeoAgent nevarēja saglabāt sesiju. Lūdzu, mēģiniet vēlreiz.';

  @override
  String get qrLoginCouldNotBeStarted => 'QR pieteikšanos nevarēja sākt.';

  @override
  String get qrLoginRequestHasExpired =>
      'qr pieteikšanās pieprasījuma termiņš ir beidzies';

  @override
  String get qrLoginRequestWasNotFound =>
      'qr pieteikšanās pieprasījums netika atrasts';

  @override
  String get qrPairing => 'QR savienošana pārī';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'tiek izpildīti vaicājumi; viss, kas raksta, tiek noraidīts.';

  @override
  String get query => 'Vaicājums';

  @override
  String get queryFilter => 'Vaicājums / filtrs';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Rindā kā stūrēšana pašreizējam braucienam: $arg1';
  }

  @override
  String get quickstart => 'Ātrā palaišana';

  @override
  String get quit => 'Iziet';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, wind_alert';

  @override
  String get ranAScriptInThePage => 'Palaida skriptu lapā';

  @override
  String ranArg1(Object? arg1) {
    return 'Noskrēja $arg1';
  }

  @override
  String get rateLimits => 'Likmes ierobežojumi';

  @override
  String get readAnArtifact => 'Izlasi artefaktu';

  @override
  String get readAndEditFilesInsideYour =>
      'Lasiet un rediģējiet failus savā NeoAgent Workspace mapē.';

  @override
  String readArg1(Object? arg1) {
    return 'Izlasiet $arg1';
  }

  @override
  String get readError => 'Lasīšanas kļūda';

  @override
  String get readFiles => 'Lasīt failus';

  @override
  String get readOnly => 'Tikai lasāms';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Izlasiet mapi un apkopojiet steku, ievades punktus un to, kā to palaist.';

  @override
  String get readThePage => 'Izlasiet lapu';

  @override
  String get readTheUiTree => 'Izlasiet lietotāja interfeisa koku';

  @override
  String get readWrite => 'Lasīt / Rakstīt';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Nolasa soļus, sirdsdarbības ātrumu, miegu, vingrinājumus un svaru.';

  @override
  String get ready => 'Gatavs';

  @override
  String get readyForFirstTimeSetup => 'Gatavs pirmajai iestatīšanai';

  @override
  String get readyToConnect => 'Gatavs savienojumam';

  @override
  String get recentChannelActivity => 'Pēdējā kanāla darbība';

  @override
  String get recentChats => 'Pēdējās tērzēšanas sarunas';

  @override
  String get recentDecisions => 'Nesenie lēmumi';

  @override
  String get recentFailedRuns => 'Pēdējās neveiksmīgās darbības';

  @override
  String get recentGroupDecisions => 'Jaunākie grupas lēmumi';

  @override
  String get recentRuns => 'Nesenie skrējieni';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Nesenie skrējieni aizņem apmēram $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Jaunākā servera izvade, jaunākie vispirms.';

  @override
  String get recentUsage4Hours => 'Nesenais lietojums (4 stundas)';

  @override
  String get recents => 'Nesen';

  @override
  String get recipientField => 'Saņēmēja lauks';

  @override
  String get reconnectOrFinishSetup =>
      'Atkārtoti pievienojiet vai pabeidziet iestatīšanu';

  @override
  String get reconnectingThisDevice =>
      'Notiek šīs ierīces atkārtota pievienošana…';

  @override
  String get recurring => 'Atkārtojas';

  @override
  String get redirectUri => 'Novirzīt URI';

  @override
  String get redoOnboarding => 'Atkārtot iestāšanos';

  @override
  String get refresh => 'Atsvaidzināt';

  @override
  String get refreshCode => 'Atsvaidzināt kodu';

  @override
  String get refreshNow => 'Atsvaidziniet tūlīt';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Atsvaidziniet Android ekrānu, lai mēģinātu vēlreiz.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Atteikties sūtīt, ja vien savienojums netiek jaunināts uz TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'neatkarīgi no tālāk norādītajiem katras kategorijas iestatījumiem.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Reģistrējiet $arg1 asistenta izsaukuma plūsmai.';
  }

  @override
  String get registrationIsClosed => 'reģistrācija ir slēgta';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'reģistrācija reģistrēt jaunus kontus ļauj reģistrēties';

  @override
  String get rejectInvalidTlsCertificates =>
      'Noraidīt nederīgos TLS sertifikātus';

  @override
  String relationArg1(Object? arg1) {
    return 'Saistība: $arg1';
  }

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'atlaist un restartēt. Pievienotās lietotnes tiek atkārtoti savienotas, tiklīdz tās ir atjaunotas.';

  @override
  String get releaseChannel => 'Atbrīvošanas kanāls';

  @override
  String get releaseCommitBranchNode => 'atbrīvot commit filiāles mezglu';

  @override
  String get releaseWhenYouAreDone => 'Atlaidiet, kad esat pabeidzis.';

  @override
  String get reloadNow => 'Pārlādēt tūlīt';

  @override
  String get rememberThisChoice => 'Atcerieties šo izvēli';

  @override
  String get remove => 'Noņemt';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Vai noņemt \"$arg1\" un tā reģistrētās darbības no darbības vēstures?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Noņemiet \"$arg1\" no galvenās atmiņas.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Vai noņemt atslēgu $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'noņemt dzēst gdpr lietotāju';

  @override
  String get removeSmtpPassword => 'Noņemiet SMTP paroli';

  @override
  String get removeTheSmtpPassword => 'Vai noņemt SMTP paroli?';

  @override
  String get rename => 'Pārdēvēt';

  @override
  String get renameSecurityKey => 'Pārdēvēt drošības atslēgu';

  @override
  String get renameSession => 'Pārdēvēt sesiju';

  @override
  String get repairAndRetry => 'Labojiet un mēģiniet vēlreiz';

  @override
  String get repairDesktop => 'Labot darbvirsmu';

  @override
  String get repeat => 'Atkārtojiet';

  @override
  String get repliesWhenTagged => 'Atbild, kad atzīmēts';

  @override
  String get replyToAddress => 'Atbildēt — adrese';

  @override
  String replyToArg1(Object? arg1) {
    return 'Atbildēt uz $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Repozitorijai ir jābūt šādā formātā: īpašnieks/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reproducējiet manis aprakstīto kļūdu, atrodiet galveno cēloni un izlabojiet to ar regresijas testu.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'pieprasījums neizdevās, izmantojot http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Pieprasījums neizdevās, izmantojot HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Pieprasīt atļaujas';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Pieprasījums $arg1 neizdevās, pirms aizmugursistēma atbildēja.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Pieprasīts $arg1';
  }

  @override
  String get requireStarttls => 'Nepieciešams STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Nepieciešams aiz HTTPS vai TLS starpniekservera. Attiecas pēc servera ';

  @override
  String get requiredExampleBerlinDe => 'Obligāti. Piemērs: Berlīne, DE';

  @override
  String get requiredFormatOwnerRepo => 'Obligāti. Formāts: īpašnieks/repo';

  @override
  String get reserveAssistantHotkey => 'Rezerves palīga karstais taustiņš';

  @override
  String get reset => 'Atiestatīt';

  @override
  String get resetPassword => 'Atiestatīt paroli';

  @override
  String get resetView => 'Atiestatīt skatu';

  @override
  String get responsibilities => 'Pienākumi';

  @override
  String get restart => 'Restartēt';

  @override
  String get restartToFinishTheUpdate =>
      ' Restartējiet, lai pabeigtu atjaunināšanu.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Iepriekšējā NeoAgent izpildlaika atjaunošana';

  @override
  String get restrictDelegationTargets => 'Ierobežot deleģēšanas mērķus';

  @override
  String get result => 'Rezultāts';

  @override
  String get resultDelivery => 'Rezultātu piegāde';

  @override
  String get resultOneClickAddsOneYou =>
      'rezultāts. Viens klikšķis pievieno vienu; jūs varat to rediģēt vēlāk.';

  @override
  String get results => 'Rezultāti';

  @override
  String get retrievalInspector => 'Atgūšanas inspektors';

  @override
  String get retry => 'Mēģiniet vēlreiz';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Atkārtoti lietojams · lietots $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Pārskatiet neizdarītās izmaiņas';

  @override
  String get revoke => 'Atsaukt';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Vispirms atsaukt administratoru ar `neoagent admin atsaukt $arg1\'';
  }

  @override
  String get revokeThisLink => 'Vai atsaukt šo saiti?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Telpas paketes logs: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Pagrieziet, lai turpinātu';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'rindas. Lai skatītu, pievienojiet LIMIT vai šaurāku WHERE klauzulu ';

  @override
  String get rule => 'Noteikums';

  @override
  String get run => 'Izpilde';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Palaidiet patvaļīgas komandas savā datorā vai virtuālajā mašīnā.';

  @override
  String get runAt => 'Skrien plkst';

  @override
  String get runCompleted => 'Skrējiens pabeigts';

  @override
  String get runFailed => 'Skrējiens neizdevās';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Palaidiet git diff, pārskatiet neizdarītās izmaiņas, lai noteiktu kļūdas un stila problēmas, un apkopojiet atrasto.';

  @override
  String get runNotFound => 'Palaist nav atrasts';

  @override
  String get runNow => 'Izpildīt tagad';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Darbiniet ienākošos personīgos WhatsApp ziņojumus.';

  @override
  String get runQuery => 'Palaist vaicājumu';

  @override
  String get runShellCommandsOrInstallApps =>
      'Palaidiet čaulas komandas vai instalējiet lietotnes savā Android ierīcē.';

  @override
  String get runStarted => 'Skrējiens sākās';

  @override
  String get runStatus => 'Palaist statuss';

  @override
  String get runStopped => 'Skrējiens apstājās';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Palaidiet termināļa komandas un atveriet lietotnes vai tīmekļa lapas.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Palaidiet šo serveri: konti, atjauninājumi, pakalpojumu sniedzēji, konfigurācija ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Palaist, kad tiek saņemts atbilstošs Gmail ziņojums.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Palaist, kad tiek saņemts atbilstošs Outlook e-pasts.';

  @override
  String get runWhenANewIssueMatching =>
      'Palaist, kad krātuvē tiek atvērta jauna problēma, kas atbilst jūsu filtriem.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Palaist, kad ir izveidota jauna NeoRecall atmiņa, kas atbilst jūsu filtriem.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Palaist, kad ierīcē tiek parādīts paziņojums.';

  @override
  String get runWhenASlackMessageMatches =>
      'Palaist, kad Slack ziņojums atbilst atlasītajam tvērumam.';

  @override
  String get runWhenATeamsChatMessage =>
      'Palaist, kad Teams tērzēšanas ziņojums atbilst atlasītajam tvērumam.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Palaist, kad vietai tiek prognozēti konfigurēti laikapstākļi.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'palaist. Kamēr jebkurš modelis ir izslēgts, piegādātāju pievienotie modeļi ';

  @override
  String get running => 'Notiek izpilde';

  @override
  String runningArg1(Object? arg1) {
    return 'Darbojas $arg1';
  }

  @override
  String get runningTask => 'Skriešanas uzdevums';

  @override
  String get runningTool => 'Skriešanas rīks';

  @override
  String get runs => 'Izpildes';

  @override
  String get runsEveryDayAtTheSelected =>
      'Darbojas katru dienu izvēlētajā laikā.';

  @override
  String get runsFourTimesPerHour => 'Darbojas četras reizes stundā.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— darbojas, ziņojumi, atmiņas, integrācijas, faili un ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'darbības, ziņas, atmiņas, integrācijas, faili un sesijas. ';

  @override
  String get runsMondayThroughFriday =>
      'Darbojas no pirmdienas līdz piektdienai.';

  @override
  String get runsOnSelectedWeekdays => 'Darbojas izvēlētajās darba dienās.';

  @override
  String get runsOncePerHour => 'Darbojas reizi stundā.';

  @override
  String get runsOncePerMonthOnThe => 'Darbojas reizi mēnesī izvēlētajā dienā.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Darbojas tikai tad, kad nospiežat Palaist tūlīt.';

  @override
  String get runsPerDay => 'Darbojas dienā';

  @override
  String get runsPerDay30Days => 'Darbojas dienā (30 dienas)';

  @override
  String get runsThatCompleted => 'Darbojas, kas pabeigta';

  @override
  String get runsThisWeek => 'Darbojas šonedēļ';

  @override
  String get runsToday => 'Skrien šodien';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Šeit ir pieejamas darbības, rīki, atmiņa, plānošana, prasmes un MCP.';

  @override
  String get runsTwicePerHour => 'Darbojas divas reizes stundā.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Darbojas atpakaļ uz koplietojamo servera atslēgu $arg1, ja tāda ir konfigurēta. To nevar atsaukt.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Izpildes laiks $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Darbības laiks: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Šis serveris sākās ar izpildlaika iestatījumiem. Rediģējiet tos zem ';

  @override
  String get runtimeSetupRequired => 'Nepieciešama izpildlaika iestatīšana';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Izpildlaika parakstīšanas publiskajai atslēgai jābūt 32 baitiem.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Saglabāt';

  @override
  String get saveATrelloApiKeyFor =>
      'Saglabājiet Trello API atslēgu šim aģentam un pēc tam droši pievienojiet vienu Trello kontu. Konta marķieris tiek glabāts serverī un tiek izmantots tikai šim aģentam.';

  @override
  String get saveAccount => 'Saglabāt kontu';

  @override
  String get saveChanges => 'Saglabāt izmaiņas';

  @override
  String get saveCloudComputerSettings =>
      'Saglabājiet mākoņa datora iestatījumus';

  @override
  String get saveConnect => 'Saglabāt un izveidot savienojumu';

  @override
  String get saveDefaults => 'Saglabāt noklusējuma iestatījumus';

  @override
  String get saveDiagnosticReport => 'Saglabājiet diagnostikas ziņojumu';

  @override
  String get saveEmail => 'Saglabāt e-pastu';

  @override
  String get saveEmailSettings => 'Saglabājiet e-pasta iestatījumus';

  @override
  String get saveGeneralSettings => 'Saglabājiet vispārīgos iestatījumus';

  @override
  String get saveName => 'Saglabāt nosaukumu';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Saglabājiet NeoAgent iestatīšanas diagnostiku';

  @override
  String get saveOnly => 'Tikai saglabāt';

  @override
  String get saveSetup => 'Saglabāt iestatījumus';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Saglabājiet šos atkopšanas kodus tūlīt. Tās vairs netiks rādītas.';

  @override
  String get savedDeliveryDestination => 'Saglabāts piegādes galamērķis';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Saglabātie likmes ierobežojumi @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Skenējiet NeoAgent pieteikšanās QR';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Skenējiet NeoAgent pārī savienoto QR no citas ierīces un apstipriniet to šajā palaišanas sesijā.';

  @override
  String get scanLoginQr => 'Skenēt pieteikšanās QR';

  @override
  String get scanPairingQr => 'Skenēt savienošanas pārī QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Skenējiet QR pieteikšanās pieprasījumus no ierīcēm, kurās esat izrakstījies, un apstipriniet tos no šīs autentificētās mobilās sesijas.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Skenējiet, lai pabeigtu $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Skenējiet ar NeoAgent savā tālrunī';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Skenē jaunos e-pasta ziņojumus un nosūta jums ping tikai tad, kad kaut kas ir svarīgs.';

  @override
  String get schedule => 'Grafiks';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'ieplānotais laiks. Kad skrējieni ir izmērīti, tie sāksies agrāk.';

  @override
  String scoreArg1(Object? arg1) {
    return 'Rezultāts: $arg1';
  }

  @override
  String get screen => 'Ekrāns';

  @override
  String get screenAction => 'ekrāna darbība';

  @override
  String get scrollIsNotSupportedOnThis =>
      'ritināšana šajā platformā netiek atbalstīta.';

  @override
  String get scrollToBottom => 'Ritiniet uz leju';

  @override
  String get search => 'Meklēt';

  @override
  String get search2 => 'Meklēt…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Meklēt administratora iestatījumus (piemēram, SMTP, Ollama, žurnāli)';

  @override
  String get searchAgain => 'Meklēt vēlreiz';

  @override
  String get searchByUsernameOrEmail => 'Meklēt pēc lietotājvārda vai e-pasta';

  @override
  String get searchChannels => 'Meklēt kanālus';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Meklējiet atklātos ziņojumapmaiņas kanālus, kontaktpersonas, grupas un jaunākās sarunas.';

  @override
  String get searchGroups => 'Meklēt grupas';

  @override
  String get searchMemory => 'Meklēt atmiņā';

  @override
  String get searchModelsOrProviders =>
      'Meklējiet modeļus vai pakalpojumu sniedzējus';

  @override
  String get searchModelsOrProviders2 =>
      'Meklēt modeļus vai pakalpojumu sniedzējus…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Meklēt jaunākos cilvēkus un grupas';

  @override
  String get searchSessions => 'Meklēšanas sesijas';

  @override
  String get searchSettings => 'Meklēšanas iestatījumi';

  @override
  String get searchTitleModelTriggerRunId =>
      'Meklējiet nosaukumu, modeli, aktivizētāju, palaišanas ID';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Meklēšanas rīki, integrācijas un prasmes';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Meklēts kods \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Meklēja failus \"$arg1\"';
  }

  @override
  String get secretField => 'Slepenais lauks';

  @override
  String get secureCookies => 'Droši sīkfaili';

  @override
  String get security => 'Drošība';

  @override
  String get securityKey => 'Drošības atslēga';

  @override
  String get securityKeyPromptWasDismissed =>
      'Drošības atslēgas uzvedne tika noraidīta.';

  @override
  String get securityKeySignInCompletedBut =>
      'Drošības atslēgas pierakstīšanās ir pabeigta, taču NeoAgent nevarēja saglabāt pārlūkprogrammas sesiju. Lūdzu, pierakstieties vēlreiz.';

  @override
  String get securityKeySignInCouldNot =>
      'Drošības atslēgas pierakstīšanos nevarēja sākt.';

  @override
  String get securityKeys => 'Drošības atslēgas';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Drošības atslēgas ir pieejamas tikai NeoAgent tīmekļa lietotnē.';

  @override
  String get seeAll => 'Skatīt visu';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Skatiet, kuru NeoAgent serveri izmanto šis logs, un palaidiet aizmugursistēmu šajā datorā.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'redzēt savu lietotājvārdu un šos iestatījumus, nevis savas tērzēšanas sarunas, atmiņas ';

  @override
  String get selectARun => 'Izvēlieties skrējienu';

  @override
  String get selectASessionToSeeIts =>
      'Atlasiet sesiju, lai skatītu tās datoru, failus un izmaiņas.';

  @override
  String get selectAll => 'Atlasiet visu';

  @override
  String get selectAll2 => 'Atlasiet visu';

  @override
  String selectArg1(Object? arg1) {
    return 'Izvēlieties $arg1';
  }

  @override
  String get selectTrigger => 'Atlasiet Trigger';

  @override
  String semanticArg1(Object? arg1) {
    return 'Semantika: $arg1';
  }

  @override
  String get send => 'Sūtīt (⌘↵)';

  @override
  String get send2 => 'Sūtīt';

  @override
  String get sendATaskFromChatAnd =>
      'Nosūtiet uzdevumu no tērzēšanas, un šeit tiks parādīta tā izpildes vēsture.';

  @override
  String get sendItToATeammateWith =>
      'nosūtīt to komandas biedram ar kontu šajā serverī.';

  @override
  String get sendLink => 'Nosūtīt saiti';

  @override
  String get sendPath => 'Sūtīt ceļu';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Nosūtiet POST / PUT / DELETE pieprasījumus ārējām API.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Nosūtiet šo saiti tikai tai personai, kurai tā ir paredzēta. Tas tiek parādīts vienu reizi; ';

  @override
  String get senderAddress => 'Sūtītāja adrese';

  @override
  String get senderFilterOptional => 'Sūtītāja filtrs (pēc izvēles)';

  @override
  String get sentSharedAttachments => 'Nosūtīti koplietotie pielikumi.';

  @override
  String get separateAccount => 'Atsevišķs konts';

  @override
  String get server => 'Serveris';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Servera noklusējuma ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Servera noklusējuma iestatījumi balss zvaniem lietotnē. Zvani notiek tiešraidē ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'pats serveris: konti, pakalpojumu sniedzēji un konfigurācija.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Serveris, segvārds, kanāls un izvēles TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'servera izvades konsoles brīdinājumu kļūdu kopija';

  @override
  String get serverProviderCredentials =>
      'Servera nodrošinātāja akreditācijas dati';

  @override
  String get serverUrl => 'Servera URL';

  @override
  String get serverUsageLimitsDonTApply =>
      'Servera lietošanas ierobežojumi neattiecas uz modeļiem, kas darbojas ar jūsu atslēgu.';

  @override
  String get serviceEmail => 'Pakalpojuma e-pasts';

  @override
  String get serviceEmailIsNotConfigured =>
      'pakalpojuma e-pasts nav konfigurēts';

  @override
  String get serviceEmailSmtp => 'Pakalpojuma e-pasts (SMTP)';

  @override
  String get sessionActions => 'Sesijas darbības';

  @override
  String get sessions => 'Sesijas';

  @override
  String get sessions2 => 'SESIJAS';

  @override
  String get sessionsArePinnedToAFolder =>
      'Sesijas tiek piespraustas mapei un datoram. Sāciet vienu, lai plānotu, izveidotu, pārbaudītu un nosūtītu no šejienes.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sesijas (VDAR 17. pants). Administratora kontus nevar izdzēst ';

  @override
  String get sessionsLogoutRevokeForce => 'sesijas atteikšanās atsaukt spēku';

  @override
  String get setBlockAskAllowPerTool =>
      'Iestatiet bloķēt/jautāt/atļaut katrai rīku kategorijai vai izvēlēties globālo režīmu.';

  @override
  String get setUpNeoagentOnThisComputer => 'Šajā datorā iestatiet NeoAgent';

  @override
  String get setUpOrConnectNeoagent => 'Iestatiet vai pievienojiet NeoAgent';

  @override
  String get setUrl => 'Iestatīt URL';

  @override
  String get settings => 'Iestatījumi';

  @override
  String get settingsAndCannotBeUndone => 'iestatījumus, un to nevar atsaukt.';

  @override
  String get settingsArea => 'Iestatījumu apgabals';

  @override
  String get settingsAreas => 'Iestatījumu apgabali';

  @override
  String get setup => 'Iestatīšana';

  @override
  String get setupDetails => 'Iestatīšanas informācija';

  @override
  String get setupRequired => 'Nepieciešama iestatīšana';

  @override
  String get setupWasCancelled => 'Iestatīšana tika atcelta.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Koplietotie pielikumi no NeoAgent klienta:';

  @override
  String get sharedFromAnotherApp => 'Kopīgots no citas lietotnes';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Koplietotās pakalpojumu sniedzēja atslēgas ir konfigurētas serverī. Lai tā vietā izmantotu savu API atslēgu vai pielāgotu galapunktu, atveriet sadaļu Papildu → Atnesiet savu atslēgu.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Kopīgots ar NeoAgent tērzēšanu un tās atmiņu.';

  @override
  String get shellCommands => 'Shell komandas';

  @override
  String showAllArg1(Object? arg1) {
    return 'Rādīt visu $arg1';
  }

  @override
  String get showEarlier => 'Rādīt agrāk';

  @override
  String get showEveryStep => 'Parādiet katru soli';

  @override
  String get showTools => 'Rādīt rīkus';

  @override
  String get showWorkbenchJ => 'Rādīt darbgaldu (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Tiek rādīts pirmais $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Parādīts sānjoslā. Atstājiet tukšu, lai izmantotu savu lietotājvārdu.';

  @override
  String get signIn => 'Pierakstīties';

  @override
  String get signInCompletedButNeoagentCould =>
      'Pierakstīšanās ir pabeigta, taču NeoAgent nevarēja saglabāt pārlūkprogrammas sesiju. Lūdzu, pierakstieties vēlreiz. Ja tas turpinās, pārbaudiet aizmugursistēmas sesijas sīkfailu iestatījumus.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Pierakstīšanās ir pabeigta, taču NeoAgent nevarēja saglabāt pārlūkprogrammas sesiju. Lūdzu, pierakstieties vēlreiz. Ja tas turpinās, aizmugursistēmas sesijas sīkfails, visticamāk, netiks saglabāts.';

  @override
  String get signInToThisNeoagentServer =>
      'Pirms QR koda skenēšanas, pierakstieties šajā NeoAgent serverī.';

  @override
  String get signInWithAHardwareKey =>
      'Pierakstieties ar aparatūras atslēgu vai paroli, nevis paroli. ';

  @override
  String get signInWithASecurityKey => 'Pierakstieties ar drošības atslēgu';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Pierakstieties ar $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Apstipriniet NeoAgent savā $arg1 kontā. Nav atslēgas, ko kopēt.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Gaidu $arg1. Pabeidziet savā pārlūkprogrammā.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Ielīmējiet $arg1 kodu';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Pēc NeoAgent apstiprināšanas $arg1 parādīja vienreizēju kodu. Ielīmējiet to šeit.';
  }

  @override
  String get signInCode => 'Pierakstīšanās kods';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Pierakstījies ar $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Pierakstīšanās neizdevās: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Pierakstieties ar to pašu e-pastu un galveno paroli, ko izmantojat pakalpojumā Bitwarden. Galvenā parole un divpakāpju kods tiek izmantoti tikai pierakstīšanai, un tie nekad netiek saglabāti vai nosūtīti AI.';

  @override
  String get signOut => 'Izrakstīties';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Visur izrakstīties @$arg1?';
  }

  @override
  String get signOutEverywhere => 'Izrakstieties visur';

  @override
  String get signalCliRestApiBridge => 'signāls-cli REST API tilts';

  @override
  String get signalCliServerUrl => 'signal-cli servera URL';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Parakstīts @$arg1 ārpus katras sesijas.';
  }

  @override
  String get signedInDevices => 'Pierakstītās ierīces';

  @override
  String get signedInWithin24Hours => 'Pierakstījies 24 stundu laikā';

  @override
  String get signingSecret => 'Paraksta noslēpums';

  @override
  String sinceArg1(Object? arg1) {
    return 'Kopš $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'kopš $arg1';
  }

  @override
  String get singleMessage => 'Viena ziņa';

  @override
  String get singleUse => 'Vienreizējai lietošanai';

  @override
  String get skill => 'Prasme';

  @override
  String get skillChanges => 'Prasmju izmaiņas';

  @override
  String get skillContent => 'Prasmju saturs';

  @override
  String get skills => 'Prasmes';

  @override
  String get skip => 'Izlaist';

  @override
  String get skipForNow => 'Pagaidām izlaist';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Izlaidiet šo uzdevumu, pirms tas izsauc modeli.';

  @override
  String get slackMessageReceived => 'Saņemta vāja ziņa';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Miega $arg1 sesijas';
  }

  @override
  String get smartSelector => 'viedais atlasītājs';

  @override
  String get smartSelector2 => 'Viedais atlasītājs';

  @override
  String get smartSelectorPool => 'Smart Selector Pool';

  @override
  String get smtpHost => 'SMTP resursdators';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp pasta sūtītāja parole tls apstiprinājuma paziņojumu atiestatīšana';

  @override
  String get smtpPassword => 'SMTP parole';

  @override
  String get smtpPort => 'SMTP ports';

  @override
  String get smtpPortMustBeAWhole =>
      'SMTP portam ir jābūt veselam skaitlim no 1 līdz 65535.';

  @override
  String get smtpUsername => 'SMTP lietotājvārds';

  @override
  String get soTheRunStartsThatMuch => 'tāpēc skrējiens sākas daudz agrāk.';

  @override
  String get socialBehaviorOff => 'Sociālā uzvedība izslēgta';

  @override
  String get socialIntelligence => 'sociālā inteliģence';

  @override
  String get socialIntelligence2 => 'Sociālā inteliģence';

  @override
  String get socialObservability => 'Sociālā novērojamība';

  @override
  String get socialReach => 'sociālā sasniedzamība';

  @override
  String get socialReach2 => 'Sociālā sasniedzamība';

  @override
  String get socialReach3 => 'Sociālā sasniedzamība';

  @override
  String get socialReachUpdated => 'Sociālā sasniedzamība ir atjaunināta.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Sociālo avotu aģenti var tieši lasīt, tostarp plūsmas, krātuves, Reddit, X, videoklipus un sīkfailu nodrošinātos tirgus datus.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Kaut kas nogāja greizi. Lūdzu, mēģiniet vēlreiz.';

  @override
  String get source => 'Avots';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Vietas vai tērzēšanas ID tiek izmantots, kad šis aģents sāk sarunu.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Kosmosa tīmekļa aizķeres un lietotņu atzvanīšanas atbalsts';

  @override
  String get speaking => 'Runājot';

  @override
  String get speechToSpeechModelUsingThe =>
      'runas-runas modeli, izmantojot OpenAI vai Google taustiņu ';

  @override
  String get speechToText => 'Runa pārveido tekstu';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Runa tekstā pārraksta balss piezīmes un diktātus. Automātiski tiek izmantots OpenAI, Gemini vai Deepgram, atkarībā no tā, kuram ir API atslēga. Balss atbildes modelis ir tērzēšanas modelis, kas atbild uz balss piezīmēm.';

  @override
  String get sqlConsole => 'SQL konsole';

  @override
  String get stable => 'Stabils';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable instalē jaunāko publicēto aizmugursistēmas laidienu.';

  @override
  String get stackTrace => 'kaudzes pēdas';

  @override
  String get standard => 'Standarta';

  @override
  String get standardView => 'Standarta skats';

  @override
  String get start => 'Sākt';

  @override
  String get startASessionToPlanOr =>
      'Sāciet sesiju, lai plānotu vai izveidotu ar NeoAgent.';

  @override
  String get startAndroid => 'Startējiet Android';

  @override
  String get startComputer => 'Startējiet datoru';

  @override
  String get startFullSetup => 'Sāciet pilnu iestatīšanu';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Sāciet iestatīšanu';

  @override
  String get startTalking => 'Sāciet runāt';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Vispirms palaidiet Android tālruni, pēc tam nometiet šeit .apk vai .apks failu.';

  @override
  String get startTheServerLaterFromThe =>
      'Sāciet serveri vēlāk no saraksta, kad konfigurācija ir saglabāta.';

  @override
  String get startWithARecommendedTask => 'Sāciet ar ieteicamo uzdevumu';

  @override
  String get startingAndroid => 'Android palaišana';

  @override
  String get startingYourComputer => 'Datora palaišana';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Sākas ar xoxb-. No jūsu Slack lietotnes akreditācijas datiem.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting Error: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistika darbojas marķieri lietotāju diagrammas panākumu līmenis';

  @override
  String get status => 'Statuss';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'statusa datu bāzes izpildlaika VM nodrošinātāji';

  @override
  String get statusIsNotLoadedYet => 'Statuss vēl nav ielādēts.';

  @override
  String get stayManagedByYou => 'pārvaldiet jūs.';

  @override
  String get stayOnTheCall => 'Saglabājiet zvanu';

  @override
  String get stayedQuiet => 'Palika kluss';

  @override
  String get steering => 'STURES';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'SOLIS $arg1 OF $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Soļi $arg1';
  }

  @override
  String get stop => 'Apturēt';

  @override
  String get stop2 => 'Apstāties (⌘.)';

  @override
  String get stopManaging => 'Beidziet pārvaldīt';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Vai pārtraukt $arg1 pārvaldību?';
  }

  @override
  String get stopRun => 'Beidz skriet';

  @override
  String get stopSpeaking => 'Beidz runāt';

  @override
  String get stoppedBeforeCompletion => 'Apturēts pirms pabeigšanas';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting Error: $arg1';
  }

  @override
  String get storage => 'Uzglabāšana';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'tiek glabāti šifrēti un izmantoti tikai jūsu pašu skrējieniem.';

  @override
  String get storedMetrics => 'Saglabātie rādītāji';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Saglabā tikai šajā serverī šifrēto Bitwarden sesijas atslēgu, lai savienojumi izdzīvotu pēc restartēšanas. Varat to bloķēt jebkurā laikā.';

  @override
  String get strong => 'Spēcīgs';

  @override
  String get strongPassword => 'Spēcīga parole.';

  @override
  String get subAgent => 'Apakšaģents';

  @override
  String get subagentUpdate => 'Subagent atjauninājums';

  @override
  String get subagentUpdate2 => 'Subagent atjauninājums.';

  @override
  String get successRate => 'Veiksmes rādītājs';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Ieteikumi: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Apkopojiet manu pēdējo skrējienu';

  @override
  String get supportUrl => 'Atbalsta URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Atbalstītie: rain_start, snow_start, wind_alert, Temperatūra_augstāk, Temperatūra_zemāk';

  @override
  String get switchAgent => 'Pārslēgt aģentu';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Simboliskas saites nav atļautas NeoAgent Workspace ceļos.';

  @override
  String get syncNow => 'Sinhronizēt tūlīt';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'Sistēmas konfidencialitātes iestatījumi';

  @override
  String get tableInfoUsers => 'Informācija par tabulu (lietotāji)';

  @override
  String get tagsOnly => 'Tikai atzīmes';

  @override
  String get tasks => 'Uzdevumi';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Uzdevumi tiek izpildīti atsevišķi un ziņo jums ar ';

  @override
  String get teach => 'Mācīt';

  @override
  String get teachingInProgress => 'Notiek mācības';

  @override
  String get team => 'Komanda';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Komandas saites nekad nevienu nepadara par servera administratoru. Administratori vada ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Komandas telpas, telpas, kanāli un dzīvās kopienas.';

  @override
  String get teamsMessageReceived => 'Komandas ziņojums saņemts';

  @override
  String get templates => 'Veidnes';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Pagaidu iestatīšanas faili tiks iztīrīti vēlāk.';

  @override
  String get tenantId => 'Īrnieka ID';

  @override
  String get testConnection => 'Pārbaudīt savienojumu';

  @override
  String get testConnection2 => 'Pārbaudīt savienojumu';

  @override
  String get textChat => 'Īsziņas un tērzēšana';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'kas pievienoja savu atslēgu, turpina to izmantot.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Šis e-pasts jau pieder esošam kontam. Vispirms pierakstieties un pēc tam saistiet Google no konta iestatījumiem.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Šis e-pasts jau ir saistīts ar citu kontu.';

  @override
  String get thatGoogleAccountIsAlreadyLinked =>
      'Šis Google konts jau ir saistīts ar citu NeoAgent kontu.';

  @override
  String get thatQrCodeIsNotA =>
      'Šis QR kods nav NeoAgent pieteikšanās pieprasījums.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Šis QR kods nav NeoAgent pieprasījums savienošanai pārī.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Šī drošības atslēga jau ir reģistrēta šajā kontā.';

  @override
  String get theAddress => 'Adrese';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Jūsu BlueBubbles servera adrese.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Adrese, ko cilvēki un OAuth pakalpojumu sniedzēji izmanto, lai sasniegtu ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Aģents nolasa jūsu pieminētos laikus un izpilda ieplānotos uzdevumus šajā laika joslā.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Aģents jautās pirms katra jutīga instrumenta, ';

  @override
  String get theAgentWillIgnoreThisSkill => 'Aģents ignorēs šo prasmi.';

  @override
  String get theAppCouldNotReachThis =>
      'Lietotne nevarēja sasniegt šo NeoAgent izvietošanu. Pārbaudiet tīkla savienojumu vai pārliecinieties, ka pakalpojuma URL ir pareizs.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Pārlūkprogramma bloķēja pieprasījumu $arg1 satura drošības politikas dēļ.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Pārlūkprogramma bloķēja nepieciešamo pieprasījumu satura drošības politikas dēļ.';

  @override
  String get theCloudWorkspace => 'mākoņa darbvieta';

  @override
  String get theComputerCouldNotStart => 'Dators nevarēja startēt';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Datoram ir nepieciešams vairāk brīvas vietas diskā NeoAgent resursdatorā. Atbrīvojiet vietu un pēc tam mēģiniet vēlreiz.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Datora izpildlaikam nepieciešams remonts. Palaidiet NeoAgent Doctor un pēc tam mēģiniet vēlreiz.';

  @override
  String get theConnectionTestFailed => 'Savienojuma pārbaude neizdevās.';

  @override
  String get theDesktopDidNotStart => 'Darbvirsma netika startēta';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Atklātais NeoAgent atgrieza nepilnīgus identitātes datus.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Atklātajā NeoAgent tiek izmantots neatbalstīts iestatīšanas protokols.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Atklātais pakalpojums nav NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Lejupielādētais NeoAgent izpildlaiks neizturēja verifikāciju.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Google tērzēšanas vietas tīmekļa aizķere, kurā šim aģentam vajadzētu izlikt ziņas.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Instalēšanas programma vairs nav pieejama.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Interaktīvā Linux darbvirsma ir pieejama tīmekļa lietotnē NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn => 'Ievads šajā ierīcē nav pieejams.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Jaunākais ir pieejams katrā kontā.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Pēdējais sinhronizācijas logs beidzās $arg1, un tajā netika atrasti jauni Health Connect ieraksti. Tālāk saglabātie dati tika iegūti no iepriekšējām sinhronizācijām.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Linux grafiskā sesija nedarbojas.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Tiešraides balss modelis neatbildēja. Mēģiniet vēlreiz.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Vietējā NeoAgent komanda tika aizvērta ar kodu $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Vietējai NeoAgent komandai iestājās noildze.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Vietējam NeoAgent izpildlaikam ir nepieciešams remonts.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Vietējam izpildlaikam ir nepieciešams remonts ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Vietējā lietotāja mājas direktorijs nav pieejams.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Pasta konts NeoAgent sūta reģistrēšanās apstiprinājumus, pierakstīšanos ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Galvenais aģents tiek izveidots automātiski, kad nepieciešams.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Šajā laidienā trūkst atbilstošā NeoAgent izpildlaika.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Visnozīmīgākais ienākošais tīmekļa aizķere, kurā šim aģentam vajadzētu izlikt ziņas.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Modeļi, kurus Smart Selector maršrutē starp automātiski.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'NeoAgent aizmugursistēmas lejupielāde neatbilda tās manifestam.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'NeoAgent aizmugursistēmas lejupielāde bija nepilnīga.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'NeoAgent aizmugursistēma šajā datorā neatbild portā ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'NeoAgent aizmugursistēmas izpildlaiku nevarēja lejupielādēt.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'NeoAgent aizmugursistēmai bija nepieciešams pārāk ilgs laiks, lai reaģētu uz $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'NeoAgent izvietošana uz nederīgiem akreditācijas datiem atbildēja ar HTTP 402, nevis parasto 401. Pārbaudiet apgrieztā starpniekservera, autentifikācijas vārtejas vai ar maksājumiem saistītos noteikumus šajā serverī.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'NeoAgent izvietošana atbildēja ar HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'NeoAgent izvietošana atbildēja ar HTTP 402. Pārbaudiet reversās starpniekservera, autentifikācijas vārtejas vai ar maksājumiem saistītos noteikumus šajā serverī.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'NeoAgent instance, ar kuru šī lietotne ir savienota.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'NeoAgent izlaišanas pakalpojums atgrieza nederīgus datus.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'NeoAgent izpildlaika artefakta metadati nav derīgi.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'NeoAgent izpildlaika manifests neizturēja paraksta pārbaudi.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'NeoAgent izpildlaika manifestā nav artefaktu.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'NeoAgent izpildlaika manifesta paraksts nav derīgs.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Parole, ko iestatījāt pakalpojumā BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Jūsu pārvaldītie cilvēki paliek kopā ar jums.';

  @override
  String get theProviderAnswers => 'sniedz pakalpojumu sniedzējs.';

  @override
  String get theQueryReturnedNoRows => 'Vaicājums neatgrieza nevienu rindu.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Pieprasītais darbvirsmas displejs nav pieejams.';

  @override
  String get theRest => 'pārējais.';

  @override
  String get theRestEndpointForYourSignal =>
      'REST galapunkts jūsu signāla klipa instancei.';

  @override
  String get theRunIsPausedUntilYou =>
      'Skrējiens tiek apturēts, līdz jūs atbildat.';

  @override
  String get theRunStartsAtTheScheduled => 'Skrējiens sākas paredzētajā laikā.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Izpildlaiks ir viegla Debian Linux darbvirsma ar Chromium, PCManFM, Mousepad, LXTerminal, Python, Git un standarta komandrindas rīkiem. Tās jaudu pārvalda NeoAgent resursdators.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Nevarēja sākt drošības atslēgas reģistrāciju.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'serveris saglabā tikai tā pirkstu nospiedumu.';

  @override
  String get theServerOnThisComputerIs => 'Serveris šajā datorā nedarbojas';

  @override
  String get theServerReportedNoHealthChecks =>
      'Serveris neziņoja par veselības pārbaudēm.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Signāla tālruņa numurs, ko izmanto šis robots.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Teams ienākošā tīmekļa aizķere, kurā šim aģentam ir jāpublicē ziņas.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Divu faktoru izaicinājums beidzās. Pierakstieties vēlreiz.';

  @override
  String get theTwoFactorCodeIsNot => 'Divfaktoru kods nav derīgs.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Verificēto izpildlaika pakotni nevarēja atzīmēt kā izpildāmu.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Verificētajā izpildlaika pakotnē trūkst nepieciešamo failu.';

  @override
  String get theWebAppCouldNotReach =>
      'Tīmekļa lietotne nevarēja sasniegt NeoAgent aizmugursistēmu.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Tīmekļa lietotne nevarēja sasniegt NeoAgent aizmugursistēmu vietnē $arg1. Pārbaudiet pārlūkprogrammas konsoli un apgrieztā starpniekservera/tīkla konfigurāciju.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'paši; servera operators vispirms noņem administratoru ar ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Šie kanāli klusē. Lai vēlreiz sazinātos ar viņiem, pievienojiet to sadaļā Kas var ziņot šai platformai.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Šie saraksti nav obligāti, ja vien iepriekš minētā sadaļa nav iestatīta kā tikai apstiprināta.';

  @override
  String get thesePeopleAnywhere => 'Šie cilvēki jebkurā vietā';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Šīs personas var ziņot $arg1 privātās tērzētavās un jebkurā grupā, ko viņi koplieto.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Šie cilvēki var nosūtīt ziņojumu $arg1 viens pret vienu. Tas neļauj viņiem runāt grupās.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Šīs personas var nosūtīt ziņojumu $arg1 tikai jūsu izvēlētajā grupā.';
  }

  @override
  String get thesePeopleInOneGroup => 'Šie cilvēki vienā grupā';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'šie slēdži, nekad jūsu tērzēšanas sarunas, atmiņas vai faili.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Šis konts atbloķēs NeoAgent šajā ierīcē.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Šis aģents var deleģēt jebkuram piemērotam saņēmējam aģentam.';

  @override
  String get thisAgentIsUsingAServer =>
      'Šis aģents izmanto servera pārvaldītu Trello API atslēgu. Tālāk ir jāautorizē tikai konta pilnvara.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Šai būvei nav atļauts sazināties ar šo NeoAgent izvietošanu.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Šis kods pieder citam NeoAgent serverim: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Šī darbvirsma ir savienota';

  @override
  String get thisDevice => 'Šī ierīce';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Šī ierīce: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Šī ierīce nevar reģistrēt drošības atslēgas. Atveriet NeoAgent pārlūkprogrammā, izmantojot HTTPS, lai to pievienotu.';

  @override
  String get thisDeviceUnavailable => 'Šī ierīce nav pieejama';

  @override
  String get thisFileHasNoContent => 'Šim failam nav satura.';

  @override
  String get thisGoogleAccountIsNotLinked =>
      'Šis Google konts vēl nav saistīts. Vispirms izmantojiet pakalpojumu sniedzēja reģistrāciju vai pierakstieties kā parasti un saistiet to no konta iestatījumiem.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Tas paslēpj \"$arg1\" no maršrutēšanas un atlases.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Šī integrācija pašlaik atbalsta vienu savienotu kontu katram aģentam. Atkārtoti atveriet iestatīšanu, lai to aizstātu.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Šī integrācija vairs nav pieejama.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Šis ievads ir paredzēts pilnekrāna ainavas atskaņošanai.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Šī ir pārvaldīta izvietošana. Tā operators izripo ';

  @override
  String get thisMayTakeAMoment => 'Tas var ilgt kādu brīdi.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Šis MCP serveris vairs nav konfigurēts.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Šī atmiņa tiks neatgriezeniski noņemta.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Šis NeoAgent būvējums nav konfigurēts, lai pārbaudītu aizmugursistēmas izpildlaikus.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Tas neatgriezeniski dzēsīs visus jūsu datus, un to nevar izdarīt ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Tādējādi tiek neatgriezeniski izdzēsts konts un viss tam piederošais: ';

  @override
  String get thisPersonAnywhere => 'Šī persona jebkurā vietā';

  @override
  String get thisPersonInOneGroup => 'Šī persona vienā grupā';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Šis QR pieteikšanās pieprasījums ir beidzies. Ģenerējiet jaunu kodu un mēģiniet vēlreiz.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'šis qr pieteikšanās pieprasījums ir beidzies';

  @override
  String get thisQrLoginRequestIsStill =>
      'Šis QR pieteikšanās pieprasījums joprojām gaida apstiprinājumu.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Šis QR pieteikšanās pieprasījums jau tika izmantots.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Tādējādi šim aģentam tiek noņemta Home Assistant iestatīšana un pievienotā instance.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Tādējādi šim aģentam tiek noņemts NeoRecall aizmugursistēmas URL un visi saistītie NeoRecall konti.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Tādējādi šim aģentam tiek noņemts Nextcloud URL un visi saistītie Nextcloud konti.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Tādējādi šim aģentam tiek noņemti Trello iestatījumi un saistītie konti.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Tam nepieciešama autentificēta sesija tajā pašā NeoAgent serverī.';

  @override
  String get thisRunDidNotProduceA =>
      'Šī izpilde neradīja lietotājam adresētu atbildi.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Šajā skrējienā nav ierakstītu soļu datu.';

  @override
  String get thisServer => 'šis serveris.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Šis serveris neziņo par pakalpojumu sniedzēja iestatījumiem.';

  @override
  String get thisSkillIsNoLongerInstalled => 'Šī prasme vairs nav instalēta.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Šis uzdevums vēl nav pabeigts, tāpēc tas joprojām sākas plkst ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Šis uzdevums darbosies tikai tad, kad nospiedīsit Palaist tūlīt.';

  @override
  String get thisWeek => 'Šonedēļ';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Tādējādi atbilde tiks importēta $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Tas noņems \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Tādējādi \"$arg1\" tiks noņemts no serveru saraksta.';
  }

  @override
  String get time => 'Laiks';

  @override
  String get timeZone => 'laika josla';

  @override
  String get timeZone2 => 'Laika josla';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Noildze $arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Nevarēja uzskaitīt laika joslas: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Nevarēja nolasīt ierīces laika joslu: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Nevarēja saglabāt ierīces laika joslu: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'uz $arg1';
  }

  @override
  String get toUseTheServerDefault =>
      'lai izmantotu servera noklusējuma iestatījumus.';

  @override
  String get today => 'Šodien';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Token budžets @$arg1. Atstājiet lauku tukšu ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Marķiera budžets katram kontam bez sava ignorēšanas. Atstājiet a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'marķiera budžeta ierobežojums 4 stundu nedēļas kvotas lietotājs';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'marķiera budžeta ierobežojums 4 stundu nedēļas kvota globālā līmenī';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Marķiera lietojums šajā servera versijā nav pieejams.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Jebkurš konts var izmantot marķieri 4 stundu laikā.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Jebkurš konts var izmantot marķieri 7 dienu laikā.';

  @override
  String get tokensPerDay => 'Žetoni dienā';

  @override
  String get tokensPerRun => 'Žetoni par skrējienu';

  @override
  String get tokensToday => 'Žetoni šodien';

  @override
  String get tokensUsed => ' izmantotie žetoni';

  @override
  String get tomorrowPrep => 'Rīt sagatavošanās';

  @override
  String get tooManyAttempts => 'pārāk daudz mēģinājumu';

  @override
  String get tooManySignInAttemptsPlease =>
      'Pārāk daudz pierakstīšanās mēģinājumu. Lūdzu, uzgaidiet un mēģiniet vēlreiz.';

  @override
  String get tool => 'Rīks';

  @override
  String get toolApproval => 'Instrumenta apstiprināšana';

  @override
  String get toolApprovalRequired => 'Nepieciešams instrumenta apstiprinājums';

  @override
  String get toolCompleted => 'Rīks ir pabeigts';

  @override
  String get toolFailed => 'Rīks neizdevās';

  @override
  String get toolPermissions => 'Rīka atļaujas';

  @override
  String get toolStarted => 'Rīks ir palaists';

  @override
  String get tools => 'Rīki';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Rīki, kas nav iebūvēti NeoAgent, tostarp saistītie MCP serveri un pielāgotu rīku nodrošinātāji.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Piedāvātie instrumenti ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Rīki, ko var izmantot pārvaldītais konts';

  @override
  String get topUsers => 'Populārākie lietotāji';

  @override
  String get topUsersAndRecentRuns =>
      'Populārākie lietotāji un jaunākie skrējieni';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Kopā: $arg1 marķieri $arg2 skrējienos';
  }

  @override
  String get totalRuns => 'Kopējie skrējieni';

  @override
  String get totalTokens => 'Kopējais žetonu skaits';

  @override
  String get totalUsers => 'Kopējais lietotāju skaits';

  @override
  String get transcript => 'Atšifrējums';

  @override
  String get transcript2 => 'TRANSKRĪTS';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transkripcija neizdevās: $arg1';
  }

  @override
  String get transfer => 'Pārsūtīšana';

  @override
  String get trelloApiKey => 'Trello API atslēga';

  @override
  String get trelloApiKeyIsRequired => 'Nepieciešama Trello API atslēga.';

  @override
  String get trelloSetup => 'Trello iestatīšana';

  @override
  String get triggerType => 'Trigera veids';

  @override
  String get tryABroaderSearchLikeModels =>
      'Izmēģiniet plašāku meklēšanu, piemēram, modeļus, pārlūkprogrammu vai balsi.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Izmēģiniet pakalpojumu sniedzēja nosaukumu, “e-pasts”, “limits”, “update” vai “logs”.';

  @override
  String get tryAgain => 'Mēģiniet vēlreiz';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Mēģiniet vēlreiz. Ja tas turpinās, palaidiet programmu NeoAgent Doctor, lai pārbaudītu datora izpildlaiku.';

  @override
  String get tryAgainInAMoment => 'Pēc brīža mēģiniet vēlreiz.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Mēģiniet vēlreiz vai palaidiet NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Izmēģiniet citu meklēšanu, pievienojiet ziņojumapmaiņas platformu vai manuāli ievadiet galamērķa ID.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Ieslēdziet grupu, ja $arg1 vajadzētu lasīt arī ziņojumus, kuros tā nav atzīmēta.';
  }

  @override
  String get turnOffComputer => 'Izslēdziet datoru';

  @override
  String get turnOffOnlyForAMail =>
      'Izslēgt tikai pasta serverim ar pašparakstītu sertifikātu.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Ieslēdziet, ja signālam vajadzētu turpināt meklēt ienākošās tērzēšanas sarunas.';

  @override
  String get turnTaking => 'savukārt ņemot';

  @override
  String get turnTakingModel => 'Pagriezienu modelis';

  @override
  String get turnTakingOff => 'Pagrieziena pacelšanās';

  @override
  String get turnThisOffToKeepThis =>
      'Izslēdziet to, lai šis aģents būtu pilnībā nošķirts no citiem aģentiem.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Izslēdza $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Izslēdza $arg1, kurš pārvalda šo kontu. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return '$arg1 to jums izslēdza — tikai viņi to var mainīt';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Jums ir izslēgts, tāpēc jūs nevarat to izsniegt';

  @override
  String get twitchChatOverIrc => 'Twitch tērzēšana, izmantojot IRC';

  @override
  String get twoFactorAuthentication => 'Divu faktoru autentifikācija';

  @override
  String get twoFactorChallengeExpired => 'divu faktoru izaicinājums beidzās';

  @override
  String get twoFactorCode => 'divu faktoru kods';

  @override
  String get twoFactorSignInCompletedBut =>
      'Divu faktoru pierakstīšanās ir pabeigta, taču NeoAgent nevarēja saglabāt pārlūkprogrammas sesiju. Lūdzu, pierakstieties vēlreiz.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Divpakāpju pieteikšanās (tikai tad, ja ir iespējota)';

  @override
  String get type => 'Tips';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Ievadiet $arg1, lai apstiprinātu';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'teksta veida teksts šajā platformā netiek atbalstīts.';

  @override
  String get typedInTheBrowser => 'Ierakstīts pārlūkprogrammā';

  @override
  String get typedText => 'Ierakstīts teksts';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime => 'nevar atrast Java izpildlaiku';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Šajā būvniecībā nevar atvērt laika iestatījumus.';

  @override
  String get unableToOpenWiFiSettings =>
      'Šajā būvniecībā nevar atvērt Wi-Fi iestatījumus.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Nevar saglabāt atlasīto darbvirsmas displeju.';

  @override
  String get unclearWhoItWasFor => 'Nav skaidrs, kam tas bija paredzēts';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'atsaukts. Ievadiet savu lietotājvārdu, lai apstiprinātu.';

  @override
  String get unknownAccount => 'Nezināms konts';

  @override
  String get unknownAgent => 'Nezināms aģents';

  @override
  String get unknownBrowser => 'Nezināma pārlūkprogramma';

  @override
  String get unknownDevice => 'Nezināma ierīce';

  @override
  String get unknownError => 'nezināma kļūda';

  @override
  String get unknownLocalComputerPermission =>
      'Nezināma vietējā datora atļauja.';

  @override
  String get unknownLocation => 'Nezināma atrašanās vieta';

  @override
  String get unknownPublishTime => 'Nezināms publicēšanas laiks';

  @override
  String get unknownSize => 'Nezināms izmērs';

  @override
  String get unlink => 'Atsaistīt';

  @override
  String get unreadOnly => 'Tikai nelasīts';

  @override
  String get unsavedChanges => 'Nesaglabātas izmaiņas';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Neatbalstīta darbvirsmas pavadošā komanda: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Neatbalstīta metode: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Neparasti pierakstīšanās brīdinājumi';

  @override
  String updateArg1(Object? arg1) {
    return 'Atjauniniet $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Atjauniniet galvenās atmiņas ierakstus no importēšanas.';

  @override
  String get updateNow => 'Atjauniniet tūlīt';

  @override
  String get updateReady => 'Atjauninājums gatavs';

  @override
  String get updateSetup => 'Atjauniniet iestatījumus';

  @override
  String get updateTheAccessListToAllow =>
      'Atjauniniet piekļuves sarakstu, lai atļautu atbildes.';

  @override
  String get updateTheServer => 'Vai atjaunināt serveri?';

  @override
  String get updateTheServer2 => 'Atjauniniet serveri';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Automātiski atjauniniet laika joslu no izmantotās ierīces.';

  @override
  String updatedArg1(Object? arg1) {
    return 'atjaunināts $arg1';
  }

  @override
  String get updates => 'Atjauninājumi';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Šim būvējumam atjauninājumi nav konfigurēti.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'atjauninājumus, tāpēc pašjaunināšana un kanālu izmaiņas šeit ir izslēgtas.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'jaunināšanas atjauninājums tagad izlaidiet kanāla stabilu beta versiju';

  @override
  String get usageAnalytics => 'Lietojuma analītika';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Lietošanas un veselības signāli, kas palīdz izskaidrot pašreizējo izpildlaika uzvedību, vispirms neizpētot žurnālus.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return '$arg1 lietojums tiek pilnībā atiestatīts';
  }

  @override
  String get usageLeaderboard => 'lietošanas līderu saraksts';

  @override
  String get usageLimits => 'Lietošana un ierobežojumi';

  @override
  String get usageLimits2 => 'Lietošana un ierobežojumi';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Izmantojiet 8+ rakstzīmes. Garākas ieejas frāzes darbojas labi.';

  @override
  String get useADateAndTimeFor =>
      'Izmantojiet datumu un laiku, piemēram, 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Izmantojiet vārdu, tālruņa numuru vai tērzēšanas ID.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Izmantojiet NeoRecall URL, ko var sasniegt NeoAgent serveris. Lai veiktu OAuth atzvanīšanu, no šīs pārlūkprogrammas ir jābūt sasniedzamam arī NeoAgent vietnei PUBLIC_URL.';

  @override
  String get useANewPasswordWithAt =>
      'Izmantojiet jaunu paroli, kurā ir vismaz 8 rakstzīmes.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Izmantojiet Nextcloud URL, ko NeoAgent serveris var sasniegt, piemēram, https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Izmantojiet paroli, kurā ir vismaz 8 rakstzīmes.';

  @override
  String get useASecureConnectionTls => 'Izmantojiet drošu savienojumu (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Izmantojiet autentifikācijas lietotni, piemēram, Authy, 1Password vai Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Izmantojiet vismaz 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Maksimālā atmiņa vienam datoram (MB)';

  @override
  String get maxVcpusPerComputer => 'Maksimālais vCPU vienam datoram';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Vismaz $arg1. Datori saņem mazāk, ja saimniekdators ir aizņemts.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Maksimālajai atmiņai jābūt vismaz $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Izmantojiet vismaz 8 rakstzīmes.';

  @override
  String get useDefault => 'Izmantot noklusējumu';

  @override
  String get useDefaultChannel => 'Izmantojiet noklusējuma kanālu';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Izmantot noklusējumu (NeoAgent Workspace)';

  @override
  String get useFor => 'Izmantot priekš';

  @override
  String get useManualDestination => 'Izmantojiet manuālo galamērķi';

  @override
  String get useOrDoTheSameFor =>
      'izmantojiet vai dariet to pašu saviem komandas biedriem.';

  @override
  String get usePerCategorySettingsBelow =>
      'Tālāk izmantojiet katras kategorijas iestatījumus.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Izmantot noklusējuma iestatījumus ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Izmantojiet serveri šajā datorā';

  @override
  String get useTheseForContextIfA =>
      'Izmantojiet tos kontekstam. Ja vietējais URI nav tieši pieejams no servera, lūdziet man nodrošināt failu, izmantojot pieejamu darbvietu.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Izmantojiet to orķestra aģentiem. Atstājiet to atsevišķiem darba robotiem, kuriem pašiem jāpabeidz tiešās ziņas.';

  @override
  String get useTlsFromTheStartOf =>
      'Izmantojiet TLS no savienojuma sākuma, parasti portā 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Izmantojiet savu API atslēgu pakalpojumu sniedzējam vai pievienojiet pielāgotu ';

  @override
  String get usedByEveryAccountOnThis =>
      'To izmanto katrs šī servera konts, kuram nav atslēgas ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Izmanto, lai pārbaudītu, vai ienākošie Slack notikumi ir patiesi.';

  @override
  String get userSummary => 'Lietotāja kopsavilkums';

  @override
  String get username => 'Lietotājvārds';

  @override
  String get usernameOrEmail => 'Lietotājvārds vai e-pasts';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'lietotāji cilvēki meklē e-pastā lietotājvārdu administratora emblēma pārvaldīta komanda';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Izmanto tērzēšanas modeli, kas konfigurēts sadaļā Iestatījumi';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Izmantojot instalēto NeoAgent izpildlaiku';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Parasti izskatās kā @bot:matrix.org';

  @override
  String get validEmail => 'derīgs e-pasts';

  @override
  String get value => 'Vērtība';

  @override
  String get vaultLocked => 'Velve aizslēgta';

  @override
  String get vaultOperationFailed => 'Vault darbība neizdevās.';

  @override
  String vectorRankArg1(Object? arg1) {
    return 'Vektora rangs: $arg1';
  }

  @override
  String get verification => 'Verifikācija';

  @override
  String verificationArg1(Object? arg1) {
    return 'Verifikācija: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'Verifikācija: $arg1';
  }

  @override
  String get verificationCompleted => 'Verifikācija pabeigta.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Verifikācijas statuss: $arg1';
  }

  @override
  String get verifiedTheResult => 'Pārbaudīja rezultātu';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Lejupielādētā izpildlaika pārbaude';

  @override
  String get versionAndUptime => 'Versija un darbības laiks';

  @override
  String versionArg1(Object? arg1) {
    return 'Versija $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Versija $arg1 ir instalēta, bet $arg2 joprojām darbojas.';
  }

  @override
  String get videoLinks => 'Video saites';

  @override
  String get viewDesktop => 'Skatīt darbvirsmu';

  @override
  String get viewLastRun => 'Skatīt pēdējo skrējienu';

  @override
  String get viewLogs => 'Skatīt žurnālus';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm attēla atmiņas CPU qemu izpildlaiks';

  @override
  String get voice => 'Balss';

  @override
  String get voiceAssistant => 'Balss palīgs';

  @override
  String get voiceCall => 'BALSS ZVANS';

  @override
  String get voiceCall2 => 'Balss zvans';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'balss zvans gpt-live gemini tiešraides modeļa runas reāllaikā';

  @override
  String get voiceCallsRunOnALive =>
      'Balss zvani tiek veikti, izmantojot tiešās runas-runas modeli ar tādu pašu personību, atmiņu un tērzēšanas vēsturi kā NeoAgent. Tā atbild uzreiz un nodod reālu darbu parastajam aģentam, kas turpina darboties fonā.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'balss piezīme runas transkripcijas API atslēga';

  @override
  String get voiceNotesAndDictation => 'Balss notis un diktāts';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Balss atskaņošana šajā ierīcē nav pieejama.';

  @override
  String get voiceReplyModel => 'Balss atbildes modelis';

  @override
  String get waitingForApproval => 'Gaida apstiprinājumu: ';

  @override
  String get waitingForCode => 'Gaida kodu';

  @override
  String get waitingForInput => 'Gaida ievadi';

  @override
  String get waitingForServerOrFlutterLog =>
      'Gaida servera vai Flutter žurnāla izvadi…';

  @override
  String get waitingForTaskEvents => 'Gaida uzdevumu notikumus...';

  @override
  String get waitingForYou => 'gaida tevi';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Vēlējos saņemt atbildi no $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Vēlas ar jums runāt · ${arg1}s';
  }

  @override
  String get weak => 'Vāja';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Laikapstākļi, kalendārs un prioritātes pirms dienas sākuma.';

  @override
  String get weatherEvent => 'Laikapstākļi';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'Web pārlūkprogramma';

  @override
  String get webSearchApiKey => 'tīmekļa meklēšanas API atslēga';

  @override
  String get webhookOrRestChannelPosting =>
      'Webhook vai REST kanāla publicēšana';

  @override
  String get webhookSecret => 'Web aizķeres noslēpums';

  @override
  String get webhookUrlCopied => 'Tīmekļa aizķeres URL ir nokopēts';

  @override
  String get weekdays => 'Darba dienas';

  @override
  String get weekdays0730 => 'Darba dienās · 07:30';

  @override
  String get weekdays1800 => 'Darba dienās · 18:00';

  @override
  String get weekly => 'Iknedēļas';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Nedēļas limits $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Nedēļas ierobežojums (žetoni)';

  @override
  String get weeklyReview => 'Iknedēļas apskats';

  @override
  String get weeklyUsage => 'Iknedēļas lietošana';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Svara $arg1 rekordi';
  }

  @override
  String get welcomeToNeoagent => 'Laipni lūdzam NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Laipni lūdzam\nNeoAgent';

  @override
  String get whatAreYouAdding => 'Ko jūs pievienojat?';

  @override
  String get whatIsOnTomorrow => 'Kas notiks rīt?';

  @override
  String get whatShouldNeoagentLearn => 'Kas NeoAgent būtu jāmācās?';

  @override
  String get whatShouldWeBuild => 'Kas mums jābūvē?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Jūsu un NeoAgent teiktais ir redzams šeit un tērzēšanā.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Saņemta WhatsApp personiskā ziņa';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Ja izvēlaties Tikai apstiprināts, tālāk pievienojiet personas vai grupas.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Kur šim aģentam būtu jāsūta atbildes.';

  @override
  String get whoCanMessage => 'Kas var ziņot';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Kas var ziņot $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Kas var nosūtīt $arg1 individuālu ziņojumu.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Kas var runāt ar $arg1 grupā, kanālā vai telpā.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'kurš pārvalda šo kontu ir izslēgts: ';

  @override
  String get whoManagesWhom => 'Kurš kuru pārvalda';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Ikviens, kurš pieņem saiti, pievienojas jūsu komandai, izmantojot tikai tās rīkus ';

  @override
  String get wholeGroup => 'Visa grupa';

  @override
  String get wholeGroups => 'Veselas grupas';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Kāpēc $arg1 atbildēja vai klusēja $arg2 grupās.';
  }

  @override
  String get windowsApp => 'Windows lietotne';

  @override
  String get windowsNt => 'logi nt';

  @override
  String get workAccount => 'Darba konts';

  @override
  String get workOnAProjectWithNeoagent =>
      'Strādājiet pie projekta ar NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Darbplūsma: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Darbs $arg1 mākoņdatorā. NeoAgent lasa un rediģē failus un var palaist komandas un pārlūkprogrammu.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Darbojas fonā: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Darbvietas konfigurācija un konta drošība vienuviet.';

  @override
  String get workspaceFiles => 'Darbvietas faili';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Darbvieta, modeļi un diagnostikas vadīklas.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Darbvietas ignorēšanai ir jābūt absolūtam ceļam.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Uzrakstīja $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttp pieprasījuma kļūda';

  @override
  String get yesterday => 'vakar';

  @override
  String get youAreInControl => 'Jūs kontrolējat';

  @override
  String get youCanFollowAlongOnThe => 'Varat sekot līdzi darbvirsmā.';

  @override
  String get youCanLeaveATeamAt =>
      'Jūs varat atstāt komandu jebkurā laikā; atkal tiek piemēroti jūsu iestatījumi.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Jūs varat iziet jebkurā laikā no komandas lapas.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Jūs izlemjat, kurus rīkus jūsu aģents drīkst izmantot, sadaļā Iestatījumi › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Jūs vēl nevienu nepārvaldāt. Tālāk izveidojiet uzaicinājuma saiti un ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Jums ir nesaglabāti iestatījumi. Ko jūs vēlētos darīt?';

  @override
  String get youReOnYourOwnYou =>
      'Jūs esat viens pats: jūs izlemjat, kādus rīkus jūsu aģents drīkst izmantot. Ja ';

  @override
  String get yourAccountAndUsageOnA =>
      'jūsu konts — un lietojums modelī, kas nodrošināts ar jūsu atslēgu ';

  @override
  String get yourAccountHasBeenDeleted => 'Jūsu konts ir izdzēsts.';

  @override
  String get yourAgentWillBeAllowed => 'Jūsu aģentam būs atļauts:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Jūsu lietotnes un faili ir saglabāti.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Jūsu lietotnes un faili paliek saglabāti.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Jūsu $arg1 atslēga';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Jūsu palīgslānis tveršanai, kontekstam un darbībai.';

  @override
  String get yourComputerIsAsleep => 'Jūsu dators ir miega režīmā';

  @override
  String get yourComputerIsOff => 'Jūsu dators ir izslēgts';

  @override
  String get yourComputerIsReady => 'Jūsu dators ir gatavs';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Jūsu pašreizējā parole nav pareiza.';

  @override
  String get yourData => 'Jūsu dati';

  @override
  String get yourDataExportWasCopiedTo =>
      'Jūsu datu eksportēšana tika kopēta starpliktuvē.';

  @override
  String get yourDesktopIsReady => 'Jūsu darbvirsma ir gatava';

  @override
  String get yourLinuxComputer => 'Jūsu Linux dators';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Jūsu atrašanās vieta nekad netiek nepārtraukti izsekota vai saglabāta mūsu serveros. Mēs to izmantojam tikai lokāli, lai pārbaudītu atbilstību jūsu aktīvajiem uzdevumiem.';

  @override
  String get yourManager => 'jūsu menedžeris';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Jūsu Mattermost vietnes URL, ja izmantojat REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Jūsu sesija beidzās vai pārlūkprogramma to nesaglabāja. Lūdzu, pierakstieties vēlreiz.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Jūsu sesija beidzās. Lūdzu, pierakstieties vēlreiz.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Jūsu lietotājvārds vai parole ir nepareiza.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Pārskats';

  @override
  String get sectionDiagnostics => 'Diagnostika';

  @override
  String get sectionVolume => 'Apjoms';

  @override
  String get sectionSession => 'Sesija';

  @override
  String get sectionDeliverable => 'Piegādājams';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Vietējais izpildlaiks vēl nav ierakstījis žurnālfailu.';

  @override
  String get thisComputer => 'Šis dators';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta instalē jaunāko pirmsizlaides aizmugursistēmu. Gaidiet raupjas malas.';

  @override
  String get copiedFinalResponse => 'Nokopēta galīgā atbilde';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Šeit tiek parādīta galīgā atbilde, kad skrējiens ir beidzies.';

  @override
  String get waitingForTheFirstStep => 'Gaidot pirmo soli…';

  @override
  String get loadingPrompt => 'Notiek uzvednes ielāde…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Šim skrējienam netika fiksēta galīgā atbilde.';

  @override
  String get readyToSignIn => 'Gatavs pierakstīties';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Pārslēdzieties uz “Noklusējums” vai “Vienmēr jautāt”, lai atkārtoti iespējotu apstiprinājuma pārbaudes.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Sūtīt vadības atjauninājumu vai nākamo piezīmi par pašreizējo skrējienu...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Nav tīkla savienojuma. NeoAgent atjaunos savienojumu, kad ierīce atkal būs tiešsaistē.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Pašreizējam braucienam tika lietots jaunākais stūrēšanas atjauninājums.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Notiek privātās balss sesijas sagatavošana…';

  @override
  String get preparingYourComputer => 'Datora sagatavošana';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent lejupielādē un sagatavo drošo Linux sistēmu. Tas notiek tikai pirmo reizi.';

  @override
  String get moreFreeSpaceIsNeeded => 'Nepieciešams vairāk brīvas vietas';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Atbrīvojiet vietu diskā NeoAgent resursdatorā un pēc tam mēģiniet vēlreiz. Jūsu esošie datora dati ir drošībā.';

  @override
  String get androidReady => 'Android gatavs';

  @override
  String get startingAndroid2 => 'Notiek Android palaišana…';

  @override
  String get androidStopped => 'Android apstājās';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Pirmajā palaišanas reizē tiek lejupielādēts Android SDK un sistēmas attēls, kas var ilgt vairākas minūtes.';

  @override
  String get androidIsStopped => 'Android ir apturēta';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Sāciet pārvaldīto Android vidi, kad tā ir nepieciešama.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Ļaujiet NeoAgent strādāt šajā datorā';

  @override
  String get firstTimeSetupIsInProgress => 'Notiek pirmā iestatīšana.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent var izmantot jūsu atļauto piekļuvi.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Atbrīvojiet daļu saimniekdatora krātuves un mēģiniet vēlreiz.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Sāciet, kad vēlaties, lai NeoAgent šeit palīdzētu.';

  @override
  String get systemPermissionMissing => 'Trūkst sistēmas atļaujas';

  @override
  String get connectingThisDevice => 'Šīs ierīces pievienošana';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Tiek izveidots drošs vietējais savienojums.';

  @override
  String get recordingYourDemonstration => 'Demonstrācijas ierakstīšana';

  @override
  String get noErrorsInTheRecentLog => 'Nesenajā žurnālā nav kļūdu.';

  @override
  String get loadingAccounts => 'Notiek kontu ielāde…';

  @override
  String get neverSignedIn => 'Nekad nav pierakstījies';

  @override
  String get emptyUsesTheServerDefault =>
      'Tukšs izmanto servera noklusējuma iestatījumus.';

  @override
  String get followTheSelectedSession => 'Sekojiet izvēlētajai sesijai';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Plānošanas režīms pārbauda tikai. Pārslēdzieties uz aģenta režīmu, lai ļautu NeoAgent rediģēt failus.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Nepieciešams, lai pievienotu vai mainītu konta e-pasta adresi.';

  @override
  String get confirmNewPassword => 'Apstipriniet jauno paroli';

  @override
  String get passwordChanged => 'Parole mainīta.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Šis pieprasījums jau ir izmantots.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Šis pieprasījums ir beidzies. Lūdziet otrai ierīcei ģenerēt jaunu kodu.';

  @override
  String get startQuickstart => 'Sāciet Quickstart';

  @override
  String get createYourAccount => 'Izveidojiet savu kontu';

  @override
  String get showWorkAsSummaries => 'Rādīt darbu kā kopsavilkumus';

  @override
  String get tokensUsedByTheLatestRun =>
      'Tokeni, kas izmantoti pēdējā palaišanā';

  @override
  String get listedTheWorkspaceRoot => 'Norādīja darbvietas sakni';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Oficiāla integrācija vēl nav pieejama.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Vēl nav konfigurēts neviens MCP serveris. Pievienojiet vienu, lai atklātu tā rīkus.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Lai sāktu, pievienojiet MCP serveri vai instalējiet prasmi.';

  @override
  String get setUp => 'Iestatīt';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Atstājiet tukšu, lai saglabātu saglabāto vērtību';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Tādējādi tiek noņemta katra šī servera konta adrese.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Vienkārši runājiet. Jūs varat pārtraukt jebkurā laikā. Pieskarieties, lai izslēgtu skaņu.';

  @override
  String get tapAgainWhenYouAreDone =>
      'Kad esat pabeidzis, pieskarieties vēlreiz.';

  @override
  String get workingOnATaskInTheBackground => 'Darbs pie uzdevuma fonā.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Runas pārvēršana runā ar tādu pašu atmiņu, rīkiem un tērzēšanas vēsturi kā NeoAgent.';

  @override
  String get checkLink => 'Pārbaudiet saiti';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Jūsu aģentam netiks atļauts neviens no kontrolētajiem rīkiem.';

  @override
  String get notYoursToChange => 'Jums nav jāmaina';

  @override
  String get setByYou => 'Jūsu iestatīts';

  @override
  String get noTools => 'Nav rīku';

  @override
  String get untitledLink => 'Saite bez nosaukuma';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Pārstāj darboties pēc tam, kad viena persona to izpērk.';

  @override
  String get theOperator => 'Operators';

  @override
  String get smartSelectorOn => 'Viedais atlasītājs ieslēgts';

  @override
  String get startASessionToBegin => 'Sāciet sesiju, lai sāktu';

  @override
  String get steerTheActiveRun => 'Vadi aktīvo skrējienu…';

  @override
  String get describeWhatToPlan => 'Aprakstiet, ko plānot…';

  @override
  String get stopDictation => 'Beidziet diktēt';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Ziņojumi vada pašreizējo palaišanu · ⌘↵ sūtīt · ⌘. stop';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Plānošanas režīms pārbauda tikai; nekas netiek mainīts, kamēr neieviesīsit · ⌘↵ nosūtīt';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Aģents rediģē darbvietu. Plānojiet tikai pārbaudes.';

  @override
  String get defaultModel => 'Noklusējuma modelis';

  @override
  String get openingScanner => 'Notiek skenera atvēršana...';

  @override
  String get theAgentCanUseThisSkill => 'Aģents var izmantot šo prasmi.';

  @override
  String get allSelected => 'Visi atlasīti';

  @override
  String get addCoreMemoryEntry => 'Pievienojiet galvenās atmiņas ierakstu';

  @override
  String get channelId => 'Kanāla ID';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'AI izveidotie un nenoteiktie uzdevumi izmanto pašreizējo noklusējuma iestatījumu.';

  @override
  String get waitingForRunEvents => 'Gaidām skriešanas pasākumus...';

  @override
  String get hideSteps => 'Slēpt soļus';

  @override
  String get commitTheActiveLiveCapture =>
      'Veiciet aktīvo tiešraides uzņemšanu';

  @override
  String get stopCaptureAndSubmit => 'Pārtrauciet uztveršanu un iesniedziet';

  @override
  String get clickTheMicToStartSpeaking =>
      'Noklikšķiniet uz mikrofona, lai sāktu runāt';

  @override
  String get connectACustomEndpoint => 'Pievienojiet pielāgotu galapunktu';

  @override
  String get hostedProvider => 'mitinātais pakalpojumu sniedzējs.';

  @override
  String get muted => ' • izslēgts';

  @override
  String get addWhoCanMessage => 'Pievienojiet, kas var ziņot';

  @override
  String get joinsGroupConversations => 'Pievienojas grupas sarunām';

  @override
  String get label1PersonOrGroupAdded => 'Pievienota 1 persona vai grupa';

  @override
  String get inProgress => 'Notiek';

  @override
  String get waitingForUpdateJobOutput => 'Gaida atjaunināšanas darba izvadi…';

  @override
  String get taskTrigger => 'Uzdevuma aktivizētājs';

  @override
  String get bearerToken => 'Uzrādītāja žetons';

  @override
  String get bearerToken2 => 'Uzrādītāja žetons';

  @override
  String get notRecorded => 'Nav ierakstīts';

  @override
  String get sessionCookie => 'Sesijas sīkfails';

  @override
  String get neverUsed => 'Nekad nav lietots';

  @override
  String get linkedRecently => 'Saistīts nesen';

  @override
  String get notUsedYet => 'Vēl nav lietots';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Vienam vai vairākiem kontiem ir beidzies derīguma termiņš. Atkārtoti izveidojiet savienojumu, lai atjaunotu piekļuvi. Ja tas turpinās, iespējams, jūsu Google Cloud OAuth lietotne ir testēšanas režīmā — publicējiet to Google mākoņkonsoles sadaļā Production, lai iegūtu ilgstošus marķierus.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault ir pievienots un pieejams pēc restartēšanas';

  @override
  String get vaultConnectedForThisSession => 'Vault ir pievienots šai sesijai';

  @override
  String get connectAnotherAccount => 'Pievienojiet citu kontu';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Ielīmējiet aizstājēju Ilgmūžīgas piekļuves marķieri';

  @override
  String get updateInstance => 'Atjaunināt gadījumu';

  @override
  String get pasteAReplacementToken => 'Ielīmējiet aizstājēju marķieri';

  @override
  String get replaceAccount => 'Aizstāt kontu';

  @override
  String get addAccount => 'Pievienot kontu';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Var deleģēt jebkuram saņēmējam aģentam';

  @override
  String get canReceiveDelegatedTasks2 => 'var saņemt deleģētos uzdevumus';

  @override
  String get noSyncYet => 'Vēl nav sinhronizācijas';

  @override
  String get noNewData => 'Nav jaunu datu';

  @override
  String get syncOnceToSeedYourBackend =>
      'Sinhronizējiet vienreiz, lai sāktu savu aizmugursistēmu.';

  @override
  String get lastWindowEndIsUnknown => 'Pēdējais loga gals nav zināms.';

  @override
  String get lastNonEmptySync => 'Pēdējā sinhronizācija, kas nav tukša';

  @override
  String get stopTranscribe => 'Apturēt un pārrakstīt';

  @override
  String get steeringMode => 'Stūres režīms';

  @override
  String get noMessageText => 'Nav ziņojuma teksta';

  @override
  String get reconnectingToServer =>
      'Notiek atkārtota savienojuma izveide ar serveri…';

  @override
  String get signingIn => 'Notiek pierakstīšanās...';

  @override
  String get noGroupsFoundYet => 'Vēl nav atrasta neviena grupa';

  @override
  String get onForNewGroupsOnly => 'Ieslēgts tikai jaunām grupām';

  @override
  String get noGroupsInThisCategory => 'Šajā kategorijā nav grupu';

  @override
  String get groupOrChannel => 'Grupa vai kanāls';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Piezīmes, kuras rakstāt sev, sāk skrējienu, un atbildes nonāk tajā pašā tērzēšanā. Atļaušanas saraksts šeit neattiecas.';

  @override
  String get needToReply => 'Vajag atbildēt';

  @override
  String get enter2faCode => 'Ievadiet 2FA kodu';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Atveriet savu autentifikācijas lietotni un ievadiet pašreizējo NeoAgent kodu.';

  @override
  String get alreadyHaveAnAccountSignIn =>
      'Vai jums jau ir konts? Pierakstīties';

  @override
  String get serverOnThisComputer => 'Serveris šajā datorā';

  @override
  String get showQrCode => 'Rādīt QR kodu';

  @override
  String get createAnotherNeoagentAccount => 'Izveidojiet citu NeoAgent kontu.';

  @override
  String get canCoordinateDelegatedWork => 'Var koordinēt deleģēto darbu';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'NeoAgent izpildlaika arhīvu nevarēja izvilkt.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'NeoAgent izpildlaika arhīvu nevarēja nolasīt.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'NeoAgent izpildlaika arhīvā ir nedrošs ceļš.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'NeoAgent izpildlaika arhīvā ir nedroša saite.';

  @override
  String get installingAppPackageOnThePhone =>
      'Notiek lietotņu pakotnes instalēšana tālrunī...';

  @override
  String get dragAndDropAApkOrApks =>
      'Velciet un nometiet .apk vai .apks failu šeit vai noklikšķiniet, lai pārlūkotu.';

  @override
  String get releaseToInstallThisPackage =>
      'Atlaidiet, lai instalētu šo pakotni';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Drošības atslēgu nevarēja izmantot.';

  @override
  String get connecting => 'Notiek savienojuma izveide…';

  @override
  String get changes => 'Izmaiņas';

  @override
  String get runtimeReady => 'Izpildes laiks gatavs';

  @override
  String get saving => 'Notiek saglabāšana...';

  @override
  String get earlier => 'Agrāk';

  @override
  String get monthJan => 'janvāris';

  @override
  String get monthFeb => 'febr';

  @override
  String get monthMar => 'marts';

  @override
  String get monthApr => 'apr';

  @override
  String get monthMay => 'maijā';

  @override
  String get monthJun => 'jūnijs';

  @override
  String get monthJul => 'jūl';

  @override
  String get monthAug => 'augusts';

  @override
  String get monthSep => 'sept';

  @override
  String get monthOct => 'okt';

  @override
  String get monthNov => 'nov';

  @override
  String get monthDec => 'decembris';

  @override
  String get steeringWord => 'Stūrēšana';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Tādējādi aizmugursistēma tiek pārslēgta no kanāla $arg1 uz kanālu $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Importēti sīkfaili $arg1';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'Pirms ${arg1}s';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Rindas stūres iekārta: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Tīmekļa lietotne nevarēja sasniegt NeoAgent aizmugursistēmu.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Pārlūkprogramma bloķēja nepieciešamo pieprasījumu satura drošības politikas dēļ.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 no 4 atļauts';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Veiciet uzdevumu kā parasti.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Izmaiņas · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Šī ierīce · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Sasniegts ierobežojums$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return '$arg1 atkopšanas kodi joprojām ir pieejami.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Drošības atslēga $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Pašreizējā sesija';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nPēdējoreiz lietots: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Darbs šajā ierīcē $arg1. NeoAgent tieši lasa un rediģē mapi un var palaist komandas, atvērt programmas un izmantot ekrānu.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Strādāja $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Atļāva $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1 uzaicinājuma saites no $arg2 tika atsauktas';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Pievienojiet personas un grupas, ar kurām $arg1 vajadzētu runāt';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Pievienojiet personas un grupas, ar kurām $arg1 drīkst runāt.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Kur klausās $arg1';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 skatās šīs vietas pieminēšanai. Ikviens var izlikt ziņas šeit, tāpēc tālāk norādītajiem lietotājiem joprojām ir nepieciešams viņu pašu apstiprinājums.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Šie cilvēki var jautāt $arg1 jebkurā vietā, kur to atzīmē. Lomas tiek skaitītas tikai iepriekš norādītajās vietās.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Tikai tad, ja ir atzīmēts $arg1';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Ieslēgts visām $arg1 grupām';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 joprojām dzird tikai personas un grupas, kuras jau esat apstiprinājis. Tas tikai ļauj $arg1 pievienoties parastajai tērzēšanai, ne tikai atzīmēm un atbildēm.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 joprojām dzird tikai personas un grupas, kuras jau esat apstiprinājis. Tas tikai izvēlas, kurai no šīm grupām tai pievienoties.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Ja kāds atzīmē $arg1 vai atbild, $arg1 vienmēr atbild. Ieslēdziet šo opciju, ja $arg1 vajadzētu piezvanīt arī parastajā grupas tērzēšanā.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Jaunās grupas ļaus $arg1 pievienoties parastai tērzēšanai ar apstiprinātām personām, līdz tās izslēgsiet.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Jaunās grupas ļaus $arg1 pievienoties parastajai tērzēšanai, līdz tās izslēgsiet.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Jaunās grupas paliek klusas, ja vien apstiprināta persona neatzīmē $arg1, līdz tās ieslēdzat.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Tikai tad, ja apstiprināta persona atzīmē $arg1, ja vien neieslēdzat grupu';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Tikai tad, kad $arg1 ir atzīmēts, ja vien neieslēdzat grupu';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 no $arg2 grupām pievienojas parastai tērzēšanai ar apstiprinātiem cilvēkiem';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Tas neapstiprina jaunus cilvēkus. Atzīmes un apstiprināto personu atbildes vienmēr saņem atbildi. Ieslēdziet grupu, ja $arg1 ir jāpievienojas arī parastajai tērzēšanai.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Tas neapstiprina jaunus cilvēkus. Ieslēdziet grupu, ja $arg1 jāpievienojas parastai tērzēšanai ar personām, kuras jau esat apstiprinājis.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Atzīmes un atbildes vienmēr saņem atbildi. Ieslēdziet grupu, ja $arg1 ir jāpievienojas arī parastajai tērzēšanai.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 pievienojas parastai tērzēšanai ar apstiprinātiem cilvēkiem';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 var pievienoties parastai tērzēšanai';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 atbild tikai tad, kad apstiprināta persona to atzīmē';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Nekas papildus nav vajadzīgs. Izveidojiet savienojumu, lai sāktu lietot $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Atsvaidzina ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Reģistrējieties ar $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Nav atmiņas, kas saistītas ar \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (noklusējums)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Filiāle: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 pievienojas tikai tām grupām un kanāliem, ko pievienojat tālāk.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 ir nepieciešams, lai atrastu NeoAgent izpildlaika datus.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[saīsināts priekšskatījums, kopā $arg1 baiti]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefakts ierobežots, $arg1 baiti kopā]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' $arg1';
  }

  @override
  String get worldNews => 'Pasaules ziņas';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Palaist, kad parādās jauni pasaules virsraksti. Jūsu uzvedne izlemj, vai jums paziņot.';

  @override
  String get newsKeywordsOptional => 'Atslēgvārdi (neobligāti)';

  @override
  String get worldNewsSetup => 'Pasaules ziņu iestatīšana';

  @override
  String get connectWorldNewsWithGnews =>
      'Pievienojiet GNews API atslēgu (bezmaksas plāns pieejams vietnē gnews.io). Tas tiek glabāts šifrēts un izmantots, lai aptaujātu populārākos virsrakstus par World News aktivizētājiem.';

  @override
  String get gnewsApiKey => 'GNews API atslēga';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Ielīmējiet nomaiņas GNews API atslēgu';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Atstājiet atslēgu tukšu, lai saglabātu pašlaik saglabāto atslēgu.';

  @override
  String get gnewsApiKeyIsRequired => 'Nepieciešama GNews API atslēga.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Nevarēja saglabāt World News iestatījumu.';

  @override
  String get disconnectWorldNews => 'Atvienojiet World News';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Tādējādi tiek noņemta saglabātā GNews API atslēga. Pasaules ziņu aktivizētāji pārtrauks darboties, līdz atkal pievienosit atslēgu.';

  @override
  String get couldNotDisconnectWorldNews => 'Nevarēja atvienot World News.';

  @override
  String get systemOneModels => 'SystemOne modeļi';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Izvēlas labāko pieejamo SystemOne modeli';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Tērzēšanas modelis pieņem šos lēmumus';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Lēmumu modeļi, kas veic aizkulišu zvanus sekundes daļā: grupas tērzēšanas pagriezieni un pārlūkprogrammas darbības. Jūsu tērzēšanas modelis joprojām raksta katru atbildi.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'SystemOne modelis izlemj, kad runāt, kamēr tas ir ieslēgts; šis modelis ir rezerves variants.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 ieguva SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne tieši novērtēja šo ziņojumu. Netika izmantots neviens valodas modelis.';

  @override
  String get systemOneUnavailable => 'SystemOne nav pieejama';

  @override
  String get systemOneAdminAvailability =>
      'Lēmumu modeļu aģenti var izvēlēties sadaļā Iestatījumi › Modeļi. Šeit izslēgts modelis atstāj šo atlasītāju, un aģenti, kas to izvēlējās, atgriežas pie Automātiskā režīma. Kamēr jebkurš modelis ir izslēgts, tiek izslēgti arī SystemOne modeļi, kurus pakalpojumu sniedzēji pievieno vēlāk.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Vēl nav neviena SystemOne modeļa. Sadaļā Providers pievienojiet atslēgu TypeSafe vai OpenRouter vai izvelciet lēmumu pieņemšanas modeli, piemēram, nimble Ollama 0.35 vai jaunākā versijā.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Neviens SystemOne modelis vēl nav pieejams. Pievienojiet TypeSafe vai OpenRouter atslēgu sadaļā Iestatījumi › Modeļi › Atnesiet savu atslēgu vai izvelciet lēmumu pieņemšanas modeli, piemēram, nimble in Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone sistēma viena lēmuma modeļi jev typesafe openrouter ollama pieejamība iespējot atspējot';

  @override
  String get chatModels => 'Tērzēšanas modeļi';

  @override
  String get disabled => 'Atspējots';

  @override
  String get enableShown => 'Iespējot parādīto';

  @override
  String get disableShown => 'Parādīts atspējots';

  @override
  String get expandAll => 'Izvērst visu';

  @override
  String get collapseAll => 'Sakļaut visu';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 nesaglabātās izmaiņas';
  }

  @override
  String get settingsScopeAllAgents => 'Visi aģenti';

  @override
  String get settingsScopeAgent => 'Šis aģents';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint => 'Tas pats visur, kur pierakstāties';

  @override
  String get settingsScopeAllAgentsHint => 'Kopīgojuši visi jūsu aģenti';

  @override
  String get settingsAppliesTo => 'Attiecas uz';

  @override
  String get settingsSaving => 'Notiek saglabāšana…';

  @override
  String get settingsSavedAutomatically =>
      'Izmaiņas tiek saglabātas automātiski';

  @override
  String get settingsSearchHint => 'Meklēt visus iestatījumus';

  @override
  String get settingsPageProfile => 'Profils';

  @override
  String get settingsPageSecurity => 'Pierakstīšanās un drošība';

  @override
  String get settingsPageUsage => 'Lietošana';

  @override
  String get settingsPagePermissions => 'Atļaujas';

  @override
  String get settingsPageComputer => 'Dators un tīmeklis';

  @override
  String get settingsPageBehavior => 'Uzvedība';

  @override
  String get settingsPageSystem => 'Sistēma';

  @override
  String get settingsPageProfileDescription =>
      'Jūsu vārds un e-pasts, jūsu datu kopija un izrakstīšanās.';

  @override
  String get settingsPageSecurityDescription =>
      'Parole, divu faktoru autentifikācija, drošības atslēgas un vieta, kur esat pierakstījies.';

  @override
  String get settingsPageUsageDescription =>
      'Jūsu ierobežojumi un pilnvaru tēriņi — viss vienuviet.';

  @override
  String get settingsPageAgentsDescription =>
      'Izveidojiet aģentus un izvēlieties, kurš no tiem atbild pēc noklusējuma.';

  @override
  String get settingsPagePermissionsDescription =>
      'Ko jūsu aģenti var darīt, jums iepriekš nejautājot.';

  @override
  String get settingsPageComputerDescription =>
      'Dators, kurā strādā jūsu aģenti, un vietnes, kuras viņi var lasīt kā jūs.';

  @override
  String get settingsPageModelsDescription =>
      'Kādus modeļus šis aģents izmanto, un API atslēgas, kas par tiem maksā.';

  @override
  String get settingsPageBehaviorDescription =>
      'Kā šis aģents runā un kā tas lasa grupas tērzēšanu.';

  @override
  String get settingsPageVoiceDescription =>
      'Tiešraides zvani, diktēšana un mutiskas atbildes šim aģentam.';

  @override
  String get settingsPageMessagingDescription =>
      'Kur cilvēki var sasniegt šo aģentu un kā tas darbojas tērzēšanā.';

  @override
  String get settingsPageGeneralDescription =>
      'Izskats, valoda, laika josla un šīs lietotnes darbība fonā.';

  @override
  String get settingsPageSystemDescription =>
      'Serveris, ko izmanto šis logs, serveris, kas atrodas šajā datorā, un lietotņu atjauninājumi.';

  @override
  String get settingsYourAgents => 'Jūsu aģenti';

  @override
  String get settingsChatModel => 'Tērzēšanas modelis';

  @override
  String get settingsChatModelDescription => 'Atbild uz jūsu ziņām.';

  @override
  String get settingsSubAgentModel => 'Apakšaģenta modelis';

  @override
  String get settingsSubAgentModelDescription =>
      'Veic uzdevuma laikā nodoto darbu.';

  @override
  String get settingsDefaultModels => 'Noklusējuma modeļi';

  @override
  String get settingsDefaultModelsDescription =>
      'Izmanto ikreiz, kad tērzēšanai vai uzdevumam nav izvēlēts savs modelis.';

  @override
  String get settingsModelPool => 'Modeļa baseins';

  @override
  String get settingsApiKeysDescription =>
      'Šim aģentam izmantojiet savas atslēgas vai galapunktu. Atslēgas ir šifrētas un nekad vairs netiek rādītas.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Precīza regulēšana';

  @override
  String get settingsFineTuningDescription =>
      'Reti vajag. Noklusējuma iestatījumi ir piemēroti lielākajai daļai tērzēšanas sarunu.';

  @override
  String get settingsShow => 'Rādīt';

  @override
  String get settingsHide => 'Slēpt';

  @override
  String get settingsMinimumContribution => 'Minimālā iemaksas vērtība';

  @override
  String get settingsBatchWindow => 'Telpas paketes logs';

  @override
  String get settingsBatchWindowDescription =>
      'Tik ilgi jāgaida, lai ātros ziņojumus uztvertu kā vienu pagriezienu.';

  @override
  String get settingsHandsFree => 'Brīvroku režīms';

  @override
  String get settingsHandsFreeDescription =>
      'Runājiet brīvi un pārtrauciet jebkurā laikā.';

  @override
  String get settingsPushToTalkDescription =>
      'Turiet, lai runātu, atlaidiet, lai nosūtītu.';

  @override
  String get settingsLiveVoice => 'Dzīvā balss';

  @override
  String get settingsChannels => 'Kanāli';

  @override
  String get settingsGroupChats => 'Grupas tērzēšanas sarunās';

  @override
  String get settingsGroupChatsDescription =>
      'Kā šis aģents darbojas grupās katrā kanālā.';

  @override
  String get settingsGroupChatsDisabled =>
      'Lai tos mainītu, sadaļā Uzvedība ieslēdziet uzvedības moduļus.';

  @override
  String get settingsParticipationAutomatic => 'Automātiski';

  @override
  String get settingsParticipationMentionOnly => 'Tikai pieminēt';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Izlasa telpu un pievienojas, kad tai ir kaut kas noderīgs, ko pievienot.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Atbild tikai tad, kad tiek minēts vai atbildēts.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Atbild uz katru ziņojumu.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Sadala garākas atbildes īsziņās, kā to darītu persona.';

  @override
  String get settingsDeliverySingleDescription =>
      'Katru atbildi nosūta kā vienu ziņojumu.';

  @override
  String get settingsComputerStatus => 'Statuss';

  @override
  String get settingsTest => 'Pārbaude';

  @override
  String get settingsAppearance => 'Izskats';

  @override
  String get settingsTheme => 'Tēma';

  @override
  String get settingsThemeSystem => 'Sistēma';

  @override
  String get settingsThemeLight => 'Gaišs';

  @override
  String get settingsThemeDark => 'Tumšs';

  @override
  String get settingsCloseWindow => 'Kad aizverat logu';

  @override
  String get settingsCloseAsk => 'Jautājiet';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent turpina darboties fonā un ir sasniedzams.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent pilnībā izslēdzas.';

  @override
  String get settingsPhoneTriggers => 'Tālruņa aktivizētāji';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signāli, ko šis tālrunis sūta jūsu aģentiem, lai uzdevumi varētu uz tiem reaģēt.';

  @override
  String get settingsLocationTriggers => 'Atrašanās vietas aktivizētāji';

  @override
  String get settingsLocationTriggersDescription =>
      'Ik pēc dažām minūtēm pārbauda jūsu aptuveno atrašanās vietu salīdzinājumā ar vietām, kuras skatās jūsu uzdevumi.';

  @override
  String get settingsNotificationTriggers => 'Paziņojumu aktivizētāji';

  @override
  String get settingsNotificationTriggersDescription =>
      'Pārsūta paziņojumus no citām šī tālruņa lietotnēm jūsu aģentiem.';

  @override
  String get settingsSetup => 'Iestatīšana';

  @override
  String get settingsOnboarding => 'Uzņemšana';

  @override
  String get settingsOnboardingDescription =>
      'Vēlreiz veiciet pirmās darbības iestatīšanu. Nekas, ko iestatījāt, netiek zaudēts.';

  @override
  String get settingsUsernameDescription =>
      'Izmantota, lai pierakstītos. To nevar mainīt.';

  @override
  String get settingsExport => 'Eksportēt';

  @override
  String get settingsLeave => 'Izrakstieties un dzēsiet';

  @override
  String get settingsSignOutDescription => 'Izraksta jūs tikai šajā ierīcē.';

  @override
  String get settingsDeleteAccountDescription =>
      'Dzēš jūsu kontu, aģentus, atmiņu un iestatījumus. Šo darbību nevar atsaukt.';

  @override
  String get settingsTokenUsage => 'Token izmantošana';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Neviens iestatījums neatbilst “$query”.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rezultāti',
      one: '$count rezultāts',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Papildu modeļa iestatījumi';

  @override
  String get settingsAdvancedModelsDescription =>
      'Pēc izvēles. Piespraust modeli viena veida darbam; tas pārņem ikreiz, kad aģents izmanto šos rīkus. Viss, kas atstāts pēc noklusējuma, atbilst tērzēšanas modelim.';

  @override
  String get settingsTaskModelDefault => 'Noklusējums';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Sekojiet tērzēšanas modelim';

  @override
  String get settingsTaskModelCoding => 'Kodēšana';

  @override
  String get settingsTaskModelCodingDescription =>
      'Koda rakstīšana, rediģēšana un atkļūdošana.';

  @override
  String get settingsTaskModelComputerUse => 'Datora lietošana';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Pārlūkprogrammas un darbvirsmas vadīšana.';

  @override
  String get settingsTaskModelAndroidUse => 'Android lietošana';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Lietotņu darbība Android ierīcē vai emulatorā.';

  @override
  String get settingsTaskModelResearch => 'Pētījumi';

  @override
  String get settingsTaskModelResearchDescription =>
      'Avotu meklēšana, lasīšana un apkopošana.';

  @override
  String get knowledgeGraphHint =>
      'Jūsu visbiežāk pieminētās entītijas, kas iekrāsotas pēc kopas. Līnijas savieno entītijas, kas parādās tajās pašās atmiņās. Pieskarieties vienam, lai redzētu tās saites un atmiņas; velciet, lai panoramētu, savelciet vai Ctrl/⌘ - ritiniet, lai tuvinātu.';

  @override
  String get linkedEntities => 'Saistītās entītijas';

  @override
  String get noLinkedEntities => 'Vēl nav saistīts ar citām entītijām.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 min';
  }

  @override
  String get entityKindConcept => 'Koncepcija';

  @override
  String get entityKindDomain => 'Domēns';

  @override
  String get entityKindEmail => 'E-pasts';

  @override
  String get entityKindLink => 'Saite';

  @override
  String get entityKindFile => 'Fails';

  @override
  String get entityKindAcronym => 'Akronīms';

  @override
  String get entityKindIdentifier => 'Identifikators';

  @override
  String get entityKindVersion => 'Versija';

  @override
  String get openFullscreen => 'Atvērt pilnekrāna režīmu';

  @override
  String get zoomIn => 'Pietuvināt';

  @override
  String get zoomOut => 'Tālināt';

  @override
  String get searchEntities => 'Atrodiet entītiju';

  @override
  String get incomingCall => 'Ienākošais zvans';

  @override
  String get answerCall => 'Atbilde';

  @override
  String get callMeLater => 'Zvaniet man vēlāk';

  @override
  String get callingEllipsis => 'Zvana…';

  @override
  String get reconnectingCall => 'Notiek savienojuma atjaunošana';

  @override
  String get agentWorking => 'Darbojas';

  @override
  String get micMuted => 'Izslēgts';

  @override
  String get speakerphone => 'Skaļrunis';

  @override
  String get muteMic => 'Izslēgt skaņu';

  @override
  String get unmuteMic => 'Ieslēgt skaņu';

  @override
  String get releaseToSend => 'Atlaidiet, lai nosūtītu';

  @override
  String get callEnded => 'Zvans beidzās';

  @override
  String get openConversation => 'Atvērt sarunu';

  @override
  String get callBack => 'Atzvanīt';

  @override
  String get letCallsReachYou => 'Ļaujiet zvaniem jūs sasniegt';

  @override
  String get callPermissionsIntro =>
      'Jūsu aģenti var jums piezvanīt. Lai zvanītu kā tālruņa zvans, kamēr NeoAgent darbojas fonā vai tālrunis ir bloķēts, tam ir nepieciešami šie.';

  @override
  String get showOverOtherApps => 'Rādīt pāri citām lietotnēm';

  @override
  String get showOverOtherAppsDetail =>
      'Atver zvana ekrānu, lai kur jūs atrastos.';

  @override
  String get fullScreenCalls => 'Pilnekrāna zvani';

  @override
  String get fullScreenCallsDetail => 'Zvani virs bloķēšanas ekrāna.';

  @override
  String get unrestrictedBattery => 'Neierobežots akumulators';

  @override
  String get unrestrictedBatteryDetail =>
      'Saglabā NeoAgent savienojumu, lai pienāk zvani.';

  @override
  String get permissionAllowed => 'Atļauts';

  @override
  String get triggerSectionCalendar => 'Kalendārs';

  @override
  String get triggerSectionFiles => 'Faili un dokumenti';

  @override
  String get triggerSectionHome => 'Mājas un mediji';

  @override
  String get triggerSectionDevices => 'Ierīces un vietas';

  @override
  String get triggerSectionTasks => 'Uzdevumi';

  @override
  String get messagingMemberJoined => 'Biedrs pievienojās';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Palaist, kad kāds pievienojas Discord serverim, Telegram vai WhatsApp grupai, Slack kanālam vai Matrix telpai.';

  @override
  String get messagingMemberLeft => 'Biedrs aizgāja';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Palaist, kad kāds atstāj Discord serveri, Telegram vai WhatsApp grupu, Slack kanālu vai Matrix istabu.';

  @override
  String get messagingReactionAdded => 'Pievienota reakcija';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Palaist, kad atļautā persona reaģē uz ziņojumu privātā tērzēšanā.';

  @override
  String get messagingPlatformDisconnected => 'Ziņojumapmaiņa ir atvienota';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Palaist, kad ziņojumapmaiņas savienojums tiek pārtraukts un jums ir nepieciešams, piemēram, pēc atteikšanās.';

  @override
  String get googleCalendarEventStarting => 'Sākas Google kalendāra pasākums';

  @override
  String get googleCalendarEventCreated =>
      'Google kalendāra pasākums ir izveidots';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Palaist, kad parādās jauns notikums vai ielūgums.';

  @override
  String get outlookCalendarEventStarting => 'Sākas Outlook kalendāra notikums';

  @override
  String get nextcloudCalendarEventStarting =>
      'Sākas Nextcloud kalendāra pasākums';

  @override
  String get runMinutesBeforeEachEvent =>
      'Pirms katra pasākuma palaidiet noteiktu minūšu skaitu.';

  @override
  String get googleDriveFileAdded => 'Pievienots Google diska fails';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Palaist, kad fails tiek pievienots Diskam vai tajā esošajai mapei.';

  @override
  String get googleSheetsRowAdded => 'Pievienota Google izklājlapu rinda';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Palaist, kad lapā parādās jaunas rindas.';

  @override
  String get onedriveFileAdded => 'OneDrive fails ir pievienots';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Palaist, kad fails tiek pievienots OneDrive mapei.';

  @override
  String get nextcloudFileAdded => 'Pievienots Nextcloud fails';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Palaist, kad fails tiek pievienots mapei Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Ar jums kopīgots Nextcloud fails';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Palaist, kad kāds ar jums koplieto failu vai mapi.';

  @override
  String get notionItemAdded => 'Pievienots jēdzienu datu bāzes vienums';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Palaist, kad vienums tiek pievienots Notion datu bāzei.';

  @override
  String get notionItemUpdated => 'Jēdzienu datu bāzes vienums ir atjaunināts';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Palaist, kad tiek mainīts vienums Notion datubāzē.';

  @override
  String get trelloCardEnteredList => 'Trello karte pievienota sarakstam';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Palaist, kad kartīte ir izveidota vai pārvietota sarakstā.';

  @override
  String get figmaCommentAdded => 'Pievienots Figma komentārs';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Palaist, kad kāds komentē Figma failu.';

  @override
  String get githubPrOpened => 'GitHub izvilkšanas pieprasījums ir atvērts';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Palaist, kad repozitorijā tiek atvērts jauns izvilkšanas pieprasījums.';

  @override
  String get githubWorkflowRunFailed =>
      'GitHub darbplūsmas palaišana neizdevās';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Palaist, kad GitHub darbību izpilde neizdodas.';

  @override
  String get githubCommitPushed => 'GitHub apņemšanās ir nospiesta';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Palaist, kad jaunas saistības sasniedz filiāli.';

  @override
  String get mcpServerFailed => 'MCP serveris neizdevās';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Palaist, kad MCP serveris, kas darbojās, neizdodas vai ir nepieciešams pierakstīties.';

  @override
  String get homeAssistantStateChanged => 'Mājas palīga statuss ir mainīts';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Palaist, kad entītija mainās, sasniedz stāvokli vai šķērso vērtību.';

  @override
  String get spotifyTrackChanged => 'Spotify celiņš mainīts';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Palaist, kad tiek atskaņots cits celiņš.';

  @override
  String get neorecallDailySummaryReady =>
      'NeoRecall dienas kopsavilkums ir gatavs';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Palaist, kad dienas kopsavilkums ir galīgs.';

  @override
  String get neorecallConversationRecorded => 'NeoRecall saruna ierakstīta';

  @override
  String get runWhenARecordedConversationEnds =>
      'Palaist, kad beidzas ierakstītā saruna.';

  @override
  String get geofenceTrigger => 'Ģeožoga atrašanās vieta';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Skrieniet, kad tālrunis pienāk vietā vai atstāj to. Nepieciešama atrašanās vietas izsekošana tālrunī.';

  @override
  String get healthMetricRecorded => 'Reģistrēts veselības rādītājs';

  @override
  String get runWhenAHealthReadingArrives =>
      'Palaist, kad tiek saņemts sinhronizēts stāvokļa rādījums, pēc izvēles virs vai zem vērtības.';

  @override
  String get wearableConnectionChanged => 'Valkājams pievienots vai atvienots';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Palaist, kad jūsu valkājamais savienojums tiek izveidots vai atvienots.';

  @override
  String get taskRunFinished => 'Vēl viens uzdevums pabeigts';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Palaist pēc tam, kad cits uzdevums ir pabeigts, izdodas vai neizdodas.';

  @override
  String get appPackageOptional => 'Lietotņu pakotne (pēc izvēles)';

  @override
  String get appPackageHelper => 'Piemēram, com.whatsapp';

  @override
  String get anyPlatform => 'Jebkura platforma';

  @override
  String get spaceIdOptional =>
      'Servera, grupas, kanāla vai telpas ID (pēc izvēles)';

  @override
  String get spaceIdHelper => 'Tukši pulksteņi, kuros atrodas robots.';

  @override
  String get emojiOptional => 'Emocijzīmes (neobligāti)';

  @override
  String get chatIdOptional => 'Tērzēšanas ID (neobligāti)';

  @override
  String get platformOptional => 'Platforma (pēc izvēles)';

  @override
  String get platformOptionalHelper =>
      'Piemēram, whatsapp. Tukši pulksteņi visi.';

  @override
  String get minutesBefore => 'Minūtes iepriekš';

  @override
  String get calendarIdOptional => 'Kalendāra ID (neobligāti)';

  @override
  String get calendarIdHelper => 'Tukšs izmanto jūsu primāro kalendāru.';

  @override
  String get invitesOnly => 'Tikai ielūgumi no citiem';

  @override
  String get nextcloudCalendarPath => 'Kalendārs';

  @override
  String get nextcloudCalendarPathHelper =>
      'Tās nosaukums Nextcloud kalendāru sarakstā, piemēram, personisks';

  @override
  String get folderIdOptionalHelperDrive => 'Tukši pulksteņi visam Diskam.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Tukšs skatās saknes mapi.';

  @override
  String get driveFolderIdOptional => 'Mapes ID (pēc izvēles)';

  @override
  String get spreadsheetId => 'Izklājlapas ID';

  @override
  String get sheetRange => 'Diapazons';

  @override
  String get sheetRangeHelper => 'Tabulas kolonnas, piemēram, Sheet1!A:E';

  @override
  String get folderPathOptional => 'Mapes ceļš (pēc izvēles)';

  @override
  String get folderPathHelper => 'Piemēram, dokumenti';

  @override
  String get notionDatabaseId => 'Datu bāzes ID';

  @override
  String get trelloListId => 'Saraksta ID';

  @override
  String get figmaFileKey => 'Faila atslēga';

  @override
  String get figmaFileKeyHelper => 'No faila saites: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Repozitorijs';

  @override
  String get workflowOptional => 'Darbplūsma (neobligāti)';

  @override
  String get workflowHelper => 'Faila nosaukums, piemēram, ci.yml';

  @override
  String get branchOptional => 'Filiāle (pēc izvēles)';

  @override
  String get branchHelper => 'Tukšs izmanto noklusējuma filiāli.';

  @override
  String get mcpServerIdOptional => 'MCP servera ID (pēc izvēles)';

  @override
  String get entityId => 'Entītijas ID';

  @override
  String get entityIdHelper => 'Piemēram, binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Mērķa stāvoklis (neobligāti)';

  @override
  String get targetStateHelper => 'Piemēram uz';

  @override
  String get aboveOptional => 'Iepriekš (pēc izvēles)';

  @override
  String get belowOptional => 'Zemāk (pēc izvēles)';

  @override
  String get placeName => 'Vietas nosaukums';

  @override
  String get latitude => 'Platums';

  @override
  String get longitude => 'Garums';

  @override
  String get radiusMeters => 'Rādiuss metros';

  @override
  String get geofenceTransition => 'Kad';

  @override
  String get arriving => 'Ierašanās';

  @override
  String get leaving => 'Aizbraukšana';

  @override
  String get healthMetric => 'Veselības metrika';

  @override
  String get healthMetricHelper =>
      'Piemēram, sirdsdarbības ātrums, soļi, svars';

  @override
  String get wearableTransition => 'Kad valkājamas';

  @override
  String get wearableConnects => 'Savieno';

  @override
  String get wearableDisconnects => 'Atvienojas';

  @override
  String get sourceTask => 'Pēc uzdevuma';

  @override
  String get taskOutcome => 'Rezultāts';

  @override
  String get anyOutcome => 'Jebkurš rezultāts';

  @override
  String get succeeded => 'Izdevās';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 trūkst vai tas nav derīgs.';
  }

  @override
  String get triggerSectionMessaging => 'Ziņapmaiņa';

  @override
  String get triggerSectionDeveloper => 'Izstrādātājs';

  @override
  String get triggerSectionMemory => 'Atmiņa';

  @override
  String get triggerSectionNews => 'Jaunumi';

  @override
  String get triggerSectionSystem => 'Sistēma';

  @override
  String get searchTriggersHint =>
      'Meklējiet aktivizētājus, lietotnes vai notikumus';

  @override
  String get noTriggersMatch =>
      'Neviens aktivizētājs neatbilst jūsu meklēšanas vaicājumam.';

  @override
  String get triggerAccountMissing => 'Vēl nav konta';

  @override
  String get pickTriggerKeyboardHint => 'Enter izvēlas pirmo rezultātu';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 trigeri';
  }

  @override
  String get addFromSkillsSh => 'Pievienot no skill.sh';

  @override
  String get skillsShHint =>
      'Meklējiet iepriekš, lai atrastu prasmes vietnē skill.sh, vai ielīmējiet saiti skill.sh vai komandu \"npx skills add\".';

  @override
  String get noSkillsShMatches =>
      'Šim meklēšanas vaicājumam neatbilst neviena skill.sh prasme.';

  @override
  String get installingSkill => 'Notiek instalēšana…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Uzstādīts $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 instalēšana';
  }

  @override
  String get authVerify => 'Pārbaudīt';

  @override
  String get authCreateAccount => 'Izveidot kontu';

  @override
  String get authNewInviteLink => 'Jauna uzaicinājuma saite';

  @override
  String get authShowPassword => 'Rādīt paroli';

  @override
  String get authHidePassword => 'Slēpt paroli';

  @override
  String get authPasswordWillBeRejected => 'pārāk vājš, tiks noraidīts';

  @override
  String get authUsernameTooShort =>
      'Lietotājvārdiem ir jābūt vismaz 3 rakstzīmēm.';

  @override
  String get authUsernameTaken => 'Šis lietotājvārds jau ir aizņemts.';

  @override
  String get authSignupsClosed =>
      'Reģistrēšanās šajā serverī ir slēgta. Jautājiet administratoram kontu.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Šis serveris pieņem tikai pierakstīšanos, izmantojot HTTPS. Tā vietā atveriet $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Šis serveris pieņem tikai pierakstīšanos, izmantojot HTTPS. Izveidojiet savienojumu ar to, izmantojot https:// adresi.';

  @override
  String get authAccountNotFound => 'Šis konts vairs nepastāv.';

  @override
  String get authQrRateLimited =>
      'Pārāk daudz QR pierakstīšanās pieprasījumu. Uzgaidiet brīdi un pēc tam atsvaidziniet kodu.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Aizmirsāt paroli? Lūdziet servera administratoram to atiestatīt sadaļā Administrēšana → Lietotāji.';

  @override
  String get authChangeServer => 'Mainīt serveri';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Pierakstīšanās $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Šī adrese neatbild kā NeoAgent serveris. Pārbaudiet URL un mēģiniet vēlreiz.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Nevarēja atvērt drošu (HTTPS) savienojumu ar $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Nevarēja sasniegt $arg1, izmantojot HTTPS, un arī vienkāršs HTTP neatbildēja. Pārbaudiet adresi un ostu.';
  }

  @override
  String get adminResetPassword => 'Atiestatīt paroli';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Atiestatiet $arg1 paroli';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Izvēlieties jaunu $arg1 paroli. Viņi tiks izrakstīti katrā ierīcē un atkal pierakstīsies ar šo paroli.';
  }

  @override
  String get adminNewPassword => 'Jauna parole';

  @override
  String get adminSetPassword => 'Iestatiet paroli';

  @override
  String get authMissingFields => 'Aizpildiet katru nepieciešamo lauku.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 atiestatīja $arg2 paroli';
  }

  @override
  String get adminPasswordUpdated =>
      'Parole atjaunināta; lietotājs visur bija izrakstījies.';

  @override
  String get authSignInTitle => 'Pierakstieties NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Skenējiet ar tālruni vai izmantojiet savu paroli.';

  @override
  String get authOrUsePassword => 'vai izmantojiet savu paroli';

  @override
  String get qrLoginWaitingTitle => 'Apstipriniet savā tālrunī';

  @override
  String get qrLoginWaitingBody =>
      'Jūsu tālrunis skenēja kodu. Apstipriniet pieteikšanos tur, lai pabeigtu pierakstīšanos.';

  @override
  String get qrLoginSigningInOn => 'Pierakstīšanās';

  @override
  String get qrLoginLocation => 'Atrašanās vieta';

  @override
  String get qrLoginWaitingForApproval => 'Gaida apstiprinājumu';

  @override
  String get qrLoginCancelAndUsePassword => 'Atceliet un izmantojiet paroli';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Pieteikšanās jūsu tālrunī tika noraidīta. Skenējiet jauno kodu, lai mēģinātu vēlreiz.';

  @override
  String get signupKey => 'Reģistrācijas atslēga';

  @override
  String get signupKeyStepSubtitle =>
      'Jauniem kontiem šajā serverī ir nepieciešama reģistrācijas atslēga. Ievadiet atslēgu, ko saņēmāt no administratora.';

  @override
  String get signupKeyChange => 'Mainīt';

  @override
  String get signupKeyRequiredError => 'Ievadiet savu reģistrācijas atslēgu.';

  @override
  String get signupKeyInvalidError =>
      'Šī reģistrācijas atslēga nav derīga. Pārbaudiet to un mēģiniet vēlreiz.';

  @override
  String get signupKeyUsedError =>
      'Šī reģistrācijas atslēga jau ir izmantota. Lūdziet administratoram jaunu.';

  @override
  String get adminRequireSignupKey => 'Pieprasīt reģistrācijas atslēgu';

  @override
  String get adminRequireSignupKeyHint =>
      'Jauniem kontiem ir nepieciešama vienreizēja atslēga no administratora. Ja izslēgts, reģistrēties var ikviens, kas var piekļūt šim serverim. Pirmajam kontam atslēga nekad nav vajadzīga.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Jauniem kontiem tagad ir nepieciešama reģistrācijas atslēga.';

  @override
  String get adminSignupOpenNotice => 'Tagad reģistrēties var ikviens.';

  @override
  String get signupKeys => 'Reģistrācijas atslēgas';

  @override
  String get signupKeysDescription =>
      'Vienreizējas atslēgas reģistrācijai, kamēr atslēga ir obligāta. Katra atslēga izveido tieši vienu kontu.';

  @override
  String get signupKeysNew => 'Jaunas atslēgas';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Neizmantotas · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Izmantotas · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Atsauktas · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Visas · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Neizmantota';

  @override
  String get signupKeyStatusUsed => 'Izmantota';

  @override
  String get signupKeyStatusRevoked => 'Atsaukta';

  @override
  String get signupKeysExport => 'Eksportēt .txt';

  @override
  String get signupKeysCopied => 'Atslēgas nokopētas';

  @override
  String get signupKeyCopied => 'Atslēga nokopēta';

  @override
  String get signupKeysEmpty => 'Šajā sarakstā nav atslēgu.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Izveidota $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Izmantoja $arg1, $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Izmantota $arg1 kontā, kas kopš tā laika ir dzēsts';
  }

  @override
  String get signupKeyRevokeTitle => 'Vai atsaukt šo atslēgu?';

  @override
  String get signupKeyRevokeMessage =>
      'Neviens ar to vairs nevarēs reģistrēties. To nevar atsaukt.';

  @override
  String get signupKeyRevoked => 'Atslēga atsaukta.';

  @override
  String signupKeysShowMore(int count) {
    return 'Rādīt vēl $count';
  }

  @override
  String get signupKeysCreateTitle => 'Izveidot reģistrācijas atslēgas';

  @override
  String get signupKeysCount => 'Atslēgu skaits';

  @override
  String get signupKeysCountHelper => 'No 1 līdz 500';

  @override
  String get signupKeysCountInvalid => 'Ievadiet skaitli no 1 līdz 500.';

  @override
  String get signupKeysLabel => 'Etiķete (neobligāti)';

  @override
  String get signupKeysLabelHint => 'piem., pavasara beta testētāji';

  @override
  String signupKeysCreateAction(int count) {
    return 'Izveidot ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Atslēgas gatavas: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Katru atslēgu nododiet tikai vienai personai. Neizmantotās atslēgas paliek sarakstā, tāpēc vēlāk tās var atkal nokopēt vai eksportēt.';

  @override
  String get signupKeysSaveDialogTitle => 'Saglabāt reģistrācijas atslēgas';

  @override
  String get signupKeysExported => 'Atslēgas eksportētas.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor izveidoja reģistrācijas atslēgas ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor atsauca reģistrācijas atslēgu';
  }
}
