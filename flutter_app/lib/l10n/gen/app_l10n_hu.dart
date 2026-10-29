// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppL10nHu extends AppL10n {
  AppL10nHu([String locale = 'hu']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Üdvözöljük';

  @override
  String get onboardingEyebrowCommunication => 'Kommunikáció';

  @override
  String get onboardingEyebrowIntelligence => 'Intelligencia';

  @override
  String get onboardingEyebrowComputer => 'Számítógép';

  @override
  String get onboardingEyebrowAutomation => 'Automatizálás';

  @override
  String get onboardingNext => 'Következő';

  @override
  String get onboardingIntroCouldNotLoad =>
      'A bevezetőt nem sikerült betölteni.';

  @override
  String get onboardingModelDescription =>
      'Válassza ki azt a modellt, amelyet a NeoAgent alapértelmezés szerint használjon, vagy hagyja, hogy automatikusan válasszon.';

  @override
  String get onboardingLoadingModels => 'Modellek betöltése…';

  @override
  String get noAiModelTitle => 'Még nincs AI modell beállítva';

  @override
  String get noAiModelBody =>
      'Adjon hozzá egy API-kulcsot egy olyan szolgáltatótól, mint az OpenAI, az Anthropic vagy a Google. A NeoAgent ezután megmutatja a használható modelleket.';

  @override
  String get noAiModelChatBody =>
      'A NeoAgentnek AI modellre van szüksége a válaszadáshoz. Adjon hozzá egy API-kulcsot egy olyan szolgáltatótól, mint az OpenAI, az Anthropic vagy a Google.';

  @override
  String get noAiModelAdminHint =>
      'Rendszergazdaként mindenki számára beállíthat szolgáltatót az Adminisztrálás → Szolgáltatók alatt.';

  @override
  String get addApiKey => 'API-kulcs hozzáadása';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform csatlakoztatva van.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Várakozás a $platform csatlakozásra…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'A beállítást nem sikerült elmenteni: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Kész';

  @override
  String get onboardingStepRequired => 'Kötelező';

  @override
  String get onboardingStepOptional => 'Választható';

  @override
  String get onboardingStepCloudOrLocal => 'Felhő vagy helyi';

  @override
  String get onboardingStepComputer => 'Számítógép';

  @override
  String get onboardingStepRoutines => 'Rutinok';

  @override
  String get onboardingComputerChoiceTitle => 'Hol\nműködjön?';

  @override
  String get onboardingComputerChoiceDescription => 'Munkamenetenként válthat.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Privát homokozó · mindig bekapcsolva';

  @override
  String get onboardingThisComputer => 'Ezt a számítógépet';

  @override
  String get onboardingThisComputerSubtitle =>
      'Fájljai, alkalmazásai és böngészője';

  @override
  String get onboardingSearchApps => 'Alkalmazások keresése…';

  @override
  String get onboardingRoutinesDescription =>
      'Az eredmények a chatekben jelennek meg.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Az eredmények értesítésként érkeznek.';

  @override
  String get onboardingNotifications => 'Értesítések';

  @override
  String get onboardingReadyTitle => 'Minden\nkészen áll.';

  @override
  String get onboardingReadyDescription => 'Küldje el az első üzenetet.';

  @override
  String get onboardingMessageNeoagent => 'Üzenet NeoAgent';

  @override
  String get onboardingAskAnything => 'Kérdezz bármit…';

  @override
  String get onboardingOpenNeoagent => 'Nyissa meg a NeoAgentet';

  @override
  String get onboardingStarterTrip => 'Tervezz egy hétvégi kirándulást';

  @override
  String get onboardingStarterLanding => 'Hozzon létre egy nyitóoldalt';

  @override
  String onboardingQuickSteps(int count) {
    return '$count gyors lépések';
  }

  @override
  String get taskNeedsEmail => 'Először csatlakoztassa az e-mailt';

  @override
  String get taskNeedsCalendar => 'Először csatlakoztasson egy naptárt';

  @override
  String get taskNeedsModel => 'Először állítson be egy AI-modellt';

  @override
  String get taskPromptDailyRecap =>
      'Foglalja össze a napomat: foglalja össze a beszélgetéseket, a befejezett munkát és a mai döntéseket, majd soroljon fel mindent, amivel holnap foglalkoznom kell. Legyen rövid, és küldje el nekem.';

  @override
  String get taskPromptInboxCheck =>
      'Nézze meg az e-mail postafiókomban az utolsó ellenőrzés óta érkezett üzeneteket. Csak a sürgős vagy választ igénylő e-mailekről írjon nekem, mindegyik egysoros összefoglalóval. Ha semmi nem igényel a figyelmemet, ne küldj semmit.';

  @override
  String get taskPromptMorningBriefing =>
      'Készítse elő a reggeli tájékoztatómat: a mai időjárás, ahol vagyok, a naptáramban szereplő események és a legfontosabb nyitott tételek, amelyekről tudok. Küldje el rövid, beolvasható üzenetként.';

  @override
  String get taskPromptTomorrowPrep =>
      'Nézd meg a holnapi naptáram. Minden egyes találkozónál mondja el, miről van szó, kik vesznek részt, és bármit, amit elő kell készítenem. Ha a holnap üres, ne küldj semmit.';

  @override
  String get taskPromptNewsDigest =>
      'Keressen az interneten a mai nap legfontosabb híreiért az engem érdeklő témákról (használja azt, amire emlékszik az érdeklődési köreimről). Legfeljebb öt elemből álló kivonatot küldj nekem egy-egy mondattal és egy hivatkozással.';

  @override
  String get taskPromptWeeklyReview =>
      'Tekintse át a hetem: mi sikerült, mi csúszott el és mi van még nyitva. Javasoljon három legfontosabb dolgot, amelyre a következő héten összpontosítson.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Kapcsoljon össze egy telefonszámot, amely az ügynökhöz tartozik. Bárki, akit engedélyez, cseveghet vele közvetlen csevegésekben és csoportokban.';

  @override
  String get whatsappSelfChatDescription =>
      'Kapcsolja össze saját számát, és beszéljen az ügynökkel az „Üzenetet küld magának” csevegésben. Ebben a fiókban minden más csevegés és csoport figyelmen kívül marad.';

  @override
  String get chatSendHintMac => '⌘↵ küldéséhez';

  @override
  String get chatSendHintOther => 'Ctrl+Enter a küldéshez';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Ehhez a végponthoz alap URL-cím szükséges.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'A megváltozott e-mail cím használat előtt megerősítésre kerül.';

  @override
  String get aDecisionHigherUpTheChain => 'A láncban feljebb lévő döntés nyer.';

  @override
  String get aDeletedAccount => 'törölt fiók';

  @override
  String get aFridayLookBackAtThe =>
      'Pénteki visszatekintés a hétre és terve a következőre.';

  @override
  String get aKeyThatAsksForA =>
      'A PIN-kódot vagy ujjlenyomatot kérő kulcs a kéttényezős kódot is helyettesíti.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Egy nyelvi modell úgy ítélte meg ezt az üzenetet, mert a SystemOne ki van kapcsolva.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Egy NeoAgent beállítási metaadatfájl túllépte a biztonságos méretkorlátot.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'A szerveren elérhető egy újabb web build. Töltse be újra a legújabb csomag letöltéséhez.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Privát asztal Chromiummal, fájlokkal, szövegszerkesztővel, terminállal és Pythonnal. Munkái a munkamenetek között mentve maradnak.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Privát Linux-számítógép vagy Android-eszköz.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'A szükséges NeoAgent telepítőfájlt nem lehetett letölteni.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Egy csapattárs küld egy meghívólinket. Ha egyszer elfogadod, ők ';

  @override
  String get aTeammateSentYouAnInvite =>
      'egy csapattársa meghívó linket küldött neked, írja be ide, hogy csatlakozzon a csapatához.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Az ideiglenes letöltést később töröljük.';

  @override
  String get aValueIsStored => 'A rendszer egy értéket tárol.';

  @override
  String get access => 'Hozzáférés';

  @override
  String get accessActivity => 'Hozzáférési tevékenység';

  @override
  String accessArg1(Object? arg1) {
    return 'Hozzáférés: $arg1';
  }

  @override
  String get accessMode => 'Hozzáférési mód';

  @override
  String get accessPermissions => 'Hozzáférési engedélyek';

  @override
  String get accessToken => 'hozzáférési token';

  @override
  String get accessToken2 => 'Hozzáférési token';

  @override
  String get account => 'Fiók';

  @override
  String accountArg1(Object? arg1) {
    return 'Számla #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Fiókmódosítási figyelmeztetések';

  @override
  String get accountEmail => 'Fiók e-mail címe';

  @override
  String get accountEmailIsOffUntilThese =>
      'A fiók e-mailje ki van kapcsolva, amíg a következőket be nem állítja: ';

  @override
  String get accountLanguageDescription =>
      'A NeoAgent az alkalmazásban mindenhol ezt a nyelvet használja. Az első bejelentkezéskor ezt az eszközt követi. Ezt követően a választás mentésre kerül a fiókjába, és minden eszközön felhasználható.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Nem sikerült megváltoztatni a nyelvet: $error';
  }

  @override
  String get accountLanguageTitle => 'Nyelv';

  @override
  String get accountNumber => 'Számlaszám';

  @override
  String get accountSettings => 'Fiókbeállítások';

  @override
  String get accounts => 'Fiókok';

  @override
  String get accountsByTokensUsedAllTime =>
      'Fiókok használt tokenek szerint, minden alkalommal.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'fiókok felhőszámítógépei. A változtatások a szerver után érvényesek ';

  @override
  String get accountsOnThisServer => 'Fiókok ezen a szerveren';

  @override
  String get active => 'Aktív';

  @override
  String get activeSessions => 'Aktív foglalkozások';

  @override
  String get activeToday => 'Aktív ma';

  @override
  String get add => 'Hozzáadás';

  @override
  String get addAProviderCredentialFirstIts =>
      'Először adjon hozzá egy szolgáltatói hitelesítő adatot. Modellei egyszer felbukkannak itt ';

  @override
  String get addAgent => 'Ügynök hozzáadása';

  @override
  String get addAnotherSignInMethodBefore =>
      'Mielőtt eltávolítaná ezt a bejelentkezési módot, adjon hozzá egy másik bejelentkezési módot.';

  @override
  String get addBinding => 'Kötés hozzáadása';

  @override
  String get addByNameOrId => 'Hozzáadás név vagy azonosító alapján';

  @override
  String get addByNameOrIdInstead =>
      'Ehelyett név vagy azonosító alapján adja hozzá';

  @override
  String get addCredentialBinding => 'Hitelesítési adatok összerendelése';

  @override
  String get addEntry => 'Bejegyzés hozzáadása';

  @override
  String get addKey => 'Kulcs hozzáadása';

  @override
  String get addMcpServer => 'MCP szerver hozzáadása';

  @override
  String get addMemory => 'Memória hozzáadása';

  @override
  String get memoryReview => 'Áttekintés';

  @override
  String get memoryReviewPrompt =>
      'Nézd át az összes emlékemet és tegyél rendet: archiváld a duplikátumokat, az elavult tényeket és mindent, aminek nincs tartós értéke. Utána röviden mondd el, mit változtattál.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Adjon hozzá több hosszúságot vagy más karaktertípust.';

  @override
  String get addPeopleOrGroups => 'Személyek vagy csoportok hozzáadása';

  @override
  String get addSecurityKey => 'Biztonsági kulcs hozzáadása';

  @override
  String get addSomeoneOrAGroup => 'Adjon hozzá valakit vagy csoportot';

  @override
  String get addTask => 'Feladat hozzáadása';

  @override
  String get addTests => 'Tesztek hozzáadása';

  @override
  String get addTestsForThePartsOf =>
      'Adjon hozzá teszteket a projekt azon részeihez, amelyek a legkisebb lefedettséggel rendelkeznek, majd futtassa őket.';

  @override
  String get addTheirOwnKeysInSettings =>
      'a Beállításokban adhatja hozzá saját kulcsait.';

  @override
  String get addToPrompt => 'Hozzáadás a prompthoz';

  @override
  String get added => 'Hozzáadva';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Hozzáadott $arg1 · Utoljára használt $arg2';
  }

  @override
  String get addressWithTheProvider => 'címet a szolgáltatóval.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Állítsa be a hangszóró hangerejét, tekintse át a hardvergombok alapértelmezett beállításait, és kezelje ezt az indítómunkamenetet.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Módosítsa a keresési vagy állapotszűrőt, hogy több üzenetküldő csatornát lásson.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Itt állíthatja be a hangszóró hangerejét.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Adminisztrátor › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Itt jelennek meg az adminisztrátori támogatások, a meghívólinkek és a kezelési változások.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Speciális kézi ütemezés speciális esetekhez.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Haladó: perc óra nap hó hétköznap.';

  @override
  String get againRightAway => 'azonnal újra.';

  @override
  String get agent => 'ügynök';

  @override
  String agentArg1(Object? arg1) {
    return 'Ügynök: $arg1';
  }

  @override
  String get agentCalls => 'Ügynökhívások';

  @override
  String get agentCommunication => 'Ügynöki kommunikáció';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Ügynöki kommunikáció: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Az Ügynök mód szerkeszti a munkaterületet · ⌘↵ küldés · ⌘N új munkamenet';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Az ügynök megáll, és engedélyt kér tőled a futtatás előtt.';

  @override
  String get agentProfile => 'Ügynökprofil';

  @override
  String get agentVisibleName => 'Ügynök által látható név';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Az ügynök a $arg1-t szeretné használni. Koppintson a döntéshez.';
  }

  @override
  String get agents => 'Ügynökök';

  @override
  String get aiAnswerUnreadable => 'Az AI válasz olvashatatlan';

  @override
  String get aiProviderKeys => 'AI szolgáltató kulcsai';

  @override
  String get aiUnavailable => 'AI nem elérhető';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'riasztások és egyéb fiók e-mailjei.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Figyelmeztetés, ha egy üzenetküldő kapcsolat felhasználói figyelmet igényel';

  @override
  String get all => 'Mind';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Minden ügynök ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Mind $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Jelenleg az összes felhő-számítógép slot használatban van. Próbálja újra egy pillanat múlva.';

  @override
  String get allComputerSlotsAreBusy => 'Minden számítógéphely foglalt';

  @override
  String get allTables => 'Minden asztal';

  @override
  String get allTime => 'Minden alkalommal';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Minden eszköz engedélyezett – az ügynök kérés nélkül használhat bármilyen képességet. ';

  @override
  String get allow => 'Engedélyezze';

  @override
  String get allowedRunsWithoutAsking => 'Engedélyezett. Kérdés nélkül fut.';

  @override
  String get allowAll => 'Minden engedélyezése';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Engedélyezze az „Ismeretlen alkalmazások telepítése” lehetőséget a NeoAgent számára, majd próbálkozzon újra a frissítéssel.';

  @override
  String get allowOnce => 'Engedje meg egyszer';

  @override
  String get allowSender => 'Feladó engedélyezése';

  @override
  String get allowSession => 'Munkamenet engedélyezése';

  @override
  String get allowTheAgentToStartAn =>
      'Engedélyezze az ügynöknek, hogy alkalmazáson belüli hanghívást indítson Önnel.';

  @override
  String get allowedOrigins => 'Engedélyezett eredet';

  @override
  String get allowedPathPrefix => 'Engedélyezett elérési út előtag';

  @override
  String get allowsYouCanChangeThatPer =>
      'lehetővé teszi. Ezt később személyenként módosíthatja. A linkek soha nem adják meg ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'már egy meglévő fiókhoz tartozik';

  @override
  String get alreadyLinkedToAnotherAccount =>
      'már össze van kapcsolva egy másik fiókkal';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'már össze van kapcsolva egy másik neoagent fiókkal';

  @override
  String get alreadyUsed => 'már használt';

  @override
  String get always => 'Mindig';

  @override
  String get alwaysAllow => 'Mindig engedélyezze';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      'A „Mindig engedélyezés” véglegesen menti a házirendet – a Beállításokban módosíthatja.';

  @override
  String get alwaysAsk => 'Mindig kérdezz';

  @override
  String get alwaysEngage => 'Mindig vegyen részt';

  @override
  String get alwaysJoins => 'Mindig csatlakozik';

  @override
  String get anApiKeyIsRequired => 'API-kulcs szükséges.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Esti összefoglaló a történtekről és a továbbiakról.';

  @override
  String get anHttpOrHttpsUrlIs => 'http vagy https URL szükséges.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'és az analitika. A csapat linkjei élnek a Csapat oldalon.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Az Android APK telepítése nem érhető el ezen a platformon.';

  @override
  String get androidApp => 'Android alkalmazás';

  @override
  String get androidControl => 'Android vezérlés';

  @override
  String get androidCouldNotStart => 'Az Android nem tudott elindulni';

  @override
  String get androidNotificationReceived => 'Android-értesítés érkezett';

  @override
  String get androidOnly => 'Csak Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Az Android csomagtelepítő nem nyitható meg.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Android képernyő — érintse meg az érintéshez, húzza az ujját';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Válaszok @említésekre a problémákról és a lehívási kérésekről';

  @override
  String get anyone => 'Bárki';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Ezen a platformon bárki küldhet üzenetet a $arg1-nek';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Ezen a platformon bárki üzenetet küldhet a $arg1 $arg2 nyelven.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Bárki, aki eléri ezt a fiókot, beszélhet a $arg1-vel.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'A link birtokában bárki csatlakozhat, amíg le nem jár, vagy vissza nem vonja.';

  @override
  String get apiHttpsOrigin => 'API HTTPS eredet';

  @override
  String get apiKey => 'API kulcs';

  @override
  String get apiKey2 => 'api kulcs';

  @override
  String get apiKey3 => 'API kulcs';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api kulcs antropikus claude openai gpt xai grok google gemini minimax nvidia nim openrouter hitelesítő adatok';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API kulcsok és végpontok mesterséges intelligencia, keresési és hangszolgáltatók számára. Ők ';

  @override
  String get apiRequest => 'API-kérés';

  @override
  String get apiYourOwnServerASelf =>
      'API – saját szerver, saját üzemeltetésű modell vagy más ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Az APK letöltése nem sikerült a HTTP $arg1 használatával.';
  }

  @override
  String get appNameIsRequired => 'Az alkalmazás neve kötelező.';

  @override
  String get appUpdates => 'Alkalmazásfrissítések';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Az alkalmazásfrissítések nincsenek konfigurálva ehhez a buildhez.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'A $arg1 sorba állított irányítási frissítéseket alkalmazta az aktuális futtatáshoz.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Alkalmazott $arg1 kormányfrissítés(ek).';
  }

  @override
  String get apply => 'Alkalmazni';

  @override
  String get applyBehaviorNotes => 'Viselkedési megjegyzések alkalmazása';

  @override
  String get applyCoreMemory => 'Alkalmazza az alapvető memóriát';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Az érzékeny ügynöki eszközök jóváhagyási kérelmei';

  @override
  String get approvalRequired => 'Jóváhagyás szükséges';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'A jóváhagyás a hitelesített mobil munkameneten belül marad, és minden kód egy rövid idő elteltével automatikusan lejár.';

  @override
  String get approveLogin => 'Bejelentkezés jóváhagyása';

  @override
  String get approveQrLogin => 'QR-bejelentkezés jóváhagyása';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Ezt csak akkor hagyja jóvá, ha éppen most kezdte meg a bejelentkezést az adott eszközön.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Jóváhagyott bejelentkezés a $arg1 számára.';
  }

  @override
  String get approvedOnly => 'Csak jóváhagyva';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Jóváhagyott párosítás a $arg1 számára.';
  }

  @override
  String get approvedPeopleAndGroups => 'Jóváhagyott személyek és csoportok';

  @override
  String get approvedPeopleOnly => 'Csak jóváhagyott személyek';

  @override
  String get archive => 'Archívum';

  @override
  String get archiveAgent => 'Archív ügynök?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archívum ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Archívum $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Archiválja a kiválasztott emlékeket?';

  @override
  String get areSharedByEveryAccountOn =>
      'minden fiók megosztja a szerveren; fiókok továbbra is ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M bemenet';
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
    return '$arg1 hozzáférés szükséges';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 fiókok';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktív';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 hozzáadva. Szerkessze bármikor, hogy módosítsa a ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return 'A „$arg1” és futási előzményei véglegesen törlődnek. Minden aktív futás leáll. A munkaterületen lévő fájlokat nem érinti meg.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return '$arg1 jóváhagyás szükséges';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 alkalmazások aktívak';
  }

  @override
  String arg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 ($arg2)';
  }

  @override
  String arg1Arg210(Object? arg1, Object? arg2) {
    return '$arg1 $arg2';
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
    return '$arg1 ($arg2 aktív szerszámok)';
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
    return '$arg1 $arg2 és $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 megváltozott';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 karakterek';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Létrehozva: $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [helyi uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 „$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent munkaterület';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 új fiókok';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\nA $arg2 fut · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 minták';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 kormányzás sorban';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 tokenek';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 tokenek';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 és $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 rendszergazda lett ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 bájt';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 csatorna';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 karakterek';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 törölve.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 konfigurálva';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 csatlakoztatva. Válassza ki a lerakatokat és személyeket a Ki küldhet üzenetet.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 alapbejegyzések.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return 'A $arg1 meghívó hivatkozást hozott létre';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 asztali';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 események';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · A $arg1 nem sikerült';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return 'A $arg1 nem sikerült';
  }

  @override
  String arg1Failing(Object? arg1) {
    return 'A $arg1 meghibásodik';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 $arg2-hez';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 csoportok csak címkézve';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h ezelőtt';
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
    return '$arg1 segítők';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 találati arány)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return 'A @$arg1 rendszergazda, így a fiók nem törölhető ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return 'A $arg1 blokkolva van a $arg2-n. Frissítse a hozzáférési listát a válaszok engedélyezéséhez.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return 'A $arg1 csatlakoztatva van és válaszol.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return 'A $arg1 már nem adminisztrátor ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return 'A $arg1 nem érhető el a $arg2 rendszeren (hiányzó futásidejű engedély vagy függőség).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 csatlakozott a $arg2 alá';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 az LLM bírálata';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 kulcs$arg2 konfigurálva';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return '$arg1 kulcs eltávolítva.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 maradt';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 bal $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 összekapcsolva';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m ezelőtt';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Győződjön meg arról, hogy fut, majd próbálja újra.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 kezeli ezt a fiókot';
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
    return '$arg1 min $arg2 mp';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'A $arg1 modellek készen állnak';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 több';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 további lépések a futástörténetben';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return 'A $arg1 átkerült a $arg2-ből ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return 'A $arg1 véges számnak kell lennie.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return 'A $arg1 címnek http:// vagy https:// címnek kell lennie.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return 'A $arg1 figyelmet igényel';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent munkaterület';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 új fiókok a legutóbbi $arg2-ben.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · új üzenetek irányítják ezt a futást';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 új futások';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return 'Mostantól a $arg1 kezeli ezt a fiókot.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '4 engedélyből $arg1 engedélyezett. A fájlok a NeoAgent Workspace mappára korlátozódnak.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1/$arg2 engedélyezve';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 csoport csatlakozik a szokásos chathez';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 a $arg2 modellek közül';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 a $arg2 modellekből készen áll';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 a $arg2 készletből';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 szerszámok megengedettek';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: Rendben';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 a $arg2 napon a $arg3 időpontban';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return 'A $arg1 csak az alább hozzáadott személyeknek válaszol.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return 'A $arg1 csak címkézés esetén válaszol';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return 'A $arg1 csak az Ön által jóváhagyott személyekkel és csoportokkal beszél';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 személyek vagy csoportok hozzáadva';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 tervezés';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1 szolgáltatók';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 készen áll';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 rekordok';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 átirányítási URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 regisztrálva';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 válaszolt';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return 'A $arg1 visszavont egy meghívó hivatkozást';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 fut';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 fut · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return 'A $arg1 az utolsó $arg2-ben fut.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 mentve.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 mp';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 kiválasztva';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 látható';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return 'A $arg1 csendben maradt';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 kormányzás $arg2 sorban áll';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 lépés$arg2 · érintsen meg egy csomópontot az ellenőrzéshez';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 lépések';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return 'A $arg1 leállította a $arg2 kezelését';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 tokenek';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 tokenek az utolsó $arg2-ben.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 szerszámok';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (nem érhető el mentett felülbírálás)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% használt · $arg2 maradt';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return 'A $arg1 beszélni szeretne veled.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 web';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return 'A „$arg1” véglegesen el lesz távolítva.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 fogja kezelni ezt a fiókot';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return 'A $arg1 nem válaszol ezen a platformon';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return 'A $arg1 nem válaszol a $arg2 üzenetre.';
  }

  @override
  String get artifactStorageByUser => 'Műterméktárolás a felhasználó által';

  @override
  String get askAQuestionOrStartA =>
      'Tegyen fel kérdést vagy kezdjen el egy feladatot...';

  @override
  String get askBeforeClosingToBackground =>
      'Kérdezze meg a háttér bezárása előtt';

  @override
  String get askMe => 'Kérdezd meg';

  @override
  String get assignedAgent => 'Kirendelt ügynök';

  @override
  String get assignedAgent2 => 'Kijelölt ügynök';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Kirendelt ügynök: $arg1';
  }

  @override
  String get assigneeOptional => 'Megbízott (nem kötelező)';

  @override
  String get assistant => 'Asszisztens';

  @override
  String get assistantKey131 => 'Segéd gomb 131';

  @override
  String get atLeast1 => 'Legalább 1.';

  @override
  String get attachFiles => 'Fájlok csatolása';

  @override
  String attentionArg1(Object? arg1) {
    return 'Figyelem $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'ellenőrzési napló rendszergazdai engedély visszavonása meghívó csapat előzményei';

  @override
  String get authMethod => 'Auth Method';

  @override
  String get authServerUrl => 'Auth Server URL';

  @override
  String get authentication => 'Hitelesítés';

  @override
  String get authenticationFailed => 'A hitelesítés nem sikerült.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'A hitelesítés még függőben van. Fejezze be a böngésző folyamatát, és próbálja újra.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'A hitelesítés még függőben van. Fejezze be a böngésző folyamatát és frissítse.';

  @override
  String get authenticationTimedOut => 'A hitelesítés lejárt.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'A hitelesítést a befejezés előtt törölték.';

  @override
  String get authenticatorApp => 'Hitelesítő alkalmazás';

  @override
  String get authenticatorCode => 'Hitelesítő kód';

  @override
  String get authorOptional => 'Szerző (nem kötelező)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Automatikus (első szolgáltató API-kulccsal)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automatikusan az elérhető legjobb modellhez vezet';

  @override
  String get automaticFast => 'Automatikus (gyors)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatikusan beolvassa a szobát, és általában visszatartja. A csak említés nem tesz döntést, amíg közvetlenül meg nem szólítják.';

  @override
  String get automaticReserved => 'Automatikus, lefoglalt';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Az automatikus visszaállításhoz újra kell próbálkozni a beállítási képernyőről.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Az Automatikus gyors modellt választ ki a normál modellkatalógusból.';

  @override
  String get automation => 'Automatizálás';

  @override
  String get available => 'Elérhető';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Újra elérhető a $arg1 változatban';
  }

  @override
  String get availableAgainShortly => 'Hamarosan újra elérhető';

  @override
  String get availableInTheDesktopAppFor =>
      'Elérhető az asztali alkalmazásban MacOS, Windows és Linux rendszerekhez';

  @override
  String get availableToTheAgent => 'Az ügynök rendelkezésére áll';

  @override
  String get averageAllTime => 'Átlagos, minden alkalommal';

  @override
  String get avgImp => 'Átl. megj.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Átl./futás: $arg1 tokenek';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Kerülje az ismétlődő karaktereket és a nyilvánvaló sorozatokat.';

  @override
  String get awaitingScan => 'Beolvasásra vár';

  @override
  String get back => 'Vissza';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count a háttérben';
  }

  @override
  String get backgroundTasks => 'Háttérfeladatok';

  @override
  String get backOn => 'vissza.';

  @override
  String get backToChat => 'Vissza a chathez';

  @override
  String get backToFolder => 'Vissza a mappához';

  @override
  String get backToSignIn => 'Vissza a bejelentkezéshez';

  @override
  String get backendChannel => 'Háttércsatorna';

  @override
  String get backendOnThisComputer => 'Háttér ezen a számítógépen';

  @override
  String get backendSync => 'Háttér szinkronizálás';

  @override
  String get backgroundLocationNeeded => 'Helyszín szükséges a háttérben';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'A háttérszinkronizálás ütemezett marad Androidon';

  @override
  String get badState => 'Rossz állapot: ';

  @override
  String get baseImageAndSizeOfThe =>
      'A futó QEMU virtuális gépek alapképe és mérete ';

  @override
  String get baseUrlOptional => 'Alap URL (nem kötelező)';

  @override
  String get baseUrlTokenLocal => 'alap URL-token helyi';

  @override
  String get basicAuthentication => 'Alapvető hitelesítés';

  @override
  String get behaviorModules => 'Viselkedési modulok';

  @override
  String get behaviorNotes => 'viselkedési jegyzetek';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Bitwarden hitelesítő bróker';

  @override
  String get bitwardenItem => 'Bitwarden elem';

  @override
  String get bitwardenServer => 'Bitwarden szerver';

  @override
  String get blankUsesCommon => 'Az üres „közönséges”';

  @override
  String get blankUsesTheDefaultCallback =>
      'Az Üres az alapértelmezett visszahívást használja';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Az üres értékek a szolgáltató alapértelmezett értékeit használják.';

  @override
  String get block => 'Blokk';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return '$arg1 bejövő üzenete blokkolva.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'BlueBubbles kompatibilis híd';

  @override
  String get bluebubblesServerUrl => 'BlueBubbles szerver URL-je';

  @override
  String get botToken => 'Bot token';

  @override
  String get botTokenAndApprovedChats => 'Bot token és jóváhagyott csevegés';

  @override
  String get botTokenAndServerChannelAccess =>
      'Bot token és szerver/csatorna hozzáférés';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bot token, Events API és csatorna hozzáférés';

  @override
  String get botUserId => 'Bot felhasználói azonosító';

  @override
  String get botUsername => 'Bot felhasználónév';

  @override
  String get brandName => 'Márkanév';

  @override
  String get braveSearch => 'Bátor keresés';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Híd minden olyan szolgáltatót, amely képes közzétenni és fogadni a webhook hasznos terheit.';

  @override
  String get bringYourOwnKey => 'hozza a saját kulcsát';

  @override
  String get bringYourOwnKey2 => 'Hozd a saját kulcsodat';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'A böngésző, a Linux asztali számítógép, a fájlok, a terminál és a Python egy állandó felhőalapú számítógépen osztoznak.';

  @override
  String get browserLogin => 'Böngésző bejelentkezés';

  @override
  String get browserScripting => 'Böngésző szkriptelés';

  @override
  String get call => 'Hívjon';

  @override
  String get callAgent => 'Hívja az ügynököt';

  @override
  String get callUser => 'Felhasználó hívása';

  @override
  String get calledByName => 'Nevén szólítva';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Feladatokat delegálhat más ügynökökre';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Delegálható a $arg1-re';
  }

  @override
  String get canReceiveDelegatedTasks => 'Képes átruházott feladatokat fogadni';

  @override
  String get cancel => 'Mégsem';

  @override
  String get cancelTask => 'Feladat megszakítása';

  @override
  String get cannotPreview => 'Az előnézet nem tekinthető meg';

  @override
  String get cannotReceiveDelegatedTasks => 'nem kaphat átruházott feladatokat';

  @override
  String get cannotRunYet => 'még nem futhat.';

  @override
  String get capturedThePage => 'Lefoglalta az oldalt';

  @override
  String get category => 'Kategória';

  @override
  String chainArg1(Object? arg1) {
    return 'Lánc: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Módosítsa a beállítási módot';

  @override
  String get channel => 'Csatorna';

  @override
  String get channelAccessToken => 'Csatorna hozzáférési token';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Csatorna: $arg1$arg2 | Frissítési verzió: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory =>
      'Csatorna hatókörű társadalmi emlékezet';

  @override
  String get channels => 'Csatornák';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'Chat ID';

  @override
  String get chatMode => 'Chat mód';

  @override
  String get chatModel => 'Chat modell';

  @override
  String get checkAutomaticallyOnLaunch => 'Automatikus ellenőrzés indításkor';

  @override
  String get checkForMessagesEveryMs => 'Üzenetek ellenőrzése minden (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Az új üzenetek automatikus ellenőrzése';

  @override
  String get checkNow => 'Ellenőrizze most';

  @override
  String get checkYourEmailToConfirmYour =>
      'A bejelentkezés előtt ellenőrizze e-mailjeit NeoAgent-fiókjának megerősítéséhez.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Ellenőrzött $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Válasszon egy kategóriát, vagy keressen az összes beállítás között.';

  @override
  String get chooseAPerson => 'Válassz egy személyt';

  @override
  String get chooseAProjectFolder => 'Válasszon ki egy projekt mappát';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Válassza ki az alapértelmezett beállításokat a csevegéshez, az ügynökökhöz, a tartalék viselkedéshez és az intelligens útválasztáshoz.';

  @override
  String get chooseGroups => 'Válasszon csoportokat';

  @override
  String get chooseHowMuchYouWantTo =>
      'Válassza ki, mennyit szeretne most konfigurálni. Mindkét opció később módosítható.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Válassza ki, hogyan induljon el ez a feladat. A kézi csak a Futtatás most funkcióval fut. Az órarend időalapú. Az integráció tüzet vált ki a csatlakoztatott hivatalos alkalmazásokból.';

  @override
  String get chooseOneToGetStartedNow =>
      'Válasszon egyet a kezdéshez. Később továbbiakat is hozzáadhat.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Válassza ki az élő modellt és hangot a Beállításokban.';

  @override
  String get chooseTheirGroup => 'Válassza ki a csoportjukat';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Válassza ki, hogy ez a személy hol beszélhet $arg1-vel. Ezt később módosíthatja a Ki tud üzenetet küldeni.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Válassza ki, hogy a $arg1 mely csoportokhoz csatlakozzon, még akkor is, ha senki nem jelöli meg. Előfordulhat, hogy ez a platform nem különbözteti meg a címkéket a szokásos üzenetektől.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Válassza ki, hogy a szerveren minden fiók mely modelleket választhatja ki, és ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Válassza ki, hogy a $arg1 kivel beszéljen, és mikor csatlakozik a csoportos csevegésekhez.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Válassza ki, hogy ki érheti el a $arg1-t, majd mentse el a módosításokat.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Válassza ki, hogy ki küldhet üzenetet az ügynöknek a WhatsApp-kártyán a „Ki tud üzenetet küldeni” szöveggel.';

  @override
  String get chooseYourDefaultModel =>
      'Válassza ki az\nalapértelmezett modellt.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'A Chromium, a fájlok, a szövegszerkesztő és a terminál mind elérhetők a Linux asztalról.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Törlés';

  @override
  String get clearAll => 'Minden törlése';

  @override
  String clearArg1(Object? arg1) {
    return 'Tiszta $arg1?';
  }

  @override
  String get clearFilter => 'Tiszta szűrő';

  @override
  String get clearFilters => 'Tiszta szűrők';

  @override
  String get clearSearch => 'Keresés törlése';

  @override
  String get clearView => 'Tiszta nézet';

  @override
  String get cliSession => 'CLI munkamenet';

  @override
  String get clickIsNotSupportedOnThis =>
      'a kattintás nem támogatott ezen a platformon.';

  @override
  String get clickOnceToBeginCapturing =>
      'Kattintson egyszer a rögzítés megkezdéséhez';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Kattintson, írja be, és lépjen kapcsolatba az asztali alkalmazásokkal.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kattintva: ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Kattintva a böngészőben';

  @override
  String get clientId => 'Ügyfél-azonosító';

  @override
  String get clientSecret => 'Ügyfél titka';

  @override
  String get close => 'Bezárás';

  @override
  String get closeJ => 'Bezárás (⌘J)';

  @override
  String get closeTeachMode => 'Zárja be a Tanítási módot';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Az ablak bezárásával a NeoAgent a háttérben futhat a tálca-hozzáféréssel, vagy teljesen kiléphet az asztali futási környezetből.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'A felhő és a saját üzemeltetésű példányok támogatottak. A helyi és magánhálózati URL-ek akkor működnek, ha a NeoAgent eléri őket.';

  @override
  String get cloudComputer => 'Felhő számítógép';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Felhőalapú számítógép · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'A felhőalapú számítógép beállításai mentve. Ezek alkalmazásához indítsa újra a kiszolgálót.';

  @override
  String get cloudComputerVm => 'Felhőalapú számítógép (VM)';

  @override
  String get cloudComputers => 'Felhő számítógépek';

  @override
  String get codeHosting => 'Kódtárhely';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Vesszővel elválasztott csatornanevek # nélkül.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Vesszővel elválasztva, például #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Vesszővel elválasztva. A probléma mindegyiknek meg kell jelennie.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'A parancs sikertelen ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Parancs szükséges.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'A parancskimeneti akkumulátor nem aktív.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'A parancskimenet feltöltése sikertelen ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'A parancs kimeneti feltöltése kihagyta a műtermék metaadatait.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'A parancs kimenete már véglegesítésre került.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Parancsok és alkalmazások';

  @override
  String get commandsRunInTheSamePersistent =>
      'A parancsok ugyanazon az állandó számítógépen futnak, amelyet a látható asztal is használ.';

  @override
  String get communityChatops => 'Közösség és ChatOps';

  @override
  String get completeSetup => 'Teljes beállítás';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Fejezze be a munkafolyamatot az asztalon.';

  @override
  String get completed => 'Befejezve';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Teljesen blokkolva – az ügynök nem használhatja ezt a kategóriát.';

  @override
  String get computerShell => 'Számítógép héj';

  @override
  String get computerUsedByThisSession =>
      'A munkamenet által használt számítógép';

  @override
  String get computerWorkspace => 'Számítógépes munkaterület';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigurálható személyes webhook híd';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigurálható relé vagy webhook híd';

  @override
  String get configurableTalkWebhookBridge => 'Konfigurálható Talk webhook híd';

  @override
  String get configurableWebInboxBridge => 'Konfigurálható webes postafiók híd';

  @override
  String get configurableWebhookBridge => 'Konfigurálható webhook híd';

  @override
  String get configurableWebhooks => 'Konfigurálható Webhookok';

  @override
  String get configurationOrInTheEnvFile =>
      'Konfiguráció vagy az .env fájlban.';

  @override
  String get configure => 'Konfigurálás';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Konfigurálja a munkaterület viselkedését és a modell alapértelmezett beállításait.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Konfigurált $arg1';
  }

  @override
  String get confirmEmailChanges => 'Erősítse meg az e-mail módosításokat';

  @override
  String get confirmNewSignUps => 'Erősítse meg az új regisztrációkat';

  @override
  String get confirmPassword => 'Erősítse meg a jelszót';

  @override
  String get confirmPassword2 => 'Jelszó megerősítése';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'A bejelentkezés előtt erősítse meg e-mail-címét. Ellenőrizze a NeoAgent szolgáltatási e-mail üzenetét.';

  @override
  String get connect => 'Csatlakozás';

  @override
  String get connectAMessagingPlatform =>
      'Csatlakoztasson egy\nüzenetküldő platformot.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Csatlakoztasson egy nyilvános HTTPS Home Assistant végpontot egy hosszú élettartamú hozzáférési tokennel. A helyi, visszahurkolt és magánhálózati címeket a szerver blokkolja.';

  @override
  String get connectAccount => 'Fiók csatlakoztatása';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Csatlakoztassa az alkalmazásfiókokat egyenként, hogy az AI minden hivatalos integrációhoz a megfelelő fiókot tudja használni.';

  @override
  String connectArg1(Object? arg1) {
    return 'Csatlakoztassa a $arg1-t';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Csatlakoztasson annyi fiókot, amennyit csak szeretne. Minden alkalmazás más fiókot használhat.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Csatlakoztasson csatornákat, válassza ki, hogy $arg1 kivel beszéljen, és nézze meg a legutóbbi tevékenységet.';
  }

  @override
  String get connectInstance => 'Csatlakozás példány';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Először csatlakoztassa ezt az integrációt a fiók kiválasztásához.';

  @override
  String get connectToThisServer => 'Csatlakozás ehhez a szerverhez';

  @override
  String get connectWhatsapp => 'Csatlakoztassa a WhatsApp-ot';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Csatlakoztassa Nextcloud-példányát, beleértve a saját üzemeltetésű kiszolgálókat is. A NeoAgent megnyitja a Nextcloud saját bejelentkezési oldalát, így jelszóval, SSO-val vagy 2FA-val jelentkezhet be.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Csatlakoztassa saját üzemeltetésű NeoRecall szerverét. A NeoAgent csak olvasási hozzáférést kap a helyi kereséshez, az emlékekhez és az átiratokhoz, miután jóváhagyta az OAuth képernyőt.';

  @override
  String get connected => 'Csatlakozva';

  @override
  String get connectedAccount => 'Kapcsolt fiók';

  @override
  String connectedArg1(Object? arg1) {
    return 'Csatlakoztatva a $arg1';
  }

  @override
  String get connectedInstance => 'Csatlakoztatott példány';

  @override
  String get connectedNeorecallUser => 'Csatlakozott NeoRecall felhasználó';

  @override
  String get connectedNextcloudUser => 'Csatlakozott Nextcloud-felhasználó';

  @override
  String get connectedServer => 'Csatlakoztatott szerver';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Csatlakozás az élő hangmodellhez...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Csatlakozás #$arg1';
  }

  @override
  String get connectionId => 'Csatlakozási azonosító';

  @override
  String get connectionLooksGood => 'A kapcsolat jól néz ki.';

  @override
  String get connectionMethod => 'Csatlakozási mód';

  @override
  String get containsTextOptional => 'Szöveget tartalmaz (nem kötelező)';

  @override
  String get content => 'Tartalom';

  @override
  String get contentSecurityPolicy => 'tartalombiztonsági szabályzat';

  @override
  String get continue2 => 'Folytatás';

  @override
  String get continueFullSetup => 'Folytassa a teljes beállítást';

  @override
  String get continueRun => 'Folytassa a futást';

  @override
  String get continueToSetup => 'Folytassa a beállítással';

  @override
  String get controlSurface => 'VEZÉRLŐFELÜLET';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Szabályozza a $arg1 szerszámokhoz való hozzáférést.';
  }

  @override
  String get conversation => 'Beszélgetés';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'A beszélgetés azonosítója akkor használatos, amikor ez az ügynök csevegést indít.';

  @override
  String get cookieSetup => 'Cookie-beállítás';

  @override
  String get cookiesNotConfigured => 'A cookie-k nincsenek konfigurálva';

  @override
  String get copiedAsCsv => 'CSV-ként másolva';

  @override
  String get copiedDebugInfo => 'Hibakeresési adatok másolva';

  @override
  String get copiedExportForTheLast5 =>
      'Az utolsó 5 üzenet exportálása másolva';

  @override
  String get copiedFullPrompt => 'Teljes prompt másolva';

  @override
  String get copiedLogs => 'Másolt naplók';

  @override
  String get copiedRunId => 'Futtatási azonosító másolva';

  @override
  String get copy => 'Másolás';

  @override
  String get copyAll => 'Az összes másolása';

  @override
  String get copyCodes => 'Kódok másolása';

  @override
  String get copyCsv => 'CSV másolása';

  @override
  String get copyDebugInfo => 'Hibakeresési adatok másolása';

  @override
  String get copyLink => 'Link másolása';

  @override
  String get copyLogs => 'Naplók másolása';

  @override
  String get copyPrompt => 'Prompt másolása';

  @override
  String get copyResponse => 'Válasz másolása';

  @override
  String get copyRunId => 'Futtatásazonosító másolása';

  @override
  String get copyWebhookUrl => 'Webhook URL másolása';

  @override
  String get core => 'Core';

  @override
  String get coreMemory => 'központi memória';

  @override
  String get coreServicesThisServerDependsOn =>
      'Az alapvető szolgáltatások, amelyektől ez a szerver függ.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domain https nyilvános URL eredete';

  @override
  String get couldHelp => 'Segíthet';

  @override
  String get couldNotApproveQrLogin =>
      'Nem sikerült jóváhagyni a QR-bejelentkezést.';

  @override
  String get couldNotApproveQrPairing =>
      'Nem sikerült jóváhagyni a QR-párosítást.';

  @override
  String get couldNotConnect => 'Nem sikerült csatlakozni.';

  @override
  String get couldNotCreateBinding => 'Nem sikerült kötést létrehozni.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Nem sikerült törölni fiókját: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Nem sikerült leválasztani a Bitwardent.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Nem sikerült leválasztani az Otthoni asszisztenst.';

  @override
  String get couldNotDisconnectNeorecall =>
      'Nem sikerült leválasztani a NeoRecallt.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Nem sikerült leválasztani a Nextcloudot.';

  @override
  String get couldNotDisconnectTrello => 'Nem sikerült leválasztani a Trellót.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Nem sikerült exportálni az adatokat: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Nem sikerült betölteni a döntéseket';

  @override
  String get couldNotLoadUsageData =>
      'Nem sikerült betölteni a használati adatokat.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Nem sikerült automatikusan megnyitni a Linux beállításait.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Nem sikerült megnyitni a szolgáltatói linkoldalt.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Nem sikerült megnyitni a szolgáltató bejelentkezési oldalát.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Nem sikerült megnyitni a kiadási eszközt.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Nem sikerült megnyitni a Trellót a böngészőben.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Nem sikerült megnyitni a munkaterület-fájl letöltését.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Nem sikerült beolvasni az Android alkalmazáscsomagot.';

  @override
  String get couldNotReadTheApk => 'Nem sikerült beolvasni az APK-t.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Nem sikerült eltávolítani a kulcsot: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Nem sikerült menteni az ügynököt.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Nem sikerült menteni a Bitwarden beállítást.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Nem sikerült menteni a Home Assistant beállítását.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Nem sikerült menteni a NeoRecall beállítását.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nem sikerült menteni a Nextcloud beállítását.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Nem sikerült menteni a Trello beállítását.';

  @override
  String get couldNotSendConfirmationEmail =>
      'nem tudott visszaigazoló e-mailt küldeni';

  @override
  String get couldNotStart => 'Nem sikerült elindítani';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Létrehozása';

  @override
  String get createAPasswordFirstToChange =>
      'Először hozzon létre egy jelszót a fiók e-mail-címének megváltoztatásához.';

  @override
  String get createAPasswordOrLinkAnother =>
      'hozzon létre egy jelszót, vagy kapcsoljon össze egy másik szolgáltatót, mielőtt eltávolítaná ezt a bejelentkezési módot';

  @override
  String get createATaskWhileThisAgent =>
      'Hozzon létre egy feladatot, amíg ez az ügynök ki van választva.';

  @override
  String get createLink => 'Link létrehozása';

  @override
  String get createOrModifyFilesInYour =>
      'Fájlokat hozhat létre vagy módosíthat a munkaterületén.';

  @override
  String get createPassword => 'Jelszó létrehozása';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Hozzon létre speciális robotokat külön memóriával, beállításokkal, eszközökkel és fiók-hozzárendelésekkel.';

  @override
  String get createTheFirstAccount => 'Hozd létre az első fiókot';

  @override
  String get createUpdateOrDeleteSkills =>
      'Készségek létrehozása, frissítése vagy törlése.';

  @override
  String get creatingYourSkill => 'Képességed kialakítása…';

  @override
  String get credentialBindings => 'Hitelesítési adatok kötései';

  @override
  String get credentialUse => 'Hitelesítési adatok használata';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Cron alapú ismétlődő futtatások és egyszeri időzített végrehajtás.';

  @override
  String get cronExpression => 'Cron kifejezés';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter futtatja a lekérdezést.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + szóköz';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Jelenlegi e-mail cím: $arg1';
  }

  @override
  String get currentPassword => 'Jelenlegi jelszó';

  @override
  String get currentPasswordIsIncorrect => 'a jelenlegi jelszó helytelen';

  @override
  String get currentTwoStepLoginCode =>
      'Jelenlegi kétlépcsős bejelentkezési kód';

  @override
  String get customAccess => 'Egyéni hozzáférés';

  @override
  String get customCron => 'Egyedi Cron';

  @override
  String get customCronMustHave5Fields =>
      'Az egyéni Cronnak 5 mezővel kell rendelkeznie.';

  @override
  String get customEndpoint => 'egyéni végpont';

  @override
  String get customField => 'Egyéni mező';

  @override
  String get customHeader => 'Egyéni fejléc';

  @override
  String get customHeadersJson => 'Egyéni fejlécek (JSON)';

  @override
  String get customOpenaiCompatible => 'Egyedi OpenAI-kompatibilis';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Egyéni OpenAI-kompatibilis végpont';

  @override
  String get customOutgoingUrl => 'Egyéni kimenő URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Naponta';

  @override
  String get dailyRecap => 'Napi összefoglaló';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'adatbázis-lekérdezés válasszon csv-sablonokat';

  @override
  String dayArg1(Object? arg1) {
    return '$arg1 nap';
  }

  @override
  String get dayOfMonth => 'A hónap napja';

  @override
  String get decideWhichToolsYourAgentMay =>
      'döntse el, hogy az ügynöke milyen eszközöket használhat. Látják a nevedet és ';

  @override
  String get decisionHigherUpTheChainWins =>
      'döntés feljebb a lánc nyer, és zárat mutat a ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'A döntések itt jelennek meg, mivel a $arg1 a jóváhagyott $arg2 csoportokat olvassa. Csak a legfrissebb 30 marad meg, és a szerver újraindulásakor visszaáll.';
  }

  @override
  String get decline => 'Elutasítás';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'mélyfutás · $arg1 lépés';
  }

  @override
  String get deepgramKey => 'Deepgram kulcs';

  @override
  String get default2 => 'Alapértelmezett';

  @override
  String get default3 => 'ALAPÉRTELMEZETT';

  @override
  String defaultArg1(Object? arg1) {
    return 'Alapértelmezett ($arg1)';
  }

  @override
  String get defaultConversation => 'Alapértelmezett beszélgetés';

  @override
  String get defaultForNewGroups => 'Új csoportok alapértelmezett beállítása';

  @override
  String get defaultGroupParticipation => 'Alapértelmezett csoportos részvétel';

  @override
  String get defaultNeoagentWorkspace =>
      'Alapértelmezett NeoAgent munkaterület';

  @override
  String get defaultOpenai => 'Alapértelmezett (OpenAI)';

  @override
  String get defaultRateLimits => 'Alapértelmezett sebességkorlátok';

  @override
  String get defaultRateLimitsSaved =>
      'Az alapértelmezett sebességkorlátok mentve.';

  @override
  String get defaultRecommended => 'Alapértelmezett (ajánlott)';

  @override
  String get defaultRouting => 'Alapértelmezett útválasztás';

  @override
  String get defaultSpace => 'Alapértelmezett tér';

  @override
  String get delete => 'Törölje';

  @override
  String get deleteAccount => 'Fiók törlése';

  @override
  String get deleteAccountPermanently => 'Véglegesen törli a fiókot?';

  @override
  String get deleteAnAccount => 'Fiók törlése';

  @override
  String deleteArg1(Object? arg1) {
    return 'Törli a @$arg1-t?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Törlés ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Véglegesen törli a $arg1 $arg2 elemet?';
  }

  @override
  String get deleteBinding => 'Kötés törlése';

  @override
  String get deleteCoreMemoryEntry => 'Törli az alapmemória bejegyzést?';

  @override
  String get deleteForever => 'Törölje örökre';

  @override
  String get deleteMcpServer => 'Törli az MCP-kiszolgálót?';

  @override
  String get deleteMemory => 'Törli a memóriát?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'A törlés véglegesen törli a fiókot és minden adatát ';

  @override
  String get deleteRun => 'Törli a futtatást?';

  @override
  String get deleteRun2 => 'Futtatás törlése';

  @override
  String get deleteSelectedMemories => 'Törli a kiválasztott emlékeket?';

  @override
  String get deleteSession => 'Törli a munkamenetet?';

  @override
  String get deleteSkill => 'Törli a készségeket?';

  @override
  String get deleteTask => 'Törli a feladatot?';

  @override
  String deletedArg1(Object? arg1) {
    return '\"$arg1\" törölve.';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'A @$arg1 és az összes adatuk törölve.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'A törlés eltávolítja az összes beszélgetést, emléket, fájlt, feladatot és ';

  @override
  String get deliverableArtifactProduced => 'Szállítandó műtárgy készült';

  @override
  String get deliverableCompleted => 'A leszállítás kész';

  @override
  String get deliverableExecutionStarted =>
      'A szállítható végrehajtás megkezdődött';

  @override
  String get deliverableSelected => 'Szállítandó kiválasztva';

  @override
  String get deliverableValidationFailed =>
      'A kézbesíthető ellenőrzés sikertelen';

  @override
  String get deliverableValidationStarted =>
      'A szállítható érvényesítés megkezdődött';

  @override
  String get deny => 'Megtagadás';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Írja le az eredményt, majd mutassa be az asztalon';

  @override
  String get describeWhatToBuildOrChange =>
      'Írja le, mit kell építeni vagy megváltoztatni…';

  @override
  String get description => 'Leírás';

  @override
  String get desktopApp => 'Asztali alkalmazás';

  @override
  String get desktopAppControlsAvailable =>
      'Az asztali alkalmazásvezérlők elérhetők';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Az asztali rögzítés nem érhető el ezen a platformon.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Az asztali parancs kimenetének feltöltése megszakítva.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Az asztali társparancs törölve.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Az asztali társkapcsolat időtúllépése lejárt.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Az asztali társ kézfogás ideje lejárt.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Az asztali kísérő itt nem érhető el.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Az asztali kísérő helyileg szünetel.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Az asztali kísérőüzenetek kezelése nem sikerült: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Az asztali kísérőengedély-beállítások nem érhetők el az interneten.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Az asztali kísérőengedély-beállítások nem érhetők el ezen a platformon.';

  @override
  String get desktopCompanionRejected => 'Az asztali társ elutasítva.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Az asztali kísérő válasza sikertelen: $arg1';
  }

  @override
  String get desktopControl => 'Asztali vezérlés';

  @override
  String get desktopFailedToStart => 'Asztal nem indult';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Az asztali adatfolyam rögzítése nem sikerült: $arg1';
  }

  @override
  String get destinationId => 'Cél azonosítója';

  @override
  String get deviceAccess => 'Eszköz hozzáférés';

  @override
  String get deviceSettings => 'Eszközbeállítások';

  @override
  String get devices => 'Eszközök';

  @override
  String get diagnosticsSaved => 'Diagnosztika mentve.';

  @override
  String get directBluebubblesImessageBridge =>
      'Közvetlen BlueBubbles iMessage híd';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'A közvetlen üzenetek továbbra is reagálnak. Az engedélyezett csoportok az alábbi részvételi módot használják.';

  @override
  String get directoryDoesNotExist => 'A címtár nem létezik.';

  @override
  String get disable2fa => 'A 2FA letiltása';

  @override
  String get disableAll => 'Az összes letiltása';

  @override
  String get discard => 'Eldobni';

  @override
  String get disconnect => 'Leválasztás';

  @override
  String get disconnectHomeAssistant => 'Leválasztja az Otthoni asszisztenst?';

  @override
  String get disconnectNeorecall => 'Leválasztja a NeoRecallt?';

  @override
  String get disconnectNextcloud => 'Lekapcsolja a NextCloudot?';

  @override
  String get disconnectPlatform => 'Válassza le a platformot';

  @override
  String get disconnectTrello => 'Lekapcsolja a Trellót?';

  @override
  String get discoveryFailed => 'A felfedezés nem sikerült';

  @override
  String get dismiss => 'Elvetés';

  @override
  String get displayIdIsRequired => 'Megjelenítési azonosító szükséges.';

  @override
  String get displayName => 'Megjelenítési név';

  @override
  String get displayNameMustBe64Characters =>
      'A megjelenített név legfeljebb 64 karakterből állhat.';

  @override
  String get displayNameSaved => 'Megjelenítési név mentve.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Ne adja meg felhasználónevét vagy e-mail címét.';

  @override
  String get done => 'Kész';

  @override
  String get downloadACopyOfYourData =>
      'Töltse le adatainak másolatát. A rendszergazdai fiókok nem törölhetők ';

  @override
  String get downloadACopyOfYourData2 =>
      'Töltse le adatainak másolatát, vagy véglegesen törölje fiókját. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Töltse le a $arg1-t';
  }

  @override
  String get downloadUpdate => 'Frissítés letöltése';

  @override
  String get downloadingTheNeoagentBackend =>
      'A NeoAgent háttérprogram letöltése';

  @override
  String get draft => 'Piszkozat';

  @override
  String get dragIsNotSupportedOnThis =>
      'a drag nem támogatott ezen a platformon.';

  @override
  String get draggedOnTheScreen => 'Húzva a képernyőn';

  @override
  String get dropAnApkOrApkBundle =>
      'A telepítéshez dobjon ide egy APK-t vagy APK-csomagot';

  @override
  String get dropApkOrApksHere => 'Dobja ide az APK-t vagy az .apks-t';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Tartós utasítások a hanghoz és az interakciós stílushoz. A biztonsági és végrehajtási szabályok továbbra is elsőbbséget élveznek.';

  @override
  String get eGAlexSLaptop => 'például Alex laptopja';

  @override
  String get eGMyLocalServer => 'pl. A helyi szerverem';

  @override
  String get edit => 'Szerkesztés';

  @override
  String get editAgent => 'Ügynök szerkesztése';

  @override
  String get editCoreMemoryEntry => 'Szerkessze az alapvető memóriabejegyzést';

  @override
  String get editInstructions => 'Szerkessze az utasításokat';

  @override
  String get editMcpServer => 'MCP Server szerkesztése';

  @override
  String get editTask => 'Feladat szerkesztése';

  @override
  String editedArg1(Object? arg1) {
    return 'Szerkesztette $arg1';
  }

  @override
  String get email => 'E-mail';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'E-mail fióktulajdonosok a szokatlannak tűnő bejelentkezésekről.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'E-mail küldése a fióktulajdonosoknak, ha fiókadatok megváltoznak.';

  @override
  String get emailCode => 'E-mail kód';

  @override
  String get emailConfirmationRequired => 'email megerősítés szükséges';

  @override
  String get emailIsAlreadyInUse => 'az email már használatban van';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail mentve. Ha megerősítésre van szükség, ellenőrizze az új címet a NeoAgent megerősítő hivatkozásért.';

  @override
  String get emailSettingsSaved => 'Az e-mail beállítások elmentve.';

  @override
  String get emailUnverified => 'Az e-mail-cím nem ellenőrizve';

  @override
  String get empty => 'Üres';

  @override
  String get emptyFile => 'Üres fájl';

  @override
  String get emptyFolder => 'Üres mappa';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Az Empty a szerver alapértelmezett értékét használja ($arg1).';
  }

  @override
  String get enable2fa => '2FA engedélyezése';

  @override
  String get enableAll => 'Összes engedélyezése';

  @override
  String get enableBehaviorModules => 'Viselkedési modulok engedélyezése';

  @override
  String get enableOrDisableModels => 'Modellek engedélyezése vagy letiltása';

  @override
  String get enabled => 'Engedélyezve';

  @override
  String get encryptedPrivateToYourAccount => 'Titkosított, privát fiók';

  @override
  String get end => 'Vége';

  @override
  String get endCall => 'Hívás befejezése';

  @override
  String get endVoiceCall => 'Befejezi a hanghívást?';

  @override
  String get endpoint => 'Végpont';

  @override
  String get enterAPassword => 'Adjon meg egy jelszót.';

  @override
  String get enterAUsername => 'Adjon meg egy felhasználónevet.';

  @override
  String get enterAValidEmailAddress => 'Adjon meg egy érvényes e-mail címet.';

  @override
  String get enterAnAddressManually => 'Adjon meg egy címet manuálisan';

  @override
  String get enterAnApiKeyFirst => 'Először írjon be egy API-kulcsot.';

  @override
  String get enterInviteLink => 'Írja be a meghívó linkjét';

  @override
  String get enterTheAddressOfANeoagent => 'Adja meg a NeoAgent szerver címét.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Adja meg a $arg1 által megadott adatokat, hogy a $arg2 üzeneteket küldhessen és fogadhasson.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Adja meg 2FA vagy helyreállítási kódját.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'A módosításhoz adja meg jelenlegi jelszavát.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Adja meg jelenlegi jelszavát az e-mail módosítások mentéséhez.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Adja meg NeoAgent fiókjának adatait.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Adja meg felhasználónevét vagy fiókjának e-mail-címét. A NeoAgent visszaállítási hivatkozást küld, ha megfelel a fióknak.';

  @override
  String get enterYourUsernameOrEmail =>
      'Adja meg felhasználónevét vagy e-mail címét.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entitás: $arg1';
  }

  @override
  String get environment => 'Környezet';

  @override
  String get error => 'Hiba';

  @override
  String errorArg1(Object? arg1) {
    return '\nhiba: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Hibák a legutóbbi naplóból, üzenet szerint csoportosítva.';

  @override
  String get errorsProblemsFailures => 'hibák problémák kudarcok';

  @override
  String get eventTypesCommaSeparated =>
      'Eseménytípusok (vesszővel elválasztva)';

  @override
  String get every15Minutes => '15 percenként';

  @override
  String get every30Minutes => '30 percenként';

  @override
  String get everyAccountOnThisServerLoses =>
      'Ezen a szerveren minden fiók elveszíti ezt a megosztott kulcsot. Fiókok ';

  @override
  String get everyAccountOnThisServerUses =>
      'Ezen a szerveren minden fiók ezt a címet használja: ';

  @override
  String get everyActiveSessionForThisAccount =>
      'A fiók minden aktív munkamenete véget ér. Be tudnak jelentkezni ';

  @override
  String get everyDay0800 => 'Minden nap · 08:00';

  @override
  String get everyDay2000 => 'Minden nap · 20:00';

  @override
  String get everyHour => 'Minden órában';

  @override
  String get everyRunOnThisServerAll =>
      'Minden futás ezen a szerveren, minden alkalommal.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Minden érzékeny eszköz jóváhagyást igényel, minden alkalommal.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Minden eszköz kérdezés nélkül fut, kivéve a személyét ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Ezekben a csoportokban, csatornákban vagy szobákban mindenki beszélhet a $arg1-vel.';
  }

  @override
  String get everyoneInThisGroup => 'Mindenki ebben a csoportban';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Minden, amit a $arg1 kikapcsolt az ügynökénél, megérkezik ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Minden más ki van kapcsolva.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Minden elérhető az asztalról.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Minden, amit az ügynök használhat: hivatalos integrációk, MCP-kiszolgálók és készségek.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Minden, amit kikapcsolt a $arg1 esetében, visszatér ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Pontos webes források engedélyezik a keresztirányú kéréseket, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Futtassa a JavaScriptet a böngésző munkamenetén belül.';

  @override
  String get execution => 'Végrehajtás';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'A végrehajtás részletei ehhez a futtatáshoz nem állnak rendelkezésre.';

  @override
  String get executionPlanCreated => 'Kiviteli terv készült.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return '$arg1 gyakorlatok';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[kilépés a $arg1-ből]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Lejár a $arg1';
  }

  @override
  String get explainThisProject => 'Magyarázza el ezt a projektet';

  @override
  String exploredArg1(Object? arg1) {
    return 'Feltárt $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Feltárt $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Felfedezte a munkaterületet';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Az exportálás sikertelen: $arg1';
  }

  @override
  String get exportLast5Messages => 'Az utolsó 5 üzenet exportálása';

  @override
  String get exportMyData => 'Exportálja az adataimat';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'A külső böngésző indítása nem sikerült a $arg1 kilépési kóddal.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'A külső böngészőindítás nem támogatott ezen a platformon.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'A külső böngésző indítása időtúllépést szenvedett.';

  @override
  String get externalMcpTools => 'Külső és MCP eszközök';

  @override
  String get extraButtons => 'Extra gombok';

  @override
  String get extractingTheNeoagentRuntime =>
      'A NeoAgent futtatókörnyezet kibontása';

  @override
  String get failed => 'Sikertelen';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Nem sikerült csatlakoztatni: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nem sikerült a $arg1 csatlakoztatása: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'A „$arg1” törlése nem sikerült: $arg2';
  }

  @override
  String get failedToFetch => 'nem sikerült lekérni';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Nem sikerült generálni: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Nem sikerült elindítani a külső böngészőt az url_launcher segítségével.';

  @override
  String get failedToLaunchOauthFlow =>
      'Nem sikerült elindítani az OAuth-folyamatot.';

  @override
  String get failedToLoadPolicies => 'Nem sikerült betölteni a házirendeket';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Nem sikerült menteni: $arg1';
  }

  @override
  String get failedToSaveMcpServer =>
      'Nem sikerült menteni az MCP-kiszolgálót.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Nem sikerült menteni a kijelölést: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Nem sikerült értesítést küldeni a háttérrendszernek: $arg1';
  }

  @override
  String get fair => 'Fair';

  @override
  String get fasterReplies => 'Gyorsabb válaszok';

  @override
  String get fewerModelCalls => 'Kevesebb modellhívás';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'üres mező a beépített alapértelmezett érték visszaállításához.';

  @override
  String get fileExceedsThe1MibEditor =>
      'A fájl meghaladja az 1 MiB szerkesztő korlátot.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'A fájl meghaladja a támogatott méretkorlátot.';

  @override
  String get fileWrites => 'Fájl írja';

  @override
  String get filename => 'Fájlnév';

  @override
  String get files => 'Fájlok';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'A NeoAgent által ebben a munkamenetben írt vagy szerkesztett fájlok itt jelennek meg.';

  @override
  String get filesSavedByAllUsers =>
      'Az összes felhasználó által mentett fájlok';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Töltse ki a jóváhagyott bejelentkezéseket vagy hitelesítse a kéréseket anélkül, hogy titkokat mutatna meg az AI-nak.';

  @override
  String get finalResponse => 'Végső válasz';

  @override
  String get findAPlatform => 'Keressen egy platformot';

  @override
  String get findAndFixABug => 'Találja meg és javítsa ki a hibát';

  @override
  String get findRecentChats => 'Keresse meg a legutóbbi csevegéseket';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'A megfelelő NeoAgent futási környezet megtalálása';

  @override
  String get finish => 'Befejezés';

  @override
  String get finishAtTheScheduledTime => 'Fejezd be a tervezett időpontban';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Fejezze be a $arg1 szolgáltatásba való bejelentkezést a böngészőben, majd csatlakozzon újra.';
  }

  @override
  String get flowGraph => 'Flow grafikon';

  @override
  String get flutterApp => 'Flutter alkalmazás';

  @override
  String get focusedExecutionProfile => 'Fókuszált végrehajtási profil';

  @override
  String get folderIdOptional => 'Mappaazonosító (opcionális)';

  @override
  String get folderUnavailable => 'A mappa nem érhető el';

  @override
  String get forExampleHttpsMatrixOrg => 'Például https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Hosztolt vagy speciális hálózati beállításokhoz';

  @override
  String get forLinksInEmailsBlankUses =>
      'Az e-mailekben található linkekre. Az Üres a szerver nyilvános URL-jét használja.';

  @override
  String get forgotPassword => 'Elfelejtetted a jelszavad?';

  @override
  String get frameUnavailable => 'A keret nem elérhető';

  @override
  String freshnessArg1(Object? arg1) {
    return 'frissesség: $arg1';
  }

  @override
  String get fridays1700 => 'péntek · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'A BotFathertől a bot létrehozása után.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Mostantól a $arg1 dönti el, hogy az ügynöke milyen eszközöket használhat. Ők ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'A Discord fejlesztői portálról, a robotod alatt.';

  @override
  String get fromTheLineDevelopersConsole => 'A LINE Developers Console-ból.';

  @override
  String get fromTheMatrixClientOrBot => 'A Matrix kliens vagy bot fiókból.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'A twitchapps.com/tmi webhelyről vagy a Twitch fejlesztői alkalmazásáról.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Teljes prompt';

  @override
  String get fullSetup => 'Teljes beállítás';

  @override
  String get general => 'tábornok';

  @override
  String get generalSettings => 'Általános beállítások';

  @override
  String get generalSettingsSaved => 'Általános beállítások mentve.';

  @override
  String get generateAPromptForAnotherAi =>
      'Hozzon létre egy promptot egy másik AI-hoz, illessze be ide a választ a memóriák importálásához.';

  @override
  String get generatePrompt => 'Prompt generálása';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Geokerítés követési hiba: $arg1';
  }

  @override
  String get getInspired => 'Merítsen ihletet';

  @override
  String get githubCopilot => 'GitHub másodpilóta';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot és OpenAI Codex';

  @override
  String get githubIssueOpened => 'Megnyílt a GitHub probléma';

  @override
  String get neorecallMemoryCreated => 'NeoRecall memória létrehozva';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'A GitHub kiadásának ellenőrzése sikertelen volt a HTTP $arg1 használatával.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'A GitHub kiadásának hasznos tartalma nem volt kiadási lista.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'GitHub felhasználónév, amely megnyitotta a problémát';

  @override
  String get globalSecurityMode => 'Globális biztonsági mód';

  @override
  String get gmailMessageReceived => 'Gmail üzenet érkezett';

  @override
  String get good => 'Jó';

  @override
  String get goodAfternoon => 'Jó napot';

  @override
  String get goodEvening => 'Jó estét';

  @override
  String get goodMorning => 'Jó reggelt';

  @override
  String get goodPasswordALittleMoreLength =>
      'Jó jelszó. Kicsit hosszabb hossz erősebbé teszi.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'A GPT-Live az Ön OpenAI API-kulcsát, a Gemini Live pedig a Google AI-kulcsát használja. A változások a következő felhívásra vonatkoznak.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'A szinkronizálás előtt adja meg a Health Connect engedélyeit.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Csoport, csatorna vagy szoba';

  @override
  String get groupType => 'Csoport típusa';

  @override
  String get groupsAndChannels => 'Csoportok és csatornák';

  @override
  String groupsArg1(Object? arg1) {
    return 'Csoportok: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'A $arg1 még nem látott csoportjai ezt követik.';
  }

  @override
  String get handlesDirectTasksItself => 'A közvetlen feladatokat maga kezeli';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Kihangosított (szabadon beszélhet, bármikor megszakíthatja)';

  @override
  String get headerName => 'Fejléc neve';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Hírek az Önt érdeklő témákról, jelzésre szűrve.';

  @override
  String get health => 'Egészség';

  @override
  String get healthChecks => 'Egészségügyi vizsgálatok';

  @override
  String get healthConnect => 'egészségügyi kapcsolat';

  @override
  String get healthConnectIsNotAvailableOn =>
      'A Health Connect nem érhető el ezen az eszközön.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'A Health Connect szinkronizálási állapota és a tárolt háttérmérők.';

  @override
  String get healthStatusIsUnavailable => 'Az egészségi állapot nem elérhető.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Az Egészségügyi szinkronizálás csak Androidon érhető el.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Szív $arg1 rekordok';
  }

  @override
  String get heldBack => 'Visszatartott';

  @override
  String get helper => 'Segítő';

  @override
  String helperArg1(Object? arg1) {
    return 'Segítő: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'itt. Az admin visszavonása először a `neoagent admin revoke $arg1\' paranccsal.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'A magasabb értékek szelektívebbé teszik a NeoAgentet a csoportokban.';

  @override
  String get highlyRecommended => 'Erősen ajánlott';

  @override
  String get holdButton131ForTheAssistant =>
      'Tartsa lenyomva a 131-es gombot az asszisztens számára.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Beszélgetéshez tartsa lenyomva a Ctrl+Shift+Szóköz billentyűket';

  @override
  String get holdToTalk => 'Tartsa meg, hogy beszéljen.';

  @override
  String get holdToTalk2 => 'Tartsa meg, hogy beszéljen';

  @override
  String get home => 'Otthon';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Otthoni asszisztens hosszú életű hozzáférési token szükséges.';

  @override
  String get homeAssistantSetup => 'Otthoni asszisztens beállítása';

  @override
  String get homeAssistantUrl => 'Otthoni asszisztens URL';

  @override
  String get homeAssistantUrlIsRequired =>
      'A Home Assistant URL-címe kötelező.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Otthoni szerver token szobalekérdezéssel';

  @override
  String get homeserverUrl => 'Otthoni szerver URL-je';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'hosztolt szolgáltatás). Kulcsai titkosítottak, és csak az általuk használhatók ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Az IRC hálózat gazdagépneve, például irc.libera.chat';

  @override
  String get hourly => 'Óránként';

  @override
  String get hourlyInboxCheck => 'Óránkénti beérkező levelek ellenőrzése';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Mennyi ideig maradnak érvényesek a megerősítő linkek.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Milyen gyakran keres ez az ügynök új szobaüzeneteket.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Milyen gyakran keres ez az ügynök új jelzésüzeneteket.';

  @override
  String get howTeamsWork => 'Hogyan működnek a csapatok';

  @override
  String get howThisServerIsReachedPlus =>
      'Hogyan érhető el ez a szerver, plusz a szerverszintű kapcsolók.';

  @override
  String get httpsSessionCookie => 'https session cookie';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Ezt a kérést most nem tudtam teljesíteni. Kérjük, próbálja újra egy pillanat múlva.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Tétlen';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Ha a $arg1 webhook URL-t kér, illessze be, hogy az üzenetek elérjék a $arg2-t.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Ha a fióknak megerősített e-mailje van, a NeoAgent jelszó-visszaállító linket küld.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Ha a szolgáltatás tokent kér a kimenő kérésekhez.';

  @override
  String get ignoreGroups => 'Csoportok figyelmen kívül hagyása';

  @override
  String get ignoreThisChat => 'Hagyja figyelmen kívül ezt a csevegést';

  @override
  String get ignoredChannels => 'Figyelmen kívül hagyott csatornák';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Figyelmen kívül hagyott hibásan formázott asztali kísérőüzenet: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Hajtsa végre a fenti tervet.';

  @override
  String get implementThisPlan => 'Hajtsa végre ezt a tervet';

  @override
  String get implicitTls => 'Implicit TLS';

  @override
  String get import => 'Importálás';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Sikertelen importálás: $arg1';
  }

  @override
  String get importFromComputer => 'Importálás számítógépről';

  @override
  String get importMemoryTransfer => 'Memóriaátvitel importálása?';

  @override
  String get importance => 'Fontosság';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Importált $arg1 memóriák, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return '@$arg1 csapatában';
  }

  @override
  String get inBackground => 'háttérben';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Itt jelennek meg a bejövő és kimenő csatornaüzenetek.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Bejövő, alkalmazáson belüli hanghívások a NeoAgenttől';

  @override
  String get incomingMessages => 'Bejövő üzenetek';

  @override
  String get incomingNeoagentCall => 'Bejövő NeoAgent hívás';

  @override
  String get incomingNeoagentCall2 => 'BEJÖVŐ NEOAGENT HÍVÁS';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Bejövő webhook és kimenő visszahívások támogatása';

  @override
  String get incorporatingSteering => 'Kormányzást tartalmaz';

  @override
  String get input => 'Bemenet';

  @override
  String get inputMode => 'Beviteli mód';

  @override
  String get insertATemplate => 'Szúrjon be egy sablont';

  @override
  String get install => 'Telepítés';

  @override
  String get installASignedSelfContainedRuntime =>
      'Telepítsen aláírt, önálló futtatókörnyezetet. Node.js, npm, Git és terminál parancsok nem szükségesek.';

  @override
  String get installApk => 'Telepítse az APK-t';

  @override
  String get installApkBundle => 'Az APK/Bundle telepítése';

  @override
  String get installApkClickOrDropA =>
      'Az APK telepítése – kattintson vagy dobjon egy .apk fájlt';

  @override
  String get installNeoagent => 'Telepítse a NeoAgentet';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Telepítse a NeoAgentet erre a számítógépre terminál nélkül, vagy csatlakozzon egy már futóhoz.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Telepítse az új kiadásokat, és válassza ki, hogy a szerver melyik csatornát kövesse.';

  @override
  String get installTheBackend => 'Telepítse a háttérprogramot';

  @override
  String get installTheCoreWithExtraOptional =>
      'Telepítse a magot extra opcionális beállítással. Az AI-szolgáltató kulcsait utólag adják hozzá, ugyanúgy, mint a Gyorsindításhoz.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Telepítse a biztonságos magot, majd hozza létre fiókját. Ezután adja hozzá az AI-szolgáltató kulcsait.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Telepítve: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Telepítve: $arg1 • Utoljára ellenőrizve: $arg2';
  }

  @override
  String get instructions => 'Utasítások';

  @override
  String get integration => 'Integráció';

  @override
  String get integrationConnections => 'Integrációs kapcsolatok';

  @override
  String get integrationSettingsSaved => 'Az integrációs beállítások elmentve.';

  @override
  String get integrations => 'Integrációk';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrations/oauth/callback, és regisztrálja ugyanazt ';

  @override
  String get interruptAi => 'Az AI megszakítása';

  @override
  String get invalid2fa => 'érvénytelen 2fa';

  @override
  String get invalidArgumentS => 'Érvénytelen argumentum(ok): ';

  @override
  String get invalidCredentials => 'érvénytelen hitelesítő adatok';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Érvénytelen NeoAgent futásidejű jegyzék.';

  @override
  String get inviteLink => 'Meghívó link';

  @override
  String get inviteLinkReady => 'Meghívó link készen áll';

  @override
  String get inviteLinks => 'Meghívó linkek';

  @override
  String get iphoneApp => 'iPhone alkalmazás';

  @override
  String get issues => 'Kérdések';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'A problémák a napló betöltésekor jelennek meg.';

  @override
  String get itCanTBeUndone => 'Nem vonható vissza.';

  @override
  String get itMayHaveBeenDeleted => 'Lehet, hogy törölték.';

  @override
  String get javaRuntime => 'java futtatókörnyezet';

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
    return 'Csatlakozott a $arg1-hez';
  }

  @override
  String get joinedInTheLast7Days => 'Az elmúlt 7 napban csatlakozott';

  @override
  String get joiningATeam => 'Csatlakozás egy csapathoz';

  @override
  String get joiningIsOffHere => 'A csatlakozás itt ki van kapcsolva';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Az üzenet szövegét tartalmazó JSON-mező. Általában szöveges.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON mező, amely azonosítja, hogy kinek szól az üzenet.';

  @override
  String get jumpToLatest => 'Ugrás a legújabbra';

  @override
  String get justNow => 'csak most';

  @override
  String get keepNeoagentRunning => 'Folytassa a NeoAgent működését?';

  @override
  String get keepRunning => 'Fuss tovább';

  @override
  String get keepTaskRunning => 'Folytassa a feladat futását';

  @override
  String get keepTheVaultAvailable => 'Tartsa elérhetővé a trezort';

  @override
  String get keepThisLauncherUpToDate => 'Tartsa naprakészen ezt az indítót.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Tartsa nyitva ezt a panelt, amíg a platform meg nem erősíti a csatlakozást.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Tartsa láthatóan a munkamenet számítógépét';

  @override
  String get keepTrackOfYourAiUsage =>
      'Kövesse nyomon az AI használatát. A korlátokat betartatják a méltányos használat biztosítása érdekében az egész platformon.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Folytassa az alkalmazások szokásos használatát. A NeoAgent ugyanazon a képernyőn működik, és mindig megkérdezi, ha új hozzáférésre van szüksége.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Az eszköz csatlakoztatva tartása';

  @override
  String get key => 'Kulcs';

  @override
  String get keyIsRequired => 'Kulcs szükséges.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Kulcs-érték párok, amelyek a beszélgetések során megmaradnak.';

  @override
  String get knowledgeGraph => 'Tudásgráf';

  @override
  String get knowledgeView => 'Tudás nézet';

  @override
  String get labelOnlyYouSeeIt => 'Címke (csak te látod)';

  @override
  String get labelsOptional => 'Címkék (opcionális)';

  @override
  String get last24Hours => 'Az elmúlt 24 óra';

  @override
  String get last7Days => 'Az elmúlt 7 nap';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Az elmúlt 7 nap: futnak a $arg1 tokenek a $arg2-ben';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Utolsó $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Utolsó: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Utolsó, nem üres szinkronizálás · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Utolsó futás: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Utoljára $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Utolsó bejelentkezés $arg1';
  }

  @override
  String get lastSyncSummary => 'Utolsó szinkronizálás összefoglalója';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Utoljára használt: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Az utolsó ablak véget ért: $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'későbbi indítás is kikapcsolva.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Utolsó futam · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Az asztali alkalmazások elindítása nem támogatott ezen a platformon.';

  @override
  String get learnRoomNorms => 'Tanuld meg a szobanormákat';

  @override
  String get leave => 'Hagyja';

  @override
  String get leaveARedirectUriBlankTo =>
      'Hagyja üresen az átirányítási URI-t a <nyilvános URL>/api/ használatához';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Kilép a $arg1 csapatából?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Hagyja alapértelmezettként, hacsak nem szabta testre a BlueBubbles-t.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Hagyja üresen a tokent, hogy az aktuálisan tárolt token megmaradjon.';

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
    return 'Hagyja, hogy $arg1 irányítson engem';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Hagyja, hogy ebben a csoportban mindenki beszéljen a $arg1-vel.';
  }

  @override
  String get letItWorkWhileYouDon => 'Hagyja, hogy\nműködjön, amíg nem.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Hagyja, hogy a NeoAgent kattintson, gépeljen és mozogjon az alkalmazások között.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Hagyja, hogy a NeoAgent megértse, mi látható a képernyőn.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Hagyja, hogy valaki, akivel dolgozik, döntse el, milyen eszközöket használhat az ügynöke ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Hagyja, hogy ez a személy egy-egy üzenetet küldjön a $arg1 számára.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Engedje meg, hogy ez a személy itt beszéljen $arg1-vel, de ne privát chaten vagy más csoportokban.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Engedje meg, hogy ez a személy beszéljen $arg1-vel privát csevegésben és bármely általa megosztott csoportban.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1/$arg2$arg3 szint';
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
  String get linkCopied => 'Link másolva';

  @override
  String get linkExpiresAfter => 'A link ezután lejár';

  @override
  String get linkLifetimeHours => 'Link élettartama (óra)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'A link élettartamának 1 és 8760 óra között kell lennie.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'A link $arg1-ig érvényes.';
  }

  @override
  String get linkedSignInProviders => 'Kapcsolt bejelentkezési szolgáltatók';

  @override
  String get linuxApp => 'Linux alkalmazás';

  @override
  String listedArg1(Object? arg1) {
    return 'Felsorolt $arg1/';
  }

  @override
  String get listening => 'Hallgatás';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Élő végrehajtási előzmények, eszközlépések és válaszok.';

  @override
  String get liveModel => 'Élő modell';

  @override
  String get liveModelProvider => 'Élő modell szolgáltató';

  @override
  String get liveRun => 'Élő futás';

  @override
  String get liveVoice => 'Élő hang';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Élő hangkapcsolat nem érhető el.';

  @override
  String get liveVoiceConnectionWasClosed => 'Az élő hangkapcsolat megszakadt.';

  @override
  String get liveVoiceDefaults => 'Élő hang alapértelmezett beállításai';

  @override
  String get liveVoiceFailed => 'Az élő hang nem sikerült.';

  @override
  String get llmMemoryExportResponse => 'LLM memória export válasz';

  @override
  String get loadFailed => 'a betöltés nem sikerült';

  @override
  String get loadingExecutionDetails =>
      'A végrehajtás részleteinek betöltése...';

  @override
  String get loadingNeoagent => 'NeoAgent betöltése';

  @override
  String get loadingRunFlow => 'Futási folyamat betöltése…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'A helyi és magánhálózati URL-címek akkor támogatottak, ha a NeoAgent szerver el tudja őket érni. A hangot soha nem teszi ki a NeoAgent.';

  @override
  String get localApp => 'helyi alkalmazás';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Helyi háttértelepítés nem érhető el ezen a platformon.';

  @override
  String get localBaseImagePath => 'Helyi alapkép elérési útja';

  @override
  String get localComputerControlIsAvailableIn =>
      'A helyi számítógépvezérlés a NeoAgent asztali alkalmazásban érhető el macOS, Windows és Linux rendszeren.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Helyi számítógépes vezérlés itt nem érhető el.';

  @override
  String get localModelsUrl => 'helyi modellek URL-je';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'A helyi NeoAgent felfedezés átmenetileg nem érhető el.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'A NeoAgent alkalmazás helyi beállításai. A számítógépes vezérlés mindig az egyesített felhőszámítógépen keresztül fut.';

  @override
  String get localSetup => 'HELYI BEÁLLÍTÁS';

  @override
  String get locationCityOrPlace => 'Helyszín (város vagy hely)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Az időjárási események indításához hely szükséges';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'A LocationService inicializálása nem sikerült: $arg1';
  }

  @override
  String get logCopied => 'Napló másolva';

  @override
  String get loginPassword => 'Bejelentkezési jelszó';

  @override
  String get logout => 'Kijelentkezés';

  @override
  String get logs => 'Naplók';

  @override
  String get logsCopied => 'A naplók másolva.';

  @override
  String get logsOnThisComputer => 'Naplózás ezen a számítógépen';

  @override
  String get longLivedAccessToken => 'Hosszú életű hozzáférési token';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Hosszú távú visszaemlékezés, strukturált tények és tudásgrafikon.';

  @override
  String get lookedAtTheScreen => 'A képernyőre nézett';

  @override
  String get lookingOnThisComputerAndYour =>
      'Ezt a számítógépet és a helyi hálózatot nézi…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Előre tekint a holnapi találkozókra, így semmi sem lep meg.';

  @override
  String get loopExecution => 'Hurokvégrehajtás';

  @override
  String get loopPaused => 'A hurok szünetel';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'A macOS kisegítő lehetősége nem biztosított a NeoAgent számára. Engedélyezze a Rendszerbeállítások › Adatvédelem és biztonság › Kisegítő lehetőségek menüpontban.';

  @override
  String get macosApp => 'macOS alkalmazás';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'A macOS Screen Recording nem engedélyezett a NeoAgent számára. Engedélyezze a Rendszerbeállítások › Adatvédelem és biztonság › Képernyőrögzítés menüpontban, majd nyissa meg újra a NeoAgentet.';

  @override
  String get mailServersThatNeedAPassword =>
      'Azok a levelezőszerverek, amelyeknek jelszóra van szükségük, megtagadják a küldést, amíg újat nem küldenek ';

  @override
  String get main => 'Fő';

  @override
  String get makeDefault => 'Legyen alapértelmezett';

  @override
  String get manage => 'Kezelése';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Kezelje fiókja e-mailjeit, kétfaktoros hitelesítését és aktív munkameneteit.';

  @override
  String get managedBy => 'által kezelt';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'A vezetőknek lehetnek saját vezetőik (legfeljebb négy szint). A ';

  @override
  String get managing => 'Irányítás';

  @override
  String get manualDestination => 'Kézi célállomás';

  @override
  String get manualTrigger => 'Kézi trigger';

  @override
  String get masterPassword => 'Mester jelszó';

  @override
  String get matchThisDevice => 'Párosítsa ezt az eszközt';

  @override
  String get matchedAgainstTitleAndBody => 'Megfelel a címnek és a törzsnek';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Megfelel a régi NeoAgent MCP-folyamatnak: URL és hitelesítési metódus.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP szerver';

  @override
  String get mcpServer2 => 'MCP szerver';

  @override
  String get mcpServerUrl => 'MCP szerver URL';

  @override
  String get mcpServers => 'MCP szerverek';

  @override
  String get meantForSomeoneElse => 'Valaki másnak szánta';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Mért modell költség: $arg1';
  }

  @override
  String get memories => 'Emlékek';

  @override
  String get memory => 'Memória';

  @override
  String memoryArg1(Object? arg1) {
    return 'Memória: $arg1';
  }

  @override
  String get memoryInjected => 'Memória beadva';

  @override
  String get mentionOrReplyOnly => 'Csak említse meg vagy válaszoljon';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Egyesített szerver és Flutter futásidejű naplók ehhez az alkalmazás-munkamenethez.';

  @override
  String get messageBodyTemplateJson => 'Üzenettörzs sablon (JSON)';

  @override
  String get messageNeedsAccess => 'Az üzenethez hozzáférés szükséges';

  @override
  String get messageTextField => 'Üzenet szövegmezője';

  @override
  String get messaging => 'Üzenetküldés';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Messaging API push és webhook események';

  @override
  String get messagingConnectionNeedsAttention =>
      'Az üzenetküldő kapcsolat figyelmet igényel';

  @override
  String get messagingConnections => 'Üzenetküldési kapcsolatok';

  @override
  String get messagingDelivery => 'Üzenetküldés';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Üzenetküldési hiba. Kérjük, próbálja újra.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'A mikrofonrögzítés váratlanul leállt. Próbáld újra.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Mikrofon hiba: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofon elnémítva. Koppintson a némítás feloldásához.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Az élő hanghoz mikrofonengedély szükséges.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimális hozzájárulási érték: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'A mobil beállítás nem sikerült.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'A mobil beállítás nem sikerült, mert a Java nem érhető el a NeoAgentet futtató gépen.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'A mobil beállítás nem sikerült, mert a Java nem érhető el a NeoAgentet futtató gépen. Telepítsen egy JDK-t, és próbálja újra.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'A mobil beállítás nem sikerült. Ellenőrizze, hogy az Android-eszközök megfelelően vannak-e telepítve, és próbálja újra.';

  @override
  String modeArg1(Object? arg1) {
    return 'mód: $arg1';
  }

  @override
  String get modeLocksWhileARunIs => 'Az üzemmód zárolódik, ha a futás aktív.';

  @override
  String get model => 'Modell';

  @override
  String modelArg1(Object? arg1) {
    return 'Típus: $arg1';
  }

  @override
  String get modelAvailability => 'A modell elérhetősége';

  @override
  String get modelAvailabilitySaved => 'A modell elérhetősége mentve.';

  @override
  String get modelForThisSession => 'Modell ehhez a munkamenethez';

  @override
  String get modelOverride => 'Modell felülbírálása';

  @override
  String get modelPending => 'Modell függőben';

  @override
  String get modelTurn => 'Modellforduló';

  @override
  String get modelTurnCompleted => 'A modellfordulat elkészült';

  @override
  String get modelTurnStarted => 'Elindult a modellfordulat';

  @override
  String get modelVisibilityHideShowList =>
      'modell láthatósága elrejteni a listát';

  @override
  String get models => 'Modellek';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modellek, viselkedés, hang és munkaterület';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modellek, böngésző, hang, diagnosztika...';

  @override
  String get modelsRouting => 'Modellek és útválasztás';

  @override
  String get monthly => 'Havonta';

  @override
  String get moreActions => 'További műveletek';

  @override
  String get morningBriefing => 'Reggeli eligazítás';

  @override
  String get mostUsedAgents => 'Leggyakrabban használt szerek';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Leggyakrabban használt modellek a legutóbbi $arg1-ben.';
  }

  @override
  String get mouseKeyboard => 'Egér és billentyűzet';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'A mouseMove nem támogatott ezen a platformon.';

  @override
  String get mustBeReachableOnThePublic =>
      'Elérhetőnek kell lennie a nyilvános interneten -- helyi és ';

  @override
  String get n24Hours => '24 óra';

  @override
  String get n2faOrRecoveryCode => '2FA vagy helyreállítási kód';

  @override
  String get n2faRequiresSessionSecretToBe =>
      'A 2FA megköveteli, hogy a SESSION_SECRET konfigurálva legyen ezen a NeoAgent-telepítésen.';

  @override
  String get n30Days => '30 nap';

  @override
  String get n365Days => '365 nap';

  @override
  String get n4HourLimitTokens => '4 órás limit (token)';

  @override
  String get n4HourUsage => '4 órás használat';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4 órás határ $arg1';
  }

  @override
  String get n7DayUsage => '7 napos használat';

  @override
  String get n7Days => '7 nap';

  @override
  String get n90Days => '90 nap';

  @override
  String get name => 'Név';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnév: New Skill\nleírás: Ismertesse, mit csinál ez a készség\n---\nÍrja ide ehhez a készséghez az utasításokat.\n';

  @override
  String get nameOfWhoeverMadeIt => 'annak a neve, aki készítette.';

  @override
  String get nameOptional => 'Név (nem kötelező)';

  @override
  String get nativeAndWebhookChannels => 'Natív és webhook csatornák';

  @override
  String get naturalBubbles => 'Természetes buborékok';

  @override
  String get nearbyNeoagentServers => 'NeoAgent szerverek a közelben';

  @override
  String get needANewAccountRegister => 'Új fiókra van szüksége? Regisztráció';

  @override
  String get needAnIdea => 'Kell egy ötlet?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Válasz kell · $arg1% beszélni';
  }

  @override
  String get needsAttention => 'Figyelmet igényel';

  @override
  String get needsInput => 'Bemenet szükséges';

  @override
  String get neoagentApp => 'NeoAgent alkalmazás';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent asszisztens';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'A NeoAgent nem tudta ellenőrizni az elérhető háttér-futási környezetet.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'A NeoAgent nem tudta befejezni a helyi beállítást.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'A NeoAgent nem tudta befejezni a helyi beállítást. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'NeoAgent hibakeresési információ';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'A NeoAgent telepíti a legújabb $arg1-t ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'A NeoAgent telepítve van és fut.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'A NeoAgent nincs telepítve erre a számítógépre.';

  @override
  String get neoagentIsReady => 'A NeoAgent készen áll';

  @override
  String get neoagentIsStillWorkingOnA =>
      'A NeoAgent még mindig dolgozik egy feladaton. Fejezze be a hívást, és csevegésben kapja meg az eredményt, vagy törölje a feladatot is.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'A NeoAgent a bemutatót adaptálható munkafolyamattá alakítja.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'A NeoAgent vár, amíg Ön az asztalt használja.';

  @override
  String get neoagentIsWorking => 'A NeoAgent működik';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux számítógép';

  @override
  String get neoagentNeedsADecision => 'A NEOAGENTnek DÖNTÉSRE KELL';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'A NeoAgent futásidejű letöltéseihez biztonságos cím szükséges.';

  @override
  String get neoagentServerAddress => 'NeoAgent szerver címe';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'A NeoAgent szolgáltatási e-mail nincs készen. Kérje meg a szerver üzemeltetőjét, hogy ellenőrizze az e-mail környezet beállításait.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'A NeoAgent beállítását nem sikerült befejezni.';

  @override
  String get neoagentUser => 'NeoAgent felhasználó';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'A NeoAgent automatikusan használja ezt a számítógépet, és rákérdez, mielőtt a képernyőt, egeret, billentyűzetet, fájlokat vagy parancssort használná.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'A NeoAgent az Ön hozzávetőleges háttérbeli helyét használja a geokerítés-emlékeztetők aktiválásához (pl. „Emlékeztessen tejet vásárolni, amikor elmegyek a szupermarket mellett”).\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent munkaterület';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][stack] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall háttér-URL';

  @override
  String get neorecallBackendUrlIsRequired =>
      'A NeoRecall háttér-URL megadása kötelező.';

  @override
  String get neorecallSetup => 'NeoRecall beállítás';

  @override
  String get networkRequestFailed => 'hálózati kérés sikertelen';

  @override
  String get networkWriteRequests => 'Hálózati írási kérések';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'soha nem számít bele a megosztott használati korlátokba.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Az új fiókok bejelentkezés előtt megerősítik e-mail címüket.';

  @override
  String get newAccountsPerDay => 'Új fiókok naponta';

  @override
  String get newChat => 'Új chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Az új csoportok mindaddig csendben maradnak, amíg valaki fel nem címkézi a $arg1-t, amíg be nem kapcsolja őket.';
  }

  @override
  String get newLink => 'Új link';

  @override
  String get newPasswordsDoNotMatch => 'Az új jelszavak nem egyeznek.';

  @override
  String get newRecoveryCodes => 'Új helyreállítási kódok';

  @override
  String get newSession => 'Új munkamenet';

  @override
  String get newSessionN => 'Új munkamenet (⌘N)';

  @override
  String get newSessionWithSameSetup =>
      'Új munkamenet ugyanazzal a beállítással';

  @override
  String get newSkill => 'Új készség';

  @override
  String get newSkill2 => 'Új készség';

  @override
  String get newThisWeek => 'Új a héten';

  @override
  String get newsDigest => 'Hírek kivonat';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Következő újrapróbálkozás: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Nextcloud bejelentkezési folyamat';

  @override
  String get nextcloudSetup => 'Nextcloud beállítás';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'Nextcloud URL';

  @override
  String get nextcloudUrlIsRequired => 'A Nextcloud URL megadása kötelező.';

  @override
  String get nickname => 'Becenév';

  @override
  String get noAccountsConnectedYet => 'Még nincsenek összekapcsolt fiókok.';

  @override
  String get noAccountsFound => 'Nem található fiók.';

  @override
  String get noActiveSessionsFound => 'Nem található aktív munkamenet.';

  @override
  String get noAgentsYet => 'Még nincsenek ügynökök';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Nincs MI-szolgáltató konfigurálva, ezért csevegés és üzenetküldés ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Nincsenek jóváhagyási kérdések – az ügynök megszakítás nélkül fut.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Egyetlen $arg1 kiadási eszköz sem felel meg ennek a platformnak.';
  }

  @override
  String get noArguments => '(nincs érv)';

  @override
  String get noAuth => 'Nincs hitelesítés';

  @override
  String get noBindingsYet => 'Még nincsenek kötések.';

  @override
  String get noChangesYet => 'Még nincs változás';

  @override
  String get noChannelsFound => 'Nem található csatorna';

  @override
  String get noCloudComputerSlotIsFree =>
      'Jelenleg egyetlen felhő-számítógép-hely sem ingyenes. Próbálja újra egy pillanat múlva.';

  @override
  String get noCoreMemoryEntriesYet =>
      'Még nincsenek alapvető memóriabejegyzések.';

  @override
  String get noDescription => 'Nincs leírás';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Jelenleg nem állnak rendelkezésre asztali kijelzők.';

  @override
  String get noDetailAvailable => 'Nincs elérhető részlet';

  @override
  String get noDetailedSyncSummaryYet =>
      'Még nincs részletes szinkronizálási összefoglaló.';

  @override
  String get noDetailsCaptured => 'Nem rögzítettek részleteket.';

  @override
  String get noEmailLinked => 'Nincs linkelt e-mail';

  @override
  String get noExternalSignInProvidersLinked =>
      'Nincsenek összekapcsolva külső bejelentkezési szolgáltatók.';

  @override
  String get noGroupMessagesYet => 'Még nincsenek csoportos üzenetek';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Még nincsenek csoportspecifikus személyek hozzáadva.';

  @override
  String get noGroupsAddedYet => 'Még nincsenek csoportok hozzáadva.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Még nem található csoport. Miután a $arg1 csoportos üzenetet lát, használja a Legutóbbi csevegések keresése lehetőséget, és ezek itt fognak megjelenni.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Még nem található csoport. Miután a $arg1 csoportüzenetet lát, használja a Legutóbbi csevegések keresése lehetőséget.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Nincs visszaküldve az egészségügyi adatok hasznos tartalma.';

  @override
  String get noHealthSamplesStoredYet =>
      'Még nem tároltak egészségügyi mintákat.';

  @override
  String get noHttpClientImplementationForThis =>
      'Nincs HTTP-kliens megvalósítás ezen a platformon.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Ehhez a lépéshez nem volt rögzítve bemenet vagy kimenet.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Egyetlen integráció sem felel meg ennek a keresésnek.';

  @override
  String get noLimit => 'Nincs korlátozás';

  @override
  String get noLocalPasswordIsSetYet =>
      'Még nincs beállítva helyi jelszó. Hozzon létre egyet a felhasználónév/jelszó bejelentkezés engedélyezéséhez.';

  @override
  String get noLogEntries => 'Nincsenek naplóbejegyzések.';

  @override
  String get noMatchingSettings => 'Nincsenek megfelelő beállítások';

  @override
  String get noMcpServersMatchThisSearch =>
      'Egyetlen MCP-kiszolgáló sem felel meg ennek a keresésnek.';

  @override
  String get noMemoryEntriesFound => 'Nem találhatók memóriabejegyzések.';

  @override
  String get noMemorySync => 'Nincs memória szinkronizálás';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Egyszer végigolvassa az elmúlt 12 hónap fontos és elküldött leveleit, hogy az ügynök ismerje a kapcsolataidat és projektjeidet.';

  @override
  String get emailMemory => 'E-mail-memória';

  @override
  String get importNow => 'Importálás most';

  @override
  String get importOnConnect =>
      'Korábbi levelek importálása fiók csatlakoztatásakor';

  @override
  String get sweepStarting => 'Előkészítés…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'E-mailek olvasása · $done/$total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'E-mailek olvasása · $count találat';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Tanulás az e-mailekből · $done/$total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Legutóbbi importálás: $emails e-mail · $memories új emlék';
  }

  @override
  String get sweepNothingNew => 'Nincs új importálandó e-mail';

  @override
  String sweepFailed(String error) {
    return 'Az importálás sikertelen: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Egyik modell sem felel meg a \"$arg1\" kifejezésnek.';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Ehhez a futtatáshoz nem rögzítettek modellkérést.';

  @override
  String get noModelsDiscoveredYet => 'Még nem fedeztek fel modelleket';

  @override
  String get noModelsSelected => 'Nincsenek kiválasztott modellek';

  @override
  String get noModelsYet => 'Még nincsenek modellek';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'ehhez a szolgáltatóhoz nincs neoagent fiók társítva';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Ehhez a számítógéphez nem érhető el NeoAgent háttér-futási környezet.';

  @override
  String get noNetworkConnection => 'Nincs hálózati kapcsolat';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Nincs hálózati kapcsolat. Csatlakozzon a NeoAgent használatának folytatásához.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Nincs hálózati kapcsolat. Csatlakozzon újra a frissítések kereséséhez.';

  @override
  String get noOne => 'Senki';

  @override
  String get noOneAddedYet => 'Még senki sem adta hozzá.';

  @override
  String get noOneCanMessage => 'Senki nem tud üzenetet küldeni';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Nem található más NeoAgent szerver. Újra kereshet, vagy manuálisan is megadhat egy címet.';

  @override
  String get noPeopleAddedYet => 'Még nincsenek hozzáadva emberek.';

  @override
  String get noPlatformsMatch => 'Egyetlen platform sem egyezik';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Még nincs konfigurálható szolgáltató.';

  @override
  String get noRecentChannelActivity =>
      'Nincs közelmúltbeli csatornatevékenység';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Nincs találat a \"$arg1\" kifejezésre';
  }

  @override
  String get noRunsInThisRange => 'Nincs futás ebben a tartományban.';

  @override
  String get noRunsMatchTheseFilters =>
      'Egyetlen futtatás sem felel meg ezeknek a szűrőknek';

  @override
  String get noRunsYet => 'Még nincs futam';

  @override
  String get noRunsYet2 => 'Még nincs futam.';

  @override
  String get noSecurityKeyWasProvided => 'Nem adtak meg biztonsági kulcsot.';

  @override
  String get noServerUrlSet => 'Nincs beállítva a szerver URL-je';

  @override
  String get noSessionMatchesThatSearch =>
      'Egyetlen munkamenet sem felel meg a keresésnek.';

  @override
  String get noSessionsYet => 'Még nincsenek ülések';

  @override
  String get noSkillsMatchTheseFilters =>
      'Egyetlen képesség sem felel meg ezeknek a szűrőknek.';

  @override
  String get noStepsWereRecordedForThis =>
      'Ehhez a futtatáshoz nem rögzítettek lépéseket.';

  @override
  String get noSummaryAvailable => 'Nem áll rendelkezésre összefoglaló.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Nincs feladat a $arg1 számára';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Egyetlen szerszám sem felel meg a \"$arg1\"-nek.';
  }

  @override
  String get noUpdateRunning => 'Nem fut frissítés';

  @override
  String get noUsageYet => 'Még nincs használat.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Még nem áll rendelkezésre ellenőrzött NeoAgent háttér-futási környezet.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Senki nem tudja többé használni. Emberek, akik már csatlakoztak ';

  @override
  String get none => 'Egyik sem';

  @override
  String get notApprovedYet => 'még nem hagyták jóvá';

  @override
  String get notAuthenticated => 'nincs hitelesítve';

  @override
  String get notCheckedYet => 'Még nincs ellenőrizve';

  @override
  String get notConfigured => 'Nincs konfigurálva';

  @override
  String get notConnected => 'Nincs csatlakoztatva';

  @override
  String get notConnected2 => 'Nincs csatlakoztatva';

  @override
  String get notInstalled => 'Nincs telepítve';

  @override
  String get notNeeded => 'Nem szükséges';

  @override
  String get notNeededEnough => 'Nem kell elég';

  @override
  String get notNow => 'Most nem';

  @override
  String get notNow2 => 'Most nem';

  @override
  String get notSet => 'Nincs beállítva';

  @override
  String get notSetUp => 'Nincs beállítva';

  @override
  String get notTheSameAsAdmin => 'Nem ugyanaz, mint az admin';

  @override
  String get nothingFound => 'Nem találtunk semmit';

  @override
  String get nothingHereYet => 'Itt még semmi.';

  @override
  String get nothingHereYet2 => 'Itt még semmi';

  @override
  String get nothingMatches => 'Semmi sem egyezik';

  @override
  String get nothingStoredYet => 'Még nincs tárolva semmi.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'OAuth-ügyfélazonosító';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth ügyfélazonosító titkos átirányítási API-kulcs';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth ügyfélazonosító titkos átirányítási gmail naptármeghajtó';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Az OAuth elindítása nem támogatott ezen a platformon.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook bérlői ügyfél-azonosító titkos';

  @override
  String get oauthToken => 'OAuth-token';

  @override
  String get oauthWithPkce => 'OAuth PKCE-vel';

  @override
  String ofArg1(Object? arg1) {
    return 'a $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'saját. Mentés után soha többé nem jelenik meg.';

  @override
  String get off => 'Ki';

  @override
  String get officialIntegration => 'Hivatalos integráció';

  @override
  String get officialIntegrationDidNotReturnA =>
      'A hivatalos integráció nem adott vissza kapcsolati URL-t.';

  @override
  String get on => 'Be';

  @override
  String get onASignedInAndroidDevice =>
      'Egy bejelentkezett Android-eszközön nyissa meg a Beállítások › Bejelentkezés és biztonság lehetőséget, olvassa be ezt a kódot, és hagyja jóvá a bejelentkezést.';

  @override
  String get onByDefaultForNewGroups =>
      'Alapértelmezés szerint be van kapcsolva az új csoportokhoz';

  @override
  String get onDemand => 'Igény szerint';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Bekapcsolva a $arg2 csoportok $arg1-éhez';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'be. Csak új meghívólinkkel csatlakozhatnak újra.';

  @override
  String get onYourOwnTheDefault => 'Önállóan (alapértelmezett)';

  @override
  String get once => 'Egyszer';

  @override
  String get oneIsSavedOtherChangesIn =>
      'az egyik meg van mentve. Az űrlap többi módosítása is mentésre kerül.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Egy vagy több fiók lejárt. Csatlakoztassa újra az érintett fiókot az eszköz hozzáférésének visszaállításához.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Egy futási idő vezérli a személyt, a csoportok átvételét, a helyiség memóriáját, a normákat, az elmeelméletet és a kézbesítést.';

  @override
  String get oneTimeRun => 'Egyszeri futás';

  @override
  String get onlyApkOrApksFilesCan =>
      'Csak .apk vagy .apks fájlok telepíthetők.';

  @override
  String get onlyInThisGroup => 'Csak ebben a csoportban';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Csak akkor szükséges, ha a szolgáltatás extra HTTP-fejléceket kér.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Csak akkor szükséges, ha át akarja alakítani a kimenő rakományt.';

  @override
  String get onlyTheyCanChangeIt => 'Csak ők tudnak változtatni rajta.';

  @override
  String get open => 'Nyissa meg';

  @override
  String get openAccountSettingsOnASigned =>
      'Nyissa meg a Beállítások › Bejelentkezés és biztonság elemet egy bejelentkezett Android-eszközön, olvassa be ezt a kódot, és hagyja jóvá a bejelentkezést.';

  @override
  String get openComputer => 'Nyissa meg a számítógépet';

  @override
  String get openDashboard => 'Nyissa meg az irányítópultot';

  @override
  String get openFolder => 'Mappa megnyitása…';

  @override
  String get openInWorkbench => 'Nyitva a munkapadon';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Nyissa meg a NeoAgentet, és csatlakoztassa újra a $arg1-t az üzenetkezelés visszaállításához.';
  }

  @override
  String get openTimeSettings => 'Nyissa meg az időbeállításokat';

  @override
  String get openToAnyone => 'Nyitott bárki számára';

  @override
  String get openTrello => 'Nyissa meg a Trellót';

  @override
  String get openVoiceAssistant => 'Hangos asszisztens megnyitása';

  @override
  String get openWiFiSettings => 'Nyissa meg a Wi-Fi beállításokat';

  @override
  String get openWithTheDefaultApp =>
      'Nyissa meg az alapértelmezett alkalmazással';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'openai kompatibilis';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'OpenAI-kompatibilis végpont (saját szerver vagy más ';

  @override
  String openedArg1(Object? arg1) {
    return 'Nyitott $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Az asztali URL-ek megnyitása nem támogatott ezen a platformon.';

  @override
  String get openingYourSavedDesktop => 'A mentett asztal megnyitása.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'A mentett asztal megnyitása. A normál indítások kevesebb, mint 10 másodpercig tartanak.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Opcionális extra titok, ha védi a bejövő webhookot.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Opcionális felülírás, ha a webhook URL nem elegendő.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Opcionális titok a bejövő csevegési események ellenőrzéséhez.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Opcionális titok a bejövő események ellenőrzéséhez.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Opcionális titok a bejövő iMessage események ellenőrzéséhez.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Opcionális titok a bejövő LINE-események ellenőrzéséhez.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Opcionális titok a bejövő Mattermost események ellenőrzéséhez.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Opcionális titok a bejövő Teams-események ellenőrzéséhez.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Választható. Az ügynöknek már megvan a maga személyisége. Bármi, amit hozzáad a tónushoz, a tetejére rétegződik, így soha nem kell meghatároznia.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Választható. Ha be van állítva, a rendszer az URL helyett használja.';

  @override
  String get orAnswerInYourOwnWords => 'Vagy válaszolj a saját szavaiddal';

  @override
  String get orBuildYourOwnTask => 'Vagy építse fel saját feladatát';

  @override
  String get orContinueWith => 'vagy folytassa ezzel';

  @override
  String get orFiles => 'vagy fájlokat.';

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
  String get originNotAllowed => 'eredete nem megengedett';

  @override
  String get outgoingMessage => 'Kimenő üzenet';

  @override
  String get outgoingWebhookUrl => 'Kimenő webhook URL';

  @override
  String get outlookEmailReceived => 'Outlook e-mail érkezett';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Az importálásból származó viselkedési megjegyzések felülírása.';

  @override
  String get ownModel => 'saját modell';

  @override
  String get packageName => 'Csomag neve';

  @override
  String get pairWithQrCode => 'Párosítás QR-kóddal';

  @override
  String get password => 'Jelszó';

  @override
  String get password2faAndActiveSessions =>
      'Jelszó, 2FA és aktív munkamenetek';

  @override
  String get passwordCreated => 'Jelszó létrehozva.';

  @override
  String get passwordIsTooWeak => 'a jelszó túl gyenge';

  @override
  String get passwordMin8 => 'jelszó min 8';

  @override
  String get passwordOrApiKey => 'Jelszó vagy API kulcs';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Jelszó erőssége: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'A jelszavak nem egyeznek.';

  @override
  String get pasteAKey => 'Illesszen be egy kulcsot.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Illesszen be egy új kulcsot a $arg1 helyére';
  }

  @override
  String get pasteTheKey => 'Illessze be a kulcsot';

  @override
  String get pasteYourAccountToken => 'Illessze be a fióktokenjét';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Illessze be a $arg1 API-kulcsot alább. Ez az ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Az elérési útnak a NeoAgent munkaterületen belül kell maradnia.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Az elérési útnak a munkaterület mappájában kell maradnia.';

  @override
  String get pauseLiveUpdates => 'Az élő frissítések szüneteltetése';

  @override
  String get pauseTaskLoop => 'Feladathurok szüneteltetése';

  @override
  String get paused => 'Szüneteltetve';

  @override
  String peakArg1(Object? arg1) {
    return 'csúcs $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Személyek privát chatekben';

  @override
  String get perAccountRateLimits => 'Számlánkénti kamatkorlátok';

  @override
  String get perCategoryPermissions => 'Kategóriánkénti engedélyek';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Eszközönkénti engedélyezési szabályzatok, jóváhagyási kapuk és folyamatleválasztás a shell-végrehajtáshoz.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Engedély szükséges: $arg1';
  }

  @override
  String get permissionsNeeded => 'Engedélyek szükségesek';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Engedélyek. Senki más nem tud ezen változtatni.';

  @override
  String get personOrChat => 'Személy vagy chat';

  @override
  String get personaBehaviorNotes => 'Személyes viselkedési megjegyzések';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Személyes hozzáférési token a Mattermost bothoz.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Személyes csatornák és közvetlen támogatási felületek.';

  @override
  String get personalSelfChat => 'Személyes öncsevegés';

  @override
  String get phoneNumber => 'Telefonszám';

  @override
  String get pickARunFromTheList =>
      'A lépések megtekintéséhez válasszon egy futást a listából.';

  @override
  String get pickARunFromTheList2 =>
      'Válasszon ki egy futást a bal oldali listából, hogy felfedezze annak menetét.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Válasszon a legutóbbi $arg1 csevegésekből, vagy adjon hozzá egy személyt vagy csoportot saját maga.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Válassza ki, hogyan használja a $arg1 ezt a fiókot.';
  }

  @override
  String get pickOneToFillInThe =>
      'Válasszon egyet a feladat kitöltéséhez. Utána mindent lehet csipegetni.';

  @override
  String get picksUpWhereYouLeftOff => 'Ott folytatja, ahol abbahagyta';

  @override
  String get plan => 'Terv';

  @override
  String get planning => 'Tervezés';

  @override
  String get platform => 'Platform';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platform $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Kérjük, válasszon menetrendet.';

  @override
  String get pleaseEnterAFilename => 'Kérjük, adjon meg egy fájlnevet.';

  @override
  String get pleaseEnterAKey => 'Kérjük, adjon meg egy kulcsot.';

  @override
  String get pleaseEnterAPrompt => 'Kérjük, írjon be egy felszólítást.';

  @override
  String get pleaseEnterATaskName => 'Adja meg a feladat nevét.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Kérjük, adja meg a memória tartalmát.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Kérjük, adja meg, hogy a feladatnak mikor kell futnia.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Kérjük, válasszon fiókot, vagy adjon meg egy érvényes kapcsolatazonosítót.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Irányítsa a NeoAgentet bármely OpenAI-kompatibilis csevegés befejezésekor ';

  @override
  String get pointTheCameraAtTheCode =>
      'Irányítsa a kamerát a kijelentkezett eszközön látható kódra. A jóváhagyás ezen a telefonon marad.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env nyilvános url megbízható proxy biztonságos cookie-k telepítése';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Prémium automatizálás ütemezési és integrációs triggerekkel.';

  @override
  String get prepareQrCode => 'Készítsen QR kódot';

  @override
  String get preparingNeoagent => 'A NeoAgent előkészítése…';

  @override
  String get preparingNeoagent2 => 'A NeoAgent előkészítése';

  @override
  String get pressAndHoldForQuickCapture =>
      'Nyomja meg és tartsa lenyomva a gyors rögzítéshez';

  @override
  String get pressKeysIsNotSupportedOn =>
      'gombnyomás nem támogatott ezen a platformon.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Préselt $arg1';
  }

  @override
  String get priceUnknown => 'Ár ismeretlen';

  @override
  String get primaryDisplay => 'Elsődleges kijelző';

  @override
  String get privateChat => 'Privát chat';

  @override
  String get privateChats => 'Privát beszélgetések';

  @override
  String get privateChats2 => 'privát chateket';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Privát csevegés: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Privát chat $arg1 · csoportok $arg2';
  }

  @override
  String get privateChatsOnly => 'Csak privát csevegés';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'privát hálózati címek nem engedélyezettek.';

  @override
  String get profileEmailAndPersonalData => 'Profil, email és személyes adatok';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Kérdezzen, mielőtt a NeoAgent a tálcán maradna.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Gyorsítótár: $arg1 gyorsítótárban tárolt tokenek ';
  }

  @override
  String get promptCopied => 'Prompt másolva.';

  @override
  String get promptOrSchedule => 'felszólítás vagy ütemezés.';

  @override
  String get promptToPasteIntoAnotherAi =>
      'Kéri, hogy illessze be egy másik AI-ba';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'A szolgáltató összekapcsolása nem indítható el.';

  @override
  String get providerSignInCouldNotBe =>
      'A szolgáltatói bejelentkezést nem sikerült elindítani.';

  @override
  String get providers => 'Szolgáltatók';

  @override
  String get providersEachAccountCanStillPick =>
      'Szolgáltatók; minden fiók továbbra is kiválaszthatja a saját modelljét a Beállításokban. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'A szolgáltatók, az integrációk, a hang és az opcionális képességek a Beállításokban bármikor megadhatók.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Nyilvános kiadási és lekérési szálak, amelyekre csak jóváhagyott személyek válaszolnak.';

  @override
  String get publicUrl => 'Nyilvános URL';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Nyilvános URL és engedélyezett eredet';

  @override
  String get publicUrlOverride => 'Nyilvános URL felülbírálása';

  @override
  String get pullsTogetherTheDayAhead => 'Összeszedi az előttünk álló napot';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'QR-alapú telefonösszekapcsolás';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'A QR-bejelentkezés befejeződött, de a NeoAgent nem tudta megtartani a munkamenetet. Kérjük, próbálja újra.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'A QR-bejelentkezést nem sikerült elindítani.';

  @override
  String get qrLoginRequestHasExpired => 'qr bejelentkezési kérelem lejárt';

  @override
  String get qrLoginRequestWasNotFound =>
      'qr bejelentkezési kérés nem található';

  @override
  String get qrPairing => 'QR-párosítás';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'lekérdezések futnak; bármit, ami ír, elutasítják.';

  @override
  String get queryFilter => 'Lekérdezés / szűrő';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Kormányzóként sorba állítva az aktuális futáshoz: $arg1';
  }

  @override
  String get quickstart => 'Gyorsindítás';

  @override
  String get quit => 'Kilép';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'eső_indítás, szél_riadó';

  @override
  String get ranAScriptInThePage => 'Futtat egy szkriptet az oldalon';

  @override
  String ranArg1(Object? arg1) {
    return 'Futott $arg1';
  }

  @override
  String get rateLimits => 'Díjkorlátok';

  @override
  String get readAnArtifact => 'Olvass el egy műalkotást';

  @override
  String get readAndEditFilesInsideYour =>
      'Olvasson és szerkesszen fájlokat a NeoAgent Workspace mappában.';

  @override
  String readArg1(Object? arg1) {
    return 'Olvassa el a $arg1-t';
  }

  @override
  String get readError => 'Olvasási hiba';

  @override
  String get readFiles => 'Fájlok olvasása';

  @override
  String get readOnly => 'Csak olvasható';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Olvassa el a mappát, és foglalja össze a veremet, a belépési pontokat és a futtatás módját.';

  @override
  String get readThePage => 'Olvassa el az oldalt';

  @override
  String get readTheUiTree => 'Olvassa el a felhasználói felület fát';

  @override
  String get readWrite => 'Olvasni / Írni';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Leolvassa a lépéseket, a pulzusszámot, az alvást, az edzést és a súlyt.';

  @override
  String get ready => 'Kész';

  @override
  String get readyForFirstTimeSetup => 'Készen áll az első beállításra';

  @override
  String get readyToConnect => 'Csatlakozásra kész';

  @override
  String get recentChannelActivity => 'Legutóbbi csatornatevékenység';

  @override
  String get recentChats => 'Legutóbbi beszélgetések';

  @override
  String get recentDecisions => 'Legutóbbi döntések';

  @override
  String get recentFailedRuns => 'Legutóbbi sikertelen futtatások';

  @override
  String get recentGroupDecisions => 'Legutóbbi csoportdöntések';

  @override
  String get recentRuns => 'Legutóbbi futások';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'A legutóbbi futások körülbelül $arg1-t vesznek igénybe, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Legutóbbi szerver kimenet, a legújabb az első.';

  @override
  String get recentUsage4Hours => 'Legutóbbi használat (4 óra)';

  @override
  String get recents => 'Legutóbbiak';

  @override
  String get recipientField => 'Címzett mező';

  @override
  String get reconnectOrFinishSetup =>
      'Csatlakoztassa újra vagy fejezze be a beállítást';

  @override
  String get reconnectingThisDevice => 'Az eszköz újracsatlakoztatása…';

  @override
  String get recurring => 'Visszatérő';

  @override
  String get redirectUri => 'Átirányítási URI';

  @override
  String get redoOnboarding => 'Ismételje meg a felvételt';

  @override
  String get refresh => 'Frissítés';

  @override
  String get refreshCode => 'Frissítse a kódot';

  @override
  String get refreshNow => 'Frissítés most';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Az újbóli próbálkozáshoz frissítse az Android képernyőt.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Ne küldje el, hacsak a kapcsolat nem frissül TLS-re.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'az alábbi kategóriánkénti beállításoktól függetlenül.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Regisztrálja a $arg1-t az asszisztensi idézési folyamathoz.';
  }

  @override
  String get registrationIsClosed => 'regisztráció lezárult';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'regisztráció regisztráció új fiókok lehetővé teszik a regisztrációt';

  @override
  String get rejectInvalidTlsCertificates =>
      'Érvénytelen TLS-tanúsítványok elutasítása';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'engedje el és újraindul. A csatlakoztatott alkalmazások újra csatlakoznak, miután visszatértek.';

  @override
  String get releaseChannel => 'Kiadási csatorna';

  @override
  String get releaseCommitBranchNode => 'commit elágazó csomópont kiadása';

  @override
  String get releaseWhenYouAreDone => 'Engedje el, ha végzett.';

  @override
  String get reloadNow => 'Újratöltés most';

  @override
  String get rememberThisChoice => 'Emlékezzen erre a választásra';

  @override
  String get remove => 'Távolítsa el';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Eltávolítja a „$arg1” fájlt és a rögzített lépéseit a futási előzményekből?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Távolítsa el a „$arg1” elemet az alapmemóriából.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Eltávolítja a $arg1 kulcsot?';
  }

  @override
  String get removeEraseGdprUser => 'távolítsa el a gdpr felhasználó törlését';

  @override
  String get removeSmtpPassword => 'Távolítsa el az SMTP jelszót';

  @override
  String get removeTheSmtpPassword => 'Eltávolítja az SMTP jelszót?';

  @override
  String get rename => 'Átnevezés';

  @override
  String get renameSecurityKey => 'Biztonsági kulcs átnevezése';

  @override
  String get renameSession => 'Munkamenet átnevezése';

  @override
  String get repairAndRetry => 'Javítsa meg és próbálja újra';

  @override
  String get repairDesktop => 'Asztali javítás';

  @override
  String get repeat => 'Ismételje meg';

  @override
  String get repliesWhenTagged => 'Válaszol a címkézéskor';

  @override
  String get replyToAddress => 'Válasz-Cím';

  @override
  String replyToArg1(Object? arg1) {
    return 'Válasz erre: $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Az adattárnak tulajdonos/tárhely formátumban kell lennie.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reprodukálja az általam leírt hibát, keresse meg a kiváltó okot és javítsa ki egy regressziós teszttel.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'a kérés meghiúsult a http $arg1 használatával';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'A kérés meghiúsult a HTTP $arg1 használatával';
  }

  @override
  String get requestPermissions => 'Kérjen engedélyeket';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'A $arg1-hez intézett kérés sikertelen volt, mielőtt a háttérrendszer válaszolt volna.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Kért $arg1';
  }

  @override
  String get requireStarttls => 'STARTTLS szükséges';

  @override
  String get requiredBehindHttpsOrATls =>
      'HTTPS vagy TLS proxy mögött szükséges. Szerver után érvényes ';

  @override
  String get requiredExampleBerlinDe => 'Kötelező. Példa: Berlin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Kötelező. Formátum: tulajdonos/repo';

  @override
  String get reserveAssistantHotkey => 'Tartalék asszisztens gyorsbillentyű';

  @override
  String get reset => 'Reset';

  @override
  String get resetPassword => 'Jelszó visszaállítása';

  @override
  String get resetView => 'Nézet visszaállítása';

  @override
  String get responsibilities => 'Felelősségek';

  @override
  String get restart => 'Indítsa újra';

  @override
  String get restartToFinishTheUpdate =>
      ' Indítsa újra a frissítés befejezéséhez.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'A korábbi NeoAgent futási környezet visszaállítása';

  @override
  String get restrictDelegationTargets => 'A delegálási célok korlátozása';

  @override
  String get result => 'Eredmény';

  @override
  String get resultDelivery => 'Eredmény kézbesítés';

  @override
  String get resultOneClickAddsOneYou =>
      'eredményt. Egy kattintás hozzáad egyet; később szerkesztheti.';

  @override
  String get results => 'Eredmények';

  @override
  String get retry => 'Próbálja újra';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Újrafelhasználható · használt $arg1×';
  }

  @override
  String get reviewUncommittedChanges =>
      'Tekintse át a nem vállalt módosításokat';

  @override
  String get revoke => 'Visszavonás';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Az admin visszavonása a `neoagent admin revoke $arg1-vel először';
  }

  @override
  String get revokeThisLink => 'Visszavonja ezt a linket?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Szobaablak: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'A folytatáshoz forgassa el';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'sorokat. A megtekintéséhez adjon hozzá egy LIMIT vagy szűkebb WHERE záradékot ';

  @override
  String get rule => 'szabály';

  @override
  String get run => 'Futtatás';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Futtasson tetszőleges parancsokat a gépen vagy a virtuális gépen.';

  @override
  String get runAt => 'Fuss at';

  @override
  String get runCompleted => 'Futás befejezve';

  @override
  String get runFailed => 'A futás nem sikerült';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Futtassa a git diff-et, tekintse át a nem véglegesített módosításokat hibák és stílusproblémák keresésére, és foglalja össze, amit talált.';

  @override
  String get runNotFound => 'Futtatás nem található';

  @override
  String get runNow => 'Futtatás most';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Futtassa a bejövő személyes WhatsApp üzeneteket.';

  @override
  String get runQuery => 'Lekérdezés futtatása';

  @override
  String get runShellCommandsOrInstallApps =>
      'Futtasson shell-parancsokat vagy telepítsen alkalmazásokat Android-eszközére.';

  @override
  String get runStarted => 'Elindult a futás';

  @override
  String get runStatus => 'Futtatás állapota';

  @override
  String get runStopped => 'A futás megállt';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Futtasson terminálparancsokat, és nyissa meg az alkalmazásokat vagy weboldalakat.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Futtassa ezt a szervert: fiókok, frissítések, szolgáltatók, konfiguráció ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Futtatás, amikor egy megfelelő Gmail-üzenet érkezik.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Futtassa, amikor egy megfelelő Outlook e-mail érkezik.';

  @override
  String get runWhenANewIssueMatching =>
      'Futtatás, ha a szűrőknek megfelelő új probléma nyílik meg egy lerakatban.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Futtassa, amikor a szűrőknek megfelelő új NeoRecall memória jön létre.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Futtassa, amikor értesítés érkezik az eszközére.';

  @override
  String get runWhenASlackMessageMatches =>
      'Futtatás, ha egy Slack-üzenet megfelel a kiválasztott hatókörnek.';

  @override
  String get runWhenATeamsChatMessage =>
      'Futtatás, ha a Teams csevegési üzenete megfelel a kiválasztott hatókörnek.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Futtatás, ha egy helyre konfigurált időjárási eseményeket jeleznek előre.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'fut. Bármelyik modell ki van kapcsolva, a szolgáltatók által hozzáadott modellek ';

  @override
  String get running => 'Folyamatban';

  @override
  String runningArg1(Object? arg1) {
    return '$arg1 fut';
  }

  @override
  String get runningTask => 'Futó feladat';

  @override
  String get runningTool => 'Futó eszköz';

  @override
  String get runs => 'Futtatások';

  @override
  String get runsEveryDayAtTheSelected =>
      'Minden nap a kiválasztott időpontban fut.';

  @override
  String get runsFourTimesPerHour => 'Óránként négyszer fut.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '- futások, üzenetek, memóriák, integrációk, fájlok és ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'futások, üzenetek, memóriák, integrációk, fájlok és munkamenetek. ';

  @override
  String get runsMondayThroughFriday => 'Hétfőtől péntekig fut.';

  @override
  String get runsOnSelectedWeekdays => 'A kiválasztott hétköznapokon fut.';

  @override
  String get runsOncePerHour => 'Óránként egyszer fut.';

  @override
  String get runsOncePerMonthOnThe =>
      'Havonta egyszer fut a kiválasztott napon.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Csak akkor fut, ha megnyomja a Futtatás most gombot.';

  @override
  String get runsPerDay => 'Naponta fut';

  @override
  String get runsPerDay30Days => 'Naponta fut (30 nap)';

  @override
  String get runsThatCompleted => 'Lefut, hogy befejeződött';

  @override
  String get runsThisWeek => 'Ezen a héten fut';

  @override
  String get runsToday => 'Ma fut';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'A futtatások, az eszközök, a memória, az ütemezés, a készségek és az MCP mind elérhetők itt.';

  @override
  String get runsTwicePerHour => 'Óránként kétszer fut.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'A futtatások a $arg1 megosztott kiszolgálókulcsára esnek vissza, ha az be van állítva. Ezt nem lehet visszavonni.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Futásidő $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Üzemidő: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Futásidejű beállítások, amelyekkel ez a szerver indult. Szerkessze őket alá ';

  @override
  String get runtimeSetupRequired => 'Futásidejű beállítás szükséges';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'A futásidejű aláírás nyilvános kulcsának 32 bájtnak kell lennie.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Mentés';

  @override
  String get saveATrelloApiKeyFor =>
      'Mentse el a Trello API-kulcsot ehhez az ügynökhöz, majd csatlakoztasson biztonságosan egy Trello-fiókot. A fiókjogkivonatot a szerver tárolja, és csak ehhez az ügynökhöz használja.';

  @override
  String get saveAccount => 'Fiók mentése';

  @override
  String get saveChanges => 'Módosítások mentése';

  @override
  String get saveCloudComputerSettings =>
      'Mentse a felhőalapú számítógép beállításait';

  @override
  String get saveConnect => 'Mentés és csatlakozás';

  @override
  String get saveDefaults => 'Alapértelmezések mentése';

  @override
  String get saveDiagnosticReport => 'Diagnosztikai jelentés mentése';

  @override
  String get saveEmail => 'E-mail mentése';

  @override
  String get saveEmailSettings => 'Mentse el az e-mail beállításokat';

  @override
  String get saveGeneralSettings => 'Általános beállítások mentése';

  @override
  String get saveName => 'Név mentése';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Mentse el a NeoAgent beállítási diagnosztikáját';

  @override
  String get saveOnly => 'Csak mentés';

  @override
  String get saveSetup => 'Mentse a beállítást';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Mentse el ezeket a helyreállítási kódokat most. Nem jelennek meg újra.';

  @override
  String get savedDeliveryDestination => 'Mentett kézbesítési cél';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Mentett díjkorlátok a @$arg1 számára.';
  }

  @override
  String get scanANeoagentLoginQr =>
      'Olvasson be egy NeoAgent bejelentkezési QR-kódot';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Olvasson be egy NeoAgent párosító QR-kódot egy másik eszközről, és hagyja jóvá ebben az indítómunkamenetben.';

  @override
  String get scanLoginQr => 'Bejelentkezési QR beolvasása';

  @override
  String get scanPairingQr => 'QR-párosítás beolvasása';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Olvassa be a QR-bejelentkezési kérelmeket a kijelentkezett eszközökről, és hagyja jóvá őket ebből a hitelesített mobil munkamenetből.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Beolvasás a befejezéshez $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Szkennelés a NeoAgent segítségével a telefonon';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Megvizsgálja az új e-maileket, és csak akkor ping-el, ha valami számít.';

  @override
  String get schedule => 'Ütemezés';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'ütemezett időpont. A futások mérése után korábban indul.';

  @override
  String get screen => 'Képernyő';

  @override
  String get screenAction => 'képernyő művelet';

  @override
  String get scrollIsNotSupportedOnThis =>
      'a görgetés nem támogatott ezen a platformon.';

  @override
  String get scrollToBottom => 'Görgessen lefelé';

  @override
  String get search => 'Keresés';

  @override
  String get search2 => 'Keresés…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Adminisztrátori beállítások keresése (pl. SMTP, Ollama, naplók)';

  @override
  String get searchAgain => 'Keresés újra';

  @override
  String get searchByUsernameOrEmail =>
      'Keresés felhasználónév vagy e-mail alapján';

  @override
  String get searchChannels => 'Csatornák keresése';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Keresés a felfedezett üzenetküldési csatornákban, névjegyekben, csoportokban és legutóbbi beszélgetésekben.';

  @override
  String get searchGroups => 'Csoportok keresése';

  @override
  String get searchMemory => 'Keresés a memóriában';

  @override
  String get searchModelsOrProviders =>
      'Keressen modelleket vagy szolgáltatókat';

  @override
  String get searchModelsOrProviders2 => 'Modellek vagy szolgáltatók keresése…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Legutóbbi személyek és csoportok keresése';

  @override
  String get searchSessions => 'Munkamenetek keresése';

  @override
  String get searchSettings => 'Keresési beállítások';

  @override
  String get searchTitleModelTriggerRunId =>
      'Keresés cím, modell, trigger, futtatási azonosító';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Keresési eszközök, integrációk és készségek';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'A \"$arg1\" kód keresése';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'A \"$arg1\" kifejezésre keresett fájlokat';
  }

  @override
  String get secretField => 'Titkos mező';

  @override
  String get secureCookies => 'Biztonságos sütik';

  @override
  String get security => 'Biztonság';

  @override
  String get securityKey => 'Biztonsági kulcs';

  @override
  String get securityKeyPromptWasDismissed =>
      'A biztonsági kulcsot kérő üzenet el lett utasítva.';

  @override
  String get securityKeySignInCompletedBut =>
      'A biztonsági kulcs bejelentkezés befejeződött, de a NeoAgent nem tudta megtartani a böngésző munkamenetet. Kérjük, jelentkezzen be újra.';

  @override
  String get securityKeySignInCouldNot =>
      'A biztonsági kulcsos bejelentkezést nem sikerült elindítani.';

  @override
  String get securityKeys => 'Biztonsági kulcsok';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'A biztonsági kulcsok csak a NeoAgent webalkalmazásban érhetők el.';

  @override
  String get seeAll => 'Az összes megtekintése';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Nézze meg, melyik NeoAgent kiszolgálót használja ez az ablak, és futtassa a háttérprogramot ezen a számítógépen.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'láthatja a felhasználónevét és ezeket a beállításokat, soha nem a beszélgetéseit, emlékeit ';

  @override
  String get selectARun => 'Válasszon egy futást';

  @override
  String get selectASessionToSeeIts =>
      'Válasszon ki egy munkamenetet a számítógép, a fájlok és a módosítások megtekintéséhez.';

  @override
  String get selectAll => 'Válassza ki az összeset';

  @override
  String get selectAll2 => 'Válassza az Összes lehetőséget';

  @override
  String selectArg1(Object? arg1) {
    return 'Válassza a $arg1 lehetőséget';
  }

  @override
  String get selectTrigger => 'Válassza a Trigger lehetőséget';

  @override
  String get send => 'Küldés (⌘↵)';

  @override
  String get send2 => 'Küldés';

  @override
  String get sendATaskFromChatAnd =>
      'Küldjön el egy feladatot a csevegésből, és a végrehajtási előzmények itt fognak megjelenni.';

  @override
  String get sendItToATeammateWith =>
      'küldje el egy csapattársának, akinek fiókja van ezen a szerveren.';

  @override
  String get sendLink => 'Link küldése';

  @override
  String get sendPath => 'Elküldési útvonal';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'POST / PUT / DELETE kérések küldése külső API-knak.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Ezt a linket csak annak a személynek küldje el, akinek szól. Egyszer látható; ';

  @override
  String get senderAddress => 'Feladó címe';

  @override
  String get senderFilterOptional => 'Feladószűrő (opcionális)';

  @override
  String get sentSharedAttachments => 'Megosztott mellékleteket küldött.';

  @override
  String get separateAccount => 'Külön számla';

  @override
  String get server => 'Szerver';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Szerver alapértelmezett ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'A szerver alapértelmezett beállításai az alkalmazáson belüli hanghívásokhoz. A hívások élőben futnak ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'maga a szerver: fiókok, szolgáltatók és konfiguráció.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Szerver, nick, csatorna és opcionális TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'szerver kimeneti konzol figyelmeztetések hibák másolat';

  @override
  String get serverProviderCredentials =>
      'Szerverszolgáltató hitelesítő adatai';

  @override
  String get serverUrl => 'Szerver URL';

  @override
  String get serverUsageLimitsDonTApply =>
      'A szerverhasználati korlátozások nem vonatkoznak a saját kulcsán futó modellekre.';

  @override
  String get serviceEmail => 'Szerviz e-mail';

  @override
  String get serviceEmailIsNotConfigured =>
      'a szerviz e-mail nincs konfigurálva';

  @override
  String get serviceEmailSmtp => 'Szolgáltatási e-mail (SMTP)';

  @override
  String get sessionActions => 'Munkamenet műveletek';

  @override
  String get sessions => 'Munkamenetek';

  @override
  String get sessions2 => 'ÜLÉSEK';

  @override
  String get sessionsArePinnedToAFolder =>
      'A munkamenetek egy mappához és egy számítógéphez vannak rögzítve. Kezdje el innen a tervezést, építést, tesztelést és szállítást.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'ülések (GDPR 17. cikk). A rendszergazdai fiókok nem törölhetők ';

  @override
  String get sessionsLogoutRevokeForce =>
      'munkamenetek kijelentkezés visszavonása hatályos';

  @override
  String get setBlockAskAllowPerTool =>
      'Állítsa be a blokk / kérdez / engedélyezés eszközkategóriánként, vagy válasszon egy globális módot.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Állítsa be a NeoAgentet ezen a számítógépen';

  @override
  String get setUpOrConnectNeoagent =>
      'Állítsa be vagy csatlakoztassa a NeoAgentet';

  @override
  String get setUrl => 'Állítsa be az URL-t';

  @override
  String get settings => 'Beállítások elemre';

  @override
  String get settingsAndCannotBeUndone =>
      'beállításokat, és nem vonható vissza.';

  @override
  String get settingsArea => 'Beállítások terület';

  @override
  String get settingsAreas => 'Beállítási területek';

  @override
  String get setup => 'Beállítás';

  @override
  String get setupDetails => 'Beállítás részletei';

  @override
  String get setupRequired => 'Beállítás szükséges';

  @override
  String get setupWasCancelled => 'A beállítás megszakadt.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Megosztott mellékletek a NeoAgent klienstől:';

  @override
  String get sharedFromAnotherApp => 'Megosztva egy másik alkalmazásból';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'A megosztott szolgáltatói kulcsok a kiszolgálón vannak konfigurálva. Ha helyette saját API-kulcsot vagy egyéni végpontot szeretne használni, lépjen a Speciális → Saját kulcs létrehozása lehetőségre.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Megosztva a NeoAgent chattel és annak memóriájával.';

  @override
  String get shellCommands => 'Shell parancsok';

  @override
  String showAllArg1(Object? arg1) {
    return 'Az összes $arg1 megjelenítése';
  }

  @override
  String get showEarlier => 'Mutasd korábban';

  @override
  String get showEveryStep => 'Mutasd meg minden lépését';

  @override
  String get showTools => 'Eszközök megjelenítése';

  @override
  String get showWorkbenchJ => 'Munkapad megjelenítése (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Az első $arg1 bemutatása ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Megjelenik az oldalsávban. Hagyja üresen a felhasználónevének használatához.';

  @override
  String get signIn => 'Jelentkezzen be';

  @override
  String get signInCompletedButNeoagentCould =>
      'A bejelentkezés befejeződött, de a NeoAgent nem tudta megtartani a böngésző munkamenetet. Kérjük, jelentkezzen be újra. Ha ez továbbra is megtörténik, ellenőrizze a backend munkamenet cookie-beállításait.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'A bejelentkezés befejeződött, de a NeoAgent nem tudta megtartani a böngésző munkamenetet. Kérjük, jelentkezzen be újra. Ha ez továbbra is megtörténik, a háttér-munkamenet-cookie valószínűleg nem őrződik meg.';

  @override
  String get signInToThisNeoagentServer =>
      'Jelentkezzen be erre a NeoAgent szerverre, mielőtt beolvassa a párosító QR-kódot.';

  @override
  String get signInWithAHardwareKey =>
      'Jelentkezzen be jelszava helyett hardverkulccsal vagy jelszóval. ';

  @override
  String get signInWithASecurityKey => 'Jelentkezzen be biztonsági kulccsal';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Jelentkezzen be a $arg1 fiókkal';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Jóváhagyja a NeoAgentet a $arg1-fiókjában. Nincs másolható kulcs.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Várom a $arg1-t. Fejezze be a böngészőben.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Illessze be a $arg1 kódot';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Miután jóváhagyta a NeoAgentet, a $arg1 egyszeri kódot mutatott. Illessze be ide.';
  }

  @override
  String get signInCode => 'Bejelentkezési kód';

  @override
  String signedInWithArg1(Object? arg1) {
    return '$arg1 fiókkal bejelentkezve.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Sikertelen bejelentkezés: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Jelentkezzen be ugyanazzal az e-mail címmel és fő jelszóval, amelyet a Bitwardenben használ. A fő jelszót és a kétlépcsős kódot csak a bejelentkezéshez használják, és soha nem tárolják vagy küldik el az AI-nak.';

  @override
  String get signOut => 'Jelentkezzen ki';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Mindenhol kijelentkezik @$arg1?';
  }

  @override
  String get signOutEverywhere => 'Jelentkezzen ki mindenhol';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API híd';

  @override
  String get signalCliServerUrl => 'signal-cli szerver URL-je';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return '@$arg1 aláírva minden munkameneten kívül.';
  }

  @override
  String get signedInDevices => 'Bejelentkezett eszközök';

  @override
  String get signedInWithin24Hours => '24 órán belül bejelentkezett';

  @override
  String get signingSecret => 'Aláírási titok';

  @override
  String sinceArg1(Object? arg1) {
    return '$arg1 óta';
  }

  @override
  String sinceArg12(Object? arg1) {
    return '$arg1 óta';
  }

  @override
  String get singleMessage => 'Egyetlen üzenet';

  @override
  String get singleUse => 'Egyszer használatos';

  @override
  String get skill => 'Ügyesség';

  @override
  String get skillChanges => 'Változások a készségekben';

  @override
  String get skillContent => 'Képességtartalom';

  @override
  String get skills => 'Készségek';

  @override
  String get skip => 'Kihagyás';

  @override
  String get skipForNow => 'Most hagyd ki';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Hagyja ki ezt a feladatot, mielőtt meghívná a modellt.';

  @override
  String get slackMessageReceived => 'Laza üzenet érkezett';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Aludjon $arg1 munkameneteket';
  }

  @override
  String get smartSelector => 'intelligens választó';

  @override
  String get smartSelector2 => 'Intelligens választó';

  @override
  String get smartSelectorPool => 'Smart Selector Pool';

  @override
  String get smtpHost => 'SMTP gazdagép';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp e-mail küldő jelszava tls megerősítő értesítések visszaállítása';

  @override
  String get smtpPassword => 'SMTP jelszó';

  @override
  String get smtpPort => 'SMTP port';

  @override
  String get smtpPortMustBeAWhole =>
      'Az SMTP-portnak egész számnak kell lennie 1 és 65535 között.';

  @override
  String get smtpUsername => 'SMTP felhasználónév';

  @override
  String get soTheRunStartsThatMuch =>
      'szóval a futás sokkal korábban kezdődik.';

  @override
  String get socialBehaviorOff => 'Társas viselkedés kikapcsolva';

  @override
  String get socialIntelligence => 'szociális intelligencia';

  @override
  String get socialIntelligence2 => 'Társadalmi intelligencia';

  @override
  String get socialObservability => 'Társadalmi megfigyelhetőség';

  @override
  String get socialReach => 'társadalmi elérést';

  @override
  String get socialReach2 => 'Társadalmi elérés';

  @override
  String get socialReach3 => 'Social Reach';

  @override
  String get socialReachUpdated => 'A Social Reach frissítve.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'A közösségi forrásokat az ügynökök közvetlenül olvashatják, ideértve a hírcsatornákat, adattárakat, Reddit, X-et, videókat és cookie-alapú piaci adatokat.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Valami elromlott. Kérjük, próbálja újra.';

  @override
  String get source => 'Forrás';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Tér vagy csevegés azonosítója, amelyet akkor használnak, amikor ez az ügynök beszélgetést indít.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space webhook és alkalmazás visszahívási támogatása';

  @override
  String get speaking => 'Beszéd';

  @override
  String get speechToSpeechModelUsingThe =>
      'beszéd-beszéd modell az OpenAI vagy a Google kulcs használatával ';

  @override
  String get speechToText => 'Beszéd-szöveg';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'A beszédből szöveggé átírja a hangjegyzeteket és a diktálást. Az Auto OpenAI-t, Geminit vagy Deepgramot használ, attól függően, hogy melyik rendelkezik API-kulccsal. A hangos válaszmodell a hangjegyzetekre válaszoló csevegési modell.';

  @override
  String get sqlConsole => 'SQL konzol';

  @override
  String get stable => 'Stabil';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'A Stable telepíti a legújabb közzétett háttérverziót.';

  @override
  String get stackTrace => 'verem nyoma';

  @override
  String get standard => 'Szabványos';

  @override
  String get standardView => 'Normál nézet';

  @override
  String get start => 'Indítsa el';

  @override
  String get startASessionToPlanOr =>
      'Indítson el egy munkamenetet a NeoAgent segítségével történő tervezéshez vagy építéshez.';

  @override
  String get startAndroid => 'Indítsa el az Androidot';

  @override
  String get startComputer => 'Indítsa el a számítógépet';

  @override
  String get startFullSetup => 'Indítsa el a teljes beállítást';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Indítsa el a beállítást';

  @override
  String get startTalking => 'Kezdj el beszélni';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Először indítsa el az Android telefont, majd dobjon ide egy .apk vagy .apks fájlt.';

  @override
  String get startTheServerLaterFromThe =>
      'A konfiguráció mentése után indítsa el a szervert később a listából.';

  @override
  String get startWithARecommendedTask => 'Kezdje egy ajánlott feladattal';

  @override
  String get startingAndroid => 'Android indítása';

  @override
  String get startingYourComputer => 'A számítógép indítása';

  @override
  String get startsWithXoxbFromYourSlack =>
      'xoxb-vel kezdődik. A Slack alkalmazás hitelesítő adataiból.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting hiba: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statisztika fut tokenek felhasználói diagramok sikerességi arány';

  @override
  String get status => 'Állapot';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'állapotadatbázis futásidejű virtuális gép szolgáltatók';

  @override
  String get statusIsNotLoadedYet => 'Az állapot még nincs betöltve.';

  @override
  String get stayManagedByYou => 'maradjon Ön által kezelt.';

  @override
  String get stayOnTheCall => 'Maradjon a hívásnál';

  @override
  String get stayedQuiet => 'Csendben maradt';

  @override
  String get steering => 'KORMÁNYZÁS';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'A $arg2 $arg1 LÉPÉSE';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Lépések $arg1';
  }

  @override
  String get stop => 'Leállítás';

  @override
  String get stop2 => 'Leállítás (⌘.)';

  @override
  String get stopManaging => 'Hagyd abba az irányítást';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Abbahagyja a $arg1 kezelését?';
  }

  @override
  String get stopRun => 'Hagyd abba a futást';

  @override
  String get stopSpeaking => 'Hagyd abba a beszédet';

  @override
  String get stoppedBeforeCompletion => 'Befejezés előtt leállt';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting Error: $arg1';
  }

  @override
  String get storage => 'Tárolás';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'titkosítva tároljuk, és csak a saját futtatásához használjuk.';

  @override
  String get storedMetrics => 'Tárolt mutatók';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Csak a Bitwarden munkamenetkulcsot tárolja titkosítva ezen a szerveren, így a kapcsolatok túlélik az újraindításokat. Bármikor lezárhatja.';

  @override
  String get strong => 'Erős';

  @override
  String get strongPassword => 'Erős jelszó.';

  @override
  String get subAgent => 'Alügynök';

  @override
  String get subagentUpdate => 'Subagent frissítés';

  @override
  String get subagentUpdate2 => 'Subagent frissítés.';

  @override
  String get successRate => 'Siker arány';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Javaslatok: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Foglalja össze utolsó futásomat';

  @override
  String get supportUrl => 'Támogatási URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Támogatott: rain_start, snow_start, wind_alert, hőmérséklet_felül, hőmérséklet_alul';

  @override
  String get switchAgent => 'Ügynök váltása';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'A NeoAgent Workspace elérési útjain nem engedélyezettek a szimbolikus hivatkozások.';

  @override
  String get syncNow => 'Szinkronizálás most';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'A rendszer adatvédelmi beállításai';

  @override
  String get tableInfoUsers => 'Táblázat információ (felhasználók)';

  @override
  String get tagsOnly => 'Csak címkék';

  @override
  String get tasks => 'Feladatok';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'A feladatok önállóan futnak, és üzenetet küldenek Önnek a ';

  @override
  String get teach => 'Taníts';

  @override
  String get teachingInProgress => 'Tanítás folyamatban';

  @override
  String get team => 'Csapat';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'A csapatlinkek soha nem tesznek senkit szerveradminisztrátorrá. Az adminisztrátorok futtatják a ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Csapatterek, szobák, csatornák és élő közösségek.';

  @override
  String get teamsMessageReceived => 'Csapatok üzenete érkezett';

  @override
  String get templates => 'Sablonok';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Az ideiglenes beállítási fájlok később törlődnek.';

  @override
  String get tenantId => 'Bérlői azonosító';

  @override
  String get testConnection => 'Teszt kapcsolat';

  @override
  String get testConnection2 => 'Kapcsolat tesztelése';

  @override
  String get textChat => 'Szöveg és csevegés';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'amelyek hozzáadták a saját kulcsukat, továbbra is használják.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Ez az e-mail már egy meglévő fiókhoz tartozik. Először jelentkezzen be, majd kapcsolja be a Google-t a fiókbeállításokból.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Ez az e-mail már össze van kapcsolva egy másik fiókkal.';

  @override
  String get thatQrCodeIsNotA =>
      'Ez a QR-kód nem a NeoAgent bejelentkezési kérelme.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Ez a QR-kód nem a NeoAgent párosítási kérelme.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Ez a biztonsági kulcs már regisztrálva van ennél a fióknál.';

  @override
  String get theAddress => 'A cím';

  @override
  String get theAddressOfYourBluebubblesServer => 'A BlueBubbles szerver címe.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Az emberek és az OAuth-szolgáltatók eléréséhez használt cím ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Az ügynök beolvassa az Ön által említett időket, és ütemezett feladatokat hajt végre ebben az időzónában.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Az ügynök minden érzékeny eszköz előtt megkérdezi, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Az ügynök figyelmen kívül hagyja ezt a képességet.';

  @override
  String get theAppCouldNotReachThis =>
      'Az alkalmazás nem tudta elérni ezt a NeoAgent-telepítést. Ellenőrizze a hálózati kapcsolatot, vagy győződjön meg arról, hogy a szolgáltatás URL-címe helyes.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'A böngésző blokkolta a $arg1 felé irányuló kérést a tartalombiztonsági szabályzat miatt.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'A böngésző letiltott egy szükséges kérést a Tartalombiztonsági szabályzat miatt.';

  @override
  String get theCloudWorkspace => 'a felhő munkaterület';

  @override
  String get theComputerCouldNotStart => 'A számítógép nem tudott elindulni';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'A számítógépnek több szabad lemezterületre van szüksége a NeoAgent gazdagépen. Szabadítson fel egy kis helyet, majd próbálja újra.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'A számítógép futtatókörnyezete javításra szorul. Futtassa a NeoAgent Doctor programot, majd próbálja újra.';

  @override
  String get theConnectionTestFailed => 'A csatlakozási teszt nem sikerült.';

  @override
  String get theDesktopDidNotStart => 'Az asztal nem indult el';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'A felfedezett NeoAgent hiányos azonosító adatokat adott vissza.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'A felfedezett NeoAgent nem támogatott beállítási protokollt használ.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'A felfedezett szolgáltatás nem a NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'A letöltött NeoAgent futtatókörnyezet nem ment át az ellenőrzésen.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'A Google Csevegőtér webhookja, amelyre az ügynöknek közzé kell tennie.';

  @override
  String get theInstallerIsNoLongerAvailable => 'A telepítő már nem elérhető.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Az interaktív Linux asztal a NeoAgent webalkalmazásban érhető el.';

  @override
  String get theIntroIsNotAvailableOn =>
      'A bevezető nem érhető el ezen az eszközön.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'A legfrissebb minden fiókban fut.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'A legutóbbi szinkronizálási ablak véget ért a $arg1-vel, és nem talált új Health Connect rekordot. Az alábbi tárolt mutatók korábbi szinkronizálásokból származnak.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'A Linux grafikus munkamenet nem fut.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Az élő hangmodell nem válaszolt. Próbáld újra.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'A helyi NeoAgent parancs a $arg1 kóddal fejeződött be.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'A helyi NeoAgent parancs időtúllépést ért el.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'A helyi NeoAgent futtatókörnyezet javításra szorul.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'A helyi futási környezet javításra szorul ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'A helyi felhasználó saját könyvtára nem érhető el.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'A NeoAgent e-mail fiók regisztrációs visszaigazolásokat küld, bejelentkezést ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'A fő ügynök szükség esetén automatikusan létrejön.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'A megfelelő NeoAgent futtatókörnyezet hiányzik ebből a kiadásból.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'A legfontosabb bejövő webhook, amelyre az ügynöknek el kell küldenie.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'A modellek között a Smart Selector automatikusan útvonalat mutat.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'A NeoAgent háttérprogram letöltése nem egyezik a jegyzékével.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'A NeoAgent háttérprogram letöltése nem volt teljes.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'A számítógép NeoAgent háttérrendszere nem válaszol a porton ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'A NeoAgent backend futási környezetet nem lehetett letölteni.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'A NeoAgent háttérprogram túl sokáig tartott a válaszadáshoz a $arg1 esetén.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'A NeoAgent telepítése a normál 401 helyett HTTP 402-vel válaszolt az érvénytelen hitelesítési adatokra. Ellenőrizze a fordított proxyt, a hitelesítési átjárót vagy a fizetéssel kapcsolatos szabályokat az adott kiszolgálón.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'A NeoAgent központi telepítés HTTP 402-vel válaszolt.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'A NeoAgent telepítése HTTP 402-vel válaszolt. Ellenőrizze a fordított proxyt, a hitelesítési átjárót vagy a fizetéssel kapcsolatos szabályokat az adott kiszolgálón.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Az a NeoAgent-példány, amelyhez ez az alkalmazás csatlakozik.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'A NeoAgent kiadási szolgáltatás érvénytelen adatokat adott vissza.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'A NeoAgent futásidejű melléktermék metaadatai érvénytelenek.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'A NeoAgent futásidejű jegyzéke nem ment át az aláírás ellenőrzésén.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'A NeoAgent futásidejű jegyzékében nincsenek melléktermékek.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'A NeoAgent futásidejű jegyzék aláírása érvénytelen.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'A BlueBubblesben beállított jelszó.';

  @override
  String get thePeopleYouManageStayWith =>
      'Az általad kezelt emberek veled maradnak.';

  @override
  String get theProviderAnswers => 'válaszol a szolgáltató.';

  @override
  String get theQueryReturnedNoRows => 'A lekérdezés nem adott vissza sorokat.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'A kért asztali kijelző nem érhető el.';

  @override
  String get theRest => 'a többit.';

  @override
  String get theRestEndpointForYourSignal =>
      'A REST végpont a signal-cli példányhoz.';

  @override
  String get theRunIsPausedUntilYou => 'A futás szünetel, amíg nem válaszol.';

  @override
  String get theRunStartsAtTheScheduled =>
      'A futás a tervezett időpontban indul.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'A futtatókörnyezet egy könnyű Debian Linux asztali számítógép Chromium, PCManFM, Mousepad, LXTerminal, Python, Git és szabványos parancssori eszközökkel. A kapacitását a NeoAgent gazdagép kezeli.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'A biztonsági kulcs regisztrációja nem indítható el.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'a szerver csak egy ujjlenyomatot tart meg belőle.';

  @override
  String get theServerOnThisComputerIs =>
      'A szerver ezen a számítógépen nem fut';

  @override
  String get theServerReportedNoHealthChecks =>
      'A szerver nem jelentett állapotvizsgálatot.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'A bot által használt Signal telefonszám.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'A Teams bejövő webhookja, amelyre az ügynöknek közzé kell tennie.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'A kéttényezős kihívás lejárt. Jelentkezzen be újra.';

  @override
  String get theTwoFactorCodeIsNot => 'A kéttényezős kód nem érvényes.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Az ellenőrzött futásidejű csomagot nem lehetett végrehajthatóként megjelölni.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Az ellenőrzött futásidejű csomagból hiányoznak a szükséges fájlok.';

  @override
  String get theWebAppCouldNotReach =>
      'A webalkalmazás nem tudta elérni a NeoAgent háttérrendszert.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'A webalkalmazás nem tudta elérni a NeoAgent háttérrendszert a $arg1 címen. Ellenőrizze a böngészőkonzolt és a fordított proxy/hálózat konfigurációját.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'maguk; a szerver üzemeltetője először eltávolítja az admin-t ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Ezek a csatornák csendben maradnak. Ha újra szeretne hallani róluk, adja hozzá őket a Ki tud üzenetet küldeni az adott platformhoz.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Ezek a listák nem kötelezőek, kivéve, ha a fenti szakasz csak jóváhagyásra van beállítva.';

  @override
  String get thesePeopleAnywhere => 'Ezek az emberek, bárhol';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Ezek az emberek privát chatekben és bármely megosztott csoportban üzenetet küldhetnek a $arg1 számára.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Ezek az emberek egy-egy üzenetet küldhetnek a $arg1-nek. Ez nem engedi, hogy csoportokban beszéljenek.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Ezek az emberek csak az Ön által kiválasztott csoportban küldhetnek üzenetet a $arg1 számára.';
  }

  @override
  String get thesePeopleInOneGroup => 'Ezek az emberek egy csoportban';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'ezek a kapcsolók, soha nem a chatjei, az emlékei vagy a fájljai.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Ez a fiók feloldja a NeoAgent zárolását ezen a gépen.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Ez az ügynök bármely jogosult fogadó ügynökre delegálhat.';

  @override
  String get thisAgentIsUsingAServer =>
      'Ez az ügynök egy szerver által felügyelt Trello API-kulcsot használ. Csak alább kell engedélyeznie egy fióktokkent.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Ez a build nem kommunikálhat ezzel a NeoAgent-telepítéssel.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Ez a kód egy másik NeoAgent szerverhez tartozik: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Ez az asztal csatlakoztatva van';

  @override
  String get thisDevice => 'Ez a készülék';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Ez az eszköz: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Ez az eszköz nem tud biztonsági kulcsokat regisztrálni. Nyissa meg a NeoAgentet egy böngészőben HTTPS-en keresztül, hogy hozzáadjon egyet.';

  @override
  String get thisDeviceUnavailable => 'Ez az eszköz – nem elérhető';

  @override
  String get thisFileHasNoContent => 'Ennek a fájlnak nincs tartalma.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Ez elrejti a \"$arg1\"-t az útválasztás és a kiválasztás elől.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Ez az integráció jelenleg ügynökönként egy csatlakoztatott fiókot támogat. A cseréhez nyissa meg újra a beállítást.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Ez az integráció már nem érhető el.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Ez a bevezető teljes képernyős, fekvő lejátszáshoz készült.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Ez egy felügyelt telepítés. A kezelője kigurul ';

  @override
  String get thisMayTakeAMoment => 'Ez eltarthat egy ideig.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Ez az MCP-kiszolgáló már nincs konfigurálva.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Ez a memória véglegesen el lesz távolítva.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Ez a NeoAgent build nincs beállítva a háttér-futási környezetek ellenőrzésére.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Ez véglegesen törli az összes adatot, és ez nem lehetséges ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Ezzel véglegesen törli a fiókot és minden hozzá tartozó dolgot: ';

  @override
  String get thisPersonAnywhere => 'Ez a személy, bárhol';

  @override
  String get thisPersonInOneGroup => 'Ez a személy egy csoportban';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Ez a QR-bejelentkezési kérelem lejárt. Hozzon létre egy új kódot, és próbálja újra.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'ez a qr bejelentkezési kérelem lejárt';

  @override
  String get thisQrLoginRequestIsStill =>
      'Ez a QR-bejelentkezési kérelem még jóváhagyásra vár.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Ezt a QR-bejelentkezési kérelmet már használták.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Ezzel eltávolítja a Home Assistant beállítását és az ügynök csatlakoztatott példányát.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Ezzel eltávolítja a NeoRecall háttér-URL-jét és az összes kapcsolódó NeoRecall-fiókot ehhez az ügynökhöz.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Ezzel eltávolítja a Nextcloud URL-t és az összes kapcsolódó Nextcloud-fiókot az ügynökhöz.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Ezzel eltávolítja a Trello-beállítást és az ügynökhöz kapcsolódó fiókokat.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Ehhez hitelesített munkamenetre van szükség ugyanazon a NeoAgent kiszolgálón.';

  @override
  String get thisRunDidNotProduceA =>
      'Ez a futtatás nem adott felhasználónak szóló választ.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Ez a futás nem tartalmaz rögzített lépésadatokat.';

  @override
  String get thisServer => 'ezt a szervert.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Ez a szerver nem számol be szolgáltatói beállításokról.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Ez a képesség már nincs telepítve.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Ez a feladat még nem fejeződött be, így továbbra is a következőnél kezdődik ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Ez a feladat csak akkor fut le, ha megnyomja a Futtatás most gombot.';

  @override
  String get thisWeek => 'Ezen a héten';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Ez importálja a választ a $arg1 fájlba.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Ezzel eltávolítja a \"$arg1\" fájlt.';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Ezzel eltávolítja a \"$arg1\" elemet a szerverlistáról.';
  }

  @override
  String get time => 'Idő';

  @override
  String get timeZone => 'időzóna';

  @override
  String get timeZone2 => 'Időzóna';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Időtúllépés$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Az időzónák nem listázhatók: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Nem sikerült beolvasni az eszköz időzónáját: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Nem sikerült menteni az eszköz időzónáját: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'a $arg1-hez';
  }

  @override
  String get toUseTheServerDefault =>
      'az alapértelmezett szerver használatához.';

  @override
  String get today => 'Ma';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Token költségkeret a @$arg1 számára. Hagyjon üresen egy mezőt ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Token költségkeret minden fiókhoz saját felülírás nélkül. Hagyja a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'token költségvetési korlát 4 órás heti kvóta felhasználó';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'token költségvetési korlát 4 órás heti kvóta globális';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'A token használata nem érhető el ezen a szerververzión.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Bármely fiók 4 órán belül felhasználható tokenek.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Bármely fiók által felhasználható tokenek 7 napon belül.';

  @override
  String get tokensPerDay => 'Token naponta';

  @override
  String get tokensPerRun => 'Tokenek futásonként';

  @override
  String get tokensToday => 'Tokenek ma';

  @override
  String get tokensUsed => ' használt tokenek';

  @override
  String get tomorrowPrep => 'Holnap felkészülés';

  @override
  String get tooManyAttempts => 'túl sok próbálkozás';

  @override
  String get tooManySignInAttemptsPlease =>
      'Túl sok bejelentkezési kísérlet. Kérjük, várjon, és próbálja újra.';

  @override
  String get tool => 'Eszköz';

  @override
  String get toolApproval => 'Szerszám jóváhagyása';

  @override
  String get toolApprovalRequired => 'Szerszám jóváhagyása szükséges';

  @override
  String get toolCompleted => 'A szerszám elkészült';

  @override
  String get toolFailed => 'Az eszköz meghibásodott';

  @override
  String get toolPermissions => 'Eszközengedélyek';

  @override
  String get toolStarted => 'Az eszköz elindult';

  @override
  String get tools => 'Eszközök';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'A NeoAgentbe nem beépített eszközök, beleértve a csatlakoztatott MCP-kiszolgálókat és az egyéni eszközszolgáltatókat.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Ajánlott szerszámok ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'A kezelt fiók által használt eszközök';

  @override
  String get topUsers => 'Legjobb felhasználók';

  @override
  String get topUsersAndRecentRuns =>
      'Legnépszerűbb felhasználók és legutóbbi futások';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Összesen: $arg1 tokenek a $arg2 futások során';
  }

  @override
  String get totalRuns => 'Összes futam';

  @override
  String get totalTokens => 'Összes token';

  @override
  String get totalUsers => 'Összes felhasználó';

  @override
  String get transcript => 'Átirat';

  @override
  String get transcript2 => 'ÁTÍRÁS';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Az átírás nem sikerült: $arg1';
  }

  @override
  String get transfer => 'Átadás';

  @override
  String get trelloApiKey => 'Trello API kulcs';

  @override
  String get trelloApiKeyIsRequired => 'Trello API-kulcs szükséges.';

  @override
  String get trelloSetup => 'Trello beállítása';

  @override
  String get triggerType => 'Trigger típusa';

  @override
  String get tryABroaderSearchLikeModels =>
      'Próbálkozzon szélesebb körű kereséssel, például modellekkel, böngészővel vagy hanggal.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Próbálja ki a szolgáltató nevét, „e-mail”, „limits”, „update” vagy „logs”.';

  @override
  String get tryAgain => 'Próbáld újra';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Próbáld újra. Ha ez továbbra is megtörténik, futtassa a NeoAgent Doctort a számítógép futásidejének ellenőrzéséhez.';

  @override
  String get tryAgainInAMoment => 'Próbálja újra egy pillanat múlva.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Próbálja újra, vagy futtassa a NeoAgent Doctor programot.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Próbálkozzon másik kereséssel, csatlakozzon egy üzenetküldő platformhoz, vagy adja meg kézzel a célazonosítót.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Kapcsolja be a csoportot, ha a $arg1 olyan üzeneteket is olvas, amelyek nem címkézik meg.';
  }

  @override
  String get turnOffComputer => 'Kapcsolja ki a számítógépet';

  @override
  String get turnOffOnlyForAMail =>
      'Csak önaláírt tanúsítvánnyal rendelkező levelezőszervernél kapcsolja ki.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Kapcsolja be, ha a Signal továbbra is keresi a bejövő csevegéseket.';

  @override
  String get turnTaking => 'fordulat vétel';

  @override
  String get turnTakingModel => 'Körbevevő modell';

  @override
  String get turnTakingOff => 'Felszállás';

  @override
  String get turnThisOffToKeepThis =>
      'Kapcsolja ki, hogy ez az ügynök teljesen elkülönüljön a többi ügynöktől.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return '$arg1 kikapcsolta';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return '$arg1, aki ezt a fiókot kezeli, kikapcsolta. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'A $arg1 kikapcsolta az Ön számára – csak ők módosíthatják';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Ki van kapcsolva neked, így nem tudod kiadni';

  @override
  String get twitchChatOverIrc => 'Twitch chat IRC-n keresztül';

  @override
  String get twoFactorAuthentication => 'Kéttényezős hitelesítés';

  @override
  String get twoFactorChallengeExpired => 'kétfaktoros kihívás lejárt';

  @override
  String get twoFactorCode => 'kétfaktoros kód';

  @override
  String get twoFactorSignInCompletedBut =>
      'A kétlépcsős bejelentkezés befejeződött, de a NeoAgent nem tudta megtartani a böngésző munkamenetet. Kérjük, jelentkezzen be újra.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Kétlépcsős bejelentkezés (csak ha engedélyezve van)';

  @override
  String get type => 'Írja be';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'A megerősítéshez írja be a $arg1-t';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'típusú szöveg nem támogatott ezen a platformon.';

  @override
  String get typedInTheBrowser => 'Beírta a böngészőbe';

  @override
  String get typedText => 'Gépelt szöveg';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'nem találja a java futtatókörnyezetet';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Nem lehet megnyitni az időbeállításokat ezen a builden.';

  @override
  String get unableToOpenWiFiSettings =>
      'Nem lehet megnyitni a Wi-Fi-beállításokat ezen a builden.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Nem lehet megőrizni a kiválasztott asztali képernyőt.';

  @override
  String get unclearWhoItWasFor => 'Nem világos, kinek szólt';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'visszavonva. A megerősítéshez írja be a felhasználónevét.';

  @override
  String get unknownAccount => 'Ismeretlen fiók';

  @override
  String get unknownAgent => 'Ismeretlen ügynök';

  @override
  String get unknownBrowser => 'Ismeretlen böngésző';

  @override
  String get unknownDevice => 'Ismeretlen eszköz';

  @override
  String get unknownError => 'ismeretlen hiba';

  @override
  String get unknownLocalComputerPermission =>
      'Ismeretlen helyi számítógép engedély.';

  @override
  String get unknownLocation => 'Ismeretlen hely';

  @override
  String get unknownPublishTime => 'Ismeretlen közzétételi idő';

  @override
  String get unknownSize => 'Ismeretlen méret';

  @override
  String get unlink => 'Leválasztás';

  @override
  String get unreadOnly => 'Csak olvasatlan';

  @override
  String get unsavedChanges => 'Nem mentett módosítások';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Nem támogatott asztali kísérőparancs: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Nem támogatott módszer: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Szokatlan bejelentkezési figyelmeztetések';

  @override
  String updateArg1(Object? arg1) {
    return 'Frissítse a $arg1-t';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Frissítse az alapvető memóriabejegyzéseket az importálásból.';

  @override
  String get updateNow => 'Frissítse most';

  @override
  String get updateReady => 'Frissítés kész';

  @override
  String get updateSetup => 'Frissítse a beállítást';

  @override
  String get updateTheAccessListToAllow =>
      'Frissítse a hozzáférési listát a válaszok engedélyezéséhez.';

  @override
  String get updateTheServer => 'Frissíti a szervert?';

  @override
  String get updateTheServer2 => 'Frissítse a szervert';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Az időzóna automatikus frissítése a használt eszközről.';

  @override
  String updatedArg1(Object? arg1) {
    return 'frissített $arg1';
  }

  @override
  String get updates => 'Frissítések';

  @override
  String get updatesAreNotConfiguredForThis =>
      'A frissítések nincsenek konfigurálva ehhez a buildhez.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'frissítéseket, így az önfrissítés és a csatornaváltás itt ki van kapcsolva.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'frissítés frissítés most csatornastabil béta kiadás';

  @override
  String get usageAnalytics => 'Használati elemzés';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Használati és állapotjelzések, amelyek segítenek megmagyarázni a jelenlegi futási viselkedést anélkül, hogy először a naplókba bújnának bele.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'A használat teljesen visszaáll a $arg1-ben';
  }

  @override
  String get usageLeaderboard => 'használati ranglista';

  @override
  String get usageLimits => 'Használat és korlátok';

  @override
  String get usageLimits2 => 'Használat és korlátok';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      '8+ karaktert használjon. A hosszabb jelmondatok jól működnek.';

  @override
  String get useADateAndTimeFor =>
      'Használjon dátumot és időt, például 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Használjon nevet, telefonszámot vagy csevegési azonosítót.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Használjon olyan NeoRecall URL-t, amelyet a NeoAgent szerver elérhet. A NeoAgent PUBLIC_URL címének is elérhetőnek kell lennie ebből a böngészőből az OAuth visszahíváshoz.';

  @override
  String get useANewPasswordWithAt =>
      'Használjon új, legalább 8 karakterből álló jelszót.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Használjon egy Nextcloud URL-t, amelyet a NeoAgent szerver elérhet, például https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Használjon legalább 8 karakterből álló jelszót.';

  @override
  String get useASecureConnectionTls =>
      'Biztonságos kapcsolat (TLS) használata';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Használjon hitelesítő alkalmazást, például az Authy, 1Password vagy Google Authenticator alkalmazást.';

  @override
  String get useAtLeast1Vcpu => 'Használjon legalább 1 vCPU-t.';

  @override
  String get maxMemoryPerComputerMb =>
      'Maximális memória számítógépenként (MB)';

  @override
  String get maxVcpusPerComputer => 'Maximális vCPU számítógépenként';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Legalább $arg1. A számítógépek kevesebbet kapnak, ha a gazdagép elfoglalt.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'A maximális memória legalább $arg1 MB legyen.';
  }

  @override
  String get useAtLeast8Characters => 'Használjon legalább 8 karaktert.';

  @override
  String get useDefault => 'Alapértelmezés használata';

  @override
  String get useDefaultChannel => 'Használja az alapértelmezett csatornát';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Alapértelmezés használata (NeoAgent Workspace)';

  @override
  String get useFor => 'Használja';

  @override
  String get useManualDestination => 'Manuális célhely használata';

  @override
  String get useOrDoTheSameFor =>
      'használja, vagy tegye ugyanezt a csapattársaival.';

  @override
  String get usePerCategorySettingsBelow =>
      'Használja az alábbi kategóriánkénti beállításokat.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Alapértelmezett beállítások használata ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Használja a szervert ezen a számítógépen';

  @override
  String get useTheseForContextIfA =>
      'Használja ezeket a kontextushoz. Ha egy helyi URI nem érhető el közvetlenül a szerverről, kérjen meg, hogy biztosítsam a fájlt egy elérhető munkaterületen keresztül.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Használja ezt a hangszerelő ügynökökhöz. Hagyja ki az elszigetelt munkarobotoknál, amelyeknek maguknak kell befejezniük a közvetlen üzeneteket.';

  @override
  String get useTlsFromTheStartOf =>
      'Használja a TLS-t a kapcsolat kezdetétől, általában a 465-ös porton.';

  @override
  String get useYourOwnApiKeyFor =>
      'Használja saját API-kulcsát egy szolgáltatóhoz, vagy csatlakoztasson egy egyéni kulcsot ';

  @override
  String get usedByEveryAccountOnThis =>
      'Ezen a kiszolgálón minden olyan fiók használja, amelyhez nincs kulcs ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'A bejövő Slack események valódiságának ellenőrzésére szolgál.';

  @override
  String get userSummary => 'Felhasználói összefoglaló';

  @override
  String get username => 'Felhasználónév';

  @override
  String get usernameOrEmail => 'Felhasználónév vagy email';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'felhasználók keresnek e-mailben felhasználónév admin jelvény kezelt csapat';

  @override
  String get usesTheChatModelConfiguredIn =>
      'A Beállításokban konfigurált csevegési modellt használja';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'A telepített NeoAgent futtatókörnyezet használata';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Általában úgy néz ki, mint @bot:matrix.org';

  @override
  String get validEmail => 'érvényes email';

  @override
  String get value => 'Érték';

  @override
  String get vaultLocked => 'A páncélszekrény zárva';

  @override
  String get vaultOperationFailed => 'A trezorművelet meghiúsult.';

  @override
  String get verification => 'Ellenőrzés';

  @override
  String verificationArg1(Object? arg1) {
    return 'Ellenőrzés: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'ellenőrzés: $arg1';
  }

  @override
  String get verificationCompleted => 'Az ellenőrzés befejeződött.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Ellenőrzés állapota: $arg1';
  }

  @override
  String get verifiedTheResult => 'Ellenőrizte az eredményt';

  @override
  String get verifyingTheDownloadedRuntime =>
      'A letöltött futási környezet ellenőrzése';

  @override
  String get versionAndUptime => 'Verzió és üzemidő';

  @override
  String versionArg1(Object? arg1) {
    return '$arg1 verzió';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'A $arg1 verzió telepítve van, de a $arg2 továbbra is fut.';
  }

  @override
  String get videoLinks => 'Videó linkek';

  @override
  String get viewDesktop => 'Asztal megtekintése';

  @override
  String get viewLastRun => 'Az utolsó futás megtekintése';

  @override
  String get viewLogs => 'Naplók megtekintése';

  @override
  String get vmImageMemoryCpuQemuRuntime => 'vm képmemória cpu qemu futásidejű';

  @override
  String get voice => 'Hang';

  @override
  String get voiceAssistant => 'Hang asszisztens';

  @override
  String get voiceCall => 'HANGHÍVÁS';

  @override
  String get voiceCall2 => 'Hanghívás';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'hanghívás gpt-live gemini élő modell beszéd valós idejű';

  @override
  String get voiceCallsRunOnALive =>
      'A hanghívások élő beszéd-beszéd modellen futnak, ugyanolyan személyiséggel, memóriával és csevegési előzményekkel, mint a NeoAgent. Azonnal válaszol, és a valódi munkát átadja a normál ügynöknek, amely folyamatosan fut a háttérben.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'hangjegyzet beszédátírás API-kulcs';

  @override
  String get voiceNotesAndDictation => 'Hangjegyzetek és diktálás';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'A hanglejátszás nem érhető el ezen az eszközön.';

  @override
  String get voiceReplyModel => 'Hangos válasz modell';

  @override
  String get waitingForApproval => 'Jóváhagyásra vár: ';

  @override
  String get waitingForCode => 'Kódra várva';

  @override
  String get waitingForInput => 'Bemenetre vár';

  @override
  String get waitingForServerOrFlutterLog =>
      'Várakozás a szerver vagy a Flutter napló kimenetére…';

  @override
  String get waitingForTaskEvents => 'Várakozás a feladat eseményeire...';

  @override
  String get waitingForYou => 'vár rád';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Választ akartam kapni a következőtől: $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Beszélni szeretne veled · ${arg1}s';
  }

  @override
  String get weak => 'Gyenge';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Időjárás, naptár és prioritások a nap kezdete előtt.';

  @override
  String get weatherEvent => 'Időjárás esemény';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'Webböngésző';

  @override
  String get webSearchApiKey => 'webes kereső API kulcs';

  @override
  String get webhookOrRestChannelPosting =>
      'Webhook vagy REST csatorna közzététele';

  @override
  String get webhookSecret => 'Webhook titka';

  @override
  String get webhookUrlCopied => 'Webhook URL másolva';

  @override
  String get weekdays => 'Hétköznapokon';

  @override
  String get weekdays0730 => 'Hétköznap · 07:30';

  @override
  String get weekdays1800 => 'Hétköznap · 18:00';

  @override
  String get weekly => 'Hetente';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Heti limit $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Heti limit (tokenek)';

  @override
  String get weeklyReview => 'Heti áttekintés';

  @override
  String get weeklyUsage => 'Heti használat';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Súly $arg1 rekordok';
  }

  @override
  String get welcomeToNeoagent => 'ÜDVÖZÖLJÜK A NEOAGENTBEN';

  @override
  String get welcomeToNeoagent2 => 'Üdvözöljük a\nNeoAgentben';

  @override
  String get whatAreYouAdding => 'mit adsz hozzá?';

  @override
  String get whatIsOnTomorrow => 'Mi lesz holnap?';

  @override
  String get whatShouldNeoagentLearn => 'Mit kell tanulnia a NeoAgentnek?';

  @override
  String get whatShouldWeBuild => 'Mit építsünk?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Amit Ön és a NeoAgent mond, az megjelenik itt és a chatben.';

  @override
  String get whatsappPersonalMessageReceived =>
      'WhatsApp személyes üzenet érkezett';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Ha a Csak jóváhagyott lehetőséget választja, adjon hozzá személyeket vagy csoportokat alább.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Ahová ennek az ügynöknek el kell küldenie a válaszokat.';

  @override
  String get whoCanMessage => 'Ki tud üzenetet küldeni';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Ki tud üzenetet küldeni a $arg1-n';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Ki küldhet egy-egy üzenetet a $arg1 számára.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Ki tud beszélni a $arg1-vel egy csoportban, csatornán vagy szobában.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'ki kezeli ezt a fiókot kikapcsolva: ';

  @override
  String get whoManagesWhom => 'Ki irányít kit';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Aki elfogad egy linket, az csak a hozzá tartozó eszközökkel csatlakozik a csapatához ';

  @override
  String get wholeGroup => 'Az egész csoport';

  @override
  String get wholeGroups => 'Egész csoportok';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Miért válaszolt vagy maradt csendben a $arg1 a $arg2 csoportokban?';
  }

  @override
  String get windowsApp => 'Windows alkalmazás';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'Munkahelyi fiók';

  @override
  String get workOnAProjectWithNeoagent =>
      'Dolgozzon egy projekten a NeoAgent segítségével';

  @override
  String workflowArg1(Object? arg1) {
    return 'Munkafolyamat: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return '$arg1 munkavégzés a felhőalapú számítógépen. A NeoAgent beolvassa és szerkeszti a fájlokat, és parancsokat és böngészőt is futtathat.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'A háttérben dolgozik: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Munkaterület-konfiguráció és fiókbiztonság egy helyen.';

  @override
  String get workspaceFiles => 'Munkaterület fájlok';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Munkaterület, modellek és diagnosztikai vezérlők.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'A munkaterület felülbírálásának abszolút elérési útnak kell lennie.';

  @override
  String wroteArg1(Object? arg1) {
    return '$arg1-t írt';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttprequest hiba';

  @override
  String get yesterday => 'tegnap';

  @override
  String get youAreInControl => 'Te irányítod';

  @override
  String get youCanFollowAlongOnThe => 'Az asztalon követheti.';

  @override
  String get youCanLeaveATeamAt =>
      'Bármikor elhagyhatja a csapatot; ismét a saját beállításaid érvényesülnek.';

  @override
  String get youCanLeaveAtAnyTime => 'Bármikor távozhat a Csapat oldaláról.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Ön döntheti el, hogy az ügynöke mely eszközöket használhatja a Beállítások › alatt ';

  @override
  String get youDonTManageAnyoneYet =>
      'Még nem irányítasz senkit. Hozzon létre egy meghívó linket alább, és ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Nem mentett beállításai vannak. mit szeretnél csinálni?';

  @override
  String get youReOnYourOwnYou =>
      'Ön egyedül van: Ön dönti el, milyen eszközöket használhat az ügynöke. Ha ';

  @override
  String get yourAccountAndUsageOnA =>
      'fiókja -- és a használat egy olyan modellen, amelyet a saját kulcsa támogat ';

  @override
  String get yourAccountHasBeenDeleted => 'Fiókját törölték.';

  @override
  String get yourAgentWillBeAllowed => 'Ügynöke a következőket engedélyezi:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Az alkalmazásai és fájljai mentésre kerülnek.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Alkalmazásai és fájljai mentve maradnak.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Az Ön $arg1 kulcsa';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'A segédréteg a rögzítéshez, a kontextushoz és a műveletekhez.';

  @override
  String get yourComputerIsAsleep => 'A számítógép alszik';

  @override
  String get yourComputerIsOff => 'A számítógép ki van kapcsolva';

  @override
  String get yourComputerIsReady => 'A számítógép készen áll';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'A jelenlegi jelszava helytelen.';

  @override
  String get yourData => 'Az Ön adatai';

  @override
  String get yourDataExportWasCopiedTo =>
      'Az exportált adatot a vágólapra másolta.';

  @override
  String get yourDesktopIsReady => 'Az asztal készen áll';

  @override
  String get yourLinuxComputer => 'Az Ön Linux számítógépe';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Az Ön tartózkodási helyét soha nem követjük folyamatosan, és soha nem tároljuk a szervereinken. Csak helyileg használjuk, hogy ellenőrizzük az aktív feladatokat.';

  @override
  String get yourManager => 'a menedzsere';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Az Ön Mattermost webhelyének URL-címe, ha a REST API-t használja.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'A munkamenet lejárt, vagy a böngésző nem őrizte meg. Kérjük, jelentkezzen be újra.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'A munkamenet lejárt. Kérjük, jelentkezzen be újra.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'A felhasználónév vagy a jelszó helytelen.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Áttekintés';

  @override
  String get sectionDiagnostics => 'Diagnosztika';

  @override
  String get sectionVolume => 'kötet';

  @override
  String get sectionSession => 'Munkamenet';

  @override
  String get sectionDeliverable => 'Szállítható';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'A helyi futási környezet még nem írt naplófájlt.';

  @override
  String get thisComputer => 'Ezt a számítógépet';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'A béta telepíti a legújabb kiadás előtti háttérprogramot. Durva élekre számítsanak.';

  @override
  String get copiedFinalResponse => 'Végső válasz másolva';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'A végső válasz itt jelenik meg, amikor a futás befejeződik.';

  @override
  String get waitingForTheFirstStep => 'Az első lépésre várva…';

  @override
  String get loadingPrompt => 'Prompt betöltése…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Erre a futtatásra nem érkezett végső válasz.';

  @override
  String get readyToSignIn => 'Készen áll a bejelentkezésre';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Váltson „Alapértelmezett” vagy „Mindig kérdez” értékre a jóváhagyási ellenőrzések újbóli engedélyezéséhez.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Kormányzási frissítés vagy következő megjegyzés küldése az aktuális futáshoz...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Nincs hálózati kapcsolat. A NeoAgent újracsatlakozik, amikor az eszköz újra online lesz.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'A legújabb kormányzási frissítést alkalmazta az aktuális futáshoz.';

  @override
  String get preparingThePrivateVoiceSession =>
      'A privát hangos munkamenet előkészítése…';

  @override
  String get preparingYourComputer => 'A számítógép előkészítése';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'A NeoAgent letölti és előkészíti a biztonságos Linux rendszert. Ez csak az első alkalommal történik meg.';

  @override
  String get moreFreeSpaceIsNeeded => 'Több szabad területre van szükség';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Szabadítson fel lemezterületet a NeoAgent gazdagépen, majd próbálja újra. Meglévő számítógépes adatai biztonságban vannak.';

  @override
  String get androidReady => 'Android készen áll';

  @override
  String get startingAndroid2 => 'Android indítása…';

  @override
  String get androidStopped => 'Android leállt';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Az első indításkor letöltődik az Android SDK és a rendszerkép, ami több percig is eltarthat.';

  @override
  String get androidIsStopped => 'Az Android leállt';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Indítsa el a felügyelt Android-környezetet, amikor szüksége van rá.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Hagyja, hogy a NeoAgent működjön ezen a számítógépen';

  @override
  String get firstTimeSetupIsInProgress => 'Az első beállítás folyamatban van.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'A NeoAgent használhatja az Ön által engedélyezett hozzáférést.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Szabadítson fel néhány gazdagép-tárhelyet, és próbálja újra.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Kezdje el, amikor azt szeretné, hogy a NeoAgent segítsen itt.';

  @override
  String get systemPermissionMissing => 'Hiányzik a rendszerengedély';

  @override
  String get connectingThisDevice => 'Az eszköz csatlakoztatása';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'A biztonságos helyi kapcsolat létrehozása folyamatban van.';

  @override
  String get recordingYourDemonstration => 'A bemutató rögzítése';

  @override
  String get noErrorsInTheRecentLog => 'Nincs hiba a legutóbbi naplóban.';

  @override
  String get loadingAccounts => 'Fiókok betöltése…';

  @override
  String get neverSignedIn => 'Soha nem jelentkezett be';

  @override
  String get emptyUsesTheServerDefault =>
      'Az üres a kiszolgáló alapértelmezett értékét használja.';

  @override
  String get followTheSelectedSession => 'Kövesse a kiválasztott munkamenetet';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Tervezési mód csak ellenőrzi. Váltson ügynök módba, hogy a NeoAgent szerkeszthesse a fájlokat.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'A fiók e-mail-címének hozzáadásához vagy módosításához szükséges.';

  @override
  String get confirmNewPassword => 'Erősítse meg az új jelszót';

  @override
  String get passwordChanged => 'Jelszó megváltozott.';

  @override
  String get thisRequestHasAlreadyBeenUsed => 'Ezt a kérést már felhasználták.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Ez a kérelem lejárt. Kérje meg a másik eszközt, hogy generáljon új kódot.';

  @override
  String get startQuickstart => 'Indítsa el a Gyorsindítást';

  @override
  String get createYourAccount => 'Hozd létre a fiókodat';

  @override
  String get showWorkAsSummaries => 'Munka megjelenítése összefoglalóként';

  @override
  String get tokensUsedByTheLatestRun =>
      'A legutóbbi futtatás során használt tokenek';

  @override
  String get listedTheWorkspaceRoot => 'Felsorolta a munkaterület gyökerét';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Hivatalos integrációk még nem állnak rendelkezésre.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Még nincs konfigurálva MCP-kiszolgáló. Adjon hozzá egyet, hogy felfedje eszközeit.';

  @override
  String get addAnMcpServerOrInstallA =>
      'A kezdéshez adjon hozzá egy MCP-kiszolgálót, vagy telepítsen egy készséget.';

  @override
  String get setUp => 'Állítsa be';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Hagyja üresen a tárolt érték megtartásához';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Ezzel eltávolítja a kiszolgálón lévő összes fiók címét.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Csak beszélj. Bármikor megszakíthatja. Koppintson a némításhoz.';

  @override
  String get tapAgainWhenYouAreDone => 'Koppintson újra, ha végzett.';

  @override
  String get workingOnATaskInTheBackground => 'Feladaton dolgozik a háttérben.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Beszédről beszédre ugyanaz a memória, eszközök és csevegési előzmények, mint a NeoAgent.';

  @override
  String get checkLink => 'Ellenőrizze a linket';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Ügynöke nem használhatja az ellenőrzött eszközöket.';

  @override
  String get notYoursToChange => 'Nem a tiéd változtatni';

  @override
  String get setByYou => 'Ön által beállított';

  @override
  String get noTools => 'Nincsenek szerszámok';

  @override
  String get untitledLink => 'Névtelen link';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Leáll, miután egy személy beváltja.';

  @override
  String get theOperator => 'Az operátor';

  @override
  String get smartSelectorOn => 'Intelligens választó bekapcsolva';

  @override
  String get startASessionToBegin => 'A kezdéshez indítson el egy munkamenetet';

  @override
  String get steerTheActiveRun => 'Irányítsd az aktív futást…';

  @override
  String get describeWhatToPlan => 'Írd le, mit tervezz…';

  @override
  String get stopDictation => 'Hagyd abba a diktálást';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Az üzenetek irányítják az aktuális futást · ⌘↵ küldés · ⌘. állj meg';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Tervezési mód csak ellenőrzi; semmi sem változik, amíg nem implementálja a · ⌘↵ küldést';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Az ügynök szerkeszti a munkaterületet. Tervezzen csak ellenőrzéseket.';

  @override
  String get defaultModel => 'Alapértelmezett modell';

  @override
  String get openingScanner => 'Szkenner megnyitása...';

  @override
  String get theAgentCanUseThisSkill =>
      'Az ügynök használhatja ezt a képességet.';

  @override
  String get allSelected => 'Minden kiválasztva';

  @override
  String get addCoreMemoryEntry => 'Adja hozzá az alapvető memóriabejegyzést';

  @override
  String get channelId => 'Csatornaazonosító';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'A mesterséges intelligencia által létrehozott és nem meghatározott feladatok az aktuális alapértelmezett értékeket használják.';

  @override
  String get waitingForRunEvents => 'Várjuk a futó eseményeket...';

  @override
  String get hideSteps => 'Lépések elrejtése';

  @override
  String get commitTheActiveLiveCapture => 'Végezze el az aktív élő rögzítést';

  @override
  String get stopCaptureAndSubmit => 'Állítsa le a rögzítést és küldje el';

  @override
  String get clickTheMicToStartSpeaking =>
      'A beszéd megkezdéséhez kattintson a mikrofonra';

  @override
  String get connectACustomEndpoint => 'Csatlakoztasson egy egyéni végpontot';

  @override
  String get hostedProvider => 'hosztolt szolgáltató.';

  @override
  String get muted => ' • elnémítva';

  @override
  String get addWhoCanMessage => 'Adja hozzá, hogy ki tud üzenetet küldeni';

  @override
  String get joinsGroupConversations =>
      'Csatlakozik a csoportos beszélgetésekhez';

  @override
  String get label1PersonOrGroupAdded => '1 személy vagy csoport hozzáadva';

  @override
  String get inProgress => 'Folyamatban';

  @override
  String get waitingForUpdateJobOutput =>
      'Várakozás a frissítési feladat kimenetére…';

  @override
  String get taskTrigger => 'Feladatindító';

  @override
  String get bearerToken => 'Bemutató jelző';

  @override
  String get bearerToken2 => 'Tartó zseton';

  @override
  String get notRecorded => 'Nem rögzítették';

  @override
  String get sessionCookie => 'Munkamenet süti';

  @override
  String get neverUsed => 'Soha nem használt';

  @override
  String get linkedRecently => 'Nemrég linkelve';

  @override
  String get notUsedYet => 'Még nem használt';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Egy vagy több fiók lejárt. Csatlakozzon újra a hozzáférés visszaállításához. Ha ez továbbra is megtörténik, előfordulhat, hogy a Google Cloud OAuth alkalmazás Tesztelési módban van – tegye közzé a Google Cloud Console éles verziójában, hogy hosszú élettartamú tokeneket kapjon.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault csatlakoztatva és újraindítás után elérhető';

  @override
  String get vaultConnectedForThisSession =>
      'Széf csatlakoztatva ehhez a munkamenethez';

  @override
  String get connectAnotherAccount => 'Csatlakoztasson egy másik fiókot';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Illessze be a csere hosszú élettartamú hozzáférési tokent';

  @override
  String get updateInstance => 'Példány frissítése';

  @override
  String get pasteAReplacementToken => 'Illesszen be egy helyettesítő tokent';

  @override
  String get replaceAccount => 'Cserélje ki a fiókot';

  @override
  String get addAccount => 'Fiók hozzáadása lehetőségre';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Bármely fogadó ügynökhöz delegálható';

  @override
  String get canReceiveDelegatedTasks2 => 'delegált feladatokat kaphat';

  @override
  String get noSyncYet => 'Még nincs szinkronizálás';

  @override
  String get noNewData => 'Nincsenek új adatok';

  @override
  String get syncOnceToSeedYourBackend =>
      'Szinkronizáljon egyszer a háttérrendszer indításához.';

  @override
  String get lastWindowEndIsUnknown => 'Az utolsó ablak vége ismeretlen.';

  @override
  String get lastNonEmptySync => 'Utolsó, nem üres szinkronizálás';

  @override
  String get stopTranscribe => 'Leállítás és átírás';

  @override
  String get steeringMode => 'Kormányzási mód';

  @override
  String get noMessageText => 'Nincs üzenet szövege';

  @override
  String get reconnectingToServer => 'Újracsatlakozás a szerverhez…';

  @override
  String get signingIn => 'Bejelentkezés...';

  @override
  String get noGroupsFoundYet => 'Még nem található csoport';

  @override
  String get onForNewGroupsOnly => 'Csak az új csoportok számára';

  @override
  String get noGroupsInThisCategory =>
      'Nincsenek csoportok ebben a kategóriában';

  @override
  String get groupOrChannel => 'Csoport vagy csatorna';

  @override
  String get notesYouWriteToYourselfStartA =>
      'A magadnak írt jegyzetek futni kezdenek, és a válaszok ugyanabban a csevegésben landolnak. Az engedélyezési lista itt nem érvényes.';

  @override
  String get needToReply => 'Válaszolni kell';

  @override
  String get enter2faCode => 'Írja be a 2FA kódot';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Nyissa meg a hitelesítő alkalmazást, és írja be az aktuális NeoAgent kódot.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Már van fiókja? Jelentkezzen be';

  @override
  String get serverOnThisComputer => 'Szerver ezen a számítógépen';

  @override
  String get showQrCode => 'QR-kód megjelenítése';

  @override
  String get createAnotherNeoagentAccount =>
      'Hozzon létre egy másik NeoAgent fiókot.';

  @override
  String get canCoordinateDelegatedWork =>
      'Képes koordinálni a delegált munkát';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'A NeoAgent futásidejű archívumot nem sikerült kibontani.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'A NeoAgent futásidejű archívuma nem olvasható.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'A NeoAgent futásidejű archívuma nem biztonságos elérési utat tartalmaz.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'A NeoAgent futásidejű archívuma nem biztonságos hivatkozást tartalmaz.';

  @override
  String get installingAppPackageOnThePhone =>
      'Alkalmazáscsomag telepítése a telefonra...';

  @override
  String get dragAndDropAApkOrApks =>
      'Húzzon ide egy .apk vagy .apks fájlt, vagy kattintson a böngészéshez.';

  @override
  String get releaseToInstallThisPackage => 'Engedje el a csomag telepítéséhez';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'A biztonsági kulcs nem használható.';

  @override
  String get connecting => 'Csatlakozás…';

  @override
  String get changes => 'Változások';

  @override
  String get runtimeReady => 'Futásidő kész';

  @override
  String get saving => 'Mentés...';

  @override
  String get earlier => 'Korábban';

  @override
  String get monthJan => 'jan';

  @override
  String get monthFeb => 'febr';

  @override
  String get monthMar => 'márc';

  @override
  String get monthApr => 'ápr';

  @override
  String get monthMay => 'május';

  @override
  String get monthJun => 'jún';

  @override
  String get monthJul => 'júl';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'szept';

  @override
  String get monthOct => 'okt';

  @override
  String get monthNov => 'nov';

  @override
  String get monthDec => 'dec';

  @override
  String get steeringWord => 'Kormányzás';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Ez átváltja a háttérrendszert a $arg1 csatornáról a $arg2 csatornára.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return '$arg1 cookie-k importálva';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '${arg1}s ezelőtt';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Sorba állított kormányzás: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'A webalkalmazás nem tudta elérni a NeoAgent háttérrendszert.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'A böngésző letiltott egy szükséges kérést a Tartalombiztonsági szabályzat miatt.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1/4 megengedett';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Végezze el a feladatot a szokásos módon.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Változások · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Ez az eszköz · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Elérte a határértéket$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'A $arg1 helyreállítási kódok továbbra is rendelkezésre állnak.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return '$arg1 biztonsági kulcs';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Aktuális munkamenet';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nUtoljára használt: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return '$arg1-ben működik ezen az eszközön. A NeoAgent közvetlenül olvassa és szerkeszti a mappát, és parancsokat futtathat, alkalmazásokat nyithat meg és használhatja a képernyőt.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return '$arg1-nél dolgozott';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return '$arg1 engedélyezve';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'A $arg2 $arg1 meghívó hivatkozásait visszavonták';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Adja hozzá azokat a személyeket és csoportokat, akikkel $arg1-nek beszélnie kell';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Adja hozzá azokat a személyeket és csoportokat, akikkel $arg1 beszélhet.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Ahol a $arg1 hallgat';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return 'A $arg1 figyeli ezeket a helyeket említésre. Itt bárki posztolhat, így az embereknek továbbra is saját jóváhagyásra van szükségük alább.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Ezek az emberek bárhol kérdezhetik a $arg1-t, ahol megjelölik. A szerepek csak a fent felsorolt ​​helyeken számítanak.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Csak akkor, ha a $arg1 fel van címkézve';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Be minden $arg1 csoporthoz';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return 'A $arg1 továbbra is csak az Ön által jóváhagyott személyeket és csoportokat hallja. Ez csak lehetővé teszi, hogy $arg1 csatlakozzon a szokásos csevegéshez, nem csak a címkékhez és a válaszokhoz.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return 'A $arg1 továbbra is csak az Ön által jóváhagyott személyeket és csoportokat hallja. Ez csak azt választja ki, hogy melyik csoporthoz csatlakozzon.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Ha valaki megcímkézi a $arg1-t vagy válaszol, a $arg1 mindig válaszol. Kapcsolja be, ha a $arg1 a szokásos csoportos csevegésben is bekapcsol.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Az új csoportok lehetővé teszik, hogy $arg1 csatlakozzon a jóváhagyott személyekkel folytatott szokásos csevegésekhez, amíg ki nem kapcsolja őket.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Az új csoportok addig engedélyezik a $arg1 számára, hogy csatlakozzanak a szokásos csevegésekhez, amíg ki nem kapcsolja őket.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Az új csoportok mindaddig csendben maradnak, amíg egy jóváhagyott személy fel nem címkézi a $arg1-t, amíg be nem kapcsolja őket.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Csak akkor, ha egy jóváhagyott személy felcímkézi a $arg1-t, hacsak nem kapcsol be egy csoportot';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Csak akkor, ha a $arg1 meg van címkézve, hacsak nem kapcsol be egy csoportot';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 csoport csatlakozik a szokásos csevegéshez jóváhagyott emberekkel';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Ez nem hagyja jóvá az új embereket. A jóváhagyott személyek címkéi és válaszai mindig választ kapnak. Kapcsoljon be egy csoportot, ha a $arg1 is csatlakozna a szokásos csevegéshez.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Ez nem hagyja jóvá az új embereket. Kapcsoljon be egy csoportot, ha a $arg1 csatlakozna a szokásos csevegéshez olyan emberekkel, akiket már jóváhagyott.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'A címkék és a válaszok mindig választ kapnak. Kapcsoljon be egy csoportot, ha a $arg1 is csatlakozna a szokásos csevegéshez.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return 'A $arg1 csatlakozik a jóváhagyott emberekkel folytatott szokásos csevegéshez';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return 'A $arg1 csatlakozhat a szokásos chathez';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return 'A $arg1 csak akkor válaszol, ha egy jóváhagyott személy megcímkézi';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Semmi extra nem kell. Csatlakoztassa a $arg1 használatának megkezdéséhez.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return '$arg1-ben frissít';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Regisztráljon a $arg1-vel';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Nincsenek „$arg1”-hez kapcsolt memória.';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (alapértelmezett)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Elágazás: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return 'A $arg1 csak az alább hozzáadott csoportokhoz és csatornákhoz csatlakozik.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return 'A $arg1 szükséges a NeoAgent futásidejű adatok megkereséséhez.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[csonka előnézet, összesen $arg1 bájt]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[termékkorlátozott, összesen $arg1 bájt]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' $arg1-ben';
  }

  @override
  String get worldNews => 'Világhírek';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Futtasson, amikor új világcímek jelennek meg. A felszólítás eldönti, hogy értesítse-e Önt.';

  @override
  String get newsKeywordsOptional => 'Kulcsszavak (nem kötelező)';

  @override
  String get worldNewsSetup => 'Világhírek beállítása';

  @override
  String get connectWorldNewsWithGnews =>
      'Adjon hozzá egy GNews API-kulcsot (ingyenes csomag elérhető a gnews.io oldalon). Titkosítva tárolják, és a World News triggerek legfontosabb címsorainak lekérdezésére használják.';

  @override
  String get gnewsApiKey => 'GNews API kulcs';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Illessze be a helyettesítő GNews API-kulcsot';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Hagyja üresen a kulcsot az aktuálisan tárolt kulcs megtartásához.';

  @override
  String get gnewsApiKeyIsRequired => 'GNews API-kulcs szükséges.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Nem sikerült menteni a World News beállítását.';

  @override
  String get disconnectWorldNews => 'A World News lekapcsolása';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Ezzel eltávolítja a tárolt GNews API kulcsot. A World News triggerek leállnak, amíg újra nem ad hozzá egy kulcsot.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Nem sikerült leválasztani a World News szolgáltatást.';

  @override
  String get systemOneModels => 'SystemOne modellek';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'A legjobb elérhető SystemOne modellt választja';

  @override
  String get systemOneOffTheChatModelDecides =>
      'A chat modell hozza meg ezeket a döntéseket';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Döntési modellek, amelyek a másodperc töredéke alatt elindítják a színfalak mögötti hívásokat: csoportos csevegés és böngésző lépések. A chatmodell továbbra is minden választ ír.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'A SystemOne modell dönti el, hogy mikor beszéljen, miközben be van kapcsolva; ez a modell a tartalék.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return 'A $arg1 pontot a SystemOne szerezte';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'A SystemOne közvetlenül értékelte ezt az üzenetet. Nem futott nyelvi modell.';

  @override
  String get systemOneUnavailable => 'A SystemOne nem érhető el';

  @override
  String get systemOneAdminAvailability =>
      'A döntési modellek ügynökei a Beállítások › Modellek alatt választhatnak. Az itt kikapcsolt modell elhagyja a választót, és az azt választó ügynökök visszaszállnak az Auto-ba. Bármelyik modell ki van kapcsolva, a szolgáltatók által később elindított SystemOne modellek is kikapcsolnak.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Még nincsenek SystemOne modellek. Adjon hozzá egy TypeSafe- vagy OpenRouter-kulcsot a Szolgáltatók alatt, vagy húzzon le egy döntési modellt, például a nimble-t az Ollama 0.35-ös vagy újabb verziójában.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Még nem érhető el SystemOne modell. Adjon hozzá egy TypeSafe- vagy OpenRouter-kulcsot a Beállítások › Modellek › Hozzon magával saját kulcsát, vagy válasszon döntési modellt, például a nimble in Ollama-ban.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone rendszer egy döntési modellek jev Typesafe openrouter ollama rendelkezésre állás engedélyezése letilt';

  @override
  String get chatModels => 'Chat modellek';

  @override
  String get disabled => 'Letiltva';

  @override
  String get enableShown => 'Megjelenített engedélyezése';

  @override
  String get disableShown => 'Letiltása látható';

  @override
  String get expandAll => 'Az összes kibontása';

  @override
  String get collapseAll => 'Az összes összecsukása';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 nem mentett módosítások';
  }

  @override
  String get settingsScopeAllAgents => 'Minden ügynök';

  @override
  String get settingsScopeAgent => 'Ez az ügynök';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint =>
      'Ugyanaz mindenhol, ahol bejelentkezik';

  @override
  String get settingsScopeAllAgentsHint => 'Megosztotta az összes ügynöke';

  @override
  String get settingsAppliesTo => 'A következőre vonatkozik';

  @override
  String get settingsSaving => 'Mentés…';

  @override
  String get settingsSavedAutomatically =>
      'A változtatások automatikusan mentésre kerülnek';

  @override
  String get settingsSearchHint => 'Keresés az összes beállításban';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Bejelentkezés és biztonság';

  @override
  String get settingsPageUsage => 'Használat';

  @override
  String get settingsPagePermissions => 'Engedélyek';

  @override
  String get settingsPageComputer => 'Számítógép és web';

  @override
  String get settingsPageBehavior => 'Viselkedés';

  @override
  String get settingsPageSystem => 'Rendszer';

  @override
  String get settingsPagePlatforms => 'Platformok';

  @override
  String get settingsPageProfileDescription =>
      'Az Ön neve és e-mail címe, adatainak másolata és kijelentkezés.';

  @override
  String get settingsPageSecurityDescription =>
      'Jelszó, kétfaktoros hitelesítés, biztonsági kulcsok és bejelentkezési hely.';

  @override
  String get settingsPageUsageDescription =>
      'Korlátai és tokenköltései – mindez egy helyen.';

  @override
  String get settingsPageAgentsDescription =>
      'Hozzon létre ügynököket, és válassza ki, hogy melyik válaszol alapértelmezés szerint.';

  @override
  String get settingsPagePermissionsDescription =>
      'Mit tehetnek az ügynökei anélkül, hogy először megkérdeznék.';

  @override
  String get settingsPageComputerDescription =>
      'A számítógép, amelyen az ügynökei dolgoznak, és a webhelyek, amelyeket Önként olvashatnak.';

  @override
  String get settingsPageModelsDescription =>
      'Az ügynök által használt modellek és az ezekért fizető API-kulcsok.';

  @override
  String get settingsPageBehaviorDescription =>
      'Hogyan beszél ez az ügynök, és hogyan olvassa el a csoportos csevegést.';

  @override
  String get settingsPageVoiceDescription =>
      'Élő hívások, diktálás és szóbeli válaszok ennek az ügynöknek.';

  @override
  String get settingsPageMessagingDescription =>
      'Hol érhetik el az emberek ezt az ügynököt, és hogyan viselkedik a chatekben.';

  @override
  String get settingsPageGeneralDescription =>
      'Megjelenés, nyelv, időzóna és az alkalmazás működése a háttérben.';

  @override
  String get settingsPageSystemDescription =>
      'Az ablak által használt kiszolgáló, a számítógépen lévő szerver és az alkalmazásfrissítések.';

  @override
  String get settingsYourAgents => 'Az ügynökei';

  @override
  String get settingsChatModel => 'Chat modell';

  @override
  String get settingsChatModelDescription => 'Válaszol az üzeneteidre.';

  @override
  String get settingsSubAgentModel => 'Al-ügynök modell';

  @override
  String get settingsSubAgentModelDescription =>
      'A feladat során átadott munkát futtatja.';

  @override
  String get settingsDefaultModels => 'Alapértelmezett modellek';

  @override
  String get settingsDefaultModelsDescription =>
      'Akkor használatos, amikor egy csevegés vagy feladat nem választja ki a saját modelljét.';

  @override
  String get settingsModelPool => 'Modell medence';

  @override
  String get settingsApiKeysDescription =>
      'Használja saját kulcsait vagy végpontját ehhez az ügynökhöz. A kulcsok titkosítva vannak, és soha többé nem jelennek meg.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Finomhangolás';

  @override
  String get settingsFineTuningDescription =>
      'Ritkán szükséges. Az alapértelmezett beállítások megfelelnek a legtöbb csevegésnek.';

  @override
  String get settingsShow => 'Megjelenítés';

  @override
  String get settingsHide => 'Elrejtés';

  @override
  String get settingsMinimumContribution => 'Minimális hozzájárulási érték';

  @override
  String get settingsBatchWindow => 'Szoba ablak';

  @override
  String get settingsBatchWindowDescription =>
      'Ennyit vár, hogy a gyors üzeneteket egyetlen fordulatként kezelje.';

  @override
  String get settingsHandsFree => 'Kihangosítva';

  @override
  String get settingsHandsFreeDescription =>
      'Beszéljen szabadon és szakítsa félbe bármikor.';

  @override
  String get settingsPushToTalkDescription =>
      'Tartsa a beszélgetéshez, engedje el a küldéshez.';

  @override
  String get settingsLiveVoice => 'Élő hang';

  @override
  String get settingsChannels => 'Csatornák';

  @override
  String get settingsGroupChats => 'Csoportos chatekben';

  @override
  String get settingsGroupChatsDescription =>
      'Hogyan viselkedik ez az ügynök csoportosan minden csatornán.';

  @override
  String get settingsGroupChatsDisabled =>
      'Ezek módosításához kapcsolja be a viselkedésmodulokat a Viselkedés részben.';

  @override
  String get settingsParticipationAutomatic => 'Automatikus';

  @override
  String get settingsParticipationMentionOnly => 'Csak említés';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Olvassa a szobát, és csatlakozik, ha van valami hasznos hozzáfűznivalója.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Csak akkor válaszol, ha megemlítik vagy válaszolnak rá.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Minden üzenetre válaszol.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'A hosszabb válaszokat rövid üzenetekre bontja, ahogyan azt egy személy tenné.';

  @override
  String get settingsDeliverySingleDescription =>
      'Minden választ egy üzenetként küld el.';

  @override
  String get settingsComputerStatus => 'Állapot';

  @override
  String get settingsTest => 'Teszt';

  @override
  String get settingsAppearance => 'Megjelenés';

  @override
  String get settingsTheme => 'téma';

  @override
  String get settingsThemeSystem => 'Rendszer';

  @override
  String get settingsThemeLight => 'Világos';

  @override
  String get settingsThemeDark => 'Sötét';

  @override
  String get settingsCloseWindow => 'Amikor becsukod az ablakot';

  @override
  String get settingsCloseAsk => 'Kérdezz';

  @override
  String get settingsCloseKeepRunningDescription =>
      'A NeoAgent folyamatosan fut a háttérben, és elérhető marad.';

  @override
  String get settingsCloseQuitDescription => 'A NeoAgent teljesen kilép.';

  @override
  String get settingsPhoneTriggers => 'Telefon triggerek';

  @override
  String get settingsPhoneTriggersDescription =>
      'Jeleket küld a telefon az ügynökeinek, hogy a feladatok reagálhassanak rájuk.';

  @override
  String get settingsLocationTriggers => 'Helyszín kiváltók';

  @override
  String get settingsLocationTriggersDescription =>
      'Néhány percenként ellenőrzi hozzávetőleges tartózkodási helyét a feladatai által figyelt helyekkel.';

  @override
  String get settingsNotificationTriggers => 'Értesítési triggerek';

  @override
  String get settingsNotificationTriggersDescription =>
      'A telefonon lévő más alkalmazások értesítéseit továbbítja ügynökeinek.';

  @override
  String get settingsSetup => 'Beállítás';

  @override
  String get settingsOnboarding => 'Felvétel';

  @override
  String get settingsOnboardingDescription =>
      'Végezze el újra az első futási beállítást. Semmi sem veszett el, amit beállítottál.';

  @override
  String get settingsUsernameDescription =>
      'Bejelentkezéshez használt. Nem módosítható.';

  @override
  String get settingsExport => 'Exportálás';

  @override
  String get settingsLeave => 'Jelentkezzen ki és törölje';

  @override
  String get settingsSignOutDescription =>
      'Csak ezen az eszközön jelentkezik ki.';

  @override
  String get settingsDeleteAccountDescription =>
      'Törli fiókját, ügynökeit, memóriáját és beállításait. Ezt nem lehet visszavonni.';

  @override
  String get settingsTokenUsage => 'Token használat';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Egy beállítás sem felel meg a „$query”-nek.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count találat',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Speciális modellbeállítások';

  @override
  String get settingsAdvancedModelsDescription =>
      'Választható. Modell rögzítése egyfajta munkához; minden alkalommal átveszi az irányítást, amikor az ügynök ezeket az eszközöket használja. Bármi, ami alapértelmezetten marad, a csevegési modellt követi.';

  @override
  String get settingsTaskModelDefault => 'Alapértelmezett';

  @override
  String get settingsTaskModelDefaultSubtitle => 'A chat modellt követi';

  @override
  String get settingsTaskModelCoding => 'Kódolás';

  @override
  String get settingsTaskModelCodingDescription =>
      'Kód írása, szerkesztése és hibakeresése.';

  @override
  String get settingsTaskModelComputerUse => 'Számítógép használat';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'A böngésző és az asztal vezetése.';

  @override
  String get settingsTaskModelAndroidUse => 'Android használat';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Alkalmazások kezelése Android-eszközön vagy emulátoron.';

  @override
  String get settingsTaskModelResearch => 'Kutatás';

  @override
  String get settingsTaskModelResearchDescription =>
      'Források keresése, olvasása, összegzése.';

  @override
  String get knowledgeGraphHint =>
      'A legtöbbet emlegetett entitások, fürtök szerint színezve. A vonalak olyan entitásokat kötnek össze, amelyek ugyanazokban a memóriákban jelennek meg. Koppintson az egyikre a hivatkozások és emlékek megtekintéséhez; húzással pásztázhat, összecsípheti vagy Ctrl/⌘-görgessen a nagyításhoz.';

  @override
  String get linkedEntities => 'Kapcsolt entitások';

  @override
  String get noLinkedEntities => 'Még nem kapcsolódik más entitásokhoz.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 említi';
  }

  @override
  String get entityKindConcept => 'Koncepció';

  @override
  String get entityKindDomain => 'Domain';

  @override
  String get entityKindEmail => 'E-mail';

  @override
  String get entityKindLink => 'Link';

  @override
  String get entityKindFile => 'Fájl';

  @override
  String get entityKindAcronym => 'Betűszó';

  @override
  String get entityKindIdentifier => 'Azonosító';

  @override
  String get entityKindVersion => 'Verzió';

  @override
  String get openFullscreen => 'Teljes képernyő megnyitása';

  @override
  String get zoomIn => 'Nagyítás';

  @override
  String get zoomOut => 'Kicsinyítés';

  @override
  String get searchEntities => 'Keressen egy entitást';

  @override
  String get incomingCall => 'Bejövő hívás';

  @override
  String get answerCall => 'Válasz';

  @override
  String get callMeLater => 'Hívjon fel később';

  @override
  String get callingEllipsis => 'Hívás…';

  @override
  String get reconnectingCall => 'Újracsatlakozás';

  @override
  String get agentWorking => 'Dolgozik';

  @override
  String get micMuted => 'Elnémítva';

  @override
  String get speakerphone => 'Hangszóró';

  @override
  String get muteMic => 'Némítás';

  @override
  String get unmuteMic => 'Némítás feloldása';

  @override
  String get releaseToSend => 'Engedje el a küldéshez';

  @override
  String get callEnded => 'A hívás véget ért';

  @override
  String get openConversation => 'Nyissa meg a beszélgetést';

  @override
  String get callBack => 'Hívjon vissza';

  @override
  String get letCallsReachYou => 'Hagyja, hogy a hívások elérjék Önt';

  @override
  String get callPermissionsIntro =>
      'Az ügynökei felhívhatják. Ahhoz, hogy telefonhívásként csenghessen, miközben a NeoAgent a háttérben van, vagy telefonja le van zárva, ezekre van szüksége.';

  @override
  String get showOverOtherApps => 'Megjelenítés más alkalmazások felett';

  @override
  String get showOverOtherAppsDetail =>
      'Bárhol is legyen, előhozza a hívásképernyőt.';

  @override
  String get fullScreenCalls => 'Teljes képernyős hívások';

  @override
  String get fullScreenCallsDetail => 'Csörög a lezárási képernyő felett.';

  @override
  String get unrestrictedBattery => 'Korlátlan akkumulátor';

  @override
  String get unrestrictedBatteryDetail =>
      'Kapcsolatban tartja a NeoAgentet, így hívások érkeznek.';

  @override
  String get permissionAllowed => 'Engedélyezett';

  @override
  String get triggerSectionCalendar => 'Naptár';

  @override
  String get triggerSectionFiles => 'Fájlok és dokumentumok';

  @override
  String get triggerSectionHome => 'Otthon és média';

  @override
  String get triggerSectionDevices => 'Eszközök és helyek';

  @override
  String get triggerSectionTasks => 'Feladatok';

  @override
  String get messagingMemberJoined => 'Tag csatlakozott';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Futtassa, ha valaki csatlakozik egy Discord-kiszolgálóhoz, Telegram- vagy WhatsApp-csoporthoz, Slack-csatornához vagy Mátrix-szobához.';

  @override
  String get messagingMemberLeft => 'Tag távozott';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Futtassa, ha valaki elhagyja a Discord-kiszolgálót, a Telegram- vagy WhatsApp-csoportot, a Slack-csatornát vagy a Mátrix-szobát.';

  @override
  String get messagingReactionAdded => 'Reakció hozzáadva';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Futtassa, ha egy engedélyezett személy válaszol egy üzenetre egy privát csevegésben.';

  @override
  String get messagingPlatformDisconnected => 'Az üzenetküldés megszakadt';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Futtassa, amikor az üzenetküldő kapcsolat leáll, és szüksége van Önre, például kijelentkezés után.';

  @override
  String get googleCalendarEventStarting => 'Google Naptár esemény indul';

  @override
  String get googleCalendarEventCreated => 'Google Naptár-esemény létrehozva';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Futtatás, ha új esemény vagy meghívó jelenik meg.';

  @override
  String get outlookCalendarEventStarting =>
      'Az Outlook naptári esemény elindul';

  @override
  String get nextcloudCalendarEventStarting =>
      'A Nextcloud naptári esemény elindul';

  @override
  String get runMinutesBeforeEachEvent =>
      'Fuss meghatározott számú percet minden esemény előtt.';

  @override
  String get googleDriveFileAdded => 'Google Drive-fájl hozzáadva';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Futtassa, ha egy fájlt hozzáad a Drive-hoz vagy egy mappához.';

  @override
  String get googleSheetsRowAdded => 'Google Táblázatok sor hozzáadva';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Futtatás, amikor új sorok jelennek meg a munkalapon.';

  @override
  String get onedriveFileAdded => 'OneDrive-fájl hozzáadva';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Futtatás, amikor egy fájl hozzáadásra kerül egy OneDrive mappához.';

  @override
  String get nextcloudFileAdded => 'Nextcloud fájl hozzáadva';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Futtatás, ha egy fájl hozzáadásra kerül egy Nextcloud mappához.';

  @override
  String get nextcloudShareReceived => 'Önnel megosztott Nextcloud fájl';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Futtassa, ha valaki megoszt Önnel egy fájlt vagy mappát.';

  @override
  String get notionItemAdded => 'Fogalomadatbázis-elem hozzáadva';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Futtatás, amikor egy elemet hozzáadunk egy Notion adatbázishoz.';

  @override
  String get notionItemUpdated => 'Fogalomadatbázis-elem frissítve';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Futtatás, amikor egy elem megváltozik a Notion adatbázisban.';

  @override
  String get trelloCardEnteredList => 'Trello kártya hozzáadva a listához';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Futtatás, amikor egy kártya létrejön egy listában vagy áthelyezi egy listába.';

  @override
  String get figmaCommentAdded => 'Figma megjegyzés hozzáadva';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Futtassa, ha valaki megjegyzést fűz egy Figma-fájlhoz.';

  @override
  String get githubPrOpened => 'GitHub lekérési kérelem megnyitva';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Futtatás, amikor új lekérési kérelem nyílik meg egy lerakatban.';

  @override
  String get githubWorkflowRunFailed =>
      'A GitHub munkafolyamat futtatása nem sikerült';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Futtassa, ha a GitHub Actions futtatása meghiúsul.';

  @override
  String get githubCommitPushed => 'A GitHub commit letoltva';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Futtatás, amikor az új commit elér egy ágat.';

  @override
  String get mcpServerFailed => 'Az MCP szerver meghibásodott';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Futtassa, ha egy működő MCP-kiszolgáló meghibásodik, vagy be kell jelentkeznie.';

  @override
  String get homeAssistantStateChanged =>
      'Az Otthoni asszisztens állapota megváltozott';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Futtatás, amikor egy entitás megváltozik, elér egy állapotot vagy átlép egy értéket.';

  @override
  String get spotifyTrackChanged => 'A Spotify szám megváltozott';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Futtassa, ha egy másik szám lejátszása kezdődik.';

  @override
  String get neorecallDailySummaryReady =>
      'A NeoRecall napi összefoglalója készen áll';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Futtassa, amikor egy nap összefoglalója végleges.';

  @override
  String get neorecallConversationRecorded => 'NeoRecall beszélgetés rögzítve';

  @override
  String get runWhenARecordedConversationEnds =>
      'Futtassa, ha egy rögzített beszélgetés véget ér.';

  @override
  String get geofenceTrigger => 'Hely geokerítés';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Futtasson, amikor telefonja megérkezik egy helyre, vagy elhagyja azt. Helymeghatározást igényel a telefonon.';

  @override
  String get healthMetricRecorded => 'Az egészségügyi mutató rögzítve';

  @override
  String get runWhenAHealthReadingArrives =>
      'Futtatás, amikor szinkronizált állapotleolvasás érkezik, opcionálisan egy érték felett vagy alatt.';

  @override
  String get wearableConnectionChanged =>
      'Viselhető csatlakoztatva vagy leválasztva';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Futtassa, amikor a hordható eszköz csatlakozik vagy megszakad.';

  @override
  String get taskRunFinished => 'Egy újabb feladat befejeződött';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Futtasson egy másik feladat befejezése, sikeres vagy sikertelensége után.';

  @override
  String get appPackageOptional => 'Alkalmazáscsomag (opcionális)';

  @override
  String get appPackageHelper => 'Például com.whatsapp';

  @override
  String get anyPlatform => 'Bármilyen platform';

  @override
  String get spaceIdOptional =>
      'Szerver-, csoport-, csatorna- vagy szobaazonosító (opcionális)';

  @override
  String get spaceIdHelper => 'Üres órák, amelyekben a bot van.';

  @override
  String get emojiOptional => 'Emoji (nem kötelező)';

  @override
  String get chatIdOptional => 'Csevegőazonosító (opcionális)';

  @override
  String get platformOptional => 'Platform (opcionális)';

  @override
  String get platformOptionalHelper => 'Például whatsapp. Üres órák minden.';

  @override
  String get minutesBefore => 'Percekkel azelőtt';

  @override
  String get calendarIdOptional => 'Naptárazonosító (opcionális)';

  @override
  String get calendarIdHelper => 'Az Üres az elsődleges naptárat használja.';

  @override
  String get invitesOnly => 'Csak meghívók másoktól';

  @override
  String get nextcloudCalendarPath => 'Naptár';

  @override
  String get nextcloudCalendarPathHelper =>
      'A neve a Nextcloud naptárlistájában, például személyes';

  @override
  String get folderIdOptionalHelperDrive => 'Az üres órák az egész Drive-ot.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Az Empty figyeli a gyökérmappát.';

  @override
  String get driveFolderIdOptional => 'Mappaazonosító (opcionális)';

  @override
  String get spreadsheetId => 'Táblázatazonosító';

  @override
  String get sheetRange => 'Tartomány';

  @override
  String get sheetRangeHelper => 'A táblázat oszlopai, például Sheet1!A:E';

  @override
  String get folderPathOptional => 'Mappa elérési útja (opcionális)';

  @override
  String get folderPathHelper => 'Például Dokumentumok';

  @override
  String get notionDatabaseId => 'Adatbázis azonosító';

  @override
  String get trelloListId => 'Listaazonosító';

  @override
  String get figmaFileKey => 'Fájlkulcs';

  @override
  String get figmaFileKeyHelper =>
      'A fájl hivatkozásáról: figma.com/file/<kulcs>/…';

  @override
  String get githubRepository => 'Adattár';

  @override
  String get workflowOptional => 'Munkafolyamat (opcionális)';

  @override
  String get workflowHelper => 'Fájlnév, például ci.yml';

  @override
  String get branchOptional => 'Ága (nem kötelező)';

  @override
  String get branchHelper => 'Az üres az alapértelmezett ágat használja.';

  @override
  String get mcpServerIdOptional => 'MCP szerver azonosító (opcionális)';

  @override
  String get entityId => 'Entitásazonosító';

  @override
  String get entityIdHelper => 'Például binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Célállapot (nem kötelező)';

  @override
  String get targetStateHelper => 'Például on';

  @override
  String get aboveOptional => 'Fent (nem kötelező)';

  @override
  String get belowOptional => 'lent (nem kötelező)';

  @override
  String get placeName => 'Helynév';

  @override
  String get latitude => 'Szélesség';

  @override
  String get longitude => 'Hosszúság';

  @override
  String get radiusMeters => 'Sugár méterben';

  @override
  String get geofenceTransition => 'Mikor';

  @override
  String get arriving => 'Megérkezés';

  @override
  String get leaving => 'Távozás';

  @override
  String get healthMetric => 'Egészségügyi mérőszám';

  @override
  String get healthMetricHelper => 'Például pulzusszám, lépések, súly';

  @override
  String get wearableTransition => 'Amikor a hordható';

  @override
  String get wearableConnects => 'Csatlakozik';

  @override
  String get wearableDisconnects => 'Lekapcsol';

  @override
  String get sourceTask => 'Feladat után';

  @override
  String get taskOutcome => 'Eredmény';

  @override
  String get anyOutcome => 'Bármilyen eredmény';

  @override
  String get succeeded => 'Sikerült';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return 'A $arg1 hiányzik vagy érvénytelen.';
  }

  @override
  String get triggerSectionMessaging => 'Üzenetküldés';

  @override
  String get triggerSectionDeveloper => 'Fejlesztő';

  @override
  String get triggerSectionMemory => 'Memória';

  @override
  String get triggerSectionNews => 'Hírek';

  @override
  String get triggerSectionSystem => 'Rendszer';

  @override
  String get searchTriggersHint =>
      'Keresési aktiválási szabályok, alkalmazások vagy események';

  @override
  String get noTriggersMatch => 'Egyetlen trigger sem felel meg a keresésnek.';

  @override
  String get triggerAccountMissing => 'Még nincs fiók';

  @override
  String get pickTriggerKeyboardHint =>
      'Az Enter kiválasztja az első eredményt';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 triggerek';
  }

  @override
  String get addFromSkillsSh => 'Add hozzá a skill.sh-ből';

  @override
  String get skillsShHint =>
      'Keressen fent a skillek kereséséhez a skill.sh oldalon, vagy illesszen be egy skill.sh hivatkozást vagy egy „npx skill add” parancsot.';

  @override
  String get noSkillsShMatches =>
      'Egyetlen skill.sh-készség sem felel meg ennek a keresésnek.';

  @override
  String get installingSkill => 'Telepítés…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Telepített $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return 'A $arg1 telepítése';
  }

  @override
  String get authVerify => 'Ellenőrizze';

  @override
  String get authCreateAccount => 'Hozzon létre fiókot';

  @override
  String get authNewInviteLink => 'Új meghívó link';

  @override
  String get authShowPassword => 'Jelszó megjelenítése';

  @override
  String get authHidePassword => 'Jelszó elrejtése';

  @override
  String get authPasswordWillBeRejected => 'túl gyenge, elutasításra kerül';

  @override
  String get authUsernameTooShort =>
      'A felhasználóneveknek legalább 3 karakterből kell állniuk.';

  @override
  String get authUsernameTaken => 'Ez a felhasználónév már foglalt.';

  @override
  String get authSignupsClosed =>
      'A regisztráció le van zárva ezen a szerveren. Kérjen fiókot az admintól.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Ez a szerver csak HTTPS-en keresztüli bejelentkezést fogad el. Nyissa meg inkább a $arg1-t.';
  }

  @override
  String get authInsecureTransport =>
      'Ez a szerver csak HTTPS-en keresztüli bejelentkezést fogad el. Csatlakozzon hozzá https:// címmel.';

  @override
  String get authAccountNotFound => 'Ez a fiók már nem létezik.';

  @override
  String get authQrRateLimited =>
      'Túl sok QR-bejelentkezési kérelem. Várjon egy kicsit, majd frissítse a kódot.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Elfelejtette jelszavát? Kérje meg a szerver adminisztrátorát, hogy állítsa vissza az Adminisztrálás → Felhasználók menüpontban.';

  @override
  String get authChangeServer => 'Szerver módosítása';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Bejelentkezés a $arg1-be';
  }

  @override
  String get authNotANeoagentServer =>
      'Ez a cím nem válaszol úgy, mint egy NeoAgent szerver. Ellenőrizze az URL-t, és próbálja újra.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Nem sikerült biztonságos (HTTPS) kapcsolatot nyitni a $arg1-hez.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Nem sikerült elérni a $arg1-t HTTPS-en keresztül, és a sima HTTP sem válaszolt. Ellenőrizze a címet és a portot.';
  }

  @override
  String get adminResetPassword => 'Jelszó visszaállítása';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Állítsa vissza a $arg1 jelszavát';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Válasszon új jelszót a $arg1 számára. A rendszer minden eszközről kijelentkezteti őket, és újra bejelentkezik ezzel a jelszóval.';
  }

  @override
  String get adminNewPassword => 'Új jelszó';

  @override
  String get adminSetPassword => 'Jelszó beállítása';

  @override
  String get authMissingFields => 'Töltsön ki minden szükséges mezőt.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return 'A $arg1 visszaállítja a $arg2 jelszavát';
  }

  @override
  String get adminPasswordUpdated =>
      'Jelszó frissítve; a felhasználó mindenhol ki volt jelentkezve.';

  @override
  String get authSignInTitle => 'Jelentkezzen be a NeoAgentbe';

  @override
  String get authSignInSubtitle =>
      'Olvassa be telefonjával, vagy használja jelszavát.';

  @override
  String get authOrUsePassword => 'vagy használja a jelszavát';

  @override
  String get qrLoginWaitingTitle => 'Jóváhagyás a telefonon';

  @override
  String get qrLoginWaitingBody =>
      'A telefon beszkennelte a kódot. A bejelentkezés befejezéséhez erősítse meg ott a bejelentkezést.';

  @override
  String get qrLoginSigningInOn => 'Bejelentkezés';

  @override
  String get qrLoginLocation => 'Helyszín';

  @override
  String get qrLoginWaitingForApproval => 'Jóváhagyásra vár';

  @override
  String get qrLoginCancelAndUsePassword => 'Mégse, és használjon jelszót';

  @override
  String get qrLoginDeclinedOnPhone =>
      'A telefonján a bejelentkezést elutasították. Olvassa be az új kódot, és próbálja újra.';

  @override
  String get signupKey => 'Regisztrációs kulcs';

  @override
  String get signupKeyStepSubtitle =>
      'Ezen a szerveren az új fiókokhoz regisztrációs kulcs kell. Adja meg a rendszergazdától kapott kulcsot.';

  @override
  String get signupKeyChange => 'Módosítás';

  @override
  String get signupKeyRequiredError => 'Adja meg a regisztrációs kulcsát.';

  @override
  String get signupKeyInvalidError =>
      'Ez a regisztrációs kulcs érvénytelen. Ellenőrizze, és próbálja újra.';

  @override
  String get signupKeyUsedError =>
      'Ezt a regisztrációs kulcsot már felhasználták. Kérjen újat egy rendszergazdától.';

  @override
  String get adminRequireSignupKey => 'Regisztrációs kulcs megkövetelése';

  @override
  String get adminRequireSignupKeyHint =>
      'Az új fiókokhoz egyszer használatos kulcs kell egy rendszergazdától. Kikapcsolva bárki regisztrálhat, aki eléri ezt a szervert. Az első fiókhoz soha nem kell kulcs.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Az új fiókokhoz mostantól regisztrációs kulcs kell.';

  @override
  String get adminSignupOpenNotice => 'Mostantól bárki regisztrálhat.';

  @override
  String get signupKeys => 'Regisztrációs kulcsok';

  @override
  String get signupKeysDescription =>
      'Egyszer használatos kulcsok a regisztrációhoz, amíg kulcs szükséges. Minden kulcs pontosan egy fiókot hoz létre.';

  @override
  String get signupKeysNew => 'Új kulcsok';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Fel nem használt · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Felhasznált · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Visszavont · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Összes · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Fel nem használt';

  @override
  String get signupKeyStatusUsed => 'Felhasznált';

  @override
  String get signupKeyStatusRevoked => 'Visszavont';

  @override
  String get signupKeysExport => 'Exportálás .txt-be';

  @override
  String get signupKeysCopied => 'Kulcsok másolva';

  @override
  String get signupKeyCopied => 'Kulcs másolva';

  @override
  String get signupKeysEmpty => 'Ebben a listában nincsenek kulcsok.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Létrehozva: $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Felhasználta: $arg1, $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Felhasználva $arg1 napon egy azóta törölt fiók által';
  }

  @override
  String get signupKeyRevokeTitle => 'Visszavonja ezt a kulcsot?';

  @override
  String get signupKeyRevokeMessage =>
      'Senki sem tud majd regisztrálni vele. Ez nem vonható vissza.';

  @override
  String get signupKeyRevoked => 'Kulcs visszavonva.';

  @override
  String signupKeysShowMore(int count) {
    return 'Még $count megjelenítése';
  }

  @override
  String get signupKeysCreateTitle => 'Regisztrációs kulcsok létrehozása';

  @override
  String get signupKeysCount => 'Kulcsok száma';

  @override
  String get signupKeysCountHelper => '1 és 500 között';

  @override
  String get signupKeysCountInvalid => 'Adjon meg egy számot 1 és 500 között.';

  @override
  String get signupKeysLabel => 'Címke (nem kötelező)';

  @override
  String get signupKeysLabelHint => 'pl. Tavaszi béta tesztelők';

  @override
  String signupKeysCreateAction(int count) {
    return 'Létrehozás ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Elkészült kulcsok: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Minden kulcsot csak egy személynek adjon át. A fel nem használt kulcsok a listában maradnak, így később újra másolhatja vagy exportálhatja őket.';

  @override
  String get signupKeysSaveDialogTitle => 'Regisztrációs kulcsok mentése';

  @override
  String get signupKeysExported => 'Kulcsok exportálva.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor regisztrációs kulcsokat hozott létre ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor visszavont egy regisztrációs kulcsot';
  }

  @override
  String get providerChooseUsername => 'Válassz felhasználónevet';

  @override
  String get providerChooseUsernameBody =>
      'Válassz egy szabad felhasználónevet a fiók létrehozásának befejezéséhez.';

  @override
  String get dataSharingTitle => 'Használati adatok megosztása';

  @override
  String get dataSharingDescription =>
      'Segíts a szerver üzemeltetőinek jobbá tenni. Azt osztja meg, hogyan használod a NeoAgentet, soha nem azt, amit írsz vagy tárolsz.';

  @override
  String dataSharingSince(String date) {
    return 'Megosztva ekkortól: $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Mi kerül megosztásra';

  @override
  String get dataSharingIncluded => 'Megosztva';

  @override
  String get dataSharingExcluded => 'Soha nincs megosztva';

  @override
  String get dataSharingIncludedDevice => 'Eszköztípus és alkalmazásverzió';

  @override
  String get dataSharingIncludedLocale =>
      'Az alkalmazás nyelve és az időzóna régiója, például Európa';

  @override
  String get dataSharingIncludedFeatures =>
      'Mely funkciókat állítottad be, például feladatokat, skilleket és integrációkat';

  @override
  String get dataSharingIncludedRuns =>
      'Mely eszközöket és modelleket használnak a futtatásaid, időtartammal és tokenszámmal';

  @override
  String get dataSharingIncludedActivity =>
      'Mikor használod a NeoAgentet, a hét napja és óra szerint';

  @override
  String get dataSharingExcludedContent => 'Üzenetek, promptok és válaszok';

  @override
  String get dataSharingExcludedRuns =>
      'Futtatások címei, eszközök bemenetei és eredményei';

  @override
  String get dataSharingExcludedFiles =>
      'Fájlok, emlékek és minden más, amit tárolsz';

  @override
  String get dataSharingExcludedIdentity =>
      'A neved, e-mail-címed, IP-címed és helyzeted';

  @override
  String get dataSharingExcludedAccounts =>
      'A fiókok, amelyekkel integrációkat kapcsolsz össze';

  @override
  String get dataSharingPooledNote =>
      'Az adminisztrátorok csak az összes megosztó összesített adatait látják, soha nem téged külön. Bármikor kikapcsolhatod, és azonnal kikerülsz az összesítésből.';

  @override
  String get dataSharingConfirmTitle => 'Megosztod a használati adatokat?';

  @override
  String get dataSharingConfirmAction => 'Megosztás';

  @override
  String get sharedUsageTitle => 'Megosztott használat';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Használati adatokat megosztó fiókok: $sharing / $total. Csak összesítések, tartalom nélkül.';
  }

  @override
  String get sharedUsageEmpty =>
      'Még senki sem oszt meg használati adatokat. Bekapcsolható itt: Beállítások, Profil, Az Ön adatai.';

  @override
  String get sharedUsageRuns => 'Megosztott futtatások';

  @override
  String get sharedUsageAvgDuration => 'Átl. időtartam';

  @override
  String get sharedUsageCompletedRuns => 'Befejezett futtatások';

  @override
  String get sharedUsageStepsPerRun => 'Lépések futtatásonként';

  @override
  String get sharedUsageDevices => 'Készülékek';

  @override
  String get sharedUsageAppVersions => 'Alkalmazásverziók';

  @override
  String get sharedUsageLanguages => 'Nyelvek';

  @override
  String get sharedUsageRegions => 'Régiók';

  @override
  String get sharedUsageFeatures => 'Funkcióhasználat';

  @override
  String get sharedUsageFeaturesDescription =>
      'A megosztó fiókok aránya, amelyek beállították.';

  @override
  String get sharedUsageTools => 'Eszközök';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Leggyakrabban hívott eszközök ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Hívások: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Sikertelen: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Integrációk';

  @override
  String get sharedUsageMessaging => 'Üzenetküldő csatornák';

  @override
  String get sharedUsageTriggers => 'Hogyan indulnak a futtatások';

  @override
  String get sharedUsageActivity => 'Mikor használják';

  @override
  String get sharedUsageActivityDescription =>
      'Futtatások a hét napja és óra szerint, UTC.';

  @override
  String get sharedUsageModels => 'Modellteljesítmény';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'átl. $latency · $cached% gyorsítótárból · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Fiókok: $count';
  }

  @override
  String get sharedUsageNoData => 'Ebben az időszakban nincs adat.';

  @override
  String get sharedUsageNotReported => 'Még nincs jelentve';

  @override
  String get sharedUsageFeatureAgents => 'Több mint egy ügynök';

  @override
  String get sharedUsageFeatureTasks => 'Ütemezett feladatok';

  @override
  String get sharedUsageFeatureSkills => 'Skillek';

  @override
  String get sharedUsageFeatureMcp => 'MCP-szerverek';

  @override
  String get sharedUsageFeatureIntegrations => 'Integrációk';

  @override
  String get sharedUsageFeatureMessaging => 'Üzenetküldő csatornák';

  @override
  String get sharedUsageFeatureMemory => 'Memória';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in adatmegosztás telemetria készülékek funkciók eszközök modellek aktivitás';

  @override
  String get yourOAuthApp => 'Saját OAuth-alkalmazásod';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Saját $provider OAuth-alkalmazásod';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Ezen a szerveren nincs globális $provider-alkalmazás, ezért egy saját magad által regisztrált OAuth-alkalmazással csatlakozol. A klienstitok titkosítva tárolódik, és többé nem jelenik meg.';
  }

  @override
  String get oauthAppStepCreate => '1. Hozd létre az alkalmazást';

  @override
  String get openDeveloperConsole => 'Fejlesztői konzol megnyitása';

  @override
  String get oauthAppStepCallback => '2. Regisztráld ezt a visszahívási URL-t';

  @override
  String get callbackUrlCopied => 'Visszahívási URL másolva';

  @override
  String get oauthAppScopes => 'Engedélyezendő hatókörök';

  @override
  String get scopesCopied => 'Hatókörök másolva';

  @override
  String get oauthAppStepCredentials =>
      '3. Illeszd be az alkalmazás hitelesítő adatait';

  @override
  String get couldNotSaveOAuthApp =>
      'Az OAuth-alkalmazást nem sikerült menteni.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Eltávolítod a(z) $provider-alkalmazásodat?';
  }

  @override
  String get removeOAuthAppBody =>
      'A csatlakoztatott fiókok a listában maradnak, de nem működnek, amíg újra nem adsz hozzá alkalmazást.';

  @override
  String get globalIntegrationConfiguration =>
      'Globális integrációs beállítások';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Opcionális, az egész szerverre érvényes OAuth-alkalmazások. Ha egy integrációnak van ilyen, minden fiók azt használja, és nem adhat hozzá sajátot. Hagyd üresen az integrációt, és minden felhasználó saját alkalmazást állít be. A titkok csak írhatók: hagyd üresen a tárolt érték megtartásához.';

  @override
  String get globalStatus => 'Globális';

  @override
  String get perUserStatus => 'Felhasználónként';

  @override
  String get phoneSyncGuidance =>
      'Oszd meg a telefon naptárait és névjegyeit az ügynököddel. Minden, már a telefonon lévő fiókkal működik.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Nyisd meg a NeoAgentet a telefonon, és ott kapcsold be a megosztást. Az ügynököd ezután látja a telefon összes fiókjának naptárait és névjegyeit.';

  @override
  String get manageOnThisPhone => 'Kezelés ezen a telefonon';

  @override
  String get setUpOnThisPhone => 'Beállítás ezen a telefonon';

  @override
  String get setUpOnPhone => 'Beállítás a telefonodon';

  @override
  String emailConnectedArg1(String email) {
    return '$email csatlakoztatva';
  }

  @override
  String get couldNotConnectEmail => 'A fiókot nem sikerült csatlakoztatni.';

  @override
  String get emailSetupTitle => 'E-mail és naptár csatlakoztatása';

  @override
  String get emailChecking => 'Postafiók ellenőrzése…';

  @override
  String get emailSetupIntro =>
      'Használj alkalmazásjelszót a levelezőszolgáltatódtól. Fejlesztői konzol nélkül, pár perc alatt kész.';

  @override
  String emailOpenArg1(String provider) {
    return '$provider megnyitása';
  }

  @override
  String get emailStepServers => '1. Add meg a szervereket';

  @override
  String get emailStepPassword => '1. Hozz létre alkalmazásjelszót';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return '$provider alkalmazásjelszavainak megnyitása';
  }

  @override
  String get emailStepSignIn => '2. Bejelentkezés';

  @override
  String get appPassword => 'Alkalmazásjelszó';

  @override
  String get appPasswordHelper =>
      'A szóközök nem számítanak. A NeoAgent titkosítva tárolja.';

  @override
  String get emailUsernameOptional => 'Felhasználónév, ha nem az e-mail-címed';

  @override
  String get emailIncludeCalendar => 'Naptár is';

  @override
  String get emailIncludeContacts => 'Névjegyek is';

  @override
  String get imapServer => 'IMAP-szerver';

  @override
  String get smtpServer => 'SMTP-szerver';

  @override
  String get caldavUrlOptional => 'CalDAV URL (nem kötelező)';

  @override
  String get carddavUrlOptional => 'CardDAV URL (nem kötelező)';

  @override
  String get alternativeEmail =>
      'Csatlakoztasd a postafiókot alkalmazásjelszóval, vagy a naptárat az iCal-hivatkozásával. Pár perc alatt kész.';

  @override
  String get alternativePhone =>
      'Oszd meg a telefonon már meglévő naptárat és névjegyeket a NeoAgent alkalmazással.';

  @override
  String get alternativePhoneElsewhere =>
      'Oszd meg a telefonon már meglévő naptárat és névjegyeket. Állítsd be a telefonos NeoAgent alkalmazásban.';

  @override
  String get skipTheDeveloperConsole => 'Fejlesztői konzol nélkül';

  @override
  String get phoneSyncPromptTitle => 'Láthatja az ügynököd a naptáradat?';

  @override
  String get phoneSyncPromptBody =>
      'Oszd meg a telefon naptárait és névjegyeit, hogy az ügynököd a napodhoz igazodva tervezhessen. Bármikor módosíthatod: Eszközök › Integrációk.';

  @override
  String get phoneSyncTitle =>
      'A telefon naptárának és névjegyeinek megosztása';

  @override
  String get phoneSyncIntro =>
      'Az ügynököd látja a telefon összes fiókjának naptárait és névjegyeit. Nincs fejlesztői konzol, nincs külön bejelentkezés.';

  @override
  String get phoneSyncPointAccounts =>
      'Működik a telefonon lévő Google-, Outlook-, iCloud- és Exchange-fiókokkal.';

  @override
  String get phoneSyncPointPrivate =>
      'Csak a NeoAgent-szervereddel osztod meg, amely titkosítva tárolja.';

  @override
  String get phoneSyncPointWrites =>
      'Az ügynök által hozzáadott eseményeket ez a telefon hozza létre, és a szokásos módon szinkronizálódnak.';

  @override
  String get phoneSyncCalendarHint =>
      'Események 30 nappal ezelőttől 90 nappal előre';

  @override
  String get phoneSyncContacts => 'Névjegyek';

  @override
  String get phoneSyncContactsHint => 'Nevek, e-mail-címek és telefonszámok';

  @override
  String get phoneSyncOtherAgent =>
      'Ez a telefon egy másik ügynökkel oszt meg. Az itteni megosztás áthelyezi ehhez az ügynökhöz.';

  @override
  String get phoneSyncDenied =>
      'A NeoAgent még nem fér hozzá. Engedélyezd a Beállításokban, majd gyere vissza.';

  @override
  String get openPhoneSettings => 'Beállítások megnyitása';

  @override
  String get phoneSyncShare => 'Megosztás a NeoAgenttel';

  @override
  String get phoneSyncStop => 'Megosztás leállítása';

  @override
  String get phoneSyncWaiting => 'Várakozás az első szinkronizálásra…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Utoljára szinkronizálva: $time';
  }

  @override
  String get calendarLink => 'Naptárhivatkozás';

  @override
  String get calendarLinkHelper =>
      'A naptár iCal-címe. Bárki, aki ismeri, olvashatja a naptárt, ezért tartsd titokban.';

  @override
  String get calendarLinkName => 'Név (nem kötelező)';

  @override
  String get calendarLinkAdded => 'Naptár hozzáadva';

  @override
  String get toolsApps => 'Alkalmazások';

  @override
  String get reconnect => 'Újracsatlakozás';

  @override
  String get reconnectNeeded => 'Újracsatlakozás szükséges';

  @override
  String get mixedAccess => 'Vegyes hozzáférés';

  @override
  String disconnectAccountTitle(String account) {
    return 'Leválasztod: $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Az ügynök ezen a fiókon keresztül elveszíti a hozzáférést ehhez: $apps.';
  }

  @override
  String get neoRouterServerDescription =>
      'Csatlakoztasd egyszer a NeoRoutered, és minden itteni fiók azt használja a lent bekapcsolt feladatokhoz.';

  @override
  String get neoRouterUserDescription =>
      'A lent bekapcsolt feladatokhoz a saját NeoRouter-fiókodat használd a szerver szolgáltatói helyett.';

  @override
  String get neoRouterAddress => 'NeoRouter címe';

  @override
  String get neoRouterConnect => 'NeoRouter csatlakoztatása';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Hagyd jóvá a NeoAgentet a NeoRouterben. Ott a(z) $arg1 kód látható.';
  }

  @override
  String get neoRouterOpenAgain => 'Újra megnyitás';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Csatlakoztatva: $arg1';
  }

  @override
  String get neoRouterUnreachable => 'A NeoRouter most nem érhető el.';

  @override
  String get neoRouterDisconnect => 'Leválasztás';

  @override
  String get neoRouterDisconnectBody =>
      'A NeoAgent többé nem használja ezt a NeoRoutert. A kulcsot is vond vissza a NeoRouter API-kulcsok részében.';

  @override
  String neoRouterServerInUseArg1(Object? arg1) {
    return 'Ez a szerver már használja a NeoRoutert itt: $arg1. Csatlakoztasd ott a saját fiókodat saját modellekhez és kerethez.';
  }

  @override
  String get neoRouterConnected => 'A NeoRouter csatlakoztatva.';

  @override
  String get neoRouterRoleChat => 'Csevegés és képfelismerés';

  @override
  String get neoRouterRoleSystemOne => 'System One döntések';

  @override
  String get neoRouterRoleTranscription => 'Beszédből szöveg';

  @override
  String get neoRouterRoleLive => 'Élő hang';

  @override
  String get neoRouterRoleEmbeddings => 'Keresés a memóriában';

  @override
  String get neoRouterRoleImages => 'Képek készítése';

  @override
  String get neoRouterRoleSearch => 'Webes keresés';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'Elérhető a NeoRouteredben: $arg1';
  }

  @override
  String get neoRouterNoModels => 'A NeoRouteredben még nincs semmi.';

  @override
  String get neoRouterPicksModels =>
      'A NeoRouter minden kéréshez maga választ modellt, ezért ez a készlet nincs használatban.';
}
