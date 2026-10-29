// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class AppL10nHr extends AppL10n {
  AppL10nHr([String locale = 'hr']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'dobrodošli';

  @override
  String get onboardingEyebrowCommunication => 'Komunikacija';

  @override
  String get onboardingEyebrowIntelligence => 'Inteligencija';

  @override
  String get onboardingEyebrowComputer => 'Računalo';

  @override
  String get onboardingEyebrowAutomation => 'Automatizacija';

  @override
  String get onboardingNext => 'Dalje';

  @override
  String get onboardingIntroCouldNotLoad => 'Uvod nije moguće učitati.';

  @override
  String get onboardingModelDescription =>
      'Odaberite model koji bi NeoAgent trebao koristiti prema zadanim postavkama ili ga pustite da odabere automatski.';

  @override
  String get onboardingLoadingModels => 'Učitavanje modela…';

  @override
  String get noAiModelTitle => 'Nijedan AI model još nije postavljen';

  @override
  String get noAiModelBody =>
      'Dodajte API ključ od dobavljača kao što je OpenAI, Anthropic ili Google. NeoAgent zatim prikazuje modele koje možete koristiti.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent treba AI model da odgovori. Dodajte API ključ od dobavljača kao što je OpenAI, Anthropic ili Google.';

  @override
  String get noAiModelAdminHint =>
      'Kao administrator također možete postaviti pružatelje za sve pod Administrator → Pružatelji.';

  @override
  String get addApiKey => 'Dodaj API ključ';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform je povezan.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Čeka se da se $platform poveže…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Postavljanje nije bilo moguće spremiti: $error';
  }

  @override
  String get onboardingEyebrowReady => 'spreman';

  @override
  String get onboardingStepRequired => 'Obavezno';

  @override
  String get onboardingStepOptional => 'Neobavezno';

  @override
  String get onboardingStepCloudOrLocal => 'Cloud ili lokalno';

  @override
  String get onboardingStepComputer => 'Računalo';

  @override
  String get onboardingStepRoutines => 'Rutine';

  @override
  String get onboardingComputerChoiceTitle => 'Gdje bi trebao\nraditi?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Možete se mijenjati po sesiji.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Privatni sandbox · uvijek uključen';

  @override
  String get onboardingThisComputer => 'Ovo računalo';

  @override
  String get onboardingThisComputerSubtitle =>
      'Vaše datoteke, aplikacije i preglednik';

  @override
  String get onboardingSearchApps => 'Traži aplikacije…';

  @override
  String get onboardingRoutinesDescription =>
      'Rezultati stižu u vaše razgovore.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Rezultati stižu kao obavijesti.';

  @override
  String get onboardingNotifications => 'Obavijesti';

  @override
  String get onboardingReadyTitle => 'Sve je\nspremno.';

  @override
  String get onboardingReadyDescription => 'Pošalji svoju prvu poruku.';

  @override
  String get onboardingMessageNeoagent => 'Poruka NeoAgent';

  @override
  String get onboardingAskAnything => 'Pitajte bilo što…';

  @override
  String get onboardingOpenNeoagent => 'Otvorite NeoAgent';

  @override
  String get onboardingStarterTrip => 'Isplanirajte putovanje za vikend';

  @override
  String get onboardingStarterLanding => 'Izradite odredišnu stranicu';

  @override
  String onboardingQuickSteps(int count) {
    return '$count brzi koraci';
  }

  @override
  String get taskNeedsEmail => 'Prvo povežite e-poštu';

  @override
  String get taskNeedsCalendar => 'Prvo povežite kalendar';

  @override
  String get taskNeedsModel => 'Najprije postavite AI model';

  @override
  String get taskPromptDailyRecap =>
      'Rekapitulirajte svoj dan: rezimirajte razgovore, završeni posao i odluke od danas, zatim navedite sve što bih trebao nastaviti sutra. Budite kratki i pošaljite mi.';

  @override
  String get taskPromptInboxCheck =>
      'Provjerite moju pristiglu poštu za poruke koje su stigle od zadnje provjere. Pošaljite mi samo poruke e-pošte koje su hitne ili zahtijevaju odgovor, sa sažetkom od jednog retka. Ako ništa ne treba moju pozornost, ne šaljite ništa.';

  @override
  String get taskPromptMorningBriefing =>
      'Pripremite moj jutarnji brifing: današnje vrijeme gdje se nalazim, događaji na mom kalendaru i najvažnije otvorene stavke za koje znam. Pošaljite je kao kratku poruku koju je moguće skenirati.';

  @override
  String get taskPromptTomorrowPrep =>
      'Pogledaj moj kalendar za sutra. Za svaki sastanak recite mi o čemu se radi, tko je uključen i sve što trebam pripremiti. Ako je sutra prazan, ne šaljite ništa.';

  @override
  String get taskPromptNewsDigest =>
      'Potražite na webu današnje najvažnije vijesti o temama koje me zanimaju (upotrijebite ono čega se sjećate o mojim interesima). Pošaljite mi sažetak do pet stavki s jednom rečenicom i vezom.';

  @override
  String get taskPromptWeeklyReview =>
      'Pregledajte svoj tjedan: što sam napravio, što je promaklo i što je još otvoreno. Predložite tri najvažnije stvari na koje se trebate usredotočiti sljedeći tjedan.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Povežite telefonski broj koji pripada agentu. Svatko kome dopustite može razgovarati s njim, u izravnim razgovorima i grupama.';

  @override
  String get whatsappSelfChatDescription =>
      'Povežite svoj broj i razgovarajte s agentom u chatu \"Pošaljite si poruku\". Svaki drugi chat i grupa na ovom računu se zanemaruju.';

  @override
  String get chatSendHintMac => '⌘↵ poslati';

  @override
  String get chatSendHintOther => 'Ctrl+Enter za slanje';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Za ovu krajnju točku potreban je osnovni URL.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Promijenjena adresa e-pošte potvrđuje se prije upotrebe.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Pobjeđuje odluka na višoj razini u lancu.';

  @override
  String get aDeletedAccount => 'izbrisani račun';

  @override
  String get aFridayLookBackAtThe =>
      'Petak osvrt na tjedan i plan za sljedeći.';

  @override
  String get aKeyThatAsksForA =>
      'Ključ koji traži PIN ili otisak prsta također zamjenjuje vaš kod s dva faktora.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Jezični model procijenio je ovu poruku jer je SystemOne isključen.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Datoteka s metapodacima za postavljanje NeoAgenta premašila je sigurno ograničenje veličine.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Na poslužitelju je dostupna novija web verzija. Ponovno učitajte da biste dohvatili najnoviji paket.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Privatna radna površina s Chromiumom, datotekama, uređivačem teksta, terminalom i Pythonom. Vaš rad ostaje spremljen između sesija.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Privatno Linux računalo ili Android uređaj.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Ne može se preuzeti potrebna datoteka za postavljanje NeoAgenta.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Suigrač vam šalje vezu s pozivnicom. Nakon što to prihvatite, oni ';

  @override
  String get aTeammateSentYouAnInvite =>
      'suigrač vam je poslao poveznicu s pozivnicom, unesite je ovdje da biste se pridružili njihovom timu.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Privremeno preuzimanje bit će očišćeno kasnije.';

  @override
  String get aValueIsStored => 'Vrijednost je pohranjena.';

  @override
  String get access => 'Pristup';

  @override
  String get accessActivity => 'Aktivnost pristupa';

  @override
  String accessArg1(Object? arg1) {
    return 'Pristup: $arg1';
  }

  @override
  String get accessMode => 'Način pristupa';

  @override
  String get accessPermissions => 'Dopuštenja za pristup';

  @override
  String get accessToken => 'pristupni token';

  @override
  String get accessToken2 => 'Pristupni token';

  @override
  String get account => 'Račun';

  @override
  String accountArg1(Object? arg1) {
    return 'Račun #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Upozorenja o promjeni računa';

  @override
  String get accountEmail => 'E-pošta računa';

  @override
  String get accountEmailIsOffUntilThese =>
      'E-pošta računa je isključena dok se ne postave: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent koristi ovaj jezik posvuda u aplikaciji. Kada se prvi put prijavite, slijedi ovaj uređaj. Nakon toga odabir se sprema na vaš račun i koristi se na svakom uređaju.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Nije moguće promijeniti jezik: $error';
  }

  @override
  String get accountLanguageTitle => 'Jezik';

  @override
  String get accountNumber => 'Broj računa';

  @override
  String get accountSettings => 'Postavke računa';

  @override
  String get accounts => 'Računi';

  @override
  String get accountsByTokensUsedAllTime =>
      'Računi prema korištenim tokenima, cijelo vrijeme.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'računala u oblaku računa. Promjene se primjenjuju nakon poslužitelja ';

  @override
  String get accountsOnThisServer => 'Računi na ovom poslužitelju';

  @override
  String get active => 'Aktivno';

  @override
  String get activeSessions => 'Aktivne sesije';

  @override
  String get activeToday => 'Aktivan danas';

  @override
  String get add => 'Dodaj';

  @override
  String get addAProviderCredentialFirstIts =>
      'Prvo dodajte vjerodajnicu davatelja usluga. Njegovi se modeli ovdje pojavljuju jednom ';

  @override
  String get addAgent => 'Dodaj agenta';

  @override
  String get addAnotherSignInMethodBefore =>
      'Dodajte drugu metodu prijave prije uklanjanja ove.';

  @override
  String get addBinding => 'Dodajte uvez';

  @override
  String get addByNameOrId => 'Dodajte po imenu ili ID-u';

  @override
  String get addByNameOrIdInstead => 'Umjesto toga dodajte po imenu ili ID-u';

  @override
  String get addCredentialBinding => 'Dodajte vezanje vjerodajnica';

  @override
  String get addEntry => 'Dodaj unos';

  @override
  String get addKey => 'Dodaj ključ';

  @override
  String get addMcpServer => 'Dodajte MCP poslužitelj';

  @override
  String get addMemory => 'Dodaj memoriju';

  @override
  String get memoryReview => 'Pregledaj';

  @override
  String get memoryReviewPrompt =>
      'Pregledaj sva moja sjećanja i pospremi ih: arhiviraj duplikate, zastarjele činjenice i sve što nema trajnu vrijednost. Zatim mi ukratko reci što si promijenio.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Dodajte više duljine ili drugu vrstu znaka.';

  @override
  String get addPeopleOrGroups => 'Dodajte osobe ili grupe';

  @override
  String get addSecurityKey => 'Dodajte sigurnosni ključ';

  @override
  String get addSomeoneOrAGroup => 'Dodajte nekoga ili grupu';

  @override
  String get addTask => 'Dodaj zadatak';

  @override
  String get addTests => 'Dodajte testove';

  @override
  String get addTestsForThePartsOf =>
      'Dodajte testove za dijelove ovog projekta koji imaju najmanju pokrivenost, a zatim ih pokrenite.';

  @override
  String get addTheirOwnKeysInSettings =>
      'dodati vlastite ključeve u Postavkama.';

  @override
  String get addToPrompt => 'Dodaj u upit';

  @override
  String get added => 'Dodano';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Dodano $arg1 · Zadnji put korišteno $arg2';
  }

  @override
  String get addressWithTheProvider => 'obratite se davatelju usluga.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Prilagodite glasnoću zvučnika, pregledajte zadane postavke hardverskih gumba i upravljajte ovom sesijom pokretača.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Podesite filtar pretraživanja ili statusa da biste vidjeli više kanala za slanje poruka.';

  @override
  String get adjustTheSpeakerVolumeHere => 'Ovdje podesite glasnoću zvučnika.';

  @override
  String get admin => 'Administrator';

  @override
  String adminArg1(Object? arg1) {
    return 'Admin › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Administratorske potpore, veze s pozivnicama i promjene upravljanja prikazuju se ovdje.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Napredni ručni raspored za posebne slučajeve.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Napredno: minuta sat dan mjesec radni dan.';

  @override
  String get againRightAway => 'opet odmah.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent: $arg1';
  }

  @override
  String get agentCalls => 'Pozivi agenta';

  @override
  String get agentCommunication => 'Komunikacija agenta';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Komunikacija agenta: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Način rada agenta uređuje radni prostor · ⌘↵ pošalji · ⌘N nova sesija';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agent zastaje i traži vaše dopuštenje prije izvršavanja.';

  @override
  String get agentProfile => 'Profil agenta';

  @override
  String get agentVisibleName => 'Vidljivo ime agenta';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agent želi koristiti $arg1. Dodirnite za odluku.';
  }

  @override
  String get agents => 'Agenti';

  @override
  String get aiAnswerUnreadable => 'AI odgovor nečitljiv';

  @override
  String get aiProviderKeys => 'Ključevi dobavljača AI';

  @override
  String get aiUnavailable => 'AI nedostupan';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'upozorenja i druge poruke e-pošte računa od.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Upozorava kada veza za razmjenu poruka zahtijeva pozornost korisnika';

  @override
  String get all => 'sve';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Svi agenti ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Svi $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Svi utori za računala u oblaku trenutno su u upotrebi. Pokušajte ponovo za trenutak.';

  @override
  String get allComputerSlotsAreBusy => 'Svi računalni utori su zauzeti';

  @override
  String get allTables => 'Svi stolovi';

  @override
  String get allTime => 'Sve vrijeme';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Svi su alati dopušteni — agent može koristiti bilo koju mogućnost bez pitanja. ';

  @override
  String get allow => 'Dopusti';

  @override
  String get allowedRunsWithoutAsking => 'Dopušteno. Trči bez pitanja.';

  @override
  String get allowAll => 'Dopusti sve';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Dopustite \"Instaliraj nepoznate aplikacije\" za NeoAgent, a zatim pokušajte ponovno ažurirati.';

  @override
  String get allowOnce => 'Dopusti jednom';

  @override
  String get allowSender => 'Dopusti pošiljatelju';

  @override
  String get allowSession => 'Dopusti sesiju';

  @override
  String get allowTheAgentToStartAn =>
      'Dopustite agentu da započne glasovni poziv unutar aplikacije s vama.';

  @override
  String get allowedOrigins => 'Dopušteno podrijetlo';

  @override
  String get allowedPathPrefix => 'Dopušteni prefiks putanje';

  @override
  String get allowsYouCanChangeThatPer =>
      'dopušta. Kasnije to možete promijeniti po osobi. Veze se nikad ne odobravaju ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'već pripada postojećem računu';

  @override
  String get alreadyLinkedToAnotherAccount => 'već povezan s drugim računom';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'već povezan s drugim neoagent računom';

  @override
  String get alreadyUsed => 'već korišten';

  @override
  String get always => 'uvijek';

  @override
  String get alwaysAllow => 'Uvijek dopusti';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '\"Uvijek dopusti\" trajno sprema pravilo — možete ga promijeniti u Postavkama.';

  @override
  String get alwaysAsk => 'Uvijek pitaj';

  @override
  String get alwaysEngage => 'Uvijek angažirati';

  @override
  String get alwaysJoins => 'Uvijek se pridružuje';

  @override
  String get anApiKeyIsRequired => 'Potreban je API ključ.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Večernji sažetak onoga što se dogodilo i što treba pratiti.';

  @override
  String get anHttpOrHttpsUrlIs => 'Potreban je http ili https URL.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'i analitiku. Veze tima žive na stranici tima.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Instalacija Android APK-a nije dostupna na ovoj platformi.';

  @override
  String get androidApp => 'Android aplikacija';

  @override
  String get androidControl => 'Android kontrola';

  @override
  String get androidCouldNotStart => 'Android se nije mogao pokrenuti';

  @override
  String get androidNotificationReceived => 'Android obavijest primljena';

  @override
  String get androidOnly => 'Samo Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Instalacijski program za Android paket nije se mogao otvoriti.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Android zaslon — dodirnite za dodir, povucite za prijelaz';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Odgovara na @spomene o problemima i zahtjeve za povlačenjem';

  @override
  String get anyone => 'bilo tko';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Svatko na ovoj platformi može slati poruke $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Svatko na ovoj platformi može poslati poruku $arg1 u $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Svatko tko može doći do ovog računa može razgovarati sa $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Svatko s vezom može se pridružiti dok ne istekne ili je ne opozovete.';

  @override
  String get apiHttpsOrigin => 'API HTTPS porijeklo';

  @override
  String get apiKey => 'API ključ';

  @override
  String get apiKey2 => 'api ključ';

  @override
  String get apiKey3 => 'API ključ';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api ključ anthropic claude openai gpt xai grok google gemini minimax nvidia nim openrouter vjerodajnice';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API ključevi i krajnje točke za AI, pretraživanje i glasovne usluge. oni ';

  @override
  String get apiRequest => 'API zahtjev';

  @override
  String get apiYourOwnServerASelf =>
      'API -- vaš vlastiti poslužitelj, model s vlastitim hostingom ili neki drugi ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Preuzimanje APK-a nije uspjelo uz HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Potreban je naziv aplikacije.';

  @override
  String get appUpdates => 'Ažuriranja aplikacije';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Ažuriranja aplikacije nisu konfigurirana za ovu verziju.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Primijenjena su $arg1 ažuriranja upravljanja u čekanju na trenutnu vožnju.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Primijenjena ažuriranja upravljača $arg1.';
  }

  @override
  String get apply => 'primijeniti';

  @override
  String get applyBehaviorNotes => 'Primijenite bilješke o ponašanju';

  @override
  String get applyCoreMemory => 'Primjena osnovne memorije';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Zahtjevi za odobrenje za osjetljive agentske alate';

  @override
  String get approvalRequired => 'Potrebno odobrenje';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Odobrenje ostaje unutar vaše autentificirane mobilne sesije, a svaki kod automatski istječe nakon kratkog vremena.';

  @override
  String get approveLogin => 'Odobri prijavu';

  @override
  String get approveQrLogin => 'Odobri QR prijavu';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Odobrite ovo samo ako ste upravo sada započeli prijavu na tom uređaju.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Odobrena prijava za $arg1.';
  }

  @override
  String get approvedOnly => 'Samo odobreno';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Odobreno uparivanje za $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Odobrene osobe i grupe';

  @override
  String get approvedPeopleOnly => 'Samo odobrene osobe';

  @override
  String get archive => 'Arhiva';

  @override
  String get archiveAgent => 'Agent arhive?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Arhiva ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Arhiva $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Arhivirati odabrana sjećanja?';

  @override
  String get areSharedByEveryAccountOn =>
      'dijele svaki račun na ovom poslužitelju; računi još mogu ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M ulaz';
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
    return '$arg1 potreban pristup';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 računi';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktivan';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return 'Dodano $arg1. Uredite ga bilo kada da biste promijenili ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '“$arg1” i njegova povijest pokretanja bit će trajno izbrisani. Svaki aktivni rad će biti zaustavljen. Datoteke u radnom prostoru se ne diraju.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Potrebno odobrenje $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 aplikacije aktivne';
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
    return '$arg1 ($arg2 aktivni alati)';
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
    return '$arg1 $arg2 i $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 promijenjen';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 znakovi';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Stvoren $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [lokalni uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 odgovara \"$arg3\"';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent radni prostor';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 novi računi';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 trči · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 uzorci';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 upravljanje na čekanju';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 tokeni';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 tokeni';
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
    return '$arg1 je postao admin ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 bajtova';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 kanal';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 znakova';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 izbrisano.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 konfiguriran';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 povezan. Odaberite spremišta i osobe pod Tko može slati poruke.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 unosi jezgre.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 je stvorio vezu za pozivnicu';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 radna površina';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 događaji';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 nije uspio';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 nije uspio';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 neuspješno';
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
    return '$arg1 grupe označene samo';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return 'prije ${arg1}h';
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
    return '$arg1 pomagači';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 omjer pogodaka)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 je administrator, tako da se račun ne može izbrisati ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 je blokiran na $arg2. Ažurirajte popis pristupa kako biste omogućili odgovore.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 je povezan i odgovara.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 više nije admin ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 nije dostupan na $arg2 (nedostaje dozvola za vrijeme izvođenja ili ovisnost).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 pridružen pod $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 sudio LLM';
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
    return 'Ključ $arg1 uklonjen.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 lijevo';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 lijevo $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 povezan';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return 'Prije ${arg1}m';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Provjerite radi li, a zatim pokušajte ponovno.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 upravlja ovim računom';
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
    return '$arg1 modeli spremni';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 više';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 više koraka u povijesti trčanja';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 premješten iz $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 mora biti konačan broj.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 mora biti http:// ili https:// adresa.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 treba pozornost';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Radni prostor $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 novi računi u posljednjem $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nove poruke upravljaju ovom trkom';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 nove vožnje';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 sada upravlja ovim računom.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 od 4 dopuštena dopuštenja. Datoteke su ograničene na mapu NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 od $arg2 omogućen';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 od $arg2 grupa pridruži se običnom chatu';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 od $arg2 modela';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 od $arg2 modela spreman';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 od $arg2 skupa';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 od $arg2 alata dopušteno';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: U redu';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 na dan $arg2 u $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 odgovara samo osobama koje dodate ispod.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 odgovara samo kada je označen';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 razgovara samo s ljudima i grupama koje odobravate';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Dodano je $arg1 osoba ili grupa';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 planiranje';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1 pružatelji usluga';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 spreman';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 zapisi';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 URI preusmjeravanja';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registriran';
  }

  @override
  String arg1Replied(Object? arg1) {
    return 'odgovorio je $arg1';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 je opozvao vezu s pozivnicom';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 trči';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 trči · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 radi u posljednjem $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 spremljeno.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return 'Odabrano $arg1';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Prikazan $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 je šutio';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 upravljanje $arg2 u redu';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · dodirnite čvor za pregled';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 koraka';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 je prestao upravljati $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 tokeni';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 tokena u posljednjem $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 alati';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (nedostupno spremljeno nadjačavanje)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return 'Iskorišteno $arg1% · Preostalo $arg2';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 želi razgovarati s vama.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 web';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" će biti trajno uklonjen.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 će upravljati ovim računom';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 neće odgovarati na ovoj platformi';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 neće odgovoriti na $arg2.';
  }

  @override
  String get artifactStorageByUser =>
      'Pohranjivanje artefakata od strane korisnika';

  @override
  String get askAQuestionOrStartA =>
      'Postavite pitanje ili pokrenite zadatak...';

  @override
  String get askBeforeClosingToBackground => 'Pitaj prije zatvaranja pozadine';

  @override
  String get askMe => 'pitaj me';

  @override
  String get assignedAgent => 'Dodijeljeni agent';

  @override
  String get assignedAgent2 => 'Dodijeljeni agent';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Dodijeljeni agent: $arg1';
  }

  @override
  String get assigneeOptional => 'Opunomoćenik (neobavezno)';

  @override
  String get assistant => 'Pomoćnik';

  @override
  String get assistantKey131 => 'Tipka pomoćnika 131';

  @override
  String get atLeast1 => 'Najmanje 1.';

  @override
  String get attachFiles => 'Priložite datoteke';

  @override
  String attentionArg1(Object? arg1) {
    return 'Pažnja $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'zapisnik nadzora administrator odobri opoziv pozvati povijest tima';

  @override
  String get authMethod => 'Auth Method';

  @override
  String get authServerUrl => 'URL poslužitelja za autentifikaciju';

  @override
  String get authentication => 'Autentifikacija';

  @override
  String get authenticationFailed => 'Autentifikacija nije uspjela.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Još je u tijeku provjera autentičnosti. Završite tijek preglednika i pokušajte ponovno.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Još je u tijeku provjera autentičnosti. Završite tijek preglednika i osvježite.';

  @override
  String get authenticationTimedOut => 'Autentikacija je istekla.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Autentifikacija je otkazana prije dovršetka.';

  @override
  String get authenticatorApp => 'Aplikacija autentifikatora';

  @override
  String get authenticatorCode => 'Kod autentifikatora';

  @override
  String get authorOptional => 'Autor (nije obavezno)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Automatski (prvi pružatelj s API ključem)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automatski usmjerava do najboljeg dostupnog modela';

  @override
  String get automaticFast => 'Automatski (brzo)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatski čita sobu i obično se zadržava. Samo spominjanje ne donosi odluke dok mu se izravno ne obrati.';

  @override
  String get automaticReserved => 'Automatski, rezerviran';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Za automatsko vraćanje potrebno je ponovno pokušati sa zaslona za postavljanje.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatski odabire brzi model kroz standardni katalog modela.';

  @override
  String get automation => 'Automatizacija';

  @override
  String get available => 'na raspolaganju';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Ponovno dostupno u $arg1';
  }

  @override
  String get availableAgainShortly => 'Uskoro ponovno dostupno';

  @override
  String get availableInTheDesktopAppFor =>
      'Dostupno u desktop aplikaciji za macOS, Windows i Linux';

  @override
  String get availableToTheAgent => 'Dostupno agentu';

  @override
  String get averageAllTime => 'Prosječno, za sva vremena';

  @override
  String get avgImp => 'Prosj. pojavlj.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Prosjek/izvođenje: $arg1 tokena';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Izbjegavajte znakove koji se ponavljaju i očite nizove.';

  @override
  String get awaitingScan => 'Čeka se skeniranje';

  @override
  String get back => 'natrag';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count u pozadini';
  }

  @override
  String get backgroundTasks => 'Pozadinski zadaci';

  @override
  String get backOn => 'natrag na.';

  @override
  String get backToChat => 'Natrag na chat';

  @override
  String get backToFolder => 'Natrag u mapu';

  @override
  String get backToSignIn => 'Natrag na prijavu';

  @override
  String get backendChannel => 'Pozadinski kanal';

  @override
  String get backendOnThisComputer => 'Backend na ovom računalu';

  @override
  String get backendSync => 'Pozadinska sinkronizacija';

  @override
  String get backgroundLocationNeeded => 'Potrebna lokacija u pozadini';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Sinkronizacija u pozadini ostaje zakazana na Androidu';

  @override
  String get badState => 'Loše stanje: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Osnovna slika i veličina QEMU virtualnih strojeva koji rade ';

  @override
  String get baseUrlOptional => 'Osnovni URL (nije obavezno)';

  @override
  String get baseUrlTokenLocal => 'osnovni url token lokalni';

  @override
  String get basicAuthentication => 'Osnovna autentifikacija';

  @override
  String get behaviorModules => 'Moduli ponašanja';

  @override
  String get behaviorNotes => 'bilješke o ponašanju';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Bitwarden broker vjerodajnica';

  @override
  String get bitwardenItem => 'Bitwarden predmet';

  @override
  String get bitwardenServer => 'Bitwarden poslužitelj';

  @override
  String get blankUsesCommon => 'Prazno koristi \"uobičajeno\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Prazno koristi zadani povratni poziv';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Prazne vrijednosti koriste zadane postavke pružatelja usluga.';

  @override
  String get block => 'Blokiraj';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Blokirana dolazna poruka od $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Most kompatibilan s BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'URL poslužitelja BlueBubbles';

  @override
  String get botToken => 'Bot token';

  @override
  String get botTokenAndApprovedChats => 'Bot token i odobreni chatovi';

  @override
  String get botTokenAndServerChannelAccess =>
      'Bot token i pristup poslužitelju/kanalu';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bot token, Events API i pristup kanalu';

  @override
  String get botUserId => 'ID korisnika bota';

  @override
  String get botUsername => 'Bot korisničko ime';

  @override
  String get brandName => 'Naziv marke';

  @override
  String get braveSearch => 'Hrabra potraga';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Premostite bilo kojeg pružatelja usluga koji može objavljivati i primati podatke web-dojavnika.';

  @override
  String get bringYourOwnKey => 'ponesite svoj ključ';

  @override
  String get bringYourOwnKey2 => 'Ponesite svoj ključ';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Preglednik, radna površina Linuxa, datoteke, terminal i Python dijele jedno trajno računalo u oblaku.';

  @override
  String get browserLogin => 'Prijava u preglednik';

  @override
  String get browserScripting => 'Skriptiranje preglednika';

  @override
  String get call => 'Nazovi';

  @override
  String get callAgent => 'Nazovi agenta';

  @override
  String get callUser => 'Nazovi korisnika';

  @override
  String get calledByName => 'Pozvan imenom';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Može delegirati zadatke drugim agentima';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Može delegirati $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Može primati delegirane zadatke';

  @override
  String get cancel => 'Odustani';

  @override
  String get cancelTask => 'Otkaži zadatak';

  @override
  String get cannotPreview => 'Nije moguće pregledati';

  @override
  String get cannotReceiveDelegatedTasks =>
      'ne može primati delegirane zadatke';

  @override
  String get cannotRunYet => 'još ne može trčati.';

  @override
  String get capturedThePage => 'Snimio stranicu';

  @override
  String get category => 'Kategorija';

  @override
  String chainArg1(Object? arg1) {
    return 'Lanac: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Promjena načina postavljanja';

  @override
  String get channel => 'kanal';

  @override
  String get channelAccessToken => 'Token za pristup kanalu';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanal: $arg1$arg2 | Ažuriranje verzije: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Društveno pamćenje s opsegom kanala';

  @override
  String get channels => 'Kanali';

  @override
  String get chat => 'Razgovarajte';

  @override
  String get chatId => 'ID chata';

  @override
  String get chatMode => 'Način razgovora';

  @override
  String get chatModel => 'Chat model';

  @override
  String get checkAutomaticallyOnLaunch => 'Check automatically on launch';

  @override
  String get checkForMessagesEveryMs => 'Check for messages every (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Automatski provjeri nove poruke';

  @override
  String get checkNow => 'Provjerite sada';

  @override
  String get checkYourEmailToConfirmYour =>
      'Provjerite svoju e-poštu kako biste potvrdili svoj NeoAgent račun prije prijave.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Provjereno $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Odaberite kategoriju ili pretražite sve postavke.';

  @override
  String get chooseAPerson => 'Odaberite osobu';

  @override
  String get chooseAProjectFolder => 'Choose a project folder';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Odaberite zadane postavke za chat, agente, rezervno ponašanje i pametno usmjeravanje.';

  @override
  String get chooseGroups => 'Choose groups';

  @override
  String get chooseHowMuchYouWantTo =>
      'Choose how much you want to configure now. Both options can be changed later.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Odaberite kako bi ovaj zadatak trebao započeti. Ručno se pokreće samo na Run Now. Schedule is time-based. Integracija pokreće vatru iz povezanih službenih aplikacija.';

  @override
  String get chooseOneToGetStartedNow =>
      'Choose one to get started now. Kasnije možete dodati više.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Choose the live model and voice in Settings.';

  @override
  String get chooseTheirGroup => 'Choose their group';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Odaberite gdje bi ova osoba trebala razgovarati sa $arg1. You can change this later under Who can message.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Odaberite kojim se grupama $arg1 treba pridružiti čak i kada ga nitko ne označi. Ova platforma možda neće razlikovati oznake od običnih poruka.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Odaberite koje modele svaki račun na ovom poslužitelju može odabrati i ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Odaberite s kim $arg1 razgovara i kada se pridružuje grupnim razgovorima.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Odaberite tko može doći do $arg1, a zatim spremite promjene.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Odaberite tko može slati poruke agentu s \"Tko može slati poruke\" na WhatsApp kartici.';

  @override
  String get chooseYourDefaultModel => 'Odaberite svoj\nzadani model.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, datoteke, uređivač teksta i terminal dostupni su s radne površine Linuxa.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Očisti';

  @override
  String get clearAll => 'Clear all';

  @override
  String clearArg1(Object? arg1) {
    return 'Clear $arg1?';
  }

  @override
  String get clearFilter => 'Clear filter';

  @override
  String get clearFilters => 'Očisti filtre';

  @override
  String get clearSearch => 'Očisti pretragu';

  @override
  String get clearView => 'Clear view';

  @override
  String get cliSession => 'CLI sesija';

  @override
  String get clickIsNotSupportedOnThis =>
      'click is not supported on this platform.';

  @override
  String get clickOnceToBeginCapturing => 'Kliknite jednom za početak snimanja';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Kliknite, tipkajte i komunicirajte s aplikacijama za stolna računala.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Clicked at ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Clicked in the browser';

  @override
  String get clientId => 'ID klijenta';

  @override
  String get clientSecret => 'Client secret';

  @override
  String get close => 'Zatvori';

  @override
  String get closeJ => 'Close (⌘J)';

  @override
  String get closeTeachMode => 'Close Teach Mode';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Zatvaranjem prozora NeoAgent može nastaviti raditi u pozadini s pristupom traci ili potpuno zatvoriti radnu sredinu radne površine.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Podržane su instance u oblaku i instance koje se samostalno hostiraju. URL-ovi lokalne i privatne mreže rade kada ih NeoAgent može dosegnuti.';

  @override
  String get cloudComputer => 'Računalo u oblaku';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Računalo u oblaku · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Postavke računala u oblaku su spremljene. Restart the server to apply them.';

  @override
  String get cloudComputerVm => 'Cloud computer (VM)';

  @override
  String get cloudComputers => 'Cloud computers';

  @override
  String get codeHosting => 'Kod hostinga';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Comma-separated channel names, without the #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Odvojeni zarezima, na primjer #općenito, #pomoć';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Comma separated. Izdanje mora imati sve njih.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Command failed ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Command is required.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Command output accumulator is not active.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Prijenos izlaza naredbe nije uspio ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Command output upload omitted artifact metadata.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Izlaz naredbe već je dovršen.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Naredbe i aplikacije';

  @override
  String get commandsRunInTheSamePersistent =>
      'Naredbe se izvode na istom trajnom računalu koje koristi vidljiva radna površina.';

  @override
  String get communityChatops => 'Zajednica i ChatOps';

  @override
  String get completeSetup => 'Dovršite postavljanje';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Complete the workflow on the desktop.';

  @override
  String get completed => 'Završeno';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Potpuno blokiran — agent ne može koristiti ovu kategoriju.';

  @override
  String get computerShell => 'Školjka računala';

  @override
  String get computerUsedByThisSession => 'Computer used by this session';

  @override
  String get computerWorkspace => 'Radni prostor za računalo';

  @override
  String get configurablePersonalWebhookBridge =>
      'Configurable personal webhook bridge';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Configurable relay or webhook bridge';

  @override
  String get configurableTalkWebhookBridge =>
      'Configurable Talk webhook bridge';

  @override
  String get configurableWebInboxBridge => 'Configurable web inbox bridge';

  @override
  String get configurableWebhookBridge => 'Configurable webhook bridge';

  @override
  String get configurableWebhooks => 'Konfigurabilni Webhookovi';

  @override
  String get configurationOrInTheEnvFile =>
      'Konfiguracija ili u .env datoteci.';

  @override
  String get configure => 'Konfigurirati';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Configure workspace behavior and model defaults.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Configured $arg1';
  }

  @override
  String get confirmEmailChanges => 'Confirm email changes';

  @override
  String get confirmNewSignUps => 'Confirm new sign-ups';

  @override
  String get confirmPassword => 'Potvrdite lozinku';

  @override
  String get confirmPassword2 => 'Potvrdite lozinku';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Potvrdite svoju e-poštu prije prijave. Provjerite servisnu e-poruku od NeoAgenta.';

  @override
  String get connect => 'Poveži se';

  @override
  String get connectAMessagingPlatform =>
      'Povežite platformu\nza razmjenu poruka.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Povežite javnu krajnju točku HTTPS Home Assistant s Long-Lived Access Tokenom. Lokalne, povratne i privatne mrežne adrese blokira poslužitelj.';

  @override
  String get connectAccount => 'Connect Account';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Pojedinačno povežite račune aplikacija kako bi AI mogao koristiti pravi račun za svaku službenu integraciju.';

  @override
  String connectArg1(Object? arg1) {
    return 'Connect $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Connect as many accounts as you want. Svaka aplikacija može koristiti drugačiji račun.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Povežite kanale, odaberite s kim $arg1 razgovara i pogledajte nedavne aktivnosti.';
  }

  @override
  String get connectInstance => 'Connect Instance';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Prvo povežite ovu integraciju da odaberete račun.';

  @override
  String get connectToThisServer => 'Connect to this server';

  @override
  String get connectWhatsapp => 'Povežite WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Povežite svoju Nextcloud instancu, uključujući samostalne poslužitelje. NeoAgent otvara Nextcloudovu vlastitu stranicu za prijavu tako da se možete prijaviti lozinkom, SSO ili 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Connect your self-hosted NeoRecall server. NeoAgent dobiva pristup samo za čitanje lokalnom pretraživanju, uspomenama i dokazima prijepisa nakon što odobrite zaslon OAuth.';

  @override
  String get connected => 'Povezan';

  @override
  String get connectedAccount => 'Povezani račun';

  @override
  String connectedArg1(Object? arg1) {
    return 'Povezan $arg1';
  }

  @override
  String get connectedInstance => 'Povezana instanca';

  @override
  String get connectedNeorecallUser => 'Povezani NeoRecall korisnik';

  @override
  String get connectedNextcloudUser => 'Povezani Nextcloud korisnik';

  @override
  String get connectedServer => 'Povezan poslužitelj';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Connecting to the live voice model...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Connection #$arg1';
  }

  @override
  String get connectionId => 'Connection ID';

  @override
  String get connectionLooksGood => 'Veza izgleda dobro.';

  @override
  String get connectionMethod => 'Način povezivanja';

  @override
  String get containsTextOptional => 'Sadrži tekst (nije obavezno)';

  @override
  String get content => 'Sadržaj';

  @override
  String get contentSecurityPolicy => 'politika sigurnosti sadržaja';

  @override
  String get continue2 => 'nastavi';

  @override
  String get continueFullSetup => 'Nastavite s punim postavljanjem';

  @override
  String get continueRun => 'Nastavite trčati';

  @override
  String get continueToSetup => 'Nastavite s postavljanjem';

  @override
  String get controlSurface => 'KONTROLNA POVRŠINA';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Controls access to $arg1 tools.';
  }

  @override
  String get conversation => 'Razgovor';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID razgovora koji se koristi kada ovaj agent započne razgovor.';

  @override
  String get cookieSetup => 'Postavljanje kolačića';

  @override
  String get cookiesNotConfigured => 'Kolačići nisu konfigurirani';

  @override
  String get copiedAsCsv => 'Kopirano kao CSV';

  @override
  String get copiedDebugInfo => 'Kopirane informacije o otklanjanju pogrešaka';

  @override
  String get copiedExportForTheLast5 => 'Copied export for the last 5 messages';

  @override
  String get copiedFullPrompt => 'Kopiran cijeli upit';

  @override
  String get copiedLogs => 'Kopirani dnevnici';

  @override
  String get copiedRunId => 'Kopiran ID izvođenja';

  @override
  String get copy => 'Kopiraj';

  @override
  String get copyAll => 'Kopiraj sve';

  @override
  String get copyCodes => 'Kopiraj kodove';

  @override
  String get copyCsv => 'Kopiraj CSV';

  @override
  String get copyDebugInfo => 'Kopiraj informacije o otklanjanju pogrešaka';

  @override
  String get copyLink => 'Kopiraj vezu';

  @override
  String get copyLogs => 'Kopiraj zapise';

  @override
  String get copyPrompt => 'Kopiraj upit';

  @override
  String get copyResponse => 'Kopiraj odgovor';

  @override
  String get copyRunId => 'Kopiraj ID izvođenja';

  @override
  String get copyWebhookUrl => 'Kopiraj URL web-dojavnika';

  @override
  String get core => 'Jezgra';

  @override
  String get coreMemory => 'jezgrena memorija';

  @override
  String get coreServicesThisServerDependsOn =>
      'Osnovne usluge o kojima ovaj poslužitelj ovisi.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domain https public url origins';

  @override
  String get couldHelp => 'Može pomoći';

  @override
  String get couldNotApproveQrLogin => 'Could not approve QR login.';

  @override
  String get couldNotApproveQrPairing => 'Nije moguće odobriti QR uparivanje.';

  @override
  String get couldNotConnect => 'Povezivanje nije uspjelo.';

  @override
  String get couldNotCreateBinding => 'Nije moguće stvoriti obvezujuće.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Could not delete your account: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Nije moguće odspojiti Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Could not disconnect Home Assistant.';

  @override
  String get couldNotDisconnectNeorecall => 'Nije moguće odspojiti NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud => 'Could not disconnect Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Could not disconnect Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Nije moguće izvesti vaše podatke: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Nije moguće učitati odluke';

  @override
  String get couldNotLoadUsageData => 'Could not load usage data.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Nije moguće automatski otvoriti postavke Linuxa.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Could not open the provider linking page.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Nije moguće otvoriti stranicu za prijavu davatelja usluga.';

  @override
  String get couldNotOpenTheReleaseAsset => 'Could not open the release asset.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Nije moguće otvoriti Trello u vašem pregledniku.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Nije moguće otvoriti preuzimanje datoteke radnog prostora.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Nije moguće pročitati paket Android aplikacije.';

  @override
  String get couldNotReadTheApk => 'Nije moguće pročitati APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Nije moguće ukloniti ključ: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Nije moguće spremiti agenta.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Nije moguće spremiti postavke Bitwardena.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Nije moguće spremiti postavke kućnog pomoćnika.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Nije moguće spremiti postavke NeoRecalla.';

  @override
  String get couldNotSaveNextcloudSetup => 'Could not save Nextcloud setup.';

  @override
  String get couldNotSaveTrelloSetup => 'Could not save Trello setup.';

  @override
  String get couldNotSendConfirmationEmail =>
      'nije mogao poslati e-poštu potvrde';

  @override
  String get couldNotStart => 'Nije moguće pokrenuti';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Stvorite';

  @override
  String get createAPasswordFirstToChange =>
      'Create a password first to change your account email.';

  @override
  String get createAPasswordOrLinkAnother =>
      'create a password or link another provider before removing this sign-in method';

  @override
  String get createATaskWhileThisAgent =>
      'Create a task while this agent is selected.';

  @override
  String get createLink => 'Create link';

  @override
  String get createOrModifyFilesInYour =>
      'Create or modify files in your workspace.';

  @override
  String get createPassword => 'Izradi lozinku';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Create specialist bots with separate memory, settings, tools, and account assignments.';

  @override
  String get createTheFirstAccount => 'Napravite prvi račun';

  @override
  String get createUpdateOrDeleteSkills => 'Create, update, or delete skills.';

  @override
  String get creatingYourSkill => 'Stvaranje vaše vještine…';

  @override
  String get credentialBindings => 'Vezivanje vjerodajnica';

  @override
  String get credentialUse => 'Upotreba vjerodajnica';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Cron-based recurring runs and one-time timed execution.';

  @override
  String get cronExpression => 'Cron expression';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter pokreće upit.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + razmaknica';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Trenutačna adresa e-pošte: $arg1';
  }

  @override
  String get currentPassword => 'Trenutna lozinka';

  @override
  String get currentPasswordIsIncorrect => 'trenutna lozinka je netočna';

  @override
  String get currentTwoStepLoginCode => 'Current two-step login code';

  @override
  String get customAccess => 'Prilagođeni pristup';

  @override
  String get customCron => 'Custom Cron';

  @override
  String get customCronMustHave5Fields => 'Custom Cron must have 5 fields.';

  @override
  String get customEndpoint => 'custom endpoint';

  @override
  String get customField => 'Custom field';

  @override
  String get customHeader => 'Custom header';

  @override
  String get customHeadersJson => 'Prilagođena zaglavlja (JSON)';

  @override
  String get customOpenaiCompatible => 'Custom OpenAI-compatible';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Prilagođena krajnja točka kompatibilna s OpenAI-jem';

  @override
  String get customOutgoingUrl => 'Prilagođeni odlazni URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Daily';

  @override
  String get dailyRecap => 'Dnevni rezime';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'upit baze podataka odaberite csv predloške';

  @override
  String dayArg1(Object? arg1) {
    return 'Dan $arg1';
  }

  @override
  String get dayOfMonth => 'Day of month';

  @override
  String get decideWhichToolsYourAgentMay =>
      'decide which tools your agent may use. Vide vaše ime i ';

  @override
  String get decisionHigherUpTheChainWins =>
      'decision higher up the chain wins and shows a lock with the ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Decisions show up here as $arg1 reads approved $arg2 groups. Only the latest 30 are kept, and they reset when the server restarts.';
  }

  @override
  String get decline => 'Odbij';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'deep run · step $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram ključ';

  @override
  String get default2 => 'Zadano';

  @override
  String get default3 => 'ZADANO';

  @override
  String defaultArg1(Object? arg1) {
    return 'Default ($arg1)';
  }

  @override
  String get defaultConversation => 'Zadani razgovor';

  @override
  String get defaultForNewGroups => 'Default for new groups';

  @override
  String get defaultGroupParticipation => 'Zadano sudjelovanje u grupi';

  @override
  String get defaultNeoagentWorkspace => 'Default NeoAgent Workspace';

  @override
  String get defaultOpenai => 'Zadano (OpenAI)';

  @override
  String get defaultRateLimits => 'Zadana ograničenja stope';

  @override
  String get defaultRateLimitsSaved =>
      'Zadana ograničenja brzine su spremljena.';

  @override
  String get defaultRecommended => 'Default (recommended)';

  @override
  String get defaultRouting => 'Default Routing';

  @override
  String get defaultSpace => 'Zadani prostor';

  @override
  String get delete => 'Izbriši';

  @override
  String get deleteAccount => 'Izbriši račun';

  @override
  String get deleteAccountPermanently => 'Trajno izbrisati račun?';

  @override
  String get deleteAnAccount => 'Delete an account';

  @override
  String deleteArg1(Object? arg1) {
    return 'Izbrisati @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Delete ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Delete $arg1 $arg2 permanently?';
  }

  @override
  String get deleteBinding => 'Izbriši vezanje';

  @override
  String get deleteCoreMemoryEntry => 'Izbrisati unos osnovne memorije?';

  @override
  String get deleteForever => 'Izbriši zauvijek';

  @override
  String get deleteMcpServer => 'Izbrisati MCP poslužitelj?';

  @override
  String get deleteMemory => 'Izbrisati memoriju?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Brisanje trajno briše račun i sve njegove podatke ';

  @override
  String get deleteRun => 'Izbrisati trčanje?';

  @override
  String get deleteRun2 => 'Izbriši trčanje';

  @override
  String get deleteSelectedMemories => 'Delete selected memories?';

  @override
  String get deleteSession => 'Izbrisati sesiju?';

  @override
  String get deleteSkill => 'Izbrisati vještinu?';

  @override
  String get deleteTask => 'Izbrisati zadatak?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Izbrisano \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Deleted @$arg1 and all of their data.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Deletion removes all your conversations, memories, files, tasks and ';

  @override
  String get deliverableArtifactProduced =>
      'Proizveden artefakt koji se može isporučiti';

  @override
  String get deliverableCompleted => 'Isporuka završena';

  @override
  String get deliverableExecutionStarted => 'Započelo je izvršenje isporuke';

  @override
  String get deliverableSelected => 'Isporučivo odabrano';

  @override
  String get deliverableValidationFailed => 'Deliverable validation failed';

  @override
  String get deliverableValidationStarted => 'Deliverable validation started';

  @override
  String get deny => 'poreći';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Describe the outcome, then demonstrate it on the desktop';

  @override
  String get describeWhatToBuildOrChange =>
      'Opišite što izgraditi ili promijeniti…';

  @override
  String get description => 'Opis';

  @override
  String get desktopApp => 'Aplikacija za stolna računala';

  @override
  String get desktopAppControlsAvailable => 'Desktop app controls available';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Desktop capture is not available on this platform.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Desktop command output upload cancelled.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Desktop companion command was cancelled.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Prateća veza radne površine istekla je.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Isteklo je vrijeme za rukovanje pratitelja radne površine.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Desktop companion nije dostupan ovdje.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Desktop companion is paused locally.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Rukovanje popratnom porukom na radnoj površini nije uspjelo: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Postavke dopuštenja pratećeg računala nisu dostupne na webu.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Postavke dopuštenja za suradnika na stolnom računalu nisu dostupne na ovoj platformi.';

  @override
  String get desktopCompanionRejected => 'Desktop companion rejected.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Desktop companion response failed: $arg1';
  }

  @override
  String get desktopControl => 'Desktop Control';

  @override
  String get desktopFailedToStart => 'Desktop failed to start';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Desktop stream capture failed: $arg1';
  }

  @override
  String get destinationId => 'ID odredišta';

  @override
  String get deviceAccess => 'Pristup uređaju';

  @override
  String get deviceSettings => 'Postavke uređaja';

  @override
  String get devices => 'Uređaji';

  @override
  String get diagnosticsSaved => 'Diagnostics saved.';

  @override
  String get directBluebubblesImessageBridge =>
      'Izravni BlueBubbles iMessage most';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Direct messages remain responsive. Grupe s popisa dopuštenih koriste donji način sudjelovanja.';

  @override
  String get directoryDoesNotExist => 'Directory does not exist.';

  @override
  String get disable2fa => 'Onemogući 2FA';

  @override
  String get disableAll => 'Onemogući sve';

  @override
  String get discard => 'Discard';

  @override
  String get disconnect => 'Prekini vezu';

  @override
  String get disconnectHomeAssistant => 'Disconnect Home Assistant?';

  @override
  String get disconnectNeorecall => 'Odspojiti NeoRecall?';

  @override
  String get disconnectNextcloud => 'Prekinuti vezu s Nextcloudom?';

  @override
  String get disconnectPlatform => 'Disconnect platform';

  @override
  String get disconnectTrello => 'Disconnect Trello?';

  @override
  String get discoveryFailed => 'Otkriće nije uspjelo';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get displayIdIsRequired => 'Display ID is required.';

  @override
  String get displayName => 'Ime za prikaz';

  @override
  String get displayNameMustBe64Characters =>
      'Display name must be 64 characters or fewer.';

  @override
  String get displayNameSaved => 'Ime za prikaz spremljeno.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Nemojte uključivati ​​svoje korisničko ime ili e-poštu.';

  @override
  String get done => 'Gotovo';

  @override
  String get downloadACopyOfYourData =>
      'Download a copy of your data. Admin accounts can’t delete ';

  @override
  String get downloadACopyOfYourData2 =>
      'Preuzmite kopiju svojih podataka ili trajno izbrišite svoj račun. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Download $arg1';
  }

  @override
  String get downloadUpdate => 'Preuzmite ažuriranje';

  @override
  String get downloadingTheNeoagentBackend => 'Preuzimanje NeoAgent pozadine';

  @override
  String get draft => 'Nacrt';

  @override
  String get dragIsNotSupportedOnThis =>
      'drag is not supported on this platform.';

  @override
  String get draggedOnTheScreen => 'Dragged on the screen';

  @override
  String get dropAnApkOrApkBundle =>
      'Drop an APK or APK bundle here to install it';

  @override
  String get dropApkOrApksHere => 'Ispustite APK ili .apks ovdje';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Trajne upute za glas i stil interakcije. Safety and execution rules still take priority.';

  @override
  String get eGAlexSLaptop => 'npr. Alexovo prijenosno računalo';

  @override
  String get eGMyLocalServer => 'npr. My local server';

  @override
  String get edit => 'Uredi';

  @override
  String get editAgent => 'Uredi agenta';

  @override
  String get editCoreMemoryEntry => 'Uredi unos osnovne memorije';

  @override
  String get editInstructions => 'Uredi upute';

  @override
  String get editMcpServer => 'Uredi MCP poslužitelj';

  @override
  String get editTask => 'Uredi zadatak';

  @override
  String editedArg1(Object? arg1) {
    return 'Edited $arg1';
  }

  @override
  String get email => 'E-mail';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Vlasnicima računa e-poštom o prijavama koje izgledaju neobično.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Pošaljite e-poštu vlasnicima računa kada se promijene detalji o njihovom računu.';

  @override
  String get emailCode => 'Šifra e-pošte';

  @override
  String get emailConfirmationRequired => 'potrebna potvrda e-pošte';

  @override
  String get emailIsAlreadyInUse => 'email je već u upotrebi';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'Email saved. Ako je potrebna potvrda, provjerite novu adresu za NeoAgent vezu za potvrdu.';

  @override
  String get emailSettingsSaved => 'Email settings saved.';

  @override
  String get emailUnverified => 'E-pošta nije potvrđena';

  @override
  String get empty => 'Prazna';

  @override
  String get emptyFile => 'Prazna datoteka';

  @override
  String get emptyFolder => 'Prazna mapa';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Empty uses the server default ($arg1).';
  }

  @override
  String get enable2fa => 'Omogućite 2FA';

  @override
  String get enableAll => 'Omogući sve';

  @override
  String get enableBehaviorModules => 'Omogući module ponašanja';

  @override
  String get enableOrDisableModels => 'Enable or disable models';

  @override
  String get enabled => 'Omogućeno';

  @override
  String get encryptedPrivateToYourAccount =>
      'Šifrirano, privatno za vaš račun';

  @override
  String get end => 'Kraj';

  @override
  String get endCall => 'Prekini poziv';

  @override
  String get endVoiceCall => 'End voice call?';

  @override
  String get endpoint => 'Krajnja točka';

  @override
  String get enterAPassword => 'Unesite lozinku.';

  @override
  String get enterAUsername => 'Unesite korisničko ime.';

  @override
  String get enterAValidEmailAddress => 'Unesite valjanu adresu e-pošte.';

  @override
  String get enterAnAddressManually => 'Unesite adresu ručno';

  @override
  String get enterAnApiKeyFirst => 'Prvo unesite API ključ.';

  @override
  String get enterInviteLink => 'Unesite vezu za pozivnicu';

  @override
  String get enterTheAddressOfANeoagent =>
      'Unesite adresu NeoAgent poslužitelja.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Unesite detalje koje vam je $arg1 dao kako bi $arg2 mogao slati i primati poruke.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Unesite svoj 2FA ili kod za oporavak.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Unesite svoju trenutnu lozinku da je promijenite.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Unesite svoju trenutnu lozinku da biste spremili promjene e-pošte.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Enter your NeoAgent account details.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Enter your username or account email. NeoAgent će poslati vezu za resetiranje ako može odgovarati računu.';

  @override
  String get enterYourUsernameOrEmail =>
      'Unesite svoje korisničko ime ili email.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entitet: $arg1';
  }

  @override
  String get environment => 'okoliš';

  @override
  String get error => 'Greška';

  @override
  String errorArg1(Object? arg1) {
    return '\npogreška: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Pogreške iz nedavnog dnevnika, grupirane po poruci.';

  @override
  String get errorsProblemsFailures => 'pogreške problemi kvarovi';

  @override
  String get eventTypesCommaSeparated => 'Vrste događaja (odvojeno zarezima)';

  @override
  String get every15Minutes => 'Svakih 15 minuta';

  @override
  String get every30Minutes => 'Svakih 30 minuta';

  @override
  String get everyAccountOnThisServerLoses =>
      'Svaki račun na ovom poslužitelju gubi ovaj zajednički ključ. Računi ';

  @override
  String get everyAccountOnThisServerUses =>
      'Svaki račun na ovom poslužitelju koristi ovu adresu za ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Svaka aktivna sesija za ovaj račun završava. Mogu se prijaviti ';

  @override
  String get everyDay0800 => 'Svaki dan · 08:00';

  @override
  String get everyDay2000 => 'Svaki dan · 20:00';

  @override
  String get everyHour => 'Svaki sat';

  @override
  String get everyRunOnThisServerAll =>
      'Svako pokretanje na ovom poslužitelju, cijelo vrijeme.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Svaki osjetljivi alat zahtijeva odobrenje, svaki put.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Svaki alat radi bez pitanja, osim onih osoba ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Svatko u tim grupama, kanalima ili sobama može razgovarati sa $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Everyone in this group';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Sve što je $arg1 isključio za vašeg agenta dolazi ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Everything else is turned off.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Everything is available from the desktop.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Sve što agent može koristiti: službene integracije, MCP poslužitelje i vještine.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Everything you turned off for $arg1 comes back ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Točno web podrijetlo dopušteno je za slanje zahtjeva između podrijetla, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Execute JavaScript inside your browser session.';

  @override
  String get execution => 'Execution';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Execution details are unavailable for this run.';

  @override
  String get executionPlanCreated => 'Execution plan created.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Exercise $arg1 sessions';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[exit $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Expires $arg1';
  }

  @override
  String get explainThisProject => 'Explain this project';

  @override
  String exploredArg1(Object? arg1) {
    return 'Explored $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Explored $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Explored the workspace';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Export failed: $arg1';
  }

  @override
  String get exportLast5Messages => 'Export last 5 messages';

  @override
  String get exportMyData => 'Export my data';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Pokretanje vanjskog preglednika nije uspjelo s izlaznim kodom $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Pokretanje vanjskog preglednika nije podržano na ovoj platformi.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'External browser launch timed out.';

  @override
  String get externalMcpTools => 'External & MCP Tools';

  @override
  String get extraButtons => 'Extra Buttons';

  @override
  String get extractingTheNeoagentRuntime => 'Extracting the NeoAgent runtime';

  @override
  String get failed => 'neuspješno';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Failed to connect: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nije uspjelo povezivanje $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Failed to delete \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'failed to fetch';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Failed to generate prompt: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Pokretanje vanjskog preglednika putem url_launchera nije uspjelo.';

  @override
  String get failedToLaunchOauthFlow => 'Failed to launch OAuth flow.';

  @override
  String get failedToLoadPolicies => 'Učitavanje pravila nije uspjelo';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Nije uspjelo spremanje: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Failed to save MCP server.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Failed to save selection: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Failed to send notification to backend: $arg1';
  }

  @override
  String get fair => 'Pošteno';

  @override
  String get fasterReplies => 'Brži odgovori';

  @override
  String get fewerModelCalls => 'Manje poziva modela';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'field empty to restore the built-in default.';

  @override
  String get fileExceedsThe1MibEditor => 'File exceeds the 1 MiB editor limit.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Datoteka premašuje podržano ograničenje veličine.';

  @override
  String get fileWrites => 'Datoteka piše';

  @override
  String get filename => 'Naziv datoteke';

  @override
  String get files => 'Datoteke';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Ovdje se prikazuju datoteke koje NeoAgent piše ili uređuje u ovoj sesiji.';

  @override
  String get filesSavedByAllUsers => 'Datoteke koje su spremili svi korisnici';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Ispunite odobrene prijave ili provjerite zahtjeve bez prikazivanja tajni AI-ju.';

  @override
  String get finalResponse => 'Konačni odgovor';

  @override
  String get findAPlatform => 'Pronađite platformu';

  @override
  String get findAndFixABug => 'Pronađite i popravite grešku';

  @override
  String get findRecentChats => 'Pronađite nedavne razgovore';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Pronalaženje ispravnog NeoAgent runtimea';

  @override
  String get finish => 'završiti';

  @override
  String get finishAtTheScheduledTime => 'Završite u zakazano vrijeme';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Dovršite prijavu na $arg1 u svom pregledniku, a zatim se ponovno povežite.';
  }

  @override
  String get flowGraph => 'Grafikon toka';

  @override
  String get flutterApp => 'Aplikacija Flutter';

  @override
  String get focusedExecutionProfile => 'Focused execution profile';

  @override
  String get folderIdOptional => 'ID mape (nije obavezno)';

  @override
  String get folderUnavailable => 'Mapa nije dostupna';

  @override
  String get forExampleHttpsMatrixOrg => 'For example https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'For hosted or advanced network setups';

  @override
  String get forLinksInEmailsBlankUses =>
      'Za poveznice u e-pošti. Blank uses the server public URL.';

  @override
  String get forgotPassword => 'Zaboravili ste lozinku?';

  @override
  String get frameUnavailable => 'Okvir nedostupan';

  @override
  String freshnessArg1(Object? arg1) {
    return 'svježina: $arg1';
  }

  @override
  String get fridays1700 => 'Petkom · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Od BotFathera nakon što stvorite bota.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Od sada $arg1 odlučuje koje alate vaš agent može koristiti. oni ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'S portala za razvojne programere Discord, pod vašim botom.';

  @override
  String get fromTheLineDevelopersConsole => 'Iz LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot =>
      'From the Matrix client or bot account.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'S twitchapps.com/tmi ili vaše aplikacije za razvojne programere Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Potpuni upit';

  @override
  String get fullSetup => 'Potpuna postavka';

  @override
  String get general => 'generalno';

  @override
  String get generalSettings => 'Opće postavke';

  @override
  String get generalSettingsSaved => 'Opće postavke su spremljene.';

  @override
  String get generateAPromptForAnotherAi =>
      'Generirajte upit za drugi AI, zalijepite odgovor ovdje za uvoz sjećanja.';

  @override
  String get generatePrompt => 'Generiraj upit';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Pogreška praćenja geoograde: $arg1';
  }

  @override
  String get getInspired => 'Inspirirajte se';

  @override
  String get githubCopilot => 'GitHub kopilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot i OpenAI Codex';

  @override
  String get githubIssueOpened => 'GitHub problem je otvoren';

  @override
  String get neorecallMemoryCreated => 'NeoRecall memorija stvorena';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Provjera izdanja GitHuba nije uspjela s HTTP-om $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Korisni teret izdanja GitHub nije bio popis izdanja.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'GitHub korisničko ime koje je otvorilo problem';

  @override
  String get globalSecurityMode => 'Globalni sigurnosni način rada';

  @override
  String get gmailMessageReceived => 'Gmail poruka primljena';

  @override
  String get good => 'dobro';

  @override
  String get goodAfternoon => 'dobar dan';

  @override
  String get goodEvening => 'dobra večer';

  @override
  String get goodMorning => 'dobro jutro';

  @override
  String get goodPasswordALittleMoreLength =>
      'Dobra lozinka. Malo veća duljina čini ga jačim.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live koristi vaš OpenAI API ključ, Gemini Live vaš Google AI ključ. Promjene se odnose na sljedeći poziv.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Dodijelite dopuštenja za Health Connect prije sinkronizacije.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grupa, kanal ili soba';

  @override
  String get groupType => 'Group type';

  @override
  String get groupsAndChannels => 'Grupe i kanali';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grupe: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Grupe koje $arg1 još nije vidio slijedit će ovo.';
  }

  @override
  String get handlesDirectTasksItself => 'Sam rješava izravne zadatke';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Bez ruku (slobodno razgovarajte, prekidajte bilo kada)';

  @override
  String get headerName => 'Naziv zaglavlja';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Naslovi o temama koje vas zanimaju, filtrirani prema signalu.';

  @override
  String get health => 'zdravlje';

  @override
  String get healthChecks => 'Zdravstveni pregledi';

  @override
  String get healthConnect => 'zdravstveni spoj';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect nije dostupan na ovom uređaju.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Status sinkronizacije Health Connect i pohranjena pozadinska metrika.';

  @override
  String get healthStatusIsUnavailable => 'Zdravstveni status nije dostupan.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Zdravstvena sinkronizacija dostupna je samo na Androidu.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Zapisi srca $arg1';
  }

  @override
  String get heldBack => 'Suzdržan';

  @override
  String get helper => 'pomagač';

  @override
  String helperArg1(Object? arg1) {
    return 'Helper: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'ovdje Prvo opozovite administratora s `neoagent admin revoke $arg1`.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Više vrijednosti čine NeoAgent selektivnijim u grupama.';

  @override
  String get highlyRecommended => 'Topla preporuka';

  @override
  String get holdButton131ForTheAssistant => 'Držite gumb 131 za pomoćnika.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Držite Ctrl+Shift+Razmaknica za razgovor';

  @override
  String get holdToTalk => 'Hold to talk.';

  @override
  String get holdToTalk2 => 'Držite za razgovor';

  @override
  String get home => 'Dom';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Potreban je dugotrajni pristupni token kućnog pomoćnika.';

  @override
  String get homeAssistantSetup => 'Postavljanje kućnog pomoćnika';

  @override
  String get homeAssistantUrl => 'URL kućnog pomoćnika';

  @override
  String get homeAssistantUrlIsRequired => 'Potreban je URL kućnog pomoćnika.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Token kućnog poslužitelja s anketiranjem sobe';

  @override
  String get homeserverUrl => 'URL kućnog poslužitelja';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'hostirana usluga). Vaši ključevi su šifrirani i mogu ih koristiti samo ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Naziv hosta IRC mreže, na primjer irc.libera.chat';

  @override
  String get hourly => 'Svaki sat';

  @override
  String get hourlyInboxCheck => 'Provjera inboxa svaki sat';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Koliko dugo veze za potvrdu ostaju važeće.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Koliko često ovaj agent traži nove poruke u sobi.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Koliko često ovaj agent traži nove Signal poruke.';

  @override
  String get howTeamsWork => 'Kako rade timovi';

  @override
  String get howThisServerIsReachedPlus =>
      'Kako se dolazi do ovog poslužitelja, plus preklopnici na cijelom poslužitelju.';

  @override
  String get httpsSessionCookie => 'kolačić https sesije';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Trenutno ne mogu ispuniti taj zahtjev. Pokušajte ponovno za koji trenutak.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Idle';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Ako $arg1 traži URL web-dojavnika, zalijepite ga kako bi poruke mogle doći do $arg2-a.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Ako taj račun ima potvrđenu e-poštu, NeoAgent će poslati vezu za ponovno postavljanje lozinke.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Ako usluga zahtijeva token na odlaznim zahtjevima.';

  @override
  String get ignoreGroups => 'Ignoriraj grupe';

  @override
  String get ignoreThisChat => 'Ignore this chat';

  @override
  String get ignoredChannels => 'Zanemareni kanali';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Zanemarena neispravna popratna poruka radne površine: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Provedite gornji plan.';

  @override
  String get implementThisPlan => 'Provedite ovaj plan';

  @override
  String get implicitTls => 'Implicit TLS';

  @override
  String get import => 'Import';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Uvoz nije uspio: $arg1';
  }

  @override
  String get importFromComputer => 'Uvoz s računala';

  @override
  String get importMemoryTransfer => 'Import memory transfer?';

  @override
  String get importance => 'Importance';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Uvezene $arg1 memorije, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'In @$arg1’s team';
  }

  @override
  String get inBackground => 'pozadina';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Ovdje će se pojaviti dolazne i odlazne poruke kanala.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Dolazni glasovni pozivi unutar aplikacije od NeoAgenta';

  @override
  String get incomingMessages => 'Dolazne poruke';

  @override
  String get incomingNeoagentCall => 'Incoming NeoAgent call';

  @override
  String get incomingNeoagentCall2 => 'DOLAZNI NEOAGENT POZIV';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Podrška za dolazni webhook i odlazni povratni poziv';

  @override
  String get incorporatingSteering => 'Uključuje upravljanje';

  @override
  String get input => 'Unos';

  @override
  String get inputMode => 'Input mode';

  @override
  String get insertATemplate => 'Insert a template';

  @override
  String get install => 'Instaliraj';

  @override
  String get installASignedSelfContainedRuntime =>
      'Instalirajte potpisano, samostalno runtime. Node.js, npm, Git i naredbe terminala nisu potrebne.';

  @override
  String get installApk => 'Install APK';

  @override
  String get installApkBundle => 'Instalirajte APK/Bundle';

  @override
  String get installApkClickOrDropA =>
      'Instalirajte APK — kliknite ili ispustite .apk datoteku';

  @override
  String get installNeoagent => 'Instalirajte NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Instalirajte NeoAgent na ovo računalo bez terminala ili se povežite s onim koji je već pokrenut.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Instalirajte nova izdanja i odaberite koji kanal ovaj poslužitelj prati.';

  @override
  String get installTheBackend => 'Instalirajte pozadinu';

  @override
  String get installTheCoreWithExtraOptional =>
      'Instalirajte jezgru s dodatnim opcijskim postavkama. Ključevi pružatelja AI dodaju se naknadno, isto kao i Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Instalirajte sigurnu jezgru, a zatim kreirajte svoj račun. Nakon toga dodajte ključeve dobavljača umjetne inteligencije.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Instalirano: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Instalirano: $arg1 • Zadnja provjera: $arg2';
  }

  @override
  String get instructions => 'upute';

  @override
  String get integration => 'Integracija';

  @override
  String get integrationConnections => 'Integracijske veze';

  @override
  String get integrationSettingsSaved => 'Postavke integracije spremljene.';

  @override
  String get integrations => 'Integracije';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integracije/oauth/povratni poziv, i registrirajte to isto ';

  @override
  String get interruptAi => 'Prekid AI';

  @override
  String get invalid2fa => 'nevažeći 2fa';

  @override
  String get invalidArgumentS => 'Nevažeći argument(i): ';

  @override
  String get invalidCredentials => 'nevažeće vjerodajnice';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Nevažeći manifest vremena izvođenja NeoAgenta.';

  @override
  String get inviteLink => 'Pozivni link';

  @override
  String get inviteLinkReady => 'Pozivnica je spremna';

  @override
  String get inviteLinks => 'Linkovi poziva';

  @override
  String get iphoneApp => 'aplikacija za iPhone';

  @override
  String get issues => 'Problemi';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Problemi se pojavljuju kada se dnevnik učita.';

  @override
  String get itCanTBeUndone => 'Ne može se poništiti.';

  @override
  String get itMayHaveBeenDeleted => 'Možda je izbrisano.';

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
    return 'Pridružio se $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Pridružio se u zadnjih 7 dana';

  @override
  String get joiningATeam => 'Pridruživanje timu';

  @override
  String get joiningIsOffHere => 'Pridruživanje je isključeno ovdje';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON polje koje sadrži tekst poruke. Obično tekst.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON polje koje identificira kome je poruka namijenjena.';

  @override
  String get jumpToLatest => 'Skoči na najnovije';

  @override
  String get justNow => 'upravo sada';

  @override
  String get keepNeoagentRunning => 'Nastaviti raditi NeoAgent?';

  @override
  String get keepRunning => 'Keep running';

  @override
  String get keepTaskRunning => 'Neka zadatak radi';

  @override
  String get keepTheVaultAvailable => 'Neka trezor bude dostupan';

  @override
  String get keepThisLauncherUpToDate => 'Održavajte ovaj pokretač ažuriranim.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Držite ovu ploču otvorenom dok platforma ne potvrdi vezu.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Neka računalo ove sesije bude vidljivo';

  @override
  String get keepTrackOfYourAiUsage =>
      'Pratite svoju upotrebu AI. Ograničenja se provode kako bi se osigurala pravedna upotreba na cijeloj platformi.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Nastavite koristiti svoje aplikacije normalno. NeoAgent radi na istom ekranu i pita kad god treba novi pristup.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Održavanje veze ovog uređaja';

  @override
  String get key => 'Ključ';

  @override
  String get keyIsRequired => 'Key is required.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Parovi ključ-vrijednost koji traju u razgovorima.';

  @override
  String get knowledgeGraph => 'Grafikon znanja';

  @override
  String get knowledgeView => 'Pogled znanja';

  @override
  String get labelOnlyYouSeeIt => 'Label (only you see it)';

  @override
  String get labelsOptional => 'Oznake (nije obavezno)';

  @override
  String get last24Hours => 'Posljednja 24 sata';

  @override
  String get last7Days => 'Zadnjih 7 dana';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Zadnjih 7 dana: $arg1 tokeni u $arg2 trčanjima';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Zadnji $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Posljednji: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Zadnja sinkronizacija koja nije prazna · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Zadnja vožnja: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Zadnji put viđen $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Last sign-in $arg1';
  }

  @override
  String get lastSyncSummary => 'Last Sync Summary';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Zadnje korištenje: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Zadnji prozor je završio $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'kasniji start također isključen.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Najnovija serija · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Pokretanje desktop aplikacija nije podržano na ovoj platformi.';

  @override
  String get learnRoomNorms => 'Naučite norme soba';

  @override
  String get leave => 'Otiđi';

  @override
  String get leaveARedirectUriBlankTo =>
      'Ostavite URI za preusmjeravanje prazan da biste koristili <javni URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Leave $arg1’s team?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Ostavite kao zadano osim ako niste prilagodili BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Ostavite token prazan kako biste zadržali trenutno pohranjeni token.';

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
    return 'Let $arg1 manage me';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Neka svi u ovoj grupi razgovaraju sa $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Neka radi dok\nti ne radiš.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Neka NeoAgent klikne, tipka i kreće se kroz vaše aplikacije.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Neka NeoAgent razumije što je vidljivo na vašem ekranu.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Neka netko s kim radite odluči koje alate može koristiti vaš agent ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Neka ova osoba pošalje $arg1 poruku jedan na jedan.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Neka ova osoba razgovara sa $arg1 ovdje, ali ne u privatnim razgovorima ili drugim grupama.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Neka ova osoba razgovara sa $arg1 u privatnim razgovorima iu bilo kojoj grupi koju dijele.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Razina $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Veza $arg1';
  }

  @override
  String get linkCopied => 'Veza je kopirana';

  @override
  String get linkExpiresAfter => 'Veza ističe nakon';

  @override
  String get linkLifetimeHours => 'Životni vijek veze (sati)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Životni vijek veze mora biti od 1 do 8760 sati.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link vrijedi do $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Povezani pružatelji usluga prijave';

  @override
  String get linuxApp => 'Linux aplikacija';

  @override
  String listedArg1(Object? arg1) {
    return 'Na popisu $arg1/';
  }

  @override
  String get listening => 'Slušanje';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Povijest izvršenja uživo, koraci alata i odgovori.';

  @override
  String get liveModel => 'Model uživo';

  @override
  String get liveModelProvider => 'Dobavljač modela uživo';

  @override
  String get liveRun => 'Trčanje uživo';

  @override
  String get liveVoice => 'Glas uživo';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Govorna veza uživo nije dostupna.';

  @override
  String get liveVoiceConnectionWasClosed => 'Govorna veza uživo je prekinuta.';

  @override
  String get liveVoiceDefaults => 'Zadane postavke glasa uživo';

  @override
  String get liveVoiceFailed => 'Glas uživo nije uspio.';

  @override
  String get llmMemoryExportResponse => 'Odgovor na izvoz LLM memorije';

  @override
  String get loadFailed => 'učitavanje nije uspjelo';

  @override
  String get loadingExecutionDetails => 'Učitavanje detalja o izvršenju...';

  @override
  String get loadingNeoagent => 'Učitavanje NeoAgenta';

  @override
  String get loadingRunFlow => 'Učitavanje toka pokretanja...';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'URL-ovi lokalne i privatne mreže podržani su kada ih NeoAgent poslužitelj može dosegnuti. Audio nikada nije izložen NeoAgentu.';

  @override
  String get localApp => 'lokalna aplikacija';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Lokalna pozadinska instalacija nije dostupna na ovoj platformi.';

  @override
  String get localBaseImagePath => 'Putanja lokalne osnovne slike';

  @override
  String get localComputerControlIsAvailableIn =>
      'Lokalna kontrola računala dostupna je u NeoAgent desktop aplikaciji na macOS-u, Windows-u i Linuxu.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Lokalna računalna kontrola ovdje nije dostupna.';

  @override
  String get localModelsUrl => 'lokalni modeli url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Lokalno otkrivanje NeoAgenta privremeno je nedostupno.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Lokalne postavke za aplikaciju NeoAgent. Računalna kontrola uvijek se odvija kroz objedinjeno računalo u oblaku.';

  @override
  String get localSetup => 'LOKALNA POSTAVKA';

  @override
  String get locationCityOrPlace => 'Lokacija (grad ili mjesto)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Lokacija je potrebna za okidače vremenskih događaja';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Inicijalizacija LocationService nije uspjela: $arg1';
  }

  @override
  String get logCopied => 'Dnevnik je kopiran';

  @override
  String get loginPassword => 'Lozinka za prijavu';

  @override
  String get logout => 'Odjava';

  @override
  String get logs => 'Dnevnici';

  @override
  String get logsCopied => 'Dnevnici su kopirani.';

  @override
  String get logsOnThisComputer => 'Zapisi na ovom računalu';

  @override
  String get longLivedAccessToken => 'Dugotrajni pristupni token';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Dugoročno sjećanje, strukturirane činjenice i grafikon znanja.';

  @override
  String get lookedAtTheScreen => 'Pogledao u ekran';

  @override
  String get lookingOnThisComputerAndYour =>
      'Gledajući ovo računalo i vašu lokalnu mrežu...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Gleda unaprijed na sutrašnje sastanke tako da vas ništa ne iznenadi.';

  @override
  String get loopExecution => 'Izvođenje petlje';

  @override
  String get loopPaused => 'Petlja je pauzirana';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'Pristupačnost macOS-a nije dodijeljena NeoAgentu. Dopustite to u postavkama sustava › Privatnost i sigurnost › Pristupačnost.';

  @override
  String get macosApp => 'macOS aplikacija';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'Snimanje zaslona macOS-a nije dopušteno NeoAgentu. Dopustite to u postavkama sustava › Privatnost i sigurnost › Snimanje zaslona, ​​a zatim ponovno otvorite NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Poslužitelji e-pošte koji trebaju lozinku odbit će poslati do nove ';

  @override
  String get main => 'Glavni';

  @override
  String get makeDefault => 'Učini zadanim';

  @override
  String get manage => 'Upravljaj';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Upravljajte e-poštom svog računa, dvofaktorskom autentifikacijom i aktivnim sesijama.';

  @override
  String get managedBy => 'Upravlja';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Upravitelji mogu imati vlastite upravitelje (do četiri razine). A ';

  @override
  String get managing => 'Upravljanje';

  @override
  String get manualDestination => 'Ručno odredište';

  @override
  String get manualTrigger => 'Ručni okidač';

  @override
  String get masterPassword => 'Glavna lozinka';

  @override
  String get matchThisDevice => 'Odgovara ovom uređaju';

  @override
  String get matchedAgainstTitleAndBody => 'Usklađeno s naslovom i tijelom';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Odgovara starom NeoAgent MCP protoku: URL plus metoda autentifikacije.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP poslužitelj';

  @override
  String get mcpServer2 => 'MCP poslužitelj';

  @override
  String get mcpServerUrl => 'URL MCP poslužitelja';

  @override
  String get mcpServers => 'MCP poslužitelji';

  @override
  String get meantForSomeoneElse => 'Namijenjeno nekom drugom';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Izmjerena cijena modela: $arg1';
  }

  @override
  String get memories => 'Sjećanja';

  @override
  String get memory => 'Memorija';

  @override
  String memoryArg1(Object? arg1) {
    return 'Memorija: $arg1';
  }

  @override
  String get memoryInjected => 'Memorija je ubrizgana';

  @override
  String get mentionOrReplyOnly => 'Samo spomeni ili odgovori';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Spojeni zapisnici vremena izvođenja poslužitelja i Fluttera za ovu sesiju aplikacije.';

  @override
  String get messageBodyTemplateJson => 'Predložak tijela poruke (JSON)';

  @override
  String get messageNeedsAccess => 'Poruka treba pristup';

  @override
  String get messageTextField => 'Polje teksta poruke';

  @override
  String get messaging => 'Slanje poruka';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Messaging API push i webhook događaji';

  @override
  String get messagingConnectionNeedsAttention =>
      'Potrebno je obratiti pozornost na vezu s porukama';

  @override
  String get messagingConnections => 'Veze za razmjenu poruka';

  @override
  String get messagingDelivery => 'Dostava poruka';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Pogreška slanja poruka. Molimo pokušajte ponovo.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Snimanje mikrofona neočekivano je zaustavljeno. Pokušajte ponovno.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Greška mikrofona: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofon isključen. Dodirnite za uključivanje zvuka.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Za glas uživo potrebno je dopuštenje mikrofona.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoftovi timovi';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimalna vrijednost doprinosa: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Postavljanje mobitela nije uspjelo.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Postavljanje mobilnog uređaja nije uspjelo jer Java nije dostupna na stroju koji pokreće NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Postavljanje mobilnog uređaja nije uspjelo jer Java nije dostupna na stroju koji pokreće NeoAgent. Instalirajte JDK i pokušajte ponovno.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Postavljanje mobitela nije uspjelo. Provjerite je li Android alat pravilno instaliran i pokušajte ponovno.';

  @override
  String modeArg1(Object? arg1) {
    return 'način: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Način rada zaključava se dok je izvođenje aktivno.';

  @override
  String get model => 'Model';

  @override
  String modelArg1(Object? arg1) {
    return 'Model: $arg1';
  }

  @override
  String get modelAvailability => 'Dostupnost modela';

  @override
  String get modelAvailabilitySaved => 'Dostupnost modela spremljena.';

  @override
  String get modelForThisSession => 'Model za ovu sesiju';

  @override
  String get modelOverride => 'Nadjačavanje modela';

  @override
  String get modelPending => 'Model na čekanju';

  @override
  String get modelTurn => 'Okret modela';

  @override
  String get modelTurnCompleted => 'Zaokret modela dovršen';

  @override
  String get modelTurnStarted => 'Započelo je okretanje modela';

  @override
  String get modelVisibilityHideShowList =>
      'vidljivost modela sakrij prikaži popis';

  @override
  String get models => 'Modeli';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modeli, ponašanje, glas i radni prostor';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modeli, preglednik, glas, dijagnostika...';

  @override
  String get modelsRouting => 'Modeli i usmjeravanje';

  @override
  String get monthly => 'Mjesečno';

  @override
  String get moreActions => 'Više akcija';

  @override
  String get morningBriefing => 'Jutarnji brifing';

  @override
  String get mostUsedAgents => 'Najčešće korištena sredstva';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Najčešće korišteni modeli u prošlom $arg1.';
  }

  @override
  String get mouseKeyboard => 'Miš i tipkovnica';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove nije podržan na ovoj platformi.';

  @override
  String get mustBeReachableOnThePublic =>
      'Mora biti dostupan na javnom internetu -- lokalno i ';

  @override
  String get n24Hours => '24 sata';

  @override
  String get n2faOrRecoveryCode => '2FA ili kod za oporavak';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA zahtijeva da se SESSION_SECRET konfigurira na ovoj implementaciji NeoAgenta.';

  @override
  String get n30Days => '30 dana';

  @override
  String get n365Days => '365 dana';

  @override
  String get n4HourLimitTokens => '4-satno ograničenje (žetoni)';

  @override
  String get n4HourUsage => 'Korištenje 4 sata';

  @override
  String n4hLimitArg1(Object? arg1) {
    return 'Ograničenje od 4 sata $arg1';
  }

  @override
  String get n7DayUsage => 'Korištenje 7 dana';

  @override
  String get n7Days => '7 dana';

  @override
  String get n90Days => '90 dana';

  @override
  String get name => 'Ime';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnaziv: Nova vještina\nopis: Opišite što ova vještina radi\n---\nOvdje napišite upute za ovu vještinu.\n';

  @override
  String get nameOfWhoeverMadeIt => 'ime onoga tko ga je napravio.';

  @override
  String get nameOptional => 'Ime (nije obavezno)';

  @override
  String get nativeAndWebhookChannels => 'Nativni i webhook kanali';

  @override
  String get naturalBubbles => 'Prirodni mjehurići';

  @override
  String get nearbyNeoagentServers => 'NeoAgent poslužitelji u blizini';

  @override
  String get needANewAccountRegister => 'Trebate novi račun? Registrirajte se';

  @override
  String get needAnIdea => 'Trebate ideju?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Trebate odgovoriti · $arg1% da biste govorili';
  }

  @override
  String get needsAttention => 'Treba pozornost';

  @override
  String get needsInput => 'Potreban unos';

  @override
  String get neoagentApp => 'Aplikacija NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent pomoćnik';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent nije mogao provjeriti dostupno pozadinsko vrijeme izvođenja.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent nije mogao završiti lokalno postavljanje.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent nije mogao završiti lokalno postavljanje. $arg1';
  }

  @override
  String get neoagentDebugInfo =>
      'NeoAgent informacije o otklanjanju pogrešaka';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent instalira najnoviji $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning => 'NeoAgent je instaliran i radi.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent nije instaliran na ovom računalu.';

  @override
  String get neoagentIsReady => 'NeoAgent je spreman';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent još uvijek radi na zadatku. Prekinite poziv i saznajte rezultat u chatu ili također otkažite zadatak.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent vašu demonstraciju pretvara u prilagodljiv tijek rada.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent čeka dok koristite radnu površinu.';

  @override
  String get neoagentIsWorking => 'NeoAgent radi';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux računalo';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT TREBA ODLUKU';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'NeoAgent runtime preuzimanja zahtijevaju sigurnu adresu.';

  @override
  String get neoagentServerAddress => 'NeoAgent adresa poslužitelja';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'E-pošta usluge NeoAgent nije spremna. Zamolite operatera poslužitelja da provjeri postavke okruženja e-pošte.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Postavljanje NeoAgent-a nije moglo završiti.';

  @override
  String get neoagentUser => 'Korisnik NeoAgent-a';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent automatski koristi ovo računalo i pita prije nego što upotrijebi vaš ekran, miš, tipkovnicu, datoteke ili naredbeni redak.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent koristi vašu približnu pozadinsku lokaciju za pokretanje podsjetnika o geoogradi (npr. \"Podsjeti me da kupim mlijeko kada prolazim pokraj supermarketa\").\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent radni prostor';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][skup] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall pozadinski URL';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Potreban je pozadinski URL za NeoRecall.';

  @override
  String get neorecallSetup => 'Postavljanje NeoRecall-a';

  @override
  String get networkRequestFailed => 'mrežni zahtjev nije uspio';

  @override
  String get networkWriteRequests => 'Mrežni zahtjevi za pisanje';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'nikad se ne računa u ograničenja zajedničke upotrebe.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Novi računi potvrđuju svoju adresu e-pošte prije prijave.';

  @override
  String get newAccountsPerDay => 'Novi računi po danu';

  @override
  String get newChat => 'Novi chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Nove grupe ostaju tihe osim ako netko ne označi $arg1, dok ih ne uključite.';
  }

  @override
  String get newLink => 'Novi link';

  @override
  String get newPasswordsDoNotMatch => 'Nove lozinke se ne podudaraju.';

  @override
  String get newRecoveryCodes => 'Novi kodovi za oporavak';

  @override
  String get newSession => 'Nova sesija';

  @override
  String get newSessionN => 'Nova sesija (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Nova sesija s istim postavkama';

  @override
  String get newSkill => 'Nova vještina';

  @override
  String get newSkill2 => 'Nova vještina';

  @override
  String get newThisWeek => 'Novo ovaj tjedan';

  @override
  String get newsDigest => 'Sažetak vijesti';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Sljedeći ponovni pokušaj: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Tijek prijave u Nextcloud';

  @override
  String get nextcloudSetup => 'Postavljanje Nextclouda';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'Nextcloud URL';

  @override
  String get nextcloudUrlIsRequired => 'Potreban je URL za Nextcloud.';

  @override
  String get nickname => 'Nadimak';

  @override
  String get noAccountsConnectedYet => 'Još nema povezanih računa.';

  @override
  String get noAccountsFound => 'Nema pronađenih računa.';

  @override
  String get noActiveSessionsFound => 'Nema aktivnih sesija.';

  @override
  String get noAgentsYet => 'Još nema agenata';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Nije konfiguriran nijedan pružatelj AI, pa chat i poruke ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Nema upita za odobrenje — agent radi bez prekida.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Nijedan materijal izdanja $arg1 ne odgovara ovoj platformi.';
  }

  @override
  String get noArguments => '(bez argumenata)';

  @override
  String get noAuth => 'Nema autorizacije';

  @override
  String get noBindingsYet => 'Još nema uveza.';

  @override
  String get noChangesYet => 'Još nema promjena';

  @override
  String get noChannelsFound => 'Nema pronađenih kanala';

  @override
  String get noCloudComputerSlotIsFree =>
      'Nijedan utor za računalo u oblaku trenutno nije slobodan. Pokušajte ponovo za trenutak.';

  @override
  String get noCoreMemoryEntriesYet => 'Još nema unosa osnovne memorije.';

  @override
  String get noDescription => 'Nema opisa';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Trenutno nema dostupnih stolnih zaslona.';

  @override
  String get noDetailAvailable => 'Nema dostupnih detalja';

  @override
  String get noDetailedSyncSummaryYet =>
      'Još nema detaljnog sažetka sinkronizacije.';

  @override
  String get noDetailsCaptured => 'Nema snimljenih detalja.';

  @override
  String get noEmailLinked => 'Nema povezane e-pošte';

  @override
  String get noExternalSignInProvidersLinked =>
      'Nema povezanih vanjskih pružatelja usluga prijave.';

  @override
  String get noGroupMessagesYet => 'Još nema grupnih poruka';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Još nisu dodane osobe specifične za grupu.';

  @override
  String get noGroupsAddedYet => 'Još nije dodana nijedna grupa.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Još nije pronađena nijedna grupa. Nakon što $arg1 vidi grupnu poruku, koristite Pronađi nedavne razgovore i oni će se pojaviti ovdje.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Još nije pronađena nijedna grupa. Nakon što $arg1 vidi grupnu poruku, koristite Pronađi nedavne razgovore.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Nema vraćenog tereta zdravstvenih podataka.';

  @override
  String get noHealthSamplesStoredYet =>
      'Još nema pohranjenih zdravstvenih uzoraka.';

  @override
  String get noHttpClientImplementationForThis =>
      'Nema implementacije HTTP klijenta za ovu platformu.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Za ovaj korak nije zabilježen nikakav ulaz ili izlaz.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Nijedna integracija ne odgovara ovom pretraživanju.';

  @override
  String get noLimit => 'Bez ograničenja';

  @override
  String get noLocalPasswordIsSetYet =>
      'Lokalna lozinka još nije postavljena. Izradite jedan da biste omogućili prijavu korisničkim imenom/lozinkom.';

  @override
  String get noLogEntries => 'Nema unosa u dnevnik.';

  @override
  String get noMatchingSettings => 'Nema odgovarajućih postavki';

  @override
  String get noMcpServersMatchThisSearch =>
      'Nijedan MCP poslužitelj ne odgovara ovoj pretrazi.';

  @override
  String get noMemoryEntriesFound => 'Nema pronađenih memorijskih unosa.';

  @override
  String get noMemorySync => 'Nema sinkronizacije memorije';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Jednom pročita važne i poslane poruke iz posljednjih 12 mjeseci kako bi agent poznavao vaše kontakte i projekte.';

  @override
  String get emailMemory => 'Memorija e-pošte';

  @override
  String get importNow => 'Uvezi sada';

  @override
  String get importOnConnect => 'Uvezi stariju poštu pri povezivanju računa';

  @override
  String get sweepStarting => 'Priprema…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Čitanje e-pošte · $done od $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Čitanje e-pošte · pronađeno $count';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Učenje iz e-pošte · $done od $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Zadnji uvoz: $emails e-poruka · $memories novih sjećanja';
  }

  @override
  String get sweepNothingNew => 'Nema novih e-poruka za uvoz';

  @override
  String sweepFailed(String error) {
    return 'Uvoz nije uspio: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Nijedan model ne odgovara \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Za ovo izvođenje nije zabilježen nijedan zahtjev za model.';

  @override
  String get noModelsDiscoveredYet => 'Još nema otkrivenih modela';

  @override
  String get noModelsSelected => 'Nema odabranih modela';

  @override
  String get noModelsYet => 'Još nema modela';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'nijedan neoagent račun nije povezan s ovim pružateljem usluga';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'NeoAgent backend runtime nije dostupan za ovo računalo.';

  @override
  String get noNetworkConnection => 'Nema mrežne veze';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Nema mrežne veze. Povežite se kako biste nastavili koristiti NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Nema mrežne veze. Ponovno se povežite da biste provjerili ima li ažuriranja.';

  @override
  String get noOne => 'nitko';

  @override
  String get noOneAddedYet => 'Još nitko nije dodao.';

  @override
  String get noOneCanMessage => 'Nitko ne može slati poruke';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Nije pronađen nijedan drugi NeoAgent poslužitelj. Možete ponovno pretraživati ​​ili unijeti adresu ručno.';

  @override
  String get noPeopleAddedYet => 'Još nije dodana nijedna osoba.';

  @override
  String get noPlatformsMatch => 'Nijedna platforma se ne podudara';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Još nema dostupnih pružatelja usluga za konfiguraciju.';

  @override
  String get noRecentChannelActivity => 'Nema nedavnih aktivnosti na kanalu';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Nema rezultata za \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Nema trčanja u ovom rasponu.';

  @override
  String get noRunsMatchTheseFilters =>
      'Nijedna serija ne odgovara ovim filtrima';

  @override
  String get noRunsYet => 'Još nema trčanja';

  @override
  String get noRunsYet2 => 'Još nema trčanja.';

  @override
  String get noSecurityKeyWasProvided => 'Sigurnosni ključ nije dostavljen.';

  @override
  String get noServerUrlSet => 'URL poslužitelja nije postavljen';

  @override
  String get noSessionMatchesThatSearch =>
      'Nijedna sesija ne odgovara toj pretrazi.';

  @override
  String get noSessionsYet => 'Još nema sesija';

  @override
  String get noSkillsMatchTheseFilters =>
      'Nijedna vještina ne odgovara ovim filtrima.';

  @override
  String get noStepsWereRecordedForThis =>
      'Za ovo trčanje nisu zabilježeni koraci.';

  @override
  String get noSummaryAvailable => 'Nema dostupnog sažetka.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Nema zadataka za $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Nijedan alat ne odgovara \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Nema ažuriranja u tijeku';

  @override
  String get noUsageYet => 'Još se ne koristi.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Još nije dostupno nijedno potvrđeno NeoAgent pozadinsko vrijeme izvođenja.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Nitko ga više ne može koristiti. Ljudi koji su se već pridružili ';

  @override
  String get none => 'Nijedan';

  @override
  String get notApprovedYet => 'još nije odobreno';

  @override
  String get notAuthenticated => 'nije ovjeren';

  @override
  String get notCheckedYet => 'Još nije provjereno';

  @override
  String get notConfigured => 'Nije konfigurirano';

  @override
  String get notConnected => 'Nije povezano';

  @override
  String get notConnected2 => 'Nije povezano';

  @override
  String get notInstalled => 'Nije instaliran';

  @override
  String get notNeeded => 'Nije potrebno';

  @override
  String get notNeededEnough => 'Nije dovoljno potrebno';

  @override
  String get notNow => 'Ne sad';

  @override
  String get notNow2 => 'Ne sada';

  @override
  String get notSet => 'Nije postavljeno';

  @override
  String get notSetUp => 'Nije postavljeno';

  @override
  String get notTheSameAsAdmin => 'Nije isto što i admin';

  @override
  String get nothingFound => 'Ništa nije pronađeno';

  @override
  String get nothingHereYet => 'Ovdje još nema ništa.';

  @override
  String get nothingHereYet2 => 'Ovdje još nema ništa';

  @override
  String get nothingMatches => 'Ništa ne odgovara';

  @override
  String get nothingStoredYet => 'Još ništa nije pohranjeno.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'OAuth ID klijenta';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth ID klijenta tajno preusmjeravanje API ključ';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth ID klijenta tajno preusmjeravanje gmail kalendar pogon';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'OAuth pokretanje nije podržano na ovoj platformi.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook stanar tajni ID klijenta';

  @override
  String get oauthToken => 'OAuth token';

  @override
  String get oauthWithPkce => 'OAuth s PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'od $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'vlastitog. Nikad se više ne prikazuje nakon spremanja.';

  @override
  String get off => 'Isključeno';

  @override
  String get officialIntegration => 'Službena integracija';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Službena integracija nije vratila URL veze.';

  @override
  String get on => 'Uključeno';

  @override
  String get onASignedInAndroidDevice =>
      'Na Android uređaju na kojem ste prijavljeni otvorite Postavke › Prijava i sigurnost, skenirajte ovaj kod i odobrite prijavu.';

  @override
  String get onByDefaultForNewGroups =>
      'Uključeno prema zadanim postavkama za nove grupe';

  @override
  String get onDemand => 'Na zahtjev';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Uključeno za $arg1 od $arg2 grupa';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'na. Mogu se ponovno pridružiti samo s novom vezom s pozivnicom.';

  @override
  String get onYourOwnTheDefault => 'Sami (zadano)';

  @override
  String get once => 'Jednom';

  @override
  String get oneIsSavedOtherChangesIn =>
      'jedan je spašen. Ostale promjene u ovom obrascu su također spremljene.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Jedan ili više računa je isteklo. Ponovno povežite zahvaćeni račun kako biste vratili pristup alatu.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Jedno vrijeme izvođenja kontrolira osobnost, redoslijed grupe, memoriju sobe, norme, teoriju uma i isporuku.';

  @override
  String get oneTimeRun => 'Jednokratno trčanje';

  @override
  String get onlyApkOrApksFilesCan =>
      'Mogu se instalirati samo .apk ili .apks datoteke.';

  @override
  String get onlyInThisGroup => 'Samo u ovoj grupi';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Potrebno samo ako usluga traži dodatna HTTP zaglavlja.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Potrebno je samo ako želite preoblikovati odlazni teret.';

  @override
  String get onlyTheyCanChangeIt => 'Samo oni to mogu promijeniti.';

  @override
  String get open => 'Otvoreno';

  @override
  String get openAccountSettingsOnASigned =>
      'Otvorite Postavke › Prijava i sigurnost na Android uređaju na kojem ste prijavljeni, skenirajte ovaj kod i odobrite prijavu.';

  @override
  String get openComputer => 'Otvori računalo';

  @override
  String get openDashboard => 'Otvori nadzornu ploču';

  @override
  String get openFolder => 'Otvori mapu…';

  @override
  String get openInWorkbench => 'Otvori u radnom stolu';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Otvorite NeoAgent i ponovno povežite $arg1 za vraćanje poruka.';
  }

  @override
  String get openTimeSettings => 'Otvorene postavke vremena';

  @override
  String get openToAnyone => 'Otvoreno za svakoga';

  @override
  String get openTrello => 'Otvorite Trello';

  @override
  String get openVoiceAssistant => 'Otvorite glasovnog pomoćnika';

  @override
  String get openWiFiSettings => 'Otvorite Wi-Fi postavke';

  @override
  String get openWithTheDefaultApp => 'Otvorite sa zadanom aplikacijom';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'openai kompatibilan';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'OpenAI-kompatibilna krajnja točka (vaš vlastiti poslužitelj ili neki drugi ';

  @override
  String openedArg1(Object? arg1) {
    return 'Otvoren $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Otvaranje URL-ova stolnih računala nije podržano na ovoj platformi.';

  @override
  String get openingYourSavedDesktop => 'Otvaranje spremljene radne površine.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Otvaranje spremljene radne površine. Normalno pokretanje traje manje od 10 sekundi.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Neobavezna dodatna tajna ako zaštitite ulazni webdojavnik.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Izborno nadjačavanje ako URL web-dojavnika nije dovoljan.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Neobavezna tajna za provjeru dolaznih Chat događaja.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Neobavezna tajna za provjeru dolaznih događaja.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Dodatna tajna za provjeru dolaznih iMessage događaja.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Neobavezna tajna za provjeru dolaznih LINE događaja.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Neobavezna tajna za provjeru dolaznih Mattermost događaja.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Neobavezna tajna za provjeru dolaznih Teams događaja.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Neobavezno. Agent već ima svoju osobnost. Sve što dodate o tonu je slojevito iznad toga, tako da ga nikada ne morate definirati.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Neobavezno. Kada je postavljeno, koristi se umjesto URL-a.';

  @override
  String get orAnswerInYourOwnWords => 'Ili odgovorite svojim riječima';

  @override
  String get orBuildYourOwnTask => 'Ili izgradite vlastiti zadatak';

  @override
  String get orContinueWith => 'ili nastaviti s';

  @override
  String get orFiles => 'ili datoteke.';

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
  String get originNotAllowed => 'porijeklo nije dopušteno';

  @override
  String get outgoingMessage => 'Odlazna poruka';

  @override
  String get outgoingWebhookUrl => 'Odlazni URL web-dojavnika';

  @override
  String get outlookEmailReceived => 'Outlook e-pošta primljena';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Prebriši bilješke o ponašanju iz uvoza.';

  @override
  String get ownModel => 'vlastiti model';

  @override
  String get packageName => 'Naziv paketa';

  @override
  String get pairWithQrCode => 'Uparite s QR kodom';

  @override
  String get password => 'Lozinka';

  @override
  String get password2faAndActiveSessions => 'Lozinka, 2FA i aktivne sesije';

  @override
  String get passwordCreated => 'Lozinka stvorena.';

  @override
  String get passwordIsTooWeak => 'lozinka je preslaba';

  @override
  String get passwordMin8 => 'lozinka min. 8';

  @override
  String get passwordOrApiKey => 'Lozinka ili API ključ';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Snaga lozinke: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Lozinke se ne podudaraju.';

  @override
  String get pasteAKey => 'Zalijepite ključ.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Zalijepite novi ključ da biste zamijenili $arg1';
  }

  @override
  String get pasteTheKey => 'Zalijepite ključ';

  @override
  String get pasteYourAccountToken => 'Zalijepite token svog računa';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Zalijepite svoj $arg1 API ključ ispod. To je ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Put mora ostati unutar NeoAgent radnog prostora.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Put mora ostati unutar mape radnog prostora.';

  @override
  String get pauseLiveUpdates => 'Pauzirajte ažuriranja uživo';

  @override
  String get pauseTaskLoop => 'Pauziraj petlju zadatka';

  @override
  String get paused => 'Pauzirano';

  @override
  String peakArg1(Object? arg1) {
    return 'vrh $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Ljudi u privatnim razgovorima';

  @override
  String get perAccountRateLimits => 'Ograničenja stopa po računu';

  @override
  String get perCategoryPermissions => 'Dopuštenja po kategoriji';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Pravila dopuštenja po alatu, vrata za odobrenje i izolacija procesa za izvršavanje ljuske.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Potrebna dozvola: $arg1';
  }

  @override
  String get permissionsNeeded => 'Potrebna dopuštenja';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Dozvole. Nitko drugi to ne može promijeniti.';

  @override
  String get personOrChat => 'Osoba ili chat';

  @override
  String get personaBehaviorNotes => 'Bilješke o ponašanju osobe';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Osobni pristupni token za Mattermost bot.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Osobni kanali i izravne potporne površine.';

  @override
  String get personalSelfChat => 'Osobni samorazgovor';

  @override
  String get phoneNumber => 'Broj telefona';

  @override
  String get pickARunFromTheList =>
      'Odaberite trčanje s popisa da biste vidjeli njegove korake.';

  @override
  String get pickARunFromTheList2 =>
      'Odaberite vožnju s popisa s lijeve strane kako biste istražili njen tijek.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Odaberite iz nedavnih $arg1 chatova ili sami dodajte osobu ili grupu.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Odaberite kako $arg1 koristi ovaj račun.';
  }

  @override
  String get pickOneToFillInThe =>
      'Odaberite jedan za ispunjavanje zadatka. Poslije možete sve podesiti.';

  @override
  String get picksUpWhereYouLeftOff => 'Nastavlja tamo gdje ste stali';

  @override
  String get plan => 'Planirajte';

  @override
  String get planning => 'Planiranje';

  @override
  String get platform => 'Platforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Odaberite raspored.';

  @override
  String get pleaseEnterAFilename => 'Unesite naziv datoteke.';

  @override
  String get pleaseEnterAKey => 'Unesite ključ.';

  @override
  String get pleaseEnterAPrompt => 'Unesite upit.';

  @override
  String get pleaseEnterATaskName => 'Unesite naziv zadatka.';

  @override
  String get pleaseEnterTheMemoryContent => 'Unesite sadržaj memorije.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Unesite kada se zadatak treba pokrenuti.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Odaberite račun ili unesite važeći ID veze.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Usmjerite NeoAgent na bilo koji završetak razgovora koji je kompatibilan s OpenAI-jem ';

  @override
  String get pointTheCameraAtTheCode =>
      'Usmjerite kameru prema kodu prikazanom na odjavljenom uređaju. Odobrenje ostaje na ovom telefonu.';

  @override
  String get port => 'Luka';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env javni url trust proxy sigurni kolačići implementacija';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Vrhunska automatizacija s rasporedom i integracijskim okidačima.';

  @override
  String get prepareQrCode => 'Pripremite QR kod';

  @override
  String get preparingNeoagent => 'Priprema NeoAgenta…';

  @override
  String get preparingNeoagent2 => 'Priprema NeoAgenta';

  @override
  String get pressAndHoldForQuickCapture =>
      'Pritisnite i držite za brzo snimanje';

  @override
  String get pressKeysIsNotSupportedOn =>
      'pritisnite tipke nije podržano na ovoj platformi.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Pritisnuto $arg1';
  }

  @override
  String get priceUnknown => 'Cijena nepoznata';

  @override
  String get primaryDisplay => 'Primarni zaslon';

  @override
  String get privateChat => 'Privatni razgovor';

  @override
  String get privateChats => 'Privatni razgovori';

  @override
  String get privateChats2 => 'privatni razgovori';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Privatni razgovori: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Privatni razgovori $arg1 · grupe $arg2';
  }

  @override
  String get privateChatsOnly => 'Samo privatni razgovori';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'privatne mrežne adrese nisu dopuštene.';

  @override
  String get profileEmailAndPersonalData => 'Profil, e-mail i osobni podaci';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Pitaj prije nego što NeoAgent ostane prisutan u programskoj traci.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Predmemorija upita: $arg1 predmemorirani tokeni ';
  }

  @override
  String get promptCopied => 'Upit kopiran.';

  @override
  String get promptOrSchedule => 'brz ili raspored.';

  @override
  String get promptToPasteIntoAnotherAi =>
      'Zahtjev za lijepljenje u drugu umjetnu inteligenciju';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Povezivanje pružatelja nije moguće pokrenuti.';

  @override
  String get providerSignInCouldNotBe =>
      'Nije moguće pokrenuti prijavu davatelja usluga.';

  @override
  String get providers => 'Pružatelji usluga';

  @override
  String get providersEachAccountCanStillPick =>
      'Pružatelji usluga; svaki račun i dalje može odabrati vlastiti model u postavkama. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Pružatelji usluga, integracije, glas i izborne mogućnosti mogu se dovršiti u Postavkama u bilo kojem trenutku.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Javna pitanja i niti zahtjeva za povlačenjem, odgovoreno samo odobrenim osobama.';

  @override
  String get publicUrl => 'Javni URL';

  @override
  String get publicUrlAndAllowedOrigins => 'Javni URL i dopušteni izvori';

  @override
  String get publicUrlOverride => 'Nadjačavanje javnog URL-a';

  @override
  String get pullsTogetherTheDayAhead => 'Spaja dan pred nama';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'Telefonsko povezivanje temeljeno na QR-u';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR prijava je dovršena, ali NeoAgent nije mogao održati sesiju. Molimo pokušajte ponovo.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'QR prijava nije mogla biti pokrenuta.';

  @override
  String get qrLoginRequestHasExpired => 'qr zahtjev za prijavu je istekao';

  @override
  String get qrLoginRequestWasNotFound => 'qr zahtjev za prijavu nije pronađen';

  @override
  String get qrPairing => 'QR uparivanje';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'pokretanje upita; sve što piše se odbija.';

  @override
  String get queryFilter => 'Upit/filtar';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Na čekanju kao upravljač za trenutnu vožnju: $arg1';
  }

  @override
  String get quickstart => 'Brzi početak';

  @override
  String get quit => 'Odustati';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'kiša_početak, vjetar_uzbuna';

  @override
  String get ranAScriptInThePage => 'Pokreni skriptu na stranici';

  @override
  String ranArg1(Object? arg1) {
    return 'Trčao je $arg1';
  }

  @override
  String get rateLimits => 'Ograničenja stope';

  @override
  String get readAnArtifact => 'Pročitajte artefakt';

  @override
  String get readAndEditFilesInsideYour =>
      'Čitajte i uređujte datoteke unutar mape NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Pročitajte $arg1';
  }

  @override
  String get readError => 'Pogreška čitanja';

  @override
  String get readFiles => 'Čitaj datoteke';

  @override
  String get readOnly => 'Samo za čitanje';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Pročitajte mapu i sažeti stog, ulazne točke i kako ga pokrenuti.';

  @override
  String get readThePage => 'Pročitajte stranicu';

  @override
  String get readTheUiTree => 'Pročitajte UI stablo';

  @override
  String get readWrite => 'Čitaj/Piši';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Očitava korake, broj otkucaja srca, spavanje, vježbanje i težinu.';

  @override
  String get ready => 'spreman';

  @override
  String get readyForFirstTimeSetup => 'Spremno za prvo postavljanje';

  @override
  String get readyToConnect => 'Spremno za spajanje';

  @override
  String get recentChannelActivity => 'Nedavna aktivnost kanala';

  @override
  String get recentChats => 'Nedavni razgovori';

  @override
  String get recentDecisions => 'Nedavne odluke';

  @override
  String get recentFailedRuns => 'Nedavna neuspjela izvođenja';

  @override
  String get recentGroupDecisions => 'Nedavne grupne odluke';

  @override
  String get recentRuns => 'Nedavna izvođenja';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Nedavna izvođenja traju oko $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Najnoviji izlaz poslužitelja, prvo najnoviji.';

  @override
  String get recentUsage4Hours => 'Nedavna upotreba (4 sata)';

  @override
  String get recents => 'Nedavni';

  @override
  String get recipientField => 'Polje primatelja';

  @override
  String get reconnectOrFinishSetup =>
      'Ponovno se povežite ili dovršite postavljanje';

  @override
  String get reconnectingThisDevice => 'Ponovno povezivanje ovog uređaja…';

  @override
  String get recurring => 'Ponavljajuće';

  @override
  String get redirectUri => 'Preusmjeri URI';

  @override
  String get redoOnboarding => 'Ponovi integraciju';

  @override
  String get refresh => 'Osvježi';

  @override
  String get refreshCode => 'Osvježi kôd';

  @override
  String get refreshNow => 'Osvježi sada';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Osvježite zaslon Androida da biste pokušali ponovno.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Odbijte slanje osim ako se veza ne nadogradi na TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'bez obzira na postavke po kategorijama u nastavku.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Registrirajte $arg1 za tok pozivanja pomoćnika.';
  }

  @override
  String get registrationIsClosed => 'registracija je zatvorena';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registracija registrirati nove račune omogućiti prijavu';

  @override
  String get rejectInvalidTlsCertificates => 'Odbaci nevažeće TLS certifikate';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'otpustite i ponovno pokrenite. Povezane aplikacije ponovno se povezuju kada se vrati.';

  @override
  String get releaseChannel => 'Oslobodi kanal';

  @override
  String get releaseCommitBranchNode => 'otpuštanje čvora grane predaje';

  @override
  String get releaseWhenYouAreDone => 'Otpustite kad završite.';

  @override
  String get reloadNow => 'Ponovno učitaj sada';

  @override
  String get rememberThisChoice => 'Zapamtite ovaj izbor';

  @override
  String get remove => 'Ukloniti';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Ukloniti \"$arg1\" i njegove snimljene korake iz povijesti trčanja?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Uklonite \"$arg1\" iz memorije jezgre.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Ukloniti ključ $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'ukloniti brisanje gdpr korisnika';

  @override
  String get removeSmtpPassword => 'Ukloni SMTP lozinku';

  @override
  String get removeTheSmtpPassword => 'Ukloniti SMTP lozinku?';

  @override
  String get rename => 'Preimenuj';

  @override
  String get renameSecurityKey => 'Preimenujte sigurnosni ključ';

  @override
  String get renameSession => 'Preimenuj sesiju';

  @override
  String get repairAndRetry => 'Popravite i pokušajte ponovno';

  @override
  String get repairDesktop => 'Popravak radne površine';

  @override
  String get repeat => 'Ponovi';

  @override
  String get repliesWhenTagged => 'Odgovara kada je označen';

  @override
  String get replyToAddress => 'Adresa za odgovor';

  @override
  String replyToArg1(Object? arg1) {
    return 'Odgovori $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Repozitorij mora biti u formatu vlasnik/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reproducirajte grešku koju opisujem, pronađite glavni uzrok i popravite je regresijskim testom.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'zahtjev nije uspio s http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Zahtjev nije uspio s HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Zatraži dopuštenja';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Zahtjev prema $arg1 nije uspio prije nego što je pozadina odgovorila.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Zatraženo $arg1';
  }

  @override
  String get requireStarttls => 'Zahtijevaj STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Potreban iza HTTPS ili TLS proxyja. Primjenjuje se nakon poslužitelja ';

  @override
  String get requiredExampleBerlinDe => 'Obavezno. Primjer: Berlin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Obavezno. Format: vlasnik/repo';

  @override
  String get reserveAssistantHotkey => 'Rezervirajte pomoćnu tipku prečaca';

  @override
  String get reset => 'Resetiraj';

  @override
  String get resetPassword => 'Resetiraj lozinku';

  @override
  String get resetView => 'Resetiraj prikaz';

  @override
  String get responsibilities => 'Odgovornosti';

  @override
  String get restart => 'Ponovno pokretanje';

  @override
  String get restartToFinishTheUpdate =>
      ' Ponovno pokrenite da biste dovršili ažuriranje.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Vraćanje prethodnog vremena izvođenja NeoAgenta';

  @override
  String get restrictDelegationTargets => 'Ograničite ciljeve delegiranja';

  @override
  String get result => 'Rezultat';

  @override
  String get resultDelivery => 'Isporuka rezultata';

  @override
  String get resultOneClickAddsOneYou =>
      'rezultat. Jedan klik dodaje jedno; možete ga urediti kasnije.';

  @override
  String get results => 'Rezultati';

  @override
  String get retry => 'Pokušaj ponovo';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Za višekratnu upotrebu · korišten $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Pregledajte neizvršene izmjene';

  @override
  String get revoke => 'opozvati';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Prvo opozovite administratora s `neoagent admin revoke $arg1`';
  }

  @override
  String get revokeThisLink => 'Opozvati ovu vezu?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Serijski prozor sobe: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Okrenite za nastavak';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'redaka. Dodajte LIMIT ili užu klauzulu WHERE da vidite ';

  @override
  String get rule => 'pravilo';

  @override
  String get run => 'Izvršavanje';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Pokrenite proizvoljne naredbe na svom računalu ili VM-u.';

  @override
  String get runAt => 'Trčanje na';

  @override
  String get runCompleted => 'Trčanje dovršeno';

  @override
  String get runFailed => 'Izvođenje nije uspjelo';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Pokrenite git diff, pregledajte neizvršene promjene za bugove i probleme sa stilom i rezimirajte ono što ste pronašli.';

  @override
  String get runNotFound => 'Izvođenje nije pronađeno';

  @override
  String get runNow => 'Pokreni sada';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Pokrenite dolazne osobne WhatsApp poruke.';

  @override
  String get runQuery => 'Pokreni upit';

  @override
  String get runShellCommandsOrInstallApps =>
      'Pokrenite naredbe ljuske ili instalirajte aplikacije na svoj Android uređaj.';

  @override
  String get runStarted => 'Trčanje je počelo';

  @override
  String get runStatus => 'Status pokretanja';

  @override
  String get runStopped => 'Trčanje zaustavljeno';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Izvršite terminalske naredbe i otvorite aplikacije ili web stranice.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Pokreni ovaj poslužitelj: računi, ažuriranja, pružatelji usluga, konfiguracija ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Pokreni kada stigne odgovarajuća Gmail poruka.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Pokreni kada stigne odgovarajuća Outlook e-pošta.';

  @override
  String get runWhenANewIssueMatching =>
      'Pokreni kada se u repozitoriju otvori novi problem koji odgovara vašim filtrima.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Pokreni kada se stvori nova NeoRecall memorija koja odgovara vašim filtrima.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Pokrenite kada na vaš uređaj stigne obavijest.';

  @override
  String get runWhenASlackMessageMatches =>
      'Pokreni kada Slack poruka odgovara odabranom opsegu.';

  @override
  String get runWhenATeamsChatMessage =>
      'Pokreni kada Teams chat poruka odgovara odabranom opsegu.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Pokreni kada se za lokaciju predviđaju konfigurirani vremenski događaji.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'trčanje. Dok je bilo koji model isključen, modeli koje pružatelji dodaju ';

  @override
  String get running => 'U tijeku';

  @override
  String runningArg1(Object? arg1) {
    return 'Pokreće se $arg1';
  }

  @override
  String get runningTask => 'Zadatak u tijeku';

  @override
  String get runningTool => 'Alat za trčanje';

  @override
  String get runs => 'Izvršavanja';

  @override
  String get runsEveryDayAtTheSelected => 'Radi svaki dan u odabrano vrijeme.';

  @override
  String get runsFourTimesPerHour => 'Radi četiri puta na sat.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— izvodi, poruke, sjećanja, integracije, datoteke i ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'pokretanja, poruke, sjećanja, integracije, datoteke i sesije. ';

  @override
  String get runsMondayThroughFriday => 'Traje od ponedjeljka do petka.';

  @override
  String get runsOnSelectedWeekdays => 'Radi odabranim radnim danima.';

  @override
  String get runsOncePerHour => 'Radi jednom na sat.';

  @override
  String get runsOncePerMonthOnThe =>
      'Pokreće se jednom mjesečno na odabrani dan.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Pokreće se samo kada pritisnete Run Now.';

  @override
  String get runsPerDay => 'Radi po danu';

  @override
  String get runsPerDay30Days => 'Izvodi po danu (30 dana)';

  @override
  String get runsThatCompleted => 'Runs koji je dovršen';

  @override
  String get runsThisWeek => 'Radi ovaj tjedan';

  @override
  String get runsToday => 'Radi danas';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Trčanja, alati, memorija, raspored, vještine i MCP dostupni su ovdje.';

  @override
  String get runsTwicePerHour => 'Radi dva puta po satu.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Izvođanja će se vratiti na zajednički ključ poslužitelja za $arg1, ako je konfiguriran. Ovo se ne može poništiti.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Vrijeme izvođenja $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Vrijeme izvođenja: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Postavke vremena izvođenja s kojima je ovaj poslužitelj započeo. Uredite ih pod ';

  @override
  String get runtimeSetupRequired => 'Potrebna je postavka vremena izvođenja';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Javni ključ za potpisivanje vremena izvođenja mora imati 32 bajta.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'spremiti';

  @override
  String get saveATrelloApiKeyFor =>
      'Spremite Trello API ključ za ovog agenta, a zatim sigurno povežite jedan Trello račun. Token računa pohranjen je na poslužitelju i koristi se samo za ovog agenta.';

  @override
  String get saveAccount => 'Spremi račun';

  @override
  String get saveChanges => 'Spremite promjene';

  @override
  String get saveCloudComputerSettings => 'Spremite postavke računala u oblaku';

  @override
  String get saveConnect => 'Spremi i poveži se';

  @override
  String get saveDefaults => 'Spremi zadane postavke';

  @override
  String get saveDiagnosticReport => 'Spremi dijagnostičko izvješće';

  @override
  String get saveEmail => 'Spremi e-poštu';

  @override
  String get saveEmailSettings => 'Spremi postavke e-pošte';

  @override
  String get saveGeneralSettings => 'Spremite opće postavke';

  @override
  String get saveName => 'Spremi ime';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Spremite dijagnostiku postavljanja NeoAgenta';

  @override
  String get saveOnly => 'Samo spremanje';

  @override
  String get saveSetup => 'Spremi postavke';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Spremite ove kodove za oporavak sada. Neće se više prikazivati.';

  @override
  String get savedDeliveryDestination => 'Spremljeno odredište isporuke';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Spremljena ograničenja brzine za @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Skenirajte QR za prijavu na NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Skenirajte QR za uparivanje NeoAgenta s drugog uređaja i odobrite ga iz ove sesije pokretača.';

  @override
  String get scanLoginQr => 'Skeniraj QR za prijavu';

  @override
  String get scanPairingQr => 'Skenirajte QR za uparivanje';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Skenirajte QR zahtjeve za prijavu s odjavljenih uređaja i odobrite ih iz ove provjerene mobilne sesije.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Skenirajte da završite $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Skenirajte s NeoAgentom na svom telefonu';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Skenira novu e-poštu i šalje vam ping samo kada je nešto važno.';

  @override
  String get schedule => 'Raspored';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'zakazano vrijeme. Nakon što se trčanja izmjere, počet će ranije.';

  @override
  String get screen => 'Zaslon';

  @override
  String get screenAction => 'radnja na ekranu';

  @override
  String get scrollIsNotSupportedOnThis =>
      'pomicanje nije podržano na ovoj platformi.';

  @override
  String get scrollToBottom => 'Pomaknite se do dna';

  @override
  String get search => 'Traži';

  @override
  String get search2 => 'Traži…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Administratorske postavke pretraživanja (npr. SMTP, Ollama, zapisnici)';

  @override
  String get searchAgain => 'Traži ponovo';

  @override
  String get searchByUsernameOrEmail =>
      'Pretražujte po korisničkom imenu ili e-pošti';

  @override
  String get searchChannels => 'Traži kanale';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Pretražite otkrivene kanale za razmjenu poruka, kontakte, grupe i nedavne razgovore.';

  @override
  String get searchGroups => 'Traži grupe';

  @override
  String get searchMemory => 'Pretraži memoriju';

  @override
  String get searchModelsOrProviders =>
      'Pretražite modele ili pružatelje usluga';

  @override
  String get searchModelsOrProviders2 => 'Pretražite modele ili pružatelje…';

  @override
  String get searchRecentPeopleAndGroups => 'Pretražite nedavne osobe i grupe';

  @override
  String get searchSessions => 'Sesije pretraživanja';

  @override
  String get searchSettings => 'Postavke pretraživanja';

  @override
  String get searchTitleModelTriggerRunId =>
      'Naslov pretraživanja, model, okidač, ID izvođenja';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Alati za pretraživanje, integracije i vještine';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Traženi kod za \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Tražene datoteke za \"$arg1\"';
  }

  @override
  String get secretField => 'Tajno polje';

  @override
  String get secureCookies => 'Sigurni kolačići';

  @override
  String get security => 'Sigurnost';

  @override
  String get securityKey => 'Sigurnosni ključ';

  @override
  String get securityKeyPromptWasDismissed =>
      'Upit za sigurnosni ključ je odbačen.';

  @override
  String get securityKeySignInCompletedBut =>
      'Prijava sa sigurnosnim ključem je dovršena, ali NeoAgent nije mogao zadržati sesiju preglednika. Prijavite se ponovo.';

  @override
  String get securityKeySignInCouldNot =>
      'Nije moguće pokrenuti prijavu sigurnosnim ključem.';

  @override
  String get securityKeys => 'Sigurnosni ključevi';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Sigurnosni ključevi dostupni su samo u web aplikaciji NeoAgent.';

  @override
  String get seeAll => 'Vidi sve';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Pogledajte koji NeoAgent poslužitelj ovaj prozor koristi i pokrenite pozadinu na ovom računalu.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'vidjeti svoje korisničko ime i ove postavke, nikada vaše razgovore, sjećanja ';

  @override
  String get selectARun => 'Odaberite trčanje';

  @override
  String get selectASessionToSeeIts =>
      'Odaberite sesiju da biste vidjeli njeno računalo, datoteke i promjene.';

  @override
  String get selectAll => 'Odaberite sve';

  @override
  String get selectAll2 => 'Odaberite sve';

  @override
  String selectArg1(Object? arg1) {
    return 'Odaberite $arg1';
  }

  @override
  String get selectTrigger => 'Odaberite Okidač';

  @override
  String get send => 'Pošalji (⌘↵)';

  @override
  String get send2 => 'poslati';

  @override
  String get sendATaskFromChatAnd =>
      'Pošaljite zadatak iz chata i ovdje će se prikazati njegova povijest izvršenja.';

  @override
  String get sendItToATeammateWith =>
      'pošaljite ga suigraču s računom na ovom poslužitelju.';

  @override
  String get sendLink => 'Pošalji link';

  @override
  String get sendPath => 'Pošalji put';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Pošalji POST / PUT / DELETE zahtjeve vanjskim API-jima.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Pošaljite ovu vezu samo osobi kojoj je namijenjena. Prikazuje se jednom; ';

  @override
  String get senderAddress => 'Adresa pošiljatelja';

  @override
  String get senderFilterOptional => 'Filtar pošiljatelja (izborno)';

  @override
  String get sentSharedAttachments => 'Poslani zajednički privici.';

  @override
  String get separateAccount => 'Odvojeni račun';

  @override
  String get server => 'poslužitelj';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Zadani poslužitelj ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Zadane postavke poslužitelja za glasovne pozive unutar aplikacije. Pozivi se odvijaju uživo ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'sam poslužitelj: računi, pružatelji usluga i konfiguracija.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Poslužitelj, nadimak, kanal i izborni TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'server output console upozorenja pogreške kopiraj';

  @override
  String get serverProviderCredentials =>
      'Vjerodajnice pružatelja poslužitelja';

  @override
  String get serverUrl => 'URL poslužitelja';

  @override
  String get serverUsageLimitsDonTApply =>
      'Ograničenja upotrebe poslužitelja ne odnose se na modele koji rade na vašem ključu.';

  @override
  String get serviceEmail => 'Servisna e-pošta';

  @override
  String get serviceEmailIsNotConfigured => 'usluga e-pošte nije konfigurirana';

  @override
  String get serviceEmailSmtp => 'E-pošta usluge (SMTP)';

  @override
  String get sessionActions => 'Radnje sesije';

  @override
  String get sessions => 'Sjednice';

  @override
  String get sessions2 => 'SJEDNICE';

  @override
  String get sessionsArePinnedToAFolder =>
      'Sesije su prikvačene na mapu i računalo. Počnite planirati, graditi, testirati i slati odavde.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sjednice (GDPR čl. 17). Administratorski računi ne mogu se izbrisati ';

  @override
  String get sessionsLogoutRevokeForce => 'sessions odjava revoke force';

  @override
  String get setBlockAskAllowPerTool =>
      'Postavite blokiranje/pitanje/dopuštanje po kategoriji alata ili odaberite globalni način rada.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Postavite NeoAgent na ovom računalu';

  @override
  String get setUpOrConnectNeoagent => 'Postavite ili povežite NeoAgent';

  @override
  String get setUrl => 'Postavite URL';

  @override
  String get settings => 'postavke';

  @override
  String get settingsAndCannotBeUndone => 'postavke i ne može se poništiti.';

  @override
  String get settingsArea => 'Područje postavki';

  @override
  String get settingsAreas => 'Područja postavki';

  @override
  String get setup => 'Postavljanje';

  @override
  String get setupDetails => 'Pojedinosti postavljanja';

  @override
  String get setupRequired => 'Potrebno postavljanje';

  @override
  String get setupWasCancelled => 'Postavljanje je otkazano.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Dijeljeni privici iz NeoAgent klijenta:';

  @override
  String get sharedFromAnotherApp => 'Podijeljeno iz druge aplikacije';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Dijeljeni ključevi pružatelja konfigurirani su na poslužitelju. Da biste umjesto toga upotrijebili vlastiti API ključ ili prilagođenu krajnju točku, idite na Napredno → Donesite vlastiti ključ.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Dijeli se s NeoAgent chatom i njegovom memorijom.';

  @override
  String get shellCommands => 'Naredbe ljuske';

  @override
  String showAllArg1(Object? arg1) {
    return 'Prikaži sve $arg1';
  }

  @override
  String get showEarlier => 'Prikaži ranije';

  @override
  String get showEveryStep => 'Pokažite svaki korak';

  @override
  String get showTools => 'Prikaži alate';

  @override
  String get showWorkbenchJ => 'Prikaži radni stol (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Prikazujem prvi $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Prikazano na bočnoj traci. Ostavite prazno za korištenje vašeg korisničkog imena.';

  @override
  String get signIn => 'Prijavite se';

  @override
  String get signInCompletedButNeoagentCould =>
      'Prijava je dovršena, ali NeoAgent nije mogao zadržati sesiju preglednika. Prijavite se ponovo. Ako se to nastavi događati, provjerite postavke kolačića pozadinske sesije.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Prijava je dovršena, ali NeoAgent nije mogao zadržati sesiju preglednika. Prijavite se ponovo. Ako se to nastavi događati, kolačić pozadinske sesije vjerojatno se ne zadržava.';

  @override
  String get signInToThisNeoagentServer =>
      'Prijavite se na ovaj NeoAgent poslužitelj prije skeniranja QR koda za uparivanje.';

  @override
  String get signInWithAHardwareKey =>
      'Prijavite se hardverskim ključem ili zaporkom umjesto lozinke. ';

  @override
  String get signInWithASecurityKey => 'Prijavite se sigurnosnim ključem';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Prijavite se sa $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Odobrite NeoAgent na svom $arg1 računu. Nema ključa za kopiranje.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Čeka se $arg1. Završite u pregledniku.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Zalijepite kod $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Nakon što ste odobrili NeoAgent, $arg1 je pokazao jednokratni kod. Zalijepite ovdje.';
  }

  @override
  String get signInCode => 'Kod za prijavu';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Prijavljeni ste putem $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Prijava nije uspjela: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Prijavite se istom e-poštom i glavnom lozinkom koju koristite u Bitwardenu. Glavna lozinka i kod u dva koraka koriste se samo za prijavu i nikada se ne pohranjuju niti šalju AI-u.';

  @override
  String get signOut => 'Odjavi se';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Svugdje se odjaviti @$arg1?';
  }

  @override
  String get signOutEverywhere => 'Odjavite se posvuda';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API most';

  @override
  String get signalCliServerUrl => 'signal-cli URL poslužitelja';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Odjavljen @$arg1 sa svake sesije.';
  }

  @override
  String get signedInDevices => 'Uređaji na kojima ste prijavljeni';

  @override
  String get signedInWithin24Hours => 'Prijavljen u roku od 24 sata';

  @override
  String get signingSecret => 'Tajno potpisivanje';

  @override
  String sinceArg1(Object? arg1) {
    return 'Od $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'od $arg1';
  }

  @override
  String get singleMessage => 'Jedna poruka';

  @override
  String get singleUse => 'Za jednokratnu upotrebu';

  @override
  String get skill => 'Vještina';

  @override
  String get skillChanges => 'Promjene vještina';

  @override
  String get skillContent => 'Sadržaj vještina';

  @override
  String get skills => 'Vještine';

  @override
  String get skip => 'Preskoči';

  @override
  String get skipForNow => 'Preskoči za sada';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Preskočite ovaj zadatak prije nego pozove model.';

  @override
  String get slackMessageReceived => 'Slack poruka primljena';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Spavaj $arg1 sesije';
  }

  @override
  String get smartSelector => 'pametan selektor';

  @override
  String get smartSelector2 => 'Pametni birač';

  @override
  String get smartSelectorPool => 'Smart Selector Pool';

  @override
  String get smtpHost => 'SMTP host';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp lozinka pošiljatelja pošte tls potvrda obavijesti reset';

  @override
  String get smtpPassword => 'SMTP lozinka';

  @override
  String get smtpPort => 'SMTP port';

  @override
  String get smtpPortMustBeAWhole =>
      'SMTP port mora biti cijeli broj od 1 do 65535.';

  @override
  String get smtpUsername => 'SMTP korisničko ime';

  @override
  String get soTheRunStartsThatMuch => 'tako da trčanje počinje puno ranije.';

  @override
  String get socialBehaviorOff => 'Društveno ponašanje isključeno';

  @override
  String get socialIntelligence => 'socijalna inteligencija';

  @override
  String get socialIntelligence2 => 'Socijalna inteligencija';

  @override
  String get socialObservability => 'Društvena promatranost';

  @override
  String get socialReach => 'društveni doseg';

  @override
  String get socialReach2 => 'Društveni doseg';

  @override
  String get socialReach3 => 'Društveni doseg';

  @override
  String get socialReachUpdated => 'Društveni doseg ažuriran.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Agenti društvenih izvora mogu izravno čitati, uključujući feedove, spremišta, Reddit, X, videozapise i tržišne podatke podržane kolačićima.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Nešto nije u redu. Molimo pokušajte ponovo.';

  @override
  String get source => 'Izvor';

  @override
  String get spaceOrChatIdUsedWhen =>
      'ID prostora ili chata koji se koristi kada ovaj agent započne razgovor.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Svemirski web-dojavnik i podrška za povratni poziv aplikacije';

  @override
  String get speaking => 'govoreći';

  @override
  String get speechToSpeechModelUsingThe =>
      'govor-u-govor model pomoću OpenAI ili Google tipke pod ';

  @override
  String get speechToText => 'Govor u tekst';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Govor u tekst transkribira glasovne bilješke i diktat. Auto koristi OpenAI, Gemini ili Deepgram, ovisno o tome koji ima API ključ. Model glasovnog odgovora je model chata koji odgovara na glasovne bilješke.';

  @override
  String get sqlConsole => 'SQL konzola';

  @override
  String get stable => 'Stabilan';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable instalira najnovije objavljeno pozadinsko izdanje.';

  @override
  String get stackTrace => 'stack trace';

  @override
  String get standard => 'Standardno';

  @override
  String get standardView => 'Standardni pogled';

  @override
  String get start => 'Start';

  @override
  String get startASessionToPlanOr =>
      'Započnite sesiju za planiranje ili izgradnju s NeoAgentom.';

  @override
  String get startAndroid => 'Pokrenite Android';

  @override
  String get startComputer => 'Pokrenite računalo';

  @override
  String get startFullSetup => 'Pokrenite potpuno postavljanje';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Započnite postavljanje';

  @override
  String get startTalking => 'Počni pričati';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Prvo pokrenite Android telefon, a zatim ispustite .apk ili .apks datoteku ovdje.';

  @override
  String get startTheServerLaterFromThe =>
      'Pokrenite poslužitelj kasnije s popisa nakon što se konfiguracija spremi.';

  @override
  String get startWithARecommendedTask => 'Započnite s preporučenim zadatkom';

  @override
  String get startingAndroid => 'Pokretanje Androida';

  @override
  String get startingYourComputer => 'Pokretanje vašeg računala';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Počinje s xoxb-. Iz vaših vjerodajnica aplikacije Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'Pogreška startTelecomCallRouting: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistika pokreće tokene korisnici grafikoni stopa uspjeha';

  @override
  String get status => 'Status';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'pružatelji vm runtime baze podataka statusa';

  @override
  String get statusIsNotLoadedYet => 'Status još nije učitan.';

  @override
  String get stayManagedByYou => 'upravljati vi.';

  @override
  String get stayOnTheCall => 'Ostani na pozivu';

  @override
  String get stayedQuiet => 'Ostao tiho';

  @override
  String get steering => 'UPRAVLJAČ';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'KORAK $arg1 OD $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Koraci $arg1';
  }

  @override
  String get stop => 'Zaustavi';

  @override
  String get stop2 => 'Zaustavi (⌘.)';

  @override
  String get stopManaging => 'Prestanite upravljati';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Prestati upravljati $arg1?';
  }

  @override
  String get stopRun => 'Prestani trčati';

  @override
  String get stopSpeaking => 'Prestani govoriti';

  @override
  String get stoppedBeforeCompletion => 'Zaustavljen prije završetka';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'StopTelecomCallRouting Greška: $arg1';
  }

  @override
  String get storage => 'Skladištenje';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'pohranjeni šifrirani i korišteni samo za vlastita izvođenja.';

  @override
  String get storedMetrics => 'Pohranjena metrika';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Pohranjuje samo Bitwarden ključ sesije šifriran na ovom poslužitelju, tako da veze prežive ponovno pokretanje. Možete ga zaključati u bilo kojem trenutku.';

  @override
  String get strong => 'Jaka';

  @override
  String get strongPassword => 'Jaka lozinka.';

  @override
  String get subAgent => 'Podagent';

  @override
  String get subagentUpdate => 'Ažuriranje subagenta';

  @override
  String get subagentUpdate2 => 'Ažuriranje subagenta.';

  @override
  String get successRate => 'Stopa uspješnosti';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Prijedlozi: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Sažeti moje zadnje trčanje';

  @override
  String get supportUrl => 'URL podrške';

  @override
  String get supportedRainStartSnowStartWind =>
      'Podržano: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Zamjena agenta';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Simboličke veze nisu dopuštene u stazama NeoAgent Workspacea.';

  @override
  String get syncNow => 'Sinkroniziraj sada';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'Postavke privatnosti sustava';

  @override
  String get tableInfoUsers => 'Podaci o tablici (korisnici)';

  @override
  String get tagsOnly => 'Samo oznake';

  @override
  String get tasks => 'Zadaci';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Zadaci se pokreću sami i šalju vam poruke ';

  @override
  String get teach => 'podučavati';

  @override
  String get teachingInProgress => 'Nastava u tijeku';

  @override
  String get team => 'Tim';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Timske veze nikad nikoga ne čine administratorom poslužitelja. Admini vode ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Timski prostori, sobe, kanali i zajednice uživo.';

  @override
  String get teamsMessageReceived => 'Poruka timova primljena';

  @override
  String get templates => 'Predlošci';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Privremene datoteke za postavljanje bit će očišćene kasnije.';

  @override
  String get tenantId => 'ID stanara';

  @override
  String get testConnection => 'Testirajte vezu';

  @override
  String get testConnection2 => 'Testirajte vezu';

  @override
  String get textChat => 'SMS & Chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'koji su dodali vlastiti ključ i dalje ga koriste.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Ta adresa e-pošte već pripada postojećem računu. Prvo se prijavite, a zatim povežite Google iz postavki računa.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Ta je e-pošta već povezana s drugim računom.';

  @override
  String get thatQrCodeIsNotA => 'Taj QR kod nije NeoAgent zahtjev za prijavu.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Taj QR kod nije NeoAgent zahtjev za uparivanje.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Taj je sigurnosni ključ već registriran na ovom računu.';

  @override
  String get theAddress => 'Adresa';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Adresa vašeg BlueBubbles poslužitelja.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Adresa koju ljudi i pružatelji OAutha koriste za dolazak ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agent čita vrijeme koje ste spomenuli i pokreće zakazane zadatke u ovoj vremenskoj zoni.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agent će prije svakog osjetljivog alata pitati, ';

  @override
  String get theAgentWillIgnoreThisSkill => 'Agent će zanemariti ovu vještinu.';

  @override
  String get theAppCouldNotReachThis =>
      'Aplikacija nije mogla doći do ove implementacije NeoAgenta. Provjerite mrežnu vezu ili potvrdite da je URL usluge točan.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Preglednik je blokirao zahtjev upućen $arg1 zbog Politike sigurnosti sadržaja.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Preglednik je blokirao traženi zahtjev zbog Pravila sigurnosti sadržaja.';

  @override
  String get theCloudWorkspace => 'radni prostor u oblaku';

  @override
  String get theComputerCouldNotStart => 'Računalo se nije moglo pokrenuti';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Računalo treba više slobodnog prostora na disku na NeoAgent hostu. Oslobodite malo prostora, a zatim pokušajte ponovno.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Izvršno vrijeme računala treba popraviti. Pokrenite NeoAgent Doctor, zatim pokušajte ponovno.';

  @override
  String get theConnectionTestFailed => 'Test veze nije uspio.';

  @override
  String get theDesktopDidNotStart => 'Radna površina se nije pokrenula';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Otkriveni NeoAgent vratio je nepotpune podatke o identitetu.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Otkriveni NeoAgent koristi nepodržani protokol za postavljanje.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Otkrivena usluga nije NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Preuzeto NeoAgent runtime nije prošlo provjeru.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Web-dojavnik prostora za Google Chat na kojem bi ovaj agent trebao objavljivati.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Instalacijski program više nije dostupan.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Interaktivna Linux radna površina dostupna je u web aplikaciji NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn => 'Uvod nije dostupan na ovom uređaju.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Najnovije se prikazuje na svakom računu.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Zadnji prozor sinkronizacije završio je $arg1 i nije pronašao nove zapise Health Connecta. Pohranjeni mjerni podaci u nastavku potječu iz ranijih sinkronizacija.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Linux grafička sesija nije pokrenuta.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Model živog glasa nije odgovorio. Pokušajte ponovno.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Lokalna naredba NeoAgent izašla je s kodom $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Lokalna NeoAgent naredba je istekla.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Lokalno NeoAgent runtime treba popraviti.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Lokalno vrijeme izvođenja treba popraviti ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Domaći direktorij lokalnog korisnika nije dostupan.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Račun pošte NeoAgent šalje potvrde prijave, prijave ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Glavni agent se automatski kreira kada je to potrebno.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Odgovarajuće vrijeme izvođenja NeoAgenta nedostaje u ovom izdanju.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Najvažniji dolazni web-dojavnik na kojem bi ovaj agent trebao objavljivati.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Modeli između kojih Smart Selector automatski usmjerava.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'NeoAgent pozadinsko preuzimanje ne odgovara njegovom manifestu.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'NeoAgent pozadinsko preuzimanje nije bilo dovršeno.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'NeoAgent pozadina na ovom računalu ne odgovara na priključku ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'NeoAgent backend runtime nije moguće preuzeti.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Pozadini NeoAgent-a trebalo je predugo da odgovori za $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Implementacija NeoAgenta odgovorila je s HTTP 402 umjesto uobičajenog 401 za nevažeće vjerodajnice. Provjerite reverse-proxy, auth gateway ili pravila koja se odnose na plaćanje na tom poslužitelju.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Implementacija NeoAgenta odgovorila je s HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Implementacija NeoAgenta odgovorila je s HTTP 402. Provjerite reverse-proxy, auth gateway ili pravila koja se odnose na plaćanje na tom poslužitelju.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Instanca NeoAgenta s kojom je ova aplikacija povezana.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Usluga izdanja NeoAgent-a vratila je nevažeće podatke.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Metapodaci artefakta vremena izvođenja NeoAgenta nisu valjani.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'NeoAgent runtime manifest nije prošao provjeru potpisa.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'NeoAgent runtime manifest nema artefakata.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Potpis manifesta vremena izvođenja NeoAgenta nije valjan.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Lozinka koju ste postavili u BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Ljudi kojima upravljate ostaju s vama.';

  @override
  String get theProviderAnswers => 'pružatelj odgovara.';

  @override
  String get theQueryReturnedNoRows => 'Upit nije vratio nijedan redak.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Traženi zaslon radne površine nije dostupan.';

  @override
  String get theRest => 'ostatak.';

  @override
  String get theRestEndpointForYourSignal =>
      'Krajnja točka REST za vašu instancu signal-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'Trčanje je pauzirano dok ne odgovorite.';

  @override
  String get theRunStartsAtTheScheduled =>
      'Trčanje počinje u zakazano vrijeme.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Runtime je lagana Debian Linux radna površina s Chromiumom, PCManFM, Mousepad, LXTerminal, Python, Git i standardnim alatima naredbenog retka. Njegovim kapacitetom upravlja NeoAgent host.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Registracija sigurnosnog ključa nije mogla biti pokrenuta.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'poslužitelj čuva samo otisak prsta.';

  @override
  String get theServerOnThisComputerIs =>
      'Poslužitelj na ovom računalu nije pokrenut';

  @override
  String get theServerReportedNoHealthChecks =>
      'Poslužitelj je prijavio da nema zdravstvenih provjera.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Telefonski broj Signala koji ovaj bot koristi.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Timovi dolazni web-dojavnik na kojem bi ovaj agent trebao objavljivati.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Izazov s dva faktora je istekao. Prijavite se ponovno.';

  @override
  String get theTwoFactorCodeIsNot => 'Dvofaktorski kod nije valjan.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Provjereni runtime paket nije mogao biti označen kao izvršni.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Provjerenom runtime paketu nedostaju potrebne datoteke.';

  @override
  String get theWebAppCouldNotReach =>
      'Web-aplikacija nije mogla doći do NeoAgent pozadine.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Web-aplikacija nije mogla doći do NeoAgent pozadine na $arg1. Provjerite konzolu preglednika i konfiguraciju obrnutog proxyja/mreže.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'se; operater poslužitelja prvo uklanja administratora sa ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Ovi kanali ostaju tihi. Da biste se ponovno čuli s njima, dodajte ih pod Tko može slati poruke za tu platformu.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Ovi popisi nisu obavezni osim ako gornji odjeljak nije postavljen samo na odobreno.';

  @override
  String get thesePeopleAnywhere => 'Ovi ljudi, bilo gdje';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Ovi ljudi mogu slati poruke $arg1 u privatnim chatovima iu bilo kojoj grupi koju dijele.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Ovi ljudi mogu slati poruke $arg1 jedan na jedan. To im ne dopušta da govore u grupama.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Ove osobe mogu slati poruke samo $arg1 u grupi koju ste odabrali.';
  }

  @override
  String get thesePeopleInOneGroup => 'Ovi ljudi, u jednoj skupini';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'ove sklopke, nikada vaše razgovore, uspomene ili datoteke.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Ovaj račun će otključati NeoAgent na ovom računalu.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Ovaj agent može delegirati bilo kojem prihvatljivom agentu za primanje.';

  @override
  String get thisAgentIsUsingAServer =>
      'Ovaj agent koristi Trello API ključ kojim upravlja poslužitelj. Samo trebate autorizirati token računa u nastavku.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Ovoj verziji nije dopušteno komunicirati s ovom implementacijom NeoAgenta.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Ovaj kod pripada drugom NeoAgent poslužitelju: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Ova radna površina je povezana';

  @override
  String get thisDevice => 'Ovaj uređaj';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Ovaj uređaj: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Ovaj uređaj ne može registrirati sigurnosne ključeve. Otvorite NeoAgent u pregledniku preko HTTPS-a da biste ga dodali.';

  @override
  String get thisDeviceUnavailable => 'Ovaj uređaj — nedostupan';

  @override
  String get thisFileHasNoContent => 'Ova datoteka nema sadržaja.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Ovo skriva \"$arg1\" od usmjeravanja i odabira.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Ova integracija trenutno podržava jedan povezani račun po agentu. Ponovno otvorite postavku da biste je zamijenili.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Ova integracija više nije dostupna.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Ovaj uvod je dizajniran za pejzažnu reprodukciju preko cijelog zaslona.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Ovo je upravljana implementacija. Njegov operater se izbacuje ';

  @override
  String get thisMayTakeAMoment => 'Ovo može potrajati trenutak.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Ovaj MCP poslužitelj više nije konfiguriran.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Ova memorija će biti trajno uklonjena.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Ova verzija NeoAgenta nije konfigurirana za provjeru pozadinskih vremena izvođenja.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Ovo trajno briše sve vaše podatke i to nije moguće ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Ovo trajno briše račun i sve što posjeduje: ';

  @override
  String get thisPersonAnywhere => 'Ova osoba, bilo gdje';

  @override
  String get thisPersonInOneGroup => 'Ova osoba, u jednoj grupi';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Ovaj QR zahtjev za prijavu je istekao. Generirajte novi kôd i pokušajte ponovno.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'ovaj qr zahtjev za prijavu je istekao';

  @override
  String get thisQrLoginRequestIsStill =>
      'Ovaj QR zahtjev za prijavu još uvijek čeka odobrenje.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Ovaj QR zahtjev za prijavu već je korišten.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Time se uklanjaju postavke Home Assistant i povezana instanca za ovog agenta.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Ovim se uklanja pozadinski URL NeoRecall-a i svi povezani NeoRecall računi za ovog agenta.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Ovo uklanja Nextcloud URL i sve povezane Nextcloud račune za ovog agenta.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Time se uklanjaju postavke Trello i povezani računi za ovog agenta.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Ovo zahtijeva autentificiranu sesiju na istom NeoAgent poslužitelju.';

  @override
  String get thisRunDidNotProduceA =>
      'Ovo pokretanje nije proizvelo korisnički odgovor.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Ovo trčanje nema zabilježenih podataka o koracima.';

  @override
  String get thisServer => 'ovaj poslužitelj.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Ovaj poslužitelj ne javlja postavke pružatelja usluga.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Ova vještina više nije instalirana.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Ovaj zadatak još nije dovršen, tako da i dalje počinje u ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Ovaj će se zadatak pokrenuti samo kada pritisnete Pokreni sada.';

  @override
  String get thisWeek => 'Ovaj tjedan';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Ovo će uvesti odgovor u $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Ovo će ukloniti \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Ovo će ukloniti \"$arg1\" s popisa poslužitelja.';
  }

  @override
  String get time => 'Vrijeme';

  @override
  String get timeZone => 'vremenska zona';

  @override
  String get timeZone2 => 'Vremenska zona';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Isteklo je $arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[Vremenska zona] Ne mogu navesti vremenske zone: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Nije moguće pročitati vremensku zonu uređaja: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Nije moguće spremiti vremensku zonu uređaja: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'do $arg1';
  }

  @override
  String get toUseTheServerDefault =>
      'za korištenje zadane postavke poslužitelja.';

  @override
  String get today => 'Danas';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Proračun tokena za @$arg1. Ostavite polje prazno ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Proračun tokena za svaki račun bez vlastitog nadjačavanja. Ostavite a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'ograničenje proračuna tokena 4 sata tjedna kvota korisnika';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'ograničenje proračuna tokena 4 sata tjedna kvota globalno';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Upotreba tokena nije dostupna na ovoj verziji poslužitelja.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokene bilo koji račun može koristiti u roku od 4 sata.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokene bilo koji račun može koristiti u roku od 7 dana.';

  @override
  String get tokensPerDay => 'Žetoni po danu';

  @override
  String get tokensPerRun => 'Tokeni po vožnji';

  @override
  String get tokensToday => 'Tokeni danas';

  @override
  String get tokensUsed => ' korišteni žetoni';

  @override
  String get tomorrowPrep => 'Sutrašnje pripreme';

  @override
  String get tooManyAttempts => 'previše pokušaja';

  @override
  String get tooManySignInAttemptsPlease =>
      'Previše pokušaja prijave. Molimo pričekajte i pokušajte ponovo.';

  @override
  String get tool => 'Alat';

  @override
  String get toolApproval => 'Odobrenje alata';

  @override
  String get toolApprovalRequired => 'Potrebno odobrenje alata';

  @override
  String get toolCompleted => 'Alat je dovršen';

  @override
  String get toolFailed => 'Alat nije uspio';

  @override
  String get toolPermissions => 'Dopuštenja alata';

  @override
  String get toolStarted => 'Alat je pokrenut';

  @override
  String get tools => 'Alati';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Alati koji nisu ugrađeni u NeoAgent, uključujući povezane MCP poslužitelje i prilagođene pružatelje alata.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Ponuđeni alati ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Alati koje upravljani račun može koristiti';

  @override
  String get topUsers => 'Najbolji korisnici';

  @override
  String get topUsersAndRecentRuns => 'Najbolji korisnici i nedavna pokretanja';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Ukupno: $arg1 tokena u $arg2 izvođenjima';
  }

  @override
  String get totalRuns => 'Ukupna trčanja';

  @override
  String get totalTokens => 'Ukupno žetona';

  @override
  String get totalUsers => 'Ukupno korisnika';

  @override
  String get transcript => 'Transkript';

  @override
  String get transcript2 => 'PRIJEPIS';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transkripcija nije uspjela: $arg1';
  }

  @override
  String get transfer => 'Prijenos';

  @override
  String get trelloApiKey => 'Trello API ključ';

  @override
  String get trelloApiKeyIsRequired => 'Potreban je Trello API ključ.';

  @override
  String get trelloSetup => 'Postavljanje Trella';

  @override
  String get triggerType => 'Vrsta okidača';

  @override
  String get tryABroaderSearchLikeModels =>
      'Isprobajte šire pretraživanje poput modela, preglednika ili glasa.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Pokušajte s nazivom davatelja usluga, \"e-pošta\", \"ograničenja\", \"ažuriranje\" ili \"dnevnici\".';

  @override
  String get tryAgain => 'Pokušajte ponovno';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Pokušajte ponovno. Ako se ovo nastavi događati, pokrenite NeoAgent Doctor da provjerite vrijeme rada računala.';

  @override
  String get tryAgainInAMoment => 'Pokušajte ponovo za trenutak.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Pokušajte ponovno ili pokrenite NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Pokušajte s drugim pretraživanjem, povežite platformu za slanje poruka ili ručno unesite ID odredišta.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Uključite grupu ako $arg1 također treba čitati poruke koje ga ne označavaju.';
  }

  @override
  String get turnOffComputer => 'Isključite računalo';

  @override
  String get turnOffOnlyForAMail =>
      'Isključi samo za poslužitelj e-pošte sa samopotpisanim certifikatom.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Uključite ako Signal treba nastaviti tražiti dolazne razgovore.';

  @override
  String get turnTaking => 'red uzimajući';

  @override
  String get turnTakingModel => 'Model koji se mijenja';

  @override
  String get turnTakingOff => 'Skretanje-polijetanje';

  @override
  String get turnThisOffToKeepThis =>
      'Isključite ovo kako bi ovaj agent bio potpuno odvojen od ostalih agenata.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Isključio $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Isključio $arg1, koji upravlja ovim računom. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Isključio za vas $arg1 — samo oni to mogu promijeniti';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Isključeno za vas, tako da ga ne možete dati';

  @override
  String get twitchChatOverIrc => 'Twitch chat preko IRC-a';

  @override
  String get twoFactorAuthentication => 'Dvofaktorska autentifikacija';

  @override
  String get twoFactorChallengeExpired => 'dvofaktorski izazov je istekao';

  @override
  String get twoFactorCode => 'dvofaktorski kod';

  @override
  String get twoFactorSignInCompletedBut =>
      'Prijava u dva faktora je dovršena, ali NeoAgent nije mogao zadržati sesiju preglednika. Prijavite se ponovo.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Prijava u dva koraka (samo ako je omogućena)';

  @override
  String get type => 'Vrsta';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Upišite $arg1 za potvrdu';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'vrsta teksta nije podržana na ovoj platformi.';

  @override
  String get typedInTheBrowser => 'Upisano u pregledniku';

  @override
  String get typedText => 'Tipkani tekst';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'nije moguće locirati vrijeme izvođenja Jave';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Nije moguće otvoriti postavke vremena na ovoj verziji.';

  @override
  String get unableToOpenWiFiSettings =>
      'Nije moguće otvoriti Wi-Fi postavke na ovoj verziji.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Nije moguće održati odabrani zaslon radne površine.';

  @override
  String get unclearWhoItWasFor => 'Nejasno za koga je';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'poništeno. Upišite svoje korisničko ime za potvrdu.';

  @override
  String get unknownAccount => 'Nepoznati račun';

  @override
  String get unknownAgent => 'Nepoznati agent';

  @override
  String get unknownBrowser => 'Nepoznati preglednik';

  @override
  String get unknownDevice => 'Nepoznati uređaj';

  @override
  String get unknownError => 'nepoznata greška';

  @override
  String get unknownLocalComputerPermission =>
      'Dopuštenje za nepoznato lokalno računalo.';

  @override
  String get unknownLocation => 'Nepoznata lokacija';

  @override
  String get unknownPublishTime => 'Nepoznato vrijeme objave';

  @override
  String get unknownSize => 'Nepoznata veličina';

  @override
  String get unlink => 'Prekini vezu';

  @override
  String get unreadOnly => 'Samo nepročitano';

  @override
  String get unsavedChanges => 'Nespremljene promjene';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Nepodržana popratna naredba radne površine: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Nepodržana metoda: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Neuobičajena upozorenja za prijavu';

  @override
  String updateArg1(Object? arg1) {
    return 'Ažurirajte $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Ažurirajte unose osnovne memorije iz uvoza.';

  @override
  String get updateNow => 'Ažurirajte sada';

  @override
  String get updateReady => 'Ažuriranje spremno';

  @override
  String get updateSetup => 'Ažuriranje postavki';

  @override
  String get updateTheAccessListToAllow =>
      'Ažurirajte popis pristupa kako biste omogućili odgovore.';

  @override
  String get updateTheServer => 'Ažurirati poslužitelj?';

  @override
  String get updateTheServer2 => 'Ažurirajte poslužitelj';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Automatski ažurirajte vremensku zonu s uređaja koji koristite.';

  @override
  String updatedArg1(Object? arg1) {
    return 'ažurirano $arg1';
  }

  @override
  String get updates => 'Ažuriranja';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Ažuriranja nisu konfigurirana za ovu verziju.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'ažuriranja, tako da su samoažuriranje i promjene kanala ovdje isključeni.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'nadogradite ažuriranje sada objavite stabilnu beta verziju kanala';

  @override
  String get usageAnalytics => 'Analitika korištenja';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Signali upotrebe i zdravlja koji pomažu objasniti trenutno ponašanje u vremenu izvođenja bez prethodnog kopanja po zapisnicima.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Upotreba se potpuno resetira u $arg1';
  }

  @override
  String get usageLeaderboard => 'ljestvica korištenja';

  @override
  String get usageLimits => 'Korištenje i ograničenja';

  @override
  String get usageLimits2 => 'Korištenje i ograničenja';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Koristite 8+ znakova. Dulje šifre dobro funkcioniraju.';

  @override
  String get useADateAndTimeFor =>
      'Koristite datum i vrijeme, na primjer 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Koristite ime, telefonski broj ili ID chata.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Koristite NeoRecall URL do kojeg NeoAgent poslužitelj može doći. NeoAgentov PUBLIC_URL također mora biti dostupan iz ovog preglednika za OAuth povratni poziv.';

  @override
  String get useANewPasswordWithAt =>
      'Koristite novu lozinku s najmanje 8 znakova.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Koristite Nextcloud URL do kojeg NeoAgent poslužitelj može doći, na primjer https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Koristite lozinku s najmanje 8 znakova.';

  @override
  String get useASecureConnectionTls => 'Koristite sigurnu vezu (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Koristite aplikaciju za autentifikaciju kao što je Authy, 1Password ili Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Koristite najmanje 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Maksimalna memorija po računalu (MB)';

  @override
  String get maxVcpusPerComputer => 'Maks vCPU-a po računalu';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Barem $arg1. Računala dobivaju manje kada je domaćin zauzet.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Maksimalna memorija mora biti najmanje $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Koristite najmanje 8 znakova.';

  @override
  String get useDefault => 'Koristi zadano';

  @override
  String get useDefaultChannel => 'Koristi zadani kanal';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Koristi zadano (NeoAgent Workspace)';

  @override
  String get useFor => 'Koristite za';

  @override
  String get useManualDestination => 'Koristite ručno odredište';

  @override
  String get useOrDoTheSameFor =>
      'koristite ili učinite isto za svoje suigrače.';

  @override
  String get usePerCategorySettingsBelow =>
      'Koristite postavke po kategorijama u nastavku.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Koristi zadane postavke ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Koristite poslužitelj na ovom računalu';

  @override
  String get useTheseForContextIfA =>
      'Koristite ih za kontekst. Ako lokalni URI nije izravno dostupan s poslužitelja, zamolite me da dam datoteku putem pristupačnog radnog prostora.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Koristite ovo za agente orkestratora. Ostavite izolirane radne botove koji bi sami trebali završiti izravne poruke.';

  @override
  String get useTlsFromTheStartOf =>
      'Koristite TLS od početka veze, obično na portu 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Upotrijebite vlastiti API ključ za pružatelja ili povežite prilagođeni ';

  @override
  String get usedByEveryAccountOnThis =>
      'Koristi ga svaki račun na ovom poslužitelju koji nema ključ ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Koristi se za provjeru jesu li dolazni Slack događaji autentični.';

  @override
  String get userSummary => 'Sažetak korisnika';

  @override
  String get username => 'Korisničko ime';

  @override
  String get usernameOrEmail => 'Korisničko ime ili email';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'korisnici ljudi traženje e-pošte korisničko ime administratorska značka upravljani tim';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Koristi model chata konfiguriran u Postavkama';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Korištenje instaliranog NeoAgent runtimea';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Obično izgleda kao @bot:matrix.org';

  @override
  String get validEmail => 'važeća e-pošta';

  @override
  String get value => 'Vrijednost';

  @override
  String get vaultLocked => 'Trezor zaključan';

  @override
  String get vaultOperationFailed => 'Operacija trezora nije uspjela.';

  @override
  String get verification => 'Provjera';

  @override
  String verificationArg1(Object? arg1) {
    return 'Provjera: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'provjera: $arg1';
  }

  @override
  String get verificationCompleted => 'Provjera dovršena.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Status provjere: $arg1';
  }

  @override
  String get verifiedTheResult => 'Provjerio rezultat';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Provjera preuzetog vremena izvođenja';

  @override
  String get versionAndUptime => 'Verzija i vrijeme rada';

  @override
  String versionArg1(Object? arg1) {
    return 'Verzija $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Verzija $arg1 je instalirana, ali $arg2 još uvijek radi.';
  }

  @override
  String get videoLinks => 'Video linkovi';

  @override
  String get viewDesktop => 'Prikaz radne površine';

  @override
  String get viewLastRun => 'Pogledajte zadnje izvođenje';

  @override
  String get viewLogs => 'Pregledaj zapisnike';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm slikovna memorija cpu qemu runtime';

  @override
  String get voice => 'Glas';

  @override
  String get voiceAssistant => 'Glasovni asistent';

  @override
  String get voiceCall => 'GLASOVNI POZIV';

  @override
  String get voiceCall2 => 'Glasovni poziv';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'glasovni poziv gpt-live gemini live model govor u stvarnom vremenu';

  @override
  String get voiceCallsRunOnALive =>
      'Glasovni pozivi se izvode na modelu govora u govor uživo s istom osobom, memorijom i poviješću razgovora kao NeoAgent. Odmah odgovara i pravi posao predaje normalnom agentu koji radi u pozadini.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'glasovna bilješka api ključ transkripcije govora';

  @override
  String get voiceNotesAndDictation => 'Glasovne bilješke i diktat';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Glasovna reprodukcija nije dostupna na ovom uređaju.';

  @override
  String get voiceReplyModel => 'Model glasovnog odgovora';

  @override
  String get waitingForApproval => 'Čeka se odobrenje: ';

  @override
  String get waitingForCode => 'Čekanje koda';

  @override
  String get waitingForInput => 'Čeka se unos';

  @override
  String get waitingForServerOrFlutterLog =>
      'Čeka se izlaz zapisnika poslužitelja ili Fluttera…';

  @override
  String get waitingForTaskEvents => 'Čekanje događaja zadataka...';

  @override
  String get waitingForYou => 'čeka te';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Tražio sam odgovor od $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Želi razgovarati s vama · ${arg1}s';
  }

  @override
  String get weak => 'Slabo';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Vrijeme, kalendar i prioriteti prije početka dana.';

  @override
  String get weatherEvent => 'Vremenski događaj';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'Web preglednik';

  @override
  String get webSearchApiKey => 'API ključ web pretraživanja';

  @override
  String get webhookOrRestChannelPosting =>
      'Webhook ili objavljivanje REST kanala';

  @override
  String get webhookSecret => 'Webhook tajna';

  @override
  String get webhookUrlCopied => 'URL web-dojavnika kopiran';

  @override
  String get weekdays => 'Radnim danima';

  @override
  String get weekdays0730 => 'Radnim danom · 07:30';

  @override
  String get weekdays1800 => 'Radnim danom · 18:00';

  @override
  String get weekly => 'Tjedni';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Tjedni limit $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Tjedno ograničenje (tokeni)';

  @override
  String get weeklyReview => 'Tjedni pregled';

  @override
  String get weeklyUsage => 'Tjedno korištenje';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Težina $arg1 zapisa';
  }

  @override
  String get welcomeToNeoagent => 'DOBRO DOŠLI U NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Dobrodošli\nu NeoAgent';

  @override
  String get whatAreYouAdding => 'Što dodajete?';

  @override
  String get whatIsOnTomorrow => 'Što je sutra?';

  @override
  String get whatShouldNeoagentLearn => 'Što bi NeoAgent trebao naučiti?';

  @override
  String get whatShouldWeBuild => 'Što bismo trebali graditi?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Ono što vi i NeoAgent kažete pojavljuje se ovdje iu chatu.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Primljena osobna poruka za WhatsApp';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Kada odaberete samo odobreno, dodajte osobe ili grupe u nastavku.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Gdje ovaj agent treba slati odgovore.';

  @override
  String get whoCanMessage => 'Tko može poruku';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Tko može slati poruke na $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Tko može poslati $arg1 poruku jedan na jedan.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Tko može razgovarati sa $arg1 u grupi, kanalu ili sobi.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'tko upravlja ovim računom je isključen: ';

  @override
  String get whoManagesWhom => 'Tko s kim upravlja';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Tko god prihvati vezu, pridružuje se vašem timu samo sa alatima koje ima ';

  @override
  String get wholeGroup => 'Cijela grupa';

  @override
  String get wholeGroups => 'Cijele grupe';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Zašto je $arg1 odgovorio ili šutio u $arg2 grupama.';
  }

  @override
  String get windowsApp => 'Windows aplikacija';

  @override
  String get windowsNt => 'prozori nt';

  @override
  String get workAccount => 'Radni račun';

  @override
  String get workOnAProjectWithNeoagent => 'Radite na projektu s NeoAgentom';

  @override
  String workflowArg1(Object? arg1) {
    return 'Tijek rada: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Rad u $arg1 na računalu u oblaku. NeoAgent tamo čita i uređuje datoteke i može pokretati naredbe i preglednik.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Rad u pozadini: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Konfiguracija radnog prostora i sigurnost računa na jednom mjestu.';

  @override
  String get workspaceFiles => 'Datoteke radnog prostora';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Radni prostor, modeli i kontrole dijagnostike.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Nadjačavanje radnog prostora mora biti apsolutni put.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Napisao $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'greška xmlhttprequest';

  @override
  String get yesterday => 'jučer';

  @override
  String get youAreInControl => 'Vi imate kontrolu';

  @override
  String get youCanFollowAlongOnThe => 'Možete pratiti na radnoj površini.';

  @override
  String get youCanLeaveATeamAt =>
      'Možete napustiti tim u bilo kojem trenutku; ponovno se primjenjuju vaše vlastite postavke.';

  @override
  String get youCanLeaveAtAnyTime => 'Možete otići bilo kada sa stranice tima.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Vi odlučujete koje alate vaš agent može koristiti, pod Postavke › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Vi još ne upravljate nikim. Stvorite vezu za poziv u nastavku i ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Imate nespremljene postavke. Što biste htjeli raditi?';

  @override
  String get youReOnYourOwnYou =>
      'Sami ste: odlučujete koje alate vaš agent može koristiti. ako ';

  @override
  String get yourAccountAndUsageOnA =>
      'vaš račun -- i korištenje na modelu koji podržava vaš vlastiti ključ ';

  @override
  String get yourAccountHasBeenDeleted => 'Vaš račun je izbrisan.';

  @override
  String get yourAgentWillBeAllowed => 'Vašem će agentu biti dopušteno:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Vaše su aplikacije i datoteke spremljene.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Vaše aplikacije i datoteke ostaju spremljene.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Vaš ključ $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Vaš pomoćni sloj za snimanje, kontekst i akciju.';

  @override
  String get yourComputerIsAsleep => 'Vaše računalo je u stanju mirovanja';

  @override
  String get yourComputerIsOff => 'Vaše računalo je isključeno';

  @override
  String get yourComputerIsReady => 'Vaše računalo je spremno';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Vaša trenutna lozinka je netočna.';

  @override
  String get yourData => 'Vaši podaci';

  @override
  String get yourDataExportWasCopiedTo =>
      'Vaš izvoz podataka je kopiran u međuspremnik.';

  @override
  String get yourDesktopIsReady => 'Vaša radna površina je spremna';

  @override
  String get yourLinuxComputer => 'Vaše Linux računalo';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Vaša se lokacija nikada ne prati kontinuirano niti se pohranjuje na našim poslužiteljima. Koristimo ga samo lokalno za provjeru vaših aktivnih zadataka.';

  @override
  String get yourManager => 'vaš menadžer';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Vaš najvažniji URL web-mjesta, ako koristite REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Vaša je sesija istekla ili je preglednik nije zadržao. Prijavite se ponovo.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Vaša je sesija istekla. Prijavite se ponovo.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Vaše korisničko ime ili lozinka su netočni.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID, …';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Osobno';

  @override
  String get sectionOverview => 'Pregled';

  @override
  String get sectionDiagnostics => 'Dijagnostika';

  @override
  String get sectionVolume => 'Volumen';

  @override
  String get sectionSession => 'Sjednica';

  @override
  String get sectionDeliverable => 'Isporučivo';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Lokalno vrijeme izvođenja još nije napisalo datoteku dnevnika.';

  @override
  String get thisComputer => 'Ovo računalo';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta instalira najnoviju pozadinu prije izdanja. Očekujte grube rubove.';

  @override
  String get copiedFinalResponse => 'Kopiran konačni odgovor';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Konačni odgovor pojavljuje se ovdje kada se izvođenje završi.';

  @override
  String get waitingForTheFirstStep => 'Čekajući prvi korak…';

  @override
  String get loadingPrompt => 'Učitavanje upita...';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Za ovo izvođenje nije zabilježen konačni odgovor.';

  @override
  String get readyToSignIn => 'Spreman za prijavu';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Prijeđite na \"Zadano\" ili \"Uvijek pitaj\" da ponovno omogućite provjere odobrenja.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Pošaljite ažuriranje upravljanja ili sljedeću bilješku za trenutnu vožnju...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Nema mrežne veze. NeoAgent će se ponovno povezati kada uređaj ponovno bude online.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Primijenjeno je najnovije ažuriranje upravljanja na trenutnu vožnju.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Priprema privatne glasovne sesije…';

  @override
  String get preparingYourComputer => 'Priprema vašeg računala';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent preuzima i priprema sigurni Linux sustav. Ovo se događa samo prvi put.';

  @override
  String get moreFreeSpaceIsNeeded => 'Potrebno je više slobodnog prostora';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Oslobodite malo prostora na disku na NeoAgent hostu, a zatim pokušajte ponovno. Vaši postojeći računalni podaci su sigurni.';

  @override
  String get androidReady => 'Spremno za Android';

  @override
  String get startingAndroid2 => 'Pokretanje Androida…';

  @override
  String get androidStopped => 'Android je stao';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Prvo pokretanje preuzima Android SDK i sliku sustava, što može potrajati nekoliko minuta.';

  @override
  String get androidIsStopped => 'Android je zaustavljen';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Pokrenite upravljano Android okruženje kada vam zatreba.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Neka NeoAgent radi na ovom računalu';

  @override
  String get firstTimeSetupIsInProgress => 'U tijeku je prvo postavljanje.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent može koristiti pristup koji dopustite.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Oslobodite malo prostora za pohranu i pokušajte ponovo.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Počnite kada želite da vam NeoAgent pomogne.';

  @override
  String get systemPermissionMissing => 'Nedostaje sistemska dozvola';

  @override
  String get connectingThisDevice => 'Povezivanje ovog uređaja';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Uspostavlja se sigurna lokalna veza.';

  @override
  String get recordingYourDemonstration => 'Snimanje vaše demonstracije';

  @override
  String get noErrorsInTheRecentLog => 'Nema grešaka u nedavnom dnevniku.';

  @override
  String get loadingAccounts => 'Učitavanje računa…';

  @override
  String get neverSignedIn => 'Nikad prijavljen';

  @override
  String get emptyUsesTheServerDefault =>
      'Empty koristi zadanu vrijednost poslužitelja.';

  @override
  String get followTheSelectedSession => 'Pratite odabranu sesiju';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Način plana samo pregledava. Prebacite se na način rada agenta kako biste dopustili NeoAgentu da uređuje datoteke.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Potrebno za dodavanje ili promjenu e-pošte vašeg računa.';

  @override
  String get confirmNewPassword => 'Potvrdite novu lozinku';

  @override
  String get passwordChanged => 'Lozinka promijenjena.';

  @override
  String get thisRequestHasAlreadyBeenUsed => 'Ovaj zahtjev je već iskorišten.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Ovaj zahtjev je istekao. Zamolite drugi uređaj da generira novi kôd.';

  @override
  String get startQuickstart => 'Pokrenite Quickstart';

  @override
  String get createYourAccount => 'Kreirajte svoj račun';

  @override
  String get showWorkAsSummaries => 'Prikaži rad kao sažetak';

  @override
  String get tokensUsedByTheLatestRun =>
      'Tokeni korišteni u posljednjem izvođenju';

  @override
  String get listedTheWorkspaceRoot => 'Naveden je korijen radnog prostora';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Još uvijek nisu dostupne službene integracije.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Još nema konfiguriranih MCP poslužitelja. Dodajte jedan kako biste otkrili njegove alate.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Dodajte MCP poslužitelj ili instalirajte skill za početak.';

  @override
  String get setUp => 'Postaviti';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Ostavite prazno kako biste zadržali pohranjenu vrijednost';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Ovo uklanja adresu za svaki račun na ovom poslužitelju.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Samo pričaj. Možete prekinuti bilo kada. Dodirnite za isključivanje zvuka.';

  @override
  String get tapAgainWhenYouAreDone => 'Dodirnite ponovno kada završite.';

  @override
  String get workingOnATaskInTheBackground => 'Rad na zadatku u pozadini.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Govor-u-govor s istom memorijom, alatima i poviješću razgovora kao NeoAgent.';

  @override
  String get checkLink => 'Provjerite vezu';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Vašem agentu neće biti dopušten nijedan od kontroliranih alata.';

  @override
  String get notYoursToChange => 'Nije tvoje da se mijenjaš';

  @override
  String get setByYou => 'Vi ste postavili';

  @override
  String get noTools => 'Bez alata';

  @override
  String get untitledLink => 'Link bez naslova';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Prestaje raditi nakon što ga jedna osoba otkupi.';

  @override
  String get theOperator => 'Operater';

  @override
  String get smartSelectorOn => 'Pametni birač uključen';

  @override
  String get startASessionToBegin => 'Pokrenite sesiju za početak';

  @override
  String get steerTheActiveRun => 'Usmjerite aktivno trčanje…';

  @override
  String get describeWhatToPlan => 'Opišite što planirati…';

  @override
  String get stopDictation => 'Prekini diktiranje';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Poruke usmjeravaju trenutnu vožnju · ⌘↵ pošalji · ⌘. zaustaviti se';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Način planiranja samo pregledava; ništa se ne mijenja dok ne implementirate · ⌘↵ pošalji';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agent uređuje radni prostor. Plan samo pregledava.';

  @override
  String get defaultModel => 'Zadani model';

  @override
  String get openingScanner => 'Otvaranje skenera...';

  @override
  String get theAgentCanUseThisSkill => 'Agent može koristiti ovu vještinu.';

  @override
  String get allSelected => 'Sve odabrano';

  @override
  String get addCoreMemoryEntry => 'Dodaj Core Memory Entry';

  @override
  String get channelId => 'ID kanala';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Zadaci koje je stvorila umjetna inteligencija i neodređeni zadaci koriste trenutnu zadanu vrijednost.';

  @override
  String get waitingForRunEvents => 'Čekanje na događaje pokretanja...';

  @override
  String get hideSteps => 'Sakrij korake';

  @override
  String get commitTheActiveLiveCapture => 'Pokrenite aktivno snimanje uživo';

  @override
  String get stopCaptureAndSubmit => 'Zaustavite snimanje i pošaljite';

  @override
  String get clickTheMicToStartSpeaking =>
      'Pritisnite mikrofon da biste počeli govoriti';

  @override
  String get connectACustomEndpoint => 'Povežite prilagođenu krajnju točku';

  @override
  String get hostedProvider => 'hosted provider.';

  @override
  String get muted => ' • utišan';

  @override
  String get addWhoCanMessage => 'Dodajte tko može slati poruke';

  @override
  String get joinsGroupConversations => 'Pridružuje se grupnim razgovorima';

  @override
  String get label1PersonOrGroupAdded => 'Dodana je 1 osoba ili grupa';

  @override
  String get inProgress => 'U tijeku';

  @override
  String get waitingForUpdateJobOutput => 'Čeka se izlaz zadatka ažuriranja…';

  @override
  String get taskTrigger => 'Okidač zadatka';

  @override
  String get bearerToken => 'Token na nositelja';

  @override
  String get bearerToken2 => 'Token nositelja';

  @override
  String get notRecorded => 'Nije snimljeno';

  @override
  String get sessionCookie => 'Sesijski kolačić';

  @override
  String get neverUsed => 'Nikad korišten';

  @override
  String get linkedRecently => 'Povezano nedavno';

  @override
  String get notUsedYet => 'Još nije korišten';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Jedan ili više računa je isteklo. Ponovno se povežite za vraćanje pristupa. Ako se to nastavi događati, vaša aplikacija Google Cloud OAuth možda je u načinu rada za testiranje — objavite je u produkciji na Google Cloud konzoli kako biste dobili dugotrajne tokene.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Trezor je povezan i dostupan nakon ponovnog pokretanja';

  @override
  String get vaultConnectedForThisSession => 'Trezor je povezan za ovu sesiju';

  @override
  String get connectAnotherAccount => 'Povežite drugi račun';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Zalijepite zamjenski dugotrajni pristupni token';

  @override
  String get updateInstance => 'Instanca ažuriranja';

  @override
  String get pasteAReplacementToken => 'Zalijepite zamjenski token';

  @override
  String get replaceAccount => 'Zamijeni račun';

  @override
  String get addAccount => 'Dodaj račun';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Može delegirati bilo kojem agentu za prijem';

  @override
  String get canReceiveDelegatedTasks2 => 'mogu primati delegirane zadatke';

  @override
  String get noSyncYet => 'Još nema sinkronizacije';

  @override
  String get noNewData => 'Nema novih podataka';

  @override
  String get syncOnceToSeedYourBackend =>
      'Sinkronizirajte jednom da biste postavili svoju pozadinu.';

  @override
  String get lastWindowEndIsUnknown => 'Zadnji kraj prozora je nepoznat.';

  @override
  String get lastNonEmptySync => 'Zadnja sinkronizacija koja nije prazna';

  @override
  String get stopTranscribe => 'Zaustavi i prepiši';

  @override
  String get steeringMode => 'Način upravljanja';

  @override
  String get noMessageText => 'Nema teksta poruke';

  @override
  String get reconnectingToServer => 'Ponovno povezivanje s poslužiteljem...';

  @override
  String get signingIn => 'Prijava...';

  @override
  String get noGroupsFoundYet => 'Još nije pronađena nijedna grupa';

  @override
  String get onForNewGroupsOnly => 'Uključeno samo za nove grupe';

  @override
  String get noGroupsInThisCategory => 'Nema grupa u ovoj kategoriji';

  @override
  String get groupOrChannel => 'Grupa ili kanal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Bilješke koje pišete sami sebi počinju nizati, a odgovori slijeću u isti chat. Popis dopuštenih ovdje se ne primjenjuje.';

  @override
  String get needToReply => 'Treba odgovoriti';

  @override
  String get enter2faCode => 'Unesite 2FA kod';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Otvorite svoju aplikaciju za autentifikaciju i unesite trenutni NeoAgent kod.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Već imate račun? Prijavite se';

  @override
  String get serverOnThisComputer => 'Poslužitelj na ovom računalu';

  @override
  String get showQrCode => 'Prikaži QR kod';

  @override
  String get createAnotherNeoagentAccount =>
      'Napravite još jedan NeoAgent račun.';

  @override
  String get canCoordinateDelegatedWork => 'Može koordinirati delegirani posao';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'NeoAgent runtime arhiva nije mogla biti ekstrahirana.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'NeoAgent runtime arhivu nije moguće pročitati.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'NeoAgent runtime arhiva sadrži nesiguran put.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'NeoAgent runtime arhiva sadrži nesigurnu vezu.';

  @override
  String get installingAppPackageOnThePhone =>
      'Instaliranje paketa aplikacija na telefon...';

  @override
  String get dragAndDropAApkOrApks =>
      'Ovdje povucite i ispustite .apk ili .apks datoteku ili kliknite za pregledavanje.';

  @override
  String get releaseToInstallThisPackage =>
      'Otpustite da biste instalirali ovaj paket';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Sigurnosni ključ nije moguće upotrijebiti.';

  @override
  String get connecting => 'Povezivanje…';

  @override
  String get changes => 'Promjene';

  @override
  String get runtimeReady => 'Runtime spreman';

  @override
  String get saving => 'Spremanje...';

  @override
  String get earlier => 'Ranije';

  @override
  String get monthJan => 'siječanj';

  @override
  String get monthFeb => 'velj';

  @override
  String get monthMar => 'ožujak';

  @override
  String get monthApr => 'tra';

  @override
  String get monthMay => 'svibnja';

  @override
  String get monthJun => 'lipnja';

  @override
  String get monthJul => 'srp';

  @override
  String get monthAug => 'kolovoz';

  @override
  String get monthSep => 'ruj';

  @override
  String get monthOct => 'lis';

  @override
  String get monthNov => 'nov';

  @override
  String get monthDec => 'pro';

  @override
  String get steeringWord => 'Upravljanje';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Ovo prebacuje pozadinu s kanala $arg1 na kanal $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return '$arg1 kolačići uvezeni';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'Prije ${arg1}s';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Upravljanje u redu čekanja: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Web-aplikacija nije mogla doći do NeoAgent pozadine.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Preglednik je blokirao traženi zahtjev zbog Pravila sigurnosti sadržaja.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 od 4 dozvoljena';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Odradite zadatak kao i inače.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Promjene · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Ovaj uređaj · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Ograničenje je dosegnuto$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return '$arg1 kodovi za oporavak su još uvijek dostupni.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Sigurnosni ključ $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Trenutačna sesija';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nZadnje korištenje: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Radim u $arg1 na ovom uređaju. NeoAgent izravno čita i uređuje mapu i može pokretati naredbe, otvarati aplikacije i koristiti zaslon.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Radio za $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Dopušteno od $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1 pozivne veze od $arg2 su opozvane';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Dodajte osobe i grupe s kojima bi $arg1 trebao razgovarati';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Dodajte osobe i grupe s kojima $arg1 smije razgovarati.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Gdje $arg1 sluša';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 promatra ova mjesta tražeći spomene. Svatko može postavljati ovdje, tako da ljudi i dalje trebaju vlastito odobrenje u nastavku.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Ovi ljudi mogu pitati $arg1 gdje god to označe. Uloge se računaju samo na gore navedenim mjestima.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Samo kada je $arg1 označen';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Uključeno za sve $arg1 grupe';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 i dalje čuje samo osobe i grupe koje ste već odobrili. Ovo samo omogućuje $arg1 da se tamo pridruži običnom chatu, ne samo oznakama i odgovorima.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 i dalje čuje samo osobe i grupe koje ste već odobrili. Ovo samo odabire kojoj od tih grupa treba da se pridruži.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Ako netko označi $arg1 ili odgovori, $arg1 uvijek odgovara. Uključite ovo ako se $arg1 također treba uključiti u uobičajeni grupni chat.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Nove grupe dopuštaju $arg1 da se pridruži običnom chatu s odobrenim osobama, sve dok ih ne isključite.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Nove grupe dopuštaju $arg1 da se pridruži običnom chatu dok ih ne isključite.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Nove grupe ostaju tihe osim ako odobrena osoba ne označi $arg1, dok ih ne uključite.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Samo kada odobrena osoba označi $arg1, osim ako ne uključite grupu';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Samo kada je $arg1 označen, osim ako ne uključite grupu';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 od $arg2 grupa pridružuju se običnom chatu s odobrenim osobama';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Ovo ne odobrava nove ljude. Oznake i odgovori odobrenih osoba uvijek dobivaju odgovor. Uključite grupu ako se $arg1 tamo također treba pridružiti običnom chatu.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Ovo ne odobrava nove ljude. Uključite grupu ako se $arg1 treba pridružiti običnom chatu s osobama koje ste već odobrili.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Oznake i odgovori uvijek dobivaju odgovor. Uključite grupu ako se $arg1 tamo također treba pridružiti običnom chatu.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 pridružuje se običnom chatu s odobrenim osobama';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 se može pridružiti običnom chatu';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 odgovara samo kada ga odobri odobrena osoba';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Nothing extra is needed. Povežite se da biste počeli koristiti $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Refreshes in ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Register with $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Nema sjećanja povezanih sa \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (default)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Grana: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 se pridružuje samo grupama i kanalima koje dodate u nastavku.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 je potreban za lociranje podataka o vremenu izvođenja NeoAgenta.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[skraćeni pregled, ukupno $arg1 bajtova]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[ograničen artefakt, ukupno $arg1 bajtova]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' u $arg1';
  }

  @override
  String get worldNews => 'Svjetske vijesti';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Pokreni se kad se pojave novi svjetski naslovi. Vaš upit odlučuje hoćete li vas obavijestiti.';

  @override
  String get newsKeywordsOptional => 'Ključne riječi (nije obavezno)';

  @override
  String get worldNewsSetup => 'World News Setup';

  @override
  String get connectWorldNewsWithGnews =>
      'Dodajte GNews API ključ (besplatan plan dostupan na gnews.io). Pohranjuje se šifrirano i koristi se za anketiranje glavnih naslova za okidače Svjetskih vijesti.';

  @override
  String get gnewsApiKey => 'GNews API ključ';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Zalijepite zamjenski GNews API ključ';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Ostavite ključ prazan kako biste zadržali trenutno pohranjeni ključ.';

  @override
  String get gnewsApiKeyIsRequired => 'Potreban je GNews API ključ.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Nije moguće spremiti postavke Svjetskih vijesti.';

  @override
  String get disconnectWorldNews => 'Odspojite Svjetske vijesti';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Ovo uklanja pohranjeni GNews API ključ. Okidači Svjetskih vijesti prestat će se aktivirati dok ponovno ne dodate ključ.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Nije moguće prekinuti vezu Svjetskih vijesti.';

  @override
  String get systemOneModels => 'SystemOne modeli';

  @override
  String get systemOneAuto => 'Automatski';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Bira najbolji dostupni SystemOne model';

  @override
  String get systemOneOffTheChatModelDecides => 'Model chata donosi te odluke';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Modeli odlučivanja koji čine pozive iza scene u djeliću sekunde: grupni chat naizmjence i koraci preglednika. Vaš model chata i dalje piše svaki odgovor.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Model SystemOne odlučuje kada će govoriti dok je uključen; ovaj model je zamjena.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 postigao je SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne je izravno ocijenio ovu poruku. No language model ran.';

  @override
  String get systemOneUnavailable => 'SystemOne nedostupan';

  @override
  String get systemOneAdminAvailability =>
      'Modele odlučivanja agenti mogu odabrati pod Postavke › Modeli. Model koji je ovdje isključen napušta taj birač, a agenti koji su ga odabrali vraćaju se Automatski. Dok je bilo koji model isključen, SystemOne modeli koje pružatelji dodaju kasnije počinju također biti isključeni.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Još nema SystemOne modela. Dodajte tipku TypeSafe ili OpenRouter pod Providers ili povucite model odlučivanja kao što je nimble u Ollami 0.35 ili novijoj verziji.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Još nije dostupan model SystemOne. Dodajte TypeSafe ili OpenRouter ključ pod Postavke › Modeli › Donesite vlastiti ključ ili povucite model odlučivanja kao što je nimble u Ollami.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone sustav modela jedne odluke jev typesafe openrouter ollama dostupnost enable onemogući';

  @override
  String get chatModels => 'Chat modeli';

  @override
  String get disabled => 'Onemogućeno';

  @override
  String get enableShown => 'Omogući prikazano';

  @override
  String get disableShown => 'Onemogući prikazano';

  @override
  String get expandAll => 'Proširi sve';

  @override
  String get collapseAll => 'Sažmi sve';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 nespremljene promjene';
  }

  @override
  String get settingsScopeAllAgents => 'Svi agenti';

  @override
  String get settingsScopeAgent => 'Ovaj agent';

  @override
  String get settingsScopeApp => 'aplikacija';

  @override
  String get settingsScopeAccountHint => 'Isto svugdje gdje se prijavite';

  @override
  String get settingsScopeAllAgentsHint => 'Dijele svi vaši agenti';

  @override
  String get settingsAppliesTo => 'Odnosi se na';

  @override
  String get settingsSaving => 'Spremanje...';

  @override
  String get settingsSavedAutomatically => 'Promjene se spremaju automatski';

  @override
  String get settingsSearchHint => 'Pretraži sve postavke';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Prijava i sigurnost';

  @override
  String get settingsPageUsage => 'Korištenje';

  @override
  String get settingsPagePermissions => 'Dozvole';

  @override
  String get settingsPageComputer => 'Računalo i web';

  @override
  String get settingsPageBehavior => 'Ponašanje';

  @override
  String get settingsPageSystem => 'sustav';

  @override
  String get settingsPagePlatforms => 'Platforme';

  @override
  String get settingsPageProfileDescription =>
      'Vaše ime i e-mail, kopija vaših podataka i odjava.';

  @override
  String get settingsPageSecurityDescription =>
      'Lozinka, autentifikacija u dva faktora, sigurnosni ključevi i gdje ste prijavljeni.';

  @override
  String get settingsPageUsageDescription =>
      'Vaša ograničenja i tokenska potrošnja, sve na jednom mjestu.';

  @override
  String get settingsPageAgentsDescription =>
      'Stvorite agente i odaberite koji od njih odgovara prema zadanim postavkama.';

  @override
  String get settingsPagePermissionsDescription =>
      'Što vaši agenti mogu učiniti bez da vas prethodno pitaju.';

  @override
  String get settingsPageComputerDescription =>
      'Računalo na kojem vaši agenti rade i web stranice koje mogu čitati kao vi.';

  @override
  String get settingsPageModelsDescription =>
      'Koje modele ovaj agent koristi i API ključeve koji ih plaćaju.';

  @override
  String get settingsPageBehaviorDescription =>
      'Kako ovaj agent razgovara i kako čita grupni razgovor.';

  @override
  String get settingsPageVoiceDescription =>
      'Pozivi uživo, diktiranje i govorni odgovori za ovog agenta.';

  @override
  String get settingsPageMessagingDescription =>
      'Gdje ljudi mogu doći do ovog agenta i kako se ponaša u chatovima.';

  @override
  String get settingsPageGeneralDescription =>
      'Izgled, jezik, vremenska zona i što ova aplikacija radi u pozadini.';

  @override
  String get settingsPageSystemDescription =>
      'Poslužitelj koji koristi ovaj prozor, onaj na ovom računalu i ažuriranja aplikacija.';

  @override
  String get settingsYourAgents => 'Vaši agenti';

  @override
  String get settingsChatModel => 'Chat model';

  @override
  String get settingsChatModelDescription => 'Odgovara na vaše poruke.';

  @override
  String get settingsSubAgentModel => 'Model podzastupnika';

  @override
  String get settingsSubAgentModelDescription =>
      'Izvršava posao koji se predaje tijekom zadatka.';

  @override
  String get settingsDefaultModels => 'Zadani modeli';

  @override
  String get settingsDefaultModelsDescription =>
      'Koristi se kad god razgovor ili zadatak ne izaberu vlastiti model.';

  @override
  String get settingsModelPool => 'Model bazena';

  @override
  String get settingsApiKeysDescription =>
      'Koristite svoje ključeve ili krajnju točku za ovog agenta. Ključevi su šifrirani i nikad se više ne prikazuju.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Fino podešavanje';

  @override
  String get settingsFineTuningDescription =>
      'Rijetko potrebna. Zadane postavke odgovaraju većini chatova.';

  @override
  String get settingsShow => 'pokazati';

  @override
  String get settingsHide => 'Sakrij se';

  @override
  String get settingsMinimumContribution => 'Minimalna vrijednost doprinosa';

  @override
  String get settingsBatchWindow => 'Sobni šaržni prozor';

  @override
  String get settingsBatchWindowDescription =>
      'Čeka toliko dugo da se brze poruke tretiraju kao jedan potez.';

  @override
  String get settingsHandsFree => 'Bez ruku';

  @override
  String get settingsHandsFreeDescription =>
      'Razgovarajte slobodno i prekidajte u bilo kojem trenutku.';

  @override
  String get settingsPushToTalkDescription =>
      'Držite za razgovor, otpustite za slanje.';

  @override
  String get settingsLiveVoice => 'Glas uživo';

  @override
  String get settingsChannels => 'Kanali';

  @override
  String get settingsGroupChats => 'U grupnim razgovorima';

  @override
  String get settingsGroupChatsDescription =>
      'Kako se ovaj agent ponaša u grupama na svakom kanalu.';

  @override
  String get settingsGroupChatsDisabled =>
      'Uključite module ponašanja u Ponašanje da biste ih promijenili.';

  @override
  String get settingsParticipationAutomatic => 'Automatski';

  @override
  String get settingsParticipationMentionOnly => 'Samo spomenuti';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Čita sobu i pridružuje se kad ima nešto korisno za dodati.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Odgovara samo kada se spomene ili odgovori.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Odgovara na svaku poruku.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Dulje odgovore dijeli na kratke poruke, onako kako bi to učinila osoba.';

  @override
  String get settingsDeliverySingleDescription =>
      'Šalje svaki odgovor kao jednu poruku.';

  @override
  String get settingsComputerStatus => 'Status';

  @override
  String get settingsTest => 'test';

  @override
  String get settingsAppearance => 'Izgled';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'sustav';

  @override
  String get settingsThemeLight => 'Svijetla';

  @override
  String get settingsThemeDark => 'Tamna';

  @override
  String get settingsCloseWindow => 'Kad zatvorite prozor';

  @override
  String get settingsCloseAsk => 'Pitajte';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent radi u pozadini i ostaje dostupan.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent potpuno prestaje.';

  @override
  String get settingsPhoneTriggers => 'Telefonski okidači';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signale koje ovaj telefon šalje vašim agentima kako bi zadaci mogli reagirati na njih.';

  @override
  String get settingsLocationTriggers => 'Lokacijski okidači';

  @override
  String get settingsLocationTriggersDescription =>
      'Provjerava vašu približnu lokaciju svakih nekoliko minuta u odnosu na mjesta koja gledaju vaši zadaci.';

  @override
  String get settingsNotificationTriggers => 'Okidači obavijesti';

  @override
  String get settingsNotificationTriggersDescription =>
      'Prosljeđuje obavijesti iz drugih aplikacija na ovom telefonu vašim agentima.';

  @override
  String get settingsSetup => 'Postavljanje';

  @override
  String get settingsOnboarding => 'Uključivanje';

  @override
  String get settingsOnboardingDescription =>
      'Ponovno prođite kroz postavljanje prvog pokretanja. Ništa što ste postavili nije izgubljeno.';

  @override
  String get settingsUsernameDescription =>
      'Koristi se za prijavu. Ne može se promijeniti.';

  @override
  String get settingsExport => 'Izvoz';

  @override
  String get settingsLeave => 'Odjavi se i izbriši';

  @override
  String get settingsSignOutDescription =>
      'Odjavljuje vas samo na ovom uređaju.';

  @override
  String get settingsDeleteAccountDescription =>
      'Briše vaš račun, agente, memoriju i postavke. Ovo se ne može poništiti.';

  @override
  String get settingsTokenUsage => 'Upotreba tokena';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Nijedna postavka ne odgovara \"$query\".';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rezultata',
      few: '$count rezultata',
      one: '$count rezultat',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Napredne postavke modela';

  @override
  String get settingsAdvancedModelsDescription =>
      'Neobavezno. Pričvrstite model na jednu vrstu rada; preuzima kad god agent koristi te alate. Sve što je ostavljeno na zadanim postavkama slijedi model chata.';

  @override
  String get settingsTaskModelDefault => 'Zadano';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Prati model chata';

  @override
  String get settingsTaskModelCoding => 'Kodiranje';

  @override
  String get settingsTaskModelCodingDescription =>
      'Pisanje, uređivanje i otklanjanje pogrešaka koda.';

  @override
  String get settingsTaskModelComputerUse => 'Korištenje računala';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Vožnja preglednika i radne površine.';

  @override
  String get settingsTaskModelAndroidUse => 'korištenje Androida';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Upravljanje aplikacijama na Android uređaju ili emulatoru.';

  @override
  String get settingsTaskModelResearch => 'istraživanje';

  @override
  String get settingsTaskModelResearchDescription =>
      'Pretraživanje, čitanje i sažimanje izvora.';

  @override
  String get knowledgeGraphHint =>
      'Vaši najčešće spominjani entiteti, obojani klasterom. Linije povezuju entitete koji se pojavljuju u istim sjećanjima. Dodirnite jedan da biste vidjeli njegove veze i sjećanja; povucite za pomicanje, stisnite prste ili Ctrl/⌘ pomaknite se za zumiranje.';

  @override
  String get linkedEntities => 'Povezani entiteti';

  @override
  String get noLinkedEntities => 'Još nije povezan s drugim entitetima.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 spominje';
  }

  @override
  String get entityKindConcept => 'Koncept';

  @override
  String get entityKindDomain => 'Domena';

  @override
  String get entityKindEmail => 'E-mail';

  @override
  String get entityKindLink => 'Link';

  @override
  String get entityKindFile => 'File';

  @override
  String get entityKindAcronym => 'Akronim';

  @override
  String get entityKindIdentifier => 'Identifikator';

  @override
  String get entityKindVersion => 'Verzija';

  @override
  String get openFullscreen => 'Otvori cijeli zaslon';

  @override
  String get zoomIn => 'Povećaj';

  @override
  String get zoomOut => 'Smanji';

  @override
  String get searchEntities => 'Pronađite entitet';

  @override
  String get incomingCall => 'Dolazni poziv';

  @override
  String get answerCall => 'odgovori';

  @override
  String get callMeLater => 'Nazovi me kasnije';

  @override
  String get callingEllipsis => 'Pozivanje…';

  @override
  String get reconnectingCall => 'Ponovno povezivanje';

  @override
  String get agentWorking => 'radim';

  @override
  String get micMuted => 'Isključeno';

  @override
  String get speakerphone => 'Zvučnik';

  @override
  String get muteMic => 'Isključi zvuk';

  @override
  String get unmuteMic => 'Uključi zvuk';

  @override
  String get releaseToSend => 'Otpustite za slanje';

  @override
  String get callEnded => 'Poziv završen';

  @override
  String get openConversation => 'Otvoren razgovor';

  @override
  String get callBack => 'Povratni poziv';

  @override
  String get letCallsReachYou => 'Neka pozivi stignu do vas';

  @override
  String get callPermissionsIntro =>
      'Vaši agenti vas mogu nazvati. Za zvonjenje poput telefonskog poziva dok je NeoAgent u pozadini ili je vaš telefon zaključan, potrebno mu je ovo.';

  @override
  String get showOverOtherApps => 'Prikaži preko drugih aplikacija';

  @override
  String get showOverOtherAppsDetail =>
      'Prikazuje zaslon poziva gdje god se nalazili.';

  @override
  String get fullScreenCalls => 'Pozivi preko cijelog zaslona';

  @override
  String get fullScreenCallsDetail => 'Zvoni preko zaključanog zaslona.';

  @override
  String get unrestrictedBattery => 'Neograničena baterija';

  @override
  String get unrestrictedBatteryDetail =>
      'Održava NeoAgent povezanim tako da pozivi stižu.';

  @override
  String get permissionAllowed => 'Dopušteno';

  @override
  String get triggerSectionCalendar => 'Kalendar';

  @override
  String get triggerSectionFiles => 'Datoteke i dokumenti';

  @override
  String get triggerSectionHome => 'Dom i mediji';

  @override
  String get triggerSectionDevices => 'Uređaji i mjesta';

  @override
  String get triggerSectionTasks => 'Zadaci';

  @override
  String get messagingMemberJoined => 'Član se pridružio';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Pokrenite kada se netko pridruži Discord poslužitelju, Telegram ili WhatsApp grupi, Slack kanalu ili Matrix sobi.';

  @override
  String get messagingMemberLeft => 'Član lijevo';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Pokrenite kada netko napusti Discord poslužitelj, Telegram ili WhatsApp grupu, Slack kanal ili Matrix sobu.';

  @override
  String get messagingReactionAdded => 'Dodana reakcija';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Pokreni kada dopuštena osoba reagira na poruku u privatnom chatu.';

  @override
  String get messagingPlatformDisconnected => 'Razmjena poruka prekinuta';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Pokreni kada se veza za razmjenu poruka zaustavi i treba vas, primjerice nakon odjave.';

  @override
  String get googleCalendarEventStarting => 'Počinje događaj Google kalendara';

  @override
  String get googleCalendarEventCreated =>
      'Izrađen je događaj Google kalendara';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Pokrenite kada se pojavi novi događaj ili pozivnica.';

  @override
  String get outlookCalendarEventStarting =>
      'Počinje događaj Outlook kalendara';

  @override
  String get nextcloudCalendarEventStarting =>
      'Početak događaja Nextcloud kalendara';

  @override
  String get runMinutesBeforeEachEvent =>
      'Trčite određeni broj minuta prije svakog događaja.';

  @override
  String get googleDriveFileAdded => 'Dodana je datoteka Google diska';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Pokreni kada se datoteka doda na Disk ili u mapu u njemu.';

  @override
  String get googleSheetsRowAdded => 'Dodan je red Google tablica';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Pokreni kada se na listu pojave novi redci.';

  @override
  String get onedriveFileAdded => 'OneDrive datoteka dodana';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Pokreni kada se datoteka doda u mapu OneDrive.';

  @override
  String get nextcloudFileAdded => 'Dodana datoteka Nextcloud';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Pokreni kada se datoteka doda u mapu Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Nextcloud datoteka podijeljena s vama';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Pokreni kada netko s vama podijeli datoteku ili mapu.';

  @override
  String get notionItemAdded => 'Dodana stavka baze podataka pojmova';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Pokreni kada se stavka doda u bazu podataka Notion.';

  @override
  String get notionItemUpdated => 'Ažurirana je stavka baze podataka pojmova';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Pokreni kada se stavka u bazi podataka Notion promijeni.';

  @override
  String get trelloCardEnteredList => 'Trello kartica dodana na popis';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Pokreni kada je kartica kreirana na popisu ili premještena na njega.';

  @override
  String get figmaCommentAdded => 'Dodan Figma komentar';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Pokreni kada netko komentira Figma datoteku.';

  @override
  String get githubPrOpened => 'Otvoren je GitHub zahtjev za povlačenje';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Pokreni kada se otvori novi zahtjev za povlačenjem u repozitoriju.';

  @override
  String get githubWorkflowRunFailed =>
      'Pokretanje GitHub tijeka rada nije uspjelo';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Pokreni kada pokretanje GitHub Actions ne uspije.';

  @override
  String get githubCommitPushed => 'GitHub potvrda je gurnuta';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Pokreni kada nova predaja stigne do grane.';

  @override
  String get mcpServerFailed => 'MCP poslužitelj nije uspio';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Pokreni kada MCP poslužitelj koji je radio zakaže ili se treba prijaviti.';

  @override
  String get homeAssistantStateChanged =>
      'Stanje kućnog pomoćnika promijenjeno';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Pokreni kada se entitet promijeni, dosegne stanje ili prijeđe vrijednost.';

  @override
  String get spotifyTrackChanged => 'Spotify pjesma promijenjena';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Pokreni kada počne svirati druga pjesma.';

  @override
  String get neorecallDailySummaryReady => 'NeoRecall dnevni sažetak spreman';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Pokrenite kada je sažetak dana konačan.';

  @override
  String get neorecallConversationRecorded => 'NeoRecall razgovor snimljen';

  @override
  String get runWhenARecordedConversationEnds =>
      'Pokreni kada snimljeni razgovor završi.';

  @override
  String get geofenceTrigger => 'Lokacijska geoograda';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Trčite kada vaš telefon stigne na neko mjesto ili ga napusti. Potrebno je praćenje lokacije na telefonu.';

  @override
  String get healthMetricRecorded => 'Zabilježena metrika zdravlja';

  @override
  String get runWhenAHealthReadingArrives =>
      'Pokreni kada stigne sinkronizirano očitanje stanja, po izboru iznad ili ispod vrijednosti.';

  @override
  String get wearableConnectionChanged => 'Nosivi spojen ili isključen';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Trčite kada se vaš nosivi spoji ili odspoji.';

  @override
  String get taskRunFinished => 'Još jedan zadatak završen';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Pokrenite nakon što drugi zadatak završi, uspije ili ne uspije.';

  @override
  String get appPackageOptional => 'Paket aplikacija (izborno)';

  @override
  String get appPackageHelper => 'Na primjer com.whatsapp';

  @override
  String get anyPlatform => 'Bilo koja platforma';

  @override
  String get spaceIdOptional =>
      'ID poslužitelja, grupe, kanala ili sobe (nije obavezno)';

  @override
  String get spaceIdHelper => 'Empty gleda svaki u kojem se nalazi bot.';

  @override
  String get emojiOptional => 'Emoji (neobavezno)';

  @override
  String get chatIdOptional => 'ID chata (nije obavezno)';

  @override
  String get platformOptional => 'Platforma (izborno)';

  @override
  String get platformOptionalHelper =>
      'Na primjer whatsapp. Prazni satovi svi.';

  @override
  String get minutesBefore => 'Nekoliko minuta prije';

  @override
  String get calendarIdOptional => 'ID kalendara (nije obavezno)';

  @override
  String get calendarIdHelper => 'Empty koristi vaš primarni kalendar.';

  @override
  String get invitesOnly => 'Samo pozivnice od drugih';

  @override
  String get nextcloudCalendarPath => 'Kalendar';

  @override
  String get nextcloudCalendarPathHelper =>
      'Njegovo ime na popisu kalendara Nextcloud, na primjer osobno';

  @override
  String get folderIdOptionalHelperDrive => 'Prazni satovi cijeli Drive.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Empty prati korijensku mapu.';

  @override
  String get driveFolderIdOptional => 'ID mape (nije obavezno)';

  @override
  String get spreadsheetId => 'ID proračunske tablice';

  @override
  String get sheetRange => 'Raspon';

  @override
  String get sheetRangeHelper => 'Stupci tablice, na primjer Sheet1!A:E';

  @override
  String get folderPathOptional => 'Put do mape (neobavezno)';

  @override
  String get folderPathHelper => 'Na primjer Dokumenti';

  @override
  String get notionDatabaseId => 'ID baze podataka';

  @override
  String get trelloListId => 'ID popisa';

  @override
  String get figmaFileKey => 'Ključ datoteke';

  @override
  String get figmaFileKeyHelper =>
      'S poveznice datoteke: figma.com/file/<ključ>/…';

  @override
  String get githubRepository => 'Spremište';

  @override
  String get workflowOptional => 'Tijek rada (nije obavezno)';

  @override
  String get workflowHelper => 'Naziv datoteke kao što je ci.yml';

  @override
  String get branchOptional => 'Podružnica (nije obavezno)';

  @override
  String get branchHelper => 'Empty koristi zadanu granu.';

  @override
  String get mcpServerIdOptional => 'ID MCP poslužitelja (neobavezno)';

  @override
  String get entityId => 'ID entiteta';

  @override
  String get entityIdHelper => 'Na primjer binarni_senzor.prednja_vrata';

  @override
  String get targetStateOptional => 'Ciljano stanje (nije obavezno)';

  @override
  String get targetStateHelper => 'Na primjer na';

  @override
  String get aboveOptional => 'Gore (nije obavezno)';

  @override
  String get belowOptional => 'Ispod (nije obavezno)';

  @override
  String get placeName => 'Ime mjesta';

  @override
  String get latitude => 'Zemljopisna širina';

  @override
  String get longitude => 'Zemljopisna dužina';

  @override
  String get radiusMeters => 'Radijus u metrima';

  @override
  String get geofenceTransition => 'kada';

  @override
  String get arriving => 'Dolazak';

  @override
  String get leaving => 'Odlazak';

  @override
  String get healthMetric => 'Mjerilo zdravlja';

  @override
  String get healthMetricHelper => 'Na primjer otkucaji srca, koraci, težina';

  @override
  String get wearableTransition => 'Kada se nosivi';

  @override
  String get wearableConnects => 'Povezuje';

  @override
  String get wearableDisconnects => 'Isključuje';

  @override
  String get sourceTask => 'Nakon zadatka';

  @override
  String get taskOutcome => 'Ishod';

  @override
  String get anyOutcome => 'Bilo kakav ishod';

  @override
  String get succeeded => 'Uspjelo';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 nedostaje ili nije valjan.';
  }

  @override
  String get triggerSectionMessaging => 'Slanje poruka';

  @override
  String get triggerSectionDeveloper => 'Developer';

  @override
  String get triggerSectionMemory => 'Memorija';

  @override
  String get triggerSectionNews => 'Vijesti';

  @override
  String get triggerSectionSystem => 'sustav';

  @override
  String get searchTriggersHint =>
      'Okidači pretraživanja, aplikacije ili događaji';

  @override
  String get noTriggersMatch =>
      'Nijedan okidač ne odgovara vašem pretraživanju.';

  @override
  String get triggerAccountMissing => 'Još nema računa';

  @override
  String get pickTriggerKeyboardHint => 'Enter odabire prvi rezultat';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 okidači';
  }

  @override
  String get addFromSkillsSh => 'Dodaj iz vještina.sh';

  @override
  String get skillsShHint =>
      'Pretražujte iznad kako biste pronašli vještine na Skills.sh ili zalijepite vezu Skills.sh ili naredbu `npx skills add`.';

  @override
  String get noSkillsShMatches =>
      'Nijedna skill.sh vještina ne odgovara ovoj pretrazi.';

  @override
  String get installingSkill => 'Instaliranje...';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Instaliran $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 instalira';
  }

  @override
  String get authVerify => 'Potvrdi';

  @override
  String get authCreateAccount => 'Napravi račun';

  @override
  String get authNewInviteLink => 'Nova veza za pozivnicu';

  @override
  String get authShowPassword => 'Prikaži lozinku';

  @override
  String get authHidePassword => 'Sakrij lozinku';

  @override
  String get authPasswordWillBeRejected => 'preslab, bit će odbijen';

  @override
  String get authUsernameTooShort =>
      'Korisničko ime mora imati najmanje 3 znaka.';

  @override
  String get authUsernameTaken => 'To je korisničko ime već zauzeto.';

  @override
  String get authSignupsClosed =>
      'Prijave su zatvorene na ovom poslužitelju. Pitajte administratora za račun.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Ovaj poslužitelj prihvaća samo prijave putem HTTPS-a. Umjesto toga otvorite $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Ovaj poslužitelj prihvaća samo prijave putem HTTPS-a. Povežite se s njim putem https:// adrese.';

  @override
  String get authAccountNotFound => 'Taj račun više ne postoji.';

  @override
  String get authQrRateLimited =>
      'Previše QR zahtjeva za prijavu. Pričekajte trenutak, a zatim osvježite kôd.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Zaboravili ste lozinku? Zamolite administratora poslužitelja da ga resetira u Administrator → Korisnici.';

  @override
  String get authChangeServer => 'Promjena poslužitelja';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Prijavljivanje na $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Ova adresa ne odgovara kao NeoAgent poslužitelj. Provjerite URL i pokušajte ponovno.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Nije moguće otvoriti sigurnu (HTTPS) vezu sa $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Nije moguće doći do $arg1 preko HTTPS-a, a ni obični HTTP nije odgovorio. Provjerite adresu i port.';
  }

  @override
  String get adminResetPassword => 'Resetiraj lozinku';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Ponovno postavite lozinku za $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Odaberite novu lozinku za $arg1. Bit će odjavljeni na svakom uređaju i ponovno će se prijaviti ovom zaporkom.';
  }

  @override
  String get adminNewPassword => 'Nova lozinka';

  @override
  String get adminSetPassword => 'Postavi lozinku';

  @override
  String get authMissingFields => 'Ispunite sva potrebna polja.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 poništi lozinku $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Lozinka ažurirana; korisnik je posvuda bio odjavljen.';

  @override
  String get authSignInTitle => 'Prijavite se na NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Skenirajte telefonom ili upotrijebite lozinku.';

  @override
  String get authOrUsePassword => 'ili koristite svoju lozinku';

  @override
  String get qrLoginWaitingTitle => 'Odobrite na svom telefonu';

  @override
  String get qrLoginWaitingBody =>
      'Vaš telefon je skenirao kod. Tamo potvrdite prijavu kako biste dovršili prijavu.';

  @override
  String get qrLoginSigningInOn => 'Prijava na';

  @override
  String get qrLoginLocation => 'Lokacija';

  @override
  String get qrLoginWaitingForApproval => 'Čeka se odobrenje';

  @override
  String get qrLoginCancelAndUsePassword => 'Odustani i upotrijebi lozinku';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Prijava je odbijena na vašem telefonu. Skenirajte novi kod da biste pokušali ponovno.';

  @override
  String get signupKey => 'Registracijski ključ';

  @override
  String get signupKeyStepSubtitle =>
      'Novi računi na ovom poslužitelju trebaju registracijski ključ. Unesite ključ koji ste dobili od administratora.';

  @override
  String get signupKeyChange => 'Promijeni';

  @override
  String get signupKeyRequiredError => 'Unesite svoj registracijski ključ.';

  @override
  String get signupKeyInvalidError =>
      'Taj registracijski ključ nije valjan. Provjerite ga i pokušajte ponovno.';

  @override
  String get signupKeyUsedError =>
      'Taj je registracijski ključ već iskorišten. Zatražite novi od administratora.';

  @override
  String get adminRequireSignupKey => 'Zahtijevaj registracijski ključ';

  @override
  String get adminRequireSignupKeyHint =>
      'Novi računi trebaju jednokratni ključ od administratora. Kada je isključeno, registrirati se može svatko tko pristupa ovom poslužitelju. Prvi račun nikad ne treba ključ.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Novi računi sada trebaju registracijski ključ.';

  @override
  String get adminSignupOpenNotice => 'Sada se svatko može registrirati.';

  @override
  String get signupKeys => 'Registracijski ključevi';

  @override
  String get signupKeysDescription =>
      'Jednokratni ključevi za registraciju dok je ključ obavezan. Svaki ključ stvara točno jedan račun.';

  @override
  String get signupKeysNew => 'Novi ključevi';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Neiskorišteni · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Iskorišteni · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Opozvani · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Svi · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Neiskorišten';

  @override
  String get signupKeyStatusUsed => 'Iskorišten';

  @override
  String get signupKeyStatusRevoked => 'Opozvan';

  @override
  String get signupKeysExport => 'Izvezi .txt';

  @override
  String get signupKeysCopied => 'Ključevi kopirani';

  @override
  String get signupKeyCopied => 'Ključ kopiran';

  @override
  String get signupKeysEmpty => 'Na ovom popisu nema ključeva.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Stvoren $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Iskoristio/la $arg1, $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Iskorišten $arg1 s računom koji je u međuvremenu izbrisan';
  }

  @override
  String get signupKeyRevokeTitle => 'Opozvati ovaj ključ?';

  @override
  String get signupKeyRevokeMessage =>
      'Nitko se više neće moći registrirati s njim. Ovo se ne može poništiti.';

  @override
  String get signupKeyRevoked => 'Ključ opozvan.';

  @override
  String signupKeysShowMore(int count) {
    return 'Prikaži još $count';
  }

  @override
  String get signupKeysCreateTitle => 'Stvori registracijske ključeve';

  @override
  String get signupKeysCount => 'Broj ključeva';

  @override
  String get signupKeysCountHelper => 'Od 1 do 500';

  @override
  String get signupKeysCountInvalid => 'Unesite broj od 1 do 500.';

  @override
  String get signupKeysLabel => 'Oznaka (neobavezno)';

  @override
  String get signupKeysLabelHint => 'npr. Proljetni beta testeri';

  @override
  String signupKeysCreateAction(int count) {
    return 'Stvori ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Ključevi spremni: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Svaki ključ dajte samo jednoj osobi. Neiskorišteni ključevi ostaju na popisu pa ih kasnije možete ponovno kopirati ili izvesti.';

  @override
  String get signupKeysSaveDialogTitle => 'Spremi registracijske ključeve';

  @override
  String get signupKeysExported => 'Ključevi izvezeni.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor je stvorio/la registracijske ključeve ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor je opozvao/la registracijski ključ';
  }

  @override
  String get providerChooseUsername => 'Odaberite korisničko ime';

  @override
  String get providerChooseUsernameBody =>
      'Odaberite dostupno korisničko ime kako biste dovršili izradu računa.';

  @override
  String get dataSharingTitle => 'Dijeli podatke o korištenju';

  @override
  String get dataSharingDescription =>
      'Pomozite onima koji vode ovaj poslužitelj da ga poboljšaju. Dijeli kako koristite NeoAgent, nikad ono što pišete ili spremate.';

  @override
  String dataSharingSince(String date) {
    return 'Dijeli se od $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Što se dijeli';

  @override
  String get dataSharingIncluded => 'Dijeli se';

  @override
  String get dataSharingExcluded => 'Nikad se ne dijeli';

  @override
  String get dataSharingIncludedDevice => 'Vrsta uređaja i verzija aplikacije';

  @override
  String get dataSharingIncludedLocale =>
      'Jezik aplikacije i regija vremenske zone, npr. Europa';

  @override
  String get dataSharingIncludedFeatures =>
      'Koje ste značajke postavili, poput zadataka, skillova i integracija';

  @override
  String get dataSharingIncludedRuns =>
      'Koje alate i modele koriste vaša pokretanja, s trajanjem i brojem tokena';

  @override
  String get dataSharingIncludedActivity =>
      'Kada koristite NeoAgent, po danu u tjednu i satu';

  @override
  String get dataSharingExcludedContent => 'Poruke, upiti i odgovori';

  @override
  String get dataSharingExcludedRuns =>
      'Naslovi pokretanja, ulazi i rezultati alata';

  @override
  String get dataSharingExcludedFiles =>
      'Datoteke, sjećanja i sve ostalo što spremate';

  @override
  String get dataSharingExcludedIdentity =>
      'Vaše ime, e-pošta, IP adresa i lokacija';

  @override
  String get dataSharingExcludedAccounts =>
      'Računi s kojima povezujete integracije';

  @override
  String get dataSharingPooledNote =>
      'Administratori vide samo zbrojeve svih koji dijele, nikad vas pojedinačno. Isključite bilo kada i odmah ispadate iz zbrojeva.';

  @override
  String get dataSharingConfirmTitle => 'Dijeliti podatke o korištenju?';

  @override
  String get dataSharingConfirmAction => 'Dijeli';

  @override
  String get sharedUsageTitle => 'Dijeljeno korištenje';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Računi koji dijele podatke o korištenju: $sharing od $total. Samo zbrojevi, bez sadržaja.';
  }

  @override
  String get sharedUsageEmpty =>
      'Još nitko ne dijeli podatke o korištenju. Uključiti se može u: Postavke, Profil, Vaši podaci.';

  @override
  String get sharedUsageRuns => 'Dijeljena pokretanja';

  @override
  String get sharedUsageAvgDuration => 'Prosj. trajanje';

  @override
  String get sharedUsageCompletedRuns => 'Dovršena pokretanja';

  @override
  String get sharedUsageStepsPerRun => 'Koraci po pokretanju';

  @override
  String get sharedUsageDevices => 'Uređaji';

  @override
  String get sharedUsageAppVersions => 'Verzije aplikacije';

  @override
  String get sharedUsageLanguages => 'Jezici';

  @override
  String get sharedUsageRegions => 'Regije';

  @override
  String get sharedUsageFeatures => 'Korištenje značajki';

  @override
  String get sharedUsageFeaturesDescription =>
      'Udio računa koji dijele i koji su je postavili.';

  @override
  String get sharedUsageTools => 'Alati';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Najčešće pozivani alati ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Pozivi: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Neuspjelo: $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Integracije';

  @override
  String get sharedUsageMessaging => 'Kanali za poruke';

  @override
  String get sharedUsageTriggers => 'Kako počinju pokretanja';

  @override
  String get sharedUsageActivity => 'Kada se koristi';

  @override
  String get sharedUsageActivityDescription =>
      'Pokretanja po danu u tjednu i satu, UTC.';

  @override
  String get sharedUsageModels => 'Učinkovitost modela';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'prosj. $latency · $cached % iz predmemorije · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Računi: $count';
  }

  @override
  String get sharedUsageNoData => 'Ništa u ovom razdoblju.';

  @override
  String get sharedUsageNotReported => 'Još nije prijavljeno';

  @override
  String get sharedUsageFeatureAgents => 'Više od jednog agenta';

  @override
  String get sharedUsageFeatureTasks => 'Zakazani zadaci';

  @override
  String get sharedUsageFeatureSkills => 'Skillovi';

  @override
  String get sharedUsageFeatureMcp => 'MCP poslužitelji';

  @override
  String get sharedUsageFeatureIntegrations => 'Integracije';

  @override
  String get sharedUsageFeatureMessaging => 'Kanali za poruke';

  @override
  String get sharedUsageFeatureMemory => 'Memorija';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in dijeljenje podataka telemetrija uređaji značajke alati modeli aktivnost';

  @override
  String get yourOAuthApp => 'Vaša OAuth aplikacija';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Vaša OAuth aplikacija za $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Ovaj poslužitelj nema globalnu aplikaciju $provider, pa se povezujete OAuth aplikacijom koju sami registrirate. Tajni ključ klijenta pohranjuje se šifrirano i više se nikad ne prikazuje.';
  }

  @override
  String get oauthAppStepCreate => '1. Izradite aplikaciju';

  @override
  String get openDeveloperConsole => 'Otvori konzolu za razvojne programere';

  @override
  String get oauthAppStepCallback =>
      '2. Registrirajte ovaj URL za povratni poziv';

  @override
  String get callbackUrlCopied => 'URL za povratni poziv kopiran';

  @override
  String get oauthAppScopes => 'Opsezi koje treba dopustiti';

  @override
  String get scopesCopied => 'Opsezi kopirani';

  @override
  String get oauthAppStepCredentials => '3. Zalijepite vjerodajnice aplikacije';

  @override
  String get couldNotSaveOAuthApp => 'Nije moguće spremiti OAuth aplikaciju.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Ukloniti vašu aplikaciju $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'Povezani računi ostaju na popisu, ali prestaju raditi dok ponovno ne dodate aplikaciju.';

  @override
  String get globalIntegrationConfiguration =>
      'Globalna konfiguracija integracija';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Neobavezne OAuth aplikacije za cijeli poslužitelj. Kad je integracija ima, svaki je račun koristi i ne može dodati vlastitu. Ostavite integraciju nepostavljenom i svaki korisnik postavlja vlastitu aplikaciju. Tajne se mogu samo upisati: ostavite prazno da zadržite spremljenu vrijednost.';

  @override
  String get globalStatus => 'Globalno';

  @override
  String get perUserStatus => 'Po korisniku';

  @override
  String get phoneSyncGuidance =>
      'Podijelite kalendare i kontakte s ovog telefona sa svojim agentom. Radi sa svim računima koji su već na telefonu.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Otvorite NeoAgent na telefonu i tamo uključite dijeljenje. Agent će tada vidjeti kalendare i kontakte svih računa na tom telefonu.';

  @override
  String get manageOnThisPhone => 'Upravljaj na ovom telefonu';

  @override
  String get setUpOnThisPhone => 'Postavi na ovom telefonu';

  @override
  String get setUpOnPhone => 'Postavi na svom telefonu';

  @override
  String emailConnectedArg1(String email) {
    return '$email povezan';
  }

  @override
  String get couldNotConnectEmail => 'Račun se nije mogao povezati.';

  @override
  String get emailSetupTitle => 'Poveži e-poštu i kalendar';

  @override
  String get emailChecking => 'Provjeravam sandučić…';

  @override
  String get emailSetupIntro =>
      'Koristite lozinku aplikacije od pružatelja e-pošte. Bez konzole za razvojne programere, gotovo za par minuta.';

  @override
  String emailOpenArg1(String provider) {
    return 'Otvori $provider';
  }

  @override
  String get emailStepServers => '1. Unesite poslužitelje';

  @override
  String get emailStepPassword => '1. Izradite lozinku aplikacije';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Otvori lozinke aplikacija za $provider';
  }

  @override
  String get emailStepSignIn => '2. Prijava';

  @override
  String get appPassword => 'Lozinka aplikacije';

  @override
  String get appPasswordHelper =>
      'Razmaci nisu bitni. NeoAgent je sprema šifrirano.';

  @override
  String get emailUsernameOptional => 'Korisničko ime, ako nije vaša e-pošta';

  @override
  String get emailIncludeCalendar => 'Uključi kalendar';

  @override
  String get emailIncludeContacts => 'Uključi kontakte';

  @override
  String get imapServer => 'IMAP poslužitelj';

  @override
  String get smtpServer => 'SMTP poslužitelj';

  @override
  String get caldavUrlOptional => 'CalDAV URL (neobavezno)';

  @override
  String get carddavUrlOptional => 'CardDAV URL (neobavezno)';

  @override
  String get alternativeEmail =>
      'Povežite sandučić lozinkom aplikacije ili kalendar njegovom iCal poveznicom. Gotovo za par minuta.';

  @override
  String get alternativePhone =>
      'Podijelite kalendar i kontakte koji su već na telefonu putem aplikacije NeoAgent.';

  @override
  String get alternativePhoneElsewhere =>
      'Podijelite kalendar i kontakte koji su već na telefonu. Postavite u aplikaciji NeoAgent na telefonu.';

  @override
  String get skipTheDeveloperConsole => 'Bez konzole za razvojne programere';

  @override
  String get phoneSyncPromptTitle => 'Smije li agent vidjeti vaš kalendar?';

  @override
  String get phoneSyncPromptBody =>
      'Podijelite kalendare i kontakte ovog telefona kako bi agent mogao planirati vaš dan. To možete promijeniti bilo kada u Alati › Integracije.';

  @override
  String get phoneSyncTitle => 'Podijeli kalendar i kontakte ovog telefona';

  @override
  String get phoneSyncIntro =>
      'Agent vidi kalendare i kontakte svih računa na ovom telefonu. Bez konzole za razvojne programere i dodatne prijave.';

  @override
  String get phoneSyncPointAccounts =>
      'Radi s Google, Outlook, iCloud i Exchange računima na ovom telefonu.';

  @override
  String get phoneSyncPointPrivate =>
      'Dijeli se samo s vašim NeoAgent poslužiteljem, koji ih sprema šifrirano.';

  @override
  String get phoneSyncPointWrites =>
      'Događaje koje doda agent stvara ovaj telefon i sinkroniziraju se kao i obično.';

  @override
  String get phoneSyncCalendarHint =>
      'Događaji od prije 30 dana do 90 dana unaprijed';

  @override
  String get phoneSyncContacts => 'Kontakti';

  @override
  String get phoneSyncContactsHint =>
      'Imena, adrese e-pošte i telefonski brojevi';

  @override
  String get phoneSyncOtherAgent =>
      'Ovaj telefon dijeli s drugim agentom. Dijeljenje ovdje premješta ga ovom agentu.';

  @override
  String get phoneSyncDenied =>
      'NeoAgent još nema pristup. Dopustite ga u Postavkama i vratite se.';

  @override
  String get openPhoneSettings => 'Otvori Postavke';

  @override
  String get phoneSyncShare => 'Podijeli s NeoAgentom';

  @override
  String get phoneSyncStop => 'Prekini dijeljenje';

  @override
  String get phoneSyncWaiting => 'Čekam prvu sinkronizaciju…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Zadnja sinkronizacija $time';
  }

  @override
  String get calendarLink => 'Poveznica kalendara';

  @override
  String get calendarLinkHelper =>
      'iCal adresa kalendara. Svatko tko je ima može čitati kalendar, zato je čuvajte privatnom.';

  @override
  String get calendarLinkName => 'Naziv (neobavezno)';

  @override
  String get calendarLinkAdded => 'Kalendar dodan';

  @override
  String get toolsApps => 'Aplikacije';

  @override
  String get reconnect => 'Ponovno poveži';

  @override
  String get reconnectNeeded => 'Potrebno ponovno povezivanje';

  @override
  String get mixedAccess => 'Mješoviti pristup';

  @override
  String disconnectAccountTitle(String account) {
    return 'Odspojiti $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Agent putem ovog računa gubi pristup za $apps.';
  }

  @override
  String get neoRouterServerDescription =>
      'Povežite svoj NeoRouter jednom i svaki račun ovdje koristit će ga za zadatke uključene u nastavku.';

  @override
  String get neoRouterUserDescription =>
      'Za zadatke uključene u nastavku koristite vlastiti NeoRouter račun umjesto pružatelja ovog poslužitelja.';

  @override
  String get neoRouterAddress => 'Adresa NeoRoutera';

  @override
  String get neoRouterConnect => 'Poveži NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Odobrite NeoAgent u NeoRouteru. Prikazuje kod $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Otvori ponovno';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Povezano s $arg1';
  }

  @override
  String get neoRouterUnreachable => 'NeoRouter trenutačno nije dostupan.';

  @override
  String get neoRouterDisconnect => 'Prekini vezu';

  @override
  String get neoRouterDisconnectBody =>
      'NeoAgent prestaje koristiti ovaj NeoRouter. Da biste povukli i ključ, opozovite ga u NeoRouteru pod API ključevi.';

  @override
  String get neoRouterServerInUse =>
      'Ovaj poslužitelj već koristi NeoRouter za sve. Povežite vlastiti NeoRouter račun za vlastite modele i proračun.';

  @override
  String get neoRouterConnected => 'NeoRouter je povezan.';

  @override
  String get neoRouterRoleChat => 'Razgovor i prepoznavanje slika';

  @override
  String get neoRouterRoleSystemOne => 'Odluke System One';

  @override
  String get neoRouterRoleTranscription => 'Govor u tekst';

  @override
  String get neoRouterRoleLive => 'Glas uživo';

  @override
  String get neoRouterRoleEmbeddings => 'Pretraživanje memorije';

  @override
  String get neoRouterRoleImages => 'Izrada slika';

  @override
  String get neoRouterRoleSearch => 'Pretraživanje weba';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'Dostupno u vašem NeoRouteru: $arg1';
  }

  @override
  String get neoRouterNoModels => 'U vašem NeoRouteru još nema ničega.';

  @override
  String get neoRouterPicksModels =>
      'NeoRouter bira model za svaki zahtjev, pa se ovaj odabir ne koristi.';

  @override
  String neoRouterNotAllowedArg1(Object? arg1) {
    return 'U vašem NeoRouteru: $arg1, ali ključ NeoAgenta ih još ne smije koristiti (npr. plaćene). Dopustite ih za NeoAgent pod API ključevi u NeoRouteru.';
  }

  @override
  String get neoRouterNoDecisionModels =>
      'Potrebni su modeli odlučivanja poput Jeva. Sigurnosni klasifikatori ne odgovaraju na ova pitanja.';
}
