// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Slovenian (`sl`).
class AppL10nSl extends AppL10n {
  AppL10nSl([String locale = 'sl']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'dobrodošli';

  @override
  String get onboardingEyebrowCommunication => 'Komunikacija';

  @override
  String get onboardingEyebrowIntelligence => 'Inteligenca';

  @override
  String get onboardingEyebrowComputer => 'Računalnik';

  @override
  String get onboardingEyebrowAutomation => 'Avtomatizacija';

  @override
  String get onboardingNext => 'Naprej';

  @override
  String get onboardingIntroCouldNotLoad => 'Uvoda ni bilo mogoče naložiti.';

  @override
  String get onboardingModelDescription =>
      'Izberite model, ki naj ga NeoAgent uporablja privzeto, ali pustite, da izbere samodejno.';

  @override
  String get onboardingLoadingModels => 'Nalaganje modelov …';

  @override
  String get noAiModelTitle => 'Nastavljen še ni noben model AI';

  @override
  String get noAiModelBody =>
      'Dodajte ključ API ponudnika, kot je OpenAI, Anthropic ali Google. NeoAgent nato prikaže modele, ki jih lahko uporabite.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent za odgovor potrebuje model AI. Dodajte ključ API ponudnika, kot je OpenAI, Anthropic ali Google.';

  @override
  String get noAiModelAdminHint =>
      'Kot skrbnik lahko tudi nastavite ponudnike za vse pod Admin → Providers.';

  @override
  String get addApiKey => 'Dodajte ključ API';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform je povezan.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Čakam, da se $platform poveže ...';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Nastavitve ni bilo mogoče shraniti: $error';
  }

  @override
  String get onboardingEyebrowReady => 'pripravljena';

  @override
  String get onboardingStepRequired => 'Obvezno';

  @override
  String get onboardingStepOptional => 'Neobvezno';

  @override
  String get onboardingStepCloudOrLocal => 'Oblak ali lokalno';

  @override
  String get onboardingStepComputer => 'Računalnik';

  @override
  String get onboardingStepRoutines => 'Rutine';

  @override
  String get onboardingComputerChoiceTitle => 'Kje naj\ndeluje?';

  @override
  String get onboardingComputerChoiceDescription => 'Preklopite lahko na sejo.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Zasebni peskovnik · vedno vklopljen';

  @override
  String get onboardingThisComputer => 'Ta računalnik';

  @override
  String get onboardingThisComputerSubtitle =>
      'Vaše datoteke, aplikacije in brskalnik';

  @override
  String get onboardingSearchApps => 'Iskanje aplikacij ...';

  @override
  String get onboardingRoutinesDescription =>
      'Rezultati prispejo v vaše klepete.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Rezultati prispejo kot obvestila.';

  @override
  String get onboardingNotifications => 'Obvestila';

  @override
  String get onboardingReadyTitle => 'Vse je\npripravljeno.';

  @override
  String get onboardingReadyDescription => 'Pošlji svoje prvo sporočilo.';

  @override
  String get onboardingMessageNeoagent => 'Sporočilo NeoAgent';

  @override
  String get onboardingAskAnything => 'Vprašaj karkoli…';

  @override
  String get onboardingOpenNeoagent => 'Odprite NeoAgent';

  @override
  String get onboardingStarterTrip => 'Načrtujte vikend izlet';

  @override
  String get onboardingStarterLanding => 'Zgradite ciljno stran';

  @override
  String onboardingQuickSteps(int count) {
    return '$count hitri koraki';
  }

  @override
  String get taskNeedsEmail => 'Najprej povežite e-pošto';

  @override
  String get taskNeedsCalendar => 'Najprej povežite koledar';

  @override
  String get taskNeedsModel => 'Najprej nastavite model AI';

  @override
  String get taskPromptDailyRecap =>
      'Povzemite svoj dan: povzemite pogovore, opravljeno delo in odločitve od danes, nato naštejte vse, kar bi moral nadaljevati jutri. Naj bo kratek in mi ga pošlji.';

  @override
  String get taskPromptInboxCheck =>
      'Preverite moj e-poštni nabiralnik za sporočila, ki so prispela od zadnjega preverjanja. Pošiljajte mi le sporočila o e-poštnih sporočilih, ki so nujna ali potrebujejo odgovor, s povzetkom v eni vrstici. Če nič ne potrebuje moje pozornosti, ne pošiljajte ničesar.';

  @override
  String get taskPromptMorningBriefing =>
      'Pripravite moj jutranji brifing: današnje vreme, kjer sem, dogodki na mojem koledarju in najpomembnejše odprte postavke, ki jih poznam. Pošljite ga kot kratko sporočilo, ki ga je mogoče skenirati.';

  @override
  String get taskPromptTomorrowPrep =>
      'Poglej moj koledar za jutri. Za vsako srečanje mi povejte, za kaj gre, kdo je vključen in kaj naj pripravim. Če je jutri prazno, ne pošiljajte ničesar.';

  @override
  String get taskPromptNewsDigest =>
      'V spletu poiščite najpomembnejše današnje novice o temah, ki me zanimajo (uporabite tisto, kar se spomnite o mojih zanimanjih). Pošlji mi povzetek največ petih elementov z enim stavkom in povezavo.';

  @override
  String get taskPromptWeeklyReview =>
      'Preglejte moj teden: kaj sem naredil, kaj je spodrsnilo in kaj je še odprto. Predlagajte tri najpomembnejše stvari, na katere se morate osredotočiti naslednji teden.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Povežite telefonsko številko, ki pripada agentu. Vsakdo, ki mu dovolite, lahko klepeta z njim v neposrednih klepetih in skupinah.';

  @override
  String get whatsappSelfChatDescription =>
      'Povežite svojo številko in se pogovorite z agentom v klepetu »Sporočilo si«. Vsi ostali klepeti in skupine v tem računu so prezrti.';

  @override
  String get chatSendHintMac => '⌘↵ za pošiljanje';

  @override
  String get chatSendHintOther => 'Ctrl+Enter za pošiljanje';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Za to končno točko je potreben osnovni URL.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Spremenjeni elektronski naslov je pred uporabo potrjen.';

  @override
  String get aDecisionHigherUpTheChain => 'Zmaga odločitev višje v verigi.';

  @override
  String get aDeletedAccount => 'izbrisan račun';

  @override
  String get aFridayLookBackAtThe =>
      'Petkov pogled nazaj na teden in načrt za naslednjega.';

  @override
  String get aKeyThatAsksForA =>
      'Ključ, ki zahteva PIN ali prstni odtis, prav tako nadomesti vašo dvofaktorsko kodo.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Jezikovni model je ocenil to sporočilo, ker je SystemOne izklopljen.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Nastavitvena metapodatkovna datoteka NeoAgent je presegla varno omejitev velikosti.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Na strežniku je na voljo novejša spletna zgradba. Znova naložite, da pridobite najnovejši sveženj.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Zasebno namizje s Chromiumom, datotekami, urejevalnikom besedil, terminalom in Pythonom. Vaše delo ostane shranjeno med sejami.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Zasebni računalnik z operacijskim sistemom Linux ali naprava s sistemom Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Zahtevane nastavitvene datoteke NeoAgent ni bilo mogoče prenesti.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Soigralec vam pošlje povezavo s povabilom. Ko to sprejmete, oni ';

  @override
  String get aTeammateSentYouAnInvite =>
      'soigralec vam je poslal povezavo s povabilom; vnesite jo tukaj, da se pridružite njegovi ekipi.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Začasni prenos bo pozneje očiščen.';

  @override
  String get aValueIsStored => 'Vrednost je shranjena.';

  @override
  String get access => 'Dostop';

  @override
  String get accessActivity => 'Dejavnost dostopa';

  @override
  String accessArg1(Object? arg1) {
    return 'Dostop: $arg1';
  }

  @override
  String get accessMode => 'Način dostopa';

  @override
  String get accessPermissions => 'Dovoljenja za dostop';

  @override
  String get accessToken => 'dostopni žeton';

  @override
  String get accessToken2 => 'Žeton za dostop';

  @override
  String get account => 'Račun';

  @override
  String accountArg1(Object? arg1) {
    return 'Račun #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Opozorila o spremembi računa';

  @override
  String get accountEmail => 'E-pošta računa';

  @override
  String get accountEmailIsOffUntilThese =>
      'E-pošta računa je izklopljena, dokler ne nastavite teh: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent uporablja ta jezik povsod v aplikaciji. Ko se prvič prijavite, sledi tej napravi. Po tem se izbira shrani v vaš račun in se uporablja v vsaki napravi.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Ni bilo mogoče spremeniti jezika: $error';
  }

  @override
  String get accountLanguageTitle => 'Jezik';

  @override
  String get accountNumber => 'Številka računa';

  @override
  String get accountSettings => 'Nastavitve računa';

  @override
  String get accounts => 'Računi';

  @override
  String get accountsByTokensUsedAllTime =>
      'Računi po uporabljenih žetonih, ves čas.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'računov v oblaku. Spremembe veljajo po strežniku ';

  @override
  String get accountsOnThisServer => 'Računi na tem strežniku';

  @override
  String get active => 'Aktiven';

  @override
  String get activeSessions => 'Aktivne seje';

  @override
  String get activeToday => 'Aktiven danes';

  @override
  String get add => 'Dodaj';

  @override
  String get addAProviderCredentialFirstIts =>
      'Najprej dodajte poverilnico ponudnika. Njegovi modeli se tukaj prikažejo enkrat ';

  @override
  String get addAgent => 'Dodaj agenta';

  @override
  String get addAnotherSignInMethodBefore =>
      'Dodajte drug način prijave, preden odstranite tega.';

  @override
  String get addBinding => 'Dodajte vezavo';

  @override
  String get addByNameOrId => 'Dodajte po imenu ali ID-ju';

  @override
  String get addByNameOrIdInstead => 'Namesto tega dodajte po imenu ali ID-ju';

  @override
  String get addCredentialBinding => 'Dodajte vezavo poverilnic';

  @override
  String get addEntry => 'Dodaj vnos';

  @override
  String get addKey => 'Dodaj ključ';

  @override
  String get addMcpServer => 'Dodajte strežnik MCP';

  @override
  String get addMemory => 'Dodaj pomnilnik';

  @override
  String get memoryReview => 'Preglej';

  @override
  String get memoryReviewPrompt =>
      'Preglej vse moje spomine in jih pospravi: arhiviraj dvojnike, zastarela dejstva in vse brez trajne vrednosti. Nato mi na kratko povej, kaj si spremenil.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Dodajte večjo dolžino ali drugo vrsto znaka.';

  @override
  String get addPeopleOrGroups => 'Dodajte osebe ali skupine';

  @override
  String get addSecurityKey => 'Dodajte varnostni ključ';

  @override
  String get addSomeoneOrAGroup => 'Dodajte nekoga ali skupino';

  @override
  String get addTask => 'Dodaj opravilo';

  @override
  String get addTests => 'Dodajte teste';

  @override
  String get addTestsForThePartsOf =>
      'Dodajte teste za dele tega projekta, ki imajo najmanjšo pokritost, in jih nato zaženite.';

  @override
  String get addTheirOwnKeysInSettings => 'dodajo lastne ključe v nastavitvah.';

  @override
  String get addToPrompt => 'Dodaj v poziv';

