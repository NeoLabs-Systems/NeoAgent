// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppL10nCs extends AppL10n {
  AppL10nCs([String locale = 'cs']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Vítejte';

  @override
  String get onboardingEyebrowCommunication => 'Komunikace';

  @override
  String get onboardingEyebrowIntelligence => 'Inteligence';

  @override
  String get onboardingEyebrowComputer => 'Počítač';

  @override
  String get onboardingEyebrowAutomation => 'automatizace';

  @override
  String get onboardingNext => 'Další';

  @override
  String get onboardingIntroCouldNotLoad => 'Úvod se nepodařilo načíst.';

  @override
  String get onboardingModelDescription =>
      'Vyberte model, který má NeoAgent používat jako výchozí, nebo jej nechte vybrat automaticky.';

  @override
  String get onboardingLoadingModels => 'Načítání modelů…';

  @override
  String get noAiModelTitle =>
      'Zatím není nastaven žádný model umělé inteligence';

  @override
  String get noAiModelBody =>
      'Přidejte klíč API od poskytovatele, jako je OpenAI, Anthropic nebo Google. NeoAgent poté ukáže modely, které můžete použít.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent potřebuje k odpovědi model umělé inteligence. Přidejte klíč API od poskytovatele, jako je OpenAI, Anthropic nebo Google.';

  @override
  String get noAiModelAdminHint =>
      'Jako správce můžete také nastavit poskytovatele pro všechny v části Správce → Poskytovatelé.';

  @override
  String get addApiKey => 'Přidat klíč API';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform je připojen.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Čekání na připojení $platform…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Nastavení nelze uložit: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Připraven';

  @override
  String get onboardingStepRequired => 'Povinné';

  @override
  String get onboardingStepOptional => 'Volitelné';

  @override
  String get onboardingStepCloudOrLocal => 'Cloudové nebo místní';

  @override
  String get onboardingStepComputer => 'Počítač';

  @override
  String get onboardingStepRoutines => 'Rutiny';

  @override
  String get onboardingComputerChoiceTitle => 'Kde by to mělo\nfungovat?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Můžete přepínat na relaci.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Soukromé pískoviště · vždy zapnuté';

  @override
  String get onboardingThisComputer => 'Tento počítač';

  @override
  String get onboardingThisComputerSubtitle =>
      'Vaše soubory, aplikace a prohlížeč';

  @override
  String get onboardingSearchApps => 'Hledat aplikace…';

  @override
  String get onboardingRoutinesDescription =>
      'Výsledky dorazí do vašich chatů.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Výsledky přicházejí jako oznámení.';

  @override
  String get onboardingNotifications => 'Oznámení';

  @override
  String get onboardingReadyTitle => 'Vše je\npřipraveno.';

  @override
  String get onboardingReadyDescription => 'Pošlete svou první zprávu.';

  @override
  String get onboardingMessageNeoagent => 'Zpráva NeoAgent';

  @override
  String get onboardingAskAnything => 'Zeptejte se na cokoliv…';

  @override
  String get onboardingOpenNeoagent => 'Otevřete NeoAgent';

  @override
  String get onboardingStarterTrip => 'Naplánujte si víkendový výlet';

  @override
  String get onboardingStarterLanding => 'Vytvořte vstupní stránku';

  @override
  String onboardingQuickSteps(int count) {
    return 'Rychlé kroky $count';
  }

  @override
  String get taskNeedsEmail => 'Nejprve připojte e-mail';

  @override
  String get taskNeedsCalendar => 'Nejprve připojte kalendář';

  @override
  String get taskNeedsModel => 'Nejprve nastavte model AI';

  @override
  String get taskPromptDailyRecap =>
      'Zrekapitulujte si můj den: shrňte konverzace, hotovou práci a rozhodnutí z dneška, pak vyjmenujte vše, na co bych měl zítra navázat. Nechte to krátké a pošlete mi to.';

  @override
  String get taskPromptInboxCheck =>
      'Zkontrolujte mou e-mailovou schránku pro zprávy, které dorazily od poslední kontroly. Posílejte mi pouze zprávy o e-mailech, které jsou naléhavé nebo vyžadují odpověď, s jednořádkovým shrnutím každého z nich. Pokud nic nevyžaduje moji pozornost, nic neposílejte.';

  @override
  String get taskPromptMorningBriefing =>
      'Připravte si ranní briefing: dnešní počasí, kde jsem, události v mém kalendáři a nejdůležitější otevřené položky, o kterých vím. Pošlete jej jako krátkou zprávu, kterou lze skenovat.';

  @override
  String get taskPromptTomorrowPrep =>
      'Podívejte se na můj kalendář na zítra. U každé schůzky mi řekněte, o co jde, kdo se jí účastní a co bych měl připravit. Pokud je zítra prázdný, nic neposílejte.';

  @override
  String get taskPromptNewsDigest =>
      'Hledejte na webu dnešní nejdůležitější zprávy o tématech, která mě zajímají (použijte to, co si pamatujete o mých zájmech). Pošlete mi přehled až pěti položek s jednou větou a odkazem.';

  @override
  String get taskPromptWeeklyReview =>
      'Zopakujte si můj týden: co se povedlo, co uklouzlo a co je ještě otevřené. Navrhněte tři nejdůležitější věci, na které se příští týden zaměřit.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Propojte telefonní číslo, které patří agentovi. Kdokoli, komu to povolíte, s ním může chatovat v přímých chatech a skupinách.';

  @override
  String get whatsappSelfChatDescription =>
      'Propojte své vlastní číslo a promluvte si s agentem v chatu „Pošlete si zprávu“. Všechny ostatní chaty a skupiny na tomto účtu jsou ignorovány.';

  @override
  String get chatSendHintMac => '⌘↵ k odeslání';

  @override
  String get chatSendHintOther => 'Ctrl+Enter pro odeslání';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Pro tento koncový bod je vyžadována základní adresa URL.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Změněná e-mailová adresa je před použitím potvrzena.';

  @override
  String get aDecisionHigherUpTheChain => 'Vyhrává rozhodnutí výše v řetězci.';

  @override
  String get aDeletedAccount => 'smazaný účet';

  @override
  String get aFridayLookBackAtThe =>
      'Páteční ohlédnutí za týdnem a plán na další.';

  @override
  String get aKeyThatAsksForA =>
      'Klíč, který požaduje PIN nebo otisk prstu, také nahrazuje váš dvoufaktorový kód.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Jazykový model tuto zprávu posoudil, protože SystemOne je vypnutý.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Soubor metadat nastavení NeoAgent překročil limit bezpečné velikosti.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Na serveru je k dispozici novější webové sestavení. Chcete-li načíst nejnovější balíček, znovu načtěte.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Soukromá plocha s prohlížečem Chromium, soubory, textovým editorem, terminálem a Pythonem. Vaše práce zůstane mezi relacemi uložena.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Soukromý počítač se systémem Linux nebo zařízení Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Požadovaný instalační soubor NeoAgent nelze stáhnout.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Spoluhráč vám pošle odkaz na pozvánku. Jakmile to přijmete, oni ';

  @override
  String get aTeammateSentYouAnInvite =>
      'spoluhráč vám poslal odkaz na pozvánku, zadejte jej sem a připojte se k jeho týmu.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Dočasné stažení bude později vyčištěno.';

  @override
  String get aValueIsStored => 'Hodnota je uložena.';

  @override
  String get access => 'Přístup';

  @override
  String get accessActivity => 'Aktivita přístupu';

  @override
  String accessArg1(Object? arg1) {
    return 'Přístup: $arg1';
  }

  @override
  String get accessMode => 'Režim přístupu';

  @override
  String get accessPermissions => 'Přístupová oprávnění';

  @override
  String get accessToken => 'přístupový token';

  @override
  String get accessToken2 => 'Přístupový token';

  @override
  String get account => 'Účet';

  @override
  String accountArg1(Object? arg1) {
    return 'Účet #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Upozornění na změnu účtu';

  @override
  String get accountEmail => 'E-mail účtu';

  @override
  String get accountEmailIsOffUntilThese =>
      'E-mail účtu je vypnutý, dokud nenastavíte: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent používá tento jazyk všude v aplikaci. Při prvním přihlášení následuje toto zařízení. Poté se výběr uloží na váš účet a použije se na každém zařízení.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Nelze změnit jazyk: $error';
  }

  @override
  String get accountLanguageTitle => 'Jazyk';

  @override
  String get accountNumber => 'Číslo účtu';

  @override
  String get accountSettings => 'Nastavení účtu';

  @override
  String get accounts => 'Účty';

  @override
  String get accountsByTokensUsedAllTime =>
      'Účty podle použitých tokenů po celou dobu.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'cloudové počítače účtů. Změny se projeví po serveru ';

  @override
  String get accountsOnThisServer => 'Účty na tomto serveru';

  @override
  String get active => 'Aktivní';

  @override
  String get activeSessions => 'Aktivní relace';

  @override
  String get activeToday => 'Dnes aktivní';

  @override
  String get add => 'Přidat';

  @override
  String get addAProviderCredentialFirstIts =>
      'Nejprve přidejte přihlašovací údaje poskytovatele. Její modely se zde jednou objeví ';

  @override
  String get addAgent => 'Přidat agenta';

  @override
  String get addAnotherSignInMethodBefore =>
      'Před odstraněním této přidejte další metodu přihlášení.';

  @override
  String get addBinding => 'Přidejte vazbu';

  @override
  String get addByNameOrId => 'Přidejte podle jména nebo ID';

  @override
  String get addByNameOrIdInstead => 'Místo toho přidejte podle jména nebo ID';

  @override
  String get addCredentialBinding => 'Přidejte vazbu pověření';

  @override
  String get addEntry => 'Přidat položku';

  @override
  String get addKey => 'Přidat klíč';

  @override
  String get addMcpServer => 'Přidat MCP server';

  @override
  String get addMemory => 'Přidat paměť';

  @override
  String get memoryReview => 'Zkontrolovat';

  @override
  String get memoryReviewPrompt =>
      'Projdi všechny mé vzpomínky a ukliď je: archivuj duplicity, zastaralá fakta a vše bez trvalé hodnoty. Pak mi stručně řekni, co jsi změnil.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Přidejte větší délku nebo jiný typ znaku.';

  @override
  String get addPeopleOrGroups => 'Přidejte lidi nebo skupiny';

  @override
  String get addSecurityKey => 'Přidejte bezpečnostní klíč';

  @override
  String get addSomeoneOrAGroup => 'Přidejte někoho nebo skupinu';

  @override
  String get addTask => 'Přidat úkol';

  @override
  String get addTests => 'Přidejte testy';

  @override
  String get addTestsForThePartsOf =>
      'Přidejte testy pro části tohoto projektu, které mají nejmenší pokrytí, a poté je spusťte.';

  @override
  String get addTheirOwnKeysInSettings => 'přidat vlastní klíče v Nastavení.';

  @override
  String get addToPrompt => 'Přidat do výzvy';

  @override
  String get added => 'Přidáno';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Přidáno $arg1 · Naposledy použité $arg2';
  }

  @override
  String get addressWithTheProvider => 'adresu u poskytovatele.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Upravte hlasitost reproduktoru, zkontrolujte výchozí nastavení hardwarových tlačítek a spravujte tuto relaci spouštěče.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Upravte vyhledávací nebo stavový filtr, abyste viděli více kanálů zpráv.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Zde upravte hlasitost reproduktoru.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Správce › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Zde se zobrazí administrátorské granty, odkazy na pozvánky a změny správy.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Pokročilý manuální plán pro speciální případy.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Pokročilé: minuta hodina den měsíc všední den.';

  @override
  String get againRightAway => 'hned znovu.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Zástupce: $arg1';
  }

  @override
  String get agentCalls => 'Agent volá';

  @override
  String get agentCommunication => 'Komunikace agentů';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Komunikace agenta: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Režim agenta upravuje pracovní prostor · ⌘↵ odeslat · ⌘N nová relace';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agent se pozastaví a před spuštěním vás požádá o svolení.';

  @override
  String get agentProfile => 'Profil agenta';

  @override
  String get agentVisibleName => 'Viditelné jméno agenta';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agent chce použít $arg1. Klepnutím se rozhodnete.';
  }

  @override
  String get agents => 'Agenti';

  @override
  String get aiAnswerUnreadable => 'Odpověď AI nečitelná';

  @override
  String get aiProviderKeys => 'Klíče poskytovatele AI';

  @override
  String get aiUnavailable => 'AI není k dispozici';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'upozornění a další e-maily z účtu.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Upozorní, když připojení k zasílání zpráv vyžaduje pozornost uživatele';

  @override
  String get all => 'všechny';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Všichni agenti ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Všechny $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Všechny sloty cloudových počítačů jsou aktuálně využívány. Zkuste to znovu za chvíli.';

  @override
  String get allComputerSlotsAreBusy =>
      'Všechny počítačové sloty jsou obsazené';

  @override
  String get allTables => 'Všechny stoly';

  @override
  String get allTime => 'Celou dobu';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Všechny nástroje jsou povoleny — agent může používat jakoukoli funkci bez ptaní. ';

  @override
  String get allow => 'Povolit';

  @override
  String get allowedRunsWithoutAsking => 'Povoleno. Běží bez ptaní.';

  @override
  String get allowAll => 'Povolit vše';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Povolte aplikaci NeoAgent „Instalovat neznámé aplikace“ a zkuste aktualizaci zopakovat.';

  @override
  String get allowOnce => 'Povolit jednou';

  @override
  String get allowSender => 'Povolit odesílateli';

  @override
  String get allowSession => 'Povolit relaci';

  @override
  String get allowTheAgentToStartAn =>
      'Umožněte agentovi zahájit s vámi hlasový hovor v aplikaci.';

  @override
  String get allowedOrigins => 'Povolené původy';

  @override
  String get allowedPathPrefix => 'Povolená předpona cesty';

  @override
  String get allowsYouCanChangeThatPer =>
      'umožňuje. Později to můžete změnit na osobu. Odkazy se nikdy neudělují ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'již patří k existujícímu účtu';

  @override
  String get alreadyLinkedToAnotherAccount => 'již propojeno s jiným účtem';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'již propojeno s jiným účtem neoagent';

  @override
  String get alreadyUsed => 'již použitý';

  @override
  String get always => 'Vždy';

  @override
  String get alwaysAllow => 'Vždy povolte';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      'Možnost „Vždy povolit“ zásadu trvale uloží – můžete ji změnit v Nastavení.';

  @override
  String get alwaysAsk => 'Vždy se ptejte';

  @override
  String get alwaysEngage => 'Vždy zapojte';

  @override
  String get alwaysJoins => 'Vždy se připojí';

  @override
  String get anApiKeyIsRequired => 'Je vyžadován klíč API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Večerní shrnutí toho, co se stalo a na co navázat.';

  @override
  String get anHttpOrHttpsUrlIs => 'Je vyžadována adresa URL http nebo https.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'a analytika. Odkazy na tým jsou dostupné na stránce Tým.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Instalace Android APK není na této platformě k dispozici.';

  @override
  String get androidApp => 'aplikace pro Android';

  @override
  String get androidControl => 'Ovládání Android';

  @override
  String get androidCouldNotStart => 'Android nelze spustit';

  @override
  String get androidNotificationReceived => 'Oznámení Android přijato';

  @override
  String get androidOnly => 'Pouze Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Instalační program balíčku Android nelze otevřít.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Obrazovka Android – klepnutím se dotkněte, přetažením přejeďte';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Odpovědi @zmínky o problémech a žádostech o stažení';

  @override
  String get anyone => 'Kdokoli';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Kdokoli na této platformě může poslat zprávu $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Kdokoli na této platformě může poslat zprávu $arg1 v $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Se $arg1 může mluvit kdokoli, kdo dosáhne na tento účet.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Kdokoli s odkazem se může připojit, dokud nevyprší jeho platnost nebo jej neodvoláte.';

  @override
  String get apiHttpsOrigin => 'Původ API HTTPS';

  @override
  String get apiKey => 'API klíč';

  @override
  String get apiKey2 => 'api klíč';

  @override
  String get apiKey3 => 'Klíč API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api klíč antropický claude openai gpt xai grok google gemini minimax nvidia nim přihlašovací údaje openrouter';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Klíče API a koncové body pro AI, vyhledávání a hlasové poskytovatele. Oni ';

  @override
  String get apiRequest => 'Žádost API';

  @override
  String get apiYourOwnServerASelf =>
      'API – váš vlastní server, model s vlastním hostitelem nebo jiný ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Stažení souboru APK se nezdařilo s HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Název aplikace je povinný.';

  @override
  String get appUpdates => 'Aktualizace aplikací';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Aktualizace aplikací nejsou pro toto sestavení nakonfigurovány.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Použity aktualizace řízení $arg1 ve frontě na aktuální běh.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Použitá aktualizace řízení $arg1.';
  }

  @override
  String get apply => 'Použít';

  @override
  String get applyBehaviorNotes => 'Použijte poznámky k chování';

  @override
  String get applyCoreMemory => 'Použijte základní paměť';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Žádosti o schválení pro nástroje citlivého agenta';

  @override
  String get approvalRequired => 'Je vyžadováno schválení';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Schválení zůstává ve vaší ověřené mobilní relaci a platnost každého kódu po krátkém okně automaticky vyprší.';

  @override
  String get approveLogin => 'Schválit přihlášení';

  @override
  String get approveQrLogin => 'Schválit přihlášení pomocí QR kódu';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Schvalte to pouze v případě, že jste se na tomto zařízení právě teď spustili.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Schválené přihlášení pro $arg1.';
  }

  @override
  String get approvedOnly => 'Pouze schváleno';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Schválené párování pro $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Schválení lidé a skupiny';

  @override
  String get approvedPeopleOnly => 'Pouze schválené osoby';

  @override
  String get archive => 'Archiv';

  @override
  String get archiveAgent => 'Archivní agent?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archiv ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Archiv $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Archivovat vybrané vzpomínky?';

  @override
  String get areSharedByEveryAccountOn =>
      'jsou sdíleny každým účtem na tomto serveru; účty stále mohou ';

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
    return 'Je vyžadován přístup $arg1';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'Účty $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktivní';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return 'Přidáno $arg1. Upravte jej kdykoli a změňte jej ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '„$arg1“ a jeho historie běhů budou trvale smazány. Jakýkoli aktivní běh bude zastaven. Soubory v pracovním prostoru se nedotknou.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Vyžaduje se schválení $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'Aplikace $arg1 jsou aktivní';
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
    return '$arg1 (aktivní nástroje $arg2)';
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
    return '$arg1 $arg2 na $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 změněno';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 znaky';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Vytvořeno $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [místní adresa: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 odpovídající „$arg3“';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return 'Pracovní prostor $arg1${arg2}NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\nNové účty $arg2';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 běží · ';
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
    return '$arg1 · Řízení $arg2 ve frontě';
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
    return '$arg1 se stal správcem ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 bajtů';
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
    return '$arg1 vymazáno.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 nakonfigurováno';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 připojeno. Vyberte úložiště a lidi v části Kdo může posílat zprávy.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return 'Vstupy jádra $arg1.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 vytvořil odkaz na pozvánku';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return 'Desktop $arg1';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'Události $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 se nezdařilo';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 se nezdařilo';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 selhává';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 pro $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Pouze označené skupiny $arg1';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return 'Před ${arg1}h';
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
    return '(Poměr zásahů $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 je správce, takže účet nelze smazat ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 je blokován na $arg2. Aktualizujte přístupový seznam, abyste povolili odpovědi.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 je připojen a odpovídá.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 již není správcem ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 není k dispozici na $arg2 (chybí oprávnění nebo závislost za běhu).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 se připojil pod $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 posuzoval LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return 'Nakonfigurován klíč $arg1$arg2';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Klíč $arg1 odstraněn.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 vlevo';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 vlevo $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 propojeno';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return 'Před ${arg1}m';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Ujistěte se, že běží, a zkuste to znovu.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return 'Tento účet spravuje $arg1';
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
    return '$arg1 min $arg2 sec';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Modely $arg1 připraveny';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 další';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 další kroky v historii běhu';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 přesunut z $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 musí být konečné číslo.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 musí být adresa http:// nebo https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 vyžaduje pozornost';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Pracovní prostor $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return 'Nové účty $arg1 v posledním $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nové zprávy řídí tento běh';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return 'Nové běhy $arg1';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return 'Tento účet nyní spravuje $arg1.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 ze 4 povolených oprávnění. Soubory jsou omezeny na složku NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 z $arg2 povoleno';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 ze skupin $arg2 se připojí k běžnému chatu';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 modelů $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return 'Připraveno $arg1 modelů $arg2';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 ze sady $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return 'Jsou povoleny nástroje $arg1 nebo $arg2';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: Dobře';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 v den $arg2 v $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 odpovídá pouze lidem, které přidáte níže.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 odpovídá pouze při označení';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 mluví pouze s lidmi a skupinami, které schválíte';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Přidáno $arg1 lidí nebo skupin';
  }

  @override
  String arg1Planning(Object? arg1) {
    return 'Plánování $arg1';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Poskytovatelé $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 připraven';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Záznamy $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI přesměrování $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return 'Registrováno $arg1';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 odpověděl';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 zrušil odkaz s pozvánkou';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 běží';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 běží · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 běží v posledním $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 uloženo.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sec';
  }

  @override
  String arg1Selected(Object? arg1) {
    return 'Vybráno $arg1';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Zobrazeno $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 zůstal tichý';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return 'Řízení $arg1 $arg2 ve frontě';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 krok$arg2 · klepněte na uzel, který chcete zkontrolovat';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 kroky';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 přestal spravovat $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'Tokeny $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Tokeny $arg1 v posledním $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Nástroje $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (nedostupné uložené přepsání)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1 % využito · $arg2 zbývající';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 s vámi chce mluvit.';
  }

  @override
  String arg1Web(Object? arg1) {
    return 'Web $arg1';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '„$arg1“ bude trvale odstraněno.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 bude tento účet spravovat';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 na této platformě neodpoví';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 neodpoví na $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Ukládání artefaktů uživatelem';

  @override
  String get askAQuestionOrStartA => 'Položte otázku nebo začněte úkol...';

  @override
  String get askBeforeClosingToBackground =>
      'Zeptejte se před zavřením na pozadí';

  @override
  String get askMe => 'Zeptej se mě';

  @override
  String get assignedAgent => 'Přidělený agent';

  @override
  String get assignedAgent2 => 'Přidělený agent';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Přidělený agent: $arg1';
  }

  @override
  String get assigneeOptional => 'Nabyvatel (volitelné)';

  @override
  String get assistant => 'asistent';

  @override
  String get assistantKey131 => 'Klíč asistenta 131';

  @override
  String get atLeast1 => 'Minimálně 1.';

  @override
  String get attachFiles => 'Připojit soubory';

  @override
  String attentionArg1(Object? arg1) {
    return 'Pozor $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'audit log admin grant revoke pozvat historii týmu';

  @override
  String get authMethod => 'Metoda ověřování';

  @override
  String get authServerUrl => 'Adresa URL autorizačního serveru';

  @override
  String get authentication => 'Autentizace';

  @override
  String get authenticationFailed => 'Ověření se nezdařilo.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Ověření stále čeká. Dokončete proces prohlížeče a zkuste to znovu.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Ověření stále čeká. Dokončete tok prohlížeče a obnovte jej.';

  @override
  String get authenticationTimedOut => 'Časový limit autentizace vypršel.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Autentizace byla před dokončením zrušena.';

  @override
  String get authenticatorApp => 'Aplikace Authenticator';

  @override
  String get authenticatorCode => 'Authenticator kód';

  @override
  String get authorOptional => 'Autor (volitelné)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (první poskytovatel s klíčem API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automatické směrování na nejlepší dostupný model';

  @override
  String get automaticFast => 'Automaticky (rychle)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatika čte místnost a normálně se drží zpátky. Pouze zmínka neprovede žádné rozhodnutí, dokud nebude přímo adresována.';

  @override
  String get automaticReserved => 'Automatické, rezervované';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automatické vrácení zpět vyžaduje opakování z obrazovky nastavení.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automaticky vybere rychlý model prostřednictvím katalogu normálních modelů.';

  @override
  String get automation => 'automatizace';

  @override
  String get available => 'K dispozici';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'K dispozici opět v $arg1';
  }

  @override
  String get availableAgainShortly => 'Brzy opět k dispozici';

  @override
  String get availableInTheDesktopAppFor =>
      'K dispozici v desktopové aplikaci pro macOS, Windows a Linux';

  @override
  String get availableToTheAgent => 'K dispozici agentovi';

  @override
  String get averageAllTime => 'Průměr, celou dobu';

  @override
  String get avgImp => 'Prům. zobr.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Prům./běh: tokeny $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Vyhněte se opakovaným znakům a zjevným sekvencím.';

  @override
  String get awaitingScan => 'Čeká se na skenování';

  @override
  String get back => 'Zpět';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count na pozadí';
  }

  @override
  String get backgroundTasks => 'Úlohy na pozadí';

  @override
  String get backOn => 'zpět na.';

  @override
  String get backToChat => 'Zpět na chat';

  @override
  String get backToFolder => 'Zpět do složky';

  @override
  String get backToSignIn => 'Zpět k přihlášení';

  @override
  String get backendChannel => 'Backendový kanál';

  @override
  String get backendOnThisComputer => 'Backend na tomto počítači';

  @override
  String get backendSync => 'Backend synchronizace';

  @override
  String get backgroundLocationNeeded => 'Je potřeba umístění pozadí';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Synchronizace na pozadí zůstává v systému Android naplánována';

  @override
  String get badState => 'Špatný stav: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Základní obraz a velikost spuštěných virtuálních strojů QEMU ';

  @override
  String get baseUrlOptional => 'Základní adresa URL (volitelné)';

  @override
  String get baseUrlTokenLocal => 'místní token základní adresy URL';

  @override
  String get basicAuthentication => 'Základní autentizace';

  @override
  String get behaviorModules => 'Moduly chování';

  @override
  String get behaviorNotes => 'poznámky k chování';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Zprostředkovatel pověření Bitwarden';

  @override
  String get bitwardenItem => 'Bitwarden předmět';

  @override
  String get bitwardenServer => 'Server Bitwarden';

  @override
  String get blankUsesCommon => 'Blank používá výraz „běžný“';

  @override
  String get blankUsesTheDefaultCallback =>
      'Blank používá výchozí zpětné volání';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Prázdné hodnoty používají výchozí hodnoty poskytovatele.';

  @override
  String get block => 'Blokovat';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Zablokována příchozí zpráva od $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Most kompatibilní s BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'Adresa URL serveru BlueBubbles';

  @override
  String get botToken => 'Bot token';

  @override
  String get botTokenAndApprovedChats => 'Token robota a schválené chaty';

  @override
  String get botTokenAndServerChannelAccess =>
      'Token bota a přístup k serveru/kanálu';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bot token, Events API a přístup ke kanálu';

  @override
  String get botUserId => 'ID uživatele robota';

  @override
  String get botUsername => 'Uživatelské jméno robota';

  @override
  String get brandName => 'Název značky';

  @override
  String get braveSearch => 'Brave Search';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Přemostění jakéhokoli poskytovatele, který může odesílat a přijímat data webhooku.';

  @override
  String get bringYourOwnKey => 'přinést vlastní klíč';

  @override
  String get bringYourOwnKey2 => 'Přineste si vlastní klíč';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Prohlížeč, plocha Linuxu, soubory, terminál a Python sdílejí jeden trvalý cloudový počítač.';

  @override
  String get browserLogin => 'Přihlášení do prohlížeče';

  @override
  String get browserScripting => 'Skriptování prohlížeče';

  @override
  String get call => 'Zavolejte';

  @override
  String get callAgent => 'Zavolejte agentovi';

  @override
  String get callUser => 'Zavolejte uživateli';

  @override
  String get calledByName => 'Volaný jménem';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Může delegovat úkoly na jiné agenty';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Může delegovat na $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Může přijímat delegované úkoly';

  @override
  String get cancel => 'Zrušit';

  @override
  String get cancelTask => 'Zrušit úkol';

  @override
  String get cannotPreview => 'Nelze zobrazit náhled';

  @override
  String get cannotReceiveDelegatedTasks => 'nemůže přijímat delegované úkoly';

  @override
  String get cannotRunYet => 'ještě nemůže běžet.';

  @override
  String get capturedThePage => 'Stránka byla zachycena';

  @override
  String get category => 'Kategorie';

  @override
  String chainArg1(Object? arg1) {
    return 'Řetěz: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Změňte režim nastavení';

  @override
  String get channel => 'kanál';

  @override
  String get channelAccessToken => 'Token přístupu ke kanálu';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanál: $arg1$arg2 | Verze aktualizace: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Sociální paměť v rámci kanálu';

  @override
  String get channels => 'Kanály';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'ID chatu';

  @override
  String get chatMode => 'Režim chatu';

  @override
  String get chatModel => 'Model chatu';

  @override
  String get checkAutomaticallyOnLaunch => 'Kontrola automaticky při spuštění';

  @override
  String get checkForMessagesEveryMs => 'Kontrolovat zprávy každých (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Automaticky kontrolovat nové zprávy';

  @override
  String get checkNow => 'Zkontrolujte nyní';

  @override
  String get checkYourEmailToConfirmYour =>
      'Před přihlášením zkontrolujte svůj e-mail a potvrďte svůj účet NeoAgent.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Zkontrolováno $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Vyberte kategorii nebo hledejte ve všech nastaveních.';

  @override
  String get chooseAPerson => 'Vyberte osobu';

  @override
  String get chooseAProjectFolder => 'Vyberte složku projektu';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Vyberte výchozí nastavení pro chat, agenty, nouzové chování a chytré směrování.';

  @override
  String get chooseGroups => 'Vyberte skupiny';

  @override
  String get chooseHowMuchYouWantTo =>
      'Vyberte, kolik chcete nyní konfigurovat. Obě možnosti lze později změnit.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Vyberte, jak má tento úkol začít. Manuální spuštění pouze na Spustit nyní. Rozvrh je založen na čase. Integrace spustí spuštění z připojených oficiálních aplikací.';

  @override
  String get chooseOneToGetStartedNow =>
      'Vyberte si jednu a začněte hned teď. Později můžete přidat další.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'V Nastavení vyberte živý model a hlas.';

  @override
  String get chooseTheirGroup => 'Vyberte jejich skupinu';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Vyberte, kde má mít tato osoba povoleno mluvit se $arg1. Toto můžete později změnit v části Kdo může poslat zprávu.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Vyberte, ke kterým skupinám se má $arg1 připojit, i když je nikdo neoznačí. Tato platforma nemusí rozlišovat značky od běžných zpráv.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Vyberte, které modely si může vybrat každý účet na tomto serveru ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Vyberte, s kým $arg1 mluví a kdy se připojí ke skupinovým chatům.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Vyberte, kdo může dosáhnout $arg1, a poté uložte změny.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Vyberte, kdo může poslat zprávu agentovi pomocí „Kdo může posílat zprávy“ na kartě WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Vyberte svůj\nvýchozí model.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, soubory, textový editor a terminál jsou dostupné z plochy Linuxu.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Vymazat';

  @override
  String get clearAll => 'Vymazat vše';

  @override
  String clearArg1(Object? arg1) {
    return 'Vymazat $arg1?';
  }

  @override
  String get clearFilter => 'Vymazat filtr';

  @override
  String get clearFilters => 'Vymazat filtry';

  @override
  String get clearSearch => 'Vymazat vyhledávání';

  @override
  String get clearView => 'Jasný výhled';

  @override
  String get cliSession => 'relace CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'click není na této platformě podporováno.';

  @override
  String get clickOnceToBeginCapturing => 'Jedním kliknutím zahájíte snímání';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Klikněte, zadejte a pracujte s aplikacemi pro stolní počítače.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kliknutí na ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Kliknuto v prohlížeči';

  @override
  String get clientId => 'ID klienta';

  @override
  String get clientSecret => 'Tajemství klienta';

  @override
  String get close => 'Zavřít';

  @override
  String get closeJ => 'Zavřít (⌘J)';

  @override
  String get closeTeachMode => 'Zavřete režim výuky';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Zavřením okna můžete buď ponechat NeoAgent spuštěný na pozadí s přístupem na lištu, nebo zcela ukončit běhové prostředí plochy.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Jsou podporovány cloudové a samostatně hostované instance. Lokální a soukromé adresy URL fungují, když je NeoAgent může dosáhnout.';

  @override
  String get cloudComputer => 'Cloudový počítač';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Cloudový počítač · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Nastavení cloudového počítače bylo uloženo. Chcete-li je použít, restartujte server.';

  @override
  String get cloudComputerVm => 'Cloudový počítač (VM)';

  @override
  String get cloudComputers => 'Cloudové počítače';

  @override
  String get codeHosting => 'Hosting kódu';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Názvy kanálů oddělené čárkami, bez #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Čárkou oddělené, například #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Odděleno čárkou. Problém musí mít všechny.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Příkaz selhal ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Je vyžadován příkaz.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Akumulátor povelového výstupu není aktivní.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Odeslání výstupu příkazu se nezdařilo ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Výstup příkazu nahrání vynechaných metadat artefaktu.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Výstup příkazu byl již dokončen.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Příkazy a aplikace';

  @override
  String get commandsRunInTheSamePersistent =>
      'Příkazy se spouštějí ve stejném trvalém počítači, který používá viditelná plocha.';

  @override
  String get communityChatops => 'Community & ChatOps';

  @override
  String get completeSetup => 'Dokončete nastavení';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Dokončete pracovní postup na ploše.';

  @override
  String get completed => 'Dokončeno';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Zcela blokováno — agent tuto kategorii nemůže použít.';

  @override
  String get computerShell => 'Počítačový shell';

  @override
  String get computerUsedByThisSession => 'Počítač používaný touto relací';

  @override
  String get computerWorkspace => 'Počítačová pracovní plocha';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigurovatelný osobní webhook most';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigurovatelné relé nebo webhook bridge';

  @override
  String get configurableTalkWebhookBridge =>
      'Konfigurovatelný webhookový most Talk';

  @override
  String get configurableWebInboxBridge =>
      'Konfigurovatelný most webové schránky';

  @override
  String get configurableWebhookBridge => 'Konfigurovatelný webhook bridge';

  @override
  String get configurableWebhooks => 'Konfigurovatelné webhooky';

  @override
  String get configurationOrInTheEnvFile => 'Konfigurace nebo v souboru .env.';

  @override
  String get configure => 'Konfigurovat';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Nakonfigurujte chování pracovního prostoru a výchozí hodnoty modelu.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Nakonfigurováno $arg1';
  }

  @override
  String get confirmEmailChanges => 'Potvrďte změny e-mailu';

  @override
  String get confirmNewSignUps => 'Potvrďte nové registrace';

  @override
  String get confirmPassword => 'Potvrďte heslo';

  @override
  String get confirmPassword2 => 'Potvrďte heslo';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Před přihlášením potvrďte svůj e-mail. Zkontrolujte e-mailovou zprávu služby od NeoAgent.';

  @override
  String get connect => 'Připojte se';

  @override
  String get connectAMessagingPlatform =>
      'Připojte platformu\npro zasílání zpráv.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Připojte veřejný koncový bod HTTPS Home Assistant s dlouhotrvajícím přístupovým tokenem. Lokální, zpětná smyčka a privátní síťové adresy jsou serverem blokovány.';

  @override
  String get connectAccount => 'Připojit účet';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Propojte účty aplikací jednotlivě, aby umělá inteligence mohla používat správný účet pro každou oficiální integraci.';

  @override
  String connectArg1(Object? arg1) {
    return 'Připojte $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Připojte tolik účtů, kolik chcete. Každá aplikace může používat jiný účet.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Připojte kanály, vyberte si, s kým $arg1 mluví, a sledujte nedávnou aktivitu.';
  }

  @override
  String get connectInstance => 'Připojte instanci';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Nejprve připojte tuto integraci a vyberte účet.';

  @override
  String get connectToThisServer => 'Připojte se k tomuto serveru';

  @override
  String get connectWhatsapp => 'Připojte WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Připojte svou instanci Nextcloud, včetně serverů s vlastním hostitelem. NeoAgent otevře vlastní přihlašovací stránku Nextcloud, takže se můžete přihlásit pomocí hesla, SSO nebo 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Připojte svůj vlastní hostovaný server NeoRecall. NeoAgent získá přístup pouze pro čtení k místnímu vyhledávání, vzpomínkám a důkazům přepisu poté, co schválíte obrazovku OAuth.';

  @override
  String get connected => 'Připojeno';

  @override
  String get connectedAccount => 'Připojený účet';

  @override
  String connectedArg1(Object? arg1) {
    return 'Připojeno $arg1';
  }

  @override
  String get connectedInstance => 'Připojená instance';

  @override
  String get connectedNeorecallUser => 'Připojený uživatel NeoRecall';

  @override
  String get connectedNextcloudUser => 'Připojený uživatel Nextcloud';

  @override
  String get connectedServer => 'Připojený server';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Připojování k modelu živého hlasu...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Připojení #$arg1';
  }

  @override
  String get connectionId => 'ID připojení';

  @override
  String get connectionLooksGood => 'Připojení vypadá dobře.';

  @override
  String get connectionMethod => 'Způsob připojení';

  @override
  String get containsTextOptional => 'Obsahuje text (volitelné)';

  @override
  String get content => 'Obsah';

  @override
  String get contentSecurityPolicy => 'zásady zabezpečení obsahu';

  @override
  String get continue2 => 'Pokračovat';

  @override
  String get continueFullSetup => 'Pokračujte v úplném nastavení';

  @override
  String get continueRun => 'Pokračujte v běhu';

  @override
  String get continueToSetup => 'Pokračujte v nastavení';

  @override
  String get controlSurface => 'OVLÁDACÍ PLOCHA';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Řídí přístup k nástrojům $arg1.';
  }

  @override
  String get conversation => 'Konverzace';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID konverzace použité, když tento agent zahájí chat.';

  @override
  String get cookieSetup => 'Nastavení souborů cookie';

  @override
  String get cookiesNotConfigured => 'Soubory cookie nejsou nakonfigurovány';

  @override
  String get copiedAsCsv => 'Zkopírováno jako CSV';

  @override
  String get copiedDebugInfo => 'Zkopírované informace o ladění';

  @override
  String get copiedExportForTheLast5 =>
      'Zkopírován export pro posledních 5 zpráv';

  @override
  String get copiedFullPrompt => 'Úplná výzva zkopírována';

  @override
  String get copiedLogs => 'Zkopírované protokoly';

  @override
  String get copiedRunId => 'Zkopírované ID běhu';

  @override
  String get copy => 'Kopírovat';

  @override
  String get copyAll => 'Zkopírujte vše';

  @override
  String get copyCodes => 'Kopírovat kódy';

  @override
  String get copyCsv => 'Zkopírujte CSV';

  @override
  String get copyDebugInfo => 'Zkopírujte informace o ladění';

  @override
  String get copyLink => 'Zkopírujte odkaz';

  @override
  String get copyLogs => 'Kopírovat protokoly';

  @override
  String get copyPrompt => 'Kopírovat výzvu';

  @override
  String get copyResponse => 'Zkopírujte odpověď';

  @override
  String get copyRunId => 'Zkopírujte ID běhu';

  @override
  String get copyWebhookUrl => 'Zkopírujte adresu URL webhooku';

  @override
  String get core => 'Jádro';

  @override
  String get coreMemory => 'jádrová paměť';

  @override
  String get coreServicesThisServerDependsOn =>
      'Základní služby, na kterých tento server závisí.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'původ veřejné adresy URL domény https';

  @override
  String get couldHelp => 'Může pomoci';

  @override
  String get couldNotApproveQrLogin =>
      'Nepodařilo se schválit přihlášení pomocí QR kódu.';

  @override
  String get couldNotApproveQrPairing => 'Párování QR se nepodařilo schválit.';

  @override
  String get couldNotConnect => 'Připojení se nezdařilo.';

  @override
  String get couldNotCreateBinding => 'Nelze vytvořit vazbu.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Nelze smazat váš účet: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Bitwarden se nepodařilo odpojit.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Home Assistant se nepodařilo odpojit.';

  @override
  String get couldNotDisconnectNeorecall => 'NeoRecall se nepodařilo odpojit.';

  @override
  String get couldNotDisconnectNextcloud => 'Nextcloud se nepodařilo odpojit.';

  @override
  String get couldNotDisconnectTrello => 'Nelze odpojit Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Vaše data nelze exportovat: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Rozhodnutí se nepodařilo načíst';

  @override
  String get couldNotLoadUsageData => 'Nelze načíst údaje o využití.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Nastavení systému Linux nelze automaticky otevřít.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Stránku propojení poskytovatele nelze otevřít.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Přihlašovací stránku poskytovatele nelze otevřít.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Dílo vydání se nepodařilo otevřít.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Nelze otevřít Trello ve vašem prohlížeči.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Nelze otevřít stahování souboru pracovního prostoru.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Balíček aplikace pro Android nelze přečíst.';

  @override
  String get couldNotReadTheApk => 'Soubor APK nelze přečíst.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Nelze odebrat klíč: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Agenta se nepodařilo uložit.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Nastavení Bitwarden se nepodařilo uložit.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Nastavení Asistenta domácnosti se nepodařilo uložit.';

  @override
  String get couldNotSaveNeorecallSetup => 'Nastavení NeoRecall nelze uložit.';

  @override
  String get couldNotSaveNextcloudSetup => 'Nastavení Nextcloud nelze uložit.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Nastavení Trello se nepodařilo uložit.';

  @override
  String get couldNotSendConfirmationEmail =>
      'nelze odeslat potvrzovací e-mail';

  @override
  String get couldNotStart => 'Nelze spustit';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Vytvořit';

  @override
  String get createAPasswordFirstToChange =>
      'Pro změnu e-mailu účtu si nejprve vytvořte heslo.';

  @override
  String get createAPasswordOrLinkAnother =>
      'před odebráním této metody přihlášení vytvořte heslo nebo propojte jiného poskytovatele';

  @override
  String get createATaskWhileThisAgent =>
      'Když je tento agent vybrán, vytvořte úlohu.';

  @override
  String get createLink => 'Vytvořit odkaz';

  @override
  String get createOrModifyFilesInYour =>
      'Vytvářejte nebo upravujte soubory ve svém pracovním prostoru.';

  @override
  String get createPassword => 'Vytvořte heslo';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Vytvářejte speciální roboty s oddělenou pamětí, nastaveními, nástroji a přiřazením účtů.';

  @override
  String get createTheFirstAccount => 'Vytvořte první účet';

  @override
  String get createUpdateOrDeleteSkills =>
      'Vytvořte, aktualizujte nebo odstraňte dovednosti.';

  @override
  String get creatingYourSkill => 'Vytváření vaší dovednosti…';

  @override
  String get credentialBindings => 'Vazby pověření';

  @override
  String get credentialUse => 'Použití pověření';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Opakované běhy založené na cron a jednorázové časované spuštění.';

  @override
  String get cronExpression => 'Cron výraz';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter spustí dotaz.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + mezerník';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Aktuální email: $arg1';
  }

  @override
  String get currentPassword => 'Aktuální heslo';

  @override
  String get currentPasswordIsIncorrect => 'aktuální heslo je nesprávné';

  @override
  String get currentTwoStepLoginCode => 'Aktuální dvoukrokový přihlašovací kód';

  @override
  String get customAccess => 'Vlastní přístup';

  @override
  String get customCron => 'Vlastní Cron';

  @override
  String get customCronMustHave5Fields => 'Vlastní Cron musí mít 5 polí.';

  @override
  String get customEndpoint => 'vlastní koncový bod';

  @override
  String get customField => 'Vlastní pole';

  @override
  String get customHeader => 'Vlastní záhlaví';

  @override
  String get customHeadersJson => 'Vlastní záhlaví (JSON)';

  @override
  String get customOpenaiCompatible => 'Vlastní kompatibilní s OpenAI';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Vlastní koncový bod kompatibilní s OpenAI';

  @override
  String get customOutgoingUrl => 'Vlastní odchozí URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Denně';

  @override
  String get dailyRecap => 'Denní rekapitulace';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'databázový dotaz vyberte šablony csv';

  @override
  String dayArg1(Object? arg1) {
    return 'Den $arg1';
  }

  @override
  String get dayOfMonth => 'den v měsíci';

  @override
  String get decideWhichToolsYourAgentMay =>
      'rozhodnout, které nástroje může váš agent používat. Vidí vaše jméno a ';

  @override
  String get decisionHigherUpTheChainWins =>
      'rozhodnutí výše v řetězu vyhrává a ukazuje zámek s ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Zde se zobrazí rozhodnutí, když $arg1 přečte schválené skupiny $arg2. Uchovává se pouze posledních 30 a po restartu serveru se resetují.';
  }

  @override
  String get decline => 'Odmítnout';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'hluboký běh · krok $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram klíč';

  @override
  String get default2 => 'Výchozí';

  @override
  String get default3 => 'VÝCHOZÍ';

  @override
  String defaultArg1(Object? arg1) {
    return 'Výchozí ($arg1)';
  }

  @override
  String get defaultConversation => 'Výchozí konverzace';

  @override
  String get defaultForNewGroups => 'Výchozí pro nové skupiny';

  @override
  String get defaultGroupParticipation => 'Výchozí skupinová účast';

  @override
  String get defaultNeoagentWorkspace => 'Výchozí pracovní prostor NeoAgent';

  @override
  String get defaultOpenai => 'Výchozí (OpenAI)';

  @override
  String get defaultRateLimits => 'Výchozí limity sazeb';

  @override
  String get defaultRateLimitsSaved => 'Výchozí limity sazeb uloženy.';

  @override
  String get defaultRecommended => 'Výchozí (doporučeno)';

  @override
  String get defaultRouting => 'Výchozí směrování';

  @override
  String get defaultSpace => 'Výchozí prostor';

  @override
  String get delete => 'Smazat';

  @override
  String get deleteAccount => 'Smazat účet';

  @override
  String get deleteAccountPermanently => 'Trvale smazat účet?';

  @override
  String get deleteAnAccount => 'Smazat účet';

  @override
  String deleteArg1(Object? arg1) {
    return 'Smazat @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Smazat ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Trvale smazat $arg1 $arg2?';
  }

  @override
  String get deleteBinding => 'Smazat vazbu';

  @override
  String get deleteCoreMemoryEntry => 'Smazat záznam hlavní paměti?';

  @override
  String get deleteForever => 'Smazat navždy';

  @override
  String get deleteMcpServer => 'Smazat MCP server?';

  @override
  String get deleteMemory => 'Smazat paměť?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Smazat trvale vymaže účet a všechna jeho data ';

  @override
  String get deleteRun => 'Smazat běh?';

  @override
  String get deleteRun2 => 'Smazat běh';

  @override
  String get deleteSelectedMemories => 'Smazat vybrané vzpomínky?';

  @override
  String get deleteSession => 'Smazat relaci?';

  @override
  String get deleteSkill => 'Smazat dovednost?';

  @override
  String get deleteTask => 'Smazat úkol?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Smazáno „$arg1“.';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Smazán @$arg1 a všechna jejich data.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Smazání odstraní všechny vaše konverzace, vzpomínky, soubory, úkoly a ';

  @override
  String get deliverableArtifactProduced => 'Vyrobený artefakt dodávky';

  @override
  String get deliverableCompleted => 'Dodávka dokončena';

  @override
  String get deliverableExecutionStarted => 'Realizace dodávky zahájena';

  @override
  String get deliverableSelected => 'Dodávka vybrána';

  @override
  String get deliverableValidationFailed => 'Ověření dodávky se nezdařilo';

  @override
  String get deliverableValidationStarted => 'Bylo zahájeno ověřování dodávky';

  @override
  String get deny => 'Odmítnout';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Popište výsledek a předveďte jej na ploše';

  @override
  String get describeWhatToBuildOrChange => 'Popište, co postavit nebo změnit…';

  @override
  String get description => 'Popis';

  @override
  String get desktopApp => 'Desktopová aplikace';

  @override
  String get desktopAppControlsAvailable =>
      'K dispozici jsou ovládací prvky desktopové aplikace';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Snímání plochy není na této platformě dostupné.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Nahrání výstupu příkazu pro plochu bylo zrušeno.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Doprovodný příkaz na ploše byl zrušen.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Vypršel časový limit doprovodného připojení k počítači.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Vypršel časový limit pro handshake společníka na ploše.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Doplněk na ploše zde není k dispozici.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Doprovodný soubor na ploše je místně pozastaven.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Zpracování doprovodných zpráv na ploše se nezdařilo: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Nastavení oprávnění doprovodu na ploše nejsou na webu k dispozici.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Nastavení oprávnění doprovodu na ploše nejsou na této platformě k dispozici.';

  @override
  String get desktopCompanionRejected =>
      'Doprovodný soubor na počítači byl zamítnut.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Doprovodná odpověď na ploše se nezdařila: $arg1';
  }

  @override
  String get desktopControl => 'Desktop Control';

  @override
  String get desktopFailedToStart => 'Desktop se nepodařilo spustit';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Zachycení streamu z plochy se nezdařilo: $arg1';
  }

  @override
  String get destinationId => 'ID cíle';

  @override
  String get deviceAccess => 'Přístup k zařízení';

  @override
  String get deviceSettings => 'Nastavení zařízení';

  @override
  String get devices => 'Zařízení';

  @override
  String get diagnosticsSaved => 'Diagnostika uložena.';

  @override
  String get directBluebubblesImessageBridge =>
      'Přímý most BlueBubbles iMessage';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Přímé zprávy zůstávají citlivé. Skupiny na seznamu povolených používají níže uvedený režim účasti.';

  @override
  String get directoryDoesNotExist => 'Adresář neexistuje.';

  @override
  String get disable2fa => 'Zakázat 2FA';

  @override
  String get disableAll => 'Zakázat vše';

  @override
  String get discard => 'Zahodit';

  @override
  String get disconnect => 'Odpojit';

  @override
  String get disconnectHomeAssistant => 'Odpojit Home Assistant?';

  @override
  String get disconnectNeorecall => 'Odpojit NeoRecall?';

  @override
  String get disconnectNextcloud => 'Odpojit Nextcloud?';

  @override
  String get disconnectPlatform => 'Odpojit platformu';

  @override
  String get disconnectTrello => 'Odpojit Trello?';

  @override
  String get discoveryFailed => 'Zjištění se nezdařilo';

  @override
  String get dismiss => 'Odmítnout';

  @override
  String get displayIdIsRequired => 'Je vyžadováno ID zobrazení.';

  @override
  String get displayName => 'Zobrazovaný název';

  @override
  String get displayNameMustBe64Characters =>
      'Zobrazovaný název musí mít 64 znaků nebo méně.';

  @override
  String get displayNameSaved => 'Zobrazovaný název uložen.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Neuvádějte své uživatelské jméno ani e-mail.';

  @override
  String get done => 'Hotovo';

  @override
  String get downloadACopyOfYourData =>
      'Stáhněte si kopii svých dat. Účty správce nelze smazat ';

  @override
  String get downloadACopyOfYourData2 =>
      'Stáhněte si kopii svých dat nebo trvale smažte svůj účet. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Stáhněte si $arg1';
  }

  @override
  String get downloadUpdate => 'Stáhnout aktualizaci';

  @override
  String get downloadingTheNeoagentBackend => 'Stažení backendu NeoAgent';

  @override
  String get draft => 'Koncept';

  @override
  String get dragIsNotSupportedOnThis =>
      'přetahování není na této platformě podporováno.';

  @override
  String get draggedOnTheScreen => 'Přetaženo na obrazovce';

  @override
  String get dropAnApkOrApkBundle =>
      'Sem přetáhněte soubor APK nebo balíček APK a nainstalujte jej';

  @override
  String get dropApkOrApksHere => 'Sem přetáhněte APK nebo .apks';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Odolné pokyny pro hlas a styl interakce. Pravidla bezpečnosti a provádění mají stále přednost.';

  @override
  String get eGAlexSLaptop => 'např. Alexův notebook';

  @override
  String get eGMyLocalServer => 'např. Můj lokální server';

  @override
  String get edit => 'Upravit';

  @override
  String get editAgent => 'Edit Agent';

  @override
  String get editCoreMemoryEntry => 'Upravit položku Core Memory Entry';

  @override
  String get editInstructions => 'Upravit pokyny';

  @override
  String get editMcpServer => 'Upravit server MCP';

  @override
  String get editTask => 'Upravit úkol';

  @override
  String editedArg1(Object? arg1) {
    return 'Upraveno $arg1';
  }

  @override
  String get email => 'Email';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'E-mail vlastníkům účtů o přihlášeních, která vypadají neobvykle.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'E-mail vlastníkům účtů, když se změní podrobnosti jejich účtu.';

  @override
  String get emailCode => 'E-mailový kód';

  @override
  String get emailConfirmationRequired => 'vyžadováno potvrzení e-mailem';

  @override
  String get emailIsAlreadyInUse => 'e-mail se již používá';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail byl uložen. Pokud je vyžadováno potvrzení, zkontrolujte novou adresu, zda neobsahuje odkaz na potvrzení NeoAgent.';

  @override
  String get emailSettingsSaved => 'Nastavení e-mailu uloženo.';

  @override
  String get emailUnverified => 'E-mail není ověřen';

  @override
  String get empty => 'Prázdný';

  @override
  String get emptyFile => 'Prázdný soubor';

  @override
  String get emptyFolder => 'Prázdná složka';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Prázdné používá výchozí nastavení serveru ($arg1).';
  }

  @override
  String get enable2fa => 'Povolit 2FA';

  @override
  String get enableAll => 'Povolit vše';

  @override
  String get enableBehaviorModules => 'Povolit moduly chování';

  @override
  String get enableOrDisableModels => 'Povolit nebo zakázat modely';

  @override
  String get enabled => 'Povoleno';

  @override
  String get encryptedPrivateToYourAccount =>
      'Šifrované, soukromé pro váš účet';

  @override
  String get end => 'Konec';

  @override
  String get endCall => 'Ukončit hovor';

  @override
  String get endVoiceCall => 'Ukončit hlasový hovor?';

  @override
  String get endpoint => 'Koncový bod';

  @override
  String get enterAPassword => 'Zadejte heslo.';

  @override
  String get enterAUsername => 'Zadejte uživatelské jméno.';

  @override
  String get enterAValidEmailAddress => 'Zadejte platnou e-mailovou adresu.';

  @override
  String get enterAnAddressManually => 'Zadejte adresu ručně';

  @override
  String get enterAnApiKeyFirst => 'Nejprve zadejte klíč API.';

  @override
  String get enterInviteLink => 'Zadejte odkaz na pozvánku';

  @override
  String get enterTheAddressOfANeoagent => 'Zadejte adresu serveru NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Zadejte podrobnosti, které vám $arg1 poskytl, aby $arg2 mohl odesílat a přijímat zprávy.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Zadejte svůj 2FA nebo obnovovací kód.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Chcete-li jej změnit, zadejte své aktuální heslo.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Chcete-li uložit změny e-mailu, zadejte své aktuální heslo.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Zadejte podrobnosti o svém účtu NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Zadejte své uživatelské jméno nebo e-mail účtu. NeoAgent odešle odkaz pro reset, pokud bude odpovídat účtu.';

  @override
  String get enterYourUsernameOrEmail =>
      'Zadejte své uživatelské jméno nebo e-mail.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entita: $arg1';
  }

  @override
  String get environment => 'Životní prostředí';

  @override
  String get error => 'Chyba';

  @override
  String errorArg1(Object? arg1) {
    return '\nchyba: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Chyby z posledního protokolu, seskupené podle zpráv.';

  @override
  String get errorsProblemsFailures => 'chyby problémy selhání';

  @override
  String get eventTypesCommaSeparated => 'Typy událostí (oddělené čárkami)';

  @override
  String get every15Minutes => 'Každých 15 minut';

  @override
  String get every30Minutes => 'Každých 30 minut';

  @override
  String get everyAccountOnThisServerLoses =>
      'Každý účet na tomto serveru ztratí tento sdílený klíč. Účty ';

  @override
  String get everyAccountOnThisServerUses =>
      'Každý účet na tomto serveru používá tuto adresu ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Každá aktivní relace pro tento účet končí. Mohou se přihlásit ';

  @override
  String get everyDay0800 => 'Každý den · 08:00';

  @override
  String get everyDay2000 => 'Každý den · 20:00';

  @override
  String get everyHour => 'Každou hodinu';

  @override
  String get everyRunOnThisServerAll =>
      'Každé spuštění na tomto serveru, po celou dobu.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Každý citlivý nástroj vyžaduje schválení, pokaždé.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Každý nástroj běží bez ptaní, kromě těch, které člověk ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Každý v těchto skupinách, kanálech nebo místnostech může mluvit se $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Všichni v této skupině';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Vše, co je $arg1 vypnuto pro vašeho agenta, přichází ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Vše ostatní je vypnuté.';

  @override
  String get everythingIsAvailableFromTheDesktop => 'Vše je dostupné z plochy.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Vše, co může agent použít: oficiální integrace, servery MCP a dovednosti.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Vše, co jste u $arg1 vypnuli, se vrátí ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Přesné webové zdroje, které mohou zadávat požadavky na různé zdroje, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Spusťte JavaScript v relaci prohlížeče.';

  @override
  String get execution => 'Provedení';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Podrobnosti o provedení nejsou pro tento běh k dispozici.';

  @override
  String get executionPlanCreated => 'Prováděcí plán vytvořen.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Cvičení $arg1 sezení';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[ukončit $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Platnost vyprší $arg1';
  }

  @override
  String get explainThisProject => 'Vysvětlete tento projekt';

  @override
  String exploredArg1(Object? arg1) {
    return 'Prozkoumáno $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Prozkoumáno $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Prozkoumal pracovní prostor';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Export se nezdařil: $arg1';
  }

  @override
  String get exportLast5Messages => 'Exportovat posledních 5 zpráv';

  @override
  String get exportMyData => 'Exportovat moje data';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Spuštění externího prohlížeče se nezdařilo s kódem ukončení $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Spouštění externího prohlížeče není na této platformě podporováno.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Vypršel časový limit spuštění externího prohlížeče.';

  @override
  String get externalMcpTools => 'Externí a MCP nástroje';

  @override
  String get extraButtons => 'Extra tlačítka';

  @override
  String get extractingTheNeoagentRuntime =>
      'Extrahování běhového prostředí NeoAgent';

  @override
  String get failed => 'Nepodařilo se';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Připojení se nezdařilo: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nepodařilo se připojit $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nepodařilo se odstranit \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'nepodařilo získat';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Nepodařilo se vygenerovat výzvu: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Spuštění externího prohlížeče přes url_launcher se nezdařilo.';

  @override
  String get failedToLaunchOauthFlow => 'Spuštění postupu OAuth se nezdařilo.';

  @override
  String get failedToLoadPolicies => 'Zásady se nepodařilo načíst';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Nepodařilo se uložit: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Server MCP se nepodařilo uložit.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Nepodařilo se uložit výběr: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Nepodařilo se odeslat oznámení do backendu: $arg1';
  }

  @override
  String get fair => 'Spravedlivý';

  @override
  String get fasterReplies => 'Rychlejší odpovědi';

  @override
  String get fewerModelCalls => 'Méně modelových hovorů';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'pole prázdné pro obnovení vestavěného výchozího nastavení.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Soubor překračuje limit editoru 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Soubor překračuje podporovaný limit velikosti.';

  @override
  String get fileWrites => 'File Writes';

  @override
  String get filename => 'Název souboru';

  @override
  String get files => 'Soubory';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Soubory, které NeoAgent zapisuje nebo upravuje v této relaci, se zobrazí zde.';

  @override
  String get filesSavedByAllUsers => 'Soubory uložené všemi uživateli';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Vyplňte schválená přihlášení nebo ověřte požadavky, aniž byste AI ukazovali tajemství.';

  @override
  String get finalResponse => 'Konečná odpověď';

  @override
  String get findAPlatform => 'Najděte platformu';

  @override
  String get findAndFixABug => 'Najděte a opravte chybu';

  @override
  String get findRecentChats => 'Najděte nedávné chaty';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Nalezení správného běhového prostředí NeoAgent';

  @override
  String get finish => 'Dokončit';

  @override
  String get finishAtTheScheduledTime => 'Dokončete v naplánovanou dobu';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Dokončete přihlašování do $arg1 v prohlížeči a poté se znovu připojte.';
  }

  @override
  String get flowGraph => 'Průtokový graf';

  @override
  String get flutterApp => 'Aplikace Flutter';

  @override
  String get focusedExecutionProfile => 'Zaměřený profil provádění';

  @override
  String get folderIdOptional => 'ID složky (volitelné)';

  @override
  String get folderUnavailable => 'Složka není k dispozici';

  @override
  String get forExampleHttpsMatrixOrg => 'Například https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Pro hostovaná nebo pokročilá nastavení sítě';

  @override
  String get forLinksInEmailsBlankUses =>
      'Pro odkazy v e-mailech. Blank používá veřejnou adresu URL serveru.';

  @override
  String get forgotPassword => 'Zapomněli jste heslo?';

  @override
  String get frameUnavailable => 'Rám není k dispozici';

  @override
  String freshnessArg1(Object? arg1) {
    return 'čerstvost: $arg1';
  }

  @override
  String get fridays1700 => 'Pátek · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Z BotFather po vytvoření robota.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Od této chvíle rozhoduje $arg1, které nástroje může váš agent používat. Oni ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Z portálu Discord Developer Portal pod vaším robotem.';

  @override
  String get fromTheLineDevelopersConsole =>
      'Z konzole LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot => 'Z klienta Matrix nebo účtu robota.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Z twitchapps.com/tmi nebo vaší vývojářské aplikace Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Úplná výzva';

  @override
  String get fullSetup => 'Kompletní nastavení';

  @override
  String get general => 'Generál';

  @override
  String get generalSettings => 'Obecná nastavení';

  @override
  String get generalSettingsSaved => 'Obecná nastavení uložena.';

  @override
  String get generateAPromptForAnotherAi =>
      'Vygenerujte výzvu pro další AI, vložte odpověď sem pro import vzpomínek.';

  @override
  String get generatePrompt => 'Generovat výzvu';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Chyba sledování geofence: $arg1';
  }

  @override
  String get getInspired => 'Nechte se inspirovat';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot a OpenAI Codex';

  @override
  String get githubIssueOpened => 'Problém GitHub otevřen';

  @override
  String get neorecallMemoryCreated => 'Vytvořena paměť NeoRecall';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Kontrola vydání GitHubu selhala s HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Obsah vydání GitHubu nebyl seznam vydání.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Uživatelské jméno GitHub, které problém otevřelo';

  @override
  String get globalSecurityMode => 'Globální bezpečnostní režim';

  @override
  String get gmailMessageReceived => 'Zpráva Gmail přijata';

  @override
  String get good => 'Dobře';

  @override
  String get goodAfternoon => 'Dobré odpoledne';

  @override
  String get goodEvening => 'Dobrý večer';

  @override
  String get goodMorning => 'Dobré ráno';

  @override
  String get goodPasswordALittleMoreLength =>
      'Dobré heslo. O něco delší délka to zpevní.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live používá váš klíč OpenAI API, Gemini Live váš klíč Google AI. Změny se použijí na další hovor.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Před synchronizací udělte oprávnění Health Connect.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Skupina, kanál nebo místnost';

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
    return 'Skupiny, které $arg1 ještě neviděl, budou následovat.';
  }

  @override
  String get handlesDirectTasksItself => 'Přímé úkoly zvládá sám';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Hands-free (volně mluvte, kdykoli přerušte)';

  @override
  String get headerName => 'Název záhlaví';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Titulky na témata, která vás zajímají, filtrované podle signálu.';

  @override
  String get health => 'Zdraví';

  @override
  String get healthChecks => 'Zdravotní prohlídky';

  @override
  String get healthConnect => 'zdraví spojit';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect není na tomto zařízení k dispozici.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Stav synchronizace Health Connect a uložené backendové metriky.';

  @override
  String get healthStatusIsUnavailable => 'Zdravotní stav není k dispozici.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Synchronizace aplikace Health je k dispozici pouze v systému Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Srdce $arg1 záznamy';
  }

  @override
  String get heldBack => 'Zadrženo';

  @override
  String get helper => 'Pomocník';

  @override
  String helperArg1(Object? arg1) {
    return 'Pomocník: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'tady. Nejprve zrušte admin pomocí `neoagent admin revoke $arg1`.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Vyšší hodnoty činí NeoAgent selektivnějším ve skupinách.';

  @override
  String get highlyRecommended => 'Vřele doporučuji';

  @override
  String get holdButton131ForTheAssistant =>
      'Podržte tlačítko 131 pro asistenta.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Chcete-li mluvit, podržte Ctrl+Shift+Mezerník';

  @override
  String get holdToTalk => 'Vydržte, abyste mohli mluvit.';

  @override
  String get holdToTalk2 => 'Vydržte a mluvte';

  @override
  String get home => 'Domů';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Je vyžadován dlouhotrvající přístupový token Home Assistant.';

  @override
  String get homeAssistantSetup => 'Nastavení domácího asistenta';

  @override
  String get homeAssistantUrl => 'Adresa URL domácího asistenta';

  @override
  String get homeAssistantUrlIsRequired =>
      'Je vyžadována adresa URL domácího asistenta.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Token domácího serveru s dotazováním místnosti';

  @override
  String get homeserverUrl => 'Adresa URL domovského serveru';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'hostovaná služba). Vaše klíče jsou zašifrované a použitelné pouze pro uživatele ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Název hostitele sítě IRC, například irc.libera.chat';

  @override
  String get hourly => 'Každou hodinu';

  @override
  String get hourlyInboxCheck => 'Hodinová kontrola doručené pošty';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Jak dlouho zůstávají v platnosti potvrzovací odkazy.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Jak často tento agent hledá nové zprávy o místnosti.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Jak často tento agent hledá nové zprávy Signal.';

  @override
  String get howTeamsWork => 'Jak fungují týmy';

  @override
  String get howThisServerIsReachedPlus =>
      'Jak je dosaženo tohoto serveru a přepínače na celém serveru.';

  @override
  String get httpsSessionCookie => 'https relace cookie';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Tento požadavek jsem teď nemohl dokončit. Zkuste to prosím znovu za chvíli.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Nečinný';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Pokud $arg1 požádá o adresu URL webhooku, vložte tuto adresu, aby se zprávy dostaly na $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Pokud má tento účet potvrzený e-mail, NeoAgent odešle odkaz pro resetování hesla.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Pokud služba vyžaduje token u odchozích požadavků.';

  @override
  String get ignoreGroups => 'Ignorovat skupiny';

  @override
  String get ignoreThisChat => 'Ignorujte tento chat';

  @override
  String get ignoredChannels => 'Ignorované kanály';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Ignorovaná chybná doprovodná zpráva na ploše: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Implementujte výše uvedený plán.';

  @override
  String get implementThisPlan => 'Implementujte tento plán';

  @override
  String get implicitTls => 'Implicitní TLS';

  @override
  String get import => 'Importovat';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Import se nezdařil: $arg1';
  }

  @override
  String get importFromComputer => 'Import z počítače';

  @override
  String get importMemoryTransfer => 'Importovat přenos paměti?';

  @override
  String get importance => 'Důležitost';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Importované paměti $arg1, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'V týmu @$arg1';
  }

  @override
  String get inBackground => 'pozadí';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Zde se zobrazí příchozí a odchozí zprávy kanálu.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Příchozí hlasové hovory v aplikaci od NeoAgent';

  @override
  String get incomingMessages => 'Příchozí zprávy';

  @override
  String get incomingNeoagentCall => 'Příchozí hovor NeoAgent';

  @override
  String get incomingNeoagentCall2 => 'PŘÍCHOZÍ VOLÁNÍ NEOAGENT';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Podpora příchozího webhooku a odchozího zpětného volání';

  @override
  String get incorporatingSteering => 'Zahrnující řízení';

  @override
  String get input => 'Vstup';

  @override
  String get inputMode => 'Vstupní režim';

  @override
  String get insertATemplate => 'Vložte šablonu';

  @override
  String get install => 'Instalovat';

  @override
  String get installASignedSelfContainedRuntime =>
      'Nainstalujte podepsané, samostatné runtime. Příkazy Node.js, npm, Git a terminálu nejsou vyžadovány.';

  @override
  String get installApk => 'Nainstalujte APK';

  @override
  String get installApkBundle => 'Nainstalujte APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Nainstalujte APK – klikněte nebo přetáhněte soubor .apk';

  @override
  String get installNeoagent => 'Nainstalujte NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Nainstalujte NeoAgent na tento počítač bez terminálu nebo se připojte k již spuštěnému.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Nainstalujte nová vydání a vyberte kanál, který tento server sleduje.';

  @override
  String get installTheBackend => 'Nainstalujte backend';

  @override
  String get installTheCoreWithExtraOptional =>
      'Nainstalujte jádro s extra volitelným nastavením. Klíče poskytovatele AI jsou přidány později, stejně jako Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Nainstalujte zabezpečené jádro a poté si vytvořte účet. Poté přidejte klíče poskytovatele AI.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Instalováno: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Instalováno: $arg1 • Naposledy zkontrolováno: $arg2';
  }

  @override
  String get instructions => 'Instrukce';

  @override
  String get integration => 'Integrace';

  @override
  String get integrationConnections => 'Integrační spojení';

  @override
  String get integrationSettingsSaved => 'Nastavení integrace uloženo.';

  @override
  String get integrations => 'Integrace';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrace/oauth/zpětné volání a zaregistrujte to samé ';

  @override
  String get interruptAi => 'Přerušit AI';

  @override
  String get invalid2fa => 'neplatný 2fa';

  @override
  String get invalidArgumentS => 'Neplatné argumenty: ';

  @override
  String get invalidCredentials => 'neplatná pověření';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Neplatný runtime manifest NeoAgent.';

  @override
  String get inviteLink => 'Odkaz na pozvánku';

  @override
  String get inviteLinkReady => 'Odkaz na pozvánku je připraven';

  @override
  String get inviteLinks => 'Odkazy na pozvánky';

  @override
  String get iphoneApp => 'aplikace pro iPhone';

  @override
  String get issues => 'Problémy';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Po načtení protokolu se objeví problémy.';

  @override
  String get itCanTBeUndone => 'Nelze to vrátit zpět.';

  @override
  String get itMayHaveBeenDeleted => 'Možná byla smazána.';

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
    return 'Připojil se k $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Připojeno během posledních 7 dnů';

  @override
  String get joiningATeam => 'Připojení k týmu';

  @override
  String get joiningIsOffHere => 'Připojování je zde vypnuto';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Pole JSON, které obsahuje text zprávy. Obvykle text.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Pole JSON, které identifikuje, pro koho je zpráva určena.';

  @override
  String get jumpToLatest => 'Přejít na nejnovější';

  @override
  String get justNow => 'právě teď';

  @override
  String get keepNeoagentRunning => 'Nechat NeoAgent běžet?';

  @override
  String get keepRunning => 'Běžte dál';

  @override
  String get keepTaskRunning => 'Udržujte úlohu spuštěnou';

  @override
  String get keepTheVaultAvailable => 'Nechte k dispozici trezor';

  @override
  String get keepThisLauncherUpToDate => 'Udržujte tento spouštěč aktuální.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Nechte tento panel otevřený, dokud platforma nepotvrdí připojení.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Udržujte počítač této relace viditelný';

  @override
  String get keepTrackOfYourAiUsage =>
      'Sledujte své využití AI. Limity jsou uplatňovány, aby bylo zajištěno spravedlivé používání napříč platformou.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Používejte své aplikace normálně. NeoAgent pracuje na stejné obrazovce a zeptá se, kdykoli potřebuje nový přístup.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Udržujte toto zařízení připojené';

  @override
  String get key => 'klíč';

  @override
  String get keyIsRequired => 'Je vyžadován klíč.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Páry klíč–hodnota, které přetrvávají napříč konverzacemi.';

  @override
  String get knowledgeGraph => 'Diagram znalostí';

  @override
  String get knowledgeView => 'Vědomostní pohled';

  @override
  String get labelOnlyYouSeeIt => 'Štítek (vidíte ho pouze vy)';

  @override
  String get labelsOptional => 'Štítky (volitelné)';

  @override
  String get last24Hours => 'Posledních 24 hodin';

  @override
  String get last7Days => 'Posledních 7 dní';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Posledních 7 dní: Tokeny $arg1 v běhu $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Poslední $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Poslední: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Poslední synchronizace bez vyprázdnění · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Poslední běh: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Naposledy viděn $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Poslední přihlášení $arg1';
  }

  @override
  String get lastSyncSummary => 'Souhrn poslední synchronizace';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Naposledy použité: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Poslední okno skončilo $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'pozdější start vypnutý.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Poslední spuštění · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Spouštění aplikací pro stolní počítače není na této platformě podporováno.';

  @override
  String get learnRoomNorms => 'Naučte se normy místností';

  @override
  String get leave => 'Odejděte';

  @override
  String get leaveARedirectUriBlankTo =>
      'Chcete-li použít <public URL>/api/, ponechte pole URI přesměrování prázdné';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Opustit tým $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Ponechte jako výchozí, pokud jste si BlueBubbles nepřizpůsobili.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Chcete-li zachovat aktuálně uložený token, nechte token prázdný.';

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
    return 'Nechte mě řídit $arg1';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Nechte každého v této skupině mluvit se $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Nechte to fungovat,\nzatímco vy ne.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Nechte NeoAgent klikat, psát a procházet aplikacemi.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Nechte NeoAgent pochopit, co je vidět na vaší obrazovce.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Nechte někoho, s kým spolupracujete, rozhodnout, jaké nástroje může váš agent používat ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Umožněte této osobě poslat zprávu $arg1 jedna ku jedné.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Nechte tuto osobu mluvit se $arg1 zde, ale ne v soukromých chatech nebo jiných skupinách.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Nechte tuto osobu mluvit se $arg1 v soukromých chatech a v jakékoli skupině, kterou sdílí.';
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
  String get linkCopied => 'Odkaz zkopírován';

  @override
  String get linkExpiresAfter => 'Platnost odkazu vyprší poté';

  @override
  String get linkLifetimeHours => 'Životnost odkazu (hodiny)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Životnost odkazu musí být od 1 do 8760 hodin.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Odkaz platí do $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Propojení poskytovatelé přihlášení';

  @override
  String get linuxApp => 'Linuxová aplikace';

  @override
  String listedArg1(Object? arg1) {
    return 'Uvedeno $arg1/';
  }

  @override
  String get listening => 'Poslouchání';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Živá historie provádění, kroky nástroje a reakce.';

  @override
  String get liveModel => 'Živý model';

  @override
  String get liveModelProvider => 'Poskytovatel živých modelů';

  @override
  String get liveRun => 'Živý běh';

  @override
  String get liveVoice => 'Živý hlas';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Živé hlasové připojení není k dispozici.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Živé hlasové spojení bylo uzavřeno.';

  @override
  String get liveVoiceDefaults => 'Výchozí nastavení živého hlasu';

  @override
  String get liveVoiceFailed => 'Živý hlas selhal.';

  @override
  String get llmMemoryExportResponse => 'Odpověď na export paměti LLM';

  @override
  String get loadFailed => 'načtení se nezdařilo';

  @override
  String get loadingExecutionDetails => 'Načítání podrobností o provedení...';

  @override
  String get loadingNeoagent => 'Načítání NeoAgent';

  @override
  String get loadingRunFlow => 'Načítání běhu…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Lokální a privátní síťové adresy URL jsou podporovány, když je server NeoAgent dosáhne. Zvuk není nikdy vystaven působení NeoAgent.';

  @override
  String get localApp => 'místní aplikace';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Místní backendová instalace není na této platformě dostupná.';

  @override
  String get localBaseImagePath => 'Cesta místního základního obrázku';

  @override
  String get localComputerControlIsAvailableIn =>
      'Ovládání místního počítače je k dispozici v desktopové aplikaci NeoAgent v systémech macOS, Windows a Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Zde není k dispozici ovládání místního počítače.';

  @override
  String get localModelsUrl => 'adresa URL místních modelů';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Místní zjišťování NeoAgent je dočasně nedostupné.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Místní předvolby pro aplikaci NeoAgent. Řízení počítače vždy probíhá prostřednictvím jednotného cloudového počítače.';

  @override
  String get localSetup => 'MÍSTNÍ NASTAVENÍ';

  @override
  String get locationCityOrPlace => 'Místo (město nebo místo)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Místo je vyžadováno pro spouštěče meteorologických událostí';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Inicializace LocationService se nezdařila: $arg1';
  }

  @override
  String get logCopied => 'Protokol zkopírován';

  @override
  String get loginPassword => 'Přihlašovací heslo';

  @override
  String get logout => 'Odhlášení';

  @override
  String get logs => 'Protokoly';

  @override
  String get logsCopied => 'Protokoly zkopírovány.';

  @override
  String get logsOnThisComputer => 'Protokoly na tomto počítači';

  @override
  String get longLivedAccessToken => 'Přístupový token s dlouhou životností';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Dlouhodobé vzpomínání, strukturovaná fakta a znalostní graf.';

  @override
  String get lookedAtTheScreen => 'Podíval se na obrazovku';

  @override
  String get lookingOnThisComputerAndYour =>
      'Prohlížíte si tento počítač a vaši místní síť…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Dívá se dopředu na zítřejší schůzky, takže vás nic nepřekvapí.';

  @override
  String get loopExecution => 'Provedení smyčky';

  @override
  String get loopPaused => 'Smyčka pozastavena';

  @override
  String get macOsX => 'mac OS x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'Přístupnost macOS není pro NeoAgent udělena. Povolte to v Nastavení systému › Soukromí a zabezpečení › Usnadnění.';

  @override
  String get macosApp => 'aplikace pro macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'Nahrávání obrazovky macOS není pro NeoAgent uděleno. Povolte to v Nastavení systému › Soukromí a zabezpečení › Záznam obrazovky a poté znovu otevřete NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Poštovní servery, které potřebují heslo, odmítnou odeslat, dokud nebude nové ';

  @override
  String get main => 'Hlavní';

  @override
  String get makeDefault => 'Nastavit jako výchozí';

  @override
  String get manage => 'Spravovat';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Spravujte e-mail svého účtu, dvoufaktorové ověřování a aktivní relace.';

  @override
  String get managedBy => 'Spravuje';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Manažeři mohou mít své vlastní manažery (až čtyři úrovně). A ';

  @override
  String get managing => 'Řízení';

  @override
  String get manualDestination => 'Manuální cíl';

  @override
  String get manualTrigger => 'Ruční spoušť';

  @override
  String get masterPassword => 'Hlavní heslo';

  @override
  String get matchThisDevice => 'Přizpůsobte toto zařízení';

  @override
  String get matchedAgainstTitleAndBody => 'Zápas proti titulu a tělu';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Odpovídá starému toku NeoAgent MCP: metoda URL plus auth.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP server';

  @override
  String get mcpServer2 => 'Server MCP';

  @override
  String get mcpServerUrl => 'Adresa URL serveru MCP';

  @override
  String get mcpServers => 'MCP servery';

  @override
  String get meantForSomeoneElse => 'Určeno pro někoho jiného';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Naměřené náklady modelu: $arg1';
  }

  @override
  String get memories => 'Vzpomínky';

  @override
  String get memory => 'Paměť';

  @override
  String memoryArg1(Object? arg1) {
    return 'Paměť: $arg1';
  }

  @override
  String get memoryInjected => 'Injekce paměti';

  @override
  String get mentionOrReplyOnly => 'Pouze zmínit nebo odpovědět';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Sloučené protokoly běhového prostředí serveru a Flutter pro tuto relaci aplikace.';

  @override
  String get messageBodyTemplateJson => 'Šablona těla zprávy (JSON)';

  @override
  String get messageNeedsAccess => 'Zpráva vyžaduje přístup';

  @override
  String get messageTextField => 'Textové pole zprávy';

  @override
  String get messaging => 'Zasílání zpráv';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Události push a webhook rozhraní API pro zasílání zpráv';

  @override
  String get messagingConnectionNeedsAttention =>
      'Připojení zpráv vyžaduje pozornost';

  @override
  String get messagingConnections => 'Připojení zpráv';

  @override
  String get messagingDelivery => 'Doručování zpráv';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Chyba zasílání zpráv. Zkuste to prosím znovu.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Snímání mikrofonem se neočekávaně zastavilo. Zkuste to znovu.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Chyba mikrofonu: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofon ztlumen. Klepnutím zapněte zvuk.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Pro živý hlas je vyžadováno povolení mikrofonu.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimální hodnota příspěvku: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Nastavení mobilního zařízení se nezdařilo.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Nastavení mobilního zařízení se nezdařilo, protože Java není k dispozici na počítači se systémem NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Nastavení mobilního zařízení se nezdařilo, protože Java není k dispozici na počítači se systémem NeoAgent. Nainstalujte JDK a zkuste to znovu.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Nastavení mobilního zařízení se nezdařilo. Zkontrolujte, zda jsou nástroje Android správně nainstalovány, a zkuste to znovu.';

  @override
  String modeArg1(Object? arg1) {
    return 'režim: $arg1';
  }

  @override
  String get modeLocksWhileARunIs => 'Režim se uzamkne, když je běh aktivní.';

  @override
  String get model => 'Model';

  @override
  String modelArg1(Object? arg1) {
    return 'Model: $arg1';
  }

  @override
  String get modelAvailability => 'Dostupnost modelu';

  @override
  String get modelAvailabilitySaved => 'Dostupnost modelu uložena.';

  @override
  String get modelForThisSession => 'Model pro tuto relaci';

  @override
  String get modelOverride => 'Přepsání modelu';

  @override
  String get modelPending => 'Model čeká na vyřízení';

  @override
  String get modelTurn => 'Modelový obrat';

  @override
  String get modelTurnCompleted => 'Otáčení modelu dokončeno';

  @override
  String get modelTurnStarted => 'Zahájení otáčení modelu';

  @override
  String get modelVisibilityHideShowList =>
      'viditelnost modelu skrýt seznam show';

  @override
  String get models => 'Modelky';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modely, chování, hlas a pracovní prostor';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modely, prohlížeč, hlas, diagnostika...';

  @override
  String get modelsRouting => 'Modely a směrování';

  @override
  String get monthly => 'Měsíční';

  @override
  String get moreActions => 'Více akcí';

  @override
  String get morningBriefing => 'Ranní briefing';

  @override
  String get mostUsedAgents => 'Nejpoužívanější agenti';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Nejpoužívanější modely v posledním $arg1.';
  }

  @override
  String get mouseKeyboard => 'Myš a klávesnice';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove není na této platformě podporováno.';

  @override
  String get mustBeReachableOnThePublic =>
      'Musí být dosažitelné na veřejném internetu -- místním a ';

  @override
  String get n24Hours => '24 hodin';

  @override
  String get n2faOrRecoveryCode => '2FA nebo obnovovací kód';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA vyžaduje, aby byla v tomto nasazení NeoAgent nakonfigurována SESSION_SECRET.';

  @override
  String get n30Days => '30 dní';

  @override
  String get n365Days => '365 dní';

  @override
  String get n4HourLimitTokens => '4hodinový limit (tokeny)';

  @override
  String get n4HourUsage => '4hodinové použití';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4h limit $arg1';
  }

  @override
  String get n7DayUsage => '7denní používání';

  @override
  String get n7Days => '7 dní';

  @override
  String get n90Days => '90 dní';

  @override
  String get name => 'Jméno';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnázev: New Skill\npopis: Popište, co tato dovednost dělá\n---\nZde napište pokyny pro tuto dovednost.\n';

  @override
  String get nameOfWhoeverMadeIt => 'jméno toho, kdo to udělal.';

  @override
  String get nameOptional => 'Jméno (volitelné)';

  @override
  String get nativeAndWebhookChannels => 'Nativní a webhookové kanály';

  @override
  String get naturalBubbles => 'Přírodní bubliny';

  @override
  String get nearbyNeoagentServers => 'Nedaleké servery NeoAgent';

  @override
  String get needANewAccountRegister =>
      'Potřebujete nový účet? Zaregistrujte se';

  @override
  String get needAnIdea => 'Potřebujete nápad?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Potřebuji odpovědět · $arg1% mluvit';
  }

  @override
  String get needsAttention => 'Vyžaduje pozornost';

  @override
  String get needsInput => 'Vyžaduje vstup';

  @override
  String get neoagentApp => 'aplikace NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'Asistent NeoAgent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent nemohl zkontrolovat dostupný backend runtime.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent nemohl dokončit místní nastavení.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent nemohl dokončit místní nastavení. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Informace o ladění NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent nainstaluje nejnovější $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent je nainstalován a spuštěn.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent není na tomto počítači nainstalován.';

  @override
  String get neoagentIsReady => 'NeoAgent je připraven';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent stále pracuje na úkolu. Ukončete hovor a získejte výsledek v chatu, nebo také zrušte úkol.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent mění vaši demonstraci na adaptabilní pracovní postup.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent čeká, když používáte plochu.';

  @override
  String get neoagentIsWorking => 'NeoAgent funguje';

  @override
  String get neoagentLinuxComputer => 'Počítač NeoAgent Linux';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT POTŘEBUJE ROZHODNUTÍ';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Stahování za běhu NeoAgent vyžaduje zabezpečenou adresu.';

  @override
  String get neoagentServerAddress => 'Adresa serveru NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'E-mail služby NeoAgent není připraven. Požádejte operátora serveru, aby zkontroloval nastavení prostředí e-mailu.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Nastavení NeoAgent se nepodařilo dokončit.';

  @override
  String get neoagentUser => 'Uživatel NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent používá tento počítač automaticky a před použitím obrazovky, myši, klávesnice, souborů nebo příkazového řádku se zeptá.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent používá vaši přibližnou polohu na pozadí ke spuštění připomenutí geofence (např. „Připomeňte mi, že mám koupit mléko, když půjdu kolem supermarketu“).\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent Workspace';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][stack] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'Adresa URL backendu NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Je vyžadována koncová adresa URL NeoRecall.';

  @override
  String get neorecallSetup => 'Nastavení NeoRecall';

  @override
  String get networkRequestFailed => 'síťový požadavek se nezdařil';

  @override
  String get networkWriteRequests => 'Síťové požadavky na zápis';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'se nikdy nezapočítává do limitů sdíleného používání.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Nové účty před přihlášením potvrďte svou e-mailovou adresu.';

  @override
  String get newAccountsPerDay => 'Nové účty za den';

  @override
  String get newChat => 'Nový chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Nové skupiny zůstanou tiché, pokud někdo neoznačí $arg1, dokud je nezapnete.';
  }

  @override
  String get newLink => 'Nový odkaz';

  @override
  String get newPasswordsDoNotMatch => 'Nová hesla se neshodují.';

  @override
  String get newRecoveryCodes => 'Nové obnovovací kódy';

  @override
  String get newSession => 'Nová relace';

  @override
  String get newSessionN => 'Nová relace (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Nová relace se stejným nastavením';

  @override
  String get newSkill => 'Nová dovednost';

  @override
  String get newSkill2 => 'Nová dovednost';

  @override
  String get newThisWeek => 'Novinka tento týden';

  @override
  String get newsDigest => 'Přehled zpráv';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Další opakování: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Přihlašovací tok Nextcloud';

  @override
  String get nextcloudSetup => 'Další nastavení cloudu';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'Adresa URL dalšího cloudu';

  @override
  String get nextcloudUrlIsRequired => 'Je vyžadována adresa URL Nextcloud.';

  @override
  String get nickname => 'přezdívka';

  @override
  String get noAccountsConnectedYet => 'Zatím nejsou připojeny žádné účty.';

  @override
  String get noAccountsFound => 'Nebyly nalezeny žádné účty.';

  @override
  String get noActiveSessionsFound => 'Nebyly nalezeny žádné aktivní relace.';

  @override
  String get noAgentsYet => 'Zatím žádní agenti';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Není nakonfigurován žádný poskytovatel AI, takže chat a zprávy ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Žádné výzvy ke schválení – agent běží bez přerušení.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Této platformě neodpovídá žádný zdroj vydání $arg1.';
  }

  @override
  String get noArguments => '(žádné argumenty)';

  @override
  String get noAuth => 'Žádné ověření';

  @override
  String get noBindingsYet => 'Zatím bez vázání.';

  @override
  String get noChangesYet => 'Zatím žádné změny';

  @override
  String get noChannelsFound => 'Nebyly nalezeny žádné kanály';

  @override
  String get noCloudComputerSlotIsFree =>
      'Žádný slot pro cloudový počítač není momentálně volný. Zkuste to znovu za chvíli.';

  @override
  String get noCoreMemoryEntriesYet => 'Zatím žádné záznamy v základní paměti.';

  @override
  String get noDescription => 'Bez popisu';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Momentálně nejsou k dispozici žádné obrazovky na ploše.';

  @override
  String get noDetailAvailable => 'Žádné podrobnosti nejsou k dispozici';

  @override
  String get noDetailedSyncSummaryYet =>
      'Zatím žádné podrobné shrnutí synchronizace.';

  @override
  String get noDetailsCaptured => 'Nebyly zachyceny žádné podrobnosti.';

  @override
  String get noEmailLinked => 'Žádný propojený e-mail';

  @override
  String get noExternalSignInProvidersLinked =>
      'Nejsou připojeni žádní externí poskytovatelé přihlášení.';

  @override
  String get noGroupMessagesYet => 'Zatím žádné skupinové zprávy';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Dosud nebyli přidáni žádní konkrétní lidé.';

  @override
  String get noGroupsAddedYet => 'Dosud nebyly přidány žádné skupiny.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Dosud nebyly nalezeny žádné skupiny. Poté, co $arg1 uvidí skupinovou zprávu, použijte Najít nedávné chaty a zobrazí se zde.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Dosud nebyly nalezeny žádné skupiny. Poté, co $arg1 uvidí skupinovou zprávu, použijte Najít poslední chaty.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Nebyla vrácena žádná užitečná zátěž zdravotních dat.';

  @override
  String get noHealthSamplesStoredYet =>
      'Zatím nejsou uloženy žádné zdravotní vzorky.';

  @override
  String get noHttpClientImplementationForThis =>
      'Žádná implementace klienta HTTP pro tuto platformu.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Pro tento krok nebyl zaznamenán žádný vstup ani výstup.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Tomuto vyhledávání neodpovídají žádné integrace.';

  @override
  String get noLimit => 'Bez omezení';

  @override
  String get noLocalPasswordIsSetYet =>
      'Zatím není nastaveno žádné místní heslo. Vytvořte jej, abyste povolili přihlášení pomocí uživatelského jména/hesla.';

  @override
  String get noLogEntries => 'Žádné záznamy protokolu.';

  @override
  String get noMatchingSettings => 'Žádná odpovídající nastavení';

  @override
  String get noMcpServersMatchThisSearch =>
      'Tomuto vyhledávání neodpovídají žádné servery MCP.';

  @override
  String get noMemoryEntriesFound => 'Nebyly nalezeny žádné položky paměti.';

  @override
  String get noMemorySync => 'Žádná synchronizace paměti';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Jednorázově přečte důležité a odeslané e-maily za posledních 12 měsíců, aby agent znal vaše kontakty a projekty.';

  @override
  String get emailMemory => 'Paměť z e-mailů';

  @override
  String get importNow => 'Importovat teď';

  @override
  String get importOnConnect => 'Při připojení účtu importovat starší poštu';

  @override
  String get sweepStarting => 'Připravuje se…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Čtení e-mailů · $done z $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Čtení e-mailů · nalezeno $count';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Učení z e-mailů · $done z $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Poslední import: $emails e-mailů · $memories nových vzpomínek';
  }

  @override
  String get sweepNothingNew => 'Žádné nové e-maily k importu';

  @override
  String sweepFailed(String error) {
    return 'Import se nezdařil: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return '\"$arg1\" neodpovídá žádný model.';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Pro tento běh nebyl zaznamenán žádný požadavek na model.';

  @override
  String get noModelsDiscoveredYet => 'Zatím nebyly objeveny žádné modely';

  @override
  String get noModelsSelected => 'Nejsou vybrány žádné modely';

  @override
  String get noModelsYet => 'Zatím žádné modely';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      's tímto poskytovatelem není spojen žádný účet neoagent';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Pro tento počítač není k dispozici žádný backendový runtime NeoAgent.';

  @override
  String get noNetworkConnection => 'Žádné síťové připojení';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Žádné síťové připojení. Připojte se, abyste mohli pokračovat v používání NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Žádné síťové připojení. Znovu se připojte a zkontrolujte aktualizace.';

  @override
  String get noOne => 'Nikdo';

  @override
  String get noOneAddedYet => 'Zatím nikdo nepřidal.';

  @override
  String get noOneCanMessage => 'Nikdo nemůže poslat zprávu';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Nebyl nalezen žádný jiný server NeoAgent. Můžete hledat znovu nebo zadat adresu ručně.';

  @override
  String get noPeopleAddedYet => 'Zatím nebyli přidáni žádní lidé.';

  @override
  String get noPlatformsMatch => 'Žádné platformy neodpovídají';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Zatím nejsou k dispozici žádní poskytovatelé ke konfiguraci.';

  @override
  String get noRecentChannelActivity => 'Žádná nedávná aktivita kanálu';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Žádné výsledky pro \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Žádné jízdy v tomto rozsahu.';

  @override
  String get noRunsMatchTheseFilters => 'Těmto filtrům neodpovídají žádné běhy';

  @override
  String get noRunsYet => 'Zatím žádné běhy';

  @override
  String get noRunsYet2 => 'Zatím žádné běhy.';

  @override
  String get noSecurityKeyWasProvided =>
      'Nebyl poskytnut žádný bezpečnostní klíč.';

  @override
  String get noServerUrlSet => 'Není nastavena žádná adresa URL serveru';

  @override
  String get noSessionMatchesThatSearch =>
      'Tomuto vyhledávání neodpovídá žádná relace.';

  @override
  String get noSessionsYet => 'Zatím žádné relace';

  @override
  String get noSkillsMatchTheseFilters =>
      'Těmto filtrům neodpovídají žádné dovednosti.';

  @override
  String get noStepsWereRecordedForThis =>
      'Pro tento běh nebyly zaznamenány žádné kroky.';

  @override
  String get noSummaryAvailable => 'Není k dispozici žádné shrnutí.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Žádné úkoly pro $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return '\"$arg1\" neodpovídá žádný nástroj.';
  }

  @override
  String get noUpdateRunning => 'Neběží žádná aktualizace';

  @override
  String get noUsageYet => 'Zatím bez použití.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Zatím není k dispozici žádný ověřený backendový runtime NeoAgent.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Nikdo už to nemůže používat. Lidé, kteří se již připojili ';

  @override
  String get none => 'žádný';

  @override
  String get notApprovedYet => 'zatím neschváleno';

  @override
  String get notAuthenticated => 'není ověřeno';

  @override
  String get notCheckedYet => 'Dosud nezkontrolováno';

  @override
  String get notConfigured => 'Není nakonfigurováno';

  @override
  String get notConnected => 'Nepřipojeno';

  @override
  String get notConnected2 => 'Nepřipojeno';

  @override
  String get notInstalled => 'Není nainstalováno';

  @override
  String get notNeeded => 'Není potřeba';

  @override
  String get notNeededEnough => 'Není dost potřeba';

  @override
  String get notNow => 'Teď ne';

  @override
  String get notNow2 => 'Teď ne';

  @override
  String get notSet => 'Nenastaveno';

  @override
  String get notSetUp => 'Není nastaveno';

  @override
  String get notTheSameAsAdmin => 'Není to stejné jako admin';

  @override
  String get nothingFound => 'Nic nenalezeno';

  @override
  String get nothingHereYet => 'Tady zatím nic.';

  @override
  String get nothingHereYet2 => 'Tady zatím nic';

  @override
  String get nothingMatches => 'Nic neodpovídá';

  @override
  String get nothingStoredYet => 'Zatím není nic uloženo.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'ID klienta OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'ID klienta oauth tajný klíč přesměrování API';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'ID klienta oauth tajné přesměrování gmail kalendář disk';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Spuštění protokolu OAuth není na této platformě podporováno.';

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
      'své vlastní. Po uložení se již nikdy nezobrazí.';

  @override
  String get off => 'Vypnuto';

  @override
  String get officialIntegration => 'Oficiální integrace';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Oficiální integrace nevrátila adresu URL připojení.';

  @override
  String get on => 'Zapnuto';

  @override
  String get onASignedInAndroidDevice =>
      'Na přihlášeném zařízení Android otevřete Nastavení › Přihlášení a zabezpečení, naskenujte tento kód a schvalte přihlášení.';

  @override
  String get onByDefaultForNewGroups =>
      'Ve výchozím nastavení zapnuto pro nové skupiny';

  @override
  String get onDemand => 'On Demand';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Zapnuto pro $arg1 skupin $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'na. Mohou se znovu připojit pouze s novým odkazem na pozvánku.';

  @override
  String get onYourOwnTheDefault => 'Sami (výchozí)';

  @override
  String get once => 'Jednou';

  @override
  String get oneIsSavedOtherChangesIn =>
      'jeden je zachráněn. Ostatní změny v tomto formuláři jsou také uloženy.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Platnost jednoho nebo více účtů vypršela. Chcete-li obnovit přístup k nástroji, znovu připojte dotčený účet.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Jeden runtime řídí persona, skupinové tahy, paměť místnosti, normy, teorii mysli a doručení.';

  @override
  String get oneTimeRun => 'Jednorázový běh';

  @override
  String get onlyApkOrApksFilesCan =>
      'Instalovat lze pouze soubory .apk nebo .apks.';

  @override
  String get onlyInThisGroup => 'Pouze v této skupině';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Potřebné pouze v případě, že služba požaduje další hlavičky HTTP.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Potřebné pouze v případě, že chcete změnit tvar odchozího užitečného zatížení.';

  @override
  String get onlyTheyCanChangeIt => 'Jen oni to mohou změnit.';

  @override
  String get open => 'Otevřít';

  @override
  String get openAccountSettingsOnASigned =>
      'Otevřete Nastavení › Přihlášení a zabezpečení na přihlášeném zařízení Android, naskenujte tento kód a schvalte přihlášení.';

  @override
  String get openComputer => 'Otevřete počítač';

  @override
  String get openDashboard => 'Otevřete palubní desku';

  @override
  String get openFolder => 'Otevřít složku…';

  @override
  String get openInWorkbench => 'Otevřít na pracovním stole';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Otevřete NeoAgent a znovu připojte $arg1, abyste obnovili zasílání zpráv.';
  }

  @override
  String get openTimeSettings => 'Otevřít nastavení času';

  @override
  String get openToAnyone => 'Otevřeno komukoli';

  @override
  String get openTrello => 'Otevřete Trello';

  @override
  String get openVoiceAssistant => 'Otevřete hlasového asistenta';

  @override
  String get openWiFiSettings => 'Otevřete nastavení Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Otevřete pomocí výchozí aplikace';

  @override
  String get openaiCodex => 'Kodex OpenAI';

  @override
  String get openaiCompatible => 'kompatibilní s openai';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Endpoint kompatibilní s OpenAI (váš vlastní server nebo jiný ';

  @override
  String openedArg1(Object? arg1) {
    return 'Otevřeno $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Otevírání adres URL pro počítače není na této platformě podporováno.';

  @override
  String get openingYourSavedDesktop => 'Otevření uložené plochy.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Otevření uložené plochy. Normální spuštění trvá méně než 10 sekund.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Volitelné další tajemství, pokud chráníte příchozí webhook.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Volitelné přepsání, pokud adresa URL webhooku nestačí.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Volitelné tajemství pro ověření příchozích událostí chatu.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Volitelné tajemství pro ověření příchozích událostí.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Volitelné tajemství pro ověření příchozích událostí iMessage.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Volitelný tajný klíč pro ověření příchozích událostí LINE.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Volitelné tajemství pro ověření příchozích událostí Mattermost.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Volitelné tajemství pro ověření příchozích událostí Teams.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Volitelné. Agent má již svou osobnost. Vše, co přidáte k tónu, se na něj navrství, takže nikdy nebudete muset žádný definovat.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Volitelné. Je-li nastaveno, použije se místo adresy URL.';

  @override
  String get orAnswerInYourOwnWords => 'Nebo odpovězte vlastními slovy';

  @override
  String get orBuildYourOwnTask => 'Nebo si sestavte svůj vlastní úkol';

  @override
  String get orContinueWith => 'nebo pokračovat s';

  @override
  String get orFiles => 'nebo soubory.';

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
  String get originNotAllowed => 'původ není povolen';

  @override
  String get outgoingMessage => 'Odchozí zpráva';

  @override
  String get outgoingWebhookUrl => 'Adresa URL odchozího webhooku';

  @override
  String get outlookEmailReceived => 'E-mail Outlook přijat';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Přepsat poznámky k chování z importu.';

  @override
  String get ownModel => 'vlastní model';

  @override
  String get packageName => 'Název balíčku';

  @override
  String get pairWithQrCode => 'Spárujte s QR kódem';

  @override
  String get password => 'Heslo';

  @override
  String get password2faAndActiveSessions => 'Heslo, 2FA a aktivní relace';

  @override
  String get passwordCreated => 'Heslo vytvořeno.';

  @override
  String get passwordIsTooWeak => 'heslo je příliš slabé';

  @override
  String get passwordMin8 => 'heslo min 8';

  @override
  String get passwordOrApiKey => 'Heslo nebo klíč API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Síla hesla: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Hesla se neshodují.';

  @override
  String get pasteAKey => 'Vložte klíč.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Vložte nový klíč, který nahradí $arg1';
  }

  @override
  String get pasteTheKey => 'Vložte klíč';

  @override
  String get pasteYourAccountToken => 'Vložte token svého účtu';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Níže vložte svůj klíč API $arg1. To je ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Cesta musí zůstat uvnitř NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Cesta musí zůstat ve složce pracovního prostoru.';

  @override
  String get pauseLiveUpdates => 'Pozastavit živé aktualizace';

  @override
  String get pauseTaskLoop => 'Pozastavit smyčku úloh';

  @override
  String get paused => 'Pozastaveno';

  @override
  String peakArg1(Object? arg1) {
    return 'vrchol $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Lidé v soukromých chatech';

  @override
  String get perAccountRateLimits => 'Sazbové limity na účet';

  @override
  String get perCategoryPermissions => 'Oprávnění pro jednotlivé kategorie';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Zásady oprávnění pro jednotlivé nástroje, schvalovací brány a izolace procesů pro spouštění prostředí.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Požadované povolení: $arg1';
  }

  @override
  String get permissionsNeeded => 'Potřebná oprávnění';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Oprávnění. Nikdo jiný to nemůže změnit.';

  @override
  String get personOrChat => 'Osoba nebo chat';

  @override
  String get personaBehaviorNotes => 'Poznámky k chování osoby';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Osobní přístupový token pro robota Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Osobní kanály a přímé opěrné plochy.';

  @override
  String get personalSelfChat => 'Osobní self-chat';

  @override
  String get phoneNumber => 'Telefonní číslo';

  @override
  String get pickARunFromTheList =>
      'Vyberte běh ze seznamu, abyste viděli jeho kroky.';

  @override
  String get pickARunFromTheList2 =>
      'Vyberte běh ze seznamu nalevo a prozkoumejte jeho průběh.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Vyberte si z nedávných chatů $arg1 nebo sami přidejte osobu či skupinu.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Vyberte, jak $arg1 používá tento účet.';
  }

  @override
  String get pickOneToFillInThe =>
      'Vyberte jeden, který splní úkol. Vše můžete následně doladit.';

  @override
  String get picksUpWhereYouLeftOff => 'Pokračujte tam, kde jste skončili';

  @override
  String get plan => 'Plán';

  @override
  String get planning => 'Plánování';

  @override
  String get platform => 'Platforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Vyberte prosím rozvrh.';

  @override
  String get pleaseEnterAFilename => 'Zadejte název souboru.';

  @override
  String get pleaseEnterAKey => 'Zadejte klíč.';

  @override
  String get pleaseEnterAPrompt => 'Zadejte prosím výzvu.';

  @override
  String get pleaseEnterATaskName => 'Zadejte název úkolu.';

  @override
  String get pleaseEnterTheMemoryContent => 'Zadejte obsah paměti.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Zadejte, kdy se má úloha spustit.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Vyberte účet nebo zadejte platné ID připojení.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Namiřte NeoAgent na jakékoli dokončení chatu kompatibilní s OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Namiřte fotoaparát na kód zobrazený na odhlášeném zařízení. Schválení zůstává na tomto telefonu.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env veřejná adresa URL důvěryhodného proxy zabezpečeného nasazení cookies';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Prémiová automatizace s plánovacími a integračními spouštěči.';

  @override
  String get prepareQrCode => 'Připravte si QR kód';

  @override
  String get preparingNeoagent => 'Příprava NeoAgent…';

  @override
  String get preparingNeoagent2 => 'Příprava NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Stiskněte a podržte pro rychlé zachycení';

  @override
  String get pressKeysIsNotSupportedOn =>
      'stisk kláves není na této platformě podporován.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Lisováno $arg1';
  }

  @override
  String get priceUnknown => 'Cena neznámá';

  @override
  String get primaryDisplay => 'Primární displej';

  @override
  String get privateChat => 'Soukromý chat';

  @override
  String get privateChats => 'Soukromé chaty';

  @override
  String get privateChats2 => 'soukromé chaty';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Soukromé chaty: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Soukromé chaty $arg1 · skupiny $arg2';
  }

  @override
  String get privateChatsOnly => 'Pouze soukromé chaty';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'adresy privátních sítí nejsou povoleny.';

  @override
  String get profileEmailAndPersonalData => 'Profil, e-mail a osobní údaje';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Dotázat se, než NeoAgent zůstane rezidentní v systémové liště.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Prompt cache: $arg1 mezipaměti tokenů ';
  }

  @override
  String get promptCopied => 'Výzva zkopírována.';

  @override
  String get promptOrSchedule => 'rychle nebo naplánovat.';

  @override
  String get promptToPasteIntoAnotherAi => 'Výzva ke vložení do jiné AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Propojení poskytovatele nelze spustit.';

  @override
  String get providerSignInCouldNotBe =>
      'Přihlášení poskytovatele nelze spustit.';

  @override
  String get providers => 'Poskytovatelé';

  @override
  String get providersEachAccountCanStillPick =>
      'Poskytovatelé; každý účet si stále může vybrat svůj vlastní model v Nastavení. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Poskytovatele, integrace, hlasové a volitelné funkce lze kdykoli dokončit v Nastavení.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Veřejná témata a vlákna žádostí o stažení, zodpovězena pouze schváleným lidem.';

  @override
  String get publicUrl => 'Veřejná adresa URL';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Veřejná adresa URL a povolené zdroje';

  @override
  String get publicUrlOverride => 'Přepsání veřejné adresy URL';

  @override
  String get pullsTogetherTheDayAhead => 'Dá se dohromady den dopředu';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'Propojení telefonu na základě QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR přihlášení bylo dokončeno, ale NeoAgent nemohl udržet relaci. Zkuste to prosím znovu.';

  @override
  String get qrLoginCouldNotBeStarted => 'QR přihlášení se nepodařilo spustit.';

  @override
  String get qrLoginRequestHasExpired => 'qr požadavek na přihlášení vypršel';

  @override
  String get qrLoginRequestWasNotFound =>
      'qr požadavek na přihlášení nebyl nalezen';

  @override
  String get qrPairing => 'QR párování';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'běží dotazy; vše, co napíše, je odmítnuto.';

  @override
  String get queryFilter => 'Dotaz / Filtr';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Ve frontě jako řízení pro aktuální běh: $arg1';
  }

  @override
  String get quickstart => 'Rychlý start';

  @override
  String get quit => 'Konec';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, wind_alert';

  @override
  String get ranAScriptInThePage => 'Spustil skript na stránce';

  @override
  String ranArg1(Object? arg1) {
    return 'Běžel $arg1';
  }

  @override
  String get rateLimits => 'Sazbové limity';

  @override
  String get readAnArtifact => 'Přečtěte si artefakt';

  @override
  String get readAndEditFilesInsideYour =>
      'Čtěte a upravujte soubory ve složce NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Přečtěte si $arg1';
  }

  @override
  String get readError => 'Chyba čtení';

  @override
  String get readFiles => 'Číst soubory';

  @override
  String get readOnly => 'Pouze pro čtení';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Přečtěte si složku a shrňte zásobník, vstupní body a způsob, jak jej spustit.';

  @override
  String get readThePage => 'Přečtěte si stránku';

  @override
  String get readTheUiTree => 'Přečtěte si strom uživatelského rozhraní';

  @override
  String get readWrite => 'Číst / psát';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Čte kroky, srdeční frekvenci, spánek, cvičení a váhu.';

  @override
  String get ready => 'Připraven';

  @override
  String get readyForFirstTimeSetup => 'Připraveno k prvnímu nastavení';

  @override
  String get readyToConnect => 'Připraveno k připojení';

  @override
  String get recentChannelActivity => 'Nedávná aktivita kanálu';

  @override
  String get recentChats => 'Nedávné chaty';

  @override
  String get recentDecisions => 'Nedávná rozhodnutí';

  @override
  String get recentFailedRuns => 'Nedávné neúspěšné běhy';

  @override
  String get recentGroupDecisions => 'Nedávná rozhodnutí skupiny';

  @override
  String get recentRuns => 'Nedávné běhy';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Poslední běhy trvají asi $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Poslední výstup serveru, nejnovější.';

  @override
  String get recentUsage4Hours => 'Nedávné použití (4 hodiny)';

  @override
  String get recents => 'Nedávné';

  @override
  String get recipientField => 'Pole příjemce';

  @override
  String get reconnectOrFinishSetup =>
      'Znovu se připojte nebo dokončete nastavení';

  @override
  String get reconnectingThisDevice => 'Opětovné připojování tohoto zařízení…';

  @override
  String get recurring => 'Opakující se';

  @override
  String get redirectUri => 'Přesměrování URI';

  @override
  String get redoOnboarding => 'Opakujte registraci';

  @override
  String get refresh => 'Obnovit';

  @override
  String get refreshCode => 'Obnovit kód';

  @override
  String get refreshNow => 'Obnovte nyní';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Obnovte obrazovku Android a zkuste to znovu.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Odmítněte odeslat, dokud se připojení neupgraduje na TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'bez ohledu na níže uvedená nastavení pro jednotlivé kategorie.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Zaregistrujte $arg1 pro postup přivolání asistenta.';
  }

  @override
  String get registrationIsClosed => 'registrace je uzavřena';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registrace registrovat nové účty umožňují registraci';

  @override
  String get rejectInvalidTlsCertificates =>
      'Odmítněte neplatné certifikáty TLS';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'uvolnit a restartovat. Připojené aplikace se znovu připojí, jakmile budou zpět.';

  @override
  String get releaseChannel => 'Uvolněte kanál';

  @override
  String get releaseCommitBranchNode => 'uvolnit uzel větve potvrzení';

  @override
  String get releaseWhenYouAreDone => 'Po dokončení uvolněte.';

  @override
  String get reloadNow => 'Znovu načíst';

  @override
  String get rememberThisChoice => 'Pamatujte na tuto volbu';

  @override
  String get remove => 'Odebrat';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Odstranit „$arg1“ a jeho zaznamenané kroky z historie běhu?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Odeberte \"$arg1\" z hlavní paměti.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Odebrat klíč $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'odstranit vymazat uživatele gdpr';

  @override
  String get removeSmtpPassword => 'Odstraňte heslo SMTP';

  @override
  String get removeTheSmtpPassword => 'Odebrat heslo SMTP?';

  @override
  String get rename => 'Přejmenovat';

  @override
  String get renameSecurityKey => 'Přejmenujte bezpečnostní klíč';

  @override
  String get renameSession => 'Přejmenovat relaci';

  @override
  String get repairAndRetry => 'Opravte a zkuste to znovu';

  @override
  String get repairDesktop => 'Oprava pracovní plochy';

  @override
  String get repeat => 'Opakujte';

  @override
  String get repliesWhenTagged => 'Odpovědi při označení';

  @override
  String get replyToAddress => 'Adresa pro odpověď';

  @override
  String replyToArg1(Object? arg1) {
    return 'Odpověď na $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Úložiště musí být ve formátu vlastník/úložiště.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Zopakujte chybu, kterou popisuji, najděte hlavní příčinu a opravte ji pomocí regresního testu.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'požadavek se nezdařil s http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Požadavek se nezdařil s HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Vyžádejte si oprávnění';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Požadavek na $arg1 selhal, než backend odpověděl.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Požadovaný $arg1';
  }

  @override
  String get requireStarttls => 'Vyžadovat STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Vyžaduje se za HTTPS nebo TLS proxy. Platí po serveru ';

  @override
  String get requiredExampleBerlinDe => 'Povinné. Příklad: Berlín, DE';

  @override
  String get requiredFormatOwnerRepo => 'Povinné. Formát: vlastník/repo';

  @override
  String get reserveAssistantHotkey =>
      'Klávesová zkratka pro asistenta rezervace';

  @override
  String get reset => 'Resetovat';

  @override
  String get resetPassword => 'Obnovit heslo';

  @override
  String get resetView => 'Obnovit zobrazení';

  @override
  String get responsibilities => 'Odpovědnosti';

  @override
  String get restart => 'Restartujte';

  @override
  String get restartToFinishTheUpdate =>
      ' Restartujte pro dokončení aktualizace.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Obnovení předchozího běhového prostředí NeoAgent';

  @override
  String get restrictDelegationTargets => 'Omezit cíle delegování';

  @override
  String get result => 'Výsledek';

  @override
  String get resultDelivery => 'Doručení výsledku';

  @override
  String get resultOneClickAddsOneYou =>
      'výsledek. Jedno kliknutí přidá jedno; můžete upravit později.';

  @override
  String get results => 'Výsledky';

  @override
  String get retry => 'Zkuste to znovu';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Opakovaně použitelné · použité $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Zkontrolujte neprovedené změny';

  @override
  String get revoke => 'Odvolat';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Nejprve zrušte admin pomocí `neoagent admin revoke $arg1`';
  }

  @override
  String get revokeThisLink => 'Zrušit tento odkaz?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Okno dávky místnosti: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Pokračujte otočením';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'řádky. Pro zobrazení přidejte LIMIT nebo užší klauzuli WHERE ';

  @override
  String get rule => 'Pravidlo';

  @override
  String get run => 'Spuštění';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Spusťte libovolné příkazy na vašem počítači nebo virtuálním počítači.';

  @override
  String get runAt => 'Run At';

  @override
  String get runCompleted => 'Běh dokončen';

  @override
  String get runFailed => 'Spuštění se nezdařilo';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Spusťte git diff, zkontrolujte neprovedené změny, zda neobsahují chyby a problémy se stylem, a shrňte, co najdete.';

  @override
  String get runNotFound => 'Spustit nebyl nalezen';

  @override
  String get runNow => 'Spustit nyní';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Spustit na příchozích osobních zprávách WhatsApp.';

  @override
  String get runQuery => 'Spustit dotaz';

  @override
  String get runShellCommandsOrInstallApps =>
      'Spouštějte příkazy prostředí nebo instalujte aplikace do zařízení Android.';

  @override
  String get runStarted => 'Běh zahájen';

  @override
  String get runStatus => 'Stav běhu';

  @override
  String get runStopped => 'Běh zastaven';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Spouštějte příkazy terminálu a otevírejte aplikace nebo webové stránky.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Spusťte tento server: účty, aktualizace, poskytovatelé, konfigurace ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Spustit, když dorazí odpovídající zpráva Gmailu.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Spustit, když dorazí odpovídající e-mail aplikace Outlook.';

  @override
  String get runWhenANewIssueMatching =>
      'Spustit, když se v úložišti otevře nový problém odpovídající vašim filtrům.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Spustit, když se vytvoří nová paměť NeoRecall odpovídající vašim filtrům.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Spustit, když na vaše zařízení dorazí oznámení.';

  @override
  String get runWhenASlackMessageMatches =>
      'Spustit, když zpráva Slack odpovídá vybranému rozsahu.';

  @override
  String get runWhenATeamsChatMessage =>
      'Spustit, když chatová zpráva Teams odpovídá vybranému rozsahu.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Spustit, když se pro určité místo předpovídají nakonfigurované události počasí.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'běh. Zatímco jakýkoli model je vypnutý, modely, které poskytovatelé přidávají ';

  @override
  String get running => 'Probíhá';

  @override
  String runningArg1(Object? arg1) {
    return 'Běží $arg1';
  }

  @override
  String get runningTask => 'Běžící úkol';

  @override
  String get runningTool => 'Běžecký nástroj';

  @override
  String get runs => 'Spuštění';

  @override
  String get runsEveryDayAtTheSelected =>
      'Spustí se každý den ve zvolenou dobu.';

  @override
  String get runsFourTimesPerHour => 'Běží čtyřikrát za hodinu.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— běhy, zprávy, paměti, integrace, soubory a ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'běhy, zprávy, paměti, integrace, soubory a relace. ';

  @override
  String get runsMondayThroughFriday => 'Běží od pondělí do pátku.';

  @override
  String get runsOnSelectedWeekdays => 'Běží ve vybrané všední dny.';

  @override
  String get runsOncePerHour => 'Jezdí jednou za hodinu.';

  @override
  String get runsOncePerMonthOnThe =>
      'Spouští se jednou za měsíc ve vybraný den.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Spustí se, pouze když stisknete Spustit nyní.';

  @override
  String get runsPerDay => 'Běží za den';

  @override
  String get runsPerDay30Days => 'Běží za den (30 dní)';

  @override
  String get runsThatCompleted => 'Spustí, které byly dokončeny';

  @override
  String get runsThisWeek => 'Běží tento týden';

  @override
  String get runsToday => 'Běží dnes';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Zde jsou k dispozici běhy, nástroje, paměť, plánování, dovednosti a MCP.';

  @override
  String get runsTwicePerHour => 'Běží dvakrát za hodinu.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Spuštění se vrátí ke sdílenému klíči serveru pro $arg1, pokud je nakonfigurován. Toto nelze vrátit zpět.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Runtime $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Provozní doba: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Nastavení runtime, se kterým tento server začínal. Upravte je pod ';

  @override
  String get runtimeSetupRequired => 'Je vyžadováno nastavení runtime';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Veřejný klíč pro podepisování za běhu musí mít 32 bajtů.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Uložit';

  @override
  String get saveATrelloApiKeyFor =>
      'Uložte klíč Trello API pro tohoto agenta a poté bezpečně připojte jeden účet Trello. Token účtu je uložen na serveru a používá se pouze pro tohoto agenta.';

  @override
  String get saveAccount => 'Uložit účet';

  @override
  String get saveChanges => 'Uložte změny';

  @override
  String get saveCloudComputerSettings =>
      'Uložte nastavení cloudového počítače';

  @override
  String get saveConnect => 'Uložit a připojit';

  @override
  String get saveDefaults => 'Uložit výchozí nastavení';

  @override
  String get saveDiagnosticReport => 'Uložit diagnostickou zprávu';

  @override
  String get saveEmail => 'Uložit e-mail';

  @override
  String get saveEmailSettings => 'Uložte nastavení e-mailu';

  @override
  String get saveGeneralSettings => 'Uložte obecná nastavení';

  @override
  String get saveName => 'Uložit jméno';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Uložte diagnostiku nastavení NeoAgent';

  @override
  String get saveOnly => 'Pouze uložit';

  @override
  String get saveSetup => 'Uložit nastavení';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Uložte si tyto kódy pro obnovení. Už se nebudou zobrazovat.';

  @override
  String get savedDeliveryDestination => 'Uložený cíl doručení';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Uložené limity rychlosti pro @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Naskenujte přihlašovací QR kód NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Naskenujte párovací QR kód NeoAgent z jiného zařízení a schvalte jej z této relace spouštěče.';

  @override
  String get scanLoginQr => 'Naskenujte přihlašovací QR';

  @override
  String get scanPairingQr => 'Naskenujte párovací QR kód';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Naskenujte QR požadavky na přihlášení z odhlášených zařízení a schvalte je z této ověřené mobilní relace.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Skenujte pro dokončení $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Skenujte pomocí NeoAgent na vašem telefonu';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Prohledá nový e-mail a odešle vám pouze ping, když na něčem záleží.';

  @override
  String get schedule => 'Rozvrh';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'naplánovaný čas. Jakmile jsou jízdy změřeny, začne dříve.';

  @override
  String get screen => 'Obrazovka';

  @override
  String get screenAction => 'akce obrazovky';

  @override
  String get scrollIsNotSupportedOnThis =>
      'rolování není na této platformě podporováno.';

  @override
  String get scrollToBottom => 'Přejděte dolů';

  @override
  String get search => 'Hledat';

  @override
  String get search2 => 'Hledat…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Vyhledat nastavení správce (např. SMTP, Ollama, protokoly)';

  @override
  String get searchAgain => 'Hledejte znovu';

  @override
  String get searchByUsernameOrEmail =>
      'Vyhledávání podle uživatelského jména nebo e-mailu';

  @override
  String get searchChannels => 'Hledat kanály';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Prohledejte nalezené kanály zpráv, kontakty, skupiny a nedávné konverzace.';

  @override
  String get searchGroups => 'Hledat skupiny';

  @override
  String get searchMemory => 'Prohledejte paměť';

  @override
  String get searchModelsOrProviders => 'Vyhledejte modely nebo poskytovatele';

  @override
  String get searchModelsOrProviders2 => 'Hledat modely nebo poskytovatele…';

  @override
  String get searchRecentPeopleAndGroups => 'Vyhledejte nedávné lidi a skupiny';

  @override
  String get searchSessions => 'Vyhledávání relací';

  @override
  String get searchSettings => 'Nastavení vyhledávání';

  @override
  String get searchTitleModelTriggerRunId =>
      'Vyhledejte název, model, spouštěč, ID běhu';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Vyhledávací nástroje, integrace a dovednosti';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Hledaný kód pro \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Hledané soubory pro \"$arg1\"';
  }

  @override
  String get secretField => 'Tajné pole';

  @override
  String get secureCookies => 'Zabezpečené soubory cookie';

  @override
  String get security => 'Bezpečnost';

  @override
  String get securityKey => 'Bezpečnostní klíč';

  @override
  String get securityKeyPromptWasDismissed =>
      'Výzva k bezpečnostnímu klíči byla zrušena.';

  @override
  String get securityKeySignInCompletedBut =>
      'Přihlášení pomocí bezpečnostního klíče bylo dokončeno, ale NeoAgent nemohl udržet relaci prohlížeče. Přihlaste se prosím znovu.';

  @override
  String get securityKeySignInCouldNot =>
      'Přihlášení pomocí bezpečnostního klíče se nepodařilo spustit.';

  @override
  String get securityKeys => 'Bezpečnostní klíče';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Bezpečnostní klíče jsou k dispozici pouze ve webové aplikaci NeoAgent.';

  @override
  String get seeAll => 'Zobrazit vše';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Podívejte se, který server NeoAgent toto okno používá, a spusťte backend na tomto počítači.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'zobrazit své uživatelské jméno a tato nastavení, nikdy své chaty, vzpomínky ';

  @override
  String get selectARun => 'Vyberte běh';

  @override
  String get selectASessionToSeeIts =>
      'Vyberte relaci a zobrazte její počítač, soubory a změny.';

  @override
  String get selectAll => 'Vyberte vše';

  @override
  String get selectAll2 => 'Vyberte Vše';

  @override
  String selectArg1(Object? arg1) {
    return 'Vyberte $arg1';
  }

  @override
  String get selectTrigger => 'Vyberte možnost Spustit';

  @override
  String get send => 'Odeslat (⌘↵)';

  @override
  String get send2 => 'Odeslat';

  @override
  String get sendATaskFromChatAnd =>
      'Odešlete úkol z chatu a zde se zobrazí historie jeho provádění.';

  @override
  String get sendItToATeammateWith =>
      'pošlete jej spoluhráči s účtem na tomto serveru.';

  @override
  String get sendLink => 'Odeslat odkaz';

  @override
  String get sendPath => 'Poslat cestu';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Odesílejte požadavky POST / PUT / DELETE na externí rozhraní API.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Pošlete tento odkaz pouze osobě, pro kterou je určen. Je zobrazen jednou; ';

  @override
  String get senderAddress => 'Adresa odesílatele';

  @override
  String get senderFilterOptional => 'Filtr odesílatele (volitelné)';

  @override
  String get sentSharedAttachments => 'Odeslané sdílené přílohy.';

  @override
  String get separateAccount => 'Samostatný účet';

  @override
  String get server => 'Server';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Výchozí server ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Výchozí nastavení serveru pro hlasové hovory v aplikaci. Hovory běží živě ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'samotný server: účty, poskytovatelé a konfigurace.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, přezdívka, kanál a volitelné TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'výstup serveru konzole varování chyby kopie';

  @override
  String get serverProviderCredentials => 'Pověření poskytovatele serveru';

  @override
  String get serverUrl => 'Adresa URL serveru';

  @override
  String get serverUsageLimitsDonTApply =>
      'Limity využití serveru se nevztahují na modely běžící na vašem vlastním klíči.';

  @override
  String get serviceEmail => 'Servisní email';

  @override
  String get serviceEmailIsNotConfigured => 'e-mail služby není nakonfigurován';

  @override
  String get serviceEmailSmtp => 'Servisní e-mail (SMTP)';

  @override
  String get sessionActions => 'Akce relace';

  @override
  String get sessions => 'Relace';

  @override
  String get sessions2 => 'SEKCE';

  @override
  String get sessionsArePinnedToAFolder =>
      'Relace jsou připnuty ke složce a počítači. Začněte s jedním plánovat, stavět, testovat a odesílat odtud.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'zasedání (článek 17 GDPR). Účty správce nelze smazat ';

  @override
  String get sessionsLogoutRevokeForce => 'sessions logout revoke force';

  @override
  String get setBlockAskAllowPerTool =>
      'Nastavte blokování / dotazování / povolení podle kategorie nástrojů nebo vyberte globální režim.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Nastavte NeoAgent na tomto počítači';

  @override
  String get setUpOrConnectNeoagent => 'Nastavte nebo připojte NeoAgent';

  @override
  String get setUrl => 'Nastavit URL';

  @override
  String get settings => 'Nastavení';

  @override
  String get settingsAndCannotBeUndone => 'nastavení a nelze je vrátit zpět.';

  @override
  String get settingsArea => 'Oblast nastavení';

  @override
  String get settingsAreas => 'Oblasti nastavení';

  @override
  String get setup => 'Nastavení';

  @override
  String get setupDetails => 'Podrobnosti nastavení';

  @override
  String get setupRequired => 'Je vyžadováno nastavení';

  @override
  String get setupWasCancelled => 'Nastavení bylo zrušeno.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Sdílené přílohy z klienta NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Sdíleno z jiné aplikace';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Sdílené klíče poskytovatele jsou nakonfigurovány na serveru. Chcete-li místo toho použít vlastní klíč API nebo vlastní koncový bod, přejděte na Rozšířené → Přinést vlastní klíč.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Sdíleno s chatem NeoAgent a jeho pamětí.';

  @override
  String get shellCommands => 'Příkazy Shell';

  @override
  String showAllArg1(Object? arg1) {
    return 'Zobrazit vše $arg1';
  }

  @override
  String get showEarlier => 'Zobrazit dříve';

  @override
  String get showEveryStep => 'Ukažte každý krok';

  @override
  String get showTools => 'Zobrazit nástroje';

  @override
  String get showWorkbenchJ => 'Zobrazit pracovní stůl (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Zobrazuje se první $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Zobrazeno v postranním panelu. Chcete-li použít své uživatelské jméno, ponechte prázdné.';

  @override
  String get signIn => 'Přihlaste se';

  @override
  String get signInCompletedButNeoagentCould =>
      'Přihlášení bylo dokončeno, ale NeoAgent nemohl udržet relaci prohlížeče. Přihlaste se prosím znovu. Pokud se to bude opakovat, zkontrolujte nastavení cookies relace.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Přihlášení bylo dokončeno, ale NeoAgent nemohl udržet relaci prohlížeče. Přihlaste se prosím znovu. Pokud se to bude opakovat, soubor cookie relace backend se pravděpodobně neuchová.';

  @override
  String get signInToThisNeoagentServer =>
      'Před skenováním párovacího QR kódu se přihlaste k tomuto serveru NeoAgent.';

  @override
  String get signInWithAHardwareKey =>
      'Přihlaste se pomocí hardwarového klíče nebo hesla namísto hesla. ';

  @override
  String get signInWithASecurityKey =>
      'Přihlaste se pomocí bezpečnostního klíče';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Přihlaste se pomocí $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Schvalte NeoAgent ve svém účtu $arg1. Žádný klíč ke kopírování.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Čekání na $arg1. Dokončete ve svém prohlížeči.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Vložte kód $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Poté, co jste schválili NeoAgent, $arg1 ukázal jednorázový kód. Vložte to sem.';
  }

  @override
  String get signInCode => 'Přihlašovací kód';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Přihlášeno pomocí $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Přihlášení se nezdařilo: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Přihlaste se pomocí stejného e-mailu a hlavního hesla, které používáte v Bitwarden. Hlavní heslo a dvoustupňový kód se používají pouze pro přihlášení a nikdy se neukládají ani neodesílají do AI.';

  @override
  String get signOut => 'Odhlaste se';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Odhlásit se @$arg1 všude?';
  }

  @override
  String get signOutEverywhere => 'Odhlaste se všude';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API most';

  @override
  String get signalCliServerUrl => 'adresa URL serveru signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Odhlášen @$arg1 z každé relace.';
  }

  @override
  String get signedInDevices => 'Přihlášená zařízení';

  @override
  String get signedInWithin24Hours => 'Přihlášeno do 24 hodin';

  @override
  String get signingSecret => 'Tajemství podpisu';

  @override
  String sinceArg1(Object? arg1) {
    return 'Od $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'od $arg1';
  }

  @override
  String get singleMessage => 'Jediná zpráva';

  @override
  String get singleUse => 'Jedno použití';

  @override
  String get skill => 'Dovednost';

  @override
  String get skillChanges => 'Změny dovedností';

  @override
  String get skillContent => 'Obsah dovedností';

  @override
  String get skills => 'Dovednosti';

  @override
  String get skip => 'Přeskočit';

  @override
  String get skipForNow => 'Prozatím přeskočte';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Před voláním modelu tuto úlohu přeskočte.';

  @override
  String get slackMessageReceived => 'Slack zpráva přijata';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Spánek relace $arg1';
  }

  @override
  String get smartSelector => 'chytrý volič';

  @override
  String get smartSelector2 => 'Inteligentní volič';

  @override
  String get smartSelectorPool => 'Inteligentní výběrový fond';

  @override
  String get smtpHost => 'Hostitel SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp mail odesílatele heslo TLS potvrzení oznámení resetovat';

  @override
  String get smtpPassword => 'SMTP heslo';

  @override
  String get smtpPort => 'SMTP port';

  @override
  String get smtpPortMustBeAWhole =>
      'Port SMTP musí být celé číslo od 1 do 65535.';

  @override
  String get smtpUsername => 'Uživatelské jméno SMTP';

  @override
  String get soTheRunStartsThatMuch => 'takže běh začíná mnohem dříve.';

  @override
  String get socialBehaviorOff => 'Společenské chování vypnuto';

  @override
  String get socialIntelligence => 'sociální inteligence';

  @override
  String get socialIntelligence2 => 'Sociální inteligence';

  @override
  String get socialObservability => 'Sociální pozorovatelnost';

  @override
  String get socialReach => 'sociální dosah';

  @override
  String get socialReach2 => 'Sociální dosah';

  @override
  String get socialReach3 => 'Sociální dosah';

  @override
  String get socialReachUpdated => 'Sociální zásah aktualizován.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Agenti sociálních zdrojů mohou číst přímo, včetně zdrojů, úložišť, Reddit, X, videí a údajů o trhu podporovaných soubory cookie.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Něco se pokazilo. Zkuste to prosím znovu.';

  @override
  String get source => 'Zdroj';

  @override
  String get spaceOrChatIdUsedWhen =>
      'ID prostoru nebo chatu použité, když tento agent zahájí konverzaci.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space webhook a podpora zpětného volání aplikace';

  @override
  String get speaking => 'Mluvit';

  @override
  String get speechToSpeechModelUsingThe =>
      'model řeči na řeč pomocí klíče OpenAI nebo Google pod ';

  @override
  String get speechToText => 'Převod řeči na text';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Přepis řeči na text přepisuje hlasové poznámky a diktáty. Auto používá OpenAI, Gemini nebo Deepgram, podle toho, co má klíč API. Model hlasové odpovědi je model chatu, který odpovídá na hlasové poznámky.';

  @override
  String get sqlConsole => 'SQL konzole';

  @override
  String get stable => 'Stabilní';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable nainstaluje nejnovější publikovanou backendovou verzi.';

  @override
  String get stackTrace => 'trasování zásobníku';

  @override
  String get standard => 'Standardní';

  @override
  String get standardView => 'Standardní pohled';

  @override
  String get start => 'Začněte';

  @override
  String get startASessionToPlanOr =>
      'Zahajte relaci k plánování nebo budování pomocí NeoAgent.';

  @override
  String get startAndroid => 'Spusťte Android';

  @override
  String get startComputer => 'Spusťte počítač';

  @override
  String get startFullSetup => 'Spusťte úplné nastavení';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Spusťte nastavení';

  @override
  String get startTalking => 'Začněte mluvit';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Nejprve spusťte telefon Android a poté sem přetáhněte soubor .apk nebo .apks.';

  @override
  String get startTheServerLaterFromThe =>
      'Po uložení konfigurace spusťte server později ze seznamu.';

  @override
  String get startWithARecommendedTask => 'Začněte doporučeným úkolem';

  @override
  String get startingAndroid => 'Spouštění Androidu';

  @override
  String get startingYourComputer => 'Spouštění počítače';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Začíná xoxb-. Z vašich přihlašovacích údajů aplikace Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'StartTelecomCallRouting Chyba: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistiky běží tokeny uživatelé grafy úspěšnost';

  @override
  String get status => 'Stav';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'poskytovatelé stavu databáze runtime vm';

  @override
  String get statusIsNotLoadedYet => 'Stav ještě není načten.';

  @override
  String get stayManagedByYou => 'zůstat pod vámi.';

  @override
  String get stayOnTheCall => 'Zůstaňte na hovoru';

  @override
  String get stayedQuiet => 'Zůstal potichu';

  @override
  String get steering => 'ŘÍZENÍ';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'KROK $arg1 Z $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Kroky $arg1';
  }

  @override
  String get stop => 'Zastavit';

  @override
  String get stop2 => 'Zastavit (⌘.)';

  @override
  String get stopManaging => 'Přestaňte spravovat';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Přestat spravovat $arg1?';
  }

  @override
  String get stopRun => 'Zastavit běh';

  @override
  String get stopSpeaking => 'Přestaň mluvit';

  @override
  String get stoppedBeforeCompletion => 'Zastaveno před dokončením';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'Chyba stopTelecomCallRouting: $arg1';
  }

  @override
  String get storage => 'Skladování';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'uložené zašifrované a používané pouze pro vaše vlastní běhy.';

  @override
  String get storedMetrics => 'Uložené metriky';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Ukládá pouze klíč relace Bitwarden zašifrovaný na tomto serveru, takže připojení přežijí restartování. Můžete jej kdykoli zamknout.';

  @override
  String get strong => 'Silný';

  @override
  String get strongPassword => 'Silné heslo.';

  @override
  String get subAgent => 'Sub-agent';

  @override
  String get subagentUpdate => 'Aktualizace subagenta';

  @override
  String get subagentUpdate2 => 'Aktualizace subagenta.';

  @override
  String get successRate => 'Úspěšnost';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Návrhy: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Shrň můj poslední běh';

  @override
  String get supportUrl => 'URL podpory';

  @override
  String get supportedRainStartSnowStartWind =>
      'Podporované: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Přepnout agenta';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'V cestách NeoAgent Workspace nejsou povoleny symbolické odkazy.';

  @override
  String get syncNow => 'Synchronizovat nyní';

  @override
  String get synologyChat => 'Chat Synology';

  @override
  String get systemPrivacySettings => 'Nastavení soukromí systému';

  @override
  String get tableInfoUsers => 'Informace o tabulce (uživatelé)';

  @override
  String get tagsOnly => 'Pouze značky';

  @override
  String get tasks => 'Úkoly';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Úkoly běží samy o sobě a zasílají vám zprávu pomocí ';

  @override
  String get teach => 'Učit';

  @override
  String get teachingInProgress => 'Výuka probíhá';

  @override
  String get team => 'Tým';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Týmové odkazy nikdy neudělají z nikoho správce serveru. Správci spouštějí ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Týmové prostory, místnosti, kanály a živé komunity.';

  @override
  String get teamsMessageReceived => 'Zpráva týmů přijata';

  @override
  String get templates => 'Šablony';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Dočasné instalační soubory budou později vyčištěny.';

  @override
  String get tenantId => 'ID nájemce';

  @override
  String get testConnection => 'Test připojení';

  @override
  String get testConnection2 => 'Test připojení';

  @override
  String get textChat => 'SMS a chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'kteří přidali svůj vlastní klíč, ho dál používejte.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Tento e-mail již patří k existujícímu účtu. Nejprve se přihlaste a poté propojte Google z nastavení účtu.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Tento e-mail je již propojen s jiným účtem.';

  @override
  String get thatQrCodeIsNotA =>
      'Tento QR kód není požadavek na přihlášení NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Tento QR kód není požadavek na párování NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Tento bezpečnostní klíč je již v tomto účtu zaregistrován.';

  @override
  String get theAddress => 'Adresa';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Adresa vašeho serveru BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Adresa, kterou lidé a poskytovatelé OAuth používají ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agent čte časy, které zmiňujete, a spouští naplánované úlohy v tomto časovém pásmu.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agent se zeptá před každým citlivým nástrojem, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Agent bude tuto dovednost ignorovat.';

  @override
  String get theAppCouldNotReachThis =>
      'Aplikace nemohla dosáhnout tohoto nasazení NeoAgent. Zkontrolujte připojení k síti nebo potvrďte správnost adresy URL služby.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Prohlížeč zablokoval požadavek na $arg1 kvůli zásadám zabezpečení obsahu.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Prohlížeč zablokoval požadovaný požadavek kvůli zásadám zabezpečení obsahu.';

  @override
  String get theCloudWorkspace => 'cloudový pracovní prostor';

  @override
  String get theComputerCouldNotStart => 'Počítač nelze spustit';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Počítač potřebuje více volného místa na disku na hostiteli NeoAgent. Uvolněte místo a zkuste to znovu.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Runtime počítače potřebuje opravu. Spusťte NeoAgent Doctor a zkuste to znovu.';

  @override
  String get theConnectionTestFailed => 'Test připojení se nezdařil.';

  @override
  String get theDesktopDidNotStart => 'Plocha se nespustila';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Objevený NeoAgent vrátil neúplné údaje o identitě.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Objevený NeoAgent používá nepodporovaný protokol nastavení.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Objevená služba není NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Stažené runtime NeoAgent neprošlo ověřením.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Webhook prostoru pro chat Google, do kterého by měl tento zástupce přispívat.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Instalační program již není k dispozici.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Interaktivní plocha Linuxu je k dispozici ve webové aplikaci NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Úvod není na tomto zařízení k dispozici.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Nejnovější běží napříč každým účtem.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Poslední okno synchronizace ukončilo $arg1 a nenašlo žádné nové záznamy Health Connect. Níže uložené metriky pocházejí z dřívějších synchronizací.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot => 'Grafická relace Linuxu neběží.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Živý hlasový model neodpověděl. Zkuste to znovu.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Místní příkaz NeoAgent skončil s kódem $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Vypršel časový limit místního příkazu NeoAgent.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Místní runtime NeoAgent potřebuje opravu.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Místní runtime potřebuje opravu ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Místní domovský adresář uživatele není k dispozici.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'E-mailový účet NeoAgent odesílá potvrzení o přihlášení, přihlášení ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Hlavní agent se v případě potřeby vytvoří automaticky.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'V této verzi chybí odpovídající runtime NeoAgent.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Příchozí webhook Mattermost, na který by měl tento agent posílat.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Modely, mezi kterými Smart Selector automaticky přechází.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Stažení backendu NeoAgent neodpovídalo jeho manifestu.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Stažení backendu NeoAgent bylo neúplné.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Backend NeoAgent na tomto počítači neodpovídá na portu ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Backendový runtime NeoAgent nelze stáhnout.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Backendu NeoAgent trvalo příliš dlouho, než reagoval na $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Nasazení NeoAgent odpovědělo HTTP 402 namísto normálního 401 pro neplatné přihlašovací údaje. Zkontrolujte reverzní proxy, auth gateway nebo pravidla související s platbami na tomto serveru.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Nasazení NeoAgent reagovalo pomocí HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Nasazení NeoAgent reagovalo pomocí HTTP 402. Zkontrolujte na tomto serveru pravidla reverzního proxy, auth brány nebo pravidel souvisejících s platbami.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Instance NeoAgent, ke které je tato aplikace připojena.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Služba vydání NeoAgent vrátila neplatná data.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Metadata runtime artefaktu NeoAgent jsou neplatná.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Runtime manifest NeoAgent neprošel ověřením podpisu.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Runtime manifest NeoAgent neobsahuje žádné artefakty.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Podpis runtime manifestu NeoAgent je neplatný.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Heslo, které jste nastavili v BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Lidé, které řídíte, zůstávají s vámi.';

  @override
  String get theProviderAnswers => 'odpoví poskytovatel.';

  @override
  String get theQueryReturnedNoRows => 'Dotaz nevrátil žádné řádky.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Požadované zobrazení plochy není k dispozici.';

  @override
  String get theRest => 'ostatní.';

  @override
  String get theRestEndpointForYourSignal =>
      'Koncový bod REST pro vaši instanci signál-cli.';

  @override
  String get theRunIsPausedUntilYou => 'Běh je pozastaven, dokud neodpovíte.';

  @override
  String get theRunStartsAtTheScheduled => 'Běh začíná v naplánovaný čas.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Runtime je lehký desktop Debian Linux s Chromium, PCManFM, Mousepad, LXTerminal, Python, Git a standardními nástroji příkazového řádku. Jeho kapacita je spravována hostitelem NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Registraci bezpečnostního klíče nelze spustit.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'server uchovává pouze jeho otisk.';

  @override
  String get theServerOnThisComputerIs =>
      'Server na tomto počítači není spuštěn';

  @override
  String get theServerReportedNoHealthChecks =>
      'Server nehlásil žádné zdravotní kontroly.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Telefonní číslo signálu, které tento robot používá.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Příchozí webhook Teams, do kterého by měl tento agent posílat příspěvky.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Dvoufaktorová výzva vypršela. Znovu se přihlaste.';

  @override
  String get theTwoFactorCodeIsNot => 'Dvoufaktorový kód není platný.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Ověřený runtime balíček nelze označit jako spustitelný.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'V ověřeném runtime balíčku chybí požadované soubory.';

  @override
  String get theWebAppCouldNotReach =>
      'Webové aplikaci se nepodařilo dosáhnout backendu NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Webové aplikaci se nepodařilo dosáhnout backendu NeoAgent na $arg1. Zkontrolujte konzolu prohlížeče a konfiguraci reverzního proxy/sítě.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'sami; operátor serveru nejprve odebere správce pomocí ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Tyto kanály zůstávají tiché. Chcete-li o nich znovu slyšet, přidejte je do části Kdo může zprávu pro danou platformu.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Tyto seznamy jsou volitelné, pokud není výše uvedená sekce nastavena jako pouze schválená.';

  @override
  String get thesePeopleAnywhere => 'Tito lidé, kdekoli';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Tito lidé mohou posílat zprávy $arg1 v soukromých chatech a v jakékoli skupině, kterou sdílejí.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Tito lidé mohou poslat zprávu $arg1 jeden na jednoho. To jim neumožňuje mluvit ve skupinách.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Tito lidé mohou posílat zprávy pouze $arg1 ve skupině, kterou jste vybrali.';
  }

  @override
  String get thesePeopleInOneGroup => 'Tito lidé v jedné skupině';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'tyto přepínače, nikdy vaše chaty, vzpomínky nebo soubory.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Tento účet odemkne NeoAgent na tomto počítači.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Tento agent může delegovat libovolného způsobilého přijímajícího agenta.';

  @override
  String get thisAgentIsUsingAServer =>
      'Tento agent používá klíč rozhraní API Trello spravovaný serverem. Musíte pouze autorizovat token účtu níže.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Toto sestavení nemá povoleno komunikovat s tímto nasazením NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Tento kód patří jinému serveru NeoAgent: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Tato plocha je připojena';

  @override
  String get thisDevice => 'Toto zařízení';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Toto zařízení: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Toto zařízení nemůže zaregistrovat bezpečnostní klíče. Otevřete NeoAgent v prohlížeči přes HTTPS a přidejte jej.';

  @override
  String get thisDeviceUnavailable => 'Toto zařízení — nedostupné';

  @override
  String get thisFileHasNoContent => 'Tento soubor nemá žádný obsah.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'To skryje \"$arg1\" před směrováním a výběrem.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Tato integrace aktuálně podporuje jeden připojený účet na agenta. Chcete-li jej vyměnit, znovu otevřete nastavení.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Tato integrace již není k dispozici.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Tento úvod je určen pro přehrávání na šířku na celou obrazovku.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Toto je řízené nasazení. Jeho operátor se rozjíždí ';

  @override
  String get thisMayTakeAMoment => 'Může to chvíli trvat.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Tento MCP server již není nakonfigurován.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Tato paměť bude trvale odstraněna.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Toto sestavení NeoAgent není nakonfigurováno pro ověřování backendových běhových modulů.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'To trvale vymaže všechna vaše data a nemůže být ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Tím se trvale vymaže účet a vše, co vlastní: ';

  @override
  String get thisPersonAnywhere => 'Tato osoba, kdekoli';

  @override
  String get thisPersonInOneGroup => 'Tato osoba v jedné skupině';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Platnost tohoto požadavku na přihlášení QR vypršela. Vygenerujte nový kód a zkuste to znovu.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'platnost tohoto požadavku na přihlášení qr vypršela';

  @override
  String get thisQrLoginRequestIsStill =>
      'Tento požadavek na přihlášení pomocí QR kódu stále čeká na schválení.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Tento požadavek na přihlášení pomocí QR kódu již byl použit.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Tím se odebere nastavení Home Assistant a připojená instance pro tohoto agenta.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Tím se odstraní koncová URL NeoRecall a všechny připojené účty NeoRecall pro tohoto agenta.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Tím se odstraní adresa URL Nextcloud a všechny připojené účty Nextcloud pro tohoto agenta.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Tím se odebere nastavení Trello a připojené účty pro tohoto agenta.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'To vyžaduje ověřenou relaci na stejném serveru NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Tento běh nevyvolal odezvu vůči uživateli.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Tento běh nemá žádné zaznamenané údaje o krocích.';

  @override
  String get thisServer => 'tento server.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Tento server nehlásí žádná nastavení poskytovatele.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Tato dovednost již není nainstalována.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Tato úloha ještě nemá dokončený běh, takže stále začíná v ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Tato úloha se spustí pouze po stisknutí tlačítka Spustit nyní.';

  @override
  String get thisWeek => 'Tento týden';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Tím se importuje odpověď do $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Tím se odstraní \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Tím se odstraní \"$arg1\" ze seznamu serverů.';
  }

  @override
  String get time => 'Čas';

  @override
  String get timeZone => 'časové pásmo';

  @override
  String get timeZone2 => 'Časové pásmo';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Vypršel časový limit$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Nelze vypsat časová pásma: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Nelze přečíst časové pásmo zařízení: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Nelze uložit časové pásmo zařízení: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'až $arg1';
  }

  @override
  String get toUseTheServerDefault => 'použít výchozí server.';

  @override
  String get today => 'dnes';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Tokenový rozpočet pro @$arg1. Ponechte pole prázdné ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Tokenový rozpočet pro každý účet bez vlastního přepsání. Nechte a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'limit rozpočtu tokenu 4hodinová týdenní kvóta uživatele';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'token budget limit 4hodinová týdenní kvóta globální';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Použití tokenu není na této verzi serveru k dispozici.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokeny může jakýkoli účet použít do 4 hodin.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokeny může použít jakýkoli účet do 7 dnů.';

  @override
  String get tokensPerDay => 'Tokeny za den';

  @override
  String get tokensPerRun => 'Tokeny za běh';

  @override
  String get tokensToday => 'Tokeny dnes';

  @override
  String get tokensUsed => ' použité tokeny';

  @override
  String get tomorrowPrep => 'Zítřejší příprava';

  @override
  String get tooManyAttempts => 'příliš mnoho pokusů';

  @override
  String get tooManySignInAttemptsPlease =>
      'Příliš mnoho pokusů o přihlášení. Počkejte prosím a zkuste to znovu.';

  @override
  String get tool => 'Nástroj';

  @override
  String get toolApproval => 'Schválení nástroje';

  @override
  String get toolApprovalRequired => 'Vyžaduje se schválení nástroje';

  @override
  String get toolCompleted => 'Nástroj dokončen';

  @override
  String get toolFailed => 'Nástroj selhal';

  @override
  String get toolPermissions => 'Oprávnění nástroje';

  @override
  String get toolStarted => 'Nástroj spuštěn';

  @override
  String get tools => 'Nástroje';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Nástroje, které nejsou zabudovány do NeoAgent, včetně připojených serverů MCP a poskytovatelů vlastních nástrojů.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Nabízené nástroje ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Nástroje, které může spravovaný účet používat';

  @override
  String get topUsers => 'Nejlepší uživatelé';

  @override
  String get topUsersAndRecentRuns => 'Nejlepší uživatelé a poslední spuštění';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Celkem: tokeny $arg1 napříč běhy $arg2';
  }

  @override
  String get totalRuns => 'Celkový počet běhů';

  @override
  String get totalTokens => 'Celkový počet tokenů';

  @override
  String get totalUsers => 'Celkový počet uživatelů';

  @override
  String get transcript => 'Přepis';

  @override
  String get transcript2 => 'PŘEPIS';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Přepis se nezdařil: $arg1';
  }

  @override
  String get transfer => 'Přenést';

  @override
  String get trelloApiKey => 'Klíč API Trello';

  @override
  String get trelloApiKeyIsRequired => 'Je vyžadován klíč rozhraní API Trello.';

  @override
  String get trelloSetup => 'Nastavení Trello';

  @override
  String get triggerType => 'Typ spouště';

  @override
  String get tryABroaderSearchLikeModels =>
      'Zkuste širší vyhledávání, jako jsou modely, prohlížeč nebo hlas.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Zkuste název poskytovatele, „e-mail“, „limity“, „aktualizace“ nebo „protokoly“.';

  @override
  String get tryAgain => 'Zkuste to znovu';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Zkuste to znovu. Pokud se to bude opakovat, spusťte NeoAgent Doctor a zkontrolujte běhové prostředí počítače.';

  @override
  String get tryAgainInAMoment => 'Zkuste to znovu za chvíli.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Zkuste to znovu nebo spusťte NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Zkuste další vyhledávání, připojte platformu pro zasílání zpráv nebo zadejte ID cíle ručně.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Zapněte skupinu, pokud má $arg1 číst také zprávy, které ji neoznačují.';
  }

  @override
  String get turnOffComputer => 'Vypněte počítač';

  @override
  String get turnOffOnlyForAMail =>
      'Vypnout pouze pro poštovní server s certifikátem podepsaným svým držitelem.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Zapněte, pokud má Signál nadále hledat příchozí chaty.';

  @override
  String get turnTaking => 'odbočit brát';

  @override
  String get turnTakingModel => 'Otočný model';

  @override
  String get turnTakingOff => 'Vypnutí-vypnutí';

  @override
  String get turnThisOffToKeepThis =>
      'Vypněte toto, aby byl tento agent zcela oddělený od ostatních agentů.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Vypnuto $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Vypnuto $arg1, který spravuje tento účet. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Vypnul pro vás $arg1 – změnit to mohou pouze oni';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Vypnuté pro vás, takže to nemůžete rozdávat';

  @override
  String get twitchChatOverIrc => 'Twitch chat přes IRC';

  @override
  String get twoFactorAuthentication => 'Dvoufaktorová autentizace';

  @override
  String get twoFactorChallengeExpired => 'dvoufaktorová výzva vypršela';

  @override
  String get twoFactorCode => 'dvoufaktorový kód';

  @override
  String get twoFactorSignInCompletedBut =>
      'Dvoufaktorové přihlášení bylo dokončeno, ale NeoAgent nemohl udržet relaci prohlížeče. Přihlaste se prosím znovu.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Dvoufázové přihlášení (pouze pokud je povoleno)';

  @override
  String get type => 'Typ';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Potvrďte zadáním $arg1';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'typ textu není na této platformě podporován.';

  @override
  String get typedInTheBrowser => 'Napsáno v prohlížeči';

  @override
  String get typedText => 'Napsaný text';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime => 'nelze najít běhové prostředí Java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'U této sestavy nelze otevřít nastavení času.';

  @override
  String get unableToOpenWiFiSettings =>
      'Na této sestavě nelze otevřít nastavení Wi-Fi.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Nelze zachovat zobrazení vybrané plochy.';

  @override
  String get unclearWhoItWasFor => 'Není jasné, pro koho to bylo';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'nedokončeno. Potvrďte zadáním svého uživatelského jména.';

  @override
  String get unknownAccount => 'Neznámý účet';

  @override
  String get unknownAgent => 'Neznámý agent';

  @override
  String get unknownBrowser => 'Neznámý prohlížeč';

  @override
  String get unknownDevice => 'Neznámé zařízení';

  @override
  String get unknownError => 'neznámá chyba';

  @override
  String get unknownLocalComputerPermission =>
      'Neznámé oprávnění místního počítače.';

  @override
  String get unknownLocation => 'Neznámá poloha';

  @override
  String get unknownPublishTime => 'Neznámý čas zveřejnění';

  @override
  String get unknownSize => 'Neznámá velikost';

  @override
  String get unlink => 'Odpojit';

  @override
  String get unreadOnly => 'Pouze nepřečtené';

  @override
  String get unsavedChanges => 'Neuložené změny';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Nepodporovaný doprovodný příkaz na ploše: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Nepodporovaná metoda: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Neobvyklá upozornění na přihlášení';

  @override
  String updateArg1(Object? arg1) {
    return 'Aktualizujte $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Aktualizujte položky základní paměti z importu.';

  @override
  String get updateNow => 'Aktualizujte nyní';

  @override
  String get updateReady => 'Aktualizace připravena';

  @override
  String get updateSetup => 'Nastavení aktualizace';

  @override
  String get updateTheAccessListToAllow =>
      'Aktualizujte přístupový seznam, abyste povolili odpovědi.';

  @override
  String get updateTheServer => 'Aktualizovat server?';

  @override
  String get updateTheServer2 => 'Aktualizujte server';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Aktualizujte časové pásmo automaticky ze zařízení, které používáte.';

  @override
  String updatedArg1(Object? arg1) {
    return 'aktualizováno $arg1';
  }

  @override
  String get updates => 'Aktualizace';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Pro toto sestavení nejsou nakonfigurovány aktualizace.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'aktualizace, takže zde jsou automatické aktualizace a změny kanálu vypnuté.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'aktualizace upgradu nyní vydává stabilní beta verzi kanálu';

  @override
  String get usageAnalytics => 'Analytika použití';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Signály využití a stavu, které pomáhají vysvětlit aktuální běhové chování, aniž byste se museli nejprve prohrabávat protokoly.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Využití se plně resetuje v $arg1';
  }

  @override
  String get usageLeaderboard => 'žebříček použití';

  @override
  String get usageLimits => 'Použití a limity';

  @override
  String get usageLimits2 => 'Použití a limity';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Použijte 8+ znaků. Delší přístupové fráze fungují dobře.';

  @override
  String get useADateAndTimeFor =>
      'Použijte datum a čas, například 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Použijte jméno, telefonní číslo nebo ID chatu.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Použijte adresu URL NeoRecall, na kterou server NeoAgent dosáhne. Adresa PUBLIC_URL společnosti NeoAgent musí být také dostupná z tohoto prohlížeče pro zpětné volání OAuth.';

  @override
  String get useANewPasswordWithAt => 'Použijte nové heslo s alespoň 8 znaky.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Použijte adresu URL Nextcloud, na kterou může server NeoAgent dosáhnout, například https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast => 'Použijte heslo s alespoň 8 znaky.';

  @override
  String get useASecureConnectionTls => 'Použít zabezpečené připojení (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Použijte ověřovací aplikaci, jako je Authy, 1Password nebo Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Použijte alespoň 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Maximální paměť na počítač (MB)';

  @override
  String get maxVcpusPerComputer => 'Maximální počet vCPU na počítač';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Alespoň $arg1. Počítače dostávají méně, když je hostitel zaneprázdněn.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Maximální velikost paměti musí být alespoň $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Použijte alespoň 8 znaků.';

  @override
  String get useDefault => 'Použít výchozí';

  @override
  String get useDefaultChannel => 'Použít výchozí kanál';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Použít výchozí (NeoAgent Workspace)';

  @override
  String get useFor => 'Použijte pro';

  @override
  String get useManualDestination => 'Použijte ruční cíl';

  @override
  String get useOrDoTheSameFor =>
      'použijte nebo udělejte totéž pro své spoluhráče.';

  @override
  String get usePerCategorySettingsBelow =>
      'Použijte níže uvedená nastavení pro jednotlivé kategorie.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Použít výchozí nastavení ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Použijte server na tomto počítači';

  @override
  String get useTheseForContextIfA =>
      'Použijte je pro kontext. Pokud místní identifikátor URI není přímo přístupný ze serveru, požádejte mě o poskytnutí souboru prostřednictvím přístupného pracovního prostoru.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Použijte to pro agenty orchestrátoru. Ponechte vypnutou pro izolované pracovní roboty, kteří by měli dokončit přímé zprávy sami.';

  @override
  String get useTlsFromTheStartOf =>
      'Používejte TLS od začátku připojení, obvykle na portu 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Použijte svůj vlastní klíč API pro poskytovatele nebo připojte vlastní ';

  @override
  String get usedByEveryAccountOnThis =>
      'Používá každý účet na tomto serveru, který nemá žádný klíč ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Používá se k ověření, že příchozí události Slack jsou pravé.';

  @override
  String get userSummary => 'Uživatelské shrnutí';

  @override
  String get username => 'Uživatelské jméno';

  @override
  String get usernameOrEmail => 'Uživatelské jméno nebo email';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'uživatelé lidé vyhledávají e-mail uživatelské jméno odznak správce spravovaný tým';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Používá model chatu nakonfigurovaný v Nastavení';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Pomocí nainstalovaného běhového prostředí NeoAgent';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Obvykle vypadá jako @bot:matrix.org';

  @override
  String get validEmail => 'platný email';

  @override
  String get value => 'Hodnota';

  @override
  String get vaultLocked => 'Trezor zamčený';

  @override
  String get vaultOperationFailed => 'Operace trezoru se nezdařila.';

  @override
  String get verification => 'Ověření';

  @override
  String verificationArg1(Object? arg1) {
    return 'Ověření: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'ověření: $arg1';
  }

  @override
  String get verificationCompleted => 'Ověření dokončeno.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Stav ověření: $arg1';
  }

  @override
  String get verifiedTheResult => 'Ověřeno výsledek';

  @override
  String get verifyingTheDownloadedRuntime => 'Ověření staženého runtime';

  @override
  String get versionAndUptime => 'Verze a doba provozu';

  @override
  String versionArg1(Object? arg1) {
    return 'Verze $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Verze $arg1 je nainstalována, ale $arg2 stále běží.';
  }

  @override
  String get videoLinks => 'Odkazy na videa';

  @override
  String get viewDesktop => 'Zobrazit plochu';

  @override
  String get viewLastRun => 'Zobrazit poslední spuštění';

  @override
  String get viewLogs => 'Zobrazit protokoly';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm obrazová paměť cpu qemu runtime';

  @override
  String get voice => 'Hlas';

  @override
  String get voiceAssistant => 'Hlasový asistent';

  @override
  String get voiceCall => 'HLASOVÉ VOLÁNÍ';

  @override
  String get voiceCall2 => 'Hlasový hovor';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'hlasový hovor gpt-live gemini živý model řeči v reálném čase';

  @override
  String get voiceCallsRunOnALive =>
      'Hlasové hovory běží na živém modelu řeči na řeč se stejnou osobností, pamětí a historií chatu jako NeoAgent. Okamžitě odpoví a předá skutečnou práci normálnímu agentovi, který běží na pozadí.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'hlasová poznámka přepis řeči api klíč';

  @override
  String get voiceNotesAndDictation => 'Hlasové poznámky a diktáty';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Přehrávání hlasu není na tomto zařízení k dispozici.';

  @override
  String get voiceReplyModel => 'Model hlasové odpovědi';

  @override
  String get waitingForApproval => 'Čekání na schválení: ';

  @override
  String get waitingForCode => 'Čekání na kód';

  @override
  String get waitingForInput => 'Čekání na vstup';

  @override
  String get waitingForServerOrFlutterLog =>
      'Čekání na výstup protokolu serveru nebo Flutter…';

  @override
  String get waitingForTaskEvents => 'Čekání na události úkolu...';

  @override
  String get waitingForYou => 'čeká na tebe';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Chtěl jsem odpověď od $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Chce s vámi mluvit · ${arg1}s';
  }

  @override
  String get weak => 'slabý';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Počasí, kalendář a priority před začátkem vašeho dne.';

  @override
  String get weatherEvent => 'Počasí Událost';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'webový prohlížeč';

  @override
  String get webSearchApiKey => 'klíč API pro vyhledávání na webu';

  @override
  String get webhookOrRestChannelPosting =>
      'Zveřejňování prostřednictvím webhooku nebo kanálu REST';

  @override
  String get webhookSecret => 'Tajemství webhooku';

  @override
  String get webhookUrlCopied => 'Adresa URL webhooku byla zkopírována';

  @override
  String get weekdays => 'všední dny';

  @override
  String get weekdays0730 => 'Pracovní dny · 07:30';

  @override
  String get weekdays1800 => 'Ve všední dny · 18:00';

  @override
  String get weekly => 'Týdenní';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Týdenní limit $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Týdenní limit (tokeny)';

  @override
  String get weeklyReview => 'Týdenní přehled';

  @override
  String get weeklyUsage => 'Týdenní použití';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Hmotnost záznamů $arg1';
  }

  @override
  String get welcomeToNeoagent => 'VÍTEJTE V NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Vítejte v\nNeoAgent';

  @override
  String get whatAreYouAdding => 'co přidáváš?';

  @override
  String get whatIsOnTomorrow => 'co bude zítra?';

  @override
  String get whatShouldNeoagentLearn => 'Co by se měl NeoAgent naučit?';

  @override
  String get whatShouldWeBuild => 'Co bychom měli stavět?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'To, co vy a NeoAgent řeknete, se objeví zde a v chatu.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Osobní zpráva WhatsApp přijata';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Pokud zvolíte možnost Pouze schválené, přidejte níže lidi nebo skupiny.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Kam má tento agent zasílat odpovědi.';

  @override
  String get whoCanMessage => 'Kdo může poslat zprávu';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Kdo může posílat zprávy na $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Kdo může odeslat $arg1 zprávu jedna ku jedné.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Kdo může mluvit se $arg1 ve skupině, kanálu nebo místnosti.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'kdo spravuje tento účet vypnut: ';

  @override
  String get whoManagesWhom => 'Kdo koho řídí';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Každý, kdo přijme odkaz, se připojí k vašemu týmu pouze s nástroji, které jsou k dispozici ';

  @override
  String get wholeGroup => 'Celá skupina';

  @override
  String get wholeGroups => 'Celé skupiny';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Proč $arg1 odpověděl nebo zůstal potichu ve skupinách $arg2.';
  }

  @override
  String get windowsApp => 'aplikace pro Windows';

  @override
  String get windowsNt => 'okna nt';

  @override
  String get workAccount => 'Pracovní účet';

  @override
  String get workOnAProjectWithNeoagent => 'Pracujte na projektu s NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Pracovní postup: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Práce v $arg1 na cloudovém počítači. NeoAgent tam čte a upravuje soubory a může spouštět příkazy a prohlížeč.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Práce na pozadí: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Konfigurace pracovního prostoru a zabezpečení účtu na jednom místě.';

  @override
  String get workspaceFiles => 'Soubory pracovního prostoru';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Ovládací prvky pracovního prostoru, modelů a diagnostiky.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Přepsání pracovního prostoru musí být absolutní cesta.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Napsal $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttprequest chyba';

  @override
  String get yesterday => 'včera';

  @override
  String get youAreInControl => 'Máte to pod kontrolou';

  @override
  String get youCanFollowAlongOnThe => 'Můžete sledovat na ploše.';

  @override
  String get youCanLeaveATeamAt =>
      'Tým můžete kdykoli opustit; znovu platí vaše vlastní nastavení.';

  @override
  String get youCanLeaveAtAnyTime => 'Ze stránky Tým můžete kdykoli odejít.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'O tom, které nástroje může váš agent používat, rozhodujete v části Nastavení › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Zatím nikoho neřídíte. Níže vytvořte odkaz na pozvánku a ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Máte neuložená nastavení. co bys chtěl dělat?';

  @override
  String get youReOnYourOwnYou =>
      'Jste na to sami: rozhodujete, které nástroje může váš agent používat. Pokud ';

  @override
  String get yourAccountAndUsageOnA =>
      'váš účet – a použití na modelu podporovaném vaším vlastním klíčem ';

  @override
  String get yourAccountHasBeenDeleted => 'Váš účet byl smazán.';

  @override
  String get yourAgentWillBeAllowed => 'Váš agent bude mít povoleno:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Vaše aplikace a soubory jsou uloženy.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Vaše aplikace a soubory zůstanou uloženy.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Váš klíč $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Vrstva vašeho asistenta pro zachycení, kontext a akci.';

  @override
  String get yourComputerIsAsleep => 'Váš počítač spí';

  @override
  String get yourComputerIsOff => 'Váš počítač je vypnutý';

  @override
  String get yourComputerIsReady => 'Váš počítač je připraven';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Vaše aktuální heslo je nesprávné.';

  @override
  String get yourData => 'Vaše data';

  @override
  String get yourDataExportWasCopiedTo =>
      'Váš export dat byl zkopírován do schránky.';

  @override
  String get yourDesktopIsReady => 'Vaše pracovní plocha je připravena';

  @override
  String get yourLinuxComputer => 'Váš počítač se systémem Linux';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Vaše poloha není nikdy nepřetržitě sledována ani uložena na našich serverech. Používáme jej pouze lokálně ke kontrole vašich aktivních úkolů.';

  @override
  String get yourManager => 'váš manažer';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'URL vašeho webu Mattermost, pokud používáte REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Vaše relace vypršela nebo ji prohlížeč neuchoval. Přihlaste se prosím znovu.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Vaše relace vypršela. Přihlaste se prosím znovu.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Vaše uživatelské jméno nebo heslo je nesprávné.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'OTP YubiKey';

  @override
  String get zaloPersonal => 'Zalo Osobní';

  @override
  String get sectionOverview => 'Přehled';

  @override
  String get sectionDiagnostics => 'Diagnostika';

  @override
  String get sectionVolume => 'Hlasitost';

  @override
  String get sectionSession => 'Relace';

  @override
  String get sectionDeliverable => 'Doručitelné';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Místní běhové prostředí ještě nezapsalo soubor protokolu.';

  @override
  String get thisComputer => 'Tento počítač';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta nainstaluje nejnovější backend předběžné verze. Očekávejte hrubé hrany.';

  @override
  String get copiedFinalResponse => 'Zkopírována konečná odpověď';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Po dokončení běhu se zde objeví konečná odpověď.';

  @override
  String get waitingForTheFirstStep => 'Čekání na první krok…';

  @override
  String get loadingPrompt => 'Načítání výzvy…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Pro tento běh nebyla zaznamenána žádná konečná odpověď.';

  @override
  String get readyToSignIn => 'Připraveno k přihlášení';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Chcete-li znovu povolit kontroly schválení, přepněte na „Výchozí“ nebo „Vždy se ptát“.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Odeslat aktualizaci řízení nebo další poznámku pro aktuální běh...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Žádné síťové připojení. NeoAgent se znovu připojí, jakmile bude zařízení opět online.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Na aktuální jízdu byla použita nejnovější aktualizace řízení.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Příprava soukromé hlasové relace…';

  @override
  String get preparingYourComputer => 'Příprava počítače';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent stahuje a připravuje bezpečný systém Linux. To se děje pouze poprvé.';

  @override
  String get moreFreeSpaceIsNeeded => 'Je potřeba více volného místa';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Uvolněte místo na disku na hostiteli NeoAgent a zkuste to znovu. Vaše stávající počítačová data jsou v bezpečí.';

  @override
  String get androidReady => 'Android připraven';

  @override
  String get startingAndroid2 => 'Spouštění Androidu…';

  @override
  String get androidStopped => 'Android se zastavil';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'První spuštění stáhne Android SDK a bitovou kopii systému, což může trvat několik minut.';

  @override
  String get androidIsStopped => 'Android je zastaven';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Spusťte spravované prostředí Android, když ho potřebujete.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Nechte NeoAgent pracovat na tomto počítači';

  @override
  String get firstTimeSetupIsInProgress => 'Probíhá první nastavení.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent může použít přístup, který povolíte.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Uvolněte úložiště hostitele a zkuste to znovu.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Začněte, když chcete, aby vám NeoAgent pomohl zde.';

  @override
  String get systemPermissionMissing => 'Chybí systémové oprávnění';

  @override
  String get connectingThisDevice => 'Připojení tohoto zařízení';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Probíhá vytváření zabezpečeného místního připojení.';

  @override
  String get recordingYourDemonstration => 'Nahrávání vaší demonstrace';

  @override
  String get noErrorsInTheRecentLog =>
      'V nedávném protokolu nejsou žádné chyby.';

  @override
  String get loadingAccounts => 'Načítání účtů…';

  @override
  String get neverSignedIn => 'Nikdy se nepřihlásil';

  @override
  String get emptyUsesTheServerDefault =>
      'Prázdné používá výchozí nastavení serveru.';

  @override
  String get followTheSelectedSession => 'Sledujte vybranou relaci';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Režim plánu pouze kontroluje. Přepněte do režimu Agent, aby NeoAgent mohl upravovat soubory.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Vyžaduje se přidání nebo změna e-mailu vašeho účtu.';

  @override
  String get confirmNewPassword => 'Potvrďte nové heslo';

  @override
  String get passwordChanged => 'Heslo změněno.';

  @override
  String get thisRequestHasAlreadyBeenUsed => 'Tento požadavek již byl použit.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Platnost této žádosti vypršela. Požádejte druhé zařízení, aby vygenerovalo nový kód.';

  @override
  String get startQuickstart => 'Spusťte rychlý start';

  @override
  String get createYourAccount => 'Vytvořte si účet';

  @override
  String get showWorkAsSummaries => 'Zobrazit práci jako souhrny';

  @override
  String get tokensUsedByTheLatestRun =>
      'Tokeny použité při posledním spuštění';

  @override
  String get listedTheWorkspaceRoot => 'Vypsal kořen pracovního prostoru';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Zatím nejsou k dispozici žádné oficiální integrace.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Zatím nejsou nakonfigurovány žádné servery MCP. Přidejte jeden, abyste odhalili jeho nástroje.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Chcete-li začít, přidejte server MCP nebo nainstalujte dovednost.';

  @override
  String get setUp => 'Nastavit';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Chcete-li zachovat uloženou hodnotu, ponechte prázdné';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Tím se odebere adresa pro každý účet na tomto serveru.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Jen mluv. Přerušit můžete kdykoli. Klepnutím ztlumíte.';

  @override
  String get tapAgainWhenYouAreDone => 'Až budete hotovi, klepněte znovu.';

  @override
  String get workingOnATaskInTheBackground => 'Práce na úkolu na pozadí.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Převod řeči na řeč se stejnou pamětí, nástroji a historií chatu jako NeoAgent.';

  @override
  String get checkLink => 'Zkontrolujte odkaz';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Váš agent nebude mít povolen žádný z kontrolovaných nástrojů.';

  @override
  String get notYoursToChange => 'Není tvoje, aby ses změnil';

  @override
  String get setByYou => 'Nastaveno vámi';

  @override
  String get noTools => 'Žádné nástroje';

  @override
  String get untitledLink => 'Odkaz bez názvu';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Přestane fungovat poté, co je uplatní jedna osoba.';

  @override
  String get theOperator => 'Operátor';

  @override
  String get smartSelectorOn => 'Inteligentní volič zapnutý';

  @override
  String get startASessionToBegin => 'Začněte zahájením relace';

  @override
  String get steerTheActiveRun => 'Řídit aktivní běh…';

  @override
  String get describeWhatToPlan => 'Popište, co plánovat…';

  @override
  String get stopDictation => 'Přestaňte diktovat';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Zprávy řídí aktuální běh · ⌘↵ odeslat · ⌘. zastavit';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Režim plánu pouze kontroluje; nic se nezmění, dokud neimplementujete · ⌘↵ odeslat';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agent upraví pracovní prostor. Plán pouze kontroluje.';

  @override
  String get defaultModel => 'Výchozí model';

  @override
  String get openingScanner => 'Otevírání skeneru...';

  @override
  String get theAgentCanUseThisSkill => 'Agent může tuto dovednost využít.';

  @override
  String get allSelected => 'Všechny vybrané';

  @override
  String get addCoreMemoryEntry => 'Přidat položku Core Memory Entry';

  @override
  String get channelId => 'ID kanálu';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Úlohy vytvořené AI a nespecifikované úlohy používají aktuální výchozí nastavení.';

  @override
  String get waitingForRunEvents => 'Čekání na spuštěné události...';

  @override
  String get hideSteps => 'Skrýt kroky';

  @override
  String get commitTheActiveLiveCapture => 'Potvrdit aktivní živé zachycení';

  @override
  String get stopCaptureAndSubmit => 'Zastavte zachycení a odešlete';

  @override
  String get clickTheMicToStartSpeaking =>
      'Klepnutím na mikrofon začněte mluvit';

  @override
  String get connectACustomEndpoint => 'Připojte vlastní koncový bod';

  @override
  String get hostedProvider => 'hostovaný poskytovatel.';

  @override
  String get muted => ' • ztlumený';

  @override
  String get addWhoCanMessage => 'Přidejte zprávu, kdo může';

  @override
  String get joinsGroupConversations =>
      'Připojuje se ke skupinovým konverzacím';

  @override
  String get label1PersonOrGroupAdded => 'Byla přidána 1 osoba nebo skupina';

  @override
  String get inProgress => 'Probíhá';

  @override
  String get waitingForUpdateJobOutput => 'Čekání na výstup úlohy aktualizace…';

  @override
  String get taskTrigger => 'Spouštěč úkolu';

  @override
  String get bearerToken => 'Token na doručitele';

  @override
  String get bearerToken2 => 'Token na doručitele';

  @override
  String get notRecorded => 'Nezaznamenáno';

  @override
  String get sessionCookie => 'Soubor cookie relace';

  @override
  String get neverUsed => 'Nikdy nepoužitý';

  @override
  String get linkedRecently => 'Nedávno propojeno';

  @override
  String get notUsedYet => 'Zatím nepoužité';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Platnost jednoho nebo více účtů vypršela. Chcete-li obnovit přístup, znovu se připojte. Pokud se to bude opakovat, vaše aplikace Google Cloud OAuth může být v testovacím režimu – publikujte ji do produkce v Google Cloud Console, abyste získali tokeny s dlouhou životností.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Trezor je připojen a dostupný po restartu';

  @override
  String get vaultConnectedForThisSession =>
      'Vault je pro tuto relaci připojen';

  @override
  String get connectAnotherAccount => 'Připojit jiný účet';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Vložte náhradní Long-Lived Access Token';

  @override
  String get updateInstance => 'Aktualizovat instanci';

  @override
  String get pasteAReplacementToken => 'Vložte náhradní token';

  @override
  String get replaceAccount => 'Nahradit účet';

  @override
  String get addAccount => 'Přidat účet';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Může delegovat na jakéhokoli přijímajícího agenta';

  @override
  String get canReceiveDelegatedTasks2 => 'může přijímat delegované úkoly';

  @override
  String get noSyncYet => 'Zatím žádná synchronizace';

  @override
  String get noNewData => 'Žádná nová data';

  @override
  String get syncOnceToSeedYourBackend =>
      'Jednou synchronizujte, abyste vytvořili backend.';

  @override
  String get lastWindowEndIsUnknown => 'Poslední konec okna není znám.';

  @override
  String get lastNonEmptySync => 'Poslední synchronizace bez vyprázdnění';

  @override
  String get stopTranscribe => 'Zastavit a přepsat';

  @override
  String get steeringMode => 'Režim řízení';

  @override
  String get noMessageText => 'Žádný text zprávy';

  @override
  String get reconnectingToServer => 'Opětovné připojení k serveru…';

  @override
  String get signingIn => 'Přihlašování...';

  @override
  String get noGroupsFoundYet => 'Dosud nebyly nalezeny žádné skupiny';

  @override
  String get onForNewGroupsOnly => 'Zapnuto pouze pro nové skupiny';

  @override
  String get noGroupsInThisCategory => 'V této kategorii nejsou žádné skupiny';

  @override
  String get groupOrChannel => 'Skupina nebo kanál';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Poznámky, které si napíšete, začnou běhat a odpovědi přistanou ve stejném chatu. Seznam povolených zde neplatí.';

  @override
  String get needToReply => 'Je potřeba odpovědět';

  @override
  String get enter2faCode => 'Zadejte kód 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Otevřete aplikaci pro ověřování a zadejte aktuální kód NeoAgent.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Už máte účet? Přihlaste se';

  @override
  String get serverOnThisComputer => 'Server na tomto počítači';

  @override
  String get showQrCode => 'Zobrazit QR kód';

  @override
  String get createAnotherNeoagentAccount => 'Vytvořte další účet NeoAgent.';

  @override
  String get canCoordinateDelegatedWork =>
      'Dokáže koordinovat delegovanou práci';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Runtime archiv NeoAgent nelze extrahovat.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Runtime archiv NeoAgent nelze přečíst.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Runtime archiv NeoAgent obsahuje nebezpečnou cestu.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Runtime archiv NeoAgent obsahuje nebezpečný odkaz.';

  @override
  String get installingAppPackageOnThePhone =>
      'Instalace balíčku aplikace do telefonu...';

  @override
  String get dragAndDropAApkOrApks =>
      'Přetáhněte sem soubor .apk nebo .apks nebo kliknutím procházejte.';

  @override
  String get releaseToInstallThisPackage =>
      'Chcete-li nainstalovat tento balíček, uvolněte';

  @override
  String get theSecurityKeyCouldNotBeUsed => 'Bezpečnostní klíč nelze použít.';

  @override
  String get connecting => 'Připojování…';

  @override
  String get changes => 'Změny';

  @override
  String get runtimeReady => 'Runtime připraveno';

  @override
  String get saving => 'Ukládání...';

  @override
  String get earlier => 'Dříve';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'února';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'dubna';

  @override
  String get monthMay => 'května';

  @override
  String get monthJun => 'června';

  @override
  String get monthJul => 'července';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'září';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'listopad';

  @override
  String get monthDec => 'prosinec';

  @override
  String get steeringWord => 'Řízení';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Toto přepne backend z kanálu $arg1 na kanál $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Byly importovány soubory cookie $arg1';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'Před ${arg1}s';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Řízení ve frontě: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Webové aplikaci se nepodařilo dosáhnout backendu NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Prohlížeč zablokoval požadovaný požadavek kvůli zásadám zabezpečení obsahu.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 ze 4 povolených';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Proveďte úkol jako obvykle.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Změny · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Toto zařízení · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limit dosažen$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Obnovovací kódy $arg1 jsou stále k dispozici.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Bezpečnostní klíč $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Aktuální relace';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nNaposledy použité: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Práce v $arg1 na tomto zařízení. NeoAgent čte a upravuje složku přímo a může spouštět příkazy, otevírat aplikace a používat obrazovku.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Pracoval pro $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Povoleno $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Odkazy na pozvánky $arg1 ze $arg2 byly zrušeny';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Přidejte lidi a skupiny, se kterými má $arg1 mluvit';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Přidejte lidi a skupiny, se kterými může $arg1 mluvit.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Kde $arg1 poslouchá';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 sleduje tato místa kvůli zmínkám. Kdokoli sem může přispívat, takže lidé stále potřebují svůj vlastní souhlas níže.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Tito lidé se mohou zeptat $arg1, kdekoli jej označí. Role se počítají pouze na výše uvedených místech.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Pouze když je označeno $arg1';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Zapnuto pro všechny skupiny $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 stále slyší pouze osoby a skupiny, které jste již schválili. To jen umožňuje $arg1 připojit se k běžnému chatu, nejen k tagům a odpovědím.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 stále slyší pouze osoby a skupiny, které jste již schválili. Tím se pouze vybere, ke které z těchto skupin se má připojit.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Pokud někdo označí $arg1 nebo odpoví, $arg1 vždy odpoví. Toto zapněte, pokud by se měl $arg1 také připojit k běžnému skupinovému chatu.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Nové skupiny umožní $arg1 připojit se k běžnému chatu se schválenými lidmi, dokud je nevypnete.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Nové skupiny umožní $arg1 připojit se k běžnému chatu, dokud je nevypnete.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Nové skupiny zůstanou tiché, pokud schválená osoba neoznačí $arg1, dokud je nezapnete.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Pouze když schválená osoba označí $arg1, pokud nezapnete skupinu';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Pouze když je označeno $arg1, pokud nezapnete skupinu';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 skupin $arg2 se připojí k běžnému chatu se schválenými lidmi';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Toto neschvaluje nové lidi. Na štítky a odpovědi od schválených lidí vždy dostanete odpověď. Zapněte skupinu, pokud se tam má $arg1 připojit také k běžnému chatu.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Toto neschvaluje nové lidi. Zapněte skupinu, pokud se má $arg1 připojit k běžnému chatu s lidmi, které jste již schválili.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Značky a odpovědi vždy dostanou odpověď. Zapněte skupinu, pokud se tam má $arg1 připojit také k běžnému chatu.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 se připojí k běžnému chatu se schválenými lidmi';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 se může připojit k běžnému chatu';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 odpovídá pouze tehdy, když jej označí schválená osoba';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Není potřeba nic navíc. Připojte se a začněte používat $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Obnovuje se v ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Zaregistrujte se u $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Žádné paměti spojené s \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (výchozí)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Větev: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 se připojí pouze ke skupinám a kanálům, které přidáte níže.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return 'K vyhledání runtime dat NeoAgent je vyžadován $arg1.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[zkrácený náhled, celkem $arg1 bajtů]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefakt ohraničený, celkem $arg1 bajtů]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' v $arg1';
  }

  @override
  String get worldNews => 'Světové zprávy';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Spusťte, když se objeví nové světové titulky. Vaše výzva rozhodne, zda vás upozorní.';

  @override
  String get newsKeywordsOptional => 'Klíčová slova (volitelné)';

  @override
  String get worldNewsSetup => 'Nastavení World News';

  @override
  String get connectWorldNewsWithGnews =>
      'Přidejte klíč GNews API (bezplatný plán dostupný na gnews.io). Je uložen zašifrován a používá se k dotazování hlavních titulků na spouštěče světových zpráv.';

  @override
  String get gnewsApiKey => 'Klíč GNews API';

  @override
  String get pasteReplacementGnewsApiKey => 'Vložte náhradní klíč GNews API';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Chcete-li zachovat aktuálně uložený klíč, ponechte klíč prázdný.';

  @override
  String get gnewsApiKeyIsRequired => 'Je vyžadován klíč GNews API.';

  @override
  String get couldNotSaveWorldNewsSetup => 'Nastavení World News nelze uložit.';

  @override
  String get disconnectWorldNews => 'Odpojit World News';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Tím se odstraní uložený klíč GNews API. Spouštěče World News se přestanou spouštět, dokud znovu nepřidáte klíč.';

  @override
  String get couldNotDisconnectWorldNews => 'World News se nepodařilo odpojit.';

  @override
  String get systemOneModels => 'Modely SystemOne';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Vybírá nejlepší dostupný model SystemOne';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Tato rozhodnutí dělá model chatu';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Rozhodovací modely, které uskutečňují hovory ze zákulisí ve zlomku sekundy: změna skupinového chatu a kroky prohlížeče. Váš model chatu stále zapisuje každou odpověď.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Model SystemOne rozhodne, kdy hovořit, když je zapnutý; tento model je záložní.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 skóroval SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne tuto zprávu zaznamenal přímo. Žádný jazykový model neproběhl.';

  @override
  String get systemOneUnavailable => 'SystemOne není k dispozici';

  @override
  String get systemOneAdminAvailability =>
      'Agenti rozhodovacích modelů si mohou vybrat v části Nastavení › Modely. Zde vypnutý model opustí výběr a agenti, kteří si jej vybrali, přejdou zpět na Auto. Když je jakýkoli model vypnutý, modely SystemOne, které poskytovatelé přidají později, se také vypnou.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Zatím žádné modely SystemOne. Přidejte klíč TypeSafe nebo OpenRouter v části Poskytovatelé nebo vytáhněte rozhodovací model, jako je svižný v Ollama 0.35 nebo novější.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Zatím není k dispozici žádný model SystemOne. Přidejte klíč TypeSafe nebo OpenRouter v části Nastavení › Modely › Přineste si vlastní klíč nebo vytáhněte rozhodovací model, jako je hbitý v Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone system one decision models jev typesafe openrouter ollama dostupnost povolit zakázat';

  @override
  String get chatModels => 'Chatovací modely';

  @override
  String get disabled => 'Vypnuto';

  @override
  String get enableShown => 'Povolit zobrazeno';

  @override
  String get disableShown => 'Je zobrazeno Zakázat';

  @override
  String get expandAll => 'Rozbalit vše';

  @override
  String get collapseAll => 'Sbalit vše';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 neuložené změny';
  }

  @override
  String get settingsScopeAllAgents => 'Všichni agenti';

  @override
  String get settingsScopeAgent => 'Tento agent';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint => 'To samé všude, kde se přihlásíte';

  @override
  String get settingsScopeAllAgentsHint => 'Sdíleno všemi vašimi agenty';

  @override
  String get settingsAppliesTo => 'Platí pro';

  @override
  String get settingsSaving => 'Ukládání…';

  @override
  String get settingsSavedAutomatically => 'Změny se automaticky uloží';

  @override
  String get settingsSearchHint => 'Prohledejte všechna nastavení';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Přihlášení a zabezpečení';

  @override
  String get settingsPageUsage => 'Využití';

  @override
  String get settingsPagePermissions => 'Oprávnění';

  @override
  String get settingsPageComputer => 'Počítač a web';

  @override
  String get settingsPageBehavior => 'Chování';

  @override
  String get settingsPageSystem => 'Systém';

  @override
  String get settingsPagePlatforms => 'Platformy';

  @override
  String get settingsPageProfileDescription =>
      'Vaše jméno a e-mail, kopie vašich dat a odhlášení.';

  @override
  String get settingsPageSecurityDescription =>
      'Heslo, dvoufaktorové ověření, bezpečnostní klíče a místo, kde jste přihlášeni.';

  @override
  String get settingsPageUsageDescription =>
      'Vaše limity a tokeny, vše na jednom místě.';

  @override
  String get settingsPageAgentsDescription =>
      'Vytvořte agenty a vyberte si, který z nich ve výchozím nastavení odpovídá.';

  @override
  String get settingsPagePermissionsDescription =>
      'Co mohou vaši agenti dělat, aniž by se vás nejprve zeptali.';

  @override
  String get settingsPageComputerDescription =>
      'Počítač, na kterém vaši agenti pracují, a stránky, které mohou číst jako vy.';

  @override
  String get settingsPageModelsDescription =>
      'Které modely tento agent používá a klíče API, které za ně platí.';

  @override
  String get settingsPageBehaviorDescription =>
      'Jak tento agent mluví a jak čte skupinový chat.';

  @override
  String get settingsPageVoiceDescription =>
      'Živé hovory, diktování a mluvené odpovědi pro tohoto agenta.';

  @override
  String get settingsPageMessagingDescription =>
      'Kde mohou lidé tohoto agenta kontaktovat a jak se chová v chatech.';

  @override
  String get settingsPageGeneralDescription =>
      'Vzhled, jazyk, časové pásmo a co tato aplikace dělá na pozadí.';

  @override
  String get settingsPageSystemDescription =>
      'Server, který toto okno používá, server v tomto počítači a aktualizace aplikací.';

  @override
  String get settingsYourAgents => 'Vaši agenti';

  @override
  String get settingsChatModel => 'Model chatu';

  @override
  String get settingsChatModelDescription => 'Odpovídá na vaše zprávy.';

  @override
  String get settingsSubAgentModel => 'Model sub-agenta';

  @override
  String get settingsSubAgentModelDescription =>
      'Spustí práci předanou během úkolu.';

  @override
  String get settingsDefaultModels => 'Výchozí modely';

  @override
  String get settingsDefaultModelsDescription =>
      'Používá se vždy, když si chat nebo úkol nevybere svůj vlastní model.';

  @override
  String get settingsModelPool => 'Modelový bazén';

  @override
  String get settingsApiKeysDescription =>
      'Použijte pro tohoto agenta své vlastní klíče nebo koncový bod. Klíče jsou zašifrovány a už se nikdy nezobrazují.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Jemné doladění';

  @override
  String get settingsFineTuningDescription =>
      'Zřídka potřeba. Výchozí nastavení vyhovuje většině chatů.';

  @override
  String get settingsShow => 'Zobrazit';

  @override
  String get settingsHide => 'Skrýt';

  @override
  String get settingsMinimumContribution => 'Minimální hodnota příspěvku';

  @override
  String get settingsBatchWindow => 'Dávkové okno místnosti';

  @override
  String get settingsBatchWindowDescription =>
      'Čeká tak dlouho, aby bylo možné rychlé zprávy považovat za jedno kolo.';

  @override
  String get settingsHandsFree => 'Hands-free';

  @override
  String get settingsHandsFreeDescription => 'Mluvte volně a kdykoli přerušte.';

  @override
  String get settingsPushToTalkDescription =>
      'Podržením hovořit, uvolněním odeslat.';

  @override
  String get settingsLiveVoice => 'Živý hlas';

  @override
  String get settingsChannels => 'Kanály';

  @override
  String get settingsGroupChats => 'Ve skupinových chatech';

  @override
  String get settingsGroupChatsDescription =>
      'Jak se tento agent chová ve skupinách na každém kanálu.';

  @override
  String get settingsGroupChatsDisabled =>
      'Chcete-li je změnit, zapněte moduly chování v Chování.';

  @override
  String get settingsParticipationAutomatic => 'Automaticky';

  @override
  String get settingsParticipationMentionOnly => 'Pouze zmínit';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Přečte místnost a připojí se, když má něco užitečného přidat.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Odpovídá pouze na zmínku nebo odpověď.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Odpovědi na každou zprávu.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Rozdělí delší odpovědi na krátké zprávy, jak by to udělal člověk.';

  @override
  String get settingsDeliverySingleDescription =>
      'Odešle každou odpověď jako jednu zprávu.';

  @override
  String get settingsComputerStatus => 'Stav';

  @override
  String get settingsTest => 'Test';

  @override
  String get settingsAppearance => 'Vzhled';

  @override
  String get settingsTheme => 'téma';

  @override
  String get settingsThemeSystem => 'Systém';

  @override
  String get settingsThemeLight => 'Světlý';

  @override
  String get settingsThemeDark => 'Tmavý';

  @override
  String get settingsCloseWindow => 'Když zavřete okno';

  @override
  String get settingsCloseAsk => 'Zeptejte se';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent běží na pozadí a je dosažitelný.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent se úplně ukončí.';

  @override
  String get settingsPhoneTriggers => 'Telefonní spouště';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signály, které tento telefon posílá vašim agentům, aby na ně úkoly mohly reagovat.';

  @override
  String get settingsLocationTriggers => 'Spouštěče polohy';

  @override
  String get settingsLocationTriggersDescription =>
      'Kontroluje vaši přibližnou polohu každých pár minut oproti místům, které sledují vaše úkoly.';

  @override
  String get settingsNotificationTriggers => 'Spouštěče oznámení';

  @override
  String get settingsNotificationTriggersDescription =>
      'Přeposílá upozornění z jiných aplikací v tomto telefonu vašim agentům.';

  @override
  String get settingsSetup => 'Nastavení';

  @override
  String get settingsOnboarding => 'Registrace';

  @override
  String get settingsOnboardingDescription =>
      'Znovu projděte nastavením prvního spuštění. Nic, co jste nastavili, se neztratí.';

  @override
  String get settingsUsernameDescription =>
      'Slouží k přihlášení. Nelze změnit.';

  @override
  String get settingsExport => 'Exportovat';

  @override
  String get settingsLeave => 'Odhlaste se a smažte';

  @override
  String get settingsSignOutDescription =>
      'Odhlásí vás pouze na tomto zařízení.';

  @override
  String get settingsDeleteAccountDescription =>
      'Vymaže váš účet, agenty, paměť a nastavení. Toto nelze vrátit zpět.';

  @override
  String get settingsTokenUsage => 'Použití tokenu';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Žádné nastavení neodpovídá „$query“.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count výsledků',
      few: '$count výsledky',
      one: '$count výsledek',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Pokročilé nastavení modelu';

  @override
  String get settingsAdvancedModelsDescription =>
      'Volitelné. Připnout model k jednomu druhu práce; přebírá to vždy, když agent tyto nástroje použije. Vše, co zůstane ve výchozím nastavení, se řídí modelem chatu.';

  @override
  String get settingsTaskModelDefault => 'Výchozí';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Sleduje model chatu';

  @override
  String get settingsTaskModelCoding => 'Kódování';

  @override
  String get settingsTaskModelCodingDescription =>
      'Psaní, úprava a ladění kódu.';

  @override
  String get settingsTaskModelComputerUse => 'Používání počítače';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Ovládání prohlížeče a plochy.';

  @override
  String get settingsTaskModelAndroidUse => 'Použití Androidu';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Obsluha aplikací na zařízení nebo emulátoru Android.';

  @override
  String get settingsTaskModelResearch => 'Výzkum';

  @override
  String get settingsTaskModelResearchDescription =>
      'Vyhledávání, čtení a sumarizace zdrojů.';

  @override
  String get knowledgeGraphHint =>
      'Vaše nejčastěji zmiňované entity, barevné podle shluků. Čáry spojují entity, které se objevují ve stejných vzpomínkách. Klepnutím na jeden zobrazíte jeho odkazy a vzpomínky; tažením posouváte, sevřením nebo posouváním Ctrl/⌘ pro přiblížení.';

  @override
  String get linkedEntities => 'Propojené entity';

  @override
  String get noLinkedEntities => 'Zatím není propojen s jinými subjekty.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 zmiňuje';
  }

  @override
  String get entityKindConcept => 'koncepce';

  @override
  String get entityKindDomain => 'doména';

  @override
  String get entityKindEmail => 'Email';

  @override
  String get entityKindLink => 'Odkaz';

  @override
  String get entityKindFile => 'Soubor';

  @override
  String get entityKindAcronym => 'Zkratka';

  @override
  String get entityKindIdentifier => 'Identifikátor';

  @override
  String get entityKindVersion => 'Verze';

  @override
  String get openFullscreen => 'Otevřít celou obrazovku';

  @override
  String get zoomIn => 'Přiblížit';

  @override
  String get zoomOut => 'Oddálit';

  @override
  String get searchEntities => 'Najděte entitu';

  @override
  String get incomingCall => 'Příchozí hovor';

  @override
  String get answerCall => 'Odpověď';

  @override
  String get callMeLater => 'Zavolej mi později';

  @override
  String get callingEllipsis => 'Volání…';

  @override
  String get reconnectingCall => 'Opětovné připojení';

  @override
  String get agentWorking => 'Práce';

  @override
  String get micMuted => 'Ztlumeno';

  @override
  String get speakerphone => 'Mluvčí';

  @override
  String get muteMic => 'Ztlumit';

  @override
  String get unmuteMic => 'Zapnout zvuk';

  @override
  String get releaseToSend => 'Odešlete uvolněním';

  @override
  String get callEnded => 'Hovor ukončen';

  @override
  String get openConversation => 'Otevřete konverzaci';

  @override
  String get callBack => 'Zavolejte zpět';

  @override
  String get letCallsReachYou => 'Nechte hovory zastihnout vás';

  @override
  String get callPermissionsIntro =>
      'Vaši agenti vám mohou zavolat. Chcete-li zvonit jako telefonní hovor, když je NeoAgent na pozadí nebo je váš telefon zamčený, potřebuje tyto.';

  @override
  String get showOverOtherApps => 'Zobrazit přes jiné aplikace';

  @override
  String get showOverOtherAppsDetail =>
      'Zobrazí obrazovku hovoru, ať jste kdekoli.';

  @override
  String get fullScreenCalls => 'Hovory přes celou obrazovku';

  @override
  String get fullScreenCallsDetail => 'Zazvoní nad zamykací obrazovkou.';

  @override
  String get unrestrictedBattery => 'Neomezená baterie';

  @override
  String get unrestrictedBatteryDetail =>
      'Udržuje NeoAgent připojený, takže hovory přicházejí.';

  @override
  String get permissionAllowed => 'Povoleno';

  @override
  String get triggerSectionCalendar => 'Kalendář';

  @override
  String get triggerSectionFiles => 'Soubory a dokumenty';

  @override
  String get triggerSectionHome => 'Domov a média';

  @override
  String get triggerSectionDevices => 'Zařízení a místa';

  @override
  String get triggerSectionTasks => 'Úkoly';

  @override
  String get messagingMemberJoined => 'Člen se připojil';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Spustit, když se někdo připojí k serveru Discord, skupině Telegram nebo WhatsApp, kanálu Slack nebo místnosti Matrix.';

  @override
  String get messagingMemberLeft => 'Člen odešel';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Spustit, když někdo opustí server Discord, skupinu telegramů nebo WhatsApp, kanál Slack nebo místnost Matrix.';

  @override
  String get messagingReactionAdded => 'Přidána reakce';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Spustit, když povolená osoba zareaguje na zprávu v soukromém chatu.';

  @override
  String get messagingPlatformDisconnected => 'Zasílání zpráv je odpojeno';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Spustit, když se připojení zasílání zpráv zastaví a potřebuje vás, například po odhlášení.';

  @override
  String get googleCalendarEventStarting => 'Začíná událost Kalendáře Google';

  @override
  String get googleCalendarEventCreated =>
      'Událost Kalendáře Google byla vytvořena';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Spustit, když se objeví nová událost nebo pozvánka.';

  @override
  String get outlookCalendarEventStarting =>
      'Zahájení události kalendáře Outlooku';

  @override
  String get nextcloudCalendarEventStarting =>
      'Začíná událost kalendáře Nextcloud';

  @override
  String get runMinutesBeforeEachEvent =>
      'Spusťte stanovený počet minut před každou událostí.';

  @override
  String get googleDriveFileAdded => 'Byl přidán soubor Disku Google';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Spustit, když je soubor přidán na Disk nebo do složky v něm.';

  @override
  String get googleSheetsRowAdded => 'Byl přidán řádek Tabulek Google';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Spustit, když se v listu objeví nové řádky.';

  @override
  String get onedriveFileAdded => 'Byl přidán soubor OneDrive';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Spustit, když je soubor přidán do složky OneDrive.';

  @override
  String get nextcloudFileAdded => 'Byl přidán soubor Nextcloud';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Spustit, když je soubor přidán do složky Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Nextcloud soubor sdílený s vámi';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Spustit, když s vámi někdo sdílí soubor nebo složku.';

  @override
  String get notionItemAdded => 'Přidána položka databáze pojmů';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Spustit, když je položka přidána do databáze Notion.';

  @override
  String get notionItemUpdated => 'Položka databáze pojmů aktualizována';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Spustit, když se změní položka v databázi Notion.';

  @override
  String get trelloCardEnteredList => 'Do seznamu přidána karta Trello';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Spustit, když je karta vytvořena nebo přesunuta do seznamu.';

  @override
  String get figmaCommentAdded => 'Přidán komentář Figma';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Spustit, když někdo okomentuje soubor Figma.';

  @override
  String get githubPrOpened => 'Požadavek na stažení GitHubu byl otevřen';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Spustit, když je v úložišti otevřen nový požadavek na stažení.';

  @override
  String get githubWorkflowRunFailed =>
      'Spuštění pracovního postupu GitHub se nezdařilo';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Spustit, když selže spuštění akce GitHub.';

  @override
  String get githubCommitPushed => 'Odeslání potvrzení GitHubu';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Spustit, když nové commity dosáhnou větve.';

  @override
  String get mcpServerFailed => 'Server MCP selhal';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Spustit, když funkční server MCP selže nebo potřebuje přihlášení.';

  @override
  String get homeAssistantStateChanged => 'Stav Home Assistant se změnil';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Spustit, když se entita změní, dosáhne stavu nebo překročí hodnotu.';

  @override
  String get spotifyTrackChanged => 'Skladba Spotify změněna';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Spustit, když se začne přehrávat jiná skladba.';

  @override
  String get neorecallDailySummaryReady => 'Denní shrnutí NeoRecall připraveno';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Spustit, když je souhrn dne konečný.';

  @override
  String get neorecallConversationRecorded =>
      'Rozhovor NeoRecall byl zaznamenán';

  @override
  String get runWhenARecordedConversationEnds =>
      'Spustit, když nahraná konverzace skončí.';

  @override
  String get geofenceTrigger => 'Umístění geofence';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Spusťte, když váš telefon dorazí na místo nebo jej opustí. Vyžaduje sledování polohy v telefonu.';

  @override
  String get healthMetricRecorded => 'Zaznamenána zdravotní metrika';

  @override
  String get runWhenAHealthReadingArrives =>
      'Spustit, když dorazí synchronizovaná hodnota stavu, volitelně nad nebo pod hodnotou.';

  @override
  String get wearableConnectionChanged => 'Nositelné připojené nebo odpojené';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Spusťte, když se vaše nositelné zařízení připojí nebo odpojí.';

  @override
  String get taskRunFinished => 'Další úkol dokončen';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Spusťte po dokončení, úspěchu nebo selhání jiné úlohy.';

  @override
  String get appPackageOptional => 'Balíček aplikace (volitelné)';

  @override
  String get appPackageHelper => 'Například com.whatsapp';

  @override
  String get anyPlatform => 'Jakákoli platforma';

  @override
  String get spaceIdOptional =>
      'ID serveru, skupiny, kanálu nebo místnosti (volitelné)';

  @override
  String get spaceIdHelper => 'Prázdné sleduje každého, ve kterém je robot.';

  @override
  String get emojiOptional => 'Emoji (volitelné)';

  @override
  String get chatIdOptional => 'ID chatu (volitelné)';

  @override
  String get platformOptional => 'Platforma (volitelné)';

  @override
  String get platformOptionalHelper =>
      'Například whatsapp. Prázdné hodinky všechny.';

  @override
  String get minutesBefore => 'Minuty předtím';

  @override
  String get calendarIdOptional => 'ID kalendáře (volitelné)';

  @override
  String get calendarIdHelper => 'Prázdné používá váš primární kalendář.';

  @override
  String get invitesOnly => 'Pouze pozvánky od ostatních';

  @override
  String get nextcloudCalendarPath => 'Kalendář';

  @override
  String get nextcloudCalendarPathHelper =>
      'Jeho název v seznamu kalendářů Nextcloud, například osobní';

  @override
  String get folderIdOptionalHelperDrive => 'Prázdné sleduje celý Disk.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Prázdný sleduje kořenovou složku.';

  @override
  String get driveFolderIdOptional => 'ID složky (volitelné)';

  @override
  String get spreadsheetId => 'ID tabulky';

  @override
  String get sheetRange => 'Rozsah';

  @override
  String get sheetRangeHelper => 'Sloupce tabulky, například List1!A:E';

  @override
  String get folderPathOptional => 'Cesta ke složce (volitelné)';

  @override
  String get folderPathHelper => 'Například Dokumenty';

  @override
  String get notionDatabaseId => 'ID databáze';

  @override
  String get trelloListId => 'ID seznamu';

  @override
  String get figmaFileKey => 'Klíč souboru';

  @override
  String get figmaFileKeyHelper =>
      'Z odkazu na soubor: figma.com/file/<klíč>/…';

  @override
  String get githubRepository => 'Úložiště';

  @override
  String get workflowOptional => 'Pracovní postup (volitelné)';

  @override
  String get workflowHelper => 'Název souboru, například ci.yml';

  @override
  String get branchOptional => 'Pobočka (volitelné)';

  @override
  String get branchHelper => 'Prázdná používá výchozí větev.';

  @override
  String get mcpServerIdOptional => 'ID serveru MCP (volitelné)';

  @override
  String get entityId => 'ID entity';

  @override
  String get entityIdHelper => 'Například binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Cílový stát (volitelné)';

  @override
  String get targetStateHelper => 'Například na';

  @override
  String get aboveOptional => 'Výše (volitelné)';

  @override
  String get belowOptional => 'Níže (volitelné)';

  @override
  String get placeName => 'Název místa';

  @override
  String get latitude => 'Zeměpisná šířka';

  @override
  String get longitude => 'Zeměpisná délka';

  @override
  String get radiusMeters => 'Poloměr v metrech';

  @override
  String get geofenceTransition => 'Kdy';

  @override
  String get arriving => 'Příjezd';

  @override
  String get leaving => 'Odcházím';

  @override
  String get healthMetric => 'Metrika zdraví';

  @override
  String get healthMetricHelper => 'Například tepová frekvence, kroky, váha';

  @override
  String get wearableTransition => 'Když nositelné';

  @override
  String get wearableConnects => 'Připojuje se';

  @override
  String get wearableDisconnects => 'Odpojí se';

  @override
  String get sourceTask => 'Po úkolu';

  @override
  String get taskOutcome => 'Výsledek';

  @override
  String get anyOutcome => 'Jakýkoli výsledek';

  @override
  String get succeeded => 'Povedlo se';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 chybí nebo není platné.';
  }

  @override
  String get triggerSectionMessaging => 'Zasílání zpráv';

  @override
  String get triggerSectionDeveloper => 'Vývojář';

  @override
  String get triggerSectionMemory => 'Paměť';

  @override
  String get triggerSectionNews => 'Novinky';

  @override
  String get triggerSectionSystem => 'Systém';

  @override
  String get searchTriggersHint =>
      'Vyhledávejte spouštěče, aplikace nebo události';

  @override
  String get noTriggersMatch => 'Vašemu vyhledávání neodpovídá žádný spouštěč.';

  @override
  String get triggerAccountMissing => 'Zatím žádný účet';

  @override
  String get pickTriggerKeyboardHint => 'Enter vybere první výsledek';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return 'Spouští $arg1';
  }

  @override
  String get addFromSkillsSh => 'Přidat z skills.sh';

  @override
  String get skillsShHint =>
      'Hledejte výše a najděte dovednosti na skills.sh nebo vložte odkaz skills.sh nebo příkaz `npx skills add`.';

  @override
  String get noSkillsShMatches =>
      'Tomuto vyhledávání neodpovídají žádné dovednosti skills.sh.';

  @override
  String get installingSkill => 'Instalace…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Nainstalovaný $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return 'Instalace $arg1';
  }

  @override
  String get authVerify => 'Ověřte';

  @override
  String get authCreateAccount => 'Vytvořit účet';

  @override
  String get authNewInviteLink => 'Nový odkaz na pozvánku';

  @override
  String get authShowPassword => 'Zobrazit heslo';

  @override
  String get authHidePassword => 'Skrýt heslo';

  @override
  String get authPasswordWillBeRejected => 'příliš slabý, bude odmítnut';

  @override
  String get authUsernameTooShort =>
      'Uživatelská jména potřebují alespoň 3 znaky.';

  @override
  String get authUsernameTaken => 'Toto uživatelské jméno je již obsazeno.';

  @override
  String get authSignupsClosed =>
      'Registrace jsou na tomto serveru uzavřeny. Požádejte administrátora o účet.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Tento server přijímá pouze přihlášení přes HTTPS. Místo toho otevřete $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Tento server přijímá pouze přihlášení přes HTTPS. Připojte se k němu pomocí adresy https://.';

  @override
  String get authAccountNotFound => 'Tento účet již neexistuje.';

  @override
  String get authQrRateLimited =>
      'Příliš mnoho požadavků na přihlášení pomocí QR kódu. Chvíli počkejte a poté obnovte kód.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Zapomněli jste heslo? Požádejte administrátora serveru, aby jej resetoval v Admin → Uživatelé.';

  @override
  String get authChangeServer => 'Změnit server';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Přihlašování do $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Tato adresa neodpovídá jako server NeoAgent. Zkontrolujte adresu URL a zkuste to znovu.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Nelze otevřít zabezpečené (HTTPS) připojení k $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Nepodařilo se dosáhnout $arg1 přes HTTPS a prostý HTTP také neodpověděl. Zkontrolujte adresu a port.';
  }

  @override
  String get adminResetPassword => 'Obnovit heslo';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Resetovat heslo pro $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Zvolte nové heslo pro $arg1. Budou odhlášeni ze všech zařízení a znovu se přihlásí pomocí tohoto hesla.';
  }

  @override
  String get adminNewPassword => 'Nové heslo';

  @override
  String get adminSetPassword => 'Nastavte heslo';

  @override
  String get authMissingFields => 'Vyplňte všechna povinná pole.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 resetuje heslo $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Heslo aktualizováno; uživatel byl všude odhlášen.';

  @override
  String get authSignInTitle => 'Přihlaste se do NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Skenujte pomocí telefonu nebo použijte heslo.';

  @override
  String get authOrUsePassword => 'nebo použijte své heslo';

  @override
  String get qrLoginWaitingTitle => 'Schválit na svém telefonu';

  @override
  String get qrLoginWaitingBody =>
      'Váš telefon naskenoval kód. Pro dokončení přihlašování potvrďte přihlášení.';

  @override
  String get qrLoginSigningInOn => 'Přihlašování zapnuto';

  @override
  String get qrLoginLocation => 'Umístění';

  @override
  String get qrLoginWaitingForApproval => 'Čekání na schválení';

  @override
  String get qrLoginCancelAndUsePassword => 'Zrušte a použijte heslo';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Přihlášení na vašem telefonu bylo odmítnuto. Naskenujte nový kód a zkuste to znovu.';

  @override
  String get signupKey => 'Registrační klíč';

  @override
  String get signupKeyStepSubtitle =>
      'Nové účty na tomto serveru vyžadují registrační klíč. Zadejte klíč, který jste dostali od správce.';

  @override
  String get signupKeyChange => 'Změnit';

  @override
  String get signupKeyRequiredError => 'Zadejte svůj registrační klíč.';

  @override
  String get signupKeyInvalidError =>
      'Tento registrační klíč není platný. Zkontrolujte ho a zkuste to znovu.';

  @override
  String get signupKeyUsedError =>
      'Tento registrační klíč už byl použit. Požádejte správce o nový.';

  @override
  String get adminRequireSignupKey => 'Vyžadovat registrační klíč';

  @override
  String get adminRequireSignupKeyHint =>
      'Nové účty vyžadují jednorázový klíč od správce. Když je vypnuto, může se zaregistrovat kdokoli, kdo se k tomuto serveru dostane. První účet klíč nikdy nepotřebuje.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Nové účty nyní vyžadují registrační klíč.';

  @override
  String get adminSignupOpenNotice => 'Nyní se může zaregistrovat kdokoli.';

  @override
  String get signupKeys => 'Registrační klíče';

  @override
  String get signupKeysDescription =>
      'Jednorázové klíče pro registraci, dokud je klíč vyžadován. Každý klíč vytvoří právě jeden účet.';

  @override
  String get signupKeysNew => 'Nové klíče';

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
    return 'Všechny · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Nepoužitý';

  @override
  String get signupKeyStatusUsed => 'Použitý';

  @override
  String get signupKeyStatusRevoked => 'Zrušený';

  @override
  String get signupKeysExport => 'Exportovat .txt';

  @override
  String get signupKeysCopied => 'Klíče zkopírovány';

  @override
  String get signupKeyCopied => 'Klíč zkopírován';

  @override
  String get signupKeysEmpty => 'V tomto seznamu nejsou žádné klíče.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Vytvořeno $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Použil(a) $arg1, $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Použito $arg1 účtem, který byl mezitím smazán';
  }

  @override
  String get signupKeyRevokeTitle => 'Zrušit tento klíč?';

  @override
  String get signupKeyRevokeMessage =>
      'Nikdo se s ním už nebude moci zaregistrovat. Tuto akci nelze vrátit.';

  @override
  String get signupKeyRevoked => 'Klíč zrušen.';

  @override
  String signupKeysShowMore(int count) {
    return 'Zobrazit dalších $count';
  }

  @override
  String get signupKeysCreateTitle => 'Vytvořit registrační klíče';

  @override
  String get signupKeysCount => 'Počet klíčů';

  @override
  String get signupKeysCountHelper => '1 až 500';

  @override
  String get signupKeysCountInvalid => 'Zadejte číslo od 1 do 500.';

  @override
  String get signupKeysLabel => 'Popisek (volitelné)';

  @override
  String get signupKeysLabelHint => 'např. Jarní beta testeři';

  @override
  String signupKeysCreateAction(int count) {
    return 'Vytvořit ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Připravené klíče: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Každý klíč předejte jen jedné osobě. Nepoužité klíče zůstávají v seznamu, takže je můžete později znovu zkopírovat nebo exportovat.';

  @override
  String get signupKeysSaveDialogTitle => 'Uložit registrační klíče';

  @override
  String get signupKeysExported => 'Klíče exportovány.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor vytvořil(a) registrační klíče ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor zrušil(a) registrační klíč';
  }

  @override
  String get providerChooseUsername => 'Zvolte si uživatelské jméno';

  @override
  String get providerChooseUsernameBody =>
      'Zvolte si dostupné uživatelské jméno a dokončete vytvoření účtu.';

  @override
  String get dataSharingTitle => 'Sdílet data o používání';

  @override
  String get dataSharingDescription =>
      'Pomozte správcům tohoto serveru ho vylepšovat. Sdílí, jak NeoAgent používáte, nikdy to, co píšete nebo ukládáte.';

  @override
  String dataSharingSince(String date) {
    return 'Sdíleno od $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Co se sdílí';

  @override
  String get dataSharingIncluded => 'Sdílí se';

  @override
  String get dataSharingExcluded => 'Nikdy se nesdílí';

  @override
  String get dataSharingIncludedDevice => 'Typ zařízení a verze aplikace';

  @override
  String get dataSharingIncludedLocale =>
      'Jazyk aplikace a oblast časového pásma, například Evropa';

  @override
  String get dataSharingIncludedFeatures =>
      'Které funkce máte nastavené, například úlohy, skilly a integrace';

  @override
  String get dataSharingIncludedRuns =>
      'Které nástroje a modely vaše běhy používají, s dobou trvání a počtem tokenů';

  @override
  String get dataSharingIncludedActivity =>
      'Kdy NeoAgent používáte, podle dne v týdnu a hodiny';

  @override
  String get dataSharingExcludedContent => 'Zprávy, prompty a odpovědi';

  @override
  String get dataSharingExcludedRuns =>
      'Názvy běhů, vstupy a výsledky nástrojů';

  @override
  String get dataSharingExcludedFiles =>
      'Soubory, vzpomínky a vše ostatní, co ukládáte';

  @override
  String get dataSharingExcludedIdentity =>
      'Vaše jméno, e-mail, IP adresa a poloha';

  @override
  String get dataSharingExcludedAccounts =>
      'Účty, se kterými propojujete integrace';

  @override
  String get dataSharingPooledNote =>
      'Správci vidí jen součty za všechny, kdo sdílejí, nikdy vás samotné. Kdykoli to vypněte a hned ze součtů vypadnete.';

  @override
  String get dataSharingConfirmTitle => 'Sdílet data o používání?';

  @override
  String get dataSharingConfirmAction => 'Sdílet';

  @override
  String get sharedUsageTitle => 'Sdílené používání';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Účty sdílející data o používání: $sharing z $total. Jen součty, žádný obsah.';
  }

  @override
  String get sharedUsageEmpty =>
      'Zatím nikdo nesdílí data o používání. Zapnout to lze v: Nastavení, Profil, Vaše data.';

  @override
  String get sharedUsageRuns => 'Sdílené běhy';

  @override
  String get sharedUsageAvgDuration => 'Prům. doba';

  @override
  String get sharedUsageCompletedRuns => 'Dokončené běhy';

  @override
  String get sharedUsageStepsPerRun => 'Kroky na běh';

  @override
  String get sharedUsageDevices => 'Zařízení';

  @override
  String get sharedUsageAppVersions => 'Verze aplikace';

  @override
  String get sharedUsageLanguages => 'Jazyky';

  @override
  String get sharedUsageRegions => 'Oblasti';

  @override
  String get sharedUsageFeatures => 'Využití funkcí';

  @override
  String get sharedUsageFeaturesDescription =>
      'Podíl sdílejících účtů, které ji mají nastavenou.';

  @override
  String get sharedUsageTools => 'Nástroje';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Nejčastěji volané nástroje ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Volání: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Selhalo: $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Integrace';

  @override
  String get sharedUsageMessaging => 'Kanály zpráv';

  @override
  String get sharedUsageTriggers => 'Jak běhy začínají';

  @override
  String get sharedUsageActivity => 'Kdy se používá';

  @override
  String get sharedUsageActivityDescription =>
      'Běhy podle dne v týdnu a hodiny, UTC.';

  @override
  String get sharedUsageModels => 'Výkon modelů';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'prům. $latency · $cached % z cache · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Účty: $count';
  }

  @override
  String get sharedUsageNoData => 'V tomto období nic.';

  @override
  String get sharedUsageNotReported => 'Zatím nenahlášeno';

  @override
  String get sharedUsageFeatureAgents => 'Více než jeden agent';

  @override
  String get sharedUsageFeatureTasks => 'Plánované úlohy';

  @override
  String get sharedUsageFeatureSkills => 'Skilly';

  @override
  String get sharedUsageFeatureMcp => 'MCP servery';

  @override
  String get sharedUsageFeatureIntegrations => 'Integrace';

  @override
  String get sharedUsageFeatureMessaging => 'Kanály zpráv';

  @override
  String get sharedUsageFeatureMemory => 'Paměť';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in sdílení dat telemetrie zařízení funkce nástroje modely aktivita';

  @override
  String get yourOAuthApp => 'Vaše OAuth aplikace';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Vaše OAuth aplikace $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Tento server nemá globální aplikaci $provider, proto se připojujete přes OAuth aplikaci, kterou si zaregistrujete sami. Tajný klíč klienta je uložen šifrovaně a už se nikdy nezobrazí.';
  }

  @override
  String get oauthAppStepCreate => '1. Vytvořte aplikaci';

  @override
  String get openDeveloperConsole => 'Otevřít vývojářskou konzoli';

  @override
  String get oauthAppStepCallback => '2. Zaregistrujte tuto callback URL';

  @override
  String get callbackUrlCopied => 'Callback URL zkopírována';

  @override
  String get oauthAppScopes => 'Povolované scopy';

  @override
  String get scopesCopied => 'Scopy zkopírovány';

  @override
  String get oauthAppStepCredentials => '3. Vložte přihlašovací údaje aplikace';

  @override
  String get couldNotSaveOAuthApp => 'OAuth aplikaci se nepodařilo uložit.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Odebrat vaši aplikaci $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'Připojené účty zůstanou v seznamu, ale přestanou fungovat, dokud znovu nepřidáte aplikaci.';

  @override
  String get globalIntegrationConfiguration => 'Globální konfigurace integrací';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Volitelné OAuth aplikace pro celý server. Pokud ji integrace má, používá ji každý účet a nemůže přidat vlastní. Ponechte integraci nenastavenou a každý uživatel si nastaví vlastní aplikaci. Tajné údaje lze pouze zapisovat: ponechte prázdné, chcete-li zachovat uloženou hodnotu.';

  @override
  String get globalStatus => 'Globální';

  @override
  String get perUserStatus => 'Pro uživatele';
}
