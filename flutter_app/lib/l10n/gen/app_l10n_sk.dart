// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Slovak (`sk`).
class AppL10nSk extends AppL10n {
  AppL10nSk([String locale = 'sk']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Vitajte';

  @override
  String get onboardingEyebrowCommunication => 'Komunikácia';

  @override
  String get onboardingEyebrowIntelligence => 'Inteligencia';

  @override
  String get onboardingEyebrowComputer => 'Počítač';

  @override
  String get onboardingEyebrowAutomation => 'automatizácia';

  @override
  String get onboardingNext => 'Ďalej';

  @override
  String get onboardingIntroCouldNotLoad => 'Úvod sa nepodarilo načítať.';

  @override
  String get onboardingModelDescription =>
      'Vyberte model, ktorý má NeoAgent štandardne používať, alebo ho nechajte vybrať automaticky.';

  @override
  String get onboardingLoadingModels => 'Načítavajú sa modely…';

  @override
  String get noAiModelTitle => 'Zatiaľ nie je nastavený žiadny model AI';

  @override
  String get noAiModelBody =>
      'Pridajte kľúč API od poskytovateľa, ako je OpenAI, Anthropic alebo Google. NeoAgent potom ukáže modely, ktoré môžete použiť.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent potrebuje na odpoveď model AI. Pridajte kľúč API od poskytovateľa, ako je OpenAI, Anthropic alebo Google.';

  @override
  String get noAiModelAdminHint =>
      'Ako správca môžete tiež nastaviť poskytovateľov pre všetkých v časti Správca → Poskytovatelia.';

  @override
  String get addApiKey => 'Pridať kľúč API';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform je pripojený.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Čaká sa na pripojenie $platform…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Nastavenie sa nepodarilo uložiť: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Pripravený';

  @override
  String get onboardingStepRequired => 'Povinné';

  @override
  String get onboardingStepOptional => 'Voliteľné';

  @override
  String get onboardingStepCloudOrLocal => 'Cloudové alebo lokálne';

  @override
  String get onboardingStepComputer => 'Počítač';

  @override
  String get onboardingStepRoutines => 'Rutiny';

  @override
  String get onboardingComputerChoiceTitle => 'Kde by to malo\nfungovať?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Môžete prepínať na reláciu.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Súkromné pieskovisko · vždy zapnuté';

  @override
  String get onboardingThisComputer => 'Tento počítač';

  @override
  String get onboardingThisComputerSubtitle =>
      'Vaše súbory, aplikácie a prehliadač';

  @override
  String get onboardingSearchApps => 'Hľadať aplikácie…';

  @override
  String get onboardingRoutinesDescription =>
      'Výsledky sa dostanú do vašich četov.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Výsledky prichádzajú ako upozornenia.';

  @override
  String get onboardingNotifications => 'Upozornenia';

  @override
  String get onboardingReadyTitle => 'Všetko je\npripravené.';

  @override
  String get onboardingReadyDescription => 'Pošlite svoju prvú správu.';

  @override
  String get onboardingMessageNeoagent => 'Správa NeoAgent';

  @override
  String get onboardingAskAnything => 'Pýtajte sa na čokoľvek…';

  @override
  String get onboardingOpenNeoagent => 'Otvorte NeoAgent';

  @override
  String get onboardingStarterTrip => 'Naplánujte si víkendový výlet';

  @override
  String get onboardingStarterLanding => 'Vytvorte vstupnú stránku';

  @override
  String onboardingQuickSteps(int count) {
    return 'Rýchle kroky $count';
  }

  @override
  String get taskNeedsEmail => 'Najprv pripojte e-mail';

  @override
  String get taskNeedsCalendar => 'Najprv pripojte kalendár';

  @override
  String get taskNeedsModel => 'Najprv nastavte model AI';

  @override
  String get taskPromptDailyRecap =>
      'Zrekapitulujte si môj deň: zhrňte konverzácie, dokončenú prácu a rozhodnutia z dnešného dňa a potom uveďte všetko, na čo by som mal zajtra nadviazať. Skrátka a pošli mi to.';

  @override
  String get taskPromptInboxCheck =>
      'Skontrolujte moju e-mailovú schránku pre správy, ktoré prišli od poslednej kontroly. Pošlite mi správu iba o e-mailoch, ktoré sú naliehavé alebo potrebujú odpoveď, pričom každý obsahuje jednoriadkové zhrnutie. Ak nič nevyžaduje moju pozornosť, nič neposielajte.';

  @override
  String get taskPromptMorningBriefing =>
      'Pripravte si môj ranný brífing: dnešné počasie, kde som, udalosti v mojom kalendári a najdôležitejšie otvorené položky, o ktorých viem. Pošlite ho ako krátku správu, ktorú je možné skenovať.';

  @override
  String get taskPromptTomorrowPrep =>
      'Pozrite si môj kalendár na zajtra. Pri každom stretnutí mi povedz, o čo ide, kto sa na ňom podieľa a čo by som mal pripraviť. Ak je zajtra prázdny, nič neposielajte.';

  @override
  String get taskPromptNewsDigest =>
      'Vyhľadajte na webe dnešné najdôležitejšie správy o témach, ktoré ma zaujímajú (použite to, čo si pamätáte o mojich záujmoch). Pošlite mi súhrn až piatich položiek s jednou vetou a odkazom.';

  @override
  String get taskPromptWeeklyReview =>
      'Zopakujte si môj týždeň: čo sa podarilo, čo sa pošmyklo a čo je ešte otvorené. Navrhnite tri najdôležitejšie veci, na ktoré by ste sa mali budúci týždeň zamerať.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Prepojte telefónne číslo, ktoré patrí zástupcovi. Ktokoľvek, komu to povolíte, s ním môže četovať v priamych četoch a skupinách.';

  @override
  String get whatsappSelfChatDescription =>
      'Prepojte svoje vlastné číslo a porozprávajte sa s agentom v čete „Pošlite si správu“. Každý ďalší rozhovor a skupina na tomto účte sa ignoruje.';

  @override
  String get chatSendHintMac => '⌘↵ na odoslanie';

  @override
  String get chatSendHintOther => 'Ctrl+Enter na odoslanie';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Pre tento koncový bod sa vyžaduje základná adresa URL.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Zmenená e-mailová adresa sa pred použitím potvrdí.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Rozhodnutie vyššie v reťazci vyhráva.';

  @override
  String get aDeletedAccount => 'vymazaný účet';

  @override
  String get aFridayLookBackAtThe =>
      'Piatkové ohliadnutie sa za týždňom a plán na ďalší.';

  @override
  String get aKeyThatAsksForA =>
      'Kľúč, ktorý vyžaduje PIN alebo odtlačok prsta, nahrádza aj váš dvojfaktorový kód.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Jazykový model posúdil túto správu, pretože SystemOne je vypnutý.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Súbor metadát nastavenia NeoAgent prekročil limit bezpečnej veľkosti.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Na serveri je k dispozícii novšia webová zostava. Znova načítajte a načítajte najnovší balík.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Súkromná plocha s prehliadačom Chromium, súbormi, textovým editorom, terminálom a Pythonom. Vaša práca zostane medzi reláciami uložená.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Súkromný počítač so systémom Linux alebo zariadenie so systémom Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Nepodarilo sa stiahnuť požadovaný inštalačný súbor NeoAgent.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Spoluhráč vám pošle odkaz na pozvánku. Keď to prijmete, oni ';

  @override
  String get aTeammateSentYouAnInvite =>
      'spoluhráč vám poslal odkaz na pozvánku, zadajte ho sem a pripojte sa k jeho tímu.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Dočasné stiahnutie bude neskôr vyčistené.';

  @override
  String get aValueIsStored => 'Uloží sa hodnota.';

  @override
  String get access => 'Prístup';

  @override
  String get accessActivity => 'Aktivita prístupu';

  @override
  String accessArg1(Object? arg1) {
    return 'Prístup: $arg1';
  }

  @override
  String get accessMode => 'Režim prístupu';

  @override
  String get accessPermissions => 'Prístupové povolenia';

  @override
  String get accessToken => 'prístupový token';

  @override
  String get accessToken2 => 'Prístupový token';

  @override
  String get account => 'Účet';

  @override
  String accountArg1(Object? arg1) {
    return 'Účet #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Upozornenia na zmenu účtu';

  @override
  String get accountEmail => 'E-mail účtu';

  @override
  String get accountEmailIsOffUntilThese =>
      'E-mail účtu je vypnutý, kým nenastavíte: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent používa tento jazyk všade v aplikácii. Pri prvom prihlásení nasleduje toto zariadenie. Potom sa výber uloží do vášho účtu a použije sa na každom zariadení.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Nepodarilo sa zmeniť jazyk: $error';
  }

  @override
  String get accountLanguageTitle => 'Jazyk';

  @override
  String get accountNumber => 'Číslo účtu';

  @override
  String get accountSettings => 'Nastavenia účtu';

  @override
  String get accounts => 'Účty';

  @override
  String get accountsByTokensUsedAllTime =>
      'Účty podľa použitých tokenov po celú dobu.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'cloudové počítače účtov. Zmeny sa prejavia po serveri ';

  @override
  String get accountsOnThisServer => 'Účty na tomto serveri';

  @override
  String get active => 'Aktívne';

  @override
  String get activeSessions => 'Aktívne sedenia';

  @override
  String get activeToday => 'Dnes aktívny';

  @override
  String get add => 'Pridať';

  @override
  String get addAProviderCredentialFirstIts =>
      'Najprv pridajte poverenia poskytovateľa. Jeho modely sa tu objavia raz ';

  @override
  String get addAgent => 'Pridať agenta';

  @override
  String get addAnotherSignInMethodBefore =>
      'Pred odstránením tejto metódy pridajte inú metódu prihlásenia.';

  @override
  String get addBinding => 'Pridajte väzbu';

  @override
  String get addByNameOrId => 'Pridajte podľa mena alebo ID';

  @override
  String get addByNameOrIdInstead =>
      'Namiesto toho pridajte podľa mena alebo ID';

  @override
  String get addCredentialBinding => 'Pridajte väzbu poverení';

  @override
  String get addEntry => 'Pridať položku';

  @override
  String get addKey => 'Pridať kľúč';

  @override
  String get addMcpServer => 'Pridajte server MCP';

  @override
  String get addMemory => 'Pridať pamäť';

  @override
  String get memoryReview => 'Skontrolovať';

  @override
  String get memoryReviewPrompt =>
      'Prejdi všetky moje spomienky a uprac ich: archivuj duplikáty, zastarané fakty a všetko bez trvalej hodnoty. Potom mi stručne povedz, čo si zmenil.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Pridajte väčšiu dĺžku alebo iný typ znaku.';

  @override
  String get addPeopleOrGroups => 'Pridajte ľudí alebo skupiny';

  @override
  String get addSecurityKey => 'Pridajte bezpečnostný kľúč';

  @override
  String get addSomeoneOrAGroup => 'Pridajte niekoho alebo skupinu';

  @override
  String get addTask => 'Pridať úlohu';

  @override
  String get addTests => 'Pridajte testy';

  @override
  String get addTestsForThePartsOf =>
      'Pridajte testy pre časti tohto projektu, ktoré majú najmenšie pokrytie, a potom ich spustite.';

  @override
  String get addTheirOwnKeysInSettings =>
      'pridať svoje vlastné kľúče v Nastaveniach.';

  @override
  String get addToPrompt => 'Pridať do výzvy';

  @override
  String get added => 'Pridané';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Pridané $arg1 · Naposledy použité $arg2';
  }

  @override
  String get addressWithTheProvider => 'adresu u poskytovateľa.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Upravte hlasitosť reproduktora, skontrolujte predvolené nastavenia hardvérových tlačidiel a spravujte túto reláciu spúšťača.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Upravte filter vyhľadávania alebo stavu, aby ste videli viac kanálov správ.';

  @override
  String get adjustTheSpeakerVolumeHere => 'Tu upravte hlasitosť reproduktora.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Správca › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Tu sa zobrazia správcovské granty, odkazy na pozvánky a zmeny v správe.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Pokročilý manuálny plán pre špeciálne prípady.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Pokročilé: minúta hodina deň mesiac pracovný deň.';

  @override
  String get againRightAway => 'hneď znova.';