  @override
  String get added => 'Dodano';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Dodano $arg1 · Nazadnje uporabljen $arg2';
  }

  @override
  String get addressWithTheProvider => 'naslov pri ponudniku.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Prilagodite glasnost zvočnika, preglejte privzete nastavitve gumbov strojne opreme in upravljajte to sejo zaganjalnika.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Prilagodite filter za iskanje ali status, da vidite več kanalov za sporočanje.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Tukaj prilagodite glasnost zvočnika.';

  @override
  String get admin => 'skrbnik';

  @override
  String adminArg1(Object? arg1) {
    return 'Admin › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Tukaj so prikazane skrbniške podpore, povezave do povabil in spremembe upravljanja.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Napreden ročni urnik za posebne primere.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Napredno: minuta ura dan mesec dan v tednu.';

  @override
  String get againRightAway => 'takoj spet.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent: $arg1';
  }

  @override
  String get agentCalls => 'Klici agentov';

  @override
  String get agentCommunication => 'Agentska komunikacija';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Komunikacija agenta: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Agentski način ureja delovni prostor · ⌘↵ pošlji · ⌘N nova seja';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agent se ustavi in vas pred izvajanjem prosi za dovoljenje.';

  @override
  String get agentProfile => 'Profil agenta';

  @override
  String get agentVisibleName => 'Zastopniku vidno ime';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agent želi uporabiti $arg1. Tapnite za odločitev.';
  }

  @override
  String get agents => 'Agenti';

  @override
  String get aiAnswerUnreadable => 'Odgovor AI neberljiv';

  @override
  String get aiProviderKeys => 'Ključi ponudnika AI';

  @override
  String get aiUnavailable => 'AI ni na voljo';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'opozorila in druga e-pošta računa od.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Opozori, ko povezava za sporočanje zahteva pozornost uporabnika';

  @override
  String get all => 'Vse';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Vsi agenti ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Vsi $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Vse reže v oblaku so trenutno v uporabi. Poskusite znova čez trenutek.';

  @override
  String get allComputerSlotsAreBusy => 'Vse računalniške reže so zasedene';

  @override
  String get allTables => 'Vse mize';

  @override
  String get allTime => 'Ves čas';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Vsa orodja so dovoljena – agent lahko uporablja katero koli zmožnost brez vprašanja. ';

  @override
  String get allow => 'Dovoli';

  @override
  String get allowedRunsWithoutAsking => 'Dovoljeno. Teče brez vprašanja.';

  @override
  String get allowAll => 'Dovoli vse';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Dovolite »Namesti neznane aplikacije« za NeoAgent, nato znova poskusite posodobiti.';

  @override
  String get allowOnce => 'Dovolite enkrat';

  @override
  String get allowSender => 'Dovoli pošiljatelju';

  @override
  String get allowSession => 'Dovoli sejo';

  @override
  String get allowTheAgentToStartAn =>
      'Dovolite agentu, da z vami začne glasovni klic v aplikaciji.';

  @override
  String get allowedOrigins => 'Dovoljeno poreklo';

  @override
  String get allowedPathPrefix => 'Dovoljena predpona poti';

  @override
  String get allowsYouCanChangeThatPer =>
      'dovoljuje. To lahko pozneje spremenite za vsako osebo. Povezave nikoli ne odobrijo ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'že pripada obstoječemu računu';

  @override
  String get alreadyLinkedToAnotherAccount => 'že povezan z drugim računom';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'že povezan z drugim računom neoagent';

  @override
  String get alreadyUsed => 'že uporabljena';

  @override
  String get always => 'Vedno';

  @override
  String get alwaysAllow => 'Vedno dovoli';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '»Vedno dovoli« trajno shrani pravilnik – spremenite ga lahko v nastavitvah.';

  @override
  String get alwaysAsk => 'Vedno vprašaj';

  @override
  String get alwaysEngage => 'Vedno sodeluj';

  @override
  String get alwaysJoins => 'Vedno se pridruži';

  @override
  String get anApiKeyIsRequired => 'Potreben je ključ API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Večerni povzetek dogajanja in kaj slediti.';

  @override
  String get anHttpOrHttpsUrlIs => 'Potreben je URL http ali https.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'in analitiko. Povezave ekipe so na voljo na strani ekipe.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Namestitev APK-ja za Android na tej platformi ni na voljo.';

  @override
  String get androidApp => 'Aplikacija za Android';

  @override
  String get androidControl => 'Android Control';

  @override
  String get androidCouldNotStart => 'Androida ni bilo mogoče zagnati';

  @override
  String get androidNotificationReceived => 'Prejeto obvestilo za Android';

  @override
  String get androidOnly => 'Samo Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Namestitvenega programa za pakete za Android ni bilo mogoče odpreti.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Zaslon Android — tapnite za dotik, povlecite za vlečenje';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Odgovarja na @omembe o težavah in zahteve po vleku';

  @override
  String get anyone => 'Kdorkoli';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Vsakdo na tej platformi lahko pošlje sporočilo $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Vsakdo na tej platformi lahko pošlje sporočilo $arg1 v $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Vsakdo, ki lahko doseže ta račun, se lahko pogovarja z $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Vsakdo s povezavo se lahko pridruži, dokler ne poteče ali je ne prekličete.';

  @override
  String get apiHttpsOrigin => 'Izvor API HTTPS';

  @override
  String get apiKey => 'API ključ';

  @override
  String get apiKey2 => 'api ključ';

  @override
  String get apiKey3 => 'API ključ';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api ključ anthropic claude openai gpt xai grok google gemini minimax nvidia nim openrouter poverilnice';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Ključi API in končne točke za AI, ponudnike iskanja in govora. Oni ';

  @override
  String get apiRequest => 'API zahteva';

  @override
  String get apiYourOwnServerASelf =>
      'API -- vaš lastni strežnik, model, ki ga sami gostite, ali drug ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Prenos APK-ja ni uspel s HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Zahtevano je ime aplikacije.';

  @override
  String get appUpdates => 'Posodobitve aplikacij';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Posodobitve aplikacij niso konfigurirane za to zgradbo.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Uporabljene posodobitve krmiljenja v čakalni vrsti $arg1 za trenutno vožnjo.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Uporabljene posodobitve krmiljenja $arg1.';
  }

  @override
  String get apply => 'Prijavite se';

  @override
  String get applyBehaviorNotes => 'Uporabite opombe o vedenju';

  @override
  String get applyCoreMemory => 'Uporabite osnovni pomnilnik';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Zahteve za odobritev občutljivih agentskih orodij';

  @override
  String get approvalRequired => 'Zahtevana odobritev';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Odobritev ostane v vaši preverjeni mobilni seji in vsaka koda samodejno poteče po kratkem oknu.';

  @override
  String get approveLogin => 'Odobri prijavo';

  @override
  String get approveQrLogin => 'Odobrite prijavo QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Odobrite to samo, če ste se prijavili v tej napravi pravkar.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Odobrena prijava za $arg1.';
  }

  @override
  String get approvedOnly => 'Samo odobreno';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Odobreno združevanje za $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Odobreni ljudje in skupine';

  @override
  String get approvedPeopleOnly => 'Samo odobreni ljudje';

  @override
  String get archive => 'Arhiv';

  @override
  String get archiveAgent => 'Arhivski agent?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Arhiv ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Arhiv $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Arhivirati izbrane spomine?';

  @override
  String get areSharedByEveryAccountOn =>
      'si delijo vsi računi na tem strežniku; računi še vedno lahko ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M vhod';
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
    return '$arg1 Potreben dostop';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 računi';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktiven';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return 'Dodan $arg1. Uredite ga kadar koli, da spremenite ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '»$arg1« in njegova zgodovina izvajanja bosta trajno izbrisana. Vsak aktivni tek bo ustavljen. Datotek v delovnem prostoru se ne dotika.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Potrebna je odobritev $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'Aktivne aplikacije $arg1';
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
    return '$arg1 (aktivna orodja $arg2)';
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
    return '$arg1 $arg2 in $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 spremenjeno';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 znakov';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Ustvarjeno $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [lokalni uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 se ujema z »$arg3«';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return 'Delovni prostor $arg1${arg2}NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 novi računi';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 teče · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 vzorci';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 krmiljenje v čakalni vrsti';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\nžetoni $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'Žetoni $arg1 / $arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 pri $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 je postal admin ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 bajtov';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'kanal $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 znakov';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 počiščeno.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 konfiguriran';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 povezan. Izberite repozitorije in osebe pod Kdo lahko pošilja sporočila.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 temeljni vnosi.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 je ustvaril povezavo za povabilo';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 namizje';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'dogodki $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 ni uspelo';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 ni uspelo';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 ne uspe';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 za $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Samo označene skupine $arg1';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h nazaj';
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
    return '$arg1 pomočniki';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 razmerje zadetkov)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 je skrbnik, zato računa ni mogoče izbrisati ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 je blokiran na $arg2. Posodobite seznam dostopov, da omogočite odgovore.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 je povezan in se odziva.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 ni več skrbnik ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 ni na voljo na $arg2 (manjka dovoljenje za izvajanje ali odvisnost).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 združen pod $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 sodil LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 ključ $arg2 konfiguriran';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Ključ $arg1 odstranjen.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 levo';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 levo $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 povezan';
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
    return '$arg1. Prepričajte se, da deluje, nato poskusite znova.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 upravlja ta račun';
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
    return 'Modeli $arg1 pripravljeni';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 več';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 več korakov v zgodovini teka';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 se je preselil iz $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 mora biti končno število.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 mora biti naslov http:// ali https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 potrebuje pozornost';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Delovni prostor $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 novi računi v zadnjem $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nova sporočila vodijo ta tek';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 nove vožnje';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 zdaj upravlja ta račun.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 od 4 dovoljenj. Datoteke so omejene na vašo mapo NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 od $arg2 omogočen';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 od skupin $arg2 se pridruži navadnemu klepetu';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 od modelov $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 modelov $arg2 pripravljen';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 od niza $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 orodij $arg2 je dovoljeno';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 na dan $arg2 ob $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 odgovarja samo osebam, ki jih dodate spodaj.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 odgovarja le, ko je označen';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 se pogovarja samo z ljudmi in skupinami, ki jih odobrite';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 dodanih oseb ali skupin';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 načrtovanje';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Ponudniki $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 pripravljen';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Zapisi $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI preusmeritve $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registriran';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 je odgovoril';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 je preklical povezavo povabila';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 teče';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 teče · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 teče v zadnjem $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 shranjeno.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 izbrano';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Prikazan $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 je ostal tiho';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 krmiljenje $arg2 v čakalni vrsti';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · tapnite vozlišče za pregled';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 koraki';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 je prenehal upravljati $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 žetoni';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 žetonov v zadnjem $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'orodja $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (nerazpoložljiva shranjena preglasitev)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return 'Uporabljeno $arg1% · Preostalo $arg2';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 želi govoriti s teboj.';
  }

  @override
  String arg1Web(Object? arg1) {
    return 'splet $arg1';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '»$arg1« bo trajno odstranjen.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 bo upravljal ta račun';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 ne bo odgovarjal na tej platformi';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 ne bo odgovoril na $arg2.';
  }

  @override
  String get artifactStorageByUser =>
      'Shranjevanje artefaktov s strani uporabnika';

  @override
  String get askAQuestionOrStartA =>
      'Postavite vprašanje ali začnite z nalogo ...';

  @override
  String get askBeforeClosingToBackground => 'Vprašaj, preden zapreš v ozadje';

  @override
  String get askMe => 'vprašaj me';

  @override
  String get assignedAgent => 'Dodeljeni agent';

  @override
  String get assignedAgent2 => 'Dodeljeni zastopnik';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Dodeljeni agent: $arg1';
  }

  @override
  String get assigneeOptional => 'Prejemnik (neobvezno)';

  @override
  String get assistant => 'Pomočnik';

  @override
  String get assistantKey131 => 'Tipka pomočnika 131';

  @override
  String get atLeast1 => 'Vsaj 1.';

  @override
  String get attachFiles => 'Priloži datoteke';

  @override
  String attentionArg1(Object? arg1) {
    return 'Pozor $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'revizijski dnevnik skrbnik odobri preklic povabila zgodovina ekipe';

  @override
  String get authMethod => 'Auth Method';

  @override
  String get authServerUrl => 'URL strežnika za preverjanje';

  @override
  String get authentication => 'Preverjanje pristnosti';

  @override
  String get authenticationFailed => 'Preverjanje ni uspelo.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Preverjanje pristnosti je še v teku. Dokončajte potek brskalnika in poskusite znova.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Preverjanje pristnosti je še v teku. Dokončajte potek brskalnika in ga osvežite.';

  @override
  String get authenticationTimedOut => 'Preverjanje pristnosti je poteklo.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Preverjanje pristnosti je bilo preklicano pred zaključkom.';

  @override
  String get authenticatorApp => 'Aplikacija za preverjanje pristnosti';

  @override
  String get authenticatorCode => 'Koda avtentifikatorja';

  @override
  String get authorOptional => 'Avtor (neobvezno)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Samodejno (prvi ponudnik s ključem API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Samodejne poti do najboljšega razpoložljivega modela';

  @override
  String get automaticFast => 'Samodejno (hitro)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Samodejno bere sobo in se običajno zadrži. Samo omemba ne sprejema odločitev, dokler ni neposredno naslovljena.';

  @override
  String get automaticReserved => 'Samodejno, rezervirano';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Za samodejno vrnitev je treba znova poskusiti z nastavitvenega zaslona.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Samodejno izbere hiter model prek običajnega kataloga modelov.';

  @override
  String get automation => 'Avtomatizacija';

  @override
  String get available => 'Na voljo';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Ponovno na voljo v $arg1';
  }

  @override
  String get availableAgainShortly => 'V kratkem spet na voljo';

  @override
  String get availableInTheDesktopAppFor =>
      'Na voljo v namizni aplikaciji za macOS, Windows in Linux';

  @override
  String get availableToTheAgent => 'Na voljo zastopniku';

  @override
  String get averageAllTime => 'Povprečje, ves čas';

  @override
  String get avgImp => 'Povpr. prik.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Povprečje/izvajanje: $arg1 žetonov';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Izogibajte se ponavljajočim se znakom in očitnim zaporedjem.';

  @override
  String get awaitingScan => 'Čakanje na skeniranje';

  @override
  String get back => 'Nazaj';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count v ozadju';
  }

  @override
  String get backgroundTasks => 'Naloge v ozadju';

  @override
  String get backOn => 'nazaj na.';

  @override
  String get backToChat => 'Nazaj na klepet';

  @override
  String get backToFolder => 'Nazaj v mapo';

  @override
  String get backToSignIn => 'Nazaj na prijavo';

  @override
  String get backendChannel => 'Zaledni kanal';

  @override
  String get backendOnThisComputer => 'Backend v tem računalniku';

  @override
  String get backendSync => 'Zaledna sinhronizacija';

  @override
  String get backgroundLocationNeeded => 'Potrebna je lokacija v ozadju';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Sinhronizacija v ozadju ostane načrtovana v sistemu Android';

  @override
  String get badState => 'Slabo stanje: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Osnovna slika in velikost navideznih strojev QEMU, ki se izvajajo ';

  @override
  String get baseUrlOptional => 'Osnovni URL (izbirno)';

  @override
  String get baseUrlTokenLocal => 'osnovni url žeton lokalni';

  @override
  String get basicAuthentication => 'Osnovna avtentikacija';

  @override
  String get behaviorModules => 'Moduli obnašanja';

  @override
  String get behaviorNotes => 'vedenjske opombe';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Posrednik poverilnic Bitwarden';

  @override
  String get bitwardenItem => 'Bitwarden predmet';

  @override
  String get bitwardenServer => 'Strežnik Bitwarden';

  @override
  String get blankUsesCommon => 'Prazno uporablja \"skupno\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Prazno uporablja privzeti povratni klic';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Prazne vrednosti uporabljajo privzete nastavitve ponudnika.';

  @override
  String get block => 'Blokiraj';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Blokirano dohodno sporočilo od $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Most, združljiv z BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'URL strežnika BlueBubbles';

  @override
  String get botToken => 'Botov žeton';

  @override
  String get botTokenAndApprovedChats => 'Bot žeton in odobreni klepeti';

  @override
  String get botTokenAndServerChannelAccess =>
      'Bot žeton in dostop do strežnika/kanala';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bot žeton, Events API in dostop do kanala';

  @override
  String get botUserId => 'ID uporabnika bota';

  @override
  String get botUsername => 'Uporabniško ime za bota';

  @override
  String get brandName => 'Blagovna znamka';

  @override
  String get braveSearch => 'Pogumno iskanje';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Premostite vse ponudnike, ki lahko objavljajo in prejemajo obremenitve webhook.';

  @override
  String get bringYourOwnKey => 'prinesite svoj ključ';

  @override
  String get bringYourOwnKey2 => 'Prinesite svoj ključ';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Brskalnik, namizje Linux, datoteke, terminal in Python si delijo en trajni računalnik v oblaku.';

  @override
  String get browserLogin => 'Prijava v brskalnik';

  @override
  String get browserScripting => 'Skriptiranje brskalnika';

  @override
  String get call => 'Pokliči';

  @override
  String get callAgent => 'Pokličite agenta';

  @override
  String get callUser => 'Pokličite uporabnika';

  @override
  String get calledByName => 'Poklican po imenu';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Naloge lahko prenese na druge agente';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Lahko prenese na $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Lahko prejema delegirane naloge';

  @override
  String get cancel => 'Prekliči';

  @override
  String get cancelTask => 'Prekliči nalogo';

  @override
  String get cannotPreview => 'Predogleda ni mogoče';

  @override
  String get cannotReceiveDelegatedTasks =>
      'ne more prejemati prenesenih nalog';

  @override
  String get cannotRunYet => 'še ne more teči.';

  @override
  String get capturedThePage => 'Zajel stran';

  @override
  String get category => 'Kategorija';

  @override
  String chainArg1(Object? arg1) {
    return 'Verižica: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Spremenite način nastavitve';

  @override
  String get channel => 'Kanal';

  @override
  String get channelAccessToken => 'Žeton za dostop do kanala';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanal: $arg1$arg2 | Različica posodobitve: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Socialni spomin v obsegu kanala';

  @override
  String get channels => 'Kanali';

  @override
  String get chat => 'Klepetajte';

  @override
  String get chatId => 'ID klepeta';

  @override
  String get chatMode => 'Način klepeta';

  @override
  String get chatModel => 'Model klepeta';

  @override
  String get checkAutomaticallyOnLaunch => 'Samodejno preveri ob zagonu';

  @override
  String get checkForMessagesEveryMs => 'Preveri sporočila vsakih (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Samodejno preveri nova sporočila';

  @override
  String get checkNow => 'Preverite zdaj';

  @override
  String get checkYourEmailToConfirmYour =>
      'Preverite svojo e-pošto, da potrdite svoj račun NeoAgent, preden se prijavite.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Preverjeno $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Izberite kategorijo ali iščite po vseh nastavitvah.';

  @override
  String get chooseAPerson => 'Izberite osebo';

  @override
  String get chooseAProjectFolder => 'Izberite mapo projekta';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Izberite privzete nastavitve za klepet, agente, nadomestno vedenje in pametno usmerjanje.';

  @override
  String get chooseGroups => 'Izberite skupine';

  @override
  String get chooseHowMuchYouWantTo =>
      'Izberite, koliko želite konfigurirati zdaj. Obe možnosti lahko pozneje spremenite.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Izberite, kako naj se ta naloga začne. Ročno deluje samo na Zaženi zdaj. Urnik je časovno odvisen. Integracija sproži požar iz povezanih uradnih aplikacij.';

  @override
  String get chooseOneToGetStartedNow =>
      'Izberite eno, da začnete zdaj. Pozneje jih lahko dodate več.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'V nastavitvah izberite model in glas v živo.';

  @override
  String get chooseTheirGroup => 'Izberite njihovo skupino';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Izberite, kje naj se ta oseba pogovarja z $arg1. To lahko pozneje spremenite pod Kdo lahko pošilja sporočila.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Izberite, katerim skupinam naj se $arg1 pridruži, tudi če ga nihče ne označi. Ta platforma morda ne bo razlikovala oznak od običajnih sporočil.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Izberite, katere modele lahko izbere vsak račun na tem strežniku in ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Izberite, s kom se $arg1 pogovarja in kdaj se pridruži skupinskim klepetom.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Izberite, kdo lahko doseže $arg1, nato shranite spremembe.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Izberite, kdo lahko pošlje agentu sporočilo z »Kdo lahko pošlje sporočilo« na kartici WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Izberite svoj\nprivzeti model.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, datoteke, urejevalnik besedil in terminal so na voljo na namizju Linux.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Počisti';

  @override
  String get clearAll => 'Počisti vse';

  @override
  String clearArg1(Object? arg1) {
    return 'Počisti $arg1?';
  }

  @override
  String get clearFilter => 'Počisti filter';

  @override
  String get clearFilters => 'Počisti filtre';

  @override
  String get clearSearch => 'Počisti iskanje';

  @override
  String get clearView => 'Jasen pogled';

  @override
  String get cliSession => 'seja CLI';

  @override
  String get clickIsNotSupportedOnThis => 'klik ni podprt na tej platformi.';

  @override
  String get clickOnceToBeginCapturing =>
      'Kliknite enkrat, da začnete zajemati';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Kliknite, tipkajte in uporabljajte namizne aplikacije.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Klik na ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Kliknil v brskalniku';

  @override
  String get clientId => 'ID stranke';

  @override
  String get clientSecret => 'Skrivnost stranke';

  @override
  String get close => 'Zapri';

  @override
  String get closeJ => 'Zapri (⌘J)';

  @override
  String get closeTeachMode => 'Zapri način učenja';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Če zaprete okno, lahko NeoAgent ostane v ozadju z dostopom do pladnja ali pa popolnoma zaprete namizni izvajalnik.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Podprti so primerki v oblaku in samogostiteljujoči primerki. URL-ji lokalnega in zasebnega omrežja delujejo, ko jih lahko doseže NeoAgent.';

  @override
  String get cloudComputer => 'Računalnik v oblaku';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Računalnik v oblaku · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Nastavitve računalnika v oblaku so shranjene. Znova zaženite strežnik, da jih uporabite.';

  @override
  String get cloudComputerVm => 'Računalnik v oblaku (VM)';

  @override
  String get cloudComputers => 'Računalniki v oblaku';

  @override
  String get codeHosting => 'Gostovanje kode';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Imena kanalov, ločena z vejicami, brez #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Ločeno z vejico, na primer #splošno, #pomoč';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Ločeno z vejicami. Težava mora vsebovati vse.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Ukaz ni uspel ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Potreben je ukaz.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Akumulator izhoda ukaza ni aktiven.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nalaganje izhoda ukaza ni uspelo ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Izhod ukaza naloži metapodatke o izpuščenih artefaktih.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Izhod ukaza je bil že dokončan.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Ukazi in aplikacije';

  @override
  String get commandsRunInTheSamePersistent =>
      'Ukazi se izvajajo v istem obstojnem računalniku, ki ga uporablja vidno namizje.';

  @override
  String get communityChatops => 'Skupnost in ChatOps';

  @override
  String get completeSetup => 'Dokončajte namestitev';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Dokončajte potek dela na namizju.';

  @override
  String get completed => 'Dokončano';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Popolnoma blokiran — agent ne more uporabljati te kategorije.';

  @override
  String get computerShell => 'Računalniška lupina';

  @override
  String get computerUsedByThisSession => 'Računalnik, uporabljen v tej seji';

  @override
  String get computerWorkspace => 'Delovni prostor računalnika';

  @override
  String get configurablePersonalWebhookBridge =>
      'Nastavljiv osebni webhook most';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Nastavljiv rele ali webhook most';

  @override
  String get configurableTalkWebhookBridge => 'Nastavljiv most Talk webhook';

  @override
  String get configurableWebInboxBridge =>
      'Nastavljiv most za spletno mapo »Prejeto«.';

  @override
  String get configurableWebhookBridge => 'Nastavljiv most webhook';

  @override
  String get configurableWebhooks => 'Webhooki, ki jih je mogoče konfigurirati';

  @override
  String get configurationOrInTheEnvFile =>
      'Konfiguracija ali v datoteki .env.';

  @override
  String get configure => 'Konfiguriraj';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Konfigurirajte vedenje delovnega prostora in privzete vrednosti modela.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Konfigurirano $arg1';
  }

  @override
  String get confirmEmailChanges => 'Potrdite spremembe e-pošte';

  @override
  String get confirmNewSignUps => 'Potrdite nove prijave';

  @override
  String get confirmPassword => 'Potrdite geslo';

  @override
  String get confirmPassword2 => 'Potrdite geslo';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Pred prijavo potrdite svojo e-pošto. Preverite e-poštno sporočilo storitve NeoAgent.';

  @override
  String get connect => 'Povežite se';

  @override
  String get connectAMessagingPlatform => 'Povežite platformo\nza sporočanje.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Povežite javno končno točko HTTPS Home Assistant z dolgoživim dostopnim žetonom. Lokalne naslove, naslove povratne zanke in zasebne omrežne naslove blokira strežnik.';

  @override
  String get connectAccount => 'Poveži račun';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Posamezno povežite račune aplikacij, da lahko AI uporabi pravi račun za vsako uradno integracijo.';

  @override
  String connectArg1(Object? arg1) {
    return 'Povežite $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Povežite poljubno število računov. Vsaka aplikacija lahko uporablja drug račun.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Povežite kanale, izberite, s kom se $arg1 pogovarja, in si oglejte nedavno dejavnost.';
  }

  @override
  String get connectInstance => 'Connect Instance';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Najprej povežite to integracijo, da izberete račun.';

  @override
  String get connectToThisServer => 'Povežite se s tem strežnikom';

  @override
  String get connectWhatsapp => 'Povežite WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Povežite svoj primerek Nextcloud, vključno s strežniki, ki sami gostujete. NeoAgent odpre lastno prijavno stran Nextcloud, tako da se lahko prijavite z geslom, SSO ali 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Povežite strežnik NeoRecall, ki ga sami gostite. NeoAgent prejme dostop samo za branje do lokalnega iskanja, spominov in dokazov o prepisu, potem ko odobrite zaslon OAuth.';

  @override
  String get connected => 'Povezan';

  @override
  String get connectedAccount => 'Povezan račun';

  @override
  String connectedArg1(Object? arg1) {
    return 'Povezan $arg1';
  }

  @override
  String get connectedInstance => 'Povezani primerek';

  @override
  String get connectedNeorecallUser => 'Povezan uporabnik NeoRecall';

  @override
  String get connectedNextcloudUser => 'Povezan uporabnik Nextcloud';

  @override
  String get connectedServer => 'Povezan strežnik';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Povezovanje z glasovnim modelom v živo ...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Povezava #$arg1';
  }

  @override
  String get connectionId => 'ID povezave';

  @override
  String get connectionLooksGood => 'Povezava izgleda dobro.';

  @override
  String get connectionMethod => 'Način povezave';

  @override
  String get containsTextOptional => 'Vsebuje besedilo (neobvezno)';

  @override
  String get content => 'Vsebina';

  @override
  String get contentSecurityPolicy => 'politiko varnosti vsebine';

  @override
  String get continue2 => 'Nadaljuj';

  @override
  String get continueFullSetup => 'Nadaljujte s popolno nastavitvijo';

  @override
  String get continueRun => 'Nadaljujte s tekom';

  @override
  String get continueToSetup => 'Nadaljujte z nastavitvijo';

  @override
  String get controlSurface => 'KONTROLNA POVRŠINA';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Nadzoruje dostop do orodij $arg1.';
  }

  @override
  String get conversation => 'Pogovor';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID pogovora, ki se uporabi, ko ta agent začne klepet.';

  @override
  String get cookieSetup => 'Nastavitev piškotkov';

  @override
  String get cookiesNotConfigured => 'Piškotki niso nastavljeni';

  @override
  String get copiedAsCsv => 'Kopirano kot CSV';

  @override
  String get copiedDebugInfo => 'Informacije o odpravljanju napak so kopirane';

  @override
  String get copiedExportForTheLast5 => 'Kopiran izvoz za zadnjih 5 sporočil';

  @override
  String get copiedFullPrompt => 'Kopiran celoten poziv';

  @override
  String get copiedLogs => 'Kopirani dnevniki';

  @override
  String get copiedRunId => 'Kopiran ID zagona';

  @override
  String get copy => 'Kopiraj';

  @override
  String get copyAll => 'Kopiraj vse';

  @override
  String get copyCodes => 'Kopirajte kode';

  @override
  String get copyCsv => 'Kopiraj CSV';

  @override
  String get copyDebugInfo => 'Kopiraj informacije o odpravljanju napak';

  @override
  String get copyLink => 'Kopiraj povezavo';

  @override
  String get copyLogs => 'Kopiraj dnevnike';

  @override
  String get copyPrompt => 'Kopiraj poziv';

  @override
  String get copyResponse => 'Kopiraj odgovor';

  @override
  String get copyRunId => 'Kopiraj ID zagona';

  @override
  String get copyWebhookUrl => 'Kopiraj URL webhooka';

  @override
  String get core => 'Jedro';

  @override
  String get coreMemory => 'jedrni pomnilnik';

  @override
  String get coreServicesThisServerDependsOn =>
      'Osnovne storitve, od katerih je odvisen ta strežnik.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domena https javni izvor url';

  @override
  String get couldHelp => 'Lahko pomaga';

  @override
  String get couldNotApproveQrLogin => 'Prijave QR ni bilo mogoče odobriti.';

  @override
  String get couldNotApproveQrPairing =>
      'Seznanjanja QR ni bilo mogoče odobriti.';

  @override
  String get couldNotConnect => 'Ni bilo mogoče vzpostaviti povezave.';

  @override
  String get couldNotCreateBinding => 'Ni bilo mogoče ustvariti vezave.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Vašega računa ni bilo mogoče izbrisati: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Bitwardena ni bilo mogoče prekiniti.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Domačega pomočnika ni bilo mogoče prekiniti.';

  @override
  String get couldNotDisconnectNeorecall =>
      'Povezave z NeoRecall ni bilo mogoče prekiniti.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Povezave z Nextcloudom ni bilo mogoče prekiniti.';

  @override
  String get couldNotDisconnectTrello =>
      'Povezave s Trellom ni bilo mogoče prekiniti.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Vaših podatkov ni bilo mogoče izvoziti: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Odločitev ni bilo mogoče naložiti';

  @override
  String get couldNotLoadUsageData =>
      'Podatkov o uporabi ni bilo mogoče naložiti.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Ni bilo mogoče samodejno odpreti nastavitev Linuxa.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Strani za povezovanje ponudnika ni bilo mogoče odpreti.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Strani za prijavo ponudnika ni bilo mogoče odpreti.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Sredstva za izdajo ni bilo mogoče odpreti.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Trello ni bilo mogoče odpreti v vašem brskalniku.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Prenosa datoteke delovnega prostora ni bilo mogoče odpreti.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Ni bilo mogoče prebrati paketa aplikacije za Android.';

  @override
  String get couldNotReadTheApk => 'APK-ja ni bilo mogoče prebrati.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Ni bilo mogoče odstraniti ključa: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Agenta ni bilo mogoče shraniti.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Nastavitev Bitwarden ni bilo mogoče shraniti.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Nastavitve domačega pomočnika ni bilo mogoče shraniti.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Nastavitev NeoRecall ni bilo mogoče shraniti.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nastavitev Nextcloud ni bilo mogoče shraniti.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Nastavitve Trello ni bilo mogoče shraniti.';

  @override
  String get couldNotSendConfirmationEmail =>
      'ni mogel poslati potrditvenega e-poštnega sporočila';

  @override
  String get couldNotStart => 'Ni bilo mogoče začeti';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Ustvari';

  @override
  String get createAPasswordFirstToChange =>
      'Najprej ustvarite geslo, če želite spremeniti e-pošto računa.';

  @override
  String get createAPasswordOrLinkAnother =>
      'ustvarite geslo ali povežite drugega ponudnika, preden odstranite ta način prijave';

  @override
  String get createATaskWhileThisAgent =>
      'Ustvarite nalogo, medtem ko je ta agent izbran.';

  @override
  String get createLink => 'Ustvari povezavo';

  @override
  String get createOrModifyFilesInYour =>
      'Ustvarite ali spremenite datoteke v svojem delovnem prostoru.';

  @override
  String get createPassword => 'Ustvari geslo';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Ustvarite specializirane bote z ločenim pomnilnikom, nastavitvami, orodji in dodelitvami računov.';

  @override
  String get createTheFirstAccount => 'Ustvarite prvi račun';

  @override
  String get createUpdateOrDeleteSkills =>
      'Ustvarite, posodobite ali izbrišite veščine.';

  @override
  String get creatingYourSkill => 'Ustvarjanje vaše spretnosti ...';

  @override
  String get credentialBindings => 'Poverilne vezave';

  @override
  String get credentialUse => 'Uporaba poverilnice';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Ponavljajoči se zagoni, ki temeljijo na Cronu, in enkratna časovna izvedba.';

  @override
  String get cronExpression => 'Cron izraz';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter zažene poizvedbo.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + preslednica';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Trenutni e-poštni naslov: $arg1';
  }

  @override
  String get currentPassword => 'Trenutno geslo';

  @override
  String get currentPasswordIsIncorrect => 'trenutno geslo ni pravilno';

  @override
  String get currentTwoStepLoginCode => 'Trenutna prijavna koda v dveh korakih';

  @override
  String get customAccess => 'Dostop po meri';

  @override
  String get customCron => 'Cron po meri';

  @override
  String get customCronMustHave5Fields => 'Cron po meri mora imeti 5 polj.';

  @override
  String get customEndpoint => 'končna točka po meri';

  @override
  String get customField => 'Polje po meri';

  @override
  String get customHeader => 'Glava po meri';

  @override
  String get customHeadersJson => 'Glave po meri (JSON)';

  @override
  String get customOpenaiCompatible => 'Po meri združljiv z OpenAI';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Končna točka po meri, združljiva z OpenAI';

  @override
  String get customOutgoingUrl => 'Odhodni URL po meri';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Dnevno';

  @override
  String get dailyRecap => 'Dnevni povzetek';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'poizvedba po bazi podatkov izberite predloge csv';

  @override
  String dayArg1(Object? arg1) {
    return 'Dan $arg1';
  }

  @override
  String get dayOfMonth => 'Dan v mesecu';

  @override
  String get decideWhichToolsYourAgentMay =>
      'odločite se, katera orodja lahko uporablja vaš agent. Vidijo tvoje ime in ';

  @override
  String get decisionHigherUpTheChainWins =>
      'odločitev višje v verigi zmaga in pokaže ključavnico z ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Odločitve se prikažejo tukaj, ko $arg1 bere odobrene skupine $arg2. Shrani se samo zadnjih 30 in se ponastavijo, ko se strežnik znova zažene.';
  }

  @override
  String get decline => 'Zavrni';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'globok zalet · korak $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram ključ';

  @override
  String get default2 => 'Privzeto';

  @override
  String get default3 => 'PRIVZETO';

  @override
  String defaultArg1(Object? arg1) {
    return 'Privzeto ($arg1)';
  }

  @override
  String get defaultConversation => 'Privzeti pogovor';

  @override
  String get defaultForNewGroups => 'Privzeto za nove skupine';

  @override
  String get defaultGroupParticipation => 'Privzeto sodelovanje v skupini';

  @override
  String get defaultNeoagentWorkspace => 'Privzeti delovni prostor NeoAgent';

  @override
  String get defaultOpenai => 'Privzeto (OpenAI)';

  @override
  String get defaultRateLimits => 'Privzete omejitve stopnje';

  @override
  String get defaultRateLimitsSaved =>
      'Privzete omejitve stopnje so shranjene.';

  @override
  String get defaultRecommended => 'Privzeto (priporočeno)';

  @override
  String get defaultRouting => 'Privzeto usmerjanje';

  @override
  String get defaultSpace => 'Privzeti prostor';

  @override
  String get delete => 'Izbriši';

  @override
  String get deleteAccount => 'Izbriši račun';

  @override
  String get deleteAccountPermanently => 'Želite trajno izbrisati račun?';

  @override
  String get deleteAnAccount => 'Izbriši račun';

  @override
  String deleteArg1(Object? arg1) {
    return 'Izbrisati @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Izbriši ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Želite trajno izbrisati $arg1 $arg2?';
  }

  @override
  String get deleteBinding => 'Izbriši vezavo';

  @override
  String get deleteCoreMemoryEntry =>
      'Želite izbrisati vnos v osnovni pomnilnik?';

  @override
  String get deleteForever => 'Izbriši za vedno';

  @override
  String get deleteMcpServer => 'Želite izbrisati strežnik MCP?';

  @override
  String get deleteMemory => 'Izbriši pomnilnik?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Z brisanjem trajno izbrišete račun in vse njegove podatke ';

  @override
  String get deleteRun => 'Izbrisati tek?';

  @override
  String get deleteRun2 => 'Izbriši tek';

  @override
  String get deleteSelectedMemories => 'Želite izbrisati izbrane spomine?';

  @override
  String get deleteSession => 'Želite izbrisati sejo?';

  @override
  String get deleteSkill => 'Želite izbrisati veščino?';

  @override
  String get deleteTask => 'Želite izbrisati nalogo?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Izbrisan \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Izbrisan @$arg1 in vsi njegovi podatki.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Brisanje odstrani vse vaše pogovore, spomine, datoteke, opravila in ';

  @override
  String get deliverableArtifactProduced =>
      'Izdelan artefakt, ki ga je mogoče dostaviti';

  @override
  String get deliverableCompleted => 'Dobava končana';

  @override
  String get deliverableExecutionStarted => 'Začela se je dobavljiva izvedba';

  @override
  String get deliverableSelected => 'Dobavljivo izbrano';

  @override
  String get deliverableValidationFailed =>
      'Preverjanje dobavljivosti ni uspelo';

  @override
  String get deliverableValidationStarted =>
      'Začelo se je preverjanje dobavljivosti';

  @override
  String get deny => 'Zavrni';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Opišite rezultat in ga nato pokažite na namizju';

  @override
  String get describeWhatToBuildOrChange =>
      'Opišite, kaj zgraditi ali spremeniti ...';

  @override
  String get description => 'Opis';

  @override
  String get desktopApp => 'Namizna aplikacija';

  @override
  String get desktopAppControlsAvailable =>
      'Na voljo so kontrolniki namiznih aplikacij';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Zajem namizja ni na voljo na tej platformi.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Nalaganje izhodnih ukazov namizja je preklicano.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Ukaz spremljevalca namizja je bil preklican.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Povezava spremljevalca namizja je potekla.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Rokovanje spremljevalca namizja je poteklo.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Desktop companion tukaj ni na voljo.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Desktop companion je lokalno zaustavljen.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Obravnava spremljevalnega sporočila namizja ni uspela: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Nastavitve dovoljenj za spremljevalce namizja v spletu niso na voljo.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Nastavitve dovoljenj za spremljevalce namizja na tej platformi niso na voljo.';

  @override
  String get desktopCompanionRejected => 'Desktop companion zavrnjen.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Odgovor spremljevalca namizja ni uspel: $arg1';
  }

  @override
  String get desktopControl => 'Nadzor namizja';

  @override
  String get desktopFailedToStart => 'Namizja ni bilo mogoče zagnati';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Zajem toka namizja ni uspel: $arg1';
  }

  @override
  String get destinationId => 'ID cilja';

  @override
  String get deviceAccess => 'Dostop do naprave';

  @override
  String get deviceSettings => 'Nastavitve naprave';

  @override
  String get devices => 'Naprave';

  @override
  String get diagnosticsSaved => 'Diagnostika shranjena.';

  @override
  String get directBluebubblesImessageBridge =>
      'Neposredni most BlueBubbles iMessage';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Neposredna sporočila ostanejo odzivna. Skupine na seznamu dovoljenih uporabljajo spodnji način sodelovanja.';

  @override
  String get directoryDoesNotExist => 'Imenik ne obstaja.';

  @override
  String get disable2fa => 'Onemogoči 2FA';

  @override
  String get disableAll => 'Onemogoči vse';

  @override
  String get discard => 'Zavrzi';

  @override
  String get disconnect => 'Prekini povezavo';

  @override
  String get disconnectHomeAssistant =>
      'Prekiniti povezavo z domačim pomočnikom?';

  @override
  String get disconnectNeorecall => 'Prekiniti povezavo z NeoRecall?';

  @override
  String get disconnectNextcloud => 'Prekiniti povezavo z Nextcloudom?';

  @override
  String get disconnectPlatform => 'Odklopite platformo';

  @override
  String get disconnectTrello => 'Prekiniti povezavo s Trellom?';

  @override
  String get discoveryFailed => 'Odkritje ni uspelo';

  @override
  String get dismiss => 'Odpusti';

  @override
  String get displayIdIsRequired => 'Potreben je prikazni ID.';

  @override
  String get displayName => 'Prikazno ime';

  @override
  String get displayNameMustBe64Characters =>
      'Prikazno ime mora imeti 64 znakov ali manj.';

  @override
  String get displayNameSaved => 'Prikazno ime je shranjeno.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Ne vključujte svojega uporabniškega imena ali e-pošte.';

  @override
  String get done => 'Končano';

  @override
  String get downloadACopyOfYourData =>
      'Prenesite kopijo svojih podatkov. Skrbniških računov ni mogoče izbrisati ';

  @override
  String get downloadACopyOfYourData2 =>
      'Prenesite kopijo svojih podatkov ali trajno izbrišite svoj račun. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Prenesite $arg1';
  }

  @override
  String get downloadUpdate => 'Prenesite posodobitev';

  @override
  String get downloadingTheNeoagentBackend => 'Prenašanje zaledja NeoAgent';

  @override
  String get draft => 'Osnutek';

  @override
  String get dragIsNotSupportedOnThis =>
      'vlečenje ni podprto na tej platformi.';

  @override
  String get draggedOnTheScreen => 'Povlecite po zaslonu';

  @override
  String get dropAnApkOrApkBundle =>
      'Sem spustite APK ali paket APK, da ga namestite';

  @override
  String get dropApkOrApksHere => 'Spustite APK ali .apks sem';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Trajna navodila za glas in slog interakcije. Še vedno imajo prednost varnostna in izvedbena pravila.';

  @override
  String get eGAlexSLaptop => 'npr. Alexov prenosnik';

  @override
  String get eGMyLocalServer => 'npr. Moj lokalni strežnik';

  @override
  String get edit => 'Uredi';

  @override
  String get editAgent => 'Uredi agenta';

  @override
  String get editCoreMemoryEntry => 'Uredi vnos jedrnega pomnilnika';

  @override
  String get editInstructions => 'Uredi navodila';

  @override
  String get editMcpServer => 'Uredite strežnik MCP';

  @override
  String get editTask => 'Uredi nalogo';

  @override
  String editedArg1(Object? arg1) {
    return 'Urejeno $arg1';
  }

  @override
  String get email => 'E-pošta';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Lastnikom računov po e-pošti o prijavah, ki so videti nenavadne.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Pošljite e-poštno sporočilo lastnikom računov, ko se spremenijo podrobnosti o njihovem računu.';

  @override
  String get emailCode => 'E-poštna koda';

  @override
  String get emailConfirmationRequired => 'potrebna potrditev e-pošte';

  @override
  String get emailIsAlreadyInUse => 'e-pošta je že v uporabi';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-pošta shranjena. Če je potrebna potrditev, preverite novi naslov za potrditveno povezavo NeoAgent.';

  @override
  String get emailSettingsSaved => 'E-poštne nastavitve so shranjene.';

  @override
  String get emailUnverified => 'E-pošta nepreverjena';

  @override
  String get empty => 'prazno';

  @override
  String get emptyFile => 'Prazna datoteka';

  @override
  String get emptyFolder => 'Prazna mapa';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Empty uporablja privzeto vrednost strežnika ($arg1).';
  }

  @override
  String get enable2fa => 'Omogoči 2FA';

  @override
  String get enableAll => 'Omogoči vse';

  @override
  String get enableBehaviorModules => 'Omogoči vedenjske module';

  @override
  String get enableOrDisableModels => 'Omogoči ali onemogoči modele';

  @override
  String get enabled => 'Omogočeno';

  @override
  String get encryptedPrivateToYourAccount => 'Šifrirano, zasebno za vaš račun';

  @override
  String get end => 'Konec';

  @override
  String get endCall => 'Končaj klic';

  @override
  String get endVoiceCall => 'Končati glasovni klic?';

  @override
  String get endpoint => 'Končna točka';

  @override
  String get enterAPassword => 'Vnesite geslo.';

  @override
  String get enterAUsername => 'Vnesite uporabniško ime.';

  @override
  String get enterAValidEmailAddress => 'Vnesite veljaven e-poštni naslov.';

  @override
  String get enterAnAddressManually => 'Ročno vnesite naslov';

  @override
  String get enterAnApiKeyFirst => 'Najprej vnesite ključ API.';

  @override
  String get enterInviteLink => 'Vnesite povezavo za povabilo';

  @override
  String get enterTheAddressOfANeoagent => 'Vnesite naslov strežnika NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Vnesite podrobnosti, ki vam jih je dal $arg1, da bo lahko $arg2 pošiljal in prejemal sporočila.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Vnesite svojo 2FA ali obnovitveno kodo.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Vnesite trenutno geslo, da ga spremenite.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Vnesite trenutno geslo, da shranite spremembe e-pošte.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Vnesite podatke o svojem računu NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Vnesite svoje uporabniško ime ali e-poštni naslov računa. NeoAgent bo poslal povezavo za ponastavitev, če se lahko ujema z računom.';

  @override
  String get enterYourUsernameOrEmail =>
      'Vnesite svoje uporabniško ime ali e-pošto.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entiteta: $arg1';
  }

  @override
  String get environment => 'okolje';

  @override
  String get error => 'Napaka';

  @override
  String errorArg1(Object? arg1) {
    return '\nnapaka: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Napake iz nedavnega dnevnika, razvrščene po sporočilih.';

  @override
  String get errorsProblemsFailures => 'napake težave napake';

  @override
  String get eventTypesCommaSeparated => 'Vrste dogodkov (ločeno z vejicami)';

  @override
  String get every15Minutes => 'Vsakih 15 minut';

  @override
  String get every30Minutes => 'Vsakih 30 minut';

  @override
  String get everyAccountOnThisServerLoses =>
      'Vsak račun na tem strežniku izgubi ta skupni ključ. Računi ';

  @override
  String get everyAccountOnThisServerUses =>
      'Vsak račun na tem strežniku uporablja ta naslov za ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Vsaka aktivna seja za ta račun se konča. Lahko se prijavijo ';

  @override
  String get everyDay0800 => 'Vsak dan · 08:00';

  @override
  String get everyDay2000 => 'Vsak dan · 20:00';

  @override
  String get everyHour => 'Vsako uro';

  @override
  String get everyRunOnThisServerAll => 'Vsak zagon na tem strežniku, ves čas.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Vsako občutljivo orodje vedno zahteva odobritev.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Vsako orodje deluje brez vprašanja, razen tistega, ki je oseba ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Vsi v teh skupinah, kanalih ali sobah se lahko pogovarjajo z $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Vsi v tej skupini';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Vse, kar je $arg1 izklopil za vašega agenta, pride ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Vse ostalo je izklopljeno.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Vse je na voljo z namizja.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Vse, kar agent lahko uporabi: uradne integracije, strežnike MCP in veščine.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Vse, kar ste izklopili za $arg1, se vrne ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Natančen spletni izvor je dovoljen za navzkrižne zahteve, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Izvedite JavaScript znotraj seje brskalnika.';

  @override
  String get execution => 'Izvedba';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Podrobnosti o izvedbi za ta zagon niso na voljo.';

  @override
  String get executionPlanCreated => 'Izvedbeni načrt izdelan.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Seje vadbe $arg1';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[izhod $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Poteče $arg1';
  }

  @override
  String get explainThisProject => 'Razloži ta projekt';

  @override
  String exploredArg1(Object? arg1) {
    return 'Raziskano $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Raziskano $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Raziskoval delovni prostor';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Izvoz ni uspel: $arg1';
  }

  @override
  String get exportLast5Messages => 'Izvozi zadnjih 5 sporočil';

  @override
  String get exportMyData => 'Izvozi moje podatke';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Zagon zunanjega brskalnika ni uspel z izhodno kodo $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Zagon zunanjega brskalnika na tej platformi ni podprt.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Časovna omejitev zagona zunanjega brskalnika je potekla.';

  @override
  String get externalMcpTools => 'Zunanja in MCP orodja';

  @override
  String get extraButtons => 'Dodatni gumbi';

  @override
  String get extractingTheNeoagentRuntime =>
      'Ekstrahiranje izvajalnega okolja NeoAgent';

  @override
  String get failed => 'Ni uspelo';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Povezava ni uspela: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Povezava $arg1: $arg2 ni uspela';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Brisanje \"$arg1\" ni uspelo: $arg2';
  }

  @override
  String get failedToFetch => 'ni uspelo pridobiti';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Ustvarjanje poziva ni uspelo: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Zagon zunanjega brskalnika prek url_launcherja ni uspel.';

  @override
  String get failedToLaunchOauthFlow => 'Zagon toka OAuth ni uspel.';

  @override
  String get failedToLoadPolicies => 'Nalaganje pravilnikov ni uspelo';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Shranjevanje ni uspelo: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Strežnika MCP ni bilo mogoče shraniti.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Izbire ni bilo mogoče shraniti: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Pošiljanje obvestila v zaledje ni uspelo: $arg1';
  }

  @override
  String get fair => 'pošteno';

  @override
  String get fasterReplies => 'Hitrejši odgovori';

  @override
  String get fewerModelCalls => 'Manj klicev modelov';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'prazno polje za obnovitev vgrajene privzete vrednosti.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Datoteka presega omejitev urejevalnika 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Datoteka presega podprto omejitev velikosti.';

  @override
  String get fileWrites => 'Datoteka piše';

  @override
  String get filename => 'Ime datoteke';

  @override
  String get files => 'Datoteke';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Datoteke, ki jih NeoAgent piše ali ureja v tej seji, so prikazane tukaj.';

  @override
  String get filesSavedByAllUsers =>
      'Datoteke, ki so jih shranili vsi uporabniki';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Izpolnite odobrene prijave ali preverite zahteve, ne da bi umetni inteligenci pokazali skrivnosti.';

  @override
  String get finalResponse => 'Končni odgovor';

  @override
  String get findAPlatform => 'Poiščite platformo';

  @override
  String get findAndFixABug => 'Poiščite in popravite napako';

  @override
  String get findRecentChats => 'Poiščite nedavne klepete';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Iskanje pravilnega izvajalnega okolja NeoAgent';

  @override
  String get finish => 'Končaj';

  @override
  String get finishAtTheScheduledTime => 'Končajte ob predvidenem času';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Dokončajte prijavo v $arg1 v brskalniku in se znova povežite.';
  }

  @override
  String get flowGraph => 'Graf poteka';

  @override
  String get flutterApp => 'Aplikacija Flutter';

  @override
  String get focusedExecutionProfile => 'Osredotočen profil izvajanja';

  @override
  String get folderIdOptional => 'ID mape (neobvezno)';

  @override
  String get folderUnavailable => 'Mapa ni na voljo';

  @override
  String get forExampleHttpsMatrixOrg => 'Na primer https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Za gostujoče ali napredne nastavitve omrežja';

  @override
  String get forLinksInEmailsBlankUses =>
      'Za povezave v elektronski pošti. Prazno uporablja javni URL strežnika.';

  @override
  String get forgotPassword => 'Ste pozabili geslo?';

  @override
  String get frameUnavailable => 'Okvir ni na voljo';

  @override
  String freshnessArg1(Object? arg1) {
    return 'svežina: $arg1';
  }

  @override
  String get fridays1700 => 'Petki · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Od BotFather, potem ko ustvarite bota.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Od zdaj naprej se $arg1 odloči, katera orodja lahko uporablja vaš agent. Oni ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Na portalu za razvijalce Discord, pod vašim botom.';

  @override
  String get fromTheLineDevelopersConsole =>
      'Iz konzole LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot => 'Iz odjemalca Matrix ali računa bota.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Na twitchapps.com/tmi ali v aplikaciji za razvijalce Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Celoten poziv';

  @override
  String get fullSetup => 'Popolna nastavitev';

  @override
  String get general => 'Splošno';

  @override
  String get generalSettings => 'Splošne nastavitve';

  @override
  String get generalSettingsSaved => 'Splošne nastavitve so shranjene.';

  @override
  String get generateAPromptForAnotherAi =>
      'Ustvarite poziv za drug AI, prilepite odgovor sem za uvoz spominov.';

  @override
  String get generatePrompt => 'Ustvari poziv';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Napaka pri sledenju Geofence: $arg1';
  }

  @override
  String get getInspired => 'Poiščite navdih';

  @override
  String get githubCopilot => 'GitHub kopilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot in OpenAI Codex';

  @override
  String get githubIssueOpened => 'Težava GitHub je odprta';

  @override
  String get neorecallMemoryCreated => 'NeoRecall Memory ustvarjen';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Preverjanje izdaje GitHub ni uspelo s HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Tovor izdaje GitHub ni bil seznam izdaj.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Uporabniško ime GitHub, ki je odprlo težavo';

  @override
  String get globalSecurityMode => 'Globalni varnostni način';

  @override
  String get gmailMessageReceived => 'Prejeto sporočilo Gmail';

  @override
  String get good => 'Dobro';

  @override
  String get goodAfternoon => 'dober dan';

  @override
  String get goodEvening => 'dober večer';

  @override
  String get goodMorning => 'dobro jutro';

  @override
  String get goodPasswordALittleMoreLength =>
      'Dobro geslo. Nekoliko večja dolžina ga naredi močnejšega.';

  @override
  String get googleChat => 'Google Klepet';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live uporablja vaš ključ OpenAI API, Gemini Live vaš ključ Google AI. Spremembe veljajo za naslednji klic.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Pred sinhronizacijo dodelite dovoljenja Health Connect.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Skupina, kanal ali soba';

  @override
  String get groupType => 'Vrsta skupine';

  @override
  String get groupsAndChannels => 'Skupine in kanali';

  @override
  String groupsArg1(Object? arg1) {
    return 'Skupine: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Temu bodo sledile skupine, ki jih $arg1 še ni videl.';
  }

  @override
  String get handlesDirectTasksItself => 'Sam opravlja neposredne naloge';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Prostoročno (prosto govorite, prekinite kadar koli)';

  @override
  String get headerName => 'Ime glave';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Naslovi o temah, ki vas zanimajo, filtrirani glede na signal.';

  @override
  String get health => 'zdravje';

  @override
  String get healthChecks => 'Zdravstveni pregledi';

  @override
  String get healthConnect => 'zdravstvena povezava';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect ni na voljo v tej napravi.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Status sinhronizacije Health Connect in shranjene zaledne meritve.';

  @override
  String get healthStatusIsUnavailable => 'Zdravstveno stanje ni na voljo.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Sinhronizacija zdravja je na voljo samo v sistemu Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Srčni zapisi $arg1';
  }

  @override
  String get heldBack => 'Zadržano';

  @override
  String get helper => 'Pomočnik';

  @override
  String helperArg1(Object? arg1) {
    return 'Pomočnik: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'tukaj Najprej prekličite skrbnika z `neoagent admin revoke $arg1`.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Zaradi višjih vrednosti je NeoAgent bolj selektiven v skupinah.';

  @override
  String get highlyRecommended => 'Zelo priporočljivo';

  @override
  String get holdButton131ForTheAssistant => 'Držite gumb 131 za pomočnika.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Za pogovor držite Ctrl+Shift+preslednico';

  @override
  String get holdToTalk => 'Drži za pogovor.';

  @override
  String get holdToTalk2 => 'Drži za pogovor';

  @override
  String get home => 'domov';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Potreben je žeton za dolgotrajni dostop Home Assistant.';

  @override
  String get homeAssistantSetup => 'Nastavitev domačega pomočnika';

  @override
  String get homeAssistantUrl => 'Domači pomočnik URL';

  @override
  String get homeAssistantUrlIsRequired =>
      'Potreben je URL domačega pomočnika.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Žeton domačega strežnika z anketiranjem sobe';

  @override
  String get homeserverUrl => 'URL domačega strežnika';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'gostujoča storitev). Vaši ključi so šifrirani in jih lahko uporablja samo ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Ime gostitelja omrežja IRC, na primer irc.libera.chat';

  @override
  String get hourly => 'Vsako uro';

  @override
  String get hourlyInboxCheck => 'Vsako uro preverjanje e-poštnega predala';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Kako dolgo ostanejo potrditvene povezave veljavne.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Kako pogosto ta agent išče sporočila o novih sobah.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Kako pogosto ta agent išče nova sporočila Signal.';

  @override
  String get howTeamsWork => 'Kako delujejo ekipe';

  @override
  String get howThisServerIsReachedPlus =>
      'Kako se doseže ta strežnik in stikala na celotnem strežniku.';

  @override
  String get httpsSessionCookie => 'https sejni piškotek';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Te zahteve trenutno ne morem dokončati. Poskusite znova čez trenutek.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'nedejaven';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Če $arg1 zahteva URL webhook, ga prilepite, da lahko sporočila dosežejo $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Če ima ta račun potrjen e-poštni naslov, bo NeoAgent poslal povezavo za ponastavitev gesla.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Če storitev zahteva žeton za odhodne zahteve.';

  @override
  String get ignoreGroups => 'Ignoriraj skupine';

  @override
  String get ignoreThisChat => 'Prezri ta klepet';

  @override
  String get ignoredChannels => 'Prezrti kanali';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Prezrto napačno oblikovano spremljevalno sporočilo namizja: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Izvedite zgornji načrt.';

  @override
  String get implementThisPlan => 'Izvedite ta načrt';

  @override
  String get implicitTls => 'Implicitni TLS';

  @override
  String get import => 'Uvozi';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Uvoz ni uspel: $arg1';
  }

  @override
  String get importFromComputer => 'Uvoz iz računalnika';

  @override
  String get importMemoryTransfer => 'Uvoz prenosa pomnilnika?';

  @override
  String get importance => 'Pomembnost';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Uvoženi pomnilniki $arg1, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'V ekipi @$arg1';
  }

  @override
  String get inBackground => 'ozadje';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Tukaj bodo prikazana dohodna in odhodna sporočila kanala.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Dohodni glasovni klici iz aplikacije NeoAgent';

  @override
  String get incomingMessages => 'Dohodna sporočila';

  @override
  String get incomingNeoagentCall => 'Dohodni klic NeoAgent';

  @override
  String get incomingNeoagentCall2 => 'DOHODNI KLIC NEOAGENTA';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Podpora za dohodni webhook in odhodni povratni klic';

  @override
  String get incorporatingSteering => 'Vključuje krmiljenje';

  @override
  String get input => 'Vnos';

  @override
  String get inputMode => 'Način vnosa';

  @override
  String get insertATemplate => 'Vstavite predlogo';

  @override
  String get install => 'Namestite';

  @override
  String get installASignedSelfContainedRuntime =>
      'Namestite podpisano, samostojno izvajalno okolje. Ukazi Node.js, npm, Git in terminal niso potrebni.';

  @override
  String get installApk => 'Namestite APK';

  @override
  String get installApkBundle => 'Namestite APK/Bundle';

  @override
  String get installApkClickOrDropA =>
      'Namestite APK – kliknite ali spustite datoteko .apk';

  @override
  String get installNeoagent => 'Namestite NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Namestite NeoAgent na ta računalnik brez terminala ali se povežite s tistim, ki že deluje.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Namestite nove izdaje in izberite, kateremu kanalu sledi ta strežnik.';

  @override
  String get installTheBackend => 'Namestite zaledje';

  @override
  String get installTheCoreWithExtraOptional =>
      'Namestite jedro z dodatno izbirno nastavitvijo. Ključi ponudnika AI so dodani naknadno, enako kot Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Namestite varno jedro in nato ustvarite svoj račun. Nato dodajte ključe ponudnika AI.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Nameščeno: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Nameščeno: $arg1 • Nazadnje preverjeno: $arg2';
  }

  @override
  String get instructions => 'Navodila';

  @override
  String get integration => 'Integracija';

  @override
  String get integrationConnections => 'Integracijske povezave';

  @override
  String get integrationSettingsSaved => 'Nastavitve integracije so shranjene.';

  @override
  String get integrations => 'Integracije';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integracij/oauth/callback in registrirajte isto ';

  @override
  String get interruptAi => 'Prekinite AI';

  @override
  String get invalid2fa => 'neveljavna 2fa';

  @override
  String get invalidArgumentS => 'Neveljavni argumenti: ';

  @override
  String get invalidCredentials => 'neveljavne poverilnice';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Neveljaven manifest izvajalnega okolja NeoAgent.';

  @override
  String get inviteLink => 'Povezava s povabilom';

  @override
  String get inviteLinkReady => 'Povezava s povabilom je pripravljena';

  @override
  String get inviteLinks => 'Povezave za povabilo';

  @override
  String get iphoneApp => 'aplikacija za iPhone';

  @override
  String get issues => 'Težave';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Težave se pojavijo, ko se dnevnik naloži.';

  @override
  String get itCanTBeUndone => 'Ni ga mogoče razveljaviti.';

  @override
  String get itMayHaveBeenDeleted => 'Morda je bil izbrisan.';

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
    return 'Pridružil se $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Pridružil se v zadnjih 7 dneh';

  @override
  String get joiningATeam => 'Pridružitev ekipi';

  @override
  String get joiningIsOffHere => 'Pridruževanje je tukaj izklopljeno';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Polje JSON, ki vsebuje besedilo sporočila. Običajno besedilo.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Polje JSON, ki določa, komu je sporočilo namenjeno.';

  @override
  String get jumpToLatest => 'Skoči na najnovejšo';

  @override
  String get justNow => 'ravno zdaj';

  @override
  String get keepNeoagentRunning => 'Naj NeoAgent še naprej deluje?';

  @override
  String get keepRunning => 'Teci naprej';

  @override
  String get keepTaskRunning => 'Opravilo naj teče';

  @override
  String get keepTheVaultAvailable => 'Naj bo trezor na voljo';

  @override
  String get keepThisLauncherUpToDate => 'Posodabljajte ta zaganjalnik.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'To ploščo pustite odprto, dokler platforma ne potrdi povezave.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Naj bo računalnik te seje viden';

  @override
  String get keepTrackOfYourAiUsage =>
      'Spremljajte svojo uporabo AI. Omejitve so uveljavljene, da se zagotovi poštena uporaba na celotni platformi.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Še naprej normalno uporabljajte svoje aplikacije. NeoAgent deluje na istem zaslonu in vpraša, ko potrebuje nov dostop.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Ohranjanje povezave s to napravo';

  @override
  String get key => 'Ključ';

  @override
  String get keyIsRequired => 'Potreben je ključ.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Pari ključ-vrednost, ki se ohranijo med pogovori.';

  @override
  String get knowledgeGraph => 'Graf znanja';

  @override
  String get knowledgeView => 'Pogled znanja';

  @override
  String get labelOnlyYouSeeIt => 'Oznaka (vidite jo samo vi)';

  @override
  String get labelsOptional => 'Oznake (neobvezno)';

  @override
  String get last24Hours => 'Zadnjih 24 ur';

  @override
  String get last7Days => 'Zadnjih 7 dni';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Zadnjih 7 dni: žetoni $arg1 v tekih $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Zadnji $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Zadnji: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Zadnja neprazna sinhronizacija · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Zadnja vožnja: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Nazadnje viden $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Zadnja prijava $arg1';
  }

  @override
  String get lastSyncSummary => 'Povzetek zadnje sinhronizacije';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Nazadnje uporabljeno: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Zadnje okno se je končalo $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'kasnejši zagon tudi izklopljen.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Zadnja serija · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Zagon namiznih aplikacij na tej platformi ni podprt.';

  @override
  String get learnRoomNorms => 'Naučite se sobnih norm';

  @override
  String get leave => 'Pusti';

  @override
  String get leaveARedirectUriBlankTo =>
      'Pustite URI preusmeritve prazen, če želite uporabiti <javni URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Zapustiti ekipo $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Pustite kot privzeto, razen če ste prilagodili BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Pustite žeton prazen, da obdržite trenutno shranjeni žeton.';

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
    return 'Naj me upravlja $arg1';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Naj se vsi v tej skupini pogovarjajo z $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Naj deluje,\nmedtem ko ti ne.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Naj NeoAgent klikne, tipka in se premika po vaših aplikacijah.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Naj NeoAgent razume, kaj je vidno na vašem zaslonu.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Naj nekdo, s katerim sodelujete, odloči, katera orodja lahko vaš agent ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Naj ta oseba pošlje $arg1 sporočilo ena na ena.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Naj ta oseba govori z $arg1 tukaj, vendar ne v zasebnih klepetih ali drugih skupinah.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Naj ta oseba govori z $arg1 v zasebnih klepetih in v kateri koli skupini, ki jo deli.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Stopnja $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Povezava $arg1';
  }

  @override
  String get linkCopied => 'Povezava je kopirana';

  @override
  String get linkExpiresAfter => 'Povezava poteče po';

  @override
  String get linkLifetimeHours => 'Življenjska doba povezave (ure)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Življenjska doba povezave mora biti od 1 do 8760 ur.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Povezava velja do $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Povezani ponudniki prijav';

  @override
  String get linuxApp => 'Aplikacija za Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Na seznamu $arg1/';
  }

  @override
  String get listening => 'Poslušanje';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Zgodovina izvajanja v živo, koraki orodja in odzivi.';

  @override
  String get liveModel => 'Model v živo';

  @override
  String get liveModelProvider => 'Ponudnik modelov v živo';

  @override
  String get liveRun => 'Tek v živo';

  @override
  String get liveVoice => 'Glas v živo';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Glasovna povezava v živo ni na voljo.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Glasovna povezava v živo je bila prekinjena.';

  @override
  String get liveVoiceDefaults => 'Privzete nastavitve glasu v živo';

  @override
  String get liveVoiceFailed => 'Glas v živo ni uspel.';

  @override
  String get llmMemoryExportResponse => 'Odgovor na izvoz pomnilnika LLM';

  @override
  String get loadFailed => 'nalaganje ni uspelo';

  @override
  String get loadingExecutionDetails => 'Nalaganje podrobnosti o izvedbi ...';

  @override
  String get loadingNeoagent => 'Nalaganje NeoAgenta';

  @override
  String get loadingRunFlow => 'Nalaganje poteka ...';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Lokalni in zasebni omrežni URL-ji so podprti, ko jih lahko doseže strežnik NeoAgent. Avdio ni nikoli izpostavljen NeoAgentu.';

  @override
  String get localApp => 'lokalna aplikacija';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Lokalna zaledna namestitev ni na voljo na tej platformi.';

  @override
  String get localBaseImagePath => 'Pot lokalne osnovne slike';

  @override
  String get localComputerControlIsAvailableIn =>
      'Nadzor lokalnega računalnika je na voljo v namizni aplikaciji NeoAgent v sistemih macOS, Windows in Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Lokalni računalniški nadzor tukaj ni na voljo.';

  @override
  String get localModelsUrl => 'lokalni modeli url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Lokalno odkrivanje NeoAgent začasno ni na voljo.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Lokalne nastavitve za aplikacijo NeoAgent. Nadzor računalnika vedno poteka prek enotnega računalnika v oblaku.';

  @override
  String get localSetup => 'LOKALNA NASTAVITEV';

  @override
  String get locationCityOrPlace => 'Lokacija (mesto ali kraj)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Lokacija je potrebna za sprožilce vremenskih dogodkov';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Inicializacija LocationService ni uspela: $arg1';
  }

  @override
  String get logCopied => 'Dnevnik je kopiran';

  @override
  String get loginPassword => 'Geslo za prijavo';

  @override
  String get logout => 'Odjava';

  @override
  String get logs => 'Dnevniki';

  @override
  String get logsCopied => 'Dnevniki kopirani.';

  @override
  String get logsOnThisComputer => 'Dnevniki v tem računalniku';

  @override
  String get longLivedAccessToken => 'Dolgoživ dostopni žeton';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Dolgoročni priklic, strukturirana dejstva in graf znanja.';

  @override
  String get lookedAtTheScreen => 'Pogledal na zaslon';

  @override
  String get lookingOnThisComputerAndYour =>
      'Gledam ta računalnik in vaše lokalno omrežje ...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Čaka na jutrišnje sestanke, da vas nič ne preseneti.';

  @override
  String get loopExecution => 'Izvedba zanke';

  @override
  String get loopPaused => 'Zanka zaustavljena';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'Dostopnost macOS ni odobrena NeoAgentu. Dovolite v sistemskih nastavitvah › Zasebnost in varnost › Dostopnost.';

  @override
  String get macosApp => 'aplikacija za macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'Snemanje zaslona macOS ni odobreno NeoAgentu. Dovolite v sistemskih nastavitvah › Zasebnost in varnost › Snemanje zaslona, ​​nato znova odprite NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Poštni strežniki, ki potrebujejo geslo, bodo zavrnili pošiljanje do novega ';

  @override
  String get main => 'Glavni';

  @override
  String get makeDefault => 'Naj bo privzeto';

  @override
  String get manage => 'Upravljaj';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Upravljajte e-pošto svojega računa, dvostopenjsko avtentikacijo in aktivne seje.';

  @override
  String get managedBy => 'Upravljavec';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Vodje imajo lahko svoje upravitelje (do štiri ravni). A ';

  @override
  String get managing => 'Upravljanje';

  @override
  String get manualDestination => 'Ročni cilj';

  @override
  String get manualTrigger => 'Ročni sprožilec';

  @override
  String get masterPassword => 'Glavno geslo';

  @override
  String get matchThisDevice => 'Ujemanje s to napravo';

  @override
  String get matchedAgainstTitleAndBody => 'Ujemanje z naslovom in telesom';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Ujema se s starim načinom toka NeoAgent MCP: URL plus auth.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP strežnik';

  @override
  String get mcpServer2 => 'MCP strežnik';

  @override
  String get mcpServerUrl => 'URL strežnika MCP';

  @override
  String get mcpServers => 'MCP strežniki';

  @override
  String get meantForSomeoneElse => 'Namenjeno nekomu drugemu';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Izmerjena cena modela: $arg1';
  }

  @override
  String get memories => 'Spomini';

  @override
  String get memory => 'Spomin';

  @override
  String memoryArg1(Object? arg1) {
    return 'Pomnilnik: $arg1';
  }

  @override
  String get memoryInjected => 'Pomnilnik vstavljen';

  @override
  String get mentionOrReplyOnly => 'Samo omemba ali odgovor';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Združeni dnevniki strežnika in izvajalnega okolja Flutter za to sejo aplikacije.';

  @override
  String get messageBodyTemplateJson => 'Predloga telesa sporočila (JSON)';

  @override
  String get messageNeedsAccess => 'Sporočilo potrebuje dostop';

  @override
  String get messageTextField => 'Besedilno polje sporočila';

  @override
  String get messaging => 'Sporočila';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Potisni API za sporočila in dogodki webhook';

  @override
  String get messagingConnectionNeedsAttention =>
      'Povezava s sporočili zahteva pozornost';

  @override
  String get messagingConnections => 'Povezave za sporočila';

  @override
  String get messagingDelivery => 'Dostava sporočil';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Napaka pri sporočanju. prosim poskusite ponovno';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Zajem mikrofona se je nepričakovano ustavil. Poskusite znova.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Napaka mikrofona: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofon izklopljen. Tapnite za vklop zvoka.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Za glas v živo je potrebno dovoljenje za mikrofon.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Najmanjša vrednost prispevka: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Mobilna nastavitev ni uspela.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Mobilna namestitev ni uspela, ker Java ni na voljo na računalniku, v katerem se izvaja NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Mobilna namestitev ni uspela, ker Java ni na voljo na računalniku, v katerem se izvaja NeoAgent. Namestite JDK in poskusite znova.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Mobilna nastavitev ni uspela. Preverite, ali je orodje Android pravilno nameščeno, in poskusite znova.';

  @override
  String modeArg1(Object? arg1) {
    return 'način: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Način se zaklene, medtem ko je tek aktiven.';

  @override
  String get model => 'Model';

  @override
  String modelArg1(Object? arg1) {
    return 'Model: $arg1';
  }

  @override
  String get modelAvailability => 'Razpoložljivost modela';

  @override
  String get modelAvailabilitySaved => 'Razpoložljivost modela je shranjena.';

  @override
  String get modelForThisSession => 'Model za to sejo';

  @override
  String get modelOverride => 'Preglasitev modela';

  @override
  String get modelPending => 'Model v teku';

  @override
  String get modelTurn => 'Obrat modela';

  @override
  String get modelTurnCompleted => 'Obrat modela je končan';

  @override
  String get modelTurnStarted => 'Začel se je obrat modela';

  @override
  String get modelVisibilityHideShowList =>
      'vidnost modela skrij pokaži seznam';

  @override
  String get models => 'Modeli';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modeli, vedenje, glas in delovni prostor';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modeli, brskalnik, glas, diagnostika ...';

  @override
  String get modelsRouting => 'Modeli in usmerjanje';

  @override
  String get monthly => 'Mesečno';

  @override
  String get moreActions => 'Več dejanj';

  @override
  String get morningBriefing => 'Jutranji brifing';

  @override
  String get mostUsedAgents => 'Najbolj uporabljena sredstva';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Najbolj uporabljeni modeli v zadnjem $arg1.';
  }

  @override
  String get mouseKeyboard => 'Miška in tipkovnica';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove ni podprt na tej platformi.';

  @override
  String get mustBeReachableOnThePublic =>
      'Biti mora dosegljiv na javnem internetu -- lokalnem in ';

  @override
  String get n24Hours => '24 ur';

  @override
  String get n2faOrRecoveryCode => '2FA ali kodo za obnovitev';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA zahteva, da je SESSION_SECRET konfiguriran v tej uvedbi NeoAgent.';

  @override
  String get n30Days => '30 dni';

  @override
  String get n365Days => '365 dni';

  @override
  String get n4HourLimitTokens => '4-urna omejitev (žetoni)';

  @override
  String get n4HourUsage => '4-urna uporaba';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4-urna omejitev $arg1';
  }

  @override
  String get n7DayUsage => '7-dnevna uporaba';

  @override
  String get n7Days => '7 dni';

  @override
  String get n90Days => '90 dni';

  @override
  String get name => 'Ime';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nime: Nova spretnost\nopis: Opišite, kaj počne ta veščina\n---\nTukaj napišite navodila za to veščino.\n';

  @override
  String get nameOfWhoeverMadeIt => 'ime tistega, ki ga je naredil.';

  @override
  String get nameOptional => 'Ime (neobvezno)';

  @override
  String get nativeAndWebhookChannels => 'Izvorni in webhook kanali';

  @override
  String get naturalBubbles => 'Naravni mehurčki';

  @override
  String get nearbyNeoagentServers => 'Strežniki NeoAgent v bližini';

  @override
  String get needANewAccountRegister =>
      'Potrebujete nov račun? Registrirajte se';

  @override
  String get needAnIdea => 'Potrebujete idejo?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Moram odgovoriti · $arg1% govoriti';
  }

  @override
  String get needsAttention => 'Potrebuje pozornost';

  @override
  String get needsInput => 'Potrebuje vnos';

  @override
  String get neoagentApp => 'Aplikacija NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent pomočnik';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent ni mogel preveriti razpoložljivega zalednega izvajalnega časa.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent ni mogel dokončati lokalne nastavitve.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent ni mogel dokončati lokalne nastavitve. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Informacije o odpravljanju napak NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent namesti najnovejši $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning => 'NeoAgent je nameščen in deluje.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent ni nameščen na tem računalniku.';

  @override
  String get neoagentIsReady => 'NeoAgent je pripravljen';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent še vedno dela na nalogi. Končajte klic in dobite rezultat v klepetu ali tudi prekličite opravilo.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent vašo predstavitev spremeni v prilagodljiv potek dela.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent čaka, medtem ko uporabljate namizje.';

  @override
  String get neoagentIsWorking => 'NeoAgent deluje';

  @override
  String get neoagentLinuxComputer => 'Računalnik NeoAgent Linux';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT POTREBUJE ODLOČITEV';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Prenosi izvajalnega okolja NeoAgent zahtevajo varen naslov.';

  @override
  String get neoagentServerAddress => 'Naslov strežnika NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'E-pošta storitve NeoAgent ni pripravljena. Prosite operaterja strežnika, da preveri nastavitve e-poštnega okolja.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Namestitve NeoAgenta ni bilo mogoče dokončati.';

  @override
  String get neoagentUser => 'Uporabnik NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent samodejno uporablja ta računalnik in vpraša, preden uporabi vaš zaslon, miško, tipkovnico, datoteke ali ukazno vrstico.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent uporablja vašo približno lokacijo v ozadju za sprožitev opomnikov o geomeji (npr. »Opomni me, naj kupim mleko, ko grem mimo supermarketa«).\n\n';

  @override
  String get neoagentWorkspace => 'Delovni prostor NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][sklad] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'Zaledni URL NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Potreben je zaledni URL NeoRecall.';

  @override
  String get neorecallSetup => 'Nastavitev NeoRecall';

  @override
  String get networkRequestFailed => 'omrežna zahteva ni uspela';

  @override
  String get networkWriteRequests => 'Omrežne zahteve za pisanje';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'nikoli ne šteje v omejitve skupne uporabe.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Novi računi pred prijavo potrdijo svoj e-poštni naslov.';

  @override
  String get newAccountsPerDay => 'Novi računi na dan';

  @override
  String get newChat => 'Nov klepet';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Nove skupine ostanejo tihe, razen če nekdo označi $arg1, dokler jih ne vklopite.';
  }

  @override
  String get newLink => 'Nova povezava';

  @override
  String get newPasswordsDoNotMatch => 'Nova gesla se ne ujemata.';

  @override
  String get newRecoveryCodes => 'Nove obnovitvene kode';

  @override
  String get newSession => 'Nova seja';

  @override
  String get newSessionN => 'Nova seja (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Nova seja z isto nastavitvijo';

  @override
  String get newSkill => 'Nova veščina';

  @override
  String get newSkill2 => 'Nova spretnost';

  @override
  String get newThisWeek => 'Novo ta teden';

  @override
  String get newsDigest => 'Povzetek novic';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Naslednji ponovni poskus: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Potek prijave v Nextcloud';

  @override
  String get nextcloudSetup => 'Nastavitev Nextcloud';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'URL Nextcloud';

  @override
  String get nextcloudUrlIsRequired => 'Potreben je URL Nextcloud.';

  @override
  String get nickname => 'Vzdevek';

  @override
  String get noAccountsConnectedYet => 'Noben račun še ni povezan.';

  @override
  String get noAccountsFound => 'Najden ni noben račun.';

  @override
  String get noActiveSessionsFound => 'Ni aktivnih sej.';

  @override
  String get noAgentsYet => 'Zastopnikov še ni';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Noben ponudnik umetne inteligence ni konfiguriran, zato klepet in sporočanje ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Ni pozivov za odobritev — agent deluje brez prekinitve.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Nobeno sredstvo za izdajo $arg1 se ni ujemalo s to platformo.';
  }

  @override
  String get noArguments => '(brez argumentov)';

  @override
  String get noAuth => 'Brez avtorizacije';

  @override
  String get noBindingsYet => 'Ni še nobenih vezav.';

  @override
  String get noChangesYet => 'Ni še nobenih sprememb';

  @override
  String get noChannelsFound => 'Ni kanalov';

  @override
  String get noCloudComputerSlotIsFree =>
      'Trenutno nobena reža za računalnik v oblaku ni prosta. Poskusite znova čez trenutek.';

  @override
  String get noCoreMemoryEntriesYet => 'Ni še nobenega osnovnega pomnilnika.';

  @override
  String get noDescription => 'Brez opisa';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Trenutno ni na voljo nobenega namiznega zaslona.';

  @override
  String get noDetailAvailable => 'Podrobnosti niso na voljo';

  @override
  String get noDetailedSyncSummaryYet =>
      'Podrobnega povzetka sinhronizacije še ni.';

  @override
  String get noDetailsCaptured => 'Ni zajetih podrobnosti.';

  @override
  String get noEmailLinked => 'E-pošta ni povezana';

  @override
  String get noExternalSignInProvidersLinked =>
      'Ni povezanih zunanjih ponudnikov za prijavo.';

  @override
  String get noGroupMessagesYet => 'Ni še skupinskih sporočil';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Dodana še ni nobena oseba za določeno skupino.';

  @override
  String get noGroupsAddedYet => 'Dodana še ni nobena skupina.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Ni še nobene skupine. Ko $arg1 vidi skupinsko sporočilo, uporabite Poišči nedavne klepete in prikazali se bodo tukaj.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Ni še nobene skupine. Ko $arg1 vidi skupinsko sporočilo, uporabite Poišči nedavne klepete.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Koristni podatki o zdravju niso bili vrnjeni.';

  @override
  String get noHealthSamplesStoredYet =>
      'Vzorci zdravstvenega stanja še niso shranjeni.';

  @override
  String get noHttpClientImplementationForThis =>
      'Za to platformo ni implementacije odjemalca HTTP.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Za ta korak ni bil zabeležen noben vhod ali izhod.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Nobena integracija ne ustreza temu iskanju.';

  @override
  String get noLimit => 'Brez omejitev';

  @override
  String get noLocalPasswordIsSetYet =>
      'Lokalno geslo še ni nastavljeno. Ustvarite ga, da omogočite prijavo z uporabniškim imenom/geslom.';

  @override
  String get noLogEntries => 'Ni vnosov v dnevnik.';

  @override
  String get noMatchingSettings => 'Ni ustreznih nastavitev';

  @override
  String get noMcpServersMatchThisSearch =>
      'Noben strežnik MCP ne ustreza temu iskanju.';

  @override
  String get noMemoryEntriesFound => 'Ni najdenih vnosov v pomnilnik.';

  @override
  String get noMemorySync => 'Ni sinhronizacije pomnilnika';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Enkrat prebere pomembna in poslana sporočila zadnjih 12 mesecev, da agent pozna vaše stike in projekte.';

  @override
  String get emailMemory => 'Pomnilnik e-pošte';

  @override
  String get importNow => 'Uvozi zdaj';

  @override
  String get importOnConnect => 'Ob povezavi računa uvozi starejšo pošto';

  @override
  String get sweepStarting => 'Pripravljanje…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Branje e-pošte · $done od $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Branje e-pošte · najdenih $count';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Učenje iz e-pošte · $done od $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Zadnji uvoz: $emails e-sporočil · $memories novih spominov';
  }

  @override
  String get sweepNothingNew => 'Ni novih e-sporočil za uvoz';

  @override
  String sweepFailed(String error) {
    return 'Uvoz ni uspel: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Noben model se ne ujema z \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Za to izvedbo ni bila zabeležena nobena zahteva po modelu.';

  @override
  String get noModelsDiscoveredYet => 'Ni še odkritih modelov';

  @override
  String get noModelsSelected => 'Ni izbranih modelov';

  @override
  String get noModelsYet => 'Ni še modelov';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'noben račun neoagent ni povezan s tem ponudnikom';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Za ta računalnik ni na voljo nobeno zaledno izvajalno okolje NeoAgent.';

  @override
  String get noNetworkConnection => 'Ni omrežne povezave';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Ni omrežne povezave. Povežite se, če želite še naprej uporabljati NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Ni omrežne povezave. Znova se povežite, da preverite, ali so na voljo posodobitve.';

  @override
  String get noOne => 'nihče';

  @override
  String get noOneAddedYet => 'Nihče še ni dodan.';

  @override
  String get noOneCanMessage => 'Nihče ne more poslati sporočila';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Najden ni bil noben drug strežnik NeoAgent. Iščete lahko znova ali ročno vnesete naslov.';

  @override
  String get noPeopleAddedYet => 'Nobena oseba še ni dodana.';

  @override
  String get noPlatformsMatch => 'Nobena platforma se ne ujema';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Noben ponudnik še ni na voljo za konfiguracijo.';

  @override
  String get noRecentChannelActivity => 'Ni nedavne dejavnosti na kanalu';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Ni rezultatov za \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'V tem območju ni tekov.';

  @override
  String get noRunsMatchTheseFilters =>
      'Nobena serija se ne ujema s temi filtri';

  @override
  String get noRunsYet => 'Tekov še ni';

  @override
  String get noRunsYet2 => 'Tekov še ni.';

  @override
  String get noSecurityKeyWasProvided => 'Varnostni ključ ni bil priložen.';

  @override
  String get noServerUrlSet => 'URL strežnika ni nastavljen';

  @override
  String get noSessionMatchesThatSearch =>
      'Nobena seja ne ustreza temu iskanju.';

  @override
  String get noSessionsYet => 'Ni še nobenih sej';

  @override
  String get noSkillsMatchTheseFilters =>
      'Nobena spretnost ne ustreza tem filtrom.';

  @override
  String get noStepsWereRecordedForThis =>
      'Za ta tek ni bil zabeležen noben korak.';

  @override
  String get noSummaryAvailable => 'Povzetek ni na voljo.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Ni nalog za $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Nobeno orodje se ne ujema z \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Posodobitev se ne izvaja';

  @override
  String get noUsageYet => 'Še brez uporabe.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Na voljo še ni nobeno preverjeno zaledno izvajalno okolje NeoAgent.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Nihče ga ne more več uporabljati. Ljudje, ki so se že pridružili ';

  @override
  String get none => 'Noben';

  @override
  String get notApprovedYet => 'še ni odobren';

  @override
  String get notAuthenticated => 'ni potrjeno';

  @override
  String get notCheckedYet => 'Še ni preverjeno';

  @override
  String get notConfigured => 'Ni nastavljeno';

  @override
  String get notConnected => 'Ni povezano';

  @override
  String get notConnected2 => 'Ni povezano';

  @override
  String get notInstalled => 'Ni nameščeno';

  @override
  String get notNeeded => 'Ni potrebno';

  @override
  String get notNeededEnough => 'Ne potrebujem dovolj';

  @override
  String get notNow => 'Ne zdaj';

  @override
  String get notNow2 => 'Ne zdaj';

  @override
  String get notSet => 'Ni nastavljeno';

  @override
  String get notSetUp => 'Ni nastavljeno';

  @override
  String get notTheSameAsAdmin => 'Ni isto kot admin';

  @override
  String get nothingFound => 'Nič najdenega';

  @override
  String get nothingHereYet => 'Tukaj še ni ničesar.';

  @override
  String get nothingHereYet2 => 'Tukaj še ni ničesar';

  @override
  String get nothingMatches => 'Nič se ne ujema';

  @override
  String get nothingStoredYet => 'Nič še ni shranjeno.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'ID odjemalca OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'ID odjemalca oauth skrivni ključ API za preusmeritev';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth id odjemalca skrivna preusmeritev gmail koledar pogon';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Zagon OAuth na tej platformi ni podprt.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'skrivni ID odjemalca najemnika oauth outlook';

  @override
  String get oauthToken => 'Žeton OAuth';

  @override
  String get oauthWithPkce => 'OAuth s PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'od $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'lastnega. Po shranjevanju se ne prikaže nikoli več.';

  @override
  String get off => 'Izklopljeno';

  @override
  String get officialIntegration => 'Uradna integracija';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Uradna integracija ni vrnila URL-ja povezave.';

  @override
  String get on => 'Vklopljeno';

  @override
  String get onASignedInAndroidDevice =>
      'V prijavljeni napravi Android odprite Nastavitve › Prijava in varnost, skenirajte to kodo in odobrite prijavo.';

  @override
  String get onByDefaultForNewGroups => 'Privzeto vklopljeno za nove skupine';

  @override
  String get onDemand => 'Na zahtevo';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Vklopljeno za $arg1 od skupin $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'na. Ponovno se lahko pridružijo le z novo povezavo s povabilom.';

  @override
  String get onYourOwnTheDefault => 'Sami (privzeto)';

  @override
  String get once => 'Enkrat';

  @override
  String get oneIsSavedOtherChangesIn =>
      'eden je shranjen. Shranijo se tudi druge spremembe v tem obrazcu.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Eden ali več računov je poteklo. Znova povežite prizadeti račun, da obnovite dostop do orodja.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'En čas izvajanja nadzoruje osebnost, nadomestne skupine, pomnilnik sobe, norme, teorijo uma in dostavo.';

  @override
  String get oneTimeRun => 'Enkratni tek';

  @override
  String get onlyApkOrApksFilesCan =>
      'Namestite lahko samo datoteke .apk ali .apks.';

  @override
  String get onlyInThisGroup => 'Samo v tej skupini';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Potreben le, če storitev zahteva dodatne glave HTTP.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Potreben le, če želite preoblikovati izhodni tovor.';

  @override
  String get onlyTheyCanChangeIt => 'Samo oni ga lahko spremenijo.';

  @override
  String get open => 'Odpri';

  @override
  String get openAccountSettingsOnASigned =>
      'Odprite Nastavitve › Prijava in varnost v prijavljeni napravi Android, skenirajte to kodo in odobrite prijavo.';

  @override
  String get openComputer => 'Odprite računalnik';

  @override
  String get openDashboard => 'Odpri nadzorno ploščo';

  @override
  String get openFolder => 'Odpri mapo ...';

  @override
  String get openInWorkbench => 'Odpri v delovni mizi';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Odprite NeoAgent in znova povežite $arg1, da obnovite sporočanje.';
  }

  @override
  String get openTimeSettings => 'Nastavitve odprtega časa';

  @override
  String get openToAnyone => 'Odprto za vsakogar';

  @override
  String get openTrello => 'Odprite Trello';

  @override
  String get openVoiceAssistant => 'Odpri glasovnega pomočnika';

  @override
  String get openWiFiSettings => 'Odprite nastavitve Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Odprite s privzeto aplikacijo';

  @override
  String get openaiCodex => 'Kodeks OpenAI';

  @override
  String get openaiCompatible => 'openai združljiv';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Končna točka, združljiva z OpenAI (vaš strežnik ali drug ';

  @override
  String openedArg1(Object? arg1) {
    return 'Odprt $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Odpiranje URL-jev namizja na tej platformi ni podprto.';

  @override
  String get openingYourSavedDesktop => 'Odpiranje shranjenega namizja.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Odpiranje shranjenega namizja. Običajni zagoni trajajo manj kot 10 sekund.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Izbirna dodatna skrivnost, če zaščitite vhodni webhook.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Izbirna preglasitev, če URL webhook ne zadostuje.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Izbirna skrivnost za preverjanje dohodnih dogodkov v klepetu.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Izbirna skrivnost za preverjanje dohodnih dogodkov.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Izbirna skrivnost za preverjanje dohodnih dogodkov iMessage.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Izbirna skrivnost za preverjanje dohodnih dogodkov LINE.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Izbirna skrivnost za preverjanje dohodnih dogodkov Mattermost.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Izbirna skrivnost za preverjanje dohodnih dogodkov Teams.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Neobvezno. Agent že ima svojo osebnost. Vse, kar dodate o tonu, se nanese nanj, tako da vam ga nikoli ni treba definirati.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Neobvezno. Ko je nastavljen, se uporablja namesto URL-ja.';

  @override
  String get orAnswerInYourOwnWords => 'Ali odgovorite s svojimi besedami';

  @override
  String get orBuildYourOwnTask => 'Ali pa sestavite svojo nalogo';

  @override
  String get orContinueWith => 'ali nadaljujte z';

  @override
  String get orFiles => 'ali datoteke.';

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
  String get originNotAllowed => 'izvor ni dovoljen';

  @override
  String get outgoingMessage => 'Odhodno sporočilo';

  @override
  String get outgoingWebhookUrl => 'URL odhodnega webhooka';

  @override
  String get outlookEmailReceived => 'Outlookova e-pošta je prejeta';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Prepiši opombe o vedenju iz uvoza.';

  @override
  String get ownModel => 'lasten model';

  @override
  String get packageName => 'Ime paketa';

  @override
  String get pairWithQrCode => 'Seznani s kodo QR';

  @override
  String get password => 'Geslo';

  @override
  String get password2faAndActiveSessions => 'Geslo, 2FA in aktivne seje';

  @override
  String get passwordCreated => 'Geslo ustvarjeno.';

  @override
  String get passwordIsTooWeak => 'geslo je prešibko';

  @override
  String get passwordMin8 => 'geslo min 8';

  @override
  String get passwordOrApiKey => 'Geslo ali API ključ';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Moč gesla: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Gesli se ne ujemata.';

  @override
  String get pasteAKey => 'Prilepite ključ.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Prilepite nov ključ, da zamenjate $arg1';
  }

  @override
  String get pasteTheKey => 'Prilepite ključ';

  @override
  String get pasteYourAccountToken => 'Prilepite žeton računa';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Spodaj prilepite svoj ključ $arg1 API. Je ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Pot mora ostati znotraj delovnega prostora NeoAgent.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Pot mora ostati znotraj mape delovnega prostora.';

  @override
  String get pauseLiveUpdates => 'Začasno ustavite posodobitve v živo';

  @override
  String get pauseTaskLoop => 'Zaustavi zanko opravila';

  @override
  String get paused => 'Zaustavljeno';

  @override
  String peakArg1(Object? arg1) {
    return 'vrh $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Ljudje v zasebnih klepetih';

  @override
  String get perAccountRateLimits => 'Omejitve obrestne mere na račun';

  @override
  String get perCategoryPermissions => 'Dovoljenja po kategorijah';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Politike dovoljenj za posamezno orodje, vrata za odobritev in izolacija procesa za izvajanje lupine.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Zahtevano dovoljenje: $arg1';
  }

  @override
  String get permissionsNeeded => 'Potrebna so dovoljenja';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Dovoljenja. Nihče drug tega ne more spremeniti.';

  @override
  String get personOrChat => 'Oseba ali klepet';

  @override
  String get personaBehaviorNotes => 'Opombe o vedenju oseb';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Žeton osebnega dostopa za bota Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Osebni kanali in neposredne podporne površine.';

  @override
  String get personalSelfChat => 'Osebni samoklepet';

  @override
  String get phoneNumber => 'Telefonska številka';

  @override
  String get pickARunFromTheList =>
      'Izberite tek s seznama, da si ogledate njegove korake.';

  @override
  String get pickARunFromTheList2 =>
      'Na seznamu na levi izberite tek, da raziščete njegov tok.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Izberite med nedavnimi klepeti $arg1 ali sami dodajte osebo ali skupino.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Izberite, kako $arg1 uporablja ta račun.';
  }

  @override
  String get pickOneToFillInThe =>
      'Izberite eno za izpolnitev naloge. Kasneje lahko vse prilagodite.';

  @override
  String get picksUpWhereYouLeftOff => 'Nadaljuje tam, kjer ste končali';

  @override
  String get plan => 'Načrtujte';

  @override
  String get planning => 'Načrtovanje';

  @override
  String get platform => 'Platforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Izberite urnik.';

  @override
  String get pleaseEnterAFilename => 'Vnesite ime datoteke.';

  @override
  String get pleaseEnterAKey => 'Vnesite ključ.';

  @override
  String get pleaseEnterAPrompt => 'Vnesite poziv.';

  @override
  String get pleaseEnterATaskName => 'Vnesite ime naloge.';

  @override
  String get pleaseEnterTheMemoryContent => 'Vnesite vsebino pomnilnika.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Vnesite, kdaj naj se opravilo izvaja.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Izberite račun ali vnesite veljaven ID povezave.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Usmerite NeoAgent na kateri koli zaključek klepeta, združljiv z OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Kamero usmerite proti kodi, prikazani na odjavljeni napravi. Odobritev ostane na tem telefonu.';

  @override
  String get port => 'Pristanišče';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env javni url zaupanje proxy varna uvedba piškotkov';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Vrhunska avtomatizacija z urnikom in integracijskimi sprožilci.';

  @override
  String get prepareQrCode => 'Pripravite QR kodo';

  @override
  String get preparingNeoagent => 'Priprava NeoAgenta …';

  @override
  String get preparingNeoagent2 => 'Priprava NeoAgenta';

  @override
  String get pressAndHoldForQuickCapture =>
      'Pritisnite in držite za hiter zajem';

  @override
  String get pressKeysIsNotSupportedOn =>
      'tipke za pritisk na tej platformi niso podprte.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Pritisnjen $arg1';
  }

  @override
  String get priceUnknown => 'Cena neznana';

  @override
  String get primaryDisplay => 'Primarni zaslon';

  @override
  String get privateChat => 'Zasebni klepet';

  @override
  String get privateChats => 'Zasebni klepeti';

  @override
  String get privateChats2 => 'zasebni klepeti';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Zasebni klepeti: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Zasebni klepeti $arg1 · skupine $arg2';
  }

  @override
  String get privateChatsOnly => 'Samo zasebni klepeti';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'zasebni omrežni naslovi niso dovoljeni.';

  @override
  String get profileEmailAndPersonalData => 'Profil, e-pošta in osebni podatki';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Poziv, preden NeoAgent ostane v sistemski vrstici.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Predpomnilnik poziva: $arg1 predpomnjeni žetoni ';
  }

  @override
  String get promptCopied => 'Poziv kopiran.';

  @override
  String get promptOrSchedule => 'poziv ali urnik.';

  @override
  String get promptToPasteIntoAnotherAi => 'Poziv za lepljenje v drug AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Povezovanja ponudnika ni bilo mogoče začeti.';

  @override
  String get providerSignInCouldNotBe =>
      'Prijave ponudnika ni bilo mogoče začeti.';

  @override
  String get providers => 'Ponudniki';

  @override
  String get providersEachAccountCanStillPick =>
      'Ponudniki; vsak račun lahko še vedno izbere svoj model v nastavitvah. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Ponudnike, integracije, glas in izbirne zmogljivosti je mogoče kadar koli dokončati v nastavitvah.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Niti javnih izdaj in zahtev za vleko, odgovor samo za odobrene osebe.';

  @override
  String get publicUrl => 'Javni URL';

  @override
  String get publicUrlAndAllowedOrigins => 'Javni URL in dovoljeni izvori';

  @override
  String get publicUrlOverride => 'Preglasitev javnega URL-ja';

  @override
  String get pullsTogetherTheDayAhead => 'Združi dan, ki je pred nami';

  @override
  String get pushToTalk => 'Pritisni in govori';

  @override
  String get qrBasedPhoneLinking => 'Telefonsko povezovanje na osnovi QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'Prijava QR končana, vendar NeoAgent ni mogel obdržati seje. prosim poskusite ponovno';

  @override
  String get qrLoginCouldNotBeStarted => 'QR prijave ni bilo mogoče začeti.';

  @override
  String get qrLoginRequestHasExpired => 'zahteva za prijavo qr je potekla';

  @override
  String get qrLoginRequestWasNotFound =>
      'zahteve za prijavo qr ni bilo mogoče najti';

  @override
  String get qrPairing => 'Seznanjanje QR';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'izvajanje poizvedb; vse kar piše se zavrne.';

  @override
  String get queryFilter => 'Poizvedba / Filter';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'V čakalni vrsti kot krmiljenje za trenutno vožnjo: $arg1';
  }

  @override
  String get quickstart => 'Hitri začetek';

  @override
  String get quit => 'Odnehaj';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'začetek dežja, opozorilo na veter';

  @override
  String get ranAScriptInThePage => 'Zagnal skript na strani';

  @override
  String ranArg1(Object? arg1) {
    return 'Ran $arg1';
  }

  @override
  String get rateLimits => 'Omejitve stopnje';

  @override
  String get readAnArtifact => 'Preberi artefakt';

  @override
  String get readAndEditFilesInsideYour =>
      'Branje in urejanje datotek v vaši mapi NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Preberi $arg1';
  }

  @override
  String get readError => 'Napaka pri branju';

  @override
  String get readFiles => 'Branje datotek';

  @override
  String get readOnly => 'Samo za branje';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Preberite mapo in povzemite sklad, vstopne točke in kako jo zagnati.';

  @override
  String get readThePage => 'Preberi stran';

  @override
  String get readTheUiTree => 'Preberite drevo uporabniškega vmesnika';

  @override
  String get readWrite => 'Branje / pisanje';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Bere korake, srčni utrip, spanje, vadbo in težo.';

  @override
  String get ready => 'pripravljena';

  @override
  String get readyForFirstTimeSetup => 'Pripravljen za prvo nastavitev';

  @override
  String get readyToConnect => 'Pripravljen za povezavo';

  @override
  String get recentChannelActivity => 'Nedavna dejavnost kanala';

  @override
  String get recentChats => 'Nedavni klepeti';

  @override
  String get recentDecisions => 'Nedavne odločitve';

  @override
  String get recentFailedRuns => 'Nedavni neuspešni zagoni';

  @override
  String get recentGroupDecisions => 'Nedavne odločitve skupine';

  @override
  String get recentRuns => 'Nedavne vožnje';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Nedavne izvedbe trajajo približno $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Najnovejši izhod strežnika, najprej najnovejši.';

  @override
  String get recentUsage4Hours => 'Nedavna uporaba (4 ure)';

  @override
  String get recents => 'Nedavne';

  @override
  String get recipientField => 'Polje prejemnika';

  @override
  String get reconnectOrFinishSetup =>
      'Ponovno povežite ali dokončajte nastavitev';

  @override
  String get reconnectingThisDevice => 'Ponovno povezovanje te naprave …';

  @override
  String get recurring => 'Ponavljajoče se';

  @override
  String get redirectUri => 'URI preusmeritve';

  @override
  String get redoOnboarding => 'Ponovi vkrcanje';

  @override
  String get refresh => 'Osveži';

  @override
  String get refreshCode => 'Osveži kodo';

  @override
  String get refreshNow => 'Osveži zdaj';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Osvežite zaslon Android, da poskusite znova.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Zavrni pošiljanje, razen če se povezava nadgradi na TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'ne glede na spodnje nastavitve po kategorijah.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Registrirajte $arg1 za tok priklica pomočnika.';
  }

  @override
  String get registrationIsClosed => 'registracija je zaključena';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registracija registracija novih računov omogoča prijavo';

  @override
  String get rejectInvalidTlsCertificates => 'Zavrni neveljavna potrdila TLS';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'sprostite in znova zaženite. Povezane aplikacije se znova povežejo, ko se vrne.';

  @override
  String get releaseChannel => 'Izpusti kanal';

  @override
  String get releaseCommitBranchNode => 'sprosti vozlišče veje potrditve';

  @override
  String get releaseWhenYouAreDone => 'Spustite, ko končate.';

  @override
  String get reloadNow => 'Ponovno naloži zdaj';

  @override
  String get rememberThisChoice => 'Zapomni si to izbiro';

  @override
  String get remove => 'Odstrani';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Ali želite odstraniti \"$arg1\" in njegove zabeležene korake iz zgodovine teka?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Odstranite \"$arg1\" iz osnovnega pomnilnika.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Odstraniti ključ $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'odstrani izbriši uporabnika gdpr';

  @override
  String get removeSmtpPassword => 'Odstrani geslo SMTP';

  @override
  String get removeTheSmtpPassword => 'Odstraniti geslo SMTP?';

  @override
  String get rename => 'Preimenuj';

  @override
  String get renameSecurityKey => 'Preimenuj varnostni ključ';

  @override
  String get renameSession => 'Preimenuj sejo';

  @override
  String get repairAndRetry => 'Popravite in poskusite znova';

  @override
  String get repairDesktop => 'Popravi namizje';

  @override
  String get repeat => 'ponovi';

  @override
  String get repliesWhenTagged => 'Odgovori, ko je označen';

  @override
  String get replyToAddress => 'Naslov za odgovor';

  @override
  String replyToArg1(Object? arg1) {
    return 'Odgovori $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Repozitorij mora biti v obliki lastnik/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reproducirajte napako, ki jo opisujem, poiščite glavni vzrok in jo popravite z regresijskim testom.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'zahteva ni uspela s http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Zahteva ni uspela s HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Zahtevaj dovoljenja';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Zahteva za $arg1 ni uspela, preden se je zaledje odzvalo.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Zahtevano $arg1';
  }

  @override
  String get requireStarttls => 'Zahtevaj STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Zahtevano za HTTPS ali TLS proxy. Velja po strežniku ';

  @override
  String get requiredExampleBerlinDe => 'Obvezno. Primer: Berlin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Obvezno. Oblika: lastnik/repo';

  @override
  String get reserveAssistantHotkey => 'Rezervirajte bližnjico pomočnika';

  @override
  String get reset => 'Ponastavi';

  @override
  String get resetPassword => 'Ponastavi geslo';

  @override
  String get resetView => 'Ponastavi pogled';

  @override
  String get responsibilities => 'Odgovornosti';

  @override
  String get restart => 'Znova zaženite';

  @override
  String get restartToFinishTheUpdate =>
      ' Znova zaženite, da dokončate posodobitev.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Obnovitev prejšnjega izvajalnega okolja NeoAgent';

  @override
  String get restrictDelegationTargets => 'Omejite cilje delegiranja';

  @override
  String get result => 'Rezultat';

  @override
  String get resultDelivery => 'Dostava rezultatov';

  @override
  String get resultOneClickAddsOneYou =>
      'rezultat. En klik doda eno; lahko uredite pozneje.';

  @override
  String get results => 'Rezultati';

  @override
  String get retry => 'Poskusite znova';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Za večkratno uporabo · rabljen $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Preglejte nepotrjene spremembe';

  @override
  String get revoke => 'Prekliči';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Najprej prekličite skrbnika z `neoagent admin revoke $arg1`';
  }

  @override
  String get revokeThisLink => 'Želite preklicati to povezavo?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Sobno šaržno okno: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Za nadaljevanje zavrtite';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'vrstice. Za ogled dodajte LIMIT ali ožji stavek WHERE ';

  @override
  String get rule => 'Pravilo';

  @override
  String get run => 'Izvajanje';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Zaženite poljubne ukaze na vašem računalniku ali VM.';

  @override
  String get runAt => 'Run At';

  @override
  String get runCompleted => 'Zagon končan';

  @override
  String get runFailed => 'Zagon ni uspel';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Zaženite git diff, preglejte nepotrjene spremembe za hrošče in težave s slogom ter povzemite, kar ste našli.';

  @override
  String get runNotFound => 'Zagon ni bil najden';

  @override
  String get runNow => 'Zaženi zdaj';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Zaženite vhodna osebna sporočila WhatsApp.';

  @override
  String get runQuery => 'Zaženi poizvedbo';

  @override
  String get runShellCommandsOrInstallApps =>
      'Zaženite lupinske ukaze ali namestite aplikacije v napravo Android.';

  @override
  String get runStarted => 'Tek se je začel';

  @override
  String get runStatus => 'Stanje izvajanja';

  @override
  String get runStopped => 'Tek ustavljen';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Zaženite terminalske ukaze in odprite aplikacije ali spletne strani.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Zaženi ta strežnik: računi, posodobitve, ponudniki, konfiguracija ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Zaženi, ko prispe ustrezno sporočilo Gmail.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Zaženi, ko prispe ujemajoče se Outlookovo e-poštno sporočilo.';

  @override
  String get runWhenANewIssueMatching =>
      'Zaženi, ko se v skladišču odpre nova težava, ki ustreza vašim filtrom.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Zaženi, ko je ustvarjen nov pomnilnik NeoRecall, ki ustreza vašim filtrom.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Zaženite, ko na vašo napravo prispe obvestilo.';

  @override
  String get runWhenASlackMessageMatches =>
      'Zaženi, ko se sporočilo Slack ujema z izbranim obsegom.';

  @override
  String get runWhenATeamsChatMessage =>
      'Zaženi, ko se sporočilo klepeta Teams ujema z izbranim obsegom.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Zaženi, ko so za lokacijo napovedani konfigurirani vremenski dogodki.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'teči. Medtem ko je kateri koli model izklopljen, modeli, ki jih ponudniki dodajo ';

  @override
  String get running => 'V teku';

  @override
  String runningArg1(Object? arg1) {
    return 'Teče $arg1';
  }

  @override
  String get runningTask => 'Naloga v teku';

  @override
  String get runningTool => 'Orodje za tek';

  @override
  String get runs => 'Izvajanja';

  @override
  String get runsEveryDayAtTheSelected => 'Teče vsak dan ob izbrani uri.';

  @override
  String get runsFourTimesPerHour => 'Teče štirikrat na uro.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— teče, sporočila, pomnilniki, integracije, datoteke in ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'teče, sporočila, spomine, integracije, datoteke in seje. ';

  @override
  String get runsMondayThroughFriday => 'Izvaja se od ponedeljka do petka.';

  @override
  String get runsOnSelectedWeekdays => 'Izvaja se ob izbranih delavnikih.';

  @override
  String get runsOncePerHour => 'Teče enkrat na uro.';

  @override
  String get runsOncePerMonthOnThe =>
      'Izvaja se enkrat mesečno na izbrani dan.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Zažene se samo, ko pritisnete Zaženi zdaj.';

  @override
  String get runsPerDay => 'Teče na dan';

  @override
  String get runsPerDay30Days => 'Teče na dan (30 dni)';

  @override
  String get runsThatCompleted => 'Teče, ki so končane';

  @override
  String get runsThisWeek => 'Teče ta teden';

  @override
  String get runsToday => 'Teče danes';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Teki, orodja, spomin, razporejanje, veščine in MCP so na voljo tukaj.';

  @override
  String get runsTwicePerHour => 'Teče dvakrat na uro.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Zagoni se bodo vrnili na ključ strežnika v skupni rabi za $arg1, če je ta konfiguriran. Tega ni mogoče razveljaviti.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Čas izvajanja $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Čas izvajanja: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Nastavitve izvajalnega časa, s katerimi se je ta strežnik začel. Uredite jih pod ';

  @override
  String get runtimeSetupRequired =>
      'Potrebna je nastavitev izvajalnega okolja';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Javni ključ za podpisovanje med izvajanjem mora imeti 32 bajtov.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Shrani';

  @override
  String get saveATrelloApiKeyFor =>
      'Shranite ključ API Trello za tega agenta, nato varno povežite en račun Trello. Žeton računa je shranjen na strežniku in se uporablja samo za tega agenta.';

  @override
  String get saveAccount => 'Shrani račun';

  @override
  String get saveChanges => 'Shranite spremembe';

  @override
  String get saveCloudComputerSettings =>
      'Shranite nastavitve računalnika v oblaku';

  @override
  String get saveConnect => 'Shrani in poveži';

  @override
  String get saveDefaults => 'Shrani privzete nastavitve';

  @override
  String get saveDiagnosticReport => 'Shrani diagnostično poročilo';

  @override
  String get saveEmail => 'Shrani e-pošto';

  @override
  String get saveEmailSettings => 'Shranite e-poštne nastavitve';

  @override
  String get saveGeneralSettings => 'Shranite splošne nastavitve';

  @override
  String get saveName => 'Shrani ime';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Shranite diagnostiko nastavitev NeoAgent';

  @override
  String get saveOnly => 'Samo shrani';

  @override
  String get saveSetup => 'Shrani nastavitev';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Shranite te obnovitvene kode zdaj. Ne bodo več prikazani.';

  @override
  String get savedDeliveryDestination => 'Shranjen cilj dostave';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Shranjene omejitve stopnje za @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Skenirajte QR za prijavo v NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Skenirajte QR za seznanjanje NeoAgent iz druge naprave in ga odobrite v tej seji zaganjalnika.';

  @override
  String get scanLoginQr => 'Skenirajte prijavni QR';

  @override
  String get scanPairingQr => 'Skenirajte seznanjanje QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Skenirajte zahteve za prijavo QR iz odjavljenih naprav in jih odobrite iz te overjene mobilne seje.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Skenirajte, da končate $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Skenirajte z NeoAgentom na vašem telefonu';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Pregleda novo e-pošto in vas pinga samo, ko je nekaj pomembno.';

  @override
  String get schedule => 'Urnik';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'načrtovani čas. Ko bodo teki izmerjeni, se bo začelo prej.';

  @override
  String get screen => 'zaslon';

  @override
  String get screenAction => 'dejanje zaslona';

  @override
  String get scrollIsNotSupportedOnThis =>
      'drsenje ni podprto na tej platformi.';

  @override
  String get scrollToBottom => 'Pomaknite se na dno';

  @override
  String get search => 'Iskanje';

  @override
  String get search2 => 'Iskanje ...';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Skrbniške nastavitve iskanja (npr. SMTP, Ollama, dnevniki)';

  @override
  String get searchAgain => 'Išči znova';

  @override
  String get searchByUsernameOrEmail =>
      'Išči po uporabniškem imenu ali e-pošti';

  @override
  String get searchChannels => 'Iskanje kanalov';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Iščite po odkritih kanalih za sporočanje, stikih, skupinah in nedavnih pogovorih.';

  @override
  String get searchGroups => 'Iskanje skupin';

  @override
  String get searchMemory => 'Iskanje spomina';

  @override
  String get searchModelsOrProviders => 'Iskanje modelov ali ponudnikov';

  @override
  String get searchModelsOrProviders2 => 'Iskanje modelov ali ponudnikov ...';

  @override
  String get searchRecentPeopleAndGroups => 'Iskanje nedavnih oseb in skupin';

  @override
  String get searchSessions => 'Seje iskanja';

  @override
  String get searchSettings => 'Nastavitve iskanja';

  @override
  String get searchTitleModelTriggerRunId =>
      'Naslov iskanja, model, sprožilec, ID zagona';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Orodja za iskanje, integracije in veščine';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Iskana koda za \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Iskane datoteke za \"$arg1\"';
  }

  @override
  String get secretField => 'Skrivno polje';

  @override
  String get secureCookies => 'Varni piškotki';

  @override
  String get security => 'Varnost';

  @override
  String get securityKey => 'Varnostni ključ';

  @override
  String get securityKeyPromptWasDismissed =>
      'Poziv za varnostni ključ je bil opuščen.';

  @override
  String get securityKeySignInCompletedBut =>
      'Prijava z varnostnim ključem je končana, vendar NeoAgent ni mogel obdržati seje brskalnika. Prosimo, prijavite se znova.';

  @override
  String get securityKeySignInCouldNot =>
      'Prijave z varnostnim ključem ni bilo mogoče začeti.';

  @override
  String get securityKeys => 'Varnostni ključi';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Varnostni ključi so na voljo samo v spletni aplikaciji NeoAgent.';

  @override
  String get seeAll => 'Glej vse';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Poglejte, kateri strežnik NeoAgent uporablja to okno, in zaženite zaledje na tem računalniku.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'videti vaše uporabniško ime in te nastavitve, nikoli vaših klepetov, spominov ';

  @override
  String get selectARun => 'Izberite tek';

  @override
  String get selectASessionToSeeIts =>
      'Izberite sejo, če si želite ogledati njen računalnik, datoteke in spremembe.';

  @override
  String get selectAll => 'Izberite vse';

  @override
  String get selectAll2 => 'Izberite Vse';

  @override
  String selectArg1(Object? arg1) {
    return 'Izberite $arg1';
  }

  @override
  String get selectTrigger => 'Izberite Sprožilec';

  @override
  String get send => 'Pošlji (⌘↵)';

  @override
  String get send2 => 'Pošlji';

  @override
  String get sendATaskFromChatAnd =>
      'Pošljite nalogo iz klepeta in tukaj se bo prikazala njena zgodovina izvajanja.';

  @override
  String get sendItToATeammateWith =>
      'pošlji soigralcu z računom na tem strežniku.';

  @override
  String get sendLink => 'Pošlji povezavo';

  @override
  String get sendPath => 'Pošlji pot';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Pošlji zahteve POST / PUT / DELETE zunanjim API-jem.';

  @override
  String get sendThisLinkOnlyToThe =>
      'To povezavo pošljite samo osebi, ki ji je namenjena. Prikazan je enkrat; ';

  @override
  String get senderAddress => 'Naslov pošiljatelja';

  @override
  String get senderFilterOptional => 'Filter pošiljatelja (neobvezno)';

  @override
  String get sentSharedAttachments => 'Poslane skupne priloge.';

  @override
  String get separateAccount => 'Ločen račun';

  @override
  String get server => 'Strežnik';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Privzeto za strežnik ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Privzete nastavitve strežnika za glasovne klice v aplikaciji. Klici potekajo v živo ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'sam strežnik: računi, ponudniki in konfiguracija.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Strežnik, nick, kanal in izbirni TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'strežnik izhodna konzola opozorila napake kopiraj';

  @override
  String get serverProviderCredentials => 'Poverilnice ponudnika strežnika';

  @override
  String get serverUrl => 'URL strežnika';

  @override
  String get serverUsageLimitsDonTApply =>
      'Omejitve uporabe strežnika ne veljajo za modele, ki se izvajajo na vašem ključu.';

  @override
  String get serviceEmail => 'Storitvena e-pošta';

  @override
  String get serviceEmailIsNotConfigured => 'storitev e-pošte ni konfigurirana';

  @override
  String get serviceEmailSmtp => 'Storitvena e-pošta (SMTP)';

  @override
  String get sessionActions => 'Dejanja seje';

  @override
  String get sessions => 'Seje';

  @override
  String get sessions2 => 'SEJE';

  @override
  String get sessionsArePinnedToAFolder =>
      'Seje so pripete v mapo in računalnik. Začnite načrtovati, graditi, testirati in pošiljati od tukaj.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'seje (17. člen GDPR). Skrbniških računov ni mogoče izbrisati ';

  @override
  String get sessionsLogoutRevokeForce => 'seje odjava preklic sila';

  @override
  String get setBlockAskAllowPerTool =>
      'Nastavite blokiranje/vprašanje/dovolitev glede na kategorijo orodja ali izberite globalni način.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Nastavite NeoAgent na tem računalniku';

  @override
  String get setUpOrConnectNeoagent => 'Nastavite ali povežite NeoAgent';

  @override
  String get setUrl => 'Nastavite URL';

  @override
  String get settings => 'nastavitve';

  @override
  String get settingsAndCannotBeUndone =>
      'nastavitve in jih ni mogoče razveljaviti.';

  @override
  String get settingsArea => 'Območje z nastavitvami';

  @override
  String get settingsAreas => 'Območja nastavitev';

  @override
  String get setup => 'Nastavitev';

  @override
  String get setupDetails => 'Podrobnosti nastavitve';

  @override
  String get setupRequired => 'Potrebna nastavitev';

  @override
  String get setupWasCancelled => 'Nastavitev je bila preklicana.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Skupne priloge iz odjemalca NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'V skupni rabi iz druge aplikacije';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Ključi ponudnika v skupni rabi so konfigurirani na strežniku. Če želite namesto tega uporabiti svoj ključ API ali končno točko po meri, pojdite na Napredno → Prinesite svoj ključ.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'V skupni rabi s klepetom NeoAgent in njegovim pomnilnikom.';

  @override
  String get shellCommands => 'Ukazi lupine';

  @override
  String showAllArg1(Object? arg1) {
    return 'Prikaži vse $arg1';
  }

  @override
  String get showEarlier => 'Pokaži prej';

  @override
  String get showEveryStep => 'Pokažite vsak korak';

  @override
  String get showTools => 'Pokaži orodja';

  @override
  String get showWorkbenchJ => 'Pokaži delovno mizo (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Prikazujem prvi $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Prikazano v stranski vrstici. Če želite uporabiti svoje uporabniško ime, pustite prazno.';

  @override
  String get signIn => 'Prijavite se';

  @override
  String get signInCompletedButNeoagentCould =>
      'Prijava je bila končana, vendar NeoAgent ni mogel obdržati seje brskalnika. Prosimo, prijavite se znova. Če se to ponavlja, preverite nastavitve piškotkov zaledne seje.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Prijava je bila končana, vendar NeoAgent ni mogel obdržati seje brskalnika. Prosimo, prijavite se znova. Če se to dogaja še naprej, se piškotek zaledne seje verjetno ne bo ohranil.';

  @override
  String get signInToThisNeoagentServer =>
      'Pred skeniranjem kode QR za seznanjanje se prijavite v ta strežnik NeoAgent.';

  @override
  String get signInWithAHardwareKey =>
      'Prijavite se s strojnim ključem ali geslom namesto z geslom. ';

  @override
  String get signInWithASecurityKey => 'Prijavite se z varnostnim ključem';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Prijavite se z $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Odobrite NeoAgent v svojem računu $arg1. Ni ključa za kopiranje.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Čakam na $arg1. Končajte v brskalniku.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Prilepite kodo $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Ko ste odobrili NeoAgent, je $arg1 prikazal enkratno kodo. Prilepite sem.';
  }

  @override
  String get signInCode => 'Koda za prijavo';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Prijavljen z $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Prijava ni uspela: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Prijavite se z istim e-poštnim naslovom in glavnim geslom, ki ga uporabljate v Bitwardenu. Glavno geslo in koda v dveh korakih se uporabljata samo za prijavo in se nikoli ne shranita ali pošljeta AI.';

  @override
  String get signOut => 'Odjavite se';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Povsod se odjavite @$arg1?';
  }

  @override
  String get signOutEverywhere => 'Odjavite se povsod';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API most';

  @override
  String get signalCliServerUrl => 'URL strežnika signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Odjavljen @$arg1 iz vsake seje.';
  }

  @override
  String get signedInDevices => 'Prijavljene naprave';

  @override
  String get signedInWithin24Hours => 'Prijavljen v 24 urah';

  @override
  String get signingSecret => 'Skrivnost podpisa';

  @override
  String sinceArg1(Object? arg1) {
    return 'Od $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'od $arg1';
  }

  @override
  String get singleMessage => 'Eno sporočilo';

  @override
  String get singleUse => 'Za enkratno uporabo';

  @override
  String get skill => 'Spretnost';

  @override
  String get skillChanges => 'Spremembe spretnosti';

  @override
  String get skillContent => 'Vsebina spretnosti';

  @override
  String get skills => 'Spretnosti';

  @override
  String get skip => 'Preskoči';

  @override
  String get skipForNow => 'Preskoči za zdaj';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Preskočite to nalogo, preden pokliče model.';

  @override
  String get slackMessageReceived => 'Slack sporočilo prejeto';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Seje spanja $arg1';
  }

  @override
  String get smartSelector => 'pametni selektor';

  @override
  String get smartSelector2 => 'Pametni izbirnik';

  @override
  String get smartSelectorPool => 'Smart Selector Pool';

  @override
  String get smtpHost => 'Gostitelj SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'ponastavitev obvestil pošiljatelja pošte smtp tls potrditev';

  @override
  String get smtpPassword => 'geslo SMTP';

  @override
  String get smtpPort => 'vrata SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'Vrata SMTP morajo biti celo število od 1 do 65535.';

  @override
  String get smtpUsername => 'uporabniško ime SMTP';

  @override
  String get soTheRunStartsThatMuch => 'zato se tek začne toliko prej.';

  @override
  String get socialBehaviorOff => 'Družbeno vedenje izklopljeno';

  @override
  String get socialIntelligence => 'socialna inteligenca';

  @override
  String get socialIntelligence2 => 'Socialna inteligenca';

  @override
  String get socialObservability => 'Družbena opazljivost';

  @override
  String get socialReach => 'socialni doseg';

  @override
  String get socialReach2 => 'Socialni doseg';

  @override
  String get socialReach3 => 'Socialni doseg';

  @override
  String get socialReachUpdated => 'Social Reach posodobljen.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Agenti družbenih virov lahko berejo neposredno, vključno z viri, repozitoriji, Reddit, X, videoposnetki in tržnimi podatki, podprtimi s piškotki.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Nekaj ​​je šlo narobe. prosim poskusite ponovno';

  @override
  String get source => 'Vir';

  @override
  String get spaceOrChatIdUsedWhen =>
      'ID prostora ali klepeta, ki se uporabi, ko ta agent začne pogovor.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space webhook in podpora za povratni klic aplikacije';

  @override
  String get speaking => 'Govorjenje';

  @override
  String get speechToSpeechModelUsingThe =>
      'model govora v govor z uporabo ključa OpenAI ali Google pod ';

  @override
  String get speechToText => 'Pretvorba govora v besedilo';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Pretvorba govora v besedilo prepisuje glasovne zapiske in narekovanje. Auto uporablja OpenAI, Gemini ali Deepgram, kar ima ključ API. Model glasovnega odgovora je model klepeta, ki odgovarja na glasovne zapiske.';

  @override
  String get sqlConsole => 'SQL konzola';

  @override
  String get stable => 'Stabilen';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable namesti najnovejšo objavljeno zaledno izdajo.';

  @override
  String get stackTrace => 'sled sklada';

  @override
  String get standard => 'Standardno';

  @override
  String get standardView => 'Standardni pogled';

  @override
  String get start => 'Začetek';

  @override
  String get startASessionToPlanOr =>
      'Začnite sejo za načrtovanje ali gradnjo z NeoAgentom.';

  @override
  String get startAndroid => 'Zaženite Android';

  @override
  String get startComputer => 'Zaženite računalnik';

  @override
  String get startFullSetup => 'Začni popolno nastavitev';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Začni nastavitev';

  @override
  String get startTalking => 'Začni govoriti';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Najprej zaženite telefon Android, nato sem spustite datoteko .apk ali .apks.';

  @override
  String get startTheServerLaterFromThe =>
      'Zaženite strežnik pozneje s seznama, ko je konfiguracija shranjena.';

  @override
  String get startWithARecommendedTask => 'Začnite s priporočeno nalogo';

  @override
  String get startingAndroid => 'Zagon Androida';

  @override
  String get startingYourComputer => 'Zagon računalnika';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Začne se z xoxb-. Iz vaših poverilnic aplikacije Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'Napaka startTelecomCallRouting: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistika izvaja žetone uporabniki grafikoni stopnja uspešnosti';

  @override
  String get status => 'Stanje';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'ponudniki vm izvajalnega okolja baze podatkov statusa';

  @override
  String get statusIsNotLoadedYet => 'Status še ni naložen.';

  @override
  String get stayManagedByYou => 'upravljajte sami.';

  @override
  String get stayOnTheCall => 'Ostanite na klicu';

  @override
  String get stayedQuiet => 'Ostal tiho';

  @override
  String get steering => 'KRMILJENJE';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'KORAK $arg1 OD $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Koraki $arg1';
  }

  @override
  String get stop => 'Ustavi';

  @override
  String get stop2 => 'Ustavi (⌘.)';

  @override
  String get stopManaging => 'Nehajte upravljati';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Prenehati upravljati $arg1?';
  }

  @override
  String get stopRun => 'Nehajte teči';

  @override
  String get stopSpeaking => 'Nehaj govoriti';

  @override
  String get stoppedBeforeCompletion => 'Ustavljeno pred zaključkom';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'StopTelecomCallRouting Napaka: $arg1';
  }

  @override
  String get storage => 'Shranjevanje';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'shranjeni šifrirani in uporabljeni samo za lastne zagone.';

  @override
  String get storedMetrics => 'Shranjene meritve';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Shranjuje samo ključ seje Bitwarden, šifriran na tem strežniku, tako da povezave preživijo ponovne zagone. Zaklenete ga lahko kadar koli.';

  @override
  String get strong => 'Močna';

  @override
  String get strongPassword => 'Močno geslo.';

  @override
  String get subAgent => 'Podzastopnik';

  @override
  String get subagentUpdate => 'Posodobitev podagenta';

  @override
  String get subagentUpdate2 => 'Posodobitev podagenta.';

  @override
  String get successRate => 'Stopnja uspešnosti';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Predlogi: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Povzemite moj zadnji tek';

  @override
  String get supportUrl => 'URL podpore';

  @override
  String get supportedRainStartSnowStartWind =>
      'Podprto: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Preklopni agent';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Simbolične povezave niso dovoljene v poteh NeoAgent Workspace.';

  @override
  String get syncNow => 'Sinhroniziraj zdaj';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'Sistemske nastavitve zasebnosti';

  @override
  String get tableInfoUsers => 'Podatki o tabeli (uporabniki)';

  @override
  String get tagsOnly => 'Samo oznake';

  @override
  String get tasks => 'Naloge';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Opravila tečejo sama od sebe in vam pošiljajo sporočila ';

  @override
  String get teach => 'poučevati';

  @override
  String get teachingInProgress => 'Poučevanje v teku';

  @override
  String get team => 'Ekipa';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Povezave ekip nikoli nikogar ne naredijo skrbnika strežnika. Administratorji vodijo ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Skupinski prostori, sobe, kanali in skupnosti v živo.';

  @override
  String get teamsMessageReceived => 'Prejeto sporočilo ekipe';

  @override
  String get templates => 'Predloge';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Začasne nastavitvene datoteke bodo pozneje očiščene.';

  @override
  String get tenantId => 'ID najemnika';

  @override
  String get testConnection => 'Testna povezava';

  @override
  String get testConnection2 => 'Testna povezava';

  @override
  String get textChat => 'Besedilo in klepet';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'ki so dodali svoj ključ, ga še naprej uporabljajo.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Ta e-poštni naslov že pripada obstoječemu računu. Najprej se prijavite, nato povežite Google v nastavitvah računa.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Ta e-pošta je že povezana z drugim računom.';

  @override
  String get thatQrCodeIsNotA => 'Ta koda QR ni zahteva za prijavo v NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Ta koda QR ni zahteva za seznanjanje NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Ta varnostni ključ je že registriran v tem računu.';

  @override
  String get theAddress => 'Naslov';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Naslov vašega strežnika BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Naslov, ki ga ljudje in ponudniki OAuth uporabljajo za doseganje ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agent bere čase, ki jih omenjate, in izvaja načrtovana opravila v tem časovnem pasu.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agent bo pred vsakim občutljivim orodjem vprašal, ';

  @override
  String get theAgentWillIgnoreThisSkill => 'Agent bo ignoriral to veščino.';

  @override
  String get theAppCouldNotReachThis =>
      'Aplikacija ni mogla doseči te uvedbe NeoAgent. Preverite omrežno povezavo ali potrdite, da je URL storitve pravilen.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Brskalnik je blokiral zahtevo za $arg1 zaradi pravilnika o varnosti vsebine.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Brskalnik je blokiral zahtevano zahtevo zaradi pravilnika o varnosti vsebine.';

  @override
  String get theCloudWorkspace => 'delovni prostor v oblaku';

  @override
  String get theComputerCouldNotStart => 'Računalnik se ni mogel zagnati';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Računalnik potrebuje več prostega prostora na disku na gostitelju NeoAgent. Sprostite nekaj prostora in poskusite znova.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Izvajalno okolje računalnika potrebuje popravilo. Zaženite NeoAgent Doctor in poskusite znova.';

  @override
  String get theConnectionTestFailed => 'Preizkus povezave ni uspel.';

  @override
  String get theDesktopDidNotStart => 'Namizje se ni zagnalo';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Odkriti NeoAgent je vrnil nepopolne podatke o identiteti.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Odkriti NeoAgent uporablja nepodprt namestitveni protokol.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Odkrita storitev ni NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Preneseno izvajalno okolje NeoAgent ni prestalo preverjanja.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Webhook prostora Google Chat, v katerem bi moral ta agent objavljati.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Namestitveni program ni več na voljo.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Interaktivno namizje Linux je na voljo v spletni aplikaciji NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn => 'Uvod ni na voljo v tej napravi.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Najnovejše teče v vsakem računu.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Zadnje sinhronizacijsko okno se je končalo z $arg1 in ni našlo nobenih novih zapisov Health Connect. Spodaj shranjene meritve izvirajo iz prejšnjih sinhronizacij.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Grafična seja Linuxa se ne izvaja.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Govorni model v živo se ni oglasil. Poskusite znova.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Lokalni ukaz NeoAgent se je končal s kodo $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Lokalni ukaz NeoAgent je potekel.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Lokalno izvajalno okolje NeoAgent potrebuje popravilo.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Lokalno izvajalno okolje potrebuje popravilo ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Lokalni uporabniški domači imenik ni na voljo.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'E-poštni račun NeoAgent pošilja potrditve prijave, prijave ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Glavni agent se po potrebi ustvari samodejno.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'V tej izdaji manjka ujemajoče se izvajalno okolje NeoAgent.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Najpomembnejši dohodni webhook, na katerem bi moral ta agent objavljati.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Modeli, med katerimi Smart Selector samodejno usmerja.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Zaledni prenos NeoAgent se ni ujemal z njegovim manifestom.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Zaledni prenos NeoAgent je bil nepopoln.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Zaledje NeoAgent v tem računalniku se ne odziva na vrata ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Zalednega izvajalnega okolja NeoAgent ni bilo mogoče prenesti.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Zaledje NeoAgent je trajalo predolgo, da se je odzvalo za $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Uvedba NeoAgent se je odzvala s HTTP 402 namesto običajnega 401 za neveljavne poverilnice. Preverite povratni proxy, prehod za preverjanje ali pravila v zvezi s plačili na tem strežniku.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Uvedba NeoAgent se je odzvala s HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Uvedba NeoAgent se je odzvala s HTTP 402. Preverite povratni proxy, prehod za preverjanje ali pravila, povezana s plačili, na tem strežniku.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Primerek NeoAgent, s katerim je povezana ta aplikacija.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Storitev izdaje NeoAgent je vrnila neveljavne podatke.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Metapodatki artefakta izvajalnega okolja NeoAgent so neveljavni.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Manifest izvajalnega okolja NeoAgent ni prestal preverjanja podpisa.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Manifest izvajalnega okolja NeoAgent nima artefaktov.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Podpis manifesta izvajalnega okolja NeoAgent je neveljaven.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Geslo, ki ste ga nastavili v BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Ljudje, ki jih vodite, ostanejo z vami.';

  @override
  String get theProviderAnswers => 'odgovarja ponudnik.';

  @override
  String get theQueryReturnedNoRows => 'Poizvedba ni vrnila nobene vrstice.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Zahtevani zaslon namizja ni na voljo.';

  @override
  String get theRest => 'ostalo.';

  @override
  String get theRestEndpointForYourSignal =>
      'Končna točka REST za vaš primerek signal-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'Tek je zaustavljen, dokler ne odgovorite.';

  @override
  String get theRunStartsAtTheScheduled => 'Tek se začne ob predvideni uri.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Izvajalno okolje je lahko namizje Debian Linux s Chromiumom, PCManFM, Mousepad, LXTerminal, Python, Git in standardnimi orodji ukazne vrstice. Njegovo zmogljivost upravlja gostitelj NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Registracije varnostnega ključa ni bilo mogoče začeti.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'strežnik hrani samo njegov prstni odtis.';

  @override
  String get theServerOnThisComputerIs =>
      'Strežnik na tem računalniku ne deluje';

  @override
  String get theServerReportedNoHealthChecks =>
      'Strežnik ni poročal o pregledih zdravja.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Telefonska številka Signal, ki jo uporablja ta bot.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Dohodni webhook Teams, v katerem bi moral ta agent objavljati.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Dvofaktorski izziv je potekel. Ponovno se prijavite.';

  @override
  String get theTwoFactorCodeIsNot => 'Dvofaktorska koda ni veljavna.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Preverjenega izvajalnega paketa ni bilo mogoče označiti kot izvršljivega.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'V preverjenem izvajalnem paketu manjkajo zahtevane datoteke.';

  @override
  String get theWebAppCouldNotReach =>
      'Spletna aplikacija ni mogla doseči zaledja NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Spletna aplikacija ni mogla doseči zaledja NeoAgent na $arg1. Preverite konzolo brskalnika in konfiguracijo povratnega proxyja/omrežja.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'sami; operater strežnika najprej odstrani skrbnika z ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Ti kanali ostanejo tihi. Če jih želite znova slišati, jih dodajte pod Kdo lahko pošilja sporočila za to platformo.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Ti seznami niso obvezni, razen če je zgornji razdelek nastavljen na samo odobreno.';

  @override
  String get thesePeopleAnywhere => 'Ti ljudje kjer koli';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Ti ljudje lahko pošiljajo sporočila $arg1 v zasebnih klepetih in v kateri koli skupini, ki jo delijo.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Ti ljudje lahko pošiljajo sporočila $arg1 ena na ena. To jim ne omogoča, da govorijo v skupinah.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Te osebe lahko pošiljajo sporočila samo $arg1 v skupini, ki ste jo izbrali.';
  }

  @override
  String get thesePeopleInOneGroup => 'Ti ljudje, v eni skupini';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'ta stikala, nikoli vaši klepeti, spomini ali datoteke.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Ta račun bo odklenil NeoAgent na tej napravi.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Ta agent lahko prenese na katerega koli upravičenega sprejemnega agenta.';

  @override
  String get thisAgentIsUsingAServer =>
      'Ta agent uporablja ključ API-ja Trello, ki ga upravlja strežnik. Spodaj morate samo avtorizirati žeton računa.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Tej gradnji ni dovoljeno komunicirati s to uvedbo NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Ta koda pripada drugemu strežniku NeoAgent: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'To namizje je povezano';

  @override
  String get thisDevice => 'Ta naprava';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Ta naprava: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Ta naprava ne more registrirati varnostnih ključev. Odprite NeoAgent v brskalniku prek HTTPS, da ga dodate.';

  @override
  String get thisDeviceUnavailable => 'Ta naprava — ni na voljo';

  @override
  String get thisFileHasNoContent => 'Ta datoteka nima vsebine.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'To skrije \"$arg1\" pred usmerjanjem in izbiro.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Ta integracija trenutno podpira en povezan račun na agenta. Znova odprite nastavitev, da jo zamenjate.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Ta integracija ni več na voljo.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Ta uvod je zasnovan za celozaslonsko ležeče predvajanje.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'To je upravljana uvedba. Njegov operater se izvije ';

  @override
  String get thisMayTakeAMoment => 'To lahko traja nekaj trenutkov.';

  @override
  String get thisMcpServerIsNoLonger => 'Ta strežnik MCP ni več konfiguriran.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Ta pomnilnik bo trajno odstranjen.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Ta zgradba NeoAgent ni konfigurirana za preverjanje zalednih izvajalnih časov.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'To trajno izbriše vse vaše podatke in to ni mogoče ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'S tem se trajno izbriše račun in vse, kar ima v lasti: ';

  @override
  String get thisPersonAnywhere => 'Ta oseba, kjerkoli';

  @override
  String get thisPersonInOneGroup => 'Ta oseba, v eni skupini';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Ta zahteva za prijavo QR je potekla. Ustvarite novo kodo in poskusite znova.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'ta zahteva za prijavo qr je potekla';

  @override
  String get thisQrLoginRequestIsStill =>
      'Ta zahteva za prijavo QR še vedno čaka na odobritev.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Ta zahteva za prijavo QR je bila že uporabljena.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'S tem se odstrani nastavitev domačega pomočnika in povezani primerek za tega agenta.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'S tem se odstrani zaledni URL NeoRecall in vsi povezani računi NeoRecall za tega agenta.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'To odstrani URL Nextcloud in vse povezane račune Nextcloud za tega agenta.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'S tem se odstranijo nastavitev Trello in povezani računi za tega agenta.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'To zahteva overjeno sejo na istem strežniku NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Ta zagon ni povzročil odziva uporabnika.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Ta tek nima zabeleženih podatkov o korakih.';

  @override
  String get thisServer => 'ta strežnik.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Ta strežnik ne poroča o nastavitvah ponudnika.';

  @override
  String get thisSkillIsNoLongerInstalled => 'Ta veščina ni več nameščena.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'To opravilo še ni dokončano, zato se še vedno začne ob ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'To opravilo se bo zagnalo le, ko pritisnete Zaženi zdaj.';

  @override
  String get thisWeek => 'Ta teden';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'To bo uvozilo odgovor v $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'S tem boste odstranili »$arg1«.';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'To bo odstranilo »$arg1« s seznama strežnikov.';
  }

  @override
  String get time => 'Čas';

  @override
  String get timeZone => 'časovni pas';

  @override
  String get timeZone2 => 'Časovni pas';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Časovna omejitev je potekla$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Časovnih pasov ni bilo mogoče navesti: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Ni bilo mogoče prebrati časovnega pasu naprave: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Časovnega pasu naprave ni bilo mogoče shraniti: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'do $arg1';
  }

  @override
  String get toUseTheServerDefault => 'za uporabo privzetega strežnika.';

  @override
  String get today => 'Danes';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Proračun žetonov za @$arg1. Pustite polje prazno ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Proračun žetonov za vsak račun brez lastne preglasitve. Pusti a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'omejitev proračuna žetona uporabnik 4-urne tedenske kvote';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'omejitev proračuna žetona 4-urna tedenska kvota globalno';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Uporaba žetona ni na voljo v tej različici strežnika.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Žetone lahko kateri koli račun uporabi v 4 urah.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Žetone lahko kateri koli račun uporabi v 7 dneh.';

  @override
  String get tokensPerDay => 'Žetoni na dan';

  @override
  String get tokensPerRun => 'Žetoni na tek';

  @override
  String get tokensToday => 'Žetoni danes';

  @override
  String get tokensUsed => ' uporabljenih žetonov';

  @override
  String get tomorrowPrep => 'Jutrišnje priprave';

  @override
  String get tooManyAttempts => 'preveč poskusov';

  @override
  String get tooManySignInAttemptsPlease =>
      'Preveč poskusov prijave. Počakajte in poskusite znova.';

  @override
  String get tool => 'Orodje';

  @override
  String get toolApproval => 'Odobritev orodja';

  @override
  String get toolApprovalRequired => 'Potrebna je odobritev orodja';

  @override
  String get toolCompleted => 'Orodje je dokončano';

  @override
  String get toolFailed => 'Orodje ni uspelo';

  @override
  String get toolPermissions => 'Dovoljenja za orodje';

  @override
  String get toolStarted => 'Orodje se je začelo';

  @override
  String get tools => 'Orodja';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Orodja, ki niso vgrajena v NeoAgent, vključno s povezanimi strežniki MCP in ponudniki orodij po meri.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Ponujena orodja ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Orodja, ki jih lahko uporablja upravljani račun';

  @override
  String get topUsers => 'Najboljši uporabniki';

  @override
  String get topUsersAndRecentRuns =>
      'Najbolj priljubljeni uporabniki in nedavna izvajanja';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Skupaj: žetoni $arg1 v tekih $arg2';
  }

  @override
  String get totalRuns => 'Skupaj tekov';

  @override
  String get totalTokens => 'Skupaj žetonov';

  @override
  String get totalUsers => 'Skupno število uporabnikov';

  @override
  String get transcript => 'Prepis';

  @override
  String get transcript2 => 'PREPIS';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transkripcija ni uspela: $arg1';
  }

  @override
  String get transfer => 'Prenos';

  @override
  String get trelloApiKey => 'Ključ API Trello';

  @override
  String get trelloApiKeyIsRequired => 'Potreben je ključ API-ja Trello.';

  @override
  String get trelloSetup => 'Nastavitev Trello';

  @override
  String get triggerType => 'Vrsta sprožilca';

  @override
  String get tryABroaderSearchLikeModels =>
      'Poskusite s širšim iskanjem, kot so modeli, brskalnik ali glas.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Poskusite z imenom ponudnika, »e-pošta«, »omejitve«, »posodobitev« ali »dnevniki«.';

  @override
  String get tryAgain => 'poskusi ponovno';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Poskusite znova. Če se to ponavlja, zaženite NeoAgent Doctor, da preverite čas izvajanja računalnika.';

  @override
  String get tryAgainInAMoment => 'Poskusite znova čez trenutek.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Poskusite znova ali zaženite NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Poskusite z drugim iskanjem, povežite platformo za sporočanje ali ročno vnesite ID cilja.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Vklopite skupino, če naj $arg1 bere tudi sporočila, ki ga ne označujejo.';
  }

  @override
  String get turnOffComputer => 'Izklopi računalnik';

  @override
  String get turnOffOnlyForAMail =>
      'Izklop samo za poštni strežnik s samopodpisanim potrdilom.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Vklopite, če naj Signal še naprej išče dohodne klepete.';

  @override
  String get turnTaking => 'obračanje';

  @override
  String get turnTakingModel => 'Model na vrsti';

  @override
  String get turnTakingOff => 'Obrat-vzlet';

  @override
  String get turnThisOffToKeepThis =>
      'Izklopite to, da bo ta agent popolnoma ločen od drugih agentov.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Izklopil $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Izklopil $arg1, ki upravlja ta račun. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Za vas izklopil $arg1 — samo oni lahko to spremenijo';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Izklopljeno za vas, zato ga ne morete izročiti';

  @override
  String get twitchChatOverIrc => 'Twitch klepet prek IRC';

  @override
  String get twoFactorAuthentication => 'Dvostopenjska avtentikacija';

  @override
  String get twoFactorChallengeExpired => 'dvofaktorski izziv je potekel';

  @override
  String get twoFactorCode => 'dvofaktorska koda';

  @override
  String get twoFactorSignInCompletedBut =>
      'Dvostopenjska prijava je končana, vendar NeoAgent ni mogel obdržati seje brskalnika. Prosimo, prijavite se znova.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Prijava v dveh korakih (samo če je omogočena)';

  @override
  String get type => 'Vrsta';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Za potrditev vnesite $arg1';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'vrsta besedila ni podprta na tej platformi.';

  @override
  String get typedInTheBrowser => 'Vtipkano v brskalnik';

  @override
  String get typedText => 'Tipkano besedilo';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'ni mogoče najti izvajalnega okolja java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Ni mogoče odpreti časovnih nastavitev v tej zgradbi.';

  @override
  String get unableToOpenWiFiSettings =>
      'V tej zgradbi ni mogoče odpreti nastavitev Wi-Fi.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Izbranega zaslona namizja ni mogoče ohraniti.';

  @override
  String get unclearWhoItWasFor => 'Ni jasno, za koga je šlo';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'razveljavljeno. Vnesite svoje uporabniško ime za potrditev.';

  @override
  String get unknownAccount => 'Neznan račun';

  @override
  String get unknownAgent => 'Neznani agent';

  @override
  String get unknownBrowser => 'Neznan brskalnik';

  @override
  String get unknownDevice => 'Neznana naprava';

  @override
  String get unknownError => 'neznana napaka';

  @override
  String get unknownLocalComputerPermission =>
      'Neznano dovoljenje za lokalni računalnik.';

  @override
  String get unknownLocation => 'Neznana lokacija';

  @override
  String get unknownPublishTime => 'Neznan čas objave';

  @override
  String get unknownSize => 'Neznana velikost';

  @override
  String get unlink => 'Prekini povezavo';

  @override
  String get unreadOnly => 'Samo neprebrano';

  @override
  String get unsavedChanges => 'Neshranjene spremembe';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Nepodprt spremljevalni ukaz namizja: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Nepodprta metoda: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Nenavadna opozorila ob prijavi';

  @override
  String updateArg1(Object? arg1) {
    return 'Posodobite $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Posodobite vnose osnovnega pomnilnika iz uvoza.';

  @override
  String get updateNow => 'Posodobite zdaj';

  @override
  String get updateReady => 'Posodobitev pripravljena';

  @override
  String get updateSetup => 'Posodobi nastavitev';

  @override
  String get updateTheAccessListToAllow =>
      'Posodobite seznam dostopov, da omogočite odgovore.';

  @override
  String get updateTheServer => 'Posodobiti strežnik?';

  @override
  String get updateTheServer2 => 'Posodobite strežnik';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Samodejno posodobite časovni pas iz naprave, ki jo uporabljate.';

  @override
  String updatedArg1(Object? arg1) {
    return 'posodobljen $arg1';
  }

  @override
  String get updates => 'Posodobitve';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Posodobitve niso konfigurirane za to zgradbo.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'posodobitve, tako da samoposodabljanje in spreminjanje kanalov tukaj ni.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'posodobitev nadgradnje zdaj izdaja stabilno beta različico kanala';

  @override
  String get usageAnalytics => 'Analitika uporabe';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Signali o uporabi in zdravju, ki pomagajo razložiti trenutno vedenje med izvajanjem, ne da bi najprej kopali po dnevnikih.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Uporaba se popolnoma ponastavi v $arg1';
  }

  @override
  String get usageLeaderboard => 'uporaba lestvice najboljših';

  @override
  String get usageLimits => 'Uporaba in omejitve';

  @override
  String get usageLimits2 => 'Uporaba in omejitve';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Uporabite 8+ znakov. Daljša gesla dobro delujejo.';

  @override
  String get useADateAndTimeFor =>
      'Uporabite datum in uro, na primer 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Uporabite ime, telefonsko številko ali ID klepeta.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Uporabite URL NeoRecall, ki ga lahko doseže strežnik NeoAgent. NeoAgentov PUBLIC_URL mora biti prav tako dosegljiv iz tega brskalnika za povratni klic OAuth.';

  @override
  String get useANewPasswordWithAt => 'Uporabite novo geslo z vsaj 8 znaki.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Uporabite URL Nextcloud, ki ga lahko doseže strežnik NeoAgent, na primer https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast => 'Uporabite geslo z vsaj 8 znaki.';

  @override
  String get useASecureConnectionTls => 'Uporabite varno povezavo (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Uporabite aplikacijo za preverjanje pristnosti, kot je Authy, 1Password ali Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Uporabite vsaj 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Največji pomnilnik na računalnik (MB)';

  @override
  String get maxVcpusPerComputer => 'Največ vCPU-jev na računalnik';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Vsaj $arg1. Računalniki dobijo manj, ko je gostitelj zaseden.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Največji pomnilnik mora biti vsaj $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Uporabite vsaj 8 znakov.';

  @override
  String get useDefault => 'Uporabi privzeto';

  @override
  String get useDefaultChannel => 'Uporabi privzeti kanal';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Uporabi privzeto (NeoAgent Workspace)';

  @override
  String get useFor => 'Uporabite za';

  @override
  String get useManualDestination => 'Uporabi ročni cilj';

  @override
  String get useOrDoTheSameFor =>
      'uporabite ali storite enako za svoje soigralce.';

  @override
  String get usePerCategorySettingsBelow =>
      'Uporabite spodnje nastavitve za posamezne kategorije.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Uporabi privzete nastavitve ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Uporabite strežnik na tem računalniku';

  @override
  String get useTheseForContextIfA =>
      'Uporabite jih za kontekst. Če lokalni URI ni neposredno dostopen s strežnika, me prosite, naj zagotovim datoteko prek dostopnega delovnega prostora.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Uporabite to za orkestrske agente. Opustite izolirane delovne bote, ki bi morali sami dokončati neposredna sporočila.';

  @override
  String get useTlsFromTheStartOf =>
      'Uporabite TLS od začetka povezave, običajno na vratih 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Uporabite svoj ključ API za ponudnika ali povežite prilagojenega ';

  @override
  String get usedByEveryAccountOnThis =>
      'Uporablja ga vsak račun na tem strežniku, ki nima ključa ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Uporablja se za preverjanje, ali so dohodni dogodki Slack pristni.';

  @override
  String get userSummary => 'Uporabniški povzetek';

  @override
  String get username => 'Uporabniško ime';

  @override
  String get usernameOrEmail => 'Uporabniško ime ali e-pošta';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'uporabniki ljudje iskanje e-pošta uporabniško ime skrbniška značka upravljana ekipa';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Uporablja model klepeta, konfiguriran v nastavitvah';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Uporaba nameščenega izvajalnega okolja NeoAgent';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Običajno izgleda kot @bot:matrix.org';

  @override
  String get validEmail => 'veljaven email';

  @override
  String get value => 'Vrednost';

  @override
  String get vaultLocked => 'Trezor zaklenjen';

  @override
  String get vaultOperationFailed => 'Operacija trezorja ni uspela.';

  @override
  String get verification => 'Preverjanje';

  @override
  String verificationArg1(Object? arg1) {
    return 'Preverjanje: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'preverjanje: $arg1';
  }

  @override
  String get verificationCompleted => 'Preverjanje končano.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Stanje preverjanja: $arg1';
  }

  @override
  String get verifiedTheResult => 'Preverjen rezultat';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Preverjanje prenesenega izvajalnega okolja';

  @override
  String get versionAndUptime => 'Različica in čas delovanja';

  @override
  String versionArg1(Object? arg1) {
    return 'Različica $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Različica $arg1 je nameščena, vendar se $arg2 še vedno izvaja.';
  }

  @override
  String get videoLinks => 'Video povezave';

  @override
  String get viewDesktop => 'Ogled namizja';

  @override
  String get viewLastRun => 'Oglejte si zadnjo vožnjo';

  @override
  String get viewLogs => 'Ogled dnevnikov';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm slikovni pomnilnik cpu qemu runtime';

  @override
  String get voice => 'Glas';

  @override
  String get voiceAssistant => 'Glasovni pomočnik';

  @override
  String get voiceCall => 'GLASOVNI KLIC';

  @override
  String get voiceCall2 => 'Glasovni klic';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'glasovni klic gpt-live gemini live model govor v realnem času';

  @override
  String get voiceCallsRunOnALive =>
      'Glasovni klici potekajo po modelu govora v govor v živo z isto osebnostjo, spominom in zgodovino klepeta kot NeoAgent. Odgovori takoj in pravo delo preda običajnemu agentu, ki še naprej teče v ozadju.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'ključ api za prepis govora glasovne beležke';

  @override
  String get voiceNotesAndDictation => 'Glasovne beležke in nareki';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Glasovno predvajanje v tej napravi ni na voljo.';

  @override
  String get voiceReplyModel => 'Model glasovnega odgovora';

  @override
  String get waitingForApproval => 'Čakanje na odobritev: ';

  @override
  String get waitingForCode => 'Čakam na kodo';

  @override
  String get waitingForInput => 'Čakanje na vnos';

  @override
  String get waitingForServerOrFlutterLog =>
      'Čakanje na izpis strežnika ali dnevnika Flutter ...';

  @override
  String get waitingForTaskEvents => 'Čakanje na dogodke opravil ...';

  @override
  String get waitingForYou => 'čaka nate';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Želel sem odgovor od $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Želi govoriti z vami · ${arg1}s';
  }

  @override
  String get weak => 'Šibko';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Vreme, koledar in prednostne naloge pred začetkom dneva.';

  @override
  String get weatherEvent => 'Vremenski dogodek';

  @override
  String get web => 'Splet';

  @override
  String get webBrowser => 'Spletni brskalnik';

  @override
  String get webSearchApiKey => 'ključ API za spletno iskanje';

  @override
  String get webhookOrRestChannelPosting => 'Webhook ali objava kanala REST';

  @override
  String get webhookSecret => 'Webhook skrivnost';

  @override
  String get webhookUrlCopied => 'URL Webhook je kopiran';

  @override
  String get weekdays => 'Delovni dnevi';

  @override
  String get weekdays0730 => 'Ob delavnikih · 07:30';

  @override
  String get weekdays1800 => 'Delovniki · 18:00';

  @override
  String get weekly => 'Tedensko';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Tedenska omejitev $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Tedenska omejitev (žetoni)';

  @override
  String get weeklyReview => 'Tedenski pregled';

  @override
  String get weeklyUsage => 'Tedenska poraba';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Zapisi teže $arg1';
  }

  @override
  String get welcomeToNeoagent => 'DOBRODOŠLI V NEOAGENTU';

  @override
  String get welcomeToNeoagent2 => 'Dobrodošli\nv NeoAgent';

  @override
  String get whatAreYouAdding => 'Kaj dodajate?';

  @override
  String get whatIsOnTomorrow => 'Kaj bo jutri?';

  @override
  String get whatShouldNeoagentLearn => 'Kaj naj se nauči NeoAgent?';

  @override
  String get whatShouldWeBuild => 'Kaj naj zgradimo?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Kar poveste vi in ​​NeoAgent, se prikaže tukaj in v klepetu.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Prejeto osebno sporočilo WhatsApp';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Ko izberete samo odobreno, spodaj dodajte osebe ali skupine.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Kam naj ta agent pošlje odgovore.';

  @override
  String get whoCanMessage => 'Kdo lahko pošlje sporočilo';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Kdo lahko pošilja sporočila na $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Kdo lahko pošlje $arg1 sporočilo ena na ena.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Kdo se lahko pogovarja z $arg1 v skupini, kanalu ali sobi.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'kdo upravlja ta račun je izklopljen: ';

  @override
  String get whoManagesWhom => 'Kdo koga upravlja';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Kdorkoli sprejme povezavo, se pridruži vaši ekipi samo z orodji, ki jih ima ';

  @override
  String get wholeGroup => 'Cela skupina';

  @override
  String get wholeGroups => 'Cele skupine';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Zakaj je $arg1 odgovoril ali molčal v skupinah $arg2.';
  }

  @override
  String get windowsApp => 'Aplikacija Windows';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'Delovni račun';

  @override
  String get workOnAProjectWithNeoagent => 'Delajte na projektu z NeoAgentom';

  @override
  String workflowArg1(Object? arg1) {
    return 'Potek dela: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Delo v $arg1 na računalniku v oblaku. NeoAgent tam bere in ureja datoteke ter lahko izvaja ukaze in brskalnik.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Delo v ozadju: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Konfiguracija delovnega prostora in varnost računa na enem mestu.';

  @override
  String get workspaceFiles => 'Datoteke delovnega prostora';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Delovni prostor, modeli in diagnostični kontrolniki.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Preglasitev delovnega prostora mora biti absolutna pot.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Napisal $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'napaka xmlhttprequest';

  @override
  String get yesterday => 'včeraj';

  @override
  String get youAreInControl => 'Vi imate nadzor';

  @override
  String get youCanFollowAlongOnThe => 'Sledite lahko na namizju.';

  @override
  String get youCanLeaveATeamAt =>
      'Ekipo lahko zapustite kadar koli; ponovno veljajo vaše nastavitve.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Na strani ekipe lahko kadar koli odidete.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Vi se odločite, katera orodja lahko uporablja vaš agent, v nastavitvah › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Še nikogar ne upravljate. Ustvarite spodnjo povezavo za povabilo in ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Imate neshranjene nastavitve. Kaj bi rad počel?';

  @override
  String get youReOnYourOwnYou =>
      'Sami ste: sami se odločite, katera orodja lahko uporablja vaš agent. če ';

  @override
  String get yourAccountAndUsageOnA =>
      'vaš račun -- in uporabo na modelu, ki ga podpira vaš lastni ključ ';

  @override
  String get yourAccountHasBeenDeleted => 'Vaš račun je bil izbrisan.';

  @override
  String get yourAgentWillBeAllowed => 'Vašemu agentu bo dovoljeno:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Vaše aplikacije in datoteke so shranjene.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Vaše aplikacije in datoteke ostanejo shranjene.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Vaš ključ $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Vaš pomočniški sloj za zajem, kontekst in dejanje.';

  @override
  String get yourComputerIsAsleep => 'Vaš računalnik spi';

  @override
  String get yourComputerIsOff => 'Vaš računalnik je izklopljen';

  @override
  String get yourComputerIsReady => 'Vaš računalnik je pripravljen';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Vaše trenutno geslo ni pravilno.';

  @override
  String get yourData => 'Vaši podatki';

  @override
  String get yourDataExportWasCopiedTo =>
      'Vaš izvoz podatkov je bil kopiran v odložišče.';

  @override
  String get yourDesktopIsReady => 'Vaše namizje je pripravljeno';

  @override
  String get yourLinuxComputer => 'Vaš računalnik z Linuxom';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Vaša lokacija se nikoli ne spremlja neprekinjeno ali shranjuje na naših strežnikih. Uporabljamo ga samo lokalno za preverjanje vaših aktivnih nalog.';

  @override
  String get yourManager => 'vaš vodja';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Vaš najpomembnejši URL spletnega mesta, če uporabljate REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Vaša seja je potekla ali pa je brskalnik ni ohranil. Prosimo, prijavite se znova.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Vaša seja je potekla. Prosimo, prijavite se znova.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Vaše uporabniško ime ali geslo ni pravilno.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID, …';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Osebno';

  @override
  String get sectionOverview => 'Pregled';

  @override
  String get sectionDiagnostics => 'Diagnostika';

  @override
  String get sectionVolume => 'Glasnost';

  @override
  String get sectionSession => 'Seja';

  @override
  String get sectionDeliverable => 'Dostavljivo';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Lokalno izvajalno okolje še ni napisalo datoteke dnevnika.';

  @override
  String get thisComputer => 'Ta računalnik';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta namesti najnovejšo predizdajno zaledje. Pričakujte grobe robove.';

  @override
  String get copiedFinalResponse => 'Kopiran končni odgovor';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Končni odgovor se prikaže tukaj, ko se tek konča.';

  @override
  String get waitingForTheFirstStep => 'Čakanje na prvi korak …';

  @override
  String get loadingPrompt => 'Nalaganje poziva …';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Za to vožnjo ni bil zajet končni odgovor.';

  @override
  String get readyToSignIn => 'Pripravljen za prijavo';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Preklopite na »Privzeto« ali »Vedno vprašaj«, da znova omogočite preverjanje odobritve.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Pošljite posodobitev krmiljenja ali naslednjo opombo za trenutno vožnjo ...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Ni omrežne povezave. NeoAgent se bo znova povezal, ko bo naprava spet povezana.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Za trenutno vožnjo je bila uporabljena najnovejša posodobitev krmiljenja.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Priprava zasebne glasovne seje ...';

  @override
  String get preparingYourComputer => 'Priprava vašega računalnika';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent prenaša in pripravlja varen sistem Linux. To se zgodi le prvič.';

  @override
  String get moreFreeSpaceIsNeeded => 'Potrebno je več prostega prostora';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Sprostite nekaj prostora na disku na gostitelju NeoAgent in poskusite znova. Vaši obstoječi računalniški podatki so varni.';

  @override
  String get androidReady => 'Android pripravljen';

  @override
  String get startingAndroid2 => 'Zagon Androida …';

  @override
  String get androidStopped => 'Android se je ustavil';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Prvi zagon prenese Android SDK in sliko sistema, kar lahko traja nekaj minut.';

  @override
  String get androidIsStopped => 'Android je ustavljen';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Zaženite upravljano okolje Android, ko ga potrebujete.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Naj NeoAgent deluje na tem računalniku';

  @override
  String get firstTimeSetupIsInProgress => 'Poteka prva nastavitev.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent lahko uporablja dostop, ki ga dovolite.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Sprostite nekaj gostiteljskega prostora za shranjevanje in poskusite znova.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Začnite, ko želite, da vam NeoAgent pomaga.';

  @override
  String get systemPermissionMissing => 'Manjka sistemsko dovoljenje';

  @override
  String get connectingThisDevice => 'Povezovanje te naprave';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Vzpostavlja se varna lokalna povezava.';

  @override
  String get recordingYourDemonstration => 'Snemanje vaše demonstracije';

  @override
  String get noErrorsInTheRecentLog => 'V nedavnem dnevniku ni napak.';

  @override
  String get loadingAccounts => 'Nalaganje računov …';

  @override
  String get neverSignedIn => 'Nikoli prijavljen';

  @override
  String get emptyUsesTheServerDefault =>
      'Prazno uporablja privzeto nastavitev strežnika.';

  @override
  String get followTheSelectedSession => 'Sledite izbrani seji';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Način načrtovanja samo pregleduje. Preklopite v agentski način, da NeoAgentu omogočite urejanje datotek.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Zahtevano za dodajanje ali spreminjanje e-pošte računa.';

  @override
  String get confirmNewPassword => 'Potrdite novo geslo';

  @override
  String get passwordChanged => 'Geslo spremenjeno.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Ta zahteva je bila že uporabljena.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Ta zahteva je potekla. Prosite drugo napravo, naj ustvari novo kodo.';

  @override
  String get startQuickstart => 'Zaženi Quickstart';

  @override
  String get createYourAccount => 'Ustvarite svoj račun';

  @override
  String get showWorkAsSummaries => 'Pokažite delo kot povzetke';

  @override
  String get tokensUsedByTheLatestRun =>
      'Žetoni, ki jih uporablja zadnji zagon';

  @override
  String get listedTheWorkspaceRoot => 'Naveden je koren delovnega prostora';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Uradne integracije še niso na voljo.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Noben strežnik MCP še ni konfiguriran. Dodajte enega, da razkrijete njegova orodja.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Za začetek dodajte strežnik MCP ali namestite veščino.';

  @override
  String get setUp => 'Nastavite';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Pustite prazno, da ohranite shranjeno vrednost';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'S tem se odstrani naslov za vsak račun na tem strežniku.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Samo govori. Prekinete lahko kadarkoli. Tapnite za izklop zvoka.';

  @override
  String get tapAgainWhenYouAreDone => 'Ko končate, znova tapnite.';

  @override
  String get workingOnATaskInTheBackground => 'Delo na nalogi v ozadju.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Pretvorba govora v govor z enakim pomnilnikom, orodji in zgodovino klepeta kot NeoAgent.';

  @override
  String get checkLink => 'Preverite povezavo';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Vašemu agentu ne bodo dovoljena nobena nadzorovana orodja.';

  @override
  String get notYoursToChange => 'Ni tvoje, da se spreminjaš';

  @override
  String get setByYou => 'Nastavite vi';

  @override
  String get noTools => 'Brez orodja';

  @override
  String get untitledLink => 'Povezava brez naslova';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Neha delovati, ko ga ena oseba unovči.';

  @override
  String get theOperator => 'Operater';

  @override
  String get smartSelectorOn => 'Pametni izbirnik vklopljen';

  @override
  String get startASessionToBegin => 'Za začetek zaženite sejo';

  @override
  String get steerTheActiveRun => 'Vodite aktivni tek…';

  @override
  String get describeWhatToPlan => 'Opišite, kaj načrtovati ...';

  @override
  String get stopDictation => 'Prenehajte z narekom';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Sporočila usmerjajo trenutni tek · ⌘↵ pošlji · ⌘. stop';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Način načrtovanja samo pregleduje; nič se ne spremeni, dokler ne implementirate · ⌘↵ pošlji';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agent ureja delovni prostor. Plan samo pregleduje.';

  @override
  String get defaultModel => 'Privzeti model';

  @override
  String get openingScanner => 'Odpiranje skenerja ...';

  @override
  String get theAgentCanUseThisSkill => 'Agent lahko uporabi to veščino.';

  @override
  String get allSelected => 'Vse izbrano';

  @override
  String get addCoreMemoryEntry => 'Dodaj vnos Core Memory';

  @override
  String get channelId => 'ID kanala';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Naloge, ustvarjene z umetno inteligenco, in nedoločene naloge uporabljajo trenutno privzeto vrednost.';

  @override
  String get waitingForRunEvents => 'Čakanje na tekaške dogodke ...';

  @override
  String get hideSteps => 'Skrij korake';

  @override
  String get commitTheActiveLiveCapture => 'Izvedite aktivni zajem v živo';

  @override
  String get stopCaptureAndSubmit => 'Ustavi zajemanje in predloži';

  @override
  String get clickTheMicToStartSpeaking =>
      'Kliknite mikrofon, da začnete govoriti';

  @override
  String get connectACustomEndpoint => 'Povežite končno točko po meri';

  @override
  String get hostedProvider => 'gostujoči ponudnik.';

  @override
  String get muted => ' • utišan';

  @override
  String get addWhoCanMessage => 'Dodajte osebe, ki lahko pošiljajo sporočila';

  @override
  String get joinsGroupConversations => 'Pridruži se skupinskim pogovorom';

  @override
  String get label1PersonOrGroupAdded => 'Dodana je 1 oseba ali skupina';

  @override
  String get inProgress => 'V teku';

  @override
  String get waitingForUpdateJobOutput =>
      'Čakanje na izpis opravila posodobitve ...';

  @override
  String get taskTrigger => 'Sprožilec opravila';

  @override
  String get bearerToken => 'Prinosniški žeton';

  @override
  String get bearerToken2 => 'Žeton nosilca';

  @override
  String get notRecorded => 'Ni zabeleženo';

  @override
  String get sessionCookie => 'Sejni piškotek';

  @override
  String get neverUsed => 'Nikoli uporabljen';

  @override
  String get linkedRecently => 'Nedavno povezano';

  @override
  String get notUsedYet => 'Še ni uporabljen';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Eden ali več računov je poteklo. Znova se povežite, da obnovite dostop. Če se to ponavlja, je vaša aplikacija Google Cloud OAuth morda v načinu testiranja – objavite jo v produkciji v konzoli Google Cloud Console, da pridobite dolgožive žetone.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Trezor je povezan in na voljo po ponovnem zagonu';

  @override
  String get vaultConnectedForThisSession => 'Trezor je povezan za to sejo';

  @override
  String get connectAnotherAccount => 'Povežite drug račun';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Prilepite nadomestni dolgoživ dostopni žeton';

  @override
  String get updateInstance => 'Posodobi primerek';

  @override
  String get pasteAReplacementToken => 'Prilepite nadomestni žeton';

  @override
  String get replaceAccount => 'Zamenjaj račun';

  @override
  String get addAccount => 'Dodaj račun';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Lahko prenese na katerega koli sprejemnega agenta';

  @override
  String get canReceiveDelegatedTasks2 => 'lahko prejemajo dodeljene naloge';

  @override
  String get noSyncYet => 'Še ni sinhronizacije';

  @override
  String get noNewData => 'Ni novih podatkov';

  @override
  String get syncOnceToSeedYourBackend =>
      'Sinhronizirajte enkrat, da zaženete svoje zaledje.';

  @override
  String get lastWindowEndIsUnknown => 'Konec zadnjega okna ni znan.';

  @override
  String get lastNonEmptySync => 'Zadnja neprazna sinhronizacija';

  @override
  String get stopTranscribe => 'Ustavi in prepiši';

  @override
  String get steeringMode => 'Način krmiljenja';

  @override
  String get noMessageText => 'Ni besedila sporočila';

  @override
  String get reconnectingToServer => 'Ponovna povezava s strežnikom …';

  @override
  String get signingIn => 'Prijava ...';

  @override
  String get noGroupsFoundYet => 'Ni še nobene skupine';

  @override
  String get onForNewGroupsOnly => 'Vklopljeno samo za nove skupine';

  @override
  String get noGroupsInThisCategory => 'V tej kategoriji ni skupin';

  @override
  String get groupOrChannel => 'Skupina ali kanal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Opombe, ki si jih napišete, začnejo teči, odgovori pa pristanejo v istem klepetu. Seznam dovoljenih tukaj ne velja.';

  @override
  String get needToReply => 'Treba je odgovoriti';

  @override
  String get enter2faCode => 'Vnesite kodo 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Odprite aplikacijo za preverjanje pristnosti in vnesite trenutno kodo NeoAgent.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Že imate račun? Prijavite se';

  @override
  String get serverOnThisComputer => 'Strežnik na tem računalniku';

  @override
  String get showQrCode => 'Prikaži kodo QR';

  @override
  String get createAnotherNeoagentAccount => 'Ustvarite nov račun NeoAgent.';

  @override
  String get canCoordinateDelegatedWork => 'Lahko koordinira delegirano delo';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Arhiva izvajalnega okolja NeoAgent ni bilo mogoče ekstrahirati.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Arhiva izvajalnega okolja NeoAgent ni bilo mogoče prebrati.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Arhiv izvajalnega okolja NeoAgent vsebuje nevarno pot.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Arhiv izvajalnega okolja NeoAgent vsebuje nevarno povezavo.';

  @override
  String get installingAppPackageOnThePhone =>
      'Nameščanje paketa aplikacij na telefon ...';

  @override
  String get dragAndDropAApkOrApks =>
      'Sem povlecite in spustite datoteko .apk ali .apks ali kliknite za brskanje.';

  @override
  String get releaseToInstallThisPackage => 'Spustite, da namestite ta paket';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Varnostnega ključa ni bilo mogoče uporabiti.';

  @override
  String get connecting => 'Povezovanje ...';

  @override
  String get changes => 'Spremembe';

  @override
  String get runtimeReady => 'Runtime pripravljen';

  @override
  String get saving => 'Shranjevanje ...';

  @override
  String get earlier => 'Prej';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'feb';

  @override
  String get monthMar => 'marec';

  @override
  String get monthApr => 'apr';

  @override
  String get monthMay => 'maja';

  @override
  String get monthJun => 'jun';

  @override
  String get monthJul => 'jul';

  @override
  String get monthAug => 'avg';

  @override
  String get monthSep => 'sept';

  @override
  String get monthOct => 'okt';

  @override
  String get monthNov => 'nov';

  @override
  String get monthDec => 'dec';

  @override
  String get steeringWord => 'Krmiljenje';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'To preklopi zaledje s kanala $arg1 na kanal $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Uvoženi piškotki $arg1';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'Pred $arg1';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Krmiljenje v čakalni vrsti: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Spletna aplikacija ni mogla doseči zaledja NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Brskalnik je blokiral zahtevano zahtevo zaradi pravilnika o varnosti vsebine.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 od 4 dovoljenih';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Nalogo opravite kot običajno.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Spremembe · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Ta naprava · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Omejitev je dosežena$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Obnovitvene kode $arg1 so še vedno na voljo.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Varnostni ključ $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Trenutna seja';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nNazadnje uporabljeno: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Delo v $arg1 na tej napravi. NeoAgent neposredno bere in ureja mapo ter lahko izvaja ukaze, odpira aplikacije in uporablja zaslon.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Delal za $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Dovoljeno z $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1 povabilne povezave od $arg2 so bile preklicane';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Dodajte osebe in skupine, s katerimi naj se $arg1 pogovarja';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Dodajte osebe in skupine, s katerimi se lahko $arg1 pogovarja.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Kjer $arg1 posluša';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 opazuje ta mesta za omembe. Vsakdo lahko objavlja tukaj, zato ljudje še vedno potrebujejo lastno odobritev spodaj.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Ti ljudje lahko vprašajo $arg1, kjer koli ga označijo. Vloge štejejo samo na zgoraj navedenih mestih.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Samo, ko je $arg1 označen';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Vklopljeno za vse skupine $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 še vedno sliši samo osebe in skupine, ki ste jih že odobrili. To samo omogoča, da se $arg1 tam pridruži običajnemu klepetu, ne le oznakam in odgovorom.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 še vedno sliši samo osebe in skupine, ki ste jih že odobrili. To samo izbere, kateri od teh skupin naj se pridruži.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Če nekdo označi $arg1 ali odgovori, $arg1 vedno odgovori. Vklopite to, če bi se moral $arg1 oglasiti tudi v običajnem skupinskem klepetu.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Nove skupine bodo dovolile, da se $arg1 pridruži navadnemu klepetu z odobrenimi osebami, dokler jih ne izklopite.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Nove skupine bodo dovolile, da se $arg1 pridruži navadnemu klepetu, dokler jih ne izklopite.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Nove skupine ostanejo tihe, razen če odobrena oseba ne označi $arg1, dokler jih ne vklopite.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Samo ko odobrena oseba označi $arg1, razen če vklopite skupino';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Samo ko je $arg1 označen, razen če vklopite skupino';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 skupin $arg2 se pridruži navadnemu klepetu z odobrenimi ljudmi';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'To ne odobrava novih ljudi. Oznake in odgovori odobrenih oseb vedno dobijo odgovor. Vklopite skupino, če bi se $arg1 tam pridružil tudi navadnemu klepetu.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'To ne odobrava novih ljudi. Vklopite skupino, če se $arg1 želi pridružiti navadnemu klepetu z osebami, ki ste jih že odobrili.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Oznake in odgovori vedno dobijo odgovor. Vklopite skupino, če bi se $arg1 tam pridružil tudi navadnemu klepetu.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 se pridruži navadnemu klepetu z odobrenimi ljudmi';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 se lahko pridruži navadnemu klepetu';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 odgovori samo, ko ga odobri odobrena oseba';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Nič dodatnega ni potrebno. Povežite se, da začnete uporabljati $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Osveži v ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Registrirajte se pri $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Ni spominov, povezanih z \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (privzeto)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Podružnica: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 se pridruži samo skupinam in kanalom, ki jih dodate spodaj.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 je potreben za iskanje podatkov o času izvajanja NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[skrajšan predogled, skupaj $arg1 bajtov]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[omejen artefakt, skupaj $arg1 bajtov]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' v $arg1';
  }

  @override
  String get worldNews => 'Svetovne novice';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Zaženite, ko se pojavijo novi svetovni naslovi. Vaš poziv se odloči, ali vas bo obvestil.';

  @override
  String get newsKeywordsOptional => 'Ključne besede (neobvezno)';

  @override
  String get worldNewsSetup => 'Nastavitev svetovnih novic';

  @override
  String get connectWorldNewsWithGnews =>
      'Dodajte ključ GNews API (brezplačen načrt je na voljo na gnews.io). Shranjuje se šifrirano in se uporablja za anketiranje najbolj priljubljenih naslovov za sprožilce svetovnih novic.';

  @override
  String get gnewsApiKey => 'Ključ GNews API';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Prilepite nadomestni ključ GNews API';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Pustite ključ prazen, da obdržite trenutno shranjen ključ.';

  @override
  String get gnewsApiKeyIsRequired => 'Potreben je ključ GNews API.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Ni bilo mogoče shraniti nastavitve Svetovnih novic.';

  @override
  String get disconnectWorldNews => 'Prekini povezavo Svetovne novice';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'S tem se odstrani shranjeni ključ GNews API. Sprožilci Svetovnih novic se bodo prenehali sprožati, dokler znova ne dodate ključa.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Povezave s svetovnimi novicami ni bilo mogoče prekiniti.';

  @override
  String get systemOneModels => 'Modeli SystemOne';

  @override
  String get systemOneAuto => 'Avto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Izbere najboljši razpoložljivi model SystemOne';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Model klepeta sprejema te odločitve';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Modeli odločanja, ki opravijo klice v zakulisju v delčku sekunde: menjava skupinskega klepeta in koraki brskalnika. Vaš model klepeta še vedno napiše vsak odgovor.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Model SystemOne se odloči, kdaj bo govoril, ko je vklopljen; ta model je rezerva.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 zadel SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne je neposredno ocenil to sporočilo. Noben jezikovni model ni deloval.';

  @override
  String get systemOneUnavailable => 'SystemOne ni na voljo';

  @override
  String get systemOneAdminAvailability =>
      'Odločitvene modele lahko agenti izberejo pod Nastavitve › Modeli. Model, ki je tukaj izklopljen, zapusti ta izbirnik, agenti, ki so ga izbrali, pa se vrnejo na Auto. Medtem ko je kateri koli model izklopljen, se začnejo izklopiti tudi modeli SystemOne, ki jih ponudniki dodajo pozneje.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Modelov SystemOne še ni. Dodajte ključ TypeSafe ali OpenRouter pod Ponudniki ali povlecite model odločanja, kot je nimble v Ollami 0.35 ali novejši.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Noben model SystemOne še ni na voljo. Dodajte ključ TypeSafe ali OpenRouter pod Nastavitve › Modeli › Prinesite svoj ključ ali povlecite model odločanja, kot je nimble v Ollami.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone sistem z eno odločitvijo modeli jev typesafe openrouter ollama razpoložljivost omogoči onemogoči';

  @override
  String get chatModels => 'Klepetalni modeli';

  @override
  String get disabled => 'Onemogočeno';

  @override
  String get enableShown => 'Omogoči prikazano';

  @override
  String get disableShown => 'Onemogoči prikazano';

  @override
  String get expandAll => 'Razširi vse';

  @override
  String get collapseAll => 'Strni vse';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 neshranjene spremembe';
  }

  @override
  String get settingsScopeAllAgents => 'Vsi agenti';

  @override
  String get settingsScopeAgent => 'Ta agent';

  @override
  String get settingsScopeApp => 'aplikacija';

  @override
  String get settingsScopeAccountHint => 'Enako povsod, kjer se prijavite';

  @override
  String get settingsScopeAllAgentsHint => 'Delijo vsi vaši agenti';

  @override
  String get settingsAppliesTo => 'Velja za';

  @override
  String get settingsSaving => 'Shranjevanje ...';

  @override
  String get settingsSavedAutomatically => 'Spremembe se samodejno shranijo';

  @override
  String get settingsSearchHint => 'Iskanje vseh nastavitev';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Prijava in varnost';

  @override
  String get settingsPageUsage => 'Uporaba';

  @override
  String get settingsPagePermissions => 'Dovoljenja';

  @override
  String get settingsPageComputer => 'Računalnik in splet';

  @override
  String get settingsPageBehavior => 'Vedenje';

  @override
  String get settingsPageSystem => 'Sistem';

  @override
  String get settingsPagePlatforms => 'Platforme';

  @override
  String get settingsPageProfileDescription =>
      'Vaše ime in e-pošta, kopija vaših podatkov in odjava.';

  @override
  String get settingsPageSecurityDescription =>
      'Geslo, dvostopenjsko preverjanje pristnosti, varnostni ključi in kje ste prijavljeni.';

  @override
  String get settingsPageUsageDescription =>
      'Vaše omejitve in žetonska poraba, vse na enem mestu.';

  @override
  String get settingsPageAgentsDescription =>
      'Ustvarite agente in izberite, kateri odgovarja privzeto.';

  @override
  String get settingsPagePermissionsDescription =>
      'Kaj lahko storijo vaši agenti, ne da bi vas prej vprašali.';

  @override
  String get settingsPageComputerDescription =>
      'Računalnik, na katerem delajo vaši agenti, in spletna mesta, ki jih lahko berejo kot vi.';

  @override
  String get settingsPageModelsDescription =>
      'Katere modele uporablja ta agent in ključe API-ja, ki jih plačajo.';

  @override
  String get settingsPageBehaviorDescription =>
      'Kako ta agent govori in kako bere skupinski klepet.';

  @override
  String get settingsPageVoiceDescription =>
      'Klici v živo, narekovanje in govorjeni odgovori za tega agenta.';

  @override
  String get settingsPageMessagingDescription =>
      'Kje lahko ljudje dosežejo tega agenta in kako se obnaša v klepetih.';

  @override
  String get settingsPageGeneralDescription =>
      'Videz, jezik, časovni pas in kaj ta aplikacija počne v ozadju.';

  @override
  String get settingsPageSystemDescription =>
      'Strežnik, ki ga uporablja to okno, tisti v tem računalniku in posodobitve aplikacij.';

  @override
  String get settingsYourAgents => 'Vaši agenti';

  @override
  String get settingsChatModel => 'Model klepeta';

  @override
  String get settingsChatModelDescription => 'Odgovarja na vaša sporočila.';

  @override
  String get settingsSubAgentModel => 'Model podzastopnika';

  @override
  String get settingsSubAgentModelDescription =>
      'Izvaja delo, predano med nalogo.';

  @override
  String get settingsDefaultModels => 'Privzeti modeli';

  @override
  String get settingsDefaultModelsDescription =>
      'Uporablja se, kadar klepet ali opravilo ne izbere svojega modela.';

  @override
  String get settingsModelPool => 'Model bazena';

  @override
  String get settingsApiKeysDescription =>
      'Za tega agenta uporabite svoje ključe ali končno točko. Ključi so šifrirani in nikoli več prikazani.';

  @override
  String get settingsPersona => 'Oseba';

  @override
  String get settingsFineTuning => 'Natančna nastavitev';

  @override
  String get settingsFineTuningDescription =>
      'Redko potrebno. Privzete nastavitve ustrezajo večini klepetov.';

  @override
  String get settingsShow => 'Prikaži';

  @override
  String get settingsHide => 'Skrij se';

  @override
  String get settingsMinimumContribution => 'Najmanjša vrednost prispevka';

  @override
  String get settingsBatchWindow => 'Sobno šaržno okno';

  @override
  String get settingsBatchWindowDescription =>
      'Tako dolgo čaka, da hitra sporočila obravnava kot en obrat.';

  @override
  String get settingsHandsFree => 'Prostoročno';

  @override
  String get settingsHandsFreeDescription =>
      'Pogovarjajte se svobodno in kadar koli prekinite.';

  @override
  String get settingsPushToTalkDescription =>
      'Pridržite za pogovor, spustite za pošiljanje.';

  @override
  String get settingsLiveVoice => 'Glas v živo';

  @override
  String get settingsChannels => 'Kanali';

  @override
  String get settingsGroupChats => 'V skupinskih klepetih';

  @override
  String get settingsGroupChatsDescription =>
      'Kako se ta agent obnaša v skupinah na vsakem kanalu.';

  @override
  String get settingsGroupChatsDisabled =>
      'Vklopite vedenjske module v Behavior, da jih spremenite.';

  @override
  String get settingsParticipationAutomatic => 'Samodejno';

  @override
  String get settingsParticipationMentionOnly => 'Samo omemba';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Prebere sobo in se ji pridruži, ko ima kaj koristnega za dodati.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Odgovori samo, ko so omenjeni ali nanje odgovorijo.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Odgovori na vsako sporočilo.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Razdeli daljše odgovore na kratka sporočila, kot bi jih oseba.';

  @override
  String get settingsDeliverySingleDescription =>
      'Pošlje vsak odgovor kot eno sporočilo.';

  @override
  String get settingsComputerStatus => 'Stanje';

  @override
  String get settingsTest => 'Test';

  @override
  String get settingsAppearance => 'Videz';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistem';

  @override
  String get settingsThemeLight => 'Svetla';

  @override
  String get settingsThemeDark => 'Temna';

  @override
  String get settingsCloseWindow => 'Ko zapreš okno';

  @override
  String get settingsCloseAsk => 'Vprašajte';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent deluje v ozadju in ostaja dosegljiv.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent popolnoma zapre.';

  @override
  String get settingsPhoneTriggers => 'Telefon sproži';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signale, ki jih ta telefon pošilja vašim agentom, da se lahko naloge odzovejo nanje.';

  @override
  String get settingsLocationTriggers => 'Lokacijski sprožilci';

  @override
  String get settingsLocationTriggersDescription =>
      'Vsakih nekaj minut preveri vašo približno lokacijo glede na mesta, ki jih spremljajo vaša opravila.';

  @override
  String get settingsNotificationTriggers => 'Sprožilci obvestil';

  @override
  String get settingsNotificationTriggersDescription =>
      'Posreduje obvestila iz drugih aplikacij v tem telefonu vašim agentom.';

  @override
  String get settingsSetup => 'Nastavitev';

  @override
  String get settingsOnboarding => 'Vkrcanje';

  @override
  String get settingsOnboardingDescription =>
      'Ponovno pojdite skozi nastavitev prvega zagona. Nič, kar ste nastavili, ni izgubljeno.';

  @override
  String get settingsUsernameDescription =>
      'Uporablja se za prijavo. Ni ga mogoče spremeniti.';

  @override
  String get settingsExport => 'Izvozi';

  @override
  String get settingsLeave => 'Odjavi se in izbriši';

  @override
  String get settingsSignOutDescription => 'Odjavi vas samo v tej napravi.';

  @override
  String get settingsDeleteAccountDescription =>
      'Izbriše vaš račun, agente, pomnilnik in nastavitve. Tega ni mogoče razveljaviti.';

  @override
  String get settingsTokenUsage => 'Uporaba žetona';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Nobena nastavitev se ne ujema z »$query«.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rezultatov',
      few: '$count rezultati',
      two: '$count rezultata',
      one: '$count rezultat',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Napredne nastavitve modela';

  @override
  String get settingsAdvancedModelsDescription =>
      'Neobvezno. Pripnite model na eno vrsto dela; prevzame vedno, ko agent uporabi ta orodja. Vse, kar ostane privzeto, sledi modelu klepeta.';

  @override
  String get settingsTaskModelDefault => 'Privzeto';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Sledi modelu klepeta';

  @override
  String get settingsTaskModelCoding => 'Kodiranje';

  @override
  String get settingsTaskModelCodingDescription =>
      'Pisanje, urejanje in odpravljanje napak kode.';

  @override
  String get settingsTaskModelComputerUse => 'Uporaba računalnika';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Vožnja brskalnika in namizja.';

  @override
  String get settingsTaskModelAndroidUse => 'uporaba Androida';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Upravljanje aplikacij v napravi Android ali emulatorju.';

  @override
  String get settingsTaskModelResearch => 'Raziskovanje';

  @override
  String get settingsTaskModelResearchDescription =>
      'Iskanje, branje in povzemanje virov.';

  @override
  String get knowledgeGraphHint =>
      'Vaše največkrat omenjene entitete, obarvane po grozdu. Črte povezujejo entitete, ki se pojavljajo v istih spominih. Dotaknite se enega, da vidite njegove povezave in spomine; povlecite za premikanje, približajte prste ali se pomaknite s tipko Ctrl/⌘ za povečavo.';

  @override
  String get linkedEntities => 'Povezane entitete';

  @override
  String get noLinkedEntities => 'Še ni povezan z drugimi entitetami.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 omenja';
  }

  @override
  String get entityKindConcept => 'Koncept';

  @override
  String get entityKindDomain => 'Domena';

  @override
  String get entityKindEmail => 'E-pošta';

  @override
  String get entityKindLink => 'Povezava';

  @override
  String get entityKindFile => 'Datoteka';

  @override
  String get entityKindAcronym => 'akronim';

  @override
  String get entityKindIdentifier => 'Identifikator';

  @override
  String get entityKindVersion => 'Različica';

  @override
  String get openFullscreen => 'Odpri celozaslonski način';

  @override
  String get zoomIn => 'Povečaj';

  @override
  String get zoomOut => 'Pomanjšaj';

  @override
  String get searchEntities => 'Poiščite entiteto';

  @override
  String get incomingCall => 'Dohodni klic';

  @override
  String get answerCall => 'Odgovori';

  @override
  String get callMeLater => 'Pokliči me kasneje';

  @override
  String get callingEllipsis => 'Klicanje ...';

  @override
  String get reconnectingCall => 'Ponovno povezovanje';

  @override
  String get agentWorking => 'Delo';

  @override
  String get micMuted => 'Utišan';

  @override
  String get speakerphone => 'Zvočnik';

  @override
  String get muteMic => 'Mute';

  @override
  String get unmuteMic => 'Vklop zvoka';

  @override
  String get releaseToSend => 'Spustite za pošiljanje';

  @override
  String get callEnded => 'Klic končan';

  @override
  String get openConversation => 'Odprt pogovor';

  @override
  String get callBack => 'Pokliči nazaj';

  @override
  String get letCallsReachYou => 'Naj vas klici dosežejo';

  @override
  String get callPermissionsIntro =>
      'Vaši agenti vas lahko pokličejo. Če želite zvoniti kot telefonski klic, medtem ko je NeoAgent v ozadju ali je vaš telefon zaklenjen, potrebuje to.';

  @override
  String get showOverOtherApps => 'Pokaži čez druge aplikacije';

  @override
  String get showOverOtherAppsDetail =>
      'Prikaže zaslon za klic, kjer koli že ste.';

  @override
  String get fullScreenCalls => 'Celozaslonski klici';

  @override
  String get fullScreenCallsDetail => 'Zvoni nad zaklenjenim zaslonom.';

  @override
  String get unrestrictedBattery => 'Neomejena baterija';

  @override
  String get unrestrictedBatteryDetail =>
      'Ohranja povezavo NeoAgenta, tako da klici prejmejo.';

  @override
  String get permissionAllowed => 'Dovoljeno';

  @override
  String get triggerSectionCalendar => 'Koledar';

  @override
  String get triggerSectionFiles => 'Datoteke in dokumenti';

  @override
  String get triggerSectionHome => 'Dom in mediji';

  @override
  String get triggerSectionDevices => 'Naprave in mesta';

  @override
  String get triggerSectionTasks => 'Naloge';

  @override
  String get messagingMemberJoined => 'Član se je pridružil';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Zaženi, ko se nekdo pridruži strežniku Discord, skupini Telegram ali WhatsApp, kanalu Slack ali sobi Matrix.';

  @override
  String get messagingMemberLeft => 'Zapuščen član';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Zaženi, ko nekdo zapusti strežnik Discord, skupino Telegram ali WhatsApp, kanal Slack ali sobo Matrix.';

  @override
  String get messagingReactionAdded => 'Dodana reakcija';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Zaženi, ko se dovoljena oseba odzove na sporočilo v zasebnem klepetu.';

  @override
  String get messagingPlatformDisconnected => 'Povezava s sporočili prekinjena';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Zaženite, ko se povezava za sporočila prekine in vas potrebuje, na primer po odjavi.';

  @override
  String get googleCalendarEventStarting =>
      'Začetek dogodka v Google Koledarju';

  @override
  String get googleCalendarEventCreated =>
      'Dogodek v Google Koledarju ustvarjen';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Zaženi, ko se pojavi nov dogodek ali povabilo.';

  @override
  String get outlookCalendarEventStarting =>
      'Začetek dogodka v Outlookovem koledarju';

  @override
  String get nextcloudCalendarEventStarting =>
      'Začetek dogodka Nextcloud Calendar';

  @override
  String get runMinutesBeforeEachEvent =>
      'Tecite določeno število minut pred vsakim dogodkom.';

  @override
  String get googleDriveFileAdded => 'Dodana datoteka Google Drive';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Zaženi, ko je datoteka dodana v Drive ali mapo v njej.';

  @override
  String get googleSheetsRowAdded => 'Dodana vrstica Google Preglednic';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Zaženi, ko se na listu pojavijo nove vrstice.';

  @override
  String get onedriveFileAdded => 'Dodana datoteka OneDrive';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Zaženi, ko je datoteka dodana v mapo OneDrive.';

  @override
  String get nextcloudFileAdded => 'Dodana datoteka Nextcloud';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Zaženi, ko je datoteka dodana v mapo Nextcloud.';

  @override
  String get nextcloudShareReceived =>
      'Datoteka Nextcloud je v skupni rabi z vami';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Zaženi, ko nekdo da datoteko ali mapo v skupno rabo z vami.';

  @override
  String get notionItemAdded => 'Dodana je postavka baze podatkov';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Zaženi, ko je element dodan v zbirko podatkov Notion.';

  @override
  String get notionItemUpdated => 'Element baze podatkov Notion je posodobljen';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Zaženi, ko se postavka v zbirki podatkov Notion spremeni.';

  @override
  String get trelloCardEnteredList => 'Kartica Trello dodana na seznam';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Zaženi, ko je kartica ustvarjena ali premaknjena na seznam.';

  @override
  String get figmaCommentAdded => 'Dodan komentar Figma';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Zaženi, ko nekdo komentira datoteko Figma.';

  @override
  String get githubPrOpened => 'Zahteva za vleko GitHub je odprta';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Zaženi, ko se v repozitoriju odpre nova zahteva za vleko.';

  @override
  String get githubWorkflowRunFailed => 'Zagon delovnega toka GitHub ni uspel';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Zaženi, ko zagon GitHub Actions ne uspe.';

  @override
  String get githubCommitPushed => 'GitHub potrditev potisnjena';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Zaženi, ko nove objave dosežejo vejo.';

  @override
  String get mcpServerFailed => 'Strežnik MCP ni uspel';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Zaženi, ko strežnik MCP, ki je deloval, odpove ali se je treba prijaviti.';

  @override
  String get homeAssistantStateChanged =>
      'Stanje domačega pomočnika je spremenjeno';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Zaženi, ko se entiteta spremeni, doseže stanje ali preseže vrednost.';

  @override
  String get spotifyTrackChanged => 'Skladba Spotify je spremenjena';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Zaženite, ko se začne predvajati druga skladba.';

  @override
  String get neorecallDailySummaryReady =>
      'Pripravljen dnevni povzetek NeoRecall';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Zaženite, ko je povzetek dneva dokončen.';

  @override
  String get neorecallConversationRecorded => 'Pogovor NeoRecall je posnet';

  @override
  String get runWhenARecordedConversationEnds =>
      'Zaženi, ko se posneti pogovor konča.';

  @override
  String get geofenceTrigger => 'Lokacijska geofence';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Zaženite, ko vaš telefon prispe na mesto ali ga zapusti. Potrebuje sledenje lokaciji na telefonu.';

  @override
  String get healthMetricRecorded => 'Zdravstvena metrika je zabeležena';

  @override
  String get runWhenAHealthReadingArrives =>
      'Zaženi, ko prispe sinhronizirani odčitek zdravja, po želji nad ali pod vrednostjo.';

  @override
  String get wearableConnectionChanged =>
      'Nosljiva naprava povezana ali odklopljena';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Zaženite, ko se vaša nosljiva naprava poveže ali prekine.';

  @override
  String get taskRunFinished => 'Še ena naloga končana';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Zaženite, ko se druga naloga konča, uspe ali ne uspe.';

  @override
  String get appPackageOptional => 'Paket aplikacij (neobvezno)';

  @override
  String get appPackageHelper => 'Na primer com.whatsapp';

  @override
  String get anyPlatform => 'Katera koli platforma';

  @override
  String get spaceIdOptional =>
      'ID strežnika, skupine, kanala ali sobe (neobvezno)';

  @override
  String get spaceIdHelper => 'Empty opazuje vse, v katerih je bot.';

  @override
  String get emojiOptional => 'Emoji (neobvezno)';

  @override
  String get chatIdOptional => 'ID klepeta (neobvezno)';

  @override
  String get platformOptional => 'Platforma (neobvezno)';

  @override
  String get platformOptionalHelper => 'Na primer whatsapp. Prazne ure vse.';

  @override
  String get minutesBefore => 'Minute prej';

  @override
  String get calendarIdOptional => 'ID koledarja (neobvezno)';

  @override
  String get calendarIdHelper => 'Empty uporablja vaš primarni koledar.';

  @override
  String get invitesOnly => 'Samo povabila drugih';

  @override
  String get nextcloudCalendarPath => 'Koledar';

  @override
  String get nextcloudCalendarPathHelper =>
      'Njegovo ime na seznamu koledarjev Nextcloud, na primer osebno';

  @override
  String get folderIdOptionalHelperDrive => 'Prazne ure ves Drive.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Empty opazuje korensko mapo.';

  @override
  String get driveFolderIdOptional => 'ID mape (neobvezno)';

  @override
  String get spreadsheetId => 'ID preglednice';

  @override
  String get sheetRange => 'Razpon';

  @override
  String get sheetRangeHelper => 'Stolpci tabele, na primer Sheet1!A:E';

  @override
  String get folderPathOptional => 'Pot do mape (neobvezno)';

  @override
  String get folderPathHelper => 'Na primer Dokumenti';

  @override
  String get notionDatabaseId => 'ID baze podatkov';

  @override
  String get trelloListId => 'ID seznama';

  @override
  String get figmaFileKey => 'Datotečni ključ';

  @override
  String get figmaFileKeyHelper =>
      'Iz povezave do datoteke: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Repozitorij';

  @override
  String get workflowOptional => 'Potek dela (neobvezno)';

  @override
  String get workflowHelper => 'Ime datoteke, kot je ci.yml';

  @override
  String get branchOptional => 'Podružnica (neobvezno)';

  @override
  String get branchHelper => 'Prazno uporablja privzeto vejo.';

  @override
  String get mcpServerIdOptional => 'ID strežnika MCP (neobvezno)';

  @override
  String get entityId => 'ID entitete';

  @override
  String get entityIdHelper => 'Na primer binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Ciljno stanje (neobvezno)';

  @override
  String get targetStateHelper => 'Na primer na';

  @override
  String get aboveOptional => 'Zgoraj (neobvezno)';

  @override
  String get belowOptional => 'Spodaj (neobvezno)';

  @override
  String get placeName => 'Ime kraja';

  @override
  String get latitude => 'Zemljepisna širina';

  @override
  String get longitude => 'Dolžina';

  @override
  String get radiusMeters => 'Polmer v metrih';

  @override
  String get geofenceTransition => 'kdaj';

  @override
  String get arriving => 'Prihod';

  @override
  String get leaving => 'Odhajam';

  @override
  String get healthMetric => 'Zdravstvena metrika';

  @override
  String get healthMetricHelper => 'Na primer srčni utrip, koraki, teža';

  @override
  String get wearableTransition => 'Ko je nosljiva';

  @override
  String get wearableConnects => 'Povezuje';

  @override
  String get wearableDisconnects => 'Odklopi';

  @override
  String get sourceTask => 'Po opravilu';

  @override
  String get taskOutcome => 'Izid';

  @override
  String get anyOutcome => 'Kakršen koli rezultat';

  @override
  String get succeeded => 'Uspelo';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 manjka ali ni veljaven.';
  }

  @override
  String get triggerSectionMessaging => 'Sporočila';

  @override
  String get triggerSectionDeveloper => 'Razvijalec';

  @override
  String get triggerSectionMemory => 'Spomin';

  @override
  String get triggerSectionNews => 'Novice';

  @override
  String get triggerSectionSystem => 'Sistem';

  @override
  String get searchTriggersHint => 'Sprožilci iskanja, aplikacije ali dogodki';

  @override
  String get noTriggersMatch => 'Noben sprožilec se ne ujema z vašim iskanjem.';

  @override
  String get triggerAccountMissing => 'Računa še ni';

  @override
  String get pickTriggerKeyboardHint => 'Enter izbere prvi rezultat';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 sproži';
  }

  @override
  String get addFromSkillsSh => 'Dodaj s Skills.sh';

  @override
  String get skillsShHint =>
      'Poiščite zgoraj, da poiščete veščine na Skills.sh, ali prilepite povezavo Skills.sh ali ukaz `npx skills add`.';

  @override
  String get noSkillsShMatches =>
      'S tem iskanjem se ne ujemajo nobene veščine.';

  @override
  String get installingSkill => 'Namestitev ...';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Nameščen $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 namesti';
  }

  @override
  String get authVerify => 'Preveri';

  @override
  String get authCreateAccount => 'Ustvari račun';

  @override
  String get authNewInviteLink => 'Nova povezava za povabilo';

  @override
  String get authShowPassword => 'Pokaži geslo';

  @override
  String get authHidePassword => 'Skrij geslo';

  @override
  String get authPasswordWillBeRejected => 'prešibak, bo zavrnjen';

  @override
  String get authUsernameTooShort => 'Uporabniško ime mora imeti vsaj 3 znake.';

  @override
  String get authUsernameTaken => 'To uporabniško ime je že zasedeno.';

  @override
  String get authSignupsClosed =>
      'Prijave na tem strežniku so zaprte. Vprašajte skrbnika za račun.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Ta strežnik sprejema samo prijave prek HTTPS. Namesto tega odprite $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Ta strežnik sprejema samo prijave prek HTTPS. Povežite se z njim z naslovom https://.';

  @override
  String get authAccountNotFound => 'Ta račun ne obstaja več.';

  @override
  String get authQrRateLimited =>
      'Preveč zahtev za prijavo QR. Počakajte trenutek in nato osvežite kodo.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Ste pozabili geslo? Prosite skrbnika strežnika, da ga ponastavi v Skrbnik → Uporabniki.';

  @override
  String get authChangeServer => 'Spremeni strežnik';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Prijava v $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Ta naslov ne odgovarja kot strežnik NeoAgent. Preverite URL in poskusite znova.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Ni bilo mogoče odpreti varne (HTTPS) povezave z $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Ni bilo mogoče doseči $arg1 prek HTTPS in tudi navaden HTTP ni odgovoril. Preverite naslov in vrata.';
  }

  @override
  String get adminResetPassword => 'Ponastavi geslo';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Ponastavite geslo za $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Izberite novo geslo za $arg1. Odjavljeni bodo v vsaki napravi in ​​se znova prijavili s tem geslom.';
  }

  @override
  String get adminNewPassword => 'Novo geslo';

  @override
  String get adminSetPassword => 'Nastavite geslo';

  @override
  String get authMissingFields => 'Izpolnite vsa zahtevana polja.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 ponastavite geslo $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Geslo posodobljeno; uporabnik je bil povsod odjavljen.';

  @override
  String get authSignInTitle => 'Prijavite se v NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Skenirajte s telefonom ali uporabite geslo.';

  @override
  String get authOrUsePassword => 'ali uporabite svoje geslo';

  @override
  String get qrLoginWaitingTitle => 'Odobrite v telefonu';

  @override
  String get qrLoginWaitingBody =>
      'Vaš telefon je skeniral kodo. Tam potrdite prijavo, da dokončate prijavo.';

  @override
  String get qrLoginSigningInOn => 'Prijava na';

  @override
  String get qrLoginLocation => 'Lokacija';

  @override
  String get qrLoginWaitingForApproval => 'Čakam na odobritev';

  @override
  String get qrLoginCancelAndUsePassword => 'Prekliči in uporabi geslo';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Prijava na vašem telefonu je bila zavrnjena. Skenirajte novo kodo in poskusite znova.';

  @override
  String get signupKey => 'Registracijski ključ';

  @override
  String get signupKeyStepSubtitle =>
      'Novi računi na tem strežniku potrebujejo registracijski ključ. Vnesite ključ, ki ste ga dobili od skrbnika.';

  @override
  String get signupKeyChange => 'Spremeni';

  @override
  String get signupKeyRequiredError => 'Vnesite svoj registracijski ključ.';

  @override
  String get signupKeyInvalidError =>
      'Ta registracijski ključ ni veljaven. Preverite ga in poskusite znova.';

  @override
  String get signupKeyUsedError =>
      'Ta registracijski ključ je že bil uporabljen. Prosite skrbnika za novega.';

  @override
  String get adminRequireSignupKey => 'Zahtevaj registracijski ključ';

  @override
  String get adminRequireSignupKeyHint =>
      'Novi računi potrebujejo enkratni ključ skrbnika. Ko je izklopljeno, se lahko registrira vsak, ki doseže ta strežnik. Prvi račun ključa nikoli ne potrebuje.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Novi računi zdaj potrebujejo registracijski ključ.';

  @override
  String get adminSignupOpenNotice => 'Zdaj se lahko registrira vsak.';

  @override
  String get signupKeys => 'Registracijski ključi';

  @override
  String get signupKeysDescription =>
      'Enkratni ključi za registracijo, dokler je ključ zahtevan. Vsak ključ ustvari natanko en račun.';

  @override
  String get signupKeysNew => 'Novi ključi';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Neuporabljeni · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Uporabljeni · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Preklicani · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Vsi · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Neuporabljen';

  @override
  String get signupKeyStatusUsed => 'Uporabljen';

  @override
  String get signupKeyStatusRevoked => 'Preklican';

  @override
  String get signupKeysExport => 'Izvozi .txt';

  @override
  String get signupKeysCopied => 'Ključi kopirani';

  @override
  String get signupKeyCopied => 'Ključ kopiran';

  @override
  String get signupKeysEmpty => 'Na tem seznamu ni ključev.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Ustvarjeno $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Uporabil(a) $arg1, $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Uporabljeno $arg1 z računom, ki je bil medtem izbrisan';
  }

  @override
  String get signupKeyRevokeTitle => 'Prekličem ta ključ?';

  @override
  String get signupKeyRevokeMessage =>
      'Z njim se ne bo mogel registrirati nihče več. Tega ni mogoče razveljaviti.';

  @override
  String get signupKeyRevoked => 'Ključ preklican.';

  @override
  String signupKeysShowMore(int count) {
    return 'Pokaži še $count';
  }

  @override
  String get signupKeysCreateTitle => 'Ustvari registracijske ključe';

  @override
  String get signupKeysCount => 'Število ključev';

  @override
  String get signupKeysCountHelper => 'Od 1 do 500';

  @override
  String get signupKeysCountInvalid => 'Vnesite število od 1 do 500.';

  @override
  String get signupKeysLabel => 'Oznaka (neobvezno)';

  @override
  String get signupKeysLabelHint => 'npr. Spomladanski beta preizkuševalci';

  @override
  String signupKeysCreateAction(int count) {
    return 'Ustvari ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Pripravljeni ključi: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Vsak ključ dajte le eni osebi. Neuporabljeni ključi ostanejo na seznamu, zato jih lahko pozneje znova kopirate ali izvozite.';

  @override
  String get signupKeysSaveDialogTitle => 'Shrani registracijske ključe';

  @override
  String get signupKeysExported => 'Ključi izvoženi.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor je ustvaril(a) registracijske ključe ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor je preklical(a) registracijski ključ';
  }

  @override
  String get providerChooseUsername => 'Izberite uporabniško ime';

  @override
  String get providerChooseUsernameBody =>
      'Izberite razpoložljivo uporabniško ime, da dokončate ustvarjanje računa.';

  @override
  String get dataSharingTitle => 'Deli podatke o uporabi';

  @override
  String get dataSharingDescription =>
      'Pomagajte upraviteljem tega strežnika, da ga izboljšajo. Deli, kako uporabljate NeoAgent, nikoli tega, kar pišete ali shranjujete.';

  @override
  String dataSharingSince(String date) {
    return 'Deljeno od $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Kaj se deli';

  @override
  String get dataSharingIncluded => 'Deli se';

  @override
  String get dataSharingExcluded => 'Nikoli se ne deli';

  @override
  String get dataSharingIncludedDevice =>
      'Vrsta naprave in različica aplikacije';

  @override
  String get dataSharingIncludedLocale =>
      'Jezik aplikacije in regija časovnega pasu, na primer Evropa';

  @override
  String get dataSharingIncludedFeatures =>
      'Katere funkcije imate nastavljene, npr. opravila, skille in integracije';

  @override
  String get dataSharingIncludedRuns =>
      'Katera orodja in modele uporabljajo vaši zagoni, s trajanjem in številom žetonov';

  @override
  String get dataSharingIncludedActivity =>
      'Kdaj uporabljate NeoAgent, po dnevih v tednu in urah';

  @override
  String get dataSharingExcludedContent => 'Sporočila, pozivi in odgovori';

  @override
  String get dataSharingExcludedRuns =>
      'Naslovi zagonov, vhodi in rezultati orodij';

  @override
  String get dataSharingExcludedFiles =>
      'Datoteke, spomini in vse drugo, kar shranjujete';

  @override
  String get dataSharingExcludedIdentity =>
      'Vaše ime, e-pošta, naslov IP in lokacija';

  @override
  String get dataSharingExcludedAccounts =>
      'Računi, s katerimi povezujete integracije';

  @override
  String get dataSharingPooledNote =>
      'Skrbniki vidijo le seštevke vseh, ki delijo, nikoli vas posebej. Kadar koli izklopite in takoj izpadete iz seštevkov.';

  @override
  String get dataSharingConfirmTitle => 'Želite deliti podatke o uporabi?';

  @override
  String get dataSharingConfirmAction => 'Deli';

  @override
  String get sharedUsageTitle => 'Deljena uporaba';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Računi, ki delijo podatke o uporabi: $sharing od $total. Samo seštevki, brez vsebine.';
  }

  @override
  String get sharedUsageEmpty =>
      'Nihče še ne deli podatkov o uporabi. Vklopiti se da v: Nastavitve, Profil, Vaši podatki.';

  @override
  String get sharedUsageRuns => 'Deljeni zagoni';

  @override
  String get sharedUsageAvgDuration => 'Povpr. trajanje';

  @override
  String get sharedUsageCompletedRuns => 'Dokončani zagoni';

  @override
  String get sharedUsageStepsPerRun => 'Koraki na zagon';

  @override
  String get sharedUsageDevices => 'Naprave';

  @override
  String get sharedUsageAppVersions => 'Različice aplikacije';

  @override
  String get sharedUsageLanguages => 'Jeziki';

  @override
  String get sharedUsageRegions => 'Regije';

  @override
  String get sharedUsageFeatures => 'Uporaba funkcij';

  @override
  String get sharedUsageFeaturesDescription =>
      'Delež računov, ki delijo in so jo nastavili.';

  @override
  String get sharedUsageTools => 'Orodja';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Najpogosteje klicana orodja ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Klici: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Neuspešno: $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Integracije';

  @override
  String get sharedUsageMessaging => 'Kanali za sporočila';

  @override
  String get sharedUsageTriggers => 'Kako se zagoni začnejo';

  @override
  String get sharedUsageActivity => 'Kdaj se uporablja';

  @override
  String get sharedUsageActivityDescription =>
      'Zagoni po dnevih v tednu in urah, UTC.';

  @override
  String get sharedUsageModels => 'Zmogljivost modelov';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'povpr. $latency · $cached % iz predpomnilnika · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Računi: $count';
  }

  @override
  String get sharedUsageNoData => 'V tem obdobju ni ničesar.';

  @override
  String get sharedUsageNotReported => 'Še ni sporočeno';

  @override
  String get sharedUsageFeatureAgents => 'Več kot en agent';

  @override
  String get sharedUsageFeatureTasks => 'Načrtovana opravila';

  @override
  String get sharedUsageFeatureSkills => 'Skilli';

  @override
  String get sharedUsageFeatureMcp => 'Strežniki MCP';

  @override
  String get sharedUsageFeatureIntegrations => 'Integracije';

  @override
  String get sharedUsageFeatureMessaging => 'Kanali za sporočila';

  @override
  String get sharedUsageFeatureMemory => 'Spomin';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in deljenje podatkov telemetrija naprave funkcije orodja modeli dejavnost';

  @override
  String get yourOAuthApp => 'Vaša aplikacija OAuth';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Vaša aplikacija OAuth za $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Ta strežnik nima globalne aplikacije $provider, zato se povežete z aplikacijo OAuth, ki jo registrirate sami. Skrivnost odjemalca je shranjena šifrirano in se ne prikaže nikoli več.';
  }

  @override
  String get oauthAppStepCreate => '1. Ustvarite aplikacijo';

  @override
  String get openDeveloperConsole => 'Odpri razvijalsko konzolo';

  @override
  String get oauthAppStepCallback => '2. Registrirajte ta URL za povratni klic';

  @override
  String get callbackUrlCopied => 'URL za povratni klic kopiran';

  @override
  String get oauthAppScopes => 'Obsegi za dovolitev';

  @override
  String get scopesCopied => 'Obsegi kopirani';

  @override
  String get oauthAppStepCredentials => '3. Prilepite poverilnice aplikacije';

  @override
  String get couldNotSaveOAuthApp =>
      'Aplikacije OAuth ni bilo mogoče shraniti.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Odstranim vašo aplikacijo $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'Povezani računi ostanejo na seznamu, vendar ne delujejo, dokler znova ne dodate aplikacije.';

  @override
  String get globalIntegrationConfiguration =>
      'Globalna konfiguracija integracij';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Neobvezne aplikacije OAuth za celoten strežnik. Ko jo integracija ima, jo uporablja vsak račun in ne more dodati svoje. Pustite integracijo nenastavljeno in vsak uporabnik nastavi svojo aplikacijo. Skrivnosti je mogoče le zapisati: pustite prazno, da ohranite shranjeno vrednost.';

  @override
  String get globalStatus => 'Globalno';

  @override
  String get perUserStatus => 'Na uporabnika';

  @override
  String get phoneSyncGuidance =>
      'Delite koledarje in stike tega telefona s svojim agentom. Deluje z vsemi računi, ki so že v telefonu.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Odprite NeoAgent v telefonu in tam vklopite deljenje. Agent bo nato videl koledarje in stike vseh računov v tem telefonu.';

  @override
  String get manageOnThisPhone => 'Upravljaj v tem telefonu';

  @override
  String get setUpOnThisPhone => 'Nastavi v tem telefonu';

  @override
  String get setUpOnPhone => 'Nastavi v telefonu';

  @override
  String emailConnectedArg1(String email) {
    return '$email povezan';
  }

  @override
  String get couldNotConnectEmail => 'Računa ni bilo mogoče povezati.';

  @override
  String get emailSetupTitle => 'Poveži e-pošto in koledar';

  @override
  String get emailChecking => 'Preverjam nabiralnik…';

  @override
  String get emailSetupIntro =>
      'Uporabite geslo za aplikacijo od ponudnika e-pošte. Brez razvijalske konzole, v nekaj minutah.';

  @override
  String emailOpenArg1(String provider) {
    return 'Odpri $provider';
  }

  @override
  String get emailStepServers => '1. Vnesite strežnike';

  @override
  String get emailStepPassword => '1. Ustvarite geslo za aplikacijo';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Odpri gesla za aplikacije pri $provider';
  }

  @override
  String get emailStepSignIn => '2. Prijava';

  @override
  String get appPassword => 'Geslo za aplikacijo';

  @override
  String get appPasswordHelper =>
      'Presledki niso pomembni. NeoAgent ga shrani šifrirano.';

  @override
  String get emailUsernameOptional =>
      'Uporabniško ime, če ni vaš e-poštni naslov';

  @override
  String get emailIncludeCalendar => 'Vključi koledar';

  @override
  String get emailIncludeContacts => 'Vključi stike';

  @override
  String get imapServer => 'Strežnik IMAP';

  @override
  String get smtpServer => 'Strežnik SMTP';

  @override
  String get caldavUrlOptional => 'URL CalDAV (neobvezno)';

  @override
  String get carddavUrlOptional => 'URL CardDAV (neobvezno)';

  @override
  String get alternativeEmail =>
      'Povežite nabiralnik z geslom za aplikacijo ali koledar z njegovo povezavo iCal. V nekaj minutah.';

  @override
  String get alternativePhone =>
      'Delite koledar in stike, ki so že v telefonu, prek aplikacije NeoAgent.';

  @override
  String get alternativePhoneElsewhere =>
      'Delite koledar in stike, ki so že v telefonu. Nastavite v aplikaciji NeoAgent v telefonu.';

  @override
  String get skipTheDeveloperConsole => 'Brez razvijalske konzole';

  @override
  String get phoneSyncPromptTitle => 'Naj agent vidi vaš koledar?';

  @override
  String get phoneSyncPromptBody =>
      'Delite koledarje in stike tega telefona, da lahko agent načrtuje okoli vašega dne. To lahko kadar koli spremenite v Orodja › Integracije.';

  @override
  String get phoneSyncTitle => 'Deli koledar in stike tega telefona';

  @override
  String get phoneSyncIntro =>
      'Agent vidi koledarje in stike vseh računov v tem telefonu. Brez razvijalske konzole in dodatne prijave.';

  @override
  String get phoneSyncPointAccounts =>
      'Deluje z računi Google, Outlook, iCloud in Exchange v tem telefonu.';

  @override
  String get phoneSyncPointPrivate =>
      'Deljeno samo z vašim strežnikom NeoAgent, ki jih shrani šifrirano.';

  @override
  String get phoneSyncPointWrites =>
      'Dogodke, ki jih doda agent, ustvari ta telefon in se sinhronizirajo kot običajno.';

  @override
  String get phoneSyncCalendarHint =>
      'Dogodki od 30 dni nazaj do 90 dni naprej';

  @override
  String get phoneSyncContacts => 'Stiki';

  @override
  String get phoneSyncContactsHint =>
      'Imena, e-poštni naslovi in telefonske številke';

  @override
  String get phoneSyncOtherAgent =>
      'Ta telefon deli z drugim agentom. Deljenje tukaj ga prestavi k temu agentu.';

  @override
  String get phoneSyncDenied =>
      'NeoAgent še nima dostopa. Dovolite ga v Nastavitvah in se vrnite.';

  @override
  String get openPhoneSettings => 'Odpri Nastavitve';

  @override
  String get phoneSyncShare => 'Deli z NeoAgent';

  @override
  String get phoneSyncStop => 'Ustavi deljenje';

  @override
  String get phoneSyncWaiting => 'Čakam na prvo sinhronizacijo…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Zadnja sinhronizacija $time';
  }

  @override
  String get calendarLink => 'Povezava do koledarja';

  @override
  String get calendarLinkHelper =>
      'Naslov iCal koledarja. Kdor ga pozna, lahko bere koledar, zato ga ohranite zasebnega.';

  @override
  String get calendarLinkName => 'Ime (neobvezno)';

  @override
  String get calendarLinkAdded => 'Koledar dodan';

  @override
  String get toolsApps => 'Aplikacije';

  @override
  String get reconnect => 'Znova poveži';

  @override
  String get reconnectNeeded => 'Potrebna ponovna povezava';

  @override
  String get mixedAccess => 'Mešan dostop';

  @override
  String disconnectAccountTitle(String account) {
    return 'Prekinem povezavo $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Agent prek tega računa izgubi dostop do $apps.';
  }

  @override
  String get neoRouterServerDescription =>
      'Enkrat povežite svoj NeoRouter in vsak račun tukaj ga bo uporabljal za spodaj vklopljena opravila.';

  @override
  String get neoRouterUserDescription =>
      'Za spodaj vklopljena opravila uporabite svoj račun NeoRouter namesto ponudnikov tega strežnika.';

  @override
  String get neoRouterAddress => 'Naslov NeoRouterja';

  @override
  String get neoRouterConnect => 'Poveži NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Odobrite NeoAgent v NeoRouterju. Prikazuje kodo $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Odpri znova';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Povezano z $arg1';
  }

  @override
  String get neoRouterUnreachable => 'NeoRouter trenutno ni dosegljiv.';

  @override
  String get neoRouterDisconnect => 'Prekini povezavo';

  @override
  String get neoRouterDisconnectBody =>
      'NeoAgent preneha uporabljati ta NeoRouter. Če želite odvzeti tudi ključ, ga prekličite v NeoRouterju pod API ključi.';

  @override
  String neoRouterServerInUseArg1(Object? arg1) {
    return 'Ta strežnik že uporablja NeoRouter na $arg1. Tam povežite svoj račun za lastne modele in proračun.';
  }

  @override
  String get neoRouterConnected => 'NeoRouter je povezan.';

  @override
  String get neoRouterRoleChat => 'Klepet in prepoznavanje slik';

  @override
  String get neoRouterRoleSystemOne => 'Odločitve System One';

  @override
  String get neoRouterRoleTranscription => 'Govor v besedilo';

  @override
  String get neoRouterRoleLive => 'Glas v živo';

  @override
  String get neoRouterRoleEmbeddings => 'Iskanje po spominu';

  @override
  String get neoRouterRoleImages => 'Ustvarjanje slik';

  @override
  String get neoRouterRoleSearch => 'Iskanje po spletu';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'Na voljo v vašem NeoRouterju: $arg1';
  }

  @override
  String get neoRouterNoModels => 'V vašem NeoRouterju še ni ničesar.';
}