  @override
  String get agent => 'agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Zástupca: $arg1';
  }

  @override
  String get agentCalls => 'Agent volá';

  @override
  String get agentCommunication => 'Komunikácia agentov';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Komunikácia agenta: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Režim agenta upravuje pracovný priestor · ⌘↵ odoslať · ⌘N nová relácia';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agent sa pozastaví a pred spustením vás požiada o súhlas.';

  @override
  String get agentProfile => 'Profil agenta';

  @override
  String get agentVisibleName => 'Viditeľné meno agenta';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agent chce použiť $arg1. Rozhodnite sa klepnutím.';
  }

  @override
  String get agents => 'Agenti';

  @override
  String get aiAnswerUnreadable => 'Odpoveď AI je nečitateľná';

  @override
  String get aiProviderKeys => 'Kľúče poskytovateľa AI';

  @override
  String get aiUnavailable => 'AI nie je k dispozícii';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'upozornenia a iné e-maily z účtu.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Upozorní, keď si spojenie na odosielanie správ vyžaduje pozornosť používateľa';

  @override
  String get all => 'Všetky';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Všetci agenti ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Všetky $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Všetky sloty pre cloudové počítače sa momentálne používajú. Skúste to znova o chvíľu.';

  @override
  String get allComputerSlotsAreBusy =>
      'Všetky počítačové sloty sú zaneprázdnené';

  @override
  String get allTables => 'Všetky stoly';

  @override
  String get allTime => 'Celý čas';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Všetky nástroje sú povolené – agent môže použiť akúkoľvek schopnosť bez pýtania. ';

  @override
  String get allow => 'Povoliť';

  @override
  String get allowedRunsWithoutAsking => 'Povolené. Beží bez pýtania.';

  @override
  String get allowAll => 'Povoliť všetko';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Povoľte \"Inštalovať neznáme aplikácie\" pre NeoAgent a potom skúste aktualizáciu znova.';

  @override
  String get allowOnce => 'Povoliť raz';

  @override
  String get allowSender => 'Povoliť odosielateľovi';

  @override
  String get allowSession => 'Povoliť reláciu';

  @override
  String get allowTheAgentToStartAn =>
      'Umožnite zástupcovi začať s vami hlasový hovor v aplikácii.';

  @override
  String get allowedOrigins => 'Povolené pôvody';

  @override
  String get allowedPathPrefix => 'Povolená predpona cesty';

  @override
  String get allowsYouCanChangeThatPer =>
      'umožňuje. Neskôr to môžete zmeniť na osobu. Odkazy sa nikdy neudelia ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'už patrí k existujúcemu účtu';

  @override
  String get alreadyLinkedToAnotherAccount => 'už prepojené s iným účtom';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'už prepojený s iným účtom neoagent';

  @override
  String get alreadyUsed => 'už použité';

  @override
  String get always => 'Vždy';

  @override
  String get alwaysAllow => 'Vždy povoľte';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      'Možnosť „Vždy povoliť“ uloží politiku natrvalo – môžete ju zmeniť v Nastaveniach.';

  @override
  String get alwaysAsk => 'Vždy sa pýtajte';

  @override
  String get alwaysEngage => 'Vždy zapojte';

  @override
  String get alwaysJoins => 'Vždy sa pripojí';

  @override
  String get anApiKeyIsRequired => 'Vyžaduje sa kľúč API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Večerné zhrnutie toho, čo sa stalo a na čo nadviazať.';

  @override
  String get anHttpOrHttpsUrlIs => 'Vyžaduje sa adresa URL http alebo https.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'a analytika. Odkazy na tím sú dostupné na stránke tímu.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Inštalácia Android APK nie je na tejto platforme k dispozícii.';

  @override
  String get androidApp => 'aplikácia pre Android';

  @override
  String get androidControl => 'Ovládanie systému Android';

  @override
  String get androidCouldNotStart => 'Android sa nepodarilo spustiť';

  @override
  String get androidNotificationReceived =>
      'Prijaté upozornenie systému Android';

  @override
  String get androidOnly => 'Iba Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Inštalátor balíka Android sa nepodarilo otvoriť.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Obrazovka Android – klepnutím sa dotknite, potiahnutím potiahnite prstom';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Odpovede @zmienky o problémoch a žiadostiach o stiahnutie';

  @override
  String get anyone => 'Ktokoľvek';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Ktokoľvek na tejto platforme môže poslať správu $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Ktokoľvek na tejto platforme môže poslať správu $arg1 v $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'So $arg1 môže hovoriť každý, kto sa dostane na tento účet.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Ktokoľvek s odkazom sa môže pripojiť, kým nevyprší jeho platnosť alebo kým ho neodvoláte.';

  @override
  String get apiHttpsOrigin => 'Pôvod API HTTPS';

  @override
  String get apiKey => 'API kľúč';

  @override
  String get apiKey2 => 'api kľúč';

  @override
  String get apiKey3 => 'API kľúč';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api kľúč antropický claude openai gpt xai grok google gemini minimax nvidia nim poverenia openrouter';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Kľúče API a koncové body pre poskytovateľov AI, vyhľadávania a hlasu. Oni ';

  @override
  String get apiRequest => 'Žiadosť API';

  @override
  String get apiYourOwnServerASelf =>
      'API – váš vlastný server, model s vlastným hosťovaním alebo iný ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Sťahovanie súboru APK zlyhalo s protokolom HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Vyžaduje sa názov aplikácie.';

  @override
  String get appUpdates => 'Aktualizácie aplikácií';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Aktualizácie aplikácií nie sú pre túto zostavu nakonfigurované.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Na aktuálnu jazdu boli použité aktualizácie riadenia $arg1 vo fronte.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Použitá aktualizácia riadenia $arg1.';
  }

  @override
  String get apply => 'Použiť';

  @override
  String get applyBehaviorNotes => 'Aplikujte poznámky o správaní';

  @override
  String get applyCoreMemory => 'Použiť jadrovú pamäť';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Žiadosti o schválenie nástrojov citlivých agentov';

  @override
  String get approvalRequired => 'Vyžaduje sa schválenie';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Schválenie zostáva vo vašej overenej mobilnej relácii a platnosť každého kódu po krátkom okne automaticky vyprší.';

  @override
  String get approveLogin => 'Schválenie prihlásenia';

  @override
  String get approveQrLogin => 'Schváľte prihlásenie pomocou QR kódu';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Schváľte to iba v prípade, že ste sa na tomto zariadení práve teraz spustili.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Schválené prihlásenie pre $arg1.';
  }

  @override
  String get approvedOnly => 'Iba schválené';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Schválené párovanie pre $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Schválení ľudia a skupiny';

  @override
  String get approvedPeopleOnly => 'Iba schválení ľudia';

  @override
  String get archive => 'Archív';

  @override
  String get archiveAgent => 'Archívny agent?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archív ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Archív $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Archivovať vybrané spomienky?';

  @override
  String get areSharedByEveryAccountOn =>
      'sú zdieľané každým účtom na tomto serveri; účty stále môžu ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / vstup 1M';
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
    return 'Vyžaduje sa prístup $arg1';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'Účty $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktívny';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return 'Pridané $arg1. Upravte ho kedykoľvek, aby ste zmenili ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '„$arg1“ a jeho história spustenia budú natrvalo odstránené. Akýkoľvek aktívny chod bude zastavený. Súbory v pracovnom priestore sa nedotknú.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Vyžaduje sa schválenie $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'Aplikácie $arg1 sú aktívne';
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
    return '$arg1 (aktívne nástroje $arg2)';
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
    return '$arg1 $arg2 pri $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 zmenené';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 znaky';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Vytvorené $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [miestna adresa: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 zodpovedajúce „$arg3“';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return 'Pracovný priestor $arg1${arg2}NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\nNové účty $arg2';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 beží · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return 'Vzorky $arg1 · $arg2';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return 'Riadenie $arg1 · $arg2 v rade';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\nTokeny $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'Tokeny $arg1 / $arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 na $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 sa stal správcom ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 bajtov';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'Kanál $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 znaky';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 vymazané.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 nakonfigurované';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 pripojené. Vyberte úložiská a ľudí v časti Kto môže posielať správy.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return 'Základné položky $arg1.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 vytvoril odkaz na pozvánku';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return 'Pracovná plocha $arg1';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'Udalosti $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 zlyhal';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 zlyhal';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 zlyháva';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 pre $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 skupiny označené len';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return 'Pred ${arg1}h';
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
    return 'Pomocníci $arg1';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '(Pomer zásahov $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 je správca, takže účet nemožno odstrániť ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 je zablokovaný na $arg2. Aktualizujte zoznam prístupových práv, aby ste povolili odpovede.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 je pripojený a odpovedá.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 už nie je správcom ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 nie je k dispozícii na $arg2 (chýbajúce povolenie alebo závislosť spustenia).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 sa pripojil pod $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 posudzuje LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 kľúč$arg2 nakonfigurovaný';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Kľúč $arg1 bol odstránený.';
  }

  @override
  String arg1Left(Object? arg1) {
    return 'Zostáva $arg1';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 vľavo $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 prepojené';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return 'Pred ${arg1}m';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Uistite sa, že beží, a skúste to znova.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 spravuje tento účet';
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
    return 'Pripravené modely $arg1';
  }

  @override
  String arg1More(Object? arg1) {
    return '+ ďalšie $arg1';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 ďalšie kroky v histórii behu';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 sa presunul z $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 musí byť konečné číslo.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 musí byť adresa http:// alebo https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 vyžaduje pozornosť';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Pracovný priestor $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 nové účty v poslednom $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nové správy riadia túto jazdu';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return 'Nové jazdy $arg1';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 teraz spravuje tento účet.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 zo 4 povolených povolení. Súbory sú obmedzené na priečinok NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 z $arg2 povolené';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 skupín $arg2 sa pripojí k bežnému chatu';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 modelov $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return 'Pripravené $arg1 modelov $arg2';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 zo sady $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 nástrojov $arg2 povolené';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: Dobre';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 v deň $arg2 o $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 odpovedá iba ľuďom, ktorých pridáte nižšie.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 odpovedá iba pri označení';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 sa rozpráva iba s ľuďmi a skupinami, ktoré schválite';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Pridali sa $arg1 ľudia alebo skupiny';
  }

  @override
  String arg1Planning(Object? arg1) {
    return 'Plánovanie $arg1';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Poskytovatelia $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 pripravený';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Záznamy $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI presmerovania $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return 'Registrovaný $arg1';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 odpovedal';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 zrušil odkaz na pozvánku';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 beží';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 beží · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 beží v poslednom $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 uložené.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return 'Zvolené $arg1';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Zobrazené $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 zostalo ticho';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return 'Riadenie $arg1 $arg2 v rade';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 krok$arg2 · klepnite na uzol, ktorý chcete skontrolovať';
  }

  @override
  String arg1Steps(Object? arg1) {
    return 'Kroky $arg1';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 prestal spravovať $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'Tokeny $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Tokeny $arg1 v poslednom $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Nástroje $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (nedostupné uložené prepísanie)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1 % využité · Zostávajúce $arg2';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 chce s vami hovoriť.';
  }

  @override
  String arg1Web(Object? arg1) {
    return 'Web $arg1';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '„$arg1“ sa natrvalo odstráni.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 bude spravovať tento účet';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 na tejto platforme neodpovie';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 neodpovie na $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Ukladanie artefaktov používateľom';

  @override
  String get askAQuestionOrStartA => 'Položte otázku alebo začnite úlohu...';

  @override
  String get askBeforeClosingToBackground =>
      'Opýtajte sa pred zatvorením pozadia';

  @override
  String get askMe => 'Spýtaj sa ma';

  @override
  String get assignedAgent => 'Pridelený agent';

  @override
  String get assignedAgent2 => 'Pridelený agent';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Pridelený agent: $arg1';
  }

  @override
  String get assigneeOptional => 'Príjemca (voliteľné)';

  @override
  String get assistant => 'asistent';

  @override
  String get assistantKey131 => 'Kľúč asistenta 131';

  @override
  String get atLeast1 => 'Aspoň 1.';

  @override
  String get attachFiles => 'Pripojte súbory';

  @override
  String attentionArg1(Object? arg1) {
    return 'Pozor $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'denník auditu správca grant odvolať históriu pozvania tímu';

  @override
  String get authMethod => 'Auth Method';

  @override
  String get authServerUrl => 'Adresa URL autorizačného servera';

  @override
  String get authentication => 'Autentifikácia';

  @override
  String get authenticationFailed => 'Autentifikácia zlyhala.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Autentifikácia stále čaká. Dokončite postup prehliadača a skúste to znova.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Autentifikácia stále čaká. Dokončite tok prehliadača a obnovte ho.';

  @override
  String get authenticationTimedOut => 'Časový limit overenia vypršal.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Autentifikácia bola pred dokončením zrušená.';

  @override
  String get authenticatorApp => 'Aplikácia Authenticator';

  @override
  String get authenticatorCode => 'Authenticator kód';

  @override
  String get authorOptional => 'Autor (voliteľné)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (prvý poskytovateľ s kľúčom API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automatické trasy na najlepší dostupný model';

  @override
  String get automaticFast => 'Automaticky (rýchlo)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatika číta miestnosť a normálne sa drží späť. Iba spomenutie nerobí žiadne rozhodnutie, kým nie je priamo adresované.';

  @override
  String get automaticReserved => 'Automatické, rezervované';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automatické vrátenie vyžaduje zopakovanie pokusu z obrazovky nastavenia.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automaticky vyberie rýchly model prostredníctvom katalógu normálnych modelov.';

  @override
  String get automation => 'automatizácia';

  @override
  String get available => 'Dostupné';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'K dispozícii opäť v $arg1';
  }

  @override
  String get availableAgainShortly => 'Čoskoro opäť k dispozícii';

  @override
  String get availableInTheDesktopAppFor =>
      'K dispozícii v desktopovej aplikácii pre macOS, Windows a Linux';

  @override
  String get availableToTheAgent => 'K dispozícii agentovi';

  @override
  String get averageAllTime => 'Priemer, celý čas';

  @override
  String get avgImp => 'Priem. zobr.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Priemer/beh: tokeny $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Vyhnite sa opakovaným znakom a jasným sekvenciám.';

  @override
  String get awaitingScan => 'Čaká sa na skenovanie';

  @override
  String get back => 'Späť';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count v pozadí';
  }

  @override
  String get backgroundTasks => 'Úlohy na pozadí';

  @override
  String get backOn => 'späť na.';

  @override
  String get backToChat => 'Späť na chat';

  @override
  String get backToFolder => 'Späť do priečinka';

  @override
  String get backToSignIn => 'Späť na prihlásenie';

  @override
  String get backendChannel => 'Backendový kanál';

  @override
  String get backendOnThisComputer => 'Backend na tomto počítači';

  @override
  String get backendSync => 'Backend synchronizácia';

  @override
  String get backgroundLocationNeeded => 'Vyžaduje sa umiestnenie pozadia';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Synchronizácia na pozadí zostáva v systéme Android naplánovaná';

  @override
  String get badState => 'Zlý stav: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Základný obraz a veľkosť spustených virtuálnych počítačov QEMU ';

  @override
  String get baseUrlOptional => 'Základná adresa URL (voliteľné)';

  @override
  String get baseUrlTokenLocal => 'lokálny token základnej adresy URL';

  @override
  String get basicAuthentication => 'Základná autentifikácia';

  @override
  String get behaviorModules => 'Moduly správania';

  @override
  String get behaviorNotes => 'poznámky k správaniu';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Sprostredkovateľ poverení Bitwarden';

  @override
  String get bitwardenItem => 'Položka Bitwarden';

  @override
  String get bitwardenServer => 'Server Bitwarden';

  @override
  String get blankUsesCommon => 'Blank používa výraz „bežný“';

  @override
  String get blankUsesTheDefaultCallback =>
      'Blank používa predvolené spätné volanie';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Prázdne hodnoty používajú predvolené hodnoty poskytovateľa.';

  @override
  String get block => 'Blokovať';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Zablokovaná prichádzajúca správa od $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Most kompatibilný s BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'Adresa URL servera BlueBubbles';

  @override
  String get botToken => 'Token robota';

  @override
  String get botTokenAndApprovedChats => 'Token robota a schválené rozhovory';

  @override
  String get botTokenAndServerChannelAccess =>
      'Token robota a prístup na server/kanál';

  @override
  String get botTokenEventsApiAndChannel =>
      'Token robota, Events API a prístup ku kanálu';

  @override
  String get botUserId => 'ID používateľa robota';

  @override
  String get botUsername => 'Používateľské meno robota';

  @override
  String get brandName => 'Názov značky';

  @override
  String get braveSearch => 'Odvážne hľadanie';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Premostite akéhokoľvek poskytovateľa, ktorý môže odosielať a prijímať užitočné zaťaženia webhooku.';

  @override
  String get bringYourOwnKey => 'priniesť si vlastný kľúč';

  @override
  String get bringYourOwnKey2 => 'Prineste si vlastný kľúč';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Prehliadač, desktop Linux, súbory, terminál a Python zdieľajú jeden trvalý cloudový počítač.';

  @override
  String get browserLogin => 'Prihlásenie do prehliadača';

  @override
  String get browserScripting => 'Skriptovanie prehliadača';

  @override
  String get call => 'Zavolajte';

  @override
  String get callAgent => 'Zavolajte agentovi';

  @override
  String get callUser => 'Zavolajte používateľovi';

  @override
  String get calledByName => 'Volaný menom';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Môže delegovať úlohy na iných agentov';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Môže delegovať na $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Môže prijímať delegované úlohy';

  @override
  String get cancel => 'Zrušiť';

  @override
  String get cancelTask => 'Zrušiť úlohu';

  @override
  String get cannotPreview => 'Nie je možné zobraziť ukážku';

  @override
  String get cannotReceiveDelegatedTasks => 'nemôže prijímať delegované úlohy';

  @override
  String get cannotRunYet => 'ešte nemôže bežať.';

  @override
  String get capturedThePage => 'Zachytená stránka';

  @override
  String get category => 'Kategória';

  @override
  String chainArg1(Object? arg1) {
    return 'Reťaz: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Zmeňte režim nastavenia';

  @override
  String get channel => 'kanál';

  @override
  String get channelAccessToken => 'Token prístupu ku kanálu';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanál: $arg1$arg2 | Aktualizovaná verzia: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Sociálna pamäť v rámci kanála';

  @override
  String get channels => 'Kanály';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'ID rozhovoru';

  @override
  String get chatMode => 'Režim chatu';

  @override
  String get chatModel => 'Model chatu';

  @override
  String get checkAutomaticallyOnLaunch => 'Kontrola automaticky pri spustení';

  @override
  String get checkForMessagesEveryMs => 'Kontrolovať správy každých (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Automaticky kontrolovať nové správy';

  @override
  String get checkNow => 'Skontrolujte teraz';

  @override
  String get checkYourEmailToConfirmYour =>
      'Pred prihlásením skontrolujte svoj e-mail a potvrďte svoj účet NeoAgent.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Skontrolované $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Vyberte kategóriu alebo hľadajte vo všetkých nastaveniach.';

  @override
  String get chooseAPerson => 'Vyberte si osobu';

  @override
  String get chooseAProjectFolder => 'Vyberte priečinok projektu';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Vyberte predvolené hodnoty pre chat, agentov, záložné správanie a inteligentné smerovanie.';

  @override
  String get chooseGroups => 'Vyberte skupiny';

  @override
  String get chooseHowMuchYouWantTo =>
      'Vyberte, koľko chcete teraz konfigurovať. Obe možnosti je možné neskôr zmeniť.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Vyberte, ako sa má táto úloha začať. Manuálne sa spúšťajú iba v režime Spustiť teraz. Rozvrh je založený na čase. Integrácia spúšťa spustenie z pripojených oficiálnych aplikácií.';

  @override
  String get chooseOneToGetStartedNow =>
      'Vyberte si jeden a začnite hneď teraz. Neskôr môžete pridať ďalšie.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'V Nastaveniach vyberte živý model a hlas.';

  @override
  String get chooseTheirGroup => 'Vyberte si ich skupinu';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Vyberte, kde má mať táto osoba povolené hovoriť so $arg1. Toto môžete neskôr zmeniť v časti Kto môže posielať správy.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Vyberte, ku ktorým skupinám sa má $arg1 pripojiť, aj keď ich nikto neoznačí. Táto platforma nemusí rozlišovať značky od bežných správ.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Vyberte, ktoré modely si môže vybrať každý účet na tomto serveri ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Vyberte si, s kým sa $arg1 rozpráva a kedy sa pripojí k skupinovým rozhovorom.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Vyberte, kto môže dosiahnuť $arg1, a potom uložte zmeny.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Vyberte, kto môže poslať správu agentovi, pomocou „Kto môže poslať správu“ na karte WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Vyberte\npredvolený model.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, súbory, textový editor a terminál sú dostupné z pracovnej plochy Linuxu.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Vymazať';

  @override
  String get clearAll => 'Vymazať všetko';

  @override
  String clearArg1(Object? arg1) {
    return 'Vymazať $arg1?';
  }

  @override
  String get clearFilter => 'Vymazať filter';

  @override
  String get clearFilters => 'Vymazať filtre';

  @override
  String get clearSearch => 'Vymazať vyhľadávanie';

  @override
  String get clearView => 'Jasný výhľad';

  @override
  String get cliSession => 'Relácia CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'kliknutie nie je na tejto platforme podporované.';

  @override
  String get clickOnceToBeginCapturing => 'Jedným kliknutím spustíte snímanie';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Klikajte, píšte a pracujte s aplikáciami pre stolné počítače.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kliknutie na ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Kliknuto v prehliadači';

  @override
  String get clientId => 'ID klienta';

  @override
  String get clientSecret => 'Tajomstvo klienta';

  @override
  String get close => 'Zavrieť';

  @override
  String get closeJ => 'Zavrieť (⌘J)';

  @override
  String get closeTeachMode => 'Zatvorte režim výučby';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Zatvorením okna môžete buď ponechať NeoAgent spustený na pozadí s prístupom na panel, alebo úplne ukončiť runtime pracovnej plochy.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Podporované sú cloudové a samostatne hosťované inštancie. Lokálne a súkromné ​​adresy URL fungujú, keď ich môže NeoAgent dosiahnuť.';

  @override
  String get cloudComputer => 'Cloudový počítač';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Cloudový počítač · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Nastavenia cloudového počítača boli uložené. Ak ich chcete použiť, reštartujte server.';

  @override
  String get cloudComputerVm => 'Cloudový počítač (VM)';

  @override
  String get cloudComputers => 'Cloudové počítače';

  @override
  String get codeHosting => 'Hosting kódu';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Názvy kanálov oddelené čiarkami, bez #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Čiarkou oddelené, napríklad #všeobecné, #pomoc';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Čiarka oddelená. Problém ich musí mať všetky.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Príkaz zlyhal ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Vyžaduje sa príkaz.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Akumulátor povelového výstupu nie je aktívny.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Odovzdanie výstupu príkazu zlyhalo ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Výstup príkazu nahrať vynechané metadáta artefaktu.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Výstup príkazu už bol dokončený.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Príkazy a aplikácie';

  @override
  String get commandsRunInTheSamePersistent =>
      'Príkazy sa spúšťajú na rovnakom trvalom počítači, ktorý používa viditeľná pracovná plocha.';

  @override
  String get communityChatops => 'Community & ChatOps';

  @override
  String get completeSetup => 'Dokončite nastavenie';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Dokončite pracovný postup na pracovnej ploche.';

  @override
  String get completed => 'Dokončené';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Úplne zablokované – agent nemôže použiť túto kategóriu.';

  @override
  String get computerShell => 'Počítačový shell';

  @override
  String get computerUsedByThisSession => 'Počítač používaný touto reláciou';

  @override
  String get computerWorkspace => 'Pracovný priestor počítača';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigurovateľný osobný webhook most';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigurovateľné relé alebo webhook most';

  @override
  String get configurableTalkWebhookBridge =>
      'Konfigurovateľný webhookový mostík Talk';

  @override
  String get configurableWebInboxBridge =>
      'Konfigurovateľný most webovej doručenej pošty';

  @override
  String get configurableWebhookBridge => 'Konfigurovateľný webhook most';

  @override
  String get configurableWebhooks => 'Konfigurovateľné webhooky';

  @override
  String get configurationOrInTheEnvFile => 'Konfigurácia alebo v súbore .env.';

  @override
  String get configure => 'Konfigurovať';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Nakonfigurujte správanie pracovného priestoru a predvolené hodnoty modelu.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Nakonfigurované $arg1';
  }

  @override
  String get confirmEmailChanges => 'Potvrďte zmeny e-mailu';

  @override
  String get confirmNewSignUps => 'Potvrďte nové registrácie';

  @override
  String get confirmPassword => 'Potvrďte heslo';

  @override
  String get confirmPassword2 => 'Potvrďte heslo';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Pred prihlásením potvrďte svoj e-mail. Skontrolujte e-mailovú správu služby od spoločnosti NeoAgent.';

  @override
  String get connect => 'Pripojte sa';

  @override
  String get connectAMessagingPlatform =>
      'Pripojte platformu na\nodosielanie správ.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Pripojte verejný koncový bod HTTPS Home Assistant s dlhotrvajúcim prístupovým tokenom. Lokálne, spätné a súkromné ​​sieťové adresy sú blokované serverom.';

  @override
  String get connectAccount => 'Pripojiť účet';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Pripojte účty aplikácií jednotlivo, aby AI mohla použiť správny účet pre každú oficiálnu integráciu.';

  @override
  String connectArg1(Object? arg1) {
    return 'Pripojte $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Pripojte toľko účtov, koľko chcete. Každá aplikácia môže používať iný účet.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Pripojte kanály, vyberte si, s kým sa $arg1 rozpráva, a sledujte nedávnu aktivitu.';
  }

  @override
  String get connectInstance => 'Pripojte inštanciu';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Najprv pripojte túto integráciu a vyberte účet.';

  @override
  String get connectToThisServer => 'Pripojte sa k tomuto serveru';

  @override
  String get connectWhatsapp => 'Pripojte WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Pripojte svoju inštanciu Nextcloud vrátane serverov s vlastným hosťovaním. NeoAgent otvorí vlastnú prihlasovaciu stránku Nextcloud, takže sa môžete prihlásiť pomocou hesla, SSO alebo 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Pripojte svoj vlastný hosťovaný server NeoRecall. Po schválení obrazovky OAuth získa NeoAgent prístup len na čítanie k miestnemu vyhľadávaniu, spomienkam a prepisom.';

  @override
  String get connected => 'Pripojené';

  @override
  String get connectedAccount => 'Prepojený účet';

  @override
  String connectedArg1(Object? arg1) {
    return 'Pripojené $arg1';
  }

  @override
  String get connectedInstance => 'Pripojená inštancia';

  @override
  String get connectedNeorecallUser => 'Pripojený používateľ NeoRecall';

  @override
  String get connectedNextcloudUser => 'Pripojený používateľ Nextcloud';

  @override
  String get connectedServer => 'Pripojený server';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Pripája sa k modelu živého hlasu...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Pripojenie #$arg1';
  }

  @override
  String get connectionId => 'ID pripojenia';

  @override
  String get connectionLooksGood => 'Spojenie vyzerá dobre.';

  @override
  String get connectionMethod => 'Spôsob pripojenia';

  @override
  String get containsTextOptional => 'Obsahuje text (voliteľné)';

  @override
  String get content => 'Obsah';

  @override
  String get contentSecurityPolicy => 'politika zabezpečenia obsahu';

  @override
  String get continue2 => 'Pokračovať';

  @override
  String get continueFullSetup => 'Pokračujte v úplnom nastavení';

  @override
  String get continueRun => 'Pokračujte v behu';

  @override
  String get continueToSetup => 'Pokračujte v nastavovaní';

  @override
  String get controlSurface => 'OVLÁDACÍ PLOCHA';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Riadi prístup k nástrojom $arg1.';
  }

  @override
  String get conversation => 'Konverzácia';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID konverzácie používané, keď tento agent začína čet.';

  @override
  String get cookieSetup => 'Nastavenie cookies';

  @override
  String get cookiesNotConfigured => 'Súbory cookie nie sú nakonfigurované';

  @override
  String get copiedAsCsv => 'Skopírované ako CSV';

  @override
  String get copiedDebugInfo => 'Skopírované informácie o ladení';

  @override
  String get copiedExportForTheLast5 => 'Skopírovaný export posledných 5 správ';

  @override
  String get copiedFullPrompt => 'Úplná výzva bola skopírovaná';

  @override
  String get copiedLogs => 'Skopírované denníky';

  @override
  String get copiedRunId => 'Skopírované ID behu';

  @override
  String get copy => 'Kopírovať';

  @override
  String get copyAll => 'Skopírujte všetko';

  @override
  String get copyCodes => 'Kopírovať kódy';

  @override
  String get copyCsv => 'Skopírujte súbor CSV';

  @override
  String get copyDebugInfo => 'Kopírovať informácie o ladení';

  @override
  String get copyLink => 'Kopírovať odkaz';

  @override
  String get copyLogs => 'Kopírovať denníky';

  @override
  String get copyPrompt => 'Kopírovať výzvu';

  @override
  String get copyResponse => 'Kopírovať odpoveď';

  @override
  String get copyRunId => 'Skopírujte ID spustenia';

  @override
  String get copyWebhookUrl => 'Skopírujte webovú adresu webhooku';

  @override
  String get core => 'Jadro';

  @override
  String get coreMemory => 'jadrová pamäť';

  @override
  String get coreServicesThisServerDependsOn =>
      'Základné služby, od ktorých tento server závisí.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'pôvod verejnej adresy URL domény https';

  @override
  String get couldHelp => 'Môže pomôcť';

  @override
  String get couldNotApproveQrLogin =>
      'Nepodarilo sa schváliť prihlásenie pomocou QR kódu.';

  @override
  String get couldNotApproveQrPairing => 'Párovanie QR sa nepodarilo schváliť.';

  @override
  String get couldNotConnect => 'Nepodarilo sa pripojiť.';

  @override
  String get couldNotCreateBinding => 'Nepodarilo sa vytvoriť väzbu.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Nepodarilo sa odstrániť váš účet: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Bitwarden sa nepodarilo odpojiť.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Asistenta domácnosti sa nepodarilo odpojiť.';

  @override
  String get couldNotDisconnectNeorecall => 'NeoRecall sa nepodarilo odpojiť.';

  @override
  String get couldNotDisconnectNextcloud => 'Nextcloud sa nepodarilo odpojiť.';

  @override
  String get couldNotDisconnectTrello => 'Trello sa nepodarilo odpojiť.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Nepodarilo sa exportovať vaše údaje: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Rozhodnutia sa nepodarilo načítať';

  @override
  String get couldNotLoadUsageData =>
      'Nepodarilo sa načítať údaje o používaní.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Nastavenia systému Linux sa nepodarilo otvoriť automaticky.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Nepodarilo sa otvoriť stránku prepojenia poskytovateľa.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Nepodarilo sa otvoriť prihlasovaciu stránku poskytovateľa.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Nepodarilo sa otvoriť dielo vydania.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Vo vašom prehliadači sa nepodarilo otvoriť Trello.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Sťahovanie súboru pracovného priestoru sa nepodarilo otvoriť.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Balík aplikácie pre Android sa nepodarilo prečítať.';

  @override
  String get couldNotReadTheApk => 'Súbor APK sa nepodarilo prečítať.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Nepodarilo sa odstrániť kľúč: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Agenta sa nepodarilo uložiť.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Nastavenie Bitwarden sa nepodarilo uložiť.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Nastavenie Asistenta domácnosti sa nepodarilo uložiť.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Nepodarilo sa uložiť nastavenie NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nepodarilo sa uložiť nastavenie Nextcloud.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Nastavenie Trello sa nepodarilo uložiť.';

  @override
  String get couldNotSendConfirmationEmail =>
      'nebolo možné odoslať potvrdzujúci e-mail';

  @override
  String get couldNotStart => 'Nepodarilo sa spustiť';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Vytvorte';

  @override
  String get createAPasswordFirstToChange =>
      'Ak chcete zmeniť e-mail svojho účtu, najprv si vytvorte heslo.';

  @override
  String get createAPasswordOrLinkAnother =>
      'pred odstránením tohto spôsobu prihlásenia vytvorte heslo alebo prepojte iného poskytovateľa';

  @override
  String get createATaskWhileThisAgent =>
      'Vytvorte úlohu, kým je vybratý tento agent.';

  @override
  String get createLink => 'Vytvoriť odkaz';

  @override
  String get createOrModifyFilesInYour =>
      'Vytvárajte alebo upravujte súbory vo svojom pracovnom priestore.';

  @override
  String get createPassword => 'Vytvorte heslo';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Vytvorte špecializovaných robotov so samostatnou pamäťou, nastaveniami, nástrojmi a priradením účtov.';

  @override
  String get createTheFirstAccount => 'Vytvorte prvý účet';

  @override
  String get createUpdateOrDeleteSkills =>
      'Vytvorte, aktualizujte alebo odstráňte zručnosti.';

  @override
  String get creatingYourSkill => 'Vytvára sa vaša zručnosť…';

  @override
  String get credentialBindings => 'Väzby poverení';

  @override
  String get credentialUse => 'Použitie poverenia';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Opakujúce sa behy založené na cron a jednorazové načasované spustenie.';

  @override
  String get cronExpression => 'Cron výraz';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter spustí dotaz.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + medzerník';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Aktuálny email: $arg1';
  }

  @override
  String get currentPassword => 'Aktuálne heslo';

  @override
  String get currentPasswordIsIncorrect => 'aktuálne heslo je nesprávne';

  @override
  String get currentTwoStepLoginCode => 'Aktuálny dvojkrokový prihlasovací kód';

  @override
  String get customAccess => 'Vlastný prístup';

  @override
  String get customCron => 'Vlastný Cron';

  @override
  String get customCronMustHave5Fields => 'Vlastný Cron musí mať 5 polí.';

  @override
  String get customEndpoint => 'vlastný koncový bod';

  @override
  String get customField => 'Vlastné pole';

  @override
  String get customHeader => 'Vlastná hlavička';

  @override
  String get customHeadersJson => 'Vlastné hlavičky (JSON)';

  @override
  String get customOpenaiCompatible => 'Vlastná kompatibilita s OpenAI';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Vlastný koncový bod kompatibilný s OpenAI';

  @override
  String get customOutgoingUrl => 'Vlastná odchádzajúca adresa URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Denne';

  @override
  String get dailyRecap => 'Denná rekapitulácia';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'databázový dotaz vyberte šablóny csv';

  @override
  String dayArg1(Object? arg1) {
    return 'Deň $arg1';
  }

  @override
  String get dayOfMonth => 'Deň v mesiaci';

  @override
  String get decideWhichToolsYourAgentMay =>
      'rozhodnite, ktoré nástroje môže váš agent použiť. Vidia vaše meno a ';

  @override
  String get decisionHigherUpTheChainWins =>
      'rozhodnutie vyššie v reťazci vyhráva a ukazuje zámok s ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Rozhodnutia sa zobrazia tu, keď $arg1 prečíta schválené skupiny $arg2. Uchováva sa iba posledných 30 a po reštartovaní servera sa resetujú.';
  }

  @override
  String get decline => 'Odmietnuť';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'hlboký chod · krok $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram kľúč';

  @override
  String get default2 => 'Predvolené';

  @override
  String get default3 => 'DEFAULT';

  @override
  String defaultArg1(Object? arg1) {
    return 'Predvolené ($arg1)';
  }

  @override
  String get defaultConversation => 'Predvolená konverzácia';

  @override
  String get defaultForNewGroups => 'Predvolené pre nové skupiny';

  @override
  String get defaultGroupParticipation => 'Predvolená účasť skupiny';

  @override
  String get defaultNeoagentWorkspace =>
      'Predvolený pracovný priestor NeoAgent';

  @override
  String get defaultOpenai => 'Predvolené (OpenAI)';

  @override
  String get defaultRateLimits => 'Predvolené limity sadzieb';

  @override
  String get defaultRateLimitsSaved =>
      'Predvolené limity sadzieb boli uložené.';

  @override
  String get defaultRecommended => 'Predvolené (odporúčané)';

  @override
  String get defaultRouting => 'Predvolené smerovanie';

  @override
  String get defaultSpace => 'Predvolený priestor';

  @override
  String get delete => 'Odstrániť';

  @override
  String get deleteAccount => 'Odstrániť účet';

  @override
  String get deleteAccountPermanently => 'Chcete natrvalo odstrániť účet?';

  @override
  String get deleteAnAccount => 'Odstráňte účet';

  @override
  String deleteArg1(Object? arg1) {
    return 'Odstrániť @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Odstrániť ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Natrvalo odstrániť $arg1 $arg2?';
  }

  @override
  String get deleteBinding => 'Odstrániť väzbu';

  @override
  String get deleteCoreMemoryEntry => 'Vymazať záznam základnej pamäte?';

  @override
  String get deleteForever => 'Odstrániť navždy';

  @override
  String get deleteMcpServer => 'Odstrániť server MCP?';

  @override
  String get deleteMemory => 'Vymazať pamäť?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Odstrániť natrvalo vymaže účet a všetky jeho údaje ';

  @override
  String get deleteRun => 'Odstrániť beh?';

  @override
  String get deleteRun2 => 'Odstrániť beh';

  @override
  String get deleteSelectedMemories => 'Odstrániť vybraté spomienky?';

  @override
  String get deleteSession => 'Odstrániť reláciu?';

  @override
  String get deleteSkill => 'Odstrániť zručnosť?';

  @override
  String get deleteTask => 'Odstrániť úlohu?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Vymazané „$arg1“.';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Odstránili sa @$arg1 a všetky ich údaje.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Odstránenie odstráni všetky vaše konverzácie, spomienky, súbory, úlohy a ';

  @override
  String get deliverableArtifactProduced => 'Vyrobený artefakt dodávky';

  @override
  String get deliverableCompleted => 'Dodávka dokončená';

  @override
  String get deliverableExecutionStarted => 'Realizácia dodávky sa začala';

  @override
  String get deliverableSelected => 'Dodávka vybraná';

  @override
  String get deliverableValidationFailed => 'Overenie dodávky zlyhalo';

  @override
  String get deliverableValidationStarted => 'Overenie dodávky sa začalo';

  @override
  String get deny => 'Odmietnuť';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Opíšte výsledok a potom ho ukážte na pracovnej ploche';

  @override
  String get describeWhatToBuildOrChange =>
      'Popíšte, čo vybudovať alebo zmeniť…';

  @override
  String get description => 'Popis';

  @override
  String get desktopApp => 'Desktopová aplikácia';

  @override
  String get desktopAppControlsAvailable =>
      'K dispozícii sú ovládacie prvky desktopovej aplikácie';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Snímanie z pracovnej plochy nie je na tejto platforme dostupné.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Odovzdávanie výstupu príkazu pracovnej plochy bolo zrušené.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Sprievodný príkaz na pracovnej ploche bol zrušený.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Časový limit sprievodného pripojenia k počítaču vypršal.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Vypršal časový limit pre podanie ruky na pracovnej ploche.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Sprievodca na pracovnej ploche tu nie je k dispozícii.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Sprievodca na pracovnej ploche je pozastavený lokálne.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Spracovanie sprievodnej správy na pracovnej ploche zlyhalo: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Nastavenia povolení sprievodcu na pracovnej ploche nie sú na webe k dispozícii.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Nastavenia povolení sprievodcu na pracovnej ploche nie sú na tejto platforme k dispozícii.';

  @override
  String get desktopCompanionRejected =>
      'Doplnok na pracovnej ploche bol odmietnutý.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Sprievodná odpoveď pracovnej plochy zlyhala: $arg1';
  }

  @override
  String get desktopControl => 'Ovládanie pracovnej plochy';

  @override
  String get desktopFailedToStart => 'Desktop sa nepodarilo spustiť';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Zachytenie streamu z pracovnej plochy zlyhalo: $arg1';
  }

  @override
  String get destinationId => 'ID destinácie';

  @override
  String get deviceAccess => 'Prístup k zariadeniu';

  @override
  String get deviceSettings => 'Nastavenia zariadenia';

  @override
  String get devices => 'Zariadenia';

  @override
  String get diagnosticsSaved => 'Diagnostika bola uložená.';

  @override
  String get directBluebubblesImessageBridge =>
      'Priamy most BlueBubbles iMessage';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Priame správy zostávajú citlivé. Skupiny na zozname povolených používajú režim účasti nižšie.';

  @override
  String get directoryDoesNotExist => 'Adresár neexistuje.';

  @override
  String get disable2fa => 'Zakázať 2FA';

  @override
  String get disableAll => 'Zakázať všetky';

  @override
  String get discard => 'Zahodiť';

  @override
  String get disconnect => 'Odpojiť';

  @override
  String get disconnectHomeAssistant => 'Chcete odpojiť domáceho asistenta?';

  @override
  String get disconnectNeorecall => 'Odpojiť NeoRecall?';

  @override
  String get disconnectNextcloud => 'Odpojiť Nextcloud?';

  @override
  String get disconnectPlatform => 'Odpojte platformu';

  @override
  String get disconnectTrello => 'Odpojiť Trello?';

  @override
  String get discoveryFailed => 'Objav zlyhal';

  @override
  String get dismiss => 'Odmietnuť';

  @override
  String get displayIdIsRequired => 'Vyžaduje sa ID zobrazenia.';

  @override
  String get displayName => 'Zobrazovaný názov';

  @override
  String get displayNameMustBe64Characters =>
      'Zobrazovaný názov môže mať maximálne 64 znakov.';

  @override
  String get displayNameSaved => 'Zobrazovaný názov bol uložený.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Neuvádzajte svoje používateľské meno ani e-mail.';

  @override
  String get done => 'Hotovo';

  @override
  String get downloadACopyOfYourData =>
      'Stiahnite si kópiu svojich údajov. Účty správcu nemožno odstrániť ';

  @override
  String get downloadACopyOfYourData2 =>
      'Stiahnite si kópiu svojich údajov alebo natrvalo odstráňte svoj účet. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Stiahnite si $arg1';
  }

  @override
  String get downloadUpdate => 'Stiahnite si aktualizáciu';

  @override
  String get downloadingTheNeoagentBackend => 'Sťahovanie backendu NeoAgent';

  @override
  String get draft => 'Návrh';

  @override
  String get dragIsNotSupportedOnThis =>
      'ťahanie nie je na tejto platforme podporované.';

  @override
  String get draggedOnTheScreen => 'Ťahané na obrazovke';

  @override
  String get dropAnApkOrApkBundle =>
      'Sem presuňte súbor APK alebo balík APK a nainštalujte ho';

  @override
  String get dropApkOrApksHere => 'Sem presuňte súbor APK alebo .apks';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Odolné pokyny pre hlas a štýl interakcie. Bezpečnostné a vykonávacie pravidlá majú stále prednosť.';

  @override
  String get eGAlexSLaptop => 'napr. Alexov notebook';

  @override
  String get eGMyLocalServer => 'napr. Môj lokálny server';

  @override
  String get edit => 'Upraviť';

  @override
  String get editAgent => 'Edit Agent';

  @override
  String get editCoreMemoryEntry => 'Upravte položku základnej pamäte';

  @override
  String get editInstructions => 'Upravte pokyny';

  @override
  String get editMcpServer => 'Upraviť server MCP';

  @override
  String get editTask => 'Upraviť úlohu';

  @override
  String editedArg1(Object? arg1) {
    return 'Upravené $arg1';
  }

  @override
  String get email => 'Email';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'E-mail vlastníkom účtov o prihláseniach, ktoré vyzerajú nezvyčajne.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'E-mail vlastníkom účtu, keď sa zmenia podrobnosti o ich účte.';

  @override
  String get emailCode => 'E-mailový kód';

  @override
  String get emailConfirmationRequired => 'vyžaduje sa potvrdenie e-mailom';

  @override
  String get emailIsAlreadyInUse => 'e-mail sa už používa';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail bol uložený. Ak sa vyžaduje potvrdenie, skontrolujte na novej adrese odkaz na potvrdenie NeoAgent.';

  @override
  String get emailSettingsSaved => 'Nastavenia e-mailu boli uložené.';

  @override
  String get emailUnverified => 'E-mail nie je overený';

  @override
  String get empty => 'Prázdny';

  @override
  String get emptyFile => 'Prázdny súbor';

  @override
  String get emptyFolder => 'Prázdny priečinok';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Prázdne používa predvolené nastavenie servera ($arg1).';
  }

  @override
  String get enable2fa => 'Povoliť 2FA';

  @override
  String get enableAll => 'Povoliť všetko';

  @override
  String get enableBehaviorModules => 'Povoliť moduly správania';

  @override
  String get enableOrDisableModels => 'Povoliť alebo zakázať modely';

  @override
  String get enabled => 'Povolené';

  @override
  String get encryptedPrivateToYourAccount =>
      'Šifrované, súkromné pre váš účet';

  @override
  String get end => 'Koniec';

  @override
  String get endCall => 'Ukončiť hovor';

  @override
  String get endVoiceCall => 'Chcete ukončiť hlasový hovor?';

  @override
  String get endpoint => 'Koncový bod';

  @override
  String get enterAPassword => 'Zadajte heslo.';

  @override
  String get enterAUsername => 'Zadajte používateľské meno.';

  @override
  String get enterAValidEmailAddress => 'Zadajte platnú e-mailovú adresu.';

  @override
  String get enterAnAddressManually => 'Zadajte adresu ručne';

  @override
  String get enterAnApiKeyFirst => 'Najprv zadajte kľúč API.';

  @override
  String get enterInviteLink => 'Zadajte odkaz na pozvánku';

  @override
  String get enterTheAddressOfANeoagent => 'Zadajte adresu servera NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Zadajte podrobnosti, ktoré vám $arg1 poskytol, aby $arg2 mohol odosielať a prijímať správy.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Zadajte svoj 2FA alebo obnovovací kód.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Ak chcete zmeniť svoje aktuálne heslo, zadajte ho.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Ak chcete uložiť zmeny e-mailu, zadajte svoje aktuálne heslo.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Zadajte podrobnosti o svojom účte NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Zadajte svoje používateľské meno alebo e-mail účtu. NeoAgent odošle odkaz na obnovenie, ak sa zhoduje s účtom.';

  @override
  String get enterYourUsernameOrEmail =>
      'Zadajte svoje používateľské meno alebo e-mail.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entita: $arg1';
  }

  @override
  String get environment => 'Životné prostredie';

  @override
  String get error => 'Chyba';

  @override
  String errorArg1(Object? arg1) {
    return '\nchyba: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Chyby z posledného denníka, zoskupené podľa správ.';

  @override
  String get errorsProblemsFailures => 'chyby problémy zlyhania';

  @override
  String get eventTypesCommaSeparated => 'Typy udalostí (oddelené čiarkami)';

  @override
  String get every15Minutes => 'Každých 15 minút';

  @override
  String get every30Minutes => 'Každých 30 minút';

  @override
  String get everyAccountOnThisServerLoses =>
      'Každý účet na tomto serveri stratí tento zdieľaný kľúč. účty ';

  @override
  String get everyAccountOnThisServerUses =>
      'Každý účet na tomto serveri používa túto adresu ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Každá aktívna relácia pre tento účet končí. Môžu sa prihlásiť ';

  @override
  String get everyDay0800 => 'Každý deň · 08:00';

  @override
  String get everyDay2000 => 'Každý deň · 20:00';

  @override
  String get everyHour => 'Každú hodinu';

  @override
  String get everyRunOnThisServerAll => 'Pri každom spustení na tomto serveri.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Každý citlivý nástroj si vždy vyžaduje schválenie.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Každý nástroj beží bez opýtania, okrem tých, ktoré osoba ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Každý v týchto skupinách, kanáloch alebo miestnostiach môže hovoriť so $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Všetci v tejto skupine';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Všetko, čo je $arg1 vypnuté pre vášho agenta, príde ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Všetko ostatné je vypnuté.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Všetko je dostupné z pracovnej plochy.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Všetko, čo môže agent použiť: oficiálne integrácie, servery MCP a zručnosti.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Všetko, čo ste vypli pre $arg1, sa vráti ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Presný webový pôvod má povolené vytvárať požiadavky na rôzne zdroje, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Spustite JavaScript v rámci relácie vášho prehliadača.';

  @override
  String get execution => 'Poprava';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Podrobnosti o vykonaní nie sú pre toto spustenie k dispozícii.';

  @override
  String get executionPlanCreated => 'Realizačný plán vytvorený.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Cvičenie $arg1';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[ukončiť $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Platnosť končí $arg1';
  }

  @override
  String get explainThisProject => 'Vysvetlite tento projekt';

  @override
  String exploredArg1(Object? arg1) {
    return 'Preskúmané $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Preskúmané $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Preskúmal pracovný priestor';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Export zlyhal: $arg1';
  }

  @override
  String get exportLast5Messages => 'Exportovať posledných 5 správ';

  @override
  String get exportMyData => 'Exportovať moje údaje';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Spustenie externého prehliadača zlyhalo s kódom ukončenia $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Spustenie externého prehliadača nie je na tejto platforme podporované.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Časový limit spustenia externého prehliadača vypršal.';

  @override
  String get externalMcpTools => 'Externé nástroje a nástroje MCP';

  @override
  String get extraButtons => 'Extra tlačidlá';

  @override
  String get extractingTheNeoagentRuntime => 'Extrahovanie runtime NeoAgent';

  @override
  String get failed => 'Nepodarilo sa';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Nepodarilo sa pripojiť: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nepodarilo sa pripojiť $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nepodarilo sa odstrániť \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'nepodarilo sa načítať';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Nepodarilo sa vygenerovať výzvu: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Nepodarilo sa spustiť externý prehliadač cez url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Nepodarilo sa spustiť postup OAuth.';

  @override
  String get failedToLoadPolicies => 'Politiky sa nepodarilo načítať';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Nepodarilo sa uložiť: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Server MCP sa nepodarilo uložiť.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Nepodarilo sa uložiť výber: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Nepodarilo sa odoslať upozornenie na server: $arg1';
  }

  @override
  String get fair => 'Spravodlivé';

  @override
  String get fasterReplies => 'Rýchlejšie odpovede';

  @override
  String get fewerModelCalls => 'Menej modelových hovorov';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'pole prázdne, aby sa obnovilo predvolené nastavenie.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Súbor prekračuje limit editora 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Súbor presahuje podporovaný limit veľkosti.';

  @override
  String get fileWrites => 'File Writes';

  @override
  String get filename => 'Názov súboru';

  @override
  String get files => 'Súbory';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Súbory, ktoré NeoAgent zapisuje alebo upravuje v tejto relácii, sa zobrazia tu.';

  @override
  String get filesSavedByAllUsers => 'Súbory uložené všetkými používateľmi';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Vyplňte schválené prihlásenia alebo overte požiadavky bez toho, aby ste AI ukázali tajomstvá.';

  @override
  String get finalResponse => 'Záverečná odpoveď';

  @override
  String get findAPlatform => 'Nájdite platformu';

  @override
  String get findAndFixABug => 'Nájdite a opravte chybu';

  @override
  String get findRecentChats => 'Nájdite nedávne rozhovory';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Nájdenie správneho runtime NeoAgent';

  @override
  String get finish => 'Dokončiť';

  @override
  String get finishAtTheScheduledTime => 'Dokončite v plánovanom čase';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Dokončite prihlasovanie do $arg1 vo svojom prehliadači a potom sa znova pripojte.';
  }

  @override
  String get flowGraph => 'Prietokový graf';

  @override
  String get flutterApp => 'Aplikácia Flutter';

  @override
  String get focusedExecutionProfile => 'Zameraný profil vykonávania';

  @override
  String get folderIdOptional => 'ID priečinka (voliteľné)';

  @override
  String get folderUnavailable => 'Priečinok je nedostupný';

  @override
  String get forExampleHttpsMatrixOrg => 'Napríklad https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Pre hostované alebo pokročilé nastavenia siete';

  @override
  String get forLinksInEmailsBlankUses =>
      'Pre odkazy v e-mailoch. Blank používa verejnú adresu URL servera.';

  @override
  String get forgotPassword => 'Zabudli ste heslo?';

  @override
  String get frameUnavailable => 'Rám je nedostupný';

  @override
  String freshnessArg1(Object? arg1) {
    return 'čerstvosť: $arg1';
  }

  @override
  String get fridays1700 => 'Piatok · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Z BotFather po vytvorení robota.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Odteraz $arg1 rozhoduje o tom, ktoré nástroje môže váš agent použiť. Oni ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Z portálu Discord Developer Portal pod vaším robotom.';

  @override
  String get fromTheLineDevelopersConsole =>
      'Z konzoly LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot => 'Z klienta Matrix alebo účtu robota.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Z twitchapps.com/tmi alebo z vašej vývojárskej aplikácie Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Úplná výzva';

  @override
  String get fullSetup => 'Úplné nastavenie';

  @override
  String get general => 'generál';

  @override
  String get generalSettings => 'Všeobecné nastavenia';

  @override
  String get generalSettingsSaved => 'Všeobecné nastavenia boli uložené.';

  @override
  String get generateAPromptForAnotherAi =>
      'Vygenerujte výzvu pre inú AI, sem vložte odpoveď na import pamätí.';

  @override
  String get generatePrompt => 'Generovať výzvu';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Chyba sledovania geofence: $arg1';
  }

  @override
  String get getInspired => 'Nechajte sa inšpirovať';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot a OpenAI Codex';

  @override
  String get githubIssueOpened => 'Problém GitHub otvorený';

  @override
  String get neorecallMemoryCreated => 'Pamäť NeoRecall bola vytvorená';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Kontrola vydania GitHub zlyhala s HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Užitočné zaťaženie vydania GitHub nebolo zoznamom vydaní.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Používateľské meno GitHub, ktoré otvorilo problém';

  @override
  String get globalSecurityMode => 'Globálny bezpečnostný režim';

  @override
  String get gmailMessageReceived => 'Správa Gmail bola prijatá';

  @override
  String get good => 'Dobre';

  @override
  String get goodAfternoon => 'Dobré popoludnie';

  @override
  String get goodEvening => 'Dobrý večer';

  @override
  String get goodMorning => 'Dobré ráno';

  @override
  String get goodPasswordALittleMoreLength =>
      'Dobré heslo. Trochu väčšia dĺžka ho robí silnejším.';

  @override
  String get googleChat => 'Rozhovor Google';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live používa váš kľúč OpenAI API, Gemini Live váš kľúč AI Google. Zmeny sa použijú na nasledujúci hovor.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Pred synchronizáciou udeľte povolenia Health Connect.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Skupina, kanál alebo miestnosť';

  @override
  String get groupType => 'Typ skupiny';

  @override
  String get groupsAndChannels => 'Skupiny a kanály';

  @override
  String groupsArg1(Object? arg1) {
    return 'Skupiny: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Skupiny, ktoré $arg1 ešte nevidel, budú nasledovať.';
  }

  @override
  String get handlesDirectTasksItself => 'Zvláda priame úlohy sám';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Hands-free (hovorte voľne, prerušte kedykoľvek)';

  @override
  String get headerName => 'Názov hlavičky';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Titulky na témy, ktoré vás zaujímajú, filtrované podľa signálu.';

  @override
  String get health => 'Zdravie';

  @override
  String get healthChecks => 'Zdravotné prehliadky';

  @override
  String get healthConnect => 'zdravie pripojiť';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect nie je na tomto zariadení k dispozícii.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Stav synchronizácie Health Connect a uložené backendové metriky.';

  @override
  String get healthStatusIsUnavailable => 'Zdravotný stav je nedostupný.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Synchronizácia aplikácie Health je k dispozícii iba v systéme Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Záznamy srdca $arg1';
  }

  @override
  String get heldBack => 'Zadržané';

  @override
  String get helper => 'Pomocník';

  @override
  String helperArg1(Object? arg1) {
    return 'Pomocník: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'tu. Najprv odvolajte správcu pomocou `neoagent admin revoke $arg1`.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Vyššie hodnoty robia NeoAgent selektívnejším v skupinách.';

  @override
  String get highlyRecommended => 'Vrelo odporúčame';

  @override
  String get holdButton131ForTheAssistant =>
      'Podržte tlačidlo 131 pre asistenta.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Ak chcete hovoriť, podržte kombináciu klávesov Ctrl+Shift+Space';

  @override
  String get holdToTalk => 'Vydržte a rozprávajte sa.';

  @override
  String get holdToTalk2 => 'Vydržte a rozprávajte sa';

  @override
  String get home => 'Domov';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Vyžaduje sa dlhotrvajúci prístupový token Home Assistant.';

  @override
  String get homeAssistantSetup => 'Nastavenie domáceho asistenta';

  @override
  String get homeAssistantUrl => 'Adresa URL domáceho asistenta';

  @override
  String get homeAssistantUrlIsRequired =>
      'Vyžaduje sa webová adresa domáceho asistenta.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Token domáceho servera s prieskumom miestnosti';

  @override
  String get homeserverUrl => 'Adresa URL domáceho servera';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'hosťovaná služba). Vaše kľúče sú zašifrované a môžu ich používať iba používatelia ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Názov hostiteľa siete IRC, napríklad irc.libera.chat';

  @override
  String get hourly => 'Každú hodinu';

  @override
  String get hourlyInboxCheck => 'Hodinová kontrola doručenej pošty';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Ako dlho zostávajú v platnosti potvrdzovacie odkazy.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Ako často tento agent hľadá nové správy o miestnosti.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Ako často tento agent hľadá nové správy Signal.';

  @override
  String get howTeamsWork => 'Ako fungujú tímy';

  @override
  String get howThisServerIsReachedPlus =>
      'Ako je dosiahnutý tento server, plus prepínače na celom serveri.';

  @override
  String get httpsSessionCookie => 'súbor cookie relácie https';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Momentálne som nemohol dokončiť túto požiadavku. Skúste to znova o chvíľu.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Nečinný';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Ak $arg1 požaduje webovú adresu webhooku, prilepte ju, aby sa správy dostali na $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Ak má tento účet potvrdený e-mail, NeoAgent odošle odkaz na obnovenie hesla.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Ak služba vyžaduje token pri odchádzajúcich požiadavkách.';

  @override
  String get ignoreGroups => 'Ignorovať skupiny';

  @override
  String get ignoreThisChat => 'Ignorovať tento rozhovor';

  @override
  String get ignoredChannels => 'Ignorované kanály';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Ignorovaná chybná sprievodná správa na pracovnej ploche: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Implementujte vyššie uvedený plán.';

  @override
  String get implementThisPlan => 'Implementujte tento plán';

  @override
  String get implicitTls => 'Implicitné TLS';

  @override
  String get import => 'Importovať';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Import zlyhal: $arg1';
  }

  @override
  String get importFromComputer => 'Importovať z počítača';

  @override
  String get importMemoryTransfer => 'Importovať prenos pamäte?';

  @override
  String get importance => 'Dôležitosť';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Importované pamäte $arg1, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'V tíme @$arg1';
  }

  @override
  String get inBackground => 'pozadia';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Tu sa zobrazia prichádzajúce a odchádzajúce správy kanála.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Prichádzajúce hlasové hovory v aplikácii od NeoAgent';

  @override
  String get incomingMessages => 'Prichádzajúce správy';

  @override
  String get incomingNeoagentCall => 'Prichádzajúci hovor NeoAgent';

  @override
  String get incomingNeoagentCall2 => 'PRICHÁDZAJÚCI HOVOR NEOAGENT';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Prichádzajúci webhook a podpora spätného volania';

  @override
  String get incorporatingSteering => 'Zahŕňa riadenie';

  @override
  String get input => 'Vstup';

  @override
  String get inputMode => 'Vstupný režim';

  @override
  String get insertATemplate => 'Vložte šablónu';

  @override
  String get install => 'Inštalovať';

  @override
  String get installASignedSelfContainedRuntime =>
      'Nainštalujte podpísaný, samostatný runtime. Príkazy Node.js, npm, Git a terminálu sa nevyžadujú.';

  @override
  String get installApk => 'Nainštalujte súbor APK';

  @override
  String get installApkBundle => 'Nainštalujte súbor APK / balík';

  @override
  String get installApkClickOrDropA =>
      'Inštalovať súbor APK – kliknite alebo pustite súbor .apk';

  @override
  String get installNeoagent => 'Nainštalujte NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Nainštalujte NeoAgent na tento počítač bez terminálu alebo sa pripojte k už spustenému.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Nainštalujte nové vydania a vyberte kanál, ktorý tento server sleduje.';

  @override
  String get installTheBackend => 'Nainštalujte backend';

  @override
  String get installTheCoreWithExtraOptional =>
      'Nainštalujte jadro s dodatočným voliteľným nastavením. Kľúče poskytovateľa AI sa pridajú neskôr, rovnako ako Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Nainštalujte zabezpečené jadro a potom si vytvorte účet. Potom pridajte kľúče poskytovateľa AI.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Nainštalované: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Nainštalované: $arg1 • Posledná kontrola: $arg2';
  }

  @override
  String get instructions => 'Pokyny';

  @override
  String get integration => 'integrácia';

  @override
  String get integrationConnections => 'Integračné spojenia';

  @override
  String get integrationSettingsSaved => 'Nastavenia integrácie boli uložené.';

  @override
  String get integrations => 'integrácií';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrácie/oauth/spätné volanie a zaregistrujte to isté ';

  @override
  String get interruptAi => 'Prerušiť AI';

  @override
  String get invalid2fa => 'neplatný 2fa';

  @override
  String get invalidArgumentS => 'Neplatné argumenty: ';

  @override
  String get invalidCredentials => 'neplatné poverenia';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Neplatný runtime manifest NeoAgent.';

  @override
  String get inviteLink => 'Odkaz na pozvánku';

  @override
  String get inviteLinkReady => 'Odkaz na pozvánku je pripravený';

  @override
  String get inviteLinks => 'Odkazy na pozvanie';

  @override
  String get iphoneApp => 'aplikácia pre iPhone';

  @override
  String get issues => 'Problémy';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Problémy sa objavia po načítaní denníka.';

  @override
  String get itCanTBeUndone => 'Nedá sa vrátiť späť.';

  @override
  String get itMayHaveBeenDeleted => 'Možno bol odstránený.';

  @override
  String get javaRuntime => 'Java runtime';

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
    return 'Pripojil sa k $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Pripojené za posledných 7 dní';

  @override
  String get joiningATeam => 'Vstup do tímu';

  @override
  String get joiningIsOffHere => 'Tu je spájanie vypnuté';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Pole JSON, ktoré obsahuje text správy. Zvyčajne text.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Pole JSON, ktoré identifikuje, komu je správa určená.';

  @override
  String get jumpToLatest => 'Prejsť na najnovšie';

  @override
  String get justNow => 'práve teraz';

  @override
  String get keepNeoagentRunning => 'Nechať NeoAgent spustený?';

  @override
  String get keepRunning => 'Bež ďalej';

  @override
  String get keepTaskRunning => 'Udržujte úlohu spustenú';

  @override
  String get keepTheVaultAvailable => 'Nechajte k dispozícii trezor';

  @override
  String get keepThisLauncherUpToDate => 'Udržujte tento spúšťač aktuálny.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Nechajte tento panel otvorený, kým platforma nepotvrdí pripojenie.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Udržujte počítač tejto relácie viditeľný';

  @override
  String get keepTrackOfYourAiUsage =>
      'Sledujte svoje využitie AI. Limity sú presadzované, aby sa zabezpečilo spravodlivé používanie na celej platforme.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Pokračujte v používaní aplikácií normálne. NeoAgent pracuje na rovnakej obrazovke a pýta sa vždy, keď potrebuje nový prístup.\n\n';

  @override
  String get keepingThisDeviceConnected =>
      'Ponechanie tohto zariadenia pripojené';

  @override
  String get key => 'kľúč';

  @override
  String get keyIsRequired => 'Vyžaduje sa kľúč.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Páry kľúč – hodnota, ktoré pretrvávajú v konverzáciách.';

  @override
  String get knowledgeGraph => 'Knowledge Graph';

  @override
  String get knowledgeView => 'Vedomostný pohľad';

  @override
  String get labelOnlyYouSeeIt => 'Štítok (vidíte ho iba vy)';

  @override
  String get labelsOptional => 'Štítky (voliteľné)';

  @override
  String get last24Hours => 'Posledných 24 hodín';

  @override
  String get last7Days => 'Posledných 7 dní';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Posledných 7 dní: Tokeny $arg1 v behu $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Posledný $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Posledný: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Posledná synchronizácia bez vyprázdnenia · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Posledný chod: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Naposledy videný $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Posledné prihlásenie $arg1';
  }

  @override
  String get lastSyncSummary => 'Súhrn poslednej synchronizácie';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Naposledy použité: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Posledné okno skončilo $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'neskorší štart je tiež vypnutý.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Posledná séria · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Spúšťanie počítačových aplikácií nie je na tejto platforme podporované.';

  @override
  String get learnRoomNorms => 'Naučte sa normy miestnosti';

  @override
  String get leave => 'Odísť';

  @override
  String get leaveARedirectUriBlankTo =>
      'Ak chcete použiť <public URL>/api/, ponechajte pole URI presmerovania prázdne';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Opustiť tím $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Ponechajte ako predvolené, pokiaľ ste neprispôsobili BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Ak chcete zachovať aktuálne uložený token, nechajte token prázdny.';

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
    return 'Nechaj ma spravovať $arg1';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Nechajte všetkých v tejto skupine hovoriť so $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Nechajte to\nfungovať, kým nie.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Nechajte NeoAgent klikať, písať a pohybovať sa po vašich aplikáciách.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Nechajte NeoAgent pochopiť, čo je viditeľné na vašej obrazovke.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Nechajte niekoho, s kým spolupracujete, rozhodnúť, aké nástroje môže váš agent použiť ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Umožnite tejto osobe poslať $arg1 individuálnu správu.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Umožnite tejto osobe hovoriť so $arg1 tu, ale nie v súkromných chatoch alebo iných skupinách.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Umožnite tejto osobe hovoriť so $arg1 v súkromných rozhovoroch a v akejkoľvek skupine, ktorú zdieľa.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Úroveň $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Odkaz $arg1';
  }

  @override
  String get linkCopied => 'Odkaz bol skopírovaný';

  @override
  String get linkExpiresAfter => 'Platnosť odkazu vyprší po';

  @override
  String get linkLifetimeHours => 'Životnosť odkazu (hodiny)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Životnosť odkazu musí byť od 1 do 8760 hodín.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Odkaz platí do $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Prepojení poskytovatelia prihlásenia';

  @override
  String get linuxApp => 'Aplikácia pre Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Uvedené $arg1/';
  }

  @override
  String get listening => 'Počúvanie';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Živá história vykonávania, kroky nástroja a reakcie.';

  @override
  String get liveModel => 'Živý model';

  @override
  String get liveModelProvider => 'Poskytovateľ živého modelu';

  @override
  String get liveRun => 'Živý beh';

  @override
  String get liveVoice => 'Živý hlas';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Živé hlasové pripojenie nie je k dispozícii.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Živé hlasové pripojenie bolo uzavreté.';

  @override
  String get liveVoiceDefaults => 'Predvolené nastavenia živého hlasu';

  @override
  String get liveVoiceFailed => 'Živý hlas zlyhal.';

  @override
  String get llmMemoryExportResponse => 'Odpoveď na export pamäte LLM';

  @override
  String get loadFailed => 'načítanie zlyhalo';

  @override
  String get loadingExecutionDetails =>
      'Načítavajú sa podrobnosti o vykonaní...';

  @override
  String get loadingNeoagent => 'Načítava sa NeoAgent';

  @override
  String get loadingRunFlow => 'Načítava sa priebeh...';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Lokálne a súkromné adresy URL sú podporované, keď ich server NeoAgent dosiahne. Zvuk nie je nikdy vystavený pôsobeniu NeoAgent.';

  @override
  String get localApp => 'miestna aplikácia';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Lokálna backendová inštalácia nie je na tejto platforme dostupná.';

  @override
  String get localBaseImagePath => 'Cesta k miestnej základnej snímke';

  @override
  String get localComputerControlIsAvailableIn =>
      'Ovládanie miestneho počítača je k dispozícii v počítačovej aplikácii NeoAgent v systémoch macOS, Windows a Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Lokálne ovládanie počítača tu nie je dostupné.';

  @override
  String get localModelsUrl => 'webová adresa miestnych modelov';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Lokálne zisťovanie NeoAgent je dočasne nedostupné.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Miestne predvoľby pre aplikáciu NeoAgent. Ovládanie počítača vždy prebieha cez jednotný cloudový počítač.';

  @override
  String get localSetup => 'MIESTNE NASTAVENIE';

  @override
  String get locationCityOrPlace => 'Miesto (mesto alebo miesto)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Poloha je povinná pre spúšťače udalostí počasia';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Inicializácia LocationService zlyhala: $arg1';
  }

  @override
  String get logCopied => 'Denník bol skopírovaný';

  @override
  String get loginPassword => 'Prihlasovacie heslo';

  @override
  String get logout => 'Odhlásiť sa';

  @override
  String get logs => 'Denníky';

  @override
  String get logsCopied => 'Denníky boli skopírované.';

  @override
  String get logsOnThisComputer => 'Protokoly na tomto počítači';

  @override
  String get longLivedAccessToken => 'Dlhotrvajúci prístupový token';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Dlhodobé zapamätanie, štruktúrované fakty a znalostný graf.';

  @override
  String get lookedAtTheScreen => 'Pozrel na obrazovku';

  @override
  String get lookingOnThisComputerAndYour =>
      'Prezeráte si tento počítač a vašu miestnu sieť...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Pozerá dopredu na zajtrajšie stretnutia, takže vás nič neprekvapí.';

  @override
  String get loopExecution => 'Vykonanie slučky';

  @override
  String get loopPaused => 'Slučka pozastavená';

  @override
  String get macOsX => 'mac OS x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'Prístupnosť macOS nie je udelená NeoAgent. Povoľte to v Nastaveniach systému › Súkromie a zabezpečenie › Dostupnosť.';

  @override
  String get macosApp => 'aplikácia pre macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'Nahrávanie obrazovky macOS nie je udelené aplikácii NeoAgent. Povoľte to v Nastaveniach systému › Súkromie a zabezpečenie › Nahrávanie obrazovky a potom znova otvorte NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Poštové servery, ktoré potrebujú heslo, odmietnu odosielať, kým nebude nové ';

  @override
  String get main => 'Hlavné';

  @override
  String get makeDefault => 'Nastaviť ako predvolené';

  @override
  String get manage => 'Spravovať';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Spravujte e-mail svojho účtu, dvojfaktorové overenie a aktívne relácie.';

  @override
  String get managedBy => 'Spravuje';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Manažéri môžu mať vlastných manažérov (až do štyroch úrovní). A ';

  @override
  String get managing => 'Riadenie';

  @override
  String get manualDestination => 'Manuálny cieľ';

  @override
  String get manualTrigger => 'Manuálny spúšťač';

  @override
  String get masterPassword => 'Hlavné heslo';

  @override
  String get matchThisDevice => 'Priraďte toto zariadenie';

  @override
  String get matchedAgainstTitleAndBody => 'Zápas proti názvu a telu';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Zodpovedá starému toku NeoAgent MCP: URL plus auth metóda.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'server MCP';

  @override
  String get mcpServer2 => 'Server MCP';

  @override
  String get mcpServerUrl => 'Adresa URL servera MCP';

  @override
  String get mcpServers => 'servery MCP';

  @override
  String get meantForSomeoneElse => 'Určené pre niekoho iného';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Namerané náklady modelu: $arg1';
  }

  @override
  String get memories => 'Spomienky';

  @override
  String get memory => 'pamäť';

  @override
  String memoryArg1(Object? arg1) {
    return 'Pamäť: $arg1';
  }

  @override
  String get memoryInjected => 'Vložená pamäť';

  @override
  String get mentionOrReplyOnly => 'Len spomeňte alebo odpovedzte';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Zlúčené protokoly servera a Flutter runtime pre túto reláciu aplikácie.';

  @override
  String get messageBodyTemplateJson => 'Šablóna tela správy (JSON)';

  @override
  String get messageNeedsAccess => 'Správa vyžaduje prístup';

  @override
  String get messageTextField => 'Textové pole správy';

  @override
  String get messaging => 'Správy';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Udalosti push a webhook rozhrania Messaging API';

  @override
  String get messagingConnectionNeedsAttention =>
      'Pripojenie správ vyžaduje pozornosť';

  @override
  String get messagingConnections => 'Pripojenia správ';

  @override
  String get messagingDelivery => 'Doručovanie správ';

  @override
  String get messagingErrorPleaseTryAgain => 'Chyba správ. Skúste to znova.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Snímanie mikrofónom sa neočakávane zastavilo. Skúste to znova.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Chyba mikrofónu: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofón je stlmený. Klepnutím zapnete zvuk.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Pre živý hlas sa vyžaduje povolenie mikrofónu.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimálna hodnota príspevku: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Nastavenie mobilu zlyhalo.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Nastavenie mobilného zariadenia zlyhalo, pretože Java nie je dostupná na počítači so systémom NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Nastavenie mobilného zariadenia zlyhalo, pretože Java nie je dostupná na počítači so systémom NeoAgent. Nainštalujte JDK a skúste to znova.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Nastavenie mobilu zlyhalo. Skontrolujte, či sú správne nainštalované nástroje Android a skúste to znova.';

  @override
  String modeArg1(Object? arg1) {
    return 'režim: $arg1';
  }

  @override
  String get modeLocksWhileARunIs => 'Režim sa uzamkne, keď je beh aktívny.';

  @override
  String get model => 'Model';

  @override
  String modelArg1(Object? arg1) {
    return 'Model: $arg1';
  }

  @override
  String get modelAvailability => 'Dostupnosť modelu';

  @override
  String get modelAvailabilitySaved => 'Dostupnosť modelu bola uložená.';

  @override
  String get modelForThisSession => 'Model pre túto reláciu';

  @override
  String get modelOverride => 'Prepísanie modelu';

  @override
  String get modelPending => 'Model čaká na spracovanie';

  @override
  String get modelTurn => 'Modelový obrat';

  @override
  String get modelTurnCompleted => 'Otáčanie modelu dokončené';

  @override
  String get modelTurnStarted => 'Modelová zákruta začala';

  @override
  String get modelVisibilityHideShowList => 'viditeľnosť modelu skryť zoznam';

  @override
  String get models => 'Modelky';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modely, správanie, hlas a pracovný priestor';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modely, prehliadač, hlas, diagnostika...';

  @override
  String get modelsRouting => 'Modely a smerovanie';

  @override
  String get monthly => 'Mesačne';

  @override
  String get moreActions => 'Viac akcií';

  @override
  String get morningBriefing => 'Ranný brífing';

  @override
  String get mostUsedAgents => 'Najpoužívanejšie prostriedky';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Najpoužívanejšie modely v poslednom $arg1.';
  }

  @override
  String get mouseKeyboard => 'Myš a klávesnica';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove nie je na tejto platforme podporované.';

  @override
  String get mustBeReachableOnThePublic =>
      'Musí byť dostupný na verejnom internete -- lokálnom a ';

  @override
  String get n24Hours => '24 hodín';

  @override
  String get n2faOrRecoveryCode => '2FA alebo obnovovací kód';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA vyžaduje, aby bola v tomto nasadení NeoAgent nakonfigurovaná SESSION_SECRET.';

  @override
  String get n30Days => '30 dní';

  @override
  String get n365Days => '365 dní';

  @override
  String get n4HourLimitTokens => '4-hodinový limit (tokeny)';

  @override
  String get n4HourUsage => '4-hodinové použitie';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4h limit $arg1';
  }

  @override
  String get n7DayUsage => '7-dňové používanie';

  @override
  String get n7Days => '7 dní';

  @override
  String get n90Days => '90 dní';

  @override
  String get name => 'Meno';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnázov: New Skill\npopis: Opíšte, čo táto zručnosť robí\n---\nTu napíšte návod na túto zručnosť.\n';

  @override
  String get nameOfWhoeverMadeIt => 'meno toho, kto to urobil.';

  @override
  String get nameOptional => 'Meno (voliteľné)';

  @override
  String get nativeAndWebhookChannels => 'Natívne a webhookové kanály';

  @override
  String get naturalBubbles => 'Prírodné bubliny';

  @override
  String get nearbyNeoagentServers => 'Neďaleké servery NeoAgent';

  @override
  String get needANewAccountRegister =>
      'Potrebujete nový účet? Zaregistrujte sa';

  @override
  String get needAnIdea => 'Potrebujete nápad?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Potreba odpovedať · $arg1% hovoriť';
  }

  @override
  String get needsAttention => 'Vyžaduje pozornosť';

  @override
  String get needsInput => 'Vyžaduje vstup';

  @override
  String get neoagentApp => 'Aplikácia NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'Asistent NeoAgent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent nemohol skontrolovať dostupný backend runtime.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent nemohol dokončiť lokálne nastavenie.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent nemohol dokončiť lokálne nastavenie. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Informácie o ladení NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent nainštaluje najnovšiu verziu $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent je nainštalovaný a spustený.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent nie je nainštalovaný na tomto počítači.';

  @override
  String get neoagentIsReady => 'NeoAgent je pripravený';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent stále pracuje na úlohe. Ukončite hovor a získajte výsledok v chate, alebo tiež zrušte úlohu.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent mení vašu demonštráciu na prispôsobivý pracovný postup.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent čaká, kým používate pracovnú plochu.';

  @override
  String get neoagentIsWorking => 'NeoAgent funguje';

  @override
  String get neoagentLinuxComputer => 'Počítač NeoAgent Linux';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT POTREBUJE ROZHODNUTIE';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Sťahovanie programu NeoAgent runtime vyžaduje zabezpečenú adresu.';

  @override
  String get neoagentServerAddress => 'Adresa servera NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'E-mail služby NeoAgent nie je pripravený. Požiadajte operátora servera, aby skontroloval nastavenia prostredia e-mailu.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Nastavenie NeoAgent sa nepodarilo dokončiť.';

  @override
  String get neoagentUser => 'Používateľ NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent používa tento počítač automaticky a pýta sa predtým, ako použije vašu obrazovku, myš, klávesnicu, súbory alebo príkazový riadok.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent používa vašu približnú polohu na pozadí na spustenie pripomienok geofence (napr. „Pripomenúť mi, že mám kúpiť mlieko, keď pôjdem okolo supermarketu“).\n\n';

  @override
  String get neoagentWorkspace => 'Pracovný priestor NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][hromada] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'Adresa URL backendu NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Vyžaduje sa koncová adresa URL NeoRecall.';

  @override
  String get neorecallSetup => 'Nastavenie NeoRecall';

  @override
  String get networkRequestFailed => 'sieťová požiadavka zlyhala';

  @override
  String get networkWriteRequests => 'Sieťové požiadavky na zápis';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'sa nikdy nezapočítava do limitov zdieľaného používania.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Nové účty pred prihlásením potvrďte svoju e-mailovú adresu.';

  @override
  String get newAccountsPerDay => 'Nové účty za deň';

  @override
  String get newChat => 'Nový chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Nové skupiny zostanú tiché, pokiaľ niekto neoznačí $arg1, kým ich nezapnete.';
  }

  @override
  String get newLink => 'Nový odkaz';

  @override
  String get newPasswordsDoNotMatch => 'Nové heslá sa nezhodujú.';

  @override
  String get newRecoveryCodes => 'Nové obnovovacie kódy';

  @override
  String get newSession => 'Nová relácia';

  @override
  String get newSessionN => 'Nová relácia (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Nová relácia s rovnakým nastavením';

  @override
  String get newSkill => 'Nová zručnosť';

  @override
  String get newSkill2 => 'Nová zručnosť';

  @override
  String get newThisWeek => 'Novinka tento týždeň';

  @override
  String get newsDigest => 'Prehľad správ';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Ďalší pokus: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Prihlasovací tok Nextcloud';

  @override
  String get nextcloudSetup => 'Nastavenie Nextcloud';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'Adresa URL Nextcloud';

  @override
  String get nextcloudUrlIsRequired => 'Vyžaduje sa adresa URL Nextcloud.';

  @override
  String get nickname => 'prezývka';

  @override
  String get noAccountsConnectedYet => 'Zatiaľ nie sú pripojené žiadne účty.';

  @override
  String get noAccountsFound => 'Nenašli sa žiadne účty.';

  @override
  String get noActiveSessionsFound => 'Nenašli sa žiadne aktívne relácie.';

  @override
  String get noAgentsYet => 'Zatiaľ žiadni agenti';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Nie je nakonfigurovaný žiadny poskytovateľ AI, takže chat a správy ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Žiadne výzvy na schválenie – agent beží bez prerušenia.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Tejto platforme nezodpovedá žiadny zdroj vydania $arg1.';
  }

  @override
  String get noArguments => '(žiadne argumenty)';

  @override
  String get noAuth => 'Žiadne overenie';

  @override
  String get noBindingsYet => 'Zatiaľ žiadne viazanie.';

  @override
  String get noChangesYet => 'Zatiaľ žiadne zmeny';

  @override
  String get noChannelsFound => 'Nenašli sa žiadne kanály';

  @override
  String get noCloudComputerSlotIsFree =>
      'Žiadny slot pre cloudový počítač nie je momentálne voľný. Skúste to znova o chvíľu.';

  @override
  String get noCoreMemoryEntriesYet =>
      'Zatiaľ žiadne položky základnej pamäte.';

  @override
  String get noDescription => 'Bez popisu';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Momentálne nie sú k dispozícii žiadne obrazovky pracovnej plochy.';

  @override
  String get noDetailAvailable => 'Nie sú k dispozícii žiadne podrobnosti';

  @override
  String get noDetailedSyncSummaryYet =>
      'Zatiaľ žiadne podrobné zhrnutie synchronizácie.';

  @override
  String get noDetailsCaptured => 'Žiadne zachytené detaily.';

  @override
  String get noEmailLinked => 'Nie je prepojený žiadny e-mail';

  @override
  String get noExternalSignInProvidersLinked =>
      'Nie sú prepojení žiadni poskytovatelia externého prihlásenia.';

  @override
  String get noGroupMessagesYet => 'Zatiaľ žiadne skupinové správy';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Zatiaľ neboli pridané žiadne osoby špecifické pre skupinu.';

  @override
  String get noGroupsAddedYet => 'Zatiaľ neboli pridané žiadne skupiny.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Zatiaľ sa nenašli žiadne skupiny. Keď $arg1 uvidí skupinovú správu, použite Nájsť nedávne rozhovory a zobrazia sa tu.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Zatiaľ sa nenašli žiadne skupiny. Keď $arg1 uvidí skupinovú správu, použite Nájsť posledné rozhovory.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Nevrátili sa žiadne údaje o zdravotnom stave.';

  @override
  String get noHealthSamplesStoredYet =>
      'Zatiaľ nie sú uložené žiadne zdravotné vzorky.';

  @override
  String get noHttpClientImplementationForThis =>
      'Žiadna implementácia klienta HTTP pre túto platformu.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Pre tento krok nebol zaznamenaný žiadny vstup ani výstup.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Tomuto vyhľadávaniu nezodpovedajú žiadne integrácie.';

  @override
  String get noLimit => 'Bez obmedzenia';

  @override
  String get noLocalPasswordIsSetYet =>
      'Zatiaľ nie je nastavené žiadne lokálne heslo. Vytvorte si ho, aby ste povolili prihlásenie pomocou používateľského mena/hesla.';

  @override
  String get noLogEntries => 'Žiadne záznamy denníka.';

  @override
  String get noMatchingSettings => 'Žiadne zodpovedajúce nastavenia';

  @override
  String get noMcpServersMatchThisSearch =>
      'Tomuto vyhľadávaniu nezodpovedajú žiadne servery MCP.';

  @override
  String get noMemoryEntriesFound => 'Nenašli sa žiadne položky pamäte.';

  @override
  String get noMemorySync => 'Žiadna synchronizácia pamäte';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Jednorazovo prečíta dôležité a odoslané e-maily za posledných 12 mesiacov, aby agent poznal vaše kontakty a projekty.';

  @override
  String get emailMemory => 'Pamäť z e-mailov';

  @override
  String get importNow => 'Importovať teraz';

  @override
  String get importOnConnect => 'Pri pripojení účtu importovať staršiu poštu';

  @override
  String get sweepStarting => 'Pripravuje sa…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Čítanie e-mailov · $done z $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Čítanie e-mailov · nájdených $count';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Učenie sa z e-mailov · $done z $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Posledný import: $emails e-mailov · $memories nových spomienok';
  }

  @override
  String get sweepNothingNew => 'Žiadne nové e-maily na import';

  @override
  String sweepFailed(String error) {
    return 'Import zlyhal: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return '\"$arg1\" nezodpovedá žiadny model.';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Pre túto jazdu nebola zaznamenaná žiadna požiadavka na model.';

  @override
  String get noModelsDiscoveredYet => 'Zatiaľ neboli nájdené žiadne modely';

  @override
  String get noModelsSelected => 'Nie sú vybraté žiadne modely';

  @override
  String get noModelsYet => 'Zatiaľ žiadne modely';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      's týmto poskytovateľom nie je prepojený žiadny účet neoagent';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Pre tento počítač nie je k dispozícii žiadny backendový runtime NeoAgent.';

  @override
  String get noNetworkConnection => 'Žiadne sieťové pripojenie';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Žiadne sieťové pripojenie. Pripojte sa a pokračujte v používaní NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Žiadne sieťové pripojenie. Ak chcete skontrolovať aktualizácie, znova sa pripojte.';

  @override
  String get noOne => 'Nikto';

  @override
  String get noOneAddedYet => 'Zatiaľ nikto nepridal.';

  @override
  String get noOneCanMessage => 'Nikto nemôže posielať správy';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Nebol nájdený žiadny iný server NeoAgent. Môžete znova hľadať alebo zadať adresu ručne.';

  @override
  String get noPeopleAddedYet => 'Zatiaľ nie sú pridaní žiadni ľudia.';

  @override
  String get noPlatformsMatch => 'Žiadne platformy sa nezhodujú';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Zatiaľ nie sú k dispozícii žiadni poskytovatelia na konfiguráciu.';

  @override
  String get noRecentChannelActivity => 'Žiadna nedávna aktivita kanála';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Žiadne výsledky pre \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Žiadne jazdy v tomto rozsahu.';

  @override
  String get noRunsMatchTheseFilters => 'Týmto filtrom nevyhovujú žiadne jazdy';

  @override
  String get noRunsYet => 'Zatiaľ žiadne behy';

  @override
  String get noRunsYet2 => 'Zatiaľ žiadne behy.';

  @override
  String get noSecurityKeyWasProvided =>
      'Nebol poskytnutý žiadny bezpečnostný kľúč.';

  @override
  String get noServerUrlSet => 'Nie je nastavená žiadna adresa URL servera';

  @override
  String get noSessionMatchesThatSearch =>
      'Tomuto vyhľadávaniu nezodpovedá žiadna relácia.';

  @override
  String get noSessionsYet => 'Zatiaľ žiadne relácie';

  @override
  String get noSkillsMatchTheseFilters =>
      'Týmto filtrom nezodpovedajú žiadne zručnosti.';

  @override
  String get noStepsWereRecordedForThis =>
      'Pre tento beh neboli zaznamenané žiadne kroky.';

  @override
  String get noSummaryAvailable => 'Nie je k dispozícii žiadny súhrn.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Žiadne úlohy pre $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Žiadny nástroj nezodpovedá \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Nie je spustená žiadna aktualizácia';

  @override
  String get noUsageYet => 'Zatiaľ bez použitia.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Zatiaľ nie je k dispozícii žiadny overený backendový modul NeoAgent.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Nikto ho už nemôže používať. Ľudia, ktorí sa už pripojili ';

  @override
  String get none => 'žiadne';

  @override
  String get notApprovedYet => 'zatiaľ neschválené';

  @override
  String get notAuthenticated => 'neoverené';

  @override
  String get notCheckedYet => 'Zatiaľ nekontrolované';

  @override
  String get notConfigured => 'Nie je nakonfigurované';

  @override
  String get notConnected => 'Nepripojené';

  @override
  String get notConnected2 => 'Nepripojené';

  @override
  String get notInstalled => 'Nie je nainštalované';

  @override
  String get notNeeded => 'Nie je potrebné';

  @override
  String get notNeededEnough => 'Nie je to dosť potrebné';

  @override
  String get notNow => 'Teraz nie';

  @override
  String get notNow2 => 'Teraz nie';

  @override
  String get notSet => 'Nie je nastavené';

  @override
  String get notSetUp => 'Nie je nastavené';

  @override
  String get notTheSameAsAdmin => 'Nie to isté ako admin';

  @override
  String get nothingFound => 'Nič sa nenašlo';

  @override
  String get nothingHereYet => 'Zatiaľ tu nič nie je.';

  @override
  String get nothingHereYet2 => 'Zatiaľ tu nič nie je';

  @override
  String get nothingMatches => 'Nič sa nezhoduje';

  @override
  String get nothingStoredYet => 'Zatiaľ nie je nič uložené.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'ID klienta OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'ID klienta oauth tajný kľúč api presmerovania';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth ID klienta tajné presmerovanie gmail kalendár disk';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Spustenie protokolu OAuth nie je na tejto platforme podporované.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'tajné ID klienta klienta oauth outlook';

  @override
  String get oauthToken => 'Token OAuth';

  @override
  String get oauthWithPkce => 'OAuth s PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'z $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'svojich vlastných. Po uložení sa už nikdy nezobrazí.';

  @override
  String get off => 'Vypnuté';

  @override
  String get officialIntegration => 'Oficiálna integrácia';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Oficiálna integrácia nevrátila webovú adresu pripojenia.';

  @override
  String get on => 'Zapnuté';

  @override
  String get onASignedInAndroidDevice =>
      'Na prihlásenom zariadení s Androidom otvorte Nastavenia › Prihlásenie a zabezpečenie, naskenujte tento kód a schváľte prihlásenie.';

  @override
  String get onByDefaultForNewGroups => 'Predvolene zapnuté pre nové skupiny';

  @override
  String get onDemand => 'On Demand';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Zapnuté pre $arg1 skupín $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'na. Znova sa môžu pripojiť iba pomocou nového odkazu na pozvánku.';

  @override
  String get onYourOwnTheDefault => 'Na vlastnú päsť (predvolené)';

  @override
  String get once => 'Raz';

  @override
  String get oneIsSavedOtherChangesIn =>
      'jeden je zachránený. Ostatné zmeny v tomto formulári sa tiež uložia.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Platnosť jedného alebo viacerých účtov vypršala. Ak chcete obnoviť prístup k nástroju, znova pripojte príslušný účet.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Jeden runtime riadi osobu, skupinové poradie, pamäť miestnosti, normy, teóriu mysle a doručenie.';

  @override
  String get oneTimeRun => 'Jednorazový beh';

  @override
  String get onlyApkOrApksFilesCan =>
      'Je možné nainštalovať iba súbory .apk alebo .apks.';

  @override
  String get onlyInThisGroup => 'Len v tejto skupine';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Potrebné iba v prípade, že služba požaduje ďalšie hlavičky HTTP.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Potrebné iba vtedy, ak chcete zmeniť tvar odchádzajúceho užitočného zaťaženia.';

  @override
  String get onlyTheyCanChangeIt => 'Len oni to môžu zmeniť.';

  @override
  String get open => 'Otvorte';

  @override
  String get openAccountSettingsOnASigned =>
      'Otvorte Nastavenia › Prihlásenie a zabezpečenie na prihlásenom zariadení so systémom Android, naskenujte tento kód a schváľte prihlásenie.';

  @override
  String get openComputer => 'Otvorte počítač';

  @override
  String get openDashboard => 'Otvorte palubnú dosku';

  @override
  String get openFolder => 'Otvoriť priečinok…';

  @override
  String get openInWorkbench => 'Otvoriť na pracovnom stole';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Otvorte NeoAgent a znova pripojte $arg1 na obnovenie správ.';
  }

  @override
  String get openTimeSettings => 'Otvoriť nastavenia času';

  @override
  String get openToAnyone => 'Otvorené pre kohokoľvek';

  @override
  String get openTrello => 'Otvorte Trello';

  @override
  String get openVoiceAssistant => 'Otvorte hlasového asistenta';

  @override
  String get openWiFiSettings => 'Otvorte nastavenia Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Otvorte pomocou predvolenej aplikácie';

  @override
  String get openaiCodex => 'Kódex OpenAI';

  @override
  String get openaiCompatible => 'kompatibilné s openai';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Endpoint kompatibilný s OpenAI (váš vlastný server alebo iný ';

  @override
  String openedArg1(Object? arg1) {
    return 'Otvorené $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Otváranie adries URL pre počítače nie je na tejto platforme podporované.';

  @override
  String get openingYourSavedDesktop => 'Otvára sa uložená plocha.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Otvára sa uložená plocha. Normálne spustenie trvá menej ako 10 sekúnd.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Voliteľné extra tajomstvo, ak chránite prichádzajúci webhook.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Voliteľné prepísanie, ak webová adresa webhooku nestačí.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Voliteľné tajomstvo na overenie prichádzajúcich udalostí četu.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Voliteľné tajomstvo na overenie prichádzajúcich udalostí.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Voliteľné tajomstvo na overenie prichádzajúcich udalostí iMessage.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Voliteľné tajomstvo na overenie prichádzajúcich udalostí LINE.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Voliteľné tajomstvo na overenie prichádzajúcich udalostí Mattermost.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Voliteľné tajomstvo na overenie prichádzajúcich udalostí Teams.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Voliteľné. Agent má už svoju osobnosť. Všetko, čo pridáte o tóne, sa navrství na jeho vrch, takže nikdy nebudete musieť definovať.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Voliteľné. Keď je nastavený, použije sa namiesto adresy URL.';

  @override
  String get orAnswerInYourOwnWords => 'Alebo odpovedzte vlastnými slovami';

  @override
  String get orBuildYourOwnTask => 'Alebo si vytvorte vlastnú úlohu';

  @override
  String get orContinueWith => 'alebo pokračovať s';

  @override
  String get orFiles => 'alebo súbory.';

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
  String get originNotAllowed => 'pôvod nie je povolený';

  @override
  String get outgoingMessage => 'Odchádzajúca správa';

  @override
  String get outgoingWebhookUrl => 'Odchádzajúca adresa URL webhooku';

  @override
  String get outlookEmailReceived => 'Prijatý e-mail programu Outlook';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Prepísať poznámky k správaniu z importu.';

  @override
  String get ownModel => 'vlastný model';

  @override
  String get packageName => 'Názov balíka';

  @override
  String get pairWithQrCode => 'Spárujte pomocou QR kódu';

  @override
  String get password => 'heslo';

  @override
  String get password2faAndActiveSessions => 'Heslo, 2FA a aktívne relácie';

  @override
  String get passwordCreated => 'Heslo bolo vytvorené.';

  @override
  String get passwordIsTooWeak => 'heslo je príliš slabé';

  @override
  String get passwordMin8 => 'heslo min 8';

  @override
  String get passwordOrApiKey => 'Heslo alebo kľúč API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Sila hesla: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Heslá sa nezhodujú.';

  @override
  String get pasteAKey => 'Prilepte kľúč.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Prilepte nový kľúč, ktorý nahradí $arg1';
  }

  @override
  String get pasteTheKey => 'Prilepte kľúč';

  @override
  String get pasteYourAccountToken => 'Prilepte token svojho účtu';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Nižšie prilepte svoj kľúč API $arg1. To je ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Cesta musí zostať vo vnútri NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Cesta musí zostať v priečinku pracovného priestoru.';

  @override
  String get pauseLiveUpdates => 'Pozastaviť živé aktualizácie';

  @override
  String get pauseTaskLoop => 'Pozastaviť slučku úloh';

  @override
  String get paused => 'Pozastavené';

  @override
  String peakArg1(Object? arg1) {
    return 'vrchol $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Ľudia v súkromných chatoch';

  @override
  String get perAccountRateLimits => 'Limity sadzieb na účet';

  @override
  String get perCategoryPermissions => 'Povolenia pre jednotlivé kategórie';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Zásady povolení pre jednotlivé nástroje, schvaľovacie brány a izolácia procesov pre spustenie shellu.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Vyžaduje sa povolenie: $arg1';
  }

  @override
  String get permissionsNeeded => 'Potrebné povolenia';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Povolenia. Nikto iný to nemôže zmeniť.';

  @override
  String get personOrChat => 'Osoba alebo chat';

  @override
  String get personaBehaviorNotes => 'Poznámky k správaniu osoby';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Osobný prístupový token pre robota Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Osobné kanály a priame podporné plochy.';

  @override
  String get personalSelfChat => 'Osobný vlastný rozhovor';

  @override
  String get phoneNumber => 'Telefónne číslo';

  @override
  String get pickARunFromTheList =>
      'Vyberte si beh zo zoznamu a pozrite si jeho kroky.';

  @override
  String get pickARunFromTheList2 =>
      'Vyberte si beh zo zoznamu naľavo a preskúmajte jeho tok.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Vyberte si z nedávnych rozhovorov $arg1 alebo sami pridajte osobu či skupinu.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Vyberte, ako $arg1 používa tento účet.';
  }

  @override
  String get pickOneToFillInThe =>
      'Vyberte jeden na vyplnenie úlohy. Všetko si potom môžete doladiť.';

  @override
  String get picksUpWhereYouLeftOff => 'Pokračujte tam, kde ste skončili';

  @override
  String get plan => 'Plán';

  @override
  String get planning => 'Plánovanie';

  @override
  String get platform => 'Platforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Vyberte si rozvrh.';

  @override
  String get pleaseEnterAFilename => 'Zadajte názov súboru.';

  @override
  String get pleaseEnterAKey => 'Zadajte kľúč.';

  @override
  String get pleaseEnterAPrompt => 'Zadajte výzvu.';

  @override
  String get pleaseEnterATaskName => 'Zadajte názov úlohy.';

  @override
  String get pleaseEnterTheMemoryContent => 'Zadajte obsah pamäte.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Zadajte, kedy sa má úloha spustiť.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Vyberte účet alebo zadajte platné ID pripojenia.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Nasmerujte NeoAgent na akékoľvek dokončenia chatu kompatibilné s OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Nasmerujte fotoaparát na kód zobrazený na odhlásenom zariadení. Schválenie zostáva na tomto telefóne.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env verejná adresa URL dôveryhodného servera proxy nasadenie bezpečných súborov cookie';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Prémiová automatizácia s plánovacími a integračnými spúšťačmi.';

  @override
  String get prepareQrCode => 'Pripravte si QR kód';

  @override
  String get preparingNeoagent => 'Pripravuje sa NeoAgent…';

  @override
  String get preparingNeoagent2 => 'Príprava NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Stlačte a podržte pre rýchle snímanie';

  @override
  String get pressKeysIsNotSupportedOn =>
      'stláčanie kláves nie je na tejto platforme podporované.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Lisované $arg1';
  }

  @override
  String get priceUnknown => 'Cena neznáma';

  @override
  String get primaryDisplay => 'Primárny displej';

  @override
  String get privateChat => 'Súkromný chat';

  @override
  String get privateChats => 'Súkromné rozhovory';

  @override
  String get privateChats2 => 'súkromné chaty';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Súkromné rozhovory: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Súkromné chaty $arg1 · skupiny $arg2';
  }

  @override
  String get privateChatsOnly => 'Iba súkromné rozhovory';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'adresy súkromnej siete nie sú povolené.';

  @override
  String get profileEmailAndPersonalData => 'Profil, e-mail a osobné údaje';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Vyzvať pred tým, ako NeoAgent zostane na systémovej lište.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Prompt cache: $arg1 cache tokeny ';
  }

  @override
  String get promptCopied => 'Výzva bola skopírovaná.';

  @override
  String get promptOrSchedule => 'promptne alebo naplánovať.';

  @override
  String get promptToPasteIntoAnotherAi => 'Výzva na vloženie do inej AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Prepojenie s poskytovateľom sa nepodarilo spustiť.';

  @override
  String get providerSignInCouldNotBe =>
      'Prihlásenie poskytovateľa sa nepodarilo spustiť.';

  @override
  String get providers => 'Poskytovatelia';

  @override
  String get providersEachAccountCanStillPick =>
      'Poskytovatelia; každý účet si stále môže vybrať svoj vlastný model v Nastaveniach. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Poskytovatelia, integrácie, hlasové a voliteľné funkcie je možné kedykoľvek dokončiť v nastaveniach.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Verejné otázky a vlákna žiadostí o stiahnutie, zodpovedané iba schváleným ľuďom.';

  @override
  String get publicUrl => 'Verejná adresa URL';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Verejná adresa URL a povolené zdroje';

  @override
  String get publicUrlOverride => 'Prepísanie verejnej adresy URL';

  @override
  String get pullsTogetherTheDayAhead => 'Ťahá deň dopredu';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'Prepojenie telefónu na základe QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR prihlásenie bolo dokončené, ale NeoAgent nemohol udržať reláciu. Skúste to znova.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'QR prihlásenie sa nepodarilo spustiť.';

  @override
  String get qrLoginRequestHasExpired =>
      'Platnosť žiadosti o prihlásenie qr vypršala';

  @override
  String get qrLoginRequestWasNotFound => 'qr žiadosť o prihlásenie sa nenašla';

  @override
  String get qrPairing => 'QR párovanie';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'spustené dopyty; všetko, čo napíše, je odmietnuté.';

  @override
  String get queryFilter => 'Dopyt / Filter';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Zaradené ako riadenie pre aktuálnu jazdu: $arg1';
  }

  @override
  String get quickstart => 'Rýchly štart';

  @override
  String get quit => 'Ukončite';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, wind_alert';

  @override
  String get ranAScriptInThePage => 'Spustil skript na stránke';

  @override
  String ranArg1(Object? arg1) {
    return 'Nabehol $arg1';
  }

  @override
  String get rateLimits => 'Sadzobné limity';

  @override
  String get readAnArtifact => 'Prečítajte si artefakt';

  @override
  String get readAndEditFilesInsideYour =>
      'Čítajte a upravujte súbory v priečinku NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Prečítajte si $arg1';
  }

  @override
  String get readError => 'Chyba čítania';

  @override
  String get readFiles => 'Čítať súbory';

  @override
  String get readOnly => 'Iba na čítanie';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Prečítajte si priečinok a zhrňte zásobník, vstupné body a ako ho spustiť.';

  @override
  String get readThePage => 'Prečítajte si stránku';

  @override
  String get readTheUiTree => 'Prečítajte si strom používateľského rozhrania';

  @override
  String get readWrite => 'Čítať / písať';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Číta kroky, srdcový tep, spánok, cvičenie a hmotnosť.';

  @override
  String get ready => 'Pripravený';

  @override
  String get readyForFirstTimeSetup => 'Pripravené na prvé nastavenie';

  @override
  String get readyToConnect => 'Pripravené na pripojenie';

  @override
  String get recentChannelActivity => 'Nedávna aktivita kanála';

  @override
  String get recentChats => 'Nedávne rozhovory';

  @override
  String get recentDecisions => 'Nedávne rozhodnutia';

  @override
  String get recentFailedRuns => 'Nedávne neúspešné behy';

  @override
  String get recentGroupDecisions => 'Nedávne skupinové rozhodnutia';

  @override
  String get recentRuns => 'Nedávne behy';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Nedávne jazdy trvajú približne $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Nedávny výstup zo servera, najnovšie ako prvé.';

  @override
  String get recentUsage4Hours => 'Nedávne použitie (4 hodiny)';

  @override
  String get recents => 'Nedávne';

  @override
  String get recipientField => 'Pole príjemcu';

  @override
  String get reconnectOrFinishSetup =>
      'Znova pripojte alebo dokončite nastavenie';

  @override
  String get reconnectingThisDevice => 'Opätovné pripojenie tohto zariadenia…';

  @override
  String get recurring => 'Opakujúce sa';

  @override
  String get redirectUri => 'Presmerovať URI';

  @override
  String get redoOnboarding => 'Zopakujte registráciu';

  @override
  String get refresh => 'Obnoviť';

  @override
  String get refreshCode => 'Obnoviť kód';

  @override
  String get refreshNow => 'Obnovte teraz';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Obnovte obrazovku Android a skúste to znova.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Odmietnuť odoslať, pokiaľ sa pripojenie neaktualizuje na TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'bez ohľadu na nižšie uvedené nastavenia pre jednotlivé kategórie.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Zaregistrujte $arg1 pre postup privolávania asistenta.';
  }

  @override
  String get registrationIsClosed => 'registrácia je uzavretá';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registrácia registrovať nové účty umožňujú registráciu';

  @override
  String get rejectInvalidTlsCertificates =>
      'Odmietnuť neplatné certifikáty TLS';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'uvoľnite a reštartujte. Pripojené aplikácie sa znova pripoja, keď budú späť.';

  @override
  String get releaseChannel => 'Uvoľnite kanál';

  @override
  String get releaseCommitBranchNode => 'uvoľniť uzol vetvy odovzdania';

  @override
  String get releaseWhenYouAreDone => 'Po dokončení uvoľnite.';

  @override
  String get reloadNow => 'Načítať znova';

  @override
  String get rememberThisChoice => 'Zapamätajte si túto voľbu';

  @override
  String get remove => 'Odstrániť';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Odstrániť „$arg1“ a jeho zaznamenané kroky z histórie spustenia?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Odstráňte \"$arg1\" z základnej pamäte.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Odstrániť kľúč $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'odstrániť vymazať používateľa gdpr';

  @override
  String get removeSmtpPassword => 'Odstráňte heslo SMTP';

  @override
  String get removeTheSmtpPassword => 'Chcete odstrániť heslo SMTP?';

  @override
  String get rename => 'Premenovať';

  @override
  String get renameSecurityKey => 'Premenujte bezpečnostný kľúč';

  @override
  String get renameSession => 'Premenovať reláciu';

  @override
  String get repairAndRetry => 'Opravte a skúste znova';

  @override
  String get repairDesktop => 'Oprava pracovnej plochy';

  @override
  String get repeat => 'Opakujte';

  @override
  String get repliesWhenTagged => 'Odpovedá pri označení';

  @override
  String get replyToAddress => 'Adresa pre odpoveď';

  @override
  String replyToArg1(Object? arg1) {
    return 'Odpovedzte na $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Úložisko musí byť vo formáte vlastník/úložisko.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Zopakujte chybu, ktorú popisujem, nájdite hlavnú príčinu a opravte ju regresným testom.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'požiadavka zlyhala s http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Požiadavka zlyhala s HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Požiadajte o povolenia';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Požiadavka na $arg1 zlyhala skôr, ako backend odpovedal.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Požadované $arg1';
  }

  @override
  String get requireStarttls => 'Vyžadovať STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Vyžaduje sa za HTTPS alebo TLS proxy. Platí po serveri ';

  @override
  String get requiredExampleBerlinDe => 'Povinné. Príklad: Berlín, DE';

  @override
  String get requiredFormatOwnerRepo => 'Povinné. Formát: vlastník/repo';

  @override
  String get reserveAssistantHotkey => 'Klávesová skratka Rezervovať asistenta';

  @override
  String get reset => 'Resetovať';

  @override
  String get resetPassword => 'Obnoviť heslo';

  @override
  String get resetView => 'Obnoviť zobrazenie';

  @override
  String get responsibilities => 'Zodpovednosti';

  @override
  String get restart => 'Reštartujte';

  @override
  String get restartToFinishTheUpdate =>
      ' Reštartovaním dokončíte aktualizáciu.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Obnovenie predchádzajúceho runtime NeoAgent';

  @override
  String get restrictDelegationTargets => 'Obmedziť ciele delegovania';

  @override
  String get result => 'Výsledok';

  @override
  String get resultDelivery => 'Doručenie výsledku';

  @override
  String get resultOneClickAddsOneYou =>
      'výsledok. Jedno kliknutie pridá jedno; môžete ho upraviť neskôr.';

  @override
  String get results => 'Výsledky';

  @override
  String get retry => 'Skúste to znova';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Opakovane použiteľné · použité $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Skontrolujte nepotvrdené zmeny';

  @override
  String get revoke => 'Odvolať';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Najprv odvolajte správcu pomocou `neoagent admin revoke $arg1`';
  }

  @override
  String get revokeThisLink => 'Odvolať tento odkaz?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Okno dávky miestnosti: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Pokračujte otočením';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'riadkov. Na zobrazenie pridajte klauzulu LIMIT alebo užšiu klauzulu WHERE ';

  @override
  String get rule => 'Pravidlo';

  @override
  String get run => 'Spustenie';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Spustite ľubovoľné príkazy na vašom počítači alebo virtuálnom počítači.';

  @override
  String get runAt => 'Run At';

  @override
  String get runCompleted => 'Beh dokončený';

  @override
  String get runFailed => 'Spustenie zlyhalo';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Spustite git diff, skontrolujte nepotvrdené zmeny na chyby a problémy so štýlom a zhrňte, čo nájdete.';

  @override
  String get runNotFound => 'Run not found';

  @override
  String get runNow => 'Spustiť teraz';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Spustite prichádzajúce osobné správy WhatsApp.';

  @override
  String get runQuery => 'Spustiť dotaz';

  @override
  String get runShellCommandsOrInstallApps =>
      'Spúšťajte príkazy shellu alebo inštalujte aplikácie na svojom zariadení so systémom Android.';

  @override
  String get runStarted => 'Beh začal';

  @override
  String get runStatus => 'Stav spustenia';

  @override
  String get runStopped => 'Beh zastavený';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Spúšťajte príkazy terminálu a otvárajte aplikácie alebo webové stránky.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Spustite tento server: účty, aktualizácie, poskytovatelia, konfigurácia ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Spustiť, keď príde zodpovedajúca správa Gmail.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Spustiť, keď príde zodpovedajúci e-mail programu Outlook.';

  @override
  String get runWhenANewIssueMatching =>
      'Spustiť, keď sa v úložisku otvorí nový problém zodpovedajúci vašim filtrom.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Spustiť, keď sa vytvorí nová pamäť NeoRecall zodpovedajúca vašim filtrom.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Spustite, keď na vaše zariadenie príde upozornenie.';

  @override
  String get runWhenASlackMessageMatches =>
      'Spustiť, keď sa správa Slack zhoduje s vybratým rozsahom.';

  @override
  String get runWhenATeamsChatMessage =>
      'Spustiť, keď chatová správa Teams zodpovedá vybratému rozsahu.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Spustiť, keď sa pre určité miesto predpovedajú nakonfigurované udalosti počasia.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'behať. Kým je ktorýkoľvek model vypnutý, modely, ktoré poskytovatelia pridávajú ';

  @override
  String get running => 'Prebieha';

  @override
  String runningArg1(Object? arg1) {
    return 'Beží $arg1';
  }

  @override
  String get runningTask => 'Spustená úloha';

  @override
  String get runningTool => 'Bežecký nástroj';

  @override
  String get runs => 'Spustenia';

  @override
  String get runsEveryDayAtTheSelected => 'Beží každý deň vo zvolenom čase.';

  @override
  String get runsFourTimesPerHour => 'Beží štyrikrát za hodinu.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— behy, správy, pamäte, integrácie, súbory a ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'behy, správy, spomienky, integrácie, súbory a relácie. ';

  @override
  String get runsMondayThroughFriday => 'Beží od pondelka do piatku.';

  @override
  String get runsOnSelectedWeekdays => 'Beží vo vybrané pracovné dni.';

  @override
  String get runsOncePerHour => 'Beží raz za hodinu.';

  @override
  String get runsOncePerMonthOnThe => 'Beží raz za mesiac vo vybraný deň.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Spustí sa iba vtedy, keď stlačíte Spustiť teraz.';

  @override
  String get runsPerDay => 'Beží za deň';

  @override
  String get runsPerDay30Days => 'Beží za deň (30 dní)';

  @override
  String get runsThatCompleted => 'Behy, ktoré boli dokončené';

  @override
  String get runsThisWeek => 'Beží tento týždeň';

  @override
  String get runsToday => 'Beží dnes';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Behy, nástroje, pamäť, plánovanie, zručnosti a MCP sú k dispozícii tu.';

  @override
  String get runsTwicePerHour => 'Beží dvakrát za hodinu.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Spustenia sa vrátia späť na kľúč zdieľaného servera pre $arg1, ak je nakonfigurovaný. Toto sa nedá vrátiť späť.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Runtime $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Doba chodu: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Nastavenia runtime s ktorými tento server začal. Upravte ich pod ';

  @override
  String get runtimeSetupRequired => 'Vyžaduje sa nastavenie runtime';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Verejný kľúč na podpisovanie runtime musí mať 32 bajtov.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Uložiť';

  @override
  String get saveATrelloApiKeyFor =>
      'Uložte kľúč Trello API pre tohto agenta a potom bezpečne pripojte jeden účet Trello. Token účtu je uložený na serveri a používa sa iba pre tohto agenta.';

  @override
  String get saveAccount => 'Uložiť účet';

  @override
  String get saveChanges => 'Uložiť zmeny';

  @override
  String get saveCloudComputerSettings =>
      'Uložte nastavenia cloudového počítača';

  @override
  String get saveConnect => 'Uložiť a pripojiť';

  @override
  String get saveDefaults => 'Uložiť predvolené nastavenia';

  @override
  String get saveDiagnosticReport => 'Uložiť diagnostickú správu';

  @override
  String get saveEmail => 'Uložiť e-mail';

  @override
  String get saveEmailSettings => 'Uložiť nastavenia e-mailu';

  @override
  String get saveGeneralSettings => 'Uložte všeobecné nastavenia';

  @override
  String get saveName => 'Uložiť meno';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Uložiť diagnostiku nastavenia NeoAgent';

  @override
  String get saveOnly => 'Iba uložiť';

  @override
  String get saveSetup => 'Uložiť nastavenie';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Teraz si tieto obnovovacie kódy uložte. Už sa nebudú zobrazovať.';

  @override
  String get savedDeliveryDestination => 'Uložený cieľ doručenia';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Uložené limity sadzieb pre @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Naskenujte prihlasovací QR kód NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Naskenujte párovací QR kód NeoAgent z iného zariadenia a schváľte ho z tejto relácie spúšťača.';

  @override
  String get scanLoginQr => 'Naskenujte prihlasovací QR kód';

  @override
  String get scanPairingQr => 'Naskenujte párovací QR kód';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Naskenujte QR žiadosti o prihlásenie z odhlásených zariadení a schváľte ich z tejto overenej mobilnej relácie.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Skenovaním dokončite $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Skenujte pomocou NeoAgent vo svojom telefóne';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Skenuje nový e-mail a odošle vám ping iba vtedy, keď na niečom záleží.';

  @override
  String get schedule => 'Rozvrh';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'plánovaný čas. Po zmeraní jázd sa začne skôr.';

  @override
  String get screen => 'Obrazovka';

  @override
  String get screenAction => 'akcia na obrazovke';

  @override
  String get scrollIsNotSupportedOnThis =>
      'rolovanie nie je na tejto platforme podporované.';

  @override
  String get scrollToBottom => 'Prejdite nadol';

  @override
  String get search => 'Hľadať';

  @override
  String get search2 => 'Hľadať…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Hľadať v nastaveniach správcu (napr. SMTP, Ollama, denníky)';

  @override
  String get searchAgain => 'Hľadajte znova';

  @override
  String get searchByUsernameOrEmail =>
      'Hľadajte podľa používateľského mena alebo e-mailu';

  @override
  String get searchChannels => 'Vyhľadajte kanály';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Vyhľadajte nájdené kanály správ, kontakty, skupiny a nedávne konverzácie.';

  @override
  String get searchGroups => 'Hľadať skupiny';

  @override
  String get searchMemory => 'Vyhľadajte pamäť';

  @override
  String get searchModelsOrProviders =>
      'Vyhľadajte modely alebo poskytovateľov';

  @override
  String get searchModelsOrProviders2 => 'Hľadať modely alebo poskytovateľov…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Vyhľadajte nedávnych ľudí a skupiny';

  @override
  String get searchSessions => 'Vyhľadávacie relácie';

  @override
  String get searchSettings => 'Nastavenia vyhľadávania';

  @override
  String get searchTitleModelTriggerRunId =>
      'Vyhľadajte názov, model, spúšťač, ID spustenia';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Vyhľadávacie nástroje, integrácie a zručnosti';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Hľadaný kód pre \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Hľadané súbory pre \"$arg1\"';
  }

  @override
  String get secretField => 'Tajné pole';

  @override
  String get secureCookies => 'Zabezpečené súbory cookie';

  @override
  String get security => 'Bezpečnosť';

  @override
  String get securityKey => 'Bezpečnostný kľúč';

  @override
  String get securityKeyPromptWasDismissed =>
      'Výzva na bezpečnostný kľúč bola zrušená.';

  @override
  String get securityKeySignInCompletedBut =>
      'Prihlásenie pomocou bezpečnostného kľúča bolo dokončené, ale NeoAgent nemohol udržať reláciu prehliadača. Prihláste sa znova.';

  @override
  String get securityKeySignInCouldNot =>
      'Prihlásenie bezpečnostným kľúčom sa nepodarilo spustiť.';

  @override
  String get securityKeys => 'Bezpečnostné kľúče';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Bezpečnostné kľúče sú dostupné iba vo webovej aplikácii NeoAgent.';

  @override
  String get seeAll => 'Zobraziť všetky';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Pozrite sa, ktorý server NeoAgent toto okno používa, a spustite backend na tomto počítači.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'vidieť svoje používateľské meno a tieto nastavenia, nikdy nie svoje rozhovory, spomienky ';

  @override
  String get selectARun => 'Vyberte beh';

  @override
  String get selectASessionToSeeIts =>
      'Vyberte reláciu, aby ste videli jej počítač, súbory a zmeny.';

  @override
  String get selectAll => 'Vybrať všetko';

  @override
  String get selectAll2 => 'Vyberte možnosť Všetky';

  @override
  String selectArg1(Object? arg1) {
    return 'Vyberte $arg1';
  }

  @override
  String get selectTrigger => 'Vyberte možnosť Spustiť';

  @override
  String get send => 'Odoslať (⌘↵)';

  @override
  String get send2 => 'Odoslať';

  @override
  String get sendATaskFromChatAnd =>
      'Odošlite úlohu z chatu a tu sa zobrazí história jej vykonávania.';

  @override
  String get sendItToATeammateWith =>
      'pošlite ho spoluhráčovi s účtom na tomto serveri.';

  @override
  String get sendLink => 'Odoslať odkaz';

  @override
  String get sendPath => 'Odoslať cestu';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Posielajte požiadavky POST / PUT / DELETE na externé rozhrania API.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Pošlite tento odkaz iba osobe, pre ktorú je určený. Zobrazuje sa raz; ';

  @override
  String get senderAddress => 'Adresa odosielateľa';

  @override
  String get senderFilterOptional => 'Filter odosielateľa (voliteľné)';

  @override
  String get sentSharedAttachments => 'Odoslané zdieľané prílohy.';

  @override
  String get separateAccount => 'Samostatný účet';

  @override
  String get server => 'Server';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Predvolené nastavenie servera ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Predvolené nastavenia servera pre hlasové hovory v aplikácii. Hovory prebiehajú naživo ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'samotný server: účty, poskytovatelia a konfigurácia.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, prezývka, kanál a voliteľné TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'výstup servera konzola varovania chyby kopírovať';

  @override
  String get serverProviderCredentials => 'Poverenia poskytovateľa servera';

  @override
  String get serverUrl => 'Adresa URL servera';

  @override
  String get serverUsageLimitsDonTApply =>
      'Limity používania servera sa nevzťahujú na modely spustené na vašom vlastnom kľúči.';

  @override
  String get serviceEmail => 'Servisný email';

  @override
  String get serviceEmailIsNotConfigured =>
      'servisný e-mail nie je nakonfigurovaný';

  @override
  String get serviceEmailSmtp => 'Servisný e-mail (SMTP)';

  @override
  String get sessionActions => 'Akcie relácie';

  @override
  String get sessions => 'Relácie';

  @override
  String get sessions2 => 'SESSIONS';

  @override
  String get sessionsArePinnedToAFolder =>
      'Relácie sú pripnuté do priečinka a počítača. Začnite odtiaľto plánovať, stavať, testovať a odosielať.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      '(čl. 17 GDPR). Správcovské účty nie je možné odstrániť ';

  @override
  String get sessionsLogoutRevokeForce => 'sessions logout revoke force';

  @override
  String get setBlockAskAllowPerTool =>
      'Nastavte blokovanie / dopyt / povolenie podľa kategórie nástrojov alebo vyberte globálny režim.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Nastavte NeoAgent na tomto počítači';

  @override
  String get setUpOrConnectNeoagent => 'Nastavte alebo pripojte NeoAgent';

  @override
  String get setUrl => 'Nastaviť URL';

  @override
  String get settings => 'Nastavenia';

  @override
  String get settingsAndCannotBeUndone =>
      'nastavenia a nemožno ich vrátiť späť.';

  @override
  String get settingsArea => 'Oblasť nastavení';

  @override
  String get settingsAreas => 'Oblasti nastavení';

  @override
  String get setup => 'Nastavenie';

  @override
  String get setupDetails => 'Podrobnosti nastavenia';

  @override
  String get setupRequired => 'Vyžaduje sa nastavenie';

  @override
  String get setupWasCancelled => 'Nastavenie bolo zrušené.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Zdieľané prílohy z klienta NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Zdieľané z inej aplikácie';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Zdieľané kľúče poskytovateľa sú nakonfigurované na serveri. Ak chcete namiesto toho použiť vlastný kľúč API alebo vlastný koncový bod, prejdite do časti Rozšírené → Priniesť vlastný kľúč.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Zdieľané s chatom NeoAgent a jeho pamäťou.';

  @override
  String get shellCommands => 'Shell príkazy';

  @override
  String showAllArg1(Object? arg1) {
    return 'Zobraziť všetky $arg1';
  }

  @override
  String get showEarlier => 'Zobraziť skôr';

  @override
  String get showEveryStep => 'Ukážte každý krok';

  @override
  String get showTools => 'Zobraziť nástroje';

  @override
  String get showWorkbenchJ => 'Zobraziť pracovný stôl (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Zobrazuje sa prvý $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Zobrazuje sa na bočnom paneli. Ak chcete použiť svoje používateľské meno, nechajte prázdne.';

  @override
  String get signIn => 'Prihláste sa';

  @override
  String get signInCompletedButNeoagentCould =>
      'Prihlásenie bolo dokončené, ale NeoAgent nemohol udržať reláciu prehliadača. Prihláste sa znova. Ak sa to bude opakovať, skontrolujte nastavenia súborov cookie pre reláciu.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Prihlásenie bolo dokončené, ale NeoAgent nemohol udržať reláciu prehliadača. Prihláste sa znova. Ak sa to bude opakovať, súbor cookie pre reláciu na konci sa pravdepodobne neuchová.';

  @override
  String get signInToThisNeoagentServer =>
      'Pred naskenovaním párovacieho QR kódu sa prihláste na tento server NeoAgent.';

  @override
  String get signInWithAHardwareKey =>
      'Prihláste sa pomocou hardvérového kľúča alebo prístupového kľúča namiesto hesla. ';

  @override
  String get signInWithASecurityKey =>
      'Prihláste sa pomocou bezpečnostného kľúča';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Prihláste sa pomocou $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Schváľte NeoAgent vo svojom účte $arg1. Žiadny kľúč na kopírovanie.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Čaká sa na $arg1. Dokončite vo svojom prehliadači.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Prilepte kód $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Keď ste schválili NeoAgent, $arg1 zobrazil jednorazový kód. Prilepte to sem.';
  }

  @override
  String get signInCode => 'Prihlasovací kód';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Prihlásený pomocou $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Prihlásenie zlyhalo: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Prihláste sa pomocou rovnakého e-mailu a hlavného hesla, ktoré používate v Bitwardene. Hlavné heslo a dvojkrokový kód sa používajú iba na prihlásenie a nikdy sa neukladajú ani neodosielajú do AI.';

  @override
  String get signOut => 'Odhláste sa';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Odhlásiť sa @$arg1 všade?';
  }

  @override
  String get signOutEverywhere => 'Odhláste sa všade';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API most';

  @override
  String get signalCliServerUrl => 'adresa URL servera signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Odhlásili ste sa @$arg1 z každej relácie.';
  }

  @override
  String get signedInDevices => 'Prihlásené zariadenia';

  @override
  String get signedInWithin24Hours => 'Prihlásený do 24 hodín';

  @override
  String get signingSecret => 'Tajomstvo podpisu';

  @override
  String sinceArg1(Object? arg1) {
    return 'Od $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'od $arg1';
  }

  @override
  String get singleMessage => 'Jedna správa';

  @override
  String get singleUse => 'Jednorazové použitie';

  @override
  String get skill => 'Zručnosť';

  @override
  String get skillChanges => 'Zmeny zručností';

  @override
  String get skillContent => 'Obsah zručností';

  @override
  String get skills => 'Zručnosti';

  @override
  String get skip => 'Preskočiť';

  @override
  String get skipForNow => 'Zatiaľ preskočiť';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Preskočte túto úlohu skôr, ako zavolá model.';

  @override
  String get slackMessageReceived => 'Slack správa bola prijatá';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Relácie spánku $arg1';
  }

  @override
  String get smartSelector => 'inteligentný volič';

  @override
  String get smartSelector2 => 'Inteligentný volič';

  @override
  String get smartSelectorPool => 'Inteligentný výberový fond';

  @override
  String get smtpHost => 'Hostiteľ SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'Heslo odosielateľa pošty smtp tls potvrdzovacie upozornenia resetované';

  @override
  String get smtpPassword => 'heslo SMTP';

  @override
  String get smtpPort => 'SMTP port';

  @override
  String get smtpPortMustBeAWhole =>
      'Port SMTP musí byť celé číslo od 1 do 65535.';

  @override
  String get smtpUsername => 'Používateľské meno SMTP';

  @override
  String get soTheRunStartsThatMuch => 'takže beh začína oveľa skôr.';

  @override
  String get socialBehaviorOff => 'Sociálne správanie vypnuté';

  @override
  String get socialIntelligence => 'sociálnej inteligencie';

  @override
  String get socialIntelligence2 => 'Sociálna inteligencia';

  @override
  String get socialObservability => 'Sociálna pozorovateľnosť';

  @override
  String get socialReach => 'sociálny dosah';

  @override
  String get socialReach2 => 'Sociálny dosah';

  @override
  String get socialReach3 => 'Sociálny dosah';

  @override
  String get socialReachUpdated => 'Sociálny dosah bol aktualizovaný.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Agenti sociálnych zdrojov môžu čítať priamo, vrátane informačných kanálov, úložísk, Reddit, X, videí a trhových údajov podporovaných súbormi cookie.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Niečo sa pokazilo. Skúste to znova.';

  @override
  String get source => 'Zdroj';

  @override
  String get spaceOrChatIdUsedWhen =>
      'ID priestoru alebo chatu použité pri začatí konverzácie týmto agentom.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space webhook a podpora spätného volania aplikácie';

  @override
  String get speaking => 'Rozprávanie';

  @override
  String get speechToSpeechModelUsingThe =>
      'model reči na reč pomocou kľúča OpenAI alebo Google pod ';

  @override
  String get speechToText => 'Prevod reči na text';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Speech-to-text prepisuje hlasové poznámky a diktáty. Auto používa OpenAI, Gemini alebo Deepgram, podľa toho, čo má API kľúč. Model hlasovej odpovede je model rozhovoru, ktorý odpovedá na hlasové poznámky.';

  @override
  String get sqlConsole => 'SQL konzola';

  @override
  String get stable => 'Stabilný';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable nainštaluje najnovšie publikované vydanie backendu.';

  @override
  String get stackTrace => 'stopa zásobníka';

  @override
  String get standard => 'Štandardné';

  @override
  String get standardView => 'Štandardné zobrazenie';

  @override
  String get start => 'Štart';

  @override
  String get startASessionToPlanOr =>
      'Začnite reláciu na plánovanie alebo budovanie pomocou NeoAgent.';

  @override
  String get startAndroid => 'Spustite Android';

  @override
  String get startComputer => 'Spustite počítač';

  @override
  String get startFullSetup => 'Spustite úplné nastavenie';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Spustite nastavenie';

  @override
  String get startTalking => 'Začnite hovoriť';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Najskôr spustite telefón s Androidom a potom sem presuňte súbor .apk alebo .apks.';

  @override
  String get startTheServerLaterFromThe =>
      'Po uložení konfigurácie spustite server neskôr zo zoznamu.';

  @override
  String get startWithARecommendedTask => 'Začnite s odporúčanou úlohou';

  @override
  String get startingAndroid => 'Spustenie systému Android';

  @override
  String get startingYourComputer => 'Spustenie počítača';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Začína sa xoxb-. Z poverení aplikácie Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'StartTelecomCallRouting Chyba: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'štatistiky beží tokeny používatelia grafy úspešnosť';

  @override
  String get status => 'Stav';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'poskytovatelia stavu databázy runtime vm';

  @override
  String get statusIsNotLoadedYet => 'Stav ešte nie je načítaný.';

  @override
  String get stayManagedByYou => 'ostať spravovaný vami.';

  @override
  String get stayOnTheCall => 'Zostaňte v hovore';

  @override
  String get stayedQuiet => 'Zostal ticho';

  @override
  String get steering => 'RIADENIE';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'KROK $arg1 ZO $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Kroky $arg1';
  }

  @override
  String get stop => 'Zastaviť';

  @override
  String get stop2 => 'Zastaviť (⌘.)';

  @override
  String get stopManaging => 'Prestaňte spravovať';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Prestať spravovať $arg1?';
  }

  @override
  String get stopRun => 'Zastavte beh';

  @override
  String get stopSpeaking => 'Prestaň hovoriť';

  @override
  String get stoppedBeforeCompletion => 'Zastavené pred dokončením';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'StopTelecomCallRouting Error: $arg1';
  }

  @override
  String get storage => 'Skladovanie';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'uložené zašifrované a používané iba pre vaše vlastné behy.';

  @override
  String get storedMetrics => 'Uložené metriky';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Ukladá iba kľúč relácie Bitwarden zašifrovaný na tomto serveri, takže pripojenia prežijú reštarty. Môžete ho kedykoľvek uzamknúť.';

  @override
  String get strong => 'Silný';

  @override
  String get strongPassword => 'Silné heslo.';

  @override
  String get subAgent => 'Sub-agent';

  @override
  String get subagentUpdate => 'Aktualizácia subagenta';

  @override
  String get subagentUpdate2 => 'Aktualizácia subagenta.';

  @override
  String get successRate => 'Miera úspešnosti';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Návrhy: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Zhrňte môj posledný beh';

  @override
  String get supportUrl => 'URL podpory';

  @override
  String get supportedRainStartSnowStartWind =>
      'Podporované: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Prepnúť agenta';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'V cestách NeoAgent Workspace nie sú povolené symbolické odkazy.';

  @override
  String get syncNow => 'Synchronizovať teraz';

  @override
  String get synologyChat => 'Chat Synology';

  @override
  String get systemPrivacySettings =>
      'Nastavenia ochrany osobných údajov systému';

  @override
  String get tableInfoUsers => 'Informácie o tabuľke (používatelia)';

  @override
  String get tagsOnly => 'Iba značky';

  @override
  String get tasks => 'Úlohy';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Úlohy sa spúšťajú samy a posielajú vám správu s ';

  @override
  String get teach => 'Učiť';

  @override
  String get teachingInProgress => 'Vyučovanie prebieha';

  @override
  String get team => 'Tím';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Tímové odkazy nikdy nerobia z nikoho správcu servera. Správcovia spúšťajú ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Tímové priestory, miestnosti, kanály a živé komunity.';

  @override
  String get teamsMessageReceived => 'Správa tímov bola prijatá';

  @override
  String get templates => 'Šablóny';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Dočasné inštalačné súbory budú vyčistené neskôr.';

  @override
  String get tenantId => 'ID nájomcu';

  @override
  String get testConnection => 'Skúšobné pripojenie';

  @override
  String get testConnection2 => 'Test pripojenia';

  @override
  String get textChat => 'SMS a chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'ktorí pridali svoj vlastný kľúč, naďalej ho používajte.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Tento e-mail už patrí k existujúcemu účtu. Najprv sa prihláste a potom v nastaveniach účtu prepojte Google.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Tento e-mail je už prepojený s iným účtom.';

  @override
  String get thatQrCodeIsNotA =>
      'Tento QR kód nie je žiadosťou o prihlásenie NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Tento QR kód nie je žiadosťou o párovanie NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Tento bezpečnostný kľúč je už zaregistrovaný v tomto účte.';

  @override
  String get theAddress => 'Adresa';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Adresa vášho servera BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Adresa, ktorú ľudia a poskytovatelia OAuth používajú ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agent číta časy, ktoré spomínate, a spúšťa naplánované úlohy v tomto časovom pásme.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agent sa spýta pred každým citlivým nástrojom, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Agent bude túto zručnosť ignorovať.';

  @override
  String get theAppCouldNotReachThis =>
      'Aplikácii sa nepodarilo dosiahnuť toto nasadenie NeoAgent. Skontrolujte sieťové pripojenie alebo potvrďte správnosť adresy URL služby.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Prehliadač zablokoval požiadavku na $arg1 kvôli zásadám zabezpečenia obsahu.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Prehliadač zablokoval požadovanú požiadavku z dôvodu zásad zabezpečenia obsahu.';

  @override
  String get theCloudWorkspace => 'cloudový pracovný priestor';

  @override
  String get theComputerCouldNotStart => 'Počítač sa nepodarilo spustiť';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Počítač potrebuje viac voľného miesta na disku na hostiteľovi NeoAgent. Uvoľnite miesto a skúste to znova.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Runtime počítača potrebuje opravu. Spustite NeoAgent Doctor a skúste to znova.';

  @override
  String get theConnectionTestFailed => 'Test pripojenia zlyhal.';

  @override
  String get theDesktopDidNotStart => 'Pracovná plocha sa nespustila';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Objavený NeoAgent vrátil neúplné údaje o identite.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Objavený NeoAgent používa nepodporovaný protokol nastavenia.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Objavená služba nie je NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Stiahnutý runtime NeoAgent neprešiel overením.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Webhook priestoru pre rozhovor Google, na ktorý by mal tento agent uverejňovať príspevky.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Inštalátor už nie je k dispozícii.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Interaktívna plocha Linuxu je dostupná vo webovej aplikácii NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Úvod nie je na tomto zariadení k dispozícii.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Najnovšie beží cez každý účet.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Najnovšie okno synchronizácie ukončilo $arg1 a nenašlo žiadne nové záznamy Health Connect. Metriky uložené nižšie pochádzajú z predchádzajúcich synchronizácií.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Grafická relácia Linuxu nie je spustená.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Model živého hlasu neodpovedal. Skúste to znova.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Miestny príkaz NeoAgent skončil s kódom $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Časový limit lokálneho príkazu NeoAgent vypršal.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Miestny runtime NeoAgent potrebuje opravu.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Lokálny runtime potrebuje opravu ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Miestny domovský adresár používateľa je nedostupný.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'E-mailový účet NeoAgent odosiela potvrdenia o prihlásení a prihlásení ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Hlavný agent sa v prípade potreby vytvorí automaticky.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'V tomto vydaní chýba zodpovedajúci runtime NeoAgent.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Najdôležitejší prichádzajúci webhook, na ktorý by mal tento agent uverejňovať príspevky.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Modely, medzi ktorými Smart Selector prechádza automaticky.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Stiahnutie backendu NeoAgent nezodpovedalo jeho manifestu.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Sťahovanie backendu NeoAgent bolo neúplné.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Backend NeoAgent na tomto počítači neodpovedá na porte ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Backendový runtime NeoAgent sa nepodarilo stiahnuť.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Backendu NeoAgent trvalo príliš dlho, kým odpovedal $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Nasadenie NeoAgent odpovedalo pomocou HTTP 402 namiesto normálneho 401 pre neplatné poverenia. Skontrolujte reverzné proxy, autorizačnú bránu alebo pravidlá súvisiace s platbami na tomto serveri.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Nasadenie NeoAgent odpovedalo HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Nasadenie NeoAgent reagovalo s HTTP 402. Skontrolujte reverzné proxy, auth gateway alebo pravidlá súvisiace s platbami na tomto serveri.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Inštancia NeoAgent, ku ktorej je táto aplikácia pripojená.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Služba uvoľnenia NeoAgent vrátila neplatné údaje.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Metadáta artefaktu runtime NeoAgent sú neplatné.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Manifest runtime NeoAgent neprešiel overením podpisu.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Manifest spustenia NeoAgent neobsahuje žiadne artefakty.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Podpis runtime manifestu NeoAgent je neplatný.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Heslo, ktoré ste nastavili v BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Ľudia, ktorých riadite, zostávajú s vami.';

  @override
  String get theProviderAnswers => 'odpovie poskytovateľ.';

  @override
  String get theQueryReturnedNoRows => 'Dopyt nevrátil žiadne riadky.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Požadované zobrazenie pracovnej plochy nie je k dispozícii.';

  @override
  String get theRest => 'zvyšok.';

  @override
  String get theRestEndpointForYourSignal =>
      'Koncový bod REST pre vašu inštanciu signál-cli.';

  @override
  String get theRunIsPausedUntilYou => 'Beh je pozastavený, kým neodpoviete.';

  @override
  String get theRunStartsAtTheScheduled => 'Beh začína v plánovanom čase.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Runtime je ľahký desktop Debian Linux s prehliadačmi Chromium, PCManFM, Mousepad, LXTerminal, Python, Git a štandardnými nástrojmi príkazového riadku. Jeho kapacita je riadená hostiteľom NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Nepodarilo sa spustiť registráciu bezpečnostného kľúča.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'server uchováva iba jeho odtlačok prsta.';

  @override
  String get theServerOnThisComputerIs =>
      'Server na tomto počítači nie je spustený';

  @override
  String get theServerReportedNoHealthChecks =>
      'Server nehlásil žiadne zdravotné kontroly.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Telefónne číslo signálu, ktoré tento robot používa.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Prichádzajúci webhook Teams, do ktorého by mal tento agent prispievať.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Platnosť dvojfaktorovej výzvy vypršala. Prihláste sa znova.';

  @override
  String get theTwoFactorCodeIsNot => 'Dvojfaktorový kód nie je platný.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Overený balík runtime sa nepodarilo označiť ako spustiteľný.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'V overenom balíku runtime chýbajú požadované súbory.';

  @override
  String get theWebAppCouldNotReach =>
      'Webovej aplikácii sa nepodarilo dosiahnuť backend NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Webovej aplikácii sa nepodarilo dosiahnuť backend NeoAgent na $arg1. Skontrolujte konzolu prehliadača a konfiguráciu reverzného proxy/sieť.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'seba; operátor servera najskôr odstráni správcu pomocou ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Tieto kanály zostanú tiché. Ak si ich chcete znova vypočuť, pridajte ich do časti Kto môže posielať správy pre túto platformu.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Tieto zoznamy sú voliteľné, pokiaľ nie je sekcia vyššie nastavená ako iba schválená.';

  @override
  String get thesePeopleAnywhere => 'Títo ľudia, kdekoľvek';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Títo ľudia môžu posielať správy $arg1 v súkromných chatoch a v akejkoľvek skupine, ktorú zdieľajú.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Títo ľudia môžu posielať správy $arg1 medzi dvoma osobami. To im neumožňuje hovoriť v skupinách.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Títo ľudia môžu posielať správy iba $arg1 v skupine, ktorú ste vybrali.';
  }

  @override
  String get thesePeopleInOneGroup => 'Títo ľudia v jednej skupine';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'tieto prepínače, nikdy nie vaše chaty, spomienky alebo súbory.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Tento účet odomkne NeoAgent na tomto počítači.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Tento agent môže delegovať na ktoréhokoľvek oprávneného prijímajúceho agenta.';

  @override
  String get thisAgentIsUsingAServer =>
      'Tento agent používa kľúč rozhrania API Trello spravovaný serverom. Musíte iba autorizovať token účtu nižšie.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Táto zostava nemá povolené komunikovať s týmto nasadením NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Tento kód patrí inému serveru NeoAgent: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Táto pracovná plocha je pripojená';

  @override
  String get thisDevice => 'Toto zariadenie';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Toto zariadenie: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Toto zariadenie nemôže zaregistrovať bezpečnostné kľúče. Otvorte NeoAgent v prehliadači cez HTTPS a pridajte ho.';

  @override
  String get thisDeviceUnavailable => 'Toto zariadenie — nedostupné';

  @override
  String get thisFileHasNoContent => 'Tento súbor nemá žiadny obsah.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Toto skryje \"$arg1\" pred smerovaním a výberom.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Táto integrácia momentálne podporuje jeden pripojený účet na agenta. Znova otvorte nastavenie, aby ste ho nahradili.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Táto integrácia už nie je k dispozícii.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Tento úvod je určený na prehrávanie na šírku na celej obrazovke.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Toto je riadené nasadenie. Jeho operátor sa rozbehne ';

  @override
  String get thisMayTakeAMoment => 'Môže to chvíľu trvať.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Tento server MCP už nie je nakonfigurovaný.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Táto pamäť bude natrvalo odstránená.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Táto zostava NeoAgent nie je nakonfigurovaná na overenie backendových runtime.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Týmto sa natrvalo vymažú všetky vaše údaje a nie je to možné ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Týmto sa natrvalo vymaže účet a všetko, čo vlastní: ';

  @override
  String get thisPersonAnywhere => 'Táto osoba, kdekoľvek';

  @override
  String get thisPersonInOneGroup => 'Táto osoba v jednej skupine';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Platnosť tejto žiadosti o prihlásenie QR vypršala. Vygenerujte nový kód a skúste to znova.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'platnosť tejto žiadosti o prihlásenie qr vypršala';

  @override
  String get thisQrLoginRequestIsStill =>
      'Táto žiadosť o prihlásenie pomocou QR kódu stále čaká na schválenie.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Táto žiadosť o prihlásenie pomocou QR kódu už bola použitá.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Týmto sa odstráni nastavenie Home Assistant a pripojená inštancia pre tohto agenta.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Týmto sa odstráni koncová URL NeoRecall a všetky pripojené účty NeoRecall pre tohto agenta.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Týmto sa odstráni adresa URL Nextcloud a všetky pripojené účty Nextcloud pre tohto agenta.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Týmto sa odstráni nastavenie Trello a pripojené účty pre tohto agenta.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Vyžaduje si to overenú reláciu na rovnakom serveri NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Toto spustenie nevyvolalo odozvu zo strany používateľa.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Tento beh nemá žiadne zaznamenané údaje o kroku.';

  @override
  String get thisServer => 'tento server.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Tento server nehlási žiadne nastavenia poskytovateľa.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Táto zručnosť už nie je nainštalovaná.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Táto úloha ešte neskončila, takže stále začína na ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Táto úloha sa spustí iba vtedy, keď stlačíte Spustiť teraz.';

  @override
  String get thisWeek => 'Tento týždeň';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Toto naimportuje odpoveď do $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Týmto sa odstráni „$arg1“.';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Týmto sa odstráni \"$arg1\" zo zoznamu serverov.';
  }

  @override
  String get time => 'Čas';

  @override
  String get timeZone => 'časové pásmo';

  @override
  String get timeZone2 => 'Časové pásmo';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Časový limit vypršal$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Nie je možné uviesť časové pásma: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Nepodarilo sa prečítať časové pásmo zariadenia: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Nepodarilo sa uložiť časové pásmo zariadenia: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'do $arg1';
  }

  @override
  String get toUseTheServerDefault => 'použiť predvolené nastavenie servera.';

  @override
  String get today => 'Dnes';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Tokenový rozpočet pre @$arg1. Nechajte pole prázdne ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Tokenový rozpočet pre každý účet bez vlastného prepísania. Nechajte a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'limit rozpočtu tokenu 4-hodinová týždenná kvóta používateľa';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'token budget limit 4-hodinová týždenná kvóta globálne';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Použitie tokenu nie je na tejto verzii servera k dispozícii.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokeny môže použiť ktorýkoľvek účet do 4 hodín.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokeny, ktoré môže použiť ktorýkoľvek účet do 7 dní.';

  @override
  String get tokensPerDay => 'Tokeny za deň';

  @override
  String get tokensPerRun => 'Tokeny na beh';

  @override
  String get tokensToday => 'Tokeny dnes';

  @override
  String get tokensUsed => ' použité tokeny';

  @override
  String get tomorrowPrep => 'Zajtra príprava';

  @override
  String get tooManyAttempts => 'príliš veľa pokusov';

  @override
  String get tooManySignInAttemptsPlease =>
      'Príliš veľa pokusov o prihlásenie. Počkajte a skúste to znova.';

  @override
  String get tool => 'Nástroj';

  @override
  String get toolApproval => 'Schválenie nástroja';

  @override
  String get toolApprovalRequired => 'Vyžaduje sa schválenie nástroja';

  @override
  String get toolCompleted => 'Nástroj dokončený';

  @override
  String get toolFailed => 'Nástroj zlyhal';

  @override
  String get toolPermissions => 'Povolenia nástroja';

  @override
  String get toolStarted => 'Nástroj sa spustil';

  @override
  String get tools => 'Nástroje';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Nástroje, ktoré nie sú zabudované do NeoAgent, vrátane pripojených serverov MCP a vlastných poskytovateľov nástrojov.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Ponúkané nástroje ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Nástroje, ktoré môže spravovaný účet používať';

  @override
  String get topUsers => 'Najlepší používatelia';

  @override
  String get topUsersAndRecentRuns =>
      'Najlepší používatelia a posledné spustenia';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Celkom: tokeny $arg1 v rámci behu $arg2';
  }

  @override
  String get totalRuns => 'Celkový počet jázd';

  @override
  String get totalTokens => 'Celkový počet tokenov';

  @override
  String get totalUsers => 'Celkový počet používateľov';

  @override
  String get transcript => 'Prepis';

  @override
  String get transcript2 => 'PREPIS';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Prepis zlyhal: $arg1';
  }

  @override
  String get transfer => 'Prestup';

  @override
  String get trelloApiKey => 'Kľúč API Trello';

  @override
  String get trelloApiKeyIsRequired => 'Vyžaduje sa kľúč rozhrania API Trello.';

  @override
  String get trelloSetup => 'Nastavenie Trello';

  @override
  String get triggerType => 'Typ spúšťača';

  @override
  String get tryABroaderSearchLikeModels =>
      'Skúste širšie vyhľadávanie, napríklad modely, prehliadač alebo hlas.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Vyskúšajte názov poskytovateľa, „e-mail“, „limity“, „aktualizácia“ alebo „protokoly“.';

  @override
  String get tryAgain => 'Skúste to znova';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Skúste to znova. Ak sa to bude opakovať, spustite aplikáciu NeoAgent Doctor a skontrolujte beh počítača.';

  @override
  String get tryAgainInAMoment => 'Skúste to znova o chvíľu.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Skúste to znova alebo spustite NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Skúste iné vyhľadávanie, pripojte platformu na odosielanie správ alebo zadajte ID cieľa manuálne.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Zapnite skupinu, ak má $arg1 čítať aj správy, ktoré ju neoznačujú.';
  }

  @override
  String get turnOffComputer => 'Vypnite počítač';

  @override
  String get turnOffOnlyForAMail =>
      'Vypnite iba pre poštový server s certifikátom s vlastným podpisom.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Zapnite, ak má signál naďalej hľadať prichádzajúce rozhovory.';

  @override
  String get turnTaking => 'otočiť branie';

  @override
  String get turnTakingModel => 'Otáčavý model';

  @override
  String get turnTakingOff => 'Odbočenie';

  @override
  String get turnThisOffToKeepThis =>
      'Vypnite, aby bol tento agent úplne oddelený od ostatných agentov.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Vypnuté pomocou $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Vypnuté $arg1, ktorý spravuje tento účet. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Vypnuté pre vás $arg1 – zmeniť to môžu iba oni';
  }

  @override
  String get turnedOffForYouSoYou => 'Vypnuté, takže to nemôžete rozdávať';

  @override
  String get twitchChatOverIrc => 'Twitch chat cez IRC';

  @override
  String get twoFactorAuthentication => 'Dvojfaktorové overenie';

  @override
  String get twoFactorChallengeExpired => 'dvojfaktorová výzva vypršala';

  @override
  String get twoFactorCode => 'dvojfaktorový kód';

  @override
  String get twoFactorSignInCompletedBut =>
      'Dvojfaktorové prihlásenie bolo dokončené, ale NeoAgent nemohol udržať reláciu prehliadača. Prihláste sa znova.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Prihlásenie v dvoch krokoch (iba ak je povolené)';

  @override
  String get type => 'Typ';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Potvrďte zadaním $arg1';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'typ textu nie je na tejto platforme podporovaný.';

  @override
  String get typedInTheBrowser => 'Zadané v prehliadači';

  @override
  String get typedText => 'Napísaný text';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime => 'nedokáže nájsť modul Java runtime';

  @override
  String get unableToOpenTimeSettingsOn =>
      'V tejto zostave nie je možné otvoriť nastavenia času.';

  @override
  String get unableToOpenWiFiSettings =>
      'Na tejto zostave nie je možné otvoriť nastavenia Wi-Fi.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Nie je možné zachovať vybraté zobrazenie pracovnej plochy.';

  @override
  String get unclearWhoItWasFor => 'Nie je jasné, pre koho to bolo';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'nedokončené. Zadajte svoje používateľské meno na potvrdenie.';

  @override
  String get unknownAccount => 'Neznámy účet';

  @override
  String get unknownAgent => 'Neznámy agent';

  @override
  String get unknownBrowser => 'Neznámy prehliadač';

  @override
  String get unknownDevice => 'Neznáme zariadenie';

  @override
  String get unknownError => 'neznáma chyba';

  @override
  String get unknownLocalComputerPermission =>
      'Neznáme povolenie miestneho počítača.';

  @override
  String get unknownLocation => 'Neznáma poloha';

  @override
  String get unknownPublishTime => 'Neznámy čas zverejnenia';

  @override
  String get unknownSize => 'Neznáma veľkosť';

  @override
  String get unlink => 'Odpojiť';

  @override
  String get unreadOnly => 'Iba neprečítané';

  @override
  String get unsavedChanges => 'Neuložené zmeny';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Nepodporovaný sprievodný príkaz pracovnej plochy: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Nepodporovaná metóda: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Neobvyklé upozornenia na prihlásenie';

  @override
  String updateArg1(Object? arg1) {
    return 'Aktualizácia $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Aktualizujte položky základnej pamäte z importu.';

  @override
  String get updateNow => 'Aktualizujte teraz';

  @override
  String get updateReady => 'Aktualizácia pripravená';

  @override
  String get updateSetup => 'Nastavenie aktualizácie';

  @override
  String get updateTheAccessListToAllow =>
      'Aktualizujte zoznam prístupových práv, aby ste povolili odpovede.';

  @override
  String get updateTheServer => 'Aktualizovať server?';

  @override
  String get updateTheServer2 => 'Aktualizujte server';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Aktualizujte časové pásmo automaticky zo zariadenia, ktoré používate.';

  @override
  String updatedArg1(Object? arg1) {
    return 'aktualizované $arg1';
  }

  @override
  String get updates => 'Aktualizácie';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Aktualizácie nie sú pre túto zostavu nakonfigurované.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'aktualizácie, takže samoaktualizácia a zmeny kanála sú tu vypnuté.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'aktualizácia aktualizácie teraz vydáva stabilnú beta verziu kanála';

  @override
  String get usageAnalytics => 'Analytika používania';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Signály používania a stavu, ktoré pomáhajú vysvetliť aktuálne správanie pri spustení bez toho, aby ste sa museli najprv prehrabávať v protokoloch.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Používanie sa úplne resetuje v $arg1';
  }

  @override
  String get usageLeaderboard => 'rebríček používania';

  @override
  String get usageLimits => 'Použitie a limity';

  @override
  String get usageLimits2 => 'Použitie a limity';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Použite 8+ znakov. Dlhšie prístupové frázy fungujú dobre.';

  @override
  String get useADateAndTimeFor =>
      'Použite dátum a čas, napríklad 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Použite meno, telefónne číslo alebo ID chatu.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Použite adresu URL NeoRecall, na ktorú sa server NeoAgent môže dostať. Pre spätné volanie OAuth musí byť z tohto prehliadača dostupná aj PUBLIC_URL spoločnosti NeoAgent.';

  @override
  String get useANewPasswordWithAt =>
      'Použite nové heslo s minimálne 8 znakmi.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Použite adresu URL Nextcloud, na ktorú má server NeoAgent prístup, napríklad https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast => 'Použite heslo s minimálne 8 znakmi.';

  @override
  String get useASecureConnectionTls => 'Použiť zabezpečené pripojenie (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Použite aplikáciu na overenie totožnosti, napríklad Authy, 1Password alebo Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Použite aspoň 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Maximálna pamäť na počítač (MB)';

  @override
  String get maxVcpusPerComputer => 'Maximálny počet vCPU na počítač';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Aspoň $arg1. Počítače sú menej náročné, keď je hostiteľ zaneprázdnený.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Maximálna veľkosť pamäte musí byť aspoň $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Použite aspoň 8 znakov.';

  @override
  String get useDefault => 'Použiť predvolené';

  @override
  String get useDefaultChannel => 'Použiť predvolený kanál';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Použiť predvolený (NeoAgent Workspace)';

  @override
  String get useFor => 'Použiť pre';

  @override
  String get useManualDestination => 'Použite manuálny cieľ';

  @override
  String get useOrDoTheSameFor =>
      'použite alebo urobte to isté pre svojich spoluhráčov.';

  @override
  String get usePerCategorySettingsBelow =>
      'Použite nižšie uvedené nastavenia pre jednotlivé kategórie.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Použiť predvolené nastavenia ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Použite server na tomto počítači';

  @override
  String get useTheseForContextIfA =>
      'Použite ich pre kontext. Ak lokálny identifikátor URI nie je priamo dostupný zo servera, požiadajte ma o poskytnutie súboru prostredníctvom prístupného pracovného priestoru.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Použite to pre agentov orchestrátora. Vypnite pre izolované pracovné roboty, ktoré by mali dokončiť priame správy sami.';

  @override
  String get useTlsFromTheStartOf =>
      'Použite TLS od začiatku pripojenia, zvyčajne na porte 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Použite svoj vlastný kľúč API pre poskytovateľa alebo pripojte vlastný ';

  @override
  String get usedByEveryAccountOnThis =>
      'Používa ho každý účet na tomto serveri, ktorý nemá kľúč ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Používa sa na overenie, či sú prichádzajúce udalosti Slack pravé.';

  @override
  String get userSummary => 'Užívateľský súhrn';

  @override
  String get username => 'Používateľské meno';

  @override
  String get usernameOrEmail => 'Používateľské meno alebo e-mail';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'používatelia vyhľadávanie ľudí e-mail používateľské meno odznak správcu spravovaný tím';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Používa model rozhovoru nakonfigurovaný v Nastaveniach';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Pomocou nainštalovaného runtime NeoAgent';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Zvyčajne vyzerá ako @bot:matrix.org';

  @override
  String get validEmail => 'platný email';

  @override
  String get value => 'Hodnota';

  @override
  String get vaultLocked => 'Trezor zamknutý';

  @override
  String get vaultOperationFailed => 'Operácia trezoru zlyhala.';

  @override
  String get verification => 'Overenie';

  @override
  String verificationArg1(Object? arg1) {
    return 'Overenie: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'overenie: $arg1';
  }

  @override
  String get verificationCompleted => 'Overenie dokončené.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Stav overenia: $arg1';
  }

  @override
  String get verifiedTheResult => 'Overený výsledok';

  @override
  String get verifyingTheDownloadedRuntime => 'Overenie stiahnutého runtime';

  @override
  String get versionAndUptime => 'Verzia a dostupnosť';

  @override
  String versionArg1(Object? arg1) {
    return 'Verzia $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Verzia $arg1 je nainštalovaná, ale $arg2 stále beží.';
  }

  @override
  String get videoLinks => 'Odkazy na videá';

  @override
  String get viewDesktop => 'Zobraziť pracovnú plochu';

  @override
  String get viewLastRun => 'Zobraziť posledné spustenie';

  @override
  String get viewLogs => 'Zobraziť denníky';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm obrazová pamäť cpu qemu runtime';

  @override
  String get voice => 'Hlas';

  @override
  String get voiceAssistant => 'Hlasový asistent';

  @override
  String get voiceCall => 'HLASOVÝ VOLAT';

  @override
  String get voiceCall2 => 'Hlasový hovor';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'hlasový hovor gpt-live gemini živý model reči v reálnom čase';

  @override
  String get voiceCallsRunOnALive =>
      'Hlasové hovory prebiehajú na živom modeli reči na reč s rovnakou osobnosťou, pamäťou a históriou chatu ako NeoAgent. Okamžite odpovie a odovzdá skutočnú prácu normálnemu agentovi, ktorý stále beží na pozadí.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'hlasová poznámka prepis reči api kľúč';

  @override
  String get voiceNotesAndDictation => 'Hlasové poznámky a diktáty';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Prehrávanie hlasu nie je na tomto zariadení k dispozícii.';

  @override
  String get voiceReplyModel => 'Model hlasovej odpovede';

  @override
  String get waitingForApproval => 'Čaká sa na schválenie: ';

  @override
  String get waitingForCode => 'Čaká sa na kód';

  @override
  String get waitingForInput => 'Čaká sa na vstup';

  @override
  String get waitingForServerOrFlutterLog =>
      'Čaká sa na výstup protokolu servera alebo Flutter...';

  @override
  String get waitingForTaskEvents => 'Čaká sa na udalosti úloh...';

  @override
  String get waitingForYou => 'čaká na teba';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Chcel som odpoveď od $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Chce s vami hovoriť · ${arg1}s';
  }

  @override
  String get weak => 'slabý';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Počasie, kalendár a priority pred začiatkom dňa.';

  @override
  String get weatherEvent => 'Počasie';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'webový prehliadač';

  @override
  String get webSearchApiKey => 'kľúč API na vyhľadávanie na webe';

  @override
  String get webhookOrRestChannelPosting =>
      'Uverejnenie na webhooku alebo kanáli REST';

  @override
  String get webhookSecret => 'Tajomstvo webhooku';

  @override
  String get webhookUrlCopied => 'Webová adresa webhooku bola skopírovaná';

  @override
  String get weekdays => 'Pracovné dni';

  @override
  String get weekdays0730 => 'Pracovné dni · 07:30';

  @override
  String get weekdays1800 => 'Pracovné dni · 18:00';

  @override
  String get weekly => 'Týždenne';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Týždenný limit $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Týždenný limit (tokeny)';

  @override
  String get weeklyReview => 'Týždenný prehľad';

  @override
  String get weeklyUsage => 'Týždenné použitie';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Rekordy hmotnosti $arg1';
  }

  @override
  String get welcomeToNeoagent => 'VITAJTE V NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Vitajte v\nNeoAgent';

  @override
  String get whatAreYouAdding => 'čo pridávaš?';

  @override
  String get whatIsOnTomorrow => 'Čo bude zajtra?';

  @override
  String get whatShouldNeoagentLearn => 'Čo by sa mal NeoAgent naučiť?';

  @override
  String get whatShouldWeBuild => 'Čo by sme mali postaviť?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'To, čo vy a NeoAgent poviete, sa zobrazí tu a v chate.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Osobná správa WhatsApp bola prijatá';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Ak vyberiete možnosť Iba schválené, nižšie pridajte ľudí alebo skupiny.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Kam má tento agent posielať odpovede.';

  @override
  String get whoCanMessage => 'Kto môže poslať správu';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Kto môže posielať správy na $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Kto môže poslať $arg1 individuálnu správu.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Kto môže hovoriť so $arg1 v skupine, kanáli alebo miestnosti.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'kto spravuje tento účet vypnutý: ';

  @override
  String get whoManagesWhom => 'Kto koho riadi';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Každý, kto prijme odkaz, sa pripojí k vášmu tímu iba s nástrojmi, ktoré má ';

  @override
  String get wholeGroup => 'Celá skupina';

  @override
  String get wholeGroups => 'Celé skupiny';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Prečo $arg1 odpovedal alebo zostal ticho v skupinách $arg2.';
  }

  @override
  String get windowsApp => 'aplikácia pre Windows';

  @override
  String get windowsNt => 'okná nt';

  @override
  String get workAccount => 'Pracovný účet';

  @override
  String get workOnAProjectWithNeoagent => 'Pracujte na projekte s NeoAgentom';

  @override
  String workflowArg1(Object? arg1) {
    return 'Pracovný postup: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Práca v $arg1 na cloudovom počítači. NeoAgent tam číta a upravuje súbory a môže spúšťať príkazy a prehliadač.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Práca na pozadí: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Konfigurácia pracovného priestoru a zabezpečenie účtu na jednom mieste.';

  @override
  String get workspaceFiles => 'Súbory pracovného priestoru';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Pracovný priestor, modely a ovládacie prvky diagnostiky.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Prepísanie pracovného priestoru musí byť absolútna cesta.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Napísal $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'chyba xmlhttprequest';

  @override
  String get yesterday => 'včera';

  @override
  String get youAreInControl => 'Máte to pod kontrolou';

  @override
  String get youCanFollowAlongOnThe =>
      'Môžete to sledovať na pracovnej ploche.';

  @override
  String get youCanLeaveATeamAt =>
      'Z tímu môžete kedykoľvek odísť; znova sa použijú vaše vlastné nastavenia.';

  @override
  String get youCanLeaveAtAnyTime => 'Zo stránky Team môžete kedykoľvek odísť.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Vy rozhodujete, ktoré nástroje môže váš agent používať, v časti Nastavenia › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Zatiaľ nikoho neriadite. Vytvorte odkaz na pozvánku nižšie a ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Máte neuložené nastavenia. čo by ste chceli robiť?';

  @override
  String get youReOnYourOwnYou =>
      'Ste na to sami: vy rozhodujete, ktoré nástroje môže váš agent použiť. Ak ';

  @override
  String get yourAccountAndUsageOnA =>
      'váš účet – a používanie na modeli podporovanom vaším vlastným kľúčom ';

  @override
  String get yourAccountHasBeenDeleted => 'Váš účet bol odstránený.';

  @override
  String get yourAgentWillBeAllowed => 'Váš agent bude mať povolené:';

  @override
  String get yourAppsAndFilesAreSaved => 'Vaše aplikácie a súbory sú uložené.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Vaše aplikácie a súbory zostanú uložené.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Váš kľúč $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Vrstva vášho asistenta na snímanie, kontext a akciu.';

  @override
  String get yourComputerIsAsleep => 'Váš počítač spí';

  @override
  String get yourComputerIsOff => 'Váš počítač je vypnutý';

  @override
  String get yourComputerIsReady => 'Váš počítač je pripravený';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Vaše aktuálne heslo je nesprávne.';

  @override
  String get yourData => 'Vaše údaje';

  @override
  String get yourDataExportWasCopiedTo =>
      'Váš export údajov bol skopírovaný do schránky.';

  @override
  String get yourDesktopIsReady => 'Vaša pracovná plocha je pripravená';

  @override
  String get yourLinuxComputer => 'Váš počítač so systémom Linux';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Vaša poloha nie je nikdy nepretržite sledovaná ani uložená na našich serveroch. Používame ho iba lokálne na kontrolu vašich aktívnych úloh.';

  @override
  String get yourManager => 'svojho manažéra';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'URL vašej stránky Mattermost, ak používate REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Vaša relácia vypršala alebo ju prehliadač neuchovala. Prihláste sa znova.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Platnosť vašej relácie vypršala. Prihláste sa znova.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Vaše používateľské meno alebo heslo je nesprávne.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'Jednorazové heslo YubiKey';

  @override
  String get zaloPersonal => 'Zalo Osobný';

  @override
  String get sectionOverview => 'Prehľad';

  @override
  String get sectionDiagnostics => 'Diagnostika';

  @override
  String get sectionVolume => 'Objem';

  @override
  String get sectionSession => 'Relácia';

  @override
  String get sectionDeliverable => 'Doručiteľné';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Lokálny runtime ešte nezapísal súbor denníka.';

  @override
  String get thisComputer => 'Tento počítač';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta inštaluje najnovší backend predbežnej verzie. Očakávajte drsné hrany.';

  @override
  String get copiedFinalResponse => 'Skopírovaná konečná odpoveď';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Konečná odpoveď sa tu zobrazí po dokončení behu.';

  @override
  String get waitingForTheFirstStep => 'Čakanie na prvý krok…';

  @override
  String get loadingPrompt => 'Načítava sa výzva…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Pre tento priebeh nebola zaznamenaná žiadna konečná odpoveď.';

  @override
  String get readyToSignIn => 'Pripravené na prihlásenie';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Ak chcete znova povoliť kontroly schválenia, prepnite na „Predvolené“ alebo „Vždy žiadať“.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Odoslať aktualizáciu riadenia alebo ďalšiu poznámku pre aktuálnu jazdu...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Žiadne sieťové pripojenie. NeoAgent sa znova pripojí, keď bude zariadenie opäť online.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Na aktuálnu jazdu bola použitá najnovšia aktualizácia riadenia.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Pripravuje sa relácia súkromného hlasu…';

  @override
  String get preparingYourComputer => 'Príprava počítača';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent sťahuje a pripravuje bezpečný systém Linux. Toto sa deje len prvýkrát.';

  @override
  String get moreFreeSpaceIsNeeded => 'Je potrebné viac voľného miesta';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Uvoľnite miesto na disku na hostiteľovi NeoAgent a skúste to znova. Vaše existujúce údaje v počítači sú v bezpečí.';

  @override
  String get androidReady => 'Android pripravený';

  @override
  String get startingAndroid2 => 'Spúšťa sa Android…';

  @override
  String get androidStopped => 'Android sa zastavil';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Prvým spustením sa stiahne súprava Android SDK a obraz systému, čo môže trvať niekoľko minút.';

  @override
  String get androidIsStopped => 'Android je zastavený';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Spustite spravované prostredie Android, keď ho potrebujete.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Nechajte NeoAgent pracovať na tomto počítači';

  @override
  String get firstTimeSetupIsInProgress => 'Prebieha prvé nastavenie.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent môže použiť prístup, ktorý povolíte.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Uvoľnite priestor hostiteľa a skúste to znova.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Začnite, keď chcete, aby vám NeoAgent pomohol tu.';

  @override
  String get systemPermissionMissing => 'Chýba systémové oprávnenie';

  @override
  String get connectingThisDevice => 'Pripojenie tohto zariadenia';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Vytvára sa zabezpečené lokálne pripojenie.';

  @override
  String get recordingYourDemonstration => 'Nahrávanie demonštrácie';

  @override
  String get noErrorsInTheRecentLog =>
      'V nedávnom protokole nie sú žiadne chyby.';

  @override
  String get loadingAccounts => 'Načítavajú sa účty…';

  @override
  String get neverSignedIn => 'Nikdy sa neprihlásili';

  @override
  String get emptyUsesTheServerDefault =>
      'Prázdne používa predvolené nastavenie servera.';

  @override
  String get followTheSelectedSession => 'Postupujte podľa zvolenej relácie';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Režim plánu iba kontroluje. Prepnite do režimu agenta, aby mohol NeoAgent upravovať súbory.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Vyžaduje sa pridanie alebo zmena e-mailu účtu.';

  @override
  String get confirmNewPassword => 'Potvrďte nové heslo';

  @override
  String get passwordChanged => 'Heslo zmenené.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Táto požiadavka už bola použitá.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Platnosť tejto žiadosti vypršala. Požiadajte druhé zariadenie, aby vygenerovalo nový kód.';

  @override
  String get startQuickstart => 'Spustite rýchly štart';

  @override
  String get createYourAccount => 'Vytvorte si účet';

  @override
  String get showWorkAsSummaries => 'Zobraziť prácu ako súhrny';

  @override
  String get tokensUsedByTheLatestRun =>
      'Tokeny použité pri poslednom spustení';

  @override
  String get listedTheWorkspaceRoot => 'Uvedený koreň pracovného priestoru';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Zatiaľ nie sú k dispozícii žiadne oficiálne integrácie.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Zatiaľ nie sú nakonfigurované žiadne servery MCP. Pridajte jeden, aby ste odhalili jeho nástroje.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Ak chcete začať, pridajte server MCP alebo nainštalujte zručnosť.';

  @override
  String get setUp => 'Nastaviť';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Ak chcete zachovať uloženú hodnotu, nechajte prázdne';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Týmto sa odstráni adresa každého účtu na tomto serveri.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Len hovor. Prerušiť môžete kedykoľvek. Klepnutím stlmíte.';

  @override
  String get tapAgainWhenYouAreDone => 'Po dokončení klepnite znova.';

  @override
  String get workingOnATaskInTheBackground => 'Práca na úlohe na pozadí.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Reč na reč s rovnakou pamäťou, nástrojmi a históriou chatu ako NeoAgent.';

  @override
  String get checkLink => 'Skontrolujte odkaz';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Vášmu agentovi nebude povolený žiadny z kontrolovaných nástrojov.';

  @override
  String get notYoursToChange => 'Nie tvoj, aby si sa zmenil';

  @override
  String get setByYou => 'Nastavené vami';

  @override
  String get noTools => 'Žiadne nástroje';

  @override
  String get untitledLink => 'Odkaz bez názvu';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Prestane fungovať po tom, ako si ho uplatní jedna osoba.';

  @override
  String get theOperator => 'Operátor';

  @override
  String get smartSelectorOn => 'Inteligentný volič zapnutý';

  @override
  String get startASessionToBegin => 'Začnite reláciu';

  @override
  String get steerTheActiveRun => 'Riadiť aktívny beh…';

  @override
  String get describeWhatToPlan => 'Popíšte, čo plánovať…';

  @override
  String get stopDictation => 'Zastavte diktát';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Správy riadia aktuálnu jazdu · ⌘↵ odoslať · ⌘. zastaviť';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Režim plánu iba kontroluje; nič sa nezmení, kým neimplementujete · ⌘↵ odoslať';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agent upraví pracovný priestor. Plán iba kontroluje.';

  @override
  String get defaultModel => 'Predvolený model';

  @override
  String get openingScanner => 'Otvára sa skener...';

  @override
  String get theAgentCanUseThisSkill => 'Agent môže využiť túto zručnosť.';

  @override
  String get allSelected => 'Všetky vybrané';

  @override
  String get addCoreMemoryEntry => 'Pridať položku základnej pamäte';

  @override
  String get channelId => 'ID kanála';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Úlohy vytvorené AI a nešpecifikované úlohy používajú aktuálne predvolené nastavenia.';

  @override
  String get waitingForRunEvents => 'Čaká sa na spustené udalosti...';

  @override
  String get hideSteps => 'Skryť kroky';

  @override
  String get commitTheActiveLiveCapture => 'Odovzdať aktívne živé snímanie';

  @override
  String get stopCaptureAndSubmit => 'Zastavte zachytávanie a odošlite';

  @override
  String get clickTheMicToStartSpeaking =>
      'Kliknutím na mikrofón začnite hovoriť';

  @override
  String get connectACustomEndpoint => 'Pripojte vlastný koncový bod';

  @override
  String get hostedProvider => 'hostovaného poskytovateľa.';

  @override
  String get muted => ' • stlmené';

  @override
  String get addWhoCanMessage => 'Pridajte správu, kto môže';

  @override
  String get joinsGroupConversations => 'Pripojí sa ku skupinovým konverzáciám';

  @override
  String get label1PersonOrGroupAdded => 'Bola pridaná 1 osoba alebo skupina';

  @override
  String get inProgress => 'Prebieha';

  @override
  String get waitingForUpdateJobOutput =>
      'Čaká sa na výstup aktualizačnej úlohy…';

  @override
  String get taskTrigger => 'Spúšťač úlohy';

  @override
  String get bearerToken => 'Token na doručiteľa';

  @override
  String get bearerToken2 => 'Token na doručiteľa';

  @override
  String get notRecorded => 'Nezaznamenané';

  @override
  String get sessionCookie => 'Súbor cookie relácie';

  @override
  String get neverUsed => 'Nikdy nepoužité';

  @override
  String get linkedRecently => 'Nedávno prepojené';

  @override
  String get notUsedYet => 'Zatiaľ nepoužité';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Platnosť jedného alebo viacerých účtov vypršala. Ak chcete obnoviť prístup, znova sa pripojte. Ak sa to bude opakovať, vaša aplikácia Google Cloud OAuth môže byť v testovacom režime – zverejnite ju v produkčnej konzole Google Cloud Console, aby ste získali tokeny s dlhou životnosťou.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Trezor je pripojený a dostupný po reštarte';

  @override
  String get vaultConnectedForThisSession => 'Vault pripojený pre túto reláciu';

  @override
  String get connectAnotherAccount => 'Pripojiť ďalší účet';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Prilepte náhradný dlhotrvajúci prístupový token';

  @override
  String get updateInstance => 'Aktualizovať inštanciu';

  @override
  String get pasteAReplacementToken => 'Prilepte náhradný token';

  @override
  String get replaceAccount => 'Nahradiť účet';

  @override
  String get addAccount => 'Pridať účet';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Môže delegovať na akéhokoľvek prijímajúceho agenta';

  @override
  String get canReceiveDelegatedTasks2 => 'môže prijímať delegované úlohy';

  @override
  String get noSyncYet => 'Zatiaľ bez synchronizácie';

  @override
  String get noNewData => 'Žiadne nové údaje';

  @override
  String get syncOnceToSeedYourBackend =>
      'Raz synchronizujte, aby ste vytvorili základný server.';

  @override
  String get lastWindowEndIsUnknown => 'Posledný koniec okna nie je známy.';

  @override
  String get lastNonEmptySync => 'Posledná neprázdna synchronizácia';

  @override
  String get stopTranscribe => 'Zastaviť a prepísať';

  @override
  String get steeringMode => 'Režim riadenia';

  @override
  String get noMessageText => 'Žiadny text správy';

  @override
  String get reconnectingToServer => 'Opätovné pripojenie k serveru…';

  @override
  String get signingIn => 'Prihlasovanie...';

  @override
  String get noGroupsFoundYet => 'Zatiaľ sa nenašli žiadne skupiny';

  @override
  String get onForNewGroupsOnly => 'Zapnuté iba pre nové skupiny';

  @override
  String get noGroupsInThisCategory =>
      'V tejto kategórii nie sú žiadne skupiny';

  @override
  String get groupOrChannel => 'Skupina alebo kanál';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Poznámky, ktoré si napíšete, začnú behať a odpovede pristanú v rovnakom rozhovore. Zoznam povolených tu neplatí.';

  @override
  String get needToReply => 'Treba odpovedať';

  @override
  String get enter2faCode => 'Zadajte kód 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Otvorte aplikáciu autentifikátora a zadajte aktuálny kód NeoAgent.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Už máte účet? Prihláste sa';

  @override
  String get serverOnThisComputer => 'Server na tomto počítači';

  @override
  String get showQrCode => 'Zobraziť QR kód';

  @override
  String get createAnotherNeoagentAccount => 'Vytvorte si ďalší účet NeoAgent.';

  @override
  String get canCoordinateDelegatedWork => 'Vie koordinovať delegovanú prácu';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Runtime archív NeoAgent sa nepodarilo extrahovať.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Runtime archív NeoAgent sa nepodarilo prečítať.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Runtime archív NeoAgent obsahuje nebezpečnú cestu.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Runtime archív NeoAgent obsahuje nebezpečný odkaz.';

  @override
  String get installingAppPackageOnThePhone =>
      'Inštaluje sa balík aplikácií do telefónu...';

  @override
  String get dragAndDropAApkOrApks =>
      'Sem presuňte myšou súbor .apk alebo .apks alebo ho kliknutím prehliadajte.';

  @override
  String get releaseToInstallThisPackage =>
      'Ak chcete nainštalovať tento balík, uvoľnite';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Bezpečnostný kľúč nebolo možné použiť.';

  @override
  String get connecting => 'Pripája sa…';

  @override
  String get changes => 'Zmeny';

  @override
  String get runtimeReady => 'Runtime pripravený';

  @override
  String get saving => 'Ukladá sa...';

  @override
  String get earlier => 'Skôr';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'mája';

  @override
  String get monthJun => 'júna';

  @override
  String get monthJul => 'júl';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'okt';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'dec';

  @override
  String get steeringWord => 'Riadenie';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Toto prepne backend z kanálu $arg1 na kanál $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Boli importované súbory cookie $arg1';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'Pred ${arg1}s';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Riadenie v rade: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Webovej aplikácii sa nepodarilo dosiahnuť backend NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Prehliadač zablokoval požadovanú požiadavku z dôvodu zásad zabezpečenia obsahu.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 zo 4 povolených';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Vykonajte úlohu ako obvykle.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Zmeny · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Toto zariadenie · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Dosiahnutý limit$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Obnovovacie kódy $arg1 sú stále k dispozícii.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Bezpečnostný kľúč $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Aktuálna relácia';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nNaposledy použité: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Na tomto zariadení pracujete v $arg1. NeoAgent priamo číta a upravuje priečinok a môže spúšťať príkazy, otvárať aplikácie a používať obrazovku.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Pracoval pre $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Povolené $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Odkazy na pozvánku $arg1 zo $arg2 boli zrušené';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Pridajte ľudí a skupiny, s ktorými má $arg1 hovoriť';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Pridajte ľudí a skupiny, s ktorými môže $arg1 hovoriť.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Kde $arg1 počúva';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 sleduje tieto miesta kvôli zmienke. Ktokoľvek tu môže uverejňovať príspevky, takže ľudia stále potrebujú vlastný súhlas nižšie.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Títo ľudia sa môžu opýtať $arg1 kdekoľvek ho označia. Roly sa počítajú iba na miestach uvedených vyššie.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Iba vtedy, keď je označené $arg1';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Zapnuté pre všetky skupiny $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 stále počuje iba ľudí a skupiny, ktoré ste už schválili. To len umožňuje $arg1 pripojiť sa k bežnému chatu, nielen k značkám a odpovediam.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 stále počuje iba ľudí a skupiny, ktoré ste už schválili. Toto len vyberie, do ktorej z týchto skupín sa má pripojiť.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Ak niekto označí $arg1 alebo odpovie, $arg1 vždy odpovie. Toto zapnite, ak sa má $arg1 pripojiť aj k bežnému skupinovému chatu.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Nové skupiny umožnia $arg1 pripojiť sa k bežnému chatu so schválenými ľuďmi, kým ich nevypnete.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Nové skupiny umožnia $arg1 pripojiť sa k bežnému chatu, kým ich nevypnete.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Nové skupiny zostanú tiché, pokiaľ schválená osoba neoznačí $arg1, kým ich nezapnete.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Iba vtedy, keď schválená osoba označí $arg1, pokiaľ nezapnete skupinu';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Iba ak je označený $arg1, pokiaľ nezapnete skupinu';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 skupín $arg2 sa pripojí k bežnému chatu so schválenými ľuďmi';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Toto neschvaľuje nových ľudí. Značky a odpovede od schválených ľudí vždy dostanú odpoveď. Zapnite skupinu, ak sa tam má $arg1 pripojiť aj k bežnému chatu.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Toto neschvaľuje nových ľudí. Zapnite skupinu, ak sa má $arg1 pripojiť k bežnému rozhovoru s ľuďmi, ktorých ste už schválili.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Značky a odpovede vždy dostanú odpoveď. Zapnite skupinu, ak sa tam má $arg1 pripojiť aj k bežnému chatu.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 sa pripojí k bežnému chatu so schválenými ľuďmi';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 sa môže pripojiť k bežnému chatu';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 odpovie iba vtedy, keď ho označí schválená osoba';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Nič extra netreba. Pripojte a začnite používať $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Obnovuje sa v ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Zaregistrujte sa u $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'So „$arg1“ nie sú spojené žiadne pamäte.';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (predvolené)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Pobočka: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 sa pripojí iba k skupinám a kanálom, ktoré pridáte nižšie.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 je potrebný na nájdenie údajov runtime NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[skrátená ukážka, celkom $arg1 bajtov]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefakt ohraničený, celkom $arg1 bajtov]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' v $arg1';
  }

  @override
  String get worldNews => 'Svetové správy';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Spustite, keď sa objavia nové svetové titulky. Vaša výzva rozhodne, či vás upozorní.';

  @override
  String get newsKeywordsOptional => 'Kľúčové slová (voliteľné)';

  @override
  String get worldNewsSetup => 'Nastavenie svetových správ';

  @override
  String get connectWorldNewsWithGnews =>
      'Pridajte kľúč GNews API (bezplatný plán dostupný na gnews.io). Je uložený zašifrovaný a používa sa na prieskum hlavných titulkov pre spúšťače svetových správ.';

  @override
  String get gnewsApiKey => 'GNews API kľúč';

  @override
  String get pasteReplacementGnewsApiKey => 'Prilepte náhradný kľúč GNews API';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Ak chcete zachovať aktuálne uložený kľúč, nechajte kľúč prázdny.';

  @override
  String get gnewsApiKeyIsRequired => 'Vyžaduje sa kľúč GNews API.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Nastavenie World News sa nepodarilo uložiť.';

  @override
  String get disconnectWorldNews => 'Odpojiť správy zo sveta';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Týmto sa odstráni uložený kľúč GNews API. Spúšťače World News sa prestanú spúšťať, kým znova nepridáte kľúč.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Svetové správy sa nepodarilo odpojiť.';

  @override
  String get systemOneModels => 'Modely SystemOne';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Vyberá najlepší dostupný model SystemOne';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Tieto rozhodnutia robí model chatu';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Rozhodovacie modely, ktoré uskutočnia hovory zo zákulisia za zlomok sekundy: obrat v skupinovom chate a kroky v prehliadači. Váš model rozhovoru stále zapisuje každú odpoveď.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Model SystemOne rozhoduje o tom, kedy hovoriť, keď je zapnutý; tento model je záložný.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 skóroval SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne zaznamenal túto správu priamo. Neprebehol žiadny jazykový model.';

  @override
  String get systemOneUnavailable => 'SystemOne nie je k dispozícii';

  @override
  String get systemOneAdminAvailability =>
      'Agenti rozhodovacích modelov si môžu vybrať v časti Nastavenia › Modely. Model, ktorý je tu vypnutý, opustí výber a agenti, ktorí si ho vybrali, prejdú späť na Auto. Kým je ktorýkoľvek model vypnutý, modely SystemOne, ktoré poskytovatelia pridajú neskôr, sa tiež vypnú.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Zatiaľ žiadne modely SystemOne. Pridajte kľúč TypeSafe alebo OpenRouter v časti Poskytovatelia alebo použite rozhodovací model, ako napríklad svižný v Ollama 0.35 alebo novšom.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Zatiaľ nie je k dispozícii žiadny model SystemOne. Pridajte kľúč TypeSafe alebo OpenRouter v časti Nastavenia › Modely › Prineste si vlastný kľúč alebo vytiahnite rozhodovací model, ako napríklad šikovný v Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone system one decision models jev typesafe openrouter ollama dostupnosť povoliť zakázať';

  @override
  String get chatModels => 'Chatovacie modely';

  @override
  String get disabled => 'Vypnuté';

  @override
  String get enableShown => 'Povoliť zobrazené';

  @override
  String get disableShown => 'Zakázať zobrazené';

  @override
  String get expandAll => 'Rozbaliť všetko';

  @override
  String get collapseAll => 'Zbaliť všetko';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 neuložené zmeny';
  }

  @override
  String get settingsScopeAllAgents => 'Všetci agenti';

  @override
  String get settingsScopeAgent => 'Tento agent';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint => 'To isté všade, kde sa prihlásite';

  @override
  String get settingsScopeAllAgentsHint => 'Zdieľané všetkými vašimi agentmi';

  @override
  String get settingsAppliesTo => 'Platí pre';

  @override
  String get settingsSaving => 'Ukladá sa…';

  @override
  String get settingsSavedAutomatically => 'Zmeny sa uložia automaticky';

  @override
  String get settingsSearchHint => 'Vyhľadajte všetky nastavenia';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Prihlásenie a zabezpečenie';

  @override
  String get settingsPageUsage => 'Použitie';

  @override
  String get settingsPagePermissions => 'Povolenia';

  @override
  String get settingsPageComputer => 'Počítač a web';

  @override
  String get settingsPageBehavior => 'Správanie';

  @override
  String get settingsPageSystem => 'Systém';

  @override
  String get settingsPagePlatforms => 'Platformy';

  @override
  String get settingsPageProfileDescription =>
      'Vaše meno a e-mail, kópiu vašich údajov a odhlásenie.';

  @override
  String get settingsPageSecurityDescription =>
      'Heslo, dvojfaktorové overenie, bezpečnostné kľúče a miesto, kde ste prihlásení.';

  @override
  String get settingsPageUsageDescription =>
      'Vaše limity a tokeny na jednom mieste.';

  @override
  String get settingsPageAgentsDescription =>
      'Vytvorte agentov a vyberte, ktorý z nich predvolene odpovie.';

  @override
  String get settingsPagePermissionsDescription =>
      'Čo môžu vaši agenti robiť bez toho, aby sa vás najprv opýtali.';

  @override
  String get settingsPageComputerDescription =>
      'Počítač, na ktorom vaši agenti pracujú, a stránky, ktoré môžu čítať ako vy.';

  @override
  String get settingsPageModelsDescription =>
      'Ktoré modely tento agent používa, a kľúče API, ktoré za ne platia.';

  @override
  String get settingsPageBehaviorDescription =>
      'Ako tento agent hovorí a ako číta skupinový chat.';

  @override
  String get settingsPageVoiceDescription =>
      'Živé hovory, diktovanie a hovorené odpovede pre tohto agenta.';

  @override
  String get settingsPageMessagingDescription =>
      'Kde môžu ľudia kontaktovať tohto agenta a ako sa správa v chatoch.';

  @override
  String get settingsPageGeneralDescription =>
      'Vzhľad, jazyk, časové pásmo a to, čo táto aplikácia robí na pozadí.';

  @override
  String get settingsPageSystemDescription =>
      'Server, ktorý toto okno používa, server v tomto počítači a aktualizácie aplikácií.';

  @override
  String get settingsYourAgents => 'Vaši agenti';

  @override
  String get settingsChatModel => 'Model chatu';

  @override
  String get settingsChatModelDescription => 'Odpovedá na vaše správy.';

  @override
  String get settingsSubAgentModel => 'Model sub-agenta';

  @override
  String get settingsSubAgentModelDescription =>
      'Vykonáva prácu odovzdanú počas úlohy.';

  @override
  String get settingsDefaultModels => 'Predvolené modely';

  @override
  String get settingsDefaultModelsDescription =>
      'Používa sa vždy, keď si chat alebo úloha nevyberie svoj vlastný model.';

  @override
  String get settingsModelPool => 'Modelový bazén';

  @override
  String get settingsApiKeysDescription =>
      'Použite svoje vlastné kľúče alebo koncový bod pre tohto agenta. Kľúče sú zašifrované a už sa nikdy nezobrazia.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Jemné dolaďovanie';

  @override
  String get settingsFineTuningDescription =>
      'Zriedka potrebné. Predvolené nastavenia vyhovujú väčšine chatov.';

  @override
  String get settingsShow => 'Zobraziť';

  @override
  String get settingsHide => 'Skryť';

  @override
  String get settingsMinimumContribution => 'Minimálna hodnota príspevku';

  @override
  String get settingsBatchWindow => 'Dávkové okno miestnosti';

  @override
  String get settingsBatchWindowDescription =>
      'Čaká tak dlho, aby sa rýchle správy považovali za jedno otočenie.';

  @override
  String get settingsHandsFree => 'Handsfree';

  @override
  String get settingsHandsFreeDescription =>
      'Hovorte slobodne a kedykoľvek prerušte.';

  @override
  String get settingsPushToTalkDescription =>
      'Podržaním hovorte, uvoľnením odošlite.';

  @override
  String get settingsLiveVoice => 'Živý hlas';

  @override
  String get settingsChannels => 'Kanály';

  @override
  String get settingsGroupChats => 'V skupinových chatoch';

  @override
  String get settingsGroupChatsDescription =>
      'Ako sa tento agent správa v skupinách na každom kanáli.';

  @override
  String get settingsGroupChatsDisabled =>
      'Ak ich chcete zmeniť, zapnite moduly správania v časti Správanie.';

  @override
  String get settingsParticipationAutomatic => 'Automaticky';

  @override
  String get settingsParticipationMentionOnly => 'Iba spomenúť';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Číta miestnosť a pripojí sa, keď má niečo užitočné pridať.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Odpovedá iba pri zmienke alebo odpovedi.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Odpovede na každú správu.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Delí dlhšie odpovede na krátke správy, ako by to urobil človek.';

  @override
  String get settingsDeliverySingleDescription =>
      'Odošle každú odpoveď ako jednu správu.';

  @override
  String get settingsComputerStatus => 'Stav';

  @override
  String get settingsTest => 'Test';

  @override
  String get settingsAppearance => 'Vzhľad';

  @override
  String get settingsTheme => 'Téma';

  @override
  String get settingsThemeSystem => 'Systém';

  @override
  String get settingsThemeLight => 'Svetlý';

  @override
  String get settingsThemeDark => 'Tmavý';

  @override
  String get settingsCloseWindow => 'Keď zatvoríte okno';

  @override
  String get settingsCloseAsk => 'Opýtajte sa';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent beží na pozadí a zostáva dostupný.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent sa úplne ukončí.';

  @override
  String get settingsPhoneTriggers => 'Spúšťače telefónu';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signály, ktoré tento telefón odosiela vašim agentom, aby na nich úlohy mohli reagovať.';

  @override
  String get settingsLocationTriggers => 'Lokalizačné spúšťače';

  @override
  String get settingsLocationTriggersDescription =>
      'Kontroluje vašu približnú polohu každých pár minút oproti miestam, ktoré sledujú vaše úlohy.';

  @override
  String get settingsNotificationTriggers => 'Spúšťače upozornení';

  @override
  String get settingsNotificationTriggersDescription =>
      'Preposiela upozornenia z iných aplikácií v tomto telefóne vašim agentom.';

  @override
  String get settingsSetup => 'Nastavenie';

  @override
  String get settingsOnboarding => 'Prihlásenie';

  @override
  String get settingsOnboardingDescription =>
      'Znova prejdite nastavením pri prvom spustení. Nič, čo ste nastavili, sa nestratí.';

  @override
  String get settingsUsernameDescription =>
      'Používa sa na prihlásenie. Nedá sa zmeniť.';

  @override
  String get settingsExport => 'Exportovať';

  @override
  String get settingsLeave => 'Odhláste sa a odstráňte';

  @override
  String get settingsSignOutDescription =>
      'Odhlási vás iba na tomto zariadení.';

  @override
  String get settingsDeleteAccountDescription =>
      'Vymaže váš účet, agentov, pamäť a nastavenia. Toto sa nedá vrátiť späť.';

  @override
  String get settingsTokenUsage => 'Použitie tokenu';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Žiadne nastavenie nezodpovedá „$query“.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count výsledkov',
      few: '$count výsledky',
      one: '$count výsledok',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Pokročilé nastavenia modelu';

  @override
  String get settingsAdvancedModelsDescription =>
      'Voliteľné. Pripnúť model k jednému druhu diela; preberá vždy, keď agent tieto nástroje použije. Všetko, čo zostane v predvolenom nastavení, sa riadi modelom chatu.';

  @override
  String get settingsTaskModelDefault => 'Predvolené';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Nasleduje model chatu';

  @override
  String get settingsTaskModelCoding => 'Kódovanie';

  @override
  String get settingsTaskModelCodingDescription =>
      'Písanie, úprava a ladenie kódu.';

  @override
  String get settingsTaskModelComputerUse => 'Používanie počítača';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Ovládanie prehliadača a pracovnej plochy.';

  @override
  String get settingsTaskModelAndroidUse => 'Používanie systému Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Prevádzkovanie aplikácií na zariadení alebo emulátore Android.';

  @override
  String get settingsTaskModelResearch => 'Výskum';

  @override
  String get settingsTaskModelResearchDescription =>
      'Vyhľadávanie, čítanie a sumarizácia zdrojov.';

  @override
  String get knowledgeGraphHint =>
      'Vaše najčastejšie spomínané entity, zafarbené podľa zhlukov. Čiary spájajú entity, ktoré sa objavujú v rovnakých spomienkach. Klepnutím na niektorú zobrazíte jej odkazy a spomienky; potiahnutím posúvajte, stláčaním prstov alebo Ctrl/⌘ posúvaním priblížite.';

  @override
  String get linkedEntities => 'Prepojené entity';

  @override
  String get noLinkedEntities => 'Zatiaľ nie je prepojený s inými subjektmi.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 spomína';
  }

  @override
  String get entityKindConcept => 'koncepcia';

  @override
  String get entityKindDomain => 'doména';

  @override
  String get entityKindEmail => 'Email';

  @override
  String get entityKindLink => 'Odkaz';

  @override
  String get entityKindFile => 'Súbor';

  @override
  String get entityKindAcronym => 'Skratka';

  @override
  String get entityKindIdentifier => 'Identifikátor';

  @override
  String get entityKindVersion => 'Verzia';

  @override
  String get openFullscreen => 'Otvoriť celú obrazovku';

  @override
  String get zoomIn => 'Priblížiť';

  @override
  String get zoomOut => 'Oddialiť';

  @override
  String get searchEntities => 'Nájdite entitu';

  @override
  String get incomingCall => 'Prichádzajúci hovor';

  @override
  String get answerCall => 'Odpoveď';

  @override
  String get callMeLater => 'Zavolaj mi neskôr';

  @override
  String get callingEllipsis => 'Volá sa…';

  @override
  String get reconnectingCall => 'Opätovné pripojenie';

  @override
  String get agentWorking => 'Pracovné';

  @override
  String get micMuted => 'Stlmené';

  @override
  String get speakerphone => 'Hovorca';

  @override
  String get muteMic => 'Stlmiť';

  @override
  String get unmuteMic => 'Zapnúť zvuk';

  @override
  String get releaseToSend => 'Uvoľnite na odoslanie';

  @override
  String get callEnded => 'Hovor bol ukončený';

  @override
  String get openConversation => 'Otvorte konverzáciu';

  @override
  String get callBack => 'Zavolajte späť';

  @override
  String get letCallsReachYou => 'Nechajte hovory, aby sa k vám dostali';

  @override
  String get callPermissionsIntro =>
      'Vaši agenti vám môžu zavolať. Ak chcete zvoniť ako telefónny hovor, keď je NeoAgent na pozadí alebo je váš telefón uzamknutý, potrebuje tieto.';

  @override
  String get showOverOtherApps => 'Zobraziť cez iné aplikácie';

  @override
  String get showOverOtherAppsDetail =>
      'Zobrazí obrazovku hovoru, nech ste kdekoľvek.';

  @override
  String get fullScreenCalls => 'Hovory na celú obrazovku';

  @override
  String get fullScreenCallsDetail => 'Zazvoní nad uzamknutou obrazovkou.';

  @override
  String get unrestrictedBattery => 'Neobmedzená batéria';

  @override
  String get unrestrictedBatteryDetail =>
      'Udržuje NeoAgent pripojený, takže prichádzajú hovory.';

  @override
  String get permissionAllowed => 'Povolené';

  @override
  String get triggerSectionCalendar => 'Kalendár';

  @override
  String get triggerSectionFiles => 'Súbory a dokumenty';

  @override
  String get triggerSectionHome => 'Domov a médiá';

  @override
  String get triggerSectionDevices => 'Zariadenia a miesta';

  @override
  String get triggerSectionTasks => 'Úlohy';

  @override
  String get messagingMemberJoined => 'Člen sa pripojil';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Spustite, keď sa niekto pripojí k serveru Discord, skupine Telegram alebo WhatsApp, kanálu Slack alebo miestnosti Matrix.';

  @override
  String get messagingMemberLeft => 'Člen odišiel';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Spustiť, keď niekto opustí server Discord, skupinu telegramov alebo WhatsApp, kanál Slack alebo miestnosť Matrix.';

  @override
  String get messagingReactionAdded => 'Reakcia pridaná';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Spustiť, keď povolená osoba zareaguje na správu v súkromnom rozhovore.';

  @override
  String get messagingPlatformDisconnected => 'Odosielanie správ je odpojené';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Spustite, keď sa spojenie na odosielanie správ zastaví a bude vás potrebovať, napríklad po odhlásení.';

  @override
  String get googleCalendarEventStarting =>
      'Začína sa udalosť Kalendára Google';

  @override
  String get googleCalendarEventCreated =>
      'Udalosť Kalendára Google bola vytvorená';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Spustiť, keď sa objaví nová udalosť alebo pozvánka.';

  @override
  String get outlookCalendarEventStarting =>
      'Udalosť kalendára programu Outlook sa začína';

  @override
  String get nextcloudCalendarEventStarting =>
      'Začína sa udalosť kalendára Nextcloud';

  @override
  String get runMinutesBeforeEachEvent =>
      'Pred každou udalosťou spustite stanovený počet minút.';

  @override
  String get googleDriveFileAdded => 'Bol pridaný súbor Disku Google';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Spustí sa, keď sa súbor pridá na Disk alebo do priečinka v ňom.';

  @override
  String get googleSheetsRowAdded => 'Bol pridaný riadok Tabuliek Google';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Spustiť, keď sa v hárku objavia nové riadky.';

  @override
  String get onedriveFileAdded => 'Bol pridaný súbor OneDrive';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Spustí sa, keď sa súbor pridá do priečinka OneDrive.';

  @override
  String get nextcloudFileAdded => 'Bol pridaný súbor Nextcloud';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Spustiť, keď sa súbor pridá do priečinka Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Nextcloud súbor zdieľaný s vami';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Spustiť, keď s vami niekto zdieľa súbor alebo priečinok.';

  @override
  String get notionItemAdded => 'Pridaná položka databázy pojmov';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Spustí sa, keď sa položka pridá do databázy Notion.';

  @override
  String get notionItemUpdated => 'Položka databázy pojmov bola aktualizovaná';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Spustiť, keď sa zmení položka v databáze Notion.';

  @override
  String get trelloCardEnteredList => 'Karta Trello bola pridaná do zoznamu';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Spustiť, keď je karta vytvorená alebo presunutá do zoznamu.';

  @override
  String get figmaCommentAdded => 'Pridaný komentár Figma';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Spustiť, keď niekto komentuje súbor Figma.';

  @override
  String get githubPrOpened => 'Žiadosť o stiahnutie GitHub bola otvorená';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Spustiť, keď sa v úložisku otvorí nová požiadavka na stiahnutie.';

  @override
  String get githubWorkflowRunFailed =>
      'Spustenie pracovného postupu GitHub zlyhalo';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Spustiť, keď spustenie akcií GitHub zlyhá.';

  @override
  String get githubCommitPushed => 'Potvrdenie GitHubu bolo odoslané';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Spustiť, keď nové odovzdania dosiahnu vetvu.';

  @override
  String get mcpServerFailed => 'Server MCP zlyhal';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Spustiť, keď fungujúci server MCP zlyhá alebo potrebuje prihlásenie.';

  @override
  String get homeAssistantStateChanged => 'Stav domáceho asistenta sa zmenil';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Spustiť, keď sa entita zmení, dosiahne stav alebo prekročí hodnotu.';

  @override
  String get spotifyTrackChanged => 'Skladba Spotify zmenená';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Spustiť, keď sa začne prehrávať iná skladba.';

  @override
  String get neorecallDailySummaryReady => 'Denný súhrn NeoRecall pripravený';

  @override
  String get runWhenADaysSummaryIsFinal => 'Spustiť, keď je súhrn dňa konečný.';

  @override
  String get neorecallConversationRecorded =>
      'Konverzácia NeoRecall bola zaznamenaná';

  @override
  String get runWhenARecordedConversationEnds =>
      'Spustiť, keď sa skončí nahraná konverzácia.';

  @override
  String get geofenceTrigger => 'Poloha geoplot';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Spustite, keď váš telefón dorazí na miesto alebo ho opustí. Vyžaduje sledovanie polohy v telefóne.';

  @override
  String get healthMetricRecorded => 'Metrika zdravia bola zaznamenaná';

  @override
  String get runWhenAHealthReadingArrives =>
      'Spustiť, keď príde synchronizovaný údaj o stave, voliteľne nad alebo pod hodnotou.';

  @override
  String get wearableConnectionChanged => 'Nositeľné pripojené alebo odpojené';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Spustite, keď sa vaše nositeľné zariadenie pripojí alebo odpojí.';

  @override
  String get taskRunFinished => 'Ďalšia úloha dokončená';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Spustite po dokončení, úspechu alebo zlyhaní inej úlohy.';

  @override
  String get appPackageOptional => 'Balík aplikácie (voliteľné)';

  @override
  String get appPackageHelper => 'Napríklad com.whatsapp';

  @override
  String get anyPlatform => 'Akákoľvek platforma';

  @override
  String get spaceIdOptional =>
      'ID servera, skupiny, kanála alebo miestnosti (voliteľné)';

  @override
  String get spaceIdHelper =>
      'Prázdne sleduje každého, v ktorom sa robot nachádza.';

  @override
  String get emojiOptional => 'Emoji (voliteľné)';

  @override
  String get chatIdOptional => 'ID četu (voliteľné)';

  @override
  String get platformOptional => 'Platforma (voliteľné)';

  @override
  String get platformOptionalHelper =>
      'Napríklad whatsapp. Prázdne hodinky všetky.';

  @override
  String get minutesBefore => 'Minúty predtým';

  @override
  String get calendarIdOptional => 'ID kalendára (voliteľné)';

  @override
  String get calendarIdHelper => 'Prázdne používa váš primárny kalendár.';

  @override
  String get invitesOnly => 'Iba pozvánky od ostatných';

  @override
  String get nextcloudCalendarPath => 'Kalendár';

  @override
  String get nextcloudCalendarPathHelper =>
      'Jeho názov v zozname kalendárov Nextcloud, napríklad osobný';

  @override
  String get folderIdOptionalHelperDrive => 'Prázdne sleduje celý Disk.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Prázdny sleduje koreňový priečinok.';

  @override
  String get driveFolderIdOptional => 'ID priečinka (voliteľné)';

  @override
  String get spreadsheetId => 'ID tabuľky';

  @override
  String get sheetRange => 'Rozsah';

  @override
  String get sheetRangeHelper => 'Stĺpce tabuľky, napríklad Hárok1!A:E';

  @override
  String get folderPathOptional => 'Cesta k priečinku (voliteľné)';

  @override
  String get folderPathHelper => 'Napríklad Dokumenty';

  @override
  String get notionDatabaseId => 'ID databázy';

  @override
  String get trelloListId => 'ID zoznamu';

  @override
  String get figmaFileKey => 'Kľúč súboru';

  @override
  String get figmaFileKeyHelper => 'Z odkazu na súbor: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Úložisko';

  @override
  String get workflowOptional => 'Pracovný postup (voliteľné)';

  @override
  String get workflowHelper => 'Názov súboru, napríklad ci.yml';

  @override
  String get branchOptional => 'Pobočka (voliteľné)';

  @override
  String get branchHelper => 'Prázdne používa predvolenú vetvu.';

  @override
  String get mcpServerIdOptional => 'ID servera MCP (voliteľné)';

  @override
  String get entityId => 'ID entity';

  @override
  String get entityIdHelper => 'Napríklad binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Cieľový štát (voliteľné)';

  @override
  String get targetStateHelper => 'Napríklad na';

  @override
  String get aboveOptional => 'Vyššie (voliteľné)';

  @override
  String get belowOptional => 'Nižšie (voliteľné)';

  @override
  String get placeName => 'Názov miesta';

  @override
  String get latitude => 'Zemepisná šírka';

  @override
  String get longitude => 'Zemepisná dĺžka';

  @override
  String get radiusMeters => 'Polomer v metroch';

  @override
  String get geofenceTransition => 'Kedy';

  @override
  String get arriving => 'Príchod';

  @override
  String get leaving => 'Odchádzam';

  @override
  String get healthMetric => 'Metrika zdravia';

  @override
  String get healthMetricHelper =>
      'Napríklad tepová frekvencia, kroky, hmotnosť';

  @override
  String get wearableTransition => 'Keď nositeľné';

  @override
  String get wearableConnects => 'Pripojí sa';

  @override
  String get wearableDisconnects => 'Odpojí sa';

  @override
  String get sourceTask => 'Po úlohe';

  @override
  String get taskOutcome => 'Výsledok';

  @override
  String get anyOutcome => 'Akýkoľvek výsledok';

  @override
  String get succeeded => 'Podarilo sa';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 chýba alebo je neplatný.';
  }

  @override
  String get triggerSectionMessaging => 'Správy';

  @override
  String get triggerSectionDeveloper => 'Vývojár';

  @override
  String get triggerSectionMemory => 'pamäť';

  @override
  String get triggerSectionNews => 'Správy';

  @override
  String get triggerSectionSystem => 'Systém';

  @override
  String get searchTriggersHint =>
      'Vyhľadávajte spúšťače, aplikácie alebo udalosti';

  @override
  String get noTriggersMatch =>
      'Vášmu vyhľadávaniu nezodpovedá žiadny spúšťač.';

  @override
  String get triggerAccountMissing => 'Zatiaľ žiadny účet';

  @override
  String get pickTriggerKeyboardHint => 'Enter vyberie prvý výsledok';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return 'Spúšťa $arg1';
  }

  @override
  String get addFromSkillsSh => 'Pridať z skills.sh';

  @override
  String get skillsShHint =>
      'Vyhľadaním vyššie nájdite zručnosti na skills.sh alebo vložte odkaz skills.sh alebo príkaz `npx skills add`.';

  @override
  String get noSkillsShMatches =>
      'Tomuto vyhľadávaniu nezodpovedajú žiadne zručnosti skills.sh.';

  @override
  String get installingSkill => 'Inštaluje sa…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Nainštalovaný $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return 'Nainštaluje sa $arg1';
  }

  @override
  String get authVerify => 'Overiť';

  @override
  String get authCreateAccount => 'Vytvoriť účet';

  @override
  String get authNewInviteLink => 'Nový odkaz na pozvánku';

  @override
  String get authShowPassword => 'Zobraziť heslo';

  @override
  String get authHidePassword => 'Skryť heslo';

  @override
  String get authPasswordWillBeRejected => 'príliš slabý, bude odmietnutý';

  @override
  String get authUsernameTooShort =>
      'Používateľské mená musia mať aspoň 3 znaky.';

  @override
  String get authUsernameTaken => 'Toto používateľské meno je už obsadené.';

  @override
  String get authSignupsClosed =>
      'Prihlasovanie na tomto serveri je ukončené. Požiadajte správcu o účet.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Tento server akceptuje iba prihlásenia cez HTTPS. Namiesto toho otvorte $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Tento server akceptuje iba prihlásenia cez HTTPS. Pripojte sa k nemu pomocou adresy https://.';

  @override
  String get authAccountNotFound => 'Tento účet už neexistuje.';

  @override
  String get authQrRateLimited =>
      'Príliš veľa žiadostí o prihlásenie pomocou kódu QR. Počkajte chvíľu a potom obnovte kód.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Zabudli ste heslo? Požiadajte správcu servera, aby ho resetoval v časti Správca → Používatelia.';

  @override
  String get authChangeServer => 'Zmeniť server';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Prihlasovanie do $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Táto adresa neodpovedá ako server NeoAgent. Skontrolujte adresu URL a skúste to znova.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Nepodarilo sa otvoriť zabezpečené pripojenie (HTTPS) k $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Nepodarilo sa dosiahnuť $arg1 cez HTTPS a neodpovedal ani obyčajný HTTP. Skontrolujte adresu a port.';
  }

  @override
  String get adminResetPassword => 'Obnoviť heslo';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Obnoviť heslo pre $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Zvoľte si nové heslo pre $arg1. Budú odhlásení zo všetkých zariadení a znova sa prihlásia pomocou tohto hesla.';
  }

  @override
  String get adminNewPassword => 'Nové heslo';

  @override
  String get adminSetPassword => 'Nastaviť heslo';

  @override
  String get authMissingFields => 'Vyplňte každé povinné pole.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 resetuje heslo $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Heslo aktualizované; používateľ bol všade odhlásený.';

  @override
  String get authSignInTitle => 'Prihláste sa do NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Skenujte pomocou telefónu alebo použite heslo.';

  @override
  String get authOrUsePassword => 'alebo použite svoje heslo';

  @override
  String get qrLoginWaitingTitle => 'Schváľte na svojom telefóne';

  @override
  String get qrLoginWaitingBody =>
      'Váš telefón naskenoval kód. Potvrďte prihlásenie, aby ste dokončili prihlásenie.';

  @override
  String get qrLoginSigningInOn => 'Prihlasovanie je zapnuté';

  @override
  String get qrLoginLocation => 'Poloha';

  @override
  String get qrLoginWaitingForApproval => 'Čaká sa na schválenie';

  @override
  String get qrLoginCancelAndUsePassword => 'Zrušte a použite heslo';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Prihlásenie bolo vo vašom telefóne odmietnuté. Naskenujte nový kód a skúste to znova.';

  @override
  String get signupKey => 'Registračný kľúč';

  @override
  String get signupKeyStepSubtitle =>
      'Nové účty na tomto serveri vyžadujú registračný kľúč. Zadajte kľúč, ktorý ste dostali od správcu.';

  @override
  String get signupKeyChange => 'Zmeniť';

  @override
  String get signupKeyRequiredError => 'Zadajte svoj registračný kľúč.';

  @override
  String get signupKeyInvalidError =>
      'Tento registračný kľúč nie je platný. Skontrolujte ho a skúste to znova.';

  @override
  String get signupKeyUsedError =>
      'Tento registračný kľúč už bol použitý. Požiadajte správcu o nový.';

  @override
  String get adminRequireSignupKey => 'Vyžadovať registračný kľúč';

  @override
  String get adminRequireSignupKeyHint =>
      'Nové účty vyžadujú jednorazový kľúč od správcu. Keď je vypnuté, môže sa zaregistrovať ktokoľvek, kto sa dostane k tomuto serveru. Prvý účet kľúč nikdy nepotrebuje.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Nové účty teraz vyžadujú registračný kľúč.';

  @override
  String get adminSignupOpenNotice => 'Teraz sa môže zaregistrovať ktokoľvek.';

  @override
  String get signupKeys => 'Registračné kľúče';

  @override
  String get signupKeysDescription =>
      'Jednorazové kľúče na registráciu, kým sa kľúč vyžaduje. Každý kľúč vytvorí práve jeden účet.';

  @override
  String get signupKeysNew => 'Nové kľúče';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Nepoužité · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Použité · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Zrušené · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Všetky · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Nepoužitý';

  @override
  String get signupKeyStatusUsed => 'Použitý';

  @override
  String get signupKeyStatusRevoked => 'Zrušený';

  @override
  String get signupKeysExport => 'Exportovať .txt';

  @override
  String get signupKeysCopied => 'Kľúče skopírované';

  @override
  String get signupKeyCopied => 'Kľúč skopírovaný';

  @override
  String get signupKeysEmpty => 'V tomto zozname nie sú žiadne kľúče.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Vytvorené $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Použil(a) $arg1, $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Použité $arg1 účtom, ktorý bol medzitým odstránený';
  }

  @override
  String get signupKeyRevokeTitle => 'Zrušiť tento kľúč?';

  @override
  String get signupKeyRevokeMessage =>
      'Nikto sa s ním už nebude môcť zaregistrovať. Túto akciu nemožno vrátiť.';

  @override
  String get signupKeyRevoked => 'Kľúč zrušený.';

  @override
  String signupKeysShowMore(int count) {
    return 'Zobraziť ďalších $count';
  }

  @override
  String get signupKeysCreateTitle => 'Vytvoriť registračné kľúče';

  @override
  String get signupKeysCount => 'Počet kľúčov';

  @override
  String get signupKeysCountHelper => '1 až 500';

  @override
  String get signupKeysCountInvalid => 'Zadajte číslo od 1 do 500.';

  @override
  String get signupKeysLabel => 'Označenie (voliteľné)';

  @override
  String get signupKeysLabelHint => 'napr. Jarní beta testeri';

  @override
  String signupKeysCreateAction(int count) {
    return 'Vytvoriť ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Pripravené kľúče: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Každý kľúč odovzdajte iba jednej osobe. Nepoužité kľúče zostávajú v zozname, takže ich môžete neskôr znova skopírovať alebo exportovať.';

  @override
  String get signupKeysSaveDialogTitle => 'Uložiť registračné kľúče';

  @override
  String get signupKeysExported => 'Kľúče exportované.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor vytvoril(a) registračné kľúče ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor zrušil(a) registračný kľúč';
  }

  @override
  String get providerChooseUsername => 'Zvoľte si používateľské meno';

  @override
  String get providerChooseUsernameBody =>
      'Zvoľte si dostupné používateľské meno a dokončite vytvorenie účtu.';

  @override
  String get dataSharingTitle => 'Zdieľať údaje o používaní';

  @override
  String get dataSharingDescription =>
      'Pomôžte správcom tohto servera ho vylepšovať. Zdieľa, ako NeoAgent používate, nikdy to, čo píšete alebo ukladáte.';

  @override
  String dataSharingSince(String date) {
    return 'Zdieľané od $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Čo sa zdieľa';

  @override
  String get dataSharingIncluded => 'Zdieľa sa';

  @override
  String get dataSharingExcluded => 'Nikdy sa nezdieľa';

  @override
  String get dataSharingIncludedDevice => 'Typ zariadenia a verzia aplikácie';

  @override
  String get dataSharingIncludedLocale =>
      'Jazyk aplikácie a oblasť časového pásma, napríklad Európa';

  @override
  String get dataSharingIncludedFeatures =>
      'Ktoré funkcie máte nastavené, napríklad úlohy, skilly a integrácie';

  @override
  String get dataSharingIncludedRuns =>
      'Ktoré nástroje a modely používajú vaše behy, s trvaním a počtom tokenov';

  @override
  String get dataSharingIncludedActivity =>
      'Kedy NeoAgent používate, podľa dňa v týždni a hodiny';

  @override
  String get dataSharingExcludedContent => 'Správy, prompty a odpovede';

  @override
  String get dataSharingExcludedRuns =>
      'Názvy behov, vstupy a výsledky nástrojov';

  @override
  String get dataSharingExcludedFiles =>
      'Súbory, spomienky a všetko ostatné, čo ukladáte';

  @override
  String get dataSharingExcludedIdentity =>
      'Vaše meno, e-mail, IP adresa a poloha';

  @override
  String get dataSharingExcludedAccounts =>
      'Účty, s ktorými prepájate integrácie';

  @override
  String get dataSharingPooledNote =>
      'Správcovia vidia iba súčty za všetkých, ktorí zdieľajú, nikdy nie vás samotných. Kedykoľvek to vypnite a hneď zo súčtov vypadnete.';

  @override
  String get dataSharingConfirmTitle => 'Zdieľať údaje o používaní?';

  @override
  String get dataSharingConfirmAction => 'Zdieľať';

  @override
  String get sharedUsageTitle => 'Zdieľané používanie';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Účty zdieľajúce údaje o používaní: $sharing z $total. Iba súčty, žiadny obsah.';
  }

  @override
  String get sharedUsageEmpty =>
      'Zatiaľ nikto nezdieľa údaje o používaní. Zapnúť sa to dá v: Nastavenia, Profil, Vaše údaje.';

  @override
  String get sharedUsageRuns => 'Zdieľané behy';

  @override
  String get sharedUsageAvgDuration => 'Priem. trvanie';

  @override
  String get sharedUsageCompletedRuns => 'Dokončené behy';

  @override
  String get sharedUsageStepsPerRun => 'Kroky na beh';

  @override
  String get sharedUsageDevices => 'Zariadenia';

  @override
  String get sharedUsageAppVersions => 'Verzie aplikácie';

  @override
  String get sharedUsageLanguages => 'Jazyky';

  @override
  String get sharedUsageRegions => 'Oblasti';

  @override
  String get sharedUsageFeatures => 'Využitie funkcií';

  @override
  String get sharedUsageFeaturesDescription =>
      'Podiel zdieľajúcich účtov, ktoré ju majú nastavenú.';

  @override
  String get sharedUsageTools => 'Nástroje';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Najčastejšie volané nástroje ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Volania: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Zlyhalo: $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Integrácie';

  @override
  String get sharedUsageMessaging => 'Kanály správ';

  @override
  String get sharedUsageTriggers => 'Ako sa behy začínajú';

  @override
  String get sharedUsageActivity => 'Kedy sa používa';

  @override
  String get sharedUsageActivityDescription =>
      'Behy podľa dňa v týždni a hodiny, UTC.';

  @override
  String get sharedUsageModels => 'Výkon modelov';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'priem. $latency · $cached % z cache · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Účty: $count';
  }

  @override
  String get sharedUsageNoData => 'V tomto období nič.';

  @override
  String get sharedUsageNotReported => 'Zatiaľ nenahlásené';

  @override
  String get sharedUsageFeatureAgents => 'Viac ako jeden agent';

  @override
  String get sharedUsageFeatureTasks => 'Plánované úlohy';

  @override
  String get sharedUsageFeatureSkills => 'Skilly';

  @override
  String get sharedUsageFeatureMcp => 'MCP servery';

  @override
  String get sharedUsageFeatureIntegrations => 'Integrácie';

  @override
  String get sharedUsageFeatureMessaging => 'Kanály správ';

  @override
  String get sharedUsageFeatureMemory => 'Pamäť';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in zdieľanie údajov telemetria zariadenia funkcie nástroje modely aktivita';

  @override
  String get yourOAuthApp => 'Vaša OAuth aplikácia';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Vaša OAuth aplikácia $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Tento server nemá globálnu aplikáciu $provider, preto sa pripájate cez OAuth aplikáciu, ktorú si zaregistrujete sami. Tajný kľúč klienta sa uloží šifrovane a už sa nikdy nezobrazí.';
  }

  @override
  String get oauthAppStepCreate => '1. Vytvorte aplikáciu';

  @override
  String get openDeveloperConsole => 'Otvoriť vývojársku konzolu';

  @override
  String get oauthAppStepCallback => '2. Zaregistrujte túto callback URL';

  @override
  String get callbackUrlCopied => 'Callback URL skopírovaná';

  @override
  String get oauthAppScopes => 'Povolené scopy';

  @override
  String get scopesCopied => 'Scopy skopírované';

  @override
  String get oauthAppStepCredentials =>
      '3. Vložte prihlasovacie údaje aplikácie';

  @override
  String get couldNotSaveOAuthApp => 'OAuth aplikáciu sa nepodarilo uložiť.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Odstrániť vašu aplikáciu $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'Pripojené účty zostanú v zozname, ale prestanú fungovať, kým znova nepridáte aplikáciu.';

  @override
  String get globalIntegrationConfiguration =>
      'Globálna konfigurácia integrácií';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Voliteľné OAuth aplikácie pre celý server. Ak ju integrácia má, používa ju každý účet a nemôže pridať vlastnú. Nechajte integráciu nenastavenú a každý používateľ si nastaví vlastnú aplikáciu. Tajné údaje sa dajú iba zapisovať: nechajte prázdne, ak chcete zachovať uloženú hodnotu.';

  @override
  String get globalStatus => 'Globálne';

  @override
  String get perUserStatus => 'Pre používateľa';

  @override
  String get phoneSyncGuidance =>
      'Zdieľajte kalendáre a kontakty z tohto telefónu so svojím agentom. Funguje so všetkými účtami, ktoré už v telefóne sú.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Otvorte NeoAgent v telefóne a zapnite tam zdieľanie. Agent potom uvidí kalendáre a kontakty všetkých účtov v tom telefóne.';

  @override
  String get manageOnThisPhone => 'Spravovať v tomto telefóne';

  @override
  String get setUpOnThisPhone => 'Nastaviť v tomto telefóne';

  @override
  String get setUpOnPhone => 'Nastaviť v telefóne';

  @override
  String emailConnectedArg1(String email) {
    return 'Pripojené $email';
  }

  @override
  String get couldNotConnectEmail => 'Účet sa nepodarilo pripojiť.';

  @override
  String get emailSetupTitle => 'Pripojiť e-mail a kalendár';

  @override
  String get emailChecking => 'Kontrolujem schránku…';

  @override
  String get emailSetupIntro =>
      'Použite heslo aplikácie od poskytovateľa e-mailu. Bez vývojárskej konzoly, hotovo za pár minút.';

  @override
  String emailOpenArg1(String provider) {
    return 'Otvoriť $provider';
  }

  @override
  String get emailStepServers => '1. Zadajte servery';

  @override
  String get emailStepPassword => '1. Vytvorte heslo aplikácie';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Otvoriť heslá aplikácií $provider';
  }

  @override
  String get emailStepSignIn => '2. Prihlásenie';

  @override
  String get appPassword => 'Heslo aplikácie';

  @override
  String get appPasswordHelper =>
      'Na medzerách nezáleží. NeoAgent ho ukladá šifrovane.';

  @override
  String get emailUsernameOptional =>
      'Používateľské meno, ak to nie je váš e-mail';

  @override
  String get emailIncludeCalendar => 'Zahrnúť kalendár';

  @override
  String get emailIncludeContacts => 'Zahrnúť kontakty';

  @override
  String get imapServer => 'Server IMAP';

  @override
  String get smtpServer => 'Server SMTP';

  @override
  String get caldavUrlOptional => 'Adresa CalDAV (voliteľné)';

  @override
  String get carddavUrlOptional => 'Adresa CardDAV (voliteľné)';

  @override
  String get alternativeEmail =>
      'Pripojte schránku heslom aplikácie alebo kalendár jeho odkazom iCal. Hotovo za pár minút.';

  @override
  String get alternativePhone =>
      'Zdieľajte kalendár a kontakty z telefónu cez aplikáciu NeoAgent.';

  @override
  String get alternativePhoneElsewhere =>
      'Zdieľajte kalendár a kontakty z telefónu. Nastavte to v aplikácii NeoAgent v telefóne.';

  @override
  String get skipTheDeveloperConsole => 'Bez vývojárskej konzoly';

  @override
  String get phoneSyncPromptTitle => 'Môže agent vidieť váš kalendár?';

  @override
  String get phoneSyncPromptBody =>
      'Zdieľajte kalendáre a kontakty z tohto telefónu, aby agent mohol plánovať podľa vášho dňa. Zmeniť to môžete kedykoľvek v Nástroje › Integrácie.';

  @override
  String get phoneSyncTitle => 'Zdieľať kalendár a kontakty z telefónu';

  @override
  String get phoneSyncIntro =>
      'Agent vidí kalendáre a kontakty všetkých účtov v tomto telefóne. Bez vývojárskej konzoly a ďalšieho prihlásenia.';

  @override
  String get phoneSyncPointAccounts =>
      'Funguje s účtami Google, Outlook, iCloud a Exchange v tomto telefóne.';

  @override
  String get phoneSyncPointPrivate =>
      'Zdieľa sa len s vaším serverom NeoAgent, ktorý ich ukladá šifrovane.';

  @override
  String get phoneSyncPointWrites =>
      'Udalosti pridané agentom vytvorí tento telefón a synchronizujú sa ako zvyčajne.';

  @override
  String get phoneSyncCalendarHint =>
      'Udalosti od 30 dní dozadu do 90 dní dopredu';

  @override
  String get phoneSyncContacts => 'Kontakty';

  @override
  String get phoneSyncContactsHint =>
      'Mená, e-mailové adresy a telefónne čísla';

  @override
  String get phoneSyncOtherAgent =>
      'Tento telefón zdieľa s iným agentom. Zdieľaním tu sa presunie k tomuto agentovi.';

  @override
  String get phoneSyncDenied =>
      'NeoAgent zatiaľ nemá prístup. Povoľte ho v Nastaveniach a vráťte sa.';

  @override
  String get openPhoneSettings => 'Otvoriť Nastavenia';

  @override
  String get phoneSyncShare => 'Zdieľať s NeoAgent';

  @override
  String get phoneSyncStop => 'Ukončiť zdieľanie';

  @override
  String get phoneSyncWaiting => 'Čakám na prvú synchronizáciu…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Naposledy synchronizované $time';
  }

  @override
  String get calendarLink => 'Odkaz na kalendár';

  @override
  String get calendarLinkHelper =>
      'Adresa iCal kalendára. Ktokoľvek ju pozná, môže kalendár čítať, preto ju uchovajte v súkromí.';

  @override
  String get calendarLinkName => 'Názov (voliteľné)';

  @override
  String get calendarLinkAdded => 'Kalendár pridaný';

  @override
  String get toolsApps => 'Aplikácie';

  @override
  String get reconnect => 'Znova pripojiť';

  @override
  String get reconnectNeeded => 'Treba znova pripojiť';

  @override
  String get mixedAccess => 'Zmiešaný prístup';

  @override
  String disconnectAccountTitle(String account) {
    return 'Odpojiť $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Agent cez tento účet stratí prístup k $apps.';
  }

  @override
  String get neoRouterServerDescription =>
      'Pripojte svoj NeoRouter raz a každý účet tu ho použije na úlohy zapnuté nižšie.';

  @override
  String get neoRouterUserDescription =>
      'Na úlohy zapnuté nižšie použite vlastný účet NeoRouter namiesto poskytovateľov tohto servera.';

  @override
  String get neoRouterAddress => 'Adresa NeoRoutera';

  @override
  String get neoRouterConnect => 'Pripojiť NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Schváľte NeoAgent v NeoRouteri. Zobrazuje kód $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Otvoriť znova';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Pripojené k $arg1';
  }

  @override
  String get neoRouterUnreachable => 'NeoRouter teraz nie je dostupný.';

  @override
  String get neoRouterDisconnect => 'Odpojiť';

  @override
  String get neoRouterDisconnectBody =>
      'NeoAgent prestane tento NeoRouter používať. Ak chcete odobrať aj kľúč, zrušte ho v NeoRouteri v časti Kľúče API.';

  @override
  String get neoRouterServerInUse =>
      'Tento server už používa NeoRouter pre všetkých. Pripojte vlastný účet NeoRouter pre vlastné modely a rozpočet.';

  @override
  String get neoRouterConnected => 'NeoRouter je pripojený.';

  @override
  String get neoRouterRoleChat => 'Chat a rozpoznávanie obrazu';

  @override
  String get neoRouterRoleSystemOne => 'Rozhodnutia System One';

  @override
  String get neoRouterRoleTranscription => 'Reč na text';

  @override
  String get neoRouterRoleLive => 'Živý hlas';

  @override
  String get neoRouterRoleEmbeddings => 'Hľadanie v pamäti';

  @override
  String get neoRouterRoleImages => 'Tvorba obrázkov';

  @override
  String get neoRouterRoleSearch => 'Vyhľadávanie na webe';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'V NeoRouteri dostupné: $arg1';
  }

  @override
  String get neoRouterNoModels => 'V NeoRouteri zatiaľ nič nie je.';

  @override
  String get neoRouterPicksModels =>
      'NeoRouter vyberá model pre každú požiadavku, takže tento výber sa nepoužíva.';

  @override
  String neoRouterNotAllowedArg1(Object? arg1) {
    return 'V NeoRouteri: $arg1, ale kľúč NeoAgentu ich zatiaľ nesmie používať (napr. platené). Povoľte ich pre NeoAgent v NeoRouteri v časti Kľúče API.';
  }

  @override
  String get neoRouterNoDecisionModels =>
      'Potrebuje rozhodovacie modely, ako je Jev. Bezpečnostné klasifikátory na tieto otázky neodpovedia.';

  @override
  String get voiceLiveNoProvider =>
      'Nie je nastavený žiadny poskytovateľ živého hlasu. Pridajte kľúč OpenAI alebo Google AI, alebo pripojte NeoRouter (Modelky → Prineste si vlastný kľúč).';

  @override
  String get voiceSttAutoNeoRouter => 'Automaticky (model vyberá NeoRouter)';

  @override
  String get voiceNotOffered => 'Už nie je k dispozícii, vyberte iné';
}
